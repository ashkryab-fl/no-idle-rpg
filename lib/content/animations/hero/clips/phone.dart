part of '../clips.dart';

void _addHeroPhone(_HeroClipBuilder builder) {
  const sheet = ClipId('hero.phoneFrames');
  builder.add(
    spriteSheetResources(
      id: sheet,
      asset: '${_heroAssetRoot}phone.png',
      frames: 11,
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
      const ClipFrameDefinition(FrameId('hero.walk.frame.8'), .125),
      frame(0, .16),
      frame(1, .20),
      frame(2, .18),
      frame(3, .14),
    ],
    entryPose: const AnimationPoseContract.pose(HeroPoses.walkLast),
    exitPose: phone,
  );
  // Neutral phone holds occupy most of the cycle; laughter is a short beat.
  builder.clips[HeroClips.phoneScroll] = AnimationClipDefinition(
    id: HeroClips.phoneScroll,
    frames: [
      frame(3, 1.2),
      frame(3, .16),
      frame(3, 1.4),
      frame(3, .16),
      frame(3, 1.6),
      frame(3, .16),
      frame(3, 1.0),
      frame(4, .20),
      frame(5, .26),
      frame(4, .18),
      frame(5, .22),
      frame(4, .16),
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
      frame(6, .30),
      frame(7, .09),
      frame(8, .09),
      frame(9, .10),
      frame(10, .12),
    ],
    entryPose: phoneFamily,
    // Walking owns its first-frame hold after the final phone stride.
    exitPose: const AnimationPoseContract.family(PoseFamilyId.walkingRight),
    markers: const [
      AnimationMarker(id: 'phoneReleased', time: .39),
      AnimationMarker(id: 'swordGrabbed', time: .48),
    ],
  );
}
