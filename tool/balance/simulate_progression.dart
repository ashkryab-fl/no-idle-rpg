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
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/drop_system.dart';
import 'package:idle_companion/game/systems/enemy_spawner.dart';

export 'package:idle_companion/game/systems/combat_system.dart'
    show DamageEvent;

enum InvestmentStrategy {
  balanced,
  adaptive,
  noPurchases,
  weaponOnly,
  armorOnly,
  helmetOnly,
  amuletOnly,
  omitWeapon,
  omitArmor,
  omitHelmet,
  omitAmulet,
}

/// Diagnostic inputs, separate from production rewards and future talent rules.
class IncomeStress {
  const IncomeStress({
    this.id = 'current_income',
    this.killGoldMultiplier = 1,
    this.stageGoldBonus = 0,
    this.firstClearGoldBonus = 0,
    this.travelFactor = 1,
  });
  final String id;
  final double killGoldMultiplier,
      stageGoldBonus,
      firstClearGoldBonus,
      travelFactor;
  Map<String, Object> toJson() => {
    'id': id,
    'killGoldMultiplier': killGoldMultiplier,
    'stageGoldBonus': stageGoldBonus,
    'firstClearGoldBonus': firstClearGoldBonus,
    'travelFactor': travelFactor,
  };
}

/// Discrete attacks and phase boundaries, using the game's stats and catalogs.
/// Productive time excludes rest/offline time. Purchases occur between encounters.
/// Pending events survive checkpoints: an unconfirmed kill earns no reward.
class ProgressionSimulation {
  ProgressionSimulation({
    int seed = 1,
    Random? random,
    CharacterProgress? character,
    List<EnemyDefinition>? definitions,
    this.curveProfile = EquipmentCurveProfile.candidate,
    this.income = const IncomeStress(),
    this.upgradeInterval = 3600,
    this.strategy = InvestmentStrategy.balanced,
    this.onEncounter,
    this.onRecovery,
    this.onPurchase,
  }) : random = random ?? Random(seed),
       hero = character ?? CharacterProgress() {
    spawner = EnemySpawner(this.random, definitions: definitions);
    combat = CombatSystem(
      this.random,
      heroPlayback: AttackPlayback(resources.clip(const ClipId('hero.attack'))),
      enemyPlayback: AttackPlayback(ProceduralEnemyTimelines.attack),
    );
    drops = DropSystem(this.random);
    purchases = EquipmentPurchases(profile: curveProfile);
    stats = CharacterStats.calculate(hero, profile: curveProfile);
    hp = stats.maxHp;
    _recovered('initial', Amount.zero);
    _schedule(0, _travel);
  }

  final EquipmentCurveProfile curveProfile;
  final IncomeStress income;
  final double upgradeInterval;
  final InvestmentStrategy strategy;
  final Random random;
  final CharacterProgress hero;
  final void Function(Map<String, Object?> trace)? onEncounter;
  final void Function(Map<String, Object?> event)? onRecovery;
  final void Function(Map<String, Object?> event)? onPurchase;
  late final EquipmentPurchases purchases;
  final resources = defaultAnimationResources();
  late final EnemySpawner spawner;
  late final CombatSystem combat;
  late final DropSystem drops;
  late CombatStats stats;
  late Amount hp;
  int stage = 1, stageKills = 0, kills = 0, deaths = 0;
  int successfulPurchases = 0, hpPurchases = 0, respawnHeals = 0;
  Amount goldEarned = Amount.zero, booksEarned = Amount.zero;
  Amount killGoldEarned = Amount.zero,
      stageGoldEarned = Amount.zero,
      firstGoldEarned = Amount.zero;
  final goldSpent = <String, Amount>{};
  final _firstRewardedStages = <int>{};
  int rejectedZeroEffects = 0;
  Amount damageReceived = Amount.zero;
  final _recentGold = <(double, Amount)>[];
  Amount purchaseHealing = Amount.zero;
  double elapsed = 0, _nextUpgrade = 0, _pendingAt = 0;
  void Function()? _pending;
  final _firstEntry = <int, double>{1: 0};
  final firstClearSeconds = <double>[];
  final killSeconds = <double>[];
  final normalSeconds = <double>[], bossSeconds = <double>[];
  final hpBeforeFractions = <double>[], hpAfterFractions = <double>[];
  final purchaseWaitSeconds = <double>[];
  final recentDeaths = <double>[];
  double _lastPurchase = 0;
  Enemy? enemy;
  bool _rewardPending = false;
  bool get rewardPending => _rewardPending;

