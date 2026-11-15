import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/backup.dart';
import 'package:labour_app/data/recovery.dart';

import 'backup_test.dart' show Problem, otherTenant, seed;
import 'support.dart';

/// A throwaway recovery key, made from a fixed seed so every run seals to the same public half.
Future<SimpleKeyPair> testRecoveryPair() => X25519().newKeyPairFromSeed(List.filled(32, 9));

Future<String> publicOf(SimpleKeyPair pair) async => base64.encode((await pair.extractPublicKey()).bytes);

Map<String, dynamic> recoveryOf(Uint8List copy) =>
    jsonDecode(utf8.decode(ZipDecoder().decodeBytes(copy).findFile(recoveryFile)!.content)) as Map<String, dynamic>;

Map<String, dynamic> manifestOf(Uint8List copy) =>
    jsonDecode(utf8.decode(ZipDecoder().decodeBytes(copy).findFile('manifest.json')!.content)) as Map<String, dynamic>;

void main() {
  late Directory work;

  setUp(() async => work = await Directory.systemTemp.createTemp('t20d'));
  tearDown(() => work.delete(recursive: true));

  test('the copy key worked out from the password opens the real backup, and another password\'s does not (DATA-07)', () async {
    final db = memoryDb();
    await seed(db);
    final bytes = await db.backupBytes('pass1234', work: work);
    await db.close();
    final data = ZipDecoder().decodeBytes(bytes).findFile('data.db')!.content;
    final file = File('${work.path}/copy.db')..writeAsBytesSync(data);

    final key = await copyKey('pass1234', data);
    expect(key, hasLength(32));
    expect(opensWithKey(file.path, key), isTrue);
    expect(opensWithKey(file.path, await copyKey('pass12345', data)), isFalse);
  });

  test('a cloud copy carries its key sealed to the recovery key, and only that key opens it, only for this copy (DATA-08)', () async {
    final pair = await testRecoveryPair();
    final db = memoryDb();
    await seed(db);
    final copy = await db.backupBytes('pass1234', work: work, recoveryKey: await publicOf(pair));
    await db.close();

    final zip = ZipDecoder().decodeBytes(copy);
    expect(zip.files.map((f) => f.name), unorderedEquals(['manifest.json', 'data.db', recoveryFile]));
    expect((await checkBackup(copy, 'pass1234', tenantId: testTenant, schemaVersion: db.schemaVersion, work: work)).workers, 1,
        reason: 'the restore reads a cloud copy as it reads a file');
    final sealed = recoveryOf(copy);
    expect(sealed, containsPair('alg', 'X25519-HKDF-SHA256-ChaCha20-Poly1305'));
    final sha = manifestOf(copy)['sha256'] as String;

    final key = await openCopyKey(sealed, pair, tenantId: testTenant, sha256: sha);
    final file = File('${work.path}/copy.db')..writeAsBytesSync(zip.findFile('data.db')!.content);
    expect(opensWithKey(file.path, key), isTrue);

    final stranger = await X25519().newKeyPairFromSeed(List.filled(32, 8));
    for (final open in [
      () => openCopyKey(sealed, stranger, tenantId: testTenant, sha256: sha),
      () => openCopyKey(sealed, pair, tenantId: otherTenant, sha256: sha),
      () => openCopyKey(sealed, pair, tenantId: testTenant, sha256: '0' * 64),
      () => openCopyKey({...sealed, 'v': 2}, pair, tenantId: testTenant, sha256: sha),
    ]) {
      await expectLater(open(), throwsA(isA<RecoveryRefused>()));
    }
  });

  test('only a real public half counts as the recovery key', () async {
    expect(isRecoveryKey(await publicOf(await testRecoveryPair())), isTrue);
    for (final bad in ['', 'abc', base64.encode(List.filled(31, 1)), 'not base64 at all!']) {
      expect(isRecoveryKey(bad), isFalse, reason: bad);
    }
  });

  test('the key file opens with its passphrase only, and holds no private bytes in the clear', () async {
    final pair = await testRecoveryPair();
    final file = await lockRecoveryKey(pair, 'a long passphrase 1');
    final text = jsonEncode(file);
    final private = await pair.extractPrivateKeyBytes();
    expect(text.contains(base64.encode(private)), isFalse);
    expect(file['public'], await publicOf(pair));

    final back = await unlockRecoveryKey(jsonDecode(text) as Map<String, dynamic>, 'a long passphrase 1');
    expect(await back.extractPrivateKeyBytes(), private);
    await expectLater(unlockRecoveryKey(file, 'a long passphrase 2'), throwsA(isA<RecoveryRefused>()));
  });

  test('the key file is never written inside a git checkout', () {
    final repo = Directory('${work.path}/repo/.git')..createSync(recursive: true);
    final inside = Directory('${repo.parent.path}/keys/deep')..createSync(recursive: true);
    expect(insideGitCheckout(inside), isTrue);
    expect(insideGitCheckout(Directory('${work.path}/elsewhere')..createSync()), isFalse);
  });

  test('the owner\'s tool turns a cloud copy into an ordinary backup with a new password (D-072)', () async {
    final pair = await testRecoveryPair();
    final db = memoryDb();
    await seed(db);
    final copy = await db.backupBytes('forgotten1', work: work, recoveryKey: await publicOf(pair));
    final saved = await db.backupBytes('forgotten1', work: work);
    await db.close();

    final opened = await reopenCloudCopy(copy, pair, 'newpass99', work);
    expect(ZipDecoder().decodeBytes(opened).files.map((f) => f.name), unorderedEquals(['manifest.json', 'data.db']),
        reason: 'what goes back to the company is an ordinary backup');
    expect(manifestOf(opened)['createdAtUtc'], manifestOf(copy)['createdAtUtc']);
    final summary = await checkBackup(opened, 'newpass99', tenantId: testTenant, schemaVersion: db.schemaVersion, work: work);
    expect(summary.workers, 1);
    expect(summary.companyName, 'Test Labour LLC');
    try {
      await checkBackup(opened, 'forgotten1', tenantId: testTenant, schemaVersion: db.schemaVersion, work: work);
      fail('the old password still opened it');
    } on BackupRefused catch (e) {
      expect(Problem(e.problem), const Problem(BackupProblem.wrongPassword));
    }
    await expectLater(reopenCloudCopy(saved, pair, 'newpass99', work), throwsA(isA<RecoveryRefused>()),
        reason: 'a saved file carries no sealed key');
    expect(work.listSync(), isEmpty, reason: 'nothing is left behind');
  });
}
