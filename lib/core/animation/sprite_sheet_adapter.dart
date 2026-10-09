import 'animation_clip.dart';
import 'animation_resources.dart';
import 'ids.dart';
import 'sprite_frame.dart';
import 'sprite_rig.dart';

/// Uniform horizontal sheets are the legacy authoring format. The resulting
/// resources use explicit rectangles and durations, with no FPS at runtime.
AnimationResources spriteSheetResources({
  required ClipId id,
  String? asset,
  int frames = 1,
  double frameWidth = 128,
  double frameHeight = 128,
  double stepTime = .6,
  bool loop = false,
  int loopStartFrame = 0,
  double anchorX = .5,
  double anchorY = 1,
  double scale = .55,
  double scaleMultiplier = 1,
  double? damageEventTime,
  AnimationPoseContract? entryPose,
  AnimationPoseContract? exitPose,
}) {
  if (frames <= 0 ||
      loopStartFrame < 0 ||
      loopStartFrame >= frames ||
      (!loop && loopStartFrame != 0)) {
    throw ArgumentError('Invalid sprite sheet: ${id.value}');
  }
  final rigId = RigId('${id.value}.rig');
  final definitions = List.generate(frames, (index) {
    final frameId = FrameId('${id.value}.frame.$index');
    final source = SpriteSourceRect(
      index * frameWidth,
      0,
      frameWidth,
      frameHeight,
    );
    return asset == null
        ? SpriteFrameDefinition.debugPlaceholder(
            id: frameId,
            rigId: rigId,
            source: source,
            scaleMultiplier: scaleMultiplier,
          )
        : SpriteFrameDefinition(
            id: frameId,
            rigId: rigId,
            source: source,
            asset: asset,
            scaleMultiplier: scaleMultiplier,
          );
  });
  return AnimationResources(
    rigs: [
      SpriteRigDefinition(
        id: rigId,
        canvasWidth: frameWidth,
        canvasHeight: frameHeight,
        anchorX: anchorX,
        anchorY: anchorY,
        worldUnitsPerPixel: scale,
      ),
    ],
    frames: definitions,
    clips: [
      AnimationClipDefinition(
        id: id,
        frames: [
          for (final frame in definitions)
            ClipFrameDefinition(frame.id, stepTime),
        ],
        loopRange: loop ? AnimationLoopRange(loopStartFrame, frames) : null,
        markers: [
          if (damageEventTime != null)
            AnimationMarker(
              id: 'damage',
              time: damageEventTime,
              kind: AnimationMarkerKind.damage,
            ),
        ],
        entryPose: entryPose,
        exitPose: exitPose,
      ),
    ],
  );
}
