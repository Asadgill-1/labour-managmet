/// shortcut: fixed Asia/Dubai offset (UAE has no DST), add a tenant timezone if a non-UAE tenant ever signs up.
const dubaiOffset = Duration(hours: 4);

String _two(int v) => v.toString().padLeft(2, '0');

/// Calendar date as stored: YYYY-MM-DD, which also sorts correctly as text.
String ymd(DateTime wallClock) => '${wallClock.year}-${_two(wallClock.month)}-${_two(wallClock.day)}';

/// Today's calendar date in the UAE, whatever timezone the phone is set to.
String dubaiToday(DateTime nowUtc) => ymd(nowUtc.toUtc().add(dubaiOffset));

/// "2026-11-01" -> "01-11-2026" (DD-MM-YYYY display).
String showDate(String storedDate) {
  final parts = storedDate.split('-');
  return '${parts[2]}-${parts[1]}-${parts[0]}';
}

/// Minutes from midnight -> "20:05".
String showMinuteOfDay(int minute) => '${_two(minute ~/ 60)}:${_two(minute % 60)}';

/// The UTC instant of a UAE wall-clock time on a stored date.
DateTime dubaiToUtc(String storedDate, int minuteOfDay) {
  final parts = storedDate.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]).add(Duration(minutes: minuteOfDay)).subtract(dubaiOffset);
}

/// A UTC instant as UAE minutes from midnight.
int dubaiMinuteOfDay(DateTime utc) {
  final local = utc.toUtc().add(dubaiOffset);
  return local.hour * 60 + local.minute;
}

/// A stored date shifted by whole days.
String addDays(String storedDate, int days) {
  final parts = storedDate.split('-').map(int.parse).toList();
  return ymd(DateTime.utc(parts[0], parts[1], parts[2] + days));
}

/// 660 -> "11:00".
String showDuration(int minutes) => '${minutes ~/ 60}:${_two(minutes % 60)}';
