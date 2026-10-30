import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/settings.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('five tabs in Roman Urdu stay left to right, and switching language persists', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LabourApp()));
    await tester.pumpAndSettle();

    for (final tab in ['Aaj', 'Companies', 'Labour', 'Hisaab', 'Aur']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
    expect(Directionality.of(tester.element(find.text('Hisaab'))), TextDirection.ltr);

    await tester.tap(find.text('Aur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect((await AppSettings.load(const FlutterSecureStorage())).locale, english);
  });

  testWidgets('large text setting scales text and survives a restart', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LabourApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aur'));
    await tester.pumpAndSettle();
    final before = MediaQuery.textScalerOf(tester.element(find.text('Bara text'))).scale(10);

    await tester.tap(find.text('Bara text'));
    await tester.pumpAndSettle();

    expect(MediaQuery.textScalerOf(tester.element(find.text('Bara text'))).scale(10), greaterThan(before));
    expect((await AppSettings.load(const FlutterSecureStorage())).largeText, isTrue);
  });
}
