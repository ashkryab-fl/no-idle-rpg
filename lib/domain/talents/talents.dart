import '../../core/balance/talent_profile.dart';
import '../../core/numbers/amount.dart';
import '../character/character.dart';
import '../progression/upgrade_price.dart';
import '../progression/purchase_quote.dart';

enum TalentPair { boss, endurance, travel }

class TalentDefinition {
  const TalentDefinition(
    this.id,
    this.name,
    this.pair,
    this.unlockStage,
    this.description,
  );
  final String id, name, description;
  final TalentPair pair;
  final int unlockStage;
}

abstract final class TalentCatalog {
  static const items = [
    TalentDefinition(
      'boss_damage',
      'Boss damage',
      TalentPair.boss,
      1,
      'Extra damage only against bosses.',
    ),
    TalentDefinition(
      'first_clear_gold',
      'First-clear Gold',
      TalentPair.boss,
      1,
      'Bonus on the first-clear Gold reward. Each stage pays once.',
    ),
    TalentDefinition(
      'stage_heal',
      'Stage recovery',
      TalentPair.endurance,
      3,
      'Restore HP after all five waves. Cannot revive a dead hero.',
    ),
    TalentDefinition(
      'crit_protection',
      'Crit protection',
      TalentPair.endurance,
      3,
      'Reduce the bonus damage of enemy critical hits; normal damage and crit chance stay the same.',
    ),
    TalentDefinition(
      'shorter_travel',
      'Shorter travel',
      TalentPair.travel,
      5,
      'Shorten travel before enemies appear. Combat, approach and rest keep their timing.',
    ),
    TalentDefinition(
      'stage_gold',
      'Stage Gold',
      TalentPair.travel,
      5,
      'Extra Gold after all five waves: first clear and two repeat clears per stage.',
    ),
  ];
  static TalentDefinition require(String id) => items.firstWhere(
    (d) => d.id == id,
    orElse: () => throw ArgumentError.value(id, 'talentId'),
  );
}

class TalentProgress {
  final Map<String, int> ownedRanks = {};
  final Map<TalentPair, String> selectedForNextAttempt = {};
  int highestFirstClearedStage = 0;
  // Missing entry means zero repeats used; counts saturate, never reset on death.
  final Map<int, int> usedRepeats = {};
  int nextAttemptId = 1;
  // Monotonic resolved-event cursor; wave 5 also closes an abandoned attempt.
  // First-clear history is separate, so abandoning never awards completion.
  int lastSettledAttempt = 0, lastSettledWave = 0;
  void abandonAttempt(int id) {
    if (id < 1 || id >= nextAttemptId) {
      throw ArgumentError.value(id, 'attemptId');
    }
    if (id < lastSettledAttempt) return;
    lastSettledAttempt = id;
    lastSettledWave = 5;
  }

  int get availableRank => highestFirstClearedStage >= 100
      ? 10
      : highestFirstClearedStage >= 20
      ? 6
      : 3;
  int rankLimit(TalentDefinition d, TalentProfile profile) =>
      highestFirstClearedStage < d.unlockStage
      ? 0
      : availableRank.clamp(0, profile.curves[d.id]!.cap);
  int clearedCount(int stage) =>
      stage > highestFirstClearedStage ? 0 : 1 + (usedRepeats[stage] ?? 0);
  int repeatsRemaining(int stage, int limit) =>
      (limit - (usedRepeats[stage] ?? 0)).clamp(0, limit);
  void reset() {
    ownedRanks.clear();
    selectedForNextAttempt.clear();
    usedRepeats.clear();
    highestFirstClearedStage = 0;
    nextAttemptId = 1;
    lastSettledAttempt = lastSettledWave = 0;
  }

