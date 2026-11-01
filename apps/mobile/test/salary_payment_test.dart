import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const sep = '2020-09';
const oct = '2020-10';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

late String asif;

/// AED 90 a day: one day in September, two in October.
Future<void> seed(TenantDatabase db) async {
  await seedProfile(db);
  asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif')));
  final emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  final marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
  await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(asif), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')));
  for (final date in const ['2020-09-10', '2020-10-05', '2020-10-06']) {
    await db.saveAttendanceBatch(workDate: date, clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: asif, shift: shift)], operationId: newUuid());
  }
}

void main() {
  late TenantDatabase db;

  setUp(() async {
    db = memoryDb();
    await seed(db);
  });

  tearDown(() => db.close());

  Future<WorkerStatement> statementOf(String month) async => (await db.statementsFor(month, workerId: asif)).single;

  Future<void> pay(int fils, Map<String, int> parts, {String date = '2020-11-03', String? operationId, String? reference, String? receiver}) => db.addSalaryPayment(
    operationId: operationId ?? newUuid(),
    date: date,
    workerId: asif,
    amountFils: fils,
    parts: parts,
    extraNote: 'Above salary',
    reference: reference,
    receiver: receiver,
  );

  group('choosing the month a payment settles (PAY-06)', () {
    test('the chosen month is settled, and the older one stays unpaid', () async {
      expect((await statementOf('2020-11')).unpaid, {sep: 9000, oct: 18000});
      await pay(18000, {oct: 18000});
      expect((await statementOf('2020-11')).unpaid, {sep: 9000});

      final september = await statementOf(sep);
      expect(september.paidFils, 0);
      expect(september.closingFils, 9000);
      final october = await statementOf(oct);
      expect(october.openingFils, 9000);
      expect(october.paidFils, 18000);
      expect(october.closingFils, 9000);
      expect(october.money.single.date, '2020-11-03');
    });

    test('a split shows its own share on each month, and the rows add up to the payment', () async {
      await pay(12000, {sep: 9000, oct: 3000});
      expect((await statementOf(sep)).paidFils, 9000);
      expect((await statementOf(oct)).paidFils, 3000);
      final rows = await db.select(db.salaryAllocations).get();
      expect(rows.fold(0, (total, a) => total + a.amountFils), 12000);
      final line = (await db.select(db.cashEntries).get()).single;
      expect((line.kind, line.amountFils), (CashKind.salaryPaid.name, 12000));
    });

    test('method, reference and who took it stay on the line', () async {
      await db.addSalaryPayment(operationId: newUuid(), date: '2020-11-03', workerId: asif, amountFils: 9000, parts: {sep: 9000}, extraNote: 'x', method: 'bank', reference: 'CHQ 123', receiver: 'Brother');
      final line = (await db.select(db.cashEntries).get()).single;
      expect((line.method, line.reference, line.receiver), ('bank', 'CHQ 123', 'Brother'));

      final l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
      final register = await buildRegister(db, l10n, Section.cashRegister);
      expect(register.entries.single.cells.last, '09-2020: AED 90.00, CHQ 123, Brother');
    });

    test('a payment from before this choice existed still goes oldest first', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-02', kind: CashKind.salaryPaid, amountFils: 12000, workerId: asif);
      expect((await statementOf(sep)).paidFils, 9000);
      expect((await statementOf(oct)).paidFils, 3000);
      expect((await statementOf(oct)).unpaid, {oct: 15000});
    });

    test('more than a month still owes is refused, and nothing is written', () async {
      await expectLater(pay(10000, {sep: 10000}), throwsA(isA<AllocationTooHigh>()));
      await expectLater(pay(5000, {sep: 9000}), throwsA(isA<AllocationTooHigh>()));
      await expectLater(pay(9000, {'2020-08': 9000}), throwsA(isA<AllocationTooHigh>()));
      expect(await db.select(db.cashEntries).get(), isEmpty);
      expect(await db.select(db.salaryAllocations).get(), isEmpty);
    });

    test('a retry of the same payment changes nothing (TEAM-04)', () async {
      final operation = newUuid();
      await pay(9000, {sep: 9000}, operationId: operation);
      await pay(9000, {sep: 9000}, operationId: operation);
      expect(await db.select(db.cashEntries).get(), hasLength(1));
      expect(await db.select(db.salaryAllocations).get(), hasLength(1));
    });

    test('undoing the payment in the cash book opens its months again', () async {
      await pay(9000, {sep: 9000});
      expect((await statementOf('2020-11')).unpaid, {oct: 18000});
      final line = (await db.select(db.cashEntries).get()).single;
      await db.reverseCashEntry(line, reason: 'Wrong month', operationId: newUuid());
      expect((await statementOf('2020-11')).unpaid, {sep: 9000, oct: 18000});
      expect((await statementOf(sep)).paidFils, 0);
    });

    test('what a payment settled cannot be edited or removed (REP-08)', () async {
      await pay(9000, {sep: 9000});
      await expectLater(db.update(db.salaryAllocations).write(const SalaryAllocationsCompanion(amountFils: Value(1))), throwsA(anything));
      await expectLater(db.delete(db.salaryAllocations).go(), throwsA(anything));
    });
  });

  group('paying more than is owed (PAY-06)', () {
    test('the extra goes on the advance as its own line, never a negative salary', () async {
      await pay(30000, {sep: 9000, oct: 18000});
      final lines = await db.select(db.cashEntries).get();
      expect(lines.map((l) => (l.kind, l.amountFils)), unorderedEquals([(CashKind.salaryPaid.name, 27000), (CashKind.advanceGiven.name, 3000)]));
      expect(lines.singleWhere((l) => l.kind == CashKind.advanceGiven.name).note, 'Above salary');
      expect(await db.advanceLeft(asif), 3000);
      expect((await statementOf('2020-11')).unpaid, isEmpty);
    });

    test('with nothing owed, the whole amount is an advance and no salary line is written', () async {
      await pay(27000, {sep: 9000, oct: 18000});
      await pay(5000, const {});
      final advance = (await db.select(db.cashEntries).get()).singleWhere((l) => l.kind == CashKind.advanceGiven.name);
      expect(advance.amountFils, 5000);
      expect(await db.select(db.salaryAllocations).get(), hasLength(2));
      expect(await db.advanceLeft(asif), 5000);
    });

    test('the account comes out the same whichever way it is paid', () async {
      await pay(30000, {sep: 9000, oct: 18000});
      expect((await statementOf('2020-11')).closingFils, 27000 - 30000);
    });
  });

  group('months owed always agree with the rest of the account', () {
    test("unpaid wages equal Tankhwah's own figure, and what is owing equals the slip's balance", () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: asif);
      await db.savePayItem(id: null, workerId: asif, month: sep, kind: PayItemKind.deduction, amountFils: 500, reason: 'Helmet', authorizedBy: 'Asif', note: null, roomId: null, operationId: newUuid());
      await db.postPayroll(sep, operationId: newUuid());
      await pay(3000, {sep: 3000});
      await db.savePayItem(id: null, workerId: asif, month: oct, kind: PayItemKind.advanceRecovery, amountFils: 500, reason: 'Advance', authorizedBy: null, note: null, roomId: null, operationId: newUuid());
      await db.postPayroll(oct, operationId: newUuid());

      final tankhwah = (await db.payrollFor(oct)).single;
      final november = await statementOf('2020-11');
      expect(november.unpaid.values.fold(0, (total, v) => total + v), tankhwah.closingFils);
      expect(november.owing.values.fold(0, (total, v) => total + v), november.closingFils);
      expect(november.closingFils, tankhwah.closingFils - (await db.advanceLeft(asif)));
    });

    test('work not posted yet counts too, so a worker can be paid mid-month', () async {
      expect((await statementOf(oct)).unpaid, {sep: 9000, oct: 18000});
      await pay(18000, {oct: 18000}, date: '2020-10-07');
      expect((await statementOf(oct)).unpaid, {sep: 9000});
    });

    test('money from before this app is the oldest wage owed, and an old advance only comes off what is owing', () async {
      await db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(kind: const Value('worker_salary_owed'), workerId: Value(asif), amountFils: const Value(4000), asOfDate: const Value('2020-08-31'), sourceNote: const Value('Old book')));
      await db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(kind: const Value('worker_advance'), workerId: Value(asif), amountFils: const Value(1000), asOfDate: const Value('2020-08-31'), sourceNote: const Value('Old book')));
      final statement = await statementOf(oct);
      expect(statement.unpaid, {'2020-08': 4000, sep: 9000, oct: 18000});
      expect(statement.owing, {'2020-08': 3000, sep: 9000, oct: 18000});
    });
  });

  group('wages due (PAY-08)', () {
    test('a finished month shows with how late it is, and paying it clears it', () async {
      final today = dubaiToday(DateTime.now());
      final due = (await db.wagesDueNow()).single;
      expect(due.worker.id, asif);
      expect(due.wages.map((w) => (w.month, w.fils)), [(sep, 9000), (oct, 18000)]);
      expect(due.wages.first.daysLate, daysBetween('2020-09-30', today));
      expect(due.wages.first.overdue, isTrue);

      await pay(27000, {sep: 9000, oct: 18000});
      expect(await db.wagesDueNow(), isEmpty);
    });

    test('an advance not yet cut is not called late pay', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 10000, workerId: asif);
      final due = (await db.wagesDueNow()).single;
      expect(due.wages.map((w) => (w.month, w.fils)), [(sep, 9000), (oct, 8000)]);
      expect(due.totalFils, 27000 - 10000);

      await db.addCashEntry(operationId: newUuid(), date: '2020-10-09', kind: CashKind.advanceGiven, amountFils: 17000, workerId: asif);
      expect(await db.wagesDueNow(), isEmpty);
    });

    test('work this month is not due yet', () async {
      await pay(27000, {sep: 9000, oct: 18000});
      final today = dubaiToday(DateTime.now());
      final emaar = (await db.select(db.clients).get()).single.id;
      final marina = (await db.select(db.sites).get()).single.id;
      await db.saveAttendanceBatch(workDate: today, clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: asif, shift: shift)], operationId: newUuid());
      expect(await db.wagesDueNow(), isEmpty);
    });

    test("the company's own days are used, and no days means late from the day after", () async {
      final profile = (await db.select(db.tenantProfiles).get()).single;
      await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(wageDueDays: Value(10)));
      final today = dubaiToday(DateTime.now());
      expect((await db.wagesDueNow()).single.wages.first.daysLate, daysBetween('2020-10-10', today));
    });

    test('the list follows the data as it changes', () async {
      final stream = db.watchWagesDue();
      final seen = <int>[];
      final done = stream.take(2).forEach((rows) => seen.add(rows.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pay(27000, {sep: 9000, oct: 18000});
      await done;
      expect(seen, [1, 0]);
    });
  });

  group('cutting the advance in one tap (D-043)', () {
    Future<void> advance(int fils) => db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: fils, workerId: asif);

    test("Tankhwah's figure then matches the slip", () async {
      await advance(2000);
      expect((await db.payrollFor(oct)).single.needsAdvanceCut, isTrue);
      expect(await db.applyAdvanceCuts(oct, reason: 'Advance', operationId: newUuid()), 1);
      final tankhwah = (await db.payrollFor(oct)).single;
      expect(tankhwah.figures.recoveryFils, 2000);
      expect(tankhwah.needsAdvanceCut, isFalse);
      expect(tankhwah.closingFils, (await statementOf(oct)).closingFils);
    });

    test('never more than the month can carry, so posting is not stopped', () async {
      await advance(50000);
      await db.applyAdvanceCuts(oct, reason: 'Advance', operationId: newUuid());
      final tankhwah = (await db.payrollFor(oct)).single;
      expect(tankhwah.figures.recoveryFils, tankhwah.figures.grossFils);
      expect(tankhwah.figures.issues, isEmpty);
    });

    test('it does nothing twice, and leaves a recovery the owner typed alone', () async {
      await advance(2000);
      await db.savePayItem(id: null, workerId: asif, month: oct, kind: PayItemKind.advanceRecovery, amountFils: 500, reason: 'Typed', authorizedBy: null, note: null, roomId: null, operationId: newUuid());
      expect(await db.applyAdvanceCuts(oct, reason: 'Advance', operationId: newUuid()), 0);
      expect((await db.payrollFor(oct)).single.figures.recoveryFils, 500);
    });

    test('a recovery waiting on another unposted month stays counted', () async {
      await advance(2000);
      await db.savePayItem(id: null, workerId: asif, month: sep, kind: PayItemKind.advanceRecovery, amountFils: 1500, reason: 'Typed', authorizedBy: null, note: null, roomId: null, operationId: newUuid());
      await db.applyAdvanceCuts(oct, reason: 'Advance', operationId: newUuid());
      expect((await db.payrollFor(oct)).single.figures.recoveryFils, 500);
    });

    test('a month already posted is left alone', () async {
      await db.postPayroll(oct, operationId: newUuid());
      await advance(2000);
      expect(await db.applyAdvanceCuts(oct, reason: 'Advance', operationId: newUuid()), 0);
    });
  });

  testWidgets('from the reminder to the payment: oldest first, a clear yes before anything goes on the advance, and the reminder clears', (tester) async {
    final app = memoryDb();
    await real(tester, () => seed(app));
    final l10n = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);

    expect(find.text(l10n.wagesDueBanner(1, 'AED 270.00')), findsOneWidget);
    await tester.tap(find.text(l10n.wagesDueBanner(1, 'AED 270.00')));
    await settle(tester);
    expect(find.text(l10n.wagesDueNote), findsOneWidget);

    await tester.tap(find.text('Asif'));
    await settle(tester);
    final amountBoxes = find.widgetWithText(TextFormField, l10n.amountAed);
    expect(amountBoxes, findsNWidgets(3), reason: 'the amount, then one for each month');
    String typed(int box) => tester.widget<TextFormField>(amountBoxes.at(box)).controller!.text;
    expect([typed(0), typed(1), typed(2)], ['270.00', '90.00', '180.00']);

    await tester.enterText(amountBoxes.at(0), '100');
    await settle(tester);
    expect([typed(1), typed(2)], ['90.00', '10.00'], reason: 'the amount shares itself out, oldest first');

    await tester.enterText(amountBoxes.at(1), '20');
    await tester.enterText(amountBoxes.at(2), '80');
    await settle(tester);
    await tester.enterText(amountBoxes.at(0), '320');
    await settle(tester);
    expect([typed(1), typed(2)], ['20', '80'], reason: "the owner's own split stays");
    expect(find.text(l10n.salaryExtraLine('AED 220.00')), findsOneWidget);

    await tester.tap(find.text(l10n.salaryOldestFirst));
    await settle(tester);
    expect([typed(1), typed(2)], ['90.00', '180.00']);
    expect(find.text(l10n.salaryExtraLine('AED 50.00')), findsOneWidget);

    await tester.tap(find.text(l10n.save));
    await settle(tester);
    expect(find.text(l10n.salaryExtraTitle('AED 50.00')), findsOneWidget);
    await tester.tap(find.text(l10n.cancel));
    await settle(tester);
    expect(await real(tester, () => app.select(app.cashEntries).get()), isEmpty);

    await tester.tap(find.text(l10n.save));
    await settle(tester);
    await tester.tap(find.text(l10n.salaryExtraConfirm));
    await settle(tester);

    final lines = await real(tester, () => app.select(app.cashEntries).get());
    expect(lines.map((l) => (l.kind, l.amountFils)), unorderedEquals([(CashKind.salaryPaid.name, 27000), (CashKind.advanceGiven.name, 5000)]));
    expect(find.text(l10n.wagesDueNone), findsOneWidget);
    await shutDown(tester, app);
  });
}
