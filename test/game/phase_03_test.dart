import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/animation/attack_playback.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/enemies/procedural_timelines.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/domain/adventure/stage_attempt.dart';
import 'package:idle_companion/game/systems/combat_system.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../../tool/balance/simulate_progression.dart';
import 'phase_01_test.dart' show ConstantRandom;

void until(GameSimulation g, bool Function() done) {
  for (var i = 0; !done() && i < 10000; i++) {
    g.advance(GameBalance.fixedStep);
  }
  expect(done(), isTrue);
}

GameSimulation restart(GameSimulation g) => GameSave.fromJson(
  jsonDecode(jsonEncode(GameSave.capture(g, DateTime.now()).toJson())),
).restoreSimulation();
GameSimulation talentsGame() {
  final g = GameSimulation(random: ConstantRandom());
  g.character.talents.highestFirstClearedStage = 100;
  g.character.books = Amount.fromNum(10000);
  for (final d in TalentCatalog.items) {
    g.purchaseTalent(d.id, count: 3);
  }
  return g;
}

void forcedClear(GameSimulation g) {
  for (var i = 0; i < 5; i++) {
    g.spawnEnemy();
    g.killEnemy();
    until(g, () => g.phase == GamePhase.reward);
    if (i < 4) until(g, () => g.phase == GamePhase.traveling);
  }
}

