import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/graph/graph_definition.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/animation/graph/node.dart';
import 'package:idle_companion/core/animation/graph/transition.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/animation/sprite_sheet_adapter.dart';
import 'package:idle_companion/domain/activity/rest_policy.dart';

void main() {
  const clipId = ClipId('test.loop');
  const loop = NodeId('test.loop');
  const done = NodeId('test.done');
  final resources = spriteSheetResources(
    id: clipId,
    asset: 'test.png',
    frames: 4,
    stepTime: 1,
    loop: true,
    loopStartFrame: 1,
  );

  AnimationGraphRunner runner({
    List<int> frames = const [],
    InterruptionPolicy interruption = InterruptionPolicy.afterCycle,
  }) => AnimationGraphRunner(
    graph: AnimationGraphDefinition(
      id: const GraphId('test.graph'),
      entryNode: loop,
      nodes: [
        LoopClip(
          id: loop,
          clipId: clipId,
          interruption: interruption,
          interruptibleFrames: frames,
          transitions: [AnimationTransition(const ActivityReturned(), done)],
        ),
        Finish(id: done, result: GraphResultId.readyToTravel),
      ],
    ),
    resources: resources,
    selectionPolicy: RestPolicy(Random(1)),
  );

  test('unannotated loops keep waiting until the cycle boundary', () {
    for (final elapsed in [.4, 4.4]) {
      final graph = runner();
      graph.advance(elapsed);
      graph.signal(GraphSignalId.activityReturned);
      final remaining = elapsed < 4 ? 4 - elapsed : 7 - elapsed;
      expect(graph.timeToNextBoundary, closeTo(remaining, 1e-10));
      graph.advance(remaining - .001);
      expect(graph.isRunning, isTrue);
      graph.advance(.001);
      expect(graph.isCompleted, isTrue);
    }
  });

  test('signals reach the next safe frame in the intro and later loops', () {
    for (final elapsed in [.4, 4.4, 7.4]) {
      final graph = runner(frames: [2]);
      graph.advance(elapsed);
      graph.signal(GraphSignalId.activityReturned);
      final remaining = elapsed < 4 ? 2 - elapsed : .6;
      expect(graph.timeToNextBoundary, closeTo(remaining, 1e-10));
      graph.advance(remaining - .001);
      expect(graph.isRunning, isTrue);
      final result = graph.advance(.101);
      expect(graph.isCompleted, isTrue);
      expect(result.remaining, closeTo(.1, 1e-10));
      expect(
        result.events.whereType<GraphTransitionEvent>().single.timeWithinStep,
        closeTo(.001, 1e-10),
      );
    }
  });

  test(
    'signals interrupt anywhere within a safe frame without consuming time',
    () {
      for (final elapsed in [2.0, 2.5, 2.999, 5.5, 8.5]) {
        final graph = runner(frames: [2]);
        graph.advance(elapsed);
        graph.signal(GraphSignalId.activityReturned);
        expect(graph.timeToNextBoundary, 0);
        final result = graph.advance(0);
        expect(graph.isCompleted, isTrue);
        expect(result.consumed, 0);
      }
    },
  );

  test('invalid safe frames and conflicting policies are rejected', () {
    for (final frames in [
      [-1],
      [4],
    ]) {
      expect(() => runner(frames: frames), throwsArgumentError);
    }
    expect(
      () => runner(frames: [2], interruption: InterruptionPolicy.immediate),
      throwsArgumentError,
    );
  });
}
