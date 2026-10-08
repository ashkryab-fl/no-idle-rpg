import 'dart:math' as math;
import 'amount.dart';

abstract final class NumberFormatter {
  static const _suffixes = [
    '',
    'K',
    'M',
    'B',
    'T',
    'Qa',
    'Qi',
    'Sx',
    'Sp',
    'Oc',
    'No',
  ];
  static String amount(Amount value) {
    if (value.isZero) return '0';
    if (value.log10 < 3) return value.toDouble().toStringAsFixed(0);
    var group = (value.log10 / 3).floor();
    if (group >= _suffixes.length) {
      return '${math.pow(10, value.log10 - value.log10.floor()).toStringAsFixed(2)}e${value.log10.floor()}';
    }
    var mantissa = math.pow(10, value.log10 - group * 3).toDouble();
    if (mantissa >= 999.95) {
      group++;
      mantissa = 1;
    }
    if (group >= _suffixes.length) return '1e${group * 3}';
    return '${mantissa.toStringAsFixed(1)}${_suffixes[group]}';
  }

  static String duration(double seconds) {
    final s = seconds.floor();
    return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m ${s % 60}s';
  }
}
