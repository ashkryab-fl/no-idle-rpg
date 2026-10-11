import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/balance/talent_profile.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/character/character.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/domain/adventure/stage_attempt.dart';
import 'package:idle_companion/domain/adventure/stage_settlement.dart';
import 'package:idle_companion/domain/economy/reward.dart';

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
  for (final definition in TalentCatalog.items) {
    test(
      '${definition.id}: bounded diminishing effect and geometric Books cost',
      () {
        final curve = TalentProfile.candidate.curves[definition.id]!;
        expect(curve.value(0), 0);
        expect(curve.value(10), curve.maximum);
        var previous = double.infinity;
        for (var n = 1; n <= 10; n++) {
          final gain = curve.value(n) - curve.value(n - 1);
          expect(gain, greaterThan(0));
          expect(gain, lessThan(previous));
          previous = gain;
        }
        expect(() => curve.value(-1), throwsArgumentError);
        expect(() => curve.value(11), throwsArgumentError);
        final hero = funded(), purchases = TalentPurchases();
        final gold = hero.gold;
        final quote = purchases.quote(hero, definition.id, count: null);
        expect(quote.count, 10);
        expect(quote.cost.toDouble(), closeTo(544.755813888, 1e-7));
        expect(purchases.purchase(hero, definition.id, count: null), 10);
        expect(hero.gold, same(gold));
        expect(hero.talents.selectedForNextAttempt, isEmpty);
        expect(purchases.purchase(hero, definition.id), 0);
      },
    );
  }
  test(
    'invalid profiles fail before mutation; precision limit bounds partial MAX',
    () {
      for (final curve in [
        const TalentCurve(cap: 0, maximum: .5),
        const TalentCurve(tau: 0, maximum: .5),
        const TalentCurve(tau: double.nan, maximum: .5),
        const TalentCurve(maximum: double.infinity),
        const TalentCurve(maximum: .8),
        const TalentCurve(maximum: .5, baseCost: 0),
        const TalentCurve(maximum: .5, costGrowth: .9),
      ]) {
        expect(
          () => TalentPurchases(profile: TalentProfile(bossDamage: curve)),
          throwsArgumentError,
        );
      }
      final hero = funded();
      final p = TalentPurchases(
        profile: const TalentProfile(
          id: 'tiny_tau',
          bossDamage: TalentCurve(tau: .0001, maximum: .5),
        ),
      );
      expect(p.quote(hero, 'boss_damage', count: null).count, 1);
      expect(p.purchase(hero, 'boss_damage', count: null), 1);
      final wallet = hero.books;
      expect(p.purchase(hero, 'boss_damage', count: null), 0);
      expect(hero.books, same(wallet));
      final before = hero.talents.nextAttemptId;
      expect(
        () => StageAttempt.begin(hero.talents, 0, plan()),
        throwsArgumentError,
      );
      expect(hero.talents.nextAttemptId, before);
    },
  );
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
    hero.books = Amount.fromNum(7.8);
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
    'all eight choices and nulls are immutable across purchases/selection',
    () {
      final hero = funded(), p = TalentPurchases();
      for (final d in TalentCatalog.items) {
        p.purchase(hero, d.id, count: 1);
      }
      for (var mask = 0; mask < 8; mask++) {
        for (var pair = 0; pair < 3; pair++) {
          p.select(
            hero,
            TalentPair.values[pair],
            TalentCatalog.items[2 * pair + ((mask >> pair) & 1)].id,
          );
        }
        final a = StageAttempt.begin(hero.talents, 1, plan());
        expect(a.ranks.length, 3);
        p.purchase(hero, 'boss_damage');
        p.select(hero, TalentPair.boss, null);
        expect(a.ranks.values, everyElement(lessThanOrEqualTo(10)));
        expect(() => a.ranks['boss_damage'] = 2, throwsUnsupportedError);
      }
      for (final pair in TalentPair.values) {
        p.select(hero, pair, null);
      }
      expect(
        StageAttempt.begin(hero.talents, 1, plan()).effects.values,
        isEmpty,
      );
    },
  );
  test(
    'stage settlement separates sources, heals once and uses full nominal plan',
    () {
      final hero = funded(100);
      final r = clear(
        hero,
        101,
        ranks: {'first_clear_gold': 10, 'stage_heal': 10, 'stage_gold': 10},
      );
      expect(
        r.reward.lines[RewardSource.killGold]!.toDouble(),
        closeTo(24, 1e-9),
      );
      expect(
        r.reward.lines[RewardSource.firstClearBaseGold]!.toDouble(),
        closeTo(24, 1e-9),
      );
      expect(
        r.reward.lines[RewardSource.firstClearBonusGold]!.toDouble(),
        closeTo(12, 1e-9),
      );
      expect(
        r.reward.lines[RewardSource.stageBonusGold]!.toDouble(),
        closeTo(36, 1e-9),
      );
      expect(r.reward.books.toDouble(), closeTo(3, 1e-9));
      expect(r.hp.toDouble(), closeTo(84, 1e-9));
      expect(hero.gold.toDouble(), closeTo(144, 1e-9));
    },
  );
  test(
    'first clear, two repeats then zero; inactive clears consume quota; death cannot reset it',
    () {
      final hero = CharacterProgress();
      clear(hero, 1);
      expect(hero.books.toDouble(), closeTo(3, 1e-9));
      clear(hero, 1);
      clear(hero, 1);
      expect(hero.books.toDouble(), closeTo(5, 1e-9));
      hero.talents.highestFirstClearedStage = 5;
      final r = clear(hero, 1, ranks: {'first_clear_gold': 1, 'stage_gold': 1});
      expect(r.reward.books.isZero, isTrue);
      expect(
        r.reward.lines.containsKey(RewardSource.firstClearBaseGold),
        isFalse,
      );
      expect(r.reward.lines.containsKey(RewardSource.stageBonusGold), isFalse);
      expect(hero.talents.usedRepeats, {1: 2});
      final restored = CharacterProgress.fromJson(
        jsonDecode(jsonEncode(hero.toJson())),
      );
      expect(clear(restored, 1).reward.books.isZero, isTrue);
    },
  );
  test(
    'milestones 5/10/20/40 deduplicate 20 and derive claims from frontier',
    () {
      final hero = CharacterProgress();
      final milestoneStages = <int>[];
      for (var stage = 1; stage <= 40; stage++) {
        final result = clear(hero, stage);
        if (result.reward.lines.containsKey(RewardSource.milestoneBooks)) {
          milestoneStages.add(stage);
        }
      }
      expect(milestoneStages, [5, 10, 20, 40]);
      expect(hero.books.toDouble(), closeTo(140, 1e-8));
      expect(
        clear(hero, 20).reward.lines.containsKey(RewardSource.milestoneBooks),
        isFalse,
      );
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
  test(
    'snapshot serialization retains effect values and rejects unknown profile/pair conflicts',
    () {
      final hero = funded();
      TalentPurchases().purchase(hero, 'boss_damage');
      TalentPurchases().select(hero, TalentPair.boss, 'boss_damage');
      final a = StageAttempt.begin(hero.talents, 1, plan());
      final json = jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>;
      (json['effects'] as Map)['boss_damage'] = .4;
      expect(StageAttempt.fromJson(json).effects['boss_damage'], .4);
      json['profileId'] = 'unknown';
      expect(() => StageAttempt.fromJson(json), throwsFormatException);
      json['profileId'] = TalentProfile.candidate.id;
      (json['ranks'] as Map)['first_clear_gold'] = 1;
      expect(() => StageAttempt.fromJson(json), throwsArgumentError);
    },
  );
}
