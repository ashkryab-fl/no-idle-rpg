import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/balance/progression_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
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
        game.advance(GameBalance.approachDuration + .1);
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
}
