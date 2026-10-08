import '../../core/numbers/amount.dart';

class Reward {
  const Reward({required this.gold, required this.books, required this.xp});
  final Amount gold, books, xp;
}
