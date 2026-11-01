import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/payroll.dart';
import 'package:domain/statement.dart';
import 'package:drift/drift.dart';

import 'attendance.dart';
import 'masters.dart';
import 'tenant_database.dart';

enum StatementMoneyKind { advance, advanceReturned, room, visa, deduction, paid }

/// A month was given more than it still owes (PAY-06). Overpaying goes on the advance, never on a month.
class AllocationTooHigh implements Exception {
  const AllocationTooHigh();
}

/// One worker's finished months with wages still unpaid (PAY-08).
class WorkerWagesDue {
  const WorkerWagesDue(this.worker, this.wages);

  final Worker worker;
  final List<WageDue> wages;

  int get totalFils => wages.fold(0, (total, w) => total + w.fils);
}

/// A dated line of money on a worker's month.
class StatementMoney {
  const StatementMoney(this.date, this.kind, this.fils, {this.note});

  final String date;
  final StatementMoneyKind kind;
  final int fils;
  final String? note;
}

/// One worker's month, from the stored rows. A mistake undone in the cash book leaves no trace here, because this is
/// what the worker reads. Advance counts when given, and visa money when it is cut from pay, which is the money the
/// worker actually sees go (D-042).
class WorkerStatement {
  const WorkerStatement({
    required this.worker,
    required this.month,
    required this.openingFils,
    required this.workFils,
    required this.salaryFils,
    required this.allowanceFils,
    required this.advanceFils,
    required this.roomFils,
    required this.visaFils,
    required this.otherFils,
    required this.paidFils,
    required this.visaLeftFils,
    required this.work,
    required this.money,
    required this.unpaid,
    required this.owing,
    this.placed = const {},
  });

  final Worker worker;
  final String month;

  /// Left from earlier months.
  final int openingFils;
  final int workFils;
  final int salaryFils;
  final int allowanceFils;

  /// Given less handed back.
  final int advanceFils;
  final int roomFils;
  final int visaFils;
  final int otherFils;
  final int paidFils;

  /// Visa money still to come out of pay. It is not part of the balance until it does.
  final int visaLeftFils;

  /// This month's attendance, oldest first.
  final List<AttendanceEntry> work;
  final List<StatementMoney> money;

  /// Each month's wage still unpaid, with advance kept apart as on Tankhwah. This is what a payment can settle (PAY-06).
  final Map<String, int> unpaid;

  /// The same less any advance not yet cut, which is what the worker is really still waiting for (PAY-08).
  final Map<String, int> owing;

  /// Which payment settled what, month by month, as the account reads it now.
  final Map<String, List<StatementPayment>> placed;

  int get earnedFils => workFils + salaryFils + allowanceFils;
  int get takenFils => advanceFils + roomFils + visaFils + otherFils + paidFils;
  int get closingFils => openingFils + earnedFils - takenFils;
  bool get hasSomething => work.isNotEmpty || money.isNotEmpty || openingFils != 0 || earnedFils != 0;
}

