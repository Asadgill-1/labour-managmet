import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/app_lock.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a PIN is 4 to 6 digits and not one of the first guesses', () {
    for (final good in ['2580', '13579', '908172']) {
      expect(isGoodPin(good), isTrue, reason: good);
    }
    for (final bad in ['258', '1234567', '12a4', '1111', '1234', '4321', '345678', '0000']) {
      expect(isGoodPin(bad), isFalse, reason: bad);
    }
  });

  test('the PIN is kept hashed; wrong tries count across restarts and the eighth removes the lock', () async {
    const storage = FlutterSecureStorage();
    await AppLock(storage).setPin('2580');
    expect(await storage.read(key: 'lock_pin'), isNot(contains('2580')));

    expect(await AppLock(storage).check('1111'), 7);
    expect(await AppLock(storage).check('2580'), isNull);
    expect(await AppLock(storage).check('1111'), 7, reason: 'a right PIN starts the count again');

    final lock = AppLock(storage);
    for (final left in [6, 5, 4, 3, 2, 1]) {
      expect(await lock.check('0000'), left);
    }
    await lock.setFingerprint(true);
    expect(await lock.check('0000'), 0);
    expect(await lock.hasPin(), isFalse);
    expect(await lock.fingerprintOn(), isFalse, reason: 'nothing of the old lock is left');
  });
}
