class GameBalance {
  const GameBalance();
  static const movementSpeed = 32.0;
  static const encounterMinDistance = 90.0;
  static const encounterMaxDistance = 160.0;
  static const enemySpawnX = 386.0;
  static const enemyCombatX = 254.0;
  static const enemyApproachDistance = enemySpawnX - enemyCombatX;
  static const approachDuration = enemyApproachDistance / movementSpeed;
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
  static const idleThresholds = [30.0, 120.0, 300.0];
  static const idleMovementMultipliers = [1.0, 1.0, 1.0, 1.0];
  static const saveInterval = Duration(minutes: 1);
  static const activityPollInterval = Duration(seconds: 1);
  static const fixedStep = 1 / 60;
  static const maxCatchupSeconds = 5.0;
  static const viewportWidth = 400.0;
  static const viewportHeight = 190.0;
  static const actorGroundY = 179.0;
  static const roadTop = 166.0;
  static const roadHeight = 24.0;
  static const heroHitboxHeight = 96.0;
  static const panelHeight = 620.0;
}
