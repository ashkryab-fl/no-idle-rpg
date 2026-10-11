import 'dart:convert';
import 'dart:io';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment_purchase.dart';
import 'simulate_progression.dart';

void main() {
  final encounters = <Map<String, Object?>>[];
  final purchases = <Map<String, Object?>>[];
  final recovery = <Map<String, Object?>>[];
  final early = ProgressionSimulation(
    seed: 1,
    upgradeInterval: 0,
    strategy: InvestmentStrategy.adaptive,
    onEncounter: encounters.add,
    onPurchase: purchases.add,
    onRecovery: recovery.add,
  )..runUntil(1800);
  final contexts = <Map<String, Object?>>[];
  for (final id in ['weapon', 'armor', 'helmet', 'amulet']) {
    for (var seed = 1; seed <= 20; seed++) {
      CharacterProgress hero() => CharacterProgress()
        ..equipment.addAll({
          'weapon': 30,
          'armor': 60,
          'helmet': id == 'amulet' ? 500 : 0,
          'amulet': id == 'helmet' ? 150 : 0,
        });
      final baseHero = hero(), boughtHero = hero()..gold = Amount.fromLog(100);
      final count = id == 'helmet'
          ? 50
          : id == 'amulet'
          ? 20
          : 10;
      const buy = EquipmentPurchases();
      final quote = buy.quote(boughtHero, id, count: count);
      boughtHero.gold = quote.cost;
      buy.purchase(boughtHero, id, count: count);
      for (final (name, character) in [
        ('before', baseHero),
        ('after', boughtHero),
      ]) {
        final fights = <Map<String, Object?>>[];
        final sim = ProgressionSimulation(
          onEncounter: fights.add,
          seed: seed,
          character: character,
          strategy: InvestmentStrategy.noPurchases,
        )..stage = 25;
        sim.runUntil(900);
        contexts.add({
          'initialEncounter': fights.first,
          'item': id,
          'seed': seed,
          'variant': name,
          'purchasedCount': name == 'after' ? count : 0,
          'costLog': name == 'after' ? quote.cost.toJson() : null,
          ...sim.snapshot(0),
        });
      }
    }
  }
  stdout.writeln(
    jsonEncode({
      'early': {
        'seed': 1,
        'policy': 'adaptive',
        'checkpoint': early.snapshot(0),
        'encounters': encounters,
        'purchases': purchases,
        'positiveHp': recovery,
      },
      'contexts': contexts,
      'contextContract':
          'paired seeds, Stage 25, 900 productive seconds, ranks Weapon30/Armor60; Helmet case Amulet150, Amulet case Helmet500; one Gold purchase before combat, no further investment',
    }),
  );
}
