import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
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
      expect(game.heroPlayback.displayLabel, 'hero.idle');

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
      expect(game.heroPlayback.graphId, isNotNull);
    });
  }

  test('rest animations wait for the existing encounter and rewards', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    final enemy = game.enemy;
    game.idle.setIdleSeconds(300);
    game.advance(GameBalance.approachDuration + .1);
    expect(game.phase, GamePhase.combat);
    expect(game.enemy, same(enemy));
    expect(game.isResting, false);
    expect(game.heroPlayback.graphId, isNull);
    final hp = game.heroHp;
    game.advance(.4);
    expect(game.heroHp < hp, true);
    expect(game.heroPlayback.graphId, isNull);
    game.killEnemy();
    game.advance(1);
    expect(game.phase, GamePhase.reward);
    expect(game.heroPlayback.graphId, isNull);
    game.advance(1);
    expect(game.isResting, true);
    expect(game.heroPlayback.graphId, isNotNull);
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

  test('returning during combat cancels the pending rest', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.idle.setIdleSeconds(300);
    game.advance(GameBalance.approachDuration + .1);
    expect(game.heroPlayback.graphId, isNull);
    game.idle.setIdleSeconds(0);
    game.killEnemy();
    final distance = game.distance;
    game.advance(2);
    expect(game.phase, GamePhase.traveling);
    expect(game.isResting, false);
    expect(game.heroPlayback.displayLabel, 'hero.walk');
    expect(game.heroPlayback.graphId, isNull);
    expect(game.distance, greaterThan(distance));
  });
  test('death and respawn finish before rest resumes', () {
    final game = GameSimulation(random: Random(1));
    game.idle.setIdleSeconds(300);
    game.advance(.1);
    game.killHero();
    expect(game.heroPlayback.displayLabel, 'hero.death');
    game.advance(game.resources.clip(const ClipId('hero.death')).duration + .1);
    expect(game.phase, GamePhase.respawn);
    expect(game.heroPlayback.displayLabel, 'hero.death');
    game.advance(2);
    expect(game.isResting, true);
    expect(game.distance, 0);
    expect(game.enemy, isNull);
    expect(game.heroHp.ratio(game.stats.maxHp), closeTo(1, 1e-8));
  });
  test('suspend gaps award nothing and running frames resume rewards', () {
    final game = GameSimulation(random: Random(3));
    game.spawnEnemy();
    game.killEnemy();
    final character = game.character.toJson();
    final phase = game.phase;
    final distance = game.distance;
    final kills = game.kills;

    game.advance(const Duration(hours: 8).inSeconds.toDouble());

    expect(game.character.toJson(), character);
    expect(game.phase, phase);
    expect(game.distance, distance);
    expect(game.kills, kills);

    for (var i = 0; i < 90; i++) {
      game.advance(1 / 30);
    }
    expect(game.kills, kills + 1);
    expect(game.character.gold.isZero, false);
    expect(!game.character.xp.isZero || game.character.level > 1, true);
  });

  test('headless combat outcomes match 30/60 FPS at x1/x5/x20', () {
    final reference = GameSimulation(random: Random(9));
    for (var i = 0; i < 3600; i++) {
      reference.advance(1 / 60);
    }
    for (final fps in [30, 60]) {
      for (final speed in [1.0, 5.0, 20.0]) {
        final game = GameSimulation(random: Random(9))..speed = speed;
        for (var i = 0; i < 60 * fps / speed; i++) {
          game.advance(1 / fps);
        }
        expect(game.phase, reference.phase, reason: '$fps FPS x$speed');
        expect(game.kills, reference.kills);
        expect(game.stage, reference.stage);
        expect(game.stageKills, reference.stageKills);
        expect(game.distance, closeTo(reference.distance, .01));
        expect(
          game.character.gold.log10,
          closeTo(reference.character.gold.log10, 1e-8),
        );
        expect(game.heroHp.log10, closeTo(reference.heroHp.log10, 1e-8));
      }
    }
  });
}
