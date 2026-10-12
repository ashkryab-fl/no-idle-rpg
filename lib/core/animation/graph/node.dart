import '../animation_clip.dart';
import '../ids.dart';
import 'selection_policy.dart';
import 'transition.dart';

sealed class AnimationGraphNode {
  AnimationGraphNode(this.id, List<AnimationTransition> transitions)
    : transitions = List.unmodifiable(transitions);
  final NodeId id;
  final List<AnimationTransition> transitions;
}

final class PlayClip extends AnimationGraphNode {
  PlayClip({
    required NodeId id,
    required this.clipId,
    this.repetitions = 1,
    this.interruption = InterruptionPolicy.afterClip,
    List<AnimationTransition> transitions = const [],
  }) : super(id, transitions);
  final ClipId clipId;
  final int repetitions;
  final InterruptionPolicy interruption;
}

final class LoopClip extends AnimationGraphNode {
  LoopClip({
    required NodeId id,
    required this.clipId,
    this.interruption = InterruptionPolicy.immediate,
    List<int> interruptibleFrames = const [],
    List<AnimationTransition> transitions = const [],
  }) : interruptibleFrames = List.unmodifiable(interruptibleFrames),
       super(id, transitions);
  final ClipId clipId;
  final InterruptionPolicy interruption;

  /// With afterCycle, these frames also allow an immediate signal transition.
  final List<int> interruptibleFrames;
}

final class HoldPose extends AnimationGraphNode {
  HoldPose({
    required NodeId id,
    required this.poseId,
    this.duration,
    this.interruption = InterruptionPolicy.immediate,
    List<AnimationTransition> transitions = const [],
  }) : super(id, transitions);
  final PoseId poseId;

  /// Null waits for a signal, without a synthetic animation clock.
  final double? duration;
  final InterruptionPolicy interruption;
}

/// Crossfades the previous resolved frame (or an explicit pose) to a new pose.
/// Both images stay still; the node owns the blend clock and blocks early exit.
final class FadePose extends AnimationGraphNode {
  FadePose({
    required NodeId id,
    required this.poseId,
    required this.duration,
    this.fromPoseId,
    List<AnimationTransition> transitions = const [],
  }) : super(id, transitions);
  final PoseId poseId;
  final PoseId? fromPoseId;
  final double duration;
}

final class Select extends AnimationGraphNode {
  Select({
    required NodeId id,
    required List<GraphChoice> choices,
    required this.fallback,
    List<AnimationTransition> transitions = const [],
  }) : choices = List.unmodifiable(choices),
       super(id, transitions);
  final List<GraphChoice> choices;

  /// An indefinite HoldPose. Retry must be an explicit edge from that hold;
  /// blocked selection never re-enters it on every update.
  final NodeId fallback;
}

final class Finish extends AnimationGraphNode {
  Finish({required NodeId id, required this.result, this.entryPose})
    : super(id, const []);
  final GraphResultId result;
  final AnimationPoseContract? entryPose;
}
