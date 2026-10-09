import 'dart:math';
import 'package:idle_companion/content/animations/enemies/procedural_timelines.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/domain/progression/infinite_upgrade.dart';
import 'package:idle_companion/game/systems/drop_system.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';

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
  animations: ProceduralEnemyTimelines.content,
);

void main() {
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
