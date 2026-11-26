import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:drift/drift.dart' show Variable;

import '../../data/statement.dart';
import '../../data/tenant_database.dart';
import '../../data/timesheets.dart' show feeCover;
import '../../l10n/app_localizations.dart';
import 'register_defs.dart';
import 'register_model.dart';

/// One worker at one site on one pair of rates, added up over the month.
class _Line {
  _Line(this.clientId, this.siteId, this.statement, this.first);

  final String clientId;
  final String siteId;
  final WorkerStatement statement;
  final AttendanceEntry first;
  var days = 0;
  var clientMinutes = 0;
  var workerMinutes = 0;
  var bill = 0;
  var pay = 0;
  var noRate = 0;
}

/// The month's figures on "Malik ki sheet": its two summary blocks, the days worked and who worked them. The cloud gets
/// them as the month's summary, so the dashboard shows the sheet's own numbers and never works them out (T22d, D-084).
typedef OwnerMonth = ({int bill, int wages, int salaries, int allowances, int cuts, int roomIn, int roomOut, int expenses, int days, int workers, int noRate});

/// What the sheet calls "Andazan nafa, audit shuda nahin": the bill less the wages, then everything else.
int estimateOf(OwnerMonth m) => m.bill - m.wages - m.salaries - m.allowances + m.cuts + m.roomIn - m.roomOut - m.expenses;

typedef _Contract = ({String company, String basis, int rateFils, int workers, int amount});

/// The month worked out once, for the sheet and for its summary.
typedef _Month = ({List<WorkerStatement> statements, Map<String, String> clients, Map<String, String> sites, List<_Line> lines, List<_Contract> contracts, OwnerMonth figures});

/// [month]'s figures, as the owner's sheet shows them.
Future<OwnerMonth> ownerMonth(TenantDatabase db, String month) async => (await _work(db, month)).figures;

/// [month]'s summary for the cloud (T22d, D-084): the sheet's figures and its estimate, and the invoices and credit notes
/// issued in the month, net of VAT. Keys as `admin_business` adds them up.
Future<Map<String, Object?>> monthSummary(TenantDatabase db, String month) async {
  final f = await ownerMonth(db, month);
  final issued = await db.customSelect(
    "SELECT i.kind AS kind, count(DISTINCT i.id) AS n, coalesce(sum(l.net_fils), 0) AS net FROM invoices i "
    "LEFT JOIN invoice_lines l ON l.invoice_id = i.id WHERE i.status IN ('issued', 'credited') AND substr(i.issue_date, 1, 7) = ? GROUP BY i.kind",
    variables: [Variable<String>(month)],
  ).get();
  int of(String kind, String column) => issued.where((r) => r.read<String>('kind') == kind).fold(0, (total, r) => total + r.read<int>(column));
  return {
    'month': month,
    'bill': f.bill,
    'wages': f.wages,
    'salaries': f.salaries,
    'allowances': f.allowances,
    'cuts': f.cuts,
    'room_in': f.roomIn,
    'room_out': f.roomOut,
    'expenses': f.expenses,
    'estimate': estimateOf(f),
    'days': f.days,
    'workers': f.workers,
    'no_rate': f.noRate,
    'invoices': of('invoice', 'n'),
    'invoiced': of('invoice', 'net'),
    'credited': of('credit', 'net'),
  };
}

