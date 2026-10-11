import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../equipment/equipment.dart';
import '../../core/balance/equipment_curve_profile.dart';

class CharacterProgress {
  Amount gold = Amount.zero;
  Amount books = Amount.zero;
  final Map<String, int> equipment = {};
  Map<String, Object?> toJson() => {
    'gold': gold.toJson(),
    'books': books.toJson(),
    'equipment': equipment,
  };
  factory CharacterProgress.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('upgrades')) {
      throw const FormatException(
        'Books stat upgrades are not allowed in current saves',
      );
    }
    final result = CharacterProgress()
      ..gold = Amount.fromJson(json['gold'])
      ..books = Amount.fromJson(json['books']);
    for (final pair in [('equipment', result.equipment)]) {
      final values = Map<String, dynamic>.from(json[pair.$1] as Map? ?? {});
      values.forEach((key, value) {
        if (!EquipmentCatalog.items.any((d) => d.id == key)) {
          throw FormatException('Unknown equipment $key');
        }
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
  static CombatStats calculate(
    CharacterProgress progress, {
    EquipmentCurveProfile profile = EquipmentCurveProfile.candidate,
  }) => CombatStats(
    maxHp: profile.value(CharacterStat.maxHp, progress.equipment['armor'] ?? 0),
    damage: profile.value(
      CharacterStat.damage,
      progress.equipment['weapon'] ?? 0,
    ),
    attackSpeed: ProgressionBalance.heroAttackSpeed,
    critChance: profile.chance.value(progress.equipment['helmet'] ?? 0),
    critDamage: profile.multiplier.value(progress.equipment['amulet'] ?? 0),
  );
}
