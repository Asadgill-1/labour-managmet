import 'dart:convert';
import 'dart:io';

import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/form_bits.dart' show TotalRow;
import 'package:labour_app/app/root.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/plans.dart';
import 'package:labour_app/data/restore.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/backup/backup_screen.dart' show shownSize;

import 'cloud_fake.dart';
import 'recovery_test.dart' show publicOf, testRecoveryPair;
import 'support.dart';

/// Getting a cloud copy back (T20d-c): the new phone's offer, the cloud's list with the add-on and without, the add-on
/// on Plan lein and in Settings, the help for a forgotten password, and the copy that follows a restore.
void main() {
  late Directory work;
  late Directory dir;
  late Directory cache;
  late String key;
  late String recoveryKey;
  late FakeCloud cloud;
  late Account account;
  late TenantDatabase open;
  const storage = FlutterSecureStorage();
  final year = int.parse(dubaiToday(DateTime.now()).substring(0, 4));
  final slip = Uint8List.fromList([...'%PDF-1.7'.codeUnits, ...List.filled(2000, 32)]);

  /// What the phone keeps: the company it opens, as a login left it, with its consent given (D-084), and [more].
  Map<String, String> kept([Map<String, String> more = const {}]) => {
    'account': jsonEncode({'tenant_id': testTenant, 'user_id': cloud.users['owner@test.ae']!.id, 'email': 'owner@test.ae'}),
    'book_consent_$testTenant': '1',
    ...more,
  };

  setUp(() async {
    work = await Directory.systemTemp.createTemp('t20d-c');
    dir = Directory('${work.path}/phone')..createSync();
    cache = Directory('${work.path}/cache')..createSync();
    key = newHexKey();
    recoveryKey = await publicOf(await testRecoveryPair());
    cloud = FakeCloud()..addUser('owner@test.ae', 'pass1234', company: testTenant);
    cloud.bank = {...cloud.bank, 'support_contact': 'support@test.ae'};
    FlutterSecureStorage.setMockInitialValues(kept());
    account = cloud.account(storage, recoveryKey: recoveryKey);
  });

  tearDown(() => work.delete(recursive: true));

  /// The company's file on this phone, as the app opens it.
  TenantDatabase live() =>
      open = openTenantDatabase(tenantFile(dir, testTenant), key, tenantId: testTenant, deviceId: 'device-1', actorId: cloud.users['owner@test.ae']!.id);

  Future<void> addWorker(TenantDatabase db, String name) =>
      db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value(name), name: Value(name)));

  /// The copy the old phone sent to the cloud: the company with one worker, its key sealed to the recovery key.
  Future<Uint8List> oldPhoneCopy(String worker) async {
    final old = openTenantDatabase(File('${work.path}/old-$worker.db'), newHexKey(), tenantId: testTenant, deviceId: 'old-phone');
    await seedProfile(old);
    await addWorker(old, worker);
    final bytes = await old.backupBytes('pass1234', work: work, recoveryKey: recoveryKey);
    await old.close();
    return bytes;
  }

  /// The company as this phone holds it before the app starts. Made on the real clock, as drift can't make a file on
  /// the fake one.
  Future<void> onThisPhone(WidgetTester tester, {String? worker}) => real(tester, () async {
    final db = live();
    if (worker != null) {
      await seedProfile(db);
      await addWorker(db, worker);
    } else {
      await db.lastNumbers(year);
    }
    await db.close();
  });

  /// A file database answers on the real clock, and a progress bar never lets the screen settle, so this waits it out.
  Future<void> quiet(WidgetTester tester) async {
    final spinning = find.byWidgetPredicate((w) => w is ProgressIndicator);
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
      if (spinning.evaluate().isEmpty) break;
    }
    await settle(tester);
  }

  Future<void> wait(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> until(WidgetTester tester, Finder target) async {
    await wait(tester, () => target.evaluate().isNotEmpty);
    expect(target, findsWidgets);
    await quiet(tester);
  }

  Future<void> tapNow(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
  }

  Future<void> field(WidgetTester tester, String label, String text) async {
    final target = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(target);
    await tester.enterText(target, text);
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(target, 150, scrollable: find.byType(Scrollable).hitTestable().first);

  Future<void> pumpPhone(WidgetTester tester, {bool signedIn = true}) async {
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const files = MethodChannel('labour_app/files');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async => cache.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, (call) async => call.method == 'pickSlip' ? slip : true);
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, null);
    });
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (signedIn) await real(tester, () => account.signIn('owner@test.ae', 'pass1234'));
    await tester.pumpWidget(
      AppRoot(
        account: account,
        lock: FakeLock(storage),
        opened: (db: live(), binding: (tenantId: testTenant, userId: cloud.users['owner@test.ae']!.id, email: 'owner@test.ae')),
        settings: const AppSettings(),
        loadSettings: () => AppSettings.load(storage),
        deleteTenant: (_) async {},
        openTenant: (tenantId, {required actorId}) async => live(),
        files: (dir: dir, key: (_) async => key),
      ),
    );
    await quiet(tester);
  }

  /// Ends the app and closes the file it had open, so the folder can go.
  Future<void> closePhone(WidgetTester tester) async {
    await wait(tester, () => false == find.byWidgetPredicate((w) => w is ProgressIndicator).evaluate().isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(open.close);
  }

  /// The sum to transfer, at the foot of Plan lein's choices.
  Future<void> total(WidgetTester tester, String amount, {String? reason}) async {
    await scrollTo(tester, find.byType(TotalRow));
    expect(find.descendant(of: find.byType(TotalRow), matching: find.text(amount)), findsOneWidget, reason: reason);
  }

  int asked(String action) => cloud.calls.where((c) => c.path == '/functions/v1/backup' && c.body['action'] == action).length;

  final inDialog = find.byType(AlertDialog);

  testWidgets(
    "a new phone is told when the cloud's copy is from; without the add-on the list leads to Plan lein, with it the copy comes back and this phone's next copy takes its place (D-072, D-078)",
    skip: playStoreBuild,
    (tester) async {
      final copy = await real(tester, () => oldPhoneCopy('Karim'));
      cloud.addCloudCopy(testTenant, 'old-phone', bytes: copy);
      await onThisPhone(tester);
      await pumpPhone(tester);

      await until(tester, find.text('Cloud mein 10-11-2026, 12:00 ki copy rakhi hai. Wapas laane ke liye dabaein.'));
      await tapNow(tester, find.text('Purane phone par is company ka data tha?'));
      await until(tester, find.text('10-11-2026, 12:00'));
      expect(find.text('Cloud mein rakhi copies'), findsOneWidget);
      expect(find.text('${shownSize(copy.length)}, sab se nayi'), findsOneWidget, reason: 'what is there shows without the add-on');
      expect(find.text('Cloud se copy wapas laane ke liye add-on chahiye. Slip bhej kar add-on lein, phir yahan wapas aayein.'), findsOneWidget);
      expect(find.textContaining('end-to-end'), findsNothing);
      await tapNow(tester, find.text('10-11-2026, 12:00'));
      await quiet(tester);
      expect(asked('download'), 0, reason: 'nothing is asked for without the add-on');

      // Plan lein opens set to the add-on alone: the trial goes on, and the add-on is what is missing.
      await tapNow(tester, find.text('Add-on lein'));
      await until(tester, find.text('Small Company Plan'));
      expect(find.text('Sirf add-on chune hue plan ki qeemat par milta hai. Is se plan nahin khulta.'), findsOneWidget, reason: 'the add-on comes first for the owner who came for it');
      await scrollTo(tester, find.text('Cloud add-on: AED 20.00 mahana').first);
      await scrollTo(tester, find.text('Cloud add-on: AED 40.00 mahana'));
      await total(tester, 'AED 20.00', reason: 'the add-on alone, at the price of the plan chosen');
      await scrollTo(tester, find.text('Slip chunein'));
      await tapNow(tester, find.text('Slip chunein'));
      await quiet(tester);
      await tapNow(tester, find.text('Slip bhejein'));
      await until(tester, find.text('Slip chali gayi. Hum bank mein check karenge.'));
      expect(cloud.slips.single['covers'], 'addon');
      expect(cloud.slips.single['expected_fils'], 2000);
      await scrollTo(tester, find.text('Sirf cloud add-on (Small Company Plan), 1 mahina'));

      // The platform finds the payment and accepts the slip; the list asks the cloud again on the way back.
      cloud.addonUntil = DateTime.now().toUtc().add(const Duration(days: 30));
      await tester.tap(find.byType(BackButton));
      await until(tester, find.text('Jo copy wapas laani hai us par dabaein.'));
      expect(find.text('Add-on lein'), findsNothing);
      await tapNow(tester, find.text('10-11-2026, 12:00'));
      await until(tester, find.text('Cloud ki 10-11-2026, 12:00 wali copy'));
      expect(asked('download'), 1);

      // A new phone keeps no backup password, so it is asked; only a cloud copy offers help with a forgotten one.
      await tapNow(tester, find.text('Password yaad nahin?'));
      await until(tester, find.text('Support se rabta karein: support@test.ae'));
      expect(find.textContaining('platform khol kar naye password ke sath aap ko de sakta hai'), findsOneWidget);
      await tapNow(tester, find.descendant(of: inDialog, matching: find.text('Wapas')));
      await quiet(tester);
      await field(tester, 'Backup password', 'pass1234');
      await tapNow(tester, find.text('Backup kholein'));
      await until(tester, find.text('Backup wapas laayein'));
      expect(find.text('Test Labour LLC'), findsOneWidget);
      await tapNow(tester, find.text('Nahin'));
      await tapNow(tester, find.text('Backup wapas laayein'));
      await until(tester, find.text('Data wapas aa gaya'));

      // The cloud's newest copy is this phone's data now, so its next copy goes with nothing asked.
      await tapNow(tester, find.text('Aage'));
      await wait(tester, () => cloud.cloudCopies.last['device_id'] != 'old-phone' && cloud.cloudCopies.last['finished_at_utc'] != null);
      expect(cloud.cloudCopies.last['replace'], isTrue);
      await quiet(tester);
      await goTo(tester, 'Backup');
      expect(find.text('Aakhri cloud copy 15-11-2026, 10:00 ko gayi.'), findsOneWidget);
      expect(find.text('Is phone ka data rakhein'), findsNothing);
      await closePhone(tester);
      final workers = await real(tester, () async {
        final db = live();
        final names = [for (final w in await db.select(db.workers).get()) w.name];
        await db.close();
        return names;
      });
      expect(workers, ['Karim']);
    },
  );

  testWidgets(
    "the list asks for the password when the session is gone, says when another phone is on, and an older copy brought back leaves the other phone's question standing",
    skip: playStoreBuild,
    (tester) async {
      FlutterSecureStorage.setMockInitialValues(
        kept({
          backupPasswordKey(testTenant): 'pass1234',
          cloudCopyKey(testTenant): jsonEncode({'at': null, 'mark': null, 'problem': 'otherPhoneCopy'}),
        }),
      );
      cloud
        ..addCloudCopy(testTenant, 'old-phone', bytes: await real(tester, () => oldPhoneCopy('Karim')), at: '2026-11-08T05:00:00.000Z')
        ..addCloudCopy(testTenant, 'old-phone', bytes: await real(tester, () => oldPhoneCopy('Asif')))
        ..addonUntil = DateTime.now().toUtc().add(const Duration(days: 30));
      await onThisPhone(tester, worker: 'Bilal');
      await pumpPhone(tester, signedIn: false);

      await goTo(tester, 'Backup');
      await tapNow(tester, find.text('Pehle wo data wapas laayein'));
      await until(tester, find.text('Copies dikhayein'));
      await field(tester, 'Password', 'pass1234');
      cloud.offline = true;
      await tapNow(tester, find.text('Copies dikhayein'));
      await until(tester, find.text('Internet nahin mila. Cloud ki copies ke liye internet chahiye.'));

      // Another phone of the account is still on: the cloud refuses the licence, and would refuse the copy.
      cloud
        ..offline = false
        ..licenceRefusal = 'other_phone';
      await tapNow(tester, find.text('Dobara dekhein'));
      await until(tester, find.text('Copies dikhayein'));
      await field(tester, 'Password', 'pass1234');
      await tapNow(tester, find.text('Copies dikhayein'));
      await until(tester, find.text('Is account par ek aur phone chal raha hai. Purana phone band karein.'));
      expect(find.text('Company ke phone'), findsOneWidget);
      expect(find.text('10-11-2026, 12:00'), findsOneWidget, reason: 'what is there still shows');
      expect(find.text('Add-on lein'), findsNothing, reason: 'it is not the add-on that is missing');
      expect(find.textContaining('add-on chahiye'), findsNothing);

      // With the old phone off, the list opens from the restore page too.
      cloud.licenceRefusal = null;
      await tester.tap(find.byType(BackButton));
      await quiet(tester);
      expect(find.textContaining('Backup file chunein, ya cloud mein rakhi copy laayein.'), findsOneWidget);
      await tapNow(tester, find.text('Cloud se laayein'));
      await until(tester, find.text('Jo copy wapas laani hai us par dabaein.'));

      // The older copy, opened by the password this phone keeps. The data here goes to a backup first (D-071).
      await tapNow(tester, find.text('08-11-2026, 09:00'));
      await until(tester, find.text('Pehle abhi wale data ka backup'));
      expect(find.text('Password yaad nahin?'), findsNothing, reason: 'no password was asked');
      await tapNow(tester, find.text('Backup save karein'));
      await until(tester, find.text('Backup wapas laayein'));
      await tapNow(tester, find.text('Nahin'));
      await tapNow(tester, find.text('Backup wapas laayein'));
      await until(tester, find.text('Data wapas aa gaya'));
      await tapNow(tester, find.text('Aage'));
      await quiet(tester);

      // The other phone's newest copy was never seen here, so nothing takes its place unasked.
      expect(asked('start'), 0);
      await goTo(tester, 'Backup');
      expect(find.text('Is phone ka data rakhein'), findsOneWidget);
      await closePhone(tester);
    },
  );

  testWidgets(
    "Settings shows the add-on's end; Plan lein adds it to a plan's total, and alone it goes with the company's own plan (D-076)",
    skip: playStoreBuild,
    (tester) async {
      cloud
        ..licenceState = 'paid'
        ..licencePlanCode = 'mid'
        ..licencePlan = 'Mid Size Company Plan'
        ..licenceWorkers = 35
        ..licenceClients = 9
        ..addonUntil = DateTime.now().toUtc().add(const Duration(days: 20));
      await onThisPhone(tester, worker: 'Bilal');
      await pumpPhone(tester);

      await goTo(tester, 'Settings');
      await until(tester, find.textContaining('Cloud add-on ${showDate(dubaiToday(cloud.addonUntil!))} ko khatam'));
      await tapNow(tester, find.text('Plan lein'));
      await until(tester, find.text('Small Company Plan'));
      expect(find.text('Managers: jald aa raha'), findsWidgets);
      await total(tester, 'AED 199.00', reason: 'the plan alone, as before');
      await tapNow(tester, find.text('Plan ke sath'));
      await quiet(tester);
      await total(tester, 'AED 219.00', reason: 'the new total');

      await tapNow(tester, find.text('Sirf add-on'));
      await quiet(tester);
      expect(find.text('Sirf add-on aap ke maujooda plan (Mid Size Company Plan) ki qeemat par milta hai.'), findsOneWidget);
      await total(tester, 'AED 20.00');
      await tester.scrollUntilVisible(find.text('Large Size Company Plan'), -150, scrollable: find.byType(Scrollable).hitTestable().first);
      await tapNow(tester, find.text('Large Size Company Plan'));
      await quiet(tester);
      await total(tester, 'AED 20.00', reason: "Large's add-on costs 40; the choice stays with the company's own plan");
      await scrollTo(tester, find.text('Slip chunein'));
      await tapNow(tester, find.text('Slip chunein'));
      await quiet(tester);
      await tapNow(tester, find.text('Slip bhejein'));
      await until(tester, find.text('Slip chali gayi. Hum bank mein check karenge.'));
      expect(cloud.slips.single['plan_code'], 'mid');
      expect(cloud.slips.single['covers'], 'addon');
      await scrollTo(tester, find.text('Sirf cloud add-on (Mid Size Company Plan), 1 mahina'));
      await closePhone(tester);
    },
  );

  testWidgets(
    'a Play Store build shows the copies and says the add-on is not available there (BILL-07)',
    skip: !playStoreBuild,
    (tester) async {
      cloud.addCloudCopy(testTenant, 'old-phone', bytes: await real(tester, () => oldPhoneCopy('Karim')));
      await onThisPhone(tester);
      await pumpPhone(tester);
      await until(tester, find.textContaining('Cloud mein 10-11-2026, 12:00 ki copy rakhi hai.'));
      await tapNow(tester, find.text('Purane phone par is company ka data tha?'));
      await until(tester, find.text('10-11-2026, 12:00'));
      expect(find.text('Cloud se copy wapas laane ke liye add-on chahiye. Ye add-on Play Store wali app mein dastyab nahin.'), findsOneWidget);
      expect(find.text('Add-on lein'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await quiet(tester);
      await closePhone(tester);
    },
  );
}
