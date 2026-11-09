import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'tenant_database.dart';

/// This phone's own lock on its company (AUTH-03): a PIN, and the fingerprint when the phone has one. It opens the
/// company with no network. It is not the account's password: forgetting it, or getting it wrong [tries] times, means
/// logging in with the email again, which opens the same data.
class AppLock {
  AppLock(this._storage);

  final FlutterSecureStorage _storage;
  LocalAuthentication? _biometrics;

  static const tries = 5;
  static const _pinKey = 'lock_pin';
  static const _failsKey = 'lock_fails';
  static const _fingerprintKey = 'lock_fingerprint';

  Future<bool> hasPin() async => await _storage.read(key: _pinKey) != null;

  /// Stored salted and hashed, inside the phone's encrypted store. Six digits are few enough to try them all, so the
  /// real guard is [tries]; the hash only keeps the PIN itself unread.
  Future<void> setPin(String pin) async {
    final salt = newUuid();
    await _storage.write(key: _pinKey, value: '$salt:${_hash(salt, pin)}');
    await _storage.delete(key: _failsKey);
  }

  /// Null when [pin] is right; otherwise the tries left. At 0 the lock is gone and the email login is needed. The count
  /// survives closing the app.
  Future<int?> check(String pin) async {
    final [salt, hash] = (await _storage.read(key: _pinKey))!.split(':');
    if (_hash(salt, pin) == hash) {
      await _storage.delete(key: _failsKey);
      return null;
    }
    final fails = int.parse(await _storage.read(key: _failsKey) ?? '0') + 1;
    if (fails >= tries) {
      await clear();
      return 0;
    }
    await _storage.write(key: _failsKey, value: '$fails');
    return tries - fails;
  }

  Future<bool> fingerprintOn() async => await _storage.read(key: _fingerprintKey) == '1';

  Future<void> setFingerprint(bool on) => on ? _storage.write(key: _fingerprintKey, value: '1') : _storage.delete(key: _fingerprintKey);

  /// The phone has a fingerprint, or face, set up in its own settings.
  Future<bool> canUseFingerprint() async {
    try {
      final auth = _biometrics ??= LocalAuthentication();
      return await auth.isDeviceSupported() && (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows the phone's own fingerprint prompt. False when it was cancelled or failed; the PIN still works.
  Future<bool> unlockWithFingerprint(String reason) async {
    try {
      return await (_biometrics ??= LocalAuthentication()).authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }

  /// With logout: the next account on this phone sets its own.
  Future<void> clear() async {
    for (final key in [_pinKey, _failsKey, _fingerprintKey]) {
      await _storage.delete(key: key);
    }
  }

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();
}

/// Four to six digits, not one digit repeated and not a straight run like 1234, which are tried first.
bool isGoodPin(String pin) {
  if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) return false;
  final steps = {for (var i = 1; i < pin.length; i++) (pin.codeUnitAt(i) - pin.codeUnitAt(i - 1))};
  return !(steps.length == 1 && steps.single.abs() <= 1);
}
