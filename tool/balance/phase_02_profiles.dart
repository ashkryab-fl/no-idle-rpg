import 'package:idle_companion/core/balance/equipment_curve_profile.dart';

const isolatedProfiles = [
  EquipmentCurveProfile(
    id: 'gold_only_old_curves',
    weapon: PowerCurve(tailRate: 1),
    armor: PowerCurve(tailRate: 1),
    chance: ChanceCurve(soft: false),
    multiplier: MultiplierCurve(soft: false),
  ),
  EquipmentCurveProfile(
    id: 'chance_soft_only',
    weapon: PowerCurve(tailRate: 1),
    armor: PowerCurve(tailRate: 1),
    multiplier: MultiplierCurve(soft: false),
  ),
  EquipmentCurveProfile(
    id: 'chance_and_multiplier',
    weapon: PowerCurve(tailRate: 1),
    armor: PowerCurve(tailRate: 1),
  ),
  EquipmentCurveProfile(id: 'plus_weapon', armor: PowerCurve(tailRate: 1)),
  EquipmentCurveProfile(id: 'plus_armor', weapon: PowerCurve(tailRate: 1)),
  EquipmentCurveProfile.candidate,
];
