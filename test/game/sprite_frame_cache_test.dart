import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/core/animation/animation_resources.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/animation/sprite_frame.dart';
import 'package:idle_companion/game/animation/flame_sprite_frame_cache.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

class TrackingImages extends Images {
  TrackingImages() : super(prefix: '');
  final List<String> requests = [];
  Completer<void>? gate;
  @override
  Future<ui.Image> load(String fileName, {String? key, String? package}) async {
    requests.add(fileName);
    if (gate != null) await gate!.future;
    return super.load(fileName, key: key, package: package);
  }
}

void main() {
  testWidgets(
    'content variants reuse the eight installed PNGs and cleanup pose',
    (tester) async {
      final resources = demoAnimationResources();
      final images = TrackingImages();
      final cache = FlameSpriteFrameCache(resources, images);
      await tester.runAsync(() async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        await cache.load(manifest.listAssets().toSet());
      });
      expect(images.requests.toSet(), hasLength(8));
      expect(images.requests, hasLength(8));
      final neutral = cache.sprite(
        resources.pose(PoseId.seatedNeutral).frameId,
      );
      expect(
        identical(
          cache.sprite(
            resources.clip(HeroClips.sharpenSlow).frames.first.frameId,
          ),
          neutral,
        ),
        true,
      );
      expect(
        identical(
          cache.sprite(
            resources.clip(HeroClips.sharpenCleanup).frames.last.frameId,
          ),
          neutral,
        ),
        true,
      );
      images.clearCache();
    },
  );

  testWidgets('late image loading cannot replace a newer playback generation', (
    tester,
  ) async {
    final game = GameSimulation(random: Random(1));
    final images = TrackingImages()..gate = Completer<void>();
    final cache = FlameSpriteFrameCache(game.resources, images);
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final pending = cache.load(manifest.listAssets().toSet());
      final old = game.heroPlayback;
      game.killHero();
      game.advance(.45);
      final current = game.heroPlayback;
      expect(current.generation, greaterThan(old.generation));
      expect(current.frameIndex, 1);
      images.gate!.complete();
      await pending;
      expect(game.heroPlayback.generation, current.generation);
      expect(game.heroPlayback.frameId, current.frameId);
      expect(game.heroPlayback.elapsed, current.elapsed);
      expect(cache.sprite(current.frameId!).srcPosition.x, 512);
      images.clearCache();
    });
  });

  testWidgets(
    'missing atlases and invalid rectangles fail instead of rendering empty pixels',
    (tester) async {
      final original = defaultAnimationResources();
      final frame = original.frame(
        original.clip(const ClipId('hero.idle')).frames.single.frameId,
      );
      final resources = AnimationResources(
        rigs: original.rigs.values,
        frames: [
          SpriteFrameDefinition(
            id: frame.id,
            rigId: frame.rigId,
            asset: frame.asset!,
            source: const SpriteSourceRect(0, 0, 513, 512),
          ),
        ],
        clips: [
          AnimationClipDefinition(
            id: const ClipId('bad'),
            frames: [ClipFrameDefinition(frame.id, .5)],
          ),
        ],
      );
      final images = TrackingImages();
      final cache = FlameSpriteFrameCache(resources, images);
      await tester.runAsync(() async {
        await expectLater(cache.load({}), throwsArgumentError);
        await expectLater(cache.load({frame.asset!}), throwsArgumentError);
      });
      expect(cache.length, 0);
      images.clearCache();
    },
  );
}
