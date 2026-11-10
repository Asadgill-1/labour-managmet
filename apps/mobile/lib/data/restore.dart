import 'dart:io';

import 'package:drift/drift.dart';

import 'documents.dart';
import 'invoices.dart';
import 'tenant_database.dart';

/// The data being brought in, prepared and checked beside the company's file until it takes its place (DATA-05).
File restoringFile(Directory dir, String tenantId) => File('${tenantFile(dir, tenantId).path}.restore');

/// The data a restore replaced, kept on the phone under its key so the owner can bring it back (D-070).
File keptFile(Directory dir, String tenantId) => File('${tenantFile(dir, tenantId).path}.kept');

/// Where the company's files live and the key that opens them, from where they are opened.
typedef TenantFiles = ({Directory dir, Future<String> Function(String tenantId) key});

/// What came in, for the page that says it did.
typedef Restored = ({String? companyName, int workers, int invoices});

/// What the restore screens get from the root: the company's folder and key, and the swap that brings the prepared file
/// in, closing and opening the company around it (DATA-05). [keep] sets the data there now aside.
typedef Restorer = ({Directory dir, Future<String> Function() key, Future<void> Function(Restored done, {required bool keep}) swap});

/// Each run of numbers a paper takes, by the key its table counts it under (INV-01, DOC-05).
const numberSeries = ['invoice', 'credit', 'timesheet', 'clientReceipt', 'payslip', 'paymentReceipt', 'advanceReceipt'];

/// How [series] prints before its count in [year], as INV-2026-.
String seriesPrefix(String series, int year, {required String invoicePrefix}) {
  final prefix = switch (series) {
    'invoice' => invoicePrefix,
    'credit' => creditNotePrefix,
    'timesheet' => DocKind.timesheetDaily.prefix,
    _ => DocKind.values.byName(series).prefix,
  };
  return '$prefix-$year-';
}

/// Brings [restoringFile] in as the company's file. With [keep] the file there now is copied aside first; without, an
/// older copy goes. The rename then replaces the file in one step, so a crash leaves one whole file or the other. The
/// company's file must be closed.
Future<void> swapIn(Directory dir, String tenantId, {required bool keep}) async {
  final live = tenantFile(dir, tenantId);
  final kept = keptFile(dir, tenantId);
  // ponytail: a whole copy, so the phone needs room for the data twice; rename instead if large files run short.
  if (keep && live.existsSync()) {
    // Its time says when it was set aside; some copies keep the original's.
    await (await live.copy(kept.path)).setLastModified(DateTime.now());
  } else if (kept.existsSync()) {
    await kept.delete();
  }
  // A journal the old file left would be read as the new one's.
  for (final end in ['-journal', '-wal', '-shm']) {
    final part = File('${live.path}$end');
    if (part.existsSync()) await part.delete();
  }
  await restoringFile(dir, tenantId).rename(live.path);
}

extension RestoreOps on TenantDatabase {
  /// The highest number each series has given in [year], floors included. A series with none is left out.
  Future<Map<String, int>> lastNumbers(int year) async {
    final rows = await customSelect(
      '''
      SELECT kind AS series, max(seq) AS seq FROM invoices WHERE year = ?1 GROUP BY kind
      UNION ALL SELECT 'timesheet', max(seq) FROM timesheets WHERE year = ?1
      UNION ALL SELECT kind, max(seq) FROM issued_documents WHERE year = ?1 AND kind IN ('clientReceipt', 'payslip', 'paymentReceipt', 'advanceReceipt') GROUP BY kind
      UNION ALL SELECT series, max(seq) FROM number_floors WHERE year = ?1 GROUP BY series
      ''',
      variables: [Variable.withInt(year)],
      readsFrom: {invoices, timesheets, issuedDocuments, numberFloors},
    ).get();
    final last = <String, int>{};
    for (final row in rows) {
      final seq = row.readNullable<int>('seq');
      final series = row.read<String>('series');
      if (seq != null && seq > (last[series] ?? 0)) last[series] = seq;
    }
    return last;
  }

  Future<Restored> restoredSummary() async {
    final name = (await select(tenantProfiles).getSingleOrNull())?.legalName;
    final count = countAll();
    final workers = await (selectOnly(this.workers)..addColumns([count])).map((r) => r.read(count)!).getSingle();
    final issued = selectOnly(invoices)
      ..addColumns([count])
      ..where(invoices.number.isNotNull());
    return (companyName: name, workers: workers, invoices: await issued.map((r) => r.read(count)!).getSingle());
  }

  /// Records that this file came back from [from], and sets a floor wherever a number was given in [year] that it has
  /// no record of: by the phone whose data it replaces ([phone]), or after the backup elsewhere, as the owner said
  /// ([owner]). The next number of each series then goes past every one given (DATA-06).
  Future<void> recordRestore({
    required String from,
    required int year,
    required Map<String, int> phone,
    required Map<String, int> owner,
    required String operationId,
  }) async {
    await applyOperation(
      operationId: operationId,
      entity: 'restores',
      recordId: operationId,
      version: 1,
      action: 'restore',
      change: () async {
        final own = await lastNumbers(year);
        final now = DateTime.now().toUtc();
        final floors = <Map<String, Object>>[];
        for (final (source, given) in [('phone', phone), ('owner', owner)]) {
          for (final MapEntry(key: series, value: seq) in given.entries) {
            if (seq <= (own[series] ?? 0)) continue;
            await into(numberFloors).insert(
              NumberFloorsCompanion.insert(
                id: newUuid(),
                tenantId: tenantId,
                createdAtUtc: now,
                updatedAtUtc: now,
                actorId: actorId,
                sourceOperationId: operationId,
                series: series,
                year: year,
                seq: seq,
                source: source,
              ),
            );
            floors.add({'series': series, 'year': year, 'seq': seq, 'source': source});
          }
        }
        return {'from': from, 'floors': floors};
      },
    );
  }
}
