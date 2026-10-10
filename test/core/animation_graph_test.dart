import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/animation_resources.dart';
import 'package:idle_companion/core/animation/graph/graph_definition.dart';
import 'package:idle_companion/core/animation/graph/graph_runner.dart';
import 'package:idle_companion/core/animation/graph/graph_validator.dart';
import 'package:idle_companion/core/animation/graph/node.dart';
import 'package:idle_companion/core/animation/graph/selection_policy.dart';
import 'package:idle_companion/core/animation/graph/transition.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/domain/activity/rest_policy.dart';

const play = NodeId('play');
const wait = NodeId('wait');
const done = NodeId('done');
const choose = NodeId('choose');
const retry = GraphSignalId('retry');

AnimationGraphDefinition graph(
  List<AnimationGraphNode> nodes, {
  NodeId entry = play,
}) => AnimationGraphDefinition(
  id: const GraphId('test'),
  entryNode: entry,
  nodes: nodes,
);

AnimationGraphRunner runner(
  AnimationGraphDefinition definition, {
  AnimationResources? resources,
  GraphSelectionPolicy? policy,
  Map<GraphFactId, double> facts = const {},
  int budget = 1024,
}) => AnimationGraphRunner(
  graph: definition,
  resources: resources ?? defaultAnimationResources(),
  selectionPolicy: policy ?? RestPolicy(Random(7)),
  facts: facts,
  transitionBudget: budget,
);

AnimationResources markerResources() {
  final base = defaultAnimationResources();
  final loop = base.clip(const ClipId('hero.sharpen'));
  final attack = base.clip(const ClipId('hero.attack'));
  return AnimationResources(
    rigs: base.rigs.values,
    frames: base.frames.values,
    poses: base.poses.values,
    clips: [
      ...base.clips.values.where((c) => c.id != loop.id && c.id != attack.id),
      AnimationClipDefinition(
        id: loop.id,
        frames: loop.frames,
        loopRange: loop.loopRange,
        entryPose: loop.entryPose,
        exitPose: loop.exitPose,
        markers: const [
          AnimationMarker(id: 'intro', time: .1),
          AnimationMarker(id: 'loopStart', time: .225),
          AnimationMarker(id: 'loop', time: .6),
          AnimationMarker(id: 'end', time: 1.125),
        ],
      ),
      AnimationClipDefinition(
        id: attack.id,
        frames: attack.frames,
        markers: const [
          AnimationMarker(
            id: 'damage',
            time: .35,
            kind: AnimationMarkerKind.damage,
          ),
        ],
      ),
    ],
  );
}

final class CountingPolicy implements GraphSelectionPolicy {
  CountingPolicy(int seed) : delegate = RestPolicy(Random(seed));
  final RestPolicy delegate;
  int calls = 0;
  final List<(VariantId, double)> starts = [], completions = [];
  @override
  GraphChoice? choose(
    List<GraphChoice> choices,
    Map<GraphFactId, double> facts,
    double clock,
  ) {
    calls++;
    return delegate.choose(choices, facts, clock);
  }

  @override
  void started(GraphChoice choice, double clock) {
    starts.add((choice.id, clock));
    delegate.started(choice, clock);
  }

  @override
  void completed(GraphChoice choice, double clock) {
    completions.add((choice.id, clock));
    delegate.completed(choice, clock);
  }
}

