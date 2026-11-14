import 'dart:convert';
import 'dart:io';

import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/root.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/app/theme.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/plan_guard.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/account/account_screens.dart';
import 'package:labour_app/features/labour/worker_form_screen.dart';
import 'package:labour_app/features/registers/register_export.dart';
import 'package:labour_app/features/today/attendance_entry_screen.dart';

import 'cloud_fake.dart';
import 'support.dart';

void main() {
  late FakeCloud cloud;
  late Account account;
  late FakeLock lock;
  final opened = <TenantDatabase>[];
  final deleted = <String>[];

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    cloud = FakeCloud();
    account = cloud.account(const FlutterSecureStorage());
    lock = FakeLock(const FlutterSecureStorage());
    opened.clear();
    deleted.clear();
  });

  Future<void> pumpRoot(WidgetTester tester, {({TenantDatabase db, Binding binding})? bound, bool pinSet = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(
      AppRoot(
        account: account,
        lock: lock,
        opened: bound,
        pinSet: pinSet,
        settings: const AppSettings(),
        loadSettings: () => AppSettings.load(const FlutterSecureStorage()),
        deleteTenant: (tenantId) async => deleted.add(tenantId),
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
    // Settings is taller than a phone, so a row far down is built and reached only once scrolled to.
    if (target.hitTestable().evaluate().isEmpty && find.byType(Scrollable).evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(target.hitTestable(), 150, scrollable: find.byType(Scrollable).hitTestable().first);
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  Future<void> fill(WidgetTester tester, String label, String text) => tester.enterText(find.widgetWithText(TextFormField, label), text);

  /// Share files live in the phone's cache folder, which logging out empties; here a folder of the test's own.
  void shareFolder(WidgetTester tester) {
    final cache = Directory.systemTemp.createTempSync('t19b');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async => cache.path);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      if (cache.existsSync()) cache.deleteSync(recursive: true);
    });
  }

  /// The phone's lock, asked for once the company opens after a login (AUTH-03).
  Future<void> setPin(WidgetTester tester, [String pin = '2580']) async {
    expect(find.text('Phone ka taala'), findsOneWidget);
    expect(find.byType(LabourApp), findsNothing, reason: 'the books wait for the lock');
    await fill(tester, 'PIN', pin);
    await fill(tester, 'PIN dobara', pin);
    await tapAndSettle(tester, find.text('Ye PIN rakhein'));
  }

  /// A phone someone signed in on before, opening with no network.
  Future<TenantDatabase> boundPhone(WidgetTester tester, {required bool pinSet}) async {
    cloud.offline = true;
    final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: 'user-1');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: 'user-1', email: 'owner@test.ae')), pinSet: pinSet);
    return db;
  }

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
    await fill(tester, 'PIN', '1234');
    await tapAndSettle(tester, find.text('Ye PIN rakhein'));
    expect(find.text('4 se 6 number rakhein. Ek hi number baar baar ya 1234 jaisi seedhi line nahin.'), findsOneWidget);
    expect(find.text('Dono PIN ek jaise nahin.'), findsOneWidget);
    await setPin(tester);

    expect(find.byType(LabourApp), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget, reason: 'the books open straight away, without asking the name again');
    final db = opened.single;
    final user = cloud.users['owner@test.ae']!.id;
    expect(db.actorId, user, reason: 'rows are written as the signed-in user');
    expect((await real(tester, () => db.select(db.tenantProfiles).getSingle())).legalName, 'Al Noor Labour Supply');
    shareFolder(tester);
    final share = await real(tester, () => writeExportFile('left-behind.pdf', Uint8List(4)));

    await goTo(tester, 'Settings');
    expect(find.text('owner@test.ae'), findsOneWidget);
    await tapAndSettle(tester, find.text('Phone ka taala (PIN)'));
    await fill(tester, 'PIN', '3690');
    await fill(tester, 'PIN dobara', '3690');
    await tapAndSettle(tester, find.text('Ye PIN rakhein'));
    expect(find.text('Naya PIN rakh liya'), findsOneWidget);
    expect(await real(tester, () => lock.check('3690')), isNull, reason: 'the PIN can be changed from Settings');
    await tapAndSettle(tester, find.text('Log out'));
    expect(find.text('Is phone par is company ka data band ho jayega. Dobara login karne par khul jayega.'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Log out'));

    expect(find.byType(LabourApp), findsNothing);
    expect(find.text('Login karein'), findsOneWidget);
    expect(await real(tester, account.binding), isNull);
    expect(await real(tester, lock.hasPin), isFalse, reason: 'the next account on the phone sets its own lock');
    // Logging out ends with the disk: each step waits on it once.
    for (var i = 0; i < 5 && await real(tester, share.exists); i++) {
      await settle(tester);
    }
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
    await setPin(tester);
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, opened.single);
  });

  testWidgets('earlier phone data goes into the company of a new account, never hidden under another (D-063)', (tester) async {
    await const FlutterSecureStorage().write(key: localTenantKey, value: testTenant);
    cloud.addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9');
    await pumpRoot(tester);
    expect(find.text('Is phone par pehle se data hai. Naya account banayein, ye data usi nayi company mein chala jayega.'), findsOneWidget);

    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'wrong999');
    await tapAndSettle(tester, find.text('Login karein'));
    expect(find.text('Email ya password ghalat hai.'), findsOneWidget);

    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    expect(find.text('Is phone ke purane data ki abhi koi company nahin. Yahan naya account banayein, data usi ki company mein chala jayega.'), findsOneWidget);
    expect(opened, isEmpty);

    await tapAndSettle(tester, find.text('Naya account banayein'));
    await fill(tester, 'Email', 'new@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Account banayein'));
    await fill(tester, 'Email wala code', FakeCloud.code);
    await tapAndSettle(tester, find.text('Aage'));
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Shuru karein'));
    await setPin(tester);
    expect(opened.single.tenantId, testTenant, reason: 'the data on the phone opens in the new company');
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, opened.single);
  });

  testWidgets('a phone that holds an account names it when another signup is tried', (tester) async {
    cloud.addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9');
    await const FlutterSecureStorage().write(key: 'device_id', value: 'dddddddd-0000-4000-8000-00000000000a');
    cloud.phones['dddddddd-0000-4000-8000-00000000000a'] = cloud.users['owner@test.ae']!.id;
    await pumpRoot(tester);
    await tapAndSettle(tester, find.text('Naya account banayein'));
    await fill(tester, 'Email', 'new@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Account banayein'));
    expect(
      find.text('Is phone par pehle se account hai: ow***@test.ae. Usi se login karein. Ek phone par ek hi account chalta hai, taake kisi company ka data is par chhup na jaye.'),
      findsOneWidget,
    );
    expect(find.text('Apni company'), findsNothing);
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
    await setPin(tester);
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, opened.single);
  });

  testWidgets('a phone with a PIN opens behind its lock with no network; a wrong PIN says how many tries are left', (tester) async {
    await lock.setPin('2580');
    final db = await boundPhone(tester, pinSet: true);
    expect(find.text('Is phone par owner@test.ae ka PIN likhein.'), findsOneWidget);
    expect(find.byType(LabourApp), findsNothing);
    expect(find.text('Fingerprint lagayein'), findsNothing, reason: 'a phone without a fingerprint is not offered one');

    await fill(tester, 'PIN', '1111');
    await tapAndSettle(tester, find.text('Kholein'));
    expect(find.text('PIN ghalat hai. 7 koshishein baqi, phir email se login karna hoga.'), findsOneWidget);
    await fill(tester, 'PIN', '2580');
    await tapAndSettle(tester, find.text('Kholein'));
    expect(find.byType(LabourApp), findsOneWidget);
    expect(cloud.calls, isEmpty, reason: 'the lock opens with no network (AUTH-03)');
    await shutDown(tester, db);
  });

  testWidgets('the fingerprint opens the lock by itself when it is on', (tester) async {
    lock = FakeLock(const FlutterSecureStorage(), hasFingerprint: true);
    await lock.setPin('2580');
    await lock.setFingerprint(true);
    final db = await boundPhone(tester, pinSet: true);
    expect(lock.prompts, 1);
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, db);
  });

  testWidgets('8 wrong PINs remove the lock; logging in with the email opens the same company again', (tester) async {
    await lock.setPin('2580');
    await boundPhone(tester, pinSet: true);
    shareFolder(tester);
    for (var i = 0; i < 7; i++) {
      await fill(tester, 'PIN', '1111');
      await tapAndSettle(tester, find.text('Kholein'));
    }
    expect(find.text('PIN ghalat hai. 1 koshish baqi, phir email se login karna hoga.'), findsOneWidget);
    await tapAndSettle(tester, find.text('PIN bhool gaye?'));
    expect(find.text('PIN ke baghair email aur password se dobara login karein. Is ke liye internet chahiye. Data isi phone par rahega aur dobara khul jayega.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Wapas'));
    await fill(tester, 'PIN', '1111');
    await tapAndSettle(tester, find.text('Kholein'));

    expect(find.text('PIN 8 baar ghalat likha gaya, is liye phone ka taala hata diya gaya. Email aur password se login karein; data isi phone par hai.'), findsOneWidget);
    expect(await real(tester, lock.hasPin), isFalse);

    cloud
      ..offline = false
      ..addUser('owner@test.ae', 'pass1234', company: testTenant);
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    await setPin(tester, '3690');
    expect(opened.single.tenantId, testTenant, reason: 'the data stayed on the phone');
    await shutDown(tester, opened.single);
  });

  testWidgets('the lock is optional: skipped after login the books open, and Settings sets and removes it (D-064)', (tester) async {
    cloud.addUser('owner@test.ae', 'pass1234', company: testTenant);
    await pumpRoot(tester);
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    expect(find.text('Phone ka taala'), findsOneWidget, reason: 'the lock is offered after a login');
    expect(find.text('Taala hatayein'), findsNothing);
    await tapAndSettle(tester, find.text('Abhi nahin'));
    expect(find.byType(LabourApp), findsOneWidget);
    expect(await real(tester, lock.hasPin), isFalse);
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Save karein'));

    await goTo(tester, 'Settings');
    await tapAndSettle(tester, find.text('Phone ka taala (PIN)'));
    expect(find.text('Abhi nahin'), findsNothing);
    expect(find.text('Taala hatayein'), findsNothing, reason: 'there is no lock to remove yet');
    await fill(tester, 'PIN', '2580');
    await fill(tester, 'PIN dobara', '2580');
    await tapAndSettle(tester, find.text('Ye PIN rakhein'));
    expect(await real(tester, lock.hasPin), isTrue);

    await tapAndSettle(tester, find.text('Phone ka taala (PIN)'));
    await tapAndSettle(tester, find.text('Taala hatayein'));
    expect(find.text('Taala hata diya'), findsOneWidget);
    expect(await real(tester, lock.hasPin), isFalse);
    await shutDown(tester, opened.single);
  });

  testWidgets('a phone without a PIN opens its books straight away', (tester) async {
    final db = await boundPhone(tester, pinSet: false);
    expect(find.text('Phone ka taala'), findsNothing);
    expect(find.byType(LabourApp), findsOneWidget);
    await shutDown(tester, db);
  });

  testWidgets('deleting the account takes the password and DELETE, then the company leaves the phone (D-066)', (tester) async {
    cloud.addUser('owner@test.ae', 'pass1234', company: testTenant);
    await pumpRoot(tester);
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    await setPin(tester);
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Save karein'));
    shareFolder(tester);
    final db = opened.single;

    await goTo(tester, 'Settings');
    await tapAndSettle(tester, find.text('Account delete karein'));
    expect(find.textContaining('Ye owner@test.ae ka account'), findsOneWidget);
    await tapAndSettle(tester, find.text('Hamesha ke liye delete karein'));
    expect(find.text('Bilkul DELETE likhein, bade huroof mein.'), findsOneWidget);
    await fill(tester, 'Password', 'wrong999');
    await fill(tester, 'DELETE likhein', 'delete');
    await tapAndSettle(tester, find.text('Hamesha ke liye delete karein'));
    expect(find.text('Bilkul DELETE likhein, bade huroof mein.'), findsOneWidget);
    expect(cloud.calls.where((call) => call.path.contains('delete_account')), isEmpty, reason: 'nothing leaves the phone until the form is right');

    await fill(tester, 'DELETE likhein', 'DELETE');
    await tapAndSettle(tester, find.text('Hamesha ke liye delete karein'));
    expect(find.text('Email ya password ghalat hai.'), findsOneWidget);
    expect(cloud.users, contains('owner@test.ae'), reason: 'a wrong password deletes nothing');

    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Hamesha ke liye delete karein'));
    for (var i = 0; i < 5 && deleted.isEmpty; i++) {
      await settle(tester);
    }
    expect(find.text('Account aur us ki company ka sara data mit gaya. Naya account bana sakte hain.'), findsOneWidget);
    expect(find.byType(LabourApp), findsNothing);
    expect(cloud.users, isEmpty);
    expect(deleted, [testTenant], reason: 'the company file and its key leave the phone');
    expect(await real(tester, account.binding), isNull);
    expect(await real(tester, lock.hasPin), isFalse);
    final closed = await real(tester, () async {
      try {
        await db.select(db.tenantProfiles).get();
        return false;
      } on StateError {
        return true;
      }
    });
    expect(closed, isTrue, reason: 'the file was closed before it was removed');
  });

  testWidgets('before deleting, the account screen opens Reports, where the data goes to Excel or PDF (AUTH-07)', (tester) async {
    final db = await boundPhone(tester, pinSet: false);
    await real(tester, () => db.saveRow(db.tenantProfiles, id: null, operationId: newUuid(), fields: const TenantProfilesCompanion(legalName: Value('Al Noor Labour Supply'))));
    await settle(tester);
    await goTo(tester, 'Settings');
    await tapAndSettle(tester, find.text('Account delete karein'));
    expect(find.text('Pehle apna data nikal lein. Reports mein har register Excel ya PDF mein nikalta hai.'), findsOneWidget);
    await tapAndSettle(tester, find.text('Reports kholein'));
    expect(find.text('Account delete karein'), findsNothing);
    expect(find.text('Sab reports'), findsWidgets);
    await shutDown(tester, db);
  });

  /// A phone someone signed in on before, as main finds it after a restart: no session, only the stored company.
  Future<(TenantDatabase, String)> restartedPhone(WidgetTester tester, {bool off = false, bool pinSet = false}) async {
    cloud.addUser('owner@test.ae', 'pass1234', company: testTenant);
    final userId = cloud.users['owner@test.ae']!.id;
    const storage = FlutterSecureStorage();
    await real(tester, () async {
      await storage.write(key: 'account', value: jsonEncode({'tenant_id': testTenant, 'user_id': userId, 'email': 'owner@test.ae'}));
      final here = await thisDeviceId(storage);
      cloud.addPhone('owner@test.ae', here, 'Office laptop', '2026-11-10T05:00:00Z');
      if (off) cloud.offPhones.add(here);
    });
    final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: userId);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: userId, email: 'owner@test.ae')), pinSet: pinSet);
    return (db, userId);
  }

  testWidgets('Settings turns an old phone off; after a login in this run no password is asked again (T20c)', (tester) async {
    const old = '00000000-0000-4000-8000-0000000000e1';
    cloud.addUser('owner@test.ae', 'pass1234', company: testTenant);
    await pumpRoot(tester);
    await fill(tester, 'Email', 'owner@test.ae');
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Login karein'));
    await setPin(tester);
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Save karein'));
    cloud.addPhone('owner@test.ae', old, 'Galaxy A51', '2026-11-03T06:00:00Z');

    await goTo(tester, 'Settings');
    await tapAndSettle(tester, find.text('Purana phone band karein'));
    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing, reason: 'signed in during this run');
    expect(find.text('Galaxy A51'), findsOneWidget);
    expect(find.text('Akhri login 03-11-2026'), findsOneWidget);
    expect(find.textContaining('Yeh phone. Akhri login'), findsOneWidget);

    await tapAndSettle(tester, find.text('Band karein'));
    expect(find.text('Galaxy A51 band karein?'), findsOneWidget);
    expect(find.textContaining('kisi backup mein nahin'), findsOneWidget);
    await tapAndSettle(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Band karein')));
    expect(find.text('Galaxy A51 band ho gaya.'), findsOneWidget);
    expect(find.text('Galaxy A51'), findsNothing);
    expect(find.text('Is company ka koi aur phone chalu nahin.'), findsOneWidget);
    expect(cloud.offPhones, {old});
    await shutDown(tester, opened.single);
  });

  testWidgets('after a restart a phone that is on stays open, and its phones page asks for the password first (T20c)', (tester) async {
    final (db, _) = await restartedPhone(tester);
    cloud.addPhone('owner@test.ae', '00000000-0000-4000-8000-0000000000e1', 'Galaxy A51', '2026-11-03T06:00:00Z');
    expect(find.byType(LabourApp), findsOneWidget);
    expect(deleted, isEmpty);
    expect(cloud.calls.where((c) => c.path.endsWith('phone_is_off')), hasLength(1), reason: 'the phone asked as it opened');
    await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
    await tapAndSettle(tester, find.text('Save karein'));

    await goTo(tester, 'Settings');
    await tapAndSettle(tester, find.text('Purana phone band karein'));
    expect(find.text('Galaxy A51'), findsNothing);
    await fill(tester, 'Password', 'wrong999');
    await tapAndSettle(tester, find.text('Phone dikhayein'));
    expect(find.text('Email ya password ghalat hai.'), findsOneWidget);
    expect(find.text('Galaxy A51'), findsNothing);
    await fill(tester, 'Password', 'pass1234');
    await tapAndSettle(tester, find.text('Phone dikhayein'));
    expect(find.text('Office laptop'), findsOneWidget);
    expect(find.text('Yeh phone. Akhri login 10-11-2026'), findsOneWidget);
    expect(find.text('Galaxy A51'), findsOneWidget);
    await shutDown(tester, db);
  });

  testWidgets('a phone the company turned off removes the company as it opens, even behind its lock (D-073)', (tester) async {
    shareFolder(tester);
    final (db, _) = await restartedPhone(tester, off: true, pinSet: true);
    for (var i = 0; i < 5 && deleted.isEmpty; i++) {
      await settle(tester);
    }
    expect(find.textContaining('Company ne ye phone band kar diya tha'), findsOneWidget);
    expect(find.byType(LabourApp), findsNothing);
    expect(deleted, [testTenant], reason: 'the company file and its key leave the phone');
    expect(await real(tester, account.binding), isNull);
    expect(await real(tester, lock.hasPin), isFalse);
    await shutDown(tester, db);
  });

  group('the plan (T21b)', () {
    /// The phone's file picker, answering with [bytes] each time.
    void slipPicker(WidgetTester tester, Uint8List Function() bytes) {
      const files = MethodChannel('labour_app/files');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, (call) async => call.method == 'pickSlip' ? bytes() : null);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, null));
    }

    /// Waits on the cloud's answers, which take real time to parse, until [target] shows.
    Future<void> until(WidgetTester tester, Finder target) async {
      for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
        await settle(tester);
      }
    }

    /// The lock a main action carries while the plan holds new entries back (T21c).
    final lockShown = find.descendant(of: find.byType(MainActionBar), matching: find.byIcon(Icons.lock_outline));
    Finder inDialog(Finder what) => find.descendant(of: find.byType(AlertDialog), matching: what);

    /// A message at the foot of the page covers the buttons there until it goes.
    Future<void> snackGone(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }

    Future<void> loggedIn(WidgetTester tester) async {
      cloud.addUser('owner@test.ae', 'pass1234', company: testTenant);
      await pumpRoot(tester);
      await fill(tester, 'Email', 'owner@test.ae');
      await fill(tester, 'Password', 'pass1234');
      await tapAndSettle(tester, find.text('Login karein'));
      await setPin(tester);
      await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
      await tapAndSettle(tester, find.text('Save karein'));
    }

    testWidgets('Settings shows the trial, its end and the checks; Plan lein sends a slip for the plan and months chosen', (tester) async {
      await loggedIn(tester);
      expect(cloud.calls.where((c) => c.path == '/functions/v1/licence'), hasLength(1), reason: 'checked right after login');
      await goTo(tester, 'Settings');
      expect(find.text('Trial'), findsOneWidget);
      final end = showDate(dubaiToday(cloud.licenceEnds));
      expect(find.textContaining('$end ko khatam'), findsOneWidget);
      expect(find.textContaining('Aakhri check ${showDate(dubaiToday(DateTime.now()))}'), findsOneWidget);
      expect(find.textContaining('se pehle internet par check zaroori'), findsOneWidget);

      await tapAndSettle(tester, find.text('Plan lein'));
      await until(tester, find.text('Small Company Plan'));
expect(find.text('Small Company Plan'), findsOneWidget);
      expect(find.text('AED 199.00'), findsOneWidget);
      expect(find.text('15 active workers, 5 client companies'), findsOneWidget);
      expect(find.text('Managers aur cloud backup (AED 20.00 mahana): jald aa raha'), findsWidgets);
      await tapAndSettle(tester, find.text('Mid Size Company Plan'));
      await tester.scrollUntilVisible(find.text('Unlimited workers, Unlimited client companies'), 150, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('Managers aur cloud backup (AED 40.00 mahana): jald aa raha'), findsOneWidget);
      await tapAndSettle(tester, find.text('1 mahina'));
      await tapAndSettle(tester, find.text('3 mahine').last);
      expect(find.text('AED 897.00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('0123456789001'), 150, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text('AE070000000123456789001'), findsOneWidget);
      expect(find.byTooltip('Copy karein'), findsNWidgets(2));

      await tapAndSettle(tester, find.text('Slip bhejein'));
      expect(find.text('Pehle slip chunein.'), findsOneWidget);
      await snackGone(tester);
      var picked = Uint8List(slipBytes + 1)..setAll(0, '%PDF-'.codeUnits);
      slipPicker(tester, () => picked);
      await tapAndSettle(tester, find.text('Slip chunein'));
      expect(find.text('Ye file 5 MB se bari hai. Choti file chunein.'), findsOneWidget);
      await snackGone(tester);
      picked = Uint8List.fromList('PK zip'.codeUnits);
      await tapAndSettle(tester, find.text('Slip chunein'));
      expect(find.text('Photo (JPG ya PNG) ya PDF chunein.'), findsOneWidget);
      await snackGone(tester);
      picked = Uint8List.fromList([...'%PDF-1.7'.codeUnits, ...List.filled(2000, 32)]);
      await tapAndSettle(tester, find.text('Slip chunein'));
      expect(find.text('PDF chuni gayi, 2 KB'), findsOneWidget);

      await tapAndSettle(tester, find.text('Slip bhejein'));
      await until(tester, find.text('Slip chali gayi. Hum bank mein check karenge.'));
      expect(cloud.slips.single['plan_code'], 'mid');
      expect(cloud.slips.single['months'], 3);
      expect(cloud.slipFiles.values.single, picked.length);
      await tester.scrollUntilVisible(find.text('Mid Size Company Plan, 3 mahine'), 150, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('Mid Size Company Plan, 3 mahine'), findsOneWidget);
      expect(find.textContaining('check ka intezar'), findsOneWidget);
      expect(find.text('Doosri chunein'), findsNothing, reason: 'the slip sent is no longer chosen');
      await shutDown(tester, opened.single);
    });

    testWidgets('a session kept from the last run renews the licence; another phone on says so and opens the phones page', (tester) async {
      cloud
        ..addUser('owner@test.ae', 'pass1234', company: testTenant)
        ..licenceRefusal = 'other_phone';
      const storage = FlutterSecureStorage();
      final userId = cloud.users['owner@test.ae']!.id;
      await real(tester, () async {
        final before = cloud.account(storage);
        await before.signIn('owner@test.ae', 'pass1234');
        await before.openCompany();
        await Future<void>.delayed(Duration.zero);
      });
      final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: userId);
      await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: userId, email: 'owner@test.ae')));
      await settle(tester);
      expect(cloud.calls.where((c) => c.path == '/functions/v1/licence'), hasLength(1));
      await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
      await tapAndSettle(tester, find.text('Save karein'));

      await goTo(tester, 'Settings');
      expect(find.text('Is account par ek aur phone chal raha hai. Purana phone band karein.'), findsOneWidget);
      cloud.licenceRefusal = null;
      await tapAndSettle(tester, find.text('Abhi check karein'));
      await until(tester, find.text('Plan check ho gaya'));
      expect(find.text('Plan check ho gaya'), findsOneWidget);
      expect(find.text('Trial'), findsOneWidget);
      expect(find.textContaining('ek aur phone'), findsNothing);
      await shutDown(tester, db);
    });

    testWidgets('with no session kept, Check now asks for the password, then the plan shows', (tester) async {
      final (db, _) = await restartedPhone(tester);
      await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
      await tapAndSettle(tester, find.text('Save karein'));
      await goTo(tester, 'Settings');
      expect(find.text('Plan check karne ke liye password se dobara login karein.'), findsOneWidget);
      expect(find.text('Abhi koi plan nahin'), findsOneWidget);
      await tapAndSettle(tester, find.text('Abhi check karein'));
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)), 'pass1234');
      await tapAndSettle(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Abhi check karein')));
      await until(tester, find.text('Trial'));
      expect(find.text('Trial'), findsOneWidget);
      expect(find.textContaining('dobara login karein'), findsNothing);
      await shutDown(tester, db);
    });

    testWidgets('the home page shows the trial days left from 5 days before the end, and opens Plan lein', (tester) async {
      cloud.licenceEnds = DateTime.now().toUtc().add(const Duration(days: 3, hours: 1));
      await loggedIn(tester);
      final days = daysBetween(dubaiToday(DateTime.now()), dubaiToday(cloud.licenceEnds));
      expect(find.text('Trial ke $days din baqi'), findsOneWidget);
      await tapAndSettle(tester, find.text('Trial ke $days din baqi'));
      await until(tester, find.text('Small Company Plan'));
      expect(find.text('Small Company Plan'), findsOneWidget);
      await shutDown(tester, opened.single);
    });

    testWidgets('a trial with more than 5 days left shows no note', (tester) async {
      await loggedIn(tester);
      expect(find.textContaining('din baqi'), findsNothing);
      expect(find.text('Nayi entry band hai'), findsNothing);
      expect(lockShown, findsNothing);
      await shutDown(tester, opened.single);
    });

    testWidgets('with the trial over the home page says so, entry buttons carry a lock that leads to Plan lein, and nothing is written (T21c)', (tester) async {
      cloud.licenceEnds = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await loggedIn(tester);
      final db = opened.single;
      final profile = await real(tester, () => db.select(db.tenantProfiles).getSingle());
      expect(profile.legalName, 'Al Noor Labour Supply', reason: 'the company\'s own details save whatever the plan');
      expect(find.text('Nayi entry band hai'), findsOneWidget);
      expect(find.textContaining('Plan khatam ho gaya.'), findsOneWidget);
      expect(find.textContaining('din baqi'), findsNothing);
      expect(lockShown, findsOneWidget);

      await tapAndSettle(tester, find.text('Hazri lagayein'));
      expect(find.byType(AttendanceEntryScreen), findsNothing);
      expect(inDialog(find.textContaining('Plan khatam ho gaya.')), findsOneWidget, reason: 'the lock says why');
      await tapAndSettle(tester, inDialog(find.text('Wapas')));

      await goTo(tester, 'Labour');
      expect(lockShown, findsOneWidget);
      await tapAndSettle(tester, find.text('Mazdoor add karein'));
      await tapAndSettle(tester, inDialog(find.text('Plan lein')));
      await until(tester, find.text('Small Company Plan'));
      expect(find.text('Small Company Plan'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Slip chunein'), 150, scrollable: find.byType(Scrollable).hitTestable().first);
      expect(find.text('Slip bhejein'), findsOneWidget);
      expect(lockShown, findsNothing, reason: 'paying is never locked');

      // Whatever a screen does, the write path itself refuses.
      Object? refused;
      await tester.runAsync(() async {
        try {
          await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Karim')));
        } catch (e) {
          refused = e;
        }
      });
      expect(refused, isA<PlanRefused>().having((e) => e.block, 'block', PlanBlock.ended));
      expect(await real(tester, () => db.select(db.workers).get()), isEmpty);
      await shutDown(tester, db);
    });

    testWidgets('on Small the 16th worker is refused from the list with the number, and so is bringing one back from the archive (T21c)', (tester) async {
      cloud
        ..licenceState = 'paid'
        ..licencePlan = 'Small Company Plan'
        ..licenceWorkers = 15
        ..licenceClients = 5;
      await loggedIn(tester);
      final db = opened.single;
      // One transaction: the open pages' lists read again only once all are in.
      await real(tester, () {
        return db.transaction(() async {
          for (var n = 1; n <= 15; n++) {
            await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value('W$n'), name: Value('Worker $n')));
          }
          await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W99'), name: Value('Old hand'), active: Value(false)));
        });
      });
      await settle(tester);
      expect(find.text('Nayi entry band hai'), findsNothing);
      expect(lockShown, findsNothing, reason: 'at the limit the day\'s work goes on');

      await goTo(tester, 'Labour');
      expect(lockShown, findsOneWidget);
      await tapAndSettle(tester, find.text('Mazdoor add karein'));
      expect(find.byType(WorkerFormScreen), findsNothing);
      expect(inDialog(find.textContaining('Is plan mein 15 workers hain.')), findsOneWidget);
      expect(inDialog(find.text('Plan lein')), findsOneWidget);
      await tapAndSettle(tester, inDialog(find.text('Wapas')));

      await tapAndSettle(tester, find.text('Archived dikhayein'));
      await tapAndSettle(tester, find.text('Old hand'));
      await tapAndSettle(tester, find.text('Dobara active karein'));
      expect(inDialog(find.textContaining('Is plan mein 15 workers hain.')), findsOneWidget);
      await tapAndSettle(tester, inDialog(find.text('Wapas')));
      final old = await real(tester, () => (db.select(db.workers)..where((w) => w.code.equals('W99'))).getSingle());
      expect(old.active, isFalse);
      await shutDown(tester, db);
    });

    testWidgets('a company over its plan picks who stays active; the rest are archived and entries go on (PLAN-04)', (tester) async {
      cloud
        ..licenceState = 'paid'
        ..licencePlan = 'Small Company Plan'
        ..licenceWorkers = 2
        ..licenceClients = 5;
      await loggedIn(tester);
      final db = opened.single;
      await real(tester, () async {
        // As a trial that ended left them: more workers than the plan now holds.
        final guard = db.guard;
        db.guard = null;
        await db.transaction(() async {
          for (final (n, name) in ['Asif', 'Bilal', 'Karim', 'Danish'].indexed) {
            await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value('W${n + 1}'), name: Value(name)));
          }
        });
        db.guard = guard;
      });
      await settle(tester);
      expect(find.text('Kaun se 2 active rahein?'), findsOneWidget);
      expect(find.textContaining('aap ke 4 active hain'), findsOneWidget);
      expect(lockShown, findsOneWidget, reason: 'new entries wait until the choice is made');

      await tapAndSettle(tester, find.text('Kaun se 2 active rahein?'));
      expect(find.text('0 / 2 chune'), findsOneWidget);
      await tapAndSettle(tester, find.text('Asif'));
      await tapAndSettle(tester, find.text('Karim'));
      await tapAndSettle(tester, find.text('Danish'));
      expect(find.text('2 se zyada nahin chun sakte.'), findsOneWidget);
      await snackGone(tester);
      expect(find.text('2 / 2 chune'), findsOneWidget);
      await tapAndSettle(tester, find.text('Baqi 2 archive karein'));
      await tapAndSettle(tester, inDialog(find.text('Archive karein')));
      await settle(tester);

      final workers = await real(tester, () => db.select(db.workers).get());
      expect(workers, hasLength(4), reason: 'nobody is deleted');
      expect({for (final w in workers.where((w) => w.active)) w.name}, {'Asif', 'Karim'});
      await snackGone(tester);
      expect(find.text('Kaun se 2 active rahein?'), findsNothing, reason: 'back on the home page with nothing left to choose');
      expect(lockShown, findsNothing);
      await shutDown(tester, db);
    });

    testWidgets('with no session kept, entries wait; Check now from the lock takes the password and opens them (T21c)', (tester) async {
      final (db, _) = await restartedPhone(tester);
      await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
      await tapAndSettle(tester, find.text('Save karein'));
      expect(find.text('Nayi entry band hai'), findsOneWidget);
      expect(find.text('Plan check karne ke liye password se dobara login karein.'), findsOneWidget);
      await tapAndSettle(tester, find.text('Hazri lagayein'));
      await tapAndSettle(tester, inDialog(find.text('Abhi check karein')));
      await tester.enterText(inDialog(find.byType(TextFormField)), 'pass1234');
      await tapAndSettle(tester, inDialog(find.text('Abhi check karein')));
      await until(tester, find.text('Plan check ho gaya'));
      await settle(tester);
      expect(find.text('Nayi entry band hai'), findsNothing);
      expect(lockShown, findsNothing);
      await shutDown(tester, db);
    });

    testWidgets('with another phone on, the lock leads to the phones page (T21c)', (tester) async {
      cloud
        ..addUser('owner@test.ae', 'pass1234', company: testTenant)
        ..licenceRefusal = 'other_phone';
      const storage = FlutterSecureStorage();
      final userId = cloud.users['owner@test.ae']!.id;
      await real(tester, () async {
        final before = cloud.account(storage);
        await before.signIn('owner@test.ae', 'pass1234');
        await before.openCompany();
        await Future<void>.delayed(Duration.zero);
      });
      final db = TenantDatabase(NativeDatabase.memory(), tenantId: testTenant, deviceId: 'device-1', actorId: userId);
      await pumpRoot(tester, bound: (db: db, binding: (tenantId: testTenant, userId: userId, email: 'owner@test.ae')));
      await settle(tester);
      await fill(tester, 'Company ka qanooni naam', 'Al Noor Labour Supply');
      await tapAndSettle(tester, find.text('Save karein'));
      expect(find.text('Nayi entry band hai'), findsOneWidget);
      await tapAndSettle(tester, find.text('Hazri lagayein'));
      expect(inDialog(find.text('Is account par ek aur phone chal raha hai. Purana phone band karein.')), findsOneWidget);
      await tapAndSettle(tester, inDialog(find.text('Purana phone band karein')));
      expect(find.byType(PhonesScreen), findsOneWidget);
      await shutDown(tester, db);
    });
  });
}

const slipBytes = 5 * 1024 * 1024;
