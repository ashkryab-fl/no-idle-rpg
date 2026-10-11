import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:idle_companion/core/balance/talent_profile.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'simulate_progression.dart';

class Scenario {
  const Scenario(
    this.id, {
    this.choices = const [],
    this.policy = 'adaptive',
    this.profile = TalentProfile.candidate,
    this.rank,
    this.cadence = 300,
    this.goldStrategy = InvestmentStrategy.adaptive,
    this.duty = 1,
  });
  final String id, policy;
  final List<String> choices;
  final TalentProfile profile;
  final int? rank;
  final double cadence, duty;
  final InvestmentStrategy goldStrategy;
}

TalentProfile varied(String id, double maximum) {
  const p = TalentProfile.candidate;
  final c = TalentCurve(maximum: maximum);
  return TalentProfile(
    id: 'sensitivity_${id}_$maximum',
    bossDamage: id == 'boss_damage' ? c : p.bossDamage,
    firstClearGold: id == 'first_clear_gold' ? c : p.firstClearGold,
    stageHeal: id == 'stage_heal' ? c : p.stageHeal,
    critProtection: id == 'crit_protection' ? c : p.critProtection,
    shorterTravel: id == 'shorter_travel' ? c : p.shorterTravel,
    stageGold: id == 'stage_gold' ? c : p.stageGold,
  );
}

