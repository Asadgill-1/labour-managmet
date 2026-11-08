import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart';

import '../../app/side_panel.dart';
import '../../data/cash.dart';
import '../../data/changes.dart';
import '../../data/invoices.dart';
import '../../data/masters.dart';
import '../../data/receipts.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_row.dart';
import '../changes/change_notes.dart';
import '../invoices/invoice_paper.dart';
import '../invoices/invoice_screen.dart' show vatCategoryLabel;
import '../invoices/invoices_screen.dart' show invoiceStatusLabel;
import '../payroll/pay_item_form_screen.dart' show payKindLabel;
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
    Section.invoiceRegister => _invoices(db, l10n, masters, from, to),
    Section.statementRegister => _statement(db, l10n, masters, from, to),
    Section.agingRegister => _aging(db, l10n, masters),
    Section.workRegister => _work(db, l10n, masters, from, to),
    Section.deletedAttendance => _deletedAttendance(db, l10n, from, to),
    Section.deletedCash => _deletedCash(db, l10n, masters, from, to),
    Section.deletedPayItems => _deletedPayItems(db, l10n, from, to),
    Section.deletedRecords => _deletedRecords(db, l10n, from, to),
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
                e.deleted.equals(false) &
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
          final note = [methodLabel(l10n, c.method), ...salaryPartLabels(parts[c.id] ?? const []), ?c.reference, ?c.receiver, ?c.note].join(', ');
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
      RegisterFilter('category', l10n.expenseCategory, [for (final c in expenseCategories) (value: c, label: categoryLabel(l10n, c))]),
      RegisterFilter('worker', l10n.colWorker, m.workerOptions),
      RegisterFilter('client', l10n.colCompany, m.clientOptions),
      RegisterFilter('site', l10n.colSite, m.siteOptions),
      RegisterFilter('room', l10n.colRoom, m.roomOptions),
      RegisterFilter('method', l10n.filterMethod, [(value: 'cash', label: l10n.methodCash), (value: 'bank', label: l10n.methodBank)]),
    ],
    // A deleted line and its reversal show on the Delete tab instead, and cancel in every total (D-056).
    entries: [
      for (final c in liveCash(rows))
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
              methodLabel(l10n, c.method),
              isMoneyIn(kind) ? line.signedFils : null,
              isMoneyIn(kind) ? null : line.signedFils,
              [...salaryPartLabels(parts[c.id] ?? const []), ?c.reference, ?c.receiver, ?c.note].join(', '),
            ],
            group: c.entryDate,
            tags: {
              'kind': {c.kind},
              'category': {?c.category},
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

/// The Dubai day a delete happened, which the Delete tab goes by.
String _deletedDay(DateTime at) => dubaiToday(at);

/// The last column of the Delete tab, blank on paper and in Excel, for whoever the owner sends it to, to say why. It
/// would only be empty on a screen.
RegisterColumn _clarification(AppLocalizations l10n) => RegisterColumn(l10n.colClarification, flex: 5, onScreen: false);

/// Attendance deleted, as it was, by the day it was deleted (D-056). A draft row went, and an approved one was deleted
/// by a correction; both keep what the row said. One deleted before the app kept that shows only when.
Future<RegisterData> _deletedAttendance(TenantDatabase db, AppLocalizations l10n, String? from, String? to) async {
  final events = await (db.select(db.auditEvents)
        ..where((a) => a.entity.equals('attendance_entries') & a.action.equals('delete'))
        ..orderBy([(a) => OrderingTerm.desc(a.atUtc)]))
      .get();
  return RegisterData(
    title: l10n.regDeletedAttendance,
    titleColumn: 2,
    amountColumns: const [8],
    note: l10n.regDeletedNote,
    columns: [
      RegisterColumn(l10n.colDeletedOn, flex: 4),
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colWorker, flex: 5),
      RegisterColumn(l10n.colCompany, flex: 4),
      RegisterColumn(l10n.colSite, flex: 4),
      RegisterColumn(l10n.filterStatus, flex: 2),
      RegisterColumn(l10n.factTime, flex: 3),
      RegisterColumn(l10n.colBill, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colPay, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colDeleteNote, flex: 5),
      _clarification(l10n),
    ],
    entries: [
      for (final e in events)
        if (_inRange(_deletedDay(e.atUtc), from, to))
          () {
            final n = ChangeNote.of(e);
            String? fact(Fact f) => n.facts[f] == null ? null : factValue(l10n, f, n.facts[f]);
            return RegisterEntry(
              [
                deletedWhen(e.atUtc),
                n.facts[Fact.date] as String?,
                fact(Fact.worker),
                fact(Fact.company),
                fact(Fact.site),
                fact(Fact.status),
                fact(Fact.time),
                n.facts[Fact.bill] as int?,
                n.facts[Fact.pay] as int?,
                n.note,
                null,
              ],
              group: _deletedDay(e.atUtc),
            );
          }(),
    ],
  );
}

