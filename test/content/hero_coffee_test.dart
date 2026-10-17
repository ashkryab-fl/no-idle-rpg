import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/coffee_graph.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/domain/activity/rest_policy.dart';
import 'package:idle_companion/game/animation/hero_animation_coordinator.dart';
import '../helpers/simulation_fixture.dart';

void main() {
  final resources = HeroClips.resources();
  final enter = resources.clip(HeroClips.coffeeEnter);
  final coffee = resources.clip(HeroClips.coffee);
  final entryDuration = enter.duration + HeroCoffeeRestGraph.fadeDuration;
  AnimationGraphRunner runner() => AnimationGraphRunner(
    graph: HeroCoffeeRestGraph.definition(resources: resources),
    resources: resources,
    selectionPolicy: RestPolicy(Random(1)),
  );

  test('entry reuses original walking and sword-supported phone frames', () {
    final phone = resources.clip(HeroClips.phoneEnter);
    expect(
      enter.frames.map((frame) => frame.frameId),
      phone.frames.take(3).map((frame) => frame.frameId),
    );
    final phoneRig = resources.rig(
      resources.frame(const FrameId('hero.phoneFrames.frame.3')).rigId,
    );
    final coffeeRig = resources.rig(
      resources.frame(coffee.frames.first.frameId).rigId,
    );
    expect(coffeeRig.anchorX, phoneRig.anchorX);
    expect(coffeeRig.anchorY, phoneRig.anchorY);
    expect(coffeeRig.worldUnitsPerPixel, phoneRig.worldUnitsPerPixel);
  });

  test(
    'each cycle rests, raises the mug, sips and lowers it before repeating',
    () {
      final graph = runner()..advance(entryDuration);
      const indices = [0, 1, 2, 3, 2, 4, 5];
      const durations = [3.0, .18, .16, .55, .12, .18, .65];
      expect(coffee.loopDuration, closeTo(4.84, 1e-9));
      for (var cycle = 0; cycle < 3; cycle++) {
        for (var i = 0; i < indices.length; i++) {
          final frame = FrameId('hero.coffeeFrames.frame.${indices[i]}');
          expect(graph.snapshot.frameId, frame);
          graph.advance(durations[i] - .001);
          expect(graph.snapshot.frameId, frame);
          graph.advance(.001);
        }
      }
      expect(
        graph.snapshot.frameId,
        const FrameId('hero.coffeeFrames.frame.0'),
      );
    },
  );

  test(
    'return finishes an active sip, then fades the lowered mug to standing',
    () {
      for (final (elapsed, delay, source) in [
        (.2, 0.0, 0),
        (3.05, 1.14, 5),
        (3.5, .69, 5),
        (4.2, 0.0, 5),
      ]) {
        final graph = runner()..advance(entryDuration + elapsed);
        graph.signal(GraphSignalId.activityReturned);
        if (delay > 0) {
          graph.advance(delay - .001);
          expect(graph.snapshot.nodeId, HeroCoffeeRestGraph.drink);
          graph.advance(.001);
        } else {
          graph.advance(0);
        }
        expect(graph.snapshot.nodeId, HeroCoffeeRestGraph.fadeOut);
        expect(
          graph.snapshot.fadeFromFrameId,
          FrameId('hero.coffeeFrames.frame.$source'),
        );
        expect(graph.snapshot.frameId, const FrameId('hero.idle.frame.0'));
        expect(graph.snapshot.fadeProgress, closeTo(0, 1e-9));
        graph.advance(.175);
        expect(graph.snapshot.fadeProgress, closeTo(.5, 1e-9));
        graph.advance(.475);
        expect(graph.isCompleted, isTrue);
      }
    },
  );

  test(
    'early return skips coffee or finishes the entry fade before leaving',
    () {
      final early = runner()..advance(.1);
      early.signal(GraphSignalId.activityReturned);
      early.advance(enter.duration - .1);
      expect(early.snapshot.nodeId, HeroCoffeeRestGraph.fadeOut);
      expect(
        early.snapshot.fadeFromFrameId,
        const FrameId('hero.phoneFrames.frame.1'),
      );
      early.advance(.65);
      expect(early.isCompleted, isTrue);

      for (final partitioned in [false, true]) {
        final graph = runner();
        if (partitioned) {
          for (var i = 0; i < 66; i++) {
            graph.advance(.01);
          }
        } else {
          graph.advance(.66);
        }
        expect(graph.snapshot.nodeId, HeroCoffeeRestGraph.fadeIn);
        expect(
          graph.snapshot.fadeFromFrameId,
          const FrameId('hero.phoneFrames.frame.1'),
        );
        expect(graph.snapshot.fadeProgress, closeTo(.5, 1e-9));
        graph.signal(GraphSignalId.activityReturned);
        graph.advance(.174);
        expect(graph.snapshot.nodeId, HeroCoffeeRestGraph.fadeIn);
        graph.advance(.001);
        expect(graph.snapshot.nodeId, HeroCoffeeRestGraph.fadeOut);
        expect(
          graph.snapshot.fadeFromFrameId,
          const FrameId('hero.coffeeFrames.frame.0'),
        );
        expect(graph.advance(1).remaining, closeTo(.35, 1e-9));
        expect(graph.isCompleted, isTrue);
      }
    },
  );

  test(
    'coffee is selected once and blocks travel through its complete exit',
    () {
      final rest = RestCoordinator(ConstantRandom(.95), resources);
      final hero = HeroAnimationCoordinator(resources, rest: rest);
      rest.setIdleSeconds(1000);
      hero.advance(1);
      hero.advance(.01);
      expect(hero.snapshot.nodeId, HeroCoffeeRestGraph.enter);
      hero.advance(entryDuration + 1);
      expect(hero.snapshot.nodeId, HeroCoffeeRestGraph.drink);
      expect(hero.advance(100), 0);
      final elapsed = rest.graphRunner!.snapshot.clipElapsed;
      hero.advance(coffee.loopDuration - elapsed % coffee.loopDuration + .1);
      rest.setIdleSeconds(0);
      hero.advance(0);
      expect(hero.snapshot.nodeId, HeroCoffeeRestGraph.fadeOut);
      expect(hero.advance(.649), 0);
      expect(hero.blocksAdventure, isTrue);
      expect(hero.advance(.101), closeTo(.1, 1e-9));
      expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.0'));
      expect(hero.restReturnRevision, 1);
    },
  );
}
