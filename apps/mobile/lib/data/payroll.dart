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
    this.unapprovedRows = 0,
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
  final int unapprovedRows;

  bool get posted => line != null;
  bool get canPost => !posted && figures.issues.isEmpty && !figures.isEmpty;
  bool get needsRoomCharge => !posted && (worker.roomChargeFils ?? 0) > 0 && !items.any((i) => i.kind == PayItemKind.roomCharge.name);
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
  Future<int> _alreadyPaid(AttendanceEntry row) async {
    var id = row.revisesEntryId;
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
    final unpaidRows = await (select(attendanceEntries)
          ..where((e) => e.superseded.equals(false) & e.payrollLineId.isNull() & e.workDate.isSmallerOrEqualValue(to)))
        .get();
    final openings = await select(openingBalances).get();
    final cash = await (select(cashEntries)..where((c) => c.workerId.isNotNull())).get();

    final result = <WorkerPayroll>[];
    for (final worker in allWorkers) {
      int openingOf(String kind) => openings.where((b) => b.kind == kind && b.workerId == worker.id).fold(0, (total, b) => total + b.amountFils);
      final workerLines = lines.where((l) => l.workerId == worker.id).toList();
      final cashLines = cash.where((c) => c.workerId == worker.id).map(cashLine).toList();
      final workerItems = items.where((i) => i.workerId == worker.id).toList();
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

      final rows = unpaidRows.where((e) => e.workerId == worker.id);
      final work = <WorkLine>[
        for (final r in rows.where((e) => e.state == 'approved' || e.state == 'linked'))
          WorkLine(r.workDate, r.workerAmountFils ?? 0, alreadyPaidFils: await _alreadyPaid(r)),
      ];
      final unapproved = rows.where((e) => e.state == 'draft' || e.state == 'submitted').length;
      final figures = workerPayroll(
        month: month,
        currentMonth: dubaiToday(DateTime.now()).substring(0, 7),
        work: work,
        // ponytail: an archived worker stops earning a monthly salary, so post their last month before archiving. Add an end date check if owners forget.
        contracts: worker.active ? contracts.where((c) => c.workerId == worker.id).map(payTerms) : const [],
        items: [for (final i in workerItems) PayItemLine(PayItemKind.values.byName(i.kind), i.amountFils)],
        advanceLeftFils: advanceLeft,
        visaLeftFils: visaLeft,
        unapprovedRows: unapproved,
        lastPostedMonth: workerLines.lastOrNull?.periodFrom.substring(0, 7),
        limitBps: limitBps,
      );
      if (figures.isEmpty && unapproved == 0) continue;
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
          unapprovedRows: unapproved,
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

  /// Rows up to the month's end that still need the owner's approval.
  Future<List<AttendanceEntry>> unapprovedUpTo(String month) {
    return (select(attendanceEntries)
          ..where((e) => e.superseded.equals(false) & e.state.isIn(const ['draft', 'submitted']) & e.workDate.isSmallerOrEqualValue(monthLastDay(month))))
        .get();
  }

  /// Posts everyone who is ready, and returns how many. Figures are worked out again here, so a stale screen cannot
  /// post old numbers. The run, its lines and the links to work and items commit together or not at all (MODEL-07).
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
        final ready = (await payrollFor(month)).where((p) => p.canPost).toList();
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

  /// Adds each worker's agreed room charge for this month. Someone with no agreement note on file is left out,
  /// because a deduction needs one (PAY-07). Returns how many were added and how many were left out.
  Future<({int added, int noNote})> applyRoomCharges(String month, {required String reason, required String operationId}) async {
    var added = 0;
    var noNote = 0;
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
          if (!p.needsRoomCharge) continue;
          final authorizedBy = p.worker.roomChargeNote;
          if (authorizedBy == null) {
            noNote++;
            continue;
          }
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
              kind: PayItemKind.roomCharge.name,
              amountFils: p.worker.roomChargeFils!,
              reason: reason,
              authorizedBy: Value(authorizedBy),
              roomId: Value(p.worker.roomId),
            ),
          );
          saved.add(row.toJson());
          added++;
        }
        return {'items': saved};
      },
    );
    return (added: added, noNote: noNote);
  }
}