  void _schedule(double at, void Function() work) {
    _pendingAt = at;
    _pending = work;
  }

  void runUntil(double deadline) {
    if (!deadline.isFinite || deadline < elapsed) {
      throw ArgumentError.value(deadline, 'deadline');
    }
    while (_pending != null && _pendingAt <= deadline) {
      elapsed = _pendingAt;
      final work = _pending!;
      _pending = null;
      work();
    }
    elapsed = deadline;
  }

  void _travel() {
    if (elapsed >= _nextUpgrade) {
      invest();
      _nextUpgrade = elapsed + upgradeInterval;
    }
    final travel =
        spawner.nextDistance() /
            GameBalance.movementSpeed *
            income.travelFactor +
        GameBalance.approachDuration;
    _schedule(elapsed + travel, _encounter);
  }

  void _encounter() {
    final foe = spawner.spawn(
      stage - 1,
      isBoss: stageKills + 1 == ProgressionBalance.enemiesPerStage,
    );
    enemy = foe;
    final start = elapsed, beforeHp = hp, maxHp = stats.maxHp;
    final encounterStage = stage, wave = stageKills + 1;
    final hits = <DamageEvent>[];
    final heroPeriod = 1 / stats.attackSpeed;
    final enemyPeriod = 1 / foe.stats.attackSpeed;
    double firstHit(AnimationClipDefinition clip, double period) =>
        clip.markers
            .firstWhere((m) => m.kind == AnimationMarkerKind.damage)
            .time *
        min(1, period / clip.duration);
    var nextHero = firstHit(
      resources.clip(const ClipId('hero.attack')),
      heroPeriod,
    );
    var nextEnemy = firstHit(
      foe.definition.animations.attack(resources),
      enemyPeriod,
    );
    _sample(hpBeforeFractions, hp.ratio(maxHp));

    void record(bool victory, double hitTime) {
      _sample(recentDeaths, victory ? 0 : 1);
      _sample(hpAfterFractions, hp.ratio(maxHp));
      onEncounter?.call({
        'stage': encounterStage,
        'wave': wave,
        'boss': foe.isBoss,
        'victory': victory,
        'combatSeconds': hitTime,
        'start': start,
        'confirmedAt': elapsed,
        'hpBeforeLog': beforeHp.toJson(),
        'hpAfterLog': hp.toJson(),
        'hits': [
          for (final hit in hits)
            {
              'hero': hit.fromHero,
              'critical': hit.critical,
              'amountLog': hit.amount.toJson(),
              'time': hit.timeWithinStep,
            },
        ],
      });
    }

    late void Function() scheduleHit;
    scheduleHit = () {
      final fromHero = nextHero <= nextEnemy + 1e-12;
      final hitTime = fromHero ? nextHero : nextEnemy;
      _schedule(start + hitTime, () {
        final hit = combat.calculate(
          fromHero ? stats : foe.stats,
          fromHero,
          timeWithinStep: hitTime,
        );
        if (onEncounter != null) hits.add(hit);
        if (fromHero) {
          foe.hp = foe.hp - hit.amount;
          nextHero += heroPeriod;
          if (foe.hp.isZero) {
            _rewardPending = true;
            _schedule(
              elapsed + foe.definition.animations.death(resources).duration,
              () {
                _rewardPending = false;
                final reward = drops.roll(foe);
                var receivedGold = reward.gold.scale(income.killGoldMultiplier);
                killGoldEarned = killGoldEarned + receivedGold;
                if (foe.isBoss) {
                  final stageBonus = foe.gold.scale(income.stageGoldBonus);
                  final firstBonus = _firstRewardedStages.add(encounterStage)
                      ? foe.gold.scale(income.firstClearGoldBonus)
                      : Amount.zero;
                  receivedGold = receivedGold + stageBonus + firstBonus;
                  stageGoldEarned = stageGoldEarned + stageBonus;
                  firstGoldEarned = firstGoldEarned + firstBonus;
                }
                hero.gold = hero.gold + receivedGold;
                hero.books = hero.books + reward.books;
                goldEarned = goldEarned + receivedGold;
                _recentGold.add((elapsed, receivedGold));
                if (_recentGold.length > 200) _recentGold.removeAt(0);
                booksEarned = booksEarned + reward.books;
                kills++;
                _sample(killSeconds, hitTime);
                _sample(foe.isBoss ? bossSeconds : normalSeconds, hitTime);
                stageKills++;
                if (stageKills == ProgressionBalance.enemiesPerStage) {
                  stage++;
                  stageKills = 0;
                  if (!_firstEntry.containsKey(stage)) {
                    firstClearSeconds.add(
                      elapsed - (_firstEntry[stage - 1] ?? start),
                    );
                    _firstEntry[stage] = elapsed;
                  }
                }
                record(true, hitTime);
                _schedule(elapsed + GameBalance.rewardDuration, () {
                  enemy = null;
                  _travel();
                });
              },
            );
            return;
          }
        } else {
          damageReceived = damageReceived + hit.amount;
          hp = hp - hit.amount;
          nextEnemy += enemyPeriod;
          if (hp.isZero) {
            deaths++;
            stage = max(1, stage - 1);
            stageKills = 0;
            record(false, hitTime);
            _schedule(
              elapsed +
                  resources.clip(const ClipId('hero.death')).duration +
                  GameBalance.respawnDuration,
              () {
                final before = hp;
                hp = stats.maxHp;
                _recovered('respawn', before);
                respawnHeals++;
                enemy = null;
                _travel();
              },
            );
            return;
          }
        }
        scheduleHit();
      });
    };
    scheduleHit();
  }

