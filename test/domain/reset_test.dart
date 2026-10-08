import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/domain/activity/activity_statistics.dart';
import 'package:idle_companion/domain/activity/idle_animation.dart';
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
      final idle = IdleBehaviorSystem(Random(2), AnimationCatalog())
        ..setIdleSeconds(300);
      idle.update(.1);
      idle.reset();
      expect(idle.animationId, null);
      expect(idle.level, IdleLevel.active);
    },
  );
}
