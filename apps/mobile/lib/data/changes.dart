import 'dart:convert';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'cash.dart';
import 'closing.dart';
import 'tenant_database.dart';

/// What the owner reads about an entry or record that was edited or deleted (D-056). Values are plain: dates as stored,
/// money in fils, a status or kind by name, yes or no as a bool. Screens put them into words, in this order.
enum Fact {
  date,
  month,
  worker,
  company,
  site,
  room,
  code,
  name,
  status,
  time,
  breakMinutes,
  overtimeMinutes,
  bill,
  pay,
  kind,
  payKind,
  balanceKind,
  amount,
  basis,
  rate,
  halfAmount,
  includedMinutes,
  overtimeRate,
  breakPaid,
  partialMethod,
  partialDivisor,
  halfDayIsHalf,
  members,
  from,
  to,
  activeFrom,
  activeTo,
  trade,
  phone,
  contactPerson,
  email,
  address,
  invoiceAddress,
  vatRegistered,
  trn,
  dueDays,
  poReference,
  location,
  joined,
  roomCharge,
  roomChargeNote,
  visaInstalment,
  method,
  reference,
  category,
  reason,
  authorizedBy,
  source,
  note,
  active,
}

/// A worker, company, site, room or group that entries name. It can only be archived, or they would lose its name (D-056).
class RecordInUse implements Exception {
  const RecordInUse();
}

/// The records the owner edits and deletes as a whole, for the Delete tab's records tab (D-056).
const recordTables = ['workers', 'clients', 'sites', 'rooms', 'worker_groups', 'pay_contracts', 'billing_contracts', 'opening_balances'];

typedef Facts = Map<Fact, Object?>;
typedef FactChange = ({Fact fact, Object? from, Object? to});

Map<String, Object?> factsJson(Facts facts) => {for (final MapEntry(:key, :value) in facts.entries) key.name: ?value};

Facts factsFrom(Object? json) => {for (final MapEntry(:key, :value) in ((json as Map?) ?? const {}).entries) ?Fact.values.asNameMap()[key]: value};

/// What differs, in the order a reader expects.
List<FactChange> diffFacts(Facts before, Facts after) => [
  for (final fact in Fact.values)
    if (before[fact] != after[fact]) (fact: fact, from: before[fact], to: after[fact]),
];

/// One edit or delete as the owner reads it: when, the app's own note of what changed, and the user's note.
class ChangeNote {
  const ChangeNote({required this.atUtc, required this.deleted, required this.note, required this.changes, required this.facts, required this.recorded});

  factory ChangeNote.of(AuditEvent e) {
    final detail = e.detail == null ? const <String, Object?>{} : jsonDecode(e.detail!) as Map<String, Object?>;
    final note = (e.reason ?? '').trim();
    return ChangeNote(
      atUtc: e.atUtc,
      deleted: e.action == 'delete' || detail['kind'] == 'delete',
      note: note.isEmpty ? null : note,
      changes: detail['from'] == null ? const [] : diffFacts(factsFrom(detail['from']), factsFrom(detail['to'])),
      facts: factsFrom(detail['facts'] ?? detail['to']),
      recorded: detail['from'] != null,
    );
  }

  final DateTime atUtc;
  final bool deleted;
  final String? note;

  /// Empty for an edit made before the app kept these, which still shows as edited.
  final List<FactChange> changes;

  /// The entry as it was when deleted, or as it became when edited.
  final Facts facts;

  /// The app kept what changed. Then an edit that changed nothing and says nothing isn't one.
  final bool recorded;

  bool get isNothing => recorded && changes.isEmpty && note == null;
}

/// What a write was, so the Delete tab and the edited colour can tell them apart.
const _editActions = {'update', 'correct', 'edit'};

