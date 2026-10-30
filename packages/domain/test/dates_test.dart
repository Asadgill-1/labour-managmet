import 'package:domain/dates.dart';
import 'package:domain/validation.dart';
import 'package:test/test.dart';

void main() {
  test('stored dates pad and display as DD-MM-YYYY', () {
    expect(ymd(DateTime(2026, 3, 7)), '2026-03-07');
    expect(showDate('2026-03-07'), '07-03-2026');
  });

  test('today is the UAE date even near midnight UTC', () {
    expect(dubaiToday(DateTime.utc(2026, 11, 1, 19, 59)), '2026-11-01');
    expect(dubaiToday(DateTime.utc(2026, 11, 1, 20, 0)), '2026-11-02');
  });

  test('UAE wall clock converts to UTC', () {
    expect(dubaiToUtc('2026-11-01', 8 * 60), DateTime.utc(2026, 11, 1, 4));
    expect(dubaiToUtc('2026-11-01', 0), DateTime.utc(2026, 10, 31, 20));
  });

  test('minute of day displays as 24-hour time', () {
    expect(showMinuteOfDay(0), '00:00');
    expect(showMinuteOfDay(20 * 60 + 5), '20:05');
  });

  test('TRN format is 15 digits and nothing else', () {
    expect(isTrnFormat('100123456700003'), isTrue);
    expect(isTrnFormat(' 100123456700003 '), isTrue);
    for (final bad in ['', '12345', '1001234567000031', '10012345670000A']) {
      expect(isTrnFormat(bad), isFalse, reason: bad);
    }
  });
}
