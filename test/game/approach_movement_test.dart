import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
  test('enemy, scenery and road share displacement until combat starts', () {
    final game = GameSimulation(random: Random(1))
      ..distance = 799.5
      ..scroll = 399.5;
    game.spawnEnemy();
    final initialDistance = game.distance;
    final worldX = game.enemyX + game.distance;
    final guard = game.enemyPlayback!.frameId;
    expect(game.enemyX, GameBalance.enemySpawnX);
    expect(game.scrollSpeed, GameBalance.movementSpeed);
    while (game.phase == GamePhase.enemyApproach) {
      final x = game.enemyX;
      final distance = game.distance;
      game.advance(1 / 60);
      final movement = game.distance - distance;
      expect(x - game.enemyX, closeTo(movement, 1e-9));
      expect(game.enemyX + game.distance, closeTo(worldX, 1e-9));
      expect(game.scroll, closeTo(game.distance % 400, 1e-8));
      expect(
        game.enemyX,
        greaterThanOrEqualTo(GameBalance.enemyCombatX - 1e-9),
      );
      if (game.phase == GamePhase.enemyApproach) {
        expect(movement, closeTo(GameBalance.movementSpeed / 60, 1e-9));
        expect(game.enemyPlayback!.frameId, guard);
        expect(game.events.where((event) => event.kind == 'hit'), isEmpty);
      }
    }
    expect(game.phase, GamePhase.combat);
    expect(game.enemyX, closeTo(GameBalance.enemyCombatX, 1e-9));
    expect(
      game.distance - initialDistance,
      closeTo(GameBalance.enemyApproachDistance, 1e-9),
    );
    final stoppedDistance = game.distance;
    game.advance(.25);
    expect(game.distance, stoppedDistance);
    expect(game.scrollSpeed, 0);
    expect(game.enemyX + game.distance, closeTo(worldX, 1e-9));
  });

  test('arrival stays aligned at 30/60 FPS and x1/x5/x20', () {
    for (final fps in [30, 60]) {
      for (final speed in [1.0, 5.0, 20.0]) {
        final game = GameSimulation(random: Random(1))..speed = speed;
        game.spawnEnemy();
        final steps = (GameBalance.approachDuration * fps / speed).ceil();
        for (var i = 0; i < steps; i++) {
          game.advance(1 / fps);
          expect(
            game.enemyX + game.distance,
            closeTo(GameBalance.enemySpawnX, 1e-9),
          );
        }
        expect(game.phase, GamePhase.combat, reason: '$fps FPS x$speed');
        expect(game.distance, closeTo(GameBalance.enemyApproachDistance, 1e-9));
        expect(game.enemyX, closeTo(GameBalance.enemyCombatX, 1e-9));
      }
    }
  });

  test('interrupting approach keeps the enemy at its world position', () {
    final game = GameSimulation(random: Random(1));
    game.spawnEnemy();
    game.advance(.5);
    final x = game.enemyX;
    final distance = game.distance;
    game.killEnemy();
    game.advance(.3);
    expect(game.phase, GamePhase.enemyDeath);
    expect(game.enemyX, x);
    expect(game.distance, distance);
  });
}
