import 'dart:convert';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/timesheet.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'documents.dart';
import 'tenant_database.dart';

/// How far a revision has gone (TS-04). Accepted is locked.
enum TsStatus { draft, approved, shared, accepted, disputed }

/// Nothing in these dates can go on a timesheet.
class TimesheetEmpty implements Exception {
  const TimesheetEmpty();
}

/// This step doesn't fit where the revision stands, or a newer revision has replaced it.
class TimesheetWrongStep implements Exception {
  const TimesheetWrongStep();
}

/// Some of this work is already on a live invoice (TS-05). Nothing was written.
class AlreadyBilled implements Exception {
  const AlreadyBilled(this.workKeys);

  final List<String> workKeys;
}

/// What a company agreed for one row instead of what the attendance says. Attendance and pay stay as they are (TS-06).
class TsAdjustment {
  const TsAdjustment({required this.status, required this.minutes, required this.amountFils, required this.reason});

  factory TsAdjustment.fromJson(Map<String, Object?> j) => TsAdjustment(
    status: AttendanceStatus.values.byName(j['status'] as String),
    minutes: j['minutes'] as int,
    amountFils: j['amount'] as int?,
    reason: j['reason'] as String,
  );

  final AttendanceStatus status;
  final int minutes;
  final int? amountFils;
  final String reason;

  Map<String, Object?> toJson() => {'status': status.name, 'minutes': minutes, 'amount': amountFils, 'reason': reason};
}

/// Rows in the dates that can't go on this timesheet, and why.
class TsLeftOut {
  const TsLeftOut({this.noCompanyRate = 0, this.noWorkerRate = 0, this.onOtherTimesheet = 0});

  final int noCompanyRate;
  final int noWorkerRate;
  final int onOtherTimesheet;
}

/// One row of a timesheet: read from live attendance in a draft, from its stored line after that.
class TimesheetRow {
  const TimesheetRow({required this.entryId, required this.workKey, required this.line, required this.workerName, required this.workerCode, required this.siteName, this.adjustReason});

  final String entryId;
  final String workKey;
  final TsLine line;
  final String workerName;
  final String workerCode;
  final String siteName;
  final String? adjustReason;
}

/// A row an invoice charged at a different figure from the current revision. The invoice stays as it was until T16's
/// correction reaches it (TS-06).
class BillingChange {
  const BillingChange({required this.workKey, required this.workDate, required this.workerName, required this.billedFils, required this.nowFils});

  final String workKey;
  final String workDate;
  final String workerName;
  final int billedFils;
  final int nowFils;

  int get differenceFils => nowFils - billedFils;
}

/// One revision of a timesheet as the screen and the paper show it. Everything derives from stored rows (REP-08).
class TimesheetView {
  TimesheetView({required this.sheet, required this.clientName, required this.clientLine, required this.siteName, required this.revision, required this.revisions, required this.rows, required this.leftOut, required this.changedRows, required this.billingChanges});

  final Timesheet sheet;
  final String clientName;

  /// The company's address and TRN, for its paper.
  final String clientLine;

  /// Null means all sites.
  final String? siteName;
  final TimesheetRevision revision;

  /// Newest first.
  final List<TimesheetRevision> revisions;
  final List<TimesheetRow> rows;

  /// Only a draft has any, since a draft is still choosing its rows.
  final TsLeftOut? leftOut;

  /// Stored lines whose attendance was corrected after approval (ATT-08).
  final int changedRows;
  final List<BillingChange> billingChanges;

  TsStatus get status => TsStatus.values.byName(revision.status);
  bool get isLatest => revision.revision == revisions.first.revision;
  late final lines = [for (final r in rows) r.line];
  late final totals = timesheetTotals(lines);
  late final siteNames = {for (final r in rows) r.line.siteId: r.siteName};

  /// By date, then site and trade by name, the way the owner reads them.
  late final daily = dailySummary(lines)
    ..sort((a, b) {
      final date = a.workDate.compareTo(b.workDate);
      if (date != 0) return date;
      final site = (siteNames[a.siteId] ?? '').compareTo(siteNames[b.siteId] ?? '');
      return site != 0 ? site : (a.trade ?? '').compareTo(b.trade ?? '');
    });
  late final monthly = monthlyContracts(lines);
}

