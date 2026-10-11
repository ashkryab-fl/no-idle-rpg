import 'progression_balance.dart';
import 'equipment_curve_profile.dart';

/// Immutable inputs shared by runtime, purchases and event experiments.
class EconomyProfile {
  const EconomyProfile({
    this.id = ProgressionBalance.profileId,
    this.equipmentCostGrowth = ProgressionBalance.equipmentCostGrowth,
    this.hpGrowth = ProgressionBalance.hpGrowth,
    this.damageGrowth = ProgressionBalance.damageGrowth,
    this.goldGrowth = ProgressionBalance.goldRewardGrowth,
    this.bossHp = ProgressionBalance.bossHp,
    this.bossDamage = ProgressionBalance.bossDamage,
    this.bossGold = ProgressionBalance.bossGold,
    this.critChanceFactor = ProgressionBalance.enemyCritChanceFactor,
    this.critBonusFactor = ProgressionBalance.enemyCritBonusFactor,
    this.growthKnee = ProgressionBalance.enemyGrowthKnee,
    this.growthWidth = ProgressionBalance.enemyGrowthWidth,
    this.growthTail = ProgressionBalance.enemyGrowthTail,
  });
  static const candidate = EconomyProfile();
  final String id;
  final double equipmentCostGrowth, hpGrowth, damageGrowth, goldGrowth;
  final double bossHp, bossDamage, bossGold, critChanceFactor, critBonusFactor;
  final int growthKnee;
  final double growthWidth, growthTail;
  double effectiveTier(int tier) => PowerCurve(
    threshold: growthKnee,
    width: growthWidth,
    tailRate: growthTail,
  ).effectiveRank(tier);
  void validate() {
    if (id.isEmpty ||
        growthKnee < 0 ||
        !growthWidth.isFinite ||
        growthWidth <= 0 ||
        !growthTail.isFinite ||
        growthTail <= 0 ||
        growthTail > 1 ||
        [
          equipmentCostGrowth,
          hpGrowth,
          damageGrowth,
          goldGrowth,
        ].any((v) => !v.isFinite || v < 1) ||
        [bossHp, bossDamage, bossGold].any((v) => !v.isFinite || v <= 0) ||
        [critChanceFactor, critBonusFactor].any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('Invalid economy profile');
    }
  }

  Map<String, Object> toJson() => {
    'id': id,
    'equipmentCostGrowth': equipmentCostGrowth,
    'hpGrowth': hpGrowth,
    'damageGrowth': damageGrowth,
    'goldGrowth': goldGrowth,
    'bossHp': bossHp,
    'bossDamage': bossDamage,
    'bossGold': bossGold,
    'critChanceFactor': critChanceFactor,
    'critBonusFactor': critBonusFactor,
    'growthKnee': growthKnee,
    'growthWidth': growthWidth,
    'growthTail': growthTail,
  };
}
