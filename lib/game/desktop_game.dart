import 'dart:async' as async;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'components/environment/scrolling_environment.dart';
import 'components/hero/actor_component.dart';
import 'components/enemies/enemy_component.dart';
import 'components/effects/combat_effect.dart';
import 'systems/game_simulation.dart';
import 'animation/flame_sprite_frame_cache.dart';
import '../core/assets/animation_catalog.dart';

class DesktopGame extends FlameGame {
  DesktopGame(this.simulation);
  final GameSimulation simulation;
  late final FlameSpriteFrameCache frameCache;
  async.Timer? _frameTimer;
  final _clock = Stopwatch();
  int _lastMicroseconds = 0;
  bool suspended = false;
  @override
  Color backgroundColor() => const Color(0x00000000);
  @override
  Future<void> onLoad() async {
    images.prefix = '';
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest.listAssets().toSet();
    frameCache = FlameSpriteFrameCache(simulation.animations.resources, images);
    await frameCache.load(bundled);
    final backgrounds = <Sprite>[];
    for (final asset in AssetCatalog.backgrounds) {
      if (!bundled.contains(asset)) continue;
      try {
        backgrounds.add(await loadSprite(asset));
      } catch (error) {
        debugPrint('Background $asset could not be loaded: $error');
      }
    }
    Sprite? road;
    if (bundled.contains(AssetCatalog.road)) {
      try {
        road = await loadSprite(
          AssetCatalog.road,
          srcPosition: Vector2(0, 217),
          srcSize: Vector2(2172, 290),
        );
      } catch (error) {
        debugPrint('Road could not be loaded: $error');
      }
    }
    await addAll([
      ScrollingEnvironment(simulation, sprites: backgrounds, road: road),
      ActorComponent(simulation, frameCache, hero: true),
      EnemyComponent(simulation, frameCache),
    ]);
  }

  @override
  void onMount() {
    super.onMount();
    pauseEngine();
    _clock.start();
    setFps(simulation.settings.fps);
  }

  void setFps(int fps) {
    _frameTimer?.cancel();
    _lastMicroseconds = _clock.elapsedMicroseconds;
    _frameTimer = async.Timer.periodic(
      Duration(microseconds: (1e6 / fps).round()),
      (_) {
        final current = _clock.elapsedMicroseconds;
        final dt = (current - _lastMicroseconds) / 1e6;
        _lastMicroseconds = current;
        if (!suspended) stepEngine(stepTime: dt);
      },
    );
  }

  @override
  void update(double dt) {
    simulation.advance(dt);
    for (final event in simulation.events) {
      add(CombatEffect(event));
    }
    simulation.events.clear();
    super.update(dt);
  }

  @override
  void onRemove() {
    _frameTimer?.cancel();
    _clock.stop();
    super.onRemove();
  }
}
