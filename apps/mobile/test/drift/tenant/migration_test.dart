import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'generated/schema.dart';

const common = "'t', 0, 0, 'a', 'op'";
const commonColumns = 'tenant_id, created_at_utc, updated_at_utc, actor_id, source_operation_id';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('Dart tables match the latest snapshot, so a table change without a migration fails', () async {
    final probe = TenantDatabase(await verifier.startAt(1), tenantId: 'tenant', deviceId: 'device');
    final latest = probe.schemaVersion;
    await probe.close();

    final db = TenantDatabase(await verifier.startAt(latest), tenantId: 'tenant', deviceId: 'device');
    addTearDown(db.close);
    await db.validateDatabaseSchema();
  });

  test('a phone on version 1 upgrades and keeps its workers and attendance (MODEL-08)', () async {
    final old = await verifier.schemaAt(1);
    old.rawDatabase.execute('''
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'Emaar');
      INSERT INTO sites (id, $commonColumns, client_id, name) VALUES ('s1', $common, 'c1', 'Marina');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO attendance_batches (id, $commonColumns, work_date, client_id, site_id) VALUES ('b1', $common, '2026-10-31', 'c1', 's1');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, work_date, clock_minutes, break_minutes,
        break_paid_client, break_paid_worker, client_billable_minutes, worker_payable_minutes, attendance_status)
      VALUES ('e1', $common, 'b1', 'w1', 'c1', 's1', '2026-10-31', 720, 60, 0, 0, 660, 660, 'present');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect((await db.select(db.workers).getSingle()).name, 'Ahmad');
    final entry = await db.select(db.attendanceEntries).getSingle();
    expect(entry.workerPayableMinutes, 660);
    expect(entry.groupId, isNull);
  });
}
