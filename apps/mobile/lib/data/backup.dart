import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tenant_database.dart';

/// The backup file (DATA-02): a zip holding `manifest.json` and `data.db`. `data.db` is the company's whole database,
/// images and letterhead included, locked with the backup password in SQLCipher 4's format: AES-256 with a key
/// stretched from the password, and a check on every page. Any SQLCipher tool opens it with that password. The
/// password is never in the file, and the phone's own key never leaves the phone (DATA-07).
const backupFormat = 1;

const backupMime = 'application/zip';

/// A reminder shows once the last backup is this many days old, as the owner chose on 2026-11-10 (D-069).
const backupEveryDays = 7;

const _locked = "PRAGMA cipher = 'sqlcipher'; PRAGMA legacy = 4;";

String _quoted(String text) => "'${text.replaceAll("'", "''")}'";

/// backup-2026-11-10-1430.zip, in UAE time.
String backupFileName(DateTime now) {
  final local = now.toUtc().add(const Duration(hours: 4));
  String two(int v) => v.toString().padLeft(2, '0');
  return 'backup-${local.year}-${two(local.month)}-${two(local.day)}-${two(local.hour)}${two(local.minute)}.zip';
}

/// What a backup says about itself, readable without the password: whose it is, from when, and its checksum.
class BackupManifest {
  const BackupManifest({required this.tenantId, required this.schemaVersion, required this.createdAtUtc, required this.sha256});

  final String tenantId;
  final int schemaVersion;
  final DateTime createdAtUtc;

  /// Of `data.db`, so a damaged file is told apart from a wrong password.
  final String sha256;

  Map<String, Object> toJson() => {
    'format': backupFormat,
    'tenantId': tenantId,
    'schemaVersion': schemaVersion,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'sha256': sha256,
  };
}

enum BackupProblem { notBackup, damaged, wrongPassword, otherCompany, newerApp }

/// A backup that cannot be used here. Nothing on the phone changed.
class BackupRefused implements Exception {
  const BackupRefused(this.problem);

  final BackupProblem problem;

  @override
  String toString() => 'BackupRefused(${problem.name})';
}

/// What a backup holds, shown before it is used.
typedef BackupSummary = ({BackupManifest manifest, String? companyName, int workers, int invoices});

extension BackupOps on TenantDatabase {
  /// The backup file's bytes, read back with [password] before they are returned, so a file that would not open is
  /// never called a backup (DATA-04). [work] holds the copy while it is made; nothing is left there.
  Future<Uint8List> backupBytes(String password, {required Directory work, DateTime? now}) async {
    final copy = File('${work.path}/backup-${newUuid()}.db');
    try {
      // The copy starts under the phone's own key, so no unlocked copy ever touches the disk.
      await customStatement('VACUUM INTO ?', [copy.path]);
      await customStatement('ATTACH DATABASE ? AS outgoing', [copy.path]);
      try {
        await customStatement("PRAGMA outgoing.cipher = 'sqlcipher'");
        await customStatement('PRAGMA outgoing.legacy = 4');
        await customStatement('PRAGMA outgoing.rekey = ${_quoted(password)}');
      } finally {
        await customStatement('DETACH DATABASE outgoing');
      }
      final data = await copy.readAsBytes();
      final manifest = BackupManifest(
        tenantId: tenantId,
        schemaVersion: schemaVersion,
        createdAtUtc: (now ?? DateTime.now()).toUtc(),
        sha256: sha256.convert(data).toString(),
      );
      final zip = Archive()
        ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())))
        ..addFile(ArchiveFile.noCompress('data.db', data.length, data));
      final bytes = ZipEncoder().encodeBytes(zip);
      await checkBackup(bytes, password, tenantId: tenantId, schemaVersion: schemaVersion, work: work);
      return bytes;
    } finally {
      if (copy.existsSync()) await copy.delete();
    }
  }
}

/// What a backup's label says, checked against its data, before any password: that it is a backup, whole, of
/// [tenantId], and from an app at [schemaVersion] or older (DATA-05). Throws [BackupRefused].
({BackupManifest manifest, Uint8List data}) readBackupLabel(Uint8List bytes, {required String tenantId, required int schemaVersion}) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes, verify: true);
  } catch (_) {
    throw const BackupRefused(BackupProblem.notBackup);
  }
  final manifestFile = zip.findFile('manifest.json');
  final dataFile = zip.findFile('data.db');
  if (manifestFile == null || dataFile == null) throw const BackupRefused(BackupProblem.notBackup);
  final BackupManifest manifest;
  try {
    final json = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    if (json['format'] != backupFormat) throw const BackupRefused(BackupProblem.newerApp);
    manifest = BackupManifest(
      tenantId: json['tenantId'] as String,
      schemaVersion: json['schemaVersion'] as int,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      sha256: json['sha256'] as String,
    );
  } on BackupRefused {
    rethrow;
  } catch (_) {
    throw const BackupRefused(BackupProblem.notBackup);
  }
  final data = dataFile.content;
  if (sha256.convert(data).toString() != manifest.sha256) throw const BackupRefused(BackupProblem.damaged);
  if (manifest.tenantId != tenantId) throw const BackupRefused(BackupProblem.otherCompany);
  if (manifest.schemaVersion > schemaVersion) throw const BackupRefused(BackupProblem.newerApp);
  return (manifest: manifest, data: data);
}

