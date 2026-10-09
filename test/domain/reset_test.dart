import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/domain/activity/activity_statistics.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/domain/activity/idle_level.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

void main() {
  test(
    'reset clears pending enemy rewards and activity session boundaries',
    () {
      final game = GameSimulation(random: Random(2));
      game.spawnEnemy();
      game.killEnemy();
      game.resetEncounter();
      for (var i = 0; i < 30; i++) {
        game.advance(1 / 30);
      }
      expect(game.phase, GamePhase.traveling);
      expect(game.kills, 0);
      expect(game.character.gold.isZero, true);
      final t = DateTime(2026, 10, 8, 12);
      final activity = ActivityStatisticsService(now: t);
      activity.sample(t, true);
      activity.sample(t.add(const Duration(seconds: 5)), true);
      activity.reset(t.add(const Duration(seconds: 6)));
      activity.sample(t.add(const Duration(seconds: 7)), false);
      expect(activity.total.activeSeconds, 0);
      expect(activity.sessionSeconds, 0);
      final idle = RestCoordinator(Random(2), defaultAnimationResources())
        ..setIdleSeconds(300);
      idle.advance(.1);
      idle.reset();
      expect(idle.graphRunner, null);
      expect(idle.level, IdleLevel.active);
    },
  );
}
