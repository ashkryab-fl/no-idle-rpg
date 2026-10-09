import 'animation_clip.dart';
import 'ids.dart';
import 'sprite_frame.dart';
import 'sprite_rig.dart';

/// Preparation-time validation; strict lookups never manufacture content.
class AnimationResources {
  AnimationResources({
    required Iterable<SpriteRigDefinition> rigs,
    required Iterable<SpriteFrameDefinition> frames,
    required Iterable<AnimationClipDefinition> clips,
    Iterable<SpritePoseDefinition> poses = const [],
  }) : rigs = _index(rigs, (r) => r.id, 'rig'),
       frames = _index(frames, (f) => f.id, 'frame'),
       clips = _index(clips, (c) => c.id, 'clip'),
       poses = _index(poses, (p) => p.id, 'pose') {
    for (final rig in this.rigs.values) {
      rig.validate();
    }
    for (final frame in this.frames.values) {
      frame.validate();
      rig(frame.rigId);
    }
    for (final pose in this.poses.values) {
      validateAnimationId(pose.id.value);
      validateAnimationId(pose.family.value);
      frame(pose.frameId);
    }
    for (final clip in this.clips.values) {
      for (final reference in clip.frames) {
        frame(reference.frameId);
      }
      for (final contract in [clip.entryPose, clip.exitPose]) {
        if (contract?.pose != null) {
          pose(contract!.pose!);
        }
        if (contract?.family != null) {
          validateAnimationId(contract!.family!.value);
        }
      }
    }
  }
  final Map<RigId, SpriteRigDefinition> rigs;
  final Map<FrameId, SpriteFrameDefinition> frames;
  final Map<ClipId, AnimationClipDefinition> clips;
  final Map<PoseId, SpritePoseDefinition> poses;

  SpriteRigDefinition rig(RigId id) => _get(rigs, id, 'rig');
  SpriteFrameDefinition frame(FrameId id) => _get(frames, id, 'frame');
  AnimationClipDefinition clip(ClipId id) => _get(clips, id, 'clip');
  SpritePoseDefinition pose(PoseId id) => _get(poses, id, 'pose');

  static T _get<K, T>(Map<K, T> map, K id, String kind) =>
      map[id] ?? (throw ArgumentError('Unknown animation $kind: $id'));
  static Map<K, T> _index<K, T>(
    Iterable<T> items,
    K Function(T) key,
    String kind,
  ) {
    final result = <K, T>{};
    for (final item in items) {
      final id = key(item);
      if (result.containsKey(id)) {
        throw ArgumentError('Duplicate animation $kind: $id');
      }
      result[id] = item;
    }
    return Map.unmodifiable(result);
  }
}
