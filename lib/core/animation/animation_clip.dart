import 'dart:math';
import 'ids.dart';

class ClipFrameDefinition {
  const ClipFrameDefinition(this.frameId, this.duration);
  final FrameId frameId;
  final double duration;
}

/// Start inclusive, end exclusive. Frames before start are a one-time intro.
class AnimationLoopRange {
  const AnimationLoopRange(this.start, this.end);
  final int start, end;
}

enum AnimationMarkerKind { damage, cue }

class AnimationMarker {
  const AnimationMarker({
    required this.id,
    required this.time,
    this.kind = AnimationMarkerKind.cue,
  });
  final String id;
  final double time;
  final AnimationMarkerKind kind;
}

/// Exact poses name shared resources; families describe compatible geometry.
class AnimationPoseContract {
  const AnimationPoseContract.pose(PoseId value) : pose = value, family = null;
  const AnimationPoseContract.family(PoseFamilyId value)
    : family = value,
      pose = null;
  final PoseId? pose;
  final PoseFamilyId? family;
}

class AnimationClipDefinition {
  AnimationClipDefinition({
    required this.id,
    required List<ClipFrameDefinition> frames,
    this.loopRange,
    List<AnimationMarker> markers = const [],
    this.entryPose,
    this.exitPose,
  }) : frames = List.unmodifiable(frames),
       markers = List.unmodifiable(markers) {
    validateAnimationId(id.value);
    if (frames.isEmpty ||
        frames.any(
          (f) =>
              f.frameId.value.trim().isEmpty ||
              !f.duration.isFinite ||
              f.duration <= 0,
        )) {
      throw ArgumentError('Invalid clip frames: ${id.value}');
    }
    final starts = <double>[0];
    for (final frame in frames) {
      final end = starts.last + frame.duration;
      if (!end.isFinite || end <= starts.last) {
        throw ArgumentError('Unrepresentable clip duration: ${id.value}');
      }
      starts.add(end);
    }
    _boundaries = List.unmodifiable(starts);
    if (!duration.isFinite ||
        (loopRange != null &&
            (loopRange!.start < 0 ||
                loopRange!.start >= loopRange!.end ||
                loopRange!.end > frames.length))) {
      throw ArgumentError('Invalid clip timeline: ${id.value}');
    }
    final markerIds = <String>{};
    for (final marker in markers) {
      if (marker.id.trim().isEmpty ||
          !markerIds.add(marker.id) ||
          !marker.time.isFinite ||
          marker.time < 0 ||
          marker.time > firstPassDuration) {
        throw ArgumentError('Invalid clip marker: ${id.value}/${marker.id}');
      }
    }
  }

  final ClipId id;
  final List<ClipFrameDefinition> frames;
  final AnimationLoopRange? loopRange;
  final List<AnimationMarker> markers;
  final AnimationPoseContract? entryPose, exitPose;
  late final List<double> _boundaries;
  double get duration => _boundaries.last;
  double frameStart(int index) => _boundaries[index];
  double get loopStartTime => frameStart(loopRange?.start ?? 0);
  double get firstPassDuration => frameStart(loopRange?.end ?? frames.length);
  double get loopDuration => firstPassDuration - loopStartTime;

  // Only absorb arithmetic round-off at boundaries, including partitioned dt.
  late final double tolerance = min(
    1e-10,
    frames.map((frame) => frame.duration).reduce(min) * 1e-8,
  );
  double timelineElapsed(double elapsed) {
    if (!elapsed.isFinite || elapsed < 0) {
      throw ArgumentError.value(elapsed, 'elapsed');
    }
    if (loopRange == null) return elapsed.clamp(0, duration);
    if (elapsed < firstPassDuration - tolerance) return elapsed;
    var offset = (elapsed - firstPassDuration) % loopDuration;
    if (offset < tolerance || loopDuration - offset < tolerance) offset = 0;
    return loopStartTime + offset;
  }

  int frameIndex(double elapsed) {
    final time = timelineElapsed(elapsed);
    final end = loopRange?.end ?? frames.length;
    // Upper-bound lookup works for unequal frame durations as well as FPS.
    var low = 0, high = end;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_boundaries[mid + 1] <= time + tolerance) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, end - 1);
  }

  int loopCount(double elapsed) {
    if (!elapsed.isFinite || elapsed < 0) {
      throw ArgumentError.value(elapsed, 'elapsed');
    }
    if (loopRange == null || elapsed < firstPassDuration - tolerance) return 0;
    return 1 +
        ((elapsed - firstPassDuration + tolerance) / loopDuration).floor();
  }
}
