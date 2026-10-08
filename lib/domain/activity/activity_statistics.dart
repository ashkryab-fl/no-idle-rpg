import 'dart:math' as math;

class ActivityBucket {
  double activeSeconds = 0, idleSeconds = 0;
  double completedActiveSeconds = 0, completedIdleSeconds = 0;
  int activeSessions = 0, idleSessions = 0;
  double get averageActive =>
      activeSessions == 0 ? 0 : completedActiveSeconds / activeSessions;
  double get averageIdle =>
      idleSessions == 0 ? 0 : completedIdleSeconds / idleSessions;
  Map<String, Object> toJson() => {
    'active': activeSeconds,
    'idle': idleSeconds,
    'activeDuration': completedActiveSeconds,
    'idleDuration': completedIdleSeconds,
    'activeSessions': activeSessions,
    'idleSessions': idleSessions,
  };
  factory ActivityBucket.fromJson(Map<String, dynamic> j) {
    double duration(String key) {
      final value = (j[key] as num? ?? 0).toDouble();
      if (!value.isFinite || value < 0) {
        throw FormatException('Invalid activity duration: $key');
      }
      return value;
    }

    int sessions(String key) {
      final value = j[key] as int? ?? 0;
      if (value < 0) throw FormatException('Invalid activity sessions: $key');
      return value;
    }

    return ActivityBucket()
      ..activeSeconds = duration('active')
      ..idleSeconds = duration('idle')
      ..completedActiveSeconds = duration('activeDuration')
      ..completedIdleSeconds = duration('idleDuration')
      ..activeSessions = sessions('activeSessions')
      ..idleSessions = sessions('idleSessions');
  }
  ActivityBucket();
}

/// Samples and session boundaries only. Midnight splits durations into local days.
/// Offline time is never counted as computer usage.
class ActivityStatisticsService {
  ActivityStatisticsService({DateTime? now})
    : day = dayKey(now ?? DateTime.now());
  String day;
  ActivityBucket today = ActivityBucket(), total = ActivityBucket();
  bool? active;
  double sessionSeconds = 0, dailySessionSeconds = 0;
  DateTime? _last;
  static String dayKey(DateTime time) =>
      '${time.year}-${time.month}-${time.day}';
  void sample(DateTime now, bool isActive) {
    if (_last == null) {
      if (day != dayKey(now)) {
        day = dayKey(now);
        today = ActivityBucket();
        dailySessionSeconds = 0;
      }
      _last = now;
      active = isActive;
      return;
    }
    var cursor = _last!;
    // A suspend/poll gap ends the current session without inventing usage.
    if (now.difference(cursor).inSeconds > 10 || now.isBefore(cursor)) {
      finishSession();
      _last = null;
      sample(now, isActive);
      return;
    }
    while (cursor.isBefore(now)) {
      final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final end = now.isBefore(midnight) ? now : midnight;
      final seconds = math.max(
        0.0,
        end.difference(cursor).inMicroseconds / 1e6,
      );
      _add(seconds, active ?? isActive);
      sessionSeconds += seconds;
      dailySessionSeconds += seconds;
      cursor = end;
      if (!cursor.isBefore(midnight)) {
        day = dayKey(cursor);
        today = ActivityBucket();
        dailySessionSeconds = 0;
      }
    }
    if (active != isActive) {
      finishSession();
      active = isActive;
    }
    _last = now;
  }

  void _add(double seconds, bool isActive) {
    for (final bucket in [today, total]) {
      if (isActive) {
        bucket.activeSeconds += seconds;
      } else {
        bucket.idleSeconds += seconds;
      }
    }
  }

  void reset(DateTime now) {
    day = dayKey(now);
    today = ActivityBucket();
    total = ActivityBucket();
    active = null;
    sessionSeconds = 0;
    dailySessionSeconds = 0;
    _last = null;
  }

  void pause() {
    finishSession();
    _last = null;
    active = null;
  }

  void finishSession() {
    if (active == null || sessionSeconds == 0) return;
    for (final pair in [
      (today, dailySessionSeconds),
      (total, sessionSeconds),
    ]) {
      if (pair.$2 == 0) continue;
      if (active!) {
        pair.$1.activeSessions++;
        pair.$1.completedActiveSeconds += pair.$2;
      } else {
        pair.$1.idleSessions++;
        pair.$1.completedIdleSeconds += pair.$2;
      }
    }
    sessionSeconds = 0;
    dailySessionSeconds = 0;
  }

  Map<String, Object?> toJson() => {
    'day': day,
    'today': today.toJson(),
    'total': total.toJson(),
    'active': active,
    'sessionSeconds': sessionSeconds,
    'dailySessionSeconds': dailySessionSeconds,
  };
  factory ActivityStatisticsService.fromJson(Map<String, dynamic> j) {
    final service = ActivityStatisticsService()
      ..day = j['day'] as String? ?? ''
      ..today = ActivityBucket.fromJson(
        Map<String, dynamic>.from(j['today'] as Map? ?? {}),
      )
      ..total = ActivityBucket.fromJson(
        Map<String, dynamic>.from(j['total'] as Map? ?? {}),
      )
      ..active = (j['active'] as bool?)
      ..sessionSeconds = (j['sessionSeconds'] as num? ?? 0).toDouble()
      ..dailySessionSeconds = (j['dailySessionSeconds'] as num? ?? 0)
          .toDouble();
    if (!service.sessionSeconds.isFinite ||
        service.sessionSeconds < 0 ||
        !service.dailySessionSeconds.isFinite ||
        service.dailySessionSeconds < 0 ||
        service.dailySessionSeconds > service.sessionSeconds) {
      throw const FormatException('Invalid activity session');
    }
    // A restart closes the saved session; the next sample starts a new one.
    service.finishSession();
    return service;
  }
}
