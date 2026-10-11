import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/core/balance/talent_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';
import 'package:idle_companion/domain/progression/purchase_quote.dart';
import 'package:idle_companion/domain/progression/upgrade_price.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

Amount stat(CombatStats s, CharacterStat stat) => switch (stat) {
  CharacterStat.damage => s.damage,
  CharacterStat.maxHp => s.maxHp,
  CharacterStat.critChance => Amount.fromNum(s.critChance),
  CharacterStat.critDamage => Amount.fromNum(s.critDamage),
};

void main() {
  for (final (id, start) in [
    ('weapon', 99),
    ('armor', 99),
    ('helmet', 199),
    ('amulet', 149),
  ]) {
    for (final requested in <int?>[1, 10, null]) {
      test(
        '$id: quote matches partial ${requested ?? "MAX"}, debit and HP',
        () {
          final game = GameSimulation(), item = EquipmentCatalog.require(id);
          final hero = game.character
            ..equipment[id] = start
            ..gold = item.batchCost(start, 3)
            ..books = Amount.fromNum(17);
          final before = game.stats;
          game.heroHp = before.maxHp.scale(.4);
          final hp = game.heroHp;
          final quote = game.purchases.quote(hero, id, count: requested);
          expect(quote.currency, PurchaseCurrency.gold);
          expect(quote.count, requested == 1 ? 1 : 3);
          expect(quote.before.log10, stat(before, item.stat).log10);
          expect(quote.delta.isZero, isFalse);
          expect(quote.relativePercent.isZero, isFalse);
          expect(
            quote.limit,
            requested == 1 ? null : PurchaseLimit.insufficientCurrency,
          );
          var sum = Amount.zero;
          for (var i = 0; i < quote.count; i++) {
            sum = sum + item.cost(start + i);
          }
          expect(quote.cost.ratio(sum), closeTo(1, 1e-12));
          final expectedWallet = hero.gold - quote.cost;
          expect(game.purchaseEquipment(id, count: requested), quote.count);
          expect(hero.gold.log10, expectedWallet.log10);
          expect(hero.books.toDouble(), closeTo(17, 1e-10));
          expect(stat(game.stats, item.stat).log10, quote.after.log10);
          expect(game.stats.attackSpeed, 1);
          expect(
            game.heroHp.log10,
            (hp + (game.stats.maxHp - before.maxHp)).log10,
          );
          if (id != 'armor') expect(game.heroHp.log10, hp.log10);
        },
      );
    }
  }
  test('dead Armor purchase changes max HP without reviving', () {
    final game = GameSimulation();
    game.killHero();
    game.character.gold = Amount.fromNum(100);
    final before = game.stats.maxHp;
    expect(game.purchaseEquipment('armor'), 1);
    expect(game.stats.maxHp, greaterThan(before));
    expect(game.heroHp.isZero, isTrue);
  });
  test(
    'epsilon, precision, maximum and no-selection are distinct from wallet',
    () {
      const normal = EquipmentPurchases(),
          epsilon = EquipmentPurchases(
            profile: EquipmentCurveProfile(
              id: 'epsilon_test',
              minimumChanceGain: 1e-6,
            ),
          );
      final h = CharacterProgress()..gold = Amount.fromLog(10000);
      final n = normal.quote(h, 'helmet', count: null);
      final e = epsilon.quote(h, 'helmet', count: null);
      expect(e.count, lessThan(n.count));
      expect(e.limit, PurchaseLimit.minimumEffect);
      expect(n.limit, PurchaseLimit.precision);
      h.equipment['helmet'] = e.count - 2;
      final partial = epsilon.quote(h, 'helmet', count: 10);
      expect(partial.count, 2);
      expect(partial.limit, PurchaseLimit.minimumEffect);
      expect(epsilon.purchase(h, 'helmet', count: 10), 2);
      h.gold = Amount.zero;
      final before = jsonEncode(h.toJson());
      expect(epsilon.quote(h, 'helmet').limit, PurchaseLimit.minimumEffect);
      expect(epsilon.purchase(h, 'helmet'), 0);
      expect(jsonEncode(h.toJson()), before);
      expect(
        epsilon.quote(h, 'helmet', count: 0).limit,
        PurchaseLimit.noSelection,
      );
      h.equipment['weapon'] = UpgradePrice.maxLevel;
      expect(normal.quote(h, 'weapon').limit, PurchaseLimit.maximumRank);
    },
  );
  test('stale rank preview is recalculated before an equipment debit', () {
    final h = CharacterProgress()..gold = Amount.fromNum(100);
    const p = EquipmentPurchases();
    final old = p.quote(h, 'weapon', count: 10);
    expect(p.purchase(h, 'weapon'), 1);
    final actual = p.quote(h, 'weapon', count: 10);
    expect(actual.rank, old.rank + 1);
    final wallet = h.gold - actual.cost;
    expect(p.purchase(h, 'weapon', count: 10), actual.count);
    expect(h.gold.log10, wallet.log10);
    expect(h.equipment['weapon'], actual.rank + actual.count);
  });
  for (final d in TalentCatalog.items) {
    test(
      '${d.id}: inactive ability quote matches funded package and next gate',
      () {
        final game = GameSimulation(), h = game.character;
        h.talents.highestFirstClearedStage = 5;
        h.books = Amount.fromNum(8.4);
        final q = game.talentPurchases.quote(h, d.id, count: 10);
        expect(q.currency, PurchaseCurrency.books);
        expect(q.count, 2);
        expect(q.limit, PurchaseLimit.insufficientCurrency);
        expect(q.delta, greaterThan(0));
        final stats = game.stats, hp = game.heroHp;
        game.spawnEnemy();
        final snapshot = game.activeAttempt!.toJson();
        expect(game.purchaseTalent(d.id, count: 10), 2);
        expect(h.books.isZero, isTrue);
        expect(h.talents.selectedForNextAttempt, isEmpty);
        expect(game.activeAttempt!.toJson(), snapshot);
        expect(game.stats.dps.log10, stats.dps.log10);
        expect(game.heroHp.log10, hp.log10);
        expect(game.talentProfile.curves[d.id]!.value(2), q.after);
        h.books = Amount.fromNum(10000);
        final gated = game.talentPurchases.quote(h, d.id, count: null);
        expect(gated.count, 1);
        expect(gated.limit, PurchaseLimit.milestone);
        expect(gated.requiredStage, 20);
      },
    );
  }
  test('saturated talent effect reports precision and never debits Books', () {
    final p = TalentPurchases(
      profile: const TalentProfile(
        bossDamage: TalentCurve(tau: .0001, maximum: .5),
      ),
    );
    final h = CharacterProgress()
      ..books = Amount.fromNum(10000)
      ..talents.highestFirstClearedStage = 100;
    expect(p.purchase(h, 'boss_damage'), 1);
    final before = jsonEncode(h.toJson());
    final q = p.quote(h, 'boss_damage', count: null);
    expect(q.limit, PurchaseLimit.precision);
    expect(q.blockedReason, startsWith('Precision'));
    expect(q.delta, 0);
    expect(p.purchase(h, 'boss_damage', count: null), 0);
    expect(jsonEncode(h.toJson()), before);
  });
}
