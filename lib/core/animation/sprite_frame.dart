import 'ids.dart';

/// An atlas rectangle, independent of Flutter/Flame's Rect.
class SpriteSourceRect {
  const SpriteSourceRect(this.x, this.y, this.width, this.height);
  final double x, y, width, height;

  void validate() {
    if ([x, y].any((v) => !v.isFinite || v < 0) ||
        [width, height].any((v) => !v.isFinite || v <= 0)) {
      throw ArgumentError('Invalid sprite source rectangle');
    }
  }
}

class SpriteFrameDefinition {
  const SpriteFrameDefinition({
    required this.id,
    required this.rigId,
    required this.source,
    required String this.asset,
    this.scaleMultiplier = 1,
  }) : debugPlaceholder = false;

  /// Placeholder content must be deliberately declared in the new catalog.
  const SpriteFrameDefinition.debugPlaceholder({
    required this.id,
    required this.rigId,
    required this.source,
    this.scaleMultiplier = 1,
  }) : asset = null,
       debugPlaceholder = true;

  final FrameId id;
  final RigId rigId;
  final String? asset;
  final SpriteSourceRect source;
  final double scaleMultiplier;
  final bool debugPlaceholder;

  void validate() {
    validateAnimationId(id.value);
    validateAnimationId(rigId.value);
    source.validate();
    if ((!debugPlaceholder && (asset == null || asset!.trim().isEmpty)) ||
        !scaleMultiplier.isFinite ||
        scaleMultiplier <= 0) {
      throw ArgumentError('Invalid sprite frame: ${id.value}');
    }
  }
}

/// A reusable pose has no FPS or hold duration; those belong to playback.
class SpritePoseDefinition {
  const SpritePoseDefinition({
    required this.id,
    required this.frameId,
    required this.family,
  });
  final PoseId id;
  final FrameId frameId;
  final PoseFamilyId family;
}
