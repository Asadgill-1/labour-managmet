import 'package:domain/cash.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';

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

  test('a phone on version 7 upgrades: old payments stay whole and go oldest first, and what a new one settles cannot change (PAY-06)', () async {
    final old = await verifier.schemaAt(7);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO opening_balances (id, $commonColumns, kind, worker_id, amount_fils, as_of_date, source_note) VALUES ('o1', $common, 'worker_salary_owed', 'w1', 5000, '2026-09-30', 'Old book');
      INSERT INTO cash_entries (id, $commonColumns, entry_date, kind, amount_fils, worker_id) VALUES ('c1', $common, '2026-10-05', 'salaryPaid', 3000, 'w1');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final line = await db.select(db.cashEntries).getSingle();
    expect((line.amountFils, line.reference, line.receiver), (3000, null, null));
    expect((await db.select(db.tenantProfiles).getSingle()).wageDueDays, isNull);
    final statement = (await db.statementsFor('2026-10', workerId: 'w1')).single;
    expect(statement.unpaid, {'2026-09': 2000});

    await db.addSalaryPayment(operationId: newUuid(), date: '2026-10-06', workerId: 'w1', amountFils: 2000, parts: {'2026-09': 2000}, extraNote: 'x');
    await expectLater(db.delete(db.salaryAllocations).go(), throwsA(anything));
  });

  test('a phone on version 11 upgrades: its attendance is untouched, and a timesheet can be made from it (TS-01)', () async {
    final old = await verifier.schemaAt(11);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'ATE');
      INSERT INTO sites (id, $commonColumns, client_id, name) VALUES ('s1', $common, 'c1', 'Melboard');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO pay_contracts (id, $commonColumns, worker_id, basis, rate_fils, effective_from) VALUES ('k1', $common, 'w1', 'day', 1000, '2026-01-01');
      INSERT INTO billing_contracts (id, $commonColumns, client_id, basis, rate_fils, effective_from) VALUES ('k2', $common, 'c1', 'day', 1500, '2026-01-01');
      INSERT INTO attendance_batches (id, $commonColumns, work_date, client_id, site_id) VALUES ('b1', $common, '2026-10-20', 'c1', 's1');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, work_date, clock_minutes, break_minutes, break_paid_client, break_paid_worker,
        client_billable_minutes, worker_payable_minutes, attendance_status, client_basis, client_rate_fils, client_amount_fils, worker_basis, worker_rate_fils, worker_amount_fils, state)
      VALUES ('e1', $common, 'b1', 'w1', 'c1', 's1', '2026-10-20', 0, 0, 0, 0, 0, 0, 'present', 'day', 1500, 1500, 'day', 1000, 1000, 'submitted');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect((await db.select(db.attendanceEntries).getSingle()).state, 'submitted');
    final id = await db.createTimesheet(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
    expect((await db.timesheetView(id)).totals.amountFils, 1500);
    final line = await db.select(db.timesheetLines).getSingle();
    await expectLater(db.customStatement("UPDATE timesheet_lines SET amount_fils = 1 WHERE id = '${line.id}'"), throwsA(anything));
    await expectLater(db.customStatement("DELETE FROM timesheet_lines WHERE id = '${line.id}'"), throwsA(anything));
    await db.allocateBilling('i1', [line], operationId: newUuid());
    await expectLater(db.allocateBilling('i2', [line], operationId: newUuid()), throwsA(isA<AlreadyBilled>()));
  });

  test('a phone on version 10 upgrades: it has no template, papers issue with the company details, and nothing else moves (DOC-05)', () async {
    final old = await verifier.schemaAt(10);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name, address) VALUES ('p1', $common, 'Al Noor LLC', 'Dubai');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO cash_entries (id, $commonColumns, entry_date, kind, amount_fils, worker_id) VALUES ('c1', $common, '2026-09-05', 'advanceGiven', 3000, 'w1');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect(await db.documentTemplate(), isNull);
    final identity = await db.currentIdentity(brandArgb: 1, softArgb: 2);
    expect((identity.legalName, identity.contactLine, identity.printLetterhead), ('Al Noor LLC', 'Dubai', true));
    expect((await db.select(db.cashEntries).getSingle()).amountFils, 3000);
    await db.saveDocumentTemplate(const DocumentTemplatesCompanion(blankTopMm: Value(55)), operationId: newUuid());
    expect((await db.documentTemplate())!.blankTopMm, 55);
    await expectLater(db.customStatement('DELETE FROM document_assets'), completes);
    await expectLater(db.customUpdate("UPDATE issued_documents SET title = 'x'"), completes, reason: 'no rows yet, and the trigger fires per row');
  });

  test('a phone on version 9 upgrades: a closed month stays closed, and a day off can be marked after it (D-045)', () async {
    final old = await verifier.schemaAt(9);
    old.rawDatabase.execute('''
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO period_locks (id, $commonColumns, month, last_day) VALUES ('l1', $common, '2026-09', '2026-09-30');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    expect(await db.lockedThrough(), '2026-09-30');
    await expectLater(db.markDayOff('2026-09-20', ['w1'], operationId: newUuid()), throwsA(isA<PeriodLocked>()));
    await db.markDayOff('2026-10-02', ['w1'], operationId: newUuid());
    await db.markDayOff('2026-10-02', ['w1'], operationId: newUuid());
    expect(await db.select(db.dayOffs).get(), hasLength(1), reason: 'marking twice is one mark');
  });

  test('a phone on version 8 upgrades: its money stays, nothing is closed, and a month closed afterwards holds (REP-04)', () async {
    final old = await verifier.schemaAt(8);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO workers (id, $commonColumns, code, name, active) VALUES ('w1', $common, 'W001', 'Ahmad', 0);
      INSERT INTO cash_entries (id, $commonColumns, entry_date, kind, amount_fils, worker_id) VALUES ('c1', $common, '2026-09-05', 'advanceGiven', 3000, 'w1');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect(await db.lockedThrough(), isNull);
    expect((await db.select(db.cashEntries).getSingle()).amountFils, 3000);

    await db.closeMonth('2026-09', operationId: newUuid());
    await expectLater(db.addCashEntry(operationId: newUuid(), date: '2026-09-06', kind: CashKind.expense, amountFils: 100), throwsA(isA<PeriodLocked>()));
  });
}
