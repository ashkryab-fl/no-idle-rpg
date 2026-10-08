import '../progression/infinite_upgrade.dart';

class EquipmentDefinition extends InfiniteUpgradeDefinition {
  const EquipmentDefinition({
    required super.id,
    required super.name,
    required super.stat,
    required super.baseCost,
    super.costGrowth = 1.14,
    super.curve,
    super.valueGrowth,
    super.softCapRate,
    super.bonusPerLevel,
  });
}

abstract final class EquipmentCatalog {
  static const items = [
    EquipmentDefinition(
      id: 'weapon',
      name: 'Weapon',
      stat: CharacterStat.damage,
      baseCost: 20,
    ),
    EquipmentDefinition(
      id: 'armor',
      name: 'Armor',
      stat: CharacterStat.maxHp,
      baseCost: 20,
    ),
    EquipmentDefinition(
      id: 'boots',
      name: 'Boots',
      stat: CharacterStat.attackSpeed,
      baseCost: 35,
      curve: UpgradeCurve.softCap,
    ),
    EquipmentDefinition(
      id: 'helmet',
      name: 'Helmet',
      stat: CharacterStat.critChance,
      baseCost: 35,
      curve: UpgradeCurve.softCap,
    ),
    EquipmentDefinition(
      id: 'amulet',
      name: 'Amulet',
      stat: CharacterStat.critDamage,
      baseCost: 30,
      curve: UpgradeCurve.additive,
    ),
  ];
}
