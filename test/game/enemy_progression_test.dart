import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/balance/progression_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
  test('enemy HP, damage and rewards scale exponentially with stage', () {
    for (final stage in [1, 2, 10, 100]) {
      final game = GameSimulation(random: Random(1))..stage = stage;
      game.spawnEnemy();
      final enemy = game.enemy!, definition = enemy.definition;
      expect(
        enemy.stats.maxHp.toDouble(),
        closeTo(
          definition.baseHp * pow(ProgressionBalance.hpGrowth, stage - 1),
          .0001,
        ),
      );
      expect(
        enemy.stats.damage.toDouble(),
        closeTo(
          definition.baseDamage *
              pow(ProgressionBalance.damageGrowth, stage - 1),
          .0001,
        ),
      );
      expect(
        enemy.gold.toDouble(),
        closeTo(
          definition.rewardGold *
              pow(ProgressionBalance.goldRewardGrowth, stage - 1),
          .0001,
        ),
      );
      expect(
        enemy.xp.toDouble(),
        closeTo(
          definition.rewardXp *
              pow(ProgressionBalance.xpRewardGrowth, stage - 1),
          .0001,
        ),
      );
    }
  });

  test('distance, lifetime victories and hero XP do not advance the stage', () {
    final game = GameSimulation(random: Random(1))
      ..distance = 1000000
      ..kills = 1000000;
    game.progression.addXp(game.character, Amount.fromNum(1000));
    expect(game.character.level, greaterThan(1));
    expect(
      game.stats.damage > Amount.fromNum(ProgressionBalance.heroDamage),
      isTrue,
    );
    expect(
      game.stats.maxHp > Amount.fromNum(ProgressionBalance.heroHp),
      isTrue,
    );
    game.spawnEnemy();
    expect(game.stage, 1);
    expect(game.stageKills, 0);
    expect(
      game.enemy!.stats.maxHp.toDouble(),
      closeTo(game.enemy!.definition.baseHp, 1e-8),
    );
    final enemy = game.enemy;
    game.advance(1.2);
    expect(game.enemy, same(enemy));
    expect(game.stage, 1);
  });

  test('only completed victories unlock the next stage', () {
    final game = GameSimulation(random: Random(1))
      ..stage = 9
      ..stageKills = ProgressionBalance.enemiesPerStage - 1;
    game.spawnEnemy();
    game.killEnemy();
    expect(game.stage, 9);
    expect(game.stageKills, ProgressionBalance.enemiesPerStage - 1);
    game.advance(2);
    expect(game.phase, GamePhase.traveling);
    expect(game.stage, 10);
    expect(game.stageKills, 0);
    expect(game.kills, 1);
    game.spawnEnemy();
    expect(
      game.enemy!.stats.maxHp.toDouble(),
      closeTo(
        game.enemy!.definition.baseHp * pow(ProgressionBalance.hpGrowth, 9),
        1e-8,
      ),
    );
  });

  test(
    '10 to 9 to 10 farming replays a full stage and keeps gold and upgrades',
    () {
      final game = GameSimulation(random: Random(1))
        ..stage = 10
        ..stageKills = 8
        ..kills = 100;
      game.character
        ..level = 10
        ..xp = Amount.fromNum(25)
        ..gold = Amount.fromNum(100)
        ..books = Amount.fromNum(10);
      game.character.equipment['weapon'] = 2;
      game.character.upgrades['hp'] = 3;
      var previousGold = game.character.gold;
      for (var cycle = 0; cycle < 2; cycle++) {
        final heroLevel = game.character.level;
        final xp = game.character.xp;
        final books = game.character.books;
        game.spawnEnemy();
        game.advance(1.2);
        game.heroHp = Amount.one;
        game.advance(.4);
        expect(game.phase, GamePhase.heroDeath);
        expect(game.stage, 9);
        expect(game.stageKills, 0);
        expect(game.character.level, heroLevel);
        expect(game.character.xp, same(xp));
        expect(game.character.gold, same(previousGold));
        expect(game.character.books, same(books));
        expect(game.character.equipment['weapon'], 2);
        expect(game.character.upgrades['hp'], 3);
        game.advance(3);
        expect(game.phase, GamePhase.traveling);
        expect(game.heroHp.ratio(game.stats.maxHp), closeTo(1, 1e-8));
        for (var kill = 1; kill <= ProgressionBalance.enemiesPerStage; kill++) {
          game.spawnEnemy();
          expect(
            game.enemy!.stats.damage.toDouble(),
            closeTo(
              game.enemy!.definition.baseDamage *
                  pow(ProgressionBalance.damageGrowth, 8),
              1e-8,
            ),
          );
          game.killEnemy();
          game.advance(2);
          expect(game.phase, GamePhase.traveling);
          expect(
            game.stage,
            kill < ProgressionBalance.enemiesPerStage ? 9 : 10,
          );
          expect(game.stageKills, kill % ProgressionBalance.enemiesPerStage);
        }
        expect(game.character.gold > previousGold, isTrue);
        expect(
          game.kills,
          100 + (cycle + 1) * ProgressionBalance.enemiesPerStage,
        );
        expect(game.character.level, greaterThanOrEqualTo(heroLevel));
        previousGold = game.character.gold;
      }
    },
  );

  test(
    'one rollback per death, stage floor is 1 and partial progress resets',
    () {
      final game = GameSimulation(random: Random(1))
        ..stage = 2
        ..stageKills = 7;
      game.character.level = 10;
      game.character.xp = Amount.fromNum(20);
      for (var attempt = 0; attempt < 3; attempt++) {
        game.killHero();
        expect(game.stage, 1);
        expect(game.stageKills, 0);
        game.killHero();
        expect(game.stage, 1);
        game.advance(game.animations.get('hero.death').duration + .05);
        expect(game.phase, GamePhase.respawn);
        game.killHero();
        expect(game.stage, 1);
        game.advance(GameBalance.respawnDuration + .1);
        expect(game.phase, GamePhase.traveling);
        expect(game.character.level, 10);
        expect(game.character.xp.toDouble(), closeTo(20, 1e-8));
        game.stageKills = 5;
      }
    },
  );
}
