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
    expect(entry.payrollLineId, isNull);
    expect((await db.select(db.workers).getSingle()).visaInstalmentFils, isNull);
  });

  test('a phone on version 5 upgrades: a row held only by its company rate now counts, and a frozen row can fill one in (D-041)', () async {
    final old = await verifier.schemaAt(5);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'ATE');
      INSERT INTO sites (id, $commonColumns, client_id, name) VALUES ('s1', $common, 'c1', 'Melboard');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO pay_contracts (id, $commonColumns, worker_id, basis, rate_fils, effective_from) VALUES ('k1', $common, 'w1', 'day', 1000, '2026-01-01');
      INSERT INTO attendance_batches (id, $commonColumns, work_date, client_id, site_id) VALUES ('b1', $common, '2026-11-01', 'c1', 's1');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, work_date, clock_minutes, break_minutes,
        break_paid_client, break_paid_worker, client_billable_minutes, worker_payable_minutes, attendance_status, worker_basis, worker_rate_fils, worker_amount_fils, state)
      VALUES ('e1', $common, 'b1', 'w1', 'c1', 's1', '2026-11-01', 0, 0, 0, 0, 0, 0, 'present', 'day', 1000, 1000, 'draft');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final entry = await db.select(db.attendanceEntries).getSingle();
    expect(entry.state, 'submitted');
    expect(entry.workerAmountFils, 1000);
    expect(entry.clientAmountFils, isNull);

    await db.customStatement("UPDATE attendance_entries SET state = 'approved'");
    await db.customStatement('UPDATE attendance_entries SET client_rate_fils = 500, client_amount_fils = 500');
    await expectLater(db.customStatement('UPDATE attendance_entries SET client_amount_fils = 1'), throwsA(anything));
    await expectLater(db.customStatement('UPDATE attendance_entries SET worker_amount_fils = 1'), throwsA(anything));
  });

  test("a phone on version 6 upgrades: a worker's own hourly rate takes over open rows from the group's daily wage, and frozen pay stays (D-042)", () async {
    final old = await verifier.schemaAt(6);
    final clock = "'2026-11-01 08:00:00'";
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'ATE');
      INSERT INTO sites (id, $commonColumns, client_id, name) VALUES ('s1', $common, 'c1', 'Melboard');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO pay_contracts (id, $commonColumns, worker_id, basis, rate_fils, effective_from) VALUES ('k1', $common, 'w1', 'hour', 1000, '2026-01-01');
      INSERT INTO worker_groups (id, $commonColumns, name, daily_rate_fils) VALUES ('g1', $common, 'Melboard', 1000);
      INSERT INTO worker_group_members (id, $commonColumns, group_id, worker_id, daily_rate_fils) VALUES ('m1', $common, 'g1', 'w1', NULL);
      INSERT INTO attendance_batches (id, $commonColumns, work_date, client_id, site_id) VALUES ('b1', $common, '2026-11-01', 'c1', 's1');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, group_id, work_date, start_utc, end_utc, clock_minutes, break_minutes,
        break_paid_client, break_paid_worker, client_billable_minutes, worker_payable_minutes, attendance_status, worker_basis, worker_rate_fils, worker_amount_fils, state)
      VALUES ('open', $common, 'b1', 'w1', 'c1', 's1', 'g1', '2026-11-01', strftime('%s', '2026-11-01 04:00:00'), strftime('%s', '2026-11-01 11:00:00'), 420, 0, 0, 0, 420, 420, 'present', 'day', 1000, 1000, 'submitted');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, group_id, work_date, start_utc, end_utc, clock_minutes, break_minutes,
        break_paid_client, break_paid_worker, client_billable_minutes, worker_payable_minutes, attendance_status, worker_basis, worker_rate_fils, worker_amount_fils, state)
      VALUES ('frozen', $common, 'b1', 'w1', 'c1', 's1', 'g1', '2026-10-31', strftime('%s', '2026-10-31 04:00:00'), strftime('%s', '2026-10-31 11:00:00'), 420, 0, 0, 0, 420, 420, 'present', 'day', 1000, 1000, 'approved');
    ''');
    expect(clock, isNotEmpty);

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final member = await db.select(db.workerGroupMembers).getSingle();
    expect(member.rateFils, isNull);
    expect(member.rateBasis, 'day');

    final rows = {for (final e in await db.select(db.attendanceEntries).get()) e.id: e};
    expect(rows['open']!.workerBasis, 'hour');
    expect(rows['open']!.workerAmountFils, 7000);
    expect(rows['frozen']!.workerAmountFils, 1000);
  });
}
