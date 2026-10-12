part of '../clips.dart';

void _addHeroDeath(_HeroClipBuilder builder) {
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.death'),
      asset: '${_heroAssetRoot}death.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: GameBalance.heroDeathFrameTime,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
    ),
  );
}
