import 'dart:math';
import '../../core/balance/game_balance.dart';
import '../../core/numbers/amount.dart';
import '../../domain/character/character.dart';

class EnemyDefinition {
  const EnemyDefinition({
    required this.id,
    required this.name,
    required this.baseHp,
    required this.baseDamage,
    required this.attackSpeed,
    required this.rewardGold,
    required this.rewardXp,
    required this.animations,
    this.critChance = .03,
    this.critDamage = 1.5,
    this.rewardBookChance = .28,
    this.difficultyWeight = 1,
  });
  final String id, name, animations;
  final double baseHp,
      baseDamage,
      attackSpeed,
      critChance,
      critDamage,
      rewardGold,
      rewardXp,
      rewardBookChance,
      difficultyWeight;
}

abstract final class EnemyCatalog {
  static const definitions = [
    EnemyDefinition(
      id: 'slime',
      name: 'Moss slime',
      baseHp: 48,
      baseDamage: 6,
      attackSpeed: .75,
      rewardGold: 12,
      rewardXp: 18,
      animations: 'slime',
    ),
    EnemyDefinition(
      id: 'sentinel',
      name: 'Stone sentinel',
      baseHp: 80,
      baseDamage: 9,
      attackSpeed: .55,
      rewardGold: 20,
      rewardXp: 28,
      animations: 'sentinel',
      difficultyWeight: .5,
    ),
    EnemyDefinition(
      id: 'wisp',
      name: 'Lost wisp',
      baseHp: 34,
      baseDamage: 5,
      attackSpeed: 1.2,
      rewardGold: 14,
      rewardXp: 20,
      animations: 'wisp',
      difficultyWeight: .8,
    ),
  ];
}

class Enemy {
  Enemy(this.definition, this.stats, this.gold, this.xp) : hp = stats.maxHp;
  final EnemyDefinition definition;
  final CombatStats stats;
  final Amount gold, xp;
  Amount hp;
}

class EnemyFactory {
  Enemy create(EnemyDefinition definition, int tier) => Enemy(
    definition,
    CombatStats(
      maxHp: Amount.fromNum(definition.baseHp).grow(GameBalance.hpGrowth, tier),
      damage: Amount.fromNum(
        definition.baseDamage,
      ).grow(GameBalance.damageGrowth, tier),
      attackSpeed: definition.attackSpeed,
      critChance: definition.critChance,
      critDamage: definition.critDamage,
    ),
    Amount.fromNum(definition.rewardGold).grow(GameBalance.rewardGrowth, tier),
    Amount.fromNum(definition.rewardXp).grow(GameBalance.rewardGrowth, tier),
  );
}

class EnemySpawner {
  EnemySpawner(this.random, {this.definitions = EnemyCatalog.definitions});
  final Random random;
  final List<EnemyDefinition> definitions;
  final factory = EnemyFactory();
  double nextDistance() =>
      GameBalance.encounterMinDistance +
      random.nextDouble() *
          (GameBalance.encounterMaxDistance - GameBalance.encounterMinDistance);
  Enemy spawn(int tier) {
    var roll =
        random.nextDouble() *
        definitions.fold<double>(0, (sum, d) => sum + d.difficultyWeight);
    var selected = definitions.last;
    for (final d in definitions) {
      roll -= d.difficultyWeight;
      if (roll <= 0) {
        selected = d;
        break;
      }
    }
    return factory.create(selected, tier);
  }
}
