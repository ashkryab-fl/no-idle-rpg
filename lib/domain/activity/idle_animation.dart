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
    this.canInterrupt = true,
    this.minLoops = 1,
    this.maxLoops = 1,
    this.cooldown = 0,
  });
  final String id;
  final IdleLevel requiredIdleLevel;
  final double weight, cooldown;
  final String? nextAnimationId;
  final bool canInterrupt;
  final int minLoops, maxLoops;
}

abstract final class IdleAnimationCatalog {
  // Placeholder IDs: add standalone nodes or complete chains here, then supply
  // their sprite metadata in AnimationCatalog. Only roots enter the lottery.
  static const definitions = [
    IdleAnimationDefinition(
      id: 'hero.a1',
      requiredIdleLevel: IdleLevel.level1,
      nextAnimationId: 'hero.a2',
      canInterrupt: false,
    ),
    IdleAnimationDefinition(
      id: 'hero.a2',
      requiredIdleLevel: IdleLevel.level1,
      nextAnimationId: 'hero.a3',
      canInterrupt: false,
    ),
    IdleAnimationDefinition(id: 'hero.a3', requiredIdleLevel: IdleLevel.level1),
    IdleAnimationDefinition(
      id: 'hero.b',
      requiredIdleLevel: IdleLevel.level1,
      minLoops: 1,
      maxLoops: 3,
      cooldown: 3,
    ),
    IdleAnimationDefinition(
      id: 'hero.c',
      requiredIdleLevel: IdleLevel.level2,
      maxLoops: 2,
    ),
    IdleAnimationDefinition(
      id: 'hero.d',
      requiredIdleLevel: IdleLevel.level3,
      minLoops: 2,
      maxLoops: 4,
      canInterrupt: false,
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
          (d.nextAnimationId != null &&
              !_byId.containsKey(d.nextAnimationId))) {
        throw ArgumentError('Invalid idle graph node: ${d.id}');
      }
      final visited = <String>{};
      IdleAnimationDefinition? node = d;
      while (node != null) {
        if (!visited.add(node.id)) {
          throw ArgumentError('Idle chain cycle at ${node.id}');
        }
        node = _byId[node.nextAnimationId];
      }
    }
    _roots = definitions
        .where((d) => !definitions.any((node) => node.nextAnimationId == d.id))
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
  double get animationElapsed => caughtRemaining > 0
      ? animations.get('hero.caught').duration - caughtRemaining
      : _elapsed;
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
    final next = current!.nextAnimationId;
    if (level == IdleLevel.active) {
      _caught();
    } else if (next != null) {
      _start(_byId[next]!);
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
    _duration =
        animations.get(d.id).duration *
        (d.minLoops + random.nextInt(d.maxLoops - d.minLoops + 1));
  }

  void _choose() {
    final choices = _roots
        .where(
          (d) =>
              d.requiredIdleLevel.index <= level.index &&
              _clock - (_lastPlayed[d.id] ?? -double.infinity) >= d.cooldown,
        )
        .toList();
    if (choices.isEmpty) return;
    var roll =
        random.nextDouble() *
        choices.fold<double>(0, (sum, d) => sum + d.weight);
    for (final d in choices) {
      roll -= d.weight;
      if (roll <= 0) {
        _start(d);
        return;
      }
    }
    _start(choices.last);
  }
}
