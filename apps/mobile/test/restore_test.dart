import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/app.dart';
import 'package:labour_app/app/root.dart';
import 'package:labour_app/app/settings.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/restore.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';

import 'cloud_fake.dart';
import 'support.dart';
import 'timesheets_test.dart' as ts;

Future<void> addWorker(TenantDatabase db, String name) =>
    db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value(name), name: Value(name)));

Future<List<String>> names(TenantDatabase db) async => [for (final w in await db.select(db.workers).get()) w.name];

void main() {
  late Directory work;

  setUp(() async => work = await Directory.systemTemp.createTemp('t20b'));
  tearDown(() => work.delete(recursive: true));

  TenantDatabase open(File file, String key) => openTenantDatabase(file, key, tenantId: testTenant, deviceId: 'device-1');

  test("a backup comes back under the phone's own key, then swaps in with the old data kept aside (DATA-05, DATA-07)", () async {
    final oldKey = newHexKey();
    final source = open(File('${work.path}/old-phone.db'), oldKey);
    await seedProfile(source);
    await addWorker(source, 'Karim');
    final bytes = await source.backupBytes('pass1234', work: work);
    await source.close();

    // The new phone has its own key and, here, some data of its own.
    final key = newHexKey();
    final live = open(tenantFile(work, testTenant), key);
    await addWorker(live, 'Bilal');
    await live.close();

    final into = restoringFile(work, testTenant);
    await unlockBackup(bytes, 'pass1234', into, key);
    final prepared = open(into, key);
    expect(await names(prepared), ['Karim'], reason: 'the backup opens with the phone key alone');
    expect((await prepared.restoredSummary()), (companyName: 'Test Labour LLC', workers: 1, invoices: 0));
    await prepared.close();
    expect(await File(into.path).readAsBytes().then((b) => String.fromCharCodes(b).contains('Karim')), isFalse, reason: 'still locked');

    await swapIn(work, testTenant, keep: true);
    expect(into.existsSync(), isFalse);
    final after = open(tenantFile(work, testTenant), key);
    expect(await names(after), ['Karim']);
    await after.close();
    final kept = open(keptFile(work, testTenant), key);
    expect(await names(kept), ['Bilal'], reason: 'what the phone had is kept, under its key');
    await kept.close();

    // Undo: the kept copy comes back the same way, and what replaced it is kept in turn.
    await keptFile(work, testTenant).copy(into.path);
    await swapIn(work, testTenant, keep: true);
    final back = open(tenantFile(work, testTenant), key);
    expect(await names(back), ['Bilal']);
    await back.close();
    final keptAgain = open(keptFile(work, testTenant), key);
    expect(await names(keptAgain), ['Karim']);
    await keptAgain.close();

    // Nothing worth keeping: an older copy goes, so it is never offered as the data a restore replaced.
    await File(tenantFile(work, testTenant).path).copy(into.path);
    await swapIn(work, testTenant, keep: false);
    expect(keptFile(work, testTenant).existsSync(), isFalse);

    // Deleting the company takes every copy.
    await File(tenantFile(work, testTenant).path).copy(into.path);
    await File(tenantFile(work, testTenant).path).copy(keptFile(work, testTenant).path);
    FlutterSecureStorage.setMockInitialValues({});
    await deleteTenant(const FlutterSecureStorage(), work, testTenant);
    expect(work.listSync().where((f) => f.path.contains(testTenant)), isEmpty);
  });

  test('numbers given that a restored file has no record of are never given again (DATA-06)', () async {
    final db = memoryDb();
    addTearDown(db.close);
    await ts.seed(db);
    final year = DateTime.now().toUtc().add(const Duration(hours: 4)).year;

    expect(await db.lastNumbers(year), isEmpty);
    await db.recordRestore(
      from: 'backup',
      year: year,
      phone: {'invoice': 12, 'payslip': 3},
      owner: {'invoice': 14, 'timesheet': 4, 'credit': 0},
      operationId: 'op-1',
    );
    // A retry changes nothing.
    await db.recordRestore(from: 'backup', year: year, phone: {'invoice': 30}, owner: const {}, operationId: 'op-1');
    expect(await db.lastNumbers(year), {'invoice': 14, 'payslip': 3, 'timesheet': 4});
    expect((await db.select(db.numberFloors).get()).map((f) => (f.series, f.seq, f.source)), unorderedEquals([('invoice', 12, 'phone'), ('payslip', 3, 'phone'), ('invoice', 14, 'owner'), ('timesheet', 4, 'owner')]));
    expect(await db.nextNumber('invoice', year, 9), 15);
    expect(await db.nextNumber('invoice', year, 20), 21, reason: 'a number given since goes on from itself');
    expect(await db.nextNumber('invoice', year + 1, null), 1, reason: 'a floor holds for its own year');
    expect(await db.nextNumber('credit', year, null), 1);

    // Through the real paths: the timesheet and the invoice take the next number past their floor.
    await ts.work(db, '2020-10-05');
    final sheet = await db.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
    expect((await db.timesheetView(sheet)).sheet.number, 'TS-$year-0005');
    final invoice = await db.createInvoice(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
    await db.issueInvoice(invoice, describe: (_) => 'Manpower', operationId: newUuid());
    expect((await db.select(db.invoices).getSingle()).number, invoiceNumber('INV', year, 15));

    await expectLater(db.customStatement('UPDATE number_floors SET seq = 1'), throwsA(anything), reason: 'a floor stays on record');
    await expectLater(db.customStatement('DELETE FROM number_floors'), throwsA(anything));
    expect(seriesPrefix('payslip', 2026, invoicePrefix: 'INV'), 'SLIP-2026-');
    expect(seriesPrefix('invoice', 2026, invoicePrefix: 'FAJR'), 'FAJR-2026-');
    expect(DocKind.values.map((k) => k.name), containsAll(numberSeries.skip(3)));
  });

  group('through the screens', () {
    late Directory dir;
    late Directory cache;
    late String key;
    late Uint8List backup;
    Uint8List? picked;
    final year = DateTime.now().toUtc().add(const Duration(hours: 4)).year;
    const binding = (tenantId: testTenant, userId: 'user-1', email: 'owner@test.ae');

    /// A file database answers on the real clock, and a spinner never lets the screen settle, so this waits it out.
    Future<void> quiet(WidgetTester tester) async {
      final spinning = find.byWidgetPredicate((w) => w is ProgressIndicator);
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (spinning.evaluate().isEmpty) break;
      }
      await settle(tester);
    }

    /// The old phone's company: Asif and Bilal at Emaar, one timesheet and one invoice.
    Future<Uint8List> oldPhoneBackup() async {
      final old = openTenantDatabase(File('${work.path}/old-phone.db'), newHexKey(), tenantId: testTenant, deviceId: 'old-phone');
      await ts.seed(old);
      await ts.work(old, '2020-10-05');
      final sheet = await old.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      await old.approveTimesheet((await old.timesheetView(sheet)).revision.id, operationId: newUuid());
      final invoice = await old.createInvoice(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      await old.issueInvoice(invoice, describe: (_) => 'Manpower', operationId: newUuid());
      final bytes = await old.backupBytes('pass1234', work: work);
      await old.close();
      return bytes;
    }

    TenantDatabase live() => openTenantDatabase(tenantFile(dir, testTenant), key, tenantId: testTenant, deviceId: 'device-1', actorId: 'user-1');

    /// The file the app has open, closed at the end so the folder can go.
    late TenantDatabase open;
    TenantDatabase opening() => open = live();

    Future<void> setUpPhone(WidgetTester tester) async {
      dir = Directory('${work.path}/phone')..createSync();
      cache = Directory('${work.path}/cache')..createSync();
      key = newHexKey();
      backup = (await tester.runAsync(oldPhoneBackup))!;
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      const files = MethodChannel('labour_app/files');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async => cache.path);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, (call) async => call.method == 'pickBackup' ? picked : null);
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, null);
      });
    }

    Future<void> pumpPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      await tester.pumpWidget(
        AppRoot(
          account: FakeCloud().account(const FlutterSecureStorage()),
          lock: FakeLock(const FlutterSecureStorage()),
          opened: (db: opening(), binding: binding),
          settings: const AppSettings(),
          loadSettings: () => AppSettings.load(const FlutterSecureStorage()),
          deleteTenant: (_) async {},
          openTenant: (tenantId, {required actorId}) async => opening(),
          files: (dir: dir, key: (_) async => key),
        ),
      );
      await quiet(tester);
    }

    /// Unlocking and opening run on the real clock, behind a moving progress bar, so this waits for [target].
    Future<void> until(WidgetTester tester, Finder target) async {
      for (var i = 0; i < 150 && target.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
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

    /// The company's file as the phone holds it once the app is gone.
    Future<(List<String>, Map<String, int>)> onPhone(WidgetTester tester) async {
      // The day page's sums read on the real clock; they finish before the file closes.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      return (await tester.runAsync(() async {
        await open.close();
        final db = live();
        final found = (await names(db), await db.lastNumbers(year));
        await db.close();
        return found;
      }))!;
    }

    testWidgets("a new phone's empty company offers the old phone's backup, asks about later numbers, and opens it (DATA-05, DATA-06)", (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await setUpPhone(tester);
      // The company opened here with nothing in it yet. Made on the real clock, as drift can't make a file on the fake one.
      await tester.runAsync(() async {
        final db = live();
        await db.lastNumbers(year);
        await db.close();
      });
      await pumpPhone(tester);
      expect(find.text('Purane phone par is company ka data tha?'), findsOneWidget, reason: 'the company opened with no data here');
      await tapNow(tester, find.text('Purane phone par is company ka data tha?'));
      await quiet(tester);
      expect(find.textContaining('alag rakha jayega'), findsOneWidget);

      picked = Uint8List.fromList('name,phone\nKarim,050'.codeUnits);
      await tapNow(tester, find.text('Backup file chunein'));
      expect(find.text('Ye file is app ki backup nahin.'), findsOneWidget, reason: 'turned away before any password');

      picked = backup;
      await tapNow(tester, find.text('Backup file chunein'));
      await until(tester, find.text('Backup password'));
      expect(find.text('Ye password is backup ka nahin.'), findsNothing, reason: 'with no password kept, it only asks');
      await field(tester, 'Backup password', 'wrongpass1');
      await tapNow(tester, find.text('Backup kholein'));
      await until(tester, find.text('Ye password is backup ka nahin.'));
      await field(tester, 'Backup password', 'pass1234');
      await tapNow(tester, find.text('Backup kholein'));
      await until(tester, find.text('Backup wapas laayein'));

      expect(find.text('Test Labour LLC'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'two workers');
      expect(find.textContaining('alag rakh diya jayega'), findsNothing, reason: 'this phone has nothing to set aside');
      expect(find.text('1'), findsOneWidget, reason: 'one invoice');
      await tapNow(tester, find.text('Backup wapas laayein'));
      expect(find.text('Pehle is sawal ka jawab dein.'), findsOneWidget, reason: 'the numbers are reviewed every time');

      await tapNow(tester, find.text('Haan, diye the'));
      expect(find.text('Backup mein aakhri: INV-$year-0001'), findsOneWidget);
      expect(find.text('Backup mein aakhri: TS-$year-0001'), findsOneWidget);
      expect(find.text('Backup mein is saal koi nahin'), findsNWidgets(5));
      await field(tester, 'Aakhri invoice', '0');
      await tapNow(tester, find.text('Backup wapas laayein'));
      expect(find.text('Sirf number likhein, jaise 12.'), findsOneWidget);
      await field(tester, 'Aakhri invoice', '3');
      await field(tester, 'Aakhri salary slip', '7');
      await tapNow(tester, find.text('Backup wapas laayein'));
      await until(tester, find.text('Data wapas aa gaya'));
      expect(find.text('Test Labour LLC: 2 mazdoor, 1 invoice.'), findsOneWidget);
      expect(find.textContaining('Pehle wala data'), findsNothing, reason: 'nothing was here to keep');
      expect(keptFile(dir, testTenant).existsSync(), isFalse);
      expect(restoringFile(dir, testTenant).existsSync(), isFalse);

      await tapNow(tester, find.text('Aage'));
      await quiet(tester);
      expect(find.byType(LabourApp), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget, reason: 'the company has its details again');
      expect(await const FlutterSecureStorage().read(key: backupPasswordKey(testTenant)), 'pass1234', reason: 'the next backup needs no typing');
      final (workers, numbers) = await onPhone(tester);
      expect(workers, unorderedEquals(['Asif', 'Bilal']));
      expect(numbers, {'invoice': 3, 'timesheet': 1, 'payslip': 7}, reason: 'the next invoice is the 4th, the next slip the 8th');
    });

    testWidgets('on the same phone the kept password opens it, the data there is kept aside, and comes back (D-070)', (tester) async {
      FlutterSecureStorage.setMockInitialValues({backupPasswordKey(testTenant): 'pass1234'});
      await setUpPhone(tester);
      await tester.runAsync(() async {
        final db = live();
        await db.saveRow(db.tenantProfiles, id: null, operationId: newUuid(), fields: const TenantProfilesCompanion(legalName: Value('Test Labour LLC')));
        await addWorker(db, 'Naya');
        await db.close();
      });
      await pumpPhone(tester);
      await tester.tap(find.text('Menu'));
      await quiet(tester);
      await tester.tap(find.text('Backup'));
      await quiet(tester);
      expect(find.text('Restore se pehle wala data'), findsNothing);
      await tapNow(tester, find.text('Backup se data wapas laana'));
      await quiet(tester);

      picked = backup;
      await tapNow(tester, find.text('Backup file chunein'));
      await until(tester, find.text('Backup wapas laayein'));
      expect(find.text('Backup password'), findsNothing, reason: 'the kept password opened it');
      expect(find.textContaining('alag rakh diya jayega'), findsOneWidget);
      await tapNow(tester, find.text('Nahin'));
      await tapNow(tester, find.text('Backup wapas laayein'));
      await until(tester, find.text('Data wapas aa gaya'));
      expect(find.textContaining('Pehle wala data is phone par alag rakha hai.'), findsOneWidget);
      await tapNow(tester, find.text('Aage'));
      await quiet(tester);

      await tester.tap(find.text('Menu'));
      await quiet(tester);
      await tester.tap(find.text('Backup'));
      await quiet(tester);
      await tapNow(tester, find.text('Restore se pehle wala data'));
      await until(tester, find.text('Ye data wapas laayein'));
      expect(find.text('1'), findsOneWidget, reason: 'Naya alone');
      expect(find.textContaining('Is backup ke baad'), findsNothing, reason: "this phone's own numbers carry over by themselves");
      await tapNow(tester, find.text('Ye data wapas laayein'));
      await until(tester, find.text('Data wapas aa gaya'));
      expect(find.text('Test Labour LLC: 1 mazdoor, 0 invoice.'), findsOneWidget);
      await tapNow(tester, find.text('Aage'));
      await quiet(tester);

      final (workers, numbers) = await onPhone(tester);
      expect(workers, ['Naya']);
      expect(numbers, {'invoice': 1, 'timesheet': 1}, reason: 'the backup had given these, so the data from before goes past them');
    });
  });
}
