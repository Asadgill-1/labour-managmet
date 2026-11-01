import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'attendance.dart';
import 'tables.dart';
import 'tenant_database.steps.dart';

part 'tenant_database.g.dart';

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// The date falls in a closed month (REP-04). The database refuses the write, so no path around it exists.
class PeriodLocked implements Exception {
  const PeriodLocked();
}

/// [through] is the last day of the latest closed month, from [TenantDatabase.lockedThrough].
bool isClosed(String date, String? through) => through != null && date.compareTo(through) <= 0;

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
    SalaryAllocations,
    PeriodLocks,
    DayOffs,
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
  int get schemaVersion => 10;

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
      from5To6: (m, schema) async {
        await m.drop(schema.approvedEntryNoEdit);
        await m.createTrigger(schema.approvedEntryNoEdit);
      },
      from6To7: (m, schema) async {
        await m.addColumn(schema.workerGroupMembers, schema.workerGroupMembers.rateBasis);
      },
      from7To8: (m, schema) async {
        await m.addColumn(schema.cashEntries, schema.cashEntries.reference);
        await m.addColumn(schema.cashEntries, schema.cashEntries.receiver);
        await m.addColumn(schema.tenantProfiles, schema.tenantProfiles.wageDueDays);
        await m.createTable(schema.salaryAllocations);
        await m.createTrigger(schema.allocationNoUpdate);
        await m.createTrigger(schema.allocationNoDelete);
      },
      from8To9: (m, schema) async {
        await m.createTable(schema.periodLocks);
        await m.createIndex(schema.oneLivePeriodLock);
        for (final trigger in [
          schema.lockNoDelete,
          schema.lockNoEdit,
          schema.lockStaysReopened,
          schema.closedCashNoInsert,
          schema.closedEntryNoInsert,
          schema.closedEntryNoEdit,
          schema.closedEntryNoDelete,
          schema.closedItemNoInsert,
          schema.closedItemNoEdit,
          schema.closedItemNoDelete,
          schema.closedLineNoInsert,
          schema.closedLineNoReverse,
          schema.closedOpeningNoInsert,
          schema.closedOpeningNoEdit,
        ]) {
          await m.createTrigger(trigger);
        }
      },
      from9To10: (m, schema) async {
        await m.createTable(schema.dayOffs);
        await m.createTrigger(schema.closedDayOffNoInsert);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Rows saved under an older pricing rule (D-041, D-042) get priced by today's rule once. Frozen pay stays as it is.
      if (details.hadUpgrade && details.versionBefore! < 7) {
        try {
          await repriceRows(operationId: newUuid());
        } catch (_) {
          // Nothing was written. The next rate saved tries again, and the owner's data must still open.
        }
      }
    },
  );

  /// The last day of the latest closed month (REP-04). Null when none is closed.
  Future<String?> lockedThrough() async {
    final latest = periodLocks.lastDay.max();
    final query = selectOnly(periodLocks)
      ..addColumns([latest])
      ..where(periodLocks.reopened.equals(false));
    return (await query.getSingle()).read(latest);
  }

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
  }) async {
    try {
      await _applyOnce(operationId: operationId, entity: entity, recordId: recordId, version: version, action: action, change: change, reason: reason);
    } catch (e) {
      // From a background database this arrives wrapped, so the words are what stays the same.
      if (e.toString().contains('period is closed')) throw const PeriodLocked();
      rethrow;
    }
  }

  Future<void> _applyOnce({
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
