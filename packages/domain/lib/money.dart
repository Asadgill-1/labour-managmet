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
