import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart';

import 'tenant_database.dart';

/// One row in a batch, as entered.
class EntryInput {
  const EntryInput({required this.workerId, required this.shift, this.groupId, this.overrideReason, this.overlapReason, this.notes});

  final String workerId;
  final ShiftInput shift;

  /// The group this row was marked through, if any. It decides the daily wage (D-029).
  final String? groupId;
  final String? overrideReason;
  final String? overlapReason;
  final String? notes;

  bool get hasOverride => shift.clientOverrideFils != null || shift.workerOverrideFils != null;
}

/// A row after pricing and checks, ready to show or save.
class RowPreview {
  const RowPreview({required this.input, required this.priced, required this.overlaps});

  final EntryInput input;
  final PricedShift priced;
  final bool overlaps;

  /// True when the row cannot be saved at all. A missing rate can be saved, as a draft.
  bool get blocksSave => !priced.breakValid || (overlaps && (input.overlapReason ?? '').isEmpty) || (input.hasOverride && (input.overrideReason ?? '').isEmpty);
}

class AttendanceInvalid implements Exception {
  const AttendanceInvalid(this.workerIds);

  final List<String> workerIds;

  @override
  String toString() => 'AttendanceInvalid($workerIds)';
}

RateTerms payTerms(PayContract c) => RateTerms(
  basis: RateBasis.values.byName(c.basis),
  rateFils: c.rateFils,
  effectiveFrom: c.effectiveFrom,
  effectiveTo: c.effectiveTo,
  breakPaid: c.breakPaid,
  halfAmountFils: c.halfAmountFils,
  includedMinutes: c.includedMinutes,
  overtimeRateFils: c.overtimeRateFils,
  siteId: c.siteId,
  partialMethod: c.partialMethod == null ? null : PartialMethod.values.byName(c.partialMethod!),
  partialDivisor: c.partialDivisor,
);

RateTerms _billingTerms(BillingContract c) => RateTerms(
  basis: RateBasis.values.byName(c.basis),
  rateFils: c.rateFils,
  effectiveFrom: c.effectiveFrom,
  effectiveTo: c.effectiveTo,
  breakPaid: c.breakPaid,
  halfAmountFils: c.halfAmountFils,
  includedMinutes: c.includedMinutes,
  overtimeRateFils: c.overtimeRateFils,
  siteId: c.siteId,
  workerId: c.workerId,
);

/// A stored row back as form input.
EntryInput entryToInput(AttendanceEntry e) => EntryInput(
  workerId: e.workerId,
  groupId: e.groupId,
  overrideReason: e.overrideReason,
  overlapReason: e.overlapReason,
  notes: e.notes,
  shift: ShiftInput(
    status: AttendanceStatus.values.byName(e.attendanceStatus),
    startMinute: e.startUtc == null ? null : dubaiMinuteOfDay(e.startUtc!),
    endMinute: e.endUtc == null ? null : dubaiMinuteOfDay(e.endUtc!),
    breakMinutes: e.breakMinutes,
    breakPaidClient: e.breakPaidClient,
    breakPaidWorker: e.breakPaidWorker,
    overtimeApproved: e.overtimeApproved,
    clientOverrideFils: e.clientRateOverrideFils,
    workerOverrideFils: e.workerRateOverrideFils,
  ),
);

extension AttendanceOps on TenantDatabase {
  Future<PricedShift> _price({
    required String workDate,
    required String clientId,
    required String siteId,
    required EntryInput input,
  }) async {
    final billing = await (select(billingContracts)..where((c) => c.clientId.equals(clientId))).get();
    final pay = await (select(payContracts)..where((c) => c.workerId.equals(input.workerId))).get();
    final contract = pickRate(pay.map(payTerms), date: workDate, siteId: siteId, workerId: input.workerId);
    return priceShift(
      workDate,
      input.shift,
      client: pickRate(billing.map(_billingTerms), date: workDate, siteId: siteId, workerId: input.workerId),
      worker: await _groupTerms(contract, input, workDate),
    );
  }

  Future<RateTerms?> _groupTerms(RateTerms? contract, EntryInput input, String date) async {
    final groupId = input.groupId;
    if (groupId == null) return contract;
    final group = await (select(workerGroups)..where((g) => g.id.equals(groupId))).getSingle();
    final member = await (select(workerGroupMembers)..where((m) => m.groupId.equals(groupId) & m.workerId.equals(input.workerId))).getSingleOrNull();
    return groupPayTerms(
      contract,
      date: date,
      groupRateFils: group.dailyRateFils,
      memberRateFils: member?.dailyRateFils,
      typedFils: input.shift.workerOverrideFils,
      halfDayIsHalf: group.halfDayIsHalf,
    );
  }

