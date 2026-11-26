import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:domain/dates.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tenant_database.dart';

/// The consent page's wording. Raised when the wording changes, so every company is asked again (D-081, D-084).
const consentVersion = 1;

/// The change list is read this many rows at a time, and one push carries at most this much JSON.
const bookBatch = 200;
const bookBatchBytes = 512 * 1024;

String bookConsentKey(String tenantId) => 'book_consent_$tenantId';

/// Set once every record of the company was put on the change list, after its first send or a restore.
String bookFullKey(String tenantId) => 'book_full_$tenantId';

/// The earliest month whose summary is still to go, kept until the cloud has it.
String bookMonthsKey(String tenantId) => 'book_months_$tenantId';
String bookSentKey(String tenantId) => 'book_sent_$tenantId';

/// Sends changed records to the cloud: `[{entity, id, version, data}]`, data null for a deleted record. Throws when
/// the cloud did not take them all.
typedef BookPush = Future<void> Function(List<Map<String, Object?>> changes);

/// The month's figures for the cloud, from the code that draws "Malik ki sheet".
typedef BookSummary = Future<Map<String, Object?>> Function(TenantDatabase db, String month);

/// Whether the company agreed, when its books last reached the cloud, and whether the last try failed.
typedef BookView = ({bool consented, DateTime? lastAt, bool failed});

/// Sends the open company's books to the cloud once its owner agreed (D-081 part 2, D-084): every record a change
/// touched, as it stands now, and the summary of each month those records fall in, up to this one. Runs when the app
/// opens, comes back to the front, or brings back a copy; a failure keeps the list for the next time and nothing on
/// screen waits for it. The first send, and the first after a restore, put every record on the list.
class BookSender {
  BookSender({
    required this._storage,
    required this.tenantId,
    required this._db,
    required this._push,
    required this._summary,
    required this._cloudConsent,
    required this._giveConsent,
    this._clock = DateTime.now,
  });

  final FlutterSecureStorage _storage;
  final String tenantId;
  final TenantDatabase Function() _db;
  final BookPush _push;
  final BookSummary _summary;
  final Future<int?> Function() _cloudConsent;
  final Future<void> Function(int version) _giveConsent;
  final DateTime Function() _clock;
  final _changes = StreamController<BookView>.broadcast();
  final _loaded = Completer<void>();
  var _consent = 0;
  DateTime? _lastAt;
  var _failed = false;
  Future<void>? _running;

  bool get consented => _consent >= consentVersion;

  /// The kept answer was read.
  bool get loaded => _loaded.isCompleted;

  /// Writes wait for consent, once the answer is known, so a company that agreed is never held up while it is read.
  bool get refuses => loaded && !consented;

  BookView get view => (consented: consented, lastAt: _lastAt, failed: _failed);

  /// The view once the kept answer is read, then each change.
  Stream<BookView> watch() async* {
    await _loaded.future;
    yield view;
    yield* _changes.stream;
  }

  /// Reads the answer kept on this phone. Without one, asks the cloud, for a company that agreed on another phone.
  Future<void> load() async {
    try {
      _consent = int.tryParse(await _storage.read(key: bookConsentKey(tenantId)) ?? '') ?? 0;
      final sent = await _storage.read(key: bookSentKey(tenantId));
      _lastAt = sent == null ? null : DateTime.tryParse(sent);
      if (!consented) {
        try {
          final cloud = await _cloudConsent() ?? 0;
          if (cloud >= consentVersion) await _keepConsent(cloud);
        } catch (_) {
          // Offline: the page asks, and agreeing again changes nothing.
        }
      }
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
      _notify();
    }
  }

  /// The owner agreed on the consent page. The cloud keeps the answer first; then the books go.
  Future<void> agree() async {
    await _giveConsent(consentVersion);
    await _keepConsent(consentVersion);
    _notify();
    unawaited(send());
  }

  /// Sends what the change list names, once at a time. Nothing goes without consent.
  Future<void> send() => _running ??= _sendAll().whenComplete(() => _running = null);

  /// Done once the send under way, if any, is.
  Future<void> settled() async => _running;

  /// A copy was brought back: its records may be older than the cloud's, so every record goes again.
  Future<void> restored() async {
    await _running;
    await _storage.delete(key: bookFullKey(tenantId));
  }

  Future<void> dispose() => _changes.close();

  Future<void> _keepConsent(int version) async {
    _consent = version;
    await _storage.write(key: bookConsentKey(tenantId), value: '$version');
  }

  Future<void> _sendAll() async {
    await _loaded.future;
    if (!consented) return;
    try {
      final db = _db();
      if (await _storage.read(key: bookFullKey(tenantId)) == null) {
        await _fillAll(db);
        await _storage.write(key: bookFullKey(tenantId), value: 'yes');
      }
      while (true) {
        final batch = await (db.select(db.bookChanges)
              ..orderBy([(c) => OrderingTerm.asc(c.seq)])
              ..limit(bookBatch))
            .get();
        if (batch.isEmpty) break;
        final records = await _records(db, batch);
        await _laterMonths(db, records);
        await _pushAll(records);
        await (db.delete(db.bookChanges)..where((c) => c.seq.isSmallerOrEqualValue(batch.last.seq))).go();
      }
      await _sendSummaries(db);
      _lastAt = _clock().toUtc();
      _failed = false;
      await _storage.write(key: bookSentKey(tenantId), value: _lastAt!.toIso8601String());
    } catch (_) {
      // The list stays as it was; the next open or return to the app tries again.
      _failed = true;
    }
    _notify();
  }

