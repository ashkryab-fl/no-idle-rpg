import 'dart:math';
import '../../core/assets/animation_catalog.dart';
import '../../core/animation/playback_snapshot.dart';
import '../animation/hero_animation_coordinator.dart';
import '../animation/enemy_animation_coordinator.dart';
import '../../core/balance/game_balance.dart';
import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../../domain/activity/activity_statistics.dart';
import '../../domain/activity/idle_animation.dart';
import '../../domain/character/character.dart';
import '../../domain/economy/reward.dart';
import '../../domain/settings.dart';
import 'combat_system.dart';
import 'drop_system.dart';
import 'enemy_spawner.dart';
import 'game_state_machine.dart';
import 'progression_system.dart';

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
    Random? random,
    Random? idleRandom,
    AnimationCatalog? animations,
    List<IdleAnimationDefinition>? idleDefinitions,
    CharacterProgress? character,
    ActivityStatisticsService? activity,
    GameSettings? settings,
    this.deathPolicy = const NoDeathPenalty(),
  }) : random = random ?? Random(),
       animations = animations ?? AnimationCatalog(),
       character = character ?? CharacterProgress(),
       activity = activity ?? ActivityStatisticsService(),
       settings = settings ?? GameSettings() {
    spawner = EnemySpawner(this.random);
    drops = DropSystem(this.random);
    final rest = IdleBehaviorSystem(
      idleRandom ?? Random(this.random.nextInt(1 << 32)),
      this.animations,
      definitions: idleDefinitions,
    );
    heroAnimations = HeroAnimationCoordinator(
      this.animations.resources,
      rest: rest,
    );
    enemyAnimations = EnemyAnimationCoordinator(this.animations.resources);
    combat = CombatSystem(
      this.random,
      this.animations,
      heroPlayback: heroAnimations.combatPlayback,
      enemyPlayback: enemyAnimations.combatPlayback,
    );
    heroHp = stats.maxHp;
    encounterRemaining = spawner.nextDistance();
    machine.transition(GamePhase.traveling);
  }
  final Random random;
  final AnimationCatalog animations;
  final CharacterProgress character;
  final ActivityStatisticsService activity;
  final GameSettings settings;
  final DeathPolicy deathPolicy;
  final machine = GameStateMachine();
  final progression = ProgressionSystem();
  late final EnemySpawner spawner;
  late final CombatSystem combat;
  late final DropSystem drops;
  late final HeroAnimationCoordinator heroAnimations;
  late final EnemyAnimationCoordinator enemyAnimations;
  IdleBehaviorSystem get idle => heroAnimations.rest;
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
  CombatStats get stats => CharacterStats.calculate(character);
  GamePhase get phase => machine.phase;
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
      : phase == GamePhase.traveling
      ? GameBalance.movementSpeed * movementMultiplier
      : phase == GamePhase.enemyApproach
      ? GameBalance.movementSpeed *
            movementMultiplier *
            (1 - machine.elapsed / GameBalance.approachDuration).clamp(0, 1)
      : 0;
  void advance(double seconds) {
    // Drop long suspend gaps. OfflineProgressService owns that interval.
    if (!seconds.isFinite ||
        seconds > GameBalance.maxCatchupSeconds ||
        seconds < 0) {
      return;
    }
    _accumulator += seconds * speed;
    while (_accumulator >= GameBalance.fixedStep) {
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
    final movement = phase == GamePhase.traveling
        ? GameBalance.movementSpeed * movementMultiplier * travelTime
        : scrollSpeed * dt;
    distance += movement;
    scroll = (scroll + movement) % GameBalance.viewportWidth;
    switch (phase) {
      case GamePhase.boot:
        break;
      case GamePhase.traveling:
        encounterRemaining -= movement;
        if (encounterRemaining <= 0) spawnEnemy();
      case GamePhase.enemyApproach:
        if (machine.elapsed >= GameBalance.approachDuration) {
          combat.reset();
          machine.transition(GamePhase.combat);
        }
      case GamePhase.combat:
        final foe = enemy!;
        for (final event in combat.update(
          dt,
          stats,
          foe.stats,
          foe.definition.animations,
          dpsMultiplier,
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
        }
      case GamePhase.enemyDeath:
        if (enemyAnimations.deathCompleted) {
          lastReward = drops.roll(enemy!, multiplier: rewardMultiplier);
          character.gold = character.gold + lastReward!.gold;
          character.books = character.books + lastReward!.books;
          final levels = progression.addXp(character, lastReward!.xp);
          if (levels > 0) heroHp = stats.maxHp;
          kills++;
          stageKills++;
          if (stageKills >= ProgressionBalance.enemiesPerStage) {
            stage++;
            stageKills = 0;
          }
          events.add(VisualEvent('reward', reward: lastReward));
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

  void resetEncounter() {
    heroAnimations.reset();
    enemyAnimations.reset();
    enemy = null;
    lastReward = null;
    events.clear();
    combat.reset();
    machine.phase = GamePhase.boot;
    machine.transition(GamePhase.traveling);
    encounterRemaining = spawner.nextDistance();
    heroHitRemaining = 0;
    enemyHitRemaining = 0;
    _accumulator = 0;
  }

  void _travel() {
    enemy = null;
    encounterRemaining = spawner.nextDistance();
    machine.transition(GamePhase.traveling);
  }

  void spawnEnemy() {
    if (phase != GamePhase.traveling || isResting) return;
    enemy = spawner.spawn(enemyTier);
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
    deathPolicy.onDeath(character);
    if (stage > 1) stage--;
    stageKills = 0;
    machine.transition(GamePhase.heroDeath);
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

  // Compatibility presentation APIs. Rendering now consumes snapshots only.
  String get heroAnimation {
    _synchronizeAnimations();
    return heroPlayback.displayLabel;
  }

  String? get enemyAnimation {
    _synchronizeAnimations();
    return enemyPlayback?.displayLabel;
  }

  double heroAnimationElapsed() {
    _synchronizeAnimations();
    return heroPlayback.graphId != null
        ? idle.animationElapsed
        : heroPlayback.elapsed;
  }

  double enemyAnimationElapsed() {
    _synchronizeAnimations();
    return enemyPlayback?.elapsed ?? 0;
  }
}
