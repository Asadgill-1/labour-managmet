import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart';

import '../../app/side_panel.dart';
import '../../data/cash.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_row.dart';
import '../rates/rate_labels.dart';
import '../today/attendance_review_screen.dart' show statusLabel;
import 'register_model.dart';

typedef _Option = ({String value, String label});

/// Everything a register row names, and the choices each filter offers.
class _Masters {
  _Masters(this.workers, this.clients, this.sites, this.rooms, this.groups);

  final Map<String, Worker> workers;
  final Map<String, Client> clients;
  final Map<String, Site> sites;
  final Map<String, Room> rooms;
  final Map<String, WorkerGroup> groups;

  static Future<_Masters> load(TenantDatabase db) async => _Masters(
    {for (final w in await (db.select(db.workers)..orderBy([(w) => OrderingTerm.asc(w.name)])).get()) w.id: w},
    {for (final c in await (db.select(db.clients)..orderBy([(c) => OrderingTerm.asc(c.name)])).get()) c.id: c},
    {for (final s in await (db.select(db.sites)..orderBy([(s) => OrderingTerm.asc(s.name)])).get()) s.id: s},
    {for (final r in await (db.select(db.rooms)..orderBy([(r) => OrderingTerm.asc(r.name)])).get()) r.id: r},
    {for (final g in await (db.select(db.workerGroups)..orderBy([(g) => OrderingTerm.asc(g.name)])).get()) g.id: g},
  );

  List<_Option> get workerOptions => [for (final w in workers.values) (value: w.id, label: '${w.name} (${w.code})')];
  List<_Option> get clientOptions => [for (final c in clients.values) (value: c.id, label: c.name)];
  List<_Option> get siteOptions => [for (final s in sites.values) (value: s.id, label: '${s.name} (${clients[s.clientId]?.name ?? ''})')];
  List<_Option> get roomOptions => [for (final r in rooms.values) (value: r.id, label: r.name)];
  List<_Option> get groupOptions => [for (final g in groups.values) (value: g.id, label: g.name)];
}

bool _inRange(String date, String? from, String? to) => (from == null || date.compareTo(from) >= 0) && (to == null || date.compareTo(to) <= 0);

String _clock(DateTime? utc) => utc == null ? '' : showMinuteOfDay(dubaiMinuteOfDay(utc));

String _methodLabel(AppLocalizations l10n, String? method) => switch (method) {
  'cash' => l10n.methodCash,
  'bank' => l10n.methodBank,
  _ => '',
};

/// What a stored attendance row's state means to the owner. A paid row carries its payroll line (D-033).
String _stateLabel(AppLocalizations l10n, AttendanceEntry e) {
  if (e.payrollLineId != null) return l10n.stateLinked;
  return switch (e.state) {
    'draft' => l10n.stateDraft,
    'submitted' => l10n.stateSubmitted,
    'approved' => l10n.stateApproved,
    _ => l10n.stateLinked,
  };
}

/// Registers read stored rows and never change them (D-038). [from] and [to] are stored dates, and null means no limit.
Future<RegisterData> buildRegister(TenantDatabase db, AppLocalizations l10n, Section section, {String? from, String? to}) async {
  final masters = await _Masters.load(db);
  return switch (section) {
    Section.attendanceRegister => _attendance(db, l10n, masters, from, to),
    Section.workerRegister => _workers(db, l10n, masters, from, to),
    Section.visaRegister => _visa(db, l10n, masters, from, to),
    Section.companyRegister => _companies(db, l10n, masters, from, to),
    Section.payrollRegister => _payroll(db, l10n, masters, from, to),
    Section.advanceRegister => _advance(db, l10n, masters, from, to),
    Section.cashRegister => _cash(db, l10n, masters, from, to),
    Section.roomRegister => _rooms(db, l10n, masters, from, to),
    _ => throw ArgumentError.value(section, 'section', 'is not a register'),
  };
}

/// Read in slices, because turning a thousand workers' month into objects in one go would freeze the screen.
Future<List<AttendanceEntry>> _liveEntries(TenantDatabase db, String? from, String? to) async {
  const slice = 2000;
  final rows = <AttendanceEntry>[];
  while (true) {
    final part = await (db.select(db.attendanceEntries)
          ..where(
            (e) =>
                e.superseded.equals(false) &
                (from == null ? const Constant(true) : e.workDate.isBiggerOrEqualValue(from)) &
                (to == null ? const Constant(true) : e.workDate.isSmallerOrEqualValue(to)),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.workDate), (e) => OrderingTerm.asc(e.id)])
          ..limit(slice, offset: rows.length))
        .get();
    rows.addAll(part);
    if (part.length < slice) return rows;
  }
}

/// A rate for a row, or a plain flag where someone worked with none. An absent row needs no rate.
String? rateCell(AppLocalizations l10n, String status, String? basis, int? rateFils) {
  if (rateFils != null) return rateSummary(l10n, basis!, rateFils);
  return status == AttendanceStatus.absent.name ? null : l10n.issueNoRate;
}

// Where each figure sits on an attendance row.
const _aWorker = 1;
const _aCode = 2;
const _aCompany = 3;
const _aSite = 4;
const _aCompanyHours = 10;
const _aWorkerHours = 11;
const _aOvertime = 12;
const _aCompanyRate = 13;
const _aBill = 14;
const _aPay = 16;
const _aDifference = 17;

