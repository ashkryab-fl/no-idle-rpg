part of '../clips.dart';

void _addHeroCoffee(_HeroClipBuilder builder) {
  // Reuse the phone entry's stop and sword-supported pocket poses unchanged.
  builder.clips[HeroClips.coffeeEnter] = AnimationClipDefinition(
    id: HeroClips.coffeeEnter,
    frames: const [
      ClipFrameDefinition(FrameId('hero.walk.frame.8'), .125),
      ClipFrameDefinition(FrameId('hero.phoneFrames.frame.0'), .16),
      ClipFrameDefinition(FrameId('hero.phoneFrames.frame.1'), .20),
    ],
    entryPose: const AnimationPoseContract.pose(HeroPoses.walkLast),
    exitPose: const AnimationPoseContract.pose(HeroPoses.phonePocket),
  );
  const sheet = ClipId('hero.coffeeFrames');
  builder.add(
    spriteSheetResources(
      id: sheet,
      asset: '${_heroAssetRoot}coffee.png',
      frames: 6,
      frameWidth: 512,
      frameHeight: 512,
      anchorX: .62,
      anchorY: .875,
      scale: .20,
    ),
  );
  final frames = builder.clips.remove(sheet)!.frames;
  ClipFrameDefinition frame(int index, double duration) =>
      ClipFrameDefinition(frames[index].frameId, duration);
  builder.clips[HeroClips.coffee] = AnimationClipDefinition(
    id: HeroClips.coffee,
    frames: [
      frame(0, 3), // Rest with the mug below her face.
      frame(1, .18), // Raise it.
      frame(2, .16), // Touch the rim to her lips.
      frame(3, .55), // Sip.
      frame(2, .12), // Straighten the mug before lowering it.
      frame(4, .18), // Lower it.
      frame(5, .65), // Enjoy the sip, then open her eyes again.
    ],
    loopRange: const AnimationLoopRange(0, 7),
    entryPose: const AnimationPoseContract.pose(HeroPoses.coffeeNeutral),
    exitPose: const AnimationPoseContract.family(HeroPoses.coffeeFamily),
  );
}