Future<_Month> _work(TenantDatabase db, String month) async {
  final statements = await db.statementsFor(month);
  // Keyed by a label unique to each company, so two companies with one name never share a group or a bill.
  final clients = companyLabels(await db.select(db.clients).get());
  final sites = {for (final s in await db.select(db.sites).get()) s.id: s.name};

  final byKey = <(String, String, String, String?, int?, String?, int?), _Line>{};
  // A monthly contract's days carry no amount, so its amount for the month is the company's bill, invoiced or not: once
  // on a fixed contract, once a worker on one per worker (D-055), at the newest rate in the month, as the invoice
  // charges it (D-080 (3)). Each rate is a line of its own under its company.
  final newest = <String, AttendanceEntry>{};
  for (final s in statements) {
    for (final e in s.work) {
      if (e.attendanceStatus == AttendanceStatus.absent.name) continue;
      if (e.clientBasis case final basis? when e.clientRateFils != null && isPeriodBasis(RateBasis.values.byName(basis))) {
        final cover = feeCover(e.clientId, basis, e.workDate, e.workerId);
        if ((newest[cover]?.workDate ?? '').compareTo(e.workDate) <= 0) newest[cover] = e;
      }
      final line = byKey[(e.clientId, e.siteId, e.workerId, e.clientBasis, e.clientRateFils, e.workerBasis, e.workerRateFils)] ??= _Line(e.clientId, e.siteId, s, e);
      line.days++;
      line.clientMinutes += e.clientBillableMinutes;
      line.workerMinutes += e.workerPayableMinutes;
      line.bill += e.clientAmountFils ?? 0;
      line.pay += e.workerAmountFils ?? 0;
      if (e.clientRateFils == null) line.noRate++;
    }
  }
  final contracts = <(String, String, int), Set<String>>{};
  for (final e in newest.values) {
    (contracts[(e.clientId, e.clientBasis!, e.clientRateFils!)] ??= {}).add(e.workerId);
  }
  String company(_Line l) => clients[l.clientId] ?? '';
  final lines = byKey.values.toList()
    ..sort((a, b) {
      final byCompany = company(a).compareTo(company(b));
      if (byCompany != 0) return byCompany;
      final bySite = (sites[a.siteId] ?? '').compareTo(sites[b.siteId] ?? '');
      return bySite != 0 ? bySite : a.statement.worker.name.compareTo(b.statement.worker.name);
    });

  int sum(Iterable<_Line> rows, int Function(_Line) of) => rows.fold(0, (total, l) => total + of(l));
  final contractLines = [
    for (final MapEntry(key: (clientId, basis, rate), value: workers) in contracts.entries)
      (
        company: clients[clientId] ?? '',
        basis: basis,
        rateFils: rate,
        workers: workers.length,
        amount: clientMonthlyCharge(RateBasis.values.byName(basis), rateFils: rate, workerCount: workers.length),
      ),
  ];

  final cash = await (db.select(db.cashEntries)..where((c) => c.kind.isIn([CashKind.roomRentReceived.name, CashKind.roomRentPaid.name, CashKind.expense.name]))).get();
  final undone = {for (final c in cash) ?c.reversesEntryId};
  int cashOf(CashKind kind) => cash
      .where((c) => c.kind == kind.name && c.reversesEntryId == null && !undone.contains(c.id) && c.entryDate.substring(0, 7) == month)
      .fold(0, (total, c) => total + c.amountFils);
  int of(int Function(WorkerStatement) figure) => statements.fold(0, (total, s) => total + figure(s));

  final figures = (
    bill: sum(lines, (l) => l.bill) + contractLines.fold<int>(0, (total, c) => total + c.amount),
    wages: sum(lines, (l) => l.pay),
    salaries: of((s) => s.salaryFils),
    allowances: of((s) => s.allowanceFils),
    cuts: of((s) => s.otherFils),
    roomIn: of((s) => s.roomFils) + cashOf(CashKind.roomRentReceived),
    roomOut: cashOf(CashKind.roomRentPaid),
    expenses: cashOf(CashKind.expense),
    days: sum(lines, (l) => l.days),
    workers: lines.map((l) => l.statement.worker.id).toSet().length,
    noRate: sum(lines, (l) => l.noRate),
  );
  return (statements: statements, clients: clients, sites: sites, lines: lines, contracts: contractLines, figures: figures);
}

