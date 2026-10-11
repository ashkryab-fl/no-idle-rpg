import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';

void main() {
  const p = EquipmentCurveProfile.candidate;
  const buy = EquipmentPurchases();
  final curves = [
    for (final rank in [
      0,
      1,
      99,
      100,
      101,
      149,
      150,
      151,
      199,
      200,
      201,
      350,
      500,
      1000,
      1000000,
    ])
      {
        'rank': rank,
        'hpLog': p.value(CharacterStat.maxHp, rank).toJson(),
        'damageLog': p.value(CharacterStat.damage, rank).toJson(),
        'chance': p.chance.value(rank),
        'multiplier': p.multiplier.value(rank),
        'chanceNextGain': p.chance.value(rank + 1) - p.chance.value(rank),
        'multiplierNextGain':
            p.multiplier.value(rank + 1) - p.multiplier.value(rank),
      },
  ];
  final boundary = [
    for (final epsilon in [0.0, 1e-6])
      {
        'epsilon': epsilon,
        'lastUsefulHelmet':
            EquipmentPurchases(
                  profile: EquipmentCurveProfile(
                    id: 'precision_$epsilon',
                    minimumChanceGain: epsilon,
                  ),
                )
                .quote(
                  CharacterProgress()..gold = Amount.fromLog(10000),
                  'helmet',
                  count: null,
                )
                .count,
      },
  ];
  final timing = <double>[];
  for (var i = 0; i < 1010; i++) {
    final hero = CharacterProgress()
      ..gold = EquipmentCatalog.require('weapon').batchCost(0, 1000000);
    final watch = Stopwatch()..start();
    final count = buy.purchase(hero, 'weapon', count: null);
    watch.stop();
    if (count != 1000000) throw StateError('Incorrect million-rank MAX');
    if (i >= 10) timing.add(watch.elapsedMicroseconds.toDouble());
  }
  timing.sort();
  final contexts = <Map<String, Object?>>[];
  for (final (id, build) in [
    ('weapon', {'weapon': 0, 'armor': 0, 'helmet': 0, 'amulet': 0}),
    ('armor', {'weapon': 0, 'armor': 0, 'helmet': 0, 'amulet': 0}),
    ('helmet', {'weapon': 200, 'armor': 200, 'helmet': 0, 'amulet': 150}),
    ('amulet', {'weapon': 200, 'armor': 200, 'helmet': 500, 'amulet': 0}),
  ]) {
    final hero = CharacterProgress()
      ..gold = Amount.fromLog(1000)
      ..equipment.addAll(build);
    final before = CharacterStats.calculate(hero), quote = buy.quote(hero, id);
    buy.purchase(hero, id);
    final after = CharacterStats.calculate(hero);
    contexts.add({
      'id': id,
      'build': build,
      'costLog': quote.cost.toJson(),
      'beforeHpLog': before.maxHp.toJson(),
      'afterHpLog': after.maxHp.toJson(),
      'beforeDpsLog': before.dps.toJson(),
      'afterDpsLog': after.dps.toJson(),
      'relativeDpsGain': after.dps.ratio(before.dps) - 1,
      'relativeHpGain': after.maxHp.ratio(before.maxHp) - 1,
    });
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'profile': p.toJson(),
      'guard':
          'analytic rank gain >= one ULP of represented stat (log stat for HP/damage), then final represented before/after check; conservative precision boundary, not product epsilon',
      'curves': curves,
      'precision': boundary,
      'contexts': contexts,
      'maxMillionBenchmark': {
        'samples': timing.length,
        'unit': 'microseconds',
        'p50': timing[500],
        'p95': timing[950],
        'max': timing.last,
      },
    }),
  );
}
