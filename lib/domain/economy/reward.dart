import '../../core/numbers/amount.dart';

enum RewardSource {
  killGold,
  firstClearBaseGold,
  firstClearBonusGold,
  stageBonusGold,
  firstBooks,
  repeatBooks,
  milestoneBooks,
}

class Reward {
  const Reward({
    required this.gold,
    required this.books,
    this.lines = const {},
  });
  factory Reward.fromLines(Map<RewardSource, Amount> lines) {
    var gold = Amount.zero, books = Amount.zero;
    for (final e in lines.entries) {
      if (e.key.index < RewardSource.firstBooks.index) {
        gold = gold + e.value;
      } else {
        books = books + e.value;
      }
    }
    return Reward(gold: gold, books: books, lines: Map.unmodifiable(lines));
  }
  final Amount gold, books;
  final Map<RewardSource, Amount> lines;
  Map<String, Object?> toJson() => {
    for (final e in lines.entries) e.key.name: e.value.toJson(),
  };
  factory Reward.fromJson(Map<String, dynamic> json) => Reward.fromLines({
    for (final e in json.entries)
      RewardSource.values.byName(e.key): Amount.fromJson(e.value),
  });
}