/// The month the owner reads and nobody else sees: what each company brought in against what its workers earned, at
/// which rates, then how each worker's account stands. An estimate from attendance, and it says so (REP-03). A monthly
/// contract counts its amount for the month (D-055). Monthly salaries stay outside the companies, because no way of
/// splitting them across companies has been chosen.
Future<RegisterData> buildSalarySheet(TenantDatabase db, AppLocalizations l10n, String month) async {
  final (:statements, :clients, :sites, :lines, contracts: contractLines, figures: f) = await _work(db, month);
  String company(_Line l) => clients[l.clientId] ?? '';
  final byCompany = <String, List<_Line>>{};
  for (final l in lines) {
    (byCompany[company(l)] ??= []).add(l);
  }
  int sum(Iterable<_Line> rows, int Function(_Line) of) => rows.fold(0, (total, l) => total + of(l));
  int people(Iterable<_Line> rows) => rows.map((l) => l.statement.worker.id).toSet().length;
  int contractBill(String? company) => contractLines.where((c) => company == null || c.company == company).fold(0, (total, c) => total + c.amount);

  // First what the work itself left, then the estimate after everything else, kept apart as REP-03 asks. VAT is never
  // in the bill, and advances and visa money are not costs, since workers pay them back (REP-02).
  final contributionRows = [(l10n.sheetBill, f.bill), (l10n.sheetWages, -f.wages)];
  final summaryRows = [
    (l10n.sheetContribution, f.bill - f.wages),
    (l10n.sheetSalaries, -f.salaries),
    (l10n.sheetAllowances, -f.allowances),
    (l10n.sheetCuts, f.cuts),
    (l10n.sheetRoomIn, f.roomIn),
    (l10n.sheetRoomOut, -f.roomOut),
    (l10n.sheetExpenses, -f.expenses),
  ];

  final rollups = [
    RegisterRollup(
      l10n.sheetSummary,
      [RegisterColumn(l10n.colWhat, flex: 14), RegisterColumn(l10n.amountAed, kind: CellKind.money, flex: 4, total: true)],
      [
        for (final (label, fils) in contributionRows) RegisterEntry([label, fils]),
      ],
      totalLabel: l10n.sheetContribution,
    ),
    RegisterRollup(
      l10n.sheetOperating,
      [RegisterColumn(l10n.colWhat, flex: 14), RegisterColumn(l10n.amountAed, kind: CellKind.money, flex: 4, total: true)],
      [
        for (final (label, fils) in summaryRows) RegisterEntry([label, fils]),
      ],
      totalLabel: l10n.sheetEstimate,
    ),
    RegisterRollup(
      l10n.sheetByCompany,
      [
        RegisterColumn(l10n.colCompany, flex: 6),
        RegisterColumn(l10n.colWorkers, kind: CellKind.number, flex: 2),
        RegisterColumn(l10n.colDays, kind: CellKind.number, flex: 2, total: true),
        RegisterColumn(l10n.colCompanyHours, kind: CellKind.minutes, total: true),
        RegisterColumn(l10n.colBill, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colPay, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colProfit, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colNoRate, kind: CellKind.number, flex: 2, total: true),
      ],
      [
        for (final MapEntry(key: name, value: rows) in byCompany.entries)
          RegisterEntry([
            name,
            people(rows),
            sum(rows, (l) => l.days),
            sum(rows, (l) => l.clientMinutes),
            sum(rows, (l) => l.bill) + contractBill(name),
            sum(rows, (l) => l.pay),
            sum(rows, (l) => l.bill - l.pay) + contractBill(name),
            sum(rows, (l) => l.noRate),
          ]),
      ],
    ),
    RegisterRollup(
      l10n.sheetWorkers,
      [
        RegisterColumn(l10n.colWorker, flex: 5),
        RegisterColumn(l10n.colCode, flex: 2),
        RegisterColumn(l10n.slipOpening, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colEarned, kind: CellKind.money, total: true),
        RegisterColumn(l10n.slipAdvance, kind: CellKind.money, total: true),
        RegisterColumn(l10n.slipRoom, kind: CellKind.money, total: true),
        RegisterColumn(l10n.slipVisa, kind: CellKind.money, total: true),
        RegisterColumn(l10n.slipOther, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colPaid, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colBalance, kind: CellKind.money, total: true),
        RegisterColumn(l10n.colVisaLeft, kind: CellKind.money, total: true),
      ],
      [
        for (final s in statements)
          RegisterEntry([s.worker.name, s.worker.code, s.openingFils, s.earnedFils, s.advanceFils, s.roomFils, s.visaFils, s.otherFils, s.paidFils, s.closingFils, s.visaLeftFils]),
      ],
      sheet: l10n.sheetWorkers,
      afterRows: true,
    ),
  ];

  return RegisterData(
    title: l10n.sheetTitle,
    titleColumn: 2,
    groupKind: CellKind.text,
    netted: false,
    dated: false,
    note: l10n.sheetNote,
    mainSheet: l10n.sheetDetail,
    summaryFirst: true,
    rollupsOf: (_) => rollups,
    groupHeads: {
      for (final MapEntry(key: name, value: rows) in byCompany.entries) name: l10n.sheetCompanyHead(people(rows), rows.map((l) => l.siteId).toSet().length),
    },
    columns: [
      RegisterColumn(l10n.colCompany, inPdf: false),
      RegisterColumn(l10n.colSite, flex: 4),
      RegisterColumn(l10n.colWorker, flex: 5),
      RegisterColumn(l10n.colCode, flex: 2),
      RegisterColumn(l10n.colDays, kind: CellKind.number, flex: 2, total: true),
      RegisterColumn(l10n.colCompanyHours, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colCompanyRate, flex: 4),
      RegisterColumn(l10n.colBill, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colWorkerHours, kind: CellKind.minutes, total: true),
      RegisterColumn(l10n.colWorkerRate, flex: 4),
      RegisterColumn(l10n.colPay, kind: CellKind.money, total: true),
      RegisterColumn(l10n.colProfit, kind: CellKind.money, total: true),
    ],
    entries: [
      for (final MapEntry(key: name, value: rows) in byCompany.entries) ...[
        for (final l in rows)
          RegisterEntry(
            [
              name,
              sites[l.siteId],
              l.statement.worker.name,
              l.statement.worker.code,
              l.days,
              l.clientMinutes,
              rateCell(l10n, l.first.attendanceStatus, l.first.clientBasis, l.first.clientRateFils),
              l.bill,
              l.workerMinutes,
              rateCell(l10n, l.first.attendanceStatus, l.first.workerBasis, l.first.workerRateFils),
              l.pay,
              l.bill - l.pay,
            ],
            group: name,
          ),
        for (final c in contractLines.where((c) => c.company == name))
          RegisterEntry(
            [
              name,
              null,
              c.basis == RateBasis.monthFixed.name ? l10n.sheetContract : '${l10n.sheetContract}, ${l10n.tsPeople(c.workers)}',
              null,
              null,
              null,
              rateCell(l10n, AttendanceStatus.present.name, c.basis, c.rateFils),
              c.amount,
              null,
              null,
              null,
              c.amount,
            ],
            group: name,
          ),
      ],
    ],
  );
}
