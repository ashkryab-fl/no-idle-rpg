import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/enemies/procedural_timelines.dart';
import 'package:idle_companion/core/animation/animation_clip.dart';
import 'package:idle_companion/core/animation/attack_playback.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/balance/progression_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/progression/infinite_upgrade.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/drop_system.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';
import 'package:idle_companion/game/systems/progression_system.dart';

/// Event-driven model: real hits/crit/rewards/XP/prices, no frame/render ticks.
/// The player invests after combat about once per active hour, splitting each
/// currency 37.5/37.5/15/10% between damage, HP, crit and crit damage.
/// Idle/offline intervals are excluded. This is a tuning model, not a playtest.
class ProgressionSimulation {
  ProgressionSimulation({
    int seed = 1,
    this.goldCostGrowth = ProgressionBalance.equipmentCostGrowth,
    this.bookCostGrowth = ProgressionBalance.bookUpgradeCostGrowth,
    this.upgradeInterval = 3600,
  }) : random = Random(seed) {
    spawner = EnemySpawner(random);
    combat = CombatSystem(
      random,
      heroPlayback: AttackPlayback(resources.clip(const ClipId('hero.attack'))),
      enemyPlayback: AttackPlayback(ProceduralEnemyTimelines.attack),
    );
    drops = DropSystem(random);
    stats = CharacterStats.calculate(hero);
    hp = stats.maxHp;
  }

  final double goldCostGrowth, bookCostGrowth, upgradeInterval;
  final Random random;
  final hero = CharacterProgress();
  final progression = ProgressionSystem();
  final resources = defaultAnimationResources();
  late final EnemySpawner spawner;
  late final CombatSystem combat;
  late final DropSystem drops;
  late CombatStats stats;
  late Amount hp;
  int stage = 1, stageKills = 0, kills = 0, deaths = 0;
  double elapsed = 0, _nextUpgrade = 0;
  final _firstEntry = <int, double>{1: 0};
  final firstClearSeconds = <double>[];
  final killSeconds = <double>[];

  void runUntil(double deadline) {
    while (elapsed < deadline) {
      if (elapsed >= _nextUpgrade) {
        _invest();
        _nextUpgrade = elapsed + upgradeInterval;
      }
      final travel =
          spawner.nextDistance() / GameBalance.movementSpeed +
          GameBalance.approachDuration;
      if (elapsed + travel >= deadline) {
        elapsed = deadline;
        return;
      }
      elapsed += travel;
      final enemy = spawner.spawn(
        stage - 1,
        isBoss: stageKills + 1 == ProgressionBalance.enemiesPerStage,
      );
      final start = elapsed;
      final heroPeriod = 1 / stats.attackSpeed;
      final enemyPeriod = 1 / enemy.stats.attackSpeed;
      final heroAttack = resources.clip(const ClipId('hero.attack'));
      final enemyAttack = enemy.definition.animations.attack(resources);
      double firstHit(AnimationClipDefinition clip, double period) =>
          clip.markers
              .firstWhere((m) => m.kind == AnimationMarkerKind.damage)
              .time *
          min(1, period / clip.duration);
      var nextHero = firstHit(heroAttack, heroPeriod);
      var nextEnemy = firstHit(enemyAttack, enemyPeriod);
      var finished = false;
      while (!finished) {
        final fromHero = nextHero <= nextEnemy;
        final hitTime = fromHero ? nextHero : nextEnemy;
        if (start + hitTime >= deadline) {
          elapsed = deadline;
          return;
        }
        elapsed = start + hitTime;
        final hit = combat.calculate(fromHero ? stats : enemy.stats, fromHero);
        if (fromHero) {
          enemy.hp = enemy.hp - hit.amount;
          nextHero += heroPeriod;
          if (enemy.hp.isZero) {
            final reward = drops.roll(enemy);
            hero.gold = hero.gold + reward.gold;
            hero.books = hero.books + reward.books;
            final levels = progression.addXp(hero, reward.xp);
            if (levels > 0) {
              stats = CharacterStats.calculate(hero);
              hp = stats.maxHp;
            }
            elapsed +=
                enemy.definition.animations.death(resources).duration +
                GameBalance.rewardDuration;
            kills++;
            killSeconds.add(hitTime);
            if (killSeconds.length > 200) killSeconds.removeAt(0);
            stageKills++;
            if (stageKills == ProgressionBalance.enemiesPerStage) {
              stage++;
              stageKills = 0;
              if (!_firstEntry.containsKey(stage)) {
                firstClearSeconds.add(elapsed - _firstEntry[stage - 1]!);
                _firstEntry[stage] = elapsed;
              }
            }
            finished = true;
          }
        } else {
          hp = hp - hit.amount;
          nextEnemy += enemyPeriod;
          if (hp.isZero) {
            deaths++;
            stage = max(1, stage - 1);
            stageKills = 0;
            elapsed +=
                resources.clip(const ClipId('hero.death')).duration +
                GameBalance.respawnDuration;
            hp = stats.maxHp;
            finished = true;
          }
        }
      }
    }
  }

