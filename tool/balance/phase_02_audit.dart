import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'simulate_progression.dart';
import 'phase_02_profiles.dart';

void main(List<String> args) {
  final seeds = args.isEmpty ? 20 : int.parse(args.first);
  const checkpoints = [.5, 1.0, 3.0, 7.0, 49.0, 210.0];
  final policies = <String, (InvestmentStrategy, double)>{
    'affordable_balanced': (InvestmentStrategy.balanced, 0),
    'hourly_balanced': (InvestmentStrategy.balanced, 3600),
    'adaptive': (InvestmentStrategy.adaptive, 0),
    'five_minute_balanced': (InvestmentStrategy.balanced, 300),
    'no_purchases': (InvestmentStrategy.noPurchases, double.infinity),
    'weapon_only': (InvestmentStrategy.weaponOnly, 0),
    'armor_only': (InvestmentStrategy.armorOnly, 0),
    'helmet_only': (InvestmentStrategy.helmetOnly, 0),
    'amulet_only': (InvestmentStrategy.amuletOnly, 0),
    'omit_weapon': (InvestmentStrategy.omitWeapon, 0),
    'omit_armor': (InvestmentStrategy.omitArmor, 0),
    'omit_helmet': (InvestmentStrategy.omitHelmet, 0),
    'omit_amulet': (InvestmentStrategy.omitAmulet, 0),
  };
  final rows = <Map<String, Object?>>[];
  final runs = <(EquipmentCurveProfile, String, IncomeStress)>[];
  for (final profile in isolatedProfiles) {
    for (final name
        in profile == EquipmentCurveProfile.candidate
            ? policies.keys
            : ['affordable_balanced', 'hourly_balanced', 'adaptive']) {
      runs.add((profile, name, const IncomeStress()));
    }
  }
  for (final bonus in [.25, .5, .75]) {
    for (final source in ['kills', 'stage', 'first_clear']) {
      runs.add((
        EquipmentCurveProfile.candidate,
        'adaptive',
        IncomeStress(
          id: '${source}_${(bonus * 100).round()}',
          killGoldMultiplier: source == 'kills' ? 1 + bonus : 1,
          stageGoldBonus: source == 'stage' ? bonus : 0,
          firstClearGoldBonus: source == 'first_clear' ? bonus : 0,
        ),
      ));
    }
  }
  for (final factor in [.75, .5]) {
    runs.add((
      EquipmentCurveProfile.candidate,
      'adaptive',
      IncomeStress(id: 'travel_$factor', travelFactor: factor),
    ));
  }
  const sensitivity = [
    EquipmentCurveProfile(
      id: 'amulet_threshold_2_5',
      multiplier: MultiplierCurve(threshold: 100),
    ),
    EquipmentCurveProfile(
      id: 'amulet_threshold_4',
      multiplier: MultiplierCurve(threshold: 250),
    ),
    EquipmentCurveProfile(
      id: 'amulet_short_tail',
      multiplier: MultiplierCurve(width: 100, tailScale: 1),
    ),
    EquipmentCurveProfile(
      id: 'amulet_long_tail',
      multiplier: MultiplierCurve(width: 300, tailScale: 3),
    ),
    EquipmentCurveProfile(
      id: 'power_N50',
      weapon: PowerCurve(threshold: 50),
      armor: PowerCurve(threshold: 50),
    ),
    EquipmentCurveProfile(
      id: 'power_N200',
      weapon: PowerCurve(threshold: 200),
      armor: PowerCurve(threshold: 200),
    ),
    EquipmentCurveProfile(
      id: 'power_W100',
      weapon: PowerCurve(width: 100),
      armor: PowerCurve(width: 100),
    ),
    EquipmentCurveProfile(
      id: 'power_W400',
      weapon: PowerCurve(width: 400),
      armor: PowerCurve(width: 400),
    ),
    EquipmentCurveProfile(
      id: 'power_r075',
      weapon: PowerCurve(tailRate: .75),
      armor: PowerCurve(tailRate: .75),
    ),
    EquipmentCurveProfile(id: 'chance_epsilon_1e6', minimumChanceGain: 1e-6),
  ];
  for (final profile in sensitivity) {
    runs.add((profile, 'adaptive', const IncomeStress()));
  }
  for (final (profile, policy, income) in runs) {
    for (var seed = 1; seed <= seeds; seed++) {
      final selection = policies[policy]!;
      final sim = ProgressionSimulation(
        seed: seed,
        curveProfile: profile,
        income: income,
        strategy: selection.$1,
        upgradeInterval: selection.$2,
      );
      for (final hours in checkpoints) {
        sim.runUntil(hours * 3600);
        rows.add({
          'policy': policy,
          'seed': seed,
          'hours': hours,
          ...sim.snapshot((hours / 7).floor()),
        });
      }
    }
    stderr.writeln('${profile.id}/$policy/${income.id}: $seeds seeds');
  }
  final summary = <Map<String, Object?>>[];
  for (final (profile, policy, income) in runs) {
    for (final hours in checkpoints) {
      final selected = rows
          .where(
            (r) =>
                r['profile'] == profile.id &&
                r['policy'] == policy &&
                r['income'] == income.id &&
                r['hours'] == hours,
          )
          .toList();
      final metrics = <String, Object>{};
      for (final key in selected.first.keys) {
        if (['seed', 'hours', 'day'].contains(key)) continue;
        final amount =
            key.endsWith('Log') &&
            selected.every((r) => r[key] == null || r[key] is String);
        if (!amount && !selected.every((r) => r[key] is num)) continue;
        final values = selected
            .map(
              (r) => amount
                  ? Amount.fromJson(r[key]).toDouble()
                  : (r[key] as num).toDouble(),
            )
            .toList();
        metrics[amount ? key.substring(0, key.length - 3) : key] = {
          'p05': ProgressionSimulation.percentile(values, .05),
          'p50': ProgressionSimulation.median(values),
          'p90': ProgressionSimulation.percentile(values, .9),
          'p95': ProgressionSimulation.percentile(values, .95),
          'min': values.reduce(math.min),
          'max': values.reduce(math.max),
        };
      }
      summary.add({
        'profile': profile.id,
        'policy': policy,
        'income': income.id,
        'hours': hours,
        'metrics': metrics,
      });
    }
  }
  stdout.writeln(
    jsonEncode({
      'date': '2026-10-11',
      'seeds': seeds,
      'hoursPerDay': 7,
      'checkpoints': checkpoints,
      'time': 'productive; no restart, rest or offline rewards',
      'booksIncome':
          'unchanged random per-kill diagnostic source; booksSpent=0',
      'profiles': {for (final (p, _, _) in runs) p.id: p.toJson()},
      'incomeInputs': {for (final (_, _, i) in runs) i.id: i.toJson()},
      'stageStressBasis':
          'bonus fraction of unmodified boss kill Gold on each clear; first-clear only once per stage, not a multiplier of all kills',
      'window':
          'last 200 completed encounters, independently sampled victories/HP/purchase intervals; last 20 first-entry durations',
      'rows': rows,
      'summary': summary,
    }),
  );
}