/// The sums an attendance register is read for: each worker's days and pay, and each site's bill and difference.
List<RegisterRollup> _attendanceRollups(AppLocalizations l10n, List<RegisterEntry> shown) {
  final byWorker = <String, List<RegisterEntry>>{};
  final bySite = <String, List<RegisterEntry>>{};
  for (final e in shown) {
    byWorker.putIfAbsent(e.tags['worker']!.first, () => []).add(e);
    bySite.putIfAbsent(e.tags['site']!.first, () => []).add(e);
  }
  int days(List<RegisterEntry> rows, AttendanceStatus status) => rows.where((e) => e.tags['status']!.contains(status.name)).length;
  String text(RegisterEntry e, int column) => (e.cells[column] as String?) ?? '';
  final workers = byWorker.values.toList()..sort((a, b) => text(a.first, _aWorker).compareTo(text(b.first, _aWorker)));
  final sites = bySite.values.toList()
    ..sort((a, b) {
      final company = text(a.first, _aCompany).compareTo(text(b.first, _aCompany));
      return company != 0 ? company : text(a.first, _aSite).compareTo(text(b.first, _aSite));
    });
  return [
    RegisterRollup(
      l10n.regByWorker,
      [
        RegisterColumn(l10n.colWorker, flex: 5),
        RegisterColumn(l10n.colCode, flex: 2),
        RegisterColumn(l10n.statusPresent, kind: CellKind.number, flex: 2, total: true),
        RegisterColumn(l10n.statusHalf, kind: CellKind.number, flex: 2, total: true),
        RegisterColumn(l10n.statusAbsent, kind: CellKind.number, flex: 2, total: true),
        RegisterColumn(l10n.colWorkerHours, kind: CellKind.minutes, flex: 2, total: true),
        RegisterColumn(l10n.colOvertime, kind: CellKind.minutes, flex: 2, total: true),
        RegisterColumn(l10n.colPay, kind: CellKind.money, total: true),
      ],
      [
        for (final rows in workers)
          RegisterEntry([
            text(rows.first, _aWorker),
            text(rows.first, _aCode),
            days(rows, AttendanceStatus.present),
            days(rows, AttendanceStatus.half),
            days(rows, AttendanceStatus.absent),
            columnTotal(rows, _aWorkerHours),
            columnTotal(rows, _aOvertime),
            columnTotal(rows, _aPay),
          ]),
      ],
    ),
    RegisterRollup(
      l10n.regBySite,
      [
        RegisterColumn(l10n.colCompany, flex: 5),
        RegisterColumn(l10n.colSite, flex: 5),
        RegisterColumn(l10n.colWorkers, kind: CellKind.number, flex: 2),
        RegisterColumn(l10n.colCompanyHours, kind: CellKind.minutes, flex: 2, total: true),
        RegisterColumn(l10n.colBill, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colPay, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colDifference, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colNoRate, kind: CellKind.number, flex: 2, total: true),
      ],
      [
        for (final rows in sites)
          RegisterEntry([
            text(rows.first, _aCompany),
            text(rows.first, _aSite),
            rows.where((e) => !e.tags['status']!.contains(AttendanceStatus.absent.name)).map((e) => e.tags['worker']!.first).toSet().length,
            columnTotal(rows, _aCompanyHours),
            columnTotal(rows, _aBill),
            columnTotal(rows, _aPay),
            columnTotal(rows, _aDifference),
            rows.where((e) => e.cells[_aCompanyRate] == l10n.issueNoRate).length,
          ]),
      ],
    ),
  ];
}

Future<RegisterData> _attendance(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final rows = await _liveEntries(db, from, to);
  String name(AttendanceEntry e) => m.workers[e.workerId]?.name ?? '';
  rows.sort((a, b) {
    final date = b.workDate.compareTo(a.workDate);
    return date != 0 ? date : name(a).compareTo(name(b));
  });
  return RegisterData(
    title: l10n.regAttendance,
    titleColumn: 1,
    amountColumns: const [_aPay],
    bandColumns: const [_aWorkerHours, _aBill, _aPay],
    note: l10n.regAttendanceNote,
    rollupsOf: (shown) => shown.isEmpty ? const [] : _attendanceRollups(l10n, shown),
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date, flex: 4),
      RegisterColumn(l10n.colWorker, flex: 4),
      RegisterColumn(l10n.colCode, flex: 2, inPdf: false),
      RegisterColumn(l10n.colCompany),
      RegisterColumn(l10n.colSite),
      // A group's wage comes before the worker's own rate (D-029), so the group explains the rate beside it.
      RegisterColumn(l10n.colGroup),
      RegisterColumn(l10n.filterStatus),
      RegisterColumn(l10n.colIn, flex: 2),
      RegisterColumn(l10n.colOut, flex: 2),
      RegisterColumn(l10n.colBreak, kind: CellKind.minutes, flex: 2),
      RegisterColumn(l10n.colCompanyHours, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colWorkerHours, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colOvertime, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colCompanyRate, flex: 4),
      RegisterColumn(l10n.colBill, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colWorkerRate, flex: 4),
      RegisterColumn(l10n.colPay, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colDifference, kind: CellKind.money, total: true),
      RegisterColumn(l10n.filterState),
      RegisterColumn(l10n.note, inPdf: false),
    ],
    filters: [
      RegisterFilter('worker', l10n.colWorker, m.workerOptions),
      RegisterFilter('client', l10n.colCompany, m.clientOptions),
      RegisterFilter('site', l10n.colSite, m.siteOptions),
      RegisterFilter('group', l10n.colGroup, m.groupOptions),
      RegisterFilter('status', l10n.filterStatus, [for (final s in AttendanceStatus.values) (value: s.name, label: statusLabel(l10n, s))]),
      RegisterFilter('state', l10n.filterState, [
        (value: 'draft', label: l10n.stateDraft),
        (value: 'submitted', label: l10n.stateSubmitted),
        (value: 'approved', label: l10n.stateApproved),
        (value: 'paid', label: l10n.stateLinked),
      ]),
    ],
    entries: [
      for (final e in rows)
        RegisterEntry(
          [
            e.workDate,
            name(e),
            m.workers[e.workerId]?.code,
            m.clients[e.clientId]?.name,
            m.sites[e.siteId]?.name,
            m.groups[e.groupId]?.name,
            statusLabel(l10n, AttendanceStatus.values.byName(e.attendanceStatus)),
            _clock(e.startUtc),
            _clock(e.endUtc),
            e.breakMinutes,
            e.clientBillableMinutes,
            e.workerPayableMinutes,
            e.overtimeMinutes,
            rateCell(l10n, e.attendanceStatus, e.clientBasis, e.clientRateFils),
            e.clientAmountFils,
            rateCell(l10n, e.attendanceStatus, e.workerBasis, e.workerRateFils),
            e.workerAmountFils,
            e.clientAmountFils == null || e.workerAmountFils == null ? null : e.clientAmountFils! - e.workerAmountFils!,
            _stateLabel(l10n, e),
            [if (e.revisesEntryId != null) l10n.correctedTag, ?e.notes].join(', '),
          ],
          group: e.workDate,
          tags: {
            'worker': {e.workerId},
            'client': {e.clientId},
            'site': {e.siteId},
            'group': {?e.groupId},
            'status': {e.attendanceStatus},
            'state': {e.payrollLineId != null ? 'paid' : e.state},
          },
        ),
    ],
  );
}

