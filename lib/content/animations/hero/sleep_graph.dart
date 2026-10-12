import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/graph/graph_validator.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';
import 'clips.dart';
import 'poses.dart';

abstract final class HeroSleepRestGraph {
  static const standing = NodeId('rest.sleep.standing');
  static const fadeIn = NodeId('rest.sleep.fadeIn');
  static const sleep = NodeId('rest.sleep.loop');
  static const fadeOut = NodeId('rest.sleep.fadeOut');
  static const exitHold = NodeId('rest.sleep.exitHold');
  static const done = NodeId('rest.sleep.done');
  static const standingDuration = .3;
  static const fadeDuration = .5;

  static AnimationGraphDefinition definition({AnimationResources? resources}) {
    final content = resources ?? HeroClips.resources();
    final graph = AnimationGraphDefinition(
      id: const GraphId('hero.sleepRest'),
      entryNode: standing,
      nodes: [
        PlayClip(
          id: standing,
          clipId: HeroClips.sleepStanding,
          transitions: [
            AnimationTransition(const ActivityReturned(), exitHold),
            AnimationTransition(const Completed(), fadeIn),
          ],
        ),
        FadePose(
          id: fadeIn,
          poseId: HeroPoses.sleepFacing,
          duration: fadeDuration,
          transitions: [AnimationTransition(const Completed(), sleep)],
        ),
        LoopClip(
          id: sleep,
          clipId: HeroClips.sleep,
          // Waking from either settled side starts the fade immediately.
          // During a roll, finish only the roll, not the four-second hold.
          interruption: InterruptionPolicy.afterCycle,
          interruptibleFrames: [0, 3],
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
          duration: .3,
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
