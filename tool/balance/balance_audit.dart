import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:idle_companion/core/balance/progression_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/progression/infinite_upgrade.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';

import 'simulate_progression.dart';

// Read-only balance report. Uses the current event model and domain catalogs;
// no save files, runtime settings or gameplay coefficients are changed.
Map<String, Object> detailedSnapshot(ProgressionSimulation sim, int day) {
  final hero = sim.hero;
  final stats = sim.stats;
  Amount spent(
    List<InfiniteUpgradeDefinition> catalog,
    Map<String, int> levels,
  ) {
    return catalog.fold(
      Amount.zero,
      (sum, item) => sum + item.batchCost(0, levels[item.id] ?? 0),
    );
  }

  final goldSpent = spent(EquipmentCatalog.items, hero.equipment);
  final booksSpent = spent(UpgradeCatalog.character, hero.upgrades);
  final xpCurve = InfiniteUpgradeDefinition(
    id: 'xp',
    name: 'XP',
    stat: CharacterStat.damage,
    baseCost: ProgressionBalance.baseXp,
    costGrowth: ProgressionBalance.xpGrowth,
  );
  final enemy = EnemyFactory().create(
    EnemyCatalog.definitions.single,
    sim.stage - 1,
  );
  return {
    ...sim.snapshot(day),
    'hours': day * 8,
    'wave': sim.stageKills + 1,
    'maxHp': stats.maxHp.toDouble(),
    'currentHp': sim.hp.toDouble(),
    'damage': stats.damage.toDouble(),
    'dps': stats.dps.toDouble(),
    'critChance': stats.critChance,
    'critDamage': stats.critDamage,
    'xpRemaining': hero.xp.toDouble(),
    'xpRequired': sim.progression.xpRequired(hero.level).toDouble(),
    'xpEarned': (xpCurve.batchCost(0, hero.level - 1) + hero.xp).toDouble(),
    'goldRemaining': hero.gold.toDouble(),
    'booksRemaining': hero.books.toDouble(),
    'goldSpent': goldSpent.toDouble(),
    'booksSpent': booksSpent.toDouble(),
    'goldEarned': (goldSpent + hero.gold).toDouble(),
    'booksEarned': (booksSpent + hero.books).toDouble(),
    for (final item in EquipmentCatalog.items)
      'equipment_${item.id}': hero.equipment[item.id] ?? 0,
    for (final item in UpgradeCatalog.character)
      'upgrade_${item.id}': hero.upgrades[item.id] ?? 0,
    'enemyHp': enemy.stats.maxHp.toDouble(),
    'enemyDamage': enemy.stats.damage.toDouble(),
    'enemyGold': enemy.gold.toDouble(),
    'enemyBookDrop': enemy.books.toDouble(),
    'enemyXp': enemy.xp.toDouble(),
  };
}

void main(List<String> args) {
  final seeds = args.isEmpty ? 20 : int.parse(args.first);
  final rows = <Map<String, Object>>[];
  for (final scenario in ['hourly_balanced', 'no_purchases']) {
    for (var seed = 1; seed <= seeds; seed++) {
      for (final day in [1, 2, 7, 30]) {
        final sim = ProgressionSimulation(
          seed: seed,
          upgradeInterval: scenario == 'no_purchases' ? double.infinity : 3600,
        );
        sim.runUntil(day * 8 * 3600);
        final before = ProgressionSimulation(
          seed: seed,
          upgradeInterval: scenario == 'no_purchases' ? double.infinity : 3600,
        );
        before.runUntil((day * 8 - 1) * 3600);
        rows.add({
          'scenario': scenario,
          'seed': seed,
          ...detailedSnapshot(sim, day),
          'lastHourKills': sim.kills - before.kills,
          'lastHourDeaths': sim.deaths - before.deaths,
          'lastHourNetStages': sim.stage - before.stage,
          'lastHourNewHighestStages':
              (sim.snapshot(day)['highestStage'] as int) -
              (before.snapshot(day)['highestStage'] as int),
        });
      }
      stderr.writeln('$scenario seed $seed/$seeds');
    }
  }
  final summary = <Map<String, Object>>[];
  for (final scenario in ['hourly_balanced', 'no_purchases']) {
    for (final day in [1, 2, 7, 30]) {
      final selected = rows.where(
        (r) => r['scenario'] == scenario && r['day'] == day,
      );
      final metrics = <String, Object>{};
      for (final key in selected.first.keys) {
        if (['scenario', 'seed', 'day'].contains(key)) continue;
        final values = selected.map((r) => (r[key] as num).toDouble()).toList();
        metrics[key] = {
          'median': ProgressionSimulation.median(values),
          'min': values.reduce(min),
          'max': values.reduce(max),
        };
      }
      summary.add({'scenario': scenario, 'day': day, 'metrics': metrics});
    }
  }
  final stageExamples = <Map<String, Object>>[];
  for (final stage in [1, 10, 25, 50, 100, 217, 552, 2215, 5087]) {
    final enemy = EnemyFactory().create(
      EnemyCatalog.definitions.single,
      stage - 1,
    );
    stageExamples.add({
      'stage': stage,
      'hp': enemy.stats.maxHp.toDouble(),
      'damage': enemy.stats.damage.toDouble(),
      'gold': enemy.gold.toDouble(),
      'booksIfDrop': enemy.books.toDouble(),
      'expectedBooks': enemy.books
          .scale(enemy.definition.rewardBookChance)
          .toDouble(),
      'xp': enemy.xp.toDouble(),
    });
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'date': '2026-10-10',
      'hoursPerDay': 8,
      'seeds': seeds,
      'checkpoints': [1, 2, 7, 30],
      'method':
          'Current ProgressionSimulation event model; independent restart at each checkpoint.',
      'rows': rows,
      'summary': summary,
      'stageExamples': stageExamples,
    }),
  );
}
