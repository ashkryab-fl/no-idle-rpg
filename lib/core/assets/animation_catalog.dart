import '../../content/animations/animation_resources.dart';
import '../animation/animation_clip.dart';
import '../animation/animation_resources.dart';
import '../animation/ids.dart';
import '../animation/sprite_frame.dart';
import '../animation/sprite_rig.dart';
import '../animation/sprite_sheet_adapter.dart';

/// Compatibility facade for uniform sprite sheets. New playback uses typed
/// resources and clips; const legacy overrides remain supported during migration.
class AnimationDefinition {
  const AnimationDefinition({
    required this.id,
    this.asset,
    this.frames = 1,
    this.frameWidth = 128,
    this.frameHeight = 128,
    this.stepTime = .6,
    this.loop = false,
    this.loopStartFrame = 0,
    this.anchorX = .5,
    this.anchorY = 1,
    this.scale = .55,
    this.scaleMultiplier = 1,
    this.damageEventTime,
    this.resourceCatalog,
  }) : assert(frames > 0),
       assert(frameWidth > 0),
       assert(frameHeight > 0),
       assert(stepTime > 0),
       assert(scale > 0),
       assert(scaleMultiplier > 0),
       assert(
         damageEventTime == null ||
             (damageEventTime >= 0 && damageEventTime <= frames * stepTime),
       );
  void validate() {
    if (id.isEmpty ||
        frames <= 0 ||
        loopStartFrame < 0 ||
        loopStartFrame >= frames ||
        (!loop && loopStartFrame != 0) ||
        !frameWidth.isFinite ||
        frameWidth <= 0 ||
        !frameHeight.isFinite ||
        frameHeight <= 0 ||
        !stepTime.isFinite ||
        stepTime <= 0 ||
        !(frames * stepTime).isFinite ||
        !scale.isFinite ||
        scale <= 0 ||
        !scaleMultiplier.isFinite ||
        scaleMultiplier <= 0 ||
        !anchorX.isFinite ||
        !anchorY.isFinite ||
        (damageEventTime != null &&
            (!damageEventTime!.isFinite ||
                damageEventTime! < 0 ||
                damageEventTime! > frames * stepTime))) {
      throw ArgumentError('Invalid animation definition: $id');
    }
  }

  final String id;
  final String? asset;
  final int frames, loopStartFrame;
  final double frameWidth, frameHeight, stepTime, anchorX, anchorY, scale;

  /// Per-animation size correction, applied around the sprite anchor.
  final double scaleMultiplier;
  final bool loop;
  final double? damageEventTime;
  final AnimationResources? resourceCatalog;
  static final _converted = Expando<AnimationResources>();
  AnimationResources get resources =>
      resourceCatalog ?? (_converted[this] ??= toResources());
  AnimationClipDefinition get clip => resources.clip(ClipId(id));
  double get duration => clip.duration;
  int frameIndex(double elapsed) => clip.frameIndex(elapsed);
  SpriteFrameDefinition frameDefinition(int index) =>
      resources.frame(clip.frames[index].frameId);
  SpriteRigDefinition frameRig(int index) =>
      resources.rig(frameDefinition(index).rigId);

  AnimationResources toResources() {
    validate();
    return spriteSheetResources(
      id: ClipId(id),
      asset: asset,
      frames: frames,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      stepTime: stepTime,
      loop: loop,
      loopStartFrame: loopStartFrame,
      anchorX: anchorX,
      anchorY: anchorY,
      scale: scale,
      scaleMultiplier: scaleMultiplier,
      damageEventTime: damageEventTime,
    );
  }

  factory AnimationDefinition.fromResources(
    AnimationResources resources,
    ClipId id,
  ) {
    final clip = resources.clip(id);
    if (clip.frames.any(
          (frame) => frame.duration != clip.frames.first.duration,
        ) ||
        (clip.loopRange != null && clip.loopRange!.end != clip.frames.length)) {
      throw ArgumentError(
        'Legacy adapter requires a uniform full sheet: ${id.value}',
      );
    }
    // Retain original sheet loading metadata even when a clip uses shared poses.
    final first = resources.frame(FrameId('${id.value}.frame.0'));
    final rig = resources.rig(first.rigId);
    return AnimationDefinition(
      id: id.value,
      asset: first.asset,
      frames: clip.frames.length,
      frameWidth: rig.canvasWidth,
      frameHeight: rig.canvasHeight,
      stepTime: clip.frames.first.duration,
      loop: clip.loopRange != null,
      loopStartFrame: clip.loopRange?.start ?? 0,
      anchorX: rig.anchorX,
      anchorY: rig.anchorY,
      scale: rig.worldUnitsPerPixel,
      scaleMultiplier: first.scaleMultiplier,
      damageEventTime: clip.markers
          .where((m) => m.kind == AnimationMarkerKind.damage)
          .firstOrNull
          ?.time,
      resourceCatalog: resources,
    );
  }

