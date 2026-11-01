import 'calc.dart';
import 'money.dart';

/// One shift as a company sees it. A worker's wage has no field here, so it can't reach a company's paper (TS-02).
class TsLine {
  const TsLine({
    required this.workDate,
    required this.siteId,
    required this.workerId,
    this.trade,
    required this.status,
    required this.clockMinutes,
    required this.breakMinutes,
    required this.billableMinutes,
    required this.basis,
    required this.rateFils,
    this.amountFils,
  });

  final String workDate;
  final String siteId;
  final String workerId;
  final String? trade;

  /// What the company is charged for. An adjusted line can say less than the attendance did (TS-06).
  final AttendanceStatus status;
  final int clockMinutes;
  final int breakMinutes;
  final int billableMinutes;
  final RateBasis basis;
  final int rateFils;

  /// Null on a monthly row: the fee belongs to the contract (TS-08).
  final int? amountFils;

  /// Half days, so a half day stays exact with no fraction anywhere.
  int get halves => switch (status) {
    AttendanceStatus.present => 2,
    AttendanceStatus.half => 1,
    AttendanceStatus.absent => 0,
  };
}

/// What was billed, each in its own unit. Hours, days and shifts are never added together (TS-03).
class TsUnits {
  const TsUnits({this.minutes = 0, this.dayHalves = 0, this.shiftHalves = 0});

  final int minutes;
  final int dayHalves;
  final int shiftHalves;

  TsUnits operator +(TsUnits o) => TsUnits(minutes: minutes + o.minutes, dayHalves: dayHalves + o.dayHalves, shiftHalves: shiftHalves + o.shiftHalves);
}

/// A monthly row bills nothing by itself, so it adds to no unit.
TsUnits unitsOf(TsLine l) => switch (l.basis) {
  RateBasis.hour => TsUnits(minutes: l.billableMinutes),
  RateBasis.day => TsUnits(dayHalves: l.halves),
  RateBasis.shift => TsUnits(shiftHalves: l.halves),
  RateBasis.month || RateBasis.monthPerWorker || RateBasis.monthFixed => const TsUnits(),
};

/// 3 -> "1.5".
String showHalves(int halves) => '${halves ~/ 2}${halves.isOdd ? '.5' : ''}';

/// Everyone on one date, site, trade, rate and basis.
class TsDayRow {
  const TsDayRow({
    required this.workDate,
    required this.siteId,
    this.trade,
    required this.basis,
    required this.rateFils,
    required this.persons,
    required this.shifts,
    required this.clockMinutes,
    required this.breakMinutes,
    required this.units,
    this.amountFils,
  });

  final String workDate;
  final String siteId;
  final String? trade;
  final RateBasis basis;
  final int rateFils;
  final int persons;
  final int shifts;
  final int clockMinutes;
  final int breakMinutes;
  final TsUnits units;
  final int? amountFils;
}

int? _addAmounts(Iterable<TsLine> lines) {
  final amounts = lines.map((l) => l.amountFils).nonNulls;
  return amounts.isEmpty ? null : amounts.fold<int>(0, (total, a) => total + a);
}

/// One row per date, site, trade, rate and basis, so a different rate or unit never hides inside a total (TS-03). A line
/// the company was not charged for is not counted.
List<TsDayRow> dailySummary(Iterable<TsLine> lines) {
  final groups = <(String, String, String?, RateBasis, int), List<TsLine>>{};
  for (final l in lines.where((l) => l.status != AttendanceStatus.absent)) {
    (groups[(l.workDate, l.siteId, l.trade, l.basis, l.rateFils)] ??= []).add(l);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      final date = a.$1.compareTo(b.$1);
      if (date != 0) return date;
      final site = a.$2.compareTo(b.$2);
      return site != 0 ? site : (a.$3 ?? '').compareTo(b.$3 ?? '');
    });
  return [
    for (final key in keys)
      () {
        final rows = groups[key]!;
        return TsDayRow(
          workDate: key.$1,
          siteId: key.$2,
          trade: key.$3,
          basis: key.$4,
          rateFils: key.$5,
          persons: rows.map((l) => l.workerId).toSet().length,
          shifts: rows.length,
          clockMinutes: rows.fold(0, (total, l) => total + l.clockMinutes),
          breakMinutes: rows.fold(0, (total, l) => total + l.breakMinutes),
          units: rows.fold(const TsUnits(), (total, l) => total + unitsOf(l)),
          amountFils: _addAmounts(rows),
        );
      }(),
  ];
}

class TsTotals {
  const TsTotals({required this.uniqueWorkers, required this.workerDays, required this.shifts, required this.units, required this.amountFils});

  final int uniqueWorkers;
  final int workerDays;
  final int shifts;
  final TsUnits units;
  final int amountFils;
}

TsTotals timesheetTotals(Iterable<TsLine> lines) {
  final counts = attendanceCounts(lines.map((l) => (workerId: l.workerId, workDate: l.workDate, status: l.status)));
  return TsTotals(
    uniqueWorkers: counts.uniqueWorkers,
    workerDays: counts.workerDays,
    shifts: counts.shifts,
    units: lines.fold(const TsUnits(), (total, l) => total + unitsOf(l)),
    amountFils: _addAmounts(lines) ?? 0,
  );
}

/// A monthly contract on a timesheet: its unit and the dates the attendance covers. The fee is charged once, on the
/// invoice, and never from these rows (TS-08, CALC-05).
class TsMonthly {
  const TsMonthly({required this.basis, required this.rateFils, required this.fromDate, required this.toDate, required this.persons});

  final RateBasis basis;
  final int rateFils;
  final String fromDate;
  final String toDate;
  final int persons;
}

List<TsMonthly> monthlyContracts(Iterable<TsLine> lines) {
  final groups = <(RateBasis, int), List<TsLine>>{};
  for (final l in lines.where((l) => isPeriodBasis(l.basis))) {
    (groups[(l.basis, l.rateFils)] ??= []).add(l);
  }
  return [
    for (final MapEntry(key: key, value: rows) in groups.entries)
      () {
        final dates = rows.map((l) => l.workDate).toList()..sort();
        return TsMonthly(basis: key.$1, rateFils: key.$2, fromDate: dates.first, toDate: dates.last, persons: rows.map((l) => l.workerId).toSet().length);
      }(),
  ];
}

/// What an agreed line comes to, to start the owner off: they can still type another figure (TS-06). Null on a monthly row.
int? adjustedAmount(RateBasis basis, int rateFils, AttendanceStatus status, int minutes) {
  if (isPeriodBasis(basis)) return null;
  if (status == AttendanceStatus.absent) return 0;
  if (basis == RateBasis.hour) return divRoundHalfUp(minutes * rateFils, 60);
  return status == AttendanceStatus.half ? divRoundHalfUp(rateFils, 2) : rateFils;
}
