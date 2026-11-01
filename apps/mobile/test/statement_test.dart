import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/documents/document_frame.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/payroll/salary_slip.dart';
import 'package:labour_app/features/registers/register_export.dart';
import 'package:labour_app/features/registers/register_model.dart';
import 'package:labour_app/features/registers/register_pdf.dart';
import 'package:labour_app/features/registers/register_xlsx.dart';
import 'package:labour_app/features/registers/salary_sheet.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const sep = '2020-09';
const oct = '2020-10';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

late String asif;
late String imran;
late String emaar;
late String marina;
late String pier;

ExportText textFor(String title) => ExportText(
  company: 'Test Labour LLC',
  title: title,
  filterLine: '10-2020',
  totalLabel: 'Total',
  madeLabel: 'Made',
  pagePattern: '{page} / {pages}',
  rollupSheet: 'Khulasa',
  clientNames: {emaar: 'Emaar'},
  siteNames: {marina: 'Marina', pier: 'Pier'},
);

Future<void> seed(TenantDatabase db) async {
  await seedProfile(db);
  Future<String> worker(String name, String code) => db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value(code), name: Value(name)));
  asif = await worker('Asif', 'W1');
  imran = await worker('Imran', 'W2');
  emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
  pier = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Pier')));
  await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(asif), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')));
  await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(imran), basis: Value(RateBasis.month.name), rateFils: const Value(200000), effectiveFrom: const Value('2020-09-01')));
  await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01')));

  Future<void> work(String id, String date, String site) => db.saveAttendanceBatch(workDate: date, clientId: emaar, siteId: site, inputs: [EntryInput(workerId: id, shift: shift)], operationId: newUuid());
  Future<void> cash(String date, CashKind kind, int fils, String id) => db.addCashEntry(operationId: newUuid(), date: date, kind: kind, amountFils: fils, workerId: id);

  await work(asif, '2020-09-10', marina);
  await work(asif, '2020-10-05', marina);
  await work(asif, '2020-10-06', pier);
  await work(imran, '2020-10-05', marina);
  await cash('2020-09-15', CashKind.visaPaid, 300000, asif);
  await cash('2020-10-08', CashKind.advanceGiven, 2000, asif);
  // September's 90 is paid early in October, so it belongs on September's slip.
  await cash('2020-10-02', CashKind.salaryPaid, 9000, asif);
  // October is paid part of it in November.
  await cash('2020-11-03', CashKind.salaryPaid, 5000, asif);
  await db.savePayItem(id: null, workerId: asif, month: oct, kind: PayItemKind.visaRecovery, amountFils: 3000, reason: 'Visa', authorizedBy: null, note: null, roomId: null, operationId: newUuid());
  await db.savePayItem(id: null, workerId: asif, month: oct, kind: PayItemKind.deduction, amountFils: 500, reason: 'Broken helmet', authorizedBy: 'Asif', note: null, roomId: null, operationId: newUuid());
  await db.applyRoomCharges(oct, charges: {asif: 1000}, reason: 'Room', ownerApproved: 'Owner', operationId: newUuid());
  await db.addCashEntry(operationId: newUuid(), date: '2020-10-11', kind: CashKind.expense, amountFils: 700);
}

