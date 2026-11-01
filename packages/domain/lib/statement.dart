import 'dates.dart';

/// A salary payment. It stays whole on one month's statement, however much it covers.
class StatementPayment {
  const StatementPayment(this.date, this.fils, {this.note});

  final String date;
  final int fils;
  final String? note;
}

/// One month of a worker's account, read like a bank statement: where it started, what the month added, what was paid.
class MonthStatement {
  const MonthStatement({required this.month, required this.openingFils, required this.ownFils, required this.payments});

  final String month;

  /// Left from earlier months, and anything brought from before this app.
  final int openingFils;

  /// What the month itself added: earnings less advance and deductions.
  final int ownFils;
  final List<StatementPayment> payments;

  int get paidFils => payments.fold(0, (total, p) => total + p.fils);
  int get closingFils => openingFils + ownFils - paidFils;
}

/// One worker's months, oldest first, up to and including [through]. Each closing is the next opening, so a run of
/// statements always adds up, and the last one is the account's balance (REP-08).
///
/// Wages are paid after the month they are for, so a payment goes on the month before its date while that month still
/// has something owing, and on its own month after that (D-042). It only decides where a payment shows, never how much is owed.
/// ponytail: a guess at what each payment was for. T12 lets the owner say which month a payment settles (PAY-06).
List<MonthStatement> monthStatements({
  required Map<String, int> ownByMonth,
  required List<StatementPayment> payments,
  required String through,
  Map<String, int> broughtByMonth = const {},
}) {
  final sorted = [...payments]..sort((a, b) => a.date.compareTo(b.date));
  final starts = [...ownByMonth.keys, ...broughtByMonth.keys, if (sorted.isNotEmpty) sorted.first.date.substring(0, 7)];
  if (starts.isEmpty) return const [];
  starts.sort();

  final result = <MonthStatement>[];
  var next = 0;
  var balance = 0;
  for (var month = starts.first; month.compareTo(through) <= 0; month = addMonths(month, 1)) {
    balance += broughtByMonth[month] ?? 0;
    final opening = balance;
    final own = ownByMonth[month] ?? 0;
    balance += own;
    final taken = <StatementPayment>[];
    void take() {
      taken.add(sorted[next]);
      balance -= sorted[next].fils;
      next++;
    }

    while (next < sorted.length && sorted[next].date.substring(0, 7).compareTo(month) <= 0) {
      take();
    }
    final following = addMonths(month, 1);
    while (next < sorted.length && balance > 0 && sorted[next].date.substring(0, 7) == following) {
      take();
    }
    result.add(MonthStatement(month: month, openingFils: opening, ownFils: own, payments: taken));
  }
  return result;
}