void main() {
  test('rest entry, shared holds, six stand-up frames and typed finish', () {
    final resources = defaultAnimationResources();
    final playback = runner(HeroRestGraphs.seatedRest(), resources: resources);
    playback.advance(1.2);
    expect(playback.snapshot.nodeId, HeroRestGraphs.sitHold);
    final seatedFrame = resources.pose(PoseId.seatedNeutral).frameId;
    expect(playback.snapshot.frameId, seatedFrame);
    expect(playback.snapshot.clipId, isNull);
    playback.advance(.5);
    expect(playback.snapshot.nodeId, HeroRestGraphs.sharpen);
    expect(playback.snapshot.frameIndex, 0);
    playback.advance(8);
    expect(
      playback.snapshot.frameIndex,
      inInclusiveRange(
        1,
        resources.clip(const ClipId('hero.sharpen')).frames.length - 1,
      ),
    );
    playback.signal(GraphSignalId.activityReturned);
    playback.advance(0);
    expect(playback.snapshot.nodeId, HeroRestGraphs.exitHold);
    expect(playback.snapshot.frameId, seatedFrame);
    expect(playback.snapshot.nodeElapsed, 0);
    playback.advance(.3);
    for (var i = 0; i < 6; i++) {
      expect(playback.snapshot.nodeId, HeroRestGraphs.stand);
      expect(playback.snapshot.frameIndex, i);
      playback.signal(GraphSignalId.activityReturned);
      final step = playback.advance(.25);
      if (i == 5) {
        expect(
          step.events.whereType<GraphCompletionEvent>().single.result,
          GraphResultId.readyToTravel,
        );
      }
    }
    expect(playback.isCompleted, true);
    expect(playback.advance(5).remaining, 5);
    expect(playback.advance(0).events, isEmpty);
  });

  test(
    'pending return survives entry/hold, exits once, reset clears signals',
    () {
      final playback = runner(HeroRestGraphs.seatedRest());
      playback.advance(.4);
      playback.signal(GraphSignalId.activityReturned);
      playback.signal(GraphSignalId.activityReturned);
      playback.advance(1);
      expect(playback.snapshot.nodeId, HeroRestGraphs.sitHold);
      final result = playback.advance(3);
      expect(result.consumed, closeTo(2.1, 1e-9));
      expect(result.remaining, closeTo(.9, 1e-9));
      expect(
        result.events.whereType<GraphTransitionEvent>().where(
          (e) => e.to == HeroRestGraphs.sharpen,
        ),
        isEmpty,
      );
      expect(result.events.whereType<GraphCompletionEvent>(), hasLength(1));
      playback.reset();
      playback.advance(1.7);
      expect(playback.snapshot.nodeId, HeroRestGraphs.sharpen);
      playback.signal(GraphSignalId.activityReturned);
      playback.cancel();
      expect(playback.snapshot.status, GraphPlaybackStatus.cancelled);
      expect(playback.advance(20).remaining, 20);
      playback.reset();
      playback.advance(1.7);
      expect(playback.snapshot.nodeId, HeroRestGraphs.sharpen);
    },
  );

  for (final policy in InterruptionPolicy.values) {
    test('$policy respects the current finite clip/cycle and carries dt', () {
      final resources = defaultAnimationResources();
      final clip = resources.clip(const ClipId('hero.sharpen'));
      final playback = runner(
        graph([
          PlayClip(
            id: play,
            clipId: const ClipId('hero.sharpen'),
            repetitions: 3,
            interruption: policy,
            transitions: [AnimationTransition(const ActivityReturned(), wait)],
          ),
          HoldPose(id: wait, poseId: PoseId.seatedNeutral),
        ]),
        resources: resources,
      );
      playback.advance(.5);
      playback.signal(GraphSignalId.activityReturned);
      final available = clip.firstPassDuration + 2 * clip.loopDuration;
      playback.advance(available);
      final delay = switch (policy) {
        InterruptionPolicy.immediate => 0.0,
        InterruptionPolicy.afterCycle => clip.firstPassDuration - .5,
        InterruptionPolicy.afterClip => available - .5,
      };
      expect(playback.snapshot.nodeId, wait);
      expect(playback.snapshot.nodeElapsed, closeTo(available - delay, 1e-9));
    });
  }

  test(
    'large and partitioned dt agree on nodes, cursor and marker sequence',
    () {
      final definition = graph([
        PlayClip(
          id: play,
          clipId: const ClipId('hero.attack'),
          repetitions: 2,
          transitions: [AnimationTransition(const Completed(), wait)],
        ),
        HoldPose(
          id: wait,
          poseId: PoseId.seatedNeutral,
          duration: .3,
          transitions: [
            AnimationTransition(const Completed(), const NodeId('loop')),
          ],
        ),
        LoopClip(
          id: const NodeId('loop'),
          clipId: const ClipId('hero.sharpen'),
        ),
      ]);
      final resources = markerResources();
      final reference = runner(definition, resources: resources);
      final expected = reference
          .advance(12)
          .events
          .whereType<GraphMarkerEvent>()
          .toList();
      for (final fps in [30, 60]) {
        for (final speed in [1, 5, 20]) {
          final playback = runner(definition, resources: resources);
          final events = <(GraphMarkerEvent, double)>[];
          final dt = speed / fps;
          final steps = 12 * fps ~/ speed;
          for (var i = 0; i < steps; i++) {
            for (final event
                in playback.advance(dt).events.whereType<GraphMarkerEvent>()) {
              events.add((event, i * dt + event.timeWithinStep));
            }
          }
          expect(playback.snapshot.nodeId, reference.snapshot.nodeId);
          expect(playback.snapshot.frameId, reference.snapshot.frameId);
          expect(
            playback.snapshot.clipElapsed,
            closeTo(reference.snapshot.clipElapsed, 1e-9),
          );
          expect(playback.snapshot.loopCount, reference.snapshot.loopCount);
          expect(
            events.map((e) => (e.$1.nodeId, e.$1.marker.marker.id)),
            expected.map((e) => (e.nodeId, e.marker.marker.id)),
          );
          for (var i = 0; i < events.length; i++) {
            expect(
              events[i].$2,
              closeTo(expected[i].timeWithinStep, 1e-9),
              reason: '$fps FPS x$speed event $i',
            );
          }
        }
      }
    },
  );

  test('cooldown completion is explicit and separate from shared clip ID', () {
    final policy = CountingPolicy(1);
    final a = GraphChoice(
      id: const VariantId('a'),
      target: play,
      completionNode: const NodeId('cleanup'),
      cooldown: const VariantCooldown(
        CooldownKey('a'),
        3,
        start: CooldownStart.completed,
      ),
    );
    final b = GraphChoice(
      id: const VariantId('b'),
      target: play,
      cooldown: const VariantCooldown(CooldownKey('b'), 3),
    );
    final playback = runner(
      graph([
        Select(id: choose, fallback: wait, choices: [a]),
        PlayClip(
          id: play,
          clipId: const ClipId('hero.sitDown'),
          transitions: [
            AnimationTransition(const Completed(), const NodeId('cleanup')),
          ],
        ),
        HoldPose(
          id: const NodeId('cleanup'),
          poseId: PoseId.seatedNeutral,
          duration: .2,
          transitions: [AnimationTransition(const Completed(), choose)],
        ),
        HoldPose(
          id: wait,
          poseId: PoseId.seatedNeutral,
          transitions: [AnimationTransition(const Signal(retry), choose)],
        ),
      ], entry: choose),
      policy: policy,
    );
    playback.advance(1.3);
    expect(policy.completions, isEmpty);
    playback.advance(.1);
    expect(policy.completions.single.$1, a.id);
    expect(policy.completions.single.$2, closeTo(1.4, 1e-9));
    expect(playback.snapshot.nodeId, wait);
    expect(policy.delegate.choose([a], {}, 4.39), isNull);
    expect(policy.delegate.choose([a], {}, 4.4), a);
    expect(policy.delegate.choose([b], {}, 1.4), b);
    policy.delegate.started(b, 1.4);
    expect(policy.delegate.choose([b], {}, 2), isNull);
    expect(policy.delegate.choose([a], {}, 4.4), a);
  });

  test(
    'seeded weighted decisions reproduce and choose only eligible variants',
    () {
      final choices = [
        GraphChoice(id: const VariantId('a'), target: play),
        GraphChoice(id: const VariantId('b'), target: play, weight: 3),
        GraphChoice(
          id: const VariantId('blocked'),
          target: play,
          weight: 100,
          conditions: [
            const GraphCondition(RestPolicy.idleLevelFact, minimum: 3),
          ],
        ),
      ];
      final a = RestPolicy(Random(123)), b = RestPolicy(Random(123));
      final selected = <VariantId>{};
      for (var i = 0; i < 100; i++) {
        final choice = a.choose(choices, {RestPolicy.idleLevelFact: 1}, 0)!;
        expect(
          choice.id,
          b.choose(choices, {RestPolicy.idleLevelFact: 1}, 0)!.id,
        );
        selected.add(choice.id);
      }
      expect(selected, {const VariantId('a'), const VariantId('b')});
    },
  );

  test('validator rejects structural, trigger, resource and pose errors', () {
    final validator = AnimationGraphValidator(defaultAnimationResources());
    final invalid = [
      graph([HoldPose(id: wait, poseId: PoseId.seatedNeutral)]),
      graph([PlayClip(id: play, clipId: const ClipId('unknown'))]),
      graph([HoldPose(id: play, poseId: const PoseId('unknown'))]),
      graph([
        PlayClip(
          id: play,
          clipId: const ClipId('hero.sitDown'),
          transitions: [AnimationTransition(const Completed(), done)],
        ),
      ]),
      graph([
        HoldPose(id: play, poseId: PoseId.seatedNeutral),
        Finish(id: done, result: GraphResultId.readyToTravel),
      ]),
      graph([LoopClip(id: play, clipId: const ClipId('hero.sitDown'))]),
      graph([
        LoopClip(
          id: play,
          clipId: const ClipId('hero.sharpen'),
          transitions: [AnimationTransition(const Completed(), play)],
        ),
      ]),
      graph([
        HoldPose(
          id: play,
          poseId: PoseId.seatedNeutral,
          transitions: [AnimationTransition(const Elapsed(0), play)],
        ),
      ]),
      graph([
        HoldPose(
          id: play,
          poseId: PoseId.seatedNeutral,
          transitions: [AnimationTransition(const Signal(retry), done)],
        ),
        Finish(
          id: done,
          result: GraphResultId.readyToTravel,
          entryPose: const AnimationPoseContract.family(
            PoseFamilyId.walkingRight,
          ),
        ),
      ]),
      graph([
        Select(id: play, choices: [], fallback: wait),
        PlayClip(id: wait, clipId: const ClipId('hero.sitDown')),
      ]),
    ];
    for (final definition in invalid) {
      expect(() => validator.validate(definition), throwsArgumentError);
    }
    expect(
      () => graph([
        HoldPose(id: play, poseId: PoseId.seatedNeutral),
        HoldPose(id: play, poseId: PoseId.seatedNeutral),
      ]),
      throwsArgumentError,
    );
  });

  test(
    'zero-time cycles fail; timed cycles use explicit entry and a budget',
    () {
      final validator = AnimationGraphValidator(defaultAnimationResources());
      expect(
        () => validator.validate(
          graph([
            Select(
              id: choose,
              choices: [
                GraphChoice(id: const VariantId('cycle'), target: choose),
              ],
              fallback: wait,
            ),
            HoldPose(id: wait, poseId: PoseId.seatedNeutral),
          ], entry: choose),
        ),
        throwsArgumentError,
      );
      final timed = graph([
        // Entry has an incoming edge, and is deliberately not the first node.
        Select(
          id: choose,
          fallback: wait,
          choices: [GraphChoice(id: const VariantId('repeat'), target: play)],
        ),
        HoldPose(id: wait, poseId: PoseId.seatedNeutral),
        PlayClip(
          id: play,
          clipId: const ClipId('hero.sitDown'),
          transitions: [AnimationTransition(const Completed(), choose)],
        ),
      ]);
      final playback = runner(timed, budget: 8);
      playback.advance(2.5);
      expect(playback.snapshot.nodeId, play);
      expect(playback.snapshot.clipElapsed, closeTo(.1, 1e-9));
      expect(() => playback.advance(100), throwsStateError);
    },
  );
}
