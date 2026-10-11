import 'dart:math' as math;
import '../../core/numbers/amount.dart';
import '../../core/numbers/stable_math.dart';

/// Geometric financial math; contains no stat or currency purchase endpoint.
class UpgradePrice {
  const UpgradePrice({required this.baseCost, required this.costGrowth})
    : assert(baseCost > 0),
      assert(costGrowth >= 1);
  static const maxLevel = 9007199254740991;
  final double baseCost, costGrowth;
  Amount cost(int level) {
    if (level < 0 || level > maxLevel) {
      throw ArgumentError.value(level, 'level');
    }
    return Amount.fromNum(baseCost).grow(costGrowth, level);
  }

  Amount batchCost(int level, int count) {
    if (level < 0 ||
        count < 0 ||
        level > maxLevel ||
        count > maxLevel - level) {
      throw ArgumentError('Upgrade levels and counts must be non-negative');
    }
    if (count == 0) return Amount.zero;
    if (costGrowth == 1) return cost(level).scale(count);
    final exponent = count * math.log(costGrowth);
    final logGeometric = exponent > 50
        ? exponent
        : math.log(StableMath.expm1(exponent));
    return cost(level) *
        Amount.fromLog((logGeometric - math.log(costGrowth - 1)) / math.ln10);
  }

  bool _covers(Amount wallet, Amount price) =>
      price.isZero ||
      price.log10 - wallet.log10 <=
          8 * StableMath.ulp(math.max(price.log10.abs(), wallet.log10.abs()));
  int affordable(int level, Amount wallet) {
    if (level < 0 || level > maxLevel) {
      throw ArgumentError.value(level, 'level');
    }
    if (wallet.isZero || !_covers(wallet, cost(level))) return 0;
    final ratioLog = (wallet.log10 - cost(level).log10) * math.ln10;
    final sumLog = costGrowth == 1 ? 0.0 : ratioLog + math.log(costGrowth - 1);
    final estimate = costGrowth == 1
        ? wallet.ratio(cost(level))
        : (sumLog > 50 ? sumLog : StableMath.log1p(math.exp(sumLog))) /
              math.log(costGrowth);
    final limit = maxLevel - level;
    var count = !estimate.isFinite || estimate >= limit
        ? limit
        : estimate.floor().clamp(0, limit);
    if (count > 0 && !_covers(wallet, batchCost(level, count))) count--;
    if (count < limit && _covers(wallet, batchCost(level, count + 1))) count++;
    return count;
  }
}
