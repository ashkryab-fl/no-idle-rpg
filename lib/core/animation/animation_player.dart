import 'dart:math';
import 'animation_clip.dart';
import 'ids.dart';

class AnimationMarkerEvent {
  const AnimationMarkerEvent({
    required this.clipId,
    required this.marker,
    required this.elapsed,
    required this.timeWithinStep,
    required this.loopCount,
  });
  final ClipId clipId;
  final AnimationMarker marker;
  final double elapsed, timeWithinStep;
  final int loopCount;
}

class AnimationPlaybackSnapshot {
  const AnimationPlaybackSnapshot({
    required this.clipId,
    required this.frameId,
    required this.frameIndex,
    required this.elapsed,
    required this.timelineElapsed,
    required this.loopCount,
    required this.completed,
  });
  final ClipId clipId;
  final FrameId frameId;
  final int frameIndex, loopCount;
  final double elapsed, timelineElapsed;
  final bool completed;
}

class AnimationAdvanceResult {
  AnimationAdvanceResult({
    required this.consumed,
    required this.remaining,
    required this.completedNow,
    required List<AnimationMarkerEvent> events,
  }) : events = List.unmodifiable(events);
  final double consumed, remaining;
  final bool completedNow;
  final List<AnimationMarkerEvent> events;
}

/// A local clock only. Game priorities, holds and finite repeats belong to the
/// graph runner. One-shots hold their last frame and return unspent dt.
class AnimationPlayer {
  AnimationPlayer(AnimationClipDefinition clip) : _clip = clip;
  AnimationClipDefinition _clip;
  double _elapsed = 0;
  final Map<String, int> _nextMarkerOccurrence = {};
  AnimationClipDefinition get clip => _clip;
  double get elapsed => _elapsed;
  bool get completed => _clip.loopRange == null && _elapsed >= _clip.duration;
  AnimationPlaybackSnapshot get snapshot {
    final index = clip.frameIndex(_elapsed);
    return AnimationPlaybackSnapshot(
      clipId: clip.id,
      frameId: clip.frames[index].frameId,
      frameIndex: index,
      elapsed: _elapsed,
      timelineElapsed: clip.timelineElapsed(_elapsed),
      loopCount: clip.loopCount(_elapsed),
      completed: completed,
    );
  }

  void play(AnimationClipDefinition clip) {
    _clip = clip;
    _elapsed = 0;
    _nextMarkerOccurrence.clear();
  }

  void reset() => play(_clip);

  AnimationAdvanceResult advance(double dt) {
    if (!dt.isFinite || dt < 0 || !(_elapsed + dt).isFinite) {
      throw ArgumentError.value(dt, 'dt');
    }
    if (dt == 0 || completed) {
      return AnimationAdvanceResult(
        consumed: 0,
        remaining: dt,
        completedNow: false,
        events: const [],
      );
    }
    final before = _elapsed;
    final target = clip.loopRange == null
        ? min(before + dt, clip.duration)
        : before + dt;
    // Snap round-off when a partitioned update completes a one-shot.
    _elapsed = clip.loopRange == null && clip.duration - target < clip.tolerance
        ? clip.duration
        : target;
    final events = <AnimationMarkerEvent>[];
    void emit(AnimationMarker marker, double time, int cycle) {
      events.add(
        AnimationMarkerEvent(
          clipId: clip.id,
          marker: marker,
          elapsed: time,
          timeWithinStep: (time - before).clamp(0, dt),
          loopCount: cycle,
        ),
      );
    }

    for (final marker in clip.markers) {
      var next = _nextMarkerOccurrence[marker.id] ?? 0;
      if (next == 0) {
        if (marker.time > _elapsed + clip.tolerance) continue;
        emit(marker, marker.time, 0);
        _nextMarkerOccurrence[marker.id] = next = 1;
      }
      final range = clip.loopRange;
      if (range == null ||
          marker.time < clip.loopStartTime ||
          marker.time > clip.firstPassDuration) {
        continue;
      }
      final first = clip.firstPassDuration + marker.time - clip.loopStartTime;
      final epsilon = clip.tolerance;
      final firstCycle = next - 1;
      final lastCycle = ((_elapsed + epsilon - first) / clip.loopDuration)
          .floor();
      for (var cycle = firstCycle; cycle <= lastCycle; cycle++) {
        emit(marker, first + cycle * clip.loopDuration, cycle + 1);
        _nextMarkerOccurrence[marker.id] = cycle + 2;
      }
    }
    events.sort((a, b) {
      final order = a.elapsed.compareTo(b.elapsed);
      return order != 0
          ? order
          : clip.markers
                .indexOf(a.marker)
                .compareTo(clip.markers.indexOf(b.marker));
    });
    final consumed = min(dt, _elapsed - before);
    return AnimationAdvanceResult(
      consumed: consumed,
      remaining: max(0, dt - consumed),
      completedNow: completed,
      events: events,
    );
  }
}