  /// Explicit between-encounter purchases; returns actual successful counts.
  void invest() {
    if (strategy == InvestmentStrategy.noPurchases) return;
    final oldHp = hp;
    final oldMax = stats.maxHp;
    final previous = successfulPurchases;
    void buy(String id, int? count) {
      if (count == 0) return;
      final quote = purchases.quote(hero, id, count: count);
      if (quote.count == 0) {
        if (quote.blockedReason?.startsWith('Precision') ?? false) {
          rejectedZeroEffects++;
        }
        return;
      }
      final bought = purchases.purchase(hero, id, count: quote.count);
      if (bought == 0) return;
      successfulPurchases++;
      goldSpent[id] = (goldSpent[id] ?? Amount.zero) + quote.cost;
      if (id == 'armor') hpPurchases++;
      onPurchase?.call({
        'time': elapsed,
        'id': id,
        'count': bought,
        'costLog': quote.cost.toJson(),
        'beforeLog': quote.before.toJson(),
        'afterLog': quote.after.toJson(),
        'stage': stage,
        'wave': stageKills + 1,
      });
    }

    if (strategy == InvestmentStrategy.adaptive) {
      // Armor is compared in a survival context, not in units of DPS/Gold.
      // Otherwise choose the best expected-DPS gain per Gold among offensive items.
      for (var attempt = 0; attempt < 16; attempt++) {
        stats = CharacterStats.calculate(hero, profile: curveProfile);
        final foe = spawner.factory.create(
          spawner.definitions.first,
          stage - 1,
          isBoss: stageKills + 1 == ProgressionBalance.enemiesPerStage,
        );
        final expectedHits = foe.hp
            .ratio(stats.dps)
            .clamp(1.0, 1000000000.0)
            .ceil();
        final incoming = foe.stats.dps.scale((expectedHits - 1).toDouble());
        final currentHp = hp.isZero ? hp : hp + (stats.maxHp - oldMax);
        final armor = purchases.quote(hero, 'armor');
        if (currentHp < incoming.scale(1.5) && armor.count > 0) {
          buy('armor', 1);
          continue;
        }
        String? selected;
        var best = double.negativeInfinity;
        for (final id in ['weapon', 'helmet', 'amulet']) {
          final quote = purchases.quote(hero, id);
          if (quote.count == 0) continue;
          final preview = CharacterProgress()..equipment.addAll(hero.equipment);
          preview.equipment[id] = quote.level + quote.count;
          final gain =
              CharacterStats.calculate(preview, profile: curveProfile).dps -
              stats.dps;
          final score = gain.isZero
              ? double.negativeInfinity
              : gain.log10 - quote.cost.log10;
          if (score > best) {
            best = score;
            selected = id;
          }
        }
        if (selected == null) break;
        buy(selected, 1);
      }
    } else {
      final wallet = hero.gold;
      var shares = switch (strategy) {
        InvestmentStrategy.weaponOnly => [1.0, 0.0, 0.0, 0.0],
        InvestmentStrategy.armorOnly => [0.0, 1.0, 0.0, 0.0],
        InvestmentStrategy.helmetOnly => [0.0, 0.0, 1.0, 0.0],
        InvestmentStrategy.amuletOnly => [0.0, 0.0, 0.0, 1.0],
        _ => [0.375, 0.375, 0.15, 0.10],
      };
      final omit = switch (strategy) {
        InvestmentStrategy.omitWeapon => 0,
        InvestmentStrategy.omitArmor => 1,
        InvestmentStrategy.omitHelmet => 2,
        InvestmentStrategy.omitAmulet => 3,
        _ => -1,
      };
      if (omit >= 0) {
        final total = 1 - shares[omit];
        shares = [
          for (var i = 0; i < 4; i++) i == omit ? 0 : shares[i] / total,
        ];
      }
      for (var i = 0; i < 4; i++) {
        if (shares[i] == 0) continue;
        final item = EquipmentCatalog.items[i];
        final count = item.affordable(
          hero.equipment[item.id] ?? 0,
          wallet.scale(shares[i]),
        );
        buy(item.id, count);
      }
    }
    stats = CharacterStats.calculate(hero, profile: curveProfile);
    if (!hp.isZero) {
      final restored = hp + (stats.maxHp - oldMax);
      hp = restored > stats.maxHp ? stats.maxHp : restored;
      purchaseHealing = purchaseHealing + (hp - oldHp);
      if (hp > oldHp) _recovered('hpPurchase', oldHp);
    }
    if (successfulPurchases > previous) {
      _sample(purchaseWaitSeconds, elapsed - _lastPurchase);
      _lastPurchase = elapsed;
    }
  }

