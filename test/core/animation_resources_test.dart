import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/animation_resources.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/animation/sprite_frame.dart';
import 'package:idle_companion/core/animation/sprite_rig.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';

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
  test('resource lookups reject every unknown typed ID', () {
    final catalog = defaultAnimationResources();
    expect(() => catalog.clip(const ClipId('unknown')), throwsArgumentError);
    expect(() => catalog.frame(const FrameId('unknown')), throwsArgumentError);
    expect(() => catalog.rig(const RigId('unknown')), throwsArgumentError);
    expect(() => catalog.pose(const PoseId('unknown')), throwsArgumentError);
  });

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

  test('seated pose is one shared resource without playback timing', () {
    final resources = defaultAnimationResources();
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
}
