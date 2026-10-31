import 'package:domain/calc.dart';
import 'package:test/test.dart';

const date = '2026-11-01';
const hourly = RateTerms(basis: RateBasis.hour, rateFils: 800, effectiveFrom: '2026-01-01');
const monthly = RateTerms(basis: RateBasis.month, rateFils: 200000, effectiveFrom: '2026-01-01');

void main() {
  test('the group wage replaces an hourly contract and pays per day, whatever the hours', () {
    final terms = groupPayTerms(hourly, date: date, groupRateFils: 10000)!;
    expect(terms.basis, RateBasis.day);
    expect(priceLine(terms, status: AttendanceStatus.present, minutes: 660, overtimeApproved: false).amountFils, 10000);
    expect(priceLine(terms, status: AttendanceStatus.present, minutes: 300, overtimeApproved: false).amountFils, 10000);
  });

  test("a member's own wage beats the group's", () {
    expect(groupPayTerms(hourly, date: date, groupRateFils: 10000, memberRateFils: 12000)!.rateFils, 12000);
  });

  test('the group wage never turns a monthly worker daily, but an own wage set on purpose does (ATT-03)', () {
    expect(groupPayTerms(monthly, date: date, groupRateFils: 10000), monthly);
    expect(groupPayTerms(monthly, date: date, groupRateFils: 10000, memberRateFils: 9000)!.basis, RateBasis.day);
  });

  test('a group with no wage leaves the contract alone, and no contract stays missing', () {
    expect(groupPayTerms(hourly, date: date), hourly);
    expect(groupPayTerms(null, date: date), isNull);
  });

  test('half pay follows the wage actually used, and only if the group says so', () {
    final half = groupPayTerms(null, date: date, groupRateFils: 10000, memberRateFils: 15000, halfDayIsHalf: true)!;
    expect(priceLine(half, status: AttendanceStatus.half, minutes: 300, overtimeApproved: false).amountFils, 7500);

    final notAgreed = groupPayTerms(null, date: date, groupRateFils: 10000)!;
    expect(priceLine(notAgreed, status: AttendanceStatus.half, minutes: 300, overtimeApproved: false).issue, LineIssue.missingHalfAmount);
  });

  test('half of an odd fils wage rounds half up, like every other amount', () {
    expect(groupPayTerms(null, date: date, groupRateFils: 10001, halfDayIsHalf: true)!.halfAmountFils, 5001);
  });

  test('a wage typed for one row is used, and half pay follows it', () {
    final typed = groupPayTerms(null, date: date, groupRateFils: 10000, typedFils: 12000, halfDayIsHalf: true)!;
    expect(typed.rateFils, 12000);
    expect(typed.halfAmountFils, 6000);
  });

  test('a wage typed with no group wage and no contract still prices the row', () {
    expect(groupPayTerms(null, date: date, typedFils: 9000)!.rateFils, 9000);
  });

  test('a wage typed over a contract with no group wage leaves the contract to apply it, keeping its basis', () {
    expect(groupPayTerms(hourly, date: date, typedFils: 900), hourly);
  });
}
