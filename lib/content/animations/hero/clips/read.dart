part of '../clips.dart';

void _addHeroRead(_HeroClipBuilder builder) {
  builder.add(
    spriteSheetResources(
      id: HeroClips.read,
      asset: '${_heroAssetRoot}read.png',
      frames: 8,
      frameWidth: 512,
      frameHeight: 512,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
      scaleMultiplier: 1.05,
    ),
  );
  const seatedFrame = HeroPoses.seatedFrame;
  const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  final readingFrames = builder.clips[HeroClips.read]!.frames;
  const seatedFamily = AnimationPoseContract.family(PoseFamilyId.seated);
  builder.clips[HeroClips.read] = AnimationClipDefinition(
    id: HeroClips.read,
    frames: [
      const ClipFrameDefinition(seatedFrame, .12),
      ClipFrameDefinition(readingFrames[0].frameId, .18),
      ClipFrameDefinition(readingFrames[1].frameId, .18),
      // Hold the reading pose for exactly four seconds between page turns.
      ClipFrameDefinition(readingFrames[2].frameId, 4),
      for (final index in [3, 4, 5, 6])
        ClipFrameDefinition(readingFrames[index].frameId, .12),
    ],
    loopRange: const AnimationLoopRange(3, 8),
    entryPose: seated,
    exitPose: seatedFamily,
  );
}
