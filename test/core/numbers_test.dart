import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';

void main() {
  test('log arithmetic and JSON support enormous values', () {
    final huge = Amount.fromLog(12000);
    expect((huge + huge).log10, closeTo(12000.30103, 1e-5));
    expect((huge * huge).log10, 24000);
    expect((huge - huge).isZero, isTrue);
    expect(Amount.fromJson(huge.toJson()).log10, huge.log10);
    expect(
      (Amount.fromNum(100) - Amount.fromNum(20)).toDouble(),
      closeTo(80, 1e-8),
    );
    expect(() => Amount.fromNum(double.infinity), throwsArgumentError);
  });
}
