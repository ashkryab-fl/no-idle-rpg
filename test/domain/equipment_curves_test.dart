import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';
import 'package:idle_companion/domain/progression/upgrade_price.dart';

void main() {
  const profile = EquipmentCurveProfile.candidate;
  const purchases = EquipmentPurchases();
  test(
    'Helmet reaches exactly 25% at 200 and uses the post-threshold formula',
    () {
      for (final (rank, expected) in [
        (0, .05),
        (199, .249),
        (200, .25),
        (201, .2509990914597966),
        (500, .4812319466683548),
        (1000, .6715714364999976),
      ]) {
        expect(profile.chance.value(rank), closeTo(expected, 1e-10));
      }
      expect(profile.chance.value(200), .25);
      expect(
        profile.chance.value(201) - profile.chance.value(200),
        lessThan(.001),
      );
      var previous = .001;
      for (var rank = 201; rank < 8000; rank++) {
        final delta =
            profile.chance.value(rank) - profile.chance.value(rank - 1);
        expect(delta, greaterThan(0));
        expect(delta, lessThan(previous));
        previous = delta;
      }
    },
  );
  test(
    'Amulet logarithmic tail is continuous and has diminishing absolute gain',
    () {
      for (final (rank, expected) in [
        (149, 2.99),
        (150, 3.0),
        (350, 4.38629436111989),
        (1000, 6.316456153207065),
      ]) {
        expect(profile.multiplier.value(rank), closeTo(expected, 1e-10));
      }
      var previous = .01;
      for (var rank = 151; rank < 10000; rank++) {
        final gain =
            profile.multiplier.value(rank) - profile.multiplier.value(rank - 1);
        expect(gain, greaterThan(0));
        expect(gain, lessThan(previous));
        previous = gain;
      }
    },
  );
  test('Weapon and Armor use fractional E with decreasing relative gains', () {
    for (final threshold in [50, 100, 200]) {
      for (final width in [100.0, 200.0, 400.0]) {
        for (final tail in [.5, .75, 1.0]) {
          final curve = PowerCurve(
            threshold: threshold,
            width: width,
            tailRate: tail,
          );
          expect(curve.effectiveRank(threshold), threshold.toDouble());
          final next = curve.effectiveRank(threshold + 1) - threshold;
          expect(next, greaterThan(0));
          expect(next, lessThanOrEqualTo(1));
          if (tail < 1) expect(next, lessThan(1));
          final far =
              curve.effectiveRank(1000000) - curve.effectiveRank(999999);
          expect(far, closeTo(tail, .001));
        }
      }
    }
    final expected =
        math.log(14) / math.ln10 +
        (100 + .5 + 100 * math.log(1.005)) * math.log(1.05) / math.ln10;
    expect(
      profile.value(CharacterStat.damage, 101).log10,
      closeTo(expected, 1e-12),
    );
    expect(
      profile.value(CharacterStat.damage, 1000000).log10,
      greaterThan(308),
    );
    for (final stat in CharacterStat.values) {
      for (final rank in [0, 1, 100, 1000, 1000000, UpgradePrice.maxLevel]) {
        expect(profile.value(stat, rank).log10.isFinite, isTrue);
      }
    }
  });
  test('registered IDs and Gold-only wallet are enforced outside UI', () {
    final hero = CharacterProgress()..books = Amount.fromLog(1000);
    expect(purchases.purchase(hero, 'weapon'), 0);
    expect(hero.gold.isZero, isTrue);
    expect(hero.equipment, isEmpty);
    hero.gold = Amount.fromNum(100);
    final before = hero.toJson();
    for (final id in [
      'damage',
      'hp',
      'crit',
      'critDamage',
      'boots',
      'unknown',
    ]) {
      expect(() => purchases.purchase(hero, id), throwsArgumentError);
    }
    expect(
      () =>
          purchases.purchase(hero, 'weapon', currency: PurchaseCurrency.books),
      throwsArgumentError,
    );
    expect(
      () => purchases.purchase(hero, 'weapon', count: -1),
      throwsArgumentError,
    );
    expect(
      () =>
          purchases.purchase(hero, 'weapon', count: UpgradePrice.maxLevel + 1),
      throwsArgumentError,
    );
    expect(purchases.purchase(hero, 'weapon', count: 0), 0);
    expect(hero.toJson(), before);
    final books = hero.books.log10;
    expect(purchases.purchase(hero, 'weapon'), 1);
    expect(hero.books.log10, books);
    expect(hero.equipment, {'weapon': 1});
    expect(hero.gold.toDouble(), closeTo(80, 1e-10));
  });
  test(
    'single/bulk purchases across thresholds have identical rank, stats and price',
    () {
      for (final (id, start) in [
        ('weapon', 99),
        ('armor', 99),
        ('helmet', 199),
        ('amulet', 149),
      ]) {
        final d = EquipmentCatalog.require(id);
        final one = CharacterProgress()
          ..equipment[id] = start
          ..gold = d.batchCost(start, 10);
        final bulk = CharacterProgress()
          ..equipment[id] = start
          ..gold = d.batchCost(start, 10);
        for (var i = 0; i < 10; i++) {
          expect(purchases.purchase(one, id), 1);
        }
        expect(purchases.purchase(bulk, id, count: 10), 10);
        expect(one.equipment, bulk.equipment);
        expect(
          profile.value(d.stat, one.equipment[id]!).log10,
          profile.value(d.stat, bulk.equipment[id]!).log10,
        );
        expect(one.gold.ratio(d.batchCost(start, 10)), lessThan(1e-12));
        expect(bulk.gold.ratio(d.batchCost(start, 10)), lessThan(1e-12));
      }
      final hero = CharacterProgress()
        ..gold = EquipmentCatalog.require('armor').batchCost(99, 3)
        ..equipment['armor'] = 99;
      final quote = purchases.quote(hero, 'armor', count: 10);
      expect(quote.count, 3);
      expect(purchases.purchase(hero, 'armor', count: 10), 3);
      expect(hero.equipment['armor'], 102);
    },
  );
  test('quotes cannot debit stale wallets or ranks', () {
    final hero = CharacterProgress()..gold = Amount.fromNum(100);
    final old = purchases.quote(hero, 'weapon', count: 10);
    expect(old.count, greaterThan(0));
    hero.gold = Amount.zero;
    expect(purchases.purchase(hero, 'weapon', count: 10), 0);
    expect(hero.equipment, isEmpty);
    hero.gold = Amount.fromNum(100);
    purchases.purchase(hero, 'weapon');
    expect(purchases.quote(hero, 'weapon').level, 1);
    purchases.purchase(hero, 'weapon');
    expect(hero.equipment['weapon'], 2);
  });
  test(
    'asymptotic precision guard supports partial MAX and blocks zero-effect debits',
    () {
      final hero = CharacterProgress()..gold = Amount.fromLog(10000);
      final whole = purchases.quote(hero, 'helmet', count: null);
      expect(whole.count, greaterThan(1000));
      expect(whole.count, lessThan(1000000));
      hero.equipment['helmet'] = whole.count - 3;
      final partial = purchases.quote(hero, 'helmet', count: 10);
      expect(partial.count, 3);
      expect(purchases.purchase(hero, 'helmet', count: 10), 3);
      final wallet = hero.gold.log10;
      expect(purchases.purchase(hero, 'helmet', count: null), 0);
      expect(hero.gold.log10, wallet);
      expect(
        purchases.quote(hero, 'helmet').blockedReason,
        startsWith('Precision'),
      );
      const epsilon = EquipmentPurchases(
        profile: EquipmentCurveProfile(
          id: 'epsilon_test',
          minimumChanceGain: 1e-6,
        ),
      );
      final early = epsilon.quote(
        CharacterProgress()..gold = Amount.fromLog(10000),
        'helmet',
        count: null,
      );
      expect(early.count, lessThan(whole.count));
      for (final id in ['weapon', 'armor', 'helmet', 'amulet']) {
        final extreme = CharacterProgress()
          ..gold = Amount.fromLog(1e308)
          ..equipment[id] = UpgradePrice.maxLevel;
        expect(purchases.purchase(extreme, id, count: null), 0);
      }
    },
  );
  test(
    'large price exponents do not turn precision tolerance into free ranks',
    () {
      final item = EquipmentCatalog.require('weapon');
      final level = 100000000000000;
      final price = item.cost(level);
      final wallet = Amount.fromLog(price.log10 - 1);
      expect(item.affordable(level, wallet), 0);
      final hero = CharacterProgress()
        ..equipment['weapon'] = level
        ..gold = wallet;
      expect(purchases.purchase(hero, 'weapon'), 0);
      expect(hero.gold.log10, wallet.log10);
    },
  );
  test('shared financial math handles flat and almost-flat growth', () {
    for (final growth in [1.0, 1.000000000001]) {
      final price = UpgradePrice(baseCost: 20, costGrowth: growth);
      final cost = price.batchCost(100, 1000000);
      expect(cost.toDouble(), closeTo(20000000, 11));
      expect(price.affordable(100, cost), 1000000);
      expect(price.affordable(100, price.batchCost(100, 3).scale(.99)), 2);
      expect(price.batchCost(100, 0).isZero, isTrue);
    }
  });
  test(
    'MAX with one million affordable ranks is bounded and preserves Books',
    () {
      final hero = CharacterProgress()
        ..gold = EquipmentCatalog.require('weapon').batchCost(0, 1000000)
        ..books = Amount.fromNum(17);
      expect(purchases.purchase(hero, 'weapon', count: null), 1000000);
      expect(hero.equipment['weapon'], 1000000);
      expect(hero.books.toDouble(), closeTo(17, 1e-10));
    },
  );
}
