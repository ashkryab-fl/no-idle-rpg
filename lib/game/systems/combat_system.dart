import 'dart:math';
import '../../core/animation/animation_clip.dart';
import '../../core/animation/attack_playback.dart';
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

class CombatSystem {
  CombatSystem(
    this.random, {
    required AttackPlayback heroPlayback,
    required AttackPlayback enemyPlayback,
  }) : heroClock = heroPlayback,
       enemyClock = enemyPlayback;
  final Random random;
  final AttackPlayback heroClock, enemyClock;
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

  List<DamageEvent> update(
    double dt,
    CombatStats hero,
    CombatStats enemy,
    double multiplier,
  ) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    final events = <DamageEvent>[];
    for (final item in [(heroClock, hero, true), (enemyClock, enemy, false)]) {
      for (final marker in item.$1.advance(dt, 1 / item.$2.attackSpeed)) {
        if (marker.marker.kind != AnimationMarkerKind.damage) continue;
        events.add(
          calculate(
            item.$2,
            item.$3,
            multiplier: item.$3 ? multiplier : 1,
            timeWithinStep: marker.timeWithinStep,
          ),
        );
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