void main(List<String> args) {
  final index = args.indexOf('--seeds');
  final seeds = index < 0 ? 20 : int.parse(args[index + 1]);
  const hours = [.5, 1.0, 3.0, 7.0, 49.0, 210.0];
  var scenarios = <Scenario>[
    const Scenario('new_rewards_no_talents', policy: 'none'),
    const Scenario('matched_none', policy: 'none', rank: 3),
    const Scenario('contextual_adaptive', policy: 'contextual'),
    for (var mask = 0; mask < 8; mask++) ...[
      Scenario(
        'funded_combo_$mask',
        choices: [
          for (var pair = 0; pair < 3; pair++)
            TalentCatalog.items[2 * pair + ((mask >> pair) & 1)].id,
        ],
      ),
      Scenario(
        'matched_combo_$mask',
        choices: [
          for (var pair = 0; pair < 3; pair++)
            TalentCatalog.items[2 * pair + ((mask >> pair) & 1)].id,
        ],
        rank: 3,
      ),
    ],
    for (final policy in [
      'adaptive',
      'economy_first',
      'travel_first',
      'protection',
      'uniform',
      'wrong_first',
    ])
      Scenario(policy, policy: policy),
    const Scenario('boss_focus', choices: ['boss_damage']),
    const Scenario('heal_focus', choices: ['stage_heal']),
    const Scenario('protection_focus', choices: ['crit_protection']),
    const Scenario('adaptive_affordable', cadence: 0),
    const Scenario('adaptive_hourly', cadence: 3600),
    const Scenario(
      'balanced_equipment',
      goldStrategy: InvestmentStrategy.balanced,
    ),
    for (final strategy in [
      InvestmentStrategy.weaponOnly,
      InvestmentStrategy.armorOnly,
      InvestmentStrategy.helmetOnly,
      InvestmentStrategy.amuletOnly,
    ])
      Scenario('equipment_${strategy.name}', goldStrategy: strategy),
    for (final omitted in TalentCatalog.items)
      Scenario(
        'omit_${omitted.id}',
        policy: 'uniform',
        choices: [
          for (final d in TalentCatalog.items)
            if (d.id != omitted.id) d.id,
        ],
      ),
    for (final d in TalentCatalog.items) ...[
      Scenario('funded_only_${d.id}', choices: [d.id]),
      Scenario('matched_only_${d.id}', choices: [d.id], rank: 3),
      for (final maximum in switch (d.id) {
        'stage_heal' => [.1, .3],
        'crit_protection' => [.4, .8],
        'shorter_travel' => [.15, .35],
        _ => [.25, .75],
      })
        Scenario(
          'sensitivity_${d.id}_$maximum',
          choices: [d.id],
          profile: varied(d.id, maximum),
        ),
    ],
    for (final repeats in [0, 1, 2])
      for (final first in [2, 3, 5])
        Scenario(
          'books_first${first}_repeat$repeats',
          profile: TalentProfile(
            id: 'books_first${first}_repeat$repeats',
            firstBooks: first,
            repeatLimit: repeats,
          ),
        ),
    for (final duty in [.25, .5, .75]) Scenario('open_duty_$duty', duty: duty),
  ];
  final excludeIndex = args.indexOf('--exclude');
  if (excludeIndex >= 0) {
    scenarios = scenarios
        .where((s) => !args[excludeIndex + 1].split(',').contains(s.id))
        .toList();
  }
  final onlyIndex = args.indexOf('--only');
  if (onlyIndex >= 0) {
    scenarios = scenarios
        .where((s) => args[onlyIndex + 1].split(',').contains(s.id))
        .toList();
  }
  final rows = <Map<String, Object?>>[], timelines = <Map<String, Object?>>[];
  for (final scenario in scenarios) {
    stderr.writeln('Running ${scenario.id} ($seeds seeds)');
    for (var seed = 1; seed <= seeds; seed++) {
      final simulation = ProgressionSimulation(
        seed: seed,
        strategy: scenario.goldStrategy,
        upgradeInterval: 0,
        talentPolicy: scenario.policy,
        talentChoices: scenario.choices,
        talentProfile: scenario.profile,
        fixedOwnedRank: scenario.rank,
        talentInterval: scenario.cadence,
      );
      for (final h in hours) {
        if (scenario.duty < 1) {
          simulation.runDutyUntil(h * 3600, scenario.duty);
        } else {
          simulation.runUntil(h * 3600);
        }
        final row = simulation.snapshot((h / 7).floor())
          ..remove('talentTimeline');
        rows.add({
          'scenario': scenario.id,
          'seed': seed,
          'checkpointHours': h,
          'horizonClock': scenario.duty < 1 ? 'open' : 'productive',
          'matchedRanksUnfunded': scenario.rank != null,
          ...row,
        });
      }
      timelines.add({
        'scenario': scenario.id,
        'seed': seed,
        'purchases': simulation.talentTimeline,
        if (simulation.selectionTimeline.isNotEmpty)
          'selections': simulation.selectionTimeline,
      });
    }
  }
  double number(Map<String, Object?> row, String field) =>
      (row[field] as num?)?.toDouble() ?? 0;
  final summaries = <Map<String, Object?>>[];
  for (final scenario in scenarios) {
    for (final h in hours) {
      final group = rows
          .where(
            (r) => r['scenario'] == scenario.id && r['checkpointHours'] == h,
          )
          .toList();
      final summary = <String, Object?>{'scenario': scenario.id, 'hours': h};
      for (final field in [
        'highestStage',
        'firstClearFrontier',
        'stage',
        'deaths',
        'normalTtkP50',
        'bossTtkP50',
        'booksSpent',
        'critHits',
        'lethalCrits',
        'actualProductiveSeconds',
        'restSeconds',
        'savedTravelSeconds',
        'claimLedgerBytes',
      ]) {
        summary[field] = {
          for (final p in [.05, .5, .95])
            'p${(p * 100).round()}': ProgressionSimulation.percentile(
              group.map((r) => number(r, field)),
              p,
            ),
        };
      }
      summary['meanSources'] = {
        for (final source in [
          'killGold',
          'firstClearBaseGold',
          'firstClearBonusGold',
          'stageBonusGold',
          'firstBooks',
          'repeatBooks',
          'milestoneBooks',
        ])
          source:
              group.fold<double>(
                0,
                (sum, r) =>
                    sum +
                    ((r['rewardSources'] as Map)[source] as num? ?? 0)
                        .toDouble(),
              ) /
              seeds,
      };
      summaries.add(summary);
    }
  }
  final paired = <Map<String, Object?>>[];
  for (final scenario in scenarios.where(
    (s) =>
        s.id.startsWith('matched_only_') ||
        s.id.startsWith('funded_combo_') ||
        s.policy == 'wrong_first',
  )) {
    for (final h in hours) {
      final deltas = <double>[];
      for (var seed = 1; seed <= seeds; seed++) {
        final treatment = rows.firstWhere(
          (r) =>
              r['scenario'] == scenario.id &&
              r['seed'] == seed &&
              r['checkpointHours'] == h,
        );
        final control = rows.firstWhere(
          (r) =>
              r['scenario'] ==
                  (scenario.rank != null
                      ? 'matched_none'
                      : 'new_rewards_no_talents') &&
              r['seed'] == seed &&
              r['checkpointHours'] == h,
        );
        deltas.add(
          number(treatment, 'highestStage') - number(control, 'highestStage'),
        );
      }
      final mean = deltas.reduce((a, b) => a + b) / seeds;
      final variance = seeds > 1
          ? deltas.fold<double>(
                  0,
                  (sum, x) => sum + pow(x - mean, 2).toDouble(),
                ) /
                (seeds - 1)
          : 0.0;
      final error = 1.96 * sqrt(variance / seeds);
      paired.add({
        'scenario': scenario.id,
        'hours': h,
        'meanFrontierDelta': mean,
        'normalApprox95Interval': [mean - error, mean + error],
        'positiveSeeds': deltas.where((x) => x > 0).length,
        'negativeSeeds': deltas.where((x) => x < 0).length,
      });
    }
  }
  stdout.writeln(
    jsonEncode({
      'model': 'phase03_event_v1',
      'seeds': seeds,
      'checkpointsHours': hours,
      'candidate': TalentProfile.candidate.toJson(),
      'baseline':
          'docs/balance/phase_02_baseline.json (archived previous source; changed RNG/rewards isolated by new_rewards_no_talents)',
      'streams':
          'combat Random(seed), selection Random(seed*7919+17), travel Random(seed*104729+29)',
      'method':
          'Funded runs buy real ranks at registered gates and prices, no refunds. Same equipment policy per pair. Matched runs grant equal gated rank 3 to all six IDs to isolate selection; they are not funding evidence. Rest begins at a completed encounter/reward boundary; actual elapsed/rest/productive time recorded. Approximate paired intervals describe these heuristics, not optimal play.',
      'scenarios': [
        for (final s in scenarios)
          {
            'id': s.id,
            'policy': s.policy,
            'choices': s.choices,
            'profile': s.profile.toJson(),
            'fixedOwnedRank': s.rank,
            'purchaseCadenceSeconds': s.cadence,
            'duty': s.duty,
            'equipmentPolicy': s.goldStrategy.name,
          },
      ],
      'rows': rows,
      'summary': summaries,
      'paired': paired,
      'timelines': timelines,
    }),
  );
}
