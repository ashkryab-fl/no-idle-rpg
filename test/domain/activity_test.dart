import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/domain/activity/activity_statistics.dart';

void main() {
  test('session transitions aggregate boundaries and means', () {
    final t = DateTime(2026, 10, 8, 12);
    final activity = ActivityStatisticsService(now: t);
    activity.sample(t, true);
    for (var i = 1; i <= 6; i++) {
      activity.sample(t.add(Duration(seconds: i)), i < 4);
    }
    activity.sample(t.add(const Duration(seconds: 7)), true);
    expect(activity.today.activeSeconds, 4);
    expect(activity.today.idleSeconds, 3);
    expect(activity.today.averageActive, 4);
    expect(activity.today.averageIdle, 3);
  });
  test('local midnight splits today and retains totals', () {
    final t = DateTime(2026, 10, 8, 23, 59, 58);
    final activity = ActivityStatisticsService(now: t);
    activity.sample(t, true);
    activity.sample(t.add(const Duration(seconds: 4)), true);
    expect(activity.day, '2026-10-9');
    expect(activity.today.activeSeconds, 2);
    expect(activity.total.activeSeconds, 4);
    activity.sample(t.add(const Duration(seconds: 5)), false);
    expect(activity.today.averageActive, 3);
  });
  test('suspend and restart do not count offline usage', () {
    final t = DateTime(2026, 10, 8, 12);
    final activity = ActivityStatisticsService(now: t)..sample(t, true);
    activity.sample(t.add(const Duration(seconds: 5)), true);
    activity.sample(t.add(const Duration(hours: 4)), true);
    expect(activity.total.activeSeconds, 5);
    final restored = ActivityStatisticsService.fromJson(activity.toJson());
    restored.sample(t.add(const Duration(hours: 8)), false);
    expect(restored.total.activeSeconds, 5);
  });
}
