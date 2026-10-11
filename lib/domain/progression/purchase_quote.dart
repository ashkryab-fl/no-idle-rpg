import '../../core/numbers/amount.dart';

enum PurchaseCurrency { gold, books }

enum PurchaseLimit {
  noSelection,
  insufficientCurrency,
  precision,
  minimumEffect,
  maximumRank,
  milestone,
}

/// A read-only preview, never an instruction to debit a previously quoted cost.
/// Effects describe the owned stat/ability, independently of active talents.
class PurchaseQuote<T> {
  const PurchaseQuote({
    required this.id,
    required this.currency,
    required this.rank,
    required this.count,
    required this.cost,
    required this.nextCost,
    required this.before,
    required this.after,
    required this.delta,
    this.limit,
    this.requiredStage,
  });
  final String id;
  final PurchaseCurrency currency;
  final int rank, count;
  final Amount cost;

  /// Price of one rank at the current position, even when wallet/gate blocks it.
  /// Zero means that the technical/tree rank limit has been reached.
  final Amount nextCost;
  final T before, after, delta;

  /// Why the next rank cannot be included; also describes partial packages.
  final PurchaseLimit? limit;
  final int? requiredStage;
  bool get canPurchase => count > 0;
  String? get limitDescription => switch (limit) {
    null => null,
    PurchaseLimit.noSelection => 'No purchase selected',
    PurchaseLimit.insufficientCurrency =>
      'Not enough ${currency == PurchaseCurrency.gold ? "Gold" : "Books"}',
    PurchaseLimit.precision => 'Precision limit: no representable gain',
    PurchaseLimit.minimumEffect => 'Minimum gain reached',
    PurchaseLimit.maximumRank => 'Maximum rank',
    PurchaseLimit.milestone => 'Requires first clear of Stage $requiredStage',
  };
  String? get blockedReason => canPurchase ? null : limitDescription;
}
