import 'package:domain/cash.dart';
import 'package:drift/drift.dart';

import 'cash.dart';
import 'tenant_database.dart';

/// Visa money spent on one worker and what has come back (D-039). Always derived from the rows (REP-08).
class VisaAccount {
  const VisaAccount({required this.worker, required this.paidFils, required this.returnedFils, required this.recoveredFils});

  final Worker worker;
  final int paidFils;

  /// Handed back in cash.
  final int returnedFils;

  /// Taken through posted payroll.
  final int recoveredFils;

  int get backFils => returnedFils + recoveredFils;
  int get leftFils => paidFils - backFils;
}

extension VisaOps on TenantDatabase {
  /// Everyone with visa money on record, by name.
  Future<List<VisaAccount>> visaAccounts() async {
    final rows = await (select(cashEntries)..where((c) => c.kind.isIn([CashKind.visaPaid.name, CashKind.visaReturned.name]))).get();
    final lines = await (select(payrollLines)..where((l) => l.reversed.equals(false))).get();
    final people = await (select(workers)..orderBy([(w) => OrderingTerm.asc(w.name)])).get();
    final result = <VisaAccount>[];
    for (final worker in people) {
      final own = rows.where((c) => c.workerId == worker.id).map(cashLine).toList();
      final recovered = lines.where((l) => l.workerId == worker.id).fold(0, (total, l) => total + l.visaRecoveryFils);
      if (own.isEmpty && recovered == 0 && worker.visaInstalmentFils == null) continue;
      result.add(VisaAccount(worker: worker, paidFils: visaPaidTotal(own), returnedFils: visaReturnedTotal(own), recoveredFils: recovered));
    }
    return result;
  }

  /// Sends a fresh copy whenever anything behind the accounts changes.
  Stream<List<VisaAccount>> watchVisaAccounts() async* {
    yield await visaAccounts();
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables([cashEntries, payrollLines, workers]))) {
      yield await visaAccounts();
    }
  }
}
