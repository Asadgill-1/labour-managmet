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

  /// No work and no item of the month's own, only a late correction taking money back. Nothing negative posts (D-104):
  /// the minus waits for the next pay, and the month can still close (D-080 (6)).
  takesBackLater,
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
  /// A salary cut whole for absence is not empty, since the cut shows day by day (D-057).
  bool get isEmpty => grossFils == 0 && absenceFils == 0 && adjustmentFils == 0 && allowancesFils == 0 && deductionsFils == 0 && recoveryFils == 0 && visaFils == 0;
}

/// The monthly contract that pays [day]: a general one before a site's, then the latest start. Each day goes to one
/// contract, so overlapping contracts never pay twice (CALC-04).
RateTerms? salaryContractOn(Iterable<RateTerms> contracts, String day) => (contracts.where((c) => c.basis == RateBasis.month && c.coversDate(day)).toList()
      ..sort((a, b) {
        final general = (a.siteId == null ? 0 : 1).compareTo(b.siteId == null ? 0 : 1);
        return general != 0 ? general : b.effectiveFrom.compareTo(a.effectiveFrom);
      }))
    .firstOrNull;

/// A day with no attendance cuts [contract]'s salary: the contract cuts absence and the day is no weekly day off (D-057).
bool cutsOn(RateTerms contract, String day) => contract.cutAbsence && !contract.offWeekdays.contains(weekdayOf(day));

int _lcm(int a, int b) => a ~/ a.gcd(b) * b;

/// A worker's monthly pay for one period (CALC-04). When the monthly contracts cover the whole month between them, each
/// part is its share of the month by its days, so one salary either side of a change pays one month exactly (D-080 (7)).
/// A month joined or left part way is each contract's own part-month rule. On a contract that cuts absence, a day up to
/// [through] with no attendance in [present], that is no weekly day off and not [excused] by the owner, is cut at the
/// contract's own rule, so no legal default is built (D-057). No [through] cuts nothing. The pay and what is left of it
/// after the cut each round once (D-101). Null when a part period or a cut has no method: stop for review (D-102).
({int fils, int cutFils, List<String> absent})? periodSalary(
  Iterable<RateTerms> contracts,
  String month, {
  Set<String> present = const {},
  Set<String> excused = const {},
  String? through,
}) {
  final monthly = contracts.where((c) => c.basis == RateBasis.month).toList();
  final last = monthLastDay(month);
  final covered = <RateTerms, int>{};
  final absent = <RateTerms, List<String>>{};
  var days = 0;
  for (var day = monthFirstDay(month); day.compareTo(last) <= 0; day = addDays(day, 1)) {
    days++;
    final contract = salaryContractOn(monthly, day);
    if (contract == null) continue;
    covered[contract] = (covered[contract] ?? 0) + 1;
    if (through != null && day.compareTo(through) <= 0 && !present.contains(day) && !excused.contains(day) && cutsOn(contract, day)) {
      (absent[contract] ??= []).add(day);
    }
  }
  final whole = covered.values.fold(0, (total, n) => total + n) == days;
  int? ownRule(RateTerms c) => switch (c.partialMethod) {
    PartialMethod.calendarDays => days,
    PartialMethod.fixedDivisor when (c.partialDivisor ?? 0) > 0 => c.partialDivisor,
    _ => null,
  };
  // Every part over one denominator, so the sums are exact before their one rounding.
  // ponytail: rate x days x denominator stays in 64 bits up to about AED 10^12 a month even with mixed divisors.
  var units = 1;
  for (final c in covered.keys) {
    final share = whole ? days : ownRule(c);
    final cut = absent.containsKey(c) ? ownRule(c) : 1;
    if (share == null || cut == null) return null;
    units = _lcm(_lcm(units, share), cut);
  }
  var pay = 0;
  var left = 0;
  for (final MapEntry(key: c, value: n) in covered.entries) {
    final part = c.rateFils * n * (units ~/ (whole ? days : ownRule(c)!));
    final off = absent[c]?.length ?? 0;
    pay += part;
    // A fixed divisor below the month's days could cut more than the part pays.
    left += off == 0 ? part : max(0, part - c.rateFils * off * (units ~/ ownRule(c)!));
  }
  final fils = divRoundHalfUp(left, units);
  return (fils: fils, cutFils: divRoundHalfUp(pay, units) - fils, absent: [for (final d in absent.values) ...d]..sort());
}

/// What attendance added after posting gives back of a posted month's absence cut, day by day in date order (D-080 (5)).
/// [cutDays] are the days the posting cut for [cutFils], [back] those a later posting gave back already, and [worked] those
/// with attendance now. Each day gives the cut on the days still missing before it less the cut after it, priced as the
/// posting priced it, so the days together give back exactly the cut, never a fil more.
Map<String, int> cutGivenBack(Iterable<RateTerms> contracts, String month, {required int cutFils, required List<String> cutDays, Set<String> back = const {}, required Set<String> worked}) {
  final terms = contracts.toList();
  final last = monthLastDay(month);
  final missing = {...cutDays}..removeAll(back);
  // Null only if a contract lost its rule since, and then nothing more is given back.
  int? cutOnMissing() => periodSalary(terms, month, present: {for (var d = monthFirstDay(month); d.compareTo(last) <= 0; d = addDays(d, 1)) if (!missing.contains(d)) d}, through: last)?.cutFils;
  int? left;
  final given = <String, int>{};
  for (final day in cutDays) {
    if (back.contains(day) || !worked.contains(day)) continue;
    left ??= missing.length == cutDays.length ? cutFils : cutOnMissing() ?? 0;
    missing.remove(day);
    final after = cutOnMissing() ?? left;
    given[day] = left - after;
    left = after;
  }
  return given;
}

bool _monthlyCovers(Iterable<RateTerms> contracts, String month) {
  return contracts.any((c) => c.basis == RateBasis.month && datesOverlap(c.effectiveFrom, c.effectiveTo, monthFirstDay(month), monthLastDay(month)));
}

/// One worker's month before posting (PAY-01). [limitBps] is the company's own deduction limit, as a share of
/// earnings. No limit is built in, because that is law for a reviewer to configure (PAY-07). With nothing posted yet,
/// [firstMonth] is the month the worker's account starts counting a salary from, so no month from then on can be skipped (D-042 (5)).
/// [itemMonths] are earlier months still holding an item no line has taken: this month waits for them, or they could never post.
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
  String? firstMonth,
  Set<String> itemMonths = const {},
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
  final checkFrom = lastPostedMonth != null ? addMonths(lastPostedMonth, 1) : firstMonth;
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
    if (checkFrom != null)
      for (var m = checkFrom; m.compareTo(month) < 0; m = addMonths(m, 1))
        // A closed month can no longer be posted, so it never holds up a later one (REP-04).
        if ((closedMonth == null || m.compareTo(closedMonth) > 0) && _monthlyCovers(contracts, m)) PayrollIssue.earlierMonthMissing,
    for (final m in itemMonths)
      if (m.compareTo(month) < 0 && (closedMonth == null || m.compareTo(closedMonth) > 0)) PayrollIssue.earlierMonthMissing,
    // Never carried as debt by itself (D-104). With no work and no item of the month's own, the minus waits (D-080 (6)).
    if (net < 0 || net + adjustment < 0) earned == 0 && salary == 0 && items.isEmpty ? PayrollIssue.takesBackLater : PayrollIssue.negativeNet,
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
