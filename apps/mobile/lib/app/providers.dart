import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tenant_database.dart';

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
