import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'cash.dart';
import 'payroll.dart';
import 'statement.dart';
import 'tenant_database.dart';

/// Something would be stranded by the lock, or the month cannot close yet (REP-04).
class MonthNotReady implements Exception {
  const MonthNotReady();
}

/// A later month is closed, so this one cannot be opened first.
class LaterMonthClosed implements Exception {
  const LaterMonthClosed();
}

/// What closing looks for (REP-04). A missing worker rate and unposted pay stop it, because a closed month could never
/// take them in. The rest are for the owner to see and confirm (D-044).
enum ClosingIssue { noWorkerRate, payrollNotPosted, noCompanyRate, noHazri, overlap, noMonthChosen }

class ClosingFinding {
  const ClosingFinding(this.issue, this.names);

  final ClosingIssue issue;
  final List<String> names;

  bool get stops => issue == ClosingIssue.noWorkerRate || issue == ClosingIssue.payrollNotPosted;
}

/// One month as the closing screen shows it. Everything derives from the stored rows (REP-08).
class MonthClosing {
  const MonthClosing({required this.month, required this.finished, required this.closedThrough, required this.lock, required this.findings, required this.statements, required this.expensesFils});

  final String month;

  /// The month has ended.
  final bool finished;

  /// The last day of the latest closed month.
  final String? closedThrough;

  /// This month's own lock, when it was closed by name rather than with a later one.
  final PeriodLock? lock;
  final List<ClosingFinding> findings;
  final List<WorkerStatement> statements;
  final int expensesFils;

  bool get closed => isClosed(monthLastDay(month), closedThrough);
  bool get canClose => finished && !closed && !findings.any((f) => f.stops);
  bool get canReopen => lock != null && lock!.lastDay == closedThrough;

  int _sum(int Function(WorkerStatement s) of) => statements.fold(0, (total, s) => total + of(s));
  int get openingFils => _sum((s) => s.openingFils);
  int get earnedFils => _sum((s) => s.earnedFils);
  int get advanceFils => _sum((s) => s.advanceFils);
  int get cutFils => _sum((s) => s.roomFils + s.visaFils + s.otherFils);
  int get paidFils => _sum((s) => s.paidFils);
  int get closingFils => _sum((s) => s.closingFils);
}

extension ClosingOps on TenantDatabase {
  /// Looks through every month not closed yet, up to this one, since closing it closes them too.
  Future<List<ClosingFinding>> _findings(String month, String? closedThrough) async {
    final to = monthLastDay(month);
    final people = await select(workers).get();
    final nameOf = {for (final w in people) w.id: w.name};
    List<String> named(Iterable<String> ids) => (ids.toSet().map((id) => nameOf[id] ?? id).toList()..sort());

    final e = attendanceEntries;
    Expression<bool> inRange(Expression<String> date) => date.isSmallerOrEqualValue(to) & (closedThrough == null ? const Constant(true) : date.isBiggerThanValue(closedThrough));
    final live = e.superseded.equals(false) & inRange(e.workDate);
    Future<List<String>> ids(GeneratedColumn<String> column, Expression<bool> where) async {
      final query = selectOnly(e, distinct: true)
        ..addColumns([column])
        ..where(where);
      return [for (final r in await query.get()) r.read(column)!];
    }

    final noRate = await ids(e.workerId, live & e.state.equals('draft'));
    final notPosted = {
      for (final p in await payrollFor(month))
        if (!p.posted && (!p.figures.isEmpty || p.unpricedRows > 0)) p.worker.id,
      for (final i in await (select(payrollItems)..where((i) => i.lineId.isNull() & inRange(i.periodFrom))).get()) i.workerId,
    };

    final noBill = await ids(e.clientId, live & e.attendanceStatus.equals('absent').not() & e.clientRateFils.isNull());
    final clients = {for (final c in await select(this.clients).get()) c.id: c.name};

    final seen = (await ids(e.workerId, live)).toSet();
    final monthEnd = dubaiToUtc(to, 24 * 60);
    final noHazri = people.where((w) => w.active && w.createdAtUtc.isBefore(monthEnd) && !seen.contains(w.id)).map((w) => w.id);

    final shifts = selectOnly(e)
      ..addColumns([e.workerId, e.startUtc, e.endUtc, e.overlapReason])
      ..where(live & e.startUtc.isNotNull())
      ..orderBy([OrderingTerm.asc(e.workerId), OrderingTerm.asc(e.startUtc)]);
    final overlapping = <String>{};
    TypedResult? previous;
    for (final r in await shifts.get()) {
      if (previous != null &&
          previous.read(e.workerId) == r.read(e.workerId) &&
          previous.read(e.endUtc)!.isAfter(r.read(e.startUtc)!) &&
          previous.read(e.overlapReason) == null &&
          r.read(e.overlapReason) == null) {
        overlapping.add(r.read(e.workerId)!);
      }
      previous = r;
    }

    final payments = await (select(cashEntries)..where((c) => c.kind.equals(CashKind.salaryPaid.name) & inRange(c.entryDate))).get();
    final undone = {for (final c in payments) ?c.reversesEntryId};
    final open = payments.where((c) => c.reversesEntryId == null && !undone.contains(c.id)).toList();
    final settled = {for (final a in await (select(salaryAllocations)..where((a) => a.paymentId.isIn(open.map((c) => c.id)))).get()) a.paymentId};
    final noMonth = open.where((c) => !settled.contains(c.id)).map((c) => c.workerId!);

    return [
      if (noRate.isNotEmpty) ClosingFinding(ClosingIssue.noWorkerRate, named(noRate)),
      if (notPosted.isNotEmpty) ClosingFinding(ClosingIssue.payrollNotPosted, named(notPosted)),
      if (noBill.isNotEmpty) ClosingFinding(ClosingIssue.noCompanyRate, (noBill.map((id) => clients[id] ?? id).toList()..sort())),
      if (noHazri.isNotEmpty) ClosingFinding(ClosingIssue.noHazri, named(noHazri)),
      if (overlapping.isNotEmpty) ClosingFinding(ClosingIssue.overlap, named(overlapping)),
      if (noMonth.isNotEmpty) ClosingFinding(ClosingIssue.noMonthChosen, named(noMonth)),
    ];
  }

