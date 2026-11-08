import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/tenant_database.dart';

const tenant = '00000000-0000-4000-8000-00000000000a';

TenantDatabase testDb() => TenantDatabase(NativeDatabase.memory(), tenantId: tenant, deviceId: 'device-1');

Future<void> insertClient(TenantDatabase db, String id, String op, {String name = 'Client'}) {
  return db.applyOperation(
    operationId: op,
    entity: 'clients',
    recordId: id,
    version: 1,
    action: 'create',
    change: () async {
      final now = DateTime.now().toUtc();
      final row = await db.into(db.clients).insertReturning(
        ClientsCompanion.insert(
          id: id,
          tenantId: tenant,
          createdAtUtc: now,
          updatedAtUtc: now,
          actorId: localOwner,
          sourceOperationId: op,
          name: name,
        ),
      );
      return row.toJson();
    },
  );
}

void main() {
  test('new UUIDs are v4, lowercase and unique', () {
    final ids = List.generate(100, (_) => newUuid());
    expect(ids.toSet().length, 100);
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    }
  });

  test('an operation writes the change, audit event and outbox row together', () async {
    final db = testDb();
    addTearDown(db.close);
    await insertClient(db, 'c1', 'op1', name: 'Al Noor');

    final audit = await db.select(db.auditEvents).getSingle();
    expect(audit.action, 'create');
    expect(audit.recordId, 'c1');

    final out = await db.select(db.outbox).getSingle();
    expect(out.operationId, 'op1');
    expect(out.tenantId, tenant);
    expect(out.deviceId, 'device-1');
    expect(out.ackedAtUtc, isNull);
    expect(jsonDecode(out.payload)['name'], 'Al Noor');
  });

  test('retrying the same operation changes nothing', () async {
    final db = testDb();
    addTearDown(db.close);
    await insertClient(db, 'c1', 'op1');
    await insertClient(db, 'c1', 'op1');

    expect(await db.select(db.clients).get(), hasLength(1));
    expect(await db.select(db.outbox).get(), hasLength(1));
    expect(await db.select(db.auditEvents).get(), hasLength(1));
  });

  test('a failing change leaves nothing behind', () async {
    final db = testDb();
    addTearDown(db.close);
    await expectLater(
      db.applyOperation(
        operationId: 'op1',
        entity: 'clients',
        recordId: 'c1',
        version: 1,
        action: 'create',
        change: () async {
          await insertClient(db, 'c1', 'nested');
          throw StateError('crash mid-save');
        },
      ),
      throwsStateError,
    );

    expect(await db.select(db.clients).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.auditEvents).get(), isEmpty);
  });

  test('audit events cannot be changed or deleted', () async {
    final db = testDb();
    addTearDown(db.close);
    await insertClient(db, 'c1', 'op1');

    await expectLater(db.customStatement("UPDATE audit_events SET action = 'x'"), throwsA(isA<SqliteException>()));
    await expectLater(db.customStatement('DELETE FROM audit_events'), throwsA(isA<SqliteException>()));
  });

  test('foreign keys are enforced', () async {
    final db = testDb();
    addTearDown(db.close);
    final now = DateTime.now().toUtc();
    await expectLater(
      db.into(db.sites).insert(
        SitesCompanion.insert(
          id: 's1',
          tenantId: tenant,
          createdAtUtc: now,
          updatedAtUtc: now,
          actorId: localOwner,
          sourceOperationId: 'op',
          clientId: 'missing',
          name: 'Site',
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('worker code is unique within the tenant', () async {
    final db = testDb();
    addTearDown(db.close);
    final now = DateTime.now().toUtc();
    WorkersCompanion worker(String id) => WorkersCompanion.insert(
      id: id,
      tenantId: tenant,
      createdAtUtc: now,
      updatedAtUtc: now,
      actorId: localOwner,
      sourceOperationId: id,
      code: 'W1',
      name: 'Ali',
    );
    await db.into(db.workers).insert(worker('w1'));
    await expectLater(db.into(db.workers).insert(worker('w2')), throwsA(isA<SqliteException>()));
  });

  test('a break longer than the shift is rejected by the database', () async {
    final db = testDb();
    addTearDown(db.close);
    await expectLater(
      db.customStatement(
        "INSERT INTO attendance_entries (id, tenant_id, created_at_utc, updated_at_utc, actor_id, source_operation_id, "
        "batch_id, worker_id, client_id, site_id, work_date, clock_minutes, break_minutes, break_paid_client, break_paid_worker, "
        "client_billable_minutes, worker_payable_minutes, attendance_status) "
        "VALUES ('e', 't', 0, 0, 'a', 'o', 'b', 'w', 'c', 's', '2026-11-01', 60, 61, 0, 0, 0, 0, 'present')",
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
