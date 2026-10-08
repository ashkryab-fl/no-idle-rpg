import '../balance/game_balance.dart';

/// Renderer-neutral animation metadata. Damage timing uses the same timeline.
class AnimationDefinition {
  const AnimationDefinition({
    required this.id,
    this.asset,
    this.frames = 1,
    this.frameWidth = 128,
    this.frameHeight = 128,
    this.stepTime = .6,
    this.loop = false,
    this.anchorX = .5,
    this.anchorY = 1,
    this.scale = .55,
    this.damageEventTime,
  }) : assert(frames > 0),
       assert(frameWidth > 0),
       assert(frameHeight > 0),
       assert(stepTime > 0),
       assert(scale > 0),
       assert(
         damageEventTime == null ||
             (damageEventTime >= 0 && damageEventTime <= frames * stepTime),
       );
  void validate() {
    if (id.isEmpty ||
        frames <= 0 ||
        !frameWidth.isFinite ||
        frameWidth <= 0 ||
        !frameHeight.isFinite ||
        frameHeight <= 0 ||
        !stepTime.isFinite ||
        stepTime <= 0 ||
        !duration.isFinite ||
        !scale.isFinite ||
        scale <= 0 ||
        !anchorX.isFinite ||
        !anchorY.isFinite ||
        (damageEventTime != null &&
            (!damageEventTime!.isFinite ||
                damageEventTime! < 0 ||
                damageEventTime! > duration))) {
      throw ArgumentError('Invalid animation definition: $id');
    }
  }

  final String id;
  final String? asset;
  final int frames;
  final double frameWidth, frameHeight, stepTime, anchorX, anchorY, scale;
  final bool loop;
  final double? damageEventTime;
  double get duration => frames * stepTime;
}

abstract final class AssetCatalog {
  static const heroRoot = 'assets/characters/hero/';
  static const enemyRoot = 'assets/enemies/';
  static const background = 'assets/environment/background_01.png';
}

class AnimationCatalog {
  AnimationCatalog([Map<String, AnimationDefinition>? overrides]) {
    definitions['hero.walk'] = const AnimationDefinition(
      id: 'hero.walk',
      asset: '${AssetCatalog.heroRoot}walk.png',
      frames: 10,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: .125,
      loop: true,
      anchorX: .62,
      anchorY: .875,
      scale: .20,
    );
    definitions['hero.attack'] = const AnimationDefinition(
      id: 'hero.attack',
      asset: '${AssetCatalog.heroRoot}attack.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: GameBalance.attackDuration / 4,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
      damageEventTime: GameBalance.damageTiming,
    );
    definitions['hero.idle'] = const AnimationDefinition(
      id: 'hero.idle',
      asset: '${AssetCatalog.heroRoot}ready.png',
      frameWidth: 512,
      frameHeight: 512,
      loop: true,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
    );
    definitions['hero.death'] = const AnimationDefinition(
      id: 'hero.death',
      asset: '${AssetCatalog.heroRoot}death.png',
      frames: 4,
      frameWidth: 512,
      frameHeight: 512,
      stepTime: GameBalance.heroDeathFrameTime,
      anchorX: .58,
      anchorY: .875,
      scale: .25,
    );
    definitions.addAll(overrides ?? {});
    for (final entry in definitions.entries) {
      entry.value.validate();
      if (entry.key != entry.value.id) {
        throw ArgumentError('Animation key must match its ID');
      }
    }
  }
  final Map<String, AnimationDefinition> definitions = {
    for (final prefix in ['hero', 'slime', 'sentinel', 'wisp']) ...{
      '$prefix.walk': AnimationDefinition(
        id: '$prefix.walk',
        stepTime: GameBalance.attackDuration,
        loop: true,
      ),
      '$prefix.idle': AnimationDefinition(
        id: '$prefix.idle',
        stepTime: .8,
        loop: true,
      ),
      '$prefix.attack': AnimationDefinition(
        id: '$prefix.attack',
        stepTime: GameBalance.attackDuration,
        damageEventTime: GameBalance.damageTiming,
      ),
      '$prefix.hit': AnimationDefinition(
        id: '$prefix.hit',
        stepTime: GameBalance.hitDuration,
      ),
      '$prefix.death': AnimationDefinition(
        id: '$prefix.death',
        stepTime: GameBalance.deathDuration,
      ),
    },
    for (final id in ['a1', 'a2', 'a3', 'b', 'c', 'd'])
      'hero.$id': AnimationDefinition(
        id: 'hero.$id',
        stepTime: id == 'a1' ? .8 : 1.2,
      ),
    'hero.caught': const AnimationDefinition(
      id: 'hero.caught',
      stepTime: GameBalance.caughtDuration,
    ),
  };
  AnimationDefinition get(String id) =>
      definitions[id] ?? AnimationDefinition(id: id);
}
