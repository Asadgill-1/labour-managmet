import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart';

import 'masters.dart';
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
    // A row with no rate yet has taken no break rule from a contract, so the contract it gets later decides.
    breakPaidClient: e.clientRateFils == null ? null : e.breakPaidClient,
    breakPaidWorker: e.workerRateFils == null ? null : e.breakPaidWorker,
    overtimeApproved: e.overtimeApproved,
    clientOverrideFils: e.clientRateOverrideFils,
    workerOverrideFils: e.workerRateOverrideFils,
  ),
);

/// Every rate a row could need, read once, so pricing a thousand rows does not ask the database thousands of times.
class _Rates {
  _Rates(Iterable<BillingContract> billing, Iterable<PayContract> pay, Iterable<WorkerGroup> groups, Iterable<WorkerGroupMember> members)
    : _billing = groupedBy(billing, (c) => c.clientId).map((client, rows) => MapEntry(client, rows.map(_billingTerms).toList())),
      _pay = groupedBy(pay, (c) => c.workerId).map((worker, rows) => MapEntry(worker, rows.map(payTerms).toList())),
      _groups = {for (final g in groups) g.id: g},
      _members = {for (final m in members) (m.groupId, m.workerId): m};

  final Map<String, List<RateTerms>> _billing;
  final Map<String, List<RateTerms>> _pay;
  final Map<String, WorkerGroup> _groups;
  final Map<(String, String), WorkerGroupMember> _members;

  PricedShift price({required String workDate, required String clientId, required String siteId, required EntryInput input}) {
    final contract = pickRate(_pay[input.workerId] ?? const [], date: workDate, siteId: siteId, workerId: input.workerId);
    final group = _groups[input.groupId];
    final member = _members[(input.groupId, input.workerId)];
    return priceShift(
      workDate,
      input.shift,
      client: pickRate(_billing[clientId] ?? const [], date: workDate, siteId: siteId, workerId: input.workerId),
      worker: group == null
          ? contract
          : groupPayTerms(
              contract,
              date: workDate,
              groupRateFils: group.dailyRateFils,
              memberRateFils: member?.rateFils,
              memberBasis: RateBasis.values.byName(member?.rateBasis ?? RateBasis.day.name),
              typedFils: input.shift.workerOverrideFils,
              halfDayIsHalf: group.halfDayIsHalf,
            ),
    );
  }
}

