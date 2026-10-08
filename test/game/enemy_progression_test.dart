import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
  test('enemy tiers and rewards advance only at victory milestones', () {
    final definition = EnemyCatalog.definitions.first;
    final spawner = EnemySpawner(Random(1), definitions: [definition]);
    for (final kills in [0, 11, 12, 23, 24]) {
      final tier = kills ~/ GameBalance.tierKills;
      final enemy = spawner.spawn(tier);
      final game = GameSimulation(random: Random(1))
        ..enemyProgressKills = kills;
      game.spawnEnemy();
      expect(game.enemyTier, tier);
      expect(
        game.enemy!.stats.maxHp.toDouble(),
        closeTo(
          game.enemy!.definition.baseHp * pow(GameBalance.hpGrowth, tier),
          1e-8,
        ),
      );
      expect(
        enemy.stats.maxHp.toDouble(),
        closeTo(definition.baseHp * pow(GameBalance.hpGrowth, tier), 1e-8),
      );
      expect(
        enemy.stats.damage.toDouble(),
        closeTo(
          definition.baseDamage * pow(GameBalance.damageGrowth, tier),
          1e-8,
        ),
      );
      expect(
        enemy.gold.toDouble(),
        closeTo(
          definition.rewardGold * pow(GameBalance.rewardGrowth, tier),
          1e-8,
        ),
      );
      expect(
        enemy.xp.toDouble(),
        closeTo(
          definition.rewardXp * pow(GameBalance.rewardGrowth, tier),
          1e-8,
        ),
      );
    }
  });

  test('distance and repeated losses cannot advance the next enemy', () {
    final game = GameSimulation(random: Random(1))
      ..distance = 1000000
      ..kills = GameBalance.tierKills - 1
      ..enemyProgressKills = GameBalance.tierKills - 1;
    game.spawnEnemy();
    final original = game.enemy!;
    expect(
      original.stats.maxHp.toDouble(),
      closeTo(original.definition.baseHp, 1e-8),
    );
    final gold = game.character.gold;
    final xp = game.character.xp;
    final books = game.character.books;
    final distance = game.distance;

    for (var attempt = 0; attempt < 5; attempt++) {
      game.advance(1.2);
      expect(game.phase, GamePhase.combat);
      game.heroHp = Amount.one;
      game.advance(.4);
      expect(original.hp < original.stats.maxHp, isTrue);
      expect(game.phase, GamePhase.heroDeath);
      game.advance(3);
      expect(game.phase, GamePhase.traveling);
      expect(game.kills, GameBalance.tierKills - 1);
      expect(game.character.gold, gold);
      expect(game.character.xp, xp);
      expect(game.character.books, books);
      expect(game.heroHp.ratio(game.stats.maxHp), closeTo(1, 1e-8));
      game.spawnEnemy();
      expect(game.enemy, same(original));
      expect(game.enemy!.hp, original.stats.maxHp);
    }
    expect(game.distance, greaterThan(distance));

    game.killEnemy();
    game.advance(2);
    expect(game.phase, GamePhase.traveling);
    expect(game.kills, GameBalance.tierKills);
    expect(game.character.gold > gold, isTrue);
    game.spawnEnemy();
    final next = game.enemy!;
    expect(next, isNot(same(original)));
    expect(
      next.stats.maxHp.toDouble(),
      closeTo(next.definition.baseHp * GameBalance.hpGrowth, 1e-8),
    );
    expect(
      next.stats.damage.toDouble(),
      closeTo(next.definition.baseDamage * GameBalance.damageGrowth, 1e-8),
    );
  });

  test('each combat death drops one tier and weakens the retry', () {
    final game = GameSimulation(random: Random(1))
      ..kills = 100
      ..enemyProgressKills = 2 * GameBalance.tierKills + 1;
    game.spawnEnemy();
    final definition = game.enemy!.definition;
    final gold = game.character.gold;
    final xp = game.character.xp;

    for (var attempt = 0; attempt < 4; attempt++) {
      final previousTier = game.enemyTier;
      game.advance(1.2);
      game.heroHp = Amount.one;
      game.advance(.4);
      expect(game.phase, GamePhase.heroDeath);
      final nextTier = max(0, previousTier - 1);
      expect(game.enemyTier, nextTier);
      expect(game.enemyProgressKills, nextTier * GameBalance.tierKills + 1);
      expect(game.kills, 100);
      expect(game.character.gold, gold);
      expect(game.character.xp, xp);
      // Repeated debug calls during death/respawn must not apply another drop.
      game.killHero();
      expect(game.enemyTier, nextTier);
      game.advance(game.animations.get('hero.death').duration + .05);
      expect(game.phase, GamePhase.respawn);
      game.killHero();
      expect(game.enemyTier, nextTier);
      game.advance(GameBalance.respawnDuration + .1);
      expect(game.phase, GamePhase.traveling);
      game.spawnEnemy();
      final retry = game.enemy!;
      expect(retry.definition, same(definition));
      expect(retry.hp, same(retry.stats.maxHp));
      expect(
        retry.stats.maxHp.toDouble(),
        closeTo(definition.baseHp * pow(GameBalance.hpGrowth, nextTier), 1e-8),
      );
      expect(
        retry.stats.damage.toDouble(),
        closeTo(
          definition.baseDamage * pow(GameBalance.damageGrowth, nextTier),
          1e-8,
        ),
      );
      expect(
        retry.gold.toDouble(),
        closeTo(
          definition.rewardGold * pow(GameBalance.rewardGrowth, nextTier),
          1e-8,
        ),
      );
      expect(
        retry.xp.toDouble(),
        closeTo(
          definition.rewardXp * pow(GameBalance.rewardGrowth, nextTier),
          1e-8,
        ),
      );
    }
  });

  test('debug death drops a tier and victories resume the saved progress', () {
    final game = GameSimulation(random: Random(1))
      ..kills = 100
      ..enemyProgressKills = 3 * GameBalance.tierKills - 1;
    expect(game.enemyTier, 2);
    // Death while traveling follows the same difficulty rule as combat death.
    game.killHero();
    expect(game.enemyTier, 1);
    expect(game.enemyProgressKills, 2 * GameBalance.tierKills - 1);
    game.advance(3);
    game.spawnEnemy();
    game.killEnemy();
    game.advance(2);
    expect(game.kills, 101);
    expect(game.enemyTier, 2);
    game.spawnEnemy();
    expect(
      game.enemy!.stats.damage.toDouble(),
      closeTo(
        game.enemy!.definition.baseDamage * pow(GameBalance.damageGrowth, 2),
        1e-8,
      ),
    );
  });

  test('reset clears the opponent waiting for a retry', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    final original = game.enemy!;
    game.killHero();
    game.advance(3);
    game.resetEncounter();
    game.spawnEnemy();
    expect(game.enemy, isNot(same(original)));
  });
}
