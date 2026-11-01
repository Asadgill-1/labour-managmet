import 'package:domain/calc.dart';
import 'package:domain/cash.dart';

import '../../data/statement.dart';
import '../../data/tenant_database.dart';
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

/// The month the owner reads and nobody else sees: what each company brought in against what its workers earned, at
/// which rates, then how each worker's account stands. An estimate from attendance, and it says so (REP-03). Monthly
/// salaries stay outside the companies, because no way of splitting them across companies has been chosen.
Future<RegisterData> buildSalarySheet(TenantDatabase db, AppLocalizations l10n, String month) async {
  final statements = await db.statementsFor(month);
  final clients = {for (final c in await db.select(db.clients).get()) c.id: c.name};
  final sites = {for (final s in await db.select(db.sites).get()) s.id: s.name};

  final byKey = <(String, String, String, String?, int?, String?, int?), _Line>{};
  for (final s in statements) {
    for (final e in s.work) {
      if (e.attendanceStatus == AttendanceStatus.absent.name) continue;
      final line = byKey[(e.clientId, e.siteId, e.workerId, e.clientBasis, e.clientRateFils, e.workerBasis, e.workerRateFils)] ??= _Line(e.clientId, e.siteId, s, e);
      line.days++;
      line.clientMinutes += e.clientBillableMinutes;
      line.workerMinutes += e.workerPayableMinutes;
      line.bill += e.clientAmountFils ?? 0;
      line.pay += e.workerAmountFils ?? 0;
      if (e.clientRateFils == null) line.noRate++;
    }
  }
  String company(_Line l) => clients[l.clientId] ?? '';
  final lines = byKey.values.toList()
    ..sort((a, b) {
      final byCompany = company(a).compareTo(company(b));
      if (byCompany != 0) return byCompany;
      final bySite = (sites[a.siteId] ?? '').compareTo(sites[b.siteId] ?? '');
      return bySite != 0 ? bySite : a.statement.worker.name.compareTo(b.statement.worker.name);
    });

  final byCompany = <String, List<_Line>>{};
  for (final l in lines) {
    (byCompany[company(l)] ??= []).add(l);
  }
  int sum(Iterable<_Line> rows, int Function(_Line) of) => rows.fold(0, (total, l) => total + of(l));
  int people(Iterable<_Line> rows) => rows.map((l) => l.statement.worker.id).toSet().length;

  final cash = await (db.select(db.cashEntries)..where((c) => c.kind.isIn([CashKind.roomRentReceived.name, CashKind.roomRentPaid.name, CashKind.expense.name]))).get();
  final undone = {for (final c in cash) ?c.reversesEntryId};
  int cashOf(CashKind kind) => cash
      .where((c) => c.kind == kind.name && c.reversesEntryId == null && !undone.contains(c.id) && c.entryDate.substring(0, 7) == month)
      .fold(0, (total, c) => total + c.amountFils);
  int of(int Function(WorkerStatement) figure) => statements.fold(0, (total, s) => total + figure(s));

  final bill = sum(lines, (l) => l.bill);
  final wages = sum(lines, (l) => l.pay);

  final summaryRows = [
    (l10n.sheetBill, bill),
    (l10n.sheetWages, -wages),
    (l10n.sheetSalaries, -of((s) => s.salaryFils)),
    (l10n.sheetAllowances, -of((s) => s.allowanceFils)),
    (l10n.sheetCuts, of((s) => s.otherFils)),
    (l10n.sheetRoomIn, of((s) => s.roomFils) + cashOf(CashKind.roomRentReceived)),
    (l10n.sheetRoomOut, -cashOf(CashKind.roomRentPaid)),
    (l10n.sheetExpenses, -cashOf(CashKind.expense)),
  ];

  final rollups = [
    RegisterRollup(
      l10n.sheetSummary,
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
            sum(rows, (l) => l.bill),
            sum(rows, (l) => l.pay),
            sum(rows, (l) => l.bill - l.pay),
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
      for (final l in lines)
        RegisterEntry(
          [
            company(l),
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
          group: company(l),
        ),
    ],
  );
}
