import '../../core/animation/animation_player.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/animation/attack_playback.dart';
import '../../core/animation/ids.dart';
import '../../core/animation/playback_snapshot.dart';
import '../../domain/activity/idle_level.dart';
import '../../domain/activity/rest_coordinator.dart';
import '../../content/animations/hero/clips.dart';
import '../../core/animation/graph/node.dart';
import '../../content/animations/hero/debug_previews.dart';
import 'hero_animation_preview.dart';

enum HeroAnimationRequest { travel, approach, combat, idle, death, respawn }

/// Game priority/channel owner. Simulation requests a semantic mode; the
/// renderer only reads this coordinator's resolved frame and overlay snapshot.
final class HeroAnimationCoordinator {
  HeroAnimationCoordinator(this.resources, {required this.rest})
    : combatPlayback = AttackPlayback(
        resources.clip(const ClipId('hero.attack')),
      ),
      _player = AnimationPlayer(resources.clip(const ClipId('hero.walk')));
  final AnimationResources resources;
  final RestCoordinator rest;
  final AttackPlayback combatPlayback;
  final AnimationPlayer _player;
  HeroAnimationPreviewPlayback? _preview;
  HeroAnimationPreview? get preview => _preview?.selection;
  bool get isPreviewing => _preview != null;
  bool get canWakePreview => _preview?.canWake ?? false;

  void startPreview(HeroAnimationPreview selection) {
    final playback = HeroAnimationPreviewPlayback(selection, resources);
    _preview = playback;
    _generation++;
  }

  void stopPreview() {
    if (_preview == null) return;
    _preview = null;
    _generation++;
  }

  void wakePreview() => _preview?.wake();
  HeroAnimationRequest _request = HeroAnimationRequest.travel;
  bool _restWasBlocking = false;
  int _generation = 0;
  int _restReturnRevision = 0;

  /// Changes once when a played rest graph finishes returning to work.
  int get restReturnRevision => _restReturnRevision;
  double _clock = 0;
  double combatPeriod = 1;
  late final bool _restUsesWalkSeam = rest.graph.nodes.values.any(
    (node) =>
        (node is PlayClip && node.clipId == HeroClips.phoneEnter) ||
        node is FadePose,
  );
  bool get blocksAdventure => rest.blocksAdventure;
  bool get deathCompleted => _player.completed;

  void synchronize(HeroAnimationRequest request) {
    if (request == _request) return;
    final previous = _request;
    _request = request;
    _generation++;
    switch (request) {
      case HeroAnimationRequest.death:
        rest.cancelPlayback();
        _restWasBlocking = false;
        combatPlayback.reset();
        _player.play(resources.clip(const ClipId('hero.death')));
      case HeroAnimationRequest.respawn:
        if (previous != HeroAnimationRequest.death) {
          _player.play(resources.clip(const ClipId('hero.death')));
          _player.advance(_player.clip.duration);
        }
      case HeroAnimationRequest.combat:
        combatPlayback.reset();
      case HeroAnimationRequest.travel || HeroAnimationRequest.approach:
        if (previous != HeroAnimationRequest.travel &&
            previous != HeroAnimationRequest.approach) {
          _player.play(resources.clip(const ClipId('hero.walk')));
        }
      case HeroAnimationRequest.idle:
        _player.play(resources.clip(const ClipId('hero.idle')));
    }
  }

