import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';

/// The platform's second lock on each cloud copy (D-072, T20d). A cloud copy is the backup zip of D-069 plus
/// `recovery.json`: the copy's own SQLCipher key, sealed to the platform's recovery key. The app holds only that key's
/// public half (`RECOVERY_KEY`); the private half stays offline with the owner, who opens a copy with
/// `tool/recovery_key.dart` for a company that forgot its backup password. A file the user saves carries no seal, so the
/// platform can open only what reached the cloud. No Flutter import here, so the owner's tool runs with `dart run`.
const recoveryFile = 'recovery.json';

/// SQLCipher 4's own stretching of the backup password: PBKDF2-HMAC-SHA512 over the file's first 16 bytes.
const copyKeyRounds = 256000;

/// The private half's lock on the owner's computer, which can afford more rounds than a phone.
const keyFileRounds = 600000;

const _alg = 'X25519-HKDF-SHA256-ChaCha20-Poly1305';
const _locked = "PRAGMA cipher = 'sqlcipher'; PRAGMA legacy = 4;";
const _keyFileKind = 'labour-app recovery key';

/// A sealed key or a key file that does not open: the wrong key or passphrase, another copy, or a damaged file.
class RecoveryRefused implements Exception {
  const RecoveryRefused(this.reason);

  final String reason;

  @override
  String toString() => 'RecoveryRefused($reason)';
}

/// True for the base64 of a 32-byte public half, so a mistyped `RECOVERY_KEY` makes no copy instead of a useless one.
bool isRecoveryKey(String text) {
  try {
    return base64.decode(text).length == 32;
  } on FormatException {
    return false;
  }
}

List<int> _random(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256));
}

String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

Future<Uint8List> _stretch(String secret, List<int> salt, int rounds) async {
  final key = await Pbkdf2(macAlgorithm: Hmac.sha512(), iterations: rounds, bits: 256).deriveKeyFromPassword(password: secret, nonce: salt);
  return Uint8List.fromList(await key.extractBytes());
}

/// The key SQLCipher derives from [password] for [data], a `data.db` locked in SQLCipher 4's format. It takes a few
/// seconds, so it runs off the calling isolate.
Future<Uint8List> copyKey(String password, List<int> data) {
  final salt = data.sublist(0, 16);
  return Isolate.run(() => _stretch(password, salt, copyKeyRounds));
}

/// Whether [key] itself, with no stretching, opens the SQLCipher file at [path].
bool opensWithKey(String path, List<int> key) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    db.execute(_locked);
    db.execute('PRAGMA key = "x\'${_hex(key)}\'"');
    db.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on SqliteException {
    return false;
  } finally {
    db.close();
  }
}

/// Binds a seal to one copy of one company, so it opens no other.
List<int> _bound(String tenantId, String sha256) => utf8.encode('${tenantId.toLowerCase()}:$sha256');

Future<SecretKey> _wrapKey(SimpleKeyPair mine, List<int> theirs, List<int> epk, List<int> recoveryPublic, List<int> bound) async {
  final shared = await X25519().sharedSecretKey(keyPair: mine, remotePublicKey: SimplePublicKey(theirs, type: KeyPairType.x25519));
  return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: utf8.encode('labour-app recovery v1'),
    info: [...epk, ...recoveryPublic, ...bound],
  );
}

/// [key] sealed to the recovery key's public half: a key pair made for this seal alone, its shared secret with the
/// recovery key stretched by HKDF, and ChaCha20-Poly1305 over the key, bound to [tenantId] and the data's [sha256].
Future<Map<String, Object>> sealCopyKey(List<int> key, String recoveryPublic, {required String tenantId, required String sha256}) async {
  final public = base64.decode(recoveryPublic);
  final once = await X25519().newKeyPair();
  final epk = (await once.extractPublicKey()).bytes;
  final bound = _bound(tenantId, sha256);
  final box = await Chacha20.poly1305Aead().encrypt(key, secretKey: await _wrapKey(once, public, epk, public, bound), aad: bound);
  return {
    'v': 1,
    'alg': _alg,
    'epk': base64.encode(epk),
    'nonce': base64.encode(box.nonce),
    'ct': base64.encode(box.cipherText),
    'mac': base64.encode(box.mac.bytes),
  };
}

/// The copy key in [sealed], opened with the recovery key [pair]. Throws [RecoveryRefused] for another key, another
/// company or another copy.
Future<Uint8List> openCopyKey(Map<String, dynamic> sealed, SimpleKeyPair pair, {required String tenantId, required String sha256}) async {
  if (sealed['v'] != 1 || sealed['alg'] != _alg) throw const RecoveryRefused('a sealed key this tool does not read');
  try {
    final epk = base64.decode(sealed['epk'] as String);
    final public = (await pair.extractPublicKey()).bytes;
    final bound = _bound(tenantId, sha256);
    final box = SecretBox(
      base64.decode(sealed['ct'] as String),
      nonce: base64.decode(sealed['nonce'] as String),
      mac: Mac(base64.decode(sealed['mac'] as String)),
    );
    return Uint8List.fromList(await Chacha20.poly1305Aead().decrypt(box, secretKey: await _wrapKey(pair, epk, epk, public, bound), aad: bound));
  } catch (_) {
    throw const RecoveryRefused('the recovery key does not open this copy');
  }
}

