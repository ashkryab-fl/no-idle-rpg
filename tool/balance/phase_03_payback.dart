import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'simulate_progression.dart';

void main() {
  final rows = <Map<String, Object?>>[];
  for (var seed = 1; seed <= 20; seed++) {
    Map<String, Object?>? checkpoint;
    double checkpointHP = 0, checkpointTime = 0;
    late ProgressionSimulation baseline;
    baseline = ProgressionSimulation(
      seed: seed,
      strategy: InvestmentStrategy.adaptive,
      upgradeInterval: 0,
      onEncounter: (trace) {
        if (checkpoint == null &&
            trace['stage'] == 5 &&
            trace['boss'] == true &&
            trace['victory'] == true) {
          checkpoint = jsonDecode(jsonEncode(baseline.hero.toJson()));
          checkpointHP = baseline.hp.toDouble();
          checkpointTime = baseline.elapsed;
        }
      },
    );
    while (checkpoint == null) {
      baseline.runUntil(baseline.elapsed + .01);
    }
    for (final id in ['boss_damage', 'first_clear_gold']) {
      final hero = CharacterProgress.fromJson(
        jsonDecode(jsonEncode(checkpoint)),
      );
      final purchase = TalentPurchases();
      final quote = purchase.quote(hero, id, count: 3);
      if (purchase.purchase(hero, id, count: 3) != 3) {
        throw StateError('Natural checkpoint cannot fund rank 3');
      }
      purchase.select(hero, TalentPair.boss, id);
      final purchases = <Map<String, Object?>>[],
          encounters = <Map<String, Object?>>[];
      final continuation =
          ProgressionSimulation(
              seed: seed + 5000,
              character: hero,
              strategy: InvestmentStrategy.adaptive,
              upgradeInterval: 0,
              talentPolicy: 'selection_only',
              talentChoices: [id],
              onPurchase: purchases.add,
              onEncounter: encounters.add,
            )
            ..stage = 6
            ..hp = Amount.fromNum(checkpointHP);
      continuation.runUntil(3600);
      rows.add({
        'seed': seed,
        'talent': id,
        'checkpointTime': checkpointTime,
        'checkpoint': checkpoint,
        'checkpointHP': checkpointHP,
        'BooksBudget': quote.cost.toDouble(),
        'frontierAfterOneHour':
            continuation.hero.talents.highestFirstClearedStage,
        'firstClears': [
          for (final e in encounters)
            if (e['boss'] == true && e['victory'] == true)
              {
                'stage': e['stage'],
                'time': e['confirmedAt'],
                'hpAfter': e['hpAfterLog'],
              },
        ],
        'gearPurchases': purchases,
        'end': continuation.snapshot(0),
      });
    }
  }
  stdout.writeln(
    jsonEncode({
      'method':
          'Natural first-clear Stage 5 checkpoint; saved HP, Gold, Books and equipment copied to both continuations. Spend exactly 15.48 Books for three ranks in one boss alternative. Further talent purchases disabled; identical Gold heuristic and independent seeded continuation streams. Actual gear purchases and stage-clear timing recorded.',
      'rows': rows,
    }),
  );
}
