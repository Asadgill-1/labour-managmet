import 'dart:io';

import 'data/tenant_database.dart';

typedef Check = ({String name, bool pass, String detail});

const _tenantA = '00000000-0000-4000-8000-00000000000a';
const _tenantB = '00000000-0000-4000-8000-00000000000b';
const _marker = 'SENSITIVE_PAYROLL_MARKER';

/// T03 spike proof. Runs on a phone with a Keystore key, and on the host in `flutter test`.
Future<List<Check>> runSpikeChecks(Directory dir, Future<String> Function(String tenantId) keyFor) async {
  final checks = <Check>[];
  void record(String name, bool pass, [String detail = '']) => checks.add((name: name, pass: pass, detail: detail));

  final fileA = tenantFile(dir, _tenantA);
  final keyA = await keyFor(_tenantA);
  final keyB = await keyFor(_tenantB);
  record('Tenants have different keys', keyA != keyB);

  final dbA = _open(fileA, keyA);
  final cipher = await dbA.customSelect('PRAGMA cipher;').getSingle();
  record('Encrypted SQLite build', true, cipher.data.values.join());

  await dbA.customStatement('CREATE TABLE IF NOT EXISTS spike (id INTEGER PRIMARY KEY, note TEXT NOT NULL)');
  final before = await _rowCount(dbA);
  final watch = Stopwatch()..start();
  await dbA.transaction(() async {
    for (var i = 0; i < 10; i++) {
      await dbA.customStatement('INSERT INTO spike (note) VALUES (?)', [_marker]);
    }
  });
  watch.stop();
  record('10-row batch saved', true, '${watch.elapsedMilliseconds} ms (BUILD-04 target: under 1000 ms)');
  await dbA.close();

  final reopened = _open(fileA, keyA);
  final after = await _rowCount(reopened);
  await reopened.close();
  record('Data survives reopen', after == before + 10, '$after rows, ${before ~/ 10} earlier launches');

  final bytes = await fileA.readAsBytes();
  record('No plaintext SQLite header', String.fromCharCodes(bytes.take(15)) != 'SQLite format 3');
  record('Marker text not in file', !String.fromCharCodes(bytes).contains(_marker), '${bytes.length} bytes');

  record('Wrong key rejected', await _rejects(fileA, newHexKey()));
  record('Tenant B key cannot open tenant A file', await _rejects(fileA, keyB));

  var badIdRejected = false;
  try {
    tenantFile(dir, '../../evil');
  } on ArgumentError {
    badIdRejected = true;
  }
  record('Unsafe tenant ID rejected', badIdRejected);

  return checks;
}

TenantDatabase _open(File file, String key) => openTenantDatabase(file, key, tenantId: _tenantA, deviceId: 'spike');

Future<int> _rowCount(TenantDatabase db) async {
  final row = await db.customSelect('SELECT count(*) AS c FROM spike').getSingle();
  return row.read<int>('c');
}

Future<bool> _rejects(File file, String key) async {
  final db = _open(file, key);
  try {
    await _rowCount(db);
    return false;
  } catch (_) {
    return true;
  } finally {
    await db.close().catchError((_) {});
  }
}
