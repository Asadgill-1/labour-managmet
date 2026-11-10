import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/providers.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';

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

/// Bills every company's open work up to the end of [month], a timesheet and an invoice for each month, so closing finds
/// only what a test is about (D-048).
Future<void> invoiceUpTo(TenantDatabase db, String month) async {
  for (final (client, m) in await db.uninvoicedWork(to: monthLastDay(month), after: await db.lockedThrough())) {
    final (from, to) = (monthFirstDay(m), monthLastDay(m));
    final sheet = await db.createTimesheet(clientId: client, from: from, to: to, operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
    final invoice = await db.createInvoice(clientId: client, from: from, to: to, operationId: newUuid());
    await db.issueInvoice(invoice, describe: (_) => 'Manpower supply', operationId: newUuid());
  }
}

/// Runs database work on the real clock. Inside testWidgets the fake clock would never let it finish.
Future<T> real<T>(WidgetTester tester, Future<T> Function() work) async => (await tester.runAsync(work)) as T;

Future<void> pumpApp(WidgetTester tester, TenantDatabase db, {Map<String, String> stored = const {}}) async {
  FlutterSecureStorage.setMockInitialValues({...stored});
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
  for (final main in const ['Hazri', 'Labour', 'Visa', 'Companies', 'Tankhwah', 'Billing', 'Hisaab', 'Reports', 'Delete hui', 'Rooms', 'Kaghazat']) {
    if (sub.evaluate().isNotEmpty) break;
    // Tabs opened on the way push later ones down the panel, past where the list has built them yet.
    if (find.text(main).hitTestable().evaluate().isEmpty) {
      await tester.scrollUntilVisible(find.text(main), 150, scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
      await tester.pump();
    }
    await tester.tap(find.text(main).hitTestable().first);
    await settle(tester);
  }
  // Every main tab opened on the way stays open, so the one wanted can sit below the fold.
  if (sub.evaluate().isNotEmpty) {
    await tester.ensureVisible(sub);
    await tester.pump();
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
