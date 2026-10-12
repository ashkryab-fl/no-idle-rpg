part of '../clips.dart';

void _addHeroAttack(_HeroClipBuilder builder) {
  builder.add(
    spriteSheetResources(
      id: ClipId('hero.attack'),
      asset: '${_heroAssetRoot}attack.png',
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
}
