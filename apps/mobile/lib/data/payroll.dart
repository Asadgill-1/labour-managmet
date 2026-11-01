import 'dart:math';

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
typedef _UnpaidRow = ({String workerId, String workDate, int? amountFils, String state, String? revisesEntryId});

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

  bool get posted => line != null;
  bool get canPost => !posted && figures.issues.isEmpty && !figures.isEmpty;
  bool get canAddRoomCharge => !posted && !items.any((i) => i.kind == PayItemKind.roomCharge.name);
  bool get needsVisaInstalment => !posted && (worker.visaInstalmentFils ?? 0) > 0 && visaLeftFils > 0 && !items.any((i) => i.kind == PayItemKind.visaRecovery.name);
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
);

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

  /// Everyone with something to pay or review this month, worked out fresh from the stored rows (REP-08).
  Future<List<WorkerPayroll>> payrollFor(String month) async {
    final from = monthFirstDay(month);
    final to = monthLastDay(month);
    final limitBps = (await select(tenantProfiles).getSingleOrNull())?.deductionLimitBps;
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
      ..addColumns([e.workerId, e.workDate, e.workerAmountFils, e.state, e.revisesEntryId])
      ..where(e.superseded.equals(false) & e.payrollLineId.isNull() & e.workDate.isSmallerOrEqualValue(to));
    final unpaidRows = <_UnpaidRow>[
      for (final r in await unpaidQuery.get())
        (workerId: r.read(e.workerId)!, workDate: r.read(e.workDate)!, amountFils: r.read(e.workerAmountFils), state: r.read(e.state)!, revisesEntryId: r.read(e.revisesEntryId)),
    ];
    final openings = await select(openingBalances).get();
    final cash = await (select(cashEntries)..where((c) => c.workerId.isNotNull())).get();

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
      final work = <WorkLine>[
        for (final r in rows.where((r) => r.state != 'draft'))
          WorkLine(r.workDate, r.amountFils ?? 0, alreadyPaidFils: r.revisesEntryId == null ? 0 : await _alreadyPaid(r.revisesEntryId)),
      ];
      final unpriced = rows.where((r) => r.state == 'draft').length;
      final figures = workerPayroll(
        month: month,
        currentMonth: dubaiToday(DateTime.now()).substring(0, 7),
        work: work,
        // ponytail: an archived worker stops earning a monthly salary, so post their last month before archiving. Add an end date check if owners forget.
        contracts: worker.active ? (contractsOf[worker.id] ?? const <PayContract>[]).map(payTerms) : const [],
        items: [for (final i in workerItems) PayItemLine(PayItemKind.values.byName(i.kind), i.amountFils)],
        advanceLeftFils: advanceLeft,
        visaLeftFils: visaLeft,
        unpricedRows: unpriced,
        lastPostedMonth: workerLines.lastOrNull?.periodFrom.substring(0, 7),
        limitBps: limitBps,
      );
      if (figures.isEmpty && unpriced == 0) continue;
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
        ),
      );
    }
    return result;
  }

  /// Sends a fresh copy of the month whenever anything behind it changes.
  Stream<List<WorkerPayroll>> watchPayroll(String month) async* {
    yield await payrollFor(month);
    final changes = tableUpdates(
      TableUpdateQuery.onAllTables([attendanceEntries, payContracts, payrollItems, payrollLines, cashEntries, openingBalances, workers, tenantProfiles]),
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
  Future<int> postPayroll(String month, {required String operationId}) async {
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
              netFils: f.netFils,
              payableFils: p.payableFils,
              paidBeforeFils: p.paidTotalFils,
            ),
          );
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

  /// Adds or changes an allowance or deduction. A recovery above what the worker still owes is refused here,
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
  }) async {
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

  Future<void> deletePayItem(PayrollItem item, {required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'payroll_items',
      recordId: item.id,
      version: item.version + 1,
      action: 'delete',
      change: () async {
        await (delete(payrollItems)..where((i) => i.id.equals(item.id))).go();
        return {'id': item.id, 'deleted': true};
      },
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
        final ticked = await (select(workers)..where((w) => w.id.isIn(charges.keys))).get();
        for (final worker in ticked) {
          if (current.where((p) => p.worker.id == worker.id && !p.canAddRoomCharge).isNotEmpty) continue;
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
