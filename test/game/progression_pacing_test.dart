import 'package:flutter_test/flutter_test.dart';
import '../../tool/balance/simulate_progression.dart';

void main() {
  test('five-wave stages slow over the month with balanced investments', () {
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
    // Twelve-fight stage duration bounds no longer apply to five-wave stages.
    // Preserve the long-term slowdown requirement without changing upgrade prices.
    expect(middle / first, greaterThanOrEqualTo(1.1));
    expect(last / first, greaterThanOrEqualTo(2));
    expect(last, greaterThan(middle));
  });
}
