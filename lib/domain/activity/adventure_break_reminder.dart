/// Session-only, real running time; combat and death remain part of the adventure.
class AdventureBreakReminder {
  static const firstReminderSeconds = 40 * 60.0;
  static const repeatSeconds = 3 * 60.0;

  double _elapsedSeconds = 0;
  double _nextReminderSeconds = firstReminderSeconds;
  int _revision = 0;

  double get elapsedSeconds => _elapsedSeconds;
  int get revision => _revision;

  void advance(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return;
    _elapsedSeconds += seconds;
    if (_elapsedSeconds + 1e-6 < _nextReminderSeconds) return;
    // Emit one event even if a caller crosses several boundaries at once.
    _revision++;
    _nextReminderSeconds =
        firstReminderSeconds +
        ((_elapsedSeconds - firstReminderSeconds + 1e-6) ~/ repeatSeconds + 1) *
            repeatSeconds;
  }

  void reset() {
    _elapsedSeconds = 0;
    _nextReminderSeconds = firstReminderSeconds;
  }
}
