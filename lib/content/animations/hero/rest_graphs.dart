import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/graph/graph_definition.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/selection_policy.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';

abstract final class HeroRestGraphs {
  static const sit = NodeId('rest.sit');
  static const sitHold = NodeId('rest.sitHold');
  static const activitySelect = NodeId('rest.activitySelect');
  static const activityWait = NodeId('rest.activityWait');
  static const sharpen = NodeId('rest.sharpen');
  static const exitHold = NodeId('rest.exitHold');
  static const standSelect = NodeId('rest.standSelect');
  static const standWait = NodeId('rest.standWait');
  static const stand = NodeId('rest.stand');
  static const done = NodeId('rest.done');
  static const selectionChanged = GraphSignalId('rest.selectionChanged');

  /// Temporary presentation aliases for callers that still render clip IDs.
  /// The runner itself uses the shared pose frame, never these aliases.
  static final holdClips = Map<NodeId, ClipId>.unmodifiable({
    sitHold: ClipId('hero.sitDown'),
    activityWait: ClipId('hero.seated'),
    exitHold: ClipId('hero.seated'),
    standWait: const ClipId('hero.seated'),
  });

  static AnimationGraphDefinition seatedRest() => AnimationGraphDefinition(
    id: const GraphId('hero.seatedRest'),
    entryNode: sit,
    nodes: [
      PlayClip(
        id: sit,
        clipId: const ClipId('hero.sitDown'),
        transitions: [
          // Return stays pending across entry and its original final hold.
          AnimationTransition(const Completed(), sitHold),
        ],
      ),
      HoldPose(
        id: sitHold,
        poseId: PoseId.seatedNeutral,
        duration: .5,
        interruption: InterruptionPolicy.afterClip,
        transitions: [
          AnimationTransition(const ActivityReturned(), exitHold),
          AnimationTransition(const Completed(), activitySelect),
        ],
      ),
      Select(
        id: activitySelect,
        fallback: activityWait,
        choices: [
          GraphChoice(
            id: const VariantId('hero.sharpen.seated'),
            target: sharpen,
          ),
        ],
        transitions: [AnimationTransition(const ActivityReturned(), exitHold)],
      ),
      HoldPose(
        id: activityWait,
        poseId: PoseId.seatedNeutral,
        transitions: [
          AnimationTransition(const ActivityReturned(), exitHold),
          AnimationTransition(const Signal(selectionChanged), activitySelect),
        ],
      ),
      LoopClip(
        id: sharpen,
        clipId: const ClipId('hero.sharpen'),
        transitions: [AnimationTransition(const ActivityReturned(), exitHold)],
      ),
      HoldPose(
        id: exitHold,
        poseId: PoseId.seatedNeutral,
        duration: .3,
        transitions: [AnimationTransition(const Completed(), standSelect)],
      ),
      Select(
        id: standSelect,
        fallback: standWait,
        choices: [
          GraphChoice(
            id: const VariantId('hero.standUp.reluctant'),
            target: stand,
          ),
        ],
      ),
      HoldPose(
        id: standWait,
        poseId: PoseId.seatedNeutral,
        transitions: [
          AnimationTransition(const Signal(selectionChanged), standSelect),
        ],
      ),
      PlayClip(
        id: stand,
        clipId: const ClipId('hero.standUp'),
        transitions: [AnimationTransition(const Completed(), done)],
      ),
      Finish(
        id: done,
        result: GraphResultId.readyToTravel,
        entryPose: const AnimationPoseContract.family(
          PoseFamilyId.standingRight,
        ),
      ),
    ],
  );
}
