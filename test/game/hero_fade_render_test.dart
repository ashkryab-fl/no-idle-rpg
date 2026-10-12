import 'dart:ui' as ui;
import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/content/animations/hero/clips.dart';
import 'package:idle_companion/content/animations/hero/debug_previews.dart';
import 'package:idle_companion/game/animation/flame_sprite_frame_cache.dart';
import 'package:idle_companion/game/components/hero/actor_component.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'crossfade keeps overlapping pixels opaque and uses both original rigs',
    () async {
      final resources = HeroClips.resources();
      final game = GameSimulation(resources: resources);
      final images = Images(prefix: '');
      addTearDown(images.clearCache);
      // Synthetic solid sprites isolate blending from the authored artwork.
      final sizes = <String, (int, int)>{};
      for (final frame in resources.frames.values) {
        if (frame.debugPlaceholder) continue;
        final rect = frame.source;
        final previous = sizes[frame.asset!] ?? (0, 0);
        final w = (rect.x + rect.width).toInt();
        final h = (rect.y + rect.height).toInt();
        sizes[frame.asset!] = (
          w > previous.$1 ? w : previous.$1,
          h > previous.$2 ? h : previous.$2,
        );
      }
      for (final entry in sizes.entries) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          ui.Rect.fromLTWH(
            0,
            0,
            entry.value.$1.toDouble(),
            entry.value.$2.toDouble(),
          ),
          ui.Paint()
            ..color = entry.key.endsWith('/sleep.png')
                ? const ui.Color(0xff0000ff)
                : const ui.Color(0xffff0000),
        );
        final picture = recorder.endRecording();
        images.add(
          entry.key,
          await picture.toImage(entry.value.$1, entry.value.$2),
        );
        picture.dispose();
      }
      final cache = FlameSpriteFrameCache(resources, images);
      await cache.load(sizes.keys.toSet());
      final actor = ActorComponent(game, cache, hero: true);
      for (final (time, expected) in [
        (.3, [255, 0, 0, 255]),
        (.55, [128, 0, 128, 255]),
        (.8, [0, 0, 255, 255]),
      ]) {
        game.heroAnimations.startPreview(HeroAnimationPreview.sleepRest);
        game.advance(time);
        final recorder = ui.PictureRecorder();
        actor.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 190);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        // These samples lie inside the overlap and outside both sprite canvases.
        final center = (150 * 400 + 104) * 4;
        for (var channel = 0; channel < 4; channel++) {
          expect(pixels[center + channel], closeTo(expected[channel], 1));
        }
        expect(pixels.sublist(0, 4), [0, 0, 0, 0]);
        image.dispose();
        picture.dispose();
      }
    },
  );
}
