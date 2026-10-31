import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:test/test.dart';

void main() {
  test('PRD advance fixture: issued 300, recovered 100, outstanding 200 (PAY-05)', () {
    const lines = [CashLine(CashKind.advanceGiven, 30000), CashLine(CashKind.advanceReturned, 10000)];
    expect(advanceOutstanding(0, lines), 20000);
  });

  test('an opening advance counts towards what is outstanding (MASTER-05)', () {
    expect(advanceOutstanding(5000, const [CashLine(CashKind.advanceGiven, 1000)]), 6000);
  });

  test('a reversal cancels its original exactly (REP-08)', () {
    const given = CashLine(CashKind.advanceGiven, 30000);
    const undone = CashLine(CashKind.advanceGiven, 30000, reversal: true);
    expect(advanceOutstanding(0, const [given, undone]), 0);
    expect(cashTotals(const [given, undone]).outFils, 0);
  });

  test('advance is not salary, and neither is counted as the other (PAY-05)', () {
    const lines = [CashLine(CashKind.advanceGiven, 30000), CashLine(CashKind.salaryPaid, 50000)];
    expect(salaryPaidTotal(lines), 50000);
    expect(advanceOutstanding(0, lines), 30000);
  });

  test('money in and out add up per direction', () {
    const lines = [
      CashLine(CashKind.advanceGiven, 100),
      CashLine(CashKind.salaryPaid, 200),
      CashLine(CashKind.roomRentPaid, 300),
      CashLine(CashKind.expense, 400),
      CashLine(CashKind.advanceReturned, 10),
      CashLine(CashKind.roomRentReceived, 20),
      CashLine(CashKind.clientReceipt, 30),
    ];
    final totals = cashTotals(lines);
    expect(totals.outFils, 1000);
    expect(totals.inFils, 60);
  });

  test('a room shows profit when more rent comes in than goes out, and loss the other way', () {
    final profit = roomResult(const [CashLine(CashKind.roomRentReceived, 300000), CashLine(CashKind.roomRentPaid, 250000)]);
    expect(profit.receivedFils, 300000);
    expect(profit.paidFils, 250000);
    expect(profit.netFils, 50000);

    final loss = roomResult(const [CashLine(CashKind.roomRentReceived, 100000), CashLine(CashKind.roomRentPaid, 250000)]);
    expect(loss.netFils, -150000);
  });

  test('other kinds never touch a room result (REP-07)', () {
    expect(roomResult(const [CashLine(CashKind.expense, 100000), CashLine(CashKind.clientReceipt, 500)]).netFils, 0);
  });

  test('months step across a year, and show like the dates do', () {
    expect(addMonths('2026-12', 1), '2027-01');
    expect(addMonths('2027-01', -1), '2026-12');
    expect(addMonths('2026-10', 0), '2026-10');
    expect(showMonth('2026-10'), '10-2026');
  });
}
