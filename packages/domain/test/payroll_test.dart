import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:test/test.dart';

const month = '2026-10';

PayrollFigures figures({
  Iterable<WorkLine> work = const [],
  Iterable<RateTerms> contracts = const [],
  Iterable<PayItemLine> items = const [],
  int advanceLeft = 0,
  int unapproved = 0,
  String? lastPosted,
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
    unapprovedRows: unapproved,
    lastPostedMonth: lastPosted,
    limitBps: limitBps,
  );
}

RateTerms monthly(int fils, {String from = '2026-01-01', String? to, PartialMethod? method, int? divisor, String? site}) {
  return RateTerms(basis: RateBasis.month, rateFils: fils, effectiveFrom: from, effectiveTo: to, partialMethod: method, partialDivisor: divisor, siteId: site);
}

void main() {
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

    test('no limit is built in, and a company limit counts recovery too', () {
      const work = [WorkLine('2026-10-15', 100000)];
      const items = [PayItemLine(PayItemKind.roomCharge, 40000), PayItemLine(PayItemKind.advanceRecovery, 10001)];
      expect(figures(work: work, items: items, advanceLeft: 10001).issues, isEmpty);
      expect(figures(work: work, items: items, advanceLeft: 10001, limitBps: 5000).issues, {PayrollIssue.deductionAboveLimit});
      expect(figures(work: work, items: const [PayItemLine(PayItemKind.roomCharge, 50000)], limitBps: 5000).issues, isEmpty);
    });
  });

  test('a row not yet approved stops that worker for review (CALC-06)', () {
    expect(figures(unapproved: 2).issues, {PayrollIssue.unapprovedWork});
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

    test('a daily worker has no period pay', () {
      const day = RateTerms(basis: RateBasis.day, rateFils: 7000, effectiveFrom: '2026-01-01');
      expect(periodSalary(const [day], month), 0);
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
