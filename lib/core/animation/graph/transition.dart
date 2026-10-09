import '../ids.dart';

/// Only signals use interruption policy. Timed/completed edges are explicit.
enum InterruptionPolicy { immediate, afterCycle, afterClip }

sealed class TransitionTrigger {
  const TransitionTrigger();
}

final class Completed extends TransitionTrigger {
  const Completed();
}

final class ActivityReturned extends TransitionTrigger {
  const ActivityReturned();
}

final class Elapsed extends TransitionTrigger {
  const Elapsed(this.seconds);
  final double seconds;
}

final class Signal extends TransitionTrigger {
  const Signal(this.id);
  final GraphSignalId id;
}

/// Generic facts supplied by a game policy; the runner knows no idle levels.
final class GraphCondition {
  const GraphCondition(this.fact, {this.minimum = 0, this.maximum});
  final GraphFactId fact;
  final double minimum;
  final double? maximum;
  bool matches(Map<GraphFactId, double> facts) {
    final value = facts[fact];
    return value != null &&
        value >= minimum &&
        (maximum == null || value <= maximum!);
  }

  void validate() {
    validateAnimationId(fact.value);
    if (!minimum.isFinite ||
        (maximum != null && (!maximum!.isFinite || maximum! < minimum))) {
      throw ArgumentError('Invalid graph condition: $fact');
    }
  }
}

final class AnimationTransition {
  AnimationTransition(
    this.trigger,
    this.target, {
    List<GraphCondition> conditions = const [],
  }) : conditions = List.unmodifiable(conditions);
  final TransitionTrigger trigger;
  final NodeId target;
  final List<GraphCondition> conditions;
}
