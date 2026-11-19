import 'dart:math';

import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'cash.dart';
import 'masters.dart';
import 'tenant_database.dart';

/// A later month is posted for this worker, so this one cannot be undone first (PAY-03).
class LaterMonthPosted implements Exception {
  const LaterMonthPosted();
}

/// The few columns payroll needs from an unpaid row. A thousand workers' rows as whole objects cost seconds on every look.
typedef _UnpaidRow = ({String workerId, String workDate, int? amountFils, String state, String? revisesEntryId, String status});

/// One worker's month. A posted month shows its stored line, otherwise a live preview (PAY-01).
class WorkerPayroll {
  const WorkerPayroll({
    required this.worker,
    required this.figures,
    required this.items,
    required this.openingFils,
    required this.paidTotalFils,
    required this.advanceLeftFils,
    this.visaLeftFils = 0,
    this.line,
    this.paidFils = 0,
    this.unpricedRows = 0,
    this.autoRecoveryFils = 0,
    this.askRecoveryFils = 0,
  });

  final Worker worker;
  final PayrollFigures figures;
  final List<PayrollItem> items;

  /// Owed before this month. Below zero means paid in advance of it, which is a credit (PAY-06).
  final int openingFils;

  /// Every salary payment to this worker so far.
  final int paidTotalFils;
  final int advanceLeftFils;
  final int visaLeftFils;
  final PayrollLine? line;

  /// Paid since this month was posted.
  final int paidFils;

  /// Rows whose pay cannot be worked out yet, because a rate is missing.
  final int unpricedRows;

  /// The advance instalments this month cuts by itself, already in [figures], and stored when it posts (D-057).
  final int autoRecoveryFils;

  /// What is left on advances with no instalment, while the owner has not said how much of it to cut.
  final int askRecoveryFils;

  bool get posted => line != null;
  bool get canPost => !posted && figures.issues.isEmpty && !figures.isEmpty;

  /// An item added to a month behind a later posted one could never post, so none is added there (PAY-02).
  bool get canAddItems => !posted && !figures.issues.contains(PayrollIssue.laterMonthPosted);
  bool get canAddRoomCharge => canAddItems && !items.any((i) => i.kind == PayItemKind.roomCharge.name);
  /// Not on a month that only waits to take money back: it has nothing to cut from, and an instalment would stop it (D-080 (6)).
  bool get needsVisaInstalment =>
      canAddItems && !figures.issues.contains(PayrollIssue.takesBackLater) && (worker.visaInstalmentFils ?? 0) > 0 && visaLeftFils > 0 && !items.any((i) => i.kind == PayItemKind.visaRecovery.name);
  int get payableFils => openingFils + figures.dueFils;
  int get closingFils => payableFils - paidFils;
}

PayrollFigures _postedFigures(PayrollLine l) => PayrollFigures(
  earnedFils: l.earnedFils,
  salaryFils: l.salaryFils,
  adjustmentFils: l.adjustmentFils,
  allowancesFils: l.allowancesFils,
  deductionsFils: l.deductionsFils,
  recoveryFils: l.recoveryFils,
  visaFils: l.visaRecoveryFils,
  absenceFils: l.absenceFils,
  absentDays: l.absentDays?.split(',') ?? const [],
);

/// Money that starts a worker's account: salary paid, or advance given or returned. A mistake undone in its own month is none (D-042 (5)).
Iterable<CashEntry> _accountCash(List<CashEntry> cash) {
  final dateOf = {for (final c in cash) c.id: c.entryDate};
  final undone = {
    for (final c in cash)
      if (c.reversesEntryId != null && c.entryDate.substring(0, 7) == dateOf[c.reversesEntryId]?.substring(0, 7)) ...[c.id, c.reversesEntryId!],
  };
  final counted = {CashKind.salaryPaid.name, CashKind.advanceGiven.name, CashKind.advanceReturned.name};
  return cash.where((c) => counted.contains(c.kind) && !undone.contains(c.id));
}

