import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/changes.dart';
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/receipts.dart';
import 'package:labour_app/data/restore.dart';
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

  test('a phone on version 18 upgrades: its invoices keep counting, and a floor a restore sets is never changed (DATA-06)', () async {
    final old = await verifier.schemaAt(18);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'Fajr');
      INSERT INTO invoices (id, $commonColumns, client_id, status, from_date, to_date, issue_date, due_date, year, seq, number, parties)
      VALUES ('i1', $common, 'c1', 'issued', '2026-10-01', '2026-10-31', '2026-11-01', '2026-11-01', 2026, 6, 'INV-2026-0006', '{"supplierName":"Labour","customerName":"Fajr"}');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect(await db.lastNumbers(2026), {'invoice': 6});
    await db.recordRestore(from: 'backup', year: 2026, phone: const {}, owner: {'invoice': 9}, operationId: newUuid());
    expect(await db.nextNumber('invoice', 2026, 6), 10);
    await expectLater(db.customStatement('DELETE FROM number_floors'), throwsA(anything));
  });

  test("a phone on version 17 upgrades: a fixed contract's month charged in part before stays charged whole, and new lines keep their month (D-058)", () async {
    final old = await verifier.schemaAt(17);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'Fajr');
      INSERT INTO sites (id, $commonColumns, client_id, name) VALUES ('s1', $common, 'c1', 'Tower');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO pay_contracts (id, $commonColumns, worker_id, basis, rate_fils, effective_from) VALUES ('k1', $common, 'w1', 'day', 1000, '2026-01-01');
      INSERT INTO billing_contracts (id, $commonColumns, client_id, basis, rate_fils, effective_from) VALUES ('k2', $common, 'c1', 'monthFixed', 500000, '2026-01-01');
      INSERT INTO attendance_batches (id, $commonColumns, work_date, client_id, site_id) VALUES ('b1', $common, '2026-10-20', 'c1', 's1');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, work_date, clock_minutes, break_minutes, break_paid_client, break_paid_worker,
        client_billable_minutes, worker_payable_minutes, attendance_status, client_basis, client_rate_fils, client_amount_fils, worker_basis, worker_rate_fils, worker_amount_fils, state)
      VALUES ('e1', $common, 'b1', 'w1', 'c1', 's1', '2026-10-20', 0, 0, 0, 0, 0, 0, 'present', 'monthFixed', 500000, NULL, 'day', 1000, 1000, 'submitted');
      INSERT INTO invoices (id, $commonColumns, client_id, status, from_date, to_date, issue_date, due_date, year, seq, number, parties)
      VALUES ('i1', $common, 'c1', 'issued', '2026-10-01', '2026-10-31', '2026-11-01', '2026-11-01', 2026, 1, 'INV-2026-0001', '{"supplierName":"Labour","customerName":"Fajr"}');
      INSERT INTO invoice_lines (id, $commonColumns, invoice_id, position, description, basis, quantity, unit_price_fils, amount_fils, net_fils, vat_fils)
      VALUES ('l1', $common, 'i1', 1, 'Monthly contract amount for 10-2026', 'monthFixed', 1, 500000, 250000, 250000, 0);
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect((await db.select(db.invoiceLines).getSingle()).feeMonth, isNull);
    final sheet = await db.createTimesheet(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
    // The old invoice charged this row, as issuing did then.
    await db.allocateBilling('i1', await db.unbilledLines(sheet, monthly: true), operationId: newUuid());
    await expectLater(db.createInvoice(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid()), throwsA(isA<InvoiceRefused>()), reason: 'its rule then: the month was charged');
    expect(await db.uninvoicedWork(to: '2026-10-31'), isEmpty);

    await db.creditInvoice('i1', reason: 'Wrong amount', operationId: newUuid());
    final id = await db.createInvoice(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid());
    await db.issueInvoice(id, describe: (_) => 'Monthly contract amount for 10-2026', operationId: newUuid());
    final lines = await (db.select(db.invoiceLines)..where((l) => l.invoiceId.equals(id))).get();
    expect((lines.single.amountFils, lines.single.feeMonth), (500000, '2026-10'));
  });

  test('a phone on version 16 upgrades: its contract keeps paying the whole month, its items stay, and a recovery can then be nothing (D-057)', () async {
    final old = await verifier.schemaAt(16);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO pay_contracts (id, $commonColumns, worker_id, basis, rate_fils, effective_from, partial_method) VALUES ('k1', $common, 'w1', 'month', 310000, '2020-01-01', 'calendarDays');
      INSERT INTO payroll_items (id, $commonColumns, worker_id, period_from, kind, amount_fils, reason) VALUES ('i1', $common, 'w1', '2020-10-01', 'allowance', 5000, 'Food');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final contract = await db.select(db.payContracts).getSingle();
    expect((contract.cutAbsence, contract.offWeekdays), (false, null));
    expect((await db.select(db.payrollItems).getSingle()).amountFils, 5000);
    final f = (await db.payrollFor('2020-10')).single.figures;
    expect((f.salaryFils, f.absenceFils), (310000, 0), reason: 'no attendance, and still the whole month');
    await db.savePayItem(id: null, workerId: 'w1', month: '2020-10', kind: PayItemKind.advanceRecovery, amountFils: 0, reason: 'Not this month', authorizedBy: null, note: null, roomId: null, operationId: newUuid());
    expect(
      db.savePayItem(id: null, workerId: 'w1', month: '2020-10', kind: PayItemKind.allowance, amountFils: 0, reason: 'x', authorizedBy: null, note: null, roomId: null, operationId: newUuid()),
      throwsA(anything),
      reason: 'only a recovery can be nothing',
    );
  });

  test('a phone on version 15 upgrades: its rows and record stay, and a row can then be deleted and kept whole (D-056)', () async {
    final old = await verifier.schemaAt(15);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'ATE');
      INSERT INTO sites (id, $commonColumns, client_id, name) VALUES ('s1', $common, 'c1', 'Melboard');
      INSERT INTO workers (id, $commonColumns, code, name) VALUES ('w1', $common, 'W001', 'Ahmad');
      INSERT INTO attendance_batches (id, $commonColumns, work_date, client_id, site_id) VALUES ('b1', $common, '2026-10-20', 'c1', 's1');
      INSERT INTO attendance_entries (id, $commonColumns, batch_id, worker_id, client_id, site_id, work_date, clock_minutes, break_minutes, break_paid_client, break_paid_worker,
        client_billable_minutes, worker_payable_minutes, attendance_status, client_basis, client_rate_fils, client_amount_fils, worker_basis, worker_rate_fils, worker_amount_fils, state)
      VALUES ('e1', $common, 'b1', 'w1', 'c1', 's1', '2026-10-20', 0, 0, 0, 0, 0, 0, 'present', 'day', 1500, 1500, 'day', 1000, 1000, 'submitted');
      INSERT INTO audit_events (id, tenant_id, at_utc, actor_id, action, entity, record_id, record_version, operation_id) VALUES ('a1', 't', 0, 'a', 'create', 'attendance_entries', 'e1', 1, 'op');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    final entry = await db.select(db.attendanceEntries).getSingle();
    expect((entry.deleted, (await db.select(db.auditEvents).getSingle()).detail), (false, null));
    await db.deleteAttendance(entry, note: 'Old row', reopenReason: 'x', operationId: newUuid());
    expect(await db.select(db.attendanceEntries).get(), isEmpty);
    final deleted = ChangeNote.of(await (db.select(db.auditEvents)..where((a) => a.action.equals('delete'))).getSingle());
    expect((deleted.note, deleted.facts[Fact.worker], deleted.facts[Fact.pay]), ('Old row', 'Ahmad (W001)', 1000));
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

  test('a phone on version 14 upgrades: its invoice and the company receipt in its cash book stay, and the receipt then settles it (INV-05)', () async {
    final old = await verifier.schemaAt(14);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'ATE');
      INSERT INTO invoices (id, $commonColumns, client_id, status, from_date, to_date, issue_date, due_date, year, seq, number, parties)
      VALUES ('i1', $common, 'c1', 'issued', '2026-10-01', '2026-10-31', '2026-11-01', '2026-11-01', 2026, 1, 'INV-2026-0001', '{"supplierName":"Labour","customerName":"ATE"}');
      INSERT INTO invoice_lines (id, $commonColumns, invoice_id, position, description, basis, quantity, unit_price_fils, amount_fils, net_fils, vat_fils)
      VALUES ('l1', $common, 'i1', 1, 'Manpower supply', 'day', 2, 1500, 3000, 3000, 0);
      INSERT INTO cash_entries (id, $commonColumns, entry_date, kind, amount_fils, client_id) VALUES ('r1', $common, '2026-11-02', 'clientReceipt', 1200, 'c1');
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect((await db.receivables()).creditOf('c1'), 1200, reason: 'an old receipt waits as credit');
    await db.useClientCredit('i1', operationId: newUuid());
    final money = await db.receivables();
    expect((money.invoices['i1']!.leftFils, money.creditOf('c1')), (1800, 0));
  });

  test('a phone on version 13 upgrades: its invoice stays as issued, and can take several credit notes for amounts (INV-06)', () async {
    final old = await verifier.schemaAt(13);
    old.rawDatabase.execute('''
      INSERT INTO tenant_profiles (id, $commonColumns, legal_name) VALUES ('p1', $common, 'Labour');
      INSERT INTO clients (id, $commonColumns, name) VALUES ('c1', $common, 'ATE');
      INSERT INTO invoices (id, $commonColumns, client_id, status, from_date, to_date, issue_date, due_date, year, seq, number, parties)
      VALUES ('i1', $common, 'c1', 'issued', '2026-10-01', '2026-10-31', '2026-11-01', '2026-11-01', 2026, 1, 'INV-2026-0001', '{"supplierName":"Labour","customerName":"ATE"}');
      INSERT INTO invoice_lines (id, $commonColumns, invoice_id, position, description, basis, quantity, unit_price_fils, amount_fils, net_fils, vat_fils)
      VALUES ('l1', $common, 'i1', 1, 'Manpower supply', 'day', 2, 1500, 3000, 3000, 0);
    ''');

    final db = TenantDatabase(old.newConnection(), tenantId: 't', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);

    expect((await db.invoiceView('i1')).totals.totalFils, 3000);
    await db.creditInvoice('i1', reason: 'Rate agreed lower', amountFils: 500, operationId: newUuid());
    await db.creditInvoice('i1', reason: 'Rate agreed lower again', amountFils: 500, operationId: newUuid());
    final v = await db.invoiceView('i1');
    expect((v.status, v.creditNotes.length, v.leftFils), (InvoiceStatus.issued, 2, 2000));
  });

  test('a phone on version 12 upgrades: its attendance stays, and an invoice bills it once, for good (INV-01, INV-06)', () async {
    final old = await verifier.schemaAt(12);
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

    expect(await db.select(db.invoices).get(), isEmpty);
    expect(await db.uninvoicedWork(to: '2026-10-31'), {('c1', '2026-10')});
    final sheet = await db.createTimesheet(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
    final id = await db.createInvoice(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid());
    await db.issueInvoice(id, describe: (_) => 'Manpower supply', operationId: newUuid());
    expect((await db.invoiceView(id)).totals.totalFils, 1500);
    expect(await db.uninvoicedWork(to: '2026-10-31'), isEmpty);
    await expectLater(db.customStatement("UPDATE invoices SET po_reference = 'x'"), throwsA(anything));
    await expectLater(db.customStatement('DELETE FROM invoice_lines'), throwsA(anything));
    await expectLater(db.createInvoice(clientId: 'c1', from: '2026-10-01', to: '2026-10-31', operationId: newUuid()), throwsA(isA<InvoiceRefused>()));
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
