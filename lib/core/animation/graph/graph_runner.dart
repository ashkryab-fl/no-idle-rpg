import 'dart:math';
import '../animation_player.dart';
import '../animation_resources.dart';
import '../ids.dart';
import 'graph_definition.dart';
import 'graph_validator.dart';
import 'node.dart';
import 'selection_policy.dart';
import 'transition.dart';

enum GraphPlaybackStatus { running, completed, cancelled }

enum GraphTransitionReason {
  completed,
  activityReturned,
  elapsed,
  signal,
  selected,
  fallback,
}

sealed class GraphPlaybackEvent {
  const GraphPlaybackEvent(this.timeWithinStep);
  final double timeWithinStep;
}

final class GraphMarkerEvent extends GraphPlaybackEvent {
  const GraphMarkerEvent(this.nodeId, this.marker, super.timeWithinStep);
  final NodeId nodeId;
  final AnimationMarkerEvent marker;
}

final class GraphTransitionEvent extends GraphPlaybackEvent {
  const GraphTransitionEvent(
    this.from,
    this.to,
    this.reason,
    super.timeWithinStep,
  );
  final NodeId from, to;
  final GraphTransitionReason reason;
}

final class GraphCompletionEvent extends GraphPlaybackEvent {
  const GraphCompletionEvent(this.result, super.timeWithinStep);
  final GraphResultId result;
}

final class GraphPlaybackSnapshot {
  const GraphPlaybackSnapshot({
    required this.graphId,
    required this.nodeId,
    required this.status,
    required this.nodeElapsed,
    required this.frameId,
    required this.clipId,
    required this.poseId,
    required this.frameIndex,
    required this.clipElapsed,
    required this.loopCount,
    required this.lastTransition,
  });
  final GraphId graphId;
  final NodeId nodeId;
  final GraphPlaybackStatus status;
  final FrameId? frameId;
  final ClipId? clipId;
  final PoseId? poseId;
  final int? frameIndex;
  final int loopCount;
  final double nodeElapsed, clipElapsed;
  final GraphTransitionEvent? lastTransition;
}

final class GraphAdvanceResult {
  GraphAdvanceResult({
    required this.consumed,
    required this.remaining,
    required List<GraphPlaybackEvent> events,
  }) : events = List.unmodifiable(events);
  final double consumed, remaining;
  final List<GraphPlaybackEvent> events;
}

/// Pure Dart playback, with one local player and no game priority decisions.
/// Selection happens only on Select entry. Signals are coalesced until consumed.
final class AnimationGraphRunner {
  AnimationGraphRunner({
    required this.graph,
    required this.resources,
    required this.selectionPolicy,
    this.transitionBudget = 1024,
    Map<GraphFactId, double> facts = const {},
    double startTime = 0,
  }) {
    AnimationGraphValidator(resources).validate(graph);
    if (transitionBudget < 1) throw ArgumentError('Invalid transition budget');
    setFacts(facts);
    reset(startTime: startTime);
  }
  final AnimationGraphDefinition graph;
  final AnimationResources resources;
  final GraphSelectionPolicy selectionPolicy;
  final int transitionBudget;
  late AnimationGraphNode _node;
  AnimationPlayer? _player;
  int _pass = 1;
  double _nodeElapsed = 0, _clock = 0;
  final Set<GraphSignalId> _signals = {};
  final Map<NodeId, List<GraphChoice>> _completingChoices = {};
  Map<GraphFactId, double> _facts = const {};
  GraphPlaybackStatus _status = GraphPlaybackStatus.running;
  GraphTransitionEvent? _lastTransition;
  GraphPlaybackSnapshot? _lastVisual;
  bool _finishReported = false;

  double get clock => _clock;
  AnimationGraphNode get currentNode => _node;

  /// Lets an external policy schedule wakeups without duplicating clip clocks.
  double get timeToNextBoundary => !isRunning
      ? double.infinity
      : _node is Select || _node is Finish || _matchingTransition() != null
      ? 0
      : _untilNextBoundary();

  bool get isCompleted => _status == GraphPlaybackStatus.completed;
  bool get isRunning => _status == GraphPlaybackStatus.running;

