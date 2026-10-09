import 'animation_clip.dart';
import 'animation_resources.dart';
import 'ids.dart';

/// Explicit enemy content; sprite IDs resolve strictly and Canvas timelines
/// are declared directly. Missing sprite content never selects Canvas content.
sealed class EnemyAnimationContent {
  const EnemyAnimationContent();
  AnimationClipDefinition attack(AnimationResources resources);
  AnimationClipDefinition death(AnimationResources resources);
}

final class SpriteEnemyAnimationContent extends EnemyAnimationContent {
  const SpriteEnemyAnimationContent({
    required this.idleId,
    required this.attackId,
    required this.deathId,
  });
  final ClipId idleId, attackId, deathId;
  @override
  AnimationClipDefinition attack(AnimationResources resources) =>
      resources.clip(attackId);
  @override
  AnimationClipDefinition death(AnimationResources resources) =>
      resources.clip(deathId);
}

final class ProceduralEnemyAnimationContent extends EnemyAnimationContent {
  const ProceduralEnemyAnimationContent({
    required this.attackClip,
    required this.deathClip,
  });
  final AnimationClipDefinition attackClip, deathClip;
  @override
  AnimationClipDefinition attack(AnimationResources resources) => attackClip;
  @override
  AnimationClipDefinition death(AnimationResources resources) => deathClip;
}
