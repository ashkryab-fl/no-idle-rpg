import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/progression/infinite_upgrade.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/game/systems/progression_system.dart';

void main() {
  final system = ProgressionSystem();
  test('XP requirement grows, level-up carries residual XP', () {
    final hero = CharacterProgress();
    expect(system.xpRequired(1).toDouble(), closeTo(45, 1e-8));
    expect(system.xpRequired(2).toDouble(), closeTo(50.4, 1e-8));
    expect(system.addXp(hero, Amount.fromNum(100)), 2);
    expect(hero.level, 3);
    expect(hero.xp.toDouble(), closeTo(4.6, 1e-7));
  });

  test(
    'MAX and partial x10 never overspend; enormous purchases are analytic',
    () {
      final definition = UpgradeCatalog.character.first;
      final wallet = definition.batchCost(30, 500000);
      expect(definition.affordable(30, wallet), 500000);
      final hero = CharacterProgress()..books = definition.batchCost(0, 3);
      expect(system.upgrade(hero, definition, equipment: false, count: 10), 3);
      expect(hero.books.toDouble(), closeTo(0, 1e-10));
      hero.books = Amount.fromLog(1000);
      final max = definition.affordable(3, hero.books);
      expect(
        system.upgrade(hero, definition, equipment: false, count: null),
        max,
      );
      expect(hero.books < definition.cost(3 + max), isTrue);
    },
  );

  test('legacy speed levels cannot change the fixed hero attack speed', () {
    final hero = CharacterProgress.fromJson({
      'level': 100,
      'upgrades': {'speed': 1000000},
      'equipment': {'boots': 1000000},
    });
    expect(
      UpgradeCatalog.character.map((item) => item.id),
      isNot(contains('speed')),
    );
    expect(
      EquipmentCatalog.items.map((item) => item.id),
      isNot(contains('boots')),
    );
    expect(CharacterStats.calculate(hero).attackSpeed, 1);
    for (final item in UpgradeCatalog.character) {
      hero.upgrades[item.id] = 1000000;
    }
    for (final item in EquipmentCatalog.items) {
      hero.equipment[item.id] = 1000000;
    }
    expect(CharacterStats.calculate(hero).attackSpeed, 1);
  });
  test('crit purchases grow by 0.1 percentage point and 0.01x per level', () {
    for (final count in [1, 10, 25]) {
      final hero = CharacterProgress();
      for (final equipment in [false, true]) {
        final catalog = equipment
            ? EquipmentCatalog.items
            : UpgradeCatalog.character;
        for (final stat in [
          CharacterStat.critChance,
          CharacterStat.critDamage,
        ]) {
          final item = catalog.singleWhere((item) => item.stat == stat);
          if (equipment) {
            hero.gold = item.batchCost(0, count);
          } else {
            hero.books = item.batchCost(0, count);
          }
          expect(
            system.upgrade(
              hero,
              item,
              equipment: equipment,
              count: count == 25 ? null : count,
            ),
            count,
          );
        }
        final stats = CharacterStats.calculate(hero);
        final totalLevels = count * (equipment ? 2 : 1);
        expect(stats.critChance, closeTo(.05 + .001 * totalLevels, 1e-10));
        expect(stats.critDamage, closeTo(1.5 + .01 * totalLevels, 1e-10));
        expect(stats.attackSpeed, 1);
      }
    }
  });
}
