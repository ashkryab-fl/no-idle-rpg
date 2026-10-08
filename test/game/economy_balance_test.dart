import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/progression_balance.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/progression/infinite_upgrade.dart';
import 'package:idle_companion/game/systems/drop_system.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/progression_system.dart';

EnemyDefinition definition(double bookChance) => EnemyDefinition(
  id: 'test',
  name: 'Test',
  baseHp: 48,
  baseDamage: 6,
  attackSpeed: .75,
  rewardGold: 12,
  rewardXp: 18,
  rewardBooks: 2,
  rewardBookChance: bookChance,
  animations: 'slime',
);

void main() {
  test('late-stage books scale with loot instead of staying flat', () {
    final factory = EnemyFactory(), drops = DropSystem(Random(1));
    for (final stage in [1, 10, 100]) {
      final enemy = factory.create(definition(1), stage - 1);
      final reward = drops.roll(enemy, multiplier: 2);
      expect(reward.books.toDouble(), closeTo(4 * pow(1.10, stage - 1), .0001));
      expect(reward.gold.toDouble(), closeTo(24 * pow(1.10, stage - 1), .0001));
      // The activity multiplier affects loot, not character XP.
      expect(reward.xp.toDouble(), closeTo(18 * pow(1.07, stage - 1), .0001));
      expect(
        drops.roll(factory.create(definition(0), stage - 1)).books.isZero,
        isTrue,
      );
    }
  });

  test(
    'an extended farming loop buys permanent power without raising stage',
    () {
      final game = GameSimulation(random: Random(1), idleDefinitions: const [])
        ..stage = 10;
      game.character.level = 10;
      game.killHero();
      game.advance(3);
      expect(game.stage, 9);
      for (var i = 0; i < ProgressionBalance.enemiesPerStage; i++) {
        game.spawnEnemy();
        game.killEnemy();
        game.advance(2);
      }
      expect(game.stage, 10);
      final damage = game.stats.damage, hp = game.stats.maxHp;
      final gold = game.character.gold, books = game.character.books;
      final weapon = EquipmentCatalog.items.first;
      final bookHp = UpgradeCatalog.character.firstWhere(
        (item) => item.id == 'hp',
      );
      final weaponCount = game.progression.upgrade(
        game.character,
        weapon,
        equipment: true,
        count: null,
      );
      final hpCount = game.progression.upgrade(
        game.character,
        bookHp,
        equipment: false,
        count: null,
      );
      expect(weaponCount, greaterThan(0));
      expect(hpCount, greaterThan(0));
      expect(game.stats.damage > damage, isTrue);
      expect(game.stats.maxHp > hp, isTrue);
      expect(game.character.gold < gold, isTrue);
      expect(game.character.books < books, isTrue);
      expect(game.character.gold < weapon.cost(weaponCount), isTrue);
      expect(game.character.books < bookHp.cost(hpCount), isTrue);
      expect(game.stage, 10);
    },
  );

  test(
    'crit upgrades from books and equipment give the combined DPS benefit',
    () {
      final hero = CharacterProgress();
      final system = ProgressionSystem();
      final critBook = UpgradeCatalog.character.firstWhere(
        (item) => item.id == 'critDamage',
      );
      final amulet = EquipmentCatalog.items.firstWhere(
        (item) => item.id == 'amulet',
      );
      hero.books = critBook.batchCost(0, 10);
      hero.gold = amulet.batchCost(0, 10);
      hero.upgrades['crit'] = 20;
      final before = CharacterStats.calculate(hero);
      expect(system.upgrade(hero, critBook, equipment: false, count: 10), 10);
      expect(system.upgrade(hero, amulet, equipment: true, count: 10), 10);
      final after = CharacterStats.calculate(hero);
      expect(before.critChance, closeTo(.07, 1e-8));
      expect(after.critDamage, closeTo(1.7, 1e-8));
      expect(after.damage.ratio(before.damage), closeTo(1, 1e-8));
      expect(after.dps > before.dps, isTrue);
      expect(hero.books.isZero, isTrue);
      expect(hero.gold.isZero, isTrue);
    },
  );

  test(
    'loot and upgrade math remains finite beyond ordinary double magnitudes',
    () {
      final enemy = EnemyFactory().create(definition(1), 1000000);
      final reward = DropSystem(Random(1)).roll(enemy);
      expect(reward.gold.log10, greaterThan(308));
      expect(reward.books.log10, greaterThan(308));
      expect(reward.gold.log10.isFinite, isTrue);
      expect(reward.books.log10.isFinite, isTrue);
      final item = UpgradeCatalog.character.first;
      final price = item.batchCost(1000000, 1000000);
      expect(price.log10.isFinite, isTrue);
      expect(item.affordable(1000000, price), 1000000);
      expect(item.effect(1000000).multiplier.log10.isFinite, isTrue);
    },
  );
}
