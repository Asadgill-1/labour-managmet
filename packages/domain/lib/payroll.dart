import 'dart:math';

import 'calc.dart';
import 'cash.dart';
import 'dates.dart';
import 'money.dart';

/// What a payroll item is. Stored by name. Room charge and other deductions need an authorization (PAY-07).
/// Recovery comes off the worker's advance (PAY-05), and a visa instalment off their visa money (D-039).
enum PayItemKind { allowance, deduction, roomCharge, advanceRecovery, visaRecovery }

/// Why one worker's month cannot be posted yet. It stops for review and nothing changes silently (CALC-06, PAY-07).
enum PayrollIssue {
  missingRate,
  missingPartialMethod,
  negativeNet,
  recoveryAboveAdvance,
  recoveryAboveVisa,
  deductionAboveLimit,
  earlierMonthMissing,
  laterMonthPosted,
  monthNotStarted,
  monthClosed,

  /// An advance with no instalment is left, and the owner has not said how much of it to cut this month (D-057).
  recoveryNotAnswered,
}

class PayItemLine {
  const PayItemLine(this.kind, this.amountFils);

  final PayItemKind kind;
  final int amountFils;
}

/// An attendance row with its pay worked out, that no posted payroll holds yet. [alreadyPaidFils] is what the row it corrects
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
    this.visaFils = 0,
    this.absenceFils = 0,
    this.absentDays = const [],
    this.issues = const {},
  });

  /// Attendance dated in this period.
  final int earnedFils;

  /// Monthly contract pay, counted once (CALC-04), less [absenceFils].
  final int salaryFils;

  /// What days with no attendance took off the salary, and those days (D-057).
  final int absenceFils;
  final List<String> absentDays;

  /// Work dated before this period, or the difference from correcting it. Kept out of this month's net (PAY-02).
  final int adjustmentFils;
  final int allowancesFils;

  /// Room charge and other deductions.
  final int deductionsFils;
  final int recoveryFils;
  final int visaFils;
  final Set<PayrollIssue> issues;

  int get grossFils => earnedFils + salaryFils;
  int get netFils => grossFils + allowancesFils - deductionsFils - recoveryFils - visaFils;

  /// What posting adds to the worker's account.
  int get dueFils => netFils + adjustmentFils;
  bool get isEmpty => grossFils == 0 && adjustmentFils == 0 && allowancesFils == 0 && deductionsFils == 0 && recoveryFils == 0 && visaFils == 0;
}

