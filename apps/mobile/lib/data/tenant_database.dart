import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tables.dart';
import 'tenant_database.steps.dart';

part 'tenant_database.g.dart';

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// Replaced by the signed-in user's ID in T19.
const localOwner = 'local-owner';

String newUuid() {
  final random = Random.secure();
  final b = List.generate(16, (_) => random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

@DriftDatabase(
  tables: [
    TenantProfiles,
    Clients,
    Sites,
    Workers,
    PayContracts,
    BillingContracts,
    OpeningBalances,
    WorkerGroups,
    WorkerGroupMembers,
    Rooms,
    CashEntries,
    AttendanceBatches,
    AttendanceEntries,
    PayrollRuns,
    PayrollLines,
    PayrollItems,
    AuditEvents,
    Outbox,
  ],
  include: {'triggers.drift'},
)
class TenantDatabase extends _$TenantDatabase {
  TenantDatabase(super.executor, {required this.tenantId, required this.deviceId, this.actorId = localOwner});

  final String tenantId;
  final String deviceId;
  final String actorId;

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.workerGroups);
        await m.createTable(schema.workerGroupMembers);
        await m.addColumn(schema.attendanceBatches, schema.attendanceBatches.groupId);
        await m.addColumn(schema.attendanceEntries, schema.attendanceEntries.groupId);
      },
      from2To3: (m, schema) async {
        await m.createTable(schema.rooms);
        await m.addColumn(schema.workers, schema.workers.roomId);
        await m.createTable(schema.cashEntries);
        await m.createIndex(schema.idxCashDate);
        await m.createIndex(schema.idxCashWorker);
        await m.createIndex(schema.idxCashRoom);
        await m.createTrigger(schema.cashNoUpdate);
        await m.createTrigger(schema.cashNoDelete);
      },
      from3To4: (m, schema) async {
        await m.addColumn(schema.tenantProfiles, schema.tenantProfiles.deductionLimitBps);
        await m.createTable(schema.payrollRuns);
        await m.createTable(schema.payrollLines);
        await m.createTable(schema.payrollItems);
        await m.addColumn(schema.attendanceEntries, schema.attendanceEntries.payrollLineId);
        await m.createIndex(schema.idxPayrollLinesWorker);
        await m.createIndex(schema.idxPayrollItemsPeriod);
        await m.createIndex(schema.oneLivePayrollLine);
        await m.createTrigger(schema.payrollRunNoUpdate);
        await m.createTrigger(schema.payrollRunNoDelete);
        await m.createTrigger(schema.payrollLineNoEdit);
        await m.createTrigger(schema.payrollLineStaysReversed);
        await m.createTrigger(schema.payrollLineNoDelete);
        await m.createTrigger(schema.postedItemNoEdit);
        await m.createTrigger(schema.postedItemNoDelete);
      },
      from4To5: (m, schema) async {
        await m.addColumn(schema.workers, schema.workers.visaInstalmentFils);
        await m.addColumn(schema.payrollLines, schema.payrollLines.visaRecoveryFils);
        // The trigger names every figure it protects, so it comes back with the new one.
        await m.drop(schema.payrollLineNoEdit);
        await m.createTrigger(schema.payrollLineNoEdit);
        await m.createTrigger(schema.cashVisaNeedsWorker);
      },
    ),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  /// The single write path. Runs [change] with its audit event and outbox row in one transaction,
  /// once per [operationId], so a retry after a crash or double tap changes nothing (TEAM-04, UX-07).
  /// [change] returns the stored record, which becomes the outbox payload.
  Future<void> applyOperation({
    required String operationId,
    required String entity,
    required String recordId,
    required int version,
    required String action,
    required Future<Map<String, dynamic>> Function() change,
    String? reason,
  }) {
    return transaction(() async {
      final seen = await (select(outbox)..where((o) => o.operationId.equals(operationId))).getSingleOrNull();
      if (seen != null) return;
      final payload = await change();
      final now = DateTime.now().toUtc();
      await into(auditEvents).insert(
        AuditEventsCompanion.insert(
          id: newUuid(),
          tenantId: tenantId,
          atUtc: now,
          actorId: actorId,
          action: action,
          entity: entity,
          recordId: recordId,
          recordVersion: version,
          operationId: operationId,
          reason: Value(reason),
        ),
      );
      await into(outbox).insert(
        OutboxCompanion.insert(
          operationId: operationId,
          tenantId: tenantId,
          entity: entity,
          recordId: recordId,
          recordVersion: version,
          deviceId: deviceId,
          payload: jsonEncode(payload),
          createdAtUtc: now,
        ),
      );
    });
  }
}

/// One encrypted file per tenant (D-005). The tenant ID becomes a file name, so only a UUID passes.
File tenantFile(Directory dir, String tenantId) {
  if (!_uuid.hasMatch(tenantId)) {
    throw ArgumentError.value(tenantId, 'tenantId', 'must be a lowercase UUID');
  }
  return File('${dir.path}/tenant_$tenantId.db');
}

TenantDatabase openTenantDatabase(File file, String hexKey, {required String tenantId, required String deviceId}) {
  return TenantDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Not an assert: a build without the cipher must never write payroll data in plaintext.
        if (db.select('PRAGMA cipher;').isEmpty) {
          throw StateError('SQLite build has no encryption support');
        }
        db.execute("PRAGMA hexkey = '$hexKey';");
      },
    ),
    tenantId: tenantId,
    deviceId: deviceId,
  );
}

String newHexKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Reads this tenant's key from Android Keystore-backed storage, creating it on first use.
Future<String> tenantKey(FlutterSecureStorage storage, String tenantId) async {
  final name = 'db_key_$tenantId';
  final existing = await storage.read(key: name);
  if (existing != null) return existing;
  final created = newHexKey();
  await storage.write(key: name, value: created);
  return created;
}

/// Opens the local tenant. Real sign-in replaces the locally created tenant ID in T19.
Future<TenantDatabase> openLocalTenant(FlutterSecureStorage storage, Directory dir) async {
  Future<String> stableId(String name) async {
    final existing = await storage.read(key: name);
    if (existing != null) return existing;
    final created = newUuid();
    await storage.write(key: name, value: created);
    return created;
  }

  final tenantId = await stableId('local_tenant_id');
  final deviceId = await stableId('device_id');
  final key = await tenantKey(storage, tenantId);
  return openTenantDatabase(tenantFile(dir, tenantId), key, tenantId: tenantId, deviceId: deviceId);
}
