import 'dates.dart';
import 'money.dart';

/// How a contract is priced. Stored by name. `month` is a worker's salary;
/// `monthPerWorker` and `monthFixed` are client billing (CALC-04, CALC-05).
enum RateBasis { hour, day, shift, month, monthPerWorker, monthFixed }

/// Paid per payroll or billing period, so an attendance line carries no amount of its own.
bool isPeriodBasis(RateBasis basis) => const {RateBasis.month, RateBasis.monthPerWorker, RateBasis.monthFixed}.contains(basis);

/// How a monthly contract handles a part period. Chosen per contract, no default (D-102).
enum PartialMethod { calendarDays, fixedDivisor }

enum AttendanceStatus { present, half, absent }

/// Why a line cannot be priced. The row stops for review; it never silently becomes zero (CALC-06).
enum LineIssue { missingRate, missingHalfAmount, missingOvertimeRate }

class RateTerms {
  const RateTerms({
    required this.basis,
    required this.rateFils,
    required this.effectiveFrom,
    this.effectiveTo,
    this.breakPaid = false,
    this.halfAmountFils,
    this.includedMinutes,
    this.overtimeRateFils,
    this.siteId,
    this.workerId,
  });

  final RateBasis basis;
  final int rateFils;
  final String effectiveFrom;
  final String? effectiveTo;
  final bool breakPaid;
  final int? halfAmountFils;
  final int? includedMinutes;
  final int? overtimeRateFils;
  final String? siteId;
  final String? workerId;

  bool coversDate(String date) => effectiveFrom.compareTo(date) <= 0 && (effectiveTo == null || effectiveTo!.compareTo(date) >= 0);
}

/// Picks the rate for one date (CALC-06). Worker plus site beats worker, which beats site, which beats
/// the general contract. An entry-level override is applied by the caller, above all of these.
/// Between equally specific contracts, the latest start wins.
RateTerms? pickRate(Iterable<RateTerms> contracts, {required String date, required String siteId, required String workerId}) {
  int specificity(RateTerms c) => (c.workerId != null ? 2 : 0) + (c.siteId != null ? 1 : 0);
  final matching = contracts
      .where((c) => c.coversDate(date) && (c.siteId == null || c.siteId == siteId) && (c.workerId == null || c.workerId == workerId))
      .toList()
    ..sort((a, b) {
      final bySpecificity = specificity(b).compareTo(specificity(a));
      return bySpecificity != 0 ? bySpecificity : b.effectiveFrom.compareTo(a.effectiveFrom);
    });
  return matching.isEmpty ? null : matching.first;
}

/// A shift's UTC times from a stored date and UAE clock times. An end at or before the start is next day (ATT-06).
({DateTime startUtc, DateTime endUtc}) shiftTimes(String workDate, int startMinute, int endMinute) {
  final start = dubaiToUtc(workDate, startMinute);
  var end = dubaiToUtc(workDate, endMinute);
  if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  return (startUtc: start, endUtc: end);
}

int clockMinutes(DateTime startUtc, DateTime endUtc) => endUtc.difference(startUtc).inMinutes;

bool isValidBreak(int breakMinutes, int clock) => breakMinutes >= 0 && breakMinutes <= clock;

/// Minutes one side counts. Client and worker sides can differ for the same shift (CALC-02).
int countedMinutes(int clock, int breakMinutes, {required bool breakPaid}) => breakPaid ? clock : clock - breakMinutes;

class LineAmount {
  const LineAmount({this.amountFils, this.regularMinutes = 0, this.overtimeMinutes = 0, this.issue});

  /// Null when the amount belongs to the period, or when [issue] is set.
  final int? amountFils;
  final int regularMinutes;
  final int overtimeMinutes;
  final LineIssue? issue;
}

