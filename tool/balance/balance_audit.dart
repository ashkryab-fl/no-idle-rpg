import 'dart:convert';
import 'dart:io';

import 'package:idle_companion/core/balance/progression_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';
import 'simulate_progression.dart';

/// Compact diagnostics for the active Gold-only equipment profile.
void main(List<String> args) {
  final seeds = args.isEmpty ? 20 : int.parse(args.first);
  final scenarios = <String, (InvestmentStrategy, double)>{
    'no_purchases': (InvestmentStrategy.noPurchases, double.infinity),
    'affordable_balanced': (InvestmentStrategy.balanced, 0),
    'five_minute_balanced': (InvestmentStrategy.balanced, 300),
    'hourly_balanced': (InvestmentStrategy.balanced, 3600),
    'weapon_only': (InvestmentStrategy.weaponOnly, 0),
    'armor_only': (InvestmentStrategy.armorOnly, 0),
  };
  const hours = [.5, 1.0, 3.0, 7.0, 49.0, 210.0];
  final rows = <Map<String, Object?>>[];
  for (final scenario in scenarios.entries) {
    for (var seed = 1; seed <= seeds; seed++) {
      final sim = ProgressionSimulation(
        seed: seed,
        strategy: scenario.value.$1,
        upgradeInterval: scenario.value.$2,
      );
      for (final hour in hours) {
        sim.runUntil(hour * 3600);
        rows.add({
          'scenario': scenario.key,
          'seed': seed,
          'hours': hour,
          ...sim.snapshot((hour / 7).floor()),
        });
      }
    }
    stderr.writeln('${scenario.key}: $seeds seeds complete');
  }
  final summary = <Map<String, Object?>>[];
  for (final scenario in scenarios.keys) {
    for (final hour in hours) {
      final selected = rows
          .where((r) => r['scenario'] == scenario && r['hours'] == hour)
          .toList();
      final metrics = <String, Object>{};
      for (final key in selected.first.keys) {
        if (['scenario', 'seed', 'day', 'hours'].contains(key)) continue;
        final magnitude =
            key.endsWith('Log') &&
            selected.every((r) => r[key] == null || r[key] is String);
        if (magnitude || selected.every((r) => r[key] is num)) {
          final values = selected.map(
            (r) => magnitude
                ? Amount.fromJson(r[key]).toDouble()
                : (r[key] as num).toDouble(),
          );
          final metricKey = magnitude ? key.substring(0, key.length - 3) : key;
          metrics[metricKey] = {
            'p50': ProgressionSimulation.median(values),
            'p90': ProgressionSimulation.percentile(values, .9),
            'p95': ProgressionSimulation.percentile(values, .95),
            'min': values.reduce((a, b) => a < b ? a : b),
            'max': values.reduce((a, b) => a > b ? a : b),
          };
        }
      }
      summary.add({'scenario': scenario, 'hours': hour, 'metrics': metrics});
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'date': '2026-10-11',
      'model': 'phase_02_equipment_only',
      'seeds': seeds,
      'hoursPerDay': 7,
      'checkpointsProductiveHours': hours,
      'method':
          'Continuous event simulation per seed, no restart/rest; reward confirmed after death animation. Gold-only equipment using the active curve profile; Books remain unspent. Affordable policies check shares after every encounter; focus policies buy one registered equipment item.',
      'sampleWindow':
          'Last 200 completed outcomes/normal kills/boss kills/purchases independently; first clear durations last 20. TTK includes only victories. Between-seed summaries of window statistics.',
      'coefficients': {
        'heroHp': ProgressionBalance.heroHp,
        'heroDamage': ProgressionBalance.heroDamage,
        'hpGrowth': ProgressionBalance.hpGrowth,
        'damageGrowth': ProgressionBalance.damageGrowth,
        'goldGrowth': ProgressionBalance.goldRewardGrowth,
        'bookGrowth': ProgressionBalance.bookRewardGrowth,
        'equipmentCostGrowth': ProgressionBalance.equipmentCostGrowth,
        'upgradeGrowth': ProgressionBalance.upgradeGrowth,
        'enemiesPerStage': ProgressionBalance.enemiesPerStage,
        'bossMultiplier': ProgressionBalance.bossStatMultiplier,
        'critCap': ProgressionBalance.critChanceCap,
      },
      'rows': rows,
      'summary': summary,
      'stageExamples': [
        for (final stage in [1, 10, 25, 50, 100])
          {
            'stage': stage,
            'hpLog': EnemyFactory()
                .create(EnemyCatalog.definitions.single, stage - 1)
                .stats
                .maxHp
                .toJson(),
            'damageLog': EnemyFactory()
                .create(EnemyCatalog.definitions.single, stage - 1)
                .stats
                .damage
                .toJson(),
            'goldLog': EnemyFactory()
                .create(EnemyCatalog.definitions.single, stage - 1)
                .gold
                .toJson(),
            'booksIfDropLog': EnemyFactory()
                .create(EnemyCatalog.definitions.single, stage - 1)
                .books
                .toJson(),
          },
      ],
    }),
  );
}
