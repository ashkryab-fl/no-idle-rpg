import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/domain/adventure/stage_attempt.dart';
import 'package:idle_companion/domain/adventure/stage_settlement.dart';

List<EncounterPlan> plan() => [
  for (var i = 0; i < 5; i++)
    EncounterPlan(
      'gobli_low',
      100 + i.toDouble(),
      Amount.fromNum(i == 4 ? 24 : 12),
    ),
];
CharacterProgress funded([int frontier = 100]) => CharacterProgress()
  ..books = Amount.fromNum(10000)
  ..talents.highestFirstClearedStage = frontier;
SettlementResult clear(
  CharacterProgress hero,
  int stage, {
  Amount? hp,
  Map<String, int> ranks = const {},
}) {
  hero.talents.ownedRanks.addAll(ranks);
  for (final id in ranks.keys) {
    hero.talents.selectedForNextAttempt[TalentCatalog.require(id).pair] = id;
  }
  final attempt = StageAttempt.begin(hero.talents, stage, plan());
  var health = hp ?? Amount.fromNum(60);
  late SettlementResult result;
  for (var wave = 1; wave <= 5; wave++) {
    result = const StageSettlement().settle(
      hero,
      attempt,
      wave,
      hp: health,
      maxHp: Amount.fromNum(120),
    );
    health = result.hp;
  }
  return result;
}

void main() {
  test(
    'stage heal caps missing HP and dead settlement cannot revive or pay',
    () {
      final hero = funded();
      final result = clear(
        hero,
        101,
        hp: Amount.fromNum(110),
        ranks: {'stage_heal': 10},
      );
      expect(result.hp.toDouble(), closeTo(120, 1e-9));
      expect(result.healed.toDouble(), closeTo(10, 1e-9));
      final attempt = StageAttempt.begin(hero.talents, 102, plan());
      final before = jsonEncode(hero.toJson());
      expect(
        () => const StageSettlement().settle(
          hero,
          attempt,
          1,
          hp: Amount.zero,
          maxHp: Amount.fromNum(120),
        ),
        throwsStateError,
      );
      expect(jsonEncode(hero.toJson()), before);
    },
  );
  test('gates, partial x10/MAX, fractional affordability and stale quote', () {
    final hero = funded(0), p = TalentPurchases();
    expect(p.purchase(hero, 'boss_damage'), 0);
    hero.talents.highestFirstClearedStage = 1;
    hero.books = Amount.fromNum(8.4);
    expect(p.quote(hero, 'boss_damage', count: 10).count, 2);
    final old = p.quote(hero, 'boss_damage', count: 10);
    hero.books = Amount.fromNum(3);
    expect(p.purchase(hero, old.id, count: 10), 1);
    hero.books = Amount.fromNum(10000);
    expect(p.purchase(hero, 'boss_damage', count: null), 2);
    expect(p.purchase(hero, 'stage_heal'), 0);
    hero.talents.highestFirstClearedStage = 5;
    expect(p.purchase(hero, 'stage_heal', count: null), 3);
    hero.talents.highestFirstClearedStage = 20;
    expect(p.purchase(hero, 'boss_damage', count: null), 3);
    hero.talents.highestFirstClearedStage = 100;
    expect(p.purchase(hero, 'boss_damage', count: null), 4);
  });
  test('Gold cannot fund talents; single and bulk debits agree', () {
    final hero = funded()
      ..books = Amount.zero
      ..gold = Amount.fromNum(10000);
    final p = TalentPurchases();
    final gold = hero.gold;
    expect(p.purchase(hero, 'boss_damage', count: null), 0);
    expect(hero.gold, same(gold));
    final singles = funded(), bulk = funded();
    for (var i = 0; i < 10; i++) {
      expect(p.purchase(singles, 'boss_damage'), 1);
    }
    expect(p.purchase(bulk, 'boss_damage', count: null), 10);
    expect(singles.books.toDouble(), closeTo(bulk.books.toDouble(), 1e-8));
    expect(singles.talents.ownedRanks, bulk.talents.ownedRanks);
  });
  test(
    'domain rejects arbitrary IDs, invalid count/pair and unowned selection',
    () {
      final hero = funded(), p = TalentPurchases();
      final before = jsonEncode(hero.toJson());
      expect(() => p.purchase(hero, 'invented'), throwsArgumentError);
      for (final count in [-1, 9007199254740992]) {
        expect(
          () => p.purchase(hero, 'boss_damage', count: count),
          throwsArgumentError,
        );
      }
      expect(
        () => p.select(hero, TalentPair.boss, 'stage_heal'),
        throwsArgumentError,
      );
      expect(
        () => p.select(hero, TalentPair.boss, 'boss_damage'),
        throwsArgumentError,
      );
      expect(jsonEncode(hero.toJson()), before);
    },
  );
  test(
    'cursor rejects duplicate/out of order settlements without rewards/heal',
    () {
      final hero = CharacterProgress(),
          a = StageAttempt.begin(CharacterProgress().talents, 1, plan());
      hero.talents.nextAttemptId = 2;
      final s = const StageSettlement();
      final hp = Amount.fromNum(50), maxHp = Amount.fromNum(120);
      expect(
        () => s.settle(hero, a, 2, hp: hp, maxHp: maxHp),
        throwsStateError,
      );
      for (var wave = 1; wave <= 5; wave++) {
        s.settle(hero, a, wave, hp: hp, maxHp: maxHp);
      }
      final before = jsonEncode(hero.toJson());
      expect(s.settle(hero, a, 5, hp: hp, maxHp: maxHp).applied, isFalse);
      expect(s.settle(hero, a, 1, hp: hp, maxHp: maxHp).applied, isFalse);
      expect(jsonEncode(hero.toJson()), before);
      final b = StageAttempt.begin(hero.talents, 2, plan());
      expect(
        () => s.settle(hero, b, 1, hp: Amount.zero, maxHp: maxHp),
        throwsStateError,
      );
    },
  );
  test(
    'death closes unsettled callbacks without claims, before and after new attempt/restart',
    () {
      final hero = CharacterProgress(), s = const StageSettlement();
      final old = StageAttempt.begin(hero.talents, 1, plan());
      final hp = Amount.fromNum(50), maxHp = Amount.fromNum(120);
      for (var wave = 1; wave < 5; wave++) {
        s.settle(hero, old, wave, hp: hp, maxHp: maxHp);
      }
      hero.talents.abandonAttempt(old.id);
      final loaded = CharacterProgress.fromJson(
        jsonDecode(jsonEncode(hero.toJson())),
      );
      final before = jsonEncode(loaded.toJson());
      expect(s.settle(loaded, old, 5, hp: hp, maxHp: maxHp).applied, isFalse);
      expect(jsonEncode(loaded.toJson()), before);
      expect(loaded.books.isZero, isTrue);
      expect(loaded.talents.highestFirstClearedStage, 0);
      StageAttempt.begin(loaded.talents, 1, plan());
      expect(s.settle(loaded, old, 5, hp: hp, maxHp: maxHp).applied, isFalse);
    },
  );
}