  GraphPlaybackSnapshot get snapshot {
    final player = _player?.snapshot;
    final pose = _node is HoldPose ? (_node as HoldPose).poseId : null;
    final finishedPlay = _node is PlayClip && _nodeCompleted;
    final lastIndex = finishedPlay
        ? (_player!.clip.loopRange?.end ?? _player!.clip.frames.length) - 1
        : player?.frameIndex;
    final frame = pose != null
        ? resources.pose(pose).frameId
        : player == null
        ? _lastVisual?.frameId
        : _player!.clip.frames[lastIndex!].frameId;
    return GraphPlaybackSnapshot(
      graphId: graph.id,
      nodeId: _node.id,
      status: _status,
      nodeElapsed: _nodeElapsed,
      frameId: frame,
      clipId: player?.clipId,
      poseId: pose,
      frameIndex: lastIndex,
      clipElapsed: player?.elapsed ?? 0,
      loopCount: player?.loopCount ?? 0,
      lastTransition: _lastTransition,
    );
  }

  void setFacts(Map<GraphFactId, double> facts) {
    for (final entry in facts.entries) {
      validateAnimationId(entry.key.value);
      if (!entry.value.isFinite) throw ArgumentError('Invalid graph fact');
    }
    _facts = Map.unmodifiable(facts);
  }

  void signal(GraphSignalId signal) {
    validateAnimationId(signal.value);
    if (isRunning) _signals.add(signal);
  }

  void reset({double startTime = 0}) {
    if (!startTime.isFinite || startTime < 0) {
      throw ArgumentError.value(startTime, 'startTime');
    }
    _signals.clear();
    _completingChoices.clear();
    _clock = startTime;
    _status = GraphPlaybackStatus.running;
    _finishReported = false;
    _lastTransition = null;
    _lastVisual = null;
    _enter(graph.entryNode);
  }

  void cancel() {
    _signals.clear();
    _completingChoices.clear();
    _status = GraphPlaybackStatus.cancelled;
  }

  GraphAdvanceResult advance(double dt) {
    if (!dt.isFinite || dt < 0 || !(_clock + dt).isFinite) {
      throw ArgumentError.value(dt, 'dt');
    }
    var remaining = dt;
    var offset = 0.0;
    var transitions = 0;
    final events = <GraphPlaybackEvent>[];
    void move(NodeId target, GraphTransitionReason reason) {
      if (++transitions > transitionBudget) {
        throw StateError('Graph transition budget exceeded: ${graph.id}');
      }
      _completeChoices(_node.id);
      _lastVisual = snapshot;
      final event = GraphTransitionEvent(_node.id, target, reason, offset);
      events.add(event);
      _lastTransition = event;
      _enter(target);
    }

    while (isRunning) {
      if (_node is Finish) {
        _completeChoices(_node.id);
        _signals.clear();
        _status = GraphPlaybackStatus.completed;
        break;
      }
      final edge = _matchingTransition();
      if (edge != null) {
        final signal = _signalFor(edge.trigger);
        if (signal != null) _signals.remove(signal);
        move(edge.target, _reason(edge.trigger));
        continue;
      }
      if (_node case Select(:final choices, :final fallback)) {
        final choice = selectionPolicy.choose(choices, _facts, _clock);
        if (choice == null) {
          move(fallback, GraphTransitionReason.fallback);
        } else {
          if (!choices.contains(choice) ||
              !choice.conditions.every((c) => c.matches(_facts))) {
            throw StateError('Selection policy returned an ineligible variant');
          }
          selectionPolicy.started(choice, _clock);
          (_completingChoices[choice.completionNode] ??= []).add(choice);
          move(choice.target, GraphTransitionReason.selected);
        }
        continue;
      }
      if (remaining == 0) break;
      final step = min(remaining, _untilNextBoundary());
      if (step <= 0) {
        throw StateError(
          'Graph made no time progress: ${graph.id}/${_node.id}',
        );
      }
      _advancePlayer(step, offset, events);
      _nodeElapsed += step;
      _clock += step;
      offset += step;
      remaining = max(0, dt - offset);
    }
    if (isCompleted && !_finishReported) {
      _finishReported = true;
      events.add(GraphCompletionEvent((_node as Finish).result, offset));
    }
    return GraphAdvanceResult(
      consumed: offset,
      remaining: remaining,
      events: events,
    );
  }

  void _enter(NodeId id) {
    _node = graph.node(id);
    _nodeElapsed = 0;
    _pass = 1;
    final clip = switch (_node) {
      PlayClip(:final clipId) ||
      LoopClip(:final clipId) => resources.clip(clipId),
      _ => null,
    };
    _player = clip == null ? null : AnimationPlayer(clip);
  }

