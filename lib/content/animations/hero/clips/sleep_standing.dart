part of '../clips.dart';

void _addHeroSleepStanding(_HeroClipBuilder builder) {
  builder.clips[HeroClips.sleepStanding] = AnimationClipDefinition(
    id: HeroClips.sleepStanding,
    frames: const [ClipFrameDefinition(FrameId('hero.idle.frame.0'), .3)],
    // Stopping replaces the walk frame directly; no authored entry seam.
    exitPose: const AnimationPoseContract.pose(HeroPoses.standing),
  );
}
