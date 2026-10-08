import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../equipment/equipment.dart';
import '../progression/infinite_upgrade.dart';
import '../progression/stat_effect.dart';

class CharacterProgress {
  int level = 1;
  Amount xp = Amount.zero;
  Amount gold = Amount.zero;
  Amount books = Amount.zero;
  final Map<String, int> upgrades = {};
  final Map<String, int> equipment = {};
  Map<String, Object?> toJson() => {
    'level': level,
    'xp': xp.toJson(),
    'gold': gold.toJson(),
    'books': books.toJson(),
    'upgrades': upgrades,
    'equipment': equipment,
  };
  factory CharacterProgress.fromJson(Map<String, dynamic> json) {
    final result = CharacterProgress()
      ..level = json['level'] as int? ?? 1
      ..xp = Amount.fromJson(json['xp'])
      ..gold = Amount.fromJson(json['gold'])
      ..books = Amount.fromJson(json['books']);
    if (result.level < 1 || result.level > 9007199254740991) {
      throw const FormatException('Invalid character level');
    }
    for (final pair in [
      ('upgrades', result.upgrades),
      ('equipment', result.equipment),
    ]) {
      final values = Map<String, dynamic>.from(json[pair.$1] as Map? ?? {});
      values.forEach((key, value) {
        if (value is! int || value < 0 || value > 9007199254740991) {
          throw FormatException('Invalid upgrade level for $key');
        }
        pair.$2[key] = value;
      });
    }
    return result;
  }
  CharacterProgress();
}

class CombatStats {
  const CombatStats({
    required this.maxHp,
    required this.damage,
    required this.attackSpeed,
    required this.critChance,
    required this.critDamage,
  });
  final Amount maxHp, damage;
  final double attackSpeed, critChance, critDamage;
  Amount get dps =>
      damage.scale(attackSpeed * (1 + critChance * (critDamage - 1)));
}

abstract final class CharacterStats {
  static CombatStats calculate(CharacterProgress progress) {
    StatEffect effect(CharacterStat stat) {
      var effect = StatEffect();
      for (final d in UpgradeCatalog.character) {
        if (d.stat == stat) {
          effect = effect.combine(d.effect(progress.upgrades[d.id] ?? 0));
        }
      }
      for (final d in EquipmentCatalog.items) {
        if (d.stat == stat) {
          effect = effect.combine(d.effect(progress.equipment[d.id] ?? 0));
        }
      }
      return effect;
    }

    double capped(double base, double cap, StatEffect effect) =>
        (cap -
                (cap - (base * effect.multiplier.toDouble()).clamp(0, cap)) *
                    effect.remainingCapFraction +
                effect.additive)
            .clamp(0, cap);
    final hp = effect(CharacterStat.maxHp),
        damage = effect(CharacterStat.damage);
    final critDamage = effect(CharacterStat.critDamage);
    final levelGrowth = Amount.one.grow(
      ProgressionBalance.levelStatGrowth,
      progress.level - 1,
    );
    return CombatStats(
      maxHp:
          Amount.fromNum(ProgressionBalance.heroHp) *
              hp.multiplier *
              levelGrowth +
          Amount.fromNum(hp.additive),
      damage:
          Amount.fromNum(ProgressionBalance.heroDamage) *
              damage.multiplier *
              levelGrowth +
          Amount.fromNum(damage.additive),
      // Legacy speed/boots levels in saves no longer affect combat.
      attackSpeed: ProgressionBalance.heroAttackSpeed,
      critChance: capped(
        ProgressionBalance.heroCritChance,
        ProgressionBalance.critChanceCap,
        effect(CharacterStat.critChance),
      ),
      critDamage:
          ProgressionBalance.heroCritDamage * critDamage.multiplier.toDouble() +
          critDamage.additive,
    );
  }
}
