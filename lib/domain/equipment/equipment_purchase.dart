import '../../core/balance/equipment_curve_profile.dart';
import '../../core/balance/economy_profile.dart';
import '../../core/numbers/amount.dart';
import '../../core/numbers/stable_math.dart';
import '../character/character.dart';
import '../progression/purchase_quote.dart';
import '../progression/upgrade_price.dart';
import 'equipment.dart';
export '../progression/purchase_quote.dart' show PurchaseCurrency;

class EquipmentQuote extends PurchaseQuote<Amount> {
  const EquipmentQuote({
    required super.id,
    required int level,
    required super.count,
    required super.cost,
    required super.nextCost,
    required super.before,
    required super.after,
    required super.delta,
    required this.relativePercent,
    super.limit,
  }) : super(rank: level, currency: PurchaseCurrency.gold);
  int get level => rank;
  final Amount relativePercent;
}

/// Accepts registered IDs, never arbitrary definitions or a wallet-selection bool.
class EquipmentPurchases {
  const EquipmentPurchases({
    this.profile = EquipmentCurveProfile.candidate,
    this.economy = EconomyProfile.candidate,
  });
  final EquipmentCurveProfile profile;
  final EconomyProfile economy;
  EquipmentQuote quote(
    CharacterProgress hero,
    String id, {
    int? count = 1,
    PurchaseCurrency currency = PurchaseCurrency.gold,
  }) {
    final item = EquipmentCatalog.require(id);
    economy.validate();
    final price = item.priceFor(economy);
    if (currency != PurchaseCurrency.gold) {
      throw ArgumentError.value(currency, 'currency');
    }
    if (count != null && (count < 0 || count > UpgradePrice.maxLevel)) {
      throw ArgumentError.value(count, 'count');
    }
    final level = hero.equipment[id] ?? 0;
    final affordable = price.affordable(level, hero.gold);
    var buying = count == null ? affordable : count.clamp(0, affordable);
    // usefulRank is monotone by construction: shrinking analytic gains and
    // increasing precision spacing. MAX requires at most 53 predicate probes.
    var low = 0, high = buying;
    while (low < high) {
      final middle = low + (high - low + 1) ~/ 2;
      if (profile.usefulRank(item.stat, level + middle)) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    buying = low;
    final before = profile.value(item.stat, level);
    final after = profile.value(item.stat, level + buying);
    final numericalPlateau =
        buying > 0 && !profile.changed(item.stat, level, level + buying);
    if (numericalPlateau) {
      buying = 0;
    }
    PurchaseLimit nextLimit() {
      if (level + buying == UpgradePrice.maxLevel) {
        return PurchaseLimit.maximumRank;
      }
      final next = level + buying + 1;
      if (!profile.usefulRank(item.stat, next)) {
        return item.stat == CharacterStat.critChance &&
                profile.chance.gain(next) >= StableMath.ulp(profile.chance.cap)
            ? PurchaseLimit.minimumEffect
            : PurchaseLimit.precision;
      }
      return PurchaseLimit.insufficientCurrency;
    }

    final result = buying == 0 ? before : after;
    final delta = buying == 0
        ? Amount.zero
        : switch (item.stat) {
            CharacterStat.critChance => Amount.fromNum(
              profile.chance.value(level + buying) -
                  profile.chance.value(level),
            ),
            CharacterStat.critDamage => Amount.fromNum(
              profile.multiplier.value(level + buying) -
                  profile.multiplier.value(level),
            ),
            _ => result - before,
          };
    return EquipmentQuote(
      id: id,
      level: level,
      count: buying,
      cost: price.batchCost(level, buying),
      nextCost: level == UpgradePrice.maxLevel
          ? Amount.zero
          : price.cost(level),
      before: before,
      after: result,
      delta: delta,
      relativePercent: delta.isZero
          ? Amount.zero
          : delta.scale(100) * Amount.fromLog(-before.log10),
      limit: count == 0
          ? PurchaseLimit.noSelection
          : numericalPlateau
          ? PurchaseLimit.precision
          : count == null || buying < count
          ? nextLimit()
          : null,
    );
  }

  int purchase(
    CharacterProgress hero,
    String id, {
    int? count = 1,
    PurchaseCurrency currency = PurchaseCurrency.gold,
  }) {
    // Recompute against current state; a UI quote is never a debit instruction.
    final current = quote(hero, id, count: count, currency: currency);
    if (current.count == 0) return 0;
    hero.gold = hero.gold - current.cost;
    hero.equipment[id] = current.level + current.count;
    return current.count;
  }
}
