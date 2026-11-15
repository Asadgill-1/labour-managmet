import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/root.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'cloud_fake.dart';
import 'recovery_test.dart' show publicOf, testRecoveryPair;
import 'support.dart';

/// The cloud copy on the screens (T20d-b): the signup step, the first copy going by itself, the Backup page's section
/// and its question about another phone's copy, the notice on the day page and the words on the deletion screen.
void main() {
  late FakeCloud cloud;
  late Account account;
  late String recoveryKey;
  final opened = <TenantDatabase>[];

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    cloud = FakeCloud();
    recoveryKey = await publicOf(await testRecoveryPair());
    account = cloud.account(const FlutterSecureStorage(), recoveryKey: recoveryKey);
    opened.clear();
  });

  Future<void> pumpRoot(WidgetTester tester, {({TenantDatabase db, Binding binding})? bound}) async {
    final cache = Directory.systemTemp.createTempSync('t20d-screens');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async => cache.path);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      if (cache.existsSync()) cache.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(
      AppRoot(
        account: account,
        lock: FakeLock(const FlutterSecureStorage()),
        opened: bound,
        settings: const AppSettings(),
        loadSettings: () => AppSettings.load(const FlutterSecureStorage()),
        deleteTenant: (_) async {},
        files: (dir: cache, key: (_) async => newHexKey()),
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

  /// Making the copy stretches the password off the main isolate, so wait on the real clock.
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await settle(tester);
  }

  int starts() => cloud.calls.where((c) => c.path == '/functions/v1/backup' && c.body['action'] == 'start').length;

  testWidgets('a new company keeps its backup password and sends its first cloud copy with nothing pressed; the Backup page asks before replacing another phone\'s copy (D-072, D-076)', (tester) async {
    await pumpRoot(tester);
    await tapAndSettle(tester, find.text('Naya account banayein'));
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Account banayein'));
    await fill(tester, 'Email wala code', FakeCloud.code);
    await tapAndSettle(tester, find.text('Aage'));
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Aage'));
    expect(find.textContaining('Password bhool jaayein to platform ise khol kar aap ko wapas de sakta hai.'), findsOneWidget);
    expect(find.textContaining('end-to-end'), findsNothing);
    await fill(tester, 'Backup password', 'backup123');
    await fill(tester, 'Backup password dobara', 'backup123');
    await tapAndSettle(tester, find.text('Shuru karein'));
    await tapAndSettle(tester, find.text('Abhi nahin'));

    await until(tester, () => cloud.cloudFiles.isNotEmpty);
    expect(cloud.cloudFiles, hasLength(1), reason: 'the first copy goes as the books open');
    final tenant = cloud.companies.values.single;
    final summary = await real(tester, () async {
      final work = await Directory.systemTemp.createTemp('t20d-check');
      try {
        return await checkBackup(cloud.cloudFiles.values.single, 'backup123', tenantId: tenant, schemaVersion: opened.single.schemaVersion, work: work);
      } finally {
        await work.delete(recursive: true);
      }
    });
    expect(summary.companyName, 'Al Noor Labour Supply');

    await goTo(tester, 'Backup');
    expect(find.text('Aakhri cloud copy 15-11-2026, 10:00 ko gayi.'), findsOneWidget);
    expect(find.textContaining('Band backup khud cloud mein jata hai, din mein ek dafa.'), findsOneWidget);

    // The phone's copy has to wait once another phone sent the latest.
    cloud.addCloudCopy(tenant, 'old-phone');
    await tester.tap(find.text('Abhi cloud mein bhejein'));
    await until(tester, () => find.text('Is phone ka data rakhein').evaluate().isNotEmpty);
    expect(find.textContaining('Cloud mein rakhi copy kisi aur phone ki hai. Pehle wo data yahan wapas laana hai'), findsOneWidget);
    expect(find.text('Pehle wo data wapas laayein'), findsOneWidget);
    expect(find.text('Abhi cloud mein bhejein'), findsNothing, reason: 'the question comes first');

    await tapAndSettle(tester, find.text('Is phone ka data rakhein'));
    expect(find.text('Cloud mein is phone ka data jayega, aur doosre phone ki copy hat sakti hai. Ye wapas nahin hota.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Wapas'));
    expect(starts(), 2, reason: 'saying no sends nothing');
    await tapAndSettle(tester, find.text('Is phone ka data rakhein'));
    await tester.tap(find.text('Haan, is phone ka data bhejein'));
    await until(tester, () => cloud.cloudFiles.length == 2 && find.byType(LinearProgressIndicator).evaluate().isEmpty);
    expect(cloud.cloudCopies.last['replace'], isTrue);
    expect(find.text('Is phone ka data rakhein'), findsNothing);
    expect(find.text('Abhi cloud mein bhejein'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await goTo(tester, 'Settings');
    await tester.scrollUntilVisible(find.text('Account delete karein'), 150, scrollable: find.byType(Scrollable).hitTestable().first);
    await tapAndSettle(tester, find.text('Account delete karein'));
    expect(find.text('Bas cloud mein rakhi aakhri backup copy 60 din rehti hai, phir wo bhi mit jaati hai.'), findsOneWidget);
    await shutDown(tester, opened.single);
  });

  testWidgets('a company that keeps no backup password is asked for one on the day page, and the page says the platform can open the cloud copy', (tester) async {
    cloud.offline = true;
    final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: 'user-1');
    await real(tester, () => seedProfile(db));
    await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: 'user-1', email: 'owner@test.ae')));
    expect(find.text('Backup password abhi nahin rakha'), findsOneWidget);
    await tapAndSettle(tester, find.text('Backup password abhi nahin rakha'));
    expect(find.textContaining('Cloud wali copy platform khol kar aap ko wapas de sakta hai.'), findsOneWidget);
    expect(find.text('Abhi tak cloud mein copy nahin gayi.'), findsOneWidget);
    expect(find.text('Pehle upar backup password rakhein.'), findsOneWidget);
    final send = tester.widget<TextButton>(find.ancestor(of: find.text('Abhi cloud mein bhejein'), matching: find.byWidgetPredicate((w) => w is TextButton)));
    expect(send.onPressed, isNull, reason: 'no copy without the password');
    await shutDown(tester, db);
  });

  testWidgets('coming back to the front sends the copy once it can go (D-075)', (tester) async {
    cloud.addUser('owner@test.ae', 'pass1234', company: testTenant);
    await real(tester, () => account.signIn('owner@test.ae', 'pass1234'));
    final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: 'user-1');
    await real(tester, () => seedProfile(db));
    await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: cloud.users['owner@test.ae']!.id, email: 'owner@test.ae')));
    await until(tester, () => cloud.calls.any((c) => c.path == '/functions/v1/licence'));
    expect(starts(), 0, reason: 'no password kept, so no copy as it opened');

    await real(tester, () => const FlutterSecureStorage().write(key: backupPasswordKey(testTenant), value: 'backup123'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await until(tester, () => cloud.cloudFiles.isNotEmpty);
    expect(cloud.cloudFiles, hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(starts(), 1, reason: 'once a day at most');
    await shutDown(tester, db);
  });

  testWidgets('a failed copy says why on the Backup page, and a build without the recovery key says the cloud backup is unavailable', (tester) async {
    cloud.offline = true;
    FlutterSecureStorage.setMockInitialValues({
      backupPasswordKey(testTenant): 'backup123',
      cloudCopyKey(testTenant): jsonEncode({'at': '2026-11-14T05:30:00.000Z', 'mark': '1/x', 'problem': 'offline'}),
    });
    final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: 'user-1');
    await real(tester, () => seedProfile(db));
    await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: 'user-1', email: 'owner@test.ae')));
    expect(find.text('Backup password abhi nahin rakha'), findsNothing);
    await goTo(tester, 'Backup');
    expect(find.text('Aakhri cloud copy 14-11-2026, 09:30 ko gayi.'), findsOneWidget);
    expect(find.text('Internet nahin mila. Agli dafa internet par khud chali jayegi.'), findsOneWidget);
    await shutDown(tester, db);

    account = cloud.account(const FlutterSecureStorage());
    final plain = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: 'user-1');
    await real(tester, () => seedProfile(plain));
    await pumpRoot(tester, bound: (db: plain, binding: (tenantId: testTenant, userId: 'user-1', email: 'owner@test.ae')));
    await goTo(tester, 'Backup');
    expect(find.text('Cloud backup is app mein dastyab nahin.'), findsOneWidget);
    expect(find.text('Abhi cloud mein bhejein'), findsNothing);
    expect(find.textContaining('platform'), findsNothing, reason: 'a build that sends no copy never says the platform can open one');
    await shutDown(tester, plain);
  });
}
