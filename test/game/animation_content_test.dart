import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/content/animations/hero/variants.dart';
import 'package:idle_companion/core/animation/graph/selection_policy.dart';
import 'package:idle_companion/core/animation/graph/transition.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

class CountingRandom implements Random {
  CountingRandom(this.roll);
  final double roll;
  int calls = 0;
  @override
  double nextDouble() {
    calls++;
    return roll;
  }

  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  test('packing recipes match runtime atlas geometry and shared poses', () {
    final resources = defaultAnimationResources();
    const clips = {
      'walk_v2': 'hero.walk',
      'attack_v1': 'hero.attack',
      'death_v1': 'hero.death',
      'seated_v1': 'hero.seated',
      'sit_down_v1': 'hero.sitDown',
      'sharpen_v1': 'hero.sharpen',
      'stand_up_v1': 'hero.standUp',
    };
    for (final entry in clips.entries) {
      final manifest =
          jsonDecode(
                File('art/hero/${entry.key}/manifest.json').readAsStringSync(),
              )
              as Map;
      final clip = resources.clip(ClipId(entry.value));
      final frames = manifest['frames'] as List? ?? [manifest];
      expect(clip.frames.length, frames.length);
      for (var index = 0; index < frames.length; index++) {
        final authored = frames[index] as Map;
        final frame = resources.frame(clip.frames[index].frameId);
        expect(frame.source.width, manifest['size']);
        expect(frame.source.height, manifest['size']);
        if (authored.containsKey('copy') || entry.key == 'seated_v1') {
          expect(frame.asset, 'assets/characters/hero/seated.png');
          expect(frame.source.x, 0);
        } else {
          expect(frame.asset, manifest['output']);
          expect(frame.source.x, index * (manifest['size'] as int));
        }
      }
    }
  });

  test(
    'second activity/stand use existing frames and cleanup to exact neutral',
    () {
      final original = defaultAnimationResources();
      final demo = demoAnimationResources();
      expect(demo.frames.keys, orderedEquals(original.frames.keys));
      expect(demo.rigs.keys, orderedEquals(original.rigs.keys));
      for (final variant in [
        ...HeroRestVariants.demoActivities,
        ...HeroRestVariants.demoStandUps,
      ]) {
        variant.validate(demo);
      }
      final cleanup = demo.clip(HeroClips.sharpenCleanup);
      expect(cleanup.exitPose?.pose, PoseId.seatedNeutral);
      expect(
        cleanup.frames.last.frameId,
        demo.pose(PoseId.seatedNeutral).frameId,
      );
      final game = GameSimulation(
        random: Random(7),
        idleRandom: CountingRandom(.99),
        resources: demo,
        restGraph: HeroRestGraphs.authoringDemo(),
      );
      game.encounterRemaining = 1e6;
      game.idle.setIdleSeconds(120);
      game.advance(2);
      expect(game.heroPlayback.clipId, HeroClips.sharpenSlow);
      final distance = game.distance;
      game.idle.setIdleSeconds(0);
      final observed = <ClipId?>{};
      for (var i = 0; i < 200 && game.isResting; i++) {
        observed.add(game.heroPlayback.clipId);
        game.spawnEnemy();
        expect(game.enemy, isNull);
        game.advance(1 / 30);
      }
      expect(
        observed,
        containsAll([
          HeroClips.sharpenSlow,
          HeroClips.sharpenCleanup,
          HeroClips.standCareful,
        ]),
      );
      expect(game.heroPlayback.clipId, const ClipId('hero.walk'));
      expect(game.distance, greaterThanOrEqualTo(distance));
    },
  );

  test(
    'variant metadata rejects unsupported facts and false pose contracts',
    () {
      for (final invalid in [
        HeroRestVariant(
          id: const VariantId('bad'),
          nodeId: HeroRestGraphs.sharpen,
          clipId: const ClipId('hero.sharpen'),
          entryPose: HeroRestVariants.seated,
          exitPose: HeroRestVariants.seatedFamily,
          conditions: const [GraphCondition(GraphFactId('unknown'))],
        ),
        HeroRestVariant(
          id: const VariantId('bad'),
          nodeId: HeroRestGraphs.sharpen,
          clipId: const ClipId('hero.sharpen'),
          entryPose: HeroRestVariants.standing,
          exitPose: HeroRestVariants.seatedFamily,
        ),
      ]) {
        expect(
          () => HeroRestGraphs.seatedRest(activities: [invalid]),
          throwsArgumentError,
        );
      }
    },
  );

  RestCoordinator blocked(CountingRandom random) {
    final activity = HeroRestVariant(
      id: const VariantId('limited'),
      nodeId: HeroRestGraphs.sharpen,
      clipId: const ClipId('hero.sharpen'),
      entryPose: HeroRestVariants.seated,
      exitPose: HeroRestVariants.seatedFamily,
      cooldown: const VariantCooldown(CooldownKey('limited'), 10),
    );
    final rest = RestCoordinator(
      random,
      defaultAnimationResources(),
      graph: HeroRestGraphs.seatedRest(activities: [activity]),
    );
    rest.policy.started(activity.choice, 0);
    rest.setIdleSeconds(30);
    return rest;
  }

  test(
    'cooldown/variant results match large steps and 30/60 FPS at x1/x5/x20',
    () {
      final reference = blocked(CountingRandom(.2))..advance(11);
      for (final fps in [30, 60]) {
        for (final speed in [1, 5, 20]) {
          final rest = blocked(CountingRandom(.2));
          var clock = 0.0;
          while (clock < 11) {
            final dt = min(speed / fps, 11 - clock);
            rest.advance(dt);
            clock += dt;
          }
          expect(
            rest.graphRunner!.snapshot.nodeId,
            reference.graphRunner!.snapshot.nodeId,
          );
          expect(rest.graphRunner!.snapshot.nodeElapsed, closeTo(1, 1e-8));
          expect(
            rest.graphRunner!.snapshot.frameId,
            reference.graphRunner!.snapshot.frameId,
          );
        }
      }
    },
  );
}
