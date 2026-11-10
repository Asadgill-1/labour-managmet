import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

const otherTenant = '00000000-0000-4000-8000-00000000000b';

Future<void> seed(TenantDatabase db) async {
  await seedProfile(db);
  await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Karim')));
}

/// The zip with data.db swapped for [data], its label left as it was.
Uint8List withData(Uint8List backup, Uint8List data) {
  final old = ZipDecoder().decodeBytes(backup);
  return ZipEncoder().encodeBytes(
    Archive()
      ..addFile(ArchiveFile.bytes('manifest.json', old.findFile('manifest.json')!.content))
      ..addFile(ArchiveFile.noCompress('data.db', data.length, data)),
  );
}

void main() {
  late Directory work;

  setUp(() async => work = await Directory.systemTemp.createTemp('t20a'));
  tearDown(() => work.delete(recursive: true));

  Future<Problem?> problem(Future<void> Function() run) async {
    try {
      await run();
      return null;
    } on BackupRefused catch (e) {
      return Problem(e.problem);
    }
  }

  test('a backup of the encrypted file opens with its password alone, and says whose it is (DATA-02, DATA-07)', () async {
    final key = newHexKey();
    final db = openTenantDatabase(tenantFile(work, testTenant), key, tenantId: testTenant, deviceId: 'device-1');
    await seed(db);
    final bytes = await db.backupBytes("it's a 2nd pass", work: work, now: DateTime.utc(2026, 11, 10, 10, 30));

    final zip = ZipDecoder().decodeBytes(bytes);
    expect(zip.files.map((f) => f.name), unorderedEquals(['manifest.json', 'data.db']));
    final manifest = jsonDecode(utf8.decode(zip.findFile('manifest.json')!.content)) as Map<String, dynamic>;
    expect(manifest, containsPair('tenantId', testTenant));
    expect(manifest, containsPair('schemaVersion', db.schemaVersion));
    expect(manifest, containsPair('createdAtUtc', '2026-11-10T10:30:00.000Z'));
    final data = zip.findFile('data.db')!.content;
    expect(utf8.decode(data.sublist(0, 15), allowMalformed: true), isNot('SQLite format 3'), reason: 'the database is locked');
    for (final secret in ["it's a 2nd pass", key]) {
      expect(latin1.decode(bytes).contains(secret), isFalse, reason: 'neither the password nor the phone key is in the file');
    }

    final summary = await checkBackup(bytes, "it's a 2nd pass", tenantId: testTenant, schemaVersion: db.schemaVersion, work: work);
    expect(summary.companyName, 'Test Labour LLC');
    expect(summary.workers, 1);
    expect(summary.manifest.createdAtUtc, DateTime.utc(2026, 11, 10, 10, 30));

    expect((await db.select(db.workers).get()).single.name, 'Karim', reason: 'the open company is untouched');
    await db.close();
    expect(work.listSync().map((f) => f.path.split(Platform.pathSeparator).last), ['tenant_$testTenant.db'], reason: 'no copy is left behind');
  });

  test('a backup that cannot be used is refused, and says why (DATA-05)', () async {
    final db = memoryDb();
    await seed(db);
    final bytes = await db.backupBytes('pass1234', work: work);
    Future<void> check(Uint8List file, {String password = 'pass1234', String tenant = testTenant, int? schema}) =>
        checkBackup(file, password, tenantId: tenant, schemaVersion: schema ?? db.schemaVersion, work: work);

    expect(await problem(() => check(bytes, password: 'wrong999')), const Problem(BackupProblem.wrongPassword));
    expect(await problem(() => check(bytes, tenant: otherTenant)), const Problem(BackupProblem.otherCompany));
    expect(await problem(() => check(bytes, schema: db.schemaVersion - 1)), const Problem(BackupProblem.newerApp));
    expect(await problem(() => check(Uint8List.fromList(utf8.encode('Code,Name\nW1,Ali\n')))), const Problem(BackupProblem.notBackup));
    final data = ZipDecoder().decodeBytes(bytes).findFile('data.db')!.content;
    final hurt = Uint8List.fromList(data)..[data.length - 100] ^= 0xff;
    expect(await problem(() => check(withData(bytes, hurt))), const Problem(BackupProblem.damaged));
    expect(await problem(() => check(bytes)), isNull);
    expect(work.listSync(), isEmpty, reason: 'checking leaves nothing behind');
    await db.close();
  });

  test('the phone keeps the password and the last backup, and forgets both with the company (D-069, AUTH-07)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    const store = BackupStore(storage, testTenant);
    expect(await store.password(), isNull);
    expect(await store.last(), isNull);
    await store.setPassword('pass1234');
    await store.record(sent: true, now: DateTime.utc(2026, 11, 10, 9));
    expect(await store.password(), 'pass1234');
    expect(await store.last(), (at: DateTime.utc(2026, 11, 10, 9), sent: true));
    expect(await const BackupStore(storage, otherTenant).password(), isNull, reason: 'each company has its own');

    await deleteTenant(storage, work, testTenant);
    expect(await store.password(), isNull);
    expect(await store.last(), isNull);
  });
  testWidgets('the day page asks for a backup once there are workers; the first one sets the password, then saves where the user chooses (DATA-03, DATA-04)', (tester) async {
    final db = memoryDb();
    final cache = Directory.systemTemp.createTempSync('t20a-cache');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const files = MethodChannel('labour_app/files');
    Uint8List? saved;
    var saveAnswer = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, (_) async => cache.path);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, (call) async {
      if (call.method != 'save') return null;
      saved = File((call.arguments as Map)['path'] as String).readAsBytesSync();
      return saveAnswer;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(paths, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(files, null);
      cache.deleteSync(recursive: true);
    });
    final empty = memoryDb();
    await real(tester, () => seedProfile(empty));
    await pumpApp(tester, empty);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Abhi tak backup nahin bana'), findsNothing, reason: 'an empty company has nothing to lose yet');
    await shutDown(tester, empty);
    await real(tester, () => seed(db));
    await pumpApp(tester, db);

    await tester.tap(find.text('Abhi tak backup nahin bana'));
    await settle(tester);
    expect(find.textContaining('Dobara login karne se bhi data wapas nahin aata.'), findsOneWidget);
    expect(find.text('Abhi tak koi backup nahin bana.'), findsOneWidget);
    expect(find.text('Backup save karein'), findsNothing, reason: 'the password comes first');
    Future<void> passwords(String one, String two) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Backup password'), one);
      await tester.enterText(find.widgetWithText(TextFormField, 'Backup password dobara'), two);
      await tester.tap(find.text('Ye password rakhein'));
      await settle(tester);
    }

    // The progress bar moves while the password is stretched, so wait on the real clock, not for the screen to settle.
    Future<void> untilSaved() async {
      for (var i = 0; i < 100 && saved == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      for (var i = 0; i < 20 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await settle(tester);
    }

    await passwords('short', 'short');
    expect(find.text('Kam az kam 8 huroof rakhein, harf aur number dono.'), findsOneWidget);
    await passwords('pass1234', 'pass12345');
    expect(find.text('Dono password ek jaise nahin.'), findsOneWidget);
    await passwords('pass1234', 'pass1234');
    expect(find.text('Backup password rakh liya'), findsOneWidget);

    // Closing the save screen saves nothing.
    await tester.tap(find.text('Backup save karein'));
    await untilSaved();
    expect(find.text('Abhi tak koi backup nahin bana.'), findsOneWidget);

    saved = null;
    saveAnswer = true;
    await tester.tap(find.text('Backup save karein'));
    await untilSaved();
    expect(find.text('Backup save ho gaya'), findsOneWidget);
    expect(find.textContaining('ko save hua.'), findsOneWidget);
    final summary = await real(tester, () => checkBackup(saved!, 'pass1234', tenantId: testTenant, schemaVersion: db.schemaVersion, work: cache));
    expect(summary.workers, 1);
    expect(summary.companyName, 'Test Labour LLC');

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Abhi tak backup nahin bana'), findsNothing);
    await shutDown(tester, db);
  });

  testWidgets('a week after the last backup the day page asks again, and not before; the menu opens Backup (D-069)', (tester) async {
    final db = memoryDb();
    await real(tester, () => seed(db));
    String daysAgo(int days) => jsonEncode({'at': DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String(), 'how': 'sent'});
    await pumpApp(tester, db, stored: {backupLastKey(testTenant): daysAgo(8)});
    expect(find.text('8 din se backup nahin bana'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, db, stored: {backupLastKey(testTenant): daysAgo(2), backupPasswordKey(testTenant): 'pass1234'});
    expect(find.textContaining('se backup nahin bana'), findsNothing);
    await tester.tap(find.text('Menu'));
    await settle(tester);
    await tester.tap(find.text('Backup'));
    await settle(tester);
    expect(find.textContaining('ko bhejne ke liye diya.'), findsOneWidget);
    expect(find.text('Backup save karein'), findsOneWidget, reason: 'the kept password needs no typing');
    expect(find.text('Backup se data wapas laana'), findsOneWidget);
    await shutDown(tester, db);
  });
}

class Problem {
  const Problem(this.problem);

  final BackupProblem problem;

  @override
  bool operator ==(Object other) => other is Problem && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() => problem.name;
}
