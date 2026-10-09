import 'dart:math';
import '../../core/assets/animation_catalog.dart';
import '../../core/balance/game_balance.dart';
import 'idle_animation_definition.dart';
import 'idle_level.dart';

// Compatibility for injected legacy definitions, removed in stage 5.
/// Chooses one rest animation or chain at a time, once an encounter is over.
class LegacyIdleBehaviorSystem {
  LegacyIdleBehaviorSystem(
    this.random,
    this.animations, {
    this.definitions = IdleAnimationCatalog.definitions,
    this.thresholds = GameBalance.idleThresholds,
  }) {
    if (thresholds.length != IdleLevel.values.length - 1 ||
        thresholds.any((t) => !t.isFinite || t <= 0)) {
      throw ArgumentError('Invalid idle thresholds');
    }
    for (var i = 1; i < thresholds.length; i++) {
      if (thresholds[i] <= thresholds[i - 1]) {
        throw ArgumentError('Idle thresholds must increase');
      }
    }
    _byId = {for (final d in definitions) d.id: d};
    if (_byId.length != definitions.length) {
      throw ArgumentError('Duplicate idle animation ID');
    }
    for (final d in definitions) {
      if (d.id.isEmpty ||
          !animations.definitions.containsKey(d.id) ||
          d.requiredIdleLevel == IdleLevel.active ||
          !d.weight.isFinite ||
          d.weight <= 0 ||
          d.minLoops < 1 ||
          d.maxLoops < d.minLoops ||
          !d.cooldown.isFinite ||
          d.cooldown < 0 ||
          !d.holdLastFrame.isFinite ||
          d.holdLastFrame < 0 ||
          d.continuations.toSet().length != d.continuations.length ||
          d.continuations.any((id) => !_byId.containsKey(id)) ||
          d.exitAnimationIds.any(
            (id) => !animations.definitions.containsKey(id),
          ) ||
          (d.loopUntilActivity &&
              (!animations.get(d.id).loop ||
                  d.holdLastFrame > 0 ||
                  d.continuations.isNotEmpty))) {
        throw ArgumentError('Invalid idle graph node: ${d.id}');
      }
    }
    void visit(String id, Set<String> path) {
      if (!path.add(id)) {
        throw ArgumentError('Idle graph cycle at $id');
      }
      for (final next in _byId[id]!.continuations) {
        visit(next, path);
      }
      path.remove(id);
    }

    for (final d in definitions) {
      visit(d.id, <String>{});
    }
    _roots = definitions
        .where(
          (d) => !definitions.any((node) => node.continuations.contains(d.id)),
        )
        .toList();
  }
  final Random random;
  final AnimationCatalog animations;
  final List<IdleAnimationDefinition> definitions;
  final List<double> thresholds;
  late final Map<String, IdleAnimationDefinition> _byId;
  late final List<IdleAnimationDefinition> _roots;
  IdleLevel level = IdleLevel.active;
  IdleAnimationDefinition? current;
  final Map<String, double> _lastPlayed = {};
  double _elapsed = 0, _duration = 0, _clock = 0, caughtRemaining = 0;
  List<String> _exitAnimationIds = const [];
  int _exitIndex = 0;
  double _exitElapsed = 0;
  String? get _exitAnimationId => _exitIndex < _exitAnimationIds.length
      ? _exitAnimationIds[_exitIndex]
      : null;
  String? get animationId =>
      _exitAnimationId ?? (caughtRemaining > 0 ? 'hero.idle' : current?.id);
  bool get blocksAdventure => level != IdleLevel.active || animationId != null;
  double get animationElapsed {
    if (_exitAnimationId != null) return _exitElapsed;
    if (caughtRemaining > 0) {
      return GameBalance.caughtDuration - caughtRemaining;
    }
    final node = current;
    if (node != null) {
      final animation = animations.get(node.id);
      final playbackDuration = _duration - node.holdLastFrame;
      // Explicit finite repeats still work for a one-shot sprite. Once their
      // last cycle ends, the end hold must clamp instead of replaying it.
      if (!animation.loop &&
          playbackDuration > animation.duration &&
          _elapsed < playbackDuration) {
        return _elapsed % animation.duration;
      }
    }
    return _elapsed;
  }

