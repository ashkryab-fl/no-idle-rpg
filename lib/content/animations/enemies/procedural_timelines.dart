import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/ids.dart';
import '../../../core/balance/game_balance.dart';

/// These timelines drive the existing Canvas enemy body, not missing sprites.
/// The body reference is resolved by the procedural renderer, outside PNG rigs.
abstract final class ProceduralEnemyTimelines {
  static const body = FrameId('canvas.enemy.body');
  static final attack = AnimationClipDefinition(
    id: const ClipId('canvas.enemy.attack'),
    frames: const [ClipFrameDefinition(body, GameBalance.attackDuration)],
    markers: const [
      AnimationMarker(
        id: 'damage',
        time: GameBalance.damageTiming,
        kind: AnimationMarkerKind.damage,
      ),
    ],
  );
  static final death = AnimationClipDefinition(
    id: const ClipId('canvas.enemy.death'),
    frames: const [ClipFrameDefinition(body, GameBalance.deathDuration)],
  );
}
