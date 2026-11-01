import 'package:domain/statement.dart';
import 'package:test/test.dart';

MonthStatement of(List<MonthStatement> months, String month) => months.singleWhere((m) => m.month == month);

void main() {
  test("wages paid early next month settle the month they are for, so the slip shows no old balance", () {
    final months = monthStatements(
      ownByMonth: {'2026-09': 200000, '2026-10': 200000},
      payments: const [StatementPayment('2026-10-05', 200000), StatementPayment('2026-11-05', 200000)],
      through: '2026-10',
    );
    final sep = of(months, '2026-09');
    expect(sep.paidFils, 200000);
    expect(sep.closingFils, 0);
    final oct = of(months, '2026-10');
    expect(oct.openingFils, 0);
    expect(oct.paidFils, 200000);
    expect(oct.closingFils, 0);
  });

  test('part paid: the rest carries to the next opening, and each closing is the next opening', () {
    final months = monthStatements(
      ownByMonth: {'2026-09': 200000, '2026-10': 200000},
      payments: const [StatementPayment('2026-10-05', 150000), StatementPayment('2026-11-05', 200000)],
      through: '2026-10',
    );
    expect(of(months, '2026-09').closingFils, 50000);
    expect(of(months, '2026-10').openingFils, 50000);
    expect(of(months, '2026-10').paidFils, 200000);
    expect(of(months, '2026-10').closingFils, 50000);
  });

  test('a second payment in the same month keeps settling last month until it is clear, then counts on its own month', () {
    final months = monthStatements(
      ownByMonth: {'2026-09': 200000, '2026-10': 100000},
      payments: const [StatementPayment('2026-10-05', 150000), StatementPayment('2026-10-20', 50000), StatementPayment('2026-10-25', 30000)],
      through: '2026-10',
    );
    expect(of(months, '2026-09').payments.map((p) => p.date), ['2026-10-05', '2026-10-20']);
    expect(of(months, '2026-09').closingFils, 0);
    expect(of(months, '2026-10').payments.map((p) => p.date), ['2026-10-25']);
    expect(of(months, '2026-10').closingFils, 70000);
  });

  test('a payment stays whole, so overpaying shows as a credit on the next opening', () {
    final months = monthStatements(
      ownByMonth: {'2026-09': 100000, '2026-10': 200000},
      payments: const [StatementPayment('2026-10-05', 130000)],
      through: '2026-10',
    );
    expect(of(months, '2026-09').closingFils, -30000);
    expect(of(months, '2026-10').openingFils, -30000);
    expect(of(months, '2026-10').closingFils, 170000);
  });

  test('nothing owing last month means the payment is for its own month', () {
    final months = monthStatements(
      ownByMonth: {'2026-10': 200000},
      payments: const [StatementPayment('2026-10-20', 50000)],
      through: '2026-10',
    );
    expect(months.single.openingFils, 0);
    expect(months.single.paidFils, 50000);
  });

  test('a month with nothing of its own still carries the balance, and still takes the next payment', () {
    final months = monthStatements(
      ownByMonth: {'2026-08': 100000},
      payments: const [StatementPayment('2026-10-05', 100000)],
      through: '2026-10',
    );
    expect(of(months, '2026-08').paidFils, 0);
    expect(of(months, '2026-09').openingFils, 100000);
    expect(of(months, '2026-09').paidFils, 100000);
    expect(of(months, '2026-10').openingFils, 0);
  });

  test('money from before this app is the opening, never new earnings', () {
    final months = monthStatements(ownByMonth: {'2026-10': 100000}, broughtByMonth: {'2026-10': 40000}, payments: const [], through: '2026-10');
    expect(months.single.openingFils, 40000);
    expect(months.single.ownFils, 100000);
    expect(months.single.closingFils, 140000);
  });

  test('however payments fall, the last closing is always everything earned less everything paid', () {
    final own = {'2026-07': 90000, '2026-08': -20000, '2026-09': 110000, '2026-10': 50000};
    const payments = [StatementPayment('2026-08-02', 30000), StatementPayment('2026-08-20', 40000), StatementPayment('2026-10-01', 80000), StatementPayment('2026-10-30', 10000)];
    final months = monthStatements(ownByMonth: own, broughtByMonth: {'2026-07': 5000}, payments: payments, through: '2026-10');
    expect(months.last.closingFils, 5000 + 90000 - 20000 + 110000 + 50000 - 160000);
    for (var i = 1; i < months.length; i++) {
      expect(months[i].openingFils, months[i - 1].closingFils);
    }
  });

  test('a payment dated after the statement is left for later, and no data means no months', () {
    final months = monthStatements(ownByMonth: {'2026-09': 100000}, payments: const [StatementPayment('2026-11-05', 100000)], through: '2026-09');
    expect(months.single.paidFils, 0);
    expect(monthStatements(ownByMonth: const {}, payments: const [], through: '2026-09'), isEmpty);
  });
}
