import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account.dart';
import 'backup.dart';
import 'tenant_database.dart';

/// The cloud's limit for one copy, the `backups` bucket's (T20d-a). A larger copy needs a resumable upload (LATER).
const cloudCopyLimit = 52428800;

/// A copy goes by itself at most this often, as the owner chose on 2026-11-14 (D-075).
const cloudCopyEvery = Duration(days: 1);

/// After a failed try the next one by itself waits this long, so coming back to the app while offline does not make
/// the copy again each time.
const cloudRetryAfter = Duration(hours: 1);

/// The last copy this phone sent to the cloud, why the last try failed, and whether one is going now.
typedef CloudView = ({DateTime? lastAt, AccountProblem? problem, bool sending});

/// Sends the open company's backup to the cloud (D-072, D-075): when it opens and when the app comes back to the front,
/// once the last copy is a day old and the data changed since; and when the owner asks on the Backup page. A failure
/// changes nothing on the phone and is kept to be shown. Each copy carries its key sealed to the recovery key.
class CloudSender {
  CloudSender({
    required this._account,
    required this._storage,
    required this.tenantId,
    required this._db,
    required this._work,
    this._clock = DateTime.now,
    this.limit = cloudCopyLimit,
  });

  final Account _account;
  final FlutterSecureStorage _storage;
  final String tenantId;

  /// The company's open file, which a restore swaps.
  final TenantDatabase Function() _db;
  final Future<Directory> Function() _work;
  final DateTime Function() _clock;
  final int limit;
  final _loaded = Completer<void>();
  final _changes = StreamController<CloudView>.broadcast();
  DateTime? _lastAt;

  /// What the outbox looked like when the last copy was made, so an unchanged company sends nothing.
  String? _mark;
  AccountProblem? _problem;
  DateTime? _failedAt;
  Future<void>? _running;

  CloudView get view => (lastAt: _lastAt, problem: _problem, sending: _running != null);

  /// The view once the kept record is read, then each change.
  Stream<CloudView> watch() async* {
    await _loaded.future;
    yield view;
    yield* _changes.stream;
  }

  Future<void> load() async {
    final raw = await _storage.read(key: cloudCopyKey(tenantId));
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _lastAt = m['at'] == null ? null : DateTime.parse(m['at'] as String);
      _mark = m['mark'] as String?;
      _problem = AccountProblem.values.asNameMap()[m['problem']];
    }
    if (!_loaded.isCompleted) _loaded.complete();
  }

  /// Sends a copy if one is due. A question only the owner can answer, such as the other phone's copy, waits for them.
  Future<void> sendIfDue() async {
    await _loaded.future;
    if (_running != null || _problem == AccountProblem.otherPhoneCopy || _problem == AccountProblem.notOwner) return;
    final now = _clock().toUtc();
    if (_failedAt != null && now.difference(_failedAt!).abs() < cloudRetryAfter) return;
    // Either way round, so a clock set wrong once does not stop the copies for as long.
    if (_lastAt != null && now.difference(_lastAt!).abs() < cloudCopyEvery) return;
    if (!_account.hasSession || await BackupStore(_storage, tenantId).password() == null) return;
    if (await _markOf(_db()) == _mark) return;
    await _send(replace: false);
  }

  /// Sends a copy now, as the owner asked. [replace] puts it in place of the copy another phone sent.
  Future<void> sendNow({bool replace = false}) async {
    await _loaded.future;
    await (_running ?? _send(replace: replace));
  }

  /// Done once no copy is being made, so the company's file can close.
  Future<void> settled() async => _running;

  Future<void> dispose() => _changes.close();

  Future<void> _send({required bool replace}) async {
    final run = _running = _attempt(replace);
    _notify();
    try {
      await run;
    } finally {
      _running = null;
      _notify();
    }
  }

  Future<void> _attempt(bool replace) async {
    final password = await BackupStore(_storage, tenantId).password();
    // The Backup page asks for the password first.
    if (password == null) return;
    try {
      final db = _db();
      final mark = await _markOf(db);
      final bytes = await db.backupBytes(password, work: await _work(), recoveryKey: _account.recoveryKey);
      if (bytes.length > limit) throw const AccountRefused(AccountProblem.tooLarge);
      _lastAt = await _account.sendCloudCopy(tenantId, bytes, replace: replace);
      _mark = mark;
      _problem = null;
      _failedAt = null;
    } on AccountRefused catch (e) {
      _problem = e.problem;
      _failedAt = _clock().toUtc();
    } catch (_) {
      _problem = AccountProblem.failed;
      _failedAt = _clock().toUtc();
    }
    await _storage.write(key: cloudCopyKey(tenantId), value: jsonEncode({'at': _lastAt?.toIso8601String(), 'mark': _mark, 'problem': _problem?.name}));
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(view);
  }
}

/// Every change writes the outbox (TEAM-04), so its size and latest time say whether the data changed.
Future<String> _markOf(TenantDatabase db) async {
  final count = db.outbox.operationId.count();
  final latest = db.outbox.createdAtUtc.max();
  final row = await (db.selectOnly(db.outbox)..addColumns([count, latest])).getSingle();
  return '${row.read(count)}/${row.read(latest)?.toUtc().toIso8601String()}';
}
