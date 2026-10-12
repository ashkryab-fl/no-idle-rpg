part of '../clips.dart';

void _addHeroAttack(_HeroClipBuilder builder) {
  const id = ClipId('hero.attack');
  const step = GameBalance.heroAttackDuration / 6;
  builder.add(
    spriteSheetResources(
      id: id,
      asset: '${_heroAssetRoot}attack.png',
      frames: 5,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: step,
      anchorX: .62,
      anchorY: .875,
      scale: .20,
      damageEventTime: GameBalance.damageTiming,
    ),
  );
  final clip = builder.clips[id]!;
  builder.clips[id] = AnimationClipDefinition(
    id: id,
    frames: [
      for (var i = 0; i < clip.frames.length; i++)
        ClipFrameDefinition(clip.frames[i].frameId, i == 1 ? step * 2 : step),
    ],
    markers: clip.markers,
  );
}
