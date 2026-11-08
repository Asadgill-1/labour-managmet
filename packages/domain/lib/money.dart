/// The one rounding rule for money (CALC-01, D-101): half-up on magnitude.
///
/// Rounding on magnitude makes a reversal the exact negative of its original.
int divRoundHalfUp(int numerator, int denominator) {
  if (denominator <= 0) {
    throw ArgumentError.value(denominator, 'denominator', 'must be positive');
  }
  final magnitude = (numerator.abs() + denominator ~/ 2) ~/ denominator;
  return numerator < 0 ? -magnitude : magnitude;
}

/// 110050 -> "AED 1,100.50". Amounts always show AED (UX-04).
String formatAed(int fils) {
  final sign = fils < 0 ? '-' : '';
  final digits = (fils.abs() ~/ 100).toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
  final decimals = (fils.abs() % 100).toString().padLeft(2, '0');
  return '${sign}AED $grouped.$decimals';
}

/// 110050 -> "1100.50", for prefilling an amount field that [parseAed] reads back.
String plainAmount(int fils) => '${fils ~/ 100}.${(fils % 100).toString().padLeft(2, '0')}';

final _amount = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// "1,100.5" -> 110050. Returns null for anything that is not a non-negative AED amount.
int? parseAed(String input) {
  final match = _amount.firstMatch(input.trim().replaceAll(',', ''));
  if (match == null) return null;
  final decimals = (match[2] ?? '').padRight(2, '0');
  return int.parse(match[1]!) * 100 + int.parse(decimals);
}
