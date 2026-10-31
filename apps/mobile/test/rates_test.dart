import 'package:domain/calc.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

Future<String> seedWorker(TenantDatabase db) {
  return db.saveRow(
    db.workers,
    id: null,
    operationId: newUuid(),
    fields: const WorkersCompanion(code: Value('W001'), name: Value('Ali Khan')),
  );
}

Future<void> openWorker(WidgetTester tester, TenantDatabase db) async {
  await real(tester, () async {
    await seedProfile(db);
    await seedWorker(db);
  });
  await pumpApp(tester, db);
  await goTo(tester, 'Labour');
  await tester.tap(find.text('Ali Khan'));
  await settle(tester);
}

void main() {
  test('overlap check looks at the same scope only, and can skip the row being edited', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final worker = await seedWorker(db);
    final id = await db.saveRow(
      db.payContracts,
      id: null,
      operationId: newUuid(),
      fields: PayContractsCompanion(
        workerId: Value(worker),
        basis: Value(RateBasis.hour.name),
        rateFils: const Value(800),
        effectiveFrom: const Value('2026-01-01'),
        effectiveTo: const Value('2026-06-30'),
      ),
    );
    Future<bool> check(String from, String? to, {String? site, String? except}) {
      return db.payContractOverlaps(workerId: worker, siteId: site, from: from, to: to, exceptId: except);
    }

    expect(await check('2026-06-30', null), isTrue);
    expect(await check('2026-07-01', null), isFalse);
    expect(await check('2026-03-01', null, except: id), isFalse);
  });

  testWidgets('a pay rate saves, and a second rate over the same dates is refused', (tester) async {
    final db = memoryDb();
    await openWorker(tester, db);

    Future<void> addRate(String amount) async {
      await tester.tap(find.text('Tankhwah ka rate add karein'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Rate (AED)'), amount);
      await tester.tap(find.text('Save karein'));
      await settle(tester);
    }

    await addRate('8.50');
    final rows = await real(tester, () => db.select(db.payContracts).get());
    expect(rows.single.rateFils, 850);
    expect(rows.single.basis, 'hour');
    expect(find.text('AED 8.50, Fi ghanta'), findsOneWidget);

    await addRate('9');
    expect(find.textContaining('doosra rate pehle se hai'), findsOneWidget);
    expect(await real(tester, () => db.select(db.payContracts).get()), hasLength(1));

    await tester.pageBack();
    await settle(tester);
    await shutDown(tester, db);
  });

  testWidgets('a monthly pay rate cannot be saved without choosing a part-month method', (tester) async {
    final db = memoryDb();
    await openWorker(tester, db);
    await tester.tap(find.text('Tankhwah ka rate add karein'));
    await settle(tester);

    await tester.tap(find.text('Fi ghanta'));
    await settle(tester);
    await tester.tap(find.text('Mahana').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Rate (AED)'), '2000');
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    expect(find.text('Yeh zaroori hai'), findsOneWidget);
    expect(await real(tester, () => db.select(db.payContracts).get()), isEmpty);

    await tester.tap(find.text('Adhooray mahine ka hisaab'));
    await settle(tester);
    await tester.tap(find.text('Mahine ke asal din').last);
    await settle(tester);
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    final row = await real(tester, () => db.select(db.payContracts).getSingle());
    expect(row.basis, 'month');
    expect(row.partialMethod, 'calendarDays');
    await shutDown(tester, db);
  });

  testWidgets('TC-030: opening salary and advance stay separate, and need a source and confirmation', (tester) async {
    final db = memoryDb();
    await openWorker(tester, db);
    await tester.tap(find.text('Mazdoor ko purani salary deni hai'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)'), '500');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsOneWidget);
    expect(find.text('Raqam check kar ke tasdeeq karein'), findsOneWidget);
    expect(await real(tester, () => db.select(db.openingBalances).get()), isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Yeh raqam kahan se aayi'), 'Old register page 12');
    await tester.tap(find.text('Maine yeh raqam check kar li hai'));
    await settle(tester);
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    await tester.tap(find.text('Mazdoor se purana advance wapas lena hai'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)'), '300');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeh raqam kahan se aayi'), 'Old register page 13');
    await tester.tap(find.text('Maine yeh raqam check kar li hai'));
    await settle(tester);
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    expect(find.text('AED 500.00'), findsOneWidget);
    expect(find.text('AED 300.00'), findsOneWidget);
    final rows = await real(tester, () => db.select(db.openingBalances).get());
    expect({for (final r in rows) r.kind: r.amountFils}, {'worker_salary_owed': 50000, 'worker_advance': 30000});
    await shutDown(tester, db);
  });

  testWidgets('a client rate can be scoped to one site', (tester) async {
    final db = memoryDb();
    await real(tester, () async {
      await seedProfile(db);
      final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
      await db.saveRow(
        db.sites,
        id: null,
        operationId: newUuid(),
        fields: SitesCompanion(clientId: Value(client), name: const Value('Marina')),
      );
    });
    await pumpApp(tester, db);
    await goTo(tester, 'Companies');
    await tester.tap(find.text('Emaar'));
    await settle(tester);
    await tester.tap(find.text('Company ka rate add karein'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Rate (AED)'), '10');
    await tester.tap(find.text('Tamam sites'));
    await settle(tester);
    await tester.tap(find.text('Marina').last);
    await settle(tester);
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    final row = await real(tester, () => db.select(db.billingContracts).getSingle());
    final site = await real(tester, () => db.select(db.sites).getSingle());
    expect(row.siteId, site.id);
    expect(row.rateFils, 1000);
    expect(find.textContaining('Marina'), findsWidgets);
    await shutDown(tester, db);
  });
}
