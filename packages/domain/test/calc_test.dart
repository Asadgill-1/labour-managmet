import 'package:domain/calc.dart';
import 'package:test/test.dart';

const present = AttendanceStatus.present;
const half = AttendanceStatus.half;
const absent = AttendanceStatus.absent;

RateTerms hourly(int rate, {bool breakPaid = false, int? included, int? overtime}) => RateTerms(
  basis: RateBasis.hour,
  rateFils: rate,
  effectiveFrom: '2026-01-01',
  breakPaid: breakPaid,
  includedMinutes: included,
  overtimeRateFils: overtime,
);

int total(RateTerms terms, {int workers = 10, required int minutes}) {
  return workers * priceLine(terms, status: present, minutes: minutes, overtimeApproved: false).amountFils!;
}

void main() {
  group('PRD fixtures', () {
    const clock = 720;
    final billable = countedMinutes(clock, 60, breakPaid: false);
    final payable = countedMinutes(clock, 60, breakPaid: false);

    test('TC-016: 10 workers, 11 paid hours, client 10, payroll 8, contribution 220', () {
      expect(billable, 660);
      expect(total(hourly(1000), minutes: billable), 110000);
      expect(total(hourly(800), minutes: payable), 88000);
      expect(total(hourly(1000), minutes: billable) - total(hourly(800), minutes: payable), 22000);
    });

    test('TC-017: agreed full shift of 70 is not multiplied by hours, contribution 400', () {
      const shift = RateTerms(basis: RateBasis.shift, rateFils: 7000, effectiveFrom: '2026-01-01');
      expect(total(shift, minutes: payable), 70000);
      expect(total(hourly(1000), minutes: billable) - total(shift, minutes: payable), 40000);
    });

    test('TC-003: client and payroll breaks are independent', () {
      expect(countedMinutes(clock, 60, breakPaid: true), 720);
      expect(countedMinutes(clock, 60, breakPaid: false), 660);
      expect(total(hourly(1000, breakPaid: true), minutes: 720), 120000);
      expect(total(hourly(800), minutes: 660), 88000);
    });

    test('TC-018: midnight shift 20:00 to 08:00 is 720 minutes, and an oversized break is invalid', () {
      final times = shiftTimes('2026-11-01', 20 * 60, 8 * 60);
      expect(times.startUtc, DateTime.utc(2026, 11, 1, 16));
      expect(times.endUtc, DateTime.utc(2026, 11, 2, 4));
      expect(clockMinutes(times.startUtc, times.endUtc), 720);
      expect(isValidBreak(60, 720), isTrue);
      expect(isValidBreak(721, 720), isFalse);
      expect(isValidBreak(-1, 720), isFalse);
    });

    test('TC-028: one worker on two shifts is headcount 1, shifts 2, worker-days 1', () {
      final counts = attendanceCounts([
        (workerId: 'w1', workDate: '2026-11-01', status: present),
        (workerId: 'w1', workDate: '2026-11-01', status: present),
        (workerId: 'w2', workDate: '2026-11-01', status: absent),
      ]);
      expect(counts.uniqueWorkers, 1);
      expect(counts.shifts, 2);
      expect(counts.workerDays, 1);
    });
  });

  group('priceLine', () {
    test('rounds each hourly line half-up to fils', () {
      // 37 minutes at AED 8.75 an hour is 539.58 fils.
      expect(priceLine(hourly(875), status: present, minutes: 37, overtimeApproved: false).amountFils, 540);
    });

    test('no rate stops for review and is never zero', () {
      final line = priceLine(null, status: present, minutes: 60, overtimeApproved: false);
      expect(line.issue, LineIssue.missingRate);
      expect(line.amountFils, isNull);
    });

    test('absent is zero, even with no rate lookup issue on a contract', () {
      expect(priceLine(hourly(1000), status: absent, minutes: 0, overtimeApproved: false).amountFils, 0);
    });

    test('half shift uses the contract amount, and stops if the contract has none', () {
      const withHalf = RateTerms(basis: RateBasis.shift, rateFils: 7000, halfAmountFils: 3500, effectiveFrom: '2026-01-01');
      const withoutHalf = RateTerms(basis: RateBasis.day, rateFils: 7000, effectiveFrom: '2026-01-01');
      expect(priceLine(withHalf, status: half, minutes: 300, overtimeApproved: false).amountFils, 3500);
      expect(priceLine(withoutHalf, status: half, minutes: 300, overtimeApproved: false).issue, LineIssue.missingHalfAmount);
    });

    test('half on an hourly contract pays the actual minutes', () {
      expect(priceLine(hourly(1000), status: half, minutes: 300, overtimeApproved: false).amountFils, 5000);
    });

    test('monthly bases carry no line amount and no issue (TC-019, TC-020)', () {
      for (final basis in [RateBasis.month, RateBasis.monthPerWorker, RateBasis.monthFixed]) {
        final terms = RateTerms(basis: basis, rateFils: 200000, effectiveFrom: '2026-01-01');
        final line = priceLine(terms, status: present, minutes: 660, overtimeApproved: false);
        expect(line.amountFils, isNull);
        expect(line.issue, isNull);
      }
    });
  });

  group('TC-022 overtime', () {
    final terms = hourly(1000, included: 480, overtime: 1500);

    test('regular and overtime minutes are separate', () {
      final line = priceLine(terms, status: present, minutes: 600, overtimeApproved: true);
      expect(line.regularMinutes, 480);
      expect(line.overtimeMinutes, 120);
      expect(line.amountFils, 8000 + 3000);
    });

    test('unapproved overtime is recorded but not paid', () {
      final line = priceLine(terms, status: present, minutes: 600, overtimeApproved: false);
      expect(line.overtimeMinutes, 120);
      expect(line.amountFils, 8000);
    });

    test('approved overtime with no contract rate stops, with no automatic multiplier', () {
      final line = priceLine(hourly(1000, included: 480), status: present, minutes: 600, overtimeApproved: true);
      expect(line.issue, LineIssue.missingOvertimeRate);
      expect(line.amountFils, isNull);
    });

    test('with no included minutes every minute is regular', () {
      final line = priceLine(hourly(1000), status: present, minutes: 720, overtimeApproved: true);
      expect(line.overtimeMinutes, 0);
      expect(line.amountFils, 12000);
    });

    test('a shift adds overtime to its fee', () {
      const shift = RateTerms(basis: RateBasis.shift, rateFils: 7000, includedMinutes: 660, overtimeRateFils: 1000, effectiveFrom: '2026-01-01');
      expect(priceLine(shift, status: present, minutes: 720, overtimeApproved: true).amountFils, 8000);
    });
  });

  group('TC-019 monthly salary', () {
    test('a full period is the monthly amount exactly', () {
      expect(monthlySalary(monthlyFils: 200000, coveredDays: 30, daysInPeriod: 30), 200000);
      expect(monthlySalary(monthlyFils: 200000, coveredDays: 31, daysInPeriod: 31, method: PartialMethod.fixedDivisor, fixedDivisor: 30), 200000);
    });

    test('a part period with no method stops for review', () {
      expect(monthlySalary(monthlyFils: 200000, coveredDays: 15, daysInPeriod: 30), isNull);
    });

    test('a fixed divisor of zero stops for review', () {
      expect(monthlySalary(monthlyFils: 200000, coveredDays: 15, daysInPeriod: 30, method: PartialMethod.fixedDivisor, fixedDivisor: 0), isNull);
    });

    test('each method calculates as its contract says', () {
      expect(monthlySalary(monthlyFils: 310000, coveredDays: 10, daysInPeriod: 31, method: PartialMethod.calendarDays), 100000);
      expect(monthlySalary(monthlyFils: 300000, coveredDays: 10, daysInPeriod: 31, method: PartialMethod.fixedDivisor, fixedDivisor: 30), 100000);
    });
  });

  test('TC-020: a fixed client contract is one fee, a per-worker contract multiplies', () {
    expect(clientMonthlyCharge(RateBasis.monthFixed, rateFils: 500000, workerCount: 10), 500000);
    expect(clientMonthlyCharge(RateBasis.monthPerWorker, rateFils: 200000, workerCount: 10), 2000000);
  });

  group('TC-021 rate priority', () {
    RateTerms contract(int rate, {String? site, String? worker, String from = '2026-01-01', String? to}) =>
        RateTerms(basis: RateBasis.hour, rateFils: rate, effectiveFrom: from, effectiveTo: to, siteId: site, workerId: worker);

    int? pick(List<RateTerms> c, {String date = '2026-06-01'}) => pickRate(c, date: date, siteId: 's1', workerId: 'w1')?.rateFils;

    test('more specific scope wins: worker and site, worker, site, general', () {
      final general = contract(100);
      final site = contract(200, site: 's1');
      final worker = contract(300, worker: 'w1');
      final both = contract(400, site: 's1', worker: 'w1');
      expect(pick([general]), 100);
      expect(pick([general, site]), 200);
      expect(pick([general, site, worker]), 300);
      expect(pick([general, site, worker, both]), 400);
    });

    test('a contract for another site or worker never applies', () {
      expect(pick([contract(200, site: 's2')]), isNull);
      expect(pick([contract(200, worker: 'w2')]), isNull);
    });

    test('dates are inclusive, and the latest start wins a tie', () {
      final old = contract(100, to: '2026-05-31');
      final current = contract(200, from: '2026-06-01');
      expect(pick([old, current], date: '2026-05-31'), 100);
      expect(pick([old, current], date: '2026-06-01'), 200);
      expect(pick([old], date: '2026-06-01'), isNull);
      expect(pick([contract(100), contract(200, from: '2026-03-01')]), 200);
    });
  });

  group('overlap', () {
    final eight = DateTime.utc(2026, 11, 1, 8);
    final twelve = DateTime.utc(2026, 11, 1, 12);
    final thirteen = DateTime.utc(2026, 11, 1, 13);
    final eighteen = DateTime.utc(2026, 11, 1, 18);

    test('shifts sharing time overlap, back-to-back and separate shifts do not (TC-025)', () {
      expect(shiftsOverlap(eight, thirteen, twelve, eighteen), isTrue);
      expect(shiftsOverlap(eight, twelve, twelve, eighteen), isFalse);
      expect(shiftsOverlap(eight, twelve, thirteen, eighteen), isFalse);
    });

    test('contract ranges treat a null end as open', () {
      expect(datesOverlap('2026-01-01', null, '2026-06-01', null), isTrue);
      expect(datesOverlap('2026-01-01', '2026-05-31', '2026-06-01', null), isFalse);
      expect(datesOverlap('2026-01-01', '2026-06-01', '2026-06-01', null), isTrue);
    });
  });

  group('priceShift', () {
    final client = hourly(1000);
    final worker = hourly(800);

    test('the PRD shift: 12 clock hours, 1 unpaid break, both sides', () {
      final shift = priceShift('2026-11-01', const ShiftInput(startMinute: 480, endMinute: 1200, breakMinutes: 60), client: client, worker: worker);
      expect(shift.clockMinutes, 720);
      expect(shift.clientMinutes, 660);
      expect(shift.client.amountFils, 11000);
      expect(shift.worker.amountFils, 8800);
      expect(shift.payHeld, isFalse);
    });

    test('a break paid on one side only changes that side', () {
      final shift = priceShift(
        '2026-11-01',
        const ShiftInput(startMinute: 480, endMinute: 1200, breakMinutes: 60, breakPaidClient: true),
        client: client,
        worker: worker,
      );
      expect(shift.clientMinutes, 720);
      expect(shift.workerMinutes, 660);
    });

    test('an oversized break is invalid and pays nothing', () {
      final shift = priceShift('2026-11-01', const ShiftInput(startMinute: 480, endMinute: 540, breakMinutes: 61), client: client, worker: worker);
      expect(shift.breakValid, isFalse);
      expect(shift.client.amountFils, 0);
    });

    test('absent has no times and no amounts', () {
      final shift = priceShift('2026-11-01', const ShiftInput(status: absent, startMinute: 480, endMinute: 1200, breakMinutes: 60), client: client, worker: worker);
      expect(shift.startUtc, isNull);
      expect(shift.clockMinutes, 0);
      expect(shift.breakValid, isTrue);
      expect(shift.worker.amountFils, 0);
    });

    test('an override changes the rate and keeps the basis (ATT-03)', () {
      const monthly = RateTerms(basis: RateBasis.month, rateFils: 200000, effectiveFrom: '2026-01-01');
      final shift = priceShift(
        '2026-11-01',
        const ShiftInput(startMinute: 480, endMinute: 1200, clientOverrideFils: 1200, workerOverrideFils: 250000),
        client: client,
        worker: monthly,
      );
      expect(shift.clientRateFils, 1200);
      expect(shift.client.amountFils, 14400);
      expect(shift.workerBasis, RateBasis.month);
      expect(shift.worker.amountFils, isNull);
      expect(shift.payHeld, isFalse);
    });

    test('an override with no contract still stops for review', () {
      final shift = priceShift('2026-11-01', const ShiftInput(startMinute: 480, endMinute: 1200, workerOverrideFils: 800), client: client);
      expect(shift.worker.issue, LineIssue.missingRate);
      expect(shift.payHeld, isTrue);
    });

    test('a missing company rate holds the bill and never the wage (ATT-07, D-041)', () {
      final shift = priceShift('2026-11-01', const ShiftInput(startMinute: 480, endMinute: 1200), worker: worker);
      expect(shift.client.issue, LineIssue.missingRate);
      expect(shift.worker.amountFils, 9600);
      expect(shift.payHeld, isFalse);
    });

    test('an absent worker needs no rate, because nobody worked', () {
      final shift = priceShift('2026-11-01', const ShiftInput(status: absent));
      expect(shift.payHeld, isFalse);
      expect(shift.worker.amountFils, 0);
      expect(shift.client.amountFils, 0);
    });
  });
}
