import 'dart:math';

import 'dates.dart';

/// A salary payment, or the part of one that settles a given month.
class StatementPayment {
  const StatementPayment(this.date, this.fils, {this.note, this.parts, this.id});

  final String date;
  final int fils;
  final String? note;

  /// The months this payment settles, as the owner confirmed them (PAY-06). Null on a payment from before months could be chosen.
  final Map<String, int>? parts;

  /// The stored payment this came from, when something needs to go back to it.
  final String? id;
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

/// What each month still owes. A month below zero is a credit, which comes off the oldest months first,
/// so the sum is always the whole account, and never below zero.
Map<String, int> unpaidByMonth(Map<String, int> netByMonth) {
  var credit = netByMonth.values.where((v) => v < 0).fold(0, (total, v) => total - v);
  final result = <String, int>{};
  for (final month in netByMonth.keys.toList()..sort()) {
    final net = netByMonth[month]!;
    if (net <= 0) continue;
    final taken = min(credit, net);
    credit -= taken;
    if (net > taken) result[month] = net - taken;
  }
  return result;
}

/// Shares [fils] across unpaid months, oldest first, with what is left over beyond them all (PAY-06).
({Map<String, int> parts, int extraFils}) splitOldestFirst(Map<String, int> unpaid, int fils) {
  final parts = <String, int>{};
  var left = fils;
  for (final month in unpaid.keys.toList()..sort()) {
    if (left == 0) break;
    final taken = min(left, unpaid[month]!);
    parts[month] = taken;
    left -= taken;
  }
  return (parts: parts, extraFils: left);
}

/// Each month with the payments that settle it. The owner's own choice stands. A payment with none goes oldest first
/// among months up to its date, and anything over stays on its own month. This only decides where a payment shows,
/// never how much is owed (D-043).
Map<String, List<StatementPayment>> placePayments(Map<String, int> owedByMonth, List<StatementPayment> payments) {
  final net = {...owedByMonth};
  final placed = <String, List<StatementPayment>>{};
  void put(StatementPayment p, String month, int fils) {
    net[month] = (net[month] ?? 0) - fils;
    (placed[month] ??= []).add(StatementPayment(p.date, fils, note: p.note, id: p.id));
  }

  for (final p in payments) {
    p.parts?.forEach((month, fils) => put(p, month, fils));
  }
  for (final p in payments.where((p) => p.parts == null).toList()..sort((a, b) => a.date.compareTo(b.date))) {
    final own = p.date.substring(0, 7);
    final split = splitOldestFirst(unpaidByMonth({...net}..removeWhere((month, _) => month.compareTo(own) > 0)), p.fils);
    split.parts.forEach((month, fils) => put(p, month, fils));
    if (split.extraFils > 0) put(p, own, split.extraFils);
  }
  return placed;
}

/// What is left of each month up to [through], once the placed payments have come off.
Map<String, int> unpaidAfter(Map<String, int> owedByMonth, Map<String, List<StatementPayment>> placed, {required String through}) {
  final net = {...owedByMonth};
  placed.forEach((month, pieces) => net[month] = (net[month] ?? 0) - pieces.fold(0, (total, p) => total + p.fils));
  return unpaidByMonth(net..removeWhere((month, _) => month.compareTo(through) > 0));
}

/// One worker's months, oldest first, up to and including [through]. Each closing is the next opening, so a run of
/// statements always adds up, and the last one is the account's balance (REP-08).
List<MonthStatement> monthStatements({
  required Map<String, int> ownByMonth,
  required Map<String, List<StatementPayment>> placed,
  required String through,
  Map<String, int> broughtByMonth = const {},
}) {
  final starts = [...ownByMonth.keys, ...broughtByMonth.keys, ...placed.keys];
  if (starts.isEmpty) return const [];
  starts.sort();

  final result = <MonthStatement>[];
  var balance = 0;
  for (var month = starts.first; month.compareTo(through) <= 0; month = addMonths(month, 1)) {
    balance += broughtByMonth[month] ?? 0;
    final statement = MonthStatement(month: month, openingFils: balance, ownFils: ownByMonth[month] ?? 0, payments: placed[month] ?? const []);
    balance = statement.closingFils;
    result.add(statement);
  }
  return result;
}

/// One finished month's wage that is still unpaid. [daysLate] above zero means it is past the day it fell due.
class WageDue {
  const WageDue(this.month, this.fils, this.daysLate);

  final String month;
  final int fils;
  final int daysLate;

  bool get overdue => daysLate > 0;
}

/// Finished months with something unpaid, oldest first. A month falls due [dueDays] after its last day. The company
/// sets those days, and no legal period is assumed. With none set, a month is due the day it ends (PAY-08, D-043).
List<WageDue> wagesDue(Map<String, int> unpaid, {required String today, int? dueDays}) {
  return [
    for (final month in unpaid.keys.toList()..sort())
      if (monthLastDay(month).compareTo(today) < 0) WageDue(month, unpaid[month]!, daysBetween(addDays(monthLastDay(month), dueDays ?? 0), today)),
  ];
}
