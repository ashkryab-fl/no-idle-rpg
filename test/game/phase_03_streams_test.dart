import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import '../../tool/balance/simulate_progression.dart';

void main() {
  for (var seed = 1; seed <= 20; seed++) {
    test(
      'independent seeded streams $seed agree through first settled stage',
      () {
        final runtime = GameSimulation(
          random: Random(seed),
          idleRandom: Random(77),
          travelRandom: Random(seed + 100),
          selectionRandom: Random(seed + 200),
        );
        final traces = <Map<String, Object?>>[];
        final model = ProgressionSimulation(
          random: Random(seed),
          travelRandom: Random(seed + 100),
          selectionRandom: Random(seed + 200),
          strategy: InvestmentStrategy.noPurchases,
          onEncounter: traces.add,
        );
        final runtimeHits = <bool>[];
        for (var tick = 0; runtime.kills < 5 && tick < 20000; tick++) {
          runtime.advance(GameBalance.fixedStep);
          for (final event in runtime.events) {
            if (event.damage case final hit?) {
              runtimeHits.add(hit.critical);
            }
          }
          runtime.events.clear();
        }
        for (var tick = 0; model.kills < 5 && tick < 20000; tick++) {
          model.runUntil(model.elapsed + GameBalance.fixedStep);
        }
        expect(runtime.kills, 5);
        expect(model.kills, 5);
        expect(runtimeHits, [
          for (final trace in traces)
            for (final hit in trace['hits'] as List) hit['critical'],
        ]);
        expect(runtime.heroHp.toDouble(), closeTo(model.hp.toDouble(), 1e-8));
        expect(
          runtime.character.gold.toDouble(),
          closeTo(model.hero.gold.toDouble(), 1e-8),
        );
        expect(
          runtime.character.books.toDouble(),
          closeTo(model.hero.books.toDouble(), 1e-8),
        );
        expect(runtime.stage, model.stage);
      },
    );
  }
}
