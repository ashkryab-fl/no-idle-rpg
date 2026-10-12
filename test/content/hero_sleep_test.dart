import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/poses.dart';
import 'package:idle_companion/content/animations/hero/sleep_graph.dart';
import 'package:idle_companion/core/animation/graph/graph_definition.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/animation/graph/node.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/animation/playback_snapshot.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/domain/activity/rest_policy.dart';
import 'package:idle_companion/game/animation/hero_animation_coordinator.dart';
import '../helpers/simulation_fixture.dart';

void main() {
  final resources = HeroClips.resources();
  final clip = resources.clip(HeroClips.sleep);
  AnimationGraphRunner runner() => AnimationGraphRunner(
    graph: HeroSleepRestGraph.definition(resources: resources),
    resources: resources,
    selectionPolicy: RestPolicy(Random(1)),
  );
  const entryDuration =
      HeroSleepRestGraph.standingDuration + HeroSleepRestGraph.fadeDuration;

  test(
    'sleep reverses the four poses and holds both sides for four seconds',
    () {
      final graph = runner()..advance(entryDuration);
      const indices = [0, 1, 2, 3, 2, 1, 0];
      for (var cycle = 0; cycle < 2; cycle++) {
        for (var i = 0; i < clip.frames.length; i++) {
          expect(
            graph.snapshot.frameId,
            FrameId('hero.sleepFrames.frame.${indices[i]}'),
          );
          final duration = i == 0 || i == 3 ? 4.0 : .18;
          graph.advance(duration - .001);
          expect(
            graph.snapshot.frameId,
            FrameId('hero.sleepFrames.frame.${indices[i]}'),
          );
          graph.advance(.001);
          expect(
            graph.snapshot.frameId,
            FrameId('hero.sleepFrames.frame.${indices[i + 1]}'),
          );
        }
      }
    },
  );

  test(
    'fade resolves both rigs, preserves flash, and waits for early return',
    () {
      final graph = runner()..advance(.3);
      expect(
        graph.snapshot.fadeFromFrameId,
        const FrameId('hero.idle.frame.0'),
      );
      expect(graph.snapshot.fadeProgress, 0);
      graph.advance(.25);
      final rendered = PlaybackSnapshot.graph(
        graph.snapshot,
        resources,
        generation: 1,
        displayLabel: 'sleep',
      ).withDamageFlash(true);
      expect(rendered.fadeProgress, .5);
      expect(rendered.fadeFromFrame!.id, const FrameId('hero.idle.frame.0'));
      expect(rendered.fadeFromRig!.id, isNot(rendered.rig!.id));
      expect(rendered.frameId, const FrameId('hero.sleepFrames.frame.0'));
      graph.signal(GraphSignalId.activityReturned);
      graph.advance(.249);
      expect(graph.snapshot.nodeId, HeroSleepRestGraph.fadeIn);
      graph.advance(.001);
      expect(graph.snapshot.nodeId, HeroSleepRestGraph.fadeOut);
      expect(
        graph.snapshot.fadeFromFrameId,
        const FrameId('hero.sleepFrames.frame.0'),
      );
      expect(graph.snapshot.frameId, const FrameId('hero.idle.frame.0'));
      graph.advance(.9);
      expect(graph.isCompleted, isTrue);
      graph.reset();
      expect(graph.snapshot.fadeFromFrameId, isNull);
      expect(graph.snapshot.frameId, const FrameId('hero.idle.frame.0'));
    },
  );

  test(
    'wake interrupts either hold immediately and rolls only to a safe side',
    () {
      for (final (elapsed, delay, frame) in [
        (2.0, 0.0, 0),
        (5.0, 0.0, 3),
        (4.05, .31, 3),
        (8.41, .31, 0),
      ]) {
        final graph = runner()..advance(entryDuration + elapsed);
        graph.signal(GraphSignalId.activityReturned);
        graph.advance(delay);
        expect(graph.snapshot.nodeId, HeroSleepRestGraph.fadeOut);
        expect(
          graph.snapshot.fadeFromFrameId,
          FrameId('hero.sleepFrames.frame.$frame'),
        );
        expect(graph.snapshot.fadeProgress, closeTo(0, 1e-9));
      }
    },
  );

  test(
    'whole and partitioned updates preserve fade clocks and unused time',
    () {
      for (final split in [false, true]) {
        final graph = runner();
        if (split) {
          for (var i = 0; i < 55; i++) {
            graph.advance(.01);
          }
        } else {
          graph.advance(.55);
        }
        expect(graph.snapshot.fadeProgress, closeTo(.5, 1e-9));
        graph.advance(5);
        graph.signal(GraphSignalId.activityReturned);
        final result = graph.advance(2);
        expect(graph.isCompleted, isTrue);
        expect(result.remaining, closeTo(1.2, 1e-9));
      }
    },
  );

  test('sleep selected once blocks travel through standing and both fades', () {
    final rest = RestCoordinator(ConstantRandom(.95), resources);
    final hero = HeroAnimationCoordinator(resources, rest: rest);
    rest.setIdleSeconds(1000);
    hero.advance(1);
    expect(rest.graphRunner, isNull);
    hero.advance(.01);
    expect(hero.snapshot.nodeId, HeroSleepRestGraph.standing);
    hero.advance(entryDuration + 1);
    expect(hero.snapshot.nodeId, HeroSleepRestGraph.sleep);
    expect(hero.advance(100), 0);
    rest.setIdleSeconds(0);
    hero.advance(0);
    expect(hero.snapshot.nodeId, HeroSleepRestGraph.fadeOut);
    expect(hero.advance(.799), 0);
    expect(hero.blocksAdventure, isTrue);
    expect(hero.advance(.101), closeTo(.1, 1e-9));
    expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.0'));
    expect(hero.restReturnRevision, 1);
  });

  test('invalid fades are rejected before playback', () {
    for (final duration in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => AnimationGraphRunner(
          graph: AnimationGraphDefinition(
            id: const GraphId('test.fade'),
            entryNode: const NodeId('test.fade'),
            nodes: [
              FadePose(
                id: const NodeId('test.fade'),
                poseId: HeroPoses.sleepFacing,
                fromPoseId: HeroPoses.standing,
                duration: duration,
              ),
            ],
          ),
          resources: resources,
          selectionPolicy: RestPolicy(Random(1)),
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => AnimationGraphRunner(
        graph: AnimationGraphDefinition(
          id: const GraphId('test.fade'),
          entryNode: const NodeId('test.fade'),
          nodes: [
            FadePose(
              id: const NodeId('test.fade'),
              poseId: HeroPoses.sleepFacing,
              duration: .5,
            ),
          ],
        ),
        resources: resources,
        selectionPolicy: RestPolicy(Random(1)),
      ),
      throwsArgumentError,
    );
  });
}