  /// True if this worker already has live time in this window. A second job at another hour is fine (ATT-05).
  Future<bool> _overlaps(String workerId, PricedShift priced, {String? exceptId}) async {
    if (priced.startUtc == null) return false;
    final query = select(attendanceEntries)
      ..where(
        (e) =>
            e.workerId.equals(workerId) &
            e.superseded.equals(false) &
            e.startUtc.isSmallerThanValue(priced.endUtc!) &
            e.endUtc.isBiggerThanValue(priced.startUtc!),
      );
    if (exceptId != null) query.where((e) => e.id.isNotValue(exceptId));
    return (await query.get()).isNotEmpty;
  }

  Future<RowPreview> previewRow({
    required String workDate,
    required String clientId,
    required String siteId,
    required EntryInput input,
    String? exceptId,
  }) async {
    final priced = await _price(workDate: workDate, clientId: clientId, siteId: siteId, input: input);
    return RowPreview(input: input, priced: priced, overlaps: await _overlaps(input.workerId, priced, exceptId: exceptId));
  }

  /// The columns one row writes. Unpriced rows stay drafts and cannot be approved (CALC-06).
  AttendanceEntriesCompanion _entryColumns(EntryInput input, PricedShift priced) => AttendanceEntriesCompanion(
    workerId: Value(input.workerId),
    groupId: Value(input.groupId),
    startUtc: Value(priced.startUtc),
    endUtc: Value(priced.endUtc),
    clockMinutes: Value(priced.clockMinutes),
    breakMinutes: Value(input.shift.status == AttendanceStatus.absent ? 0 : input.shift.breakMinutes),
    breakPaidClient: Value(priced.breakPaidClient),
    breakPaidWorker: Value(priced.breakPaidWorker),
    clientBillableMinutes: Value(priced.clientMinutes),
    workerPayableMinutes: Value(priced.workerMinutes),
    overtimeMinutes: Value(priced.worker.overtimeMinutes),
    overtimeApproved: Value(input.shift.overtimeApproved),
    attendanceStatus: Value(input.shift.status.name),
    clientBasis: Value(priced.clientBasis?.name),
    clientRateFils: Value(priced.clientRateFils),
    clientAmountFils: Value(priced.client.amountFils),
    workerBasis: Value(priced.workerBasis?.name),
    workerRateFils: Value(priced.workerRateFils),
    workerAmountFils: Value(priced.worker.amountFils),
    clientRateOverrideFils: Value(input.shift.clientOverrideFils),
    workerRateOverrideFils: Value(input.shift.workerOverrideFils),
    overrideReason: Value(input.overrideReason),
    overlapReason: Value(input.overlapReason),
    notes: Value(input.notes),
    state: Value(priced.hasPricingIssue ? 'draft' : 'submitted'),
  );

  AttendanceEntriesCompanion _stamp(AttendanceEntriesCompanion row, String id, String operationId, DateTime now) => row.copyWith(
    id: Value(id),
    tenantId: Value(tenantId),
    createdAtUtc: Value(now),
    updatedAtUtc: Value(now),
    actorId: Value(actorId),
    sourceOperationId: Value(operationId),
  );