Future<RegisterData> _companies(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final rows = await _liveEntries(db, from, to);
  final bySite = <(String, String), List<AttendanceEntry>>{};
  for (final e in rows) {
    bySite.putIfAbsent((e.workDate, e.siteId), () => []).add(e);
  }
  String company(String siteId) => m.clients[m.sites[siteId]?.clientId]?.name ?? '';
  final keys = bySite.keys.toList()
    ..sort((a, b) {
      final date = b.$1.compareTo(a.$1);
      if (date != 0) return date;
      final name = company(a.$2).compareTo(company(b.$2));
      return name != 0 ? name : (m.sites[a.$2]?.name ?? '').compareTo(m.sites[b.$2]?.name ?? '');
    });
  int sum(List<AttendanceEntry> rows, int? Function(AttendanceEntry) of) => rows.fold(0, (total, e) => total + (of(e) ?? 0));
  return RegisterData(
    title: l10n.regCompanies,
    titleColumn: 1,
    amountColumns: const [5],
    bandColumns: const [5, 6, 7],
    note: l10n.regCompanyNote,
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colCompany, flex: 5),
      RegisterColumn(l10n.colSite, flex: 5),
      RegisterColumn(l10n.colWorkers, kind: CellKind.number, flex: 2),
      RegisterColumn(l10n.colHours, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colBill, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colWages, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colDifference, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colNoRate, kind: CellKind.number, flex: 2, total: true),
    ],
    filters: [RegisterFilter('client', l10n.colCompany, m.clientOptions), RegisterFilter('site', l10n.colSite, m.siteOptions)],
    entries: [
      for (final key in keys)
        () {
          final day = bySite[key]!;
          final bill = sum(day, (e) => e.clientAmountFils);
          final wages = sum(day, (e) => e.workerAmountFils);
          return RegisterEntry(
            [
              key.$1,
              company(key.$2),
              m.sites[key.$2]?.name,
              day.where((e) => e.attendanceStatus != AttendanceStatus.absent.name).map((e) => e.workerId).toSet().length,
              sum(day, (e) => e.clientBillableMinutes),
              bill,
              wages,
              bill - wages,
              day.where((e) => e.clientRateFils == null && e.attendanceStatus != AttendanceStatus.absent.name).length,
            ],
            group: key.$1,
            tags: {
              'client': {?m.sites[key.$2]?.clientId},
              'site': {key.$2},
            },
          );
        }(),
    ],
  );
}

/// One line of a worker's account. In date order, each line can say where the account stood after it.
class _AccountLine {
  const _AccountLine(
    this.date,
    this.at,
    this.what, {
    this.status,
    this.company,
    this.site,
    this.timeIn,
    this.timeOut,
    this.minutes,
    this.overtime,
    this.rate,
    this.earned,
    this.given,
    this.cut,
    this.paid,
    this.brought = 0,
    this.advance = 0,
    this.visa = 0,
    this.note,
  });

  final String date;
  final DateTime at;
  final String what;
  final String? status;
  final String? company;
  final String? site;
  final String? timeIn;
  final String? timeOut;
  final int? minutes;
  final int? overtime;
  final String? rate;

  /// Work, a monthly salary or an allowance.
  final int? earned;

  /// Advance the worker has had. It counts when given, so taking it back through pay changes nothing here.
  final int? given;
  final int? cut;
  final int? paid;

  /// Owed from before this app. Old debt is never new earnings (MASTER-05).
  final int brought;

  /// How this line moves what is left of the worker's advance and visa money.
  final int advance;
  final int visa;
  final String? note;

  int get change => brought + (earned ?? 0) - (given ?? 0) - (cut ?? 0) - (paid ?? 0);
}

// Where each figure sits on a worker's account row.
const _wMinutes = 8;
const _wEarned = 11;
const _wGiven = 12;
const _wCut = 13;
const _wPaid = 14;
const _wLeft = 15;