/// The amount for one attendance line under one contract (CALC-02, CALC-03, CALC-07).
///
/// Overtime exists only past a contract's included minutes, and is paid only if approved at the
/// contract's own overtime rate. Approved overtime with no such rate stops for review. There is no
/// multiplier anywhere: extra hours never get an automatic one.
LineAmount priceLine(RateTerms? terms, {required AttendanceStatus status, required int minutes, required bool overtimeApproved}) {
  if (terms == null) return const LineAmount(issue: LineIssue.missingRate);
  if (status == AttendanceStatus.absent) return const LineAmount(amountFils: 0);

  final included = terms.includedMinutes;
  final overtime = included != null && minutes > included ? minutes - included : 0;
  final regular = minutes - overtime;
  if (isPeriodBasis(terms.basis)) return LineAmount(regularMinutes: regular, overtimeMinutes: overtime);

  int base;
  if (terms.basis == RateBasis.hour) {
    base = divRoundHalfUp(regular * terms.rateFils, 60);
  } else if (status == AttendanceStatus.half) {
    final half = terms.halfAmountFils;
    if (half == null) return LineAmount(regularMinutes: regular, issue: LineIssue.missingHalfAmount);
    base = half;
  } else {
    base = terms.rateFils;
  }

  if (overtime == 0 || !overtimeApproved) {
    return LineAmount(amountFils: base, regularMinutes: regular, overtimeMinutes: overtime);
  }
  final overtimeRate = terms.overtimeRateFils;
  if (overtimeRate == null) {
    return LineAmount(regularMinutes: regular, overtimeMinutes: overtime, issue: LineIssue.missingOvertimeRate);
  }
  return LineAmount(
    amountFils: base + divRoundHalfUp(overtime * overtimeRate, 60),
    regularMinutes: regular,
    overtimeMinutes: overtime,
  );
}

/// A worker's monthly salary for one payroll period, counted once whatever the attendance rows (CALC-04).
/// A full period is the monthly amount exactly. A part period needs the contract's method, otherwise null: stop for review.
int? monthlySalary({
  required int monthlyFils,
  required int coveredDays,
  required int daysInPeriod,
  PartialMethod? method,
  int? fixedDivisor,
}) {
  if (coveredDays >= daysInPeriod) return monthlyFils;
  return switch (method) {
    PartialMethod.calendarDays => divRoundHalfUp(monthlyFils * coveredDays, daysInPeriod),
    PartialMethod.fixedDivisor when fixedDivisor != null && fixedDivisor > 0 => divRoundHalfUp(monthlyFils * coveredDays, fixedDivisor),
    _ => null,
  };
}

/// A client's monthly charge. A fixed contract is one fee, never multiplied by worker rows (CALC-05).
int clientMonthlyCharge(RateBasis basis, {required int rateFils, required int workerCount}) {
  return basis == RateBasis.monthFixed ? rateFils : rateFils * workerCount;
}

/// Two shifts overlap if they share any time. One ending exactly as the next starts does not (ATT-05).
bool shiftsOverlap(DateTime startA, DateTime endA, DateTime startB, DateTime endB) => startA.isBefore(endB) && startB.isBefore(endA);

/// Two contract date ranges, where a null end means open-ended. Both ends are inclusive.
bool datesOverlap(String fromA, String? toA, String fromB, String? toB) {
  return (toB == null || fromA.compareTo(toB) <= 0) && (toA == null || fromB.compareTo(toA) <= 0);
}

/// Information only, never an input to an amount (ATT-09).
({int uniqueWorkers, int shifts, int workerDays}) attendanceCounts(Iterable<({String workerId, String workDate, AttendanceStatus status})> rows) {
  final worked = rows.where((r) => r.status != AttendanceStatus.absent).toList();
  return (
    uniqueWorkers: worked.map((r) => r.workerId).toSet().length,
    shifts: worked.length,
    workerDays: worked.map((r) => '${r.workerId}|${r.workDate}').toSet().length,
  );
}

/// One worker's shift as entered. Null break flags mean "as the contract says".
class ShiftInput {
  const ShiftInput({
    this.status = AttendanceStatus.present,
    this.startMinute,
    this.endMinute,
    this.breakMinutes = 0,
    this.breakPaidClient,
    this.breakPaidWorker,
    this.overtimeApproved = false,
    this.clientOverrideFils,
    this.workerOverrideFils,
  });

