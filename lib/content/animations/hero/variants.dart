import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/graph/node.dart';
import '../../../core/animation/graph/selection_policy.dart';
import '../../../core/animation/graph/transition.dart';
import '../../../core/animation/ids.dart';
import 'clips.dart';

/// Metadata and graph fragments belong to content, independently of clip IDs.
final class HeroRestVariant {
  HeroRestVariant({
    required this.id,
    required this.nodeId,
    required this.clipId,
    required this.entryPose,
    required this.exitPose,
    this.weight = 1,
    this.cooldown,
    this.interruption = InterruptionPolicy.immediate,
    this.cleanupClip,
    this.cleanupNode,
    List<GraphCondition> conditions = const [],
  }) : conditions = List.unmodifiable(conditions);

  final VariantId id;
  final NodeId nodeId;
  final ClipId clipId;
  final AnimationPoseContract entryPose, exitPose;
  final double weight;
  final VariantCooldown? cooldown;
  final InterruptionPolicy interruption;
  final ClipId? cleanupClip;
  final NodeId? cleanupNode;
  final List<GraphCondition> conditions;

  GraphChoice get choice => GraphChoice(
    id: id,
    target: nodeId,
    weight: weight,
    conditions: conditions,
    cooldown: cooldown,
    completionNode: cleanupNode,
  );

  void validate(AnimationResources resources) {
    final clip = resources.clip(clipId);
    for (final condition in conditions) {
      if (!HeroRestVariants.allowedFacts.contains(condition.fact)) {
        throw ArgumentError(
          'Unsupported hero variant condition: ${condition.fact}',
        );
      }
      condition.validate();
    }
    bool equal(AnimationPoseContract? a, AnimationPoseContract b) =>
        a?.pose == b.pose && a?.family == b.family;
    if (!equal(clip.entryPose, entryPose) ||
        !equal(clip.exitPose, exitPose) ||
        (cleanupClip == null) != (cleanupNode == null)) {
      throw ArgumentError('Variant pose/cleanup metadata mismatch: $id');
    }
    if (cleanupClip != null) {
      final cleanup = resources.clip(cleanupClip!);
      if (cleanup.loopRange != null ||
          cleanup.exitPose?.pose != PoseId.seatedNeutral) {
        throw ArgumentError('Cleanup must finish in seatedNeutral: $id');
      }
    }
  }

  List<AnimationGraphNode> activityNodes(NodeId exit) => [
    LoopClip(
      id: nodeId,
      clipId: clipId,
      interruption: interruption,
      transitions: [
        AnimationTransition(const ActivityReturned(), cleanupNode ?? exit),
      ],
    ),
    if (cleanupClip != null)
      PlayClip(
        id: cleanupNode!,
        clipId: cleanupClip!,
        transitions: [AnimationTransition(const Completed(), exit)],
      ),
  ];

  AnimationGraphNode standNode(NodeId done) => PlayClip(
    id: nodeId,
    clipId: clipId,
    transitions: [AnimationTransition(const Completed(), done)],
  );
}

abstract final class HeroRestVariants {
  static const allowedFacts = [GraphFactId('rest.idleLevel')];
  static const idleLevel = GraphFactId('rest.idleLevel');
  static const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  static const seatedFamily = AnimationPoseContract.family(PoseFamilyId.seated);
  static const standing = AnimationPoseContract.family(
    PoseFamilyId.standingRight,
  );

  static final activities = List<HeroRestVariant>.unmodifiable([
    HeroRestVariant(
      id: const VariantId('hero.sharpen.seated'),
      nodeId: const NodeId('rest.sharpen'),
      clipId: const ClipId('hero.sharpen'),
      entryPose: seated,
      exitPose: seatedFamily,
    ),
  ]);
  static final standUps = List<HeroRestVariant>.unmodifiable([
    HeroRestVariant(
      id: const VariantId('hero.standUp.reluctant'),
      nodeId: const NodeId('rest.stand'),
      clipId: const ClipId('hero.standUp'),
      entryPose: seatedFamily,
      exitPose: standing,
    ),
  ]);

  // Opt-in descriptions use authored frames at a different cadence; they are
  // not new artwork. Cleanup visibly returns the sharpening tool to neutral.
  static final demoActivities = List<HeroRestVariant>.unmodifiable([
    ...activities,
    HeroRestVariant(
      id: const VariantId('hero.sharpen.slow'),
      nodeId: const NodeId('rest.sharpenSlow'),
      clipId: HeroClips.sharpenSlow,
      entryPose: seated,
      exitPose: seatedFamily,
      cleanupClip: HeroClips.sharpenCleanup,
      cleanupNode: const NodeId('rest.sharpenCleanup'),
      weight: 2,
      conditions: const [GraphCondition(idleLevel, minimum: 2)],
      cooldown: const VariantCooldown(
        CooldownKey('rest.slowSharpen'),
        12,
        start: CooldownStart.completed,
      ),
      interruption: InterruptionPolicy.afterCycle,
    ),
  ]);
  static final demoStandUps = List<HeroRestVariant>.unmodifiable([
    ...standUps,
    HeroRestVariant(
      id: const VariantId('hero.standUp.careful'),
      nodeId: const NodeId('rest.standCareful'),
      clipId: HeroClips.standCareful,
      entryPose: seatedFamily,
      exitPose: standing,
      cooldown: const VariantCooldown(CooldownKey('rest.carefulStand'), 8),
    ),
  ]);
}
