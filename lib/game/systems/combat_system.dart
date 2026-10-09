import 'dart:math';
import '../../content/animations/enemies/procedural_timelines.dart';
import '../../core/animation/animation_clip.dart';
import '../../core/animation/attack_playback.dart';
import '../../core/animation/ids.dart';
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

class CombatSystem {
  CombatSystem(
    this.random,
    this.animations, {
    AttackPlayback? heroPlayback,
    AttackPlayback? enemyPlayback,
  }) : heroClock =
           heroPlayback ??
           AttackPlayback(
             animations.resources.clip(const ClipId('hero.attack')),
           ),
       enemyClock =
           enemyPlayback ?? AttackPlayback(ProceduralEnemyTimelines.attack);
  final Random random;
  final AnimationCatalog animations;
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

  double cycleDuration(CombatStats stats, String prefix) =>
      1 / stats.attackSpeed;
  double attackElapsed(bool hero, CombatStats stats, String prefix) =>
      (hero ? heroClock : enemyClock).clipElapsed(cycleDuration(stats, prefix));

  bool attacking(bool hero, CombatStats stats, String prefix) =>
      (hero ? heroClock : enemyClock).attacking(cycleDuration(stats, prefix));
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
      final clip =
          animations.resources.clips[ClipId('${item.$3}.attack')] ??
          ProceduralEnemyTimelines.attack;
      if (item.$1.clip != clip) item.$1.reset(clip: clip);
      for (final marker in item.$1.advance(
        dt,
        cycleDuration(item.$2, item.$3),
      )) {
        if (marker.marker.kind != AnimationMarkerKind.damage) continue;
        events.add(
          calculate(
            item.$2,
            item.$4,
            multiplier: item.$4 ? multiplier : 1,
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