/// One line of the list of timesheets.
class TimesheetListRow {
  const TimesheetListRow({required this.id, required this.clientName, required this.siteName, required this.fromDate, required this.toDate, required this.number, required this.revision, required this.status, required this.amountFils});

  final String id;
  final String clientName;
  final String? siteName;
  final String fromDate;
  final String toDate;
  final String? number;
  final int revision;
  final TsStatus status;

  /// What the current lines come to. Null until first approved, or when all of it is a monthly fee.
  final int? amountFils;
}

typedef TimesheetPreview = ({List<TimesheetRow> rows, List<AttendanceEntry> entries, TsLeftOut leftOut});

extension TimesheetOps on TenantDatabase {
  /// What a timesheet over these dates would hold today. A row goes on when it was worked, has a company rate, is not held
  /// back by a missing wage, and is not already on another timesheet (TS-01, TS-05).
  Future<TimesheetPreview> timesheetPreview({required String clientId, String? siteId, required String from, required String to, String? ownTimesheetId, Map<String, TsAdjustment> adjustments = const {}}) async {
    final all = await (select(attendanceEntries)..where((e) => e.clientId.equals(clientId) & e.workDate.isBetweenValues(from, to) & (siteId == null ? const Constant(true) : e.siteId.equals(siteId)))).get();
    final byId = {for (final e in all) e.id: e};
    String keyOf(AttendanceEntry e) {
      var at = e;
      while (byId[at.revisesEntryId] != null) {
        at = byId[at.revisesEntryId]!;
      }
      return at.id;
    }

    final l = timesheetLines;
    final onLines = await (selectOnly(l)
          ..addColumns([l.workKey, l.timesheetId])
          ..where(l.live.equals(true) & l.workDate.isBetweenValues(from, to)))
        .get();
    final taken = {
      for (final r in onLines)
        if (r.read(l.timesheetId) != ownTimesheetId) r.read(l.workKey)!,
    };
    final people = {for (final w in await select(workers).get()) w.id: w};
    final places = {for (final s in await select(sites).get()) s.id: s.name};

    var noCompanyRate = 0;
    var noWorkerRate = 0;
    var onOther = 0;
    final rows = <TimesheetRow>[];
    final entries = <AttendanceEntry>[];
    for (final e in all.where((e) => !e.superseded && e.attendanceStatus != AttendanceStatus.absent.name)) {
      final key = keyOf(e);
      final basis = e.clientBasis == null ? null : RateBasis.values.byName(e.clientBasis!);
      if (taken.contains(key)) {
        onOther++;
      } else if (basis == null || e.clientRateFils == null || (e.clientAmountFils == null && !isPeriodBasis(basis))) {
        noCompanyRate++;
      } else if (e.state == 'draft') {
        noWorkerRate++;
      } else {
        final agreed = adjustments[e.id];
        final worker = people[e.workerId]!;
        entries.add(e);
        rows.add(
          TimesheetRow(
            entryId: e.id,
            workKey: key,
            workerName: worker.name,
            workerCode: worker.code,
            siteName: places[e.siteId] ?? '',
            adjustReason: agreed?.reason,
            line: TsLine(
              workDate: e.workDate,
              siteId: e.siteId,
              workerId: e.workerId,
              trade: worker.trade,
              status: agreed?.status ?? AttendanceStatus.values.byName(e.attendanceStatus),
              clockMinutes: e.clockMinutes,
              breakMinutes: e.breakMinutes,
              billableMinutes: agreed?.minutes ?? e.clientBillableMinutes,
              basis: basis,
              rateFils: e.clientRateFils!,
              amountFils: agreed == null ? e.clientAmountFils : agreed.amountFils,
            ),
          ),
        );
      }
    }
    rows.sort((a, b) {
      final date = a.line.workDate.compareTo(b.line.workDate);
      if (date != 0) return date;
      final site = a.siteName.compareTo(b.siteName);
      return site != 0 ? site : a.workerName.compareTo(b.workerName);
    });
    return (rows: rows, entries: entries, leftOut: TsLeftOut(noCompanyRate: noCompanyRate, noWorkerRate: noWorkerRate, onOtherTimesheet: onOther));
  }

