import 'package:flutter_test/flutter_test.dart';
import '../../tool/balance/simulate_progression.dart';

void main() {
  test('no-purchase farming cannot increase permanent combat power', () {
    for (var seed = 1; seed <= 20; seed++) {
      final sim = ProgressionSimulation(
        seed: seed,
        strategy: InvestmentStrategy.noPurchases,
      );
      final hp = sim.stats.maxHp.log10, damage = sim.stats.damage.log10;
      sim.runUntil(1800);
      expect(sim.kills, greaterThan(0));
      expect(sim.deaths, greaterThan(0));
      expect(sim.hero.equipment, isEmpty);
      expect(sim.hero.toJson().containsKey('upgrades'), isFalse);
      expect(sim.stats.maxHp.log10, hp);
      expect(sim.stats.damage.log10, damage);
      expect(sim.hp <= sim.stats.maxHp, isTrue);
      expect(sim.goldEarned.isZero, isFalse);
    }
  });

  test('affordable balanced investments break the early farming wall', () {
    for (var seed = 1; seed <= 20; seed++) {
      final sim = ProgressionSimulation(seed: seed, upgradeInterval: 0);
      sim.runUntil(1800);
      final earlyHighest = sim.snapshot(0)['highestStage'] as int;
      expect(sim.successfulPurchases, greaterThan(0));
      expect(sim.hpPurchases, greaterThan(0));
      expect(earlyHighest, greaterThan(2));
      sim.runUntil(7 * 3600);
      expect(sim.snapshot(1)['highestStage'] as int, greaterThan(earlyHighest));
      expect(sim.hp <= sim.stats.maxHp, isTrue);
      expect(sim.hero.gold.isZero || sim.hero.gold.log10.isFinite, isTrue);
      expect(sim.hero.books.isZero || sim.hero.books.log10.isFinite, isTrue);
    }
  });
}
