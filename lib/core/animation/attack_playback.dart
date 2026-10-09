import 'dart:math';
import 'animation_clip.dart';
import 'animation_player.dart';

/// The single attack-cycle clock used by both damage and rendering. The clip
/// is stretched only when the attack period is shorter; the rest is a guard.
/// Speed changes preserve cycle progress and already-emitted marker identities.
final class AttackPlayback {
  AttackPlayback(this.clip);
  AnimationClipDefinition clip;
  double elapsed = 0;
  double? period;
  final Set<String> _emitted = {};
  int cycles = 0;
  double elapsedFor(double nextPeriod) =>
      period == null ? elapsed : elapsed * nextPeriod / period!;
  void reset({AnimationClipDefinition? clip}) {
    if (clip != null) this.clip = clip;
    elapsed = 0;
    period = null;
    _emitted.clear();
    cycles = 0;
  }

  void setPeriod(double nextPeriod) {
    if (!nextPeriod.isFinite || nextPeriod <= 0) {
      throw ArgumentError('Attack period must be positive and finite');
    }
    elapsed = elapsedFor(nextPeriod);
    period = nextPeriod;
  }

  double clipElapsed(double nextPeriod) =>
      elapsedFor(nextPeriod) * max(1, clip.duration / nextPeriod);
  bool attacking(double nextPeriod) => clipElapsed(nextPeriod) < clip.duration;

  List<AnimationMarkerEvent> advance(double dt, double nextPeriod) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    setPeriod(nextPeriod);
    final rate = max(1, clip.duration / nextPeriod);
    final events = <AnimationMarkerEvent>[];
    var remaining = dt, consumed = 0.0;
    final ordered = [...clip.markers]..sort((a, b) => a.time.compareTo(b.time));
    while (remaining > 1e-12) {
      final pending = ordered
          .where((m) => !_emitted.contains(m.id))
          .firstOrNull;
      final boundary = pending == null ? nextPeriod : pending.time / rate;
      final delta = max(0.0, boundary - elapsed);
      if (delta > remaining + 1e-12) {
        elapsed += remaining;
        break;
      }
      remaining = max(0, remaining - delta);
      consumed += delta;
      // An overdue marker after retiming must not rewind the visible cursor.
      elapsed = max(elapsed, boundary);
      if (pending != null) {
        _emitted.add(pending.id);
        events.add(
          AnimationMarkerEvent(
            clipId: clip.id,
            marker: pending,
            elapsed: pending.time,
            timeWithinStep: consumed,
            loopCount: cycles,
          ),
        );
      } else {
        elapsed = 0;
        _emitted.clear();
        cycles++;
      }
    }
    return events;
  }
}
