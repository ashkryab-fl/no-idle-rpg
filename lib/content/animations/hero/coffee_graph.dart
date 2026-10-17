import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/graph/graph_validator.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';
import 'clips.dart';
import 'poses.dart';

abstract final class HeroCoffeeRestGraph {
  static const enter = NodeId('rest.coffee.enter');
  static const fadeIn = NodeId('rest.coffee.fadeIn');
  static const drink = NodeId('rest.coffee.drink');
  static const fadeOut = NodeId('rest.coffee.fadeOut');
  static const exitHold = NodeId('rest.coffee.exitHold');
  static const done = NodeId('rest.coffee.done');
  static const fadeDuration = .35;
  static const exitHoldDuration = .3;

  static AnimationGraphDefinition definition({AnimationResources? resources}) {
    final content = resources ?? HeroClips.resources();
    final graph = AnimationGraphDefinition(
      id: const GraphId('hero.coffeeRest'),
      entryNode: enter,
      nodes: [
        PlayClip(
          id: enter,
          clipId: HeroClips.coffeeEnter,
          transitions: [
            AnimationTransition(const ActivityReturned(), fadeOut),
            AnimationTransition(const Completed(), fadeIn),
          ],
        ),
        FadePose(
          id: fadeIn,
          poseId: HeroPoses.coffeeNeutral,
          duration: fadeDuration,
          transitions: [AnimationTransition(const Completed(), drink)],
        ),
        LoopClip(
          id: drink,
          clipId: HeroClips.coffee,
          interruption: InterruptionPolicy.afterCycle,
          // Finish an active sip; the two lowered-mug poses can exit at once.
          interruptibleFrames: [0, 6],
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
          duration: exitHoldDuration,
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
