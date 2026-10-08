import 'dart:math';
import '../../core/assets/animation_catalog.dart';
import '../../core/balance/game_balance.dart';
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
    combat = CombatSystem(this.random, this.animations);
    drops = DropSystem(this.random);
    idle = IdleBehaviorSystem(
      idleRandom ?? Random(this.random.nextInt(1 << 32)),
      this.animations,
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
  late final IdleBehaviorSystem idle;
  late Amount heroHp;
  Enemy? enemy;
  Reward? lastReward;
  double distance = 0, scroll = 0, encounterRemaining = 0;
  double heroHitRemaining = 0, enemyHitRemaining = 0;
  int kills = 0;
  double speed = 1;
  bool hitboxes = false;
  final List<VisualEvent> events = [];
  double _accumulator = 0;
  CombatStats get stats => CharacterStats.calculate(character);
  GamePhase get phase => machine.phase;
  double get movementMultiplier =>
      GameBalance.idleMovementMultipliers[idle.level.index];
  double get dpsMultiplier => GameBalance.idleDpsMultipliers[idle.level.index];
  double get rewardMultiplier =>
      GameBalance.idleRewardMultipliers[idle.level.index];
  double get scrollSpeed => phase == GamePhase.traveling
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
    idle.update(dt);
    heroHitRemaining = max(0, heroHitRemaining - dt);
    enemyHitRemaining = max(0, enemyHitRemaining - dt);
    machine.elapsed += dt;
    final movement = scrollSpeed * dt;
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
            enemyHitRemaining = animations
                .get('${foe.definition.animations}.hit')
                .duration;
            if (foe.hp.isZero) machine.transition(GamePhase.enemyDeath);
          } else {
            heroHp = heroHp - event.amount;
            heroHitRemaining = animations.get('hero.hit').duration;
            if (heroHp.isZero) {
              deathPolicy.onDeath(character);
              machine.transition(GamePhase.heroDeath);
            }
          }
        }
      case GamePhase.enemyDeath:
        if (machine.elapsed >=
            animations.get('${enemy!.definition.animations}.death').duration) {
          lastReward = drops.roll(enemy!, multiplier: rewardMultiplier);
          character.gold = character.gold + lastReward!.gold;
          character.books = character.books + lastReward!.books;
          final levels = progression.addXp(character, lastReward!.xp);
          if (levels > 0) heroHp = stats.maxHp;
          kills++;
          events.add(VisualEvent('reward', reward: lastReward));
          machine.transition(GamePhase.reward);
        }
      case GamePhase.reward:
        if (machine.elapsed >= GameBalance.rewardDuration) _travel();
      case GamePhase.heroDeath:
        if (machine.elapsed >= animations.get('hero.death').duration) {
          machine.transition(GamePhase.respawn);
        }
      case GamePhase.respawn:
        if (machine.elapsed >= GameBalance.respawnDuration) {
          heroHp = stats.maxHp;
          _travel();
        }
    }
    // A renderer is optional; bound the event queue for headless simulation.
    if (events.length > 100) events.removeRange(0, events.length - 100);
  }

  void resetEncounter() {
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
    if (phase != GamePhase.traveling) return;
    enemy = spawner.spawn(distance, kills);
    machine.transition(GamePhase.enemyApproach);
  }

  void killEnemy() {
    if (enemy != null &&
        (phase == GamePhase.combat || phase == GamePhase.enemyApproach)) {
      enemy!.hp = Amount.zero;
      machine.transition(GamePhase.enemyDeath);
    }
  }

  void killHero() {
    if (phase == GamePhase.heroDeath || phase == GamePhase.respawn) return;
    heroHp = Amount.zero;
    machine.transition(GamePhase.heroDeath);
  }

  String get heroAnimation {
    if (phase == GamePhase.heroDeath || phase == GamePhase.respawn) {
      return 'hero.death';
    }
    if (idle.animationId != null) return idle.animationId!;
    if (heroHitRemaining > 0) return 'hero.hit';
    if (phase == GamePhase.combat && combat.attacking(true, stats, 'hero')) {
      return 'hero.attack';
    }
    return phase == GamePhase.traveling || phase == GamePhase.enemyApproach
        ? 'hero.walk'
        : 'hero.idle';
  }

  String? get enemyAnimation {
    if (enemy == null) return null;
    final prefix = enemy!.definition.animations;
    if (phase == GamePhase.enemyDeath || phase == GamePhase.reward) {
      return '$prefix.death';
    }
    if (enemyHitRemaining > 0) return '$prefix.hit';
    if (phase == GamePhase.combat &&
        combat.attacking(false, enemy!.stats, prefix)) {
      return '$prefix.attack';
    }
    return '$prefix.idle';
  }

  double heroAnimationElapsed() {
    if (phase == GamePhase.respawn) {
      return animations.get('hero.death').duration;
    }
    if (heroAnimation == idle.animationId) return idle.animationElapsed;
    if (heroAnimation == 'hero.attack') {
      return combat.attackElapsed(true, stats, 'hero');
    }
    if (heroAnimation == 'hero.hit') {
      return animations.get('hero.hit').duration - heroHitRemaining;
    }
    return machine.elapsed;
  }

  double enemyAnimationElapsed() {
    if (phase == GamePhase.reward && enemy != null) {
      return animations.get('${enemy!.definition.animations}.death').duration;
    }
    if (enemyAnimation?.endsWith('.attack') ?? false) {
      return combat.attackElapsed(
        false,
        enemy!.stats,
        enemy!.definition.animations,
      );
    }
    if (enemyAnimation?.endsWith('.hit') ?? false) {
      return animations.get('${enemy!.definition.animations}.hit').duration -
          enemyHitRemaining;
    }
    return machine.elapsed;
  }
}
