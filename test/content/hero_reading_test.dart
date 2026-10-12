import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/poses.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/animation/graph/node.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/domain/activity/rest_coordinator.dart';
import 'package:idle_companion/domain/activity/rest_policy.dart';

final class _Rolls implements Random {
  _Rolls(this.values);
  final List<double> values;
  int calls = 0;
  @override
  double nextDouble() => values[calls++ % values.length];
  @override
  bool nextBool() => throw UnimplementedError();
  @override
  int nextInt(int max) => throw UnimplementedError();
}

void main() {
  final resources = HeroClips.resources();
  final graph = HeroRestGraphs.seatedRest(resources: resources);

  test('every reading cycle holds four seconds before turning one page', () {
    final clip = resources.clip(HeroClips.read);
    expect(clip.loopDuration, closeTo(4.48, 1e-10));
    expect(clip.frames.first.frameId, HeroPoses.seatedFrame);
    for (var cycle = 0; cycle < 20; cycle++) {
      final start = clip.loopStartTime + cycle * clip.loopDuration;
      expect(clip.frameIndex(start), 3);
      expect(clip.frameIndex(start + 3.999), 3);
      expect(clip.frameIndex(start + 4), 4);
      expect(clip.frameIndex(start + 4.12), 5);
      expect(clip.frameIndex(start + 4.24), 6);
      expect(clip.frameIndex(start + 4.36), 7);
    }
  });

  test('equal weights split random selection at one half', () {
    final select = graph.node(HeroRestGraphs.activitySelect) as Select;
    expect(select.choices.map((choice) => choice.weight), [1, 1]);
    final policy = RestPolicy(_Rolls([0, .499999, .5, .999999]));
    expect(
      List.generate(4, (_) => policy.choose(select.choices, {}, 0)!.target),
      [
        HeroRestGraphs.sharpen,
        HeroRestGraphs.sharpen,
        HeroRestGraphs.read,
        HeroRestGraphs.read,
      ],
    );
  });

  test('activity is selected once after each sit, never during its loop', () {
    final rolls = _Rolls([.25, .75]);
    final runner = AnimationGraphRunner(
      graph: graph,
      resources: resources,
      selectionPolicy: RestPolicy(rolls),
    );
    runner.advance(1.699);
    expect(rolls.calls, 0);
    runner.advance(.001);
    expect(runner.snapshot.nodeId, HeroRestGraphs.sharpen);
    runner.advance(60);
    expect(rolls.calls, 1);
    runner.reset();
    runner.advance(1.7);
    expect(runner.snapshot.nodeId, HeroRestGraphs.read);
    runner.advance(60);
    expect(rolls.calls, 2);
    expect(runner.snapshot.nodeId, HeroRestGraphs.read);
  });

  test(
    'return during a page turn finishes it, then closes book and stands',
    () {
      final rest = RestCoordinator(_Rolls([.75]), resources, graph: graph);
      rest.setIdleSeconds(1000);
      rest.advance(1.7);
      final reading = resources.clip(HeroClips.read);
      rest.advance(reading.loopStartTime + 4.18);
      expect(rest.graphRunner!.snapshot.frameIndex, 5);
      rest.setIdleSeconds(0);
      rest.advance(.299);
      expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.read);
      expect(rest.blocksAdventure, isTrue);
      rest.advance(.001);
      expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.readCleanup);
      expect(rest.blocksAdventure, isTrue);
      final cleanup = resources.clip(HeroClips.readCleanup);
      expect(cleanup.frames.last.frameId, HeroPoses.seatedFrame);
      rest.advance(cleanup.duration);
      expect(rest.graphRunner!.snapshot.poseId, PoseId.seatedNeutral);
      expect(rest.blocksAdventure, isTrue);
      rest.advance(.3);
      expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.stand);
      expect(rest.blocksAdventure, isTrue);
      rest.advance(1.5);
      expect(rest.graphRunner!.isCompleted, isTrue);
      expect(rest.blocksAdventure, isFalse);
    },
  );

  test('return interrupts every part of the reading hold immediately', () {
    final reading = resources.clip(HeroClips.read);
    for (final cycle in [0, 1, 3]) {
      for (final offset in [0.0, .01, 1.99, 3.999]) {
        final rest = RestCoordinator(_Rolls([.75]), resources, graph: graph);
        rest.setIdleSeconds(1000);
        rest.advance(1.7);
        rest.advance(
          reading.loopStartTime + cycle * reading.loopDuration + offset,
        );
        expect(rest.graphRunner!.snapshot.frameIndex, 3);
        rest.setIdleSeconds(0);
        rest.advance(0);
        expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.readCleanup);
        expect(rest.graphRunner!.snapshot.nodeElapsed, 0);
        expect(rest.blocksAdventure, isTrue);
        rest.advance(resources.clip(HeroClips.readCleanup).duration + .3 + 1.5);
        expect(rest.graphRunner!.isCompleted, isTrue);
        expect(rest.blocksAdventure, isFalse);
      }
    }
  });

  test('return during opening starts cleanup as soon as the book is open', () {
    final rest = RestCoordinator(_Rolls([.75]), resources, graph: graph);
    rest.setIdleSeconds(1000);
    rest.advance(1.7);
    rest.advance(.2);
    rest.setIdleSeconds(0);
    rest.advance(.279);
    expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.read);
    rest.advance(.001);
    expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.readCleanup);
    expect(rest.graphRunner!.snapshot.nodeElapsed, closeTo(0, 1e-10));
  });

  test('return finishes only the remaining page turn in later cycles', () {
    final reading = resources.clip(HeroClips.read);
    for (final cycle in [0, 1, 3]) {
      for (final offset in [4.0, 4.12, 4.18, 4.24, 4.36, 4.479]) {
        final rest = RestCoordinator(_Rolls([.75]), resources, graph: graph);
        rest.setIdleSeconds(1000);
        rest.advance(1.7);
        rest.advance(
          reading.loopStartTime + cycle * reading.loopDuration + offset,
        );
        rest.setIdleSeconds(0);
        final remaining = reading.loopDuration - offset;
        rest.advance(remaining - .0001);
        expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.read);
        rest.advance(.0001);
        expect(rest.graphRunner!.snapshot.nodeId, HeroRestGraphs.readCleanup);
        expect(rest.graphRunner!.snapshot.nodeElapsed, closeTo(0, 1e-10));
      }
    }
  });

  test(
    'large and partitioned return updates complete the same exit sequence',
    () {
      RestCoordinator readingRest() {
        final rest = RestCoordinator(_Rolls([.75]), resources, graph: graph);
        rest.setIdleSeconds(1000);
        rest.advance(1.7);
        rest.advance(resources.clip(HeroClips.read).loopStartTime + 2);
        rest.setIdleSeconds(0);
        return rest;
      }

      final whole = readingRest();
      final partitioned = readingRest();
      const duration = .74 + .3 + 1.5;
      expect(whole.advance(duration + 1), closeTo(1, 1e-10));
      for (var i = 0; i < 254; i++) {
        partitioned.advance(.01);
      }
      expect(partitioned.advance(1), closeTo(1, 1e-10));
      expect(
        whole.graphRunner!.snapshot.nodeId,
        partitioned.graphRunner!.snapshot.nodeId,
      );
      expect(whole.blocksAdventure, isFalse);
      expect(partitioned.blocksAdventure, isFalse);
    },
  );

  test('early return completes sitting without opening the book', () {
    final rolls = _Rolls([.75]);
    final runner = AnimationGraphRunner(
      graph: graph,
      resources: resources,
      selectionPolicy: RestPolicy(rolls),
    );
    runner.advance(.1);
    runner.signal(GraphSignalId.activityReturned);
    runner.advance(1.6);
    expect(runner.snapshot.nodeId, HeroRestGraphs.exitHold);
    expect(rolls.calls, 0);
    runner.advance(1.8);
    expect(runner.isCompleted, isTrue);
  });
}
