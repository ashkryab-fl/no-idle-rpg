import 'dart:math';
import '../../content/animations/animation_resources.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/animation/playback_snapshot.dart';
import '../../core/animation/graph/graph_definition.dart';
import '../animation/hero_animation_coordinator.dart';
import '../animation/enemy_animation_coordinator.dart';
import '../../core/balance/game_balance.dart';
import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../../domain/activity/activity_statistics.dart';
import '../../domain/activity/rest_coordinator.dart';
import '../../domain/character/character.dart';
import '../../domain/economy/reward.dart';
import '../../domain/settings.dart';
import '../../domain/equipment/equipment_purchase.dart';
import '../../core/balance/equipment_curve_profile.dart';
import 'combat_system.dart';
import '../../core/balance/talent_profile.dart';
import '../../domain/talents/talents.dart';
import '../../domain/adventure/stage_attempt.dart';
import '../../domain/adventure/stage_settlement.dart';
import '../../domain/adventure/adventure_checkpoint.dart';
import 'enemy_spawner.dart';
import 'game_state_machine.dart';

class VisualEvent {
  VisualEvent(this.kind, {this.damage, this.reward});
  final String kind;
  final DamageEvent? damage;
  final Reward? reward;
}

abstract class DeathPolicy {
  void onDeath(CharacterProgress progress);
}

class NoDeathPenalty implements DeathPolicy {
  const NoDeathPenalty();
  @override
  void onDeath(CharacterProgress progress) {}
}

class GameSimulation {
  GameSimulation({
    this.curveProfile = EquipmentCurveProfile.candidate,
    Random? random,
    Random? idleRandom,
    Random? travelRandom,
    Random? selectionRandom,
    this.talentProfile = TalentProfile.candidate,
    AnimationResources? resources,
    AnimationGraphDefinition? restGraph,
    CharacterProgress? character,
    ActivityStatisticsService? activity,
    GameSettings? settings,
    this.deathPolicy = const NoDeathPenalty(),
  }) : random = random ?? Random(),
       resources = resources ?? defaultAnimationResources(),
       character = character ?? CharacterProgress(),
       activity = activity ?? ActivityStatisticsService(),
       settings = settings ?? GameSettings() {
    spawner = EnemySpawner(
      selectionRandom ?? Random(this.random.nextInt(1 << 32)),
      travelRandom: travelRandom ?? Random(this.random.nextInt(1 << 32)),
    );
    talentPurchases = TalentPurchases(profile: talentProfile);
    settlement = StageSettlement(profile: talentProfile);
    final rest = RestCoordinator(
      idleRandom ?? Random(this.random.nextInt(1 << 32)),
      this.resources,
      graph: restGraph,
    );
    heroAnimations = HeroAnimationCoordinator(this.resources, rest: rest);
    enemyAnimations = EnemyAnimationCoordinator(this.resources);
    combat = CombatSystem(
      this.random,
      heroPlayback: heroAnimations.combatPlayback,
      enemyPlayback: enemyAnimations.combatPlayback,
    );
    purchases = EquipmentPurchases(profile: curveProfile);
    heroHp = stats.maxHp;
    encounterRemaining = 0;
    machine.transition(GamePhase.traveling);
  }
  final Random random;
  final AnimationResources resources;
  final CharacterProgress character;
  final ActivityStatisticsService activity;
  final GameSettings settings;
  final DeathPolicy deathPolicy;
  final machine = GameStateMachine();
  final EquipmentCurveProfile curveProfile;
  late final EquipmentPurchases purchases;
  late final EnemySpawner spawner;
  late final CombatSystem combat;
  final TalentProfile talentProfile;
  late final TalentPurchases talentPurchases;
  late final StageSettlement settlement;
  StageAttempt? activeAttempt;
  StageAttempt? _enemyAttempt;
  int _enemyWave = 0;
  bool _needsTravelTarget = true;
  late final HeroAnimationCoordinator heroAnimations;
  late final EnemyAnimationCoordinator enemyAnimations;
  RestCoordinator get idle => heroAnimations.rest;
  late Amount heroHp;
  Enemy? enemy;
  Reward? lastReward;
  double distance = 0, scroll = 0, encounterRemaining = 0;
  double heroHitRemaining = 0, enemyHitRemaining = 0;
  int kills = 0;
  int stage = 1;
  int stageKills = 0;
  double speed = 1;
  bool hitboxes = false;
  final List<VisualEvent> events = [];
  double _accumulator = 0;
  double _enemySpawnDistance = 0;
  double get _approachRemaining => max(
    0,
    GameBalance.enemyApproachDistance - (distance - _enemySpawnDistance),
  );
  // The enemy stands in the world; the camera moves it by the same distance
  // that scrolls the scenery and road, including the final approach tick.
  double get enemyX =>
      GameBalance.enemySpawnX - (distance - _enemySpawnDistance);
  CombatStats get stats =>
      CharacterStats.calculate(character, profile: curveProfile);
  GamePhase get phase => machine.phase;
  int get wave => stageKills + 1;
  bool get isBossWave => wave == ProgressionBalance.enemiesPerStage;
  int get enemyTier => stage - 1;
  bool get isResting => phase == GamePhase.traveling && idle.blocksAdventure;
  double get movementMultiplier =>
      GameBalance.idleMovementMultipliers[idle.level.index];
  double get dpsMultiplier =>
      ProgressionBalance.idleDpsMultipliers[idle.level.index];
  double get rewardMultiplier =>
      ProgressionBalance.idleRewardMultipliers[idle.level.index];
  double get scrollSpeed => isResting
      ? 0
      : phase == GamePhase.traveling || phase == GamePhase.enemyApproach
      ? GameBalance.movementSpeed * movementMultiplier
      : 0;
  void advance(double seconds) {
    // Discard suspend gaps: rewards only come from running simulation ticks.
    if (!seconds.isFinite ||
        seconds > GameBalance.maxCatchupSeconds ||
        seconds < 0) {
      return;
    }
    _accumulator += seconds * speed;
    // Floating-point partitions must not lose a tick at x5/x20 boundaries.
    // Keep the tiny residual debt so tolerance never adds elapsed time.
    while (_accumulator + 1e-12 >= GameBalance.fixedStep) {
      _tick(GameBalance.fixedStep);
      _accumulator -= GameBalance.fixedStep;
    }
  }

