part of '../clips.dart';

void _addHeroPhone(_HeroClipBuilder builder) {
  const sheet = ClipId('hero.phoneFrames');
  builder.add(
    spriteSheetResources(
      id: sheet,
      asset: '${_heroAssetRoot}phone.png',
      frames: 12,
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
  const phone = AnimationPoseContract.pose(HeroPoses.phoneNeutral);
  const phoneFamily = AnimationPoseContract.family(HeroPoses.phoneFamily);
  builder.clips[HeroClips.phoneEnter] = AnimationClipDefinition(
    id: HeroClips.phoneEnter,
    frames: [
      const ClipFrameDefinition(FrameId('hero.walk.frame.9'), .125),
      frame(0, .16),
      frame(1, .20),
      frame(2, .18),
      frame(3, .14),
    ],
    entryPose: const AnimationPoseContract.pose(HeroPoses.walkLast),
    exitPose: phone,
  );
  // Thumb swipes occupy most of the cycle; laughter is a short occasional beat.
  builder.clips[HeroClips.phoneScroll] = AnimationClipDefinition(
    id: HeroClips.phoneScroll,
    frames: [
      frame(3, 1.2),
      frame(4, .16),
      frame(3, 1.4),
      frame(4, .16),
      frame(3, 1.6),
      frame(4, .16),
      frame(3, 1.0),
      frame(5, .20),
      frame(6, .26),
      frame(5, .18),
      frame(6, .22),
      frame(5, .16),
      frame(3, .4),
    ],
    loopRange: const AnimationLoopRange(0, 13),
    entryPose: phone,
    exitPose: phoneFamily,
  );
  // Phone is airborne in release/grab/stride; the sword is taken before it lands.
  builder.clips[HeroClips.phoneWake] = AnimationClipDefinition(
    id: HeroClips.phoneWake,
    frames: [
      frame(7, .10),
      frame(8, .09),
      frame(9, .09),
      frame(10, .10),
      frame(11, .12),
      const ClipFrameDefinition(FrameId('hero.walk.frame.0'), .125),
    ],
    entryPose: phoneFamily,
    exitPose: const AnimationPoseContract.pose(HeroPoses.walkFirst),
    markers: const [
      AnimationMarker(id: 'phoneReleased', time: .19),
      AnimationMarker(id: 'swordGrabbed', time: .28),
    ],
  );
}
