import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

Future<String> addWorkerRow(TenantDatabase db, {String code = 'W001', String name = 'Ali', String? op}) {
  return db.saveRow(
    db.workers,
    id: null,
    operationId: op ?? newUuid(),
    fields: WorkersCompanion(code: Value(code), name: Value(name)),
  );
}

void main() {
  test('create stamps common columns, update bumps version, and each writes the outbox', () async {
    final db = memoryDb();
    addTearDown(db.close);

    final id = await addWorkerRow(db);
    var worker = await db.select(db.workers).getSingle();
    expect(worker.id, id);
    expect(worker.tenantId, testTenant);
    expect(worker.version, 1);

    await db.saveRow(db.workers, id: id, operationId: newUuid(), fields: const WorkersCompanion(trade: Value('Mason')));
    worker = await db.select(db.workers).getSingle();
    expect(worker.version, 2);
    expect(worker.trade, 'Mason');
    expect(worker.name, 'Ali');

    final outbox = await db.select(db.outbox).get();
    expect(outbox, hasLength(2));
    expect(outbox.map((o) => o.recordVersion), [1, 2]);
    expect(jsonDecode(outbox.last.payload)['trade'], 'Mason');
  });

  test('a double tap on save creates one row', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final op = newUuid();
    await addWorkerRow(db, op: op);
    await addWorkerRow(db, op: op, code: 'W002');
    expect(await db.select(db.workers).get(), hasLength(1));
  });

  test('a cleared optional field becomes null', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final id = await addWorkerRow(db);
    await db.saveRow(db.workers, id: id, operationId: newUuid(), fields: const WorkersCompanion(trade: Value('Mason')));
    await db.saveRow(db.workers, id: id, operationId: newUuid(), fields: const WorkersCompanion(trade: Value(null)));
    expect((await db.select(db.workers).getSingle()).trade, isNull);
  });

  test('worker code suggestion and uniqueness check', () async {
    final db = memoryDb();
    addTearDown(db.close);
    expect(await db.nextWorkerCode(), 'W001');
    final id = await addWorkerRow(db);
    expect(await db.nextWorkerCode(), 'W002');
    expect(await db.workerCodeTaken('W001'), isTrue);
    expect(await db.workerCodeTaken('W001', exceptId: id), isFalse);
  });

  testWidgets('add a worker, reject a used code, then archive without losing the record', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);
    await goTo(tester, 'Labour');
    expect(find.text('Abhi koi mazdoor nahin. Pehla mazdoor add karein.'), findsOneWidget);

    Future<void> add(String name) async {
      await tester.tap(find.text('Mazdoor add karein'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mazdoor ka naam'), name);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mazdoor ka code'), 'W001');
      await tester.tap(find.text('Save karein'));
      await settle(tester);
    }

    await add('Ali Khan');
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('W001'), findsOneWidget);

    await add('Second Ali');
    expect(find.text('Yeh code kisi aur mazdoor ka hai'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(await real(tester, () => db.select(db.workers).get()), hasLength(1));

    await tester.tap(find.text('Ali Khan'));
    await settle(tester);
    await tester.tap(find.text('Archive karein'));
    await settle(tester);
    expect(find.text('Dobara active karein'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    expect(find.text('Ali Khan'), findsNothing);
    await tester.tap(find.text('Archived dikhayein'));
    await settle(tester);
    expect(find.text('Ali Khan'), findsOneWidget);
    expect((await real(tester, () => db.select(db.workers).getSingle())).active, isFalse);
    await shutDown(tester, db);
  });

  testWidgets('add a client and a site, and a bad TRN is stopped at the field', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);
    await goTo(tester, 'Companies');

    await tester.tap(find.text('Company add karein'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Company ka naam'), 'Emaar Site Works');
    await tester.tap(find.text('Yeh company VAT registered hai'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'TRN'), '123');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('TRN mein 15 hindsay hote hain'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'TRN'), '100123456700003');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    await tester.tap(find.text('Emaar Site Works'));
    await settle(tester);

    await tester.tap(find.text('Site add karein'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Site ya project ka naam'), 'Marina Tower');
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    expect(find.text('Marina Tower'), findsOneWidget);
    final site = await real(tester, () => db.select(db.sites).getSingle());
    final client = await real(tester, () => db.select(db.clients).getSingle());
    expect(site.clientId, client.id);
    expect(client.trn, '100123456700003');
    await shutDown(tester, db);
  });
}
