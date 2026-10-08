import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/progression_balance.dart';
import '../../tool/simulate_progression.dart';

void main() {
  test('sustained damage budget grows slightly slower than enemy HP', () {
    // Optimistic income-budget estimate, excluding capped crit chance and
    // additive crit damage. The long-run model below includes those effects.
    final upgradeLogGrowth =
        log(ProgressionBalance.upgradeGrowth) *
        (log(ProgressionBalance.goldRewardGrowth) /
                log(ProgressionBalance.equipmentCostGrowth) +
            log(ProgressionBalance.bookRewardGrowth) /
                log(ProgressionBalance.bookUpgradeCostGrowth));
    final xpLogGrowth =
        log(ProgressionBalance.levelStatGrowth) *
        log(ProgressionBalance.xpRewardGrowth) /
        log(ProgressionBalance.xpGrowth);
    final lag =
        log(ProgressionBalance.hpGrowth) - upgradeLogGrowth - xpLogGrowth;
    expect(lag, greaterThan(0));
    // Keep the per-stage gap small; large gaps become abrupt grind walls.
    expect(lag, lessThan(.003));
  });

  test('monthly pacing slows gradually with regular balanced investments', () {
    final daily = <double>[], fortnight = <double>[], monthly = <double>[];
    for (var seed = 1; seed <= 3; seed++) {
      for (final (days, times) in [
        (1, daily),
        (14, fortnight),
        (30, monthly),
      ]) {
        final sim = ProgressionSimulation(seed: seed);
        sim.runUntil(days * 8 * 3600);
        times.add((sim.snapshot(days)['medianRecentStageSeconds'] as double));
        expect(sim.stage, greaterThan(1));
        expect(sim.kills, greaterThan(0));
      }
    }
    final first = ProgressionSimulation.median(daily);
    final middle = ProgressionSimulation.median(fortnight);
    final last = ProgressionSimulation.median(monthly);
    expect(middle / first, inInclusiveRange(1.1, 2));
    expect(last / first, inInclusiveRange(2, 5));
    expect(last, greaterThan(middle));
  });
}
