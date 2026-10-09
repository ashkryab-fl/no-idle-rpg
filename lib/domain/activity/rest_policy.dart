import 'dart:math';
import '../../core/animation/graph/selection_policy.dart';
import '../../core/animation/ids.dart';
import '../../core/balance/game_balance.dart';
import 'idle_level.dart';
import 'weighted_variant_selector.dart';

/// Game eligibility and cooldowns live outside the universal runner.
final class RestPolicy implements GraphSelectionPolicy {
  RestPolicy(
    Random random, {
    List<double> thresholds = GameBalance.idleThresholds,
  }) : thresholds = List.unmodifiable(thresholds),
       selector = WeightedVariantSelector(random) {
    if (thresholds.length != IdleLevel.values.length - 1 ||
        thresholds.any((t) => !t.isFinite || t <= 0)) {
      throw ArgumentError('Invalid idle thresholds');
    }
    for (var i = 1; i < thresholds.length; i++) {
      if (thresholds[i] <= thresholds[i - 1]) {
        throw ArgumentError('Idle thresholds must increase');
      }
    }
  }
  static const idleLevelFact = GraphFactId('rest.idleLevel');
  final List<double> thresholds;
  final WeightedVariantSelector selector;
  final Map<CooldownKey, double> _cooldowns = {};

  IdleLevel levelFor(double seconds) {
    if (!seconds.isFinite || seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds');
    }
    for (var i = thresholds.length - 1; i >= 0; i--) {
      if (seconds >= thresholds[i]) return IdleLevel.values[i + 1];
    }
    return IdleLevel.active;
  }

  @override
  GraphChoice? choose(
    List<GraphChoice> choices,
    Map<GraphFactId, double> facts,
    double clock,
  ) => selector.choose([
    for (final choice in choices)
      if (isEligible(choice, facts, clock)) choice,
  ]);
  bool isEligible(
    GraphChoice choice,
    Map<GraphFactId, double> facts,
    double clock,
  ) =>
      choice.conditions.every((c) => c.matches(facts)) &&
      (choice.cooldown == null || clock >= _availableAt(choice.cooldown!));

  double _availableAt(VariantCooldown cooldown) =>
      (_cooldowns[cooldown.key] ?? -double.infinity) + cooldown.seconds;

  /// No RNG is consumed while checking a waiting Select's eligibility.
  double? nextEligibilityChange(
    List<GraphChoice> choices,
    Map<GraphFactId, double> facts,
    double clock,
  ) {
    double? next;
    for (final choice in choices) {
      if (!choice.conditions.every((c) => c.matches(facts))) continue;
      if (isEligible(choice, facts, clock)) return clock;
      final available = _availableAt(choice.cooldown!);
      next = next == null ? available : min(next, available);
    }
    return next;
  }

  @override
  void started(GraphChoice choice, double clock) {
    if (choice.cooldown?.start == CooldownStart.started) {
      _cooldowns[choice.cooldown!.key] = clock;
    }
  }

  @override
  void completed(GraphChoice choice, double clock) {
    if (choice.cooldown?.start == CooldownStart.completed) {
      _cooldowns[choice.cooldown!.key] = clock;
    }
  }

  void reset() => _cooldowns.clear();
}
