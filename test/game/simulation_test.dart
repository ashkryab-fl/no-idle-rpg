import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';
import 'package:idle_companion/game/systems/drop_system.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
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
      closeTo(definition.rewardGold * pow(1.07, 10), 1e-7),
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