extension ChangeOps on TenantDatabase {
  Future<Facts> attendanceFacts(AttendanceEntry e) async {
    final worker = await (select(workers)..where((w) => w.id.equals(e.workerId))).getSingleOrNull();
    final client = await (select(clients)..where((c) => c.id.equals(e.clientId))).getSingleOrNull();
    final site = await (select(sites)..where((s) => s.id.equals(e.siteId))).getSingleOrNull();
    final absent = e.attendanceStatus == AttendanceStatus.absent.name;
    return {
      Fact.date: e.workDate,
      Fact.worker: worker == null ? null : '${worker.name} (${worker.code})',
      Fact.company: client?.name,
      Fact.site: site?.name,
      Fact.status: e.attendanceStatus,
      Fact.time: e.startUtc == null || e.endUtc == null
          ? null
          : '${showMinuteOfDay(dubaiMinuteOfDay(e.startUtc!))}-${showMinuteOfDay(dubaiMinuteOfDay(e.endUtc!))}',
      Fact.breakMinutes: absent ? null : e.breakMinutes,
      Fact.overtimeMinutes: e.overtimeMinutes == 0 ? null : e.overtimeMinutes,
      Fact.bill: e.clientAmountFils,
      Fact.pay: e.workerAmountFils,
      Fact.note: e.notes,
    };
  }

  Future<Facts> cashFacts(CashEntry e) async {
    final worker = e.workerId == null ? null : await (select(workers)..where((w) => w.id.equals(e.workerId!))).getSingleOrNull();
    final client = e.clientId == null ? null : await (select(clients)..where((c) => c.id.equals(e.clientId!))).getSingleOrNull();
    final site = e.siteId == null ? null : await (select(sites)..where((s) => s.id.equals(e.siteId!))).getSingleOrNull();
    final room = e.roomId == null ? null : await (select(rooms)..where((r) => r.id.equals(e.roomId!))).getSingleOrNull();
    return {
      Fact.date: e.entryDate,
      Fact.kind: e.kind,
      Fact.amount: e.amountFils,
      Fact.worker: worker == null ? null : '${worker.name} (${worker.code})',
      Fact.company: client?.name,
      Fact.site: site?.name,
      Fact.room: room?.name,
      Fact.category: e.category,
      Fact.method: e.method,
      Fact.reference: e.reference,
      Fact.note: e.note,
    };
  }

  Future<String?> _workerName(Object? id) async {
    if (id == null) return null;
    final w = await (select(workers)..where((w) => w.id.equals(id as String))).getSingleOrNull();
    return w == null ? null : '${w.name} (${w.code})';
  }

  Future<String?> _clientName(Object? id) async =>
      id == null ? null : (await (select(clients)..where((c) => c.id.equals(id as String))).getSingleOrNull())?.name;

  Future<String?> _siteName(Object? id) async =>
      id == null ? null : (await (select(sites)..where((s) => s.id.equals(id as String))).getSingleOrNull())?.name;

  Future<String?> _roomName(Object? id) async =>
      id == null ? null : (await (select(rooms)..where((r) => r.id.equals(id as String))).getSingleOrNull())?.name;

  static String? _times(Object? start, Object? end) =>
      start == null || end == null ? null : '${showMinuteOfDay(start as int)}-${showMinuteOfDay(end as int)}';

