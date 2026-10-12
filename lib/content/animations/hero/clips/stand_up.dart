part of '../clips.dart';

void _addHeroStandUp(_HeroClipBuilder builder) {
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.standUp'),
      asset: '${_heroAssetRoot}stand_up.png',
      frames: 6,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .25,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
      scaleMultiplier: 1.05,
    ),
  );
  builder.contract(
    'hero.standUp',
    entry: const AnimationPoseContract.family(PoseFamilyId.seated),
    exit: const AnimationPoseContract.family(PoseFamilyId.standingRight),
  );
}
