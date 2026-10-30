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

final sitesOfClientProvider = StreamProvider.family<List<Site>, String>((ref, clientId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sites)
        ..where((s) => s.clientId.equals(clientId))
        ..orderBy([(s) => OrderingTerm.asc(s.name)]))
      .watch();
});
