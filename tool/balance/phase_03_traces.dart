import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/adventure/stage_attempt.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import 'simulate_progression.dart';

class FixedRandom implements Random {
  const FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor();
  @override
  bool nextBool() => value < .5;
}

void main() {
  final rows = <Map<String, Object?>>[];
  for (var mask = 0; mask < 8; mask++) {
    for (final wave in [1, 5]) {
      for (final roll in [.0, .99]) {
        final game = GameSimulation(
          random: FixedRandom(roll),
          travelRandom: const FixedRandom(.5),
          selectionRandom: const FixedRandom(.5),
        );
        game.stage = 6;
        game.stageKills = wave - 1;
        game.heroHp = Amount.fromNum(60);
        game.character.talents.highestFirstClearedStage = 5;
        game.character.books = Amount.fromNum(1000);
        for (final d in TalentCatalog.items) {
          game.purchaseTalent(d.id, count: 3);
        }
        for (var pair = 0; pair < 3; pair++) {
          game.selectTalent(
            TalentPair.values[pair],
            TalentCatalog.items[2 * pair + ((mask >> pair) & 1)].id,
          );
        }
        final attempt = StageAttempt.begin(
          game.character.talents,
          6,
          game.spawner.plan(6),
        );
        game.activeAttempt = attempt;
        if (wave > 1) {
          game.character.talents.lastSettledAttempt = attempt.id;
          game.character.talents.lastSettledWave = wave - 1;
        }
        final traces = <Map<String, Object?>>[];
        final model =
            ProgressionSimulation(
                character: CharacterProgress.fromJson(
                  jsonDecode(jsonEncode(game.character.toJson())),
                ),
                random: FixedRandom(roll),
                travelRandom: const FixedRandom(.5),
                selectionRandom: const FixedRandom(.5),
                strategy: InvestmentStrategy.noPurchases,
                onEncounter: traces.add,
              )
              ..stage = 6
              ..stageKills = wave - 1
              ..activeAttempt = attempt
              ..hp = Amount.fromNum(60);
        final hits = <Map<String, Object?>>[];
        var combatTime = 0.0, elapsed = 0.0;
        for (var tick = 0; tick < 10000; tick++) {
          final fighting = game.phase == GamePhase.combat;
          game.advance(GameBalance.fixedStep);
          elapsed += GameBalance.fixedStep;
          for (final event in game.events) {
            if (event.damage case final hit?) {
              hits.add({
                'hero': hit.fromHero,
                'critical': hit.critical,
                'amount': hit.amount.toDouble(),
                'time': combatTime + hit.timeWithinStep,
              });
            }
          }
          game.events.clear();
          if (fighting) combatTime += GameBalance.fixedStep;
          if (game.phase == GamePhase.reward ||
              game.phase == GamePhase.heroDeath) {
            break;
          }
        }
        for (var tick = 0; traces.isEmpty && tick < 10000; tick++) {
          model.runUntil(model.elapsed + GameBalance.fixedStep);
        }
        final modelHits = traces.single['hits'] as List;
        if (modelHits.length != hits.length) {
          throw StateError('Hit count mismatch');
        }
        for (var i = 0; i < hits.length; i++) {
          final actual = hits[i], expected = modelHits[i] as Map;
          if (actual['hero'] != expected['hero'] ||
              actual['critical'] != expected['critical'] ||
              ((actual['amount'] as double) -
                          Amount.fromJson(expected['amountLog']).toDouble())
                      .abs() >
                  1e-8 ||
              ((actual['time'] as double) - (expected['time'] as double))
                      .abs() >
                  GameBalance.fixedStep + 1e-9) {
            throw StateError('Hit mismatch');
          }
        }
        if ((game.character.gold.toDouble() - model.hero.gold.toDouble())
                    .abs() >
                1e-8 ||
            (game.character.books.toDouble() - model.hero.books.toDouble())
                    .abs() >
                1e-8 ||
            (game.heroHp.toDouble() - model.hp.toDouble()).abs() > 1e-8 ||
            game.stage != model.stage ||
            game.wave != model.stageKills + 1 ||
            (elapsed - model.elapsed).abs() >
                4 * GameBalance.fixedStep + 1e-9) {
          throw StateError('Boundary mismatch');
        }
        rows.add({
          'mask': mask,
          'wave': wave,
          'critRoll': roll,
          'snapshot': attempt.toJson(),
          'runtimeSeconds': elapsed,
          'modelSeconds': model.elapsed,
          'runtimeHP': game.heroHp.toDouble(),
          'modelHP': model.hp.toDouble(),
          'reward': game.lastReward?.toJson(),
          'hits': hits,
          'model': traces.single,
        });
      }
    }
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'model': 'phase03_controlled_parity_v1',
      'method':
          'All 8 selections, normal/boss, crit/noncrit. Purchased fixture rank 3, gates at first-clear 5, one immutable encounter plan. Hit-time tolerance one fixed step; complete travel+approach+settlement tolerance four fixed steps.',
      'rows': rows,
    }),
  );
}