  void _tick(double dt) {
    _synchronizeAnimations();
    final travelTime = heroAnimations.advance(dt);
    enemyAnimations.advance(dt);
    heroHitRemaining = max(0, heroHitRemaining - dt);
    enemyHitRemaining = max(0, enemyHitRemaining - dt);
    machine.elapsed += dt;
    if (phase == GamePhase.traveling &&
        travelTime > 0 &&
        !idle.blocksAdventure) {
      _prepareTravel();
    }
    final movement = phase == GamePhase.traveling
        ? GameBalance.movementSpeed * movementMultiplier * travelTime
        : phase == GamePhase.enemyApproach
        ? min(scrollSpeed * dt, _approachRemaining)
        : 0.0;
    distance += movement;
    scroll = (scroll + movement) % GameBalance.viewportWidth;
    switch (phase) {
      case GamePhase.boot:
        break;
      case GamePhase.traveling:
        encounterRemaining -= movement;
        if (!_needsTravelTarget && encounterRemaining <= 0) spawnEnemy();
      case GamePhase.enemyApproach:
        if (_approachRemaining <= 1e-9) {
          combat.reset();
          machine.transition(GamePhase.combat);
        }
      case GamePhase.combat:
        final foe = enemy!;
        for (final event in combat.update(
          dt,
          stats,
          foe.stats,
          dpsMultiplier,
          effects: activeAttempt?.effects,
          isBoss: foe.isBoss,
        )) {
          if (phase != GamePhase.combat) break;
          events.add(VisualEvent('hit', damage: event));
          if (event.fromHero) {
            foe.hp = foe.hp - event.amount;
            enemyHitRemaining = GameBalance.hitDuration;
            if (foe.hp.isZero) machine.transition(GamePhase.enemyDeath);
          } else {
            heroHp = heroHp - event.amount;
            heroHitRemaining = GameBalance.hitDuration;
            if (heroHp.isZero) {
              _heroDied();
            }
          }
          if (phase != GamePhase.combat) break;
        }
      case GamePhase.enemyDeath:
        if (enemyAnimations.deathCompleted) {
          final result = settlement.settle(
            character,
            _enemyAttempt!,
            _enemyWave,
            hp: heroHp,
            maxHp: stats.maxHp,
            killMultiplier: rewardMultiplier,
          );
          if (result.applied) {
            lastReward = result.reward;
            heroHp = result.hp;
            kills++;
            stageKills++;
            if (stageKills >= ProgressionBalance.enemiesPerStage) {
              stage++;
              stageKills = 0;
              activeAttempt = null;
            }
            events.add(VisualEvent('reward', reward: lastReward));
          }
          machine.transition(GamePhase.reward);
        }
      case GamePhase.reward:
        if (machine.elapsed >= GameBalance.rewardDuration) _travel();
      case GamePhase.heroDeath:
        if (heroAnimations.deathCompleted) {
          machine.transition(GamePhase.respawn);
          machine.elapsed = travelTime;
        }
      case GamePhase.respawn:
        if (machine.elapsed >= GameBalance.respawnDuration) {
          heroHp = stats.maxHp;
          _travel();
        }
    }
    _synchronizeAnimations();
    // A renderer is optional; bound the event queue for headless simulation.
    if (events.length > 100) events.removeRange(0, events.length - 100);
  }