  final AttendanceStatus status;
  final int? startMinute;
  final int? endMinute;
  final int breakMinutes;
  final bool? breakPaidClient;
  final bool? breakPaidWorker;
  final bool overtimeApproved;
  final int? clientOverrideFils;
  final int? workerOverrideFils;
}

class PricedShift {
  const PricedShift({
    this.startUtc,
    this.endUtc,
    required this.clockMinutes,
    required this.breakValid,
    required this.breakPaidClient,
    required this.breakPaidWorker,
    required this.clientMinutes,
    required this.workerMinutes,
    required this.client,
    required this.worker,
    this.clientBasis,
    this.clientRateFils,
    this.workerBasis,
    this.workerRateFils,
  });

  final DateTime? startUtc;
  final DateTime? endUtc;
  final int clockMinutes;
  final bool breakValid;
  final bool breakPaidClient;
  final bool breakPaidWorker;
  final int clientMinutes;
  final int workerMinutes;
  final LineAmount client;
  final LineAmount worker;
  final RateBasis? clientBasis;
  final int? clientRateFils;
  final RateBasis? workerBasis;
  final int? workerRateFils;

  bool get hasPricingIssue => client.issue != null || worker.issue != null;
}

/// An override changes the amount and keeps the contract's basis, so mixed pay is never silently converted (ATT-03).
RateTerms? _withOverride(RateTerms? terms, int? overrideFils) {
  if (terms == null || overrideFils == null) return terms;
  return RateTerms(
    basis: terms.basis,
    rateFils: overrideFils,
    effectiveFrom: terms.effectiveFrom,
    effectiveTo: terms.effectiveTo,
    breakPaid: terms.breakPaid,
    halfAmountFils: terms.halfAmountFils,
    includedMinutes: terms.includedMinutes,
    overtimeRateFils: terms.overtimeRateFils,
    siteId: terms.siteId,
    workerId: terms.workerId,
  );
}

/// Prices one shift for both sides, independently (CALC-02, CALC-06).
PricedShift priceShift(String workDate, ShiftInput input, {RateTerms? client, RateTerms? worker}) {
  final clientTerms = _withOverride(client, input.clientOverrideFils);
  final workerTerms = _withOverride(worker, input.workerOverrideFils);
  final paidClient = input.breakPaidClient ?? client?.breakPaid ?? false;
  final paidWorker = input.breakPaidWorker ?? worker?.breakPaid ?? false;

  final worked = input.status != AttendanceStatus.absent && input.startMinute != null && input.endMinute != null;
  final times = worked ? shiftTimes(workDate, input.startMinute!, input.endMinute!) : null;
  final clock = times == null ? 0 : clockMinutes(times.startUtc, times.endUtc);
  final breakMinutes = worked ? input.breakMinutes : 0;
  final breakValid = isValidBreak(breakMinutes, clock);
  final clientMinutes = breakValid ? countedMinutes(clock, breakMinutes, breakPaid: paidClient) : 0;
  final workerMinutes = breakValid ? countedMinutes(clock, breakMinutes, breakPaid: paidWorker) : 0;

  return PricedShift(
    startUtc: times?.startUtc,
    endUtc: times?.endUtc,
    clockMinutes: clock,
    breakValid: breakValid,
    breakPaidClient: paidClient,
    breakPaidWorker: paidWorker,
    clientMinutes: clientMinutes,
    workerMinutes: workerMinutes,
    client: priceLine(clientTerms, status: input.status, minutes: clientMinutes, overtimeApproved: input.overtimeApproved),
    worker: priceLine(workerTerms, status: input.status, minutes: workerMinutes, overtimeApproved: input.overtimeApproved),
    clientBasis: clientTerms?.basis,
    clientRateFils: clientTerms?.rateFils,
    workerBasis: workerTerms?.basis,
    workerRateFils: workerTerms?.rateFils,
  );
}
