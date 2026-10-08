import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/activity/idle_animation.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';
import 'package:idle_companion/game/systems/drop_system.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
  for (final idleSeconds in [30.0, 120.0, 300.0]) {
    test('rest at $idleSeconds seconds stops adventure progress', () {
      final game = GameSimulation(random: Random(1));
      game.advance(1);
      final distance = game.distance;
      final scroll = game.scroll;
      final encounterDistance = game.encounterRemaining;
      game.idle.setIdleSeconds(idleSeconds);
      expect(game.isResting, true);
      expect(game.scrollSpeed, 0);
      expect(game.heroAnimation, 'hero.idle');

      // A debug spawn must also respect rest before the first animation tick.
      game.spawnEnemy();
      expect(game.enemy, isNull);
      for (var i = 0; i < 600; i++) {
        game.advance(1 / 30);
      }

      expect(game.distance, distance);
      expect(game.scroll, scroll);
      expect(game.encounterRemaining, encounterDistance);
      expect(game.phase, GamePhase.traveling);
      expect(game.enemy, isNull);
      expect(game.kills, 0);
      expect(game.character.gold.isZero, true);
      expect(game.idle.animationId, isNotNull);
    });
  }
  test('spawns resume only after rest and the caught animation finish', () {
    final game = GameSimulation(
      random: Random(1),
      idleDefinitions: const [
        IdleAnimationDefinition(
          id: 'rest',
          requiredIdleLevel: IdleLevel.level1,
          canInterrupt: false,
        ),
      ],
    );
    game.advance(.5);
    final distance = game.distance;
    final scroll = game.scroll;
    game.idle.setIdleSeconds(30);
    for (var i = 0; i < 100; i++) {
      game.advance(.1);
      if (game.idle.current?.canInterrupt == false) break;
    }
    expect(game.idle.current?.canInterrupt, false);
    game.encounterRemaining = 0;
    game.idle.setIdleSeconds(0);
    game.advance(.1);
    expect(game.idle.level, IdleLevel.active);
    expect(game.idle.current, isNotNull);
    game.spawnEnemy();
    expect(game.enemy, isNull);
    expect(game.distance, distance);
    expect(game.scroll, scroll);

    for (var i = 0; i < 100; i++) {
      game.advance(.1);
      expect(game.enemy, isNull);
      expect(game.distance, distance);
      expect(game.scroll, scroll);
      if (game.idle.animationId == 'hero.caught') break;
    }
    expect(game.idle.animationId, 'hero.caught');
    game.spawnEnemy();
    expect(game.enemy, isNull);
    game.advance(.1);
    expect(game.enemy, isNull);
    expect(game.distance, distance);
    expect(game.scroll, scroll);

    game.advance(1);
    expect(game.idle.animationId, isNull);
    expect(game.enemy, isNotNull);
    expect(game.phase, GamePhase.enemyApproach);
    expect(game.distance, greaterThan(distance));
    expect(game.isResting, false);
  });
  test('rest animations wait for the existing encounter and rewards', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    final enemy = game.enemy;
    game.idle.setIdleSeconds(300);
    game.advance(1.2);
    expect(game.phase, GamePhase.combat);
    expect(game.enemy, same(enemy));
    expect(game.isResting, false);
    expect(game.idle.animationId, isNull);
    final hp = game.heroHp;
    game.advance(.4);
    expect(game.heroHp < hp, true);
    expect(game.idle.animationId, isNull);
    game.killEnemy();
    game.advance(1);
    expect(game.phase, GamePhase.reward);
    expect(game.idle.animationId, isNull);
    game.advance(1);
    expect(game.isResting, true);
    expect(game.idle.animationId, isNotNull);
    final distance = game.distance;
    for (var i = 0; i < 600; i++) {
      game.advance(1 / 30);
    }
    expect(game.phase, GamePhase.traveling);
    expect(game.enemy, isNull);
    expect(game.kills, 1);
    expect(game.character.gold.isZero, false);
    expect(game.distance, distance);
  });
  test('rest cooldown gaps remain stationary until user activity returns', () {
    final game = GameSimulation(
      random: Random(1),
      idleDefinitions: const [
        IdleAnimationDefinition(
          id: 'rest',
          requiredIdleLevel: IdleLevel.level1,
          cooldown: 10,
        ),
      ],
    );
    game.idle.setIdleSeconds(30);
    game.advance(.1);
    expect(game.heroAnimation, 'rest');
    game.advance(1);
    expect(game.idle.animationId, isNull);
    expect(game.heroAnimation, 'hero.idle');
    game.advance(4);
    expect(game.isResting, true);
    expect(game.distance, 0);
    expect(game.enemy, isNull);
    final encounterDistance = game.encounterRemaining;
    game.idle.setIdleSeconds(0);
    game.advance(.1);
    expect(game.isResting, false);
    expect(game.heroAnimation, 'hero.walk');
    expect(game.distance, greaterThan(0));
    expect(game.encounterRemaining, lessThan(encounterDistance));
  });
  test('returning during combat cancels the pending rest', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.idle.setIdleSeconds(300);
    game.advance(1.2);
    expect(game.idle.animationId, isNull);
    game.idle.setIdleSeconds(0);
    game.killEnemy();
    final distance = game.distance;
    game.advance(2);
    expect(game.phase, GamePhase.traveling);
    expect(game.isResting, false);
    expect(game.heroAnimation, 'hero.walk');
    expect(game.idle.animationId, isNull);
    expect(game.distance, greaterThan(distance));
  });
  test('death and respawn finish before rest resumes', () {
    final game = GameSimulation(random: Random(1));
    game.idle.setIdleSeconds(300);
    game.advance(.1);
    game.killHero();
    expect(game.heroAnimation, 'hero.death');
    game.advance(game.animations.get('hero.death').duration + .1);
    expect(game.phase, GamePhase.respawn);
    expect(game.heroAnimation, 'hero.death');
    game.advance(2);
    expect(game.isResting, true);
    expect(game.distance, 0);
    expect(game.enemy, isNull);
    expect(game.heroHp.ratio(game.stats.maxHp), closeTo(1, 1e-8));
  });
  test('invalid frame deltas cannot poison the simulation accumulator', () {
    final game = GameSimulation(random: Random(1));
    for (final dt in [double.nan, double.infinity, -1.0, 20.0]) {
      game.advance(dt);
    }
    game.advance(.1);
    expect(game.distance, greaterThan(0));
    expect(game.distance.isFinite, isTrue);
  });
  CombatStats stats(double crit) => CombatStats(
    maxHp: Amount.fromNum(100),
    damage: Amount.fromNum(10),
    attackSpeed: 1,
    critChance: crit,
    critDamage: 2,
  );
  test('critical calculation and damage event timing', () {
    final combat = CombatSystem(Random(1), AnimationCatalog());
    expect(
      combat.calculate(stats(1), true).amount.toDouble(),
      closeTo(20, 1e-8),
    );
    expect(combat.calculate(stats(0), true).critical, false);
    expect(combat.update(.34, stats(0), stats(0), 'slime', 1), isEmpty);
    expect(combat.update(.02, stats(0), stats(0), 'slime', 1).length, 2);
  });
  test('attack speed scales the animation timeline', () {
    final fast = CombatStats(
      maxHp: Amount.one,
      damage: Amount.one,
      attackSpeed: 5,
      critChance: 0,
      critDamage: 1,
    );
    final combat = CombatSystem(Random(1), AnimationCatalog());
    expect(combat.update(1, fast, fast, 'slime', 1).length, 10);
  });
  test('enemy HP, damage and gold scale exponentially', () {
    final factory = EnemyFactory(), definition = EnemyCatalog.definitions.first;
    final enemy = factory.create(definition, 10);
    expect(
      enemy.stats.maxHp.toDouble(),
      closeTo(definition.baseHp * pow(1.08, 10), 1e-7),
    );
    expect(
      enemy.stats.damage.toDouble(),
      closeTo(definition.baseDamage * pow(1.065, 10), 1e-7),
    );
    expect(
      enemy.gold.toDouble(),
      closeTo(definition.rewardGold * pow(1.10, 10), 1e-7),
    );
  });
  test(
    'book chance extremes and guaranteed gold are independent of visuals',
    () {
      Enemy enemy(double chance) => EnemyFactory().create(
        EnemyDefinition(
          id: 'test',
          name: 'Test',
          baseHp: 1,
          baseDamage: 1,
          attackSpeed: 1,
          rewardGold: 10,
          rewardXp: 1,
          rewardBookChance: chance,
          animations: 'slime',
        ),
        0,
      );
      final drops = DropSystem(Random(1));
      expect(drops.roll(enemy(0)).books.isZero, true);
      final reward = drops.roll(enemy(1));
      expect(reward.books.toDouble(), 1);
      expect(reward.gold.toDouble(), closeTo(10, 1e-8));
    },
  );
  test('vertical slice travels, fights, rewards, continues and respawns', () {
    final game = GameSimulation(random: Random(3));
    for (var i = 0; i < 1200; i++) {
      game.advance(1 / 30);
    }
    expect(game.kills, greaterThan(0));
    expect(game.distance, greaterThan(90));
    expect(game.character.gold.isZero, false);
    game.killHero();
    expect(game.phase, GamePhase.heroDeath);
    for (var i = 0; i < 80; i++) {
      game.advance(1 / 30);
    }
    expect(game.phase, GamePhase.traveling);
    expect(game.heroHp.ratio(game.stats.maxHp), closeTo(1, 1e-8));
  });
  test('fixed-step outcomes match across refresh rates', () {
    final a = GameSimulation(random: Random(9)),
        b = GameSimulation(random: Random(9));
    for (var i = 0; i < 3600; i++) {
      a.advance(1 / 60);
    }
    for (var i = 0; i < 900; i++) {
      b.advance(1 / 15);
    }
    expect(a.phase, b.phase);
    expect(a.kills, b.kills);
    expect(a.distance, closeTo(b.distance, .01));
    expect(a.character.gold.log10, closeTo(b.character.gold.log10, 1e-8));
  });
  test('state machine rejects illegal transitions', () {
    expect(
      () => GameStateMachine().transition(GamePhase.reward),
      throwsStateError,
    );
  });
}
