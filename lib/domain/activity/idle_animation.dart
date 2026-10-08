import 'dart:math';
import '../../core/assets/animation_catalog.dart';
import '../../core/balance/game_balance.dart';

enum IdleLevel { active, level1, level2, level3 }

class IdleAnimationDefinition {
  const IdleAnimationDefinition({
    required this.id,
    required this.requiredIdleLevel,
    this.weight = 1,
    this.nextAnimationId,
    this.nextAnimationIds = const [],
    this.canInterrupt = true,
    this.minLoops = 1,
    this.maxLoops = 1,
    this.cooldown = 0,
    this.holdLastFrame = 0,
    this.loopUntilActivity = false,
  });
  final String id;
  final IdleLevel requiredIdleLevel;
  final double weight, cooldown, holdLastFrame;
  final String? nextAnimationId;
  final List<String> nextAnimationIds;
  final bool canInterrupt, loopUntilActivity;
  final int minLoops, maxLoops;
  List<String> get continuations => [?nextAnimationId, ...nextAnimationIds];
}

abstract final class IdleAnimationCatalog {
  // Add seated activities to this root's continuations. Child weights control
  // the random choice; children never enter the lottery before sitting down.
  static const definitions = [
    IdleAnimationDefinition(
      id: 'hero.sitDown',
      requiredIdleLevel: IdleLevel.level1,
      nextAnimationIds: ['hero.sharpen'],
      canInterrupt: false,
      holdLastFrame: .5,
    ),
    IdleAnimationDefinition(
      id: 'hero.sharpen',
      requiredIdleLevel: IdleLevel.level1,
      loopUntilActivity: true,
    ),
  ];
}

/// Chooses one rest animation or chain at a time, once an encounter is over.
class IdleBehaviorSystem {
  IdleBehaviorSystem(
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
  String? get animationId => caughtRemaining > 0 ? 'hero.caught' : current?.id;
  bool get blocksAdventure => level != IdleLevel.active || animationId != null;
  double get animationElapsed {
    if (caughtRemaining > 0) {
      return animations.get('hero.caught').duration - caughtRemaining;
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
  }

  void setIdleSeconds(double seconds) {
    level = levelFor(seconds);
  }

  void update(double dt, {bool canRest = true}) {
    _clock += dt;
    // Keep tracking user inactivity, but finish combat/death/rewards first.
    if (!canRest) return;
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
    current = null;
    _elapsed = 0;
    caughtRemaining = animations.get('hero.caught').duration;
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
