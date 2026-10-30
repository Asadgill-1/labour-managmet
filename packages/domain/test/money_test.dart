import 'package:domain/money.dart';
import 'package:test/test.dart';

void main() {
  group('divRoundHalfUp', () {
    test('rounds down below half and up at half', () {
      expect(divRoundHalfUp(149, 100), 1);
      expect(divRoundHalfUp(150, 100), 2);
      expect(divRoundHalfUp(151, 100), 2);
    });

    test('odd denominators round to nearest', () {
      expect(divRoundHalfUp(1, 3), 0);
      expect(divRoundHalfUp(2, 3), 1);
    });

    test('a reversal is the exact negative of its original', () {
      for (final n in [1, 50, 149, 150, 151, 999]) {
        expect(divRoundHalfUp(-n, 100), -divRoundHalfUp(n, 100));
      }
    });

    test('rejects a non-positive denominator', () {
      expect(() => divRoundHalfUp(1, 0), throwsArgumentError);
      expect(() => divRoundHalfUp(1, -60), throwsArgumentError);
    });

    test('PRD billing fixture: 10 workers, 660 minutes, AED 10 per hour', () {
      expect(10 * divRoundHalfUp(660 * 1000, 60), 110000);
    });

    test('PRD wage fixture: 10 workers, 660 minutes, AED 8 per hour', () {
      expect(10 * divRoundHalfUp(660 * 800, 60), 88000);
    });
  });
}