  Future<MonthClosing> closingFor(String month) async {
    final closedThrough = await lockedThrough();
    final to = monthLastDay(month);
    final closed = isClosed(to, closedThrough);
    final lock = await (select(periodLocks)..where((l) => l.month.equals(month) & l.reopened.equals(false))).getSingleOrNull();
    final expenses = await (select(cashEntries)..where((c) => c.kind.equals(CashKind.expense.name) & c.entryDate.isBetweenValues(monthFirstDay(month), to))).get();
    return MonthClosing(
      month: month,
      finished: to.compareTo(dubaiToday(DateTime.now())) < 0,
      closedThrough: closedThrough,
      lock: lock,
      findings: closed ? const [] : await _findings(month, closedThrough),
      statements: await statementsFor(month, withWork: false),
      expensesFils: expenses.fold(0, (total, c) => total + cashLine(c).signedFils),
    );
  }

  /// Sends a fresh copy whenever anything behind it changes.
  Stream<MonthClosing> watchClosing(String month) async* {
    yield await closingFor(month);
    final changes = tableUpdates(
      TableUpdateQuery.onAllTables([attendanceEntries, payContracts, payrollItems, payrollLines, cashEntries, salaryAllocations, openingBalances, workers, periodLocks]),
    );
    await for (final _ in changes) {
      yield await closingFor(month);
    }
  }

  /// Closes a month and every open month before it, on the owner's confirmation (REP-04). The rows nobody has frozen yet,
  /// which pay nothing, freeze with it, so nothing in a closed month is left waiting on a later posting.
  Future<void> closeMonth(String month, {required String operationId}) {
    final id = newUuid();
    return applyOperation(
      operationId: operationId,
      entity: 'period_locks',
      recordId: id,
      version: 1,
      action: 'close',
      change: () async {
        if (!(await closingFor(month)).canClose) throw const MonthNotReady();
        final open = await unapprovedUpTo(month);
        if (open.isNotEmpty) await approveEntries(open, operationId: newUuid());
        final now = DateTime.now().toUtc();
        final row = await into(periodLocks).insertReturning(
          PeriodLocksCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            month: month,
            lastDay: monthLastDay(month),
          ),
        );
        return row.toJson();
      },
    );
  }

  /// Opens the latest closed month again, with the owner's reason on record. The lock stays, flagged (REP-04, D-044).
  Future<void> reopenMonth(PeriodLock lock, {required String reason, required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'period_locks',
      recordId: lock.id,
      version: lock.version + 1,
      action: 'reopen',
      reason: reason,
      change: () async {
        if (await lockedThrough() != lock.lastDay) throw const LaterMonthClosed();
        await (update(periodLocks)..where((l) => l.id.equals(lock.id))).write(
          PeriodLocksCompanion(reopened: const Value(true), version: Value(lock.version + 1), updatedAtUtc: Value(DateTime.now().toUtc()), sourceOperationId: Value(operationId)),
        );
        return (await (select(periodLocks)..where((l) => l.id.equals(lock.id))).getSingle()).toJson();
      },
    );
  }
}
