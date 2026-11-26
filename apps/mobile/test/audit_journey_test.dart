// One company's month from its first record to a restored backup, through the app's own write paths on an encrypted
// file (QA-01, TC-013). The figures are worked out by hand from docs/CALCULATION_SPEC.md, not read back from the code.
// Signup and login run against stand-ins in account_flow_test.dart; nothing here touches the cloud.
import 'dart:io';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/receipts.dart';
import 'package:labour_app/data/restore.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/features/invoices/invoice_paper.dart';

import 'support.dart';

const _oct = '2020-10';

/// 08:00 to 18:00 with an unpaid hour: 540 minutes counted.
const _shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

void main() {
  // A paper draws with the fonts from the app's assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory oldPhone;
  late Directory newPhone;
  final dbs = <TenantDatabase>[];

  setUp(() async {
    oldPhone = await Directory.systemTemp.createTemp('qa01-old');
    newPhone = await Directory.systemTemp.createTemp('qa01-new');
  });
  tearDown(() async {
    // Closed first, even after a failure, or Windows keeps the file.
    for (final db in dbs) {
      await db.close();
    }
    dbs.clear();
    await oldPhone.delete(recursive: true);
    await newPhone.delete(recursive: true);
  });

  TenantDatabase open(Directory dir, String key) => openTenantDatabase(tenantFile(dir, testTenant), key, tenantId: testTenant, deviceId: 'device-1');

  test('a company, two clients, mixed pay, attendance, payroll, part payment, timesheet, VAT invoice, part receipt, paper, backup and restore (QA-01)', () async {
    final key = newHexKey();
    var db = open(oldPhone, key);
    dbs.add(db);

    // Apni company, registered for VAT.
    await db.saveRow(
      db.tenantProfiles,
      id: null,
      operationId: newUuid(),
      fields: const TenantProfilesCompanion(legalName: Value('Al Noor Labour Supply LLC'), vatRegistered: Value(true), trn: Value('100234567800003')),
    );

    // Two client companies with a site each: one billed by the hour, one by the day.
    final emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
    final marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
    final nakheel = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Nakheel')));
    final palm = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(nakheel), name: const Value('Palm')));
    await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01')));
    await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(nakheel), basis: Value(RateBasis.day.name), rateFils: const Value(12000), effectiveFrom: const Value('2020-01-01')));

    // Mixed pay: by the hour, by the day and by the month.
    final asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif')));
    final bilal = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Bilal')));
    final karim = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W3'), name: Value('Karim')));
    await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(asif), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')));
    await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(bilal), basis: Value(RateBasis.day.name), rateFils: const Value(8000), effectiveFrom: const Value('2020-01-01')));
    await db.saveRow(
      db.payContracts,
      id: null,
      operationId: newUuid(),
      fields: PayContractsCompanion(workerId: Value(karim), basis: Value(RateBasis.month.name), rateFils: const Value(300000), partialMethod: Value(PartialMethod.calendarDays.name), effectiveFrom: const Value('2020-01-01')),
    );

    // Bulk attendance: three at Emaar on the 5th, two at Nakheel on the 6th. A second tap of the same save adds nothing.
    final firstSave = newUuid();
    for (var tap = 0; tap < 2; tap++) {
      await db.saveAttendanceBatch(workDate: '2020-10-05', clientId: emaar, siteId: marina, inputs: [for (final w in [asif, bilal, karim]) EntryInput(workerId: w, shift: _shift)], operationId: firstSave);
    }
    await db.saveAttendanceBatch(workDate: '2020-10-06', clientId: nakheel, siteId: palm, inputs: [for (final w in [asif, bilal]) EntryInput(workerId: w, shift: _shift)], operationId: newUuid());
    expect(await db.select(db.attendanceEntries).get(), hasLength(5));

    // Payroll: 9 h at 10 twice = 180; two days at 80 = 160; a whole month = 3,000.
    Future<Map<String, WorkerPayroll>> payroll(TenantDatabase from) async => {for (final p in await from.payrollFor(_oct)) p.worker.id: p};
    final before = await payroll(db);
    expect({for (final w in [asif, bilal, karim]) w: before[w]!.figures.dueFils}, {asif: 18000, bilal: 16000, karim: 300000});
    expect(await db.postPayroll(_oct, operationId: newUuid()), 3);

    // A part payment: 100 of Asif's 180 leaves 80 owed.
    await db.addSalaryPayment(operationId: newUuid(), date: '2020-11-03', workerId: asif, amountFils: 10000, parts: {_oct: 10000}, extraNote: 'Above salary');
    final asifPay = (await payroll(db))[asif]!;
    expect((asifPay.payableFils, asifPay.paidFils, asifPay.closingFils), (18000, 10000, 8000));
    expect((await db.statementsFor(_oct, workerId: asif)).single.closingFils, 8000);

    // Timesheets and VAT invoices. Emaar: 3 x 9 h x 15 = 405.00, VAT 5% 20.25, total 425.25. Nakheel: 2 x 120 = 240.00, VAT 12.00.
    Future<String> bill(String client, {String from = '2020-10-01', String to = '2020-10-31'}) async {
      final sheet = await db.createTimesheet(clientId: client, from: from, to: to, operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
      final invoice = await db.createInvoice(clientId: client, from: from, to: to, operationId: newUuid());
      await db.issueInvoice(invoice, describe: (l) => invoiceLineText(paperWords, l), operationId: newUuid());
      return invoice;
    }

    final emaarInvoice = await bill(emaar);
    final nakheelInvoice = await bill(nakheel);
    final emaarView = await db.invoiceView(emaarInvoice);
    final nakheelView = await db.invoiceView(nakheelInvoice);
    expect((emaarView.totals.netFils, emaarView.totals.vatFils, emaarView.totals.totalFils), (40500, 2025, 42525));
    expect((nakheelView.totals.netFils, nakheelView.totals.vatFils, nakheelView.totals.totalFils), (24000, 1200, 25200));
    expect(emaarView.invoice.number, matches(RegExp(r'^INV-\d{4}-0001$')));
    expect(nakheelView.invoice.number, matches(RegExp(r'^INV-\d{4}-0002$')));
    // The same work cannot be billed a second time.
    await expectLater(db.createInvoice(clientId: emaar, from: '2020-10-01', to: '2020-10-31', operationId: newUuid()), throwsA(isA<InvoiceRefused>()));

    // A part receipt: 200.00 of 425.25 leaves 225.25, and more than is owed is refused.
    final today = dubaiToday(DateTime.now());
    await db.addClientReceipt(operationId: newUuid(), date: today, clientId: emaar, amountFils: 20000, parts: {emaarInvoice: 20000}, method: 'bank', reference: 'TT 1');
    await expectLater(db.addClientReceipt(operationId: newUuid(), date: today, clientId: emaar, amountFils: 30000, parts: {emaarInvoice: 30000}), throwsA(isA<ReceiptTooHigh>()));
    Future<(int, int, PayState)> owed(TenantDatabase from) async {
      final money = (await from.receivables()).invoices[emaarInvoice]!;
      return (money.receivedFils, money.leftFils, money.state(today));
    }

    expect(await owed(db), (20000, 22525, PayState.partlyPaid));

    // The invoice's paper, stored as it went out.
    final paper = await issueInvoicePaper(db, await db.invoiceView(emaarInvoice));
    expect(String.fromCharCodes(paper.pdfBytes.take(5)), '%PDF-');

    // Backup, with a wrong password told apart from a good one.
    final events = (await db.select(db.auditEvents).get()).length;
    final backup = await db.backupBytes('pass1234', work: oldPhone);
    await db.close();
    final summary = await checkBackup(backup, 'pass1234', tenantId: testTenant, schemaVersion: db.schemaVersion, work: oldPhone);
    expect((summary.companyName, summary.workers, summary.invoices), ('Al Noor Labour Supply LLC', 3, 2));
    await expectLater(
      checkBackup(backup, 'wrong-one', tenantId: testTenant, schemaVersion: db.schemaVersion, work: oldPhone),
      throwsA(isA<BackupRefused>().having((e) => e.problem, 'problem', BackupProblem.wrongPassword)),
    );

    // Restore on a new phone, under that phone's own key. Every figure is as it was.
    final newKey = newHexKey();
    await unlockBackup(backup, 'pass1234', restoringFile(newPhone, testTenant), newKey);
    await swapIn(newPhone, testTenant, keep: false);
    db = open(newPhone, newKey);
    dbs.add(db);
    expect((await db.select(db.auditEvents).get()).length, events);
    final restoredPay = await payroll(db);
    expect((restoredPay[asif]!.closingFils, restoredPay[bilal]!.closingFils, restoredPay[karim]!.closingFils), (8000, 16000, 300000));
    expect(await owed(db), (20000, 22525, PayState.partlyPaid));
    expect((await db.invoiceView(nakheelInvoice)).totals.totalFils, 25200);
    expect((await issueInvoicePaper(db, await db.invoiceView(emaarInvoice))).pdfBytes, paper.pdfBytes, reason: 'the issued paper came back byte for byte');

    // Work goes on, and the next invoice takes the next number.
    await db.saveAttendanceBatch(workDate: '2020-11-02', clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: asif, shift: _shift)], operationId: newUuid());
    final next = await db.invoiceView(await bill(emaar, from: '2020-11-01', to: '2020-11-30'));
    expect(next.invoice.number, matches(RegExp(r'^INV-\d{4}-0003$')));
    expect(next.totals.totalFils, 14175);
  });
}
