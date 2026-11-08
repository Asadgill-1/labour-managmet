import 'package:domain/dates.dart';
import 'package:domain/statement.dart';
import 'package:test/test.dart';

MonthStatement of(List<MonthStatement> months, String month) => months.singleWhere((m) => m.month == month);

List<MonthStatement> run(Map<String, int> own, List<StatementPayment> payments, {required String through, Map<String, int> brought = const {}}) {
  final owed = {...own};
  brought.forEach((month, fils) => owed[month] = (owed[month] ?? 0) + fils);
  return monthStatements(ownByMonth: own, broughtByMonth: brought, placed: placePayments(owed, payments), through: through);
}

void main() {
  group('a payment with no month chosen goes oldest first', () {
    test('wages paid early next month settle the month they are for, so the slip shows no old balance', () {
      final months = run({'2026-09': 200000, '2026-10': 200000}, const [StatementPayment('2026-10-05', 200000), StatementPayment('2026-11-05', 200000)], through: '2026-10');
      final sep = of(months, '2026-09');
      expect(sep.paidFils, 200000);
      expect(sep.closingFils, 0);
      final oct = of(months, '2026-10');
      expect(oct.openingFils, 0);
      expect(oct.paidFils, 200000);
      expect(oct.closingFils, 0);
    });

    test('part paid: the rest carries to the next opening, and each closing is the next opening', () {
      final months = run({'2026-09': 200000, '2026-10': 200000}, const [StatementPayment('2026-10-05', 150000), StatementPayment('2026-11-05', 200000)], through: '2026-10');
      expect(of(months, '2026-09').paidFils, 200000, reason: 'the second payment clears September first');
      expect(of(months, '2026-09').payments.map((p) => p.fils), [150000, 50000]);
      expect(of(months, '2026-10').openingFils, 0);
      expect(of(months, '2026-10').paidFils, 150000);
      expect(of(months, '2026-10').closingFils, 50000);
    });

    test('one payment can cross months, and each month shows only its own share', () {
      final months = run({'2026-09': 100000, '2026-10': 200000}, const [StatementPayment('2026-10-05', 130000)], through: '2026-10');
      expect(of(months, '2026-09').paidFils, 100000);
      expect(of(months, '2026-09').closingFils, 0);
      expect(of(months, '2026-10').payments.single.date, '2026-10-05');
      expect(of(months, '2026-10').paidFils, 30000);
      expect(of(months, '2026-10').closingFils, 170000);
    });

    test('anything beyond every month stays on its own month as a credit, never lost', () {
      final months = run({'2026-09': 100000}, const [StatementPayment('2026-09-20', 130000)], through: '2026-10');
      expect(of(months, '2026-09').closingFils, -30000);
      expect(of(months, '2026-10').openingFils, -30000);
    });

    test('a month after the payment is not settled by it', () {
      final months = run({'2026-08': 50000, '2026-10': 100000}, const [StatementPayment('2026-08-20', 80000)], through: '2026-10');
      expect(of(months, '2026-08').paidFils, 80000);
      expect(of(months, '2026-09').openingFils, -30000);
      expect(of(months, '2026-10').paidFils, 0);
      expect(of(months, '2026-10').closingFils, 70000);
    });

    test('a month with nothing of its own still carries the balance', () {
      final months = run({'2026-08': 100000}, const [StatementPayment('2026-10-05', 40000)], through: '2026-10');
      expect(of(months, '2026-08').paidFils, 40000);
      expect(of(months, '2026-09').openingFils, 60000);
      expect(of(months, '2026-10').openingFils, 60000);
    });
  });

  group('the owner choosing the month (PAY-06)', () {
    test('their choice stands over oldest first, even with an older month unpaid', () {
      final months = run({'2026-09': 100000, '2026-10': 100000}, const [StatementPayment('2026-11-03', 100000, parts: {'2026-10': 100000})], through: '2026-10');
      expect(of(months, '2026-09').paidFils, 0);
      expect(of(months, '2026-09').closingFils, 100000);
      expect(of(months, '2026-10').openingFils, 100000);
      expect(of(months, '2026-10').paidFils, 100000);
      expect(of(months, '2026-10').closingFils, 100000);
    });

    test('a chosen split shows on each month, dated when it was paid', () {
      final months = run({'2026-09': 100000, '2026-10': 100000}, const [StatementPayment('2026-11-03', 120000, parts: {'2026-09': 70000, '2026-10': 50000})], through: '2026-10');
      expect(of(months, '2026-09').payments.single.fils, 70000);
      expect(of(months, '2026-10').payments.single.fils, 50000);
      expect(of(months, '2026-10').payments.single.date, '2026-11-03');
    });

    test('older payments with no choice go around the months already chosen', () {
      final placed = placePayments({'2026-09': 100000, '2026-10': 100000}, const [
        StatementPayment('2026-10-20', 80000),
        StatementPayment('2026-11-03', 100000, parts: {'2026-09': 100000}),
      ]);
      expect(placed['2026-09']!.single.fils, 100000);
      expect(placed['2026-10']!.single.fils, 80000);
    });

    test('a payment chosen for a later month does not touch an earlier statement', () {
      final placed = placePayments({'2026-09': 100000, '2026-10': 50000}, const [StatementPayment('2026-11-03', 50000, parts: {'2026-10': 50000})]);
      expect(unpaidAfter({'2026-09': 100000}, placed, through: '2026-09'), {'2026-09': 100000});
    });
  });

  group('what each month still owes', () {
    test('a month below zero comes off the oldest first, so the sum is the whole account', () {
      expect(unpaidByMonth({'2026-08': 50000, '2026-09': -80000, '2026-10': 100000}), {'2026-10': 70000});
      expect(unpaidByMonth({'2026-08': 50000, '2026-09': -20000}), {'2026-08': 30000});
      expect(unpaidByMonth({'2026-08': 50000, '2026-09': -80000}), isEmpty);
    });

    test('sharing out: oldest first, with what is left over beyond them all', () {
      final both = splitOldestFirst({'2026-10': 100000, '2026-09': 50000}, 120000);
      expect(both.parts, {'2026-09': 50000, '2026-10': 70000});
      expect(both.extraFils, 0);
      final over = splitOldestFirst({'2026-09': 50000}, 80000);
      expect(over.parts, {'2026-09': 50000});
      expect(over.extraFils, 30000);
      expect(splitOldestFirst(const {}, 80000).extraFils, 80000);
      expect(splitOldestFirst({'2026-09': 50000}, 0).parts, isEmpty);
    });
  });

  test('money from before this app is the opening, never new earnings', () {
    final months = run({'2026-10': 100000}, const [], through: '2026-10', brought: {'2026-10': 40000});
    expect(months.single.openingFils, 40000);
    expect(months.single.ownFils, 100000);
    expect(months.single.closingFils, 140000);
  });

  test('however payments fall, the last closing is always everything earned less everything paid', () {
    final own = {'2026-07': 90000, '2026-08': -20000, '2026-09': 110000, '2026-10': 50000};
    const payments = [
      StatementPayment('2026-08-02', 30000),
      StatementPayment('2026-08-20', 40000),
      StatementPayment('2026-10-01', 80000, parts: {'2026-09': 80000}),
      StatementPayment('2026-10-30', 10000),
    ];
    final months = run(own, payments, through: '2026-10', brought: {'2026-07': 5000});
    expect(months.last.closingFils, 5000 + 90000 - 20000 + 110000 + 50000 - 160000);
    for (var i = 1; i < months.length; i++) {
      expect(months[i].openingFils, months[i - 1].closingFils);
    }
  });

  test('no data means no months', () {
    expect(run(const {}, const [], through: '2026-09'), isEmpty);
  });

  group('wages falling due (PAY-08)', () {
    test('a month not over yet is never due', () {
      expect(wagesDue({'2026-10': 5000}, today: '2026-10-31'), isEmpty);
    });

    test('with no days set, a month is late from the day after it ends', () {
      final due = wagesDue({'2026-10': 5000}, today: '2026-11-01').single;
      expect(due.daysLate, 1);
      expect(due.overdue, isTrue);
    });

    test('the company\'s own days hold it as due until they pass', () {
      expect(wagesDue({'2026-10': 5000}, today: '2026-11-15', dueDays: 15).single.overdue, isFalse);
      final late = wagesDue({'2026-10': 5000}, today: '2026-11-18', dueDays: 15).single;
      expect(late.overdue, isTrue);
      expect(late.daysLate, 3);
    });

    test('oldest month first, and the months run across a year end', () {
      final due = wagesDue({'2026-12': 100, '2026-11': 200, '2027-01': 300}, today: '2027-01-10');
      expect(due.map((d) => d.month), ['2026-11', '2026-12']);
      expect(due.first.daysLate, daysBetween('2026-11-30', '2027-01-10'));
      expect(daysBetween('2026-12-31', '2027-01-01'), 1);
      expect(daysBetween('2027-01-01', '2026-12-31'), -1);
    });
  });
}
