import '../../core/animation/animation_clip.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/animation/ids.dart';
import '../../core/animation/sprite_frame.dart';
import '../../core/animation/sprite_rig.dart';
import '../../core/animation/sprite_sheet_adapter.dart';
import '../../core/balance/game_balance.dart';

/// Installed sprite content only. Procedural enemy timing has no PNG catalog.
AnimationResources defaultAnimationResources() {
  const heroRoot = 'assets/characters/hero/';
  final rigs = <RigId, SpriteRigDefinition>{};
  final frames = <FrameId, SpriteFrameDefinition>{};
  final clips = <ClipId, AnimationClipDefinition>{};
  void add(AnimationResources resources) {
    rigs.addAll(resources.rigs);
    frames.addAll(resources.frames);
    clips.addAll(resources.clips);
  }

  add(
    spriteSheetResources(
      id: ClipId('hero.walk'),
      asset: '${heroRoot}walk.png',
      frames: 10,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .125,
      loop: true,
      anchorX: .62,
      anchorY: .875,
      scale: .20,
    ),
  );
  add(
    spriteSheetResources(
      id: ClipId('hero.attack'),
      asset: '${heroRoot}attack.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: GameBalance.attackDuration / 4,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
      damageEventTime: GameBalance.damageTiming,
    ),
  );
  add(
    spriteSheetResources(
      id: ClipId('hero.idle'),
      asset: '${heroRoot}ready.png',
      frameWidth: 512,
      frameHeight: 512,
      loop: true,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
    ),
  );
  add(
    spriteSheetResources(
      id: ClipId('hero.death'),
      asset: '${heroRoot}death.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: GameBalance.heroDeathFrameTime,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
    ),
  );
  add(
    spriteSheetResources(
      id: ClipId('hero.sitDown'),
      asset: '${heroRoot}sit_down.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .3,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
    ),
  );
  add(
    spriteSheetResources(
      id: ClipId('hero.seated'),
      asset: '${heroRoot}seated.png',
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
  add(
    spriteSheetResources(
      id: ClipId('hero.sharpen'),
      asset: '${heroRoot}sharpen.png',
      frames: 5,
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
  add(
    spriteSheetResources(
      id: ClipId('hero.standUp'),
      asset: '${heroRoot}stand_up.png',
      frames: 6,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .25,
      anchorX: .5,
      anchorY: .875,
      scale: .25,
      scaleMultiplier: 1.05,
    ),
  );

  const seatedFrame = FrameId('hero.seated.frame.0');
  const seated = AnimationPoseContract.pose(PoseId.seatedNeutral);
  void contract(
    String id, {
    AnimationPoseContract? entry,
    AnimationPoseContract? exit,
    int? sharedFrame,
  }) {
    final key = ClipId(id);
    final clip = clips[key]!;
    clips[key] = AnimationClipDefinition(
      id: key,
      frames: [
        for (var i = 0; i < clip.frames.length; i++)
          ClipFrameDefinition(
            i == sharedFrame ? seatedFrame : clip.frames[i].frameId,
            clip.frames[i].duration,
          ),
      ],
      loopRange: clip.loopRange,
      markers: clip.markers,
      entryPose: entry,
      exitPose: exit,
    );
  }

  contract('hero.sitDown', exit: seated, sharedFrame: 3);
  contract('hero.seated', entry: seated, exit: seated);
  contract(
    'hero.sharpen',
    entry: seated,
    exit: const AnimationPoseContract.family(PoseFamilyId.seated),
    sharedFrame: 0,
  );
  contract(
    'hero.standUp',
    entry: const AnimationPoseContract.family(PoseFamilyId.seated),
    exit: const AnimationPoseContract.family(PoseFamilyId.standingRight),
  );
  contract(
    'hero.walk',
    entry: const AnimationPoseContract.family(PoseFamilyId.walkingRight),
    exit: const AnimationPoseContract.family(PoseFamilyId.walkingRight),
  );
  return AnimationResources(
    rigs: rigs.values,
    frames: frames.values,
    clips: clips.values,
    poses: const [
      SpritePoseDefinition(
        id: PoseId.seatedNeutral,
        frameId: seatedFrame,
        family: PoseFamilyId.seated,
      ),
    ],
  );
}
