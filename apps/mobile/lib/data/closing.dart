import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'cash.dart';
import 'masters.dart';
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

/// What closing looks for (REP-04). Anything of these left stops the month, because a closed month could never take it
/// in. Unpaid wages do not: they carry forward (PAY-03, D-045).
enum ClosingIssue { noHazri, noWorkerRate, noCompanyRate, overlap, payrollNotPosted, noMonthChosen }

/// The worker, company, attendance row or payment to open, and the name to show for it.
typedef ClosingTarget = ({String id, String name});

/// One kind of thing left on one date. Pay left unposted sits on the last day of its month.
class ClosingFinding {
  const ClosingFinding(this.issue, this.date, this.targets);

  final ClosingIssue issue;
  final String date;
  final List<ClosingTarget> targets;

  List<String> get names => [for (final t in targets) t.name];
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
  bool get canClose => finished && !closed && findings.isEmpty;
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
  /// Looks through every month not closed yet, up to this one, since closing it closes them too. Soonest date first.
  Future<List<ClosingFinding>> _findings(String month, String? closedThrough) async {
    final to = monthLastDay(month);
    final people = await select(workers).get();
    final nameOf = {for (final w in people) w.id: w.name};
    final found = <(ClosingIssue, String), Map<String, String>>{};
    void add(ClosingIssue issue, String date, String id, String name) => (found[(issue, date)] ??= {})[id] = name;

    final e = attendanceEntries;
    Expression<bool> inRange(Expression<String> date) => date.isSmallerOrEqualValue(to) & (closedThrough == null ? const Constant(true) : date.isBiggerThanValue(closedThrough));
    final live = e.superseded.equals(false) & inRange(e.workDate);
    Future<List<(String, String)>> byDate(GeneratedColumn<String> column, Expression<bool> where) async {
      final query = selectOnly(e, distinct: true)
        ..addColumns([column, e.workDate])
        ..where(where);
      return [for (final r in await query.get()) (r.read(column)!, r.read(e.workDate)!)];
    }

    for (final (id, date) in await byDate(e.workerId, live & e.state.equals('draft'))) {
      add(ClosingIssue.noWorkerRate, date, id, nameOf[id] ?? id);
    }

    final clients = {for (final c in await select(this.clients).get()) c.id: c.name};
    for (final (id, date) in await byDate(e.clientId, live & e.attendanceStatus.equals('absent').not() & e.clientRateFils.isNull())) {
      add(ClosingIssue.noCompanyRate, date, id, clients[id] ?? id);
    }

    for (final p in await payrollFor(month)) {
      if (!p.posted && (!p.figures.isEmpty || p.unpricedRows > 0)) add(ClosingIssue.payrollNotPosted, to, p.worker.id, p.worker.name);
    }
    for (final i in await (select(payrollItems)..where((i) => i.lineId.isNull() & inRange(i.periodFrom))).get()) {
      add(ClosingIssue.payrollNotPosted, monthLastDay(i.periodFrom.substring(0, 7)), i.workerId, nameOf[i.workerId] ?? i.workerId);
    }

    await _findGaps(to, closedThrough, people, (date, w) => add(ClosingIssue.noHazri, date, w.id, w.name));

    final shifts = selectOnly(e)
      ..addColumns([e.id, e.workerId, e.workDate, e.startUtc, e.endUtc, e.overlapReason])
      ..where(live & e.startUtc.isNotNull())
      ..orderBy([OrderingTerm.asc(e.workerId), OrderingTerm.asc(e.startUtc)]);
    TypedResult? previous;
    for (final r in await shifts.get()) {
      if (previous != null &&
          previous.read(e.workerId) == r.read(e.workerId) &&
          previous.read(e.endUtc)!.isAfter(r.read(e.startUtc)!) &&
          previous.read(e.overlapReason) == null &&
          r.read(e.overlapReason) == null) {
        add(ClosingIssue.overlap, r.read(e.workDate)!, r.read(e.id)!, nameOf[r.read(e.workerId)] ?? '');
      }
      previous = r;
    }

    final payments = await (select(cashEntries)..where((c) => c.kind.equals(CashKind.salaryPaid.name) & inRange(c.entryDate))).get();
    final undone = {for (final c in payments) ?c.reversesEntryId};
    final open = payments.where((c) => c.reversesEntryId == null && !undone.contains(c.id)).toList();
    final settled = {for (final a in await (select(salaryAllocations)..where((a) => a.paymentId.isIn(open.map((c) => c.id)))).get()) a.paymentId};
    for (final c in open.where((c) => !settled.contains(c.id))) {
      add(ClosingIssue.noMonthChosen, c.entryDate, c.id, '${nameOf[c.workerId] ?? ''} ${formatAed(c.amountFils)}');
    }

    final byName = [
      for (final f in found.entries) ClosingFinding(f.key.$1, f.key.$2, [for (final t in f.value.entries) (id: t.key, name: t.value)]..sort((a, b) => a.name.compareTo(b.name))),
    ];
    return byName..sort((a, b) {
      final date = a.date.compareTo(b.date);
      return date != 0 ? date : a.issue.index - b.issue.index;
    });
  }

