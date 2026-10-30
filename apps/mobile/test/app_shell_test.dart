import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/settings.dart';

import 'support.dart';

void main() {
  testWidgets('five tabs in Roman Urdu stay left to right, and switching language persists', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);

    for (final tab in ['Aaj', 'Companies', 'Labour', 'Hisaab', 'Aur']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
    expect(Directionality.of(tester.element(find.text('Hisaab'))), TextDirection.ltr);

    await tester.tap(find.text('Aur'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButton<Locale>));
    await settle(tester);
    await tester.tap(find.text('English').last);
    await settle(tester);

    expect(find.text('Accounts'), findsOneWidget);
    expect((await real(tester, () => AppSettings.load(const FlutterSecureStorage()))).locale, english);
    await shutDown(tester, db);
  });

  testWidgets('large text setting scales text and survives a restart', (tester) async {
    final db = memoryDb();
    await real(tester, () => seedProfile(db));
    await pumpApp(tester, db);
    await tester.tap(find.text('Aur'));
    await settle(tester);
    final before = MediaQuery.textScalerOf(tester.element(find.text('Bara text'))).scale(10);

    await tester.tap(find.text('Bara text'));
    await settle(tester);

    expect(MediaQuery.textScalerOf(tester.element(find.text('Bara text'))).scale(10), greaterThan(before));
    expect((await real(tester, () => AppSettings.load(const FlutterSecureStorage()))).largeText, isTrue);
    await shutDown(tester, db);
  });

  testWidgets('first run asks only for the company name, then opens the tabs', (tester) async {
    final db = memoryDb();
    await pumpApp(tester, db);

    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Company ka qanooni naam'), 'Al Noor Labour LLC');
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect((await real(tester, () => db.select(db.tenantProfiles).getSingle())).legalName, 'Al Noor Labour LLC');
    await shutDown(tester, db);
  });
}