  Map<String, TsAdjustment> _adjustmentsOf(TimesheetRevision r) => (jsonDecode(r.adjustments) as Map<String, Object?>).map((id, a) => MapEntry(id, TsAdjustment.fromJson(a! as Map<String, Object?>)));

  Future<TimesheetPreview> _draftOf(Timesheet sheet, TimesheetRevision revision) =>
      timesheetPreview(clientId: sheet.clientId, siteId: sheet.siteId, from: sheet.fromDate, to: sheet.toDate, ownTimesheetId: sheet.id, adjustments: _adjustmentsOf(revision));

  Future<Timesheet> _sheet(String id) => (select(timesheets)..where((t) => t.id.equals(id))).getSingle();

  Future<TimesheetRevision> _revision(String id) => (select(timesheetRevisions)..where((r) => r.id.equals(id))).getSingle();

  Future<List<TimesheetRevision>> _revisionsOf(String timesheetId) => (select(timesheetRevisions)
        ..where((r) => r.timesheetId.equals(timesheetId))
        ..orderBy([(r) => OrderingTerm.desc(r.revision)]))
      .get();

  /// A step only ever applies to the newest revision.
  Future<void> _mustBeLatest(TimesheetRevision r) async {
    if ((await _revisionsOf(r.timesheetId)).first.id != r.id) throw const TimesheetWrongStep();
  }

  TimesheetRevisionsCompanion _newRevision(String id, String timesheetId, int number, String operationId, {String? reason, String adjustments = '{}'}) {
    final now = DateTime.now().toUtc();
    return TimesheetRevisionsCompanion.insert(
      id: id,
      tenantId: tenantId,
      createdAtUtc: now,
      updatedAtUtc: now,
      actorId: actorId,
      sourceOperationId: operationId,
      timesheetId: timesheetId,
      revision: number,
      reason: Value(reason),
      adjustments: Value(adjustments),
    );
  }