  void _invest() {
    final oldHp = stats.maxHp;
    const shares = [0.375, 0.375, 0.15, 0.10];
    final gold = hero.gold, books = hero.books;
    // Equipment catalog order is damage, HP, crit, crit damage here.
    final equipment = ['weapon', 'armor', 'helmet', 'amulet'];
    for (var i = 0; i < shares.length; i++) {
      for (final isEquipment in [true, false]) {
        final source = isEquipment
            ? EquipmentCatalog.items.firstWhere(
                (item) => item.id == equipment[i],
              )
            : UpgradeCatalog.character[i];
        final item = InfiniteUpgradeDefinition(
          id: source.id,
          name: source.name,
          stat: source.stat,
          baseCost: source.baseCost,
          costGrowth: isEquipment ? goldCostGrowth : bookCostGrowth,
          curve: source.curve,
          valueGrowth: source.valueGrowth,
          softCapRate: source.softCapRate,
          bonusPerLevel: source.bonusPerLevel,
        );
        final levels = isEquipment ? hero.equipment : hero.upgrades;
        final count = item.affordable(
          levels[item.id] ?? 0,
          (isEquipment ? gold : books).scale(shares[i]),
        );
        progression.upgrade(hero, item, equipment: isEquipment, count: count);
      }
    }
    stats = CharacterStats.calculate(hero);
    hp = hp + (stats.maxHp - oldHp);
  }

  static double median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    return sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
  }

  Map<String, Object> snapshot(int day) => {
    'day': day,
    'stage': stage,
    'highestStage': _firstEntry.keys.last,
    'characterLevel': hero.level,
    'kills': kills,
    'deaths': deaths,
    'medianRecentStageSeconds': median(
      firstClearSeconds.skip(max(0, firstClearSeconds.length - 20)),
    ),
    'medianRecentKillSeconds': median(killSeconds),
    'weapon': hero.equipment['weapon'] ?? 0,
    'bookDamage': hero.upgrades['damage'] ?? 0,
  };
}

void main(List<String> args) {
  double option(String name, double fallback) {
    final index = args.indexOf(name);
    return index < 0 ? fallback : double.parse(args[index + 1]);
  }

  final hours = option('--hours-per-day', 8);
  final seeds = option('--seeds', 3).toInt();
  final days = option('--days', 30).toInt();
  final goldGrowth = option(
    '--gold-cost-growth',
    ProgressionBalance.equipmentCostGrowth,
  );
  final bookGrowth = option(
    '--book-cost-growth',
    ProgressionBalance.bookUpgradeCostGrowth,
  );
  final checkpoints = [
    1,
    7,
    14,
    days,
  ].where((day) => day <= days).toSet().toList()..sort();
  final rows = <Map<String, Object>>[];
  for (var seed = 1; seed <= seeds; seed++) {
    // Run each checkpoint from the same start so interrupted fights cannot
    // change results at a later checkpoint.
    for (final day in checkpoints) {
      final sim = ProgressionSimulation(
        seed: seed,
        goldCostGrowth: goldGrowth,
        bookCostGrowth: bookGrowth,
      );
      sim.runUntil(day * hours * 3600);
      rows.add({'seed': seed, ...sim.snapshot(day)});
    }
  }
  stdout.writeln(
    jsonEncode({
      'hoursPerDay': hours,
      'goldCostGrowth': goldGrowth,
      'bookCostGrowth': bookGrowth,
      'rows': rows,
    }),
  );
}
