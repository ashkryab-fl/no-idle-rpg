part of '../clips.dart';

void _addHeroReadCleanup(_HeroClipBuilder builder) {
  const seatedFrame = HeroPoses.seatedFrame;
  const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  const seatedFamily = AnimationPoseContract.family(PoseFamilyId.seated);
  final readingFrames = List.generate(
    8,
    (index) => FrameId('hero.read.frame.$index'),
  );
  builder.clips[HeroClips.readCleanup] = AnimationClipDefinition(
    id: HeroClips.readCleanup,
    frames: [
      ClipFrameDefinition(readingFrames[2], .12),
      ClipFrameDefinition(readingFrames[1], .16),
      ClipFrameDefinition(readingFrames[0], .16),
      ClipFrameDefinition(readingFrames[7], .18),
      const ClipFrameDefinition(seatedFrame, .12),
    ],
    entryPose: seatedFamily,
    exitPose: seated,
  );
}
