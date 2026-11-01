import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
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
    expect(day.cells[8], 0, reason: 'every row here has a company rate');
    expect(filterEntries(data.entries, {'client': {emaar}}), hasLength(1));
  });

  group('worker register', () {
    Map<String, Object?> at(RegisterData d, RegisterEntry e) => {for (var i = 0; i < d.columns.length; i++) d.columns[i].label: e.cells[i]};
    List<Map<String, Object?>> rowsOf(RegisterData d, String name) => [for (final e in d.entries.where((e) => e.cells[1] == name)) at(d, e)];

    test('is one account per worker, date by date, with where they worked, the rate, the sums and what is left', () async {
      final data = await build(Section.workerRegister);
      expect(data.dated, isTrue);
      expect(data.groupsByName, isTrue);
      expect(groupEntries(data.entries).map((g) => g.group), ['Asif (W1)', 'Imran (W2)']);

      final asifRows = rowsOf(data, 'Asif');
      expect(asifRows.map((r) => r[l10n.colDate]), ['2020-09-01', '2020-09-02', '2020-09-05', '2020-09-06', '2020-09-30', '2020-09-30', '2020-09-30'], reason: 'oldest first');

      final worked = asifRows[2];
      expect(worked[l10n.colCompany], 'Emaar');
      expect(worked[l10n.colSite], 'Marina');
      expect(worked[l10n.colIn], '08:00');
      expect(worked[l10n.colOut], '18:00');
      expect(worked[l10n.colHours], 9 * 60);
      expect(worked[l10n.colRate], 'AED 10.00, ${l10n.basisHour}');
      expect(worked[l10n.colEarned], 9000);

      // Visa money the company spends moves nothing yet. The advance of 200 goes out first, then two days' work bring it up.
      expect(asifRows[0][l10n.colBalance], 0);
      expect(asifRows[0][l10n.note], contains('AED 3,000.00'));
      expect(asifRows[1][l10n.colBalance], -20000);
      expect(worked[l10n.colBalance], -11000);
      expect(asifRows[3][l10n.colBalance], -2000);

      // The visa instalment counts as it is cut from pay (D-042).
      final instalment = asifRows.where((r) => r[l10n.colWhat] == l10n.payKindVisa).single;
      expect(instalment[l10n.payKindDeduction], 10000);
      expect(instalment[l10n.colBalance], -12000);

      // Taking an advance back through pay moves nothing, because it counted when it was given.
      final recovered = asifRows.where((r) => r[l10n.colWhat] == l10n.payKindRecovery).single;
      expect(recovered[l10n.colBalance], -12000);
      expect(recovered[l10n.note], contains('AED 50.00'));
      expect(asifRows.last[l10n.colWhat], l10n.kindSalaryPaid);
      expect(asifRows.last[l10n.colPaid], 1000);
      expect(asifRows.last[l10n.colBalance], -13000);

      final column = data.columns.indexWhere((c) => c.label == l10n.colBalance);
      final asifGroup = groupEntries(data.entries).first.rows;
      expect(columnFigure(data.columns, asifGroup, column), -13000);
      expect(columnFigure(data.columns, data.entries, column), -13000 + 7200 + 7200, reason: 'where each worker ended, added up');
      expect(data.groupHeads['Asif (W1)'], contains('Helper'));
      expect(data.groupFeet['Asif (W1)'], contains(l10n.regOwedByWorker('AED 130.00')));
      expect(data.groupFeet['Asif (W1)'], contains(l10n.regOwedSplit('AED 20.00', 'AED 150.00')));
      expect(data.groupFeet['Asif (W1)'], contains(l10n.regVisaLeft('AED 2,900.00')));
      expect(data.groupFeet['Imran (W2)'], l10n.regOwedToWorker('AED 144.00'));
    });

    test('balance always equals pay owed plus work not posted, less the advance not yet cut (REP-08)', () async {
      final data = await build(Section.workerRegister);
      final months = await db.payrollFor('2020-10');
      for (final (id, label) in [(asif, 'Asif (W1)'), (imran, 'Imran (W2)')]) {
        final left = groupEntries(data.entries).singleWhere((g) => g.group == label).rows.last.cells[data.columns.indexWhere((c) => c.label == l10n.colBalance)]! as int;
        // Someone with nothing new in October stands where September left them.
        final owed = months.where((p) => p.worker.id == id).firstOrNull?.payableFils ?? (await db.payrollFor(sep)).singleWhere((p) => p.worker.id == id).closingFils;
        expect(left, owed - await db.advanceLeft(id), reason: label);
      }
    });

    test('a date range brings the balance forward, and keeps a worker who owes with nothing in the range', () async {
      final data = await build(Section.workerRegister, from: '2020-10-01', to: '2020-10-31');
      final asifRows = rowsOf(data, 'Asif');
      expect(asifRows.single[l10n.colWhat], l10n.regBrought);
      expect(asifRows.single[l10n.colBalance], -13000);
      expect(asifRows.single[l10n.colEarned], isNull);

      final imranRows = rowsOf(data, 'Imran');
      expect(imranRows.first[l10n.colWhat], l10n.regBrought);
      expect(imranRows.last[l10n.colEarned], 7200);
      expect(imranRows.last[l10n.colBalance], 14400);

      final before = await build(Section.workerRegister, from: '2020-01-01', to: '2020-01-31');
      expect(before.entries, isEmpty, reason: 'nothing yet, and nothing owed');
    });

    test('filters keep whole accounts, and the sums follow them', () async {
      final data = await build(Section.workerRegister);
      final one = filterEntries(data.entries, {'worker': {imran}});
      expect(one.every((e) => e.cells[1] == 'Imran'), isTrue);
      expect(data.rollupsOf!(one), isEmpty, reason: 'one account needs no list of accounts');

      final all = data.rollupsOf!(data.entries).single;
      expect(all.rows, hasLength(2));
      final first = {for (var i = 0; i < all.columns.length; i++) all.columns[i].label: all.rows.first.cells[i]};
      expect(first[l10n.colWorker], 'Asif');
      expect(first[l10n.colDays], 2);
      expect(first[l10n.colHours], 18 * 60);
      expect(first[l10n.colEarned], 18000);
      expect(first[l10n.kindAdvanceGiven], 20000);
      expect(first[l10n.payKindDeduction], 10000);
      expect(first[l10n.colPaid], 1000);
      expect(first[l10n.colBalance], -13000);
    });

    test('allowances, deductions and monthly salary all land on the account, and an undone month stays honest', () async {
      await db.savePayItem(id: null, workerId: imran, month: '2020-10', kind: PayItemKind.allowance, amountFils: 500, reason: 'Food', authorizedBy: null, note: null, roomId: null, operationId: newUuid());
      await db.applyRoomCharges('2020-10', charges: {imran: 300}, reason: l10n.payKindRoom, ownerApproved: 'Owner', operationId: newUuid());
      var rows = rowsOf(await build(Section.workerRegister), 'Imran');
      expect(rows.singleWhere((r) => r[l10n.colWhat] == l10n.payKindAllowance)[l10n.colEarned], 500);
      expect(rows.singleWhere((r) => r[l10n.colWhat] == l10n.payKindRoom)[l10n.payKindDeduction], 300);
      expect(rows.last[l10n.colBalance], 7200 + 7200 + 500 - 300);

      await db.saveRow(
        db.payContracts,
        id: null,
        operationId: newUuid(),
        fields: PayContractsCompanion(workerId: Value(imran), basis: Value(RateBasis.month.name), rateFils: const Value(100000), effectiveFrom: const Value('2020-10-01'), siteId: Value(pier)),
      );
      await db.postPayroll('2020-10', operationId: newUuid());
      rows = rowsOf(await build(Section.workerRegister), 'Imran');
      expect(rows.singleWhere((r) => r[l10n.colWhat] == l10n.payrollSalary)[l10n.colEarned], 100000);

      final line = await (db.select(db.payrollLines)..where((l) => l.workerId.equals(imran) & l.periodFrom.equals('2020-10-01'))).getSingle();
      await db.reversePayrollLine(line, reason: 'Wrong', operationId: newUuid());
      rows = rowsOf(await build(Section.workerRegister), 'Imran');
      expect(rows.where((r) => r[l10n.colWhat] == l10n.payrollSalary), isEmpty);
    });
  });

  test('attendance register adds the difference, the sums by worker and site, and flags a missing rate', () async {
    final noRate = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('ATE')));
    final melboard = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(noRate), name: const Value('Melboard')));
    await db.saveAttendanceBatch(workDate: '2020-11-01', clientId: noRate, siteId: melboard, inputs: [EntryInput(workerId: asif, shift: shift)], operationId: newUuid());
    await db.saveAttendanceBatch(
      workDate: '2020-11-02',
      clientId: emaar,
      siteId: marina,
      inputs: [EntryInput(workerId: asif, shift: const ShiftInput(status: AttendanceStatus.absent))],
      operationId: newUuid(),
    );
    final data = await build(Section.attendanceRegister, from: '2020-09-01', to: '2020-11-30');
    Map<String, Object?> row(String date, String name) {
      final e = data.entries.singleWhere((e) => e.group == date && e.cells[1] == name);
      return {for (var i = 0; i < data.columns.length; i++) data.columns[i].label: e.cells[i]};
    }

    final priced = row('2020-09-05', 'Asif');
    expect(priced[l10n.colBill], 9 * 1200);
    expect(priced[l10n.colPay], 9 * 1000);
    expect(priced[l10n.colDifference], 9 * 200);
    expect(priced[l10n.colBreak], 60);

    final flagged = row('2020-11-01', 'Asif');
    expect(flagged[l10n.colCompanyRate], l10n.issueNoRate);
    expect(flagged[l10n.colBill], isNull);
    expect(flagged[l10n.colDifference], isNull, reason: 'no bill yet, so no difference to claim');
    expect(flagged[l10n.colPay], 9000, reason: 'the wage does not wait for the bill');
    expect(row('2020-11-02', 'Asif')[l10n.colCompanyRate], isNot(l10n.issueNoRate), reason: 'an absent row needs no rate');

    final [byWorker, bySite] = data.rollupsOf!(data.entries);
    final asifSum = {for (var i = 0; i < byWorker.columns.length; i++) byWorker.columns[i].label: byWorker.rows.first.cells[i]};
    expect(asifSum[l10n.colWorker], 'Asif');
    expect(asifSum[l10n.statusPresent], 3);
    expect(asifSum[l10n.statusAbsent], 1);
    expect(asifSum[l10n.colWorkerHours], 27 * 60);
    expect(asifSum[l10n.colPay], 27000);
    final ate = bySite.rows.first;
    final ateSum = {for (var i = 0; i < bySite.columns.length; i++) bySite.columns[i].label: ate.cells[i]};
    expect(ateSum[l10n.colCompany], 'ATE');
    expect(ateSum[l10n.colNoRate], 1);
    expect(ateSum[l10n.colBill], 0);
    expect(ateSum[l10n.colPay], 9000);

    final filtered = data.rollupsOf!(filterEntries(data.entries, {'worker': {imran}})).first;
    expect(filtered.rows.single.cells.first, 'Imran', reason: 'the sums follow the filters');
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
      expect(a.findFile('xl/worksheets/sheet2.xml'), isNull, reason: 'no sums, no second sheet');
    });

    test('sums go on a second sheet, and a running balance totals where each group ended', () {
      const account = [
        RegisterColumn('Date', kind: CellKind.date),
        RegisterColumn('Earned', kind: CellKind.money, total: true),
        RegisterColumn('Left', kind: CellKind.money, closing: true),
      ];
      const rows = [
        RegisterEntry(['2020-09-05', 1000, 1000], group: 'Asif'),
        RegisterEntry(['2020-09-06', 500, 1500], group: 'Asif'),
        RegisterEntry(['2020-09-06', 200, 200], group: 'Imran'),
      ];
      final a = ZipDecoder().decodeBytes(
        registerXlsx(
          company: 'Al Noor',
          title: 'Mazdoor',
          filterLine: '',
          columns: account,
          entries: rows,
          totalLabel: 'Total',
          brandHex: '143E8F',
          rollupSheet: 'Khulasa',
          rollups: const [
            RegisterRollup('Sab', [RegisterColumn('Name'), RegisterColumn('Earned', kind: CellKind.money, total: true)], [RegisterEntry(['Asif', 1500]), RegisterEntry(['Imran', 200])]),
          ],
        ),
      );
      final sheet = part(a, 'xl/worksheets/sheet1.xml');
      expect(sheet, contains('<v>17.00</v>'), reason: '1,500 fils and 200 fils, where each ended');
      expect(sheet, contains('SUBTOTAL(109,B6:B8)'));
      expect(sheet, isNot(contains('SUBTOTAL(109,C6:C8)')));
      final second = part(a, 'xl/worksheets/sheet2.xml');
      expect(second, contains('SUBTOTAL(109,B3:B4)'));
      expect(second, contains('<v>17.00</v>'));
      expect(part(a, 'xl/workbook.xml'), contains('name="Khulasa"'));
      expect(part(a, '[Content_Types].xml'), contains('sheet2.xml'));
      expect(part(a, 'xl/_rels/workbook.xml.rels'), contains('sheet2.xml'));
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
        softArgb: 0xFFE7EDFA,
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

    test('a worker account prints in sections with its sums, and a long one runs across pages', () async {
      final data = await build(Section.workerRegister);
      Future<List<int>> account(List<RegisterEntry> entries) => registerPdf(
        company: 'Al Noor Labour Supply LLC',
        companyLine: 'Dubai',
        title: 'Mazdoor register',
        filterLine: 'Tareekh: sab',
        columns: data.columns,
        entries: entries,
        totalLabel: 'Total',
        pageLabel: (page, pages) => 'Safha $page / $pages',
        madeLabel: 'Banaya',
        brandArgb: 0xFF143E8F,
        softArgb: 0xFFE7EDFA,
        regularFont: File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
        boldFont: File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync(),
        rollups: data.rollupsOf!(entries),
        groupHeads: data.groupHeads,
        groupFeet: data.groupFeet,
        sections: true,
      );
      expect(pages(await account(data.entries)), 1);
      final group = groupEntries(data.entries).first;
      final long = [for (var i = 0; i < 300; i++) group.rows[i % group.rows.length]];
      expect(pages(await account(long)), greaterThan(3));
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
