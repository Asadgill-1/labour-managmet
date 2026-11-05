import 'dart:convert';

import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/csv.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show AxisDirection, BackButton, Locale, Scrollable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/import.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/receipts.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/features/registers/register_model.dart';
import 'package:labour_app/features/registers/salary_sheet.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';
import 'timesheets_test.dart' as ts;

void main() {
  late TenantDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = memoryDb();
    await ts.seed(db);
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => db.close());

  Future<String> issued({String? site}) async {
    final sheet = await db.createTimesheet(clientId: ts.emaar, siteId: site, from: ts.from, to: ts.to, operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
    final id = await db.createInvoice(clientId: ts.emaar, siteId: site, from: ts.from, to: ts.to, operationId: newUuid());
    await db.issueInvoice(id, describe: (l) => 'Manpower', operationId: newUuid());
    return id;
  }

  group('CSV import (MASTER-08)', () {
    Future<List<Worker>> workers() => db.select(db.workers).get();
    // Records holding lists compare by identity, so each line is written out: its row, then its problems.
    List<String> problems(ImportPlan plan) => [
      for (final l in plan.lines) [l.row, for (final i in l.issues) i.problem.name].join(' '),
    ];

    test('workers come in with their pay rate after a preview, and a name already there is only a warning', () async {
      const file =
          'Code,Name,Trade,Phone,Joining date,Pay basis,Pay rate,Rate from\r\n'
          'W10,Rashid,Mason,0501112222,01/11/2026,day,120,\r\n'
          'W11,Asif,Helper,,,Hourly,"AED 1,000.50",05/11/2026\r\n';
      final plan = await db.planImport(ImportKind.workers, file);
      expect(await workers(), hasLength(2), reason: 'a preview writes nothing');
      expect(problems(plan), ['2', '3 sameName']);
      expect([for (final l in plan.lines) l.read.join(', ')], ['Mason, 0501112222, Joining date 01-11-2026', 'Helper, Rate from 05-11-2026']);
      expect(plan.lines.last.rate, (basis: RateBasis.hour, fils: 100050));
      expect(plan.ready, isTrue);

      expect(await db.applyImport(plan), 2);
      final rashid = (await workers()).singleWhere((w) => w.code == 'W10');
      expect((rashid.name, rashid.trade, rashid.phone, rashid.joiningDate), ('Rashid', 'Mason', '0501112222', '2026-11-01'));
      final rates = {
        for (final c in await db.select(db.payContracts).get())
          if (c.workerId != ts.asif && c.workerId != ts.bilal) (await workers()).singleWhere((w) => w.id == c.workerId).code: (c.basis, c.rateFils, c.effectiveFrom),
      };
      expect(rates, {'W10': (RateBasis.day.name, 12000, '2026-11-01'), 'W11': (RateBasis.hour.name, 100050, '2026-11-05')});

      final again = await db.planImport(ImportKind.workers, file);
      expect(again.ready, isFalse, reason: 'the same file twice is refused, so a retry adds nothing');
      expect(problems(again), ['2 exists sameName', '3 exists sameName']);
    });

    test('every mistake is named by row and column, and then nothing at all is saved', () async {
      const file =
          'Code;Name;Pay basis;Pay rate;Extra\n'
          'W1;Someone;;;x\n'
          'W12;;month;100;\n'
          '\n'
          'W13;Ok;day;;\n'
          'W14;Again;;12.345;\n'
          'w14;Twice;;;\n';
      final plan = await db.planImport(ImportKind.workers, file);
      expect(plan.ignoredColumns, ['Extra']);
      expect(problems(plan), ['2 exists', '3 missing monthlyBasis rateNeedsDate', '5 rateAndBasis rateNeedsDate', '6 badAmount rateAndBasis', '7 repeated']);
      expect(plan.lines[1].issues.first.field, ImportField.name);
      expect(plan.ready, isFalse);
      await expectLater(db.applyImport(plan), throwsStateError);
      expect(await workers(), hasLength(2));
    });

    test('a file missing a needed column, or with nothing under its headings, is not ready', () async {
      final noCode = await db.planImport(ImportKind.workers, 'Name\nRashid\n');
      expect((noCode.missingColumns.single, noCode.ready), (ImportField.code, false));
      final blank = await db.planImport(ImportKind.workers, importTemplate(ImportKind.workers));
      expect((blank.lines.length, blank.ready), (0, false));
      expect(parseCsv(importTemplate(ImportKind.sites)).single.fields, ['Company', 'Site', 'Location', 'Contact', 'Start', 'End', 'Break minutes']);
    });

    test('if saving fails part way, the lines already written are taken back', () async {
      final plan = await db.planImport(ImportKind.workers, 'Code,Name\nW20,First\nW21,Second\n');
      expect(plan.ready, isTrue);
      // Someone else takes W21 between the preview and the save.
      await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W21'), name: Value('Other')));
      await expectLater(db.applyImport(plan), throwsA(anything));
      expect((await workers()).map((w) => w.code), unorderedEquals(['W1', 'W2', 'W21']), reason: 'W20 went back with the failure');
    });

    test('companies keep a TRN only when registered for VAT, and sites find their company by name', () async {
      const companies =
          'Name,VAT registered,TRN,Due days\n'
          'Nakheel,yes,100555444300003,30\n'
          'Dubai Holding,no,123,\n'
          'Meraas,yes,,\n'
          'emaar ,,,\n';
      final first = await db.planImport(ImportKind.companies, companies);
      expect(problems(first), ['2', '3 trnWithoutVat', '4 missing', '5 exists']);
      final plan = await db.planImport(ImportKind.companies, companies.split('\n').take(3).join('\n'));
      expect(plan.ready, isTrue);
      await db.applyImport(plan);
      final saved = {for (final c in await db.select(db.clients).get()) c.name: (c.vatRegistered, c.trn, c.dueDays)};
      expect(saved['Nakheel'], (true, '100555444300003', 30));
      expect(saved['Dubai Holding'], (false, null, null));

      const sites =
          'Company,Site,Start,End,Break minutes\n'
          'Nakheel,Palm,07:00,16:00,60\n'
          'nakheel ,Palm,,,\n'
          'Nobody,X,,,\n'
          'Emaar,Marina,,,\n'
          'Emaar,Pier,8:00,,\n';
      expect(problems(await db.planImport(ImportKind.sites, sites)), ['2', '3 repeated', '4 noCompany', '5 exists', '6 missing']);
      await db.applyImport(await db.planImport(ImportKind.sites, sites.split('\n').take(2).join('\n')));
      final palm = await (db.select(db.sites)..where((s) => s.name.equals('Palm'))).getSingle();
      expect((palm.defaultStartMinute, palm.defaultEndMinute, palm.defaultBreakMinutes), (420, 960, 60));
    });
  });

  test('what companies owe, by how late, as of today, with credit left under each company (REP-01)', () async {
    final today = dubaiToday(DateTime.now());
    final nakheel = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Nakheel')));
    Future<void> opening(String client, int days, int fils) => db.saveRow(
      db.openingBalances,
      id: null,
      operationId: newUuid(),
      fields: OpeningBalancesCompanion(kind: const Value('client_receivable'), clientId: Value(client), amountFils: Value(fils), asOfDate: Value(addDays(today, -days)), sourceNote: const Value('Old ledger')),
    );
    await opening(ts.emaar, 100, 50000);
    await opening(nakheel, 10, 20000);
    await ts.work(db, '2020-10-05');
    final invoice = await issued();
    await db.addClientReceipt(operationId: newUuid(), date: today, clientId: ts.emaar, amountFils: 1000, parts: const {});

    final data = await buildRegister(db, l10n, Section.agingRegister);
    expect(data.dated, isFalse);
    expect(data.note, contains(showDate(today)));
    expect([for (final e in data.entries) (e.group, e.cells[1], e.cells[5], e.cells[6], e.cells[7])], [
      ('Emaar', l10n.receiptOldBalance, l10n.ageOver90, 50000, 50000),
      ('Emaar', (await db.invoiceView(invoice)).invoice.number, l10n.ageNotDue, null, 13500),
      ('Nakheel', l10n.receiptOldBalance, l10n.ageDays('1-30'), 20000, 20000),
    ]);
    expect(data.groupFeet['Emaar'], l10n.regUnusedCredit('AED 10.00'));
    final byAge = data.rollupsOf!(data.entries).single;
    expect([for (final r in byAge.rows) r.cells], [
      ['Emaar', 13500, 0, 0, 0, 50000, 63500],
      ['Nakheel', 0, 20000, 0, 0, 0, 20000],
    ]);
    final late = filterEntries(data.entries, {
      'age': {'over90'},
    });
    expect(late.single.cells[7], 50000);
  });

  test('work by company, site and month: invoiced, still to bill, and work with no company rate (REP-01)', () async {
    final ate = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('ATE')));
    final melboard = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(ate), name: const Value('Melboard')));
    await ts.work(db, '2020-10-05');
    await ts.work(db, '2020-10-06', site: ts.creek);
    await db.saveAttendanceBatch(workDate: '2020-10-07', clientId: ate, siteId: melboard, inputs: [EntryInput(workerId: ts.bilal, shift: ts.shift)], operationId: newUuid());
    await issued(site: ts.marina);

    final data = await buildRegister(db, l10n, Section.workRegister, from: ts.from, to: ts.to);
    expect([for (final e in data.entries) (e.group, e.cells[2], e.cells[3], e.cells[5], e.cells[6], e.cells[7], e.cells[8], e.cells[9])], [
      ('ATE', 'Melboard', 1, 0, null, null, null, 1),
      ('Emaar', 'Creek', 1, 13500, null, 13500, 1, null),
      ('Emaar', 'Marina', 1, 13500, 13500, null, null, null),
    ]);
    final open = filterEntries(data.entries, {
      'billed': {'open'},
    });
    expect(open.map((e) => e.cells[2]), ['Melboard', 'Creek']);
    expect(await db.uninvoicedWork(to: ts.to), {(ts.emaar, '2020-10')}, reason: 'closing reads the same rows');
    expect((await buildRegister(db, l10n, Section.workRegister, from: '2020-11-01', to: '2020-11-30')).entries, isEmpty);
  });

  testWidgets('the Reports tab names every report with the date it goes by, and a CSV file chosen on Labour is checked, then saved (REP-01, MASTER-08)', (tester) async {
    final app = memoryDb();
    await real(tester, () => ts.seed(app));
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    const channel = MethodChannel('labour_app/files');
    var file = 'Code,Name\nW1,Again\n';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async => call.method == 'pickCsv' ? Uint8List.fromList(utf8.encode(file)) : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await pumpApp(tester, app);

    await goTo(tester, words.reportsTab);
    for (final what in [words.repAttendance, words.repWork, words.repAging, words.repInvoices, words.repReceipts, words.repStatement, words.repWorkers, words.repPayroll, words.repAdvance, words.repExpenses, words.repMargin]) {
      await tester.scrollUntilVisible(find.text(what), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
      expect(find.text(what), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text(words.repReceipts), -200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.tap(find.text(words.repReceipts));
    await settle(tester);
    expect(find.text('${words.filterKind} (1)'), findsOneWidget, reason: 'opens the cash register showing company receipts only');
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text(words.repAging));
    await settle(tester);
    expect(find.textContaining(showDate(dubaiToday(DateTime.now()))), findsOneWidget, reason: 'says the date it is as of');

    await goTo(tester, words.tabLabour);
    await tester.tap(find.bySemanticsLabel(words.importCsv));
    await settle(tester);
    await tester.tap(find.text(words.importChoose));
    await settle(tester);
    expect(find.text(words.problemExists('Code')), findsOneWidget);
    expect(find.text(words.importFix), findsOneWidget);
    file = 'Code,Name\nW30,Sajid\n';
    await tester.tap(find.text(words.importChooseAgain).last);
    await settle(tester);
    await tester.tap(find.text(words.importSave(1)));
    await settle(tester);
    expect(find.text('Sajid'), findsOneWidget, reason: 'back on the list, saved');
    await shutDown(tester, app);
  });

  test("the owner's sheet keeps VAT out of the bill, advances out of wages and receipts out of revenue, and room in and out apart (REP-02, REP-03, REP-07)", () async {
    final profile = await db.select(db.tenantProfiles).getSingle();
    await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(vatRegistered: Value(true), trn: Value('100000000000003')));
    final room = await db.saveRow(db.rooms, id: null, operationId: newUuid(), fields: const RoomsCompanion(name: Value('Room 1')));
    await ts.work(db, '2020-10-05');
    final invoice = await issued();
    final total = (await db.receivables()).invoices[invoice]!.totalFils;
    expect(total, 13500 + 675, reason: 'the invoice carries 5% VAT');
    await db.addClientReceipt(operationId: newUuid(), date: '2020-10-20', clientId: ts.emaar, amountFils: total, parts: {invoice: total});
    await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: ts.asif);
    await db.addCashEntry(operationId: newUuid(), date: '2020-10-09', kind: CashKind.roomRentReceived, amountFils: 1000, workerId: ts.asif, roomId: room);
    await db.addCashEntry(operationId: newUuid(), date: '2020-10-10', kind: CashKind.roomRentPaid, amountFils: 5000, roomId: room);

    final sheet = await buildSalarySheet(db, l10n, '2020-10');
    final [contribution, summary, ..._] = sheet.rollupsOf!(sheet.entries);
    final work = {for (final r in contribution.rows) r.cells[0]: r.cells[1]};
    expect(work, {l10n.sheetBill: 13500, l10n.sheetWages: -9000});
    final figures = {for (final r in summary.rows) r.cells[0]: r.cells[1]};
    expect(figures[l10n.sheetContribution], 4500);
    expect(figures[l10n.sheetRoomIn], 1000);
    expect(figures[l10n.sheetRoomOut], -5000);
    expect(columnTotal(summary.rows, 1), 4500 + 1000 - 5000, reason: 'no receipt, no VAT and no advance in the estimate');
    final words = [contribution.title, contribution.totalLabel, summary.title, summary.totalLabel, ...figures.keys].join(' ').toLowerCase();
    expect(words, isNot(contains('net profit')));
    expect(summary.totalLabel, contains('not audited'));
  });
}
