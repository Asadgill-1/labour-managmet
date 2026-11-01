import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/payroll.dart';
import 'package:domain/statement.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'masters.dart';
import 'tenant_database.dart';

enum StatementMoneyKind { advance, advanceReturned, room, visa, deduction, paid }

/// A dated line of money on a worker's month.
class StatementMoney {
  const StatementMoney(this.date, this.kind, this.fils, {this.note});

  final String date;
  final StatementMoneyKind kind;
  final int fils;
  final String? note;
}

/// One worker's month, from the stored rows. A mistake undone in the cash book leaves no trace here, because this is
/// what the worker reads. Advance counts when given, and visa money when it is cut from pay, which is the money the
/// worker actually sees go (D-042).
class WorkerStatement {
  const WorkerStatement({
    required this.worker,
    required this.month,
    required this.openingFils,
    required this.workFils,
    required this.salaryFils,
    required this.allowanceFils,
    required this.advanceFils,
    required this.roomFils,
    required this.visaFils,
    required this.otherFils,
    required this.paidFils,
    required this.visaLeftFils,
    required this.work,
    required this.money,
  });

  final Worker worker;
  final String month;

  /// Left from earlier months.
  final int openingFils;
  final int workFils;
  final int salaryFils;
  final int allowanceFils;

  /// Given less handed back.
  final int advanceFils;
  final int roomFils;
  final int visaFils;
  final int otherFils;
  final int paidFils;

  /// Visa money still to come out of pay. It is not part of the balance until it does.
  final int visaLeftFils;

  /// This month's attendance, oldest first.
  final List<AttendanceEntry> work;
  final List<StatementMoney> money;

  int get earnedFils => workFils + salaryFils + allowanceFils;
  int get takenFils => advanceFils + roomFils + visaFils + otherFils + paidFils;
  int get closingFils => openingFils + earnedFils - takenFils;
  bool get hasSomething => work.isNotEmpty || money.isNotEmpty || openingFils != 0 || earnedFils != 0;
}

