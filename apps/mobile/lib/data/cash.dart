import 'package:domain/cash.dart';
import 'package:drift/drift.dart';

import 'tenant_database.dart';

/// More than the worker still owes back, so it would turn an advance negative (PAY-05).
class AdvanceTooHigh implements Exception {
  const AdvanceTooHigh();
}

CashLine cashLine(CashEntry e) => CashLine(CashKind.values.byName(e.kind), e.amountFils, reversal: e.reversesEntryId != null);

extension CashOps on TenantDatabase {
  /// What this worker still owes back, including any advance carried over from before this app.
  Future<int> advanceLeft(String workerId) async {
    final opening = await (select(openingBalances)..where((b) => b.kind.equals('worker_advance') & b.workerId.equals(workerId))).getSingleOrNull();
    final rows = await (select(cashEntries)..where((c) => c.workerId.equals(workerId))).get();
    final lines = await (select(payrollLines)..where((l) => l.workerId.equals(workerId) & l.reversed.equals(false))).get();
    final recovered = lines.fold(0, (total, l) => total + l.recoveryFils);
    return advanceOutstanding(opening?.amountFils ?? 0, rows.map(cashLine), recoveredFils: recovered);
  }

  /// Writes one line. A retry with the same operation ID changes nothing (TEAM-04).
  Future<void> addCashEntry({
    required String operationId,
    required String date,
    required CashKind kind,
    required int amountFils,
    String? workerId,
    String? roomId,
    String? clientId,
    String? siteId,
    String? category,
    String method = 'cash',
    String? note,
  }) {
    final id = newUuid();
    return applyOperation(
      operationId: operationId,
      entity: 'cash_entries',
      recordId: id,
      version: 1,
      action: 'create',
      change: () async {
        if (kind == CashKind.advanceReturned && amountFils > await advanceLeft(workerId!)) throw const AdvanceTooHigh();
        final now = DateTime.now().toUtc();
        final row = await into(cashEntries).insertReturning(
          CashEntriesCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            entryDate: date,
            kind: kind.name,
            amountFils: amountFils,
            workerId: Value(workerId),
            roomId: Value(roomId),
            clientId: Value(clientId),
            siteId: Value(siteId),
            category: Value(category),
            method: Value(method),
            note: Value(note),
          ),
        );
        return row.toJson();
      },
    );
  }

  /// Undoes a line with a matching reversal on the same date. The original stays on record (REP-08).
  /// ponytail: uses the original's date, so a closed period would change. T13 needs a dated adjustment here once locks exist (REP-04).
  Future<void> reverseCashEntry(CashEntry entry, {required String reason, required String operationId}) {
    final id = newUuid();
    return applyOperation(
      operationId: operationId,
      entity: 'cash_entries',
      recordId: id,
      version: 1,
      action: 'reverse',
      reason: reason,
      change: () async {
        if (entry.reversesEntryId != null) throw StateError('a reversal cannot be reversed');
        if (entry.kind == CashKind.advanceGiven.name && entry.amountFils > await advanceLeft(entry.workerId!)) throw const AdvanceTooHigh();
        final now = DateTime.now().toUtc();
        final row = await into(cashEntries).insertReturning(
          CashEntriesCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            entryDate: entry.entryDate,
            kind: entry.kind,
            amountFils: entry.amountFils,
            workerId: Value(entry.workerId),
            roomId: Value(entry.roomId),
            clientId: Value(entry.clientId),
            siteId: Value(entry.siteId),
            category: Value(entry.category),
            method: Value(entry.method),
            note: Value(reason),
            reversesEntryId: Value(entry.id),
          ),
        );
        return row.toJson();
      },
    );
  }
}
