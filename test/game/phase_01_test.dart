import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';

class ConstantRandom implements Random {
  ConstantRandom([this.value = .99]);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor();
  @override
  bool nextBool() => value < .5;
}

void main() {
  test('baseline stats depend only on purchases, never on game history', () {
    final game = GameSimulation(random: ConstantRandom());
    final initial = game.stats;
    expect(initial.maxHp.toDouble(), closeTo(120, 1e-10));
    expect(initial.damage.toDouble(), closeTo(14, 1e-10));
    expect(initial.attackSpeed, 1);
    expect(initial.critChance, closeTo(.05, 1e-10));
    expect(initial.critDamage, 1.5);
    expect(initial.dps.toDouble(), closeTo(14.35, 1e-10));
    game
      ..kills = 100000
      ..stage = 100
      ..distance = 1e10;
    game.character
      ..gold = Amount.fromLog(100)
      ..books = Amount.fromLog(100);
    expect(game.stats.maxHp.log10, initial.maxHp.log10);
    expect(game.stats.damage.log10, initial.damage.log10);
    game.character.equipment.addAll({'armor': 7, 'weapon': 5});
    final fresh = CharacterProgress()
      ..equipment.addAll(game.character.equipment);
    expect(CharacterStats.calculate(fresh).maxHp.log10, game.stats.maxHp.log10);
    expect(game.stats.maxHp.toDouble(), closeTo(120 * pow(1.05, 7), 1e-9));
    expect(game.stats.damage.toDouble(), closeTo(14 * pow(1.05, 5), 1e-9));
  });

  test('natural no-crit Stage 1: 20 hero hits, 15 enemy hits, HP 28.2', () {
    final game = GameSimulation(random: ConstantRandom());
    final hits = <(bool, bool, double)>[];
    var rewards = 0;
    for (var tick = 0; tick < 20000 && game.stage == 1; tick++) {
      game.advance(GameBalance.fixedStep);
      for (final event in game.events) {
        if (event.damage case final hit?) {
          hits.add((hit.fromHero, hit.critical, hit.amount.toDouble()));
        }
        if (event.kind == 'reward') rewards++;
      }
      game.events.clear();
    }
    expect(game.stage, 2);
    expect(game.wave, 1);
    expect(game.kills, 5);
    expect(rewards, 5);
    expect(hits.where((h) => h.$1).length, 20);
    expect(hits.where((h) => !h.$1).length, 15);
    expect(hits.every((h) => !h.$2), isTrue);
    expect(
      hits.where((h) => !h.$1).map((h) => h.$3).take(12),
      everyElement(closeTo(6, 1e-10)),
    );
    expect(
      hits.where((h) => !h.$1).map((h) => h.$3).skip(12),
      everyElement(closeTo(6.6, 1e-10)),
    );
    expect(game.heroHp.toDouble(), closeTo(28.2, 1e-9));
    expect(game.stats.maxHp.toDouble(), closeTo(120, 1e-10));
    expect(game.stats.damage.toDouble(), closeTo(14, 1e-10));
  });

  test('reward occurs once after death boundary without HP recovery', () {
    final game = GameSimulation(random: ConstantRandom())
      ..heroHp = Amount.fromNum(50);
    game.spawnEnemy();
    game.killEnemy();
    expect(game.kills, 0);
    expect(game.character.gold.isZero, isTrue);
    game.advance(GameBalance.fixedStep);
    expect(game.kills, 0);
    while (game.phase == GamePhase.enemyDeath) {
      game.advance(GameBalance.fixedStep);
    }
    expect(game.phase, GamePhase.reward);
    expect(game.heroHp.toDouble(), closeTo(50, 1e-10));
    expect(game.character.gold.toDouble(), closeTo(12, 1e-10));
    game.advance(.5);
    expect(game.kills, 1);
    expect(game.character.gold.toDouble(), closeTo(12, 1e-10));
  });

  test(
    'HP purchase restores only real max HP delta; failures and death do not heal',
    () {
      final game = GameSimulation(random: ConstantRandom())
        ..heroHp = Amount.fromNum(50);
      final armor = EquipmentCatalog.items.singleWhere((d) => d.id == 'armor');
      final weapon = EquipmentCatalog.items.singleWhere(
        (d) => d.id == 'weapon',
      );
      expect(game.purchaseEquipment(armor.id), 0);
      expect(game.heroHp.toDouble(), closeTo(50, 1e-10));
      expect(game.character.equipment, isEmpty);
      game.character.gold = Amount.fromNum(1000);
      expect(game.purchaseEquipment(armor.id), 1);
      expect(game.stats.maxHp.toDouble(), closeTo(126, 1e-9));
      expect(game.heroHp.toDouble(), closeTo(56, 1e-9));
      expect(game.purchaseEquipment(weapon.id), 1);
      for (final d in EquipmentCatalog.items.where(
        (d) => [
          CharacterStat.critChance,
          CharacterStat.critDamage,
        ].contains(d.stat),
      )) {
        game.purchaseEquipment(d.id);
      }
      expect(game.heroHp.toDouble(), closeTo(56, 1e-9));
      game.killHero();
      expect(game.purchaseEquipment(armor.id), 1);
      expect(game.heroHp.isZero, isTrue);
      game.advance(.2);
      expect(game.heroHp.isZero, isTrue);
      game.advance(4);
      expect(game.heroHp.log10, game.stats.maxHp.log10);
    },
  );

  for (final stage in [1, 10]) {
    test(
      'death at stage $stage preserves permanent progress until respawn',
      () {
        final game = GameSimulation(random: ConstantRandom())
          ..stage = stage
          ..stageKills = 4
          ..kills = 123;
        game.character
          ..gold = Amount.fromNum(456)
          ..books = Amount.fromNum(7);
        game.character.equipment['weapon'] = 3;
        final before = game.character.toJson();
        game.spawnEnemy();
        game.killHero();
        expect(game.stage, max(1, stage - 1));
        expect(game.wave, 1);
        expect(game.heroHp.isZero, isTrue);
        expect(game.kills, 123);
        expect(game.character.toJson(), before);
        game.advance(3);
        expect(game.heroHp.log10, game.stats.maxHp.log10);
      },
    );
  }

  test('rest and suspend provide no reward, growth or healing', () {
    final game = GameSimulation(random: ConstantRandom())
      ..heroHp = Amount.fromNum(50);
    game.idle.setIdleSeconds(301);
    final before = game.character.toJson();
    final hp = game.heroHp.log10;
    final distance = game.distance;
    for (var i = 0; i < 200; i++) {
      game.advance(.1);
    }
    expect(game.isResting, isTrue);
    expect(game.distance, distance);
    expect(game.character.toJson(), before);
    expect(game.heroHp.log10, hp);
    game.advance(3600);
    expect(game.kills, 0);
    expect(game.character.toJson(), before);
    expect(game.heroHp.log10, hp);
  });
}
