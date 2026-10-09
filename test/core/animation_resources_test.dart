import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/animation_resources.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/animation/sprite_frame.dart';
import 'package:idle_companion/core/animation/sprite_rig.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';

const rig = SpriteRigDefinition(
  id: RigId('rig'),
  canvasWidth: 512,
  canvasHeight: 512,
);
const frame = SpriteFrameDefinition(
  id: FrameId('frame'),
  rigId: RigId('rig'),
  source: SpriteSourceRect(0, 0, 512, 512),
  asset: 'hero.png',
);
AnimationClipDefinition clip({
  FrameId frameId = const FrameId('frame'),
  AnimationPoseContract? entry,
}) => AnimationClipDefinition(
  id: const ClipId('clip'),
  frames: [ClipFrameDefinition(frameId, .2)],
  entryPose: entry,
);

void main() {
  test('IDs have distinct namespaces and stable value equality', () {
    expect(const ClipId('same'), const ClipId('same'));
    expect(const ClipId('same'), isNot(const PoseId('same')));
    expect(const GraphId('same'), isNot(const ClipId('same')));
    expect({
      const ClipId('same'),
      const PoseId('same'),
      const GraphId('same'),
    }, hasLength(3));
  });
  test(
    'resource lookups are strict while legacy fallback remains compatible',
    () {
      final catalog = AnimationCatalog();
      expect(
        () => catalog.resources.clip(const ClipId('unknown')),
        throwsArgumentError,
      );
      expect(
        () => catalog.resources.frame(const FrameId('unknown')),
        throwsArgumentError,
      );
      expect(
        () => catalog.resources.rig(const RigId('unknown')),
        throwsArgumentError,
      );
      expect(
        () => catalog.resources.pose(const PoseId('unknown')),
        throwsArgumentError,
      );
      expect(catalog.get('unknown').duration, .6);
      expect(catalog.get('unknown').frameDefinition(0).debugPlaceholder, true);
    },
  );

  test(
    'duplicates and unresolved frame, rig and pose references fail preparation',
    () {
      for (final create in <void Function()>[
        () => AnimationResources(
          rigs: [rig, rig],
          frames: [frame],
          clips: [clip()],
        ),
        () => AnimationResources(
          rigs: [rig],
          frames: [frame, frame],
          clips: [clip()],
        ),
        () => AnimationResources(
          rigs: [rig],
          frames: [frame],
          clips: [clip(), clip()],
        ),
        () => AnimationResources(rigs: [], frames: [frame], clips: [clip()]),
        () => AnimationResources(
          rigs: [rig],
          frames: [frame],
          clips: [clip(frameId: const FrameId('missing'))],
        ),
        () => AnimationResources(
          rigs: [rig],
          frames: [frame],
          clips: [
            clip(entry: const AnimationPoseContract.pose(PoseId('missing'))),
          ],
        ),
        () => AnimationResources(
          rigs: [rig],
          frames: [frame],
          clips: [clip()],
          poses: const [
            SpritePoseDefinition(
              id: PoseId('pose'),
              frameId: FrameId('missing'),
              family: PoseFamilyId.seated,
            ),
          ],
        ),
      ]) {
        expect(create, throwsArgumentError);
      }
    },
  );

  test(
    'invalid geometry, empty IDs and undeclared placeholders are rejected',
    () {
      for (final invalid in [
        const SpriteRigDefinition(
          id: RigId(''),
          canvasWidth: 1,
          canvasHeight: 1,
        ),
        const SpriteRigDefinition(
          id: RigId('x'),
          canvasWidth: double.nan,
          canvasHeight: 1,
        ),
        const SpriteRigDefinition(
          id: RigId('x'),
          canvasWidth: 1,
          canvasHeight: 1,
          worldUnitsPerPixel: 0,
        ),
      ]) {
        expect(invalid.validate, throwsArgumentError);
      }
      for (final invalid in [
        const SpriteFrameDefinition(
          id: FrameId(''),
          rigId: RigId('rig'),
          source: SpriteSourceRect(0, 0, 1, 1),
          asset: 'x',
        ),
        const SpriteFrameDefinition(
          id: FrameId('x'),
          rigId: RigId('rig'),
          source: SpriteSourceRect(-1, 0, 1, 1),
          asset: 'x',
        ),
        const SpriteFrameDefinition(
          id: FrameId('x'),
          rigId: RigId('rig'),
          source: SpriteSourceRect(0, 0, 1, 1),
          asset: '',
        ),
        const SpriteFrameDefinition(
          id: FrameId('x'),
          rigId: RigId('rig'),
          source: SpriteSourceRect(0, 0, 1, 1),
          asset: 'x',
          scaleMultiplier: double.infinity,
        ),
      ]) {
        expect(invalid.validate, throwsArgumentError);
      }
      const placeholder = SpriteFrameDefinition.debugPlaceholder(
        id: FrameId('x'),
        rigId: RigId('rig'),
        source: SpriteSourceRect(0, 0, 1, 1),
      );
      expect(placeholder.validate, returnsNormally);
    },
  );

  test('durations, loop ranges and markers are validated in pure Dart', () {
    for (final durations in [
      <double>[],
      [0.0],
      [-1.0],
      [double.nan],
      [double.infinity],
      [1e308, 1e308],
    ]) {
      expect(
        () => AnimationClipDefinition(
          id: const ClipId('x'),
          frames: [
            for (final d in durations)
              ClipFrameDefinition(const FrameId('frame'), d),
          ],
        ),
        throwsArgumentError,
      );
    }
    for (final range in [
      const AnimationLoopRange(-1, 1),
      const AnimationLoopRange(1, 1),
      const AnimationLoopRange(0, 2),
    ]) {
      expect(
        () => AnimationClipDefinition(
          id: const ClipId('x'),
          frames: const [ClipFrameDefinition(FrameId('frame'), .2)],
          loopRange: range,
        ),
        throwsArgumentError,
      );
    }
    for (final markers in [
      const [AnimationMarker(id: 'x', time: -.1)],
      const [AnimationMarker(id: 'x', time: .3)],
      const [AnimationMarker(id: 'x', time: double.nan)],
      const [AnimationMarker(id: '', time: .1)],
      const [
        AnimationMarker(id: 'x', time: .1),
        AnimationMarker(id: 'x', time: .2),
      ],
    ]) {
      expect(
        () => AnimationClipDefinition(
          id: const ClipId('x'),
          frames: const [ClipFrameDefinition(FrameId('frame'), .2)],
          markers: markers,
        ),
        throwsArgumentError,
      );
    }
  });

  test('prepared resource maps and timeline lists cannot be mutated', () {
    final input = [const ClipFrameDefinition(FrameId('frame'), .2)];
    final definition = AnimationClipDefinition(
      id: const ClipId('clip'),
      frames: input,
    );
    input.clear();
    expect(definition.frames, hasLength(1));
    final resources = AnimationResources(
      rigs: [rig],
      frames: [frame],
      clips: [definition],
    );
    expect(() => resources.frames.clear(), throwsUnsupportedError);
    expect(() => definition.frames.clear(), throwsUnsupportedError);
    expect(() => definition.markers.clear(), throwsUnsupportedError);
  });

  test('seated pose is one shared resource without playback timing', () {
    final resources = AnimationCatalog().resources;
    final pose = resources.pose(PoseId.seatedNeutral);
    final sit = resources.clip(const ClipId('hero.sitDown'));
    final seated = resources.clip(const ClipId('hero.seated'));
    final sharpen = resources.clip(const ClipId('hero.sharpen'));
    expect([
      sit.frames.last.frameId,
      seated.frames.single.frameId,
      sharpen.frames.first.frameId,
    ], everyElement(pose.frameId));
    expect(
      identical(
        resources.frame(sit.frames.last.frameId),
        resources.frame(sharpen.frames.first.frameId),
      ),
      true,
    );
    expect(sit.exitPose!.pose, PoseId.seatedNeutral);
    expect(sharpen.entryPose!.pose, PoseId.seatedNeutral);
    expect(resources.frame(pose.frameId).scaleMultiplier, 1.05);
  });

  test(
    'one-frame sit-down overrides preserve metadata and final-frame correction',
    () {
      final catalog = AnimationCatalog({
        'hero.sitDown': const AnimationDefinition(
          id: 'hero.sitDown',
          scaleMultiplier: 2,
        ),
      });
      final sit = catalog.get('hero.sitDown');
      expect(sit.scaleMultiplier, 2);
      expect(sit.frameDefinition(0).scaleMultiplier, 1.05);
      expect(sit.frameRig(0).canvasWidth, 128);
      expect(sit.frameRig(0).worldUnitsPerPixel, .55);
    },
  );

  test(
    'unrepresentable durations and unreachable loop markers fail preparation',
    () {
      expect(
        () => AnimationClipDefinition(
          id: const ClipId('x'),
          frames: const [
            ClipFrameDefinition(FrameId('frame'), 1e20),
            ClipFrameDefinition(FrameId('frame'), 1e-12),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => AnimationClipDefinition(
          id: const ClipId('x'),
          frames: const [
            ClipFrameDefinition(FrameId('frame'), .1),
            ClipFrameDefinition(FrameId('frame'), .2),
          ],
          loopRange: const AnimationLoopRange(0, 1),
          markers: const [AnimationMarker(id: 'unreachable', time: .2)],
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'legacy overrides keep sit-down canvas and only borrow seated multiplier',
    () {
      final catalog = AnimationCatalog({
        'hero.seated': const AnimationDefinition(
          id: 'hero.seated',
          scaleMultiplier: 1.2,
        ),
      });
      final sit = catalog.get('hero.sitDown');
      expect(sit.frameRig(3).canvasWidth, 512);
      expect(sit.frameRig(3).anchorY, .875);
      expect(sit.frameRig(3).worldUnitsPerPixel, .25);
      expect(sit.frameDefinition(3).scaleMultiplier, 1.2);
      final sharpen = catalog.get('hero.sharpen');
      expect(sharpen.frameRig(0).canvasWidth, 512);
      expect(sharpen.frameDefinition(0).scaleMultiplier, 1.05);
    },
  );
}
