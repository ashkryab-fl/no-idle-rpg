part of '../clips.dart';

void _addHeroSeated(_HeroClipBuilder builder) {
  const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.seated'),
      asset: '${_heroAssetRoot}seated.png',
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .3,
      loop: true,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
      scaleMultiplier: 1.05,
    ),
  );
  builder.contract('hero.seated', entry: seated, exit: seated);
}
