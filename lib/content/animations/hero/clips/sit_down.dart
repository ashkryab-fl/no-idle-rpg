part of '../clips.dart';

void _addHeroSitDown(_HeroClipBuilder builder) {
  const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.sitDown'),
      asset: '${_heroAssetRoot}sit_down.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .3,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
    ),
  );
  builder.contract('hero.sitDown', exit: seated, sharedFrame: 3);
}
