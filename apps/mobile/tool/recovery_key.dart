// The platform owner's recovery key (D-072, T20d). Run on the owner's own computer, from apps/mobile:
//
//   dart run tool/recovery_key.dart make <folder outside any git checkout>
//   dart run tool/recovery_key.dart open <recovery-key.json> <cloud copy.zip> <new backup.zip>
//
// `make` writes the private half, locked with a passphrase, and prints the public half for `RECOVERY_KEY` in
// apps/mobile/.env. `open` turns a cloud copy downloaded for a company that forgot its backup password into an ordinary
// backup locked with a new password, which the owner gives to the company. docs/RUNBOOK.md has the steps.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:labour_app/data/recovery.dart';

const _keyFileName = 'recovery-key.json';

Future<void> main(List<String> args) async {
  try {
    switch (args) {
      case ['make', final folder]:
        await _make(Directory(folder));
      case ['open', final keyFile, final copy, final out]:
        await _open(File(keyFile), File(copy), File(out));
      default:
        stderr.writeln('Use: make <folder> | open <recovery-key.json> <copy.zip> <out.zip>');
        exitCode = 64;
    }
  } on RecoveryRefused catch (e) {
    stderr.writeln('Refused: ${e.reason}.');
    exitCode = 1;
  } on FileSystemException catch (e) {
    stderr.writeln('Refused: ${e.message}, ${e.path}.');
    exitCode = 1;
  }
}

Future<void> _make(Directory folder) async {
  if (!folder.existsSync()) throw const RecoveryRefused('the folder does not exist');
  if (insideGitCheckout(folder)) throw const RecoveryRefused('the folder is inside a git checkout, where the key could be committed');
  final file = File('${folder.path}${Platform.pathSeparator}$_keyFileName');
  if (file.existsSync()) throw const RecoveryRefused('a key file is there already; it is never overwritten');
  final passphrase = _ask('Passphrase (12 characters or more): ');
  if (passphrase.length < 12) throw const RecoveryRefused('the passphrase is shorter than 12 characters');
  if (_ask('The passphrase again: ') != passphrase) throw const RecoveryRefused('the two passphrases differ');
  final pair = await X25519().newKeyPair();
  final locked = await lockRecoveryKey(pair, passphrase);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(locked), flush: true);
  stdout
    ..writeln('Written: ${file.path}')
    ..writeln('Keep a second copy apart, offline. Never in git, on the server or in .env.')
    ..writeln('RECOVERY_KEY=${locked['public']}');
}

Future<void> _open(File keyFile, File copy, File out) async {
  if (out.existsSync()) throw const RecoveryRefused('the output file is there already');
  final pair = await unlockRecoveryKey(jsonDecode(await keyFile.readAsString()) as Map<String, dynamic>, _ask('Passphrase: '));
  final password = _ask('New backup password for the company: ');
  if (password.length < 8 || !RegExp('[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
    throw const RecoveryRefused('the new password needs 8 or more characters, with letters and digits');
  }
  if (_ask('The new password again: ') != password) throw const RecoveryRefused('the two passwords differ');
  final work = await Directory.systemTemp.createTemp('recovery');
  try {
    final opened = await reopenCloudCopy(await copy.readAsBytes(), pair, password, work);
    await out.writeAsBytes(opened, flush: true);
    final label = jsonDecode(utf8.decode(ZipDecoder().decodeBytes(opened).findFile('manifest.json')!.content)) as Map<String, dynamic>;
    stdout.writeln('Company ${label['tenantId']}, copy made ${label['createdAtUtc']} (UTC).');
  } finally {
    await work.delete(recursive: true);
  }
  stdout.writeln('Written: ${out.path}. Give it to the company with the new password, each by its own way.');
}

/// A line typed without showing it on a terminal.
String _ask(String prompt) {
  stdout.write(prompt);
  final hide = stdin.hasTerminal;
  if (hide) stdin.echoMode = false;
  try {
    return stdin.readLineSync(encoding: utf8) ?? '';
  } finally {
    if (hide) {
      stdin.echoMode = true;
      stdout.writeln();
    }
  }
}