/// Each worker's account, date by date: where they worked and at what rate, what they earned, what they took, what they
/// were paid, and what is left (D-041, D-042). Balance = earned - advance - deductions, room and visa cut - paid, and
/// always derives (REP-08). Work before the range is only added up, so years of history cost nothing here.
Future<RegisterData> _workers(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final entries = groupedBy(await _liveEntries(db, from, to), (e) => e.workerId);
  final earnedBefore = <String, int>{};
  if (from != null) {
    final sum = db.attendanceEntries.workerAmountFils.sum();
    final sums = await (db.selectOnly(db.attendanceEntries)
          ..addColumns([db.attendanceEntries.workerId, sum])
          ..where(db.attendanceEntries.superseded.equals(false) & db.attendanceEntries.workDate.isSmallerThanValue(from))
          ..groupBy([db.attendanceEntries.workerId]))
        .get();
    for (final r in sums) {
      earnedBefore[r.read(db.attendanceEntries.workerId)!] = r.read(sum) ?? 0;
    }
  }
  final cash = groupedBy(await (db.select(db.cashEntries)..where((c) => c.workerId.isNotNull())).get(), (c) => c.workerId);
  final parts = await _salaryParts(db);
  final lines = groupedBy(await (db.select(db.payrollLines)..where((l) => l.reversed.equals(false))).get(), (l) => l.workerId);
  final items = groupedBy(await db.select(db.payrollItems).get(), (i) => i.workerId);
  final openings = groupedBy(await (db.select(db.openingBalances)..where((b) => b.workerId.isNotNull())).get(), (b) => b.workerId);
  final members = groupedBy(await db.select(db.workerGroupMembers).get(), (g) => g.workerId);
  final contracts = groupedBy(await (db.select(db.payContracts)..orderBy([(c) => OrderingTerm.desc(c.effectiveFrom)])).get(), (c) => c.workerId);
  final trades = {for (final w in m.workers.values) ?w.trade}.toList()..sort();

  final rows = <RegisterEntry>[];
  final heads = <String, String>{};
  final feet = <String, String>{};
  final facts = <String, List<Object?>>{};
  for (final w in m.workers.values) {
    final account = <_AccountLine?>[
      for (final b in openings[w.id] ?? const <OpeningBalance>[])
        if (b.kind == 'worker_salary_owed')
          _AccountLine(b.asOfDate, b.createdAtUtc, l10n.openingHeading, brought: b.amountFils, note: b.sourceNote)
        else if (b.kind == 'worker_advance')
          _AccountLine(b.asOfDate, b.createdAtUtc, '${l10n.openingHeading}, ${l10n.kindAdvanceGiven}', given: b.amountFils, advance: b.amountFils, note: b.sourceNote),
      for (final e in entries[w.id] ?? const <AttendanceEntry>[])
        _AccountLine(
          e.workDate,
          e.createdAtUtc,
          statusLabel(l10n, AttendanceStatus.values.byName(e.attendanceStatus)),
          status: e.attendanceStatus,
          company: m.clients[e.clientId]?.name,
          site: m.sites[e.siteId]?.name,
          timeIn: _clock(e.startUtc),
          timeOut: _clock(e.endUtc),
          minutes: e.workerPayableMinutes,
          overtime: e.overtimeMinutes,
          rate: rateCell(l10n, e.attendanceStatus, e.workerBasis, e.workerRateFils),
          earned: e.workerAmountFils,
          note: [?m.groups[e.groupId]?.name, if (e.revisesEntryId != null) l10n.correctedTag, ?e.notes].join(', '),
        ),
      for (final l in (lines[w.id] ?? const <PayrollLine>[]).where((l) => l.salaryFils != 0))
        _AccountLine(monthLastDay(l.periodFrom.substring(0, 7)), l.createdAtUtc, l10n.payrollSalary, earned: l.salaryFils, note: showMonth(l.periodFrom.substring(0, 7))),
      for (final i in items[w.id] ?? const <PayrollItem>[])
        () {
          final date = monthLastDay(i.periodFrom.substring(0, 7));
          final kind = PayItemKind.values.byName(i.kind);
          final note = [showMonth(i.periodFrom.substring(0, 7)), i.reason, ?i.note].join(', ');
          return switch (kind) {
            PayItemKind.allowance => _AccountLine(date, i.createdAtUtc, l10n.payKindAllowance, earned: i.amountFils, note: note),
            PayItemKind.deduction => _AccountLine(date, i.createdAtUtc, l10n.payKindDeduction, cut: i.amountFils, note: note),
            PayItemKind.roomCharge => _AccountLine(date, i.createdAtUtc, l10n.payKindRoom, cut: i.amountFils, note: note),
            // Only a posted recovery has come off what is left. The balance counted the money when it was given.
            PayItemKind.advanceRecovery => _AccountLine(date, i.createdAtUtc, l10n.payKindRecovery, advance: i.lineId == null ? 0 : -i.amountFils, note: l10n.regRecoveryRow(formatAed(i.amountFils))),
            PayItemKind.visaRecovery => _AccountLine(date, i.createdAtUtc, l10n.payKindVisa, cut: i.amountFils, visa: -i.amountFils, note: note),
          };
        }(),
      for (final c in cash[w.id] ?? const <CashEntry>[])
        () {
          final kind = CashKind.values.byName(c.kind);
          final signed = cashLine(c).signedFils;
          final what = _withReversal(l10n, kindLabel(l10n, kind), c);
          final note = [_methodLabel(l10n, c.method), ...salaryPartLabels(parts[c.id] ?? const []), ?c.reference, ?c.receiver, ?c.note].join(', ');
          return switch (kind) {
            CashKind.salaryPaid => _AccountLine(c.entryDate, c.createdAtUtc, what, paid: signed, note: note),
            CashKind.advanceGiven => _AccountLine(c.entryDate, c.createdAtUtc, what, given: signed, advance: signed, note: note),
            CashKind.advanceReturned => _AccountLine(c.entryDate, c.createdAtUtc, what, given: -signed, advance: -signed, note: note),
            // Visa money comes off the balance as it is cut from pay, not when the company spends it.
            CashKind.visaPaid || CashKind.visaReturned => _AccountLine(
              c.entryDate,
              c.createdAtUtc,
              what,
              visa: kind == CashKind.visaPaid ? signed : -signed,
              note: [l10n.regVisaRow(formatAed(signed)), if (note.isNotEmpty) note].join(', '),
            ),
            // Rent the worker paid in cash is the room's money, not part of their wage.
            _ => null,
          };
        }(),
    ].nonNulls.toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date != 0 ? date : a.at.compareTo(b.at);
      });

    final name = '${w.name} (${w.code})';
    final groupIds = (members[w.id] ?? const <WorkerGroupMember>[]).map((g) => g.groupId).toSet();
    final tags = <String, Set<String>>{
      'worker': {w.id},
      'group': groupIds,
      'room': {?w.roomId},
      'trade': {?w.trade},
      'active': {w.active ? 'active' : 'archived'},
    };
    var left = earnedBefore[w.id] ?? 0;
    var advanceLeft = 0;
    var visaLeft = 0;
    void count(_AccountLine line) {
      left += line.change;
      advanceLeft += line.advance;
      visaLeft += line.visa;
    }

    final shownRows = <RegisterEntry>[];
    if (from != null) {
      account.where((l) => l.date.compareTo(from) < 0).forEach(count);
      if (left != 0) {
        shownRows.add(RegisterEntry([from, w.name, w.code, l10n.regBrought, null, null, null, null, null, null, null, null, null, null, null, left, null], group: name, tags: tags));
      }
    }
    for (final line in account.where((l) => _inRange(l.date, from, to))) {
      count(line);
      shownRows.add(
        RegisterEntry(
          [
            line.date,
            w.name,
            w.code,
            line.what,
            line.company,
            line.site,
            line.timeIn,
            line.timeOut,
            line.minutes,
            line.overtime,
            line.rate,
            line.earned,
            line.given,
            line.cut,
            line.paid,
            left,
            line.note,
          ],
          group: name,
          tags: {...tags, 'status': {?line.status}},
        ),
      );
    }
    if (shownRows.isEmpty) continue;
    rows.addAll(shownRows);
    final own = contracts[w.id] ?? const <PayContract>[];
    final contract = own.where((c) => c.siteId == null).firstOrNull ?? own.firstOrNull;
    final rate = contract == null ? null : rateSummary(l10n, contract.basis, contract.rateFils);
    final room = m.rooms[w.roomId]?.name;
    final groupNames = [for (final id in groupIds) ?m.groups[id]?.name].join(', ');
    heads[name] = [?w.trade, ?w.phone, ?room, if (groupNames.isNotEmpty) groupNames, ?rate].join('   ');
    feet[name] = [
      if (left > 0) l10n.regOwedToWorker(formatAed(left)) else if (left < 0) l10n.regOwedByWorker(formatAed(-left)) else l10n.regSettled,
      if (advanceLeft != 0) l10n.regOwedSplit(formatAed(left + advanceLeft), formatAed(advanceLeft)),
      if (visaLeft != 0) l10n.regVisaLeft(formatAed(visaLeft)),
    ].join('   ');
    facts[name] = [w.name, w.code, w.trade, w.phone, room, groupNames, rate];
  }

  List<RegisterRollup> rollups(List<RegisterEntry> shown) {
    final groups = groupEntries(shown);
    if (groups.length < 2) return const [];
    return [
      RegisterRollup(
        l10n.regAllWorkers,
        [
          RegisterColumn(l10n.colWorker, flex: 5),
          RegisterColumn(l10n.colCode, flex: 2),
          RegisterColumn(l10n.filterTrade),
          RegisterColumn(l10n.colPhone),
          RegisterColumn(l10n.colRoom),
          RegisterColumn(l10n.colGroup),
          RegisterColumn(l10n.colRate, flex: 4),
          RegisterColumn(l10n.colDays, kind: CellKind.number, flex: 2, total: true),
          RegisterColumn(l10n.colHours, kind: CellKind.minutes, flex: 2, total: true),
          RegisterColumn(l10n.colEarned, kind: CellKind.money, total: true),
          RegisterColumn(l10n.kindAdvanceGiven, kind: CellKind.money, total: true),
          RegisterColumn(l10n.payKindDeduction, kind: CellKind.money, total: true),
          RegisterColumn(l10n.colPaid, kind: CellKind.money, total: true),
          RegisterColumn(l10n.colBalance, kind: CellKind.money, total: true),
        ],
        [
          for (final g in groups)
            RegisterEntry([
              ...facts[g.group]!,
              g.rows.where((e) => (e.tags['status'] ?? const {}).any((s) => s != AttendanceStatus.absent.name)).length,
              columnTotal(g.rows, _wMinutes),
              columnTotal(g.rows, _wEarned),
              columnTotal(g.rows, _wGiven),
              columnTotal(g.rows, _wCut),
              columnTotal(g.rows, _wPaid),
              g.rows.last.cells[_wLeft],
            ]),
        ],
      ),
    ];
  }

  return RegisterData(
    title: l10n.regWorkers,
    titleColumn: 3,
    amountColumns: const [_wEarned, _wGiven, _wCut, _wPaid],
    bandColumns: const [_wEarned, _wPaid, _wLeft],
    groupKind: CellKind.text,
    netted: false,
    note: l10n.regWorkerNote,
    groupHeads: heads,
    groupFeet: feet,
    rollupsOf: rollups,
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colWorker, flex: 5, inPdf: false, onScreen: false),
      RegisterColumn(l10n.colCode, flex: 2, inPdf: false, onScreen: false),
      RegisterColumn(l10n.colWhat, flex: 4),
      RegisterColumn(l10n.colCompany),
      RegisterColumn(l10n.colSite),
      RegisterColumn(l10n.colIn, flex: 2),
      RegisterColumn(l10n.colOut, flex: 2),
      RegisterColumn(l10n.colHours, kind: CellKind.minutes, flex: 2, total: true),
      RegisterColumn(l10n.colOvertime, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colRate, flex: 4),
      RegisterColumn(l10n.colEarned, kind: CellKind.money, total: true, tone: CellTone.plus),
      RegisterColumn(l10n.kindAdvanceGiven, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.payKindDeduction, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.colPaid, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.colBalance, kind: CellKind.money, closing: true),
      RegisterColumn(l10n.note, flex: 4),
    ],
    filters: [
      RegisterFilter('worker', l10n.colWorker, m.workerOptions),
      RegisterFilter('group', l10n.colGroup, m.groupOptions),
      RegisterFilter('room', l10n.colRoom, m.roomOptions),
      RegisterFilter('trade', l10n.filterTrade, [for (final t in trades) (value: t, label: t)]),
      RegisterFilter('active', l10n.filterActive, [(value: 'active', label: l10n.stateActive), (value: 'archived', label: l10n.stateArchived)]),
    ],
    entries: rows,
  );
}