  /// Every record of every book table on the list once, oldest table first, in place of what the list held.
  Future<void> _fillAll(TenantDatabase db) => db.transaction(() async {
    await db.delete(db.bookChanges).go();
    for (final table in bookTables) {
      await db.customStatement(
        "INSERT INTO book_changes (tenant_id, entity, record_id, version) SELECT tenant_id, '$table', id, version FROM $table ORDER BY created_at_utc",
      );
    }
  });

  /// The records [batch] names, each as it stands now. A record no longer there goes as a mark, at the version after
  /// its last. Pictures' bytes stay on the phone (D-084).
  Future<List<Map<String, Object?>>> _records(TenantDatabase db, List<BookChange> batch) async {
    final last = <(String, String), BookChange>{for (final c in batch) (c.entity, c.recordId): c};
    final byTable = <String, List<BookChange>>{};
    for (final c in last.values) {
      if (bookTables.contains(c.entity)) (byTable[c.entity] ??= []).add(c);
    }
    final records = <Map<String, Object?>>[];
    for (final MapEntry(key: table, value: changes) in byTable.entries) {
      final rows = <String, Map<String, Object?>>{};
      for (var i = 0; i < changes.length; i += 500) {
        final ids = [for (final c in changes.sublist(i, min(i + 500, changes.length))) c.recordId];
        final found = await db
            .customSelect('SELECT * FROM $table WHERE id IN (${List.filled(ids.length, '?').join(', ')})', variables: [for (final id in ids) Variable<String>(id)])
            .get();
        for (final row in found) {
          rows[row.data['id'] as String] = {
            for (final MapEntry(:key, :value) in row.data.entries)
              if (value is! Uint8List) key: value,
          };
        }
      }
      for (final c in changes) {
        final row = rows[c.recordId];
        records.add({'entity': table, 'id': c.recordId, 'version': row == null ? c.version : row['version'] as int, 'data': row});
      }
    }
    return records;
  }

  /// Keeps the earliest month [records] fall in, no earlier than the first day of work or cash, as due for a summary.
  Future<void> _laterMonths(TenantDatabase db, List<Map<String, Object?>> records) async {
    final first = await _firstMonth(db);
    if (first == null) return;
    String? earliest;
    for (final r in records) {
      for (final value in (r['data'] as Map<String, Object?>?)?.values ?? const <Object?>[]) {
        if (value is String && _day.hasMatch(value)) {
          final month = value.substring(0, 7);
          if (earliest == null || month.compareTo(earliest) < 0) earliest = month;
        }
      }
    }
    final now = _month(_clock());
    var from = earliest ?? now;
    if (from.compareTo(first) < 0) from = first;
    if (from.compareTo(now) > 0) from = now;
    final kept = await _storage.read(key: bookMonthsKey(tenantId));
    if (kept == null || from.compareTo(kept) < 0) await _storage.write(key: bookMonthsKey(tenantId), value: from);
  }

  /// The summaries of the months due, up to this one, then nothing is due.
  Future<void> _sendSummaries(TenantDatabase db) async {
    final from = await _storage.read(key: bookMonthsKey(tenantId));
    if (from == null) return;
    final now = _month(_clock());
    final summaries = <Map<String, Object?>>[
      for (var m = from; m.compareTo(now) <= 0; m = addMonths(m, 1)) {'entity': 'month_summary', 'id': m, 'version': 1, 'data': await _summary(db, m)},
    ];
    await _pushAll(summaries);
    await _storage.delete(key: bookMonthsKey(tenantId));
  }

  /// Pushes [records] in pieces of at most [bookBatchBytes] of JSON.
  // ponytail: one record over the cloud's 500 KB holds the list; a paper for 100 workers is about 50 KB.
  Future<void> _pushAll(List<Map<String, Object?>> records) async {
    var piece = <Map<String, Object?>>[];
    var size = 0;
    for (final r in records) {
      final bytes = utf8.encode(jsonEncode(r)).length;
      if (piece.isNotEmpty && (size + bytes > bookBatchBytes || piece.length == 500)) {
        await _push(piece);
        piece = [];
        size = 0;
      }
      piece.add(r);
      size += bytes;
    }
    if (piece.isNotEmpty) await _push(piece);
  }

  Future<String?> _firstMonth(TenantDatabase db) async {
    final row = await db
        .customSelect('SELECT min(d) AS d FROM (SELECT min(work_date) AS d FROM attendance_entries UNION ALL SELECT min(entry_date) FROM cash_entries)')
        .getSingle();
    return row.data['d'] == null ? null : (row.data['d'] as String).substring(0, 7);
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(view);
  }
}

final _day = RegExp(r'^\d{4}-\d{2}(-\d{2})?$');

String _month(DateTime at) => dubaiToday(at).substring(0, 7);