  /// Apply a purchase and restore only the actual increase in max HP.
  /// Dead heroes stay at zero until the normal respawn boundary.
  int purchaseEquipment(String id, {int? count = 1}) {
    final oldMax = stats.maxHp;
    final bought = purchases.purchase(character, id, count: count);
    if (bought > 0 && !heroHp.isZero) {
      final newMax = stats.maxHp;
      final restored = heroHp + (newMax - oldMax);
      heroHp = restored > newMax ? newMax : restored;
    }
    return bought;
  }

  void resetEncounter() {
    heroAnimations.reset();
    enemyAnimations.reset();
    enemy = null;
    _enemyAttempt = null;
    _enemyWave = 0;
    lastReward = null;
    events.clear();
    combat.reset();
    machine.phase = GamePhase.boot;
    machine.transition(GamePhase.traveling);
    activeAttempt = null;
    _needsTravelTarget = true;
    encounterRemaining = 0;
    heroHitRemaining = 0;
    enemyHitRemaining = 0;
    _accumulator = 0;
  }

  void _travel() {
    enemy = null;
    _enemyAttempt = null;
    _enemyWave = 0;
    _needsTravelTarget = true;
    encounterRemaining = 0;
    machine.transition(GamePhase.traveling);
  }

  void spawnEnemy() {
    if (phase != GamePhase.traveling || isResting) return;
    _prepareTravel();
    _enemyAttempt = activeAttempt;
    _enemyWave = wave;
    enemy = spawner.planned(_enemyAttempt!, _enemyWave);
    _enemySpawnDistance = distance;
    machine.transition(GamePhase.enemyApproach);
    _synchronizeAnimations();
  }

  void killEnemy() {
    if (enemy != null &&
        (phase == GamePhase.combat || phase == GamePhase.enemyApproach)) {
      enemy!.hp = Amount.zero;
      machine.transition(GamePhase.enemyDeath);
      _synchronizeAnimations();
    }
  }

  void killHero() {
    if (phase == GamePhase.heroDeath || phase == GamePhase.respawn) return;
    heroHp = Amount.zero;
    _heroDied();
  }