  /// Returns travel time after rest/exit consumes its part of this update.
  /// Combat is advanced exactly once by CombatSystem on the shared playback.
  double advance(double dt) {
    if (!dt.isFinite || dt < 0 || !(_clock + dt).isFinite) {
      throw ArgumentError.value(dt, 'dt');
    }
    if (_preview != null) {
      _preview!.advance(dt);
      return 0;
    }
    final start = _clock;
    _clock += dt;
    if (_request == HeroAnimationRequest.travel) {
      final wasBlocking = rest.blocksAdventure || _restWasBlocking;
      if (!_restWasBlocking && rest.blocksAdventure) _generation++;
      var restTime = dt;
      var restStart = start;
      if (_restUsesWalkSeam &&
          rest.blocksAdventure &&
          rest.level != IdleLevel.active &&
          rest.graphRunner?.isRunning != true) {
        final walk = _player.clip;
        final lastStart = walk.frameStart(walk.frames.length - 1);
        final untilLast = lastStart - _player.snapshot.timelineElapsed;
        if (untilLast > walk.tolerance) {
          final settling = restTime < untilLast ? restTime : untilLast;
          _player.advance(settling);
          rest.advance(settling, canRest: false, startTime: restStart);
          restTime -= settling;
          restStart += settling;
          if (restTime == 0) {
            _restWasBlocking = true;
            return 0;
          }
        }
      }
      var remaining = rest.advance(restTime, startTime: restStart);
      // Finish standing up before new inactivity starts another entry.
      if (remaining > 0 &&
          rest.level != IdleLevel.active &&
          rest.graphRunner?.isCompleted == true) {
        remaining = rest.advance(remaining, startTime: _clock - remaining);
      }
      _restWasBlocking = rest.blocksAdventure;
      if (!rest.blocksAdventure) {
        if (wasBlocking) {
          if (rest.graphRunner?.isCompleted == true) _restReturnRevision++;
          _generation++;
          _player.play(resources.clip(const ClipId('hero.walk')));
        }
        _player.advance(remaining);
        return remaining;
      }
      return 0;
    }
    rest.advance(dt, canRest: false, startTime: start);
    if (_request == HeroAnimationRequest.combat) return 0;
    final result = _player.advance(dt);
    return _request == HeroAnimationRequest.approach ? dt : result.remaining;
  }

  PlaybackSnapshot get snapshot {
    if (_preview != null) return _preview!.snapshot(_generation);
    if (_request == HeroAnimationRequest.travel && rest.blocksAdventure) {
      final graph = rest.graphRunner;
      if (graph != null && graph.isRunning) {
        return PlaybackSnapshot.graph(
          graph.snapshot,
          resources,
          generation: _generation,
          displayLabel: graph.snapshot.graphId.value,
        );
      }
      if (_restUsesWalkSeam) {
        return PlaybackSnapshot.clip(
          _player.snapshot,
          resources,
          generation: _generation,
          displayLabel: _player.clip.id.value,
          pose: ProceduralPose.moving,
        );
      }
      // Inactivity may be sampled before the first simulation tick. Resolve
      // the explicit guard resource until the runner enters its initial node.
      return PlaybackSnapshot.atClip(
        resources,
        const ClipId('hero.idle'),
        0,
        generation: _generation,
        displayLabel: 'hero.idle',
      );
    }
    if (_request == HeroAnimationRequest.combat) {
      final attacking = combatPlayback.attacking(combatPeriod);
      final id = attacking ? combatPlayback.clip.id : const ClipId('hero.idle');
      final elapsed = attacking
          ? combatPlayback.clipElapsed(combatPeriod)
          : 0.0;
      return PlaybackSnapshot.atClip(
        resources,
        id,
        elapsed,
        generation: _generation,
        displayLabel: id.value,
        pose: attacking ? ProceduralPose.striking : ProceduralPose.standing,
      );
    }
    return PlaybackSnapshot.clip(
      _player.snapshot,
      resources,
      generation: _generation,
      displayLabel: _player.clip.id.value,
      pose: switch (_request) {
        HeroAnimationRequest.death ||
        HeroAnimationRequest.respawn => ProceduralPose.fallen,
        HeroAnimationRequest.travel ||
        HeroAnimationRequest.approach => ProceduralPose.moving,
        _ => ProceduralPose.standing,
      },
    );
  }

  void reset() {
    stopPreview();
    rest.cancelPlayback();
    combatPlayback.reset();
    _generation++;
    _clock = 0;
    _restWasBlocking = false;
    _request = HeroAnimationRequest.travel;
    _player.play(resources.clip(const ClipId('hero.walk')));
  }
}