  factory AnimationDefinition._adapt(
    AnimationDefinition original,
    AnimationResources resources,
  ) => AnimationDefinition(
    id: original.id,
    asset: original.asset,
    frames: original.frames,
    frameWidth: original.frameWidth,
    frameHeight: original.frameHeight,
    stepTime: original.stepTime,
    loop: original.loop,
    loopStartFrame: original.loopStartFrame,
    anchorX: original.anchorX,
    anchorY: original.anchorY,
    scale: original.scale,
    scaleMultiplier: original.scaleMultiplier,
    damageEventTime: original.damageEventTime,
    resourceCatalog: resources,
  );
}

abstract final class AssetCatalog {
  static const road = 'assets/environment/road_dirt_01.png';
  static const heroRoot = 'assets/characters/hero/';
  static const enemyRoot = 'assets/enemies/';
  static const backgrounds = [
    'assets/environment/background_meadow_01.png',
    'assets/environment/background_stream_02.png',
    'assets/environment/background_wheat_03.png',
  ];
}

/// Legacy string lookup facade. Typed resource lookups are strict; the old
/// unknown-ID placeholder remains until the callers are migrated in stage 5.
class AnimationCatalog {
  AnimationCatalog([Map<String, AnimationDefinition>? overrides]) {
    final defaults = defaultAnimationResources();
    final rigs = {...defaults.rigs};
    final frames = {...defaults.frames};
    final clips = {...defaults.clips};
    for (final entry
        in (overrides ?? <String, AnimationDefinition>{}).entries) {
      entry.value.validate();
      if (entry.key != entry.value.id) {
        throw ArgumentError('Animation key must match its ID');
      }
      final converted = entry.value.toResources();
      rigs.addAll(converted.rigs);
      frames.addAll(converted.frames);
      clips.addAll(converted.clips);
    }
    // Legacy overrides only borrowed the seated multiplier, never its canvas,
    // anchor or artwork. Keep that contract while preparing frame geometry.
    if (overrides?.containsKey('hero.seated') == true ||
        overrides?.containsKey('hero.sitDown') == true) {
      const sitId = ClipId('hero.sitDown');
      final sit = clips[sitId]!;
      final lastId = FrameId('hero.sitDown.frame.${sit.frames.length - 1}');
      final last = frames[lastId]!;
      final multiplier =
          frames[const FrameId('hero.seated.frame.0')]!.scaleMultiplier;
      frames[lastId] = last.debugPlaceholder
          ? SpriteFrameDefinition.debugPlaceholder(
              id: lastId,
              rigId: last.rigId,
              source: last.source,
              scaleMultiplier: multiplier,
            )
          : SpriteFrameDefinition(
              id: lastId,
              rigId: last.rigId,
              source: last.source,
              asset: last.asset!,
              scaleMultiplier: multiplier,
            );
      clips[sitId] = AnimationClipDefinition(
        id: sitId,
        frames: [
          ...sit.frames.take(sit.frames.length - 1),
          ClipFrameDefinition(lastId, sit.frames.last.duration),
        ],
        loopRange: sit.loopRange,
        markers: sit.markers,
        entryPose: sit.entryPose,
        exitPose: sit.exitPose,
      );
      // An override need not contain the canonical seated artwork.
      if (overrides?.containsKey('hero.seated') == true &&
          overrides?.containsKey('hero.sharpen') != true) {
        const sharpenId = ClipId('hero.sharpen');
        final sharpen = clips[sharpenId]!;
        clips[sharpenId] = AnimationClipDefinition(
          id: sharpenId,
          frames: [
            ClipFrameDefinition(
              const FrameId('hero.sharpen.frame.0'),
              sharpen.frames.first.duration,
            ),
            ...sharpen.frames.skip(1),
          ],
          loopRange: sharpen.loopRange,
          markers: sharpen.markers,
          exitPose: sharpen.exitPose,
        );
      }
    }
    resources = AnimationResources(
      rigs: rigs.values,
      frames: frames.values,
      clips: clips.values,
      poses: defaults.poses.values,
    );
    definitions = {
      for (final id in resources.clips.keys)
        id.value: AnimationDefinition.fromResources(resources, id),
      for (final entry
          in (overrides ?? <String, AnimationDefinition>{}).entries)
        entry.key: AnimationDefinition._adapt(entry.value, resources),
    };
  }
  late final AnimationResources resources;
  late final Map<String, AnimationDefinition> definitions;
  AnimationDefinition get(String id) =>
      definitions[id] ?? AnimationDefinition(id: id);
}
