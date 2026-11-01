import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/payroll.dart';
import '../data/statement.dart';
import '../data/tenant_database.dart';
import '../data/visa.dart';

/// Opened in main. Disposing this scope at logout closes the tenant's data (AUTH-04).
final dbProvider = Provider<TenantDatabase>((ref) => throw UnimplementedError('opened in main'));

final profileProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.tenantProfiles).watchSingleOrNull();
});

final clientsProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.clients)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
});

final workersProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.workers)..orderBy([(w) => OrderingTerm.asc(w.name)])).watch();
});

final allSitesProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sites)..orderBy([(s) => OrderingTerm.asc(s.name)])).watch();
});

final payContractsProvider = StreamProvider.family<List<PayContract>, String>((ref, workerId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.payContracts)
        ..where((c) => c.workerId.equals(workerId))
        ..orderBy([(c) => OrderingTerm.desc(c.effectiveFrom)]))
      .watch();
});

final billingContractsProvider = StreamProvider.family<List<BillingContract>, String>((ref, clientId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.billingContracts)
        ..where((c) => c.clientId.equals(clientId))
        ..orderBy([(c) => OrderingTerm.desc(c.effectiveFrom)]))
      .watch();
});

final roomsProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.rooms)..orderBy([(r) => OrderingTerm.asc(r.name)])).watch();
});

final cashOnDateProvider = StreamProvider.family<List<CashEntry>, String>((ref, date) {
  final db = ref.watch(dbProvider);
  return (db.select(db.cashEntries)
        ..where((c) => c.entryDate.equals(date))
        ..orderBy([(c) => OrderingTerm.desc(c.createdAtUtc)]))
      .watch();
});

/// [month] is YYYY-MM.
final cashInMonthProvider = StreamProvider.family<List<CashEntry>, String>((ref, month) {
  final db = ref.watch(dbProvider);
  return (db.select(db.cashEntries)
        ..where((c) => c.entryDate.like('$month-%'))
        ..orderBy([(c) => OrderingTerm.desc(c.entryDate), (c) => OrderingTerm.desc(c.createdAtUtc)]))
      .watch();
});

final cashOfWorkerProvider = StreamProvider.family<List<CashEntry>, String>((ref, workerId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.cashEntries)
        ..where((c) => c.workerId.equals(workerId))
        ..orderBy([(c) => OrderingTerm.desc(c.entryDate), (c) => OrderingTerm.desc(c.createdAtUtc)]))
      .watch();
});

/// [month] is YYYY-MM.
final payrollProvider = StreamProvider.family<List<WorkerPayroll>, String>((ref, month) => ref.watch(dbProvider).watchPayroll(month));

final wagesDueProvider = StreamProvider<List<WorkerWagesDue>>((ref) => ref.watch(dbProvider).watchWagesDue());

/// The months one salary payment settled (PAY-06).
final allocationsOfPaymentProvider = StreamProvider.family<List<SalaryAllocation>, String>((ref, paymentId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.salaryAllocations)
        ..where((a) => a.paymentId.equals(paymentId))
        ..orderBy([(a) => OrderingTerm.asc(a.month)]))
      .watch();
});

/// Posted months that still stand.
final linesOfWorkerProvider = StreamProvider.family<List<PayrollLine>, String>((ref, workerId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.payrollLines)..where((l) => l.workerId.equals(workerId) & l.reversed.equals(false))).watch();
});

/// Room charge taken through posted payroll in [month], which counts as rent received (D-031).
final roomChargesInMonthProvider = StreamProvider.family<List<PayrollItem>, String>((ref, month) {
  final db = ref.watch(dbProvider);
  return (db.select(db.payrollItems)..where((i) => i.periodFrom.equals('$month-01') & i.kind.equals('roomCharge') & i.lineId.isNotNull())).watch();
});

final roomChargesOfWorkerProvider = StreamProvider.family<List<PayrollItem>, String>((ref, workerId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.payrollItems)..where((i) => i.workerId.equals(workerId) & i.kind.equals('roomCharge') & i.lineId.isNotNull())).watch();
});

final visaAccountsProvider = StreamProvider<List<VisaAccount>>((ref) => ref.watch(dbProvider).watchVisaAccounts());

final workerGroupsProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.workerGroups)..orderBy([(g) => OrderingTerm.asc(g.name)])).watch();
});

final allGroupMembersProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.workerGroupMembers).watch();
});

final allPayContractsProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.payContracts)..orderBy([(c) => OrderingTerm.desc(c.effectiveFrom)])).watch();
});

final allBillingContractsProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.billingContracts)..orderBy([(c) => OrderingTerm.desc(c.effectiveFrom)])).watch();
});

final openingBalancesProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.openingBalances).watch();
});

final sitesOfClientProvider = StreamProvider.family<List<Site>, String>((ref, clientId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sites)
        ..where((s) => s.clientId.equals(clientId))
        ..orderBy([(s) => OrderingTerm.asc(s.name)]))
      .watch();
});

/// Live entries for one date. Corrected originals stay stored but drop out of this list.
final entriesOnDateProvider = StreamProvider.family<List<AttendanceEntry>, String>((ref, date) {
  final db = ref.watch(dbProvider);
  return (db.select(db.attendanceEntries)
        ..where((e) => e.workDate.equals(date) & e.superseded.equals(false))
        ..orderBy([(e) => OrderingTerm.asc(e.createdAtUtc)]))
      .watch();
});
