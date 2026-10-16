import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/domain/activity/adventure_break_reminder.dart';

void main() {
  test('First reminder at 40 minutes, then every 3 minutes', () {
    final reminder = AdventureBreakReminder();
    reminder.advance(2399);
    expect(reminder.revision, 0);
    reminder.advance(1);
    expect(reminder.revision, 1);
    reminder.advance(179);
    expect(reminder.revision, 1);
    reminder.advance(1);
    expect(reminder.revision, 2);
    reminder.advance(180);
    expect(reminder.revision, 3);
  });

  test('Frame partitions preserve reminder boundaries', () {
    final reminder = AdventureBreakReminder();
    for (var i = 0; i < 40 * 60 * 60; i++) {
      reminder.advance(1 / 60);
    }
    expect(reminder.revision, 1);
    for (var i = 0; i < 3 * 60 * 60; i++) {
      reminder.advance(1 / 60);
    }
    expect(reminder.revision, 2);
  });

  test('Rest restarts 40-minute grace period without replaying old events', () {
    final reminder = AdventureBreakReminder()..advance(2400);
    reminder.reset();
    expect(reminder.revision, 1);
    expect(reminder.elapsedSeconds, 0);
    reminder.advance(2399);
    expect(reminder.revision, 1);
    reminder.advance(1);
    expect(reminder.revision, 2);
  });

  test('Invalid deltas are ignored and missed boundaries do not burst', () {
    final reminder = AdventureBreakReminder();
    for (final value in [double.nan, double.infinity, -1.0, 0.0]) {
      reminder.advance(value);
    }
    expect(reminder.elapsedSeconds, 0);
    reminder.advance(2940);
    expect(reminder.revision, 1);
    reminder.advance(179);
    expect(reminder.revision, 1);
    reminder.advance(1);
    expect(reminder.revision, 2);
  });
}
