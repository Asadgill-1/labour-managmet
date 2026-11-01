import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/providers.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

const testTenant = '00000000-0000-4000-8000-00000000000a';

TenantDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1');
}

Future<void> seedProfile(TenantDatabase db) async {
  await db.saveRow(
    db.tenantProfiles,
    id: null,
    operationId: newUuid(),
    fields: const TenantProfilesCompanion(legalName: Value('Test Labour LLC')),
  );
}

/// Runs database work on the real clock. Inside testWidgets the fake clock would never let it finish.
Future<T> real<T>(WidgetTester tester, Future<T> Function() work) async => (await tester.runAsync(work)) as T;

Future<void> pumpApp(WidgetTester tester, TenantDatabase db) async {
  FlutterSecureStorage.setMockInitialValues({});
  // Narrow as a real phone, tall enough that detail screens need no scrolling in tests.
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: const LabourApp(),
    ),
  );
  await settle(tester);
}

/// Shows the side panel and opens a section.
Future<void> goTo(WidgetTester tester, String section) async {
  await tester.tap(find.text('Menu'));
  await settle(tester);
  // A sub-tab shows once its main tab is open.
  final sub = find.byKey(ValueKey('sub-$section'));
  for (final main in const ['Hazri', 'Labour', 'Visa', 'Companies', 'Tankhwah', 'Hisaab', 'Rooms', 'Kaghazat']) {
    if (sub.evaluate().isNotEmpty) break;
    await tester.tap(find.text(main).hitTestable().first);
    await settle(tester);
  }
  await tester.tap(sub.evaluate().isNotEmpty ? sub : find.text(section).hitTestable().last);
  await settle(tester);
}

/// Lets database streams deliver, then lets the UI finish animating.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

/// Ends the app so drift's stream timers finish before the test does.
Future<void> shutDown(WidgetTester tester, TenantDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}