void main() {
  late TenantDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = memoryDb();
    await seed(db);
    l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
  });

  tearDown(() => db.close());

  Future<WorkerStatement> statementOf(String id, String month) async => (await db.statementsFor(month, workerId: id)).single;

  group('a worker\'s month', () {
    test('adds up the way the slip reads it, and each closing is the next opening', () async {
      final september = await statementOf(asif, sep);
      expect(september.workFils, 9000);
      expect(september.paidFils, 9000, reason: 'paid on 2 October, for September');
      expect(september.closingFils, 0);

      final october = await statementOf(asif, oct);
      expect(october.openingFils, 0);
      expect(october.workFils, 18000);
      expect(october.advanceFils, 2000);
      expect(october.roomFils, 1000);
      expect(october.visaFils, 3000);
      expect(october.otherFils, 500);
      expect(october.paidFils, 5000, reason: 'paid on 3 November, for October');
      expect(october.closingFils, 18000 - 2000 - 1000 - 3000 - 500 - 5000);
    });

    test('visa money counts as it is cut from pay, and what is left shows apart from the balance', () async {
      final september = await statementOf(asif, sep);
      expect(september.visaFils, 0);
      expect(september.visaLeftFils, 300000);
      final october = await statementOf(asif, oct);
      expect(october.visaFils, 3000);
      expect(october.visaLeftFils, 297000);
    });

    test('money rows come date by date, and add up to what was taken', () async {
      final october = await statementOf(asif, oct);
      expect(october.money.map((m) => m.date).toList(), ['2020-10-08', '2020-10-31', '2020-10-31', '2020-10-31', '2020-11-03']);
      expect(october.money.map((m) => m.kind).first, StatementMoneyKind.advance);
      expect(october.money.fold(0, (total, m) => total + m.fils), october.takenFils);
    });

    test('a mistake undone in the cash book leaves nothing on the slip', () async {
      final mistake = newUuid();
      await db.addCashEntry(operationId: mistake, date: '2020-10-20', kind: CashKind.advanceGiven, amountFils: 99900, workerId: asif);
      final row = (await db.select(db.cashEntries).get()).singleWhere((c) => c.amountFils == 99900);
      await db.reverseCashEntry(row, reason: 'Wrong worker', operationId: newUuid());
      final october = await statementOf(asif, oct);
      expect(october.advanceFils, 2000);
      expect(october.money.where((m) => m.fils.abs() == 99900), isEmpty);
    });

    test('a monthly salary counts before posting, the same after it, and only once', () async {
      await db.saveAttendanceBatch(workDate: '2020-09-20', clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: imran, shift: shift)], operationId: newUuid());
      final before = await statementOf(imran, oct);
      expect(before.salaryFils, 200000);
      expect(before.openingFils, 200000, reason: "September's salary, not posted and not paid");
      await db.postPayroll(sep, operationId: newUuid());
      await db.postPayroll(oct, operationId: newUuid());
      final after = await statementOf(imran, oct);
      expect(after.salaryFils, 200000);
      expect(after.openingFils, 200000);
      expect(after.closingFils, before.closingFils);
    });

    test('a contract dated from long ago does not run up pay from before the account started', () async {
      await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(imran), basis: Value(RateBasis.month.name), rateFils: const Value(100), effectiveFrom: const Value('2015-01-01'), effectiveTo: const Value('2020-08-31')));
      final october = await statementOf(imran, oct);
      expect(october.openingFils, 0, reason: 'nothing happened on this account before October');
      expect(october.salaryFils, 200000);
    });

    test('the balance is pay owed plus anything not posted, less the advance not yet cut, as on the Tankhwah screen', () async {
      await db.postPayroll(sep, operationId: newUuid());
      await db.postPayroll(oct, operationId: newUuid());
      final october = await statementOf(asif, oct);
      final line = (await db.payrollFor(oct)).singleWhere((p) => p.worker.id == asif);
      expect(october.closingFils, line.closingFils - await db.advanceLeft(asif));
    });

    test('opening money from before this app is old balance, never this month', () async {
      await db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(workerId: Value(imran), kind: const Value('worker_salary_owed'), amountFils: const Value(50000), asOfDate: const Value('2020-09-01'), sourceNote: const Value('Old book')));
      final september = await statementOf(imran, sep);
      expect(september.openingFils, 50000);
      expect(september.earnedFils, 200000);
    });
  });

  group('salary slip', () {
    test('never says what a company pays, and tells a worker plainly what they get (D-042)', () async {
      final slip = slipContent(await statementOf(asif, oct), l10n, textFor(l10n.slipTitle));
      final everything = [
        ...slip.summary.expand((l) => [l.$1, l.$2]),
        ...slip.days.headings,
        ...slip.days.rows.expand((r) => r),
        ...slip.days.total,
        ...slip.money.rows.expand((r) => r),
        ...slip.notes,
      ].join(' ');
      expect(everything, isNot(contains(RegExp(r'(?<![\d,])15\.00'))), reason: "the company's rate");
      expect(everything, isNot(contains(RegExp(r'(?<![\d,])135\.00'))), reason: "a day's bill");
      expect(everything, isNot(contains(l10n.colBill)));
      expect(everything, isNot(contains(l10n.colProfit)));
      expect(slip.days.rows.first, ['05-10-2020', 'Emaar', 'Marina', l10n.statusPresent, '9:00', '10.00 ${l10n.basisHour}', '90.00']);
      expect(slip.days.total.last, '180.00');
      expect(slip.closingLabel, l10n.slipOwedToYou);
      expect(slip.closingAmount, 'AED 65.00');
      expect(slip.money.rows.first, ['08-10-2020', l10n.kindAdvanceGiven, '', '20.00']);
      expect(slip.notes.first, contains('AED 2,970.00'));
    });

    test('someone who owes is told so, and an empty month says it has nothing', () async {
      final slip = slipContent(await statementOf(imran, sep), l10n, textFor(l10n.slipTitle));
      expect(slip.money.rows, isEmpty);
      expect(slip.days.rows, isEmpty);
      await db.addCashEntry(operationId: newUuid(), date: '2020-09-20', kind: CashKind.advanceGiven, amountFils: 300000, workerId: imran);
      final owes = slipContent(await statementOf(imran, sep), l10n, textFor(l10n.slipTitle));
      expect(owes.closingLabel, l10n.slipYouOwe);
      expect(owes.closingAmount, 'AED 1,000.00');
    });

    test('prints as real text on an upright page, and a long month breaks across pages', () async {
      final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
      final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
      final inputs = [for (var d = 1; d <= 31; d++) (d, d)];
      for (final (d, _) in inputs) {
        await db.saveAttendanceBatch(workDate: '2020-12-${d.toString().padLeft(2, '0')}', clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: asif, shift: shift), EntryInput(workerId: asif, shift: const ShiftInput(startMinute: 19 * 60, endMinute: 23 * 60))], operationId: newUuid());
      }
      final slip = slipContent(await statementOf(asif, '2020-12'), l10n, textFor(l10n.slipTitle));
      expect(slip.days.rows, hasLength(62));
      final bytes = await slipPdf(slip, const DocumentIdentity(legalName: 'Test'), const DocumentMeta(title: 'Slip', pagePattern: '{page}/{pages}', madeLabel: 'Made'), regularFont: regular, boldFont: bold);
      final raw = latin1.decode(bytes);
      expect(raw.substring(0, 5), '%PDF-');
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(1));
    });
  });

  group("owner's sheet", () {
    Map<String, Object?> at(List<RegisterColumn> columns, RegisterEntry e) => {for (var i = 0; i < columns.length; i++) columns[i].label: e.cells[i]};

    test('shows each company with its rates, bill, pay and profit, and every line adds up', () async {
      final sheet = await buildSalarySheet(db, l10n, oct);
      expect(groupEntries(sheet.entries).map((g) => g.group), ['Emaar']);
      final lines = [for (final e in sheet.entries) at(sheet.columns, e)];
      expect(lines.map((l) => l[l10n.colSite]), ['Marina', 'Marina', 'Pier']);
      final asifMarina = lines.first;
      expect(asifMarina[l10n.colWorker], 'Asif');
      expect(asifMarina[l10n.colCompanyRate], 'AED 15.00, ${l10n.basisHour}');
      expect(asifMarina[l10n.colWorkerRate], 'AED 10.00, ${l10n.basisHour}');
      expect(asifMarina[l10n.colDays], 1);
      expect(asifMarina[l10n.colBill], 13500);
      expect(asifMarina[l10n.colPay], 9000);
      expect(asifMarina[l10n.colProfit], 4500);
      for (final l in lines) {
        expect((l[l10n.colBill]! as int) - (l[l10n.colPay]! as int), l[l10n.colProfit]);
      }
    });

    test('the month in short adds up to the estimate, and keeps monthly pay outside the companies (REP-03)', () async {
      final sheet = await buildSalarySheet(db, l10n, oct);
      final [summary, byCompany, workers] = sheet.rollupsOf!(sheet.entries);
      final figures = {for (final r in summary.rows) r.cells[0]: r.cells[1]};
      expect(figures[l10n.sheetBill], 3 * 13500);
      expect(figures[l10n.sheetWages], -18000, reason: 'Imran is monthly, so no wage on the row');
      expect(figures[l10n.sheetSalaries], -200000);
      expect(figures[l10n.sheetCuts], 500);
      expect(figures[l10n.sheetRoomIn], 1000);
      expect(figures[l10n.sheetExpenses], -700);
      expect(summary.totalLabel, l10n.sheetEstimate);
      expect(columnTotal(summary.rows, 1), 40500 - 18000 - 200000 + 500 + 1000 - 700);

      expect(byCompany.rows.single.cells.first, 'Emaar');
      expect(byCompany.rows.single.cells[4], 40500);

      final accounts = {for (final r in workers.rows) r.cells[0]: at(workers.columns, r)};
      final account = accounts['Asif']!;
      expect(account[l10n.slipOpening], 0);
      expect(account[l10n.colEarned], 18000);
      expect(account[l10n.slipAdvance], 2000);
      expect(account[l10n.slipRoom], 1000);
      expect(account[l10n.slipVisa], 3000);
      expect(account[l10n.slipOther], 500);
      expect(account[l10n.colPaid], 5000);
      expect(account[l10n.colBalance], 6500);
      expect(account[l10n.colVisaLeft], 297000);
      expect(workers.sheet, l10n.sheetWorkers);
      expect(workers.afterRows, isTrue);
    });

    test('a company with no rate yet shows the wage against nothing, flagged, so the sum still reads true', () async {
      final other = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('ATE')));
      final site = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(other), name: const Value('Melboard')));
      await db.saveAttendanceBatch(workDate: '2020-10-07', clientId: other, siteId: site, inputs: [EntryInput(workerId: asif, shift: shift)], operationId: newUuid());
      final sheet = await buildSalarySheet(db, l10n, oct);
      final line = at(sheet.columns, sheet.entries.first);
      expect(line[l10n.colCompany], 'ATE');
      expect(line[l10n.colCompanyRate], l10n.issueNoRate);
      expect(line[l10n.colProfit], -9000);
      final byCompany = sheet.rollupsOf!(sheet.entries)[1];
      expect(byCompany.rows.first.cells.last, 1);
    });

    test('in Excel the sums come first, then the companies, then the workers on a sheet with its own filter', () async {
      final sheet = await buildSalarySheet(db, l10n, oct);
      final bytes = registerXlsx(
        company: 'Test',
        title: sheet.title,
        filterLine: '10-2020',
        columns: sheet.columns,
        entries: sheet.entries,
        totalLabel: 'Total',
        brandHex: '1F3A8A',
        softHex: 'E0EEFF',
        note: sheet.note,
        rollups: sheet.rollupsOf!(sheet.entries),
        rollupSheet: l10n.regSummarySheet,
        mainSheet: sheet.mainSheet,
        summaryFirst: sheet.summaryFirst,
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      String part(String name) => utf8.decode(zip.findFile(name)!.content as List<int>);
      final workbook = part('xl/workbook.xml');
      final names = RegExp(r'<sheet name="([^"]+)"').allMatches(workbook).map((m) => m[1]).toList();
      expect(names, [l10n.regSummarySheet, l10n.sheetDetail, l10n.sheetWorkers]);
      expect(part('xl/worksheets/sheet1.xml'), contains(l10n.sheetEstimate));
      expect(part('xl/worksheets/sheet1.xml'), isNot(contains('autoFilter')));
      expect(part('xl/worksheets/sheet2.xml'), contains('autoFilter'));
      expect(part('xl/worksheets/sheet3.xml'), contains('autoFilter'));
      expect(workbook, contains('localSheetId="1"'));
      expect(workbook, contains('localSheetId="2"'));
      expect(workbook, isNot(contains('localSheetId="0"')));
    });

    test('prints a band per company and the workers after them, as text', () async {
      final sheet = await buildSalarySheet(db, l10n, oct);
      final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
      final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
      final bytes = await registerPdf(
        identity: const DocumentIdentity(legalName: 'Test', contactLine: ''),
        meta: DocumentMeta(title: sheet.title, subtitle: '10-2020', pagePattern: 'Safha {page} / {pages}', madeLabel: 'Banaya'),
        columns: sheet.columns,
        entries: sheet.entries,
        totalLabel: 'Total',
        regularFont: regular,
        boldFont: bold,
        rollups: sheet.rollupsOf!(sheet.entries),
        groupHeads: sheet.groupHeads,
        sections: true,
      );
      expect(latin1.decode(bytes).substring(0, 5), '%PDF-');
    });
  });

  test('a long register is cut into slices, and still has every row and page', () async {
    final columns = [const RegisterColumn('Worker'), const RegisterColumn('Pay', kind: CellKind.money, total: true)];
    final entries = [for (var i = 0; i < 1500; i++) RegisterEntry(['Worker $i', 1000])];
    final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
    final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();
    final watch = Stopwatch()..start();
    final bytes = await registerPdf(
      identity: const DocumentIdentity(legalName: 'Test', contactLine: ''),
      meta: DocumentMeta(title: 'Long', subtitle: '', pagePattern: 'Safha {page} / {pages}', madeLabel: 'Banaya'),
        columns: columns,
      entries: entries,
      totalLabel: 'Total',
      regularFont: regular,
      boldFont: bold,
    );
    expect(watch.elapsed.inSeconds, lessThan(30), reason: 'one big table took 11 seconds at 1,300 rows of a wider register, and grew with the square');
    final pages = RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;
    expect(pages, greaterThanOrEqualTo(1500 ~/ 45));
  });
}
