import 'dart:math' as math;
import 'dart:typed_data';

abstract final class StableMath {
  static double expm1(double x) {
    if (x.abs() > 1e-4) return math.exp(x) - 1;
    var sum = x, term = x;
    for (var i = 2; i <= 8; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }

  static double log1p(double x) {
    if (x.abs() > 1e-4) return math.log(1 + x);
    var sum = x, power = x;
    for (var i = 2; i <= 8; i++) {
      power *= -x;
      sum += power / i;
    }
    return sum;
  }

  /// Spacing of represented doubles in this binade, without decimal rounding.
  static double ulp(double x) {
    final bits = ByteData(8)..setFloat64(0, x.abs());
    final exponent = (bits.getUint64(0) >> 52) & 0x7ff;
    return exponent == 0
        ? double.minPositive
        : math.pow(2, exponent - 1075).toDouble();
  }
}
