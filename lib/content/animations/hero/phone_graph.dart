import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/graph/graph_validator.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';
import 'clips.dart';
import 'poses.dart';

abstract final class HeroPhoneRestGraph {
  static const enter = NodeId('rest.phone.enter');
  static const scroll = NodeId('rest.phone.scroll');
  static const wake = NodeId('rest.phone.wake');
  static const done = NodeId('rest.phone.done');

  static AnimationGraphDefinition definition({AnimationResources? resources}) {
    final content = resources ?? HeroClips.resources();
    final graph = AnimationGraphDefinition(
      id: const GraphId('hero.phoneRest'),
      entryNode: enter,
      nodes: [
        PlayClip(
          id: enter,
          clipId: HeroClips.phoneEnter,
          // A return during entry stays pending until the phone is drawn.
          transitions: [AnimationTransition(const Completed(), scroll)],
        ),
        LoopClip(
          id: scroll,
          clipId: HeroClips.phoneScroll,
          transitions: [AnimationTransition(const ActivityReturned(), wake)],
        ),
        PlayClip(
          id: wake,
          clipId: HeroClips.phoneWake,
          transitions: [AnimationTransition(const Completed(), done)],
        ),
        Finish(
          id: done,
          result: GraphResultId.readyToTravel,
          entryPose: const AnimationPoseContract.pose(HeroPoses.walkFirst),
        ),
      ],
    );
    AnimationGraphValidator(content).validate(graph);
    return graph;
  }
}