/// Cash book lines deleted, as they were, by the day they were deleted (D-056). Each was cancelled by its reversal, and
/// both left the cash book. A line an edit replaced shows edited where it is, not here.
Future<RegisterData> _deletedCash(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final events = await (db.select(db.auditEvents)
        ..where((a) => a.entity.equals('cash_entries') & a.action.equals('reverse'))
        ..orderBy([(a) => OrderingTerm.desc(a.atUtc)]))
      .get();
  final byId = {for (final c in await db.select(db.cashEntries).get()) c.id: c};
  return RegisterData(
    title: l10n.regDeletedCash,
    titleColumn: 3,
    amountColumns: const [4],
    note: l10n.regDeletedNote,
    columns: [
      RegisterColumn(l10n.colDeletedOn, flex: 4),
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colKind, flex: 4),
      RegisterColumn(l10n.colWho, flex: 5),
      RegisterColumn(l10n.tsAmount, kind: CellKind.money, total: true),
      RegisterColumn(l10n.receiptMethod, flex: 2),
      RegisterColumn(l10n.note, flex: 4),
      RegisterColumn(l10n.colDeleteNote, flex: 5),
      _clarification(l10n),
    ],
    filters: [RegisterFilter('kind', l10n.filterKind, [for (final k in CashKind.values) (value: k.name, label: kindLabel(l10n, k))])],
    entries: [
      for (final e in events)
        if (e.detail == null || !e.detail!.contains('"replaced"'))
          if (byId[byId[e.recordId]?.reversesEntryId] case final c? when _inRange(_deletedDay(e.atUtc), from, to))
            RegisterEntry(
              [
                deletedWhen(e.atUtc),
                c.entryDate,
                kindLabel(l10n, CashKind.values.byName(c.kind)),
                m.workers[c.workerId]?.name ?? m.rooms[c.roomId]?.name ?? m.clients[c.clientId]?.name ?? categoryLabel(l10n, c.category),
                c.amountFils,
                methodLabel(l10n, c.method),
                [?c.reference, ?c.receiver, ?c.note].join(', '),
                (e.reason ?? '').trim().isEmpty ? null : e.reason!.trim(),
                null,
              ],
              group: _deletedDay(e.atUtc),
              tags: {
                'kind': {c.kind},
              },
            ),
    ],
  );
}

/// Allowances and deductions deleted, as they were, by the day they were deleted (D-056). One deleted before the app
/// kept that shows only when.
Future<RegisterData> _deletedPayItems(TenantDatabase db, AppLocalizations l10n, String? from, String? to) async {
  final events = await (db.select(db.auditEvents)
        ..where((a) => a.entity.equals('payroll_items') & a.action.equals('delete'))
        ..orderBy([(a) => OrderingTerm.desc(a.atUtc)]))
      .get();
  return RegisterData(
    title: l10n.regDeletedPayItems,
    titleColumn: 2,
    amountColumns: const [4],
    note: l10n.regDeletedNote,
    columns: [
      RegisterColumn(l10n.colDeletedOn, flex: 4),
      RegisterColumn(l10n.colMonth, flex: 2),
      RegisterColumn(l10n.colWorker, flex: 5),
      RegisterColumn(l10n.colKind, flex: 3),
      RegisterColumn(l10n.tsAmount, kind: CellKind.money, total: true),
      RegisterColumn(l10n.payItemReason, flex: 4),
      RegisterColumn(l10n.colDeleteNote, flex: 5),
      _clarification(l10n),
    ],
    filters: [RegisterFilter('kind', l10n.filterKind, [for (final k in PayItemKind.values) (value: k.name, label: payKindLabel(l10n, k))])],
    entries: [
      for (final e in events)
        if (_inRange(_deletedDay(e.atUtc), from, to))
          () {
            final n = ChangeNote.of(e);
            String? fact(Fact f) => n.facts[f] == null ? null : factValue(l10n, f, n.facts[f]);
            return RegisterEntry(
              [
                deletedWhen(e.atUtc),
                fact(Fact.month),
                fact(Fact.worker),
                fact(Fact.payKind),
                n.facts[Fact.amount] as int?,
                [?fact(Fact.reason), ?fact(Fact.authorizedBy), ?fact(Fact.note)].join(', '),
                n.note,
                null,
              ],
              group: _deletedDay(e.atUtc),
              tags: {
                'kind': {?n.facts[Fact.payKind] as String?},
              },
            );
          }(),
    ],
  );
}

