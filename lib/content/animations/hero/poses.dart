import '../../../core/animation/ids.dart';
import '../../../core/animation/sprite_frame.dart';

/// Static poses contain artwork and geometry; graph nodes own their duration.
abstract final class HeroPoses {
  static const seatedFrame = FrameId('hero.seated.frame.0');
  static const walkFirst = PoseId('hero.walkFirst');
  static const walkLast = PoseId('hero.walkLast');
  static const phoneNeutral = PoseId('hero.phoneNeutral');
  static const phoneFamily = PoseFamilyId('hero.phoneRight');
  static const definitions = [
    SpritePoseDefinition(
      id: walkFirst,
      frameId: FrameId('hero.walk.frame.0'),
      family: PoseFamilyId.walkingRight,
    ),
    SpritePoseDefinition(
      id: walkLast,
      frameId: FrameId('hero.walk.frame.8'),
      family: PoseFamilyId.walkingRight,
    ),
    SpritePoseDefinition(
      id: phoneNeutral,
      frameId: FrameId('hero.phoneFrames.frame.3'),
      family: phoneFamily,
    ),
    SpritePoseDefinition(
      id: PoseId.seatedNeutral,
      frameId: seatedFrame,
      family: PoseFamilyId.seated,
    ),
  ];
}
