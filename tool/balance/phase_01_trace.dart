import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:idle_companion/core/numbers/amount.dart';
import 'simulate_progression.dart';

class _ConstantRandom implements Random {
  _ConstantRandom(this.roll);
  final double roll;
  @override
  double nextDouble() => roll;
  @override
  int nextInt(int max) => (roll * max).floor();
  @override
  bool nextBool() => roll < .5;
}

void main() {
  final rows = <Map<String, Object?>>[];
  for (final (name, roll, hp, wave) in [
    ('no_crit', .99, 50.0, 1),
    ('crit', 0.0, 120.0, 1),
    ('death_and_respawn', .99, 1.0, 1),
    ('boss_clear', .99, 120.0, 5),
    ('hp_purchase_between_encounters', .99, 50.0, 1),
  ]) {
    final encounters = <Map<String, Object?>>[],
        recovery = <Map<String, Object?>>[];
    final sim =
        ProgressionSimulation(
            random: _ConstantRandom(roll),
            strategy: name == 'hp_purchase_between_encounters'
                ? InvestmentStrategy.armorOnly
                : InvestmentStrategy.noPurchases,
            upgradeInterval: double.infinity,
            onEncounter: encounters.add,
            onRecovery: recovery.add,
          )
          ..hp = Amount.fromNum(hp)
          ..stageKills = wave - 1;
    // Current HP is a scripted fixture; it is not a recovery event.
    while (encounters.isEmpty) {
      sim.runUntil(sim.elapsed + .01);
    }
    if (name == 'death_and_respawn') {
      while (sim.hp.isZero) {
        sim.runUntil(sim.elapsed + .01);
      }
    }
    if (name == 'hp_purchase_between_encounters') {
      sim.hero.gold = Amount.fromNum(20);
      sim.invest();
    }
    rows.add({
      'scenario': name,
      'scriptedInitialHp': hp,
      'randomRoll': roll,
      'encounters': encounters,
      'healthRecovery': recovery,
      'final': sim.snapshot(0),
    });
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({'rows': rows}));
}
