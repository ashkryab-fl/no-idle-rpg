import '../../../core/animation/animation_clip.dart';
import '../../../core/animation/animation_resources.dart';
import '../../../core/animation/enemy_animation_content.dart';
import '../../../core/animation/ids.dart';
import '../../../core/animation/sprite_frame.dart';
import '../../../core/animation/sprite_sheet_adapter.dart';
import '../../../core/balance/game_balance.dart';

abstract final class GoblinClips {
  static const idleId = ClipId('enemy.gobliLow.idle');
  static const attackId = ClipId('enemy.gobliLow.attack');
  static const deathId = ClipId('enemy.gobliLow.death');
  static const asset = 'assets/enemies/gobli_low/attack.png';
  static const content = SpriteEnemyAnimationContent(
    idleId: idleId,
    attackId: attackId,
    deathId: deathId,
  );

  static AnimationResources resources() {
    final sheet = spriteSheetResources(
      id: attackId,
      asset: asset,
      frames: 7,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: GameBalance.attackDuration / 7,
      anchorX: 427 / 512,
      anchorY: 469 / 512,
      scale: .20,
      damageEventTime: GameBalance.damageTiming,
    );
    final guard = sheet.clips[attackId]!.frames.first.frameId;
    return AnimationResources(
      rigs: sheet.rigs.values,
      frames: sheet.frames.values,
      poses: [
        SpritePoseDefinition(
          id: const PoseId('enemy.gobliLow.guard'),
          frameId: guard,
          family: const PoseFamilyId('enemy.gobliLow.standingLeft'),
        ),
      ],
      clips: [
        ...sheet.clips.values,
        AnimationClipDefinition(
          id: idleId,
          frames: [ClipFrameDefinition(guard, GameBalance.attackDuration)],
          loopRange: const AnimationLoopRange(0, 1),
        ),
        // No authored death pose yet: retain the guard while the renderer
        // fades it over the existing death/reward transition.
        AnimationClipDefinition(
          id: deathId,
          frames: [ClipFrameDefinition(guard, GameBalance.deathDuration)],
        ),
      ],
    );
  }
}