  void _heroDied() {
    if (activeAttempt != null) {
      character.talents.abandonAttempt(activeAttempt!.id);
    }
    deathPolicy.onDeath(character);
    activeAttempt = null;
    _needsTravelTarget = true;
    if (stage > 1) stage--;
    stageKills = 0;
    machine.transition(GamePhase.heroDeath);
    _synchronizeAnimations();
  }

  void _prepareTravel() {
    activeAttempt ??= StageAttempt.begin(
      character.talents,
      stage,
      spawner.plan(stage),
      profile: talentProfile,
    );
    if (_needsTravelTarget) {
      encounterRemaining =
          activeAttempt!.encounters[stageKills].distance *
          (1 - activeAttempt!.effects['shorter_travel']);
      _needsTravelTarget = false;
    }
  }

  int purchaseTalent(String id, {int? count = 1}) =>
      talentPurchases.purchase(character, id, count: count);
  void selectTalent(TalentPair pair, String? id) =>
      talentPurchases.select(character, pair, id);

  AdventureCheckpoint captureAdventure() => AdventureCheckpoint(
    hp: heroHp,
    attempt: activeAttempt,
    phase: phase.name,
    elapsed: machine.elapsed,
    travelRemaining: max(0, encounterRemaining),
    needsTravelTarget: _needsTravelTarget,
    lastReward: lastReward,
  );

  void restoreAdventure(AdventureCheckpoint checkpoint) {
    heroAnimations.reset();
    enemyAnimations.reset();
    combat.reset();
    enemy = null;
    _enemyAttempt = null;
    _enemyWave = 0;
    events.clear();
    _accumulator = 0;
    heroHitRemaining = enemyHitRemaining = 0;
    heroHp = checkpoint.hp;
    activeAttempt = checkpoint.attempt;
    _needsTravelTarget = checkpoint.needsTravelTarget;
    encounterRemaining = checkpoint.travelRemaining;
    lastReward = checkpoint.lastReward;
    machine.phase = GamePhase.values.byName(checkpoint.phase);
    machine.elapsed = checkpoint.elapsed;
    // Combat resumes at the same planned wave with fresh enemy HP and saved hero HP.
    // A killed enemy remains unsettled; a committed reward only resumes its hold.
    if (phase == GamePhase.combat ||
        phase == GamePhase.enemyApproach ||
        phase == GamePhase.enemyDeath) {
      _enemyAttempt = activeAttempt;
      _enemyWave = wave;
      enemy = spawner.planned(_enemyAttempt!, _enemyWave);
      _enemySpawnDistance = distance - GameBalance.enemyApproachDistance;
      if (phase == GamePhase.enemyDeath) {
        enemy!.hp = Amount.zero;
      } else {
        machine.phase = GamePhase.combat;
      }
      machine.elapsed = 0;
    }
    _synchronizeAnimations();
  }

  void _synchronizeAnimations() {
    heroAnimations.combatPeriod = 1 / stats.attackSpeed;
    heroAnimations.synchronize(switch (phase) {
      GamePhase.heroDeath => HeroAnimationRequest.death,
      GamePhase.respawn => HeroAnimationRequest.respawn,
      GamePhase.combat => HeroAnimationRequest.combat,
      GamePhase.traveling => HeroAnimationRequest.travel,
      GamePhase.enemyApproach => HeroAnimationRequest.approach,
      _ => HeroAnimationRequest.idle,
    });
    enemyAnimations.combatPeriod = enemy == null
        ? 1
        : 1 / enemy!.stats.attackSpeed;
    enemyAnimations.synchronize(enemy?.definition.animations, switch (phase) {
      GamePhase.enemyDeath || GamePhase.reward => EnemyAnimationRequest.death,
      GamePhase.combat => EnemyAnimationRequest.combat,
      _ => EnemyAnimationRequest.idle,
    });
  }

  PlaybackSnapshot get heroPlayback {
    return heroAnimations.snapshot.withDamageFlash(heroHitRemaining > 0);
  }

  PlaybackSnapshot? get enemyPlayback {
    return enemyAnimations.snapshot?.withDamageFlash(enemyHitRemaining > 0);
  }
}
