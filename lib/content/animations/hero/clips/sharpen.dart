part of '../clips.dart';

void _addHeroSharpen(_HeroClipBuilder builder) {
  const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.sharpen'),
      asset: '${_heroAssetRoot}sharpen.png',
      frames: 9,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .225,
      loop: true,
      // Enter from the shared neutral pose once, then keep the stone in hand.
      loopStartFrame: 1,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
      scaleMultiplier: 1.05,
    ),
  );
  builder.contract(
    'hero.sharpen',
    entry: seated,
    exit: const AnimationPoseContract.family(PoseFamilyId.seated),
    sharedFrame: 0,
  );
}
