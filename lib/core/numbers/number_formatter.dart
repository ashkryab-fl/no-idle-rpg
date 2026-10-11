import 'dart:math' as math;
import 'amount.dart';

abstract final class NumberFormatter {
  static const _suffixes = [
    '',
    'K',
    'M',
    'B',
    'T',
    'aa',
    'ab',
    'ac',
    'ba',
    'bb',
    'bc',
  ];

  /// One decimal below 100; whole numbers from 100, including rounded values.
  static String decimal(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    final rounded = double.parse(value.toStringAsFixed(1));
    return rounded.toStringAsFixed(rounded.abs() < 100 ? 1 : 0);
  }

  /// Currency, HP and damage use whole numbers, including compact notation.
  static String amount(Amount value, {bool whole = true}) {
    final format = whole ? (double value) => value.toStringAsFixed(0) : decimal;
    if (value.isZero) return format(0);
    if (value.log10 < (whole ? 6 : 3)) return format(value.toDouble());
    var group = (value.log10 / 3).floor();
    if (group >= _suffixes.length) {
      var exponent = value.log10.floor();
      var mantissa = math.pow(10, value.log10 - exponent).toDouble();
      if (double.parse(format(mantissa)) >= 10) {
        exponent++;
        mantissa = 1;
      }
      return '${format(mantissa)}e$exponent';
    }
    var mantissa = math.pow(10, value.log10 - group * 3).toDouble();
    if (double.parse(format(mantissa)) >= 1000) {
      group++;
      mantissa = 1;
    }
    if (group >= _suffixes.length) return '${format(1)}e${group * 3}';
    return '${format(mantissa)}${_suffixes[group]}';
  }

  static String duration(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m ${s % 60}s';
  }

  /// Display rounding never changes the raw Amount used for affordability.
  static String price(Amount value) => amount(value);

  /// A displayed zero must not hide a small, positive purchase effect.
  static String gain(double value) =>
      value > 0 && value < .05 ? '<0.1' : decimal(value);
}
