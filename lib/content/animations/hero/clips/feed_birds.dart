part of '../clips.dart';

void _addHeroFeedBirds(_HeroClipBuilder builder) {
  builder.clips[HeroClips.feedBirdsStanding] = AnimationClipDefinition(
    id: HeroClips.feedBirdsStanding,
    frames: const [ClipFrameDefinition(FrameId('hero.idle.frame.0'), .3)],
    // Stop the walking step before fading to the separate bench scene.
    exitPose: const AnimationPoseContract.pose(HeroPoses.standing),
  );
  const sheet = ClipId('hero.feedBirdsFrames');
  builder.add(
    spriteSheetResources(
      id: sheet,
      asset: '${_heroAssetRoot}feed_birds.png',
      frames: 8,
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
  final timeline = [
    // Birds keep pecking while the heroine rests between handfuls.
    for (var peck = 0; peck < 4; peck++) ...[frame(0, .4), frame(1, .4)],
    frame(2, .18), // Reach toward the sack.
    frame(3, .24), // Gather seed inside the sack.
    frame(4, .18), // Lift a handful.
    frame(5, .14), // Begin the underhand toss.
    frame(6, .18), // Scatter seed at the birds' feet.
    frame(7, .18), // Return the hand to the resting pose.
  ];
  builder.clips[HeroClips.feedBirds] = AnimationClipDefinition(
    id: HeroClips.feedBirds,
    frames: timeline,
    loopRange: AnimationLoopRange(0, timeline.length),
    entryPose: const AnimationPoseContract.pose(HeroPoses.feedBirds),
    exitPose: const AnimationPoseContract.family(HeroPoses.feedBirdsFamily),
  );
}
