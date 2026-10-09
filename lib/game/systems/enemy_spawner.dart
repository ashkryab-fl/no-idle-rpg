import 'dart:math';
import '../../content/animations/enemies/procedural_timelines.dart';
import '../../core/animation/enemy_animation_content.dart';
import '../../core/balance/game_balance.dart';
import '../../core/balance/progression_balance.dart';
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
    this.critChance = ProgressionBalance.enemyCritChance,
    this.critDamage = ProgressionBalance.enemyCritDamage,
    this.rewardBookChance = ProgressionBalance.bookDropChance,
    this.rewardBooks = ProgressionBalance.baseBookReward,
    this.difficultyWeight = ProgressionBalance.enemyWeight,
  });
  final String id, name;
  final EnemyAnimationContent animations;
  final double baseHp,
      baseDamage,
      attackSpeed,
      critChance,
      critDamage,
      rewardGold,
      rewardXp,
      rewardBookChance,
      rewardBooks,
      difficultyWeight;
}

abstract final class EnemyCatalog {
  static final definitions = List<EnemyDefinition>.unmodifiable([
    EnemyDefinition(
      id: 'slime',
      name: 'Moss slime',
      baseHp: ProgressionBalance.slimeHp,
      baseDamage: ProgressionBalance.slimeDamage,
      attackSpeed: ProgressionBalance.slimeAttackSpeed,
      rewardGold: ProgressionBalance.slimeGold,
      rewardXp: ProgressionBalance.slimeXp,
      difficultyWeight: ProgressionBalance.slimeWeight,
      animations: ProceduralEnemyTimelines.content,
    ),
    EnemyDefinition(
      id: 'sentinel',
      name: 'Stone sentinel',
      baseHp: ProgressionBalance.sentinelHp,
      baseDamage: ProgressionBalance.sentinelDamage,
      attackSpeed: ProgressionBalance.sentinelAttackSpeed,
      rewardGold: ProgressionBalance.sentinelGold,
      rewardXp: ProgressionBalance.sentinelXp,
      animations: ProceduralEnemyTimelines.content,
      difficultyWeight: ProgressionBalance.sentinelWeight,
    ),
    EnemyDefinition(
      id: 'wisp',
      name: 'Lost wisp',
      baseHp: ProgressionBalance.wispHp,
      baseDamage: ProgressionBalance.wispDamage,
      attackSpeed: ProgressionBalance.wispAttackSpeed,
      rewardGold: ProgressionBalance.wispGold,
      rewardXp: ProgressionBalance.wispXp,
      animations: ProceduralEnemyTimelines.content,
      difficultyWeight: ProgressionBalance.wispWeight,
    ),
  ]);
}

class Enemy {
  Enemy(this.definition, this.stats, this.gold, this.xp, {Amount? books})
    : books = books ?? Amount.fromNum(ProgressionBalance.baseBookReward),
      hp = stats.maxHp;
  final EnemyDefinition definition;
  final CombatStats stats;
  final Amount gold, xp, books;
  Amount hp;
}

class EnemyFactory {
  Enemy create(EnemyDefinition definition, int tier) => Enemy(
    definition,
    CombatStats(
      maxHp: Amount.fromNum(
        definition.baseHp,
      ).grow(ProgressionBalance.hpGrowth, tier),
      damage: Amount.fromNum(
        definition.baseDamage,
      ).grow(ProgressionBalance.damageGrowth, tier),
      attackSpeed: definition.attackSpeed,
      critChance: definition.critChance,
      critDamage: definition.critDamage,
    ),
    Amount.fromNum(
      definition.rewardGold,
    ).grow(ProgressionBalance.goldRewardGrowth, tier),
    Amount.fromNum(
      definition.rewardXp,
    ).grow(ProgressionBalance.xpRewardGrowth, tier),
    books: Amount.fromNum(
      definition.rewardBooks,
    ).grow(ProgressionBalance.bookRewardGrowth, tier),
  );
}

class EnemySpawner {
  EnemySpawner(this.random, {List<EnemyDefinition>? definitions})
    : definitions = definitions ?? EnemyCatalog.definitions;
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
