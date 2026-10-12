part of '../clips.dart';

void _addHeroIdle(_HeroClipBuilder builder) {
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.idle'),
      asset: '${_heroAssetRoot}ready.png',
      frameWidth: 512,
      frameHeight: 512,
      loop: true,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
    ),
  );
}
