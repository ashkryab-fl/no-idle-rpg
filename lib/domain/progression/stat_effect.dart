import '../../core/numbers/amount.dart';

class StatEffect {
  StatEffect({
    Amount? multiplier,
    this.additive = 0,
    this.remainingCapFraction = 1,
  }) : multiplier = multiplier ?? Amount.one;
  final Amount multiplier;
  final double additive, remainingCapFraction;
  Amount get percentageBonus => (multiplier - Amount.one).scale(100);
  double get capProgressPercent => (1 - remainingCapFraction) * 100;
  StatEffect combine(StatEffect other) => StatEffect(
    multiplier: multiplier * other.multiplier,
    additive: additive + other.additive,
    remainingCapFraction: remainingCapFraction * other.remainingCapFraction,
  );
}
