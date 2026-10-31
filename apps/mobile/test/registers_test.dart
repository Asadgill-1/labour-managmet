import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/features/registers/register_export.dart';
import 'package:labour_app/features/registers/register_model.dart';
import 'package:labour_app/features/registers/register_pdf.dart';
import 'package:labour_app/features/registers/register_xlsx.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

// Well in the past, so a test never meets the "month has not started" rule.
const sep = '2020-09';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

late String asif;
late String imran;
late String emaar;
late String marina;
late String meraas;
late String pier;
late String room;

Future<void> seed(TenantDatabase db) async {
  Future<String> worker(String name, String code) => db.saveRow(
    db.workers,
    id: null,
    operationId: newUuid(),
    fields: WorkersCompanion(code: Value(code), name: Value(name), trade: const Value('Helper')),
  );
  Future<void> rate(String id, int fils) => db.saveRow(
    db.payContracts,
    id: null,
    operationId: newUuid(),
    fields: PayContractsCompanion(workerId: Value(id), basis: Value(RateBasis.hour.name), rateFils: Value(fils), effectiveFrom: const Value('2020-01-01')),
  );
  Future<({String client, String site})> place(String company, String siteName) async {
    final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: ClientsCompanion(name: Value(company)));
    final site = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(client), name: Value(siteName)));
    await db.saveRow(
      db.billingContracts,
      id: null,
      operationId: newUuid(),
      fields: BillingContractsCompanion(clientId: Value(client), basis: Value(RateBasis.hour.name), rateFils: const Value(1200), effectiveFrom: const Value('2020-01-01')),
    );
    return (client: client, site: site);
  }

  await seedProfile(db);
  asif = await worker('Asif', 'W1');
  imran = await worker('Imran', 'W2');
  await rate(asif, 1000);
  await rate(imran, 800);
  final a = await place('Emaar', 'Marina');
  final b = await place('Meraas', 'Pier');
  emaar = a.client;
  marina = a.site;
  meraas = b.client;
  pier = b.site;
  Future<void> work(String id, ({String client, String site}) at, String date) => db.saveAttendanceBatch(
    workDate: date,
    clientId: at.client,
    siteId: at.site,
    inputs: [EntryInput(workerId: id, shift: shift)],
    operationId: newUuid(),
  );
  await work(asif, a, '2020-09-05');
  await work(imran, a, '2020-09-05');
  await work(asif, b, '2020-09-06');
  await work(imran, b, '2020-10-02');
  await db.approveEntries(await db.unapprovedUpTo('2020-09'), operationId: newUuid());

  room = await db.saveRow(db.rooms, id: null, operationId: newUuid(), fields: const RoomsCompanion(name: Value('Sonapur 12')));
  Future<void> cash(String date, CashKind kind, int fils, {String? worker, String? roomId, String? client}) =>
      db.addCashEntry(operationId: newUuid(), date: date, kind: kind, amountFils: fils, workerId: worker, roomId: roomId, clientId: client);
  await cash('2020-09-01', CashKind.visaPaid, 300000, worker: asif);
  await cash('2020-09-02', CashKind.advanceGiven, 20000, worker: asif);
  await cash('2020-09-03', CashKind.roomRentPaid, 150000, roomId: room);
  await cash('2020-09-04', CashKind.roomRentReceived, 180000, roomId: room);
  await cash('2020-09-07', CashKind.clientReceipt, 500000, client: emaar);
  await cash('2020-10-01', CashKind.expense, 5000);
  await db.saveRow(db.workers, id: asif, operationId: newUuid(), fields: const WorkersCompanion(visaInstalmentFils: Value(10000)));
  await db.applyVisaInstalments(sep, reason: 'Visa', operationId: newUuid());
  await db.savePayItem(
    id: null,
    workerId: asif,
    month: sep,
    kind: PayItemKind.advanceRecovery,
    amountFils: 5000,
    reason: 'Advance',
    authorizedBy: null,
    note: null,
    roomId: null,
    operationId: newUuid(),
  );
  await db.postPayroll(sep, operationId: newUuid());
  await cash('2020-09-30', CashKind.salaryPaid, 1000, worker: asif);
}

