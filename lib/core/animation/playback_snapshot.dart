import 'animation_resources.dart';
import 'animation_player.dart';
import 'graph/graph_runner.dart';
import 'ids.dart';
import 'sprite_frame.dart';
import 'sprite_rig.dart';

/// Explicit Canvas poses for procedural content or declared debug resources.
enum ProceduralPose { standing, moving, striking, fallen }

/// A resolved, immutable rendering instruction. Reading it never advances time.
final class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.clipId,
    required this.elapsed,
    required this.duration,
    required this.displayLabel,
    required this.generation,
    this.frame,
    this.rig,
    this.frameIndex,
    this.graphId,
    this.nodeId,
    this.poseId,
    this.loopCount = 0,
    this.completed = false,
    this.lastTransition,
    this.proceduralPose = ProceduralPose.standing,
    this.damageFlash = false,
    this.fadeFromFrame,
    this.fadeFromRig,
    this.fadeProgress = 1,
  });
  final ClipId? clipId;
  final SpriteFrameDefinition? frame;
  final SpriteRigDefinition? rig;
  final SpriteFrameDefinition? fadeFromFrame;
  final SpriteRigDefinition? fadeFromRig;
  final double fadeProgress;
  FrameId? get frameId => frame?.id;
  final int? frameIndex;
  final GraphId? graphId;
  final NodeId? nodeId;
  final PoseId? poseId;
  final int generation, loopCount;
  final double elapsed, duration;
  final bool completed, damageFlash;
  final String displayLabel;
  final GraphTransitionEvent? lastTransition;
  final ProceduralPose proceduralPose;

  factory PlaybackSnapshot.atClip(
    AnimationResources resources,
    ClipId id,
    double elapsed, {
    required int generation,
    required String displayLabel,
    ProceduralPose pose = ProceduralPose.standing,
  }) {
    final clip = resources.clip(id);
    return PlaybackSnapshot.clip(
      AnimationPlaybackSnapshot(
        clipId: id,
        frameId: clip.frames[clip.frameIndex(elapsed)].frameId,
        frameIndex: clip.frameIndex(elapsed),
        elapsed: elapsed,
        timelineElapsed: clip.timelineElapsed(elapsed),
        loopCount: clip.loopCount(elapsed),
        completed: clip.loopRange == null && elapsed >= clip.duration,
      ),
      resources,
      generation: generation,
      displayLabel: displayLabel,
      pose: pose,
    );
  }

  factory PlaybackSnapshot.clip(
    AnimationPlaybackSnapshot state,
    AnimationResources resources, {
    required int generation,
    required String displayLabel,
    ProceduralPose pose = ProceduralPose.standing,
  }) {
    final frame = resources.frame(state.frameId);
    return PlaybackSnapshot(
      clipId: state.clipId,
      frame: frame,
      rig: resources.rig(frame.rigId),
      frameIndex: state.frameIndex,
      elapsed: state.elapsed,
      duration: resources.clip(state.clipId).duration,
      loopCount: state.loopCount,
      completed: state.completed,
      displayLabel: displayLabel,
      generation: generation,
      proceduralPose: pose,
    );
  }

  factory PlaybackSnapshot.graph(
    GraphPlaybackSnapshot state,
    AnimationResources resources, {
    required int generation,
    required String displayLabel,
  }) {
    final frame = state.frameId == null
        ? null
        : resources.frame(state.frameId!);
    final from = state.fadeFromFrameId == null
        ? null
        : resources.frame(state.fadeFromFrameId!);
    return PlaybackSnapshot(
      clipId: state.clipId,
      frame: frame,
      rig: frame == null ? null : resources.rig(frame.rigId),
      fadeFromFrame: from,
      fadeFromRig: from == null ? null : resources.rig(from.rigId),
      fadeProgress: state.fadeProgress,
      frameIndex: state.frameIndex,
      graphId: state.graphId,
      nodeId: state.nodeId,
      poseId: state.poseId,
      elapsed: state.nodeElapsed,
      duration: state.clipId == null
          ? 0
          : resources.clip(state.clipId!).duration,
      loopCount: state.loopCount,
      completed: state.status == GraphPlaybackStatus.completed,
      lastTransition: state.lastTransition,
      displayLabel: displayLabel,
      generation: generation,
    );
  }

  PlaybackSnapshot withDamageFlash(bool flash) => PlaybackSnapshot(
    clipId: clipId,
    frame: frame,
    rig: rig,
    frameIndex: frameIndex,
    graphId: graphId,
    nodeId: nodeId,
    poseId: poseId,
    elapsed: elapsed,
    duration: duration,
    loopCount: loopCount,
    completed: completed,
    lastTransition: lastTransition,
    displayLabel: displayLabel,
    generation: generation,
    proceduralPose: proceduralPose,
    damageFlash: flash,
    fadeFromFrame: fadeFromFrame,
    fadeFromRig: fadeFromRig,
    fadeProgress: fadeProgress,
  );
}