  /// Starts a draft. It holds no rows of its own, so it always reads the attendance as it stands.
  Future<String> createTimesheet({required String clientId, String? siteId, required String from, required String to, required String operationId}) async {
    final id = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'timesheets',
      recordId: id,
      version: 1,
      action: 'create',
      change: () async {
        if ((await timesheetPreview(clientId: clientId, siteId: siteId, from: from, to: to)).rows.isEmpty) throw const TimesheetEmpty();
        final now = DateTime.now().toUtc();
        await into(timesheets).insert(
          TimesheetsCompanion.insert(id: id, tenantId: tenantId, createdAtUtc: now, updatedAtUtc: now, actorId: actorId, sourceOperationId: operationId, clientId: clientId, siteId: Value(siteId), fromDate: from, toDate: to),
        );
        await into(timesheetRevisions).insert(_newRevision(newUuid(), id, 1, operationId));
        return (await _sheet(id)).toJson();
      },
    );
    return id;
  }

  /// One step on a revision. [step] checks it fits and says what to write, inside the operation, so a retry of a step
  /// already taken changes nothing rather than failing.
  Future<void> _stepRevision(String revisionId, Future<TimesheetRevisionsCompanion> Function(TimesheetRevision r) step, {required String action, required String operationId, String? reason}) async {
    final before = await _revision(revisionId);
    await applyOperation(
      operationId: operationId,
      entity: 'timesheet_revisions',
      recordId: revisionId,
      version: before.version + 1,
      action: action,
      reason: reason,
      change: () async {
        final fields = await step(before);
        await (update(timesheetRevisions)..where((x) => x.id.equals(revisionId))).write(
          fields.copyWith(version: Value(before.version + 1), updatedAtUtc: Value(DateTime.now().toUtc()), actorId: Value(actorId), sourceOperationId: Value(operationId)),
        );
        return (await _revision(revisionId)).toJson();
      },
    );
  }

  /// Records what a company agreed for one row of a draft, or takes it back with null.
  Future<void> adjustTimesheetRow(String revisionId, String entryId, TsAdjustment? agreed, {required String operationId}) => _stepRevision(
    revisionId,
    (r) async {
      if (r.status != TsStatus.draft.name) throw const TimesheetWrongStep();
      final all = {..._adjustmentsOf(r)};
      if (agreed == null) {
        all.remove(entryId);
      } else {
        all[entryId] = agreed;
      }
      return TimesheetRevisionsCompanion(adjustments: Value(jsonEncode({for (final a in all.entries) a.key: a.value.toJson()})));
    },
    action: 'adjust',
    operationId: operationId,
    reason: agreed?.reason,
  );

  /// Approves a draft: its attendance freezes, and its rows are stored as they stand. The first approval gives the number.
  /// The revision it replaces keeps its lines, no longer current (TS-04, TS-06).
  Future<void> approveTimesheet(String revisionId, {required String operationId}) async {
    final r = await _revision(revisionId);
    await applyOperation(
      operationId: operationId,
      entity: 'timesheet_revisions',
      recordId: revisionId,
      version: r.version + 1,
      action: 'approve',
      change: () async {
        if (r.status != TsStatus.draft.name) throw const TimesheetWrongStep();
        final sheet = await _sheet(r.timesheetId);
        var draft = await _draftOf(sheet, r);
        final waiting = draft.entries.where((e) => e.state == 'submitted').toList();
        if (waiting.isNotEmpty) {
          await approveEntries(waiting, operationId: newUuid());
          draft = await _draftOf(sheet, r);
        }
        if (draft.rows.isEmpty) throw const TimesheetEmpty();

        final now = DateTime.now().toUtc();
        await (update(timesheetLines)..where((l) => l.timesheetId.equals(sheet.id) & l.live.equals(true))).write(const TimesheetLinesCompanion(live: Value(false)));
        await batch((b) {
          b.insertAll(timesheetLines, [
            for (final row in draft.rows)
              TimesheetLinesCompanion.insert(
                id: newUuid(),
                tenantId: tenantId,
                createdAtUtc: now,
                updatedAtUtc: now,
                actorId: actorId,
                sourceOperationId: operationId,
                timesheetId: sheet.id,
                revisionId: r.id,
                entryId: row.entryId,
                workKey: row.workKey,
                workDate: row.line.workDate,
                siteId: row.line.siteId,
                siteName: row.siteName,
                workerId: row.line.workerId,
                workerName: row.workerName,
                workerCode: row.workerCode,
                trade: Value(row.line.trade),
                attendanceStatus: row.line.status.name,
                clockMinutes: row.line.clockMinutes,
                breakMinutes: row.line.breakMinutes,
                billableMinutes: row.line.billableMinutes,
                basis: row.line.basis.name,
                rateFils: row.line.rateFils,
                amountFils: Value(row.line.amountFils),
                adjustReason: Value(row.adjustReason),
              ),
          ]);
        });
        if (sheet.number == null) {
          final year = int.parse(dubaiToday(now).substring(0, 4));
          final top = timesheets.seq.max();
          final seq = ((await (selectOnly(timesheets)
                        ..addColumns([top])
                        ..where(timesheets.year.equals(year)))
                      .getSingle())
                  .read(top) ??
              0) + 1;
          await (update(timesheets)..where((t) => t.id.equals(sheet.id))).write(
            TimesheetsCompanion(year: Value(year), seq: Value(seq), number: Value(documentNumber(DocKind.timesheetDaily, year, seq, 1)), version: Value(sheet.version + 1), updatedAtUtc: Value(now)),
          );
        }
        await (update(timesheetRevisions)..where((x) => x.id.equals(r.id))).write(
          TimesheetRevisionsCompanion(status: Value(TsStatus.approved.name), version: Value(r.version + 1), updatedAtUtc: Value(now), sourceOperationId: Value(operationId)),
        );
        final lines = await (select(timesheetLines)..where((l) => l.revisionId.equals(r.id))).get();
        return {'revision': (await _revision(r.id)).toJson(), 'lines': [for (final l in lines) l.toJson()]};
      },
    );
  }

  /// The owner's word that the company has the paper. The app can't know that by itself (DOC-07).
  Future<void> markTimesheetShared(String revisionId, String date, {required String operationId}) => _stepRevision(
    revisionId,
    (r) async {
      await _mustBeLatest(r);
      if (r.status != TsStatus.approved.name) throw const TimesheetWrongStep();
      return TimesheetRevisionsCompanion(status: Value(TsStatus.shared.name), sharedOn: Value(date));
    },
    action: 'share',
    operationId: operationId,
  );

  /// What the company said. Accepting locks the revision. A dispute can still end in acceptance, or in a new revision.
  /// Neither touches attendance or pay, so a late or angry company never holds up a wage (TS-04, ATT-07).
  Future<void> recordTimesheetResponse(String revisionId, {required bool accepted, required String date, String? note, String? evidenceAssetId, required String operationId}) => _stepRevision(
    revisionId,
    (r) async {
      await _mustBeLatest(r);
      final allowed = accepted ? const {'shared', 'disputed'} : const {'shared'};
      if (!allowed.contains(r.status)) throw const TimesheetWrongStep();
      return TimesheetRevisionsCompanion(
        status: Value((accepted ? TsStatus.accepted : TsStatus.disputed).name),
        respondedOn: Value(date),
        responseNote: Value(note),
        evidenceAssetId: Value(evidenceAssetId ?? r.evidenceAssetId),
      );
    },
    action: accepted ? 'accept' : 'dispute',
    operationId: operationId,
    reason: note,
  );

  /// Opens a new draft from an approved timesheet. Agreed rows carry over by attendance row, so one whose attendance was
  /// corrected since starts again from the new figures (TS-06).
  Future<void> startTimesheetRevision(String timesheetId, {required String reason, required String operationId}) async {
    final id = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'timesheet_revisions',
      recordId: id,
      version: 1,
      action: 'revise',
      reason: reason,
      change: () async {
        final latest = (await _revisionsOf(timesheetId)).first;
        if (latest.status == TsStatus.draft.name) throw const TimesheetWrongStep();
        final agreed = await (select(timesheetLines)..where((l) => l.revisionId.equals(latest.id) & l.adjustReason.isNotNull())).get();
        final carried = {
          for (final l in agreed) l.entryId: TsAdjustment(status: AttendanceStatus.values.byName(l.attendanceStatus), minutes: l.billableMinutes, amountFils: l.amountFils, reason: l.adjustReason!).toJson(),
        };
        await into(timesheetRevisions).insert(_newRevision(id, timesheetId, latest.revision + 1, operationId, reason: reason, adjustments: jsonEncode(carried)));
        return (await _revision(id)).toJson();
      },
    );
  }

  /// Throws away a draft. The first revision's draft takes the timesheet with it, and a later one falls back to the revision before.
  Future<void> deleteTimesheetDraft(String revisionId, {required String operationId}) async {
    final r = await (select(timesheetRevisions)..where((x) => x.id.equals(revisionId))).getSingleOrNull();
    if (r == null) return;
    await applyOperation(
      operationId: operationId,
      entity: 'timesheet_revisions',
      recordId: r.id,
      version: r.version + 1,
      action: 'delete',
      change: () async {
        if (r.status != TsStatus.draft.name) throw const TimesheetWrongStep();
        await (delete(timesheetRevisions)..where((x) => x.id.equals(r.id))).go();
        if (r.revision == 1) await (delete(timesheets)..where((t) => t.id.equals(r.timesheetId))).go();
        return {'id': r.id, 'deleted': true};
      },
    );
  }

  /// One revision of a timesheet, the newest unless [revision] says otherwise.
  Future<TimesheetView> timesheetView(String id, {int? revision}) async {
    final sheet = await _sheet(id);
    final revisions = await _revisionsOf(id);
    final shown = revision == null ? revisions.first : revisions.firstWhere((r) => r.revision == revision);
    final client = await (select(clients)..where((c) => c.id.equals(sheet.clientId))).getSingle();
    final site = sheet.siteId == null ? null : await (select(sites)..where((s) => s.id.equals(sheet.siteId!))).getSingle();
    final isDraft = shown.status == TsStatus.draft.name;
    final draft = isDraft ? await _draftOf(sheet, shown) : null;
    final stored = isDraft
        ? const <TimesheetLine>[]
        : await (select(timesheetLines)
                ..where((l) => l.revisionId.equals(shown.id))
                ..orderBy([(l) => OrderingTerm.asc(l.workDate), (l) => OrderingTerm.asc(l.siteName), (l) => OrderingTerm.asc(l.workerName)]))
              .get();
    return TimesheetView(
      sheet: sheet,
      clientName: client.name,
      clientLine: [?client.invoiceAddress ?? client.address, if (client.trn != null) 'TRN ${client.trn}'].join('   '),
      siteName: site?.name,
      revision: shown,
      revisions: revisions,
      rows: draft?.rows ?? [for (final l in stored) _rowOf(l)],
      leftOut: draft?.leftOut,
      changedRows: stored.isEmpty || shown.id != revisions.first.id ? 0 : await _changedRows(shown.id),
      billingChanges: shown.id == revisions.first.id ? await _billingChanges(id) : const [],
    );
  }

  TimesheetRow _rowOf(TimesheetLine l) => TimesheetRow(
    entryId: l.entryId,
    workKey: l.workKey,
    workerName: l.workerName,
    workerCode: l.workerCode,
    siteName: l.siteName,
    adjustReason: l.adjustReason,
    line: TsLine(
      workDate: l.workDate,
      siteId: l.siteId,
      workerId: l.workerId,
      trade: l.trade,
      status: AttendanceStatus.values.byName(l.attendanceStatus),
      clockMinutes: l.clockMinutes,
      breakMinutes: l.breakMinutes,
      billableMinutes: l.billableMinutes,
      basis: RateBasis.values.byName(l.basis),
      rateFils: l.rateFils,
      amountFils: l.amountFils,
    ),
  );

  Future<int> _changedRows(String revisionId) async {
    final l = timesheetLines;
    final e = attendanceEntries;
    final count = l.id.count();
    final query = selectOnly(l).join([innerJoin(e, e.id.equalsExp(l.entryId))])
      ..addColumns([count])
      ..where(l.revisionId.equals(revisionId) & e.superseded.equals(true));
    return (await query.getSingle()).read(count)!;
  }

  /// Sends a fresh copy whenever anything behind it changes.
  Stream<TimesheetView> watchTimesheet(String id, {int? revision}) async* {
    yield await timesheetView(id, revision: revision);
    final changes = tableUpdates(TableUpdateQuery.onAllTables([timesheets, timesheetRevisions, timesheetLines, billedAllocations, attendanceEntries, billingContracts, payContracts, workers, sites, clients]));
    await for (final _ in changes) {
      // A draft thrown away takes its timesheet with it while the screen is closing.
      if (await (select(timesheets)..where((t) => t.id.equals(id))).getSingleOrNull() == null) return;
      yield await timesheetView(id, revision: revision);
    }
  }

  /// Every timesheet, newest first.
  Stream<List<TimesheetListRow>> watchTimesheets() async* {
    Future<List<TimesheetListRow>> read() async {
      final names = {for (final c in await select(clients).get()) c.id: c.name};
      final places = {for (final s in await select(sites).get()) s.id: s.name};
      final newest = <String, TimesheetRevision>{};
      for (final r in await select(timesheetRevisions).get()) {
        if (r.revision > (newest[r.timesheetId]?.revision ?? 0)) newest[r.timesheetId] = r;
      }
      final l = timesheetLines;
      final sum = l.amountFils.sum();
      final amounts = {
        for (final r in await (selectOnly(l)
              ..addColumns([l.timesheetId, sum])
              ..where(l.live.equals(true))
              ..groupBy([l.timesheetId]))
            .get())
          r.read(l.timesheetId)!: r.read(sum),
      };
      final sheets = await (select(timesheets)..orderBy([(t) => OrderingTerm.desc(t.createdAtUtc)])).get();
      return [
        for (final t in sheets)
          TimesheetListRow(
            id: t.id,
            clientName: names[t.clientId] ?? '',
            siteName: places[t.siteId],
            fromDate: t.fromDate,
            toDate: t.toDate,
            number: t.number,
            revision: newest[t.id]!.revision,
            status: TsStatus.values.byName(newest[t.id]!.status),
            amountFils: amounts[t.id],
          ),
      ];
    }

    yield await read();
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables([timesheets, timesheetRevisions, timesheetLines]))) {
      yield await read();
    }
  }

  /// Approved work an invoice can still charge (TS-05). A disputed revision waits until it is settled, a monthly row's fee
  /// belongs to its contract (TS-08), and a row whose attendance has changed waits for a new revision.
  Future<List<TimesheetLine>> unbilledLines(String timesheetId) async {
    final l = timesheetLines;
    final r = timesheetRevisions;
    final e = attendanceEntries;
    final query = select(l).join([
      innerJoin(r, r.id.equalsExp(l.revisionId)),
      innerJoin(e, e.id.equalsExp(l.entryId)),
    ])
      ..where(l.timesheetId.equals(timesheetId) & l.live.equals(true) & r.status.isIn(const ['approved', 'shared', 'accepted']) & l.amountFils.isBiggerThanValue(0) & e.superseded.equals(false))
      ..orderBy([OrderingTerm.asc(l.workDate), OrderingTerm.asc(l.workerName)]);
    final billed = await _liveBillingKeys();
    return [
      for (final row in await query.get())
        if (!billed.contains(row.readTable(l).workKey)) row.readTable(l),
    ];
  }

  Future<Set<String>> _liveBillingKeys() async {
    final b = billedAllocations;
    final query = selectOnly(b)
      ..addColumns([b.workKey])
      ..where(b.released.equals(false));
    return {for (final row in await query.get()) row.read(b.workKey)!};
  }

  /// Records which work an invoice charged, all of it or none (TS-05). T16 calls this as it issues.
  Future<void> allocateBilling(String invoiceId, List<TimesheetLine> lines, {required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'billed_allocations',
      recordId: invoiceId,
      version: 1,
      action: 'bill',
      change: () async {
        final billed = await _liveBillingKeys();
        final clash = [
          for (final l in lines)
            if (billed.contains(l.workKey)) l.workKey,
        ];
        if (clash.isNotEmpty) throw AlreadyBilled(clash);
        final now = DateTime.now().toUtc();
        await batch((b) {
          b.insertAll(billedAllocations, [
            for (final l in lines)
              BilledAllocationsCompanion.insert(id: newUuid(), tenantId: tenantId, createdAtUtc: now, updatedAtUtc: now, actorId: actorId, sourceOperationId: operationId, lineId: l.id, workKey: l.workKey, invoiceId: invoiceId, amountFils: l.amountFils!),
          ]);
        });
        return {'invoice': invoiceId, 'lines': [for (final l in lines) l.id]};
      },
    );
  }

  /// Frees what a credit note or cancelled invoice charged. The rows stay, flagged (INV-06). T16 calls this.
  Future<void> releaseBilling(String invoiceId, {required String reason, required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'billed_allocations',
      recordId: invoiceId,
      version: 2,
      action: 'release',
      reason: reason,
      change: () async {
        await (update(billedAllocations)..where((b) => b.invoiceId.equals(invoiceId) & b.released.equals(false))).write(BilledAllocationsCompanion(released: const Value(true), updatedAtUtc: Value(DateTime.now().toUtc()), sourceOperationId: Value(operationId)));
        return {'invoice': invoiceId, 'released': true};
      },
    );
  }

  Future<List<BillingChange>> _billingChanges(String timesheetId) async {
    final l = timesheetLines;
    final b = billedAllocations;
    final query = select(b).join([innerJoin(l, l.id.equalsExp(b.lineId))])..where(b.released.equals(false) & l.timesheetId.equals(timesheetId));
    final billed = await query.get();
    if (billed.isEmpty) return const [];
    final current = {for (final line in await (select(l)..where((x) => x.timesheetId.equals(timesheetId) & x.live.equals(true))).get()) line.workKey: line};
    return [
      for (final row in billed)
        if ((current[row.readTable(b).workKey]?.amountFils ?? 0) != row.readTable(b).amountFils)
          BillingChange(
            workKey: row.readTable(b).workKey,
            workDate: row.readTable(l).workDate,
            workerName: row.readTable(l).workerName,
            billedFils: row.readTable(b).amountFils,
            nowFils: current[row.readTable(b).workKey]?.amountFils ?? 0,
          ),
    ];
  }
}
