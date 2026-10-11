import 'dart:math';
import '../../content/animations/enemies/goblin_clips.dart';
import '../../core/animation/enemy_animation_content.dart';
import '../../core/balance/game_balance.dart';
import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../../domain/character/character.dart';
import '../../domain/adventure/stage_attempt.dart';

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
  Enemy(this.definition, this.stats, this.gold, {this.isBoss = false})
    : hp = stats.maxHp;
  final EnemyDefinition definition;
  final bool isBoss;
  final CombatStats stats;
  final Amount gold;
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
      );
}

class EnemySpawner {
  EnemySpawner(
    this.random, {
    Random? travelRandom,
    List<EnemyDefinition>? definitions,
  }) : travelRandom = travelRandom ?? random,
       definitions = definitions ?? EnemyCatalog.definitions;
  final Random random, travelRandom;
  final List<EnemyDefinition> definitions;
  final factory = EnemyFactory();
  double nextDistance() =>
      GameBalance.encounterMinDistance +
      travelRandom.nextDouble() *
          (GameBalance.encounterMaxDistance - GameBalance.encounterMinDistance);
  List<EncounterPlan> plan(int stage) => List.generate(5, (i) {
    final foe = spawn(stage - 1, isBoss: i == 4);
    return EncounterPlan(foe.definition.id, nextDistance(), foe.gold);
  });
  Enemy planned(StageAttempt attempt, int wave) {
    final plan = attempt.encounters[wave - 1];
    final definition = definitions.firstWhere(
      (d) => d.id == plan.enemyId,
      orElse: () => throw StateError("Unknown saved enemy ${plan.enemyId}"),
    );
    final foe = factory.create(
      definition,
      attempt.stage - 1,
      isBoss: wave == 5,
    );
    return Enemy(definition, foe.stats, plan.gold, isBoss: wave == 5);
  }

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
