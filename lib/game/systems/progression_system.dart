import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../../domain/character/character.dart';
import '../../domain/progression/infinite_upgrade.dart';

class ProgressionSystem {
  static const _xpCurve = InfiniteUpgradeDefinition(
    id: 'xp',
    name: 'XP',
    stat: CharacterStat.damage,
    baseCost: ProgressionBalance.baseXp,
    costGrowth: ProgressionBalance.xpGrowth,
  );
  Amount xpRequired(int level) => _xpCurve.cost(level - 1);
  int addXp(CharacterProgress hero, Amount reward) {
    hero.xp = hero.xp + reward;
    final count = _xpCurve.affordable(hero.level - 1, hero.xp);
    hero.xp = hero.xp - _xpCurve.batchCost(hero.level - 1, count);
    hero.level += count;
    return count;
  }

  int upgrade(
    CharacterProgress hero,
    InfiniteUpgradeDefinition definition, {
    required bool equipment,
    int? count = 1,
  }) {
    final levels = equipment ? hero.equipment : hero.upgrades;
    final wallet = equipment ? hero.gold : hero.books;
    final level = levels[definition.id] ?? 0;
    final affordable = definition.affordable(level, wallet);
    final buying = count == null ? affordable : count.clamp(0, affordable);
    if (buying == 0) return 0;
    final remainder = wallet - definition.batchCost(level, buying);
    if (equipment) {
      hero.gold = remainder;
    } else {
      hero.books = remainder;
    }
    levels[definition.id] = level + buying;
    return buying;
  }
}