  /// What the owner reads about a saved record, from its row as `toJson` gives it: names in place of ids, so a deleted
  /// one still reads whole (D-056). Null for a table that is not one of these records.
  Future<Facts?> recordFacts(String table, Map<String, Object?> r) async => switch (table) {
    'workers' => {
      Fact.code: r['code'],
      Fact.name: r['name'],
      Fact.trade: r['trade'],
      Fact.phone: r['phone'],
      Fact.joined: r['joiningDate'],
      Fact.room: await _roomName(r['roomId']),
      Fact.roomCharge: r['roomChargeFils'],
      Fact.roomChargeNote: r['roomChargeNote'],
      Fact.visaInstalment: r['visaInstalmentFils'],
      Fact.active: r['active'],
    },
    'clients' => {
      Fact.name: r['name'],
      Fact.contactPerson: r['contactPerson'],
      Fact.phone: r['phone'],
      Fact.email: r['email'],
      Fact.address: r['address'],
      Fact.vatRegistered: r['vatRegistered'],
      Fact.trn: r['trn'],
      Fact.invoiceAddress: r['invoiceAddress'],
      Fact.dueDays: r['dueDays'],
      Fact.poReference: r['poReference'],
      Fact.note: r['note'],
      Fact.active: r['active'],
    },
    'sites' => {
      Fact.company: await _clientName(r['clientId']),
      Fact.name: r['name'],
      Fact.location: r['location'],
      Fact.contactPerson: r['contact'],
      Fact.time: _times(r['defaultStartMinute'], r['defaultEndMinute']),
      Fact.breakMinutes: r['defaultBreakMinutes'] == 0 ? null : r['defaultBreakMinutes'],
      Fact.activeFrom: r['activeFrom'],
      Fact.activeTo: r['activeTo'],
      Fact.active: r['active'],
    },
    'rooms' => {Fact.name: r['name'], Fact.note: r['note'], Fact.active: r['active']},
    'worker_groups' => {
      Fact.name: r['name'],
      Fact.company: await _clientName(r['clientId']),
      Fact.site: await _siteName(r['siteId']),
      Fact.rate: r['dailyRateFils'],
      Fact.halfDayIsHalf: r['halfDayIsHalf'],
      Fact.time: _times(r['startMinute'], r['endMinute']),
      Fact.breakMinutes: r['breakMinutes'] == 0 ? null : r['breakMinutes'],
      Fact.members: await _members(r['id'] as String),
      Fact.active: r['active'],
    },
    'payroll_items' => {
      Fact.month: (r['periodFrom'] as String).substring(0, 7),
      Fact.worker: await _workerName(r['workerId']),
      Fact.payKind: r['kind'],
      Fact.amount: r['amountFils'],
      Fact.reason: r['reason'],
      Fact.authorizedBy: r['authorizedBy'],
      Fact.room: await _roomName(r['roomId']),
      Fact.note: r['note'],
    },
    'opening_balances' => {
      Fact.balanceKind: r['kind'],
      Fact.worker: await _workerName(r['workerId']),
      Fact.company: await _clientName(r['clientId']),
      Fact.amount: r['amountFils'],
      Fact.date: r['asOfDate'],
      Fact.source: r['sourceNote'],
    },
    'pay_contracts' || 'billing_contracts' => {
      Fact.company: await _clientName(r['clientId']),
      Fact.worker: await _workerName(r['workerId']),
      Fact.site: await _siteName(r['siteId']),
      Fact.basis: r['basis'],
      Fact.rate: r['rateFils'],
      Fact.halfAmount: r['halfAmountFils'],
      Fact.includedMinutes: r['includedMinutes'],
      Fact.overtimeRate: r['overtimeRateFils'],
      Fact.breakPaid: r['breakPaid'],
      Fact.partialMethod: r['partialMethod'],
      Fact.partialDivisor: r['partialDivisor'],
      Fact.from: r['effectiveFrom'],
      Fact.to: r['effectiveTo'],
    },
    _ => null,
  };

  /// A group's workers by name, each with the rate set for them there.
  Future<String?> _members(String groupId) async {
    final rows = await (select(workerGroupMembers).join([innerJoin(workers, workers.id.equalsExp(workerGroupMembers.workerId))])
          ..where(workerGroupMembers.groupId.equals(groupId))
          ..orderBy([OrderingTerm.asc(workers.name)]))
        .get();
    if (rows.isEmpty) return null;
    return [
      for (final r in rows)
        () {
          final w = r.readTable(workers);
          final fils = r.readTable(workerGroupMembers).rateFils;
          return '${w.name} (${w.code})${fils == null ? '' : ' ${formatAed(fils)}'}';
        }(),
    ].join(', ');
  }

  /// True when a row of another table names this record, a worker's place in a group aside.
  Future<bool> _inUse(String table, String id) async {
    for (final t in allTables) {
      if (t.actualTableName == 'worker_group_members') continue;
      for (final key in await customSelect('PRAGMA foreign_key_list(${t.actualTableName})').get()) {
        if (key.read<String>('table') != table) continue;
        final hit = await customSelect(
          'SELECT 1 FROM ${t.actualTableName} WHERE ${key.read<String>('from')} = ? LIMIT 1',
          variables: [Variable<String>(id)],
        ).getSingleOrNull();
        if (hit != null) return true;
      }
    }
    return false;
  }

