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
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const sep = '2020-09';
const oct = '2020-10';
const nov = '2020-11';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

late String asif;
late String emaar;
late String marina;

Future<void> work(TenantDatabase db, String date, {String? worker, String? client, String? site, ShiftInput input = shift}) =>
    db.saveAttendanceBatch(workDate: date, clientId: client ?? emaar, siteId: site ?? marina, inputs: [EntryInput(workerId: worker ?? asif, shift: input)], operationId: newUuid());

Future<void> rate(TenantDatabase db, String worker, int fils, {String from = '2020-01-01', RateBasis basis = RateBasis.hour}) =>
    db.savingRate(() => db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(worker), basis: Value(basis.name), rateFils: Value(fils), effectiveFrom: Value(from))), workerId: worker);

/// AED 90 a day and a bill of AED 135: one day in September, two in October.
Future<void> seed(TenantDatabase db) async {
  await seedProfile(db);
  asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif')));
  emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
  await rate(db, asif, 1000);
  await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01')));
  for (final date in const ['2020-09-10', '2020-10-05', '2020-10-06']) {
    await work(db, date);
  }
}

/// Says everyone without a row had no work, so only the other findings are left.
Future<void> restOff(TenantDatabase db, String month) => db.transaction(() async {
  for (final f in (await db.closingFor(month)).findings.where((f) => f.issue == ClosingIssue.noHazri)) {
    await db.markDayOff(f.date, [for (final t in f.targets) t.id], operationId: newUuid());
  }
});

