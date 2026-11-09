import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/root.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_export.dart';

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
}