  /// Deletes a record nothing else names, kept whole for the Delete tab (D-056). One that entries name is refused with
  /// [RecordInUse]. A group's member list goes with the group, and a worker's places in groups with the worker.
  Future<void> deleteRecord<T extends Table, D extends DataClass>(TableInfo<T, D> table, String id, {String? note, required String operationId}) =>
      transaction(() async {
        final name = table.actualTableName;
        final idColumn = table.columnsByName['id']! as Expression<String>;
        final row = (await (select(table)..where((_) => idColumn.equals(id))).getSingle()).toJson();
        if (await _inUse(name, id)) throw const RecordInUse();
        final facts = factsJson((await recordFacts(name, row))!);
        await applyOperation(
          operationId: operationId,
          entity: name,
          recordId: id,
          version: (row['version'] as int) + 1,
          action: 'delete',
          reason: note,
          detail: () async => {'kind': 'delete', 'facts': facts},
          change: () async {
            if (name == 'worker_groups') await (delete(workerGroupMembers)..where((m) => m.groupId.equals(id))).go();
            if (name == 'workers') await (delete(workerGroupMembers)..where((m) => m.workerId.equals(id))).go();
            await (delete(table)..where((_) => idColumn.equals(id))).go();
            return {'id': id, 'deleted': true};
          },
        );
      });

  /// Opens every closed month from [date]'s on, latest first, each with [reason] on record, so an entry there can change
  /// (D-056). Gives the months it opened, for the screen to say so. The owner closes them again.
  Future<List<String>> openMonthsFrom(String date, {required String reason}) async {
    final opened = <String>[];
    while (true) {
      final through = await lockedThrough();
      if (through == null || through.compareTo(date) < 0) return opened;
      final lock = await (select(periodLocks)..where((l) => l.reopened.equals(false) & l.lastDay.equals(through))).getSingle();
      await reopenMonth(lock, reason: reason, operationId: newUuid());
      opened.add(lock.month);
    }
  }

  /// Edits a row wherever it stands: in place before approval, by a correction after it (ATT-08). A closed month opens
  /// first. Gives the months opened.
  Future<List<String>> editAttendance(AttendanceEntry old, EntryInput input, {String? note, required String reopenReason, required String operationId}) =>
      transaction(() async {
        final opened = await openMonthsFrom(old.workDate, reason: note ?? reopenReason);
        final before = factsJson(await attendanceFacts(old));
        if (old.state == 'draft' || old.state == 'submitted') {
          await updateUnapprovedEntry(
            old,
            input,
            operationId: operationId,
            note: note,
            detail: () async => {'from': before, 'to': factsJson(await attendanceFacts(await _entry(old.id)))},
          );
        } else {
          await correctEntry(
            old,
            input,
            reason: note,
            operationId: operationId,
            // Only one row can revise another, since the original is then superseded.
            detail: () async => {
              'from': before,
              'to': factsJson(await attendanceFacts(await (select(attendanceEntries)..where((e) => e.revisesEntryId.equals(old.id))).getSingle())),
            },
          );
        }
        return opened;
      });

  /// Deletes a row: a draft goes, an approved or paid one gets a deleted correction, so pay already given comes back as a
  /// difference in the next payroll (D-056, ATT-08). Either way it is kept whole for the Delete tab.
  Future<List<String>> deleteAttendance(AttendanceEntry old, {String? note, required String reopenReason, required String operationId}) =>
      transaction(() async {
        final opened = await openMonthsFrom(old.workDate, reason: note ?? reopenReason);
        final facts = factsJson(await attendanceFacts(old));
        Future<Map<String, Object?>> detail() async => {'kind': 'delete', 'facts': facts};
        if ((old.state == 'draft' || old.state == 'submitted') && old.payrollLineId == null) {
          await deleteUnapprovedEntry(old, operationId: operationId, note: note, detail: detail);
        } else {
          await correctEntry(
            old,
            EntryInput(
              workerId: old.workerId,
              groupId: old.groupId,
              shift: const ShiftInput(status: AttendanceStatus.absent),
            ),
            reason: note,
            operationId: operationId,
            deleted: true,
            detail: detail,
          );
        }
        return opened;
      });

