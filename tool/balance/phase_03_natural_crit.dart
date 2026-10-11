import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/core/numbers/amount.dart';
import 'simulate_progression.dart';

/// Counterfactuals replay actual incoming hits at the same pre-hit HP, without
/// protection. This measures immediate lethal hits averted, not an optimal policy.
void main(List<String> args) {
  final summaries = <Map<String, Object?>>[],
      examples = <Map<String, Object?>>[];
  for (var seed = 1; seed <= 20; seed++) {
    var averted = 0,
        bossAverted = 0,
        victoriesWithAverted = 0,
        encounters = 0,
        critHits = 0;
    final simulation = ProgressionSimulation(
      seed: seed,
      strategy: InvestmentStrategy.adaptive,
      upgradeInterval: 0,
      talentPolicy: 'protection',
      onEncounter: (trace) {
        encounters++;
        var hp = Amount.fromJson(trace['hpBeforeLog']);
        var saved = false;
        for (final hit in trace['hits'] as List) {
          if (hit['hero'] == true) continue;
          final amount = Amount.fromJson(hit['amountLog']);
          final prevented = Amount.fromJson(hit['preventedCritBonusLog']);
          if (hit['critical'] == true) critHits++;
          if (!prevented.isZero && hp > amount && hp <= amount + prevented) {
            averted++;
            if (trace['boss'] == true) bossAverted++;
            saved = true;
            if (examples.length < 20 && trace['victory'] == true) {
              examples.add({
                'seed': seed,
                'preHitHP': hp.toDouble(),
                'protectedDamage': amount.toDouble(),
                'unprotectedDamage': (amount + prevented).toDouble(),
                'trace': trace,
              });
            }
          }
          hp = hp - amount;
        }
        if (saved && trace['victory'] == true) victoriesWithAverted++;
      },
    );
    for (final hours in [7.0, 49.0, 210.0]) {
      simulation.runUntil(hours * 3600);
      summaries.add({
        'seed': seed,
        'hours': hours,
        'encounters': encounters,
        'criticalHits': critHits,
        'immediateLethalHitsAverted': averted,
        'bossLethalHitsAverted': bossAverted,
        'victoriesWithAvertedHit': victoriesWithAverted,
        'highestStage': simulation.snapshot(0)['highestStage'],
      });
    }
    stderr.writeln('Natural crit seed $seed completed');
  }
  stdout.writeln(
    jsonEncode({
      'profile': 'phase02 enemy unchanged: chance .03, multiplier 1.5',
      'method':
          'Real funded protection policy, no crafted 100%-crit enemies. Subtract recorded incoming hits from actual pre-encounter HP. Compare each protected critical hit with its original damage at identical pre-hit HP. Immediate counterfactual, not a claim about whole alternate timelines.',
      'rows': summaries,
      'naturalExamples': examples,
    }),
  );
}
