import 'dart:math' as math;
import '../numbers/amount.dart';
import '../numbers/stable_math.dart';
import 'progression_balance.dart';

enum CharacterStat { damage, maxHp, critChance, critDamage }

class PowerCurve {
  const PowerCurve({this.threshold = 100, this.width = 200, this.tailRate = .5})
    : assert(threshold >= 0),
      assert(width > 0),
      assert(tailRate > 0 && tailRate <= 1);
  final int threshold;
  final double width, tailRate;
  double effectiveRank(int rank) {
    if (rank <= threshold) return rank.toDouble();
    final x = (rank - threshold).toDouble();
    return threshold +
        tailRate * x +
        (1 - tailRate) * width * StableMath.log1p(x / width);
  }

  double logGain(int rank) => rank <= threshold
      ? math.log(ProgressionBalance.upgradeGrowth) / math.ln10
      : (tailRate +
                (1 - tailRate) *
                    width *
                    StableMath.log1p(1 / (width + rank - 1 - threshold))) *
            math.log(ProgressionBalance.upgradeGrowth) /
            math.ln10;
}

class ChanceCurve {
  const ChanceCurve({this.threshold = 200, this.cap = .8, this.soft = true})
    : assert(threshold >= 0),
      assert(cap > .05 && cap <= 1),
      assert(!soft || .05 + .001 * threshold < cap);
  final int threshold;
  final double cap;
  final bool soft;
  double get atThreshold =>
      ProgressionBalance.heroCritChance +
      ProgressionBalance.critChanceBonus * threshold;
  double get width => (cap - atThreshold) / ProgressionBalance.critChanceBonus;
  double value(int rank) {
    if (!soft || rank <= threshold) {
      return math.min(
        cap,
        ProgressionBalance.heroCritChance +
            ProgressionBalance.critChanceBonus * rank,
      );
    }
    // cap - remaining avoids cancellation near the asymptote.
    return cap - (cap - atThreshold) * math.exp(-(rank - threshold) / width);
  }

  double gain(int rank) {
    if (!soft) return rank <= (cap - .05) / .001 ? .001 : 0;
    if (rank <= threshold) return ProgressionBalance.critChanceBonus;
    return (cap - atThreshold) *
        math.exp(-(rank - 1 - threshold) / width) *
        -StableMath.expm1(-1 / width);
  }
}

class MultiplierCurve {
  const MultiplierCurve({
    this.threshold = 150,
    this.width = 200,
    this.tailScale = 2,
    this.soft = true,
  }) : assert(threshold >= 0),
       assert(width > 0),
       assert(tailScale > 0);
  final int threshold;
  final double width, tailScale;
  final bool soft;
  double value(int rank) => !soft || rank <= threshold
      ? ProgressionBalance.heroCritDamage +
            ProgressionBalance.critDamageBonus * rank
      : ProgressionBalance.heroCritDamage +
            ProgressionBalance.critDamageBonus * threshold +
            tailScale * StableMath.log1p((rank - threshold) / width);
  double gain(int rank) => !soft || rank <= threshold
      ? ProgressionBalance.critDamageBonus
      : tailScale * StableMath.log1p(1 / (width + rank - 1 - threshold));
}

/// Versioned, immutable resolver shared by gameplay, previews and diagnostics.
class EquipmentCurveProfile {
  const EquipmentCurveProfile({
    required this.id,
    this.weapon = const PowerCurve(),
    this.armor = const PowerCurve(),
    this.chance = const ChanceCurve(),
    this.multiplier = const MultiplierCurve(),
    this.minimumChanceGain = 0,
  }) : assert(minimumChanceGain >= 0);
  static const candidate = EquipmentCurveProfile(id: 'phase02_candidate_v1');
  final String id;
  final PowerCurve weapon, armor;
  final ChanceCurve chance;
  final MultiplierCurve multiplier;

  /// Optional explicit diagnostic epsilon; production blocks numerical plateaus.
  final double minimumChanceGain;
  Amount value(CharacterStat stat, int rank) {
    if (rank < 0 || rank > 9007199254740991) {
      throw ArgumentError.value(rank, 'rank');
    }
    return switch (stat) {
      CharacterStat.damage || CharacterStat.maxHp => Amount.fromLog(
        math.log(
                  stat == CharacterStat.damage
                      ? ProgressionBalance.heroDamage
                      : ProgressionBalance.heroHp,
                ) /
                math.ln10 +
            (stat == CharacterStat.damage ? weapon : armor).effectiveRank(
                  rank,
                ) *
                math.log(ProgressionBalance.upgradeGrowth) /
                math.ln10,
      ),
      CharacterStat.critChance => Amount.fromNum(chance.value(rank)),
      CharacterStat.critDamage => Amount.fromNum(multiplier.value(rank)),
    };
  }

  /// Monotone analytic marginal gain compared with a non-decreasing precision
  /// floor. This conservatively guarantees every charged rank is representable;
  /// it never binary-searches subtraction of two rounded values.
  bool usefulRank(CharacterStat stat, int rank) {
    if (rank <= 0 || rank > 9007199254740991) return false;
    return switch (stat) {
      CharacterStat.damage || CharacterStat.maxHp =>
        (stat == CharacterStat.damage ? weapon : armor).logGain(rank) >=
            StableMath.ulp(value(stat, rank).log10),
      CharacterStat.critChance =>
        chance.gain(rank) >=
            math.max(minimumChanceGain, StableMath.ulp(chance.cap)),
      CharacterStat.critDamage =>
        multiplier.gain(rank) >= StableMath.ulp(multiplier.value(rank)),
    };
  }

  bool changed(CharacterStat stat, int before, int after) => switch (stat) {
    CharacterStat.critChance => chance.value(after) > chance.value(before),
    CharacterStat.critDamage =>
      multiplier.value(after) > multiplier.value(before),
    _ => value(stat, after) > value(stat, before),
  };
  Map<String, Object> toJson() => {
    'id': id,
    'minimumChanceGain': minimumChanceGain,
    'weapon': {
      'threshold': weapon.threshold,
      'width': weapon.width,
      'tailRate': weapon.tailRate,
    },
    'armor': {
      'threshold': armor.threshold,
      'width': armor.width,
      'tailRate': armor.tailRate,
    },
    'chance': {
      'threshold': chance.threshold,
      'cap': chance.cap,
      'soft': chance.soft,
    },
    'multiplier': {
      'threshold': multiplier.threshold,
      'width': multiplier.width,
      'tailScale': multiplier.tailScale,
      'soft': multiplier.soft,
    },
  };
}
