import 'package:flutter_test/flutter_test.dart';
import '../../tool/simulate_progression.dart';

void main() {
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
