import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/payroll.dart';
import 'package:test/test.dart';

const month = '2026-10';

PayrollFigures figures({
  Iterable<WorkLine> work = const [],
  Iterable<RateTerms> contracts = const [],
  Iterable<PayItemLine> items = const [],
  int advanceLeft = 0,
  int unpriced = 0,
  String? lastPosted,
  String? closed,
  int? limitBps,
  String current = month,
  String period = month,
}) {
  return workerPayroll(
    month: period,
    currentMonth: current,
    work: work,
    contracts: contracts,
    items: items,
    advanceLeftFils: advanceLeft,
    unpricedRows: unpriced,
    lastPostedMonth: lastPosted,
    closedMonth: closed,
    limitBps: limitBps,
  );
}

RateTerms monthly(int fils, {String from = '2026-01-01', String? to, PartialMethod? method, int? divisor, String? site}) {
  return RateTerms(basis: RateBasis.month, rateFils: fils, effectiveFrom: from, effectiveTo: to, partialMethod: method, partialDivisor: divisor, siteId: site);
}

void main() {
  group('a day with no attendance on a monthly salary (D-057)', () {
    RateTerms cutting(int fils, {PartialMethod method = PartialMethod.calendarDays, int? divisor, Set<int> off = const {}}) =>
        RateTerms(basis: RateBasis.month, rateFils: fils, effectiveFrom: '2026-01-01', partialMethod: method, partialDivisor: divisor, cutAbsence: true, offWeekdays: off);
    Set<String> days(String month, bool Function(String day) keep) => {
      for (var d = monthFirstDay(month); d.compareTo(monthLastDay(month)) <= 0; d = addDays(d, 1))
        if (keep(d)) d,
    };

    test("is cut at the contract's own rule, but never a weekly day off or a day the owner excused", () {
      final present = days(month, (d) => !{'2026-10-05', '2026-10-12', '2026-10-20'}.contains(d) && weekdayOf(d) != DateTime.friday);
      final f = workerPayroll(
        month: month,
        currentMonth: month,
        work: const [],
        contracts: [cutting(310000, off: {DateTime.friday})],
        items: const [],
        advanceLeftFils: 0,
        present: present,
        excused: const {'2026-10-20'},
        through: '2026-10-31',
      );
      expect((f.salaryFils, f.absenceFils, f.absentDays.join(' '), f.issues.length), (290000, 20000, '2026-10-05 2026-10-12', 0));
    });

    test('counts only up to the day given, by a fixed divisor too, and never takes more than the month pays', () {
      expect(periodSalary([cutting(300000, method: PartialMethod.fixedDivisor, divisor: 30)], month, through: '2026-10-10')?.cutFils, 100000);
      expect(periodSalary([cutting(300000, method: PartialMethod.fixedDivisor, divisor: 20)], '2026-02', through: '2026-02-28')?.fils, 0);
    });

    test('a contract with the cut off pays the whole month, and a cut with no rule stops for review (D-102)', () {
      expect(periodSalary([monthly(300000, method: PartialMethod.calendarDays)], month, through: '2026-10-31')?.fils, 300000);
      final noRule = RateTerms(basis: RateBasis.month, rateFils: 300000, effectiveFrom: '2026-01-01', cutAbsence: true);
      expect(periodSalary([noRule], month, through: '2026-10-31'), isNull);
      expect(periodSalary([noRule], month, present: days(month, (_) => true), through: '2026-10-31')?.fils, 300000);
    });

    test('D-080 (8) a part month with a day cut rounds once, and the cut is the part pay less what is paid (D-101)', () {
      final late = RateTerms(basis: RateBasis.month, rateFils: 100000, effectiveFrom: '2026-10-29', partialMethod: PartialMethod.calendarDays, cutAbsence: true);
      final pay = periodSalary([late], month, present: const {'2026-10-30', '2026-10-31'}, through: '2026-10-31');
      // 100,000 x 2 / 31 = 6,451.6, so 6,452. The part month alone is 100,000 x 3 / 31 = 9,677.
      expect((pay?.fils, pay?.cutFils), (6452, 9677 - 6452));
    });

    test('D-080 (5) attendance added late gives each cut day back, and all of them give back exactly the cut, never a fil more', () {
      final late = RateTerms(basis: RateBasis.month, rateFils: 100000, effectiveFrom: '2026-10-29', partialMethod: PartialMethod.calendarDays, cutAbsence: true);
      final posted = periodSalary([late], month, present: const {'2026-10-31'}, through: '2026-10-31')!;
      expect((posted.cutFils, posted.absent.join(' ')), (6451, '2026-10-29 2026-10-30'));
      Map<String, int> back({Set<String> before = const {}, required Set<String> worked}) =>
          cutGivenBack([late], month, cutFils: posted.cutFils, cutDays: posted.absent, back: before, worked: worked);

      // One day alone would round to 3,226 twice, which is 6,452: one fil more than was cut.
      expect(back(worked: const {'2026-10-29', '2026-10-30'}), {'2026-10-29': 3226, '2026-10-30': 3225});
      expect(back(worked: const {'2026-10-30', '2026-10-31', '2026-09-30'}), {'2026-10-30': 3226}, reason: 'a day that was never cut gives nothing back');
      expect(back(before: const {'2026-10-29'}, worked: const {'2026-10-29', '2026-10-30'}), {'2026-10-30': 3225}, reason: 'a day given back already is not given twice');
      expect(back(worked: const {}), isEmpty);
    });
  });

  group('a closed month (REP-04)', () {
    test('cannot post, and pays no salary', () {
      final closed = figures(contracts: [monthly(200000)], closed: month);
      expect(closed.issues, contains(PayrollIssue.monthClosed));
      expect(closed.salaryFils, 0);
      expect(figures(contracts: [monthly(200000)], period: '2026-09', closed: month).issues, contains(PayrollIssue.monthClosed));
    });

    test('never holds up a later month, though an open one still does', () {
      final held = figures(contracts: [monthly(200000)], lastPosted: '2026-08');
      expect(held.issues, contains(PayrollIssue.earlierMonthMissing));
      final free = figures(contracts: [monthly(200000)], lastPosted: '2026-08', closed: '2026-09');
      expect(free.issues, isNot(contains(PayrollIssue.earlierMonthMissing)));
      expect(free.salaryFils, 200000);
      final still = figures(contracts: [monthly(200000)], lastPosted: '2026-07', closed: '2026-08');
      expect(still.issues, contains(PayrollIssue.earlierMonthMissing));
    });
  });

  group('TC-001 carry-forward (PAY-02, PAY-03)', () {
    test('1,000 earned and 500 paid leaves 1,500 due next month, and 1,500 still due if nothing is paid', () {
      final september = figures(work: const [WorkLine('2026-09-30', 100000)], period: '2026-09');
      const paid = [CashLine(CashKind.salaryPaid, 50000)];
      final opening = salaryOwed(0, september.dueFils, paid);
      expect(opening, 50000);

      final october = figures(work: const [WorkLine('2026-10-15', 100000)]);
      expect(october.grossFils, 100000, reason: 'old debt never becomes new earnings');
      expect(opening + october.dueFils, 150000);
      expect(salaryOwed(0, september.dueFils + october.dueFils, paid), 150000);
    });
  });

  test('TC-032 the deductions example: total 1,200, closing 600 (PAY-04)', () {
    final f = figures(
      work: const [WorkLine('2026-10-15', 100000)],
      items: const [PayItemLine(PayItemKind.roomCharge, 20000), PayItemLine(PayItemKind.advanceRecovery, 10000)],
      advanceLeft: 10000,
    );
    expect(f.issues, isEmpty);
    expect(f.netFils, 70000);
    expect(50000 + f.dueFils, 120000);
    expect(salaryOwed(50000, f.dueFils, const [CashLine(CashKind.salaryPaid, 60000)]), 60000);
  });

  test('TC-002 advance 300 less recovery 100 is 200, and neither is a wage (PAY-05)', () {
    expect(advanceOutstanding(0, const [CashLine(CashKind.advanceGiven, 30000)], recoveredFils: 10000), 20000);
    final f = figures(work: const [WorkLine('2026-10-15', 100000)], items: const [PayItemLine(PayItemKind.advanceRecovery, 10000)], advanceLeft: 30000);
    expect(f.grossFils, 100000);
    expect(f.netFils, 90000);
  });

  test('TC-035 recovery above the advance stops for review (PAY-05)', () {
    final f = figures(work: const [WorkLine('2026-10-15', 100000)], items: const [PayItemLine(PayItemKind.advanceRecovery, 10001)], advanceLeft: 10000);
    expect(f.issues, {PayrollIssue.recoveryAboveAdvance});
  });

  group('TC-033 deductions (PAY-07, D-104)', () {
    test('more than earned stops for review and never becomes debt', () {
      final f = figures(work: const [WorkLine('2026-10-15', 10000)], items: const [PayItemLine(PayItemKind.deduction, 10001)]);
      expect(f.issues, {PayrollIssue.negativeNet});
    });

    test('work corrected downward cannot push the month below zero either', () {
      final f = figures(work: const [WorkLine('2026-10-15', 10000), WorkLine('2026-09-15', 5000, alreadyPaidFils: 20000)]);
      expect(f.adjustmentFils, -15000);
      expect(f.issues, {PayrollIssue.negativeNet});
    });

    test('D-080 (6) a month with no work and no item of its own, only a late correction taking money back, waits for the next pay', () {
      const back = WorkLine('2026-09-15', 0, alreadyPaidFils: 10000);
      final waiting = figures(work: const [back]);
      expect((waiting.netFils, waiting.adjustmentFils), (0, -10000));
      expect(waiting.issues, {PayrollIssue.takesBackLater});
      expect(figures(work: const [back, WorkLine('2026-10-15', 15000)]).issues, isEmpty, reason: 'next pay with work takes it off');
      expect(figures(work: const [back], items: const [PayItemLine(PayItemKind.allowance, 5000)]).issues, {PayrollIssue.negativeNet}, reason: 'a month with an item of its own still stops');
      expect(figures(work: const [back], contracts: [monthly(5000)]).issues, {PayrollIssue.negativeNet}, reason: 'and so does one with a salary');
    });

    test('no limit is built in, and a company limit counts recovery too', () {
      const work = [WorkLine('2026-10-15', 100000)];
      const items = [PayItemLine(PayItemKind.roomCharge, 40000), PayItemLine(PayItemKind.advanceRecovery, 10001)];
      expect(figures(work: work, items: items, advanceLeft: 10001).issues, isEmpty);
      expect(figures(work: work, items: items, advanceLeft: 10001, limitBps: 5000).issues, {PayrollIssue.deductionAboveLimit});
      expect(figures(work: work, items: const [PayItemLine(PayItemKind.roomCharge, 50000)], limitBps: 5000).issues, isEmpty);
    });
  });

  test('a row not yet approved stops that worker for review (CALC-06)', () {
    expect(figures(unpriced: 2).issues, {PayrollIssue.missingRate});
  });

  group('TC-019 monthly pay once per period (CALC-04)', () {
    test('a full month is the amount exactly, whatever the attendance rows', () {
      final f = figures(contracts: [monthly(200000)], work: const [WorkLine('2026-10-01', 0), WorkLine('2026-10-02', 0)]);
      expect(f.salaryFils, 200000);
      expect(f.issues, isEmpty);
    });

    test("a part month needs the contract's method", () {
      expect(figures(contracts: [monthly(310000, from: '2026-10-22')]).issues, {PayrollIssue.missingPartialMethod});
      final f = figures(contracts: [monthly(310000, from: '2026-10-22', method: PartialMethod.calendarDays)]);
      expect(f.salaryFils, 100000);
    });

    test('a raise mid-month splits by days, and overlapping contracts never pay twice', () {
      final raise = [
        monthly(310000, to: '2026-10-21', method: PartialMethod.calendarDays),
        monthly(620000, from: '2026-10-22', method: PartialMethod.calendarDays),
      ];
      expect(figures(contracts: raise).salaryFils, 210000 + 200000);
      expect(figures(contracts: [monthly(200000), monthly(900000, site: 'site-1')]).salaryFils, 200000);
    });

    group('D-080 (7) when monthly contracts cover the whole month between them, each part is its share of the month by its days', () {
      const divisor = PartialMethod.fixedDivisor;

      test('the same salary either side of a change pays exactly one month, by a fixed divisor too', () {
        final same = [monthly(300000, to: '2026-10-15', method: divisor, divisor: 30), monthly(300000, from: '2026-10-16', method: divisor, divisor: 30)];
        expect(figures(contracts: same).salaryFils, 300000, reason: 'not 1,500 + 1,600 = 3,100 by a divisor of 30 in a 31-day month');
        expect(figures(contracts: [monthly(300000, method: divisor, divisor: 30)]).salaryFils, 300000, reason: 'one contract for the whole month is its amount exactly');
      });

      test('a raise in February pays between the two salaries', () {
        final raise = [monthly(300000, to: '2026-02-14', method: divisor, divisor: 30), monthly(330000, from: '2026-02-15', method: divisor, divisor: 30)];
        // 3,000 x 14/28 + 3,300 x 14/28, where the divisor would give 1,400 + 1,540 = 2,940, less than either month.
        expect(figures(contracts: raise, period: '2026-02', current: '2026-02').salaryFils, 315000);
      });

      test("a month joined or left part way is still the contract's own rule, and calendar days pay as before", () {
        expect(figures(contracts: [monthly(300000, from: '2026-10-22', method: divisor, divisor: 30)]).salaryFils, 100000);
        expect(figures(contracts: [monthly(300000, to: '2026-10-10', method: divisor, divisor: 30)]).salaryFils, 100000);
        final joinedThenRaised = [monthly(300000, from: '2026-10-12', to: '2026-10-21', method: divisor, divisor: 30), monthly(600000, from: '2026-10-22', method: divisor, divisor: 30)];
        expect(figures(contracts: joinedThenRaised).salaryFils, 100000 + 200000);
        expect(figures(contracts: [monthly(310000, from: '2026-10-22', method: PartialMethod.calendarDays)]).salaryFils, 100000);
        final calendar = [
          monthly(310000, to: '2026-10-21', method: PartialMethod.calendarDays),
          monthly(620000, from: '2026-10-22', method: PartialMethod.calendarDays),
        ];
        expect(figures(contracts: calendar).salaryFils, 410000);
      });
    });

    test('a daily worker has no period pay', () {
      const day = RateTerms(basis: RateBasis.day, rateFils: 7000, effectiveFrom: '2026-01-01');
      expect(periodSalary(const [day], month)?.fils, 0);
    });

    test('approved overtime on a monthly contract is earned per line, at its own rate (CALC-07)', () {
      const terms = RateTerms(basis: RateBasis.month, rateFils: 200000, effectiveFrom: '2026-01-01', includedMinutes: 480, overtimeRateFils: 1200);
      const present = AttendanceStatus.present;
      expect(priceLine(terms, status: present, minutes: 540, overtimeApproved: false).amountFils, isNull);
      expect(priceLine(terms, status: present, minutes: 540, overtimeApproved: true).amountFils, 1200);
      const noRate = RateTerms(basis: RateBasis.month, rateFils: 200000, effectiveFrom: '2026-01-01', includedMinutes: 480);
      expect(priceLine(noRate, status: present, minutes: 540, overtimeApproved: true).issue, LineIssue.missingOvertimeRate);
    });
  });

  test("work from an earlier period stays out of this month's earnings (PAY-02, ATT-08)", () {
    final f = figures(work: const [WorkLine('2026-10-15', 10000), WorkLine('2026-09-20', 7000), WorkLine('2026-09-21', 9000, alreadyPaidFils: 7000)]);
    expect(f.earnedFils, 10000);
    expect(f.adjustmentFils, 9000);
    expect(f.netFils, 10000);
    expect(f.dueFils, 19000);
  });

  group('month order', () {
    test('a later posted month blocks going back', () {
      final behind = figures(contracts: [monthly(200000)], work: const [WorkLine('2026-10-15', 7000)], lastPosted: '2026-11', current: '2026-11');
      expect(behind.issues, {PayrollIssue.laterMonthPosted});
      expect(behind.salaryFils, 0, reason: 'its salary cannot post any more, so it must not show');
      expect(behind.earnedFils, 7000, reason: 'late rows carry into the next payroll');
    });

    test('skipping a month blocks a monthly worker, but not one with no contract that month', () {
      expect(figures(contracts: [monthly(200000)], lastPosted: '2026-08').issues, {PayrollIssue.earlierMonthMissing});
      expect(figures(contracts: [monthly(200000)], lastPosted: '2026-09').issues, isEmpty);
      expect(figures(contracts: [monthly(200000, from: '2026-10-01')], lastPosted: '2026-08').issues, isEmpty);
      expect(figures(lastPosted: '2026-08').issues, isEmpty);
    });

    test('a month that has not started cannot be posted', () {
      expect(figures(period: '2026-11').issues, {PayrollIssue.monthNotStarted});
    });
  });

  test('room charge through payroll counts as rent received for that room (D-031)', () {
    final result = roomResult(const [CashLine(CashKind.roomRentPaid, 50000), CashLine(CashKind.roomRentReceived, 10000)], deductedFils: 20000);
    expect(result.receivedFils, 30000);
    expect(result.netFils, -20000);
  });
}
