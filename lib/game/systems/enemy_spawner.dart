import 'dart:math';
import '../../content/animations/enemies/goblin_clips.dart';
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
    required this.animations,
    this.scale = 1.0,
    this.critChance = ProgressionBalance.enemyCritChance,
    this.critDamage = ProgressionBalance.enemyCritDamage,
    this.rewardBookChance = ProgressionBalance.bookDropChance,
    this.rewardBooks = ProgressionBalance.baseBookReward,
    this.difficultyWeight = ProgressionBalance.enemyWeight,
  });
  final String id, name;
  final EnemyAnimationContent animations;
  final double scale;
  final double baseHp,
      baseDamage,
      attackSpeed,
      critChance,
      critDamage,
      rewardGold,
      rewardBookChance,
      rewardBooks,
      difficultyWeight;
}

abstract final class EnemyCatalog {
  static final definitions = List<EnemyDefinition>.unmodifiable([
    EnemyDefinition(
      id: 'gobli_low',
      name: 'Goblin',
      scale: .8,
      // Start with the existing low-tier combat and reward baseline.
      baseHp: ProgressionBalance.slimeHp,
      baseDamage: ProgressionBalance.slimeDamage,
      attackSpeed: ProgressionBalance.slimeAttackSpeed,
      rewardGold: ProgressionBalance.slimeGold,
      difficultyWeight: ProgressionBalance.slimeWeight,
      animations: GoblinClips.content,
    ),
  ]);
}

class Enemy {
  Enemy(
    this.definition,
    this.stats,
    this.gold, {
    Amount? books,
    this.isBoss = false,
  }) : books = books ?? Amount.fromNum(ProgressionBalance.baseBookReward),
       hp = stats.maxHp;
  final EnemyDefinition definition;
  final bool isBoss;
  final CombatStats stats;
  final Amount gold, books;
  Amount hp;
}

class EnemyFactory {
  Enemy create(EnemyDefinition definition, int tier, {bool isBoss = false}) =>
      Enemy(
        definition,
        CombatStats(
          maxHp: Amount.fromNum(definition.baseHp)
              .grow(ProgressionBalance.hpGrowth, tier)
              .scale(isBoss ? ProgressionBalance.bossStatMultiplier : 1),
          damage: Amount.fromNum(definition.baseDamage)
              .grow(ProgressionBalance.damageGrowth, tier)
              .scale(isBoss ? ProgressionBalance.bossStatMultiplier : 1),
          attackSpeed: definition.attackSpeed,
          critChance: definition.critChance,
          critDamage: definition.critDamage,
        ),
        Amount.fromNum(
          definition.rewardGold,
        ).grow(ProgressionBalance.goldRewardGrowth, tier),
        isBoss: isBoss,
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
  Enemy spawn(int tier, {bool isBoss = false}) {
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
    return factory.create(selected, tier, isBoss: isBoss);
  }
}