void main() {
  late TenantDatabase db;

  setUp(() async {
    db = memoryDb();
    await seed(db);
  });

  tearDown(() => db.close());

  Future<void> postAndClose(String month) async {
    await db.postPayroll(month, operationId: newUuid());
    await restOff(db, month);
    await db.closeMonth(month, operationId: newUuid());
  }

  Future<WorkerStatement> statementOf(String month, [String? worker]) async => (await db.statementsFor(month, workerId: worker ?? asif)).single;

  group('nothing closes while anything is left, and each thing shows on its date (D-045)', () {
    test('pay not posted stops it, on the last day of the month, until it is posted', () async {
      await restOff(db, oct);
      final before = await db.closingFor(oct);
      expect(before.canClose, isFalse);
      final finding = before.findings.single;
      expect((finding.issue, finding.date), (ClosingIssue.payrollNotPosted, '2020-10-31'));
      expect(finding.names, ['Asif']);
      await expectLater(db.closeMonth(oct, operationId: newUuid()), throwsA(isA<MonthNotReady>()));
      expect(await db.lockedThrough(), isNull);

      await db.postPayroll(oct, operationId: newUuid());
      expect((await db.closingFor(oct)).canClose, isTrue);
      await db.closeMonth(oct, operationId: newUuid());
      expect(await db.lockedThrough(), '2020-10-31');
    });

    test('attendance with no pay rate shows on its own date, and stops it', () async {
      final imran = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Imran')));
      await work(db, '2020-10-05', worker: imran);
      await db.postPayroll(oct, operationId: newUuid());
      await restOff(db, oct);
      final c = await db.closingFor(oct);
      expect(c.canClose, isFalse);
      final finding = c.findings.singleWhere((f) => f.issue == ClosingIssue.noWorkerRate);
      expect((finding.date, finding.targets.single), ('2020-10-05', (id: imran, name: 'Imran')));
    });

    test('a deduction waiting on an earlier open month stops it too', () async {
      await db.savePayItem(id: null, workerId: asif, month: sep, kind: PayItemKind.deduction, amountFils: 500, reason: 'Helmet', authorizedBy: 'Asif', note: null, roomId: null, operationId: newUuid());
      await db.postPayroll(oct, operationId: newUuid());
      final held = (await db.closingFor(oct)).findings.where((f) => f.issue == ClosingIssue.payrollNotPosted).toList();
      expect(held.single.date, '2020-09-30');
    });

    test('a month that has not ended cannot close, and nor can one already closed', () async {
      final thisMonth = dubaiToday(DateTime.now()).substring(0, 7);
      final current = await db.closingFor(thisMonth);
      expect(current.finished, isFalse);
      expect(current.canClose, isFalse);
      await expectLater(db.closeMonth(thisMonth, operationId: newUuid()), throwsA(isA<MonthNotReady>()));

      await postAndClose(oct);
      expect((await db.closingFor(oct)).closed, isTrue);
      await expectLater(db.closeMonth(oct, operationId: newUuid()), throwsA(isA<MonthNotReady>()));
      await expectLater(db.closeMonth(sep, operationId: newUuid()), throwsA(isA<MonthNotReady>()));
    });

    test('a company with no rate, an overlap and a payment with no month each stop it, and each clears', () async {
      final nakheel = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Nakheel')));
      final palm = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(nakheel), name: const Value('Palm')));
      await work(db, '2020-10-07', client: nakheel, site: palm);
      final row = (await db.select(db.attendanceEntries).get()).firstWhere((e) => e.workDate == '2020-10-05');
      await db.into(db.attendanceEntries).insert(row.toCompanion(false).copyWith(id: Value(newUuid())));
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-20', kind: CashKind.salaryPaid, amountFils: 100, workerId: asif);
      await db.postPayroll(oct, operationId: newUuid());
      await restOff(db, oct);

      var c = await db.closingFor(oct);
      expect(c.canClose, isFalse);
      final bill = c.findings.singleWhere((f) => f.issue == ClosingIssue.noCompanyRate);
      expect((bill.date, bill.names.single), ('2020-10-07', 'Nakheel'));
      final overlap = c.findings.singleWhere((f) => f.issue == ClosingIssue.overlap);
      expect((overlap.date, overlap.names.single), ('2020-10-05', 'Asif'));
      final payment = c.findings.singleWhere((f) => f.issue == ClosingIssue.noMonthChosen);
      expect(payment.date, '2020-10-20');
      expect([for (final f in c.findings) f.date], ['2020-10-05', '2020-10-07', '2020-10-20'], reason: 'soonest first');

      await db.savingRate(() => db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(nakheel), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01'))), clientId: nakheel);
      final kept = await db.select(db.attendanceEntries).get();
      final corrected = kept.firstWhere((e) => e.id == overlap.targets.single.id);
      await db.correctEntry(corrected, EntryInput(workerId: asif, shift: shift, overlapReason: 'Two sites'), reason: 'Both true', operationId: newUuid());
      await db.settleOldPayment((await db.select(db.cashEntries).get()).single, operationId: newUuid());

      c = await db.closingFor(oct);
      expect(c.findings, isEmpty);
      await db.closeMonth(oct, operationId: newUuid());
      expect((await db.closingFor(oct)).closed, isTrue);
    });

    test('settling an old payment writes down what the account already reads, and moves nothing', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-20', kind: CashKind.salaryPaid, amountFils: 12000, workerId: asif);
      final before = await statementOf(oct);
      await db.settleOldPayment((await db.select(db.cashEntries).get()).single, operationId: newUuid());
      final after = await statementOf(oct);
      expect(after.unpaid, before.unpaid);
      expect(after.paidFils, before.paidFils);
      expect(after.closingFils, before.closingFils);
      final parts = await db.select(db.salaryAllocations).get();
      expect({for (final a in parts) a.month: a.amountFils}, {sep: 9000, oct: 3000});
    });

    test('a payment with its month chosen is not flagged, and unpaid wages do not stop the month', () async {
      await db.addSalaryPayment(operationId: newUuid(), date: '2020-10-20', workerId: asif, amountFils: 100, parts: {sep: 100}, extraNote: 'x');
      await db.postPayroll(oct, operationId: newUuid());
      await restOff(db, oct);
      final c = await db.closingFor(oct);
      expect(c.findings, isEmpty);
      expect(c.closingFils, greaterThan(0));
      expect(c.canClose, isTrue);
    });
  });

  group('attendance left out shows date by date (D-045)', () {
    /// A worker the app has known since before these months.
    Future<String> oldWorker(String name, {String? joining}) async {
      final id = newUuid();
      await db.into(db.workers).insert(
        WorkersCompanion.insert(id: id, tenantId: testTenant, createdAtUtc: DateTime.utc(2020, 8), updatedAtUtc: DateTime.utc(2020, 8), actorId: 'a', sourceOperationId: 'op', code: name, name: name, joiningDate: Value(joining)),
      );
      return id;
    }

    Future<List<String>> gapsOf(String name, String month) async => [
      for (final f in (await db.closingFor(month)).findings)
        if (f.issue == ClosingIssue.noHazri && f.names.contains(name)) f.date,
    ];

    test('every day with no row is named on its own date', () async {
      await oldWorker('Bilal');
      final gaps = await gapsOf('Bilal', '2020-08');
      expect(gaps.first, '2020-08-01');
      expect(gaps.last, '2020-08-31');
      expect(gaps, hasLength(31));
    });

    test('an absent row counts as entered, and so does the owner saying there was no work', () async {
      final bilal = await oldWorker('Bilal');
      await work(db, '2020-08-10', worker: bilal, input: const ShiftInput(status: AttendanceStatus.absent));
      await db.markDayOff('2020-08-11', [bilal], operationId: newUuid());
      final gaps = await gapsOf('Bilal', '2020-08');
      expect(gaps, hasLength(29));
      expect(gaps, isNot(contains('2020-08-10')));
      expect(gaps, isNot(contains('2020-08-11')));
    });

    test('nobody is asked about days before they joined, or an archived worker at all', () async {
      await oldWorker('Bilal', joining: '2020-08-20');
      expect((await gapsOf('Bilal', '2020-08')).first, '2020-08-20');
      final khan = await oldWorker('Khan');
      await db.saveRow(db.workers, id: khan, operationId: newUuid(), fields: const WorkersCompanion(active: Value(false)));
      expect(await gapsOf('Khan', '2020-08'), isEmpty);
    });

    test('a worker added today is not asked about last year, unless their attendance reaches back that far', () async {
      final made = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W5'), name: Value('Today')));
      expect(await gapsOf('Today', oct), isEmpty);
      await rate(db, made, 1000);
      await work(db, '2020-10-30', worker: made);
      expect(await gapsOf('Today', oct), ['2020-10-31']);
    });

    test('a worker on a monthly salary is paid whatever the register says, so their days are not asked for', () async {
      final bilal = await oldWorker('Bilal');
      await rate(db, bilal, 300000, from: '2020-01-01', basis: RateBasis.month);
      expect(await gapsOf('Bilal', '2020-08'), isEmpty);
    });

    test('a closed month is not asked about again, and a day off cannot be dated in it', () async {
      await postAndClose(oct);
      expect((await gapsOf('Asif', nov)).first, '2020-11-01');
      await expectLater(db.markDayOff('2020-10-20', [asif], operationId: newUuid()), throwsA(isA<PeriodLocked>()));
    });
  });

  group('a closed month stays as it was (REP-04)', () {
    setUp(() => postAndClose(oct));

    test('attendance cannot be added, corrected or removed, in it or in earlier months', () async {
      await expectLater(work(db, '2020-10-20'), throwsA(isA<PeriodLocked>()));
      await expectLater(work(db, '2020-09-20'), throwsA(isA<PeriodLocked>()));
      final row = (await db.select(db.attendanceEntries).get()).firstWhere((e) => e.workDate == '2020-10-05');
      await expectLater(db.correctEntry(row, entryToInput(row), reason: 'Wrong', operationId: newUuid()), throwsA(isA<PeriodLocked>()));
      await expectLater(db.deleteUnapprovedEntry(row, operationId: newUuid()), throwsA(anything));
      await work(db, '2020-11-02');
    });

    test('money cannot be dated in it, but can be after it', () async {
      await expectLater(db.addCashEntry(operationId: newUuid(), date: '2020-10-20', kind: CashKind.expense, amountFils: 100), throwsA(isA<PeriodLocked>()));
      await expectLater(db.addSalaryPayment(operationId: newUuid(), date: '2020-10-20', workerId: asif, amountFils: 100, parts: {oct: 100}, extraNote: 'x'), throwsA(isA<PeriodLocked>()));
      await db.addCashEntry(operationId: newUuid(), date: '2020-11-01', kind: CashKind.expense, amountFils: 100);
    });

    test('payroll cannot be changed, undone or posted', () async {
      await expectLater(db.savePayItem(id: null, workerId: asif, month: oct, kind: PayItemKind.allowance, amountFils: 100, reason: 'x', authorizedBy: null, note: null, roomId: null, operationId: newUuid()), throwsA(isA<PeriodLocked>()));
      final line = (await db.select(db.payrollLines).get()).single;
      await expectLater(db.reversePayrollLine(line, reason: 'x', operationId: newUuid()), throwsA(isA<PeriodLocked>()));
    });

    test('an opening balance dated in it cannot be added or moved into it', () async {
      Future<String> opening(String date) => db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(kind: const Value('worker_salary_owed'), workerId: Value(asif), amountFils: const Value(100), asOfDate: Value(date), sourceNote: const Value('Old book')));
      await expectLater(opening('2020-10-31'), throwsA(isA<PeriodLocked>()));
      final id = await opening('2020-11-01');
      await expectLater(db.saveRow(db.openingBalances, id: id, operationId: newUuid(), fields: const OpeningBalancesCompanion(asOfDate: Value('2020-10-01'))), throwsA(isA<PeriodLocked>()));
    });

    test('no row in it is left waiting to be frozen, so later posting never touches it', () async {
      expect(await db.unapprovedUpTo(oct), isEmpty);
      await work(db, '2020-11-02');
      expect(await db.postPayroll(nov, operationId: newUuid()), 1);
    });

    test('a later rate reaches open rows and never a closed month, even a bill that never had one (REP-05)', () async {
      final before = {for (final e in await db.select(db.attendanceEntries).get()) e.id: (e.workerAmountFils, e.clientAmountFils)};
      await work(db, '2020-11-02');
      await rate(db, asif, 2000, from: '2020-01-02');
      final rows = await db.select(db.attendanceEntries).get();
      for (final e in rows.where((e) => e.workDate.compareTo('2020-10-31') <= 0)) {
        expect((e.workerAmountFils, e.clientAmountFils), before[e.id]);
      }
      expect(rows.singleWhere((e) => e.workDate == '2020-11-02').workerAmountFils, 18000);
    });

    test('a monthly contract added later neither changes a closed month nor holds up the next one', () async {
      final slip = (await statementOf(oct)).closingFils;
      await rate(db, asif, 300000, from: '2020-09-01', basis: RateBasis.month);
      expect((await statementOf(oct)).closingFils, slip);
      final november = (await db.payrollFor(nov)).single;
      expect(november.figures.issues, isEmpty);
      expect(november.figures.salaryFils, 300000);
      expect((await db.payrollFor(oct)).single.posted, isTrue);
    });
  });

  group('undoing money from a closed month is a dated adjustment (REP-04)', () {
    final today = dubaiToday(DateTime.now());
    final thisMonth = today.substring(0, 7);

    test('the closed month keeps it, today carries the reversal, and the balance comes out right', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: asif);
      await postAndClose(oct);
      final closedBefore = await statementOf(oct);
      final line = (await db.select(db.cashEntries).get()).single;
      await db.reverseCashEntry(line, reason: 'Wrong worker', operationId: newUuid());

      final reversal = (await db.select(db.cashEntries).get()).singleWhere((c) => c.reversesEntryId != null);
      expect(reversal.entryDate, today);
      expect(reversal.note, 'Wrong worker');

      final closedAfter = await statementOf(oct);
      expect(closedAfter.advanceFils, closedBefore.advanceFils);
      expect(closedAfter.closingFils, closedBefore.closingFils);

      final now = await statementOf(thisMonth);
      expect(now.advanceFils, -2000);
      expect(now.money.single.fils, -2000);
      expect(now.closingFils, closedBefore.closingFils + 2000);
      expect(await db.advanceLeft(asif), 0);
    });

    test('a salary paid in a closed month: that month still shows it, and the wage is owed again from today', () async {
      await db.addSalaryPayment(operationId: newUuid(), date: '2020-10-20', workerId: asif, amountFils: 9000, parts: {sep: 9000}, extraNote: 'x');
      await postAndClose(oct);
      final line = (await db.select(db.cashEntries).get()).single;
      await db.reverseCashEntry(line, reason: 'Bounced', operationId: newUuid());

      expect((await statementOf(sep)).paidFils, 9000);
      final now = await statementOf(thisMonth);
      expect(now.paidFils, -9000);
      expect(now.unpaid[thisMonth], 9000);
      expect(now.unpaid.values.fold(0, (total, v) => total + v), 27000);
    });

    test('undoing in an open month still leaves no trace on the slip, and keeps its date', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: asif);
      final line = (await db.select(db.cashEntries).get()).single;
      await db.reverseCashEntry(line, reason: 'Wrong', operationId: newUuid());
      expect((await db.select(db.cashEntries).get()).singleWhere((c) => c.reversesEntryId != null).entryDate, '2020-10-08');
      expect((await statementOf(oct)).advanceFils, 0);
      expect((await statementOf(oct)).money, isEmpty);
    });

    test('wages for a closed month can still be paid, dated after it', () async {
      await postAndClose(oct);
      await db.addSalaryPayment(operationId: newUuid(), date: '2020-11-03', workerId: asif, amountFils: 18000, parts: {oct: 18000}, extraNote: 'x');
      expect((await statementOf(oct)).paidFils, 18000);
      expect((await statementOf(nov)).unpaid, {sep: 9000});
    });
  });

  group('opening a closed month again (D-044)', () {
    test('needs a reason, keeps the lock on record, and the month can change and close again', () async {
      await postAndClose(oct);
      final lock = (await db.closingFor(oct)).lock!;
      await db.reopenMonth(lock, reason: 'Missed a day', operationId: newUuid());

      expect(await db.lockedThrough(), isNull);
      final stored = await db.select(db.periodLocks).getSingle();
      expect(stored.reopened, isTrue);
      final audit = await (db.select(db.auditEvents)..where((a) => a.action.equals('reopen'))).getSingle();
      expect(audit.reason, 'Missed a day');
      await expectLater(db.delete(db.periodLocks).go(), throwsA(anything));

      await work(db, '2020-10-20');
      await db.postPayroll(oct, operationId: newUuid()).catchError((_) => 0);
      final line = (await db.select(db.payrollLines).get()).single;
      await db.reversePayrollLine(line, reason: 'Redo', operationId: newUuid());
      await postAndClose(oct);
      expect(await db.lockedThrough(), '2020-10-31');
    });

    test('only the latest closed month opens, so months never close out of order', () async {
      await postAndClose(sep);
      await postAndClose(oct);
      final september = await (db.select(db.periodLocks)..where((l) => l.month.equals(sep))).getSingle();
      await expectLater(db.reopenMonth(september, reason: 'x', operationId: newUuid()), throwsA(isA<LaterMonthClosed>()));
      expect((await db.closingFor(sep)).canReopen, isFalse);
      expect((await db.closingFor(oct)).canReopen, isTrue);
    });
  });

  test('month-close reconciliation: the month adds up, the next starts where it ended, and closing moves nothing (P2 gate)', () async {
    final imran = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Imran')));
    await rate(db, imran, 500);
    await work(db, '2020-10-05', worker: imran);
    await db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(kind: const Value('worker_salary_owed'), workerId: Value(imran), amountFils: const Value(4000), asOfDate: const Value('2020-08-31'), sourceNote: const Value('Old book')));
    await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: asif);
    await db.addCashEntry(operationId: newUuid(), date: '2020-10-11', kind: CashKind.expense, amountFils: 700);
    await db.addCashEntry(operationId: newUuid(), date: '2020-10-12', kind: CashKind.expense, amountFils: 300);
    await db.savePayItem(id: null, workerId: asif, month: oct, kind: PayItemKind.deduction, amountFils: 500, reason: 'Helmet', authorizedBy: 'Asif', note: null, roomId: null, operationId: newUuid());
    await db.addSalaryPayment(operationId: newUuid(), date: '2020-10-20', workerId: asif, amountFils: 9000, parts: {sep: 9000}, extraNote: 'x');
    await db.addSalaryPayment(operationId: newUuid(), date: '2020-10-21', workerId: asif, amountFils: 3000, parts: {oct: 3000}, extraNote: 'x');
    await db.applyAdvanceCuts(oct, reason: 'Advance', operationId: newUuid());
    await db.postPayroll(oct, operationId: newUuid());
    await restOff(db, oct);

    final before = await db.closingFor(oct);
    expect(before.closingFils, before.openingFils + before.earnedFils - before.advanceFils - before.cutFils - before.paidFils);
    expect(before.expensesFils, 1000);

    await db.closeMonth(oct, operationId: newUuid());
    final after = await db.closingFor(oct);
    expect(after.closingFils, before.closingFils);
    expect(after.openingFils, before.openingFils);
    expect(after.earnedFils, before.earnedFils);
    expect(after.paidFils, before.paidFils);

    // Everything paid and earned is on the account, so Tankhwah's figure and the slip's agree once advance is cut.
    final tankhwah = await db.payrollFor(oct);
    expect(tankhwah.fold(0, (total, p) => total + p.closingFils), after.closingFils);
    expect((await db.closingFor(nov)).openingFils, after.closingFils);
  });

  group('old reports stay put (REP-05)', () {
    late AppLocalizations l10n;
    Future<List<List<Object?>>> cells(Section section) async => [
      for (final e in (await buildRegister(db, l10n, section, from: monthFirstDay(sep), to: monthLastDay(oct))).entries) e.cells,
    ];

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
    });

    test('archiving a worker or company, or changing a rate, leaves a posted month as it was', () async {
      await db.postPayroll(oct, operationId: newUuid());
      final attendance = await cells(Section.attendanceRegister);
      final accounts = await cells(Section.workerRegister);
      final slip = await statementOf(oct);

      await rate(db, asif, 2000, from: '2020-01-02');
      await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(3000), effectiveFrom: const Value('2020-01-02')));
      await db.saveRow(db.workers, id: asif, operationId: newUuid(), fields: const WorkersCompanion(active: Value(false)));
      await db.saveRow(db.clients, id: emaar, operationId: newUuid(), fields: const ClientsCompanion(active: Value(false)));

      expect(await cells(Section.attendanceRegister), attendance);
      expect(await cells(Section.workerRegister), accounts);
      final after = await statementOf(oct);
      expect(after.closingFils, slip.closingFils);
      expect(after.workFils, slip.workFils);
    });

    test('an opening balance sits at its source date: before it, nothing, and after it, in the opening', () async {
      await db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(kind: const Value('worker_salary_owed'), workerId: Value(asif), amountFils: const Value(4000), asOfDate: const Value('2020-09-30'), sourceNote: const Value('Old book')));
      final august = (await db.statementsFor('2020-08', workerId: asif)).single;
      expect(august.closingFils, 0);
      final september = await statementOf(sep);
      expect(september.openingFils, 4000);
      expect((await statementOf(oct)).openingFils, 4000 + 9000);
      expect(september.unpaid, {sep: 13000});
    });
  });

  testWidgets('closing from the screen: what is left by date, clearing it, the confirmation, and opening it again', (tester) async {
    final app = memoryDb();
    final last = addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1);
    await real(tester, () async {
      await seed(app);
      await work(app, '$last-05');
      await app.addCashEntry(operationId: newUuid(), date: '$last-06', kind: CashKind.expense, amountFils: 700);
    });
    final l10n = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);

    await goTo(tester, l10n.tabClosing);
    final left = (await real(tester, () => app.closingFor(last))).findings;
    final count = left.fold(0, (total, f) => total + f.targets.length);
    expect(find.text(l10n.closingLeft(count)), findsOneWidget);
    expect(find.text(l10n.closeBlocked(count)), findsOneWidget);
    await tester.tap(find.text(l10n.closeBlocked(count)));
    await settle(tester);
    expect(find.text(l10n.closeTitle(showMonth(last))), findsNothing, reason: 'the button does nothing while anything is left');

    // Clearing one date from its own row.
    final firstGap = left.firstWhere((f) => f.issue == ClosingIssue.noHazri);
    await tester.tap(find.text(l10n.findingNoHazri(1, 'Asif')).first);
    await settle(tester);
    expect(find.text(l10n.closingDayOffHelp), findsOneWidget);
    await tester.tap(find.text(l10n.closingDayOff));
    await settle(tester);
    final after = (await real(tester, () => app.closingFor(last))).findings;
    expect(after.any((f) => f.issue == ClosingIssue.noHazri && f.date == firstGap.date), isFalse);

    await real(tester, () => restOff(app, last));
    await settle(tester);
    await tester.scrollUntilVisible(find.text(l10n.findingNotPosted(1, 'Asif')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text(l10n.findingNotPosted(1, 'Asif')), findsOneWidget);

    await real(tester, () => app.postPayroll(last, operationId: newUuid()));
    await settle(tester);
    expect(find.text(l10n.closingAllClear), findsOneWidget);
    await tester.tap(find.text(l10n.closeButton(showMonth(last))));
    await settle(tester);
    await tester.tap(find.text(l10n.cancel));
    await settle(tester);
    expect(await real(tester, app.lockedThrough), isNull);

    await tester.tap(find.text(l10n.closeButton(showMonth(last))));
    await settle(tester);
    await tester.tap(find.text(l10n.closeConfirm));
    await settle(tester);
    expect(await real(tester, app.lockedThrough), monthLastDay(last));
    expect(find.text(l10n.closingIsClosed), findsOneWidget);

    await goTo(tester, l10n.menuPayroll);
    expect(find.text(l10n.closedNote), findsNothing, reason: 'this month is still open');
    await tester.tap(find.byTooltip(l10n.previousMonth));
    await settle(tester);
    expect(find.text(l10n.closedNote), findsOneWidget);
    expect(find.text(l10n.applyRoomCharges), findsNothing);
    await tester.tap(find.byTooltip(l10n.nextMonth));
    await settle(tester);

    await goTo(tester, l10n.tabClosing);
    await tester.scrollUntilVisible(find.text(l10n.reopenButton), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(l10n.reopenButton));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Missed a day');
    await tester.tap(find.text(l10n.reopenConfirm));
    await settle(tester);
    expect(await real(tester, app.lockedThrough), isNull);
    expect(find.text(l10n.closingOpen), findsOneWidget);
    await shutDown(tester, app);
  });
}
