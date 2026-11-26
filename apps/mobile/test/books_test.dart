import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
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
}