  /// Saves the whole batch or nothing (ATT-04). Every row is priced and checked again here, so a stale
  /// screen cannot save a bad row. A retry with the same operation ID changes nothing.
  Future<String> saveAttendanceBatch({
    required String workDate,
    required String clientId,
    required String siteId,
    required List<EntryInput> inputs,
    required String operationId,
  }) async {
    final batchId = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'attendance_batches',
      recordId: batchId,
      version: 1,
      action: 'create',
      change: () async {
        final now = DateTime.now().toUtc();
        final bad = <String>[];
        final rows = <AttendanceEntriesCompanion>[];
        for (final input in inputs) {
          final preview = await previewRow(workDate: workDate, clientId: clientId, siteId: siteId, input: input);
          if (preview.blocksSave) bad.add(input.workerId);
          rows.add(
            _stamp(_entryColumns(input, preview.priced), newUuid(), operationId, now).copyWith(
              batchId: Value(batchId),
              clientId: Value(clientId),
              siteId: Value(siteId),
              workDate: Value(workDate),
            ),
          );
        }
        if (bad.isNotEmpty) throw AttendanceInvalid(bad);
        final saved = await into(attendanceBatches).insertReturning(
          AttendanceBatchesCompanion.insert(
            id: batchId,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            workDate: workDate,
            clientId: clientId,
            siteId: siteId,
            groupId: Value(inputs.firstOrNull?.groupId),
          ),
        );
        await batch((b) => b.insertAll(attendanceEntries, rows));
        final stored = await (select(attendanceEntries)..where((e) => e.batchId.equals(batchId))).get();
        return {...saved.toJson(), 'entries': stored.map((e) => e.toJson()).toList()};
      },
    );
    return batchId;
  }

  /// Edits a row that is not yet approved, and prices it again.
  Future<void> updateUnapprovedEntry(AttendanceEntry old, EntryInput input, {required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'attendance_entries',
      recordId: old.id,
      version: old.version + 1,
      action: 'update',
      change: () async {
        final preview = await previewRow(workDate: old.workDate, clientId: old.clientId, siteId: old.siteId, input: input, exceptId: old.id);
        if (preview.blocksSave) throw AttendanceInvalid([input.workerId]);
        await (update(attendanceEntries)..where((e) => e.id.equals(old.id))).write(
          _entryColumns(input, preview.priced).copyWith(
            updatedAtUtc: Value(DateTime.now().toUtc()),
            actorId: Value(actorId),
            version: Value(old.version + 1),
            sourceOperationId: Value(operationId),
          ),
        );
        return (await (select(attendanceEntries)..where((e) => e.id.equals(old.id))).getSingle()).toJson();
      },
    );
  }

  /// Corrects an approved or linked row: the old row stays as it was, flagged, and a new row revises it (ATT-08).
  Future<String> correctEntry(AttendanceEntry old, EntryInput input, {required String reason, required String operationId}) async {
    final newId = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'attendance_entries',
      recordId: newId,
      version: 1,
      action: 'correct',
      reason: reason,
      change: () async {
        final preview = await previewRow(workDate: old.workDate, clientId: old.clientId, siteId: old.siteId, input: input, exceptId: old.id);
        if (preview.blocksSave) throw AttendanceInvalid([input.workerId]);
        await (update(attendanceEntries)..where((e) => e.id.equals(old.id))).write(const AttendanceEntriesCompanion(superseded: Value(true)));
        final row = await into(attendanceEntries).insertReturning(
          _stamp(_entryColumns(input, preview.priced), newId, operationId, DateTime.now().toUtc()).copyWith(
            batchId: Value(old.batchId),
            clientId: Value(old.clientId),
            siteId: Value(old.siteId),
            workDate: Value(old.workDate),
            revisesEntryId: Value(old.id),
          ),
        );
        return row.toJson();
      },
    );
    return newId;
  }

  /// Approves rows and freezes their rate snapshot (ATT-07, CALC-06). Rows still missing a rate stay
  /// behind as drafts, and the count of approved rows is returned.
  Future<int> approveEntries(List<AttendanceEntry> rows, {required String operationId}) async {
    var approved = 0;
    await applyOperation(
      operationId: operationId,
      entity: 'attendance_entries',
      recordId: operationId,
      version: 1,
      action: 'approve',
      change: () async {
        final ids = <String>[];
        for (final old in rows.where((e) => e.state == 'draft' || e.state == 'submitted')) {
          final input = entryToInput(old);
          final priced = await _price(workDate: old.workDate, clientId: old.clientId, siteId: old.siteId, input: input);
          final columns = _entryColumns(input, priced);
          await (update(attendanceEntries)..where((e) => e.id.equals(old.id))).write(
            columns.copyWith(
              state: Value(priced.hasPricingIssue ? 'draft' : 'approved'),
              version: Value(old.version + 1),
              updatedAtUtc: Value(DateTime.now().toUtc()),
              sourceOperationId: Value(operationId),
            ),
          );
          if (!priced.hasPricingIssue) {
            approved++;
            ids.add(old.id);
          }
        }
        return {'approved': ids};
      },
    );
    return approved;
  }

  /// Removes a row that nobody has approved.
  Future<void> deleteUnapprovedEntry(AttendanceEntry old, {required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'attendance_entries',
      recordId: old.id,
      version: old.version + 1,
      action: 'delete',
      change: () async {
        await (delete(attendanceEntries)..where((e) => e.id.equals(old.id))).go();
        return {'id': old.id, 'deleted': true};
      },
    );
  }

  /// The most recent batch, to prefill today's client and site (UX-05).
  Future<AttendanceBatch?> lastBatch() {
    return (select(attendanceBatches)
          ..orderBy([(b) => OrderingTerm.desc(b.workDate), (b) => OrderingTerm.desc(b.createdAtUtc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Who worked this site on its latest day before [date] (UX-05).
  Future<List<String>> lastTeam(String siteId, String date) async {
    final latest = await (select(attendanceEntries)
          ..where((e) => e.siteId.equals(siteId) & e.workDate.isSmallerThanValue(date) & e.superseded.equals(false))
          ..orderBy([(e) => OrderingTerm.desc(e.workDate)])
          ..limit(1))
        .getSingleOrNull();
    if (latest == null) return const [];
    final rows = await (select(attendanceEntries)
          ..where((e) => e.siteId.equals(siteId) & e.workDate.equals(latest.workDate) & e.superseded.equals(false)))
        .get();
    return rows.where((e) => e.attendanceStatus != 'absent').map((e) => e.workerId).toSet().toList();
  }
}