  /// Days a working worker has neither attendance nor a day off, from the day they started. Nobody is asked about days
  /// before the app knew them, or about today. A worker on a monthly salary is paid whatever the register says, so their
  /// days are not asked for (D-045).
  Future<void> _findGaps(String to, String? closedThrough, List<Worker> people, void Function(String date, Worker worker) report) async {
    final e = attendanceEntries;
    final firstDay = e.workDate.min();
    final firstOf = {
      for (final r in await (selectOnly(e)
            ..addColumns([e.workerId, firstDay])
            ..where(e.superseded.equals(false))
            ..groupBy([e.workerId]))
          .get())
        r.read(e.workerId)!: r.read(firstDay)!,
    };
    final done = selectOnly(e, distinct: true)
      ..addColumns([e.workerId, e.workDate])
      ..where(e.superseded.equals(false) & e.workDate.isSmallerOrEqualValue(to) & (closedThrough == null ? const Constant(true) : e.workDate.isBiggerThanValue(closedThrough)));
    final seen = {for (final r in await done.get()) (r.read(e.workerId), r.read(e.workDate))};
    for (final d in await select(dayOffs).get()) {
      seen.add((d.workerId, d.workDate));
    }
    final monthly = groupedBy(await (select(payContracts)..where((c) => c.basis.equals(RateBasis.month.name))).get(), (c) => c.workerId);

    final yesterday = addDays(dubaiToday(DateTime.now()), -1);
    final last = to.compareTo(yesterday) < 0 ? to : yesterday;
    for (final w in people.where((w) => w.active)) {
      var start = dubaiToday(w.createdAtUtc);
      if (w.joiningDate != null && w.joiningDate!.compareTo(start) > 0) start = w.joiningDate!;
      final first = firstOf[w.id];
      if (first != null && first.compareTo(start) < 0) start = first;
      if (closedThrough != null && closedThrough.compareTo(start) >= 0) start = addDays(closedThrough, 1);
      for (var date = start; date.compareTo(last) <= 0; date = addDays(date, 1)) {
        final salaried = (monthly[w.id] ?? const <PayContract>[]).any((c) => c.effectiveFrom.compareTo(date) <= 0 && (c.effectiveTo == null || c.effectiveTo!.compareTo(date) >= 0));
        if (!salaried && !seen.contains((w.id, date))) report(date, w);
      }
    }
  }

  /// The owner's word that these workers had no work on this date.
  Future<void> markDayOff(String date, List<String> workerIds, {required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'day_offs',
      recordId: operationId,
      version: 1,
      action: 'create',
      change: () async {
        final now = DateTime.now().toUtc();
        await batch((b) {
          b.insertAll(
            dayOffs,
            [
              for (final id in workerIds)
                DayOffsCompanion.insert(id: newUuid(), tenantId: tenantId, createdAtUtc: now, updatedAtUtc: now, actorId: actorId, sourceOperationId: operationId, workerId: id, workDate: date),
            ],
            mode: InsertMode.insertOrIgnore,
          );
        });
        return {'date': date, 'workers': workerIds};
      },
    );
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
      TableUpdateQuery.onAllTables([attendanceEntries, payContracts, payrollItems, payrollLines, cashEntries, salaryAllocations, openingBalances, workers, periodLocks, dayOffs]),
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
