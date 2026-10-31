import 'calc.dart';
import 'cash.dart';
import 'dates.dart';

/// What a payroll item is. Stored by name. Room charge and other deductions need an authorization (PAY-07).
/// Recovery comes off the worker's advance (PAY-05).
enum PayItemKind { allowance, deduction, roomCharge, advanceRecovery }

/// Why one worker's month cannot be posted yet. It stops for review and nothing changes silently (CALC-06, PAY-07).
enum PayrollIssue {
  unapprovedWork,
  missingPartialMethod,
  negativeNet,
  recoveryAboveAdvance,
  deductionAboveLimit,
  earlierMonthMissing,
  laterMonthPosted,
  monthNotStarted,
}

class PayItemLine {
  const PayItemLine(this.kind, this.amountFils);

  final PayItemKind kind;
  final int amountFils;
}

/// An approved attendance row that no posted payroll holds yet. [alreadyPaidFils] is what the row it corrects
/// was already paid, so only the difference is due (ATT-08).
class WorkLine {
  const WorkLine(this.workDate, this.amountFils, {this.alreadyPaidFils = 0});

  final String workDate;
  final int amountFils;
  final int alreadyPaidFils;
}

class PayrollFigures {
  const PayrollFigures({
    this.earnedFils = 0,
    this.salaryFils = 0,
    this.adjustmentFils = 0,
    this.allowancesFils = 0,
    this.deductionsFils = 0,
    this.recoveryFils = 0,
    this.issues = const {},
  });

  /// Attendance dated in this period.
  final int earnedFils;

  /// Monthly contract pay, counted once (CALC-04).
  final int salaryFils;

  /// Work dated before this period, or the difference from correcting it. Kept out of this month's net (PAY-02).
  final int adjustmentFils;
  final int allowancesFils;

  /// Room charge and other deductions.
  final int deductionsFils;
  final int recoveryFils;
  final Set<PayrollIssue> issues;

  int get grossFils => earnedFils + salaryFils;
  int get netFils => grossFils + allowancesFils - deductionsFils - recoveryFils;

  /// What posting adds to the worker's account.
  int get dueFils => netFils + adjustmentFils;
  bool get isEmpty => grossFils == 0 && adjustmentFils == 0 && allowancesFils == 0 && deductionsFils == 0 && recoveryFils == 0;
}

/// A worker's monthly pay for one period, whatever the attendance rows (CALC-04). Each day goes to one contract,
/// so overlapping contracts never pay twice. Null when a part period has no method: stop for review (D-102).
int? periodSalary(Iterable<RateTerms> contracts, String month) {
  final monthly = contracts.where((c) => c.basis == RateBasis.month).toList()
    ..sort((a, b) {
      final general = (a.siteId == null ? 0 : 1).compareTo(b.siteId == null ? 0 : 1);
      return general != 0 ? general : b.effectiveFrom.compareTo(a.effectiveFrom);
    });
  final last = monthLastDay(month);
  final covered = <RateTerms, int>{};
  var days = 0;
  for (var day = monthFirstDay(month); day.compareTo(last) <= 0; day = addDays(day, 1)) {
    days++;
    final contract = monthly.where((c) => c.coversDate(day)).firstOrNull;
    if (contract != null) covered[contract] = (covered[contract] ?? 0) + 1;
  }
  var total = 0;
  for (final MapEntry(key: c, value: coveredDays) in covered.entries) {
    final pay = monthlySalary(monthlyFils: c.rateFils, coveredDays: coveredDays, daysInPeriod: days, method: c.partialMethod, fixedDivisor: c.partialDivisor);
    if (pay == null) return null;
    total += pay;
  }
  return total;
}

bool _monthlyCovers(Iterable<RateTerms> contracts, String month) {
  return contracts.any((c) => c.basis == RateBasis.month && datesOverlap(c.effectiveFrom, c.effectiveTo, monthFirstDay(month), monthLastDay(month)));
}

/// One worker's month before posting (PAY-01). [limitBps] is the company's own deduction limit, as a share of
/// earnings. No limit is built in, because that is law for a reviewer to configure (PAY-07).
PayrollFigures workerPayroll({
  required String month,
  required String currentMonth,
  required Iterable<WorkLine> work,
  required Iterable<RateTerms> contracts,
  required Iterable<PayItemLine> items,
  required int advanceLeftFils,
  int unapprovedRows = 0,
  String? lastPostedMonth,
  int? limitBps,
}) {
  final from = monthFirstDay(month);
  var earned = 0;
  var adjustment = 0;
  for (final w in work) {
    final due = w.amountFils - w.alreadyPaidFils;
    if (w.workDate.compareTo(from) < 0) {
      adjustment += due;
    } else {
      earned += due;
    }
  }
  int sum(Set<PayItemKind> kinds) => items.where((i) => kinds.contains(i.kind)).fold(0, (total, i) => total + i.amountFils);
  final later = lastPostedMonth != null && lastPostedMonth.compareTo(month) >= 0;
  // A month behind the latest posted one cannot pay a salary any more. Only its late rows carry forward.
  final salary = later ? 0 : periodSalary(contracts, month);
  final allowances = sum(const {PayItemKind.allowance});
  final deductions = sum(const {PayItemKind.deduction, PayItemKind.roomCharge});
  final recovery = sum(const {PayItemKind.advanceRecovery});
  final earnings = earned + (salary ?? 0) + allowances;
  final net = earnings - deductions - recovery;

  final issues = <PayrollIssue>{
    if (month.compareTo(currentMonth) > 0) PayrollIssue.monthNotStarted,
    if (unapprovedRows > 0) PayrollIssue.unapprovedWork,
    if (salary == null) PayrollIssue.missingPartialMethod,
    if (recovery > advanceLeftFils) PayrollIssue.recoveryAboveAdvance,
    if (limitBps != null && (deductions + recovery) * 10000 > earnings * limitBps) PayrollIssue.deductionAboveLimit,
    if (later) PayrollIssue.laterMonthPosted,
    if (lastPostedMonth != null)
      for (var m = addMonths(lastPostedMonth, 1); m.compareTo(month) < 0; m = addMonths(m, 1))
        if (_monthlyCovers(contracts, m)) PayrollIssue.earlierMonthMissing,
    // Never carried as debt by itself (D-104).
    if (net < 0 || net + adjustment < 0) PayrollIssue.negativeNet,
  };
  return PayrollFigures(
    earnedFils: earned,
    salaryFils: salary ?? 0,
    adjustmentFils: adjustment,
    allowancesFils: allowances,
    deductionsFils: deductions,
    recoveryFils: recovery,
    issues: issues,
  );
}

/// What a worker is owed now: opening + everything posted - every salary payment. Always derived, never stored (REP-08).
/// Below zero means paid too much, which is a credit and never a negative salary (PAY-06).
int salaryOwed(int openingFils, int postedFils, Iterable<CashLine> lines) => openingFils + postedFils - salaryPaidTotal(lines);
