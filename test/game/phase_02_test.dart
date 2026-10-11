import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/equipment_curve_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/equipment/equipment.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import '../../tool/balance/simulate_progression.dart';
import 'phase_01_test.dart' show ConstantRandom;

void main() {
  test('Armor across threshold heals actual fractional max HP delta', () {
    final hero = CharacterProgress()
      ..equipment['armor'] = 100
      ..gold = Amount.fromLog(100);
    final runtime = GameSimulation(character: hero, random: ConstantRandom());
    final oldMax = runtime.stats.maxHp;
    runtime.heroHp = oldMax.scale(.4);
    final before = runtime.heroHp;
    expect(runtime.purchaseEquipment('armor'), 1);
    expect(
      runtime.heroHp.log10,
      (before + (runtime.stats.maxHp - oldMax)).log10,
    );
    expect(runtime.stats.maxHp.ratio(oldMax) - 1, lessThan(.05));
    final modelHero = CharacterProgress()
      ..equipment['armor'] = 100
      ..gold = EquipmentCatalog.require('armor').cost(100);
    final model = ProgressionSimulation(
      character: modelHero,
      random: ConstantRandom(),
      strategy: InvestmentStrategy.armorOnly,
    )..hp = before;
    model.invest();
    expect(model.hero.equipment, runtime.character.equipment);
    expect(model.hp.log10, runtime.heroHp.log10);
  });
  test(
    'Weapon purchase changes natural combat hit count and HP, not forced rewards',
    () {
      final plain = GameSimulation(random: ConstantRandom());
      final equipped = GameSimulation(random: ConstantRandom());
      equipped.character.gold = EquipmentCatalog.require(
        'weapon',
      ).batchCost(0, 10);
      equipped.purchaseEquipment('weapon', count: 10);
      for (final sim in [plain, equipped]) {
        while (sim.kills == 0) {
          sim.advance(1 / 60);
        }
      }
      expect(equipped.heroHp > plain.heroHp, isTrue);
      expect(plain.kills, 1);
      expect(equipped.kills, 1);
      expect(plain.character.gold.toDouble(), closeTo(12, 1e-10));
      expect(equipped.character.gold.toDouble(), closeTo(12, 1e-8));
    },
  );
  test('income stress reinvests Gold and source rewards do not double count', () {
    const policy = InvestmentStrategy.noPurchases;
    final base = ProgressionSimulation(
      random: ConstantRandom(),
      strategy: policy,
    );
    final bonus = ProgressionSimulation(
      random: ConstantRandom(),
      strategy: policy,
      income: const IncomeStress(killGoldMultiplier: 1.75),
    );
    base.runUntil(1800);
    bonus.runUntil(1800);
    expect(bonus.kills, base.kills);
    expect(bonus.stage, base.stage);
    expect(bonus.goldEarned.ratio(base.goldEarned), closeTo(1.75, 1e-10));
    expect(bonus.booksEarned.log10, base.booksEarned.log10);
    final first = ProgressionSimulation(
      random: ConstantRandom(),
      strategy: policy,
      income: const IncomeStress(firstClearGoldBonus: .25),
    );
    first.runUntil(1800);
    expect(first.firstGoldEarned.toDouble(), closeTo(3, 1e-10));
    expect(first.stageGoldEarned.isZero, isTrue);
    var expectedGold = Amount.zero;
    final fast = ProgressionSimulation(
      onEncounter: (event) {
        if (event['victory'] == true) {
          expectedGold =
              expectedGold +
              Amount.fromNum(12).grow(1.1, (event['stage'] as int) - 1);
        }
      },
      random: ConstantRandom(),
      strategy: policy,
      income: const IncomeStress(travelFactor: .5),
    );
    fast.runUntil(1800);
    expect(fast.kills, greaterThan(base.kills));
    expect(fast.goldEarned.log10, closeTo(expectedGold.log10, 1e-12));
    // The per-kill reward is unchanged; higher income comes from more victories.
    expect(fast.killGoldEarned.log10, fast.goldEarned.log10);
  });
  test(
    'crafted high-crit contexts give both offensive crit items real effects',
    () {
      for (final id in ['helmet', 'amulet']) {
        final hero = CharacterProgress()
          ..equipment.addAll({
            'weapon': 200,
            'armor': 200,
            'helmet': id == 'amulet' ? 500 : 0,
            'amulet': id == 'helmet' ? 150 : 0,
          })
          ..gold = Amount.fromLog(100);
        final sim = GameSimulation(character: hero, random: ConstantRandom());
        final before = sim.stats;
        expect(sim.purchaseEquipment(id), 1);
        expect(sim.stats.dps > before.dps, isTrue);
        expect(sim.stats.maxHp.log10, before.maxHp.log10);
        expect(sim.stats.attackSpeed, 1);
      }
    },
  );
  test('different equipment order gives the same final four curves', () {
    final a = GameSimulation(random: ConstantRandom()),
        b = GameSimulation(random: ConstantRandom());
    a.character.gold = b.character.gold = Amount.fromLog(1000);
    for (final id in ['weapon', 'armor', 'helmet', 'amulet']) {
      a.purchaseEquipment(id, count: 250);
    }
    for (final id in ['amulet', 'helmet', 'armor', 'weapon']) {
      b.purchaseEquipment(id, count: 250);
    }
    expect(a.character.equipment, b.character.equipment);
    expect(a.stats.damage.log10, b.stats.damage.log10);
    expect(a.stats.maxHp.log10, b.stats.maxHp.log10);
    expect(a.stats.critChance, b.stats.critChance);
    expect(a.stats.critDamage, b.stats.critDamage);
    expect(a.curveProfile.id, EquipmentCurveProfile.candidate.id);
  });
}
