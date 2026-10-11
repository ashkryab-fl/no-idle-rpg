import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../../tool/balance/simulate_progression.dart';
import 'phase_01_test.dart' show ConstantRandom;

void main() {
  for (final (name, critRoll, hp, wave) in [
    ('no-crit victory', .99, 120.0, 1),
    ('crit victory', .0, 120.0, 1),
    ('death', .99, 1.0, 1),
    ('boss clear', .99, 120.0, 5),
    ('curved crit build', .0, 120.0, 5),
  ]) {
    test('$name: runtime and event encounters agree', () {
      final runtime = GameSimulation(random: ConstantRandom(critRoll))
        ..heroHp = Amount.fromNum(hp)
        ..stageKills = wave - 1;
      if (name == 'curved crit build') {
        runtime.character.equipment.addAll({
          'weapon': 101,
          'armor': 101,
          'helmet': 201,
          'amulet': 151,
        });
      }
      final traces = <Map<String, Object?>>[];
      final model =
          ProgressionSimulation(
              character: CharacterProgress()
                ..equipment.addAll(runtime.character.equipment),
              random: ConstantRandom(critRoll),
              strategy: InvestmentStrategy.noPurchases,
              onEncounter: traces.add,
            )
            ..hp = Amount.fromNum(hp)
            ..stageKills = wave - 1;
      final hits = <Map<String, Object?>>[];
      runtime.spawnEnemy();
      var combatStarted = false;
      var combatElapsed = 0.0, runtimeBoundary = 0.0;
      var sinceStart = 0.0;
      for (var tick = 0; tick < 10000; tick++) {
        final wasCombat = runtime.phase == GamePhase.combat;
        if (wasCombat) combatStarted = true;
        runtime.advance(GameBalance.fixedStep);
        if (combatStarted) sinceStart += GameBalance.fixedStep;
        for (final event in runtime.events) {
          if (event.damage case final hit?) {
            hits.add({
              'hero': hit.fromHero,
              'critical': hit.critical,
              'amountLog': hit.amount.toJson(),
              'time': combatElapsed + hit.timeWithinStep,
            });
          }
        }
        runtime.events.clear();
        if (wasCombat) combatElapsed += GameBalance.fixedStep;
        if (runtime.phase == GamePhase.reward ||
            runtime.phase == GamePhase.heroDeath) {
          runtimeBoundary = sinceStart;
          break;
        }
      }
      for (var i = 0; traces.isEmpty && i < 10000; i++) {
        model.runUntil(model.elapsed + GameBalance.fixedStep);
      }
      final trace = traces.single;
      final modelHits = trace['hits'] as List;
      expect(hits.length, modelHits.length);
      for (var i = 0; i < hits.length; i++) {
        expect(hits[i]['hero'], modelHits[i]['hero']);
        expect(hits[i]['critical'], modelHits[i]['critical']);
        expect(
          double.parse(hits[i]['amountLog'] as String),
          closeTo(double.parse(modelHits[i]['amountLog'] as String), 1e-10),
        );
        expect(
          hits[i]['time'] as double,
          closeTo(
            modelHits[i]['time'] as double,
            GameBalance.fixedStep + 1e-10,
          ),
        );
      }
      expect(runtime.kills, model.kills);
      expect(runtime.stage, model.stage);
      expect(runtime.wave, model.stageKills + 1);
      expect(runtime.heroHp.toDouble(), closeTo(model.hp.toDouble(), 1e-9));
      expect(
        runtime.character.gold.toDouble(),
        closeTo(model.hero.gold.toDouble(), 1e-10),
      );
      expect(
        runtime.character.books.toDouble(),
        closeTo(model.hero.books.toDouble(), 1e-10),
      );
      expect(trace['victory'], runtime.phase == GamePhase.reward);
      expect(
        runtimeBoundary,
        closeTo(
          (trace['confirmedAt'] as double) - (trace['start'] as double),
          2 * GameBalance.fixedStep + 1e-10,
        ),
      );
    });
  }

  test(
    'HP purchase between encounters uses actual new stats in both models',
    () {
      final runtime = GameSimulation(random: ConstantRandom())
        ..heroHp = Amount.fromNum(50);
      final hero = CharacterProgress()..gold = Amount.fromNum(20);
      final model = ProgressionSimulation(
        character: hero,
        random: ConstantRandom(),
        strategy: InvestmentStrategy.armorOnly,
      )..hp = Amount.fromNum(50);
      runtime.character.gold = Amount.fromNum(20);
      runtime.purchaseEquipment('armor');
      model.invest();
      expect(model.hero.equipment, runtime.character.equipment);
      expect(model.hp.toDouble(), closeTo(56, 1e-10));
      expect(model.stats.maxHp.log10, runtime.stats.maxHp.log10);
      expect(model.hp.log10, runtime.heroHp.log10);
      model.hp = Amount.zero;
      model.hero.gold = Amount.fromNum(100);
      model.invest();
      expect(model.hp.isZero, isTrue);
    },
  );

  test(
    'checkpoints preserve pending attacks, reward and future random draws',
    () {
      final continuous = ProgressionSimulation(seed: 17);
      final split = ProgressionSimulation(seed: 17);
      continuous.runUntil(3600);
      for (var second = 1; second <= 3600; second++) {
        split.runUntil(second.toDouble());
      }
      expect(split.snapshot(0), continuous.snapshot(0));
    },
  );

  test('lethal hit has no committed reward before the death boundary', () {
    final traces = <Map<String, Object?>>[];
    final model = ProgressionSimulation(
      random: ConstantRandom(),
      strategy: InvestmentStrategy.noPurchases,
      onEncounter: traces.add,
    );
    for (var i = 0; !model.rewardPending && i < 10000; i++) {
      model.runUntil(model.elapsed + .01);
    }
    expect(model.rewardPending, isTrue);
    expect(model.kills, 0);
    expect(model.hero.gold.isZero, isTrue);
    expect(traces, isEmpty);
    while (traces.isEmpty) {
      model.runUntil(model.elapsed + .01);
    }
    expect(model.kills, 1);
    expect(model.rewardPending, isFalse);
    expect(model.hero.gold.toDouble(), closeTo(12, 1e-10));
  });
  test('positive HP journal records only initial, HP purchase and respawn', () {
    final events = <Map<String, Object?>>[];
    final model = ProgressionSimulation(
      random: ConstantRandom(),
      strategy: InvestmentStrategy.armorOnly,
      upgradeInterval: double.infinity,
      onRecovery: events.add,
    )..hp = Amount.one;
    // Let the natural fight kill the damaged fixture, then complete respawn.
    while (model.deaths == 0) {
      model.runUntil(model.elapsed + .01);
    }
    expect(model.hp.isZero, isTrue);
    while (model.hp.isZero) {
      model.runUntil(model.elapsed + .01);
    }
    expect(events.map((e) => e['reason']), ['initial', 'respawn']);
    model.hp = Amount.fromNum(50);
    model.hero.gold = Amount.fromNum(20);
    model.invest();
    expect(events.map((e) => e['reason']), [
      'initial',
      'respawn',
      'hpPurchase',
    ]);
    expect(model.hp.toDouble(), closeTo(56, 1e-9));
  });
}