  IdleLevel levelFor(double seconds) {
    for (var i = thresholds.length - 1; i >= 0; i--) {
      if (seconds >= thresholds[i]) {
        return IdleLevel.values[i + 1];
      }
    }
    return IdleLevel.active;
  }

  void reset() {
    level = IdleLevel.active;
    current = null;
    _lastPlayed.clear();
    _elapsed = 0;
    _duration = 0;
    _clock = 0;
    caughtRemaining = 0;
    _exitAnimationIds = const [];
    _exitIndex = 0;
    _exitElapsed = 0;
  }

  void setIdleSeconds(double seconds) {
    level = levelFor(seconds);
  }

  void cancelPlayback() {
    current = null;
    _elapsed = 0;
    _duration = 0;
    caughtRemaining = 0;
    _exitAnimationIds = const [];
    _exitIndex = 0;
    _exitElapsed = 0;
  }

  void update(double dt, {bool canRest = true}) {
    _clock += dt;
    // Keep tracking user inactivity, but finish combat/death/rewards first.
    if (!canRest) return;
    if (_exitAnimationId != null) {
      _exitElapsed += dt;
      while (_exitAnimationId != null) {
        final duration = animations.get(_exitAnimationId!).duration;
        if (_exitElapsed < duration) break;
        _exitElapsed -= duration;
        _exitIndex++;
      }
      return;
    }
    if (caughtRemaining > 0) {
      caughtRemaining = max(0, caughtRemaining - dt);
      return;
    }
    if (current != null && level == IdleLevel.active && current!.canInterrupt) {
      _caught();
      return;
    }
    if (current == null) {
      if (level != IdleLevel.active) _choose();
      return;
    }
    _elapsed += dt;
    if (_elapsed < _duration) return;
    if (level == IdleLevel.active) {
      _caught();
    } else if (current!.loopUntilActivity) {
      // Wrap only the active cycle, preserving any one-time entry frame. A
      // noninterruptible activity can then finish its current cycle on return.
      final animation = animations.get(current!.id);
      final intro = animation.loopStartFrame * animation.stepTime;
      _elapsed = intro + (_elapsed - intro) % (_duration - intro);
    } else if (current!.continuations.isNotEmpty) {
      final next = _pick([for (final id in current!.continuations) _byId[id]!]);
      if (next != null) {
        _start(next);
      } else {
        // Preserve the completed pose while child cooldowns/levels block them.
        _elapsed = _duration;
      }
    } else {
      current = null;
      _choose();
    }
  }

  void _caught() {
    _exitAnimationIds = current?.exitAnimationIds ?? const [];
    _exitIndex = 0;
    _exitElapsed = 0;
    current = null;
    _elapsed = 0;
    caughtRemaining = _exitAnimationIds.isEmpty
        ? GameBalance.caughtDuration
        : 0;
  }

  void _start(IdleAnimationDefinition d) {
    current = d;
    _elapsed = 0;
    _lastPlayed[d.id] = _clock;
    final animation = animations.get(d.id);
    final loops = d.minLoops + random.nextInt(d.maxLoops - d.minLoops + 1);
    final cycle =
        (animation.frames - animation.loopStartFrame) * animation.stepTime;
    _duration = animation.duration + cycle * (loops - 1) + d.holdLastFrame;
  }

  void _choose() {
    final choice = _pick(_roots);
    if (choice != null) _start(choice);
  }

  IdleAnimationDefinition? _pick(List<IdleAnimationDefinition> candidates) {
    final choices = candidates
        .where(
          (d) =>
              d.requiredIdleLevel.index <= level.index &&
              _clock - (_lastPlayed[d.id] ?? -double.infinity) >= d.cooldown,
        )
        .toList();
    if (choices.isEmpty) return null;
    var roll =
        random.nextDouble() *
        choices.fold<double>(0, (sum, d) => sum + d.weight);
    for (final d in choices) {
      roll -= d.weight;
      if (roll <= 0) {
        return d;
      }
    }
    return choices.last;
  }
}
