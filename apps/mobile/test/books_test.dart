import 'package:domain/cash.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/books.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/changes.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

Future<String> addWorker(TenantDatabase db, String code, String name) =>
    db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value(code), name: Value(name)));

Future<List<({String entity, String recordId, int version})>> changeList(TenantDatabase db) async => [
  for (final c in await (db.select(db.bookChanges)..orderBy([(c) => OrderingTerm.asc(c.seq)])).get()) (entity: c.entity, recordId: c.recordId, version: c.version),
];

void main() {
  group('the change list (T22d)', () {
    late TenantDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('every book table has its three triggers', () async {
      final withCommon = {
        for (final t in db.allTables)
          if (t.columnsByName.containsKey('source_operation_id')) t.actualTableName,
      };
      expect(bookTables, withCommon);
      expect(bookTables, hasLength(30));
      final triggers = {
        for (final r in await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'book\\_%' ESCAPE '\\'").get()) r.read<String>('name'),
      };
      for (final table in bookTables) {
        expect(triggers, containsAll(['book_${table}_ins', 'book_${table}_upd', 'book_${table}_del']), reason: table);
      }
    });

    test('a save, an edit and a delete each name the record', () async {
      final id = await addWorker(db, 'W1', 'Ali');
      await db.saveRow(db.workers, id: id, operationId: newUuid(), fields: const WorkersCompanion(name: Value('Ali Khan')));
      await db.deleteRecord(db.workers, id, operationId: newUuid());
      final workers = (await changeList(db)).where((c) => c.entity == 'workers').toList();
      expect(workers.map((c) => c.recordId), [id, id, id]);
      expect(workers.map((c) => c.version), [1, 2, 3]);
      expect((await changeList(db)).every((c) => c.entity != 'audit_events' && c.entity != 'outbox'), isTrue);
    });
  });

  group('sending (T22d)', () {
    late TenantDatabase db;
    late List<List<Map<String, Object?>>> pushes;
    Object? fail;
    Future<void> Function()? during;
    var given = <int>[];

    BookSender sender({int? cloud}) => BookSender(
      storage: const FlutterSecureStorage(),
      tenantId: testTenant,
      db: () => db,
      push: (changes) async {
        if (fail case final error?) throw error;
        pushes.add(changes);
        final then = during;
        during = null;
        await then?.call();
      },
      summary: (_, month) async => {'month': month},
      cloudConsent: () async => cloud,
      giveConsent: (version) async => given.add(version),
      clock: () => DateTime.utc(2026, 11, 26, 9),
    );

    List<Map<String, Object?>> sent() => [for (final p in pushes) ...p];
    List<Map<String, Object?>> rows(String entity) => [for (final r in sent()) if (r['entity'] == entity) r];

    setUp(() {
      db = memoryDb();
      pushes = [];
      fail = null;
      during = null;
      given = [];
    });
    tearDown(() => db.close());

    /// A company that agreed, and whose records went once already, so only what follows goes.
    Future<BookSender> agreedAndSent() async {
      FlutterSecureStorage.setMockInitialValues({bookConsentKey(testTenant): '1', bookFullKey(testTenant): 'yes'});
      final books = sender();
      await books.load();
      await db.delete(db.bookChanges).go();
      return books;
    }

    test('nothing goes before consent, and agreeing tells the cloud first, then sends', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await addWorker(db, 'W1', 'Ali');
      final books = sender();
      await books.load();
      await books.send();
      expect(books.consented, isFalse);
      expect(pushes, isEmpty);
      await books.agree();
      await books.settled();
      expect(given, [consentVersion]);
      expect(rows('workers').single['data'], containsPair('name', 'Ali'));
    });

    test('a company that agreed on another phone is not asked again', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final books = sender(cloud: consentVersion);
      await books.load();
      expect(books.consented, isTrue);
      expect(await const FlutterSecureStorage().read(key: bookConsentKey(testTenant)), '$consentVersion');
    });

    test('fills every existing record once, then sends it in batches', () async {
      for (var i = 0; i < 450; i++) {
        await addWorker(db, 'W$i', 'Worker $i');
      }
      FlutterSecureStorage.setMockInitialValues({bookConsentKey(testTenant): '1'});
      final books = sender();
      await books.load();
      await books.send();
      expect(pushes.map((p) => p.length), [200, 200, 50]);
      expect(rows('workers').map((r) => r['id']).toSet(), hasLength(450));
      expect(await db.select(db.bookChanges).get(), isEmpty);
      await books.send();
      expect(pushes, hasLength(3), reason: 'nothing changed, nothing goes');
    });

    test('sends a record as it stands now, without picture bytes', () async {
      final books = await agreedAndSent();
      final id = await addWorker(db, 'W1', 'Ali');
      await db.saveRow(db.workers, id: id, operationId: newUuid(), fields: const WorkersCompanion(name: Value('Ali Khan')));
      await db.customStatement(
        'INSERT INTO document_assets (id, tenant_id, created_at_utc, updated_at_utc, actor_id, version, source_operation_id, kind, mime, width_px, height_px, bytes) '
        "VALUES ('a1', '$testTenant', 0, 0, 'a', 1, 'op', 'logo', 'image/png', 1, 1, x'89504e47')",
      );
      await books.send();
      final worker = rows('workers').single;
      expect((worker['id'], worker['version']), (id, 2));
      expect(worker['data'], containsPair('name', 'Ali Khan'));
      expect(worker['data'], containsPair('tenant_id', testTenant));
      final asset = rows('document_assets').single['data']! as Map<String, Object?>;
      expect(asset['kind'], 'logo');
      expect(asset.containsKey('bytes'), isFalse);
    });

    test('a delete goes as a mark, at the version after the last', () async {
      final books = await agreedAndSent();
      final id = await addWorker(db, 'W1', 'Ali');
      await books.send();
      await db.deleteRecord(db.workers, id, operationId: newUuid());
      await books.send();
      final last = rows('workers').last;
      expect((last['id'], last['version'], last['data']), (id, 2, null));
    });

    test('a failed push keeps the list, and the next send sends the same records', () async {
      final books = await agreedAndSent();
      final id = await addWorker(db, 'W1', 'Ali');
      fail = Exception('offline');
      await books.send();
      expect(books.view.failed, isTrue);
      expect(await db.select(db.bookChanges).get(), hasLength(1));
      fail = null;
      await books.send();
      expect(rows('workers').single['id'], id);
      expect(books.view.failed, isFalse);
      expect(books.view.lastAt, DateTime.utc(2026, 11, 26, 9));
    });

    test('changes made while sending go too', () async {
      final books = await agreedAndSent();
      await addWorker(db, 'W1', 'Ali');
      during = () => addWorker(db, 'W2', 'Babar');
      await books.send();
      expect(rows('workers').map((r) => (r['data']! as Map)['name']), ['Ali', 'Babar']);
      expect(await db.select(db.bookChanges).get(), isEmpty);
    });

    test('a restore sends everything again', () async {
      final books = await agreedAndSent();
      await addWorker(db, 'W1', 'Ali');
      await books.send();
      await books.restored();
      await books.send();
      expect(rows('workers').map((r) => r['id']).toSet(), hasLength(1));
      expect(rows('workers'), hasLength(2));
    });

    test('the months from the earliest changed day to now get a summary, once', () async {
      final books = await agreedAndSent();
      await db.addCashEntry(operationId: newUuid(), date: '2026-09-15', kind: CashKind.expense, amountFils: 700);
      await books.send();
      expect(rows('month_summary').map((r) => r['id']), ['2026-09', '2026-10', '2026-11']);
      expect(rows('month_summary').first['data'], {'month': '2026-09'});
      await addWorker(db, 'W1', 'Ali');
      await books.send();
      expect(rows('month_summary').map((r) => r['id']), ['2026-09', '2026-10', '2026-11', '2026-11'], reason: 'a change with no day of its own redoes this month only');
    });
  });
}
