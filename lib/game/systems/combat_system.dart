import 'dart:math';
import '../../core/assets/animation_catalog.dart';
import '../../core/numbers/amount.dart';
import '../../domain/character/character.dart';

class DamageEvent {
  const DamageEvent({
    required this.fromHero,
    required this.amount,
    required this.critical,
    this.timeWithinStep = 0,
  });
  final bool fromHero, critical;
  final Amount amount;
  final double timeWithinStep;
}

/// Time within the current attack cycle, rather than time since combat began.
/// A speed change preserves cycle progress without replaying historic hits.
class AttackClock {
  double elapsed = 0;
  double? period;
  bool damageEmitted = false;
  void reset() {
    elapsed = 0;
    period = null;
    damageEmitted = false;
  }

  double elapsedFor(double nextPeriod) =>
      period == null ? elapsed : elapsed * nextPeriod / period!;
  void setPeriod(double nextPeriod) {
    elapsed = elapsedFor(nextPeriod);
    period = nextPeriod;
  }
}

class CombatSystem {
  CombatSystem(this.random, this.animations);
  final Random random;
  final AnimationCatalog animations;
  final heroClock = AttackClock(), enemyClock = AttackClock();
  void reset() {
    heroClock.reset();
    enemyClock.reset();
  }

  DamageEvent calculate(
    CombatStats stats,
    bool fromHero, {
    double multiplier = 1,
    double timeWithinStep = 0,
  }) {
    final critical = random.nextDouble() < stats.critChance;
    return DamageEvent(
      fromHero: fromHero,
      amount: stats.damage.scale(
        multiplier * (critical ? stats.critDamage : 1),
      ),
      critical: critical,
      timeWithinStep: timeWithinStep,
    );
  }

  double cycleDuration(CombatStats stats, String prefix) =>
      1 / stats.attackSpeed;
  double attackElapsed(bool hero, CombatStats stats, String prefix) {
    final period = cycleDuration(stats, prefix);
    return (hero ? heroClock : enemyClock).elapsedFor(period) *
        max(1, animations.get('$prefix.attack').duration / period);
  }

  bool attacking(bool hero, CombatStats stats, String prefix) =>
      attackElapsed(hero, stats, prefix) <
      animations.get('$prefix.attack').duration;
  List<DamageEvent> update(
    double dt,
    CombatStats hero,
    CombatStats enemy,
    String enemyPrefix,
    double multiplier,
  ) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    final events = <DamageEvent>[];
    for (final item in [
      (heroClock, hero, 'hero', true),
      (enemyClock, enemy, enemyPrefix, false),
    ]) {
      final definition = animations.get('${item.$3}.attack');
      final period = cycleDuration(item.$2, item.$3);
      if (!period.isFinite || period <= 0) {
        throw ArgumentError('Attack speed must be positive and finite');
      }
      final hitTime =
          (definition.damageEventTime ?? 0) *
          min(1, period / definition.duration);
      final clock = item.$1..setPeriod(period);
      var remaining = dt, consumed = 0.0;
      while (remaining > 1e-12) {
        final boundary = clock.damageEmitted ? period : hitTime;
        final toBoundary = max(0.0, boundary - clock.elapsed);
        if (toBoundary > remaining + 1e-12) {
          clock.elapsed += remaining;
          break;
        }
        remaining = max(0.0, remaining - toBoundary);
        consumed += toBoundary;
        clock.elapsed = boundary;
        if (!clock.damageEmitted) {
          clock.damageEmitted = true;
          events.add(
            calculate(
              item.$2,
              item.$4,
              multiplier: item.$4 ? multiplier : 1,
              timeWithinStep: consumed,
            ),
          );
        } else {
          clock.elapsed = 0;
          clock.damageEmitted = false;
        }
      }
    }
    events.sort((a, b) {
      final order = a.timeWithinStep - b.timeWithinStep;
      if (order.abs() > 1e-12) return order < 0 ? -1 : 1;
      return a.fromHero == b.fromHero
          ? 0
          : a.fromHero
          ? -1
          : 1;
    });
    return events;
  }
}
