import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/graph/graph_validator.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';
import 'clips.dart';
import 'poses.dart';

abstract final class HeroFeedBirdsRestGraph {
  static const standing = NodeId('rest.feedBirds.standing');
  static const fadeIn = NodeId('rest.feedBirds.fadeIn');
  static const feed = NodeId('rest.feedBirds.loop');
  static const fadeOut = NodeId('rest.feedBirds.fadeOut');
  static const exitHold = NodeId('rest.feedBirds.exitHold');
  static const done = NodeId('rest.feedBirds.done');
  static const standingDuration = .3;
  static const fadeDuration = .5;

  static AnimationGraphDefinition definition({AnimationResources? resources}) {
    final content = resources ?? HeroClips.resources();
    final graph = AnimationGraphDefinition(
      id: const GraphId('hero.feedBirdsRest'),
      entryNode: standing,
      nodes: [
        PlayClip(
          id: standing,
          clipId: HeroClips.feedBirdsStanding,
          transitions: [
            AnimationTransition(const ActivityReturned(), exitHold),
            AnimationTransition(const Completed(), fadeIn),
          ],
        ),
        FadePose(
          id: fadeIn,
          poseId: HeroPoses.feedBirds,
          duration: fadeDuration,
          transitions: [AnimationTransition(const Completed(), feed)],
        ),
        LoopClip(
          id: feed,
          clipId: HeroClips.feedBirds,
          interruption: InterruptionPolicy.afterCycle,
          // Pecking can stop immediately; finish an active handful first.
          interruptibleFrames: [0, 1, 2, 3, 4, 5, 6, 7],
          transitions: [AnimationTransition(const ActivityReturned(), fadeOut)],
        ),
        FadePose(
          id: fadeOut,
          poseId: HeroPoses.standing,
          duration: fadeDuration,
          transitions: [AnimationTransition(const Completed(), exitHold)],
        ),
        HoldPose(
          id: exitHold,
          poseId: HeroPoses.standing,
          duration: standingDuration,
          interruption: InterruptionPolicy.afterClip,
          transitions: [AnimationTransition(const Completed(), done)],
        ),
        Finish(
          id: done,
          result: GraphResultId.readyToTravel,
          entryPose: const AnimationPoseContract.pose(HeroPoses.standing),
        ),
      ],
    );
    AnimationGraphValidator(content).validate(graph);
    return graph;
  }
}
