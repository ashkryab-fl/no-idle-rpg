import '../../../core/animation/ids.dart';
import '../../../core/animation/sprite_frame.dart';

/// Static poses contain artwork and geometry; graph nodes own their duration.
abstract final class HeroPoses {
  static const seatedFrame = FrameId('hero.seated.frame.0');
  static const definitions = [
    SpritePoseDefinition(
      id: PoseId.seatedNeutral,
      frameId: seatedFrame,
      family: PoseFamilyId.seated,
    ),
  ];
}