extension StatementOps on TenantDatabase {
  /// Everyone's month, or one worker's. Older months are only added up in the database, so a year of history costs
  /// no more than a month of it (REP-08).
  Future<List<WorkerStatement>> statementsFor(String month, {String? workerId}) async {
    final from = monthFirstDay(month);
    final to = monthLastDay(month);
    final latestPayment = monthLastDay(addMonths(month, 1));
    final thisMonth = dubaiToday(DateTime.now()).substring(0, 7);

    final people = await (select(workers)
          ..where((w) => workerId == null ? const Constant(true) : w.id.equals(workerId))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();

    final monthOf = attendanceEntries.workDate.substr(1, 7);
    final earned = attendanceEntries.workerAmountFils.sum();
    final sums = await (selectOnly(attendanceEntries)
          ..addColumns([attendanceEntries.workerId, monthOf, earned])
          ..where(attendanceEntries.superseded.equals(false) & attendanceEntries.workDate.isSmallerOrEqualValue(to) & (workerId == null ? const Constant(true) : attendanceEntries.workerId.equals(workerId)))
          ..groupBy([attendanceEntries.workerId, monthOf]))
        .get();
    final sumsOf = groupedBy(sums, (r) => r.read(attendanceEntries.workerId)!);

    final rows = await (select(attendanceEntries)
          ..where((e) => e.superseded.equals(false) & e.workDate.isBetweenValues(from, to) & (workerId == null ? const Constant(true) : e.workerId.equals(workerId)))
          ..orderBy([(e) => OrderingTerm.asc(e.workDate), (e) => OrderingTerm.asc(e.createdAtUtc)]))
        .get();
    final rowsOf = groupedBy(rows, (e) => e.workerId);

    final cash = await (select(cashEntries)
          ..where((c) => c.entryDate.isSmallerOrEqualValue(latestPayment) & (workerId == null ? c.workerId.isNotNull() : c.workerId.equals(workerId)))
          ..orderBy([(c) => OrderingTerm.asc(c.entryDate), (c) => OrderingTerm.asc(c.createdAtUtc)]))
        .get();
    final undone = {for (final c in cash) ?c.reversesEntryId};
    final cashOf = groupedBy(cash.where((c) => c.reversesEntryId == null && !undone.contains(c.id)), (c) => c.workerId);

    final items = await (select(payrollItems)
          ..where((i) => i.periodFrom.isSmallerOrEqualValue(from) & (workerId == null ? const Constant(true) : i.workerId.equals(workerId)))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAtUtc)]))
        .get();
    final itemsOf = groupedBy(items, (i) => i.workerId);

    final lines = await (select(payrollLines)
          ..where((l) => l.reversed.equals(false) & l.periodFrom.isSmallerOrEqualValue(from) & (workerId == null ? const Constant(true) : l.workerId.equals(workerId)))
          ..orderBy([(l) => OrderingTerm.asc(l.periodFrom)]))
        .get();
    final linesOf = groupedBy(lines, (l) => l.workerId);

    final openings = await (select(openingBalances)..where((b) => workerId == null ? b.workerId.isNotNull() : b.workerId.equals(workerId))).get();
    final openingsOf = groupedBy(openings, (b) => b.workerId);
    final contracts = await (select(payContracts)..where((c) => c.basis.equals(RateBasis.month.name))).get();
    final contractsOf = groupedBy(contracts, (c) => c.workerId);

    final result = <WorkerStatement>[];
    for (final worker in people) {
      final own = <String, int>{};
      void add(String m, int fils) => own[m] = (own[m] ?? 0) + fils;
      for (final r in sumsOf[worker.id] ?? const <TypedResult>[]) {
        add(r.read(monthOf)!, r.read(earned) ?? 0);
      }

      var allowance = 0, room = 0, visa = 0, other = 0, visaCut = 0;
      final money = <StatementMoney>[];
      for (final i in itemsOf[worker.id] ?? const <PayrollItem>[]) {
        final m = i.periodFrom.substring(0, 7);
        final current = i.periodFrom == from;
        void cut(StatementMoneyKind kind, void Function() count) {
          add(m, -i.amountFils);
          if (current) {
            count();
            money.add(StatementMoney(monthLastDay(month), kind, i.amountFils, note: i.reason));
          }
        }

        switch (PayItemKind.values.byName(i.kind)) {
          case PayItemKind.allowance:
            add(m, i.amountFils);
            if (current) allowance += i.amountFils;
          case PayItemKind.roomCharge:
            cut(StatementMoneyKind.room, () => room += i.amountFils);
          case PayItemKind.deduction:
            cut(StatementMoneyKind.deduction, () => other += i.amountFils);
          case PayItemKind.visaRecovery:
            visaCut += i.amountFils;
            cut(StatementMoneyKind.visa, () => visa += i.amountFils);
          // Counted when the advance was given.
          case PayItemKind.advanceRecovery:
            break;
        }
      }

      var advance = 0, visaGiven = 0;
      final payments = <StatementPayment>[];
      for (final c in cashOf[worker.id] ?? const <CashEntry>[]) {
        final m = c.entryDate.substring(0, 7);
        final current = m == month;
        switch (CashKind.values.byName(c.kind)) {
          case CashKind.salaryPaid:
            payments.add(StatementPayment(c.entryDate, c.amountFils, note: c.note ?? c.method));
          case CashKind.advanceGiven:
            if (m.compareTo(month) > 0) break;
            add(m, -c.amountFils);
            if (current) {
              advance += c.amountFils;
              money.add(StatementMoney(c.entryDate, StatementMoneyKind.advance, c.amountFils, note: c.note));
            }
          case CashKind.advanceReturned:
            if (m.compareTo(month) > 0) break;
            add(m, c.amountFils);
            if (current) {
              advance -= c.amountFils;
              money.add(StatementMoney(c.entryDate, StatementMoneyKind.advanceReturned, -c.amountFils, note: c.note));
            }
          case CashKind.visaPaid:
            if (c.entryDate.compareTo(to) <= 0) visaGiven += c.amountFils;
          case CashKind.visaReturned:
            if (c.entryDate.compareTo(to) <= 0) visaGiven -= c.amountFils;
          // Rent the worker paid in cash is the room's money, not part of their wage.
          case CashKind.roomRentPaid || CashKind.roomRentReceived || CashKind.expense || CashKind.clientReceipt:
            break;
        }
      }

      // Money from before this app is old balance, never this month's advance or earnings (MASTER-05).
      final brought = <String, int>{};
      for (final b in openingsOf[worker.id] ?? const <OpeningBalance>[]) {
        final m = b.asOfDate.substring(0, 7);
        if (b.kind == 'worker_salary_owed') brought[m] = (brought[m] ?? 0) + b.amountFils;
        if (b.kind == 'worker_advance') brought[m] = (brought[m] ?? 0) - b.amountFils;
      }

      // A monthly salary counts once its month is posted, and until then at what posting would pay. A contract dated
      // from the hiring date must not run up years of pay nobody recorded, so it counts from the account's first activity.
      final workerLines = linesOf[worker.id] ?? const <PayrollLine>[];
      final salaries = {for (final l in workerLines) l.periodFrom.substring(0, 7): l.salaryFils};
      final monthly = worker.active ? (contractsOf[worker.id] ?? const <PayContract>[]).map(payTerms).toList() : const <RateTerms>[];
      if (monthly.isNotEmpty) {
        final lastPosted = workerLines.lastOrNull?.periodFrom.substring(0, 7);
        final firstContract = monthly.map((c) => c.effectiveFrom.substring(0, 7)).reduce((a, b) => a.compareTo(b) < 0 ? a : b);
        final activity = [...own.keys, ...brought.keys, ...payments.map((p) => p.date.substring(0, 7)), month]..sort();
        final first = firstContract.compareTo(activity.first) > 0 ? firstContract : activity.first;
        for (var m = first; m.compareTo(month) <= 0 && m.compareTo(thisMonth) <= 0; m = addMonths(m, 1)) {
          if (!salaries.containsKey(m) && (lastPosted == null || m.compareTo(lastPosted) > 0)) salaries[m] = periodSalary(monthly, m) ?? 0;
        }
      }
      salaries.forEach(add);

      final months = monthStatements(ownByMonth: own, broughtByMonth: brought, payments: payments, through: month);
      final statement = months.where((s) => s.month == month).firstOrNull;
      money
        ..addAll([for (final p in statement?.payments ?? const <StatementPayment>[]) StatementMoney(p.date, StatementMoneyKind.paid, p.fils, note: p.note)])
        ..sort((a, b) => a.date.compareTo(b.date));

      final work = rowsOf[worker.id] ?? const <AttendanceEntry>[];
      final one = WorkerStatement(
        worker: worker,
        month: month,
        openingFils: statement?.openingFils ?? 0,
        workFils: work.fold(0, (total, e) => total + (e.workerAmountFils ?? 0)),
        salaryFils: salaries[month] ?? 0,
        allowanceFils: allowance,
        advanceFils: advance,
        roomFils: room,
        visaFils: visa,
        otherFils: other,
        paidFils: statement?.paidFils ?? 0,
        visaLeftFils: visaGiven - visaCut,
        work: work,
        money: money,
      );
      if (workerId != null || one.hasSomething) result.add(one);
    }
    return result;
  }
}
