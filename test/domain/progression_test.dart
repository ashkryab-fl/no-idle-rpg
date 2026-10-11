import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';

void main() {
  const purchases = EquipmentPurchases();
  test(
    'MAX and partial x10 never overspend; million ranks use bounded math',
    () {
      final item = EquipmentCatalog.items.first;
      final wallet = item.batchCost(30, 1000000);
      expect(item.affordable(30, wallet), 1000000);
      final hero = CharacterProgress()..gold = item.batchCost(0, 3);
      expect(purchases.purchase(hero, item.id, count: 10), 3);
      expect(hero.gold.toDouble(), closeTo(0, 1e-10));
      hero.gold = Amount.fromLog(1000);
      final quote = purchases.quote(hero, item.id, count: null);
      expect(purchases.purchase(hero, item.id, count: null), quote.count);
      expect(hero.gold < item.cost(hero.equipment[item.id]!), isTrue);
    },
  );
  test('hero attack speed is fixed even with enormous equipment ranks', () {
    final hero = CharacterProgress();
    for (final d in EquipmentCatalog.items) {
      hero.equipment[d.id] = 1000000;
    }
    expect(CharacterStats.calculate(hero).attackSpeed, 1);
    expect(
      () => CharacterProgress.fromJson({
        'equipment': {'boots': 1},
      }),
      throwsFormatException,
    );
  });
  test('early crit equipment grows with unchanged starting steps', () {
    for (final count in [1, 10, 25]) {
      final hero = CharacterProgress();
      for (final id in ['helmet', 'amulet']) {
        final d = EquipmentCatalog.require(id);
        hero.gold = d.batchCost(0, count);
        expect(purchases.purchase(hero, id, count: count), count);
      }
      final stats = CharacterStats.calculate(hero);
      expect(stats.critChance, closeTo(.05 + .001 * count, 1e-10));
      expect(stats.critDamage, closeTo(1.5 + .01 * count, 1e-10));
    }
  });
}