extension PayrollOps on TenantDatabase {
  /// What a corrected row's originals were already paid. Only the latest paid version counts, since each holds the whole amount (ATT-08).
  Future<int> _alreadyPaid(String? revises) async {
    var id = revises;
    while (id != null) {
      final old = await (select(attendanceEntries)..where((e) => e.id.equals(id!))).getSingle();
      if (old.payrollLineId != null) return old.workerAmountFils ?? 0;
      id = old.revisesEntryId;
    }
    return 0;
  }

  /// Days of a posted month's absence cut that a later month's line gave back already: worked rows dated in a month and paid
  /// by a later one, by worker. A row corrected since still counts, so no day is given back twice (D-080 (5)).
  Future<Map<String, Set<String>>> _cutDaysPaidBack({String? workerId}) async {
    final e = attendanceEntries;
    final query = selectOnly(e).join([innerJoin(payrollLines, payrollLines.id.equalsExp(e.payrollLineId), useColumns: false)])
      ..addColumns([e.workerId, e.workDate])
      ..where(payrollLines.periodFrom.isBiggerThan(e.workDate) & e.attendanceStatus.isNotValue(AttendanceStatus.absent.name) & (workerId == null ? const Constant(true) : e.workerId.equals(workerId)));
    final back = <String, Set<String>>{};
    for (final r in await query.get()) {
      final String id = r.read(e.workerId)!;
      (back[id] ??= <String>{}).add(r.read(e.workDate)!);
    }
    return back;
  }

  /// What each posted month's absence cut gives back for days in it worked after all, by worker, month and day: what later
  /// postings gave back and what the next one will (D-080 (5)). Late work counts in the month it was done, so the worker's
  /// statement and register count this in the month it was cut.
  Future<Map<String, Map<String, Map<String, int>>>> cutsGivenBack({String? workerId}) async {
    Expression<bool> whose(GeneratedColumn<String> column) => workerId == null ? const Constant(true) : column.equals(workerId);
    final cut = await (select(payrollLines)..where((l) => l.reversed.equals(false) & l.absentDays.isNotNull() & whose(l.workerId))).get();
    if (cut.isEmpty) return const {};
    final worked = await _cutDaysPaidBack(workerId: workerId);
    final latest = cut.map((l) => l.periodFrom).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    final e = attendanceEntries;
    final unpaid = selectOnly(e, distinct: true)
      ..addColumns([e.workerId, e.workDate])
      ..where(
        e.superseded.equals(false) &
            e.payrollLineId.isNull() &
            e.state.isNotValue('draft') &
            e.attendanceStatus.isNotValue(AttendanceStatus.absent.name) &
            e.workDate.isSmallerOrEqualValue(monthLastDay(latest.substring(0, 7))) &
            whose(e.workerId),
      );
    for (final r in await unpaid.get()) {
      final String id = r.read(e.workerId)!;
      (worked[id] ??= <String>{}).add(r.read(e.workDate)!);
    }
    final contractsOf = groupedBy(await (select(payContracts)..where((c) => whose(c.workerId))).get(), (c) => c.workerId);
    final result = <String, Map<String, Map<String, int>>>{};
    for (final l in cut) {
      final days = worked[l.workerId];
      if (days == null) continue;
      final month = l.periodFrom.substring(0, 7);
      final terms = (contractsOf[l.workerId] ?? const <PayContract>[]).map(payTerms);
      final given = cutGivenBack(terms, month, cutFils: l.absenceFils, cutDays: l.absentDays!.split(','), worked: days);
      if (given.isNotEmpty) (result[l.workerId] ??= {})[month] = given;
    }
    return result;
  }

