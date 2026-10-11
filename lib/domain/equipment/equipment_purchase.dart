import '../../core/balance/equipment_curve_profile.dart';
import '../../core/numbers/amount.dart';
import '../character/character.dart';
import 'equipment.dart';

enum PurchaseCurrency { gold, books }

class EquipmentQuote {
  const EquipmentQuote({
    required this.id,
    required this.level,
    required this.count,
    required this.cost,
    required this.before,
    required this.after,
    this.blockedReason,
  });
  final String id;
  final int level, count;
  final Amount cost, before, after;
  final String? blockedReason;
}

/// Accepts registered IDs, never arbitrary definitions or a wallet-selection bool.
class EquipmentPurchases {
  const EquipmentPurchases({this.profile = EquipmentCurveProfile.candidate});
  final EquipmentCurveProfile profile;
  EquipmentQuote quote(
    CharacterProgress hero,
    String id, {
    int? count = 1,
    PurchaseCurrency currency = PurchaseCurrency.gold,
  }) {
    final item = EquipmentCatalog.require(id);
    if (currency != PurchaseCurrency.gold) {
      throw ArgumentError.value(currency, 'currency');
    }
    if (count != null && (count < 0 || count > 9007199254740991)) {
      throw ArgumentError.value(count, 'count');
    }
    final level = hero.equipment[id] ?? 0;
    final affordable = item.affordable(level, hero.gold);
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
    if (buying > 0 && !profile.changed(item.stat, level, level + buying)) {
      buying = 0;
    }
    return EquipmentQuote(
      id: id,
      level: level,
      count: buying,
      cost: item.batchCost(level, buying),
      before: before,
      after: buying == 0 ? before : after,
      blockedReason: buying > 0
          ? null
          : count == 0
          ? 'No purchase selected'
          : affordable == 0
          ? 'Not enough Gold'
          : 'Precision limit: no representable gain',
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
