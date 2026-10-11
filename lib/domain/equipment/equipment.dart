import '../../core/balance/equipment_curve_profile.dart';
import '../../core/balance/progression_balance.dart';
import '../../core/balance/economy_profile.dart';
import '../../core/numbers/amount.dart';
import '../progression/upgrade_price.dart';
export '../../core/balance/equipment_curve_profile.dart' show CharacterStat;

class EquipmentDefinition {
  const EquipmentDefinition({
    required this.id,
    required this.name,
    required this.stat,
    required this.baseCost,
    double? costGrowth,
  }) : _fixedCostGrowth = costGrowth;
  final String id, name;
  final CharacterStat stat;
  final double baseCost;
  final double? _fixedCostGrowth;
  double get costGrowth =>
      _fixedCostGrowth ?? ProgressionBalance.equipmentCostGrowth;
  UpgradePrice get price => priceFor(EconomyProfile.candidate);
  UpgradePrice priceFor(EconomyProfile profile) => UpgradePrice(
    baseCost: baseCost,
    costGrowth: _fixedCostGrowth ?? profile.equipmentCostGrowth,
  );
  Amount cost(int rank) => price.cost(rank);
  Amount batchCost(int rank, int count) => price.batchCost(rank, count);
  int affordable(int rank, Amount wallet) => price.affordable(rank, wallet);
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
    ),
    EquipmentDefinition(
      id: 'amulet',
      name: 'Amulet',
      stat: CharacterStat.critDamage,
      baseCost: ProgressionBalance.amuletCost,
    ),
  ];
  static EquipmentDefinition require(String id) => items.firstWhere(
    (d) => d.id == id,
    orElse: () =>
        throw ArgumentError.value(id, 'equipmentId', 'Unknown equipment'),
  );
}
