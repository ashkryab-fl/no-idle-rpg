import 'dart:math' as math;
import '../../core/numbers/amount.dart';
import '../../core/balance/progression_balance.dart';
import 'stat_effect.dart';

enum CharacterStat { damage, maxHp, critChance, critDamage }

enum UpgradeCurve { exponential, softCap, additive }

class InfiniteUpgradeDefinition {
  const InfiniteUpgradeDefinition({
    required this.id,
    required this.name,
    required this.stat,
    required this.baseCost,
    this.costGrowth = ProgressionBalance.bookUpgradeCostGrowth,
    this.curve = UpgradeCurve.exponential,
    this.valueGrowth = ProgressionBalance.upgradeGrowth,
    this.softCapRate = ProgressionBalance.softCapRate,
    this.bonusPerLevel = ProgressionBalance.critDamageBonus,
  }) : assert(baseCost > 0),
       assert(costGrowth >= 1),
       assert(valueGrowth >= 1),
       assert(softCapRate >= 0),
       assert(bonusPerLevel >= 0);
  final String id;
  final String name;
  final CharacterStat stat;
  final double baseCost;
  final double costGrowth;
  final UpgradeCurve curve;
  final double valueGrowth, softCapRate, bonusPerLevel;
  StatEffect effect(int level) {
    if (level < 0) throw ArgumentError.value(level, 'level');
    return switch (curve) {
      UpgradeCurve.exponential => StatEffect(
        multiplier: Amount.one.grow(valueGrowth, level),
      ),
      UpgradeCurve.softCap => StatEffect(
        remainingCapFraction: math.exp(-softCapRate * level),
      ),
      UpgradeCurve.additive => StatEffect(additive: bonusPerLevel * level),
    };
  }

  Amount cost(int level) => Amount.fromNum(baseCost).grow(costGrowth, level);
  Amount batchCost(int level, int count) {
    if (level < 0 || count < 0) {
      throw ArgumentError('Upgrade levels and counts must be non-negative');
    }
    if (count == 0) return Amount.zero;
    if (costGrowth == 1) return cost(level).scale(count);
    final exponent = count * math.log(costGrowth);
    final logGeometric = exponent > 50 ? exponent : math.log(_expm1(exponent));
    return cost(level) *
        Amount.fromLog((logGeometric - math.log(costGrowth - 1)) / math.ln10);
  }

  bool _covers(Amount wallet, Amount price) =>
      price.isZero ||
      price.log10 - wallet.log10 <= 2e-14 * math.max(1, wallet.log10.abs());
  int affordable(int level, Amount wallet) {
    if (level < 0) throw ArgumentError.value(level, 'level');
    if (wallet.isZero || !_covers(wallet, cost(level))) return 0;
    final ratioLog = (wallet.log10 - cost(level).log10) * math.ln10;
    final sumLog = costGrowth == 1 ? 0.0 : ratioLog + math.log(costGrowth - 1);
    final estimate = costGrowth == 1
        ? wallet.ratio(cost(level))
        : (sumLog > 50 ? sumLog : _log1p(math.exp(sumLog))) /
              math.log(costGrowth);
    final limit = 9007199254740991 - level;
    var count = estimate.floor().clamp(0, limit);
    if (count > 0 && !_covers(wallet, batchCost(level, count))) count--;
    if (count < limit && _covers(wallet, batchCost(level, count + 1))) count++;
    return count;
  }

  static double _expm1(double value) {
    if (value.abs() > 1e-4) return math.exp(value) - 1;
    var sum = value, term = value;
    for (var i = 2; i <= 8; i++) {
      term *= value / i;
      sum += term;
    }
    return sum;
  }

  static double _log1p(double value) {
    if (value.abs() > 1e-4) return math.log(1 + value);
    var sum = value, power = value;
    for (var i = 2; i <= 8; i++) {
      power *= -value;
      sum += power / i;
    }
    return sum;
  }
}

abstract final class UpgradeCatalog {
  static const character = [
    InfiniteUpgradeDefinition(
      id: 'damage',
      name: 'Damage',
      stat: CharacterStat.damage,
      baseCost: ProgressionBalance.bookDamageCost,
    ),
    InfiniteUpgradeDefinition(
      id: 'hp',
      name: 'Max HP',
      stat: CharacterStat.maxHp,
      baseCost: ProgressionBalance.bookHpCost,
    ),
    InfiniteUpgradeDefinition(
      id: 'crit',
      name: 'Crit Chance',
      stat: CharacterStat.critChance,
      baseCost: ProgressionBalance.bookCritChanceCost,
      curve: UpgradeCurve.additive,
      bonusPerLevel: ProgressionBalance.critChanceBonus,
    ),
    InfiniteUpgradeDefinition(
      id: 'critDamage',
      name: 'Crit Damage',
      stat: CharacterStat.critDamage,
      baseCost: ProgressionBalance.bookCritDamageCost,
      curve: UpgradeCurve.additive,
    ),
  ];
}