/// The months each salary payment settled, by payment (PAY-06).
Future<Map<String, List<SalaryAllocation>>> _salaryParts(TenantDatabase db) async {
  return groupedBy(await (db.select(db.salaryAllocations)..orderBy([(a) => OrderingTerm.asc(a.month)])).get(), (a) => a.paymentId);
}

Future<RegisterData> _cash(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final rows = (await (db.select(db.cashEntries)..orderBy([(c) => OrderingTerm.desc(c.entryDate), (c) => OrderingTerm.asc(c.createdAtUtc)])).get())
      .where((c) => _inRange(c.entryDate, from, to))
      .toList();
  final undone = undoneIds(rows);
  final parts = await _salaryParts(db);
  return RegisterData(
    title: l10n.regCash,
    titleColumn: 1,
    amountColumns: const [6, 7],
    bandColumns: const [6, 7],
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colWho, flex: 5),
      RegisterColumn(l10n.colWhat, flex: 4),
      RegisterColumn(l10n.colRoom),
      RegisterColumn(l10n.colSite),
      RegisterColumn(l10n.filterMethod, flex: 2),
      RegisterColumn(l10n.moneyIn, kind: CellKind.money, total: true, tone: CellTone.plus),
      RegisterColumn(l10n.moneyOut, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.note, flex: 4),
    ],
    filters: [
      RegisterFilter('kind', l10n.filterKind, [for (final k in CashKind.values) (value: k.name, label: kindLabel(l10n, k))]),
      RegisterFilter('worker', l10n.colWorker, m.workerOptions),
      RegisterFilter('client', l10n.colCompany, m.clientOptions),
      RegisterFilter('site', l10n.colSite, m.siteOptions),
      RegisterFilter('room', l10n.colRoom, m.roomOptions),
      RegisterFilter('method', l10n.filterMethod, [(value: 'cash', label: l10n.methodCash), (value: 'bank', label: l10n.methodBank)]),
    ],
    entries: [
      for (final c in rows)
        () {
          final kind = CashKind.values.byName(c.kind);
          final line = cashLine(c);
          return RegisterEntry(
            [
              c.entryDate,
              m.workers[c.workerId]?.name ?? m.rooms[c.roomId]?.name ?? m.clients[c.clientId]?.name ?? categoryLabel(l10n, c.category),
              [kindLabel(l10n, kind), if (c.reversesEntryId != null) l10n.reversalTag, if (undone.contains(c.id)) l10n.reversedTag].join(', '),
              m.rooms[c.roomId]?.name,
              m.sites[c.siteId]?.name,
              _methodLabel(l10n, c.method),
              isMoneyIn(kind) ? line.signedFils : null,
              isMoneyIn(kind) ? null : line.signedFils,
              [...salaryPartLabels(parts[c.id] ?? const []), ?c.reference, ?c.receiver, ?c.note].join(', '),
            ],
            group: c.entryDate,
            tags: {
              'kind': {c.kind},
              'worker': {?c.workerId},
              'client': {?c.clientId},
              'site': {?c.siteId},
              'room': {?c.roomId},
              'method': {c.method},
            },
          );
        }(),
    ],
  );
}

