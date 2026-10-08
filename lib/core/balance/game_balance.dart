class GameBalance {
  const GameBalance();
  static const heroHp = 120.0;
  static const heroDamage = 14.0;
  static const heroAttackSpeed = 1.0;
  static const heroCritChance = .05;
  static const heroCritDamage = 1.5;
  static const movementSpeed = 32.0;
  static const encounterMinDistance = 90.0;
  static const encounterMaxDistance = 160.0;
  static const approachDuration = 1.1;
  static const deathDuration = .8;
  static const rewardDuration = .9;
  static const heroDeathFrameTime = .4;
  static const heroDeathLastFrameDuration = 1.0;
  // The final death frame already plays for one step before RESPAWN holds it.
  static const respawnDuration =
      heroDeathLastFrameDuration - heroDeathFrameTime;
  static const attackDuration = .6;
  static const damageTiming = .35;
  static const hitDuration = .18;
  static const hpGrowth = 1.08;
  static const damageGrowth = 1.065;
  static const rewardGrowth = 1.07;
  static const tierDistance = 500.0;
  static const tierKills = 12;
  static const baseXp = 45.0;
  static const xpGrowth = 1.12;
  static const levelStatGrowth = 1.015;
  static const upgradeGrowth = 1.05;
  static const critChanceCap = .8;
  static const attackSpeedCap = 5.0;
  static const softCapRate = .035;
  static const critDamageBonus = .035;
  static const idleThresholds = [30.0, 120.0, 300.0];
  static const caughtDuration = .65;
  static const idleMovementMultipliers = [1.0, 1.0, 1.0, 1.0];
  static const idleDpsMultipliers = [1.0, 1.0, 1.0, 1.0];
  static const idleRewardMultipliers = [1.0, 1.0, 1.0, 1.0];
  static const saveInterval = Duration(minutes: 1);
  static const activityPollInterval = Duration(seconds: 1);
  static const fixedStep = 1 / 60;
  static const maxCatchupSeconds = 5.0;
  static const viewportWidth = 400.0;
  static const viewportHeight = 190.0;
  static const panelHeight = 620.0;
}
