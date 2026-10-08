import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/numbers/number_formatter.dart';

void main() {
  test('formats suffixes and scientific notation beyond suffix catalog', () {
    expect(NumberFormatter.amount(Amount.fromNum(950)), '950');
    expect(NumberFormatter.amount(Amount.fromNum(1200)), '1.2K');
    expect(NumberFormatter.amount(Amount.fromNum(2400000)), '2.4M');
    expect(NumberFormatter.amount(Amount.fromLog(900.5)), '3.16e900');
    expect(NumberFormatter.amount(Amount.zero), '0');
  });
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
