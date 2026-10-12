part of 'clips.dart';

const _heroAssetRoot = 'assets/characters/hero/';

final class _HeroClipBuilder {
  final rigs = <RigId, SpriteRigDefinition>{};
  final frames = <FrameId, SpriteFrameDefinition>{};
  final clips = <ClipId, AnimationClipDefinition>{};

  void add(AnimationResources resources) {
    rigs.addAll(resources.rigs);
    frames.addAll(resources.frames);
    clips.addAll(resources.clips);
  }

  void contract(
    String id, {
    AnimationPoseContract? entry,
    AnimationPoseContract? exit,
    int? sharedFrame,
  }) {
    final key = ClipId(id);
    final clip = clips[key]!;
    clips[key] = AnimationClipDefinition(
      id: key,
      frames: [
        for (var i = 0; i < clip.frames.length; i++)
          ClipFrameDefinition(
            i == sharedFrame ? HeroPoses.seatedFrame : clip.frames[i].frameId,
            clip.frames[i].duration,
          ),
      ],
      loopRange: clip.loopRange,
      markers: clip.markers,
      entryPose: entry,
      exitPose: exit,
    );
  }

  AnimationResources build() => AnimationResources(
    rigs: rigs.values,
    frames: frames.values,
    clips: clips.values,
    poses: HeroPoses.definitions,
  );
}
