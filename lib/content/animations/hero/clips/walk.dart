part of '../clips.dart';

void _addHeroWalk(_HeroClipBuilder builder) {
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.walk'),
      asset: '${_heroAssetRoot}walk.png',
      frames: 9,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .125,
      loop: true,
      anchorX: .62,
      anchorY: .875,
      scale: .20,
    ),
  );
  builder.contract(
    'hero.walk',
    entry: const AnimationPoseContract.family(PoseFamilyId.walkingRight),
    exit: const AnimationPoseContract.family(PoseFamilyId.walkingRight),
  );
}