/// Opens a backup with [password] and says what it holds, or why it can't be used for [tenantId] on an app at
/// [schemaVersion] (DATA-05). It only reads.
Future<BackupSummary> checkBackup(
  Uint8List bytes,
  String password, {
  required String tenantId,
  required int schemaVersion,
  required Directory work,
}) async {
  final (:manifest, :data) = readBackupLabel(bytes, tenantId: tenantId, schemaVersion: schemaVersion);
  final file = File('${work.path}/check-${newUuid()}.db');
  try {
    await file.writeAsBytes(data, flush: true);
    final path = file.path;
    final read = await Isolate.run(() => _readLocked(path, password));
    // The file must say inside what its label says outside.
    if (read.version != manifest.schemaVersion || read.tenants.any((t) => t != manifest.tenantId)) {
      throw const BackupRefused(BackupProblem.damaged);
    }
    return (manifest: manifest, companyName: read.name, workers: read.workers, invoices: read.invoices);
  } finally {
    if (file.existsSync()) await file.delete();
  }
}

/// Puts a checked backup's data into [into], locked again with this phone's key for the company (DATA-07): the backup
/// password opens it this once and is gone from the file. [into] keeps the backup's schema until the app opens it.
Future<void> unlockBackup(Uint8List bytes, String password, File into, String hexKey) async {
  final data = ZipDecoder().decodeBytes(bytes).findFile('data.db')!.content;
  for (final part in [into, File('${into.path}-journal')]) {
    if (part.existsSync()) await part.delete();
  }
  await into.writeAsBytes(data, flush: true);
  final path = into.path;
  await Isolate.run(() {
    final db = sqlite3.open(path);
    try {
      db.execute(_locked);
      db.execute('PRAGMA key = ${_quoted(password)}');
      // The scheme is chosen before the new key, as the phone's own file uses it.
      db.execute("PRAGMA cipher = 'chacha20'");
      db.execute("PRAGMA hexrekey = '$hexKey'");
    } finally {
      db.close();
    }
  });
}

/// Runs off the main isolate: stretching the password takes a moment on a phone.
({int version, List<String> tenants, String? name, int workers, int invoices}) _readLocked(String path, String password) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    db.execute(_locked);
    db.execute('PRAGMA key = ${_quoted(password)}');
    try {
      db.select('SELECT count(*) FROM sqlite_master');
    } on SqliteException catch (e) {
      // The checksum matched, so a file that won't open was locked with another password.
      if (e.resultCode == 26) throw const BackupRefused(BackupProblem.wrongPassword);
      throw const BackupRefused(BackupProblem.damaged);
    }
    if (db.select('PRAGMA integrity_check').first.values.first != 'ok') throw const BackupRefused(BackupProblem.damaged);
    final version = db.select('PRAGMA user_version').first.values.first! as int;
    final tenants = [
      for (final row in db.select('SELECT tenant_id FROM tenant_profiles UNION SELECT tenant_id FROM workers UNION SELECT tenant_id FROM invoices'))
        row['tenant_id'] as String,
    ];
    final name = db.select('SELECT legal_name FROM tenant_profiles LIMIT 1').firstOrNull?['legal_name'] as String?;
    final workers = db.select('SELECT count(*) AS c FROM workers').first['c'] as int;
    final invoices = db.select('SELECT count(*) AS c FROM invoices WHERE number IS NOT NULL').first['c'] as int;
    return (version: version, tenants: tenants, name: name, workers: workers, invoices: invoices);
  } on SqliteException {
    throw const BackupRefused(BackupProblem.damaged);
  } finally {
    db.close();
  }
}

String backupPasswordKey(String tenantId) => 'backup_password_$tenantId';
String backupLastKey(String tenantId) => 'backup_last_$tenantId';

/// The last backup that left the app: saved where the user chose, or handed to the share sheet (DATA-04).
typedef LastBackup = ({DateTime at, bool sent});

/// What this phone keeps about one company's backups, in its encrypted store. The password is kept so later backups
/// need no typing, as the owner chose (D-069); a new phone needs it typed.
class BackupStore {
  const BackupStore(this._storage, this.tenantId);

  final FlutterSecureStorage _storage;
  final String tenantId;

  Future<String?> password() => _storage.read(key: backupPasswordKey(tenantId));

  Future<void> setPassword(String password) => _storage.write(key: backupPasswordKey(tenantId), value: password);

  Future<LastBackup?> last() async {
    final raw = await _storage.read(key: backupLastKey(tenantId));
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (at: DateTime.parse(json['at'] as String), sent: json['how'] == 'sent');
  }

  Future<void> record({required bool sent, DateTime? now}) => _storage.write(
    key: backupLastKey(tenantId),
    value: jsonEncode({'at': (now ?? DateTime.now()).toUtc().toIso8601String(), 'how': sent ? 'sent' : 'saved'}),
  );
}