extension StatementOps on TenantDatabase {
  /// Everyone's month, or one worker's. Older months are only added up in the database, so a year of history costs
  /// no more than a month of it (REP-08). Without [withWork], the day by day rows are left out.
  Future<List<WorkerStatement>> statementsFor(String month, {String? workerId, bool withWork = true}) async {
    final from = monthFirstDay(month);
    final to = monthLastDay(month);
    final thisMonth = dubaiToday(DateTime.now()).substring(0, 7);
    final closedThrough = await lockedThrough();

    final people = await (select(workers)
          ..where((w) => workerId == null ? const Constant(true) : w.id.equals(workerId))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();

    final monthOf = attendanceEntries.workDate.substr(1, 7);
    final earned = attendanceEntries.workerAmountFils.sum();
    final sums = await (selectOnly(attendanceEntries)
          ..addColumns([attendanceEntries.workerId, monthOf, earned])
          ..where(attendanceEntries.superseded.equals(false) & attendanceEntries.workDate.isSmallerOrEqualValue(to) & (workerId == null ? const Constant(true) : attendanceEntries.workerId.equals(workerId)))
          ..groupBy([attendanceEntries.workerId, monthOf]))
        .get();
    final sumsOf = groupedBy(sums, (r) => r.read(attendanceEntries.workerId)!);

    final rows = !withWork
        ? const <AttendanceEntry>[]
        : await (select(attendanceEntries)
              ..where((e) => e.superseded.equals(false) & e.workDate.isBetweenValues(from, to) & (workerId == null ? const Constant(true) : e.workerId.equals(workerId)))
              ..orderBy([(e) => OrderingTerm.asc(e.workDate), (e) => OrderingTerm.asc(e.createdAtUtc)]))
            .get();
    final rowsOf = groupedBy(rows, (e) => e.workerId);

    final cash = await (select(cashEntries)
          ..where((c) => workerId == null ? c.workerId.isNotNull() : c.workerId.equals(workerId))
          ..orderBy([(c) => OrderingTerm.asc(c.entryDate), (c) => OrderingTerm.asc(c.createdAtUtc)]))
        .get();
    // A mistake undone in its own month leaves no trace. One from a closed month stays there, and its reversal counts on
    // the later date it carries (REP-04).
    final dateOf = {for (final c in cash) c.id: c.entryDate};
    bool sameMonth(CashEntry reversal) => reversal.entryDate.substring(0, 7) == dateOf[reversal.reversesEntryId]?.substring(0, 7);
    final undone = {
      for (final c in cash)
        if (c.reversesEntryId != null && sameMonth(c)) c.reversesEntryId!,
    };
    final cashOf = groupedBy(cash.where((c) => c.reversesEntryId == null ? !undone.contains(c.id) : !sameMonth(c)), (c) => c.workerId);

    final allocations = await (select(salaryAllocations)..where((a) => workerId == null ? const Constant(true) : a.paymentId.isIn([for (final c in cash) c.id]))).get();
    final partsOf = <String, Map<String, int>>{};
    for (final a in allocations) {
      (partsOf[a.paymentId] ??= {})[a.month] = a.amountFils;
    }

    final items = await (select(payrollItems)
          ..where((i) => i.periodFrom.isSmallerOrEqualValue(from) & (workerId == null ? const Constant(true) : i.workerId.equals(workerId)))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAtUtc)]))
        .get();
    final itemsOf = groupedBy(items, (i) => i.workerId);

    final lines = await (select(payrollLines)
          ..where((l) => l.reversed.equals(false) & l.periodFrom.isSmallerOrEqualValue(from) & (workerId == null ? const Constant(true) : l.workerId.equals(workerId)))
          ..orderBy([(l) => OrderingTerm.asc(l.periodFrom)]))
        .get();
    final linesOf = groupedBy(lines, (l) => l.workerId);

    final openings = await (select(openingBalances)..where((b) => workerId == null ? b.workerId.isNotNull() : b.workerId.equals(workerId))).get();
    final openingsOf = groupedBy(openings, (b) => b.workerId);
    final contracts = await (select(payContracts)..where((c) => c.basis.equals(RateBasis.month.name))).get();
    final contractsOf = groupedBy(contracts, (c) => c.workerId);

    final result = <WorkerStatement>[];
    for (final worker in people) {
      final own = <String, int>{};
      void add(String m, int fils) => own[m] = (own[m] ?? 0) + fils;
      for (final r in sumsOf[worker.id] ?? const <TypedResult>[]) {
        add(r.read(monthOf)!, r.read(earned) ?? 0);
      }
      final workFils = own[month] ?? 0;

      // The account counts advance when given. Wages count it only when it is cut (PAY-05).
      final advanceAside = <String, int>{};
      void aside(String m, int fils) => advanceAside[m] = (advanceAside[m] ?? 0) + fils;

      var allowance = 0, room = 0, visa = 0, other = 0, visaCut = 0;
      final money = <StatementMoney>[];
      for (final i in itemsOf[worker.id] ?? const <PayrollItem>[]) {
        final m = i.periodFrom.substring(0, 7);
        final current = i.periodFrom == from;
        void cut(StatementMoneyKind kind, void Function() count) {
          add(m, -i.amountFils);
          if (current) {
            count();
            money.add(StatementMoney(monthLastDay(month), kind, i.amountFils, note: i.reason));
          }
        }

        switch (PayItemKind.values.byName(i.kind)) {
          case PayItemKind.allowance:
            add(m, i.amountFils);
            if (current) allowance += i.amountFils;
          case PayItemKind.roomCharge:
            cut(StatementMoneyKind.room, () => room += i.amountFils);
          case PayItemKind.deduction:
            cut(StatementMoneyKind.deduction, () => other += i.amountFils);
          case PayItemKind.visaRecovery:
            visaCut += i.amountFils;
            cut(StatementMoneyKind.visa, () => visa += i.amountFils);
          // Counted when the advance was given.
          case PayItemKind.advanceRecovery:
            aside(m, -i.amountFils);
        }
      }

      var advance = 0, visaGiven = 0;
      final payments = <StatementPayment>[];
      for (final c in cashOf[worker.id] ?? const <CashEntry>[]) {
        final m = c.entryDate.substring(0, 7);
        final current = m == month;
        final fils = c.reversesEntryId == null ? c.amountFils : -c.amountFils;
        switch (CashKind.values.byName(c.kind)) {
          case CashKind.salaryPaid:
            payments.add(StatementPayment(c.entryDate, fils, note: c.note ?? c.reference ?? c.method, parts: c.reversesEntryId == null ? partsOf[c.id] : {m: fils}, id: c.id));
          case CashKind.advanceGiven:
            if (m.compareTo(month) > 0) break;
            add(m, -fils);
            aside(m, fils);
            if (current) {
              advance += fils;
              money.add(StatementMoney(c.entryDate, StatementMoneyKind.advance, fils, note: c.note));
            }
          case CashKind.advanceReturned:
            if (m.compareTo(month) > 0) break;
            add(m, fils);
            aside(m, -fils);
            if (current) {
              advance -= fils;
              money.add(StatementMoney(c.entryDate, StatementMoneyKind.advanceReturned, -fils, note: c.note));
            }
          case CashKind.visaPaid:
            if (c.entryDate.compareTo(to) <= 0) visaGiven += fils;
          case CashKind.visaReturned:
            if (c.entryDate.compareTo(to) <= 0) visaGiven -= fils;
          // Rent the worker paid in cash is the room's money, not part of their wage.
          case CashKind.roomRentPaid || CashKind.roomRentReceived || CashKind.expense || CashKind.clientReceipt:
            break;
        }
      }

      // Money from before this app is old balance, never this month's advance or earnings (MASTER-05).
      final brought = <String, int>{};
      for (final b in openingsOf[worker.id] ?? const <OpeningBalance>[]) {
        final m = b.asOfDate.substring(0, 7);
        if (b.kind == 'worker_salary_owed') brought[m] = (brought[m] ?? 0) + b.amountFils;
        if (b.kind == 'worker_advance') {
          brought[m] = (brought[m] ?? 0) - b.amountFils;
          aside(m, b.amountFils);
        }
      }

      // A monthly salary counts once its month is posted, and until then at what posting would pay. A contract dated
      // from the hiring date must not run up years of pay nobody recorded, so it counts from the account's first activity.
      final workerLines = linesOf[worker.id] ?? const <PayrollLine>[];
      final salaries = {for (final l in workerLines) l.periodFrom.substring(0, 7): l.salaryFils};
      final monthly = worker.active ? (contractsOf[worker.id] ?? const <PayContract>[]).map(payTerms).toList() : const <RateTerms>[];
      if (monthly.isNotEmpty) {
        final lastPosted = workerLines.lastOrNull?.periodFrom.substring(0, 7);
        final firstContract = monthly.map((c) => c.effectiveFrom.substring(0, 7)).reduce((a, b) => a.compareTo(b) < 0 ? a : b);
        final activity = [...own.keys, ...brought.keys, ...payments.map((p) => p.date.substring(0, 7)), month]..sort();
        final first = firstContract.compareTo(activity.first) > 0 ? firstContract : activity.first;
        for (var m = first; m.compareTo(month) <= 0 && m.compareTo(thisMonth) <= 0; m = addMonths(m, 1)) {
          if (!salaries.containsKey(m) && (lastPosted == null || m.compareTo(lastPosted) > 0) && !isClosed(monthLastDay(m), closedThrough)) salaries[m] = periodSalary(monthly, m) ?? 0;
        }
      }
      salaries.forEach(add);

      final account = _added(own, brought);
      final wages = _added(account, advanceAside);
      final placed = placePayments(wages, payments);
      final months = monthStatements(ownByMonth: own, broughtByMonth: brought, placed: placed, through: month);
      final statement = months.where((s) => s.month == month).firstOrNull;
      money
        ..addAll([for (final p in statement?.payments ?? const <StatementPayment>[]) StatementMoney(p.date, StatementMoneyKind.paid, p.fils, note: p.note)])
        ..sort((a, b) => a.date.compareTo(b.date));

      final work = rowsOf[worker.id] ?? const <AttendanceEntry>[];
      final one = WorkerStatement(
        worker: worker,
        month: month,
        openingFils: statement?.openingFils ?? 0,
        workFils: workFils,
        salaryFils: salaries[month] ?? 0,
        allowanceFils: allowance,
        advanceFils: advance,
        roomFils: room,
        visaFils: visa,
        otherFils: other,
        paidFils: statement?.paidFils ?? 0,
        visaLeftFils: visaGiven - visaCut,
        work: work,
        money: money,
        unpaid: unpaidAfter(wages, placed, through: month),
        owing: unpaidAfter(account, placed, through: month),
        placed: placed,
      );
      if (workerId != null || one.hasSomething) result.add(one);
    }
    return result;
  }

  /// Records a salary payment and the months it settles, together (PAY-06, MODEL-07). Anything beyond [parts] goes on the
  /// worker's advance as a line of its own, so it never shows as a negative salary. A retry changes nothing (TEAM-04).
  /// ponytail: undoing the salary line leaves that advance line, which is undone by hand. Link them if owners trip on it.
  Future<void> addSalaryPayment({
    required String operationId,
    required String date,
    required String workerId,
    required int amountFils,
    required Map<String, int> parts,
    required String extraNote,
    String method = 'cash',
    String? note,
    String? reference,
    String? receiver,
  }) {
    final id = newUuid();
    return applyOperation(
      operationId: operationId,
      entity: 'cash_entries',
      recordId: id,
      version: 1,
      action: 'create',
      change: () async {
        final paid = parts.values.fold(0, (total, fils) => total + fils);
        final unpaid = (await statementsFor(date.substring(0, 7), workerId: workerId, withWork: false)).single.unpaid;
        if (paid > amountFils || parts.entries.any((p) => p.value <= 0 || p.value > (unpaid[p.key] ?? 0))) throw const AllocationTooHigh();
        final now = DateTime.now().toUtc();
        Future<CashEntry> line(String rowId, CashKind kind, int fils, String? text) => into(cashEntries).insertReturning(
          CashEntriesCompanion.insert(
            id: rowId,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            entryDate: date,
            kind: kind.name,
            amountFils: fils,
            workerId: Value(workerId),
            method: Value(method),
            note: Value(text),
            reference: Value(reference),
            receiver: Value(receiver),
          ),
        );
        final saved = <Map<String, dynamic>>[];
        if (paid > 0) {
          saved.add((await line(id, CashKind.salaryPaid, paid, note)).toJson());
          for (final part in parts.entries) {
            await into(salaryAllocations).insert(
              SalaryAllocationsCompanion.insert(
                id: newUuid(),
                tenantId: tenantId,
                createdAtUtc: now,
                updatedAtUtc: now,
                actorId: actorId,
                sourceOperationId: operationId,
                paymentId: id,
                month: part.key,
                amountFils: part.value,
              ),
            );
          }
        }
        if (amountFils > paid) saved.add((await line(paid > 0 ? newUuid() : id, CashKind.advanceGiven, amountFils - paid, extraNote)).toJson());
        return {'lines': saved, 'parts': parts};
      },
    );
  }

  /// Writes down the months an old payment settled, exactly as the account already reads it, so no figure moves (PAY-06).
  Future<void> settleOldPayment(CashEntry payment, {required String operationId}) {
    return applyOperation(
      operationId: operationId,
      entity: 'cash_entries',
      recordId: payment.id,
      version: payment.version,
      action: 'allocate',
      change: () async {
        final statement = (await statementsFor(dubaiToday(DateTime.now()).substring(0, 7), workerId: payment.workerId, withWork: false)).single;
        final parts = {
          for (final e in statement.placed.entries)
            for (final piece in e.value)
              if (piece.id == payment.id) e.key: piece.fils,
        };
        final now = DateTime.now().toUtc();
        for (final part in parts.entries) {
          await into(salaryAllocations).insert(
            SalaryAllocationsCompanion.insert(
              id: newUuid(),
              tenantId: tenantId,
              createdAtUtc: now,
              updatedAtUtc: now,
              actorId: actorId,
              sourceOperationId: operationId,
              paymentId: payment.id,
              month: part.key,
              amountFils: part.value,
            ),
          );
        }
        return {'payment': payment.id, 'parts': parts};
      },
    );
  }

  /// Everyone with wages unpaid from a finished month, longest waiting first (PAY-08).
  Future<List<WorkerWagesDue>> wagesDueNow() async {
    final today = dubaiToday(DateTime.now());
    final dueDays = (await select(tenantProfiles).getSingleOrNull())?.wageDueDays;
    final result = <WorkerWagesDue>[];
    for (final s in await statementsFor(today.substring(0, 7), withWork: false)) {
      final wages = wagesDue(s.owing, today: today, dueDays: dueDays);
      if (wages.isNotEmpty) result.add(WorkerWagesDue(s.worker, wages));
    }
    result.sort((a, b) => a.wages.first.month.compareTo(b.wages.first.month));
    return result;
  }

  /// Sends a fresh list whenever anything behind it changes.
  /// ponytail: adds up every worker on each change. Fine at 1,000 workers (see scale_test), debounce if a phone shows lag.
  Stream<List<WorkerWagesDue>> watchWagesDue() async* {
    yield await wagesDueNow();
    final changes = tableUpdates(
      TableUpdateQuery.onAllTables([attendanceEntries, payContracts, payrollItems, payrollLines, cashEntries, salaryAllocations, openingBalances, workers, tenantProfiles]),
    );
    await for (final _ in changes) {
      yield await wagesDueNow();
    }
  }
}

Map<String, int> _added(Map<String, int> a, Map<String, int> b) {
  final sum = {...a};
  b.forEach((month, fils) => sum[month] = (sum[month] ?? 0) + fils);
  return sum;
}
