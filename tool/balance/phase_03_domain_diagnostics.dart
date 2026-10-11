import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/core/balance/talent_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/progression/upgrade_price.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

void main() {
  final purchases = TalentPurchases(), curves = <Map<String, Object?>>[];
  for (final d in TalentCatalog.items) {
    final c = TalentProfile.candidate.curves[d.id]!;
    final price = UpgradePrice(baseCost: c.baseCost, costGrowth: c.costGrowth);
    curves.add({
      'id': d.id,
      'curve': c.toJson(),
      'ranks': [
        for (var rank = 0; rank <= 10; rank++)
          {
            'rank': rank,
            'effect': c.value(rank),
            'nextDelta': rank == 10 ? null : c.value(rank + 1) - c.value(rank),
            'nextCostBooks': rank == 10
                ? null
                : price.batchCost(rank, 1).toDouble(),
          },
      ],
      'totalBooks': price.batchCost(0, 10).toDouble(),
    });
  }
  final hero = CharacterProgress()
    ..books = Amount.fromNum(10000)
    ..talents.highestFirstClearedStage = 100;
  final latency = <Map<String, Object?>>[];
  for (final count in <int?>[1, 10, null]) {
    for (var warm = 0; warm < 1000; warm++) {
      purchases.quote(hero, 'boss_damage', count: count);
    }
    final timer = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      purchases.quote(hero, 'boss_damage', count: count);
    }
    timer.stop();
    latency.add({
      'count': count ?? 'MAX',
      'quotes': 10000,
      'microsecondsPerQuote': timer.elapsedMicroseconds / 10000,
    });
  }
  final ledger = <Map<String, Object?>>[];
  for (final entries in [0, 1000, 100000]) {
    final game = GameSimulation();
    game.character.talents.highestFirstClearedStage = 1000000000000;
    for (var stage = 1; stage <= entries; stage++) {
      game.character.talents.usedRepeats[stage] = 2;
    }
    final timer = Stopwatch()..start();
    final save = GameSave.capture(game, DateTime.utc(2026, 10, 11));
    timer.stop();
    final cloneUs = timer.elapsedMicroseconds;
    timer.reset();
    timer.start();
    final json = jsonEncode(save.toJson());
    timer.stop();
    ledger.add({
      'frontier': 1000000000000,
      'repeatEntries': entries,
      'saveBytes': utf8.encode(json).length,
      'captureMicroseconds': cloneUs,
      'encodeMicroseconds': timer.elapsedMicroseconds,
    });
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'profile': TalentProfile.candidate.toJson(),
      'method':
          'Finite curves and exact rank-10 endpoints; production quotes; sparse frontier/used-repeat stress. Timings are local diagnostics, not cross-platform budgets.',
      'curves': curves,
      'quoteLatency': latency,
      'ledgerStress': ledger,
    }),
  );
}
