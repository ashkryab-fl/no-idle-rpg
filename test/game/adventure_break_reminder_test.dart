import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/debug_previews.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../helpers/simulation_fixture.dart';

GameSimulation travelingGame() {
  final game = GameSimulation(random: Random(7));
  game.advance(.1);
  game.encounterRemaining = 1e9;
  game.breakReminder.reset();
  return game;
}

void main() {
  test('Reminder uses real time at normal and accelerated speeds', () {
    for (final speed in [1.0, 5.0, 20.0]) {
      final game = travelingGame()..speed = speed;
      game.breakReminder.advance(2399);
      game.advance(.5);
      expect(game.breakReminder.revision, 0);
      game.advance(.5);
      expect(game.breakReminder.revision, 1);
      expect(game.breakReminder.elapsedSeconds, closeTo(2400, 1e-6));
    }
  });

  test(
    'Encounters count; requested rest waits until the encounter finishes',
    () {
      final game = travelingGame();
      game.breakReminder.advance(100);
      game.spawnEnemy();
      game.idle.setIdleSeconds(31);
      game.advance(.1);
      expect(game.phase, GamePhase.enemyApproach);
      expect(game.breakReminder.elapsedSeconds, closeTo(100.1, 1e-6));
      game.machine.transition(GamePhase.combat);
      game.advance(.1);
      expect(game.breakReminder.elapsedSeconds, closeTo(100.2, 1e-6));
      game.killEnemy();
      until(game, () => game.isResting);
      game.advance(.1);
      expect(game.breakReminder.elapsedSeconds, 0);
    },
  );

  test('Only actual rest restarts the streak', () {
    final game = travelingGame();
    game.breakReminder.advance(2399);
    game.idle.setIdleSeconds(31);
    game.advance(.1);
    expect(game.isResting, isTrue);
    expect(game.breakReminder.elapsedSeconds, 0);
    expect(game.breakReminder.revision, 0);
  });

  test('Death preserves the first deadline and the three-minute cadence', () {
    for (final elapsed in [2399.0, 2579.0]) {
      final game = travelingGame();
      game.breakReminder.advance(elapsed);
      final revision = game.breakReminder.revision;
      game.killHero();
      expect(game.breakReminder.elapsedSeconds, elapsed);
      game.advance(1);
      expect(game.phase, GamePhase.heroDeath);
      expect(game.breakReminder.revision, revision + 1);
      until(game, () => game.phase == GamePhase.respawn);
      final beforeRespawn = game.breakReminder.elapsedSeconds;
      game.advance(.1);
      expect(game.phase, GamePhase.respawn);
      expect(
        game.breakReminder.elapsedSeconds,
        closeTo(beforeRespawn + .1, 1e-6),
      );
      until(game, () => game.phase == GamePhase.traveling);
      expect(game.breakReminder.elapsedSeconds, greaterThan(beforeRespawn));
      game.idle.setIdleSeconds(31);
      game.advance(.1);
      expect(game.breakReminder.elapsedSeconds, 0);
    }
  });

  test('Encounter resets and suspend gaps preserve elapsed time', () {
    final game = travelingGame();
    game.breakReminder.advance(100);
    game.resetEncounter();
    expect(game.breakReminder.elapsedSeconds, 100);
    game.restoreAdventure(game.captureAdventure());
    expect(game.breakReminder.elapsedSeconds, 100);
    game.advance(60);
    expect(game.breakReminder.elapsedSeconds, 100);
  });

  test(
    'Animation previews do not count and a restart begins a fresh streak',
    () {
      final game = travelingGame();
      game.breakReminder.advance(2399);
      game.heroAnimations.startPreview(HeroAnimationPreview.values.first);
      game.advance(1);
      expect(game.breakReminder.elapsedSeconds, 2399);
      expect(game.breakReminder.revision, 0);
      final saved = GameSimulation(random: Random(8));
      saved.breakReminder.advance(2399);
      expect(restart(saved).breakReminder.elapsedSeconds, 0);
    },
  );
}
