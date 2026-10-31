import 'package:domain/cash.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

const date = '2026-11-01';

Future<({String worker, String room})> seedMoney(TenantDatabase db) async {
  await seedProfile(db);
  final room = await db.saveRow(db.rooms, id: null, operationId: newUuid(), fields: const RoomsCompanion(name: Value('Sonapur 12')));
  final worker = await db.saveRow(
    db.workers,
    id: null,
    operationId: newUuid(),
    fields: WorkersCompanion(code: const Value('W001'), name: const Value('Ali Khan'), roomId: Value(room), roomChargeFils: const Value(30000)),
  );
  return (worker: worker, room: room);
}

void main() {
  group('cash book rules', () {
    late TenantDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('a retry with the same operation ID writes once (TEAM-04)', () async {
      final seed = await seedMoney(db);
      final op = newUuid();
      for (var i = 0; i < 2; i++) {
        await db.addCashEntry(operationId: op, date: date, kind: CashKind.advanceGiven, amountFils: 30000, workerId: seed.worker);
      }
      expect(await db.select(db.cashEntries).get(), hasLength(1));
    });

    test('entries cannot be changed or deleted, even directly (REP-08)', () async {
      final seed = await seedMoney(db);
      await db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceGiven, amountFils: 30000, workerId: seed.worker);
      await expectLater(db.customStatement('UPDATE cash_entries SET amount_fils = 1'), throwsA(anything));
      await expectLater(db.customStatement('DELETE FROM cash_entries'), throwsA(anything));
    });

    test('an entry must name who or what it belongs to, and the amount must be above zero', () async {
      await seedMoney(db);
      await expectLater(db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.salaryPaid, amountFils: 100), throwsA(anything));
      await expectLater(db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.roomRentPaid, amountFils: 100), throwsA(anything));
      await expectLater(db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.clientReceipt, amountFils: 100), throwsA(anything));
      await expectLater(db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.expense, amountFils: 0), throwsA(anything));
      expect(await db.select(db.cashEntries).get(), isEmpty);
    });

    test('a return above what is outstanding is refused, counting the opening advance (PAY-05)', () async {
      final seed = await seedMoney(db);
      await db.saveRow(
        db.openingBalances,
        id: null,
        operationId: newUuid(),
        fields: OpeningBalancesCompanion(kind: const Value('worker_advance'), workerId: Value(seed.worker), amountFils: const Value(5000), asOfDate: const Value(date), sourceNote: const Value('Old')),
      );
      await db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceGiven, amountFils: 10000, workerId: seed.worker);
      expect(await db.advanceLeft(seed.worker), 15000);
      await expectLater(
        db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceReturned, amountFils: 15001, workerId: seed.worker),
        throwsA(isA<AdvanceTooHigh>()),
      );
      await db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceReturned, amountFils: 15000, workerId: seed.worker);
      expect(await db.advanceLeft(seed.worker), 0);
    });

    test('undoing keeps the original, cancels it exactly, and works only once (REP-08)', () async {
      final seed = await seedMoney(db);
      await db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceGiven, amountFils: 30000, workerId: seed.worker);
      final original = await db.select(db.cashEntries).getSingle();
      await db.reverseCashEntry(original, reason: 'Wrong worker', operationId: newUuid());

      final rows = await db.select(db.cashEntries).get();
      expect(rows, hasLength(2));
      expect(await db.advanceLeft(seed.worker), 0);
      final reversal = rows.singleWhere((r) => r.reversesEntryId != null);
      expect(reversal.note, 'Wrong worker');
      expect(reversal.entryDate, date);

      await expectLater(db.reverseCashEntry(original, reason: 'Again', operationId: newUuid()), throwsA(anything));
      await expectLater(db.reverseCashEntry(reversal, reason: 'Undo the undo', operationId: newUuid()), throwsA(anything));
      expect(await db.select(db.cashEntries).get(), hasLength(2));
    });

    test('an advance already partly returned cannot be undone until the return is', () async {
      final seed = await seedMoney(db);
      await db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceGiven, amountFils: 30000, workerId: seed.worker);
      final given = await db.select(db.cashEntries).getSingle();
      await db.addCashEntry(operationId: newUuid(), date: date, kind: CashKind.advanceReturned, amountFils: 10000, workerId: seed.worker);
      await expectLater(db.reverseCashEntry(given, reason: 'Oops', operationId: newUuid()), throwsA(isA<AdvanceTooHigh>()));
    });

    test('every write leaves an audit event and an outbox row (TEAM-04)', () async {
      final seed = await seedMoney(db);
      final op = newUuid();
      await db.addCashEntry(operationId: op, date: date, kind: CashKind.advanceGiven, amountFils: 30000, workerId: seed.worker);
      expect((await (db.select(db.auditEvents)..where((a) => a.operationId.equals(op))).getSingle()).entity, 'cash_entries');
      expect((await (db.select(db.outbox)..where((o) => o.operationId.equals(op))).getSingle()).entity, 'cash_entries');
    });
  });

  testWidgets('money written once reaches the worker and the room by itself, and can be undone', (tester) async {
    final db = memoryDb();
    late ({String worker, String room}) seed;
    await real(tester, () async => seed = await seedMoney(db));
    await pumpApp(tester, db);

    await goTo(tester, 'Rozana hisaab');
    expect(find.text('Yahan koi hisaab nahin. Paisay dene ya milne par Hisaab likhein dabayein.'), findsOneWidget);

    // Advance to a worker.
    await tester.tap(find.text('Hisaab likhein'));
    await settle(tester);
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsOneWidget);
    await tester.tap(find.text('Mazdoor'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)'), '300');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('-AED 300.00'), findsNWidgets(2), reason: 'the row, and the difference for the day');
    expect(find.textContaining('Ali Khan ke hisaab mein'), findsOneWidget);

    // Rent paid for the room. Only one room, so it fills in by itself.
    await tester.tap(find.text('Hisaab likhein'));
    await settle(tester);
    await tester.tap(find.text('Room ka kiraya diya'));
    await settle(tester);
    await tester.tap(find.text('Room'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)'), '200');
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    // Rent received from the worker starts on their room and agreed charge.
    await tester.tap(find.text('Hisaab likhein'));
    await settle(tester);
    await tester.tap(find.text('Paisay mile'));
    await settle(tester);
    await tester.tap(find.text('Mazdoor'));
    await settle(tester);
    expect(find.text('300.00'), findsOneWidget);
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    final rows = await real(tester, () => db.select(db.cashEntries).get());
    expect(rows, hasLength(3));
    final rent = rows.singleWhere((r) => r.kind == CashKind.roomRentReceived.name);
    expect(rent.roomId, seed.room);
    expect(rent.workerId, seed.worker);
    expect(rent.amountFils, 30000);

    // The worker's own screen shows it, without entering anything twice.
    await goTo(tester, 'Labour');
    await tester.tap(find.text('Ali Khan'));
    await settle(tester);
    expect(find.text('Advance baqi'), findsOneWidget);
    expect(find.text('AED 300.00'), findsNWidgets(3), reason: 'agreed room charge, advance left, and rent from this worker');
    await tester.pageBack();
    await settle(tester);

    // The room shows rent in, rent out and the difference.
    await goTo(tester, 'Rooms');
    expect(find.text('Nafa AED 100.00'), findsOneWidget, reason: 'rent received 300 minus rent paid 200');
    expect(find.text('Mila AED 300.00, diya AED 200.00'), findsOneWidget);

    // Undo needs a reason, keeps the record, and the sums follow.
    await goTo(tester, 'Rozana hisaab');
    await tester.tap(find.text('-AED 200.00').last);
    await settle(tester);
    await tester.tap(find.text('Wapas karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Wapas karne ki wajah'), 'Wrong amount');
    await tester.tap(find.text('Wapas karein'));
    await settle(tester);
    expect(await real(tester, () => db.select(db.cashEntries).get()), hasLength(4));

    await goTo(tester, 'Rooms');
    expect(find.text('Nafa AED 300.00'), findsOneWidget);
    await shutDown(tester, db);
  });
}