  /// Workers whose account has not started: nothing posted, and no attendance, item, old balance or money, the activity a
  /// salary counts from (D-079 (3)), so no month of theirs is on payroll. Closing asks about their days as for a daily
  /// worker, so a new worker whose attendance was forgotten is not left out (D-080 (4)).
  Future<Set<String>> workersWithoutAccount() async {
    Future<Set<String>> who<T extends HasResultSet, R>(ResultSetImplementation<T, R> table, GeneratedColumn<String> worker, Expression<bool> where) async => {
      for (final r in await (selectOnly(table, distinct: true)
            ..addColumns([worker])
            ..where(where))
          .get())
        ?r.read(worker),
    };
    final started = {
      ...await who(payrollLines, payrollLines.workerId, payrollLines.reversed.equals(false)),
      ...await who(attendanceEntries, attendanceEntries.workerId, attendanceEntries.superseded.equals(false)),
      ...await who(payrollItems, payrollItems.workerId, payrollItems.kind.equals(PayItemKind.advanceRecovery.name).not()),
      ...await who(openingBalances, openingBalances.workerId, openingBalances.kind.isIn(const ['worker_salary_owed', 'worker_advance'])),
      for (final c in _accountCash(await (select(cashEntries)..where((c) => c.workerId.isNotNull())).get())) c.workerId!,
    };
    return {for (final w in await select(workers).get()) w.id}.difference(started);
  }

