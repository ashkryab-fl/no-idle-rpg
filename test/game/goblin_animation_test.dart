import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/enemies/goblin_clips.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/game/animation/enemy_animation_coordinator.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';

class GoblinRoll implements Random {
  @override
  double nextDouble() => .99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  test('spawn pool contains only the installed goblin', () {
    final spawner = EnemySpawner(Random(17));
    expect(EnemyCatalog.definitions.map((enemy) => enemy.id), ['gobli_low']);
    for (var tier = 0; tier < 50; tier++) {
      final enemy = spawner.spawn(tier);
      expect(enemy.definition.id, 'gobli_low');
      expect(enemy.definition.animations, same(GoblinClips.content));
      expect(File(GoblinClips.asset).existsSync(), true);
    }
  });

  test('goblin waits in guard throughout approach and between attacks', () {
    final game = GameSimulation(random: GoblinRoll());
    game.spawnEnemy();
    expect(game.enemy!.definition.id, 'gobli_low');
    final guard = game.enemyPlayback!.frameId;
    expect(game.enemyPlayback!.clipId, GoblinClips.idleId);
    game.advance(GameBalance.approachDuration - .2);
    expect(game.phase, GamePhase.enemyApproach);
    expect(game.enemyPlayback!.frameId, guard);
    expect(game.enemyPlayback!.elapsed, 0);
    expect(game.enemyAnimations.combatPlayback.elapsed, 0);
    expect(game.events.where((event) => event.kind == 'hit'), isEmpty);
    game.advance(.4);
    expect(game.phase, GamePhase.combat);
    expect(game.enemyPlayback!.clipId, GoblinClips.attackId);
    expect(game.enemyPlayback!.frameIndex, greaterThan(0));
    game.advance(.5);
    expect(game.phase, GamePhase.combat);
    expect(game.enemyPlayback!.clipId, GoblinClips.idleId);
    expect(game.enemyPlayback!.frameId, guard);
  });

  test('knife impact, guard and death share the installed atlas and rig', () {
    final resources = defaultAnimationResources();
    final enemy = EnemyAnimationCoordinator(resources);
    enemy.synchronize(GoblinClips.content, EnemyAnimationRequest.combat);
    final events = enemy.combatPlayback.advance(GameBalance.damageTiming, 1);
    expect(events.single.marker.kind, AnimationMarkerKind.damage);
    expect(enemy.snapshot!.frameIndex, 4);
    expect(enemy.snapshot!.frame!.asset, GoblinClips.asset);
    expect(enemy.snapshot!.rig!.anchorX, 427 / 512);
    expect(enemy.snapshot!.rig!.anchorY, 469 / 512);
    enemy.combatPlayback.advance(.3, 1);
    final guard = enemy.snapshot!.frameId;
    expect(enemy.snapshot!.clipId, GoblinClips.idleId);
    expect(guard, resources.clip(GoblinClips.attackId).frames.first.frameId);
    enemy.synchronize(GoblinClips.content, EnemyAnimationRequest.death);
    enemy.advance(GameBalance.deathDuration);
    expect(enemy.deathCompleted, true);
    expect(enemy.snapshot!.frameId, guard);
    expect(enemy.snapshot!.completed, true);
  });

  test('packing order and runtime timeline use all seven authored cells', () {
    final manifest =
        jsonDecode(File('art/enemy/gobli_low/manifest.json').readAsStringSync())
            as Map;
    expect(
      (manifest['frames'] as List).map((frame) => (frame as Map)['copy']),
      [0, 1, 0, 2, 3, 2, 0].map((index) => 'aligned_sources/$index.png'),
    );
    final resources = defaultAnimationResources();
    final clip = resources.clip(GoblinClips.attackId);
    expect(clip.frames, hasLength(7));
    expect(clip.duration, closeTo(GameBalance.attackDuration, 1e-12));
    expect(clip.loopRange, isNull);
    for (var i = 0; i < 7; i++) {
      final frame = resources.frame(clip.frames[i].frameId);
      expect(frame.source.x, i * 512);
      expect(frame.source.width, 512);
      expect(frame.asset, manifest['output']);
    }
    expect(
      resources.pose(const PoseId('enemy.gobliLow.guard')).frameId,
      clip.frames.first.frameId,
    );
  });
}
