import 'dart:math' as math;

/// Non-negative magnitude stored in log10 space. Arithmetic never overflows
/// at 1e308; precision is ~15 significant digits, as with a double.
final class Amount implements Comparable<Amount> {
  const Amount._(this.log10);
  static const zero = Amount._(double.negativeInfinity);
  static final one = Amount.fromNum(1);
  final double log10;
  factory Amount.fromNum(num value) {
    if (!value.isFinite || value < 0) throw ArgumentError.value(value);
    return value == 0 ? zero : Amount._(math.log(value) / math.ln10);
  }
  factory Amount.fromLog(double value) {
    if (value.isNaN || value == double.infinity) {
      throw ArgumentError.value(value);
    }
    return Amount._(value);
  }
  factory Amount.fromJson(Object? value) => value == null
      ? zero
      : value is num
      ? Amount.fromNum(value)
      : Amount.fromLog(double.parse(value as String));
  Object? toJson() => isZero ? null : log10.toString();
  bool get isZero => log10 == double.negativeInfinity;
  Amount operator +(Amount other) {
    if (isZero) return other;
    if (other.isZero) return this;
    final high = math.max(log10, other.log10);
    final low = math.min(log10, other.log10);
    return Amount.fromLog(
      high + math.log(1 + math.pow(10, low - high)) / math.ln10,
    );
  }

  Amount operator -(Amount other) {
    if (other.isZero) return this;
    if (this <= other) return zero;
    return Amount.fromLog(
      log10 + math.log(1 - math.pow(10, other.log10 - log10)) / math.ln10,
    );
  }

  Amount operator *(Amount other) =>
      isZero || other.isZero ? zero : Amount.fromLog(log10 + other.log10);
  Amount scale(num value) => this * Amount.fromNum(value);
  Amount grow(double growth, num level) => isZero
      ? zero
      : Amount.fromLog(log10 + level * math.log(growth) / math.ln10);
  double ratio(Amount other) => isZero
      ? 0
      : math.pow(10, (log10 - other.log10).clamp(-320, 308)).toDouble();
  double toDouble() =>
      isZero ? 0 : math.pow(10, log10.clamp(-320, 308)).toDouble();
  @override
  int compareTo(Amount other) => log10.compareTo(other.log10);
  bool operator <(Amount other) => compareTo(other) < 0;
  bool operator <=(Amount other) => compareTo(other) <= 0;
  bool operator >=(Amount other) => compareTo(other) >= 0;
  bool operator >(Amount other) => compareTo(other) > 0;
}