void main() {
  test(
    'contextual boss multiplier follows crit; protection affects only enemy crit bonus',
    () {
      final resources = defaultAnimationResources();
      final stats = CombatStats(
        maxHp: Amount.fromNum(120),
        damage: Amount.fromNum(100),
        attackSpeed: 1,
        critChance: .5,
        critDamage: 2,
      );
      for (final critical in [false, true]) {
        final combat = CombatSystem(
          ConstantRandom(critical ? 0 : .99),
          heroPlayback: AttackPlayback(
            resources.clip(const ClipId('hero.attack')),
          ),
          enemyPlayback: AttackPlayback(ProceduralEnemyTimelines.attack),
        );
        final effects = TalentEffects({
          'boss_damage': .5,
          'crit_protection': .6,
        });
        expect(
          combat.calculate(stats, true, effects: effects).amount.toDouble(),
          closeTo(critical ? 200 : 100, 1e-9),
        );
        expect(
          combat
              .calculate(stats, true, effects: effects, isBoss: true)
              .amount
              .toDouble(),
          closeTo(critical ? 300 : 150, 1e-9),
        );
        final incoming = combat.calculate(stats, false, effects: effects);
        expect(incoming.amount.toDouble(), closeTo(critical ? 140 : 100, 1e-9));
        expect(
          incoming.preventedCritBonus.toDouble(),
          closeTo(critical ? 60 : 0, 1e-9),
        );
      }
    },
  );
  test(
    'purchases/select queue mid-attempt; death restarts lower stage with queued values',
    () {
      final g = talentsGame()..stage = 6;
      g.selectTalent(TalentPair.boss, 'boss_damage');
      g.spawnEnemy();
      final snapshot = g.activeAttempt!;
      final hp = g.heroHp;
      g.purchaseTalent('boss_damage');
      g.selectTalent(TalentPair.boss, 'first_clear_gold');
      expect(g.heroHp, same(hp));
      expect(g.activeAttempt, same(snapshot));
      expect(snapshot.ranks, {'boss_damage': 3});
      final restored = restart(g);
      expect(restored.activeAttempt!.ranks, snapshot.ranks);
      expect(restored.heroHp.log10, hp.log10);
      restored.killHero();
      expect(restored.stage, 5);
      expect(restored.activeAttempt, isNull);
      until(restored, () => restored.phase == GamePhase.traveling);
      restored.spawnEnemy();
      expect(restored.activeAttempt!.ranks, {'first_clear_gold': 3});
    },
  );
  test(
    'snapshot waits for productive travel; rest and suspend keep unfinished snapshot',
    () {
      final g = talentsGame();
      g.idle.setIdleSeconds(301);
      g.advance(.5);
      expect(g.activeAttempt, isNull);
      g.selectTalent(TalentPair.travel, 'shorter_travel');
      g.idle.setIdleSeconds(0);
      until(g, () => g.activeAttempt != null);
      final snapshot = g.activeAttempt!;
      final reduced =
          snapshot.encounters[0].distance *
          (1 - snapshot.effects['shorter_travel']);
      expect(g.encounterRemaining, lessThanOrEqualTo(reduced));
      g.idle.setIdleSeconds(301);
      g.selectTalent(TalentPair.travel, 'stage_gold');
      final remaining = g.encounterRemaining;
      g.advance(1);
      g.advance(3600);
      expect(g.encounterRemaining, remaining);
      expect(g.activeAttempt, same(snapshot));
      final restored = restart(g);
      expect(restored.activeAttempt!.ranks, snapshot.ranks);
    },
  );
  test(
    'full-clear heal uses live equipment and old snapshot, capped at missing HP',
    () {
      final g = talentsGame();
      g.selectTalent(TalentPair.endurance, 'stage_heal');
      g.spawnEnemy();
      final fraction = g.activeAttempt!.effects['stage_heal'];
      g.heroHp = Amount.fromNum(40);
      g.character.gold = Amount.fromNum(20);
      g.purchaseEquipment('armor');
      g.purchaseTalent('stage_heal');
      g.selectTalent(TalentPair.endurance, 'crit_protection');
      g.killEnemy();
      until(g, () => g.phase == GamePhase.traveling);
      for (var i = 1; i < 5; i++) {
        g.spawnEnemy();
        g.killEnemy();
        until(g, () => g.phase == GamePhase.reward);
        if (i < 4) until(g, () => g.phase == GamePhase.traveling);
      }
      expect(g.heroHp.toDouble(), closeTo(46 + 126 * fraction, 1e-8));
      expect(g.activeAttempt, isNull);
      final hp = g.heroHp.toDouble();
      final restored = restart(g);
      expect(restored.heroHp.toDouble(), closeTo(hp, 1e-8));
      until(restored, () => restored.phase == GamePhase.traveling);
      restored.spawnEnemy();
      expect(restored.activeAttempt!.ranks, {'crit_protection': 3});
    },
  );
  for (final boundary in [
    'travel',
    'combat',
    'unsettled',
    'reward',
    'clearReward',
    'death',
    'respawn',
  ]) {
    test(
      'restart $boundary preserves HP/claims and cannot repay committed reward',
      () {
        var g = GameSimulation(random: ConstantRandom())
          ..heroHp = Amount.fromNum(50);
        if (boundary == 'travel') g.advance(.1);
        if (boundary == 'combat') {
          g.spawnEnemy();
          until(g, () => g.phase == GamePhase.combat);
        }
        if (boundary == 'unsettled' || boundary == 'reward') {
          g.spawnEnemy();
          g.killEnemy();
          if (boundary == 'reward') until(g, () => g.phase == GamePhase.reward);
        }
        if (boundary == 'clearReward') forcedClear(g);
        if (boundary == 'death' || boundary == 'respawn') {
          g.killHero();
          if (boundary == 'respawn') {
            until(g, () => g.phase == GamePhase.respawn);
          }
        }
        final hp = g.heroHp,
            kills = g.kills,
            gold = g.character.gold.toDouble(),
            books = g.character.books.toDouble();
        final ranks = g.activeAttempt?.ranks;
        final remaining = g.encounterRemaining;
        g = restart(g);
        expect(g.heroHp.log10, hp.log10);
        expect(g.activeAttempt?.ranks, ranks);
        expect(g.kills, kills);
        expect(g.character.gold.toDouble(), closeTo(gold, 1e-9));
        expect(g.character.books.toDouble(), closeTo(books, 1e-9));
        if (boundary == 'travel') {
          expect(g.encounterRemaining, closeTo(remaining, 1e-9));
        }
        if (boundary == 'unsettled') {
          until(g, () => g.phase == GamePhase.reward);
          expect(g.kills, 1);
          g = restart(g);
          expect(g.kills, 1);
        }
        if (boundary == 'reward' || boundary == 'clearReward') {
          g.advance(.1);
          expect(g.character.gold.toDouble(), closeTo(gold, 1e-9));
          expect(g.character.books.toDouble(), closeTo(books, 1e-9));
        }
        if (boundary == 'death' || boundary == 'respawn') {
          expect(g.heroHp.isZero, isTrue);
          until(g, () => g.phase == GamePhase.traveling);
          expect(g.heroHp.log10, g.stats.maxHp.log10);
        }
      },
    );
  }
  test(
    'duplicate completed death callback uses its captured wave and creates no second UI reward',
    () {
      final g = GameSimulation(random: ConstantRandom());
      g.spawnEnemy();
      g.killEnemy();
      until(g, () => g.phase == GamePhase.reward);
      final gold = g.character.gold.log10;
      g.events.clear();
      g.machine.phase = GamePhase.enemyDeath;
      g.advance(GameBalance.fixedStep);
      expect(g.kills, 1);
      expect(g.wave, 2);
      expect(g.character.gold.log10, gold);
      expect(g.events.where((e) => e.kind == 'reward'), isEmpty);
    },
  );
  test(
    'capture is immutable while wallet/ranks/claims change; unknown profile rejected',
    () {
      final g = talentsGame();
      g.spawnEnemy();
      final save = GameSave.capture(g, DateTime.now());
      final before = jsonEncode(save.toJson());
      g.purchaseTalent('boss_damage');
      g.character.gold = Amount.fromNum(999);
      g.selectTalent(TalentPair.travel, 'stage_gold');
      expect(jsonEncode(save.toJson()), before);
      final bad = jsonDecode(before) as Map<String, dynamic>;
      ((bad['adventure'] as Map)['attempt'] as Map)['profileId'] =
          'future_curve';
      expect(() => GameSave.fromJson(bad), throwsFormatException);
    },
  );
  test('finite repeat reserve survives repeated clear/death/restart loops', () {
    var g = GameSimulation(random: ConstantRandom());
    for (var cycle = 0; cycle < 6; cycle++) {
      forcedClear(g);
      g = restart(g);
      g.killHero();
      until(g, () => g.phase == GamePhase.traveling);
      g = restart(g);
    }
    expect(g.character.books.toDouble(), closeTo(5, 1e-9));
    expect(g.character.talents.usedRepeats, {1: 2});
  });
  test(
    'event runner records funded reinvestment, gates and actual boundary rest',
    () {
      final s = ProgressionSimulation(
        seed: 1,
        strategy: InvestmentStrategy.adaptive,
        upgradeInterval: 0,
        talentPolicy: 'adaptive',
      );
      s.runUntil(3600);
      expect(s.booksSpent, isNotEmpty);
      expect(s.hero.talents.ownedRanks, isNotEmpty);
      expect(s.goldSpent, isNotEmpty);
      expect(s.gateTimeline[1], isNotNull);
      s.requestRest();
      s.runUntil(s.elapsed + 120);
      final kills = s.kills;
      s.runUntil(s.elapsed + 120);
      expect(s.kills, kills);
      expect(s.productiveSeconds, lessThan(s.elapsed));
      s.resumeAdventure();
      s.runUntil(s.elapsed + 120);
      expect(s.kills, greaterThan(kills));
    },
  );
}
