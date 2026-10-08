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
import '../core/assets/animation_catalog.dart';

class DesktopGame extends FlameGame {
  DesktopGame(this.simulation);
  final GameSimulation simulation;
  async.Timer? _frameTimer;
  final _clock = Stopwatch();
  int _lastMicroseconds = 0;
  bool suspended = false;
  @override
  Color backgroundColor() => const Color(0x00000000);
  @override
  Future<void> onLoad() async {
    images.prefix = '';
    final loaded = <String, SpriteAnimation>{};
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest.listAssets().toSet();
    for (final d in simulation.animations.definitions.values) {
      if (d.asset == null || !bundled.contains(d.asset)) continue;
      try {
        loaded[d.id] = await loadSpriteAnimation(
          d.asset!,
          SpriteAnimationData.sequenced(
            amount: d.frames,
            stepTime: d.stepTime,
            textureSize: Vector2(d.frameWidth, d.frameHeight),
            loop: d.loop,
          ),
        );
      } catch (error) {
        debugPrint('Animation ${d.id} uses placeholder: $error');
      }
    }
    Sprite? background;
    if (bundled.contains(AssetCatalog.background)) {
      try {
        background = await loadSprite(AssetCatalog.background);
      } catch (error) {
        debugPrint('Background uses placeholder: $error');
      }
    }
    await addAll([
      ScrollingEnvironment(simulation, sprite: background),
      ActorComponent(simulation, loaded, hero: true),
      EnemyComponent(simulation, loaded),
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