int fils(RegisterData d, String label, [Iterable<RegisterEntry>? rows]) => columnTotal(rows ?? d.entries, d.columns.indexWhere((c) => c.label == label));

void main() {
  late TenantDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = memoryDb();
    await seed(db);
    l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
  });

  tearDown(() => db.close());

  Future<RegisterData> build(Section s, {String? from, String? to}) => buildRegister(db, l10n, s, from: from, to: to);

  test('attendance: dated rows, newest first, with date range and several filters', () async {
    final all = await build(Section.attendanceRegister);
    expect(all.entries.map((e) => e.group), ['2020-10-02', '2020-09-06', '2020-09-05', '2020-09-05']);
    expect(all.entries.last.cells[1], 'Imran', reason: 'by name within a date');

    final september = await build(Section.attendanceRegister, from: '2020-09-01', to: '2020-09-30');
    expect(september.entries, hasLength(3));
    expect(september.titleColumn, 1);

    expect(filterEntries(all.entries, {'worker': {asif}}), hasLength(2));
    expect(filterEntries(all.entries, {'worker': {asif, imran}}), hasLength(4), reason: 'any chosen name matches');
    expect(filterEntries(all.entries, {'worker': {asif}, 'client': {meraas}}), hasLength(1), reason: 'every filter must match');
    expect(filterEntries(all.entries, {'site': {pier}}), hasLength(2));
    expect(filterEntries(all.entries, {'site': {marina}}), hasLength(2));
    expect(filterEntries(all.entries, {'state': {'paid'}}), hasLength(3), reason: 'September rows are posted');
    expect(filterEntries(all.entries, {'state': {'submitted'}}), hasLength(1));
    expect(filterEntries(all.entries, {'worker': <String>{}}), hasLength(4), reason: 'an empty filter hides nothing');
  });

  test('a corrected row shows once, as its latest version', () async {
    final row = await (db.select(db.attendanceEntries)..where((e) => e.workDate.equals('2020-10-02'))).getSingle();
    await db.approveEntries([row], operationId: newUuid());
    final approved = await (db.select(db.attendanceEntries)..where((e) => e.id.equals(row.id))).getSingle();
    await db.correctEntry(approved, const EntryInput(workerId: 'x', shift: shift).copyWithWorker(approved.workerId), reason: 'Wrong', operationId: newUuid());
    final data = await build(Section.attendanceRegister, from: '2020-10-01', to: '2020-10-31');
    expect(data.entries, hasLength(1));
    expect(data.entries.single.cells.last, contains(l10n.correctedTag));
  });

  test('money register: in, out and difference add up, and an undone line nets to zero', () async {
    final data = await build(Section.cashRegister);
    expect(fils(data, l10n.moneyIn), 180000 + 500000);
    expect(fils(data, l10n.moneyOut), 300000 + 20000 + 150000 + 5000 + 1000);
    expect(registerDifference(data, data.entries), 680000 - 476000);

    final expense = await (db.select(db.cashEntries)..where((c) => c.kind.equals(CashKind.expense.name))).getSingle();
    await db.reverseCashEntry(expense, reason: 'Mistake', operationId: newUuid());
    final after = await build(Section.cashRegister);
    expect(fils(after, l10n.moneyOut), 300000 + 20000 + 150000 + 1000);
    expect(filterEntries(after.entries, {'kind': {CashKind.expense.name}}), hasLength(2), reason: 'both lines stay on record');
  });

  test('advance and visa registers carry what was left, whatever the date range', () async {
    final advance = await build(Section.advanceRegister);
    expect(advance.entries.map((e) => e.cells[7]), [15000, 20000], reason: 'recovered through pay after being given');
    expect(fils(advance, l10n.colGiven), 20000);
    expect(fils(advance, l10n.colBack), 5000);

    final visa = await build(Section.visaRegister);
    expect(visa.entries.map((e) => e.cells[7]), [290000, 300000]);

    final late = await build(Section.visaRegister, from: '2020-09-02');
    expect(late.entries.single.cells[7], 290000, reason: 'the earlier spend still counts in what is left');
  });

  test('pay register shows posted months with paid and closing, and drops an undone month', () async {
    final data = await build(Section.payrollRegister);
    expect(data.groupKind, CellKind.month);
    final row = data.entries.singleWhere((e) => e.cells[1] == 'Asif');
    expect(row.group, sep);
    final at = {for (var i = 0; i < data.columns.length; i++) data.columns[i].label: row.cells[i]};
    expect(at[l10n.payKindVisa], 10000);
    expect(at[l10n.payKindRecovery], 5000);
    expect(at[l10n.payrollPaid], 1000);
    expect(at[l10n.payrollClosing], (at[l10n.payrollPayable]! as int) - 1000);

    final line = await (db.select(db.payrollLines)..where((l) => l.workerId.equals(asif))).getSingle();
    await db.reversePayrollLine(line, reason: 'Wrong', operationId: newUuid());
    expect((await build(Section.payrollRegister)).entries.where((e) => e.cells[1] == 'Asif'), isEmpty);
  });

  test('room register: rent received and paid per date, with the difference', () async {
    final data = await build(Section.roomRegister);
    expect(fils(data, l10n.rentIn), 180000);
    expect(fils(data, l10n.rentOut), 150000);
    expect(registerDifference(data, data.entries), 30000);
    expect(filterEntries(data.entries, {'room': {room}}), hasLength(2));
  });

  test('company register sums one line per date and site', () async {
    final data = await build(Section.companyRegister);
    expect(data.entries, hasLength(3));
    final day = data.entries.singleWhere((e) => e.group == '2020-09-05');
    expect(day.cells[1], 'Emaar');
    expect(day.cells[3], 2, reason: 'two workers that day');
    expect(day.cells[5], 2 * 9 * 1200);
    expect(day.cells[6], 9 * 1000 + 9 * 800);
    expect(day.cells[7], 2 * 9 * 1200 - (9 * 1000 + 9 * 800));
    expect(day.cells[8], 0);
    expect(data.entries.first.cells[8], 1, reason: 'the October row is not approved');
    expect(filterEntries(data.entries, {'client': {emaar}}), hasLength(1));
  });

  test('worker register has every worker and live balances, and no dates', () async {
    final data = await build(Section.workerRegister);
    expect(data.dated, isFalse);
    expect(data.entries.map((e) => e.cells[1]), ['Asif', 'Imran']);
    final at = {for (var i = 0; i < data.columns.length; i++) data.columns[i].label: data.entries.first.cells[i]};
    expect(at[l10n.advanceOutstanding], 15000);
    expect(at[l10n.visaLeft], 290000);
    expect(at[l10n.filterTrade], 'Helper');
    expect(data.entries.first.group, '');
  });

  group('Excel', () {
    const columns = [
      RegisterColumn('Date', kind: CellKind.date),
      RegisterColumn('Name'),
      RegisterColumn('Hours', kind: CellKind.minutes, total: true),
      RegisterColumn('Pay', kind: CellKind.money, total: true),
      RegisterColumn('Rows', kind: CellKind.number, total: true),
    ];
    const entries = [
      RegisterEntry(['2020-09-05', 'Asif & <Sons> "A"', 540, 110050, 1], group: '2020-09-05'),
      RegisterEntry(['2020-09-06', '=SUM(A1)', 60, -2505, 2], group: '2020-09-06'),
    ];
    Archive unzip() => ZipDecoder().decodeBytes(
      registerXlsx(company: 'Al Noor', title: 'Hazri: register', filterLine: 'Tareekh', columns: columns, entries: entries, totalLabel: 'Total', brandHex: '143E8F'),
    );
    String part(Archive a, String name) => utf8.decode(a.findFile(name)!.content as List<int>);

    test('has values, headings that stay, filters, totals and print settings', () {
      final a = unzip();
      final sheet = part(a, 'xl/worksheets/sheet1.xml');
      expect(sheet, contains('<v>44079</v>'), reason: '5 Sep 2020 is a real date');
      expect(sheet, contains('<v>1100.50</v>'), reason: 'money from whole fils');
      expect(sheet, contains('<v>-25.05</v>'));
      expect(sheet, contains('state="frozen"'));
      expect(sheet, contains('<autoFilter ref="A5:E7"/>'));
      expect(sheet, contains('SUBTOTAL(109,D6:D7)'));
      expect(sheet, contains('<v>1075.45</v>'));
      expect(sheet, contains('orientation="landscape"'));
      expect(sheet, contains('Asif &amp; &lt;Sons&gt; &quot;A&quot;'));
      expect(sheet, contains('t="inlineStr"><is><t xml:space="preserve">=SUM(A1)'), reason: 'typed text never runs as a formula');
      expect(sheet, isNot(contains('<f>SUM(A1)')));
      final book = part(a, 'xl/workbook.xml');
      expect(book, contains('name="Hazri  register"'), reason: 'a sheet name cannot hold a colon');
      expect(book, contains('_xlnm.Print_Titles'));
    });
  });

  group('PDF', () {
    Future<List<int>> pdf(List<RegisterEntry> entries) async {
      final data = await build(Section.attendanceRegister);
      return registerPdf(
        company: 'Al Noor Labour Supply LLC',
        companyLine: 'Dubai',
        title: 'Hazri register',
        filterLine: 'Tareekh: sab',
        columns: data.columns,
        entries: entries,
        totalLabel: 'Total',
        pageLabel: (page, pages) => 'Safha $page / $pages',
        madeLabel: 'Banaya',
        brandArgb: 0xFF143E8F,
        regularFont: File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
        boldFont: File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync(),
      );
    }

    int pages(List<int> bytes) => RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

    test('one short page, then many rows across pages with no blank page at the end', () async {
      final data = await build(Section.attendanceRegister);
      final short = await pdf(data.entries);
      expect(latin1.decode(short.sublist(0, 5)), '%PDF-');
      expect(pages(short), 1);

      final many = [for (var i = 0; i < 400; i++) data.entries[i % data.entries.length]];
      final long = await pdf(many);
      final count = pages(long);
      expect(count, greaterThan(5));
      final oneLess = await pdf(many.sublist(0, many.length - 1));
      expect(pages(oneLess), lessThanOrEqualTo(count));
    });
  });

  test('a file runs oldest date first and keeps each date in screen order', () {
    const a = RegisterEntry(['b1'], group: '2020-09-06');
    const b = RegisterEntry(['a1'], group: '2020-09-05');
    const c = RegisterEntry(['a2'], group: '2020-09-05');
    expect(oldestFirst([a, b, c]), [b, c, a]);
  });

  test('a file name is safe for every app', () {
    expect(exportFileName('Hazri register', '2020-09-01', '2020-09-30', ExportFormat.pdf), 'Hazri-register_2020-09-01_2020-09-30.pdf');
    expect(exportFileName('Mazdoor register', null, null, ExportFormat.excel), 'Mazdoor-register.xlsx');
  });

  testWidgets('a register opens from its sub-tab, filters by name and shows every field', (tester) async {
    await pumpApp(tester, db);
    // The test font is wider than a real one, so chips that fit a phone need more room here.
    tester.view.physicalSize = const Size(2400, 4800);
    await goTo(tester, 'Hazri register');
    await settle(tester);
    expect(find.text('Sab'), findsOneWidget);
    await tester.tap(find.text('Sab'));
    await settle(tester);
    expect(find.text('4 entries'), findsOneWidget);
    expect(find.text('Asif'), findsNWidgets(2));
    expect(find.textContaining('Marina'), findsWidgets);
    expect(find.textContaining('08:00'), findsWidgets);

    await tester.tap(find.text('Mazdoor').first);
    await settle(tester);
    await tester.tap(find.text('Imran (W2)'));
    await tester.pump();
    await tester.tap(find.text('Theek hai'));
    await settle(tester);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('Asif'), findsNothing);
    expect(find.text('Imran'), findsNWidgets(2));

    await tester.tap(find.text('Saaf karein'));
    await settle(tester);
    expect(find.text('4 entries'), findsOneWidget);

    await tester.tap(find.text('PDF, Excel ya WhatsApp'));
    await settle(tester);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Excel'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNWidgets(2));
    await shutDown(tester, db);
  });
}

extension on EntryInput {
  EntryInput copyWithWorker(String id) => EntryInput(workerId: id, shift: shift);
}