/// One move on a worker's advance or visa account, oldest first, so each row can show what was left after it.
class _Move {
  const _Move(this.date, this.at, this.workerId, this.type, this.what, {this.given = 0, this.back = 0, this.method, this.note});

  final String date;
  final DateTime at;
  final String workerId;
  final String type;
  final String what;
  final int given;
  final int back;
  final String? method;
  final String? note;
}

Future<Map<String, String>> _postingDates(TenantDatabase db) async => {for (final r in await db.select(db.payrollRuns).get()) r.id: r.postingDate};

RegisterData _account({
  required String title,
  required AppLocalizations l10n,
  required _Masters m,
  required List<_Move> moves,
  required List<_Option> types,
  required String? from,
  required String? to,
}) {
  moves.sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.at.compareTo(b.at);
  });
  final left = <String, int>{};
  final entries = <RegisterEntry>[];
  for (final move in moves) {
    left[move.workerId] = (left[move.workerId] ?? 0) + move.given - move.back;
    if (!_inRange(move.date, from, to)) continue;
    entries.add(
      RegisterEntry(
        [
          move.date,
          m.workers[move.workerId]?.name,
          m.workers[move.workerId]?.code,
          move.what,
          _methodLabel(l10n, move.method),
          move.given == 0 ? null : move.given,
          move.back == 0 ? null : move.back,
          left[move.workerId],
          move.note,
        ],
        group: move.date,
        tags: {
          'worker': {move.workerId},
          'type': {move.type},
        },
      ),
    );
  }
  return RegisterData(
    title: title,
    titleColumn: 1,
    amountColumns: const [5, 6],
    bandColumns: const [5, 6],
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colWorker, flex: 5),
      RegisterColumn(l10n.colCode, flex: 2),
      RegisterColumn(l10n.colWhat, flex: 4),
      RegisterColumn(l10n.filterMethod, flex: 2),
      RegisterColumn(l10n.colGiven, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colBack, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colLeft, kind: CellKind.money),
      RegisterColumn(l10n.note, flex: 4),
    ],
    filters: [RegisterFilter('worker', l10n.colWorker, m.workerOptions), RegisterFilter('type', l10n.filterKind, types)],
    entries: oldestFirst(entries),
  );
}