/// A worker's monthly pay for one period (CALC-04). Each day goes to one contract, so overlapping contracts never pay
/// twice. On a contract that cuts absence, a day up to [through] with no attendance in [present], that is no weekly day
/// off and not [excused] by the owner, is cut at the contract's own part-month rule, so no legal default is built
/// (D-057). No [through] cuts nothing. Null when a part period or a cut has no method: stop for review (D-102).
({int fils, int cutFils, List<String> absent})? periodSalary(
  Iterable<RateTerms> contracts,
  String month, {
  Set<String> present = const {},
  Set<String> excused = const {},
  String? through,
}) {
  final monthly = contracts.where((c) => c.basis == RateBasis.month).toList()
    ..sort((a, b) {
      final general = (a.siteId == null ? 0 : 1).compareTo(b.siteId == null ? 0 : 1);
      return general != 0 ? general : b.effectiveFrom.compareTo(a.effectiveFrom);
    });
  final last = monthLastDay(month);
  final covered = <RateTerms, int>{};
  final absent = <RateTerms, List<String>>{};
  var days = 0;
  for (var day = monthFirstDay(month); day.compareTo(last) <= 0; day = addDays(day, 1)) {
    days++;
    final contract = monthly.where((c) => c.coversDate(day)).firstOrNull;
    if (contract == null) continue;
    covered[contract] = (covered[contract] ?? 0) + 1;
    if (contract.cutAbsence &&
        through != null &&
        day.compareTo(through) <= 0 &&
        !present.contains(day) &&
        !excused.contains(day) &&
        !contract.offWeekdays.contains(weekdayOf(day))) {
      (absent[contract] ??= []).add(day);
    }
  }
  var total = 0;
  var cut = 0;
  for (final MapEntry(key: c, value: coveredDays) in covered.entries) {
    final pay = monthlySalary(monthlyFils: c.rateFils, coveredDays: coveredDays, daysInPeriod: days, method: c.partialMethod, fixedDivisor: c.partialDivisor);
    if (pay == null) return null;
    final off = absent[c]?.length ?? 0;
    final perDay = switch (c.partialMethod) {
      PartialMethod.calendarDays => days,
      PartialMethod.fixedDivisor when (c.partialDivisor ?? 0) > 0 => c.partialDivisor,
      _ => null,
    };
    if (off > 0 && perDay == null) return null;
    // A fixed divisor below the month's days could cut more than the month pays.
    final less = off == 0 ? 0 : min(pay, divRoundHalfUp(c.rateFils * off, perDay!));
    total += pay - less;
    cut += less;
  }
  return (fils: total, cutFils: cut, absent: [for (final d in absent.values) ...d]..sort());
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
  int visaLeftFils = 0,
  int unpricedRows = 0,
  String? lastPostedMonth,
  String? closedMonth,
  int? limitBps,
  Set<String> present = const {},
  Set<String> excused = const {},
  String? through,
  bool askRecovery = false,
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
  final closed = closedMonth != null && month.compareTo(closedMonth) <= 0;
  // A month behind the latest posted one cannot pay a salary any more, and nor can a closed one. Only late rows carry forward.
  final pay = later || closed ? (fils: 0, cutFils: 0, absent: const <String>[]) : periodSalary(contracts, month, present: present, excused: excused, through: through);
  final salary = pay?.fils;
  final allowances = sum(const {PayItemKind.allowance});
  final deductions = sum(const {PayItemKind.deduction, PayItemKind.roomCharge});
  final recovery = sum(const {PayItemKind.advanceRecovery});
  final visa = sum(const {PayItemKind.visaRecovery});
  final earnings = earned + (salary ?? 0) + allowances;
  final net = earnings - deductions - recovery - visa;

  final issues = <PayrollIssue>{
    if (month.compareTo(currentMonth) > 0) PayrollIssue.monthNotStarted,
    if (unpricedRows > 0) PayrollIssue.missingRate,
    if (salary == null) PayrollIssue.missingPartialMethod,
    if (recovery > advanceLeftFils) PayrollIssue.recoveryAboveAdvance,
    if (visa > visaLeftFils) PayrollIssue.recoveryAboveVisa,
    if (limitBps != null && (deductions + recovery + visa) * 10000 > earnings * limitBps) PayrollIssue.deductionAboveLimit,
    if (later) PayrollIssue.laterMonthPosted,
    if (closed) PayrollIssue.monthClosed,
    if (askRecovery) PayrollIssue.recoveryNotAnswered,
    if (lastPostedMonth != null)
      for (var m = addMonths(lastPostedMonth, 1); m.compareTo(month) < 0; m = addMonths(m, 1))
        // A closed month can no longer be posted, so it never holds up a later one (REP-04).
        if ((closedMonth == null || m.compareTo(closedMonth) > 0) && _monthlyCovers(contracts, m)) PayrollIssue.earlierMonthMissing,
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
    visaFils: visa,
    absenceFils: pay?.cutFils ?? 0,
    absentDays: pay?.absent ?? const [],
    issues: issues,
  );
}

/// What a worker is owed now: opening + everything posted - every salary payment. Always derived, never stored (REP-08).
/// Below zero means paid too much, which is a credit and never a negative salary (PAY-06).
int salaryOwed(int openingFils, int postedFils, Iterable<CashLine> lines) => openingFils + postedFils - salaryPaidTotal(lines);