/// What each kind of record is called on the Delete tab.
String _recordKind(AppLocalizations l10n, String table) => switch (table) {
  'workers' => l10n.colWorker,
  'clients' => l10n.colCompany,
  'sites' => l10n.colSite,
  'rooms' => l10n.colRoom,
  'worker_groups' => l10n.tabGroups,
  'pay_contracts' => l10n.payContractsHeading,
  'billing_contracts' => l10n.billingContractsHeading,
  _ => l10n.openingHeading,
};

/// Workers, companies, sites, rooms, groups, rates and opening balances deleted, each whole, by the day they were
/// deleted (D-056). Only a record no entry named could be deleted.
Future<RegisterData> _deletedRecords(TenantDatabase db, AppLocalizations l10n, String? from, String? to) async {
  final events = await (db.select(db.auditEvents)
        ..where((a) => a.entity.isIn(recordTables) & a.action.equals('delete'))
        ..orderBy([(a) => OrderingTerm.desc(a.atUtc)]))
      .get();
  return RegisterData(
    title: l10n.regDeletedRecords,
    titleColumn: 2,
    note: l10n.regDeletedNote,
    columns: [
      RegisterColumn(l10n.colDeletedOn, flex: 4),
      RegisterColumn(l10n.colKind, flex: 3),
      RegisterColumn(l10n.factName, flex: 5),
      RegisterColumn(l10n.colDetails, flex: 9),
      RegisterColumn(l10n.colDeleteNote, flex: 5),
      _clarification(l10n),
    ],
    filters: [RegisterFilter('kind', l10n.filterKind, [for (final t in recordTables) (value: t, label: _recordKind(l10n, t))])],
    entries: [
      for (final e in events)
        if (_inRange(_deletedDay(e.atUtc), from, to))
          () {
            final n = ChangeNote.of(e);
            // A record is known by its name, a rate or balance by whose it is.
            final named = [Fact.name, Fact.worker, Fact.company].where((f) => n.facts[f] != null).firstOrNull;
            return RegisterEntry(
              [
                deletedWhen(e.atUtc),
                _recordKind(l10n, e.entity),
                named == null ? null : n.facts[named] as String,
                // Whether it was archived is all a status adds once it is gone.
                factsInWords(l10n, n.facts, leaving: {?named, if (n.facts[Fact.active] == true) Fact.active}),
                n.note,
                null,
              ],
              group: _deletedDay(e.atUtc),
              tags: {
                'kind': {e.entity},
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
          methodLabel(l10n, move.method),
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

// Where each figure sits on a company's statement row.
const _sInvoiced = 4;
const _sCredited = 5;
const _sReceived = 6;
const _sLost = 7;
const _sBalance = 8;

/// One line of a company's account, in date order.
typedef _StatementLine = ({String date, DateTime at, String what, String? number, int invoiced, int credited, int received, int lost, String? note});

/// Each company's account, date by date: its balance from before the app, invoices, credit notes, receipts and what the
/// owner closed as lost, with the balance after each (INV-07). It always derives from those rows, so it reconciles with
/// what each invoice still owes less the company's unused credit (REP-08). Lines before the range are only added up.
Future<RegisterData> _statement(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final money = await db.receivables();
  final today = dubaiToday(DateTime.now());
  final issued = await (db.select(db.invoices)..where((i) => i.status.equals(InvoiceStatus.draft.name).not())).get();
  final numbers = {for (final i in issued) i.id: i.number};
  final totals = <String, int>{
    for (final i in issued)
      i.id: i.kind == 'credit' ? 0 : (money.invoices[i.id]?.totalFils ?? 0),
  };
  final lineSums = groupedBy(await (db.select(db.invoiceLines)..where((l) => l.invoiceId.isIn([for (final i in issued) if (i.kind == 'credit') i.id]))).get(), (l) => l.invoiceId);
  for (final MapEntry(:key, :value) in lineSums.entries) {
    totals[key] = value.fold(0, (total, l) => total + l.netFils + l.vatFils);
  }
  final receipts = await (db.select(db.cashEntries)..where((c) => c.kind.equals(CashKind.clientReceipt.name))).get();
  final parts = <String, List<ReceiptPart>>{for (final c in receipts.where((c) => c.reversesEntryId == null)) c.id: await db.receiptParts(c.id)};
  final openings = await (db.select(db.openingBalances)..where((b) => b.kind.equals('client_receivable'))).get();
  final lost = await (db.select(db.invoiceAllocations)..where((a) => a.paymentId.isNull())).get();

  final byClient = <String, List<_StatementLine>>{};
  void add(String clientId, _StatementLine line) => (byClient[clientId] ??= []).add(line);
  for (final b in openings) {
    add(b.clientId!, (date: b.asOfDate, at: b.createdAtUtc, what: l10n.receiptOldBalance, number: null, invoiced: b.amountFils, credited: 0, received: 0, lost: 0, note: b.sourceNote));
  }
  for (final i in issued) {
    final credit = i.kind == 'credit';
    add(i.clientId, (
      date: i.issueDate!,
      at: i.createdAtUtc,
      what: credit ? l10n.invCreditNoteLabel : l10n.invTab,
      number: i.number,
      invoiced: credit ? 0 : totals[i.id]!,
      credited: credit ? totals[i.id]! : 0,
      received: 0,
      lost: 0,
      note: credit ? [?numbers[i.creditsInvoiceId], ?i.reason].join(', ') : (i.dueDate == null ? null : l10n.invDue(showDate(i.dueDate!))),
    ));
  }
  for (final c in receipts) {
    add(c.clientId!, (
      date: c.entryDate,
      at: c.createdAtUtc,
      what: _withReversal(l10n, kindLabel(l10n, CashKind.clientReceipt), c),
      number: c.reference,
      invoiced: 0,
      credited: 0,
      received: cashLine(c).signedFils,
      lost: 0,
      note: [methodLabel(l10n, c.method), ...receiptPartLabels(l10n, parts[c.id] ?? const []), ?c.note].join(', '),
    ));
  }
  for (final a in lost) {
    add(a.clientId, (date: a.entryDate, at: a.createdAtUtc, what: a.amountFils > 0 ? l10n.invLost : l10n.regLostUndone, number: numbers[a.invoiceId], invoiced: 0, credited: 0, received: 0, lost: a.amountFils, note: a.reason));
  }

  final rows = <RegisterEntry>[];
  final feet = <String, String>{};
  final facts = <String, List<Object?>>{};
  for (final c in m.clients.values) {
    final account = (byClient[c.id] ?? const <_StatementLine>[]).toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date != 0 ? date : a.at.compareTo(b.at);
      });
    var balance = 0;
    void count(_StatementLine l) => balance += l.invoiced - l.credited - l.received - l.lost;
    final shown = <RegisterEntry>[];
    final tags = <String, Set<String>>{
      'client': {c.id},
    };
    if (from != null) {
      account.where((l) => l.date.compareTo(from) < 0).forEach(count);
      if (balance != 0) shown.add(RegisterEntry([from, c.name, l10n.regBrought, null, null, null, null, null, balance, null], group: c.name, tags: tags));
    }
    for (final l in account.where((l) => _inRange(l.date, from, to))) {
      count(l);
      shown.add(
        RegisterEntry(
          [l.date, c.name, l.what, l.number, l.invoiced == 0 ? null : l.invoiced, l.credited == 0 ? null : l.credited, l.received == 0 ? null : l.received, l.lost == 0 ? null : l.lost, balance, l.note],
          group: c.name,
          tags: tags,
        ),
      );
    }
    if (shown.isEmpty) continue;
    rows.addAll(shown);
    final overdue = money.invoices.values.where((i) => i.invoice.clientId == c.id && i.invoice.status == InvoiceStatus.issued.name && i.state(today) == PayState.overdue).fold(0, (total, i) => total + i.leftFils);
    final credit = money.creditOf(c.id);
    feet[c.name] = [
      if (balance > 0) l10n.regCompanyOwes(formatAed(balance)) else if (balance < 0) l10n.regCompanyCredit(formatAed(-balance)) else l10n.regSettled,
      if (overdue > 0) l10n.regOverdue(formatAed(overdue)),
      if (credit > 0 && balance > 0) l10n.regUnusedCredit(formatAed(credit)),
    ].join('   ');
    facts[c.name] = [c.name, c.trn];
  }

  List<RegisterRollup> rollups(List<RegisterEntry> shown) {
    final groups = groupEntries(shown);
    if (groups.length < 2) return const [];
    return [
      RegisterRollup(
        l10n.regAllCompanies,
        [
          RegisterColumn(l10n.colCompany, flex: 5),
          RegisterColumn(l10n.trn, flex: 3),
          RegisterColumn(l10n.regInvoiced, kind: CellKind.money, total: true),
          RegisterColumn(l10n.invCreditNoteLabel, kind: CellKind.money, total: true),
          RegisterColumn(l10n.invReceived, kind: CellKind.money, total: true),
          RegisterColumn(l10n.invLost, kind: CellKind.money, total: true),
          RegisterColumn(l10n.colBalance, kind: CellKind.money, total: true),
        ],
        [
          for (final g in groups)
            RegisterEntry([
              ...facts[g.group]!,
              columnTotal(g.rows, _sInvoiced),
              columnTotal(g.rows, _sCredited),
              columnTotal(g.rows, _sReceived),
              columnTotal(g.rows, _sLost),
              g.rows.last.cells[_sBalance],
            ]),
        ],
      ),
    ];
  }

  return RegisterData(
    title: l10n.regStatement,
    titleColumn: 2,
    amountColumns: const [_sInvoiced, _sCredited, _sReceived, _sLost],
    bandColumns: const [_sInvoiced, _sReceived, _sBalance],
    groupKind: CellKind.text,
    netted: false,
    note: l10n.regStatementNote,
    groupFeet: feet,
    rollupsOf: rollups,
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colCompany, flex: 5, inPdf: false, onScreen: false),
      RegisterColumn(l10n.colWhat, flex: 4),
      RegisterColumn(l10n.colNumber, flex: 3),
      RegisterColumn(l10n.regInvoiced, kind: CellKind.money, total: true, tone: CellTone.plus),
      RegisterColumn(l10n.invCreditNoteLabel, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.invReceived, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.invLost, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.colBalance, kind: CellKind.money, closing: true),
      RegisterColumn(l10n.note, flex: 5),
    ],
    filters: [RegisterFilter('client', l10n.colCompany, m.clientOptions)],
    entries: rows,
  );
}

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
          methodLabel(l10n, c.method),
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

/// Every line of every invoice and credit note issued, with each figure as it went out: the structured record a later
/// e-invoicing export starts from (D-011). A credit note counts against, so the totals net out.
Future<RegisterData> _invoices(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final issued = {
    for (final i in await (db.select(db.invoices)..where((i) => i.issueDate.isNotNull())).get())
      if (_inRange(i.issueDate!, from, to)) i.id: i,
  };
  // Newest first, and each invoice's lines in their printed order.
  final lines = (await (db.select(db.invoiceLines)..where((l) => l.invoiceId.isIn(issued.keys))).get())
    ..sort((a, b) {
      final x = issued[a.invoiceId]!;
      final y = issued[b.invoiceId]!;
      final date = y.issueDate!.compareTo(x.issueDate!);
      if (date != 0) return date;
      final made = y.createdAtUtc.compareTo(x.createdAtUtc);
      if (made != 0) return made;
      // Times are to the second, so the number keeps two papers made in one second apart.
      final number = y.number!.compareTo(x.number!);
      return number != 0 ? number : a.position - b.position;
    });
  return RegisterData(
    title: l10n.regInvoices,
    titleColumn: 2,
    amountColumns: const [16],
    bandColumns: const [12, 15, 16],
    note: l10n.regInvoiceNote,
    columns: [
      RegisterColumn(l10n.colDate, kind: CellKind.date),
      RegisterColumn(l10n.colNumber, flex: 3),
      RegisterColumn(l10n.colCompany, flex: 4),
      RegisterColumn('TRN', inPdf: false),
      RegisterColumn(l10n.colKind, inPdf: false),
      RegisterColumn(l10n.colStatus, inPdf: false),
      RegisterColumn(l10n.invPo, inPdf: false),
      RegisterColumn(l10n.colDescription, flex: 7),
      RegisterColumn(l10n.colQty, flex: 2),
      RegisterColumn(l10n.colUnit, flex: 2),
      RegisterColumn(l10n.colUnitPrice, kind: CellKind.money),
      RegisterColumn(l10n.invDiscount, kind: CellKind.money, total: true, inPdf: false),
      RegisterColumn(l10n.invNet, kind: CellKind.money, total: true),
      RegisterColumn(l10n.invVatTreatment, inPdf: false),
      RegisterColumn(l10n.colVatRate, flex: 2, inPdf: false),
      RegisterColumn(l10n.invVat, kind: CellKind.money, total: true),
      RegisterColumn(l10n.invTotal, kind: CellKind.money, total: true),
      RegisterColumn(l10n.invDueDate, kind: CellKind.date, inPdf: false),
    ],
    filters: [RegisterFilter('client', l10n.colCompany, m.clientOptions)],
    entries: [
      for (final l in lines)
        () {
          final inv = issued[l.invoiceId]!;
          final sign = inv.kind == 'credit' ? -1 : 1;
          final parties = InvoiceParties.fromJson(inv.parties!);
          return RegisterEntry(
            [
              inv.issueDate,
              inv.number,
              parties.customerName,
              parties.customerTrn,
              inv.kind == 'credit' ? l10n.invCreditNoteLabel : l10n.invTab,
              invoiceStatusLabel(l10n, inv),
              inv.poReference,
              l.description,
              quantityText(basisOf(l.basis), l.quantity),
              unitText(paperWords, basisOf(l.basis)),
              l.unitPriceFils,
              sign * l.discountFils,
              sign * l.netFils,
              inv.vatRegistered ? vatCategoryLabel(l10n, VatCategory.values.byName(inv.vatCategory)) : null,
              inv.vatRegistered ? vatPercent(inv.vatBps) : null,
              sign * l.vatFils,
              sign * (l.netFils + l.vatFils),
              inv.dueDate,
            ],
            group: inv.issueDate!,
            tags: {
              'client': {inv.clientId},
            },
          );
        }(),
    ],
  );
}

/// How late money still owed is, in the usual steps.
enum _Age { notDue, upTo30, upTo60, upTo90, over90 }

_Age _ageOf(int daysLate) => switch (daysLate) {
  <= 0 => _Age.notDue,
  <= 30 => _Age.upTo30,
  <= 60 => _Age.upTo60,
  <= 90 => _Age.upTo90,
  _ => _Age.over90,
};

String _ageLabel(AppLocalizations l10n, _Age age) => switch (age) {
  _Age.notDue => l10n.ageNotDue,
  _Age.upTo30 => l10n.ageDays('1-30'),
  _Age.upTo60 => l10n.ageDays('31-60'),
  _Age.upTo90 => l10n.ageDays('61-90'),
  _Age.over90 => l10n.ageOver90,
};

const _aLate = 6;
const _aLeft = 7;

/// What each company still owes as of today, each invoice by how late it is. Its balance from before the app counts
/// from its own date. Read from the stored rows, so it agrees with the statement (REP-01, REP-08).
Future<RegisterData> _aging(TenantDatabase db, AppLocalizations l10n, _Masters m) async {
  final today = dubaiToday(DateTime.now());
  final money = await db.receivables();
  final openingDates = {
    for (final b in await (db.select(db.openingBalances)..where((b) => b.kind.equals('client_receivable'))).get()) b.clientId!: b.asOfDate,
  };
  final rows = <RegisterEntry>[];
  final feet = <String, String>{};
  for (final c in m.clients.values) {
    final open = money.openOf(c.id);
    if (open.isEmpty) {
      // A company that only has credit left still shows, or its credit would be out of sight.
      final credit = money.creditOf(c.id);
      if (credit > 0) {
        rows.add(RegisterEntry([c.name, l10n.regUnusedCredit(formatAed(credit)), null, null, null, null, null, null], group: c.name, tags: {'client': {c.id}, 'age': <String>{}}));
      }
      continue;
    }
    for (final o in open) {
      final invoice = o.invoiceId == null ? null : money.invoices[o.invoiceId]!.invoice;
      final due = o.dueDate ?? openingDates[c.id] ?? today;
      final late = daysBetween(due, today);
      final age = _ageOf(late);
      rows.add(
        RegisterEntry(
          [c.name, o.number ?? l10n.receiptOldBalance, invoice?.issueDate ?? openingDates[c.id], due, late > 0 ? late : null, _ageLabel(l10n, age), late > 0 ? o.leftFils : null, o.leftFils],
          group: c.name,
          tags: {
            'client': {c.id},
            'age': {age.name},
          },
        ),
      );
    }
    final credit = money.creditOf(c.id);
    if (credit > 0) feet[c.name] = l10n.regUnusedCredit(formatAed(credit));
  }

  List<RegisterRollup> rollups(List<RegisterEntry> shown) => [
    RegisterRollup(
      l10n.regByAge,
      [
        RegisterColumn(l10n.colCompany, flex: 5),
        for (final age in _Age.values) RegisterColumn(_ageLabel(l10n, age), kind: CellKind.money, total: true),
        RegisterColumn(l10n.invToPay, kind: CellKind.money, total: true),
      ],
      [
        for (final g in groupEntries(shown))
          RegisterEntry([
            g.group,
            for (final age in _Age.values) columnTotal(g.rows.where((r) => r.tags['age']!.contains(age.name)), _aLeft),
            columnTotal(g.rows, _aLeft),
          ]),
      ],
    ),
  ];

  return RegisterData(
    title: l10n.regAging,
    titleColumn: 1,
    amountColumns: const [_aLeft],
    bandColumns: const [_aLate, _aLeft],
    groupKind: CellKind.text,
    dated: false,
    netted: false,
    note: l10n.regAgingNote(showDate(today)),
    groupFeet: feet,
    rollupsOf: rollups,
    summaryFirst: true,
    columns: [
      RegisterColumn(l10n.colCompany, flex: 5, inPdf: false, onScreen: false),
      RegisterColumn(l10n.colNumber, flex: 4),
      RegisterColumn(l10n.colIssued, kind: CellKind.date),
      RegisterColumn(l10n.invDueDate, kind: CellKind.date),
      RegisterColumn(l10n.colDaysLate, kind: CellKind.number, flex: 2),
      RegisterColumn(l10n.colAge, flex: 3),
      RegisterColumn(l10n.invStatusOverdue, kind: CellKind.money, total: true, tone: CellTone.minus, onScreen: false),
      RegisterColumn(l10n.invToPay, kind: CellKind.money, total: true),
    ],
    filters: [
      RegisterFilter('client', l10n.colCompany, m.clientOptions),
      RegisterFilter('age', l10n.colAge, [for (final age in _Age.values) (value: age.name, label: _ageLabel(l10n, age))]),
    ],
    entries: rows,
  );
}

const _wWorth = 5;
const _wInvoiced = 6;
const _wOpen = 7;
const _wOpenDays = 8;
const _wNoRate = 9;

/// Work each company owes for, by site and month: what it is worth at the company's rate, what an invoice already
/// charges and what is still to bill. By work date, as attendance has it (REP-01, D-048).
Future<RegisterData> _work(TenantDatabase db, AppLocalizations l10n, _Masters m, String? from, String? to) async {
  final lines = <(String, String, String), List<WorkCharge>>{};
  for (final w in await db.workCharges(from: from, to: to)) {
    (lines[(w.clientId, w.workDate.substring(0, 7), w.siteId)] ??= []).add(w);
  }
  String company(String id) => m.clients[id]?.name ?? '';
  final keys = lines.keys.toList()
    ..sort((a, b) {
      final byCompany = company(a.$1).compareTo(company(b.$1));
      if (byCompany != 0) return byCompany;
      final byMonth = a.$2.compareTo(b.$2);
      return byMonth != 0 ? byMonth : (m.sites[a.$3]?.name ?? '').compareTo(m.sites[b.$3]?.name ?? '');
    });
  int sum(Iterable<WorkCharge> rows) => rows.fold(0, (total, w) => total + w.amountFils);
  final rows = [
    for (final key in keys)
      () {
        final all = lines[key]!;
        final rated = all.where((w) => w.rated);
        final open = rated.where((w) => !w.settled);
        final noRate = all.length - rated.length;
        final invoiced = sum(rated.where((w) => w.invoiceId != null));
        return RegisterEntry(
          [
            company(key.$1),
            key.$2,
            m.sites[key.$3]?.name,
            // Every day worked counts, rated or not. Only its worth needs a rate.
            all.length,
            all.fold<int>(0, (total, w) => total + w.minutes),
            sum(rated),
            // Nothing invoiced shows nothing, so work with no rate never reads as billed.
            invoiced == 0 ? null : invoiced,
            open.isEmpty ? null : sum(open),
            open.isEmpty ? null : open.length,
            noRate == 0 ? null : noRate,
          ],
          group: company(key.$1),
          tags: {
            'client': {key.$1},
            'site': {key.$3},
            'billed': {open.isEmpty && noRate == 0 ? 'done' : 'open'},
          },
        );
      }(),
  ];

  List<RegisterRollup> rollups(List<RegisterEntry> shown) {
    final groups = groupEntries(shown);
    if (groups.length < 2) return const [];
    return [
      RegisterRollup(
        l10n.regAllCompanies,
        [
          RegisterColumn(l10n.colCompany, flex: 5),
          RegisterColumn(l10n.colWorth, kind: CellKind.money, total: true),
          RegisterColumn(l10n.regInvoiced, kind: CellKind.money, total: true),
          RegisterColumn(l10n.colNotInvoiced, kind: CellKind.money, total: true),
          RegisterColumn(l10n.colDaysNotInvoiced, kind: CellKind.number, flex: 2, total: true),
          RegisterColumn(l10n.colNoRate, kind: CellKind.number, flex: 2, total: true),
        ],
        [
          for (final g in groups)
            RegisterEntry([
              g.group,
              for (final c in const [_wWorth, _wInvoiced, _wOpen, _wOpenDays, _wNoRate]) columnTotal(g.rows, c),
            ]),
        ],
      ),
    ];
  }

  return RegisterData(
    title: l10n.regWork,
    titleColumn: 2,
    amountColumns: const [_wOpen, _wInvoiced],
    bandColumns: const [_wInvoiced, _wOpen],
    groupKind: CellKind.text,
    netted: false,
    note: l10n.regWorkNote,
    rollupsOf: rollups,
    summaryFirst: true,
    columns: [
      RegisterColumn(l10n.colCompany, flex: 5, inPdf: false, onScreen: false),
      RegisterColumn(l10n.colMonth, kind: CellKind.month),
      RegisterColumn(l10n.colSite, flex: 4),
      RegisterColumn(l10n.colDays, kind: CellKind.number, flex: 2, total: true),
      RegisterColumn(l10n.colCompanyHours, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colWorth, kind: CellKind.money, total: true),
      RegisterColumn(l10n.regInvoiced, kind: CellKind.money, total: true, tone: CellTone.plus),
      RegisterColumn(l10n.colNotInvoiced, kind: CellKind.money, total: true, tone: CellTone.minus),
      RegisterColumn(l10n.colDaysNotInvoiced, kind: CellKind.number, flex: 2, total: true),
      RegisterColumn(l10n.colNoRate, kind: CellKind.number, total: true),
    ],
    filters: [
      RegisterFilter('client', l10n.colCompany, m.clientOptions),
      RegisterFilter('site', l10n.colSite, m.siteOptions),
      RegisterFilter('billed', l10n.filterBilled, [(value: 'open', label: l10n.billedOpen), (value: 'done', label: l10n.billedDone)]),
    ],
    entries: rows,
  );
}
