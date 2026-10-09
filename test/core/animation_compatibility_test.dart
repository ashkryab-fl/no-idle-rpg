import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/animation_player.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';

void main() {
  test(
    'installed sprites preserve pre-refactor metadata, cursor and geometry',
    () {
      // Frozen from the working tree before stage 1, including six-frame stand-up.
      final baseline =
          jsonDecode(
                File(
                  'test/fixtures/animation_catalog_stage1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final catalog = AnimationCatalog();
      final installed = Map<String, dynamic>.fromEntries(
        baseline.entries.where(
          (entry) => (entry.value as Map)['asset'] != null,
        ),
      );
      expect(catalog.definitions.keys.toSet(), installed.keys.toSet());
      expect(
        catalog.resources.frames.values.every(
          (frame) => frame.asset != null && !frame.debugPlaceholder,
        ),
        isTrue,
      );
      for (final entry in installed.entries) {
        final old = entry.value as Map<String, dynamic>;
        final definition = catalog.get(entry.key);
        expect(
          {
            'asset': definition.asset,
            'frames': definition.frames,
            'frameWidth': definition.frameWidth,
            'frameHeight': definition.frameHeight,
            'stepTime': definition.stepTime,
            'loop': definition.loop,
            'loopStartFrame': definition.loopStartFrame,
            'anchorX': definition.anchorX,
            'anchorY': definition.anchorY,
            'scale': definition.scale,
            'scaleMultiplier': definition.scaleMultiplier,
            'damageEventTime': definition.damageEventTime,
          },
          old,
          reason: entry.key,
        );
        final frames = (old['frames'] as num).toInt();
        final stepTime = (old['stepTime'] as num).toDouble();
        final loopStart = (old['loopStartFrame'] as num).toInt();
        final loop = old['loop'] as bool;
        expect(definition.duration, closeTo(frames * stepTime, 1e-10));
        int oldIndex(double elapsed) {
          final index = (elapsed / stepTime).floor();
          return !loop || index < frames
              ? index.clamp(0, frames - 1)
              : loopStart + (index - loopStart) % (frames - loopStart);
        }

        for (var sample = 0; sample < 300; sample++) {
          // Sample inside frames, avoiding the old floor formula's round-off.
          final time = (sample + .37) * stepTime;
          final player = AnimationPlayer(definition.clip)..advance(time);
          expect(
            player.snapshot.frameIndex,
            oldIndex(time),
            reason: '${entry.key} at $time',
          );
          expect(definition.frameIndex(time), oldIndex(time));
        }
        for (var index = 0; index < frames; index++) {
          final rig = definition.frameRig(index);
          final frame = definition.frameDefinition(index);
          final multiplier = entry.key == 'hero.sitDown' && index == frames - 1
              ? (baseline['hero.seated'] as Map)['scaleMultiplier']
              : old['scaleMultiplier'];
          expect(
            rig.canvasWidth * rig.worldUnitsPerPixel * frame.scaleMultiplier,
            closeTo(
              (old['frameWidth'] as num) *
                  (old['scale'] as num) *
                  (multiplier as num),
              1e-10,
            ),
          );
          expect(rig.anchorX, old['anchorX']);
          expect(rig.anchorY, old['anchorY']);
          expect(frame.source.width, old['frameWidth']);
          expect(frame.source.height, old['frameHeight']);
          final shared =
              entry.key == 'hero.sitDown' && index == frames - 1 ||
              entry.key == 'hero.sharpen' && index == 0;
          expect(
            frame.asset,
            shared ? baseline['hero.seated']['asset'] : old['asset'],
          );
          expect(
            frame.source.x,
            shared ? 0 : index * (old['frameWidth'] as num),
          );
        }
        final damage = definition.clip.markers.where(
          (m) => m.kind == AnimationMarkerKind.damage,
        );
        if (old['damageEventTime'] == null) {
          expect(damage, isEmpty);
        } else {
          expect(damage.single.time, old['damageEventTime']);
          final events = AnimationPlayer(
            definition.clip,
          ).advance(definition.duration).events;
          expect(events.single.marker.kind, AnimationMarkerKind.damage);
          expect(events.single.elapsed, old['damageEventTime']);
        }
      }
    },
  );
}
