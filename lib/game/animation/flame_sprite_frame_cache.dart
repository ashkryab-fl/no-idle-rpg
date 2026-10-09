import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/animation/ids.dart';

/// Loads image/atlas data only. No FPS, loop flag, ticker or animation selection.
/// Shared FrameIds resolve to the same Sprite; each asset is requested once.
final class FlameSpriteFrameCache {
  FlameSpriteFrameCache(this.resources, this.images);
  final AnimationResources resources;
  final Images images;
  final Map<FrameId, Sprite> _sprites = {};
  Future<void>? _loading;
  int get length => _sprites.length;
  Sprite sprite(FrameId id) =>
      _sprites[id] ?? (throw StateError('Sprite frame is not loaded: $id'));

  Future<void> load(Set<String> bundledAssets) async {
    try {
      await (_loading ??= _load(bundledAssets));
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> _load(Set<String> bundledAssets) async {
    final used = {
      for (final clip in resources.clips.values)
        for (final frame in clip.frames) frame.frameId,
      for (final pose in resources.poses.values) pose.frameId,
    };
    final assets = <String>{};
    for (final id in used) {
      final frame = resources.frame(id);
      if (frame.debugPlaceholder) continue;
      if (!bundledAssets.contains(frame.asset)) {
        throw ArgumentError(
          'Missing bundled sprite asset: ${frame.asset} ($id)',
        );
      }
      assets.add(frame.asset!);
    }
    await images.loadAll(assets.toList());
    final loaded = <FrameId, Sprite>{};
    for (final id in used) {
      final frame = resources.frame(id);
      if (frame.debugPlaceholder) continue;
      final image = images.fromCache(frame.asset!);
      final rect = frame.source;
      if (rect.x + rect.width > image.width ||
          rect.y + rect.height > image.height) {
        throw ArgumentError(
          'Sprite rectangle outside asset: ${frame.asset} ($id)',
        );
      }
      loaded[id] = Sprite(
        image,
        srcPosition: Vector2(rect.x, rect.y),
        srcSize: Vector2(rect.width, rect.height),
      );
    }
    _sprites.addAll(loaded);
  }
}
