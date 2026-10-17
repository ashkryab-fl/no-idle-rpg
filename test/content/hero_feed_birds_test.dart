import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/feed_birds_graph.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/domain/activity/rest_policy.dart';
import 'package:idle_companion/game/animation/hero_animation_coordinator.dart';
import '../helpers/simulation_fixture.dart';

void main() {
  final resources = HeroClips.resources();
  final clip = resources.clip(HeroClips.feedBirds);
  const entryDuration =
      HeroFeedBirdsRestGraph.standingDuration +
      HeroFeedBirdsRestGraph.fadeDuration;
  AnimationGraphRunner runner() => AnimationGraphRunner(
    graph: HeroFeedBirdsRestGraph.definition(resources: resources),
    resources: resources,
    selectionPolicy: RestPolicy(Random(1)),
  );

  test('birds peck between handfuls and each toss returns to resting pose', () {
    final graph = runner()..advance(entryDuration);
    const indices = [0, 1, 0, 1, 0, 1, 0, 1, 2, 3, 4, 5, 6, 7];
    const durations = [
      .4,
      .4,
      .4,
      .4,
      .4,
      .4,
      .4,
      .4,
      .18,
      .24,
      .18,
      .14,
      .18,
      .18,
    ];
    expect(clip.loopDuration, closeTo(4.3, 1e-9));
    for (var cycle = 0; cycle < 2; cycle++) {
      for (var i = 0; i < indices.length; i++) {
        final expected = FrameId('hero.feedBirdsFrames.frame.${indices[i]}');
        expect(graph.snapshot.frameId, expected);
        graph.advance(durations[i] - .001);
        expect(graph.snapshot.frameId, expected);
        graph.advance(.001);
      }
    }
    expect(
      graph.snapshot.frameId,
      const FrameId('hero.feedBirdsFrames.frame.0'),
    );
  });

  test('pecking exits immediately but an active handful finishes first', () {
    for (final elapsed in [.2, 1.7, 3.25, 3.9, 4.2]) {
      final graph = runner()..advance(entryDuration + elapsed);
      graph.signal(GraphSignalId.activityReturned);
      final delay = elapsed < 3.2 ? 0.0 : 4.3 - elapsed;
      if (delay > 0) {
        graph.advance(delay - .001);
        expect(graph.snapshot.nodeId, HeroFeedBirdsRestGraph.feed);
        graph.advance(.001);
      } else {
        graph.advance(0);
      }
      expect(graph.snapshot.nodeId, HeroFeedBirdsRestGraph.fadeOut);
      expect(graph.snapshot.fadeFromFrameId, isNotNull);
      expect(graph.snapshot.frameId, const FrameId('hero.idle.frame.0'));
      expect(graph.snapshot.fadeProgress, closeTo(0, 1e-9));
      graph.advance(.25);
      expect(graph.snapshot.fadeProgress, closeTo(.5, 1e-9));
      graph.advance(.55);
      expect(graph.isCompleted, isTrue);
    }
  });

  test('early return skips bench or finishes its entry fade before exit', () {
    final beforeFade = runner()..advance(.1);
    beforeFade.signal(GraphSignalId.activityReturned);
    beforeFade.advance(.2);
    expect(beforeFade.snapshot.nodeId, HeroFeedBirdsRestGraph.exitHold);
    beforeFade.advance(.3);
    expect(beforeFade.isCompleted, isTrue);

    for (final partitioned in [false, true]) {
      final graph = runner();
      if (partitioned) {
        for (var i = 0; i < 55; i++) {
          graph.advance(.01);
        }
      } else {
        graph.advance(.55);
      }
      expect(
        graph.snapshot.fadeFromFrameId,
        const FrameId('hero.idle.frame.0'),
      );
      expect(graph.snapshot.fadeProgress, closeTo(.5, 1e-9));
      graph.signal(GraphSignalId.activityReturned);
      graph.advance(.249);
      expect(graph.snapshot.nodeId, HeroFeedBirdsRestGraph.fadeIn);
      graph.advance(.001);
      expect(graph.snapshot.nodeId, HeroFeedBirdsRestGraph.fadeOut);
      expect(
        graph.snapshot.fadeFromFrameId,
        const FrameId('hero.feedBirdsFrames.frame.0'),
      );
      final result = graph.advance(1);
      expect(graph.isCompleted, isTrue);
      expect(result.remaining, closeTo(.2, 1e-9));
    }
  });

  test(
    'random rest selection blocks travel until bench and standing fade out',
    () {
      final rest = RestCoordinator(ConstantRandom(.70), resources);
      final hero = HeroAnimationCoordinator(resources, rest: rest);
      rest.setIdleSeconds(1000);
      hero.advance(1);
      hero.advance(.01);
      expect(hero.snapshot.nodeId, HeroFeedBirdsRestGraph.standing);
      hero.advance(entryDuration + 1);
      expect(hero.snapshot.nodeId, HeroFeedBirdsRestGraph.feed);
      expect(hero.advance(100), 0);
      // Return during one of the calm pecking poses.
      final elapsed = rest.graphRunner!.snapshot.clipElapsed;
      hero.advance(clip.loopDuration - elapsed % clip.loopDuration + .1);
      rest.setIdleSeconds(0);
      hero.advance(0);
      expect(hero.snapshot.nodeId, HeroFeedBirdsRestGraph.fadeOut);
      expect(hero.advance(.799), 0);
      expect(hero.blocksAdventure, isTrue);
      expect(hero.advance(.101), closeTo(.1, 1e-9));
      expect(hero.snapshot.frameId, const FrameId('hero.walk.frame.0'));
      expect(hero.restReturnRevision, 1);
    },
  );
}