  Map<String, Object?> toJson() => {
    'ownedRanks': ownedRanks,
    'selectedForNextAttempt': {
      for (final e in selectedForNextAttempt.entries) e.key.name: e.value,
    },
    'highestFirstClearedStage': highestFirstClearedStage,
    'usedRepeats': {for (final e in usedRepeats.entries) '${e.key}': e.value},
    'nextAttemptId': nextAttemptId,
    'lastSettledAttempt': lastSettledAttempt,
    'lastSettledWave': lastSettledWave,
  };
  TalentProgress();
  factory TalentProgress.fromJson(Map<String, dynamic> json) {
    final p = TalentProgress();
    int counter(String key, int fallback) {
      final n = json[key] ?? fallback;
      if (n is! int || n < 0 || n > UpgradePrice.maxLevel) {
        throw FormatException('Invalid $key');
      }
      return n;
    }

    p.highestFirstClearedStage = counter('highestFirstClearedStage', 0);
    p.nextAttemptId = counter('nextAttemptId', 1);
    p.lastSettledAttempt = counter('lastSettledAttempt', 0);
    p.lastSettledWave = counter('lastSettledWave', 0);
    if (p.nextAttemptId < 1 ||
        p.lastSettledAttempt >= p.nextAttemptId ||
        p.lastSettledWave > 5 ||
        (p.lastSettledAttempt == 0) != (p.lastSettledWave == 0)) {
      throw const FormatException('Invalid settlement cursor');
    }
    for (final e in Map<String, dynamic>.from(
      json['ownedRanks'] as Map? ?? {},
    ).entries) {
      final d = TalentCatalog.require(e.key);
      if (e.value is! int ||
          e.value < 0 ||
          e.value > p.rankLimit(d, TalentProfile.candidate)) {
        throw const FormatException('Invalid talent rank/gate');
      }
      p.ownedRanks[e.key] = e.value;
    }
    for (final e in Map<String, dynamic>.from(
      json['selectedForNextAttempt'] as Map? ?? {},
    ).entries) {
      final pair = TalentPair.values.firstWhere((p) => p.name == e.key);
      final d = TalentCatalog.require(e.value as String);
      if (d.pair != pair || (p.ownedRanks[d.id] ?? 0) < 1) {
        throw const FormatException('Invalid selected talent');
      }
      p.selectedForNextAttempt[pair] = d.id;
    }
    for (final e in Map<String, dynamic>.from(
      json['usedRepeats'] as Map? ?? {},
    ).entries) {
      final stage = int.tryParse(e.key);
      if (stage == null ||
          stage < 1 ||
          stage > p.highestFirstClearedStage ||
          e.value is! int ||
          e.value < 1 ||
          e.value > 2) {
        throw const FormatException('Invalid repeat ledger');
      }
      p.usedRepeats[stage] = e.value;
    }
    return p;
  }
}

class TalentQuote extends PurchaseQuote<double> {
  const TalentQuote({
    required super.id,
    required super.rank,
    required super.count,
    required super.cost,
    required super.nextCost,
    required super.before,
    required super.after,
    required super.delta,
    super.limit,
    super.requiredStage,
  }) : super(currency: PurchaseCurrency.books);
  String? get reason => blockedReason;
}

class TalentPurchases {
  TalentPurchases({this.profile = TalentProfile.candidate}) {
    profile.validate();
  }
  final TalentProfile profile;
  TalentQuote quote(CharacterProgress hero, String id, {int? count = 1}) {
    final d = TalentCatalog.require(id), curve = profile.curves[id]!;
    if (count != null && (count < 0 || count > UpgradePrice.maxLevel)) {
      throw ArgumentError.value(count, 'count');
    }
    final rank = hero.talents.ownedRanks[id] ?? 0;
    final limit = hero.talents.rankLimit(d, profile);
    final price = UpgradePrice(
      baseCost: curve.baseCost,
      costGrowth: curve.costGrowth,
    );
    final affordable = price.affordable(rank, hero.books);
    var useful = 0;
    for (var n = rank; n < limit; n++) {
      if (curve.value(n + 1) <= curve.value(n)) break;
      useful++;
    }
    final buying = (count ?? curve.cap).clamp(0, affordable.clamp(0, useful));
    final before = curve.value(rank), after = curve.value(rank + buying);
    final nextRank = rank + buying;
    final boundary = count == 0
        ? PurchaseLimit.noSelection
        : count != null && buying == count
        ? null
        : nextRank >= curve.cap
        ? PurchaseLimit.maximumRank
        : nextRank >= limit
        ? PurchaseLimit.milestone
        : curve.value(nextRank + 1) <= curve.value(nextRank)
        ? PurchaseLimit.precision
        : PurchaseLimit.insufficientCurrency;
    return TalentQuote(
      id: id,
      rank: rank,
      count: buying,
      cost: price.batchCost(rank, buying),
      nextCost: rank == curve.cap ? Amount.zero : price.cost(rank),
      before: before,
      after: after,
      delta: after - before,
      limit: boundary,
      requiredStage: boundary == PurchaseLimit.milestone
          ? limit == 0
                ? d.unlockStage
                : limit == 3
                ? 20
                : 100
          : null,
    );
  }

  int purchase(CharacterProgress hero, String id, {int? count = 1}) {
    final q = quote(hero, id, count: count);
    if (q.count == 0 || q.after <= q.before) return 0;
    hero.books = hero.books - q.cost;
    hero.talents.ownedRanks[id] = q.rank + q.count;
    return q.count;
  }

  void select(CharacterProgress hero, TalentPair pair, String? id) {
    if (id == null) {
      hero.talents.selectedForNextAttempt.remove(pair);
      return;
    }
    final d = TalentCatalog.require(id);
    if (d.pair != pair ||
        hero.talents.rankLimit(d, profile) == 0 ||
        (hero.talents.ownedRanks[id] ?? 0) < 1) {
      throw ArgumentError('Unavailable talent/pair');
    }
    hero.talents.selectedForNextAttempt[pair] = id;
  }
}
