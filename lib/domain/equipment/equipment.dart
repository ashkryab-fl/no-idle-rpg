import '../progression/infinite_upgrade.dart';
import '../../core/balance/progression_balance.dart';

class EquipmentDefinition extends InfiniteUpgradeDefinition {
  const EquipmentDefinition({
    required super.id,
    required super.name,
    required super.stat,
    required super.baseCost,
    super.costGrowth = ProgressionBalance.equipmentCostGrowth,
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
      baseCost: ProgressionBalance.weaponCost,
    ),
    EquipmentDefinition(
      id: 'armor',
      name: 'Armor',
      stat: CharacterStat.maxHp,
      baseCost: ProgressionBalance.armorCost,
    ),
    EquipmentDefinition(
      id: 'helmet',
      name: 'Helmet',
      stat: CharacterStat.critChance,
      baseCost: ProgressionBalance.helmetCost,
      curve: UpgradeCurve.additive,
      bonusPerLevel: ProgressionBalance.critChanceBonus,
    ),
    EquipmentDefinition(
      id: 'amulet',
      name: 'Amulet',
      stat: CharacterStat.critDamage,
      baseCost: ProgressionBalance.amuletCost,
      curve: UpgradeCurve.additive,
    ),
  ];
}
