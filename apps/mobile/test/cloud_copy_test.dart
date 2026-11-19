import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/cloud_copy.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/recovery.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'backup_test.dart' show seed;
import 'cloud_fake.dart';
import 'recovery_test.dart' show manifestOf, publicOf, recoveryOf, testRecoveryPair;
import 'support.dart';

void main() {
  late Directory work;
  late FakeCloud cloud;
  late TenantDatabase db;
  late Account account;
  late SimpleKeyPair pair;
  late DateTime now;
  const storage = FlutterSecureStorage();

  setUp(() async {
    work = await Directory.systemTemp.createTemp('t20d-send');
    FlutterSecureStorage.setMockInitialValues({backupPasswordKey(testTenant): 'pass1234'});
    pair = await testRecoveryPair();
    cloud = FakeCloud()..addUser('owner@test.ae', 'pass1234', company: testTenant);
    account = cloud.account(storage, recoveryKey: await publicOf(pair));
    await account.signIn('owner@test.ae', 'pass1234');
    db = memoryDb();
    await seed(db);
    now = DateTime.utc(2026, 11, 15, 6);
  });

  tearDown(() async {
    await db.close();
    await work.delete(recursive: true);
  });

  CloudSender sender({int limit = cloudCopyLimit}) =>
      CloudSender(account: account, storage: storage, tenantId: testTenant, db: () => db, work: () async => work, clock: () => now, limit: limit);

  int starts() => cloud.calls.where((c) => c.path == '/functions/v1/backup' && c.body['action'] == 'start').length;

  Future<void> change() => db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value('W${starts()}x'), name: const Value('Rafiq')));

  test('the first open sends a copy the recovery key opens; the same day, or an unchanged company, sends nothing more (D-075)', () async {
    final s = sender();
    await s.load();
    await s.sendIfDue();
    expect(cloud.cloudFiles, hasLength(1));
    expect(s.view, (lastAt: DateTime.utc(2026, 11, 15, 6), problem: null, sending: false));
    final copy = cloud.cloudFiles.values.single;
    expect(cloud.cloudCopies.single['replace'], isFalse);
    expect((await checkBackup(copy, 'pass1234', tenantId: testTenant, schemaVersion: db.schemaVersion, work: work)).workers, 1);
    expect(await openCopyKey(recoveryOf(copy), pair, tenantId: testTenant, sha256: manifestOf(copy)['sha256'] as String), hasLength(32));

    now = now.add(const Duration(hours: 5));
    await change();
    await s.sendIfDue();
    expect(starts(), 1, reason: 'once a day at most');

    now = now.add(const Duration(days: 1));
    final again = sender();
    await again.load();
    expect(again.view.lastAt, DateTime.utc(2026, 11, 15, 6), reason: 'kept on the phone');
    await again.sendIfDue();
    expect(starts(), 2, reason: 'a day on, with a change');

    now = now.add(const Duration(days: 2));
    await again.sendIfDue();
    expect(starts(), 2, reason: 'nothing changed since');
  });

  test('a failed try changes nothing and says why; the next try by itself waits an hour', () async {
    final s = sender();
    await s.load();
    await s.sendIfDue();
    now = now.add(const Duration(days: 1));
    await change();
    cloud.offline = true;
    await s.sendIfDue();
    expect(s.view, (lastAt: DateTime.utc(2026, 11, 15, 6), problem: AccountProblem.offline, sending: false));

    cloud.offline = false;
    now = now.add(const Duration(minutes: 30));
    await s.sendIfDue();
    expect(starts(), 1, reason: 'coming back to the app within the hour does not make the copy again');
    now = now.add(const Duration(minutes: 31));
    await s.sendIfDue();
    expect(starts(), 2);
    expect(s.view.problem, isNull);
  });

  test("another phone's copy is never replaced by itself; the owner's choice replaces it (D-076)", () async {
    cloud.addCloudCopy(testTenant, 'old-phone');
    final s = sender();
    await s.load();
    await s.sendIfDue();
    expect(s.view.problem, AccountProblem.otherPhoneCopy);
    expect(cloud.cloudFiles, isEmpty);

    now = now.add(const Duration(days: 1));
    await change();
    final later = sender();
    await later.load();
    await later.sendIfDue();
    expect(starts(), 0, reason: 'the question waits for the owner; this phone never sent a copy, so it asks before the cloud does (BUG-020)');

    await later.sendNow(replace: true);
    expect(cloud.cloudFiles, hasLength(1));
    expect(cloud.cloudCopies.last['replace'], isTrue);
    expect(later.view.problem, isNull);

    // Once this phone has sent, the cloud itself refuses when another phone's copy is newer.
    cloud.addCloudCopy(testTenant, 'old-phone', at: '2026-11-16T08:00:00.000Z');
    now = now.add(const Duration(days: 1));
    await change();
    await later.sendIfDue();
    expect(starts(), 2);
    expect(later.view.problem, AccountProblem.otherPhoneCopy);
  });

  test("after a reinstall the phone's empty company never replaces this same phone's earlier copy by itself (BUG-020)", () async {
    // The phone's id survives a reinstall or clearing the app's data (D-063); the kept record of the copies does not.
    final here = await thisDeviceId(storage);
    cloud.addCloudCopy(testTenant, here, bytes: Uint8List.fromList(List.filled(64, 7)));
    final old = cloud.cloudFiles.keys.single;
    final s = sender();
    await s.load();
    await s.sendIfDue();
    expect(starts(), 0, reason: 'the cloud would take it, as the copy is from this phone, and then remove the real one');
    expect(cloud.cloudFiles.keys, [old]);
    expect(s.view.problem, AccountProblem.otherPhoneCopy, reason: 'the Backup page asks the owner');
    await s.sendNow();
    expect(starts(), 0, reason: 'sending without the choice asks the same');

    await s.sendNow(replace: true);
    expect(cloud.cloudCopies.single['replace'], isTrue, reason: "the owner's choice still replaces it");
    expect(cloud.cloudFiles.keys, isNot(contains(old)));
    expect(s.view.problem, isNull);
  });

  test("once the cloud's newest copy is brought back, this phone's next copy takes its place without the question (D-078)", () async {
    cloud.addCloudCopy(testTenant, 'old-phone');
    final s = sender();
    await s.load();
    await s.sendIfDue();
    expect(s.view.problem, AccountProblem.otherPhoneCopy);

    await s.broughtBack();
    expect(s.view.problem, isNull, reason: 'the question is answered');
    // Kept on the phone, so a restart between the restore and the copy changes nothing.
    final later = sender();
    await later.load();
    await later.sendIfDue();
    expect(cloud.cloudFiles, hasLength(1));
    expect(cloud.cloudCopies.last['replace'], isTrue);

    now = now.add(const Duration(days: 1));
    await change();
    final after = sender();
    await after.load();
    await after.sendIfDue();
    expect(cloud.cloudCopies.last['replace'], isFalse, reason: 'only the one copy');
  });

  test('the owner sees the copies the cloud keeps, newest first, and brings one back only with the add-on (D-072)', () async {
    final s = sender();
    await s.load();
    await s.sendNow();
    final mine = cloud.cloudFiles.values.single;
    cloud.addCloudCopy(testTenant, 'old-phone', at: '2026-11-09T04:00:00.000Z');
    final copies = await account.cloudCopies(testTenant);
    expect(copies.map((c) => c.at), [DateTime.utc(2026, 11, 15, 6), DateTime.utc(2026, 11, 9, 4)]);
    expect(copies.first.sizeBytes, mine.length);

    Future<AccountProblem?> problem() async {
      try {
        await account.downloadCloudCopy(testTenant, copies.first.id);
        return null;
      } on AccountRefused catch (e) {
        return e.problem;
      }
    }

    expect(await problem(), AccountProblem.addonNeeded, reason: 'the cloud decides, not the app');
    cloud.addonUntil = DateTime.now().toUtc().add(const Duration(days: 30));
    cloud.downloadRefusal = 'other_phone';
    expect(await problem(), AccountProblem.otherPhone);
    cloud.downloadRefusal = null;
    expect(await account.downloadCloudCopy(testTenant, copies.first.id), mine);
    cloud.offline = true;
    expect(await problem(), AccountProblem.offline);
  });

  test('the support contact comes from the live settings, and reads as none when blank or unreachable', () async {
    expect(await account.supportContact(), isNull);
    cloud.bank = {...cloud.bank, 'support_contact': ' support@test.ae '};
    expect(await account.supportContact(), 'support@test.ae');
    cloud.offline = true;
    expect(await account.supportContact(), isNull);
  });

  test('a copy over the limit never reaches the cloud, and a refusal the owner must see is kept', () async {
    final small = sender(limit: 1000);
    await small.load();
    await small.sendNow();
    expect(small.view.problem, AccountProblem.tooLarge);
    expect(starts(), 0);

    cloud.backupRefusal = 'not_owner';
    final s = sender();
    await s.load();
    await s.sendNow();
    expect(s.view.problem, AccountProblem.notOwner);
    now = now.add(const Duration(days: 2));
    await change();
    final later = sender();
    await later.load();
    await later.sendIfDue();
    expect(starts(), 1, reason: 'only the owner sends; asking again by itself would not change that');
  });

  test('no password, no session or no recovery key sends nothing; deleting the company forgets the record', () async {
    expect(cloud.account(storage).cloudSender(testTenant, db: () => db, work: () async => work), isNull);
    expect(cloud.account(storage, recoveryKey: 'abc').cloudSender(testTenant, db: () => db, work: () async => work), isNull);
    expect(account.cloudSender(testTenant, db: () => db, work: () async => work), isNotNull);

    await storage.delete(key: backupPasswordKey(testTenant));
    final s = sender();
    await s.load();
    await s.sendIfDue();
    await s.sendNow();
    expect(starts(), 0);

    await storage.write(key: backupPasswordKey(testTenant), value: 'pass1234');
    final signedOut = cloud.account(storage, recoveryKey: await publicOf(pair));
    final idle = CloudSender(account: signedOut, storage: storage, tenantId: testTenant, db: () => db, work: () async => work, clock: () => now);
    await idle.load();
    await idle.sendIfDue();
    expect(starts(), 0);

    await s.sendNow();
    expect(await storage.read(key: cloudCopyKey(testTenant)), isNotNull);
    await deleteTenant(storage, work, testTenant);
    expect(await storage.read(key: cloudCopyKey(testTenant)), isNull);
  });
}