  void _recovered(String reason, Amount before) => onRecovery?.call({
    'reason': reason,
    'productiveSeconds': elapsed,
    'beforeLog': before.toJson(),
    'afterLog': hp.toJson(),
    'maxHpLog': stats.maxHp.toJson(),
  });

  static void _sample(List<double> values, double value) {
    values.add(value);
    if (values.length > 200) values.removeAt(0);
  }

  static double percentile(Iterable<double> values, double p) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final index = (sorted.length - 1) * p;
    final low = index.floor(), high = index.ceil();
    return sorted[low] + (sorted[high] - sorted[low]) * (index - low);
  }

  static double median(Iterable<double> values) => percentile(values, .5);

  Map<String, Object?> snapshot(int day) {
    final recentIncome = _recentGold
        .fold(Amount.zero, (sum, e) => sum + e.$2)
        .scale(
          1 /
              max(
                GameBalance.fixedStep,
                _recentGold.isEmpty ? elapsed : elapsed - _recentGold.first.$1,
              ),
        );
    final diagnostics = <String, Object?>{};
    for (final item in EquipmentCatalog.items) {
      final level = hero.equipment[item.id] ?? 0;
      final price = item.cost(level);
      final shortage = price - hero.gold;
      diagnostics['nextCost_${item.id}Log'] = price.toJson();
      diagnostics['timeToAfford_${item.id}Seconds'] = shortage.isZero
          ? 0.0
          : recentIncome.isZero
          ? null
          : shortage.ratio(recentIncome);
      diagnostics['rank_${item.id}'] = level;
      diagnostics['spent_${item.id}Log'] = (goldSpent[item.id] ?? Amount.zero)
          .toJson();
      if (level < 9007199254740991 &&
          curveProfile.usefulRank(item.stat, level + 1)) {
        final preview = CharacterProgress()..equipment.addAll(hero.equipment);
        preview.equipment[item.id] = level + 1;
        final next = CharacterStats.calculate(preview, profile: curveProfile);
        final gain = item.id == 'armor'
            ? next.maxHp - stats.maxHp
            : next.dps - stats.dps;
        diagnostics['${item.id}_marginal${item.id == 'armor' ? 'Hp' : 'Dps'}PerGoldLog'] =
            gain.isZero
            ? null
            : Amount.fromLog(gain.log10 - price.log10).toJson();
      }
    }
    return {
      ...diagnostics,
      'recentGoldPerSecondLog': recentIncome.toJson(),
      'damageReceivedLog': damageReceived.toJson(),
      'goldSpentTotalLog': goldSpent.values
          .fold(Amount.zero, (sum, value) => sum + value)
          .toJson(),
      'profile': curveProfile.id,
      'income': income.id,
      'booksSpent': 0,
      'goldSpentLog': {
        for (final e in goldSpent.entries) e.key: e.value.toJson(),
      },
      'rejectedZeroEffects': rejectedZeroEffects,
      'killGoldEarnedLog': killGoldEarned.toJson(),
      'stageGoldEarnedLog': stageGoldEarned.toJson(),
      'firstClearGoldEarnedLog': firstGoldEarned.toJson(),
      'dpsLog': stats.dps.toJson(),
      'day': day,
      'productiveSeconds': elapsed,
      'stage': stage,
      'wave': stageKills + 1,
      'highestStage': _firstEntry.keys.reduce(max),
      'kills': kills,
      'deaths': deaths,
      'deathsPer100RecentEncounters': recentDeaths.isEmpty
          ? 0.0
          : 100 * recentDeaths.reduce((a, b) => a + b) / recentDeaths.length,
      'medianRecentStageSeconds': median(
        firstClearSeconds.skip(max(0, firstClearSeconds.length - 20)),
      ),
      'medianRecentKillSeconds': median(killSeconds),
      'normalTtkP50': median(normalSeconds),
      'normalTtkP90': percentile(normalSeconds, .9),
      'bossTtkP50': median(bossSeconds),
      'bossTtkP90': percentile(bossSeconds, .9),
      'hpBeforeFractionP50': median(hpBeforeFractions),
      'hpAfterFractionP50': median(hpAfterFractions),
      'hpPurchaseHealingLog': purchaseHealing.toJson(),
      'successfulPurchases': successfulPurchases,
      'hpPurchases': hpPurchases,
      'respawnHeals': respawnHeals,
      'purchaseWaitP50': median(purchaseWaitSeconds),
      'purchaseWaitP90': percentile(purchaseWaitSeconds, .9),
      'goldEarnedLog': goldEarned.toJson(),
      'booksEarnedLog': booksEarned.toJson(),
      'goldRemainingLog': hero.gold.toJson(),
      'booksRemainingLog': hero.books.toJson(),
      'maxHpLog': stats.maxHp.toJson(),
      'currentHpLog': hp.toJson(),
      'damageLog': stats.damage.toJson(),
      'equipment': Map.of(hero.equipment),
      'firstStageEntrySeconds': {
        for (final entry in _firstEntry.entries) '${entry.key}': entry.value,
      },
      'rewardPending': rewardPending,
      'weapon': hero.equipment['weapon'] ?? 0,
    };
  }
}

void main(List<String> args) {
  double option(String name, double fallback) {
    final index = args.indexOf(name);
    return index < 0 ? fallback : double.parse(args[index + 1]);
  }

  final hours = option('--hours-per-day', 7);
  final seeds = option('--seeds', 20).toInt();
  final days = option('--days', 30).toInt();
  final rows = <Map<String, Object?>>[];
  final checkpoints = [1, 7, days].where((day) => day <= days).toSet().toList()
    ..sort();
  for (var seed = 1; seed <= seeds; seed++) {
    final sim = ProgressionSimulation(seed: seed);
    for (final day in checkpoints) {
      sim.runUntil(day * hours * 3600);
      rows.add({'seed': seed, ...sim.snapshot(day)});
    }
  }
  stdout.writeln(
    jsonEncode({
      'hoursPerDay': hours,
      'seeds': seeds,
      'strategy': 'hourly_balanced',
      'time': 'productive, no rest or restart',
      'rows': rows,
    }),
  );
}
