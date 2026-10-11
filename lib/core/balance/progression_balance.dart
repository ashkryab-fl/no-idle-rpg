/// Gameplay/economy tuning. Rendering, timing and platform settings are kept
/// in GameBalance; all progression coefficients and catalog numbers live here.
abstract final class ProgressionBalance {
  static const heroHp = 120.0;
  static const heroDamage = 14.0;
  static const heroAttackSpeed = 1.0;
  static const heroCritChance = .05;
  static const heroCritDamage = 1.5;

  static const hpGrowth = 1.08;
  static const damageGrowth = 1.065;
  static const enemiesPerStage = 5;
  static const profileId = 'phase06_calibrated_v3';
  static const bossHp = 2.2;
  static const bossDamage = 1.2;
  static const bossGold = 2.0;
  static const enemyGrowthKnee = 40;
  static const enemyGrowthWidth = 40.0;
  static const enemyGrowthTail = .35;
  static const enemyCritChanceFactor = 4.0;
  static const enemyCritBonusFactor = 2.0;
  static const talentCostGrowth = 1.8;
  static const bossDamageTalent = .5;
  static const firstClearGoldTalent = 1.5;
  static const stageHealTalent = .2;
  static const critProtectionTalent = .8;
  static const shorterTravelTalent = .25;
  static const stageGoldTalent = .5;
  static const firstClearGoldBaseMultiplier = 3.0;
  static const enemyCritChance = .03;
  static const enemyCritDamage = 1.5;
  static const enemyWeight = 1.0;

  static const goldRewardGrowth = 1.10;

  static const upgradeGrowth = 1.05;
  // Calibrated candidate; remaining pacing gaps are summarized in docs/balance_refactoring_summary.md.
  static const equipmentCostGrowth = 1.1195;
  static const critChanceCap = .8;
  // +0.1 percentage point of crit chance and +0.01x crit multiplier per level.
  static const critChanceBonus = .001;
  static const critDamageBonus = .01;

  static const weaponCost = 20.0;
  static const armorCost = 20.0;
  static const helmetCost = 35.0;
  static const amuletCost = 30.0;

  static const idleDpsMultipliers = [1.0, 1.0, 1.0, 1.0];
  static const idleRewardMultipliers = [1.0, 1.0, 1.0, 1.0];

  static const slimeHp = 48.0;
  static const slimeDamage = 6.0;
  static const slimeAttackSpeed = .75;
  static const slimeGold = 12.0;
  static const slimeWeight = 1.0;

  static const sentinelHp = 80.0;
  static const sentinelDamage = 9.0;
  static const sentinelAttackSpeed = .55;
  static const sentinelGold = 20.0;
  static const sentinelWeight = .5;

  static const wispHp = 34.0;
  static const wispDamage = 5.0;
  static const wispAttackSpeed = 1.2;
  static const wispGold = 14.0;
  static const wispWeight = .8;
}