Future<RegisterData> _advance(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final posting = await _postingDates(db);
  final cash = await (db.select(db.cashEntries)..where((c) => c.kind.isIn([CashKind.advanceGiven.name, CashKind.advanceReturned.name]))).get();
  final lines = await (db.select(db.payrollLines)..where((l) => l.reversed.equals(false) & l.recoveryFils.isBiggerThanValue(0))).get();
  final openings = await (db.select(db.openingBalances)..where((b) => b.kind.equals('worker_advance'))).get();
  return _account(
    title: l10n.regAdvance,
    l10n: l10n,
    m: m,
    from: from,
    to: to,
    types: [
      (value: 'opening', label: l10n.openingHeading),
      (value: 'given', label: l10n.kindAdvanceGiven),
      (value: 'returned', label: l10n.kindAdvanceReturned),
      (value: 'pay', label: l10n.payKindRecovery),
    ],
    moves: [
      for (final b in openings) _Move(b.asOfDate, b.createdAtUtc, b.workerId!, 'opening', l10n.openingHeading, given: b.amountFils, note: b.sourceNote),
      for (final c in cash)
        if (c.kind == CashKind.advanceGiven.name)
          _Move(c.entryDate, c.createdAtUtc, c.workerId!, 'given', _withReversal(l10n, l10n.kindAdvanceGiven, c), given: cashLine(c).signedFils, method: c.method, note: c.note)
        else
          _Move(c.entryDate, c.createdAtUtc, c.workerId!, 'returned', _withReversal(l10n, l10n.kindAdvanceReturned, c), back: cashLine(c).signedFils, method: c.method, note: c.note),
      for (final l in lines)
        _Move(posting[l.runId] ?? l.periodFrom, l.createdAtUtc, l.workerId, 'pay', l10n.payKindRecovery, back: l.recoveryFils, note: showMonth(l.periodFrom.substring(0, 7))),
    ],
  );
}

Future<RegisterData> _visa(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final posting = await _postingDates(db);
  final cash = await (db.select(db.cashEntries)..where((c) => c.kind.isIn([CashKind.visaPaid.name, CashKind.visaReturned.name]))).get();
  final lines = await (db.select(db.payrollLines)..where((l) => l.reversed.equals(false) & l.visaRecoveryFils.isBiggerThanValue(0))).get();
  return _account(
    title: l10n.regVisa,
    l10n: l10n,
    m: m,
    from: from,
    to: to,
    types: [
      (value: 'given', label: l10n.kindVisaPaid),
      (value: 'returned', label: l10n.kindVisaReturned),
      (value: 'pay', label: l10n.payKindVisa),
    ],
    moves: [
      for (final c in cash)
        if (c.kind == CashKind.visaPaid.name)
          _Move(c.entryDate, c.createdAtUtc, c.workerId!, 'given', _withReversal(l10n, l10n.kindVisaPaid, c), given: cashLine(c).signedFils, method: c.method, note: c.note)
        else
          _Move(c.entryDate, c.createdAtUtc, c.workerId!, 'returned', _withReversal(l10n, l10n.kindVisaReturned, c), back: cashLine(c).signedFils, method: c.method, note: c.note),
      for (final l in lines)
        _Move(posting[l.runId] ?? l.periodFrom, l.createdAtUtc, l.workerId, 'pay', l10n.payKindVisa, back: l.visaRecoveryFils, note: showMonth(l.periodFrom.substring(0, 7))),
    ],
  );
}

String _withReversal(AppLocalizations l10n, String what, CashEntry c) => c.reversesEntryId == null ? what : '$what, ${l10n.reversalTag}';