  /// Deletes a cash line by its reversal on its own date, so every total drops it, and both leave the cash book
  /// (D-056, REP-08). A closed month opens first.
  Future<List<String>> deleteCash(CashEntry entry, {String? note, required String reopenReason, required String operationId}) => transaction(() async {
    final opened = await openMonthsFrom(entry.entryDate, reason: note ?? reopenReason);
    final facts = factsJson(await cashFacts(entry));
    await reverseCashEntry(entry, reason: note, operationId: operationId, detail: () async => {'kind': 'delete', 'facts': facts});
    return opened;
  });

  /// Edits a cash line: [add] writes the new one under [operationId], and the old one is reversed on its own date first,
  /// so what it settled is free again, all or nothing. The new line is marked edited, with what changed (D-056).
  Future<List<String>> replaceCash(
    CashEntry old,
    Future<void> Function() add, {
    String? note,
    required String newDate,
    required String reopenReason,
    required String operationId,
  }) => transaction(() async {
    // A retry after the edit landed changes nothing (TEAM-04).
    if (await (select(outbox)..where((o) => o.operationId.equals('$operationId-edit'))).getSingleOrNull() != null) return const <String>[];
    final first = old.entryDate.compareTo(newDate) <= 0 ? old.entryDate : newDate;
    final opened = await openMonthsFrom(first, reason: note ?? reopenReason);
    final before = factsJson(await cashFacts(old));
    await reverseCashEntry(old, reason: note, operationId: newUuid(), detail: () async => {'kind': 'replaced'});
    await add();
    final added = await (select(cashEntries)..where((c) => c.sourceOperationId.equals(operationId) & c.reversesEntryId.isNull())).getSingle();
    await applyOperation(
      operationId: '$operationId-edit',
      entity: 'cash_entries',
      recordId: added.id,
      version: 1,
      action: 'edit',
      reason: note,
      detail: () async => {'from': before, 'to': factsJson(await cashFacts(added)), 'replaces': old.id},
      change: () async => {'id': added.id, 'replaces': old.id},
    );
    return opened;
  });

  Future<AttendanceEntry> _entry(String id) => (select(attendanceEntries)..where((e) => e.id.equals(id))).getSingle();

  /// Every edit of these entries, by the entry it now shows on, oldest first. A corrected row carries the notes of the
  /// rows it replaced, and so does an edited cash line, so nothing said earlier is lost (D-056).
  Stream<Map<String, List<ChangeNote>>> watchEdits(String entity) {
    Future<Map<String, List<ChangeNote>>> read() async {
      final events =
          await (select(auditEvents)
                ..where((a) => a.entity.equals(entity) & a.action.isIn(_editActions))
                ..orderBy([(a) => OrderingTerm.asc(a.atUtc)]))
              .get();
      final own = <String, List<ChangeNote>>{};
      for (final e in events) {
        final note = ChangeNote.of(e);
        if (!note.isNothing) (own[e.recordId] ??= []).add(note);
      }
      // Which earlier record each one replaced: a correction's original, or the line an edit reversed.
      final previous = <String, String>{};
      if (entity == 'attendance_entries') {
        final e = attendanceEntries;
        for (final r
            in await (selectOnly(e)
                  ..addColumns([e.id, e.revisesEntryId])
                  ..where(e.revisesEntryId.isNotNull()))
                .get()) {
          previous[r.read(e.id)!] = r.read(e.revisesEntryId)!;
        }
      } else {
        for (final e in events) {
          final replaces = e.detail == null ? null : (jsonDecode(e.detail!) as Map<String, Object?>)['replaces'] as String?;
          if (replaces != null) previous[e.recordId] = replaces;
        }
      }
      return {
        for (final id in own.keys)
          id: [for (String? at = previous[id]; at != null; at = previous[at]) ...?own[at], ...own[id]!]..sort((a, b) => a.atUtc.compareTo(b.atUtc)),
      };
    }

    return Stream.multi((sink) async {
      sink.add(await read());
      await for (final _ in tableUpdates(TableUpdateQuery.onAllTables([auditEvents]))) {
        sink.add(await read());
      }
    });
  }
}
