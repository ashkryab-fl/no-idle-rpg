import '../numbers/amount.dart';

class OfflineProgressResult {
  const OfflineProgressResult(
    this.duration, {
    this.distance = 0,
    this.kills = 0,
    this.gold = Amount.zero,
    this.books = Amount.zero,
  });
  final Duration duration;
  final double distance;
  final int kills;
  final Amount gold, books;
}

class OfflineProgressService {
  OfflineProgressResult calculate(DateTime? lastSave, DateTime now) =>
      OfflineProgressResult(
        lastSave == null || now.isBefore(lastSave)
            ? Duration.zero
            : now.difference(lastSave),
      );
}