Future<RegisterData> _rooms(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final posting = await _postingDates(db);
  final cash = await (db.select(db.cashEntries)..where((c) => c.roomId.isNotNull())).get();
  final items = await (db.select(db.payrollItems)..where((i) => i.kind.equals(PayItemKind.roomCharge.name) & i.lineId.isNotNull() & i.roomId.isNotNull())).get();
  final lines = {for (final l in await (db.select(db.payrollLines)..where((l) => l.reversed.equals(false))).get()) l.id: l};
  final rows = <({String date, DateTime at, RegisterEntry entry})>[];
  for (final c in cash) {
    if (!_inRange(c.entryDate, from, to)) continue;
    final kind = CashKind.values.byName(c.kind);
    final signed = cashLine(c).signedFils;
    rows.add((
      date: c.entryDate,
      at: c.createdAtUtc,
      entry: RegisterEntry(
        [
          c.entryDate,
          m.rooms[c.roomId]?.name,
          _withReversal(l10n, kindLabel(l10n, kind), c),
          m.workers[c.workerId]?.name,
          _methodLabel(l10n, c.method),
          isMoneyIn(kind) ? signed : null,
          isMoneyIn(kind) ? null : signed,
          c.note,
        ],
        group: c.entryDate,
        tags: {
          'room': {c.roomId!},
          'worker': {?c.workerId},
          'type': {c.kind},
          'method': {c.method},
        },
      ),
    ));
  }
  for (final i in items) {
    final line = lines[i.lineId];
    if (line == null) continue;
    final date = posting[line.runId] ?? line.periodFrom;
    if (!_inRange(date, from, to)) continue;
    rows.add((
      date: date,
      at: i.createdAtUtc,
      entry: RegisterEntry(
        [date, m.rooms[i.roomId]?.name, l10n.rentFromPay, m.workers[i.workerId]?.name, null, i.amountFils, null, showMonth(line.periodFrom.substring(0, 7))],
        group: date,
        tags: {
          'room': {i.roomId!},
          'worker': {i.workerId},
          'type': {'pay'},
        },
      ),
    ));
  }
  rows.sort((a, b) {
    final date = b.date.compareTo(a.date);
    return date != 0 ? date : a.at.compareTo(b.at);
  });
  return RegisterData(
    title: l10n.regRooms,
    titleColumn: 1,
    amountColumns: const [5, 6],
    bandColumns: const [5, 6],
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colRoom, flex: 4),
      RegisterColumn(l10n.colWhat, flex: 4),
      RegisterColumn(l10n.colWorker, flex: 4),
      RegisterColumn(l10n.filterMethod, flex: 2),
      RegisterColumn(l10n.rentIn, kind: CellKind.money, total: true, tone: CellTone.plus),
      RegisterColumn(l10n.rentOut, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.note, flex: 4),
    ],
    filters: [
      RegisterFilter('room', l10n.colRoom, m.roomOptions),
      RegisterFilter('worker', l10n.colWorker, m.workerOptions),
      RegisterFilter('type', l10n.filterKind, [
        (value: CashKind.roomRentReceived.name, label: l10n.kindRoomRentReceived),
        (value: CashKind.roomRentPaid.name, label: l10n.kindRoomRentPaid),
        (value: 'pay', label: l10n.rentFromPay),
      ]),
      RegisterFilter('method', l10n.filterMethod, [(value: 'cash', label: l10n.methodCash), (value: 'bank', label: l10n.methodBank)]),
    ],
    entries: [for (final r in rows) r.entry],
  );
}

Future<RegisterData> _payroll(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final posting = await _postingDates(db);
  final lines = await (db.select(db.payrollLines)
        ..where((l) => l.reversed.equals(false))
        ..orderBy([(l) => OrderingTerm.asc(l.periodFrom)]))
      .get();
  final paidCash = await (db.select(db.cashEntries)..where((c) => c.kind.equals(CashKind.salaryPaid.name))).get();
  final fromMonth = from?.substring(0, 7);
  final toMonth = to?.substring(0, 7);
  final entries = <RegisterEntry>[];
  final paidOf = groupedBy(paidCash, (c) => c.workerId);
  // Walking newest first, so this holds what the worker's next month started from.
  final paidUntil = <String, int>{};
  for (final l in lines.reversed) {
    final month = l.periodFrom.substring(0, 7);
    // Paid derives, as on the payroll screen: everything between this posting and the worker's next one (D-033).
    final until = paidUntil[l.workerId] ?? salaryPaidTotal((paidOf[l.workerId] ?? const <CashEntry>[]).map(cashLine));
    paidUntil[l.workerId] = l.paidBeforeFils;
    if (!_inRange(month, fromMonth, toMonth)) continue;
    final paid = until - l.paidBeforeFils;
    final closing = l.payableFils - paid;
    entries.add(
      RegisterEntry(
        [
          month,
          m.workers[l.workerId]?.name,
          m.workers[l.workerId]?.code,
          l.openingFils,
          l.earnedFils,
          l.salaryFils,
          l.adjustmentFils,
          l.allowancesFils,
          l.deductionsFils,
          l.recoveryFils,
          l.visaRecoveryFils,
          l.netFils,
          l.payableFils,
          paid,
          closing,
          posting[l.runId],
        ],
        group: month,
        tags: {
          'worker': {l.workerId},
          'owed': {closing > 0 ? 'owed' : 'clear'},
        },
      ),
    );
  }
  String name(RegisterEntry e) => (e.cells[1] as String?) ?? '';
  entries.sort((a, b) {
    final month = b.group.compareTo(a.group);
    return month != 0 ? month : name(a).compareTo(name(b));
  });
  return RegisterData(
    title: l10n.regPayroll,
    titleColumn: 1,
    amountColumns: const [14],
    bandColumns: const [11, 13],
    groupKind: CellKind.month,
    note: l10n.regPayrollNote,
    columns: [
      RegisterColumn(l10n.colMonth, kind: CellKind.month, flex: 2),
      RegisterColumn(l10n.colWorker, flex: 5),
      RegisterColumn(l10n.colCode, flex: 2, inPdf: false),
      RegisterColumn(l10n.payrollOpening, kind: CellKind.money),
      RegisterColumn(l10n.payrollEarned, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payrollSalary, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payrollAdjustment, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payKindAllowance, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payKindDeduction, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payKindRecovery, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payKindVisa, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payrollNet, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payrollPayable, kind: CellKind.money),
      RegisterColumn(l10n.payrollPaid, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payrollClosing, kind: CellKind.money),
      RegisterColumn(l10n.colPostedOn, kind: CellKind.date, inPdf: false),
    ],
    filters: [
      RegisterFilter('worker', l10n.colWorker, m.workerOptions),
      RegisterFilter('owed', l10n.filterOwed, [(value: 'owed', label: l10n.owedYes), (value: 'clear', label: l10n.owedNo)]),
    ],
    entries: entries,
  );
}
