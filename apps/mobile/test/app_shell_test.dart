import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/app/theme.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

void main() {
  testWidgets('the side panel stays hidden until asked for, lists every section and hides again', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);
    expect(find.text('Pichla baqaya'), findsNothing);

    await tester.tap(find.text('Menu'));
    await settle(tester);
    // Main tabs show first. The open one is the current section's, and the rest open on a tap (D-036).
    for (final main in ['Hazri', 'Labour', 'Visa', 'Companies', 'Tankhwah', 'Hisaab', 'Rooms', 'Apni company', 'Settings']) {
      expect(find.text(main), findsWidgets, reason: main);
    }
    expect(find.text('Aaj').hitTestable(), findsOneWidget);
    expect(find.text('Pichla baqaya'), findsNothing);
    expect(Directionality.of(tester.element(find.text('Tankhwah'))), TextDirection.ltr);
    for (final (main, sub) in [('Labour', 'Mazdoor register'), ('Companies', 'Rates'), ('Tankhwah', 'Advance register'), ('Hisaab', 'Pichla baqaya'), ('Rooms', 'Room register')]) {
      await tester.tap(find.text(main).hitTestable().first);
      await settle(tester);
      expect(find.text(sub).hitTestable(), findsOneWidget, reason: sub);
    }

    // Not built yet, so it says so and goes nowhere (AI-07).
    await tester.tap(find.text('Jald aa raha hai'));
    await settle(tester);
    expect(find.text('Jald'), findsWidgets);
    await tester.tap(find.text('Timesheet'));
    await settle(tester);
    expect(find.text('Timesheet'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu band karein'));
    await settle(tester);
    expect(find.text('Pichla baqaya'), findsNothing);
    await shutDown(tester, db);
  });

  testWidgets('switching language persists', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);

    await goTo(tester, 'Settings');
    await tester.tap(find.byType(DropdownButton<Locale>));
    await settle(tester);
    await tester.tap(find.text('English').last);
    await settle(tester);

    expect(find.text('Language'), findsOneWidget);
    expect((await real(tester, () => AppSettings.load(const FlutterSecureStorage()))).locale, english);
    await shutDown(tester, db);
  });

  testWidgets('choosing a colour changes every screen at once and survives a restart', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);
    Color? bandOnToday() {
      final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(TopBand), matching: find.byType(DecoratedBox)).first);
      return (box.decoration as BoxDecoration).color;
    }

    expect(bandOnToday(), AppPalette.blue.brand);

    await goTo(tester, 'Settings');
    await tester.tap(find.text('Sabz aur sunehra'));
    await settle(tester);
    expect(Theme.of(tester.element(find.text('Sabz aur sunehra'))).colorScheme.primary, AppPalette.green.brand);
    expect((await real(tester, () => AppSettings.load(const FlutterSecureStorage()))).palette, AppPalette.green);

    // The attendance screen was already built, behind this one, and still picks up the change.
    await goTo(tester, 'Aaj');
    expect(bandOnToday(), AppPalette.green.brand);

    // Other settings keep the choice.
    await goTo(tester, 'Settings');
    await tester.tap(find.text('Bara text'));
    await settle(tester);
    expect((await real(tester, () => AppSettings.load(const FlutterSecureStorage()))).palette, AppPalette.green);
    expect(brand, AppPalette.green.brand);
    await shutDown(tester, db);
  });

  testWidgets('large text setting scales text and survives a restart', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);
    await goTo(tester, 'Settings');
    final before = MediaQuery.textScalerOf(tester.element(find.text('Bara text'))).scale(10);

    await tester.tap(find.text('Bara text'));
    await settle(tester);

    expect(MediaQuery.textScalerOf(tester.element(find.text('Bara text'))).scale(10), greaterThan(before));
    expect((await real(tester, () => AppSettings.load(const FlutterSecureStorage()))).largeText, isTrue);
    await shutDown(tester, db);
  });

  testWidgets('first run asks only for the company name, then opens the app', (tester) async {
    final db = memoryDb();
    await pumpApp(tester, db);

    expect(find.byType(MenuButton), findsNothing);
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Company ka qanooni naam'), 'Al Noor Labour LLC');
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    expect(find.byType(MenuButton), findsOneWidget);
    expect((await real(tester, () => db.select(db.tenantProfiles).getSingle())).legalName, 'Al Noor Labour LLC');
    await shutDown(tester, db);
  });

  testWidgets('Sites, Rates and Pichla baqaya gather what the company and worker screens hold', (tester) async {
    final db = memoryDb();
    await real(tester, () async {
      await seedProfile(db);
      final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
      await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(client), name: const Value('Marina')));
      final worker = await db.saveRow(
        db.workers,
        id: null,
        operationId: newUuid(),
        fields: const WorkersCompanion(code: Value('W001'), name: Value('Ali Khan')),
      );
      await db.saveRow(
        db.payContracts,
        id: null,
        operationId: newUuid(),
        fields: PayContractsCompanion(workerId: Value(worker), basis: const Value('hour'), rateFils: const Value(800), effectiveFrom: const Value('2026-10-01')),
      );
      await db.saveRow(
        db.openingBalances,
        id: null,
        operationId: newUuid(),
        fields: OpeningBalancesCompanion(
          kind: const Value('worker_salary_owed'),
          workerId: Value(worker),
          amountFils: const Value(123456789),
          asOfDate: const Value('2026-10-01'),
          sourceNote: const Value('Old register'),
        ),
      );
    });
    await pumpApp(tester, db);

    await goTo(tester, 'Sites');
    expect(find.text('Marina'), findsOneWidget);
    expect(find.text('Emaar'), findsOneWidget);

    // With one company there is nothing to ask, so Add goes straight to the form.
    await tester.tap(find.text('Site add karein'));
    await settle(tester);
    expect(find.widgetWithText(TextFormField, 'Site ya project ka naam'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await goTo(tester, 'Rates');
    await tester.tap(find.text('Tankhwah ke rate'));
    await settle(tester);
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.textContaining('AED 8.00'), findsOneWidget);

    await goTo(tester, 'Pichla baqaya');
    expect(find.text('AED 1,234,567.89'), findsOneWidget);
    // A big amount shrinks to fit. It must not squeeze the name into a sliver.
    expect(tester.getSize(find.text('Ali Khan')).width, greaterThan(60));
    await tester.tap(find.text('AED 1,234,567.89'));
    await settle(tester);
    expect(find.widgetWithText(TextFormField, 'Raqam (AED)'), findsOneWidget);
    await shutDown(tester, db);
  });
}