extension AttendanceOps on TenantDatabase {
  Future<_Rates> _rates() async => _Rates(await select(billingContracts).get(), await select(payContracts).get(), await select(workerGroups).get(), await select(workerGroupMembers).get());

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
    final priced = (await _rates()).price(workDate: workDate, clientId: clientId, siteId: siteId, input: input);
    return RowPreview(input: input, priced: priced, overlaps: await _overlaps(input.workerId, priced, exceptId: exceptId));
  }

  /// A whole batch in one go. A shift starts on its work date and runs under a day, so only the days around it can overlap.
  Future<List<RowPreview>> previewRows({
    required String workDate,
    required String clientId,
    required String siteId,
    required List<EntryInput> inputs,
  }) async {
    final rates = await _rates();
    final nearby = await (select(attendanceEntries)
          ..where((e) => e.superseded.equals(false) & e.startUtc.isNotNull() & e.workDate.isBetweenValues(addDays(workDate, -1), addDays(workDate, 1))))
        .get();
    final byWorker = groupedBy(nearby, (e) => e.workerId);
    return [
      for (final input in inputs)
        () {
          final priced = rates.price(workDate: workDate, clientId: clientId, siteId: siteId, input: input);
          final overlaps = priced.startUtc != null && (byWorker[input.workerId] ?? const <AttendanceEntry>[]).any((e) => e.startUtc!.isBefore(priced.endUtc!) && e.endUtc!.isAfter(priced.startUtc!));
          return RowPreview(input: input, priced: priced, overlaps: overlaps);
        }(),
    ];
  }

  /// The columns one row writes. A row with no worker pay stays a draft. A row with only the company rate missing
  /// goes on, because the wage must not wait for the bill (CALC-06, ATT-07, D-041).
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
    state: Value(priced.payHeld ? 'draft' : 'submitted'),
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
        for (final preview in await previewRows(workDate: workDate, clientId: clientId, siteId: siteId, inputs: inputs)) {
          final input = preview.input;
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

  /// Approves rows and freezes their rate snapshot (ATT-07, CALC-06). Posting payroll does this for the workers it
  /// posts (D-041). Rows with no worker pay stay behind as drafts, and the count of approved rows is returned.
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
        final rates = await _rates();
        final now = DateTime.now().toUtc();
        await batch((b) {
          for (final old in rows.where((e) => e.state == 'draft' || e.state == 'submitted')) {
            final input = entryToInput(old);
            final priced = rates.price(workDate: old.workDate, clientId: old.clientId, siteId: old.siteId, input: input);
            b.update(
              attendanceEntries,
              _entryColumns(input, priced).copyWith(
                state: Value(priced.payHeld ? 'draft' : 'approved'),
                version: Value(old.version + 1),
                updatedAtUtc: Value(now),
                sourceOperationId: Value(operationId),
              ),
              where: (e) => e.id.equals(old.id),
            );
            if (!priced.payHeld) {
              approved++;
              ids.add(old.id);
            }
          }
        });
        return {'approved': ids};
      },
    );
    return approved;
  }

  /// What a rate added or changed later does to stored rows. A row not yet frozen takes it in full. A frozen row only
  /// fills a company rate it never had, so its bill appears and its pay stays put (CALC-06, D-041). A closed month takes
  /// nothing, so its reports stay as they were (REP-05).
  /// The limits keep a thousand workers' rows out of it when one worker's rate changes.
  Future<List<(AttendanceEntry, AttendanceEntriesCompanion)>> _repriced({String? workerId, String? clientId, String? groupId, String? upTo}) async {
    final closedThrough = await lockedThrough();
    final rows = await (select(attendanceEntries)
          ..where(
            (e) =>
                e.superseded.equals(false) &
                (closedThrough == null ? const Constant(true) : e.workDate.isBiggerThanValue(closedThrough)) &
                (e.state.isIn(const ['draft', 'submitted']) | e.clientRateFils.isNull()) &
                (workerId == null ? const Constant(true) : e.workerId.equals(workerId)) &
                (clientId == null ? const Constant(true) : e.clientId.equals(clientId)) &
                (groupId == null ? const Constant(true) : e.groupId.equals(groupId)) &
                (upTo == null ? const Constant(true) : e.workDate.isSmallerOrEqualValue(upTo)),
          ))
        .get();
    final rates = await _rates();
    final changes = <(AttendanceEntry, AttendanceEntriesCompanion)>[];
    for (final old in rows) {
      final input = entryToInput(old);
      final priced = rates.price(workDate: old.workDate, clientId: old.clientId, siteId: old.siteId, input: input);
      if (old.state == 'draft' || old.state == 'submitted') {
        final same =
            old.state == (priced.payHeld ? 'draft' : 'submitted') &&
            old.clientRateFils == priced.clientRateFils &&
            old.clientAmountFils == priced.client.amountFils &&
            old.clientBillableMinutes == priced.clientMinutes &&
            old.workerRateFils == priced.workerRateFils &&
            old.workerAmountFils == priced.worker.amountFils &&
            old.workerPayableMinutes == priced.workerMinutes;
        if (!same) changes.add((old, _entryColumns(input, priced)));
      } else if (priced.clientRateFils != null) {
        changes.add((
          old,
          AttendanceEntriesCompanion(
            breakPaidClient: Value(priced.breakPaidClient),
            clientBillableMinutes: Value(priced.clientMinutes),
            clientBasis: Value(priced.clientBasis?.name),
            clientRateFils: Value(priced.clientRateFils),
            clientAmountFils: Value(priced.client.amountFils),
          ),
        ));
      }
    }
    return changes;
  }

  /// Lets rates reach the rows they change, and returns how many changed. Nothing changed means nothing is recorded.
  Future<int> repriceRows({required String operationId, String? workerId, String? clientId, String? groupId, String? upTo}) async {
    final changes = await _repriced(workerId: workerId, clientId: clientId, groupId: groupId, upTo: upTo);
    if (changes.isEmpty) return 0;
    await applyOperation(
      operationId: operationId,
      entity: 'attendance_entries',
      recordId: operationId,
      version: 1,
      action: 'reprice',
      change: () async {
        final now = DateTime.now().toUtc();
        await batch((b) {
          for (final (old, columns) in changes) {
            b.update(
              attendanceEntries,
              columns.copyWith(version: Value(old.version + 1), updatedAtUtc: Value(now), actorId: Value(actorId), sourceOperationId: Value(operationId)),
              where: (e) => e.id.equals(old.id),
            );
          }
        });
        return {'repriced': [for (final (old, _) in changes) old.id]};
      },
    );
    return changes.length;
  }

  /// Saves a rate and lets it reach its rows together, so a crash can't leave them apart. Name the worker, company or
  /// group it belongs to when there is one, so only their rows are looked at.
  Future<void> savingRate(Future<void> Function() save, {String? workerId, String? clientId, String? groupId}) => transaction(() async {
    await save();
    await repriceRows(operationId: newUuid(), workerId: workerId, clientId: clientId, groupId: groupId);
  });

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
