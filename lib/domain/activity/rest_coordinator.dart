import 'dart:math';
import '../../content/animations/hero/rest_graphs.dart';
import '../../core/animation/graph/graph_runner.dart';
import '../../core/animation/graph/graph_definition.dart';
import '../../core/animation/graph/graph_validator.dart';
import '../../core/animation/graph/node.dart';
import '../../core/animation/graph/transition.dart';
import '../../core/animation/ids.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/balance/game_balance.dart';
import 'idle_level.dart';
import 'rest_policy.dart';

/// Rest policy scheduler. The graph runner owns frames, time and signals.
class RestCoordinator {
  RestCoordinator(
    Random random,
    this.resources, {
    this.thresholds = GameBalance.idleThresholds,
    AnimationGraphDefinition? graph,
  }) : policy = RestPolicy(random, thresholds: thresholds),
       graph = graph ?? HeroRestGraphs.rest(resources: resources) {
    AnimationGraphValidator(resources).validate(this.graph);
  }
  final AnimationResources resources;
  final List<double> thresholds;
  final RestPolicy policy;
  final AnimationGraphDefinition graph;
  Map<GraphFactId, double> get _facts => {
    RestPolicy.idleLevelFact: _level.index.toDouble(),
  };
  AnimationGraphRunner? _runner;
  IdleLevel _level = IdleLevel.active;
  double _clock = 0;
  bool _readyToTravel = true;
  List<GraphPlaybackEvent> events = const [];
  AnimationGraphRunner? get graphRunner => _runner;
  IdleLevel get level => _level;
  IdleLevel levelFor(double seconds) => policy.levelFor(seconds);
  bool get blocksAdventure =>
      level != IdleLevel.active ||
      _runner?.isRunning == true ||
      !_readyToTravel;

  void setIdleSeconds(double seconds) {
    final previous = _level;
    _level = levelFor(seconds);
    _runner?.setFacts({RestPolicy.idleLevelFact: _level.index.toDouble()});
    if (_level == IdleLevel.active) {
      _runner?.signal(GraphSignalId.activityReturned);
    } else if (_level != previous) {
      _runner?.signal(HeroRestGraphs.selectionChanged);
    }
  }

  double advance(double dt, {bool canRest = true, double? startTime}) {
    if (!dt.isFinite || dt < 0 || !(_clock + dt).isFinite) {
      throw ArgumentError.value(dt, 'dt');
    }
    if (startTime != null &&
        (!startTime.isFinite || startTime < 0 || !(startTime + dt).isFinite)) {
      throw ArgumentError.value(startTime, 'startTime');
    }
    events = const [];
    final localStart = startTime ?? _clock;
    _clock = localStart + dt;
    // Track policy time while the semantic coordinator finishes an encounter.
    if (!canRest) return dt;
    if (_runner == null || !_runner!.isRunning) {
      if (_level == IdleLevel.active) return dt;
      _readyToTravel = false;
      _runner = AnimationGraphRunner(
        graph: graph,
        resources: resources,
        selectionPolicy: policy,
        facts: {RestPolicy.idleLevelFact: _level.index.toDouble()},
        startTime: localStart,
      );
    }
    if (_level == IdleLevel.active) {
      _runner!.signal(GraphSignalId.activityReturned);
    }
    final runner = _runner!;
    var remaining = dt;
    var offset = 0.0;
    final collected = <GraphPlaybackEvent>[];
    var budget = runner.transitionBudget;
    while (runner.isRunning) {
      if (--budget < 0) {
        throw StateError('Rest scheduling budget exceeded');
      }
      double wakeup = double.infinity;
      final node = runner.currentNode;
      if (node is HoldPose && node.duration == null) {
        for (final edge in node.transitions) {
          if (edge.trigger is! Signal ||
              (edge.trigger as Signal).id != HeroRestGraphs.selectionChanged ||
              !edge.conditions.every((c) => c.matches(_facts))) {
            continue;
          }
          final target = graph.node(edge.target);
          if (target is! Select) continue;
          final next = policy.nextEligibilityChange(
            target.choices,
            _facts,
            runner.clock,
          );
          if (next == null) continue;
          if (next <= runner.clock) {
            runner.signal(HeroRestGraphs.selectionChanged);
          } else {
            wakeup = min(wakeup, next - runner.clock);
          }
        }
      }
      final step = min(remaining, min(runner.timeToNextBoundary, wakeup));
      final result = runner.advance(step);
      for (final event in result.events) {
        final time = offset + event.timeWithinStep;
        collected.add(switch (event) {
          GraphTransitionEvent() => GraphTransitionEvent(
            event.from,
            event.to,
            event.reason,
            time,
          ),
          GraphMarkerEvent() => GraphMarkerEvent(
            event.nodeId,
            event.marker,
            time,
          ),
          GraphCompletionEvent() => GraphCompletionEvent(event.result, time),
        });
      }
      offset += result.consumed;
      remaining = max(0, dt - offset);
      if (remaining == 0 || !runner.isRunning) break;
      if (result.consumed == 0 && result.events.isEmpty) {
        throw StateError('Rest scheduling made no progress');
      }
    }
    events = List.unmodifiable(collected);
    for (final completion in events.whereType<GraphCompletionEvent>()) {
      if (completion.result != GraphResultId.readyToTravel) {
        throw StateError('Unexpected rest completion: ${completion.result}');
      }
      _readyToTravel = true;
    }
    return remaining;
  }

  void reset() {
    _runner?.cancel();
    _runner = null;
    _level = IdleLevel.active;
    _clock = 0;
    _readyToTravel = true;
    events = const [];
    policy.reset();
  }

  /// Death/reset discard playback and pending return signals, while retaining
  /// the sampled idle level and policy cooldown history.
  void cancelPlayback() {
    _runner?.cancel();
    _runner = null;
    _readyToTravel = true;
    events = const [];
  }
}