/// The recovery key's private half locked with [passphrase], for a file on the owner's computer. The public half is
/// kept beside it in the clear, so the owner can check which key a file holds.
Future<Map<String, Object>> lockRecoveryKey(SimpleKeyPair pair, String passphrase) async {
  final salt = _random(16);
  final lock = await Isolate.run(() => _stretch(passphrase, salt, keyFileRounds));
  final box = await Chacha20.poly1305Aead().encrypt(await pair.extractPrivateKeyBytes(), secretKey: SecretKey(lock), aad: utf8.encode(_keyFileKind));
  return {
    'v': 1,
    'kind': _keyFileKind,
    'public': base64.encode((await pair.extractPublicKey()).bytes),
    'kdf': 'PBKDF2-HMAC-SHA512',
    'rounds': keyFileRounds,
    'salt': base64.encode(salt),
    'nonce': base64.encode(box.nonce),
    'ct': base64.encode(box.cipherText),
    'mac': base64.encode(box.mac.bytes),
  };
}

/// The key pair in a key [file] made by [lockRecoveryKey]. Throws [RecoveryRefused] for a wrong passphrase.
Future<SimpleKeyPair> unlockRecoveryKey(Map<String, dynamic> file, String passphrase) async {
  if (file['v'] != 1 || file['kind'] != _keyFileKind) throw const RecoveryRefused('not a recovery key file');
  try {
    final salt = base64.decode(file['salt'] as String);
    final rounds = file['rounds'] as int;
    final lock = await Isolate.run(() => _stretch(passphrase, salt, rounds));
    final box = SecretBox(base64.decode(file['ct'] as String), nonce: base64.decode(file['nonce'] as String), mac: Mac(base64.decode(file['mac'] as String)));
    final private = await Chacha20.poly1305Aead().decrypt(box, secretKey: SecretKey(lock), aad: utf8.encode(_keyFileKind));
    final pair = await X25519().newKeyPairFromSeed(private);
    if (base64.encode((await pair.extractPublicKey()).bytes) != file['public']) throw const RecoveryRefused('damaged');
    return pair;
  } catch (_) {
    throw const RecoveryRefused('the passphrase does not open this key file');
  }
}

/// [dir] or a folder above it is a git checkout, where a key file could be committed by mistake.
bool insideGitCheckout(Directory dir) {
  var at = dir.absolute;
  while (true) {
    if (FileSystemEntity.typeSync('${at.path}${Platform.pathSeparator}.git') != FileSystemEntityType.notFound) return true;
    final up = at.parent;
    if (up.path == at.path) return false;
    at = up;
  }
}

/// A cloud [copy] opened with the recovery key [pair] and locked again with [newPassword]: an ordinary backup with no
/// seal, which the company brings back through the restore it knows. [work] holds the data while it is relocked.
Future<Uint8List> reopenCloudCopy(Uint8List copy, SimpleKeyPair pair, String newPassword, Directory work) async {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(copy, verify: true);
  } catch (_) {
    throw const RecoveryRefused('not a backup');
  }
  final manifestFile = zip.findFile('manifest.json');
  final dataFile = zip.findFile('data.db');
  final sealedFile = zip.findFile(recoveryFile);
  if (manifestFile == null || dataFile == null) throw const RecoveryRefused('not a backup');
  if (sealedFile == null) throw const RecoveryRefused('no sealed key: only a cloud copy carries one');
  final manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
  final data = dataFile.content;
  final sha = manifest['sha256'] as String;
  if (crypto.sha256.convert(data).toString() != sha) throw const RecoveryRefused('the copy is damaged');
  final key = await openCopyKey(jsonDecode(utf8.decode(sealedFile.content)) as Map<String, dynamic>, pair, tenantId: manifest['tenantId'] as String, sha256: sha);
  final file = File('${work.path}${Platform.pathSeparator}reopen-${_hex(_random(8))}.db');
  try {
    await file.writeAsBytes(data, flush: true);
    final path = file.path;
    await Isolate.run(() => _relock(path, key, newPassword));
    final fresh = await file.readAsBytes();
    final label = {...manifest, 'sha256': crypto.sha256.convert(fresh).toString()};
    return ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.string('manifest.json', jsonEncode(label)))
        ..addFile(ArchiveFile.noCompress('data.db', fresh.length, fresh)),
    );
  } finally {
    for (final part in [file, File('${file.path}-journal')]) {
      if (part.existsSync()) await part.delete();
    }
  }
}

void _relock(String path, List<int> key, String password) {
  final db = sqlite3.open(path);
  try {
    db.execute(_locked);
    db.execute('PRAGMA key = "x\'${_hex(key)}\'"');
    db.select('SELECT count(*) FROM sqlite_master');
    db.execute("PRAGMA rekey = '${password.replaceAll("'", "''")}'");
  } on SqliteException {
    throw const RecoveryRefused('the sealed key does not open the copy');
  } finally {
    db.close();
  }
}
