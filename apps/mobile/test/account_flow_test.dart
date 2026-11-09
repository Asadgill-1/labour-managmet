import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/root.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_export.dart';

import 'cloud_fake.dart';
import 'support.dart';

void main() {
  late FakeCloud cloud;
  late Account account;
  final opened = <TenantDatabase>[];

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    cloud = FakeCloud();
    account = cloud.account(const FlutterSecureStorage());
    opened.clear();
  });

  Future<void> pumpRoot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(
      AppRoot(
        account: account,
        settings: const AppSettings(),
        loadSettings: () => AppSettings.load(const FlutterSecureStorage()),
        openTenant: (tenantId, {required actorId}) async {
          final db = TenantDatabase(NativeDatabase.memory(), tenantId: tenantId, deviceId: 'device-1', actorId: actorId);
          opened.add(db);
          return db;
        },
      ),
    );
    await settle(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  Future<void> fill(WidgetTester tester, String label, String text) => tester.enterText(find.widgetWithText(TextFormField, label), text);

  testWidgets('a new owner signs up, types the email code, names the company and lands in its books; logging out closes them', (tester) async {
    await pumpRoot(tester);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('English'), findsOneWidget, reason: 'the language can be chosen first (UX-02)');

    await tapAndSettle(tester, find.text('Naya account banayein'));
    await fill(tester, 'Email', 'owner@test');
    await fill(tester, 'Password', 'pass123');
    await tapAndSettle(tester, find.text('Account banayein'));
    expect(find.text('Poori email likhein, jaise name@example.com.'), findsOneWidget);
    expect(find.text('Kam az kam 8 huroof rakhein, harf aur number dono.'), findsOneWidget);
    expect(cloud.calls, isEmpty, reason: 'nothing leaves the phone until the form is right');

    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Account banayein'));
    expect(find.text('owner@test.ae par code bheja hai. Na mile to spam folder dekhein.'), findsOneWidget);

    await fill(tester, 'Email wala code', '00000000');
    await tapAndSettle(tester, find.text('Aage'));
    expect(find.text('Ye code ghalat hai ya purana ho gaya. Naya code mangwayein.'), findsOneWidget);
    await fill(tester, 'Email wala code', FakeCloud.code);
    await tapAndSettle(tester, find.text('Aage'));

    expect(find.text('Apni company'), findsOneWidget);
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Shuru karein'));

    expect(find.byType(LabourApp), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget, reason: 'the books open straight away, without asking the name again');
    final db = opened.single;
    final user = cloud.users['owner@test.ae']!.id;
    expect(db.actorId, user, reason: 'rows are written as the signed-in user');
    expect((await real(tester, () => db.select(db.tenantProfiles).getSingle())).legalName, 'Al Noor Labour Supply');
    // Share files live in the phone's cache folder; here a folder of the test's own.
    final cache = Directory.systemTemp.createTempSync('t19b');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async => cache.path);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      cache.deleteSync(recursive: true);
    });
    final share = await real(tester, () => writeExportFile('left-behind.pdf', Uint8List(4)));

    await goTo(tester, 'Settings');
    expect(find.text('owner@test.ae'), findsOneWidget);
    await tapAndSettle(tester, find.text('Log out'));
    expect(find.text('Is phone par is company ka data band ho jayega. Dobara login karne par khul jayega.'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Log out'));

    expect(find.byType(LabourApp), findsNothing);
    expect(find.text('Login karein'), findsOneWidget);
    expect(await real(tester, account.binding), isNull);
    expect(await real(tester, share.exists), isFalse, reason: 'no share file is left for the next account (AUTH-04)');
    final closed = await real(tester, () async {
      try {
        await db.select(db.tenantProfiles).get();
        return false;
      } on StateError {
        return true;
      }
    });
    expect(closed, isTrue, reason: 'the company file is closed');
  });

  testWidgets('from the built-in sender the email carries a link: tapping it, then Aage, goes on; a lost password waits for codes', (tester) async {
    account = cloud.account(const FlutterSecureStorage(), emailCodes: false);
    await pumpRoot(tester);
    await tapAndSettle(tester, find.text('Password bhool gaye?'));
    expect(find.text('Password badalna abhi chalu nahin. Ye email ke code se hoga, jo jald aa raha hai.'), findsOneWidget);
    expect(cloud.calls, isEmpty, reason: 'no reset email that the app could not finish');
    await tapAndSettle(tester, find.text('Theek hai'));

    await tapAndSettle(tester, find.text('Naya account banayein'));
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Account banayein'));
    expect(find.textContaining('owner@test.ae par email bheji hai. Us mein diya link dabayein'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email wala code'), findsNothing, reason: 'this email has no code');

    await tapAndSettle(tester, find.text('Aage'));
    expect(find.text('Email abhi confirm nahin hui. Pehle email mein diya link dabayein.'), findsOneWidget);
    cloud.confirmByLink('owner@test.ae');
    await tapAndSettle(tester, find.text('Aage'));
    expect(find.text('Apni company'), findsOneWidget);
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Shuru karein'));
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, opened.single);
  });

  testWidgets('an owner with a company logs in on a phone that has data, and is told what happens to it', (tester) async {
    await const FlutterSecureStorage().write(key: localTenantKey, value: testTenant);
    cloud.addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9');
    await pumpRoot(tester);
    expect(find.textContaining('Is phone par pehle se data hai.'), findsOneWidget);

    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'wrong999');
    await tapAndSettle(tester, find.text('Login karein'));
    expect(find.text('Email ya password ghalat hai.'), findsOneWidget);

    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    expect(opened.single.tenantId, '00000000-0000-4000-8000-0000000000c9');
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, opened.single);
  });

  testWidgets('a phone the company turned off stays on the login screen', (tester) async {
    cloud
      ..addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9')
      ..deviceRevoked = true;
    await pumpRoot(tester);
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    expect(find.text('Aap ki company ne is phone ka access band kar diya hai.'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testWidgets('a forgotten password is replaced with the email code, then the company opens', (tester) async {
    cloud.addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9');
    await pumpRoot(tester);
    await tapAndSettle(tester, find.text('Password bhool gaye?'));
    expect(find.text('Poori email likhein, jaise name@example.com.'), findsOneWidget);

    await fill(tester, 'Email', 'owner@test.ae');
    await tapAndSettle(tester, find.text('Password bhool gaye?'));
    await fill(tester, 'Email wala code', FakeCloud.code);
    await fill(tester, 'Naya password', 'newpass99');
    await tapAndSettle(tester, find.text('Naya password rakhein'));
    expect(cloud.users['owner@test.ae']?.password, 'newpass99');
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, opened.single);
  });
}
