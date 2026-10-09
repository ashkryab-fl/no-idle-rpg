import 'ids.dart';

/// Geometry in source pixels. Anchors are normalized to the canvas, and
/// worldUnitsPerPixel preserves existing artwork's render scale.
class SpriteRigDefinition {
  const SpriteRigDefinition({
    required this.id,
    required this.canvasWidth,
    required this.canvasHeight,
    this.anchorX = .5,
    this.anchorY = 1,
    this.worldUnitsPerPixel = 1,
  });

  final RigId id;
  final double canvasWidth, canvasHeight, anchorX, anchorY, worldUnitsPerPixel;

  void validate() {
    validateAnimationId(id.value);
    if ([
          canvasWidth,
          canvasHeight,
          worldUnitsPerPixel,
        ].any((v) => !v.isFinite || v <= 0) ||
        !anchorX.isFinite ||
        !anchorY.isFinite) {
      throw ArgumentError('Invalid sprite rig: ${id.value}');
    }
  }
}
