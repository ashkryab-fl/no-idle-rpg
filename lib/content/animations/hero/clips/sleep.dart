part of '../clips.dart';

void _addHeroSleep(_HeroClipBuilder builder) {
  const sheet = ClipId('hero.sleepFrames');
  builder.add(
    spriteSheetResources(
      id: sheet,
      asset: '${_heroAssetRoot}sleep.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      anchorX: .5,
      anchorY: .875,
      scale: .23,
    ),
  );
  final frames = builder.clips.remove(sheet)!.frames;
  ClipFrameDefinition frame(int index, double duration) =>
      ClipFrameDefinition(frames[index].frameId, duration);
  builder.clips[HeroClips.sleep] = AnimationClipDefinition(
    id: HeroClips.sleep,
    // End poses hold four seconds. Intermediate frames run in reverse on return.
    frames: [
      frame(0, 4),
      frame(1, .18),
      frame(2, .18),
      frame(3, 4),
      frame(2, .18),
      frame(1, .18),
    ],
    loopRange: const AnimationLoopRange(0, 6),
    entryPose: const AnimationPoseContract.pose(HeroPoses.sleepFacing),
    exitPose: const AnimationPoseContract.family(HeroPoses.sleepFamily),
  );
}
