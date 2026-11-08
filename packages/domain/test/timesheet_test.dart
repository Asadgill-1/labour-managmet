import 'package:domain/calc.dart';
import 'package:domain/timesheet.dart';
import 'package:test/test.dart';

const present = AttendanceStatus.present;
const half = AttendanceStatus.half;
const absent = AttendanceStatus.absent;

TsLine line(
  String worker, {
  String date = '2026-10-05',
  String site = 'site-1',
  String? trade,
  AttendanceStatus status = present,
  RateBasis basis = RateBasis.hour,
  int rate = 1500,
  int clock = 540,
  int breakMinutes = 60,
  int billable = 480,
  int? amount = 12000,
}) => TsLine(
  workDate: date,
  siteId: site,
  workerId: worker,
  trade: trade,
  status: status,
  clockMinutes: clock,
  breakMinutes: breakMinutes,
  billableMinutes: billable,
  basis: basis,
  rateFils: rate,
  amountFils: amount,
);

void main() {
  group('daily summary (TS-03)', () {
    test('same date, site, rate and basis become one row', () {
      final rows = dailySummary([line('a'), line('b'), line('c')]);
      expect(rows, hasLength(1));
      expect(rows.single.persons, 3);
      expect(rows.single.shifts, 3);
      expect(rows.single.clockMinutes, 1620);
      expect(rows.single.breakMinutes, 180);
      expect(rows.single.units.minutes, 1440);
      expect(rows.single.amountFils, 36000);
    });

    test('a different rate or unit never merges into an ambiguous row (TC-039)', () {
      final rows = dailySummary([
        line('a'),
        line('b', rate: 2000, amount: 16000),
        line('c', basis: RateBasis.day, rate: 12000, amount: 12000),
        line('d', basis: RateBasis.shift, rate: 13000, amount: 13000),
      ]);
      expect(rows, hasLength(4));
      expect(rows.map((r) => r.basis), containsAll([RateBasis.hour, RateBasis.day, RateBasis.shift]));
    });

    test('another site or date is another row, in date order', () {
      final rows = dailySummary([line('a', date: '2026-10-06'), line('a', site: 'site-2'), line('b')]);
      expect(rows.map((r) => (r.workDate, r.siteId, r.persons)), [('2026-10-05', 'site-1', 1), ('2026-10-05', 'site-2', 1), ('2026-10-06', 'site-1', 1)]);
    });

    test('one worker on two shifts counts once as a person and twice as shifts', () {
      final row = dailySummary([line('a'), line('a')]).single;
      expect(row.persons, 1);
      expect(row.shifts, 2);
    });

    test('a trade keeps its own row, when workers have one', () {
      final rows = dailySummary([line('a', trade: 'Helper'), line('b', trade: 'Mason')]);
      expect(rows.map((r) => r.trade), ['Helper', 'Mason']);
    });

    test('half days stay exact, and a line the company did not take is left out', () {
      final rows = dailySummary([
        line('a', basis: RateBasis.day, rate: 12000, amount: 12000),
        line('b', basis: RateBasis.day, rate: 12000, amount: 6000, status: half),
        line('c', basis: RateBasis.day, rate: 12000, amount: 0, status: absent),
      ]);
      expect(rows.single.persons, 2);
      expect(rows.single.units.dayHalves, 3);
      expect(rows.single.amountFils, 18000);
    });
  });

  group('totals (TS-03)', () {
    test('worker-days, unique workers and each unit keep their own names', () {
      final totals = timesheetTotals([
        line('a'),
        line('a', date: '2026-10-06'),
        line('a', date: '2026-10-06', site: 'site-2'),
        line('b', basis: RateBasis.day, rate: 12000, amount: 12000),
        line('b', date: '2026-10-06', basis: RateBasis.day, rate: 12000, amount: 6000, status: half),
        line('c', basis: RateBasis.shift, rate: 13000, amount: 13000),
      ]);
      expect(totals.uniqueWorkers, 3);
      expect(totals.workerDays, 5);
      expect(totals.shifts, 6);
      expect(totals.units.minutes, 1440);
      expect(totals.units.dayHalves, 3);
      expect(totals.units.shiftHalves, 2);
      expect(totals.amountFils, 12000 * 3 + 12000 + 6000 + 13000);
    });

    test('nothing to total is zero, not an error', () {
      final totals = timesheetTotals(const []);
      expect(totals.uniqueWorkers, 0);
      expect(totals.amountFils, 0);
    });
  });

  group('monthly contracts (TS-08, CALC-05)', () {
    test('ten workers on a fixed fee add nothing to the daily amounts (TC-020)', () {
      final lines = [for (var i = 0; i < 10; i++) line('w$i', basis: RateBasis.monthFixed, rate: 500000, amount: null)];
      final totals = timesheetTotals(lines);
      expect(totals.amountFils, 0);
      expect(totals.units.minutes, 0);
      expect(totals.workerDays, 10);
      expect(dailySummary(lines).single.amountFils, isNull);
    });

    test('names the unit and the dates it covers, once per contract', () {
      final months = monthlyContracts([
        line('a', date: '2026-10-03', basis: RateBasis.monthFixed, rate: 500000, amount: null),
        line('b', date: '2026-10-20', basis: RateBasis.monthFixed, rate: 500000, amount: null),
        line('c', date: '2026-10-09', basis: RateBasis.monthPerWorker, rate: 200000, amount: null),
        line('d'),
      ]);
      expect(months, hasLength(2));
      final fixed = months.firstWhere((m) => m.basis == RateBasis.monthFixed);
      expect((fixed.rateFils, fixed.fromDate, fixed.toDate, fixed.persons), (500000, '2026-10-03', '2026-10-20', 2));
    });

    test('approved extra time on a monthly row is still its own amount', () {
      expect(timesheetTotals([line('a', basis: RateBasis.monthFixed, rate: 500000, amount: 4500)]).amountFils, 4500);
    });
  });

  group('adjusted amount (TS-06)', () {
    test('hours follow the rate, half up', () {
      expect(adjustedAmount(RateBasis.hour, 1500, present, 450), 11250);
      expect(adjustedAmount(RateBasis.hour, 1001, present, 1), 17);
    });

    test('a day or shift is whole, half or nothing', () {
      expect(adjustedAmount(RateBasis.day, 12001, present, 0), 12001);
      expect(adjustedAmount(RateBasis.day, 12001, half, 0), 6001);
      expect(adjustedAmount(RateBasis.shift, 13000, absent, 0), 0);
    });

    test('a monthly row has no amount of its own to adjust', () {
      expect(adjustedAmount(RateBasis.monthFixed, 500000, present, 480), isNull);
    });
  });

  test('half days show without a fraction type', () {
    expect(showHalves(0), '0');
    expect(showHalves(1), '0.5');
    expect(showHalves(4), '2');
    expect(showHalves(9), '4.5');
  });
}