  double get _duration => switch (_node) {
    PlayClip(:final repetitions) =>
      _player!.clip.loopRange == null
          ? _player!.clip.duration * repetitions
          : _player!.clip.firstPassDuration +
                _player!.clip.loopDuration * (repetitions - 1),
    HoldPose(:final duration) => duration ?? double.infinity,
    _ => double.infinity,
  };
  double get _epsilon =>
      _player?.clip.tolerance ??
      min(
        1e-10,
        (_node is HoldPose ? (_node as HoldPose).duration ?? 1 : 1) * 1e-8,
      );
  bool get _nodeCompleted =>
      _duration.isFinite && _nodeElapsed >= _duration - _epsilon;
  InterruptionPolicy get _interruption => switch (_node) {
    PlayClip(:final interruption) ||
    LoopClip(:final interruption) ||
    HoldPose(:final interruption) => interruption,
    _ => InterruptionPolicy.immediate,
  };

  double _cycleDelta() {
    if (_nodeElapsed == 0 || _nodeCompleted) return 0;
    final clip = _player!.clip;
    final first = clip.firstPassDuration;
    if (_nodeElapsed < first - _epsilon) return first - _nodeElapsed;
    final cycle = clip.loopRange == null ? clip.duration : clip.loopDuration;
    final remainder = (_nodeElapsed - first) % cycle;
    if (remainder < _epsilon || cycle - remainder < _epsilon) return 0;
    return cycle - remainder;
  }

  bool get _canInterrupt => switch (_interruption) {
    InterruptionPolicy.immediate => true,
    InterruptionPolicy.afterClip => _nodeCompleted,
    InterruptionPolicy.afterCycle => _cycleDelta() == 0,
  };

  AnimationTransition? _matchingTransition() {
    for (final edge in _node.transitions) {
      if (!edge.conditions.every((c) => c.matches(_facts))) continue;
      final ready = switch (edge.trigger) {
        Completed() => _nodeCompleted,
        Elapsed(:final seconds) => _nodeElapsed >= seconds - _epsilon,
        ActivityReturned() || Signal() =>
          _signals.contains(_signalFor(edge.trigger)) && _canInterrupt,
      };
      if (ready) return edge;
    }
    return null;
  }

  double _untilNextBoundary() {
    var delta = _nodeCompleted ? double.infinity : _duration - _nodeElapsed;
    for (final edge in _node.transitions) {
      if (!edge.conditions.every((c) => c.matches(_facts))) continue;
      if (edge.trigger case Elapsed(:final seconds)) {
        if (seconds > _nodeElapsed + _epsilon) {
          delta = min(delta, seconds - _nodeElapsed);
        }
      } else if (_signals.contains(_signalFor(edge.trigger))) {
        final interruptDelta = switch (_interruption) {
          InterruptionPolicy.immediate => 0.0,
          InterruptionPolicy.afterClip => _duration - _nodeElapsed,
          InterruptionPolicy.afterCycle => _cycleDelta(),
        };
        delta = min(delta, interruptDelta);
      }
    }
    return delta;
  }

  void _advancePlayer(
    double dt,
    double offset,
    List<GraphPlaybackEvent> events,
  ) {
    final player = _player;
    if (player == null || _nodeCompleted) return;
    var left = min(dt, _duration - _nodeElapsed);
    var within = 0.0;
    while (left > 0) {
      final result = player.advance(left);
      for (final event in result.events) {
        // The local player loops forever; finite PlayClip ends at a cycle
        // boundary. Keep its end marker, but suppress the next cycle's start.
        if (_node case PlayClip(:final repetitions)) {
          if (player.clip.loopRange != null && event.loopCount >= repetitions) {
            continue;
          }
        }
        events.add(
          GraphMarkerEvent(
            _node.id,
            event,
            offset + within + event.timeWithinStep,
          ),
        );
      }
      within += result.consumed;
      left = result.remaining;
      if (player.completed &&
          _node is PlayClip &&
          _pass < (_node as PlayClip).repetitions) {
        _pass++;
        player.reset();
      } else {
        break;
      }
    }
  }

  void _completeChoices(NodeId id) {
    for (final choice in _completingChoices.remove(id) ?? <GraphChoice>[]) {
      selectionPolicy.completed(choice, _clock);
    }
  }

  GraphSignalId? _signalFor(TransitionTrigger trigger) => switch (trigger) {
    ActivityReturned() => GraphSignalId.activityReturned,
    Signal(:final id) => id,
    _ => null,
  };
  GraphTransitionReason _reason(TransitionTrigger trigger) => switch (trigger) {
    Completed() => GraphTransitionReason.completed,
    ActivityReturned() => GraphTransitionReason.activityReturned,
    Elapsed() => GraphTransitionReason.elapsed,
    Signal() => GraphTransitionReason.signal,
  };
}