  /// Everyone with something to pay or review this month, worked out fresh from the stored rows (REP-08).
  Future<List<WorkerPayroll>> payrollFor(String month) async {
    final from = monthFirstDay(month);
    final to = monthLastDay(month);
    final limitBps = (await select(tenantProfiles).getSingleOrNull())?.deductionLimitBps;
    final closedThrough = await lockedThrough();
    final allWorkers = await (select(workers)..orderBy([(w) => OrderingTerm.asc(w.name)])).get();
    final contracts = await select(payContracts).get();
    final items = await (select(payrollItems)
          ..where((i) => i.periodFrom.equals(from))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAtUtc)]))
        .get();
    final lines = await (select(payrollLines)
          ..where((l) => l.reversed.equals(false))
          ..orderBy([(l) => OrderingTerm.asc(l.periodFrom)]))
        .get();
    final e = attendanceEntries;
    final unpaidQuery = selectOnly(e)
      ..addColumns([e.workerId, e.workDate, e.workerAmountFils, e.state, e.revisesEntryId, e.attendanceStatus])
      ..where(e.superseded.equals(false) & e.payrollLineId.isNull() & e.workDate.isSmallerOrEqualValue(to));
    final unpaidRows = <_UnpaidRow>[
      for (final r in await unpaidQuery.get())
        (
          workerId: r.read(e.workerId)!,
          workDate: r.read(e.workDate)!,
          amountFils: r.read(e.workerAmountFils),
          state: r.read(e.state)!,
          revisesEntryId: r.read(e.revisesEntryId),
          status: r.read(e.attendanceStatus)!,
        ),
    ];
    final excusedOf = groupedBy(await (select(dayOffs)..where((d) => d.workDate.isBetweenValues(from, to))).get(), (d) => d.workerId);
    // A day counts as absent once it is over, so today's attendance can still come in (D-057).
    final yesterday = addDays(dubaiToday(DateTime.now()), -1);
    final through = to.compareTo(yesterday) < 0 ? to : yesterday;
    final openings = await select(openingBalances).get();
    final cash = await (select(cashEntries)..where((c) => c.workerId.isNotNull())).get();
    final reversed = {for (final c in cash) ?c.reversesEntryId};
    // With nothing posted, a salary counts on the account from its first activity, as the statement reads it (D-042 (5)), so a
    // later month cannot be posted past an earlier one the account already counts (D-033).
    final accountCash = {for (final c in _accountCash(cash)) c.id};

    final firstItem = payrollItems.periodFrom.min();
    final firstItemOf = {
      for (final r in await (selectOnly(payrollItems)
            ..addColumns([payrollItems.workerId, firstItem])
            ..where(payrollItems.kind.equals(PayItemKind.advanceRecovery.name).not())
            ..groupBy([payrollItems.workerId]))
          .get())
        r.read(payrollItems.workerId)!: r.read(firstItem)!,
    };
    // An item no line has taken in an earlier month holds this one, or posting it would leave the item behind for ever.
    final itemMonthsOf = <String, Set<String>>{};
    for (final r in await (selectOnly(payrollItems, distinct: true)
          ..addColumns([payrollItems.workerId, payrollItems.periodFrom])
          ..where(payrollItems.lineId.isNull() & payrollItems.periodFrom.isSmallerThanValue(from)))
        .get()) {
      final String id = r.read(payrollItems.workerId)!;
      (itemMonthsOf[id] ??= <String>{}).add(r.read(payrollItems.periodFrom)!.substring(0, 7));
    }
    // A recovery waiting on another unposted month has taken its share of the advance already.
    final waiting = groupedBy(
      await (select(payrollItems)..where((i) => i.kind.equals(PayItemKind.advanceRecovery.name) & i.lineId.isNull() & i.periodFrom.equals(from).not())).get(),
      (i) => i.workerId,
    );

    final paidBack = await _cutDaysPaidBack();

    final contractsOf = groupedBy(contracts, (c) => c.workerId);
    final itemsOf = groupedBy(items, (i) => i.workerId);
    final linesOf = groupedBy(lines, (l) => l.workerId);
    final rowsOf = groupedBy(unpaidRows, (r) => r.workerId);
    final openingsOf = groupedBy(openings, (b) => b.workerId);
    final cashOf = groupedBy(cash, (c) => c.workerId);

    final result = <WorkerPayroll>[];
    for (final worker in allWorkers) {
      int openingOf(String kind) => (openingsOf[worker.id] ?? const <OpeningBalance>[]).where((b) => b.kind == kind).fold(0, (total, b) => total + b.amountFils);
      final workerLines = linesOf[worker.id] ?? const <PayrollLine>[];
      final cashLines = (cashOf[worker.id] ?? const <CashEntry>[]).map(cashLine).toList();
      final workerItems = itemsOf[worker.id] ?? const <PayrollItem>[];
      final paidTotal = salaryPaidTotal(cashLines);
      final recovered = workerLines.fold(0, (total, l) => total + l.recoveryFils);
      final advanceLeft = advanceOutstanding(openingOf('worker_advance'), cashLines, recoveredFils: recovered);
      final visaLeft = visaOutstanding(cashLines, recoveredFils: workerLines.fold(0, (total, l) => total + l.visaRecoveryFils));

      final index = workerLines.indexWhere((l) => l.periodFrom == from);
      if (index >= 0) {
        final line = workerLines[index];
        final paidUntil = index + 1 < workerLines.length ? workerLines[index + 1].paidBeforeFils : paidTotal;
        result.add(
          WorkerPayroll(
            worker: worker,
            figures: _postedFigures(line),
            items: workerItems,
            openingFils: line.openingFils,
            paidTotalFils: paidTotal,
            advanceLeftFils: advanceLeft,
            visaLeftFils: visaLeft,
            line: line,
            paidFils: paidUntil - line.paidBeforeFils,
          ),
        );
        continue;
      }

      final rows = rowsOf[worker.id] ?? const <_UnpaidRow>[];
      final priced = rows.where((r) => r.state != 'draft').toList();
      // A day a posted salary cut, worked after all, gives its cut back as earlier work, carried by the day's first row (D-080 (5)).
      final worked = {for (final r in priced) if (r.status != AttendanceStatus.absent.name) r.workDate};
      final terms = (contractsOf[worker.id] ?? const <PayContract>[]).map(payTerms).toList();
      final back = <String, int>{
        for (final l in workerLines)
          if (l.absentDays != null)
            ...cutGivenBack(terms, l.periodFrom.substring(0, 7), cutFils: l.absenceFils, cutDays: l.absentDays!.split(','), back: paidBack[worker.id] ?? const {}, worked: worked),
      };
      final work = <WorkLine>[
        for (final r in priced)
          WorkLine(r.workDate, (r.amountFils ?? 0) + (back.remove(r.workDate) ?? 0), alreadyPaidFils: r.revisesEntryId == null ? 0 : await _alreadyPaid(r.revisesEntryId)),
      ];
      final unpriced = rows.where((r) => r.state == 'draft').length;
      final activity = [
        if (workerLines.isEmpty) ...[
          for (final r in rows) r.workDate,
          ?firstItemOf[worker.id],
          // An old balance already holds everything up to its date, so the account starts the day after it.
          for (final b in openingsOf[worker.id] ?? const <OpeningBalance>[])
            if (b.kind == 'worker_salary_owed' || b.kind == 'worker_advance') addDays(b.asOfDate, 1),
          for (final c in cashOf[worker.id] ?? const <CashEntry>[])
            if (accountCash.contains(c.id)) c.entryDate,
        ],
      ]..sort();
      PayrollFigures figuresWith({int recovery = 0, bool ask = false}) => workerPayroll(
        month: month,
        currentMonth: dubaiToday(DateTime.now()).substring(0, 7),
        work: work,
        // ponytail: an archived worker stops earning a monthly salary, so post their last month before archiving. Add an end date check if owners forget.
        contracts: worker.active ? (contractsOf[worker.id] ?? const <PayContract>[]).map(payTerms) : const [],
        items: [
          for (final i in workerItems) PayItemLine(PayItemKind.values.byName(i.kind), i.amountFils),
          if (recovery > 0) PayItemLine(PayItemKind.advanceRecovery, recovery),
        ],
        advanceLeftFils: advanceLeft,
        visaLeftFils: visaLeft,
        unpricedRows: unpriced,
        lastPostedMonth: workerLines.lastOrNull?.periodFrom.substring(0, 7),
        firstMonth: activity.firstOrNull?.substring(0, 7),
        itemMonths: itemMonthsOf[worker.id] ?? const {},
        closedMonth: closedThrough?.substring(0, 7),
        limitBps: limitBps,
        present: {
          for (final r in rows)
            if (r.status != AttendanceStatus.absent.name && r.workDate.compareTo(from) >= 0) r.workDate,
        },
        excused: {for (final d in excusedOf[worker.id] ?? const <DayOff>[]) d.workDate},
        through: through,
        askRecovery: ask,
      );
      var figures = figuresWith();

      // Advance comes off by itself at each advance's instalment, oldest first, up to what the month can carry. With no
      // instalment the owner says how much, and a recovery the owner set, even at nothing, replaces all of it (D-057).
      var auto = 0;
      var ask = 0;
      if (advanceLeft > 0 && figures.netFils > 0 && !workerItems.any((i) => i.kind == PayItemKind.advanceRecovery.name)) {
        // Only advances given by the month's end come off it.
        final given = [
          for (final b in (openingsOf[worker.id] ?? const <OpeningBalance>[]).where((b) => b.kind == 'worker_advance' && b.asOfDate.compareTo(to) <= 0))
            (amountFils: b.amountFils, instalmentFils: null),
          for (final c in cashOf[worker.id] ?? const <CashEntry>[])
            if (c.kind == CashKind.advanceGiven.name && c.reversesEntryId == null && !reversed.contains(c.id) && c.entryDate.compareTo(to) <= 0)
              (amountFils: c.amountFils, instalmentFils: c.instalmentFils),
        ];
        final returned = cashLines.where((l) => l.kind == CashKind.advanceReturned).fold(0, (total, l) => total + l.signedFils);
        final taken = (waiting[worker.id] ?? const <PayrollItem>[]).fold(0, (total, i) => total + i.amountFils);
        final due = advanceInstalments(given, paidBackFils: returned + recovered + taken);
        auto = min(due.instalmentFils, figures.netFils);
        if (due.askFils > 0 && figures.netFils > auto) ask = due.askFils;
        if (auto > 0 || ask > 0) figures = figuresWith(recovery: auto, ask: ask > 0);
      }
      // Before the account's first activity a salary counts for nothing (D-042 (5)), so a month cut whole for absence there
      // is no month to post. From the first activity on, a whole month's cut still shows (BUG-005).
      final beforeAccount = workerLines.isEmpty && (activity.isEmpty || activity.first.substring(0, 7).compareTo(month) > 0);
      // Weekly days off are never cut, so such a month can keep their pay and still hold nothing of its own (D-080 (4)).
      final onlyCut = figures.absenceFils > 0 &&
          figures.earnedFils == 0 &&
          figures.adjustmentFils == 0 &&
          figures.allowancesFils == 0 &&
          figures.deductionsFils == 0 &&
          figures.recoveryFils == 0 &&
          figures.visaFils == 0;
      if ((figures.isEmpty || beforeAccount && onlyCut) && unpriced == 0) continue;
      final posted = workerLines.fold(0, (total, l) => total + l.netFils + l.adjustmentFils);
      result.add(
        WorkerPayroll(
          worker: worker,
          figures: figures,
          items: workerItems,
          openingFils: salaryOwed(openingOf('worker_salary_owed'), posted, cashLines),
          paidTotalFils: paidTotal,
          advanceLeftFils: advanceLeft,
          visaLeftFils: visaLeft,
          unpricedRows: unpriced,
          autoRecoveryFils: auto,
          askRecoveryFils: ask,
        ),
      );
    }
    return result;
  }

  /// Sends a fresh copy of the month whenever anything behind it changes.
  Stream<List<WorkerPayroll>> watchPayroll(String month) async* {
    yield await payrollFor(month);
    final changes = tableUpdates(
      TableUpdateQuery.onAllTables([attendanceEntries, payContracts, payrollItems, payrollLines, cashEntries, openingBalances, workers, tenantProfiles, dayOffs]),
    );
    await for (final _ in changes) {
      yield await payrollFor(month);
    }
  }

  /// Rows up to the month's end that are not frozen yet.
  Future<List<AttendanceEntry>> unapprovedUpTo(String month) {
    return (select(attendanceEntries)
          ..where((e) => e.superseded.equals(false) & e.state.isIn(const ['draft', 'submitted']) & e.workDate.isSmallerOrEqualValue(monthLastDay(month))))
        .get();
  }

  /// Posts everyone who is ready, and returns how many. Figures are worked out again here, so a stale screen cannot
  /// post old numbers. Posting is the owner's approval: a posted worker's rows freeze here (D-041).
  /// The run, its lines and the links to work and items commit together or not at all (MODEL-07).
  /// [instalmentReason] is the reason an advance instalment cut by itself is stored with (D-057).
  Future<int> postPayroll(String month, {required String operationId, String instalmentReason = 'Advance instalment'}) async {
    final runId = newUuid();
    final from = monthFirstDay(month);
    final to = monthLastDay(month);
    var posted = 0;
    await applyOperation(
      operationId: operationId,
      entity: 'payroll_runs',
      recordId: runId,
      version: 1,
      action: 'post',
      change: () async {
        final now = DateTime.now().toUtc();
        await repriceRows(operationId: newUuid(), upTo: to);
        final ready = (await payrollFor(month)).where((p) => p.canPost).toList();
        final readyIds = ready.map((p) => p.worker.id).toSet();
        final toFreeze = (await unapprovedUpTo(month)).where((e) => readyIds.contains(e.workerId)).toList();
        if (toFreeze.isNotEmpty) await approveEntries(toFreeze, operationId: newUuid());
        final run = await into(payrollRuns).insertReturning(
          PayrollRunsCompanion.insert(
            id: runId,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            periodFrom: from,
            periodTo: to,
            postingDate: dubaiToday(now),
          ),
        );
        final saved = <Map<String, dynamic>>[];
        for (final p in ready) {
          final lineId = newUuid();
          final f = p.figures;
          final line = await into(payrollLines).insertReturning(
            PayrollLinesCompanion.insert(
              id: lineId,
              tenantId: tenantId,
              createdAtUtc: now,
              updatedAtUtc: now,
              actorId: actorId,
              sourceOperationId: operationId,
              runId: runId,
              workerId: p.worker.id,
              periodFrom: from,
              openingFils: p.openingFils,
              earnedFils: f.earnedFils,
              salaryFils: f.salaryFils,
              adjustmentFils: f.adjustmentFils,
              allowancesFils: f.allowancesFils,
              deductionsFils: f.deductionsFils,
              recoveryFils: f.recoveryFils,
              visaRecoveryFils: Value(f.visaFils),
              absenceFils: Value(f.absenceFils),
              absentDays: Value(f.absentDays.isEmpty ? null : f.absentDays.join(',')),
              netFils: f.netFils,
              payableFils: p.payableFils,
              paidBeforeFils: p.paidTotalFils,
            ),
          );
          if (p.autoRecoveryFils > 0) {
            await into(payrollItems).insert(
              PayrollItemsCompanion.insert(
                id: newUuid(),
                tenantId: tenantId,
                createdAtUtc: now,
                updatedAtUtc: now,
                actorId: actorId,
                sourceOperationId: operationId,
                workerId: p.worker.id,
                periodFrom: from,
                kind: PayItemKind.advanceRecovery.name,
                amountFils: p.autoRecoveryFils,
                reason: instalmentReason,
              ),
            );
          }
          await (update(attendanceEntries)
                ..where(
                  (e) =>
                      e.workerId.equals(p.worker.id) &
                      e.superseded.equals(false) &
                      e.payrollLineId.isNull() &
                      e.state.isIn(const ['approved', 'linked']) &
                      e.workDate.isSmallerOrEqualValue(to),
                ))
              .write(AttendanceEntriesCompanion(payrollLineId: Value(lineId)));
          await (update(payrollItems)..where((i) => i.workerId.equals(p.worker.id) & i.periodFrom.equals(from)))
              .write(PayrollItemsCompanion(lineId: Value(lineId)));
          saved.add(line.toJson());
          posted++;
        }
        return {...run.toJson(), 'lines': saved};
      },
    );
    return posted;
  }

  /// Undoes one worker's posted month with a reason. The line stays on record, flagged, and its work and items
  /// are unpaid again, so the month can be fixed and posted again (REP-08).
  Future<void> reversePayrollLine(PayrollLine line, {required String reason, required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'payroll_lines',
      recordId: line.id,
      version: line.version + 1,
      action: 'reverse',
      reason: reason,
      change: () async {
        final later = await (select(payrollLines)
              ..where((l) => l.workerId.equals(line.workerId) & l.reversed.equals(false) & l.periodFrom.isBiggerThanValue(line.periodFrom)))
            .get();
        if (later.isNotEmpty) throw const LaterMonthPosted();
        await (update(payrollLines)..where((l) => l.id.equals(line.id))).write(
          PayrollLinesCompanion(
            reversed: const Value(true),
            version: Value(line.version + 1),
            updatedAtUtc: Value(DateTime.now().toUtc()),
            sourceOperationId: Value(operationId),
          ),
        );
        await (update(attendanceEntries)..where((e) => e.payrollLineId.equals(line.id))).write(const AttendanceEntriesCompanion(payrollLineId: Value(null)));
        await (update(payrollItems)..where((i) => i.lineId.equals(line.id))).write(const PayrollItemsCompanion(lineId: Value(null)));
        return (await (select(payrollLines)..where((l) => l.id.equals(line.id))).getSingle()).toJson();
      },
    );
  }

  /// Workers among [workerIds] with a month after [month] posted, so an item added to [month] could never post (PAY-02).
  Future<Set<String>> _postedAfter(Iterable<String> workerIds, String month) async => {
    for (final l in await (select(payrollLines)
          ..where((l) => l.workerId.isIn(workerIds) & l.reversed.equals(false) & l.periodFrom.isBiggerThanValue(monthFirstDay(month))))
        .get())
      l.workerId,
  };

  /// Adds or changes an allowance or deduction. Refused for a month behind a later posted one, where it could never
  /// post (LaterMonthPosted). A recovery above what the worker still owes is refused here,
  /// and checked again at posting (PAY-05).
  Future<void> savePayItem({
    required String? id,
    required String workerId,
    required String month,
    required PayItemKind kind,
    required int amountFils,
    required String reason,
    required String? authorizedBy,
    required String? note,
    required String? roomId,
    required String operationId,
    String? changeNote,
  }) async {
    if ((await _postedAfter([workerId], month)).isNotEmpty) throw const LaterMonthPosted();
    if (kind == PayItemKind.advanceRecovery) {
      final others = await (select(payrollItems)
            ..where((i) => i.workerId.equals(workerId) & i.kind.equals(kind.name) & i.lineId.isNull()))
          .get();
      final taken = others.where((i) => i.id != id).fold(0, (total, i) => total + i.amountFils);
      if (amountFils + taken > await advanceLeft(workerId)) throw const AdvanceTooHigh();
    }
    if (kind == PayItemKind.visaRecovery) {
      final others = await (select(payrollItems)
            ..where((i) => i.workerId.equals(workerId) & i.kind.equals(kind.name) & i.lineId.isNull()))
          .get();
      final taken = others.where((i) => i.id != id).fold(0, (total, i) => total + i.amountFils);
      if (amountFils + taken > await visaLeft(workerId)) throw const VisaTooHigh();
    }
    await saveRow(
      payrollItems,
      id: id,
      operationId: operationId,
      reason: changeNote,
      fields: PayrollItemsCompanion(
        workerId: Value(workerId),
        periodFrom: Value(monthFirstDay(month)),
        kind: Value(kind.name),
        amountFils: Value(amountFils),
        reason: Value(reason),
        authorizedBy: Value(authorizedBy),
        note: Value(note),
        roomId: Value(roomId),
      ),
    );
  }

  /// Adds each worker's visa instalment for this month, capped at what is left (D-039). Returns how many were added.
  Future<int> applyVisaInstalments(String month, {required String reason, required String operationId}) async {
    var added = 0;
    await applyOperation(
      operationId: operationId,
      entity: 'payroll_items',
      recordId: operationId,
      version: 1,
      action: 'create',
      change: () async {
        final now = DateTime.now().toUtc();
        final saved = <Map<String, dynamic>>[];
        for (final p in await payrollFor(month)) {
          if (!p.needsVisaInstalment) continue;
          final row = await into(payrollItems).insertReturning(
            PayrollItemsCompanion.insert(
              id: newUuid(),
              tenantId: tenantId,
              createdAtUtc: now,
              updatedAtUtc: now,
              actorId: actorId,
              sourceOperationId: operationId,
              workerId: p.worker.id,
              periodFrom: monthFirstDay(month),
              kind: PayItemKind.visaRecovery.name,
              amountFils: min(p.worker.visaInstalmentFils!, p.visaLeftFils),
              reason: reason,
            ),
          );
          saved.add(row.toJson());
          added++;
        }
        return {'items': saved};
      },
    );
    return added;
  }

  /// Adds a room charge for the workers the owner ticked, at the amounts given. Ticking them is the owner's authorization,
  /// unless the worker has an agreement note of their own (PAY-07, D-041). Someone already charged or posted is left out.
  /// Returns how many were added.
  Future<int> applyRoomCharges(String month, {required Map<String, int> charges, required String reason, required String ownerApproved, required String operationId}) async {
    var added = 0;
    await applyOperation(
      operationId: operationId,
      entity: 'payroll_items',
      recordId: operationId,
      version: 1,
      action: 'create',
      change: () async {
        final now = DateTime.now().toUtc();
        final saved = <Map<String, dynamic>>[];
        final current = await payrollFor(month);
        // A worker with nothing in this month is not on its list, so a later posted month is asked for itself.
        final later = await _postedAfter(charges.keys, month);
        final ticked = await (select(workers)..where((w) => w.id.isIn(charges.keys))).get();
        for (final worker in ticked) {
          if (later.contains(worker.id) || current.where((p) => p.worker.id == worker.id && !p.canAddRoomCharge).isNotEmpty) continue;
          final row = await into(payrollItems).insertReturning(
            PayrollItemsCompanion.insert(
              id: newUuid(),
              tenantId: tenantId,
              createdAtUtc: now,
              updatedAtUtc: now,
              actorId: actorId,
              sourceOperationId: operationId,
              workerId: worker.id,
              periodFrom: monthFirstDay(month),
              kind: PayItemKind.roomCharge.name,
              amountFils: charges[worker.id]!,
              reason: reason,
              authorizedBy: Value(worker.roomChargeNote ?? ownerApproved),
              roomId: Value(worker.roomId),
            ),
          );
          saved.add(row.toJson());
          added++;
        }
        return {'items': saved};
      },
    );
    return added;
  }
}
