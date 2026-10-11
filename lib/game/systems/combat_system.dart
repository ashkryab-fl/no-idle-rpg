import 'dart:math';
import '../../core/animation/animation_clip.dart';
import '../../core/animation/attack_playback.dart';
import '../../core/numbers/amount.dart';
import '../../domain/character/character.dart';
import '../../domain/adventure/stage_attempt.dart';

class DamageEvent {
  const DamageEvent({
    required this.fromHero,
    required this.amount,
    required this.critical,
    this.timeWithinStep = 0,
    this.preventedCritBonus = Amount.zero,
  });
  final bool fromHero, critical;
  final Amount amount, preventedCritBonus;
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
    TalentEffects? effects,
    bool isBoss = false,
  }) {
    final critical = random.nextDouble() < stats.critChance;
    final protection = effects?['crit_protection'] ?? 0;
    final factor = critical
        ? fromHero
              ? stats.critDamage
              : 1 + (stats.critDamage - 1) * (1 - protection)
        : 1.0;
    return DamageEvent(
      preventedCritBonus: !fromHero && critical
          ? stats.damage.scale((stats.critDamage - 1) * protection)
          : Amount.zero,
      fromHero: fromHero,
      amount: stats.damage.scale(
        multiplier *
            factor *
            (fromHero && isBoss ? 1 + (effects?['boss_damage'] ?? 0) : 1),
      ),
      critical: critical,
      timeWithinStep: timeWithinStep,
    );
  }

  Iterable<DamageEvent> update(
    double dt,
    CombatStats hero,
    CombatStats enemy,
    double multiplier, {
    TalentEffects? effects,
    bool isBoss = false,
  }) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    final markers = <(CombatStats, bool, double)>[];
    for (final item in [(heroClock, hero, true), (enemyClock, enemy, false)]) {
      for (final marker in item.$1.advance(dt, 1 / item.$2.attackSpeed)) {
        if (marker.marker.kind == AnimationMarkerKind.damage) {
          markers.add((item.$2, item.$3, marker.timeWithinStep));
        }
      }
    }
    markers.sort((a, b) {
      final order = a.$3 - b.$3;
      if (order.abs() > 1e-12) return order < 0 ? -1 : 1;
      return a.$2 == b.$2
          ? 0
          : a.$2
          ? -1
          : 1;
    });
    // Roll in chronological order, only for hits the caller consumes before a
    // lethal boundary. Cache each roll so rereading the returned events is safe.
    final rolls = [
      for (final marker in markers)
        () {
          DamageEvent? cached;
          return () => cached ??= calculate(
            marker.$1,
            marker.$2,
            multiplier: marker.$2 ? multiplier : 1,
            timeWithinStep: marker.$3,
            effects: effects,
            isBoss: isBoss,
          );
        }(),
    ];
    return rolls.map((roll) => roll());
  }
}
