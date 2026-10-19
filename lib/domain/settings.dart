class GameSettings {
  static const defaultWindowSize = .2;
  bool alwaysOnTop = true;
  bool sound = false;
  int fps = 30;
  double backgroundOpacity = 1;
  double roadOpacity = 1;
  double overallOpacity = 1;
  double windowSize = defaultWindowSize;
  double get windowScale => .5 + 2.5 * windowSize;
  Map<String, Object> toJson() => {
    'alwaysOnTop': alwaysOnTop,
    'sound': sound,
    'fps': fps,
    'backgroundOpacity': backgroundOpacity,
    'roadOpacity': roadOpacity,
    'overallOpacity': overallOpacity,
    'windowSize': windowSize,
  };
  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings()
    ..alwaysOnTop = j['alwaysOnTop'] as bool? ?? true
    ..sound = j['sound'] as bool? ?? false
    ..fps = [15, 30, 60].contains(j['fps']) ? j['fps'] as int : 30
    ..backgroundOpacity = _opacity(j['backgroundOpacity'])
    ..roadOpacity = _opacity(j['roadOpacity'])
    ..overallOpacity = _opacity(j['overallOpacity'])
    ..windowSize = _fraction(j['windowSize'], defaultWindowSize);
  static double _opacity(dynamic value) => _fraction(value, 1);
  static double _fraction(dynamic value, double fallback) =>
      value is num && value.isFinite
      ? value.toDouble().clamp(0.0, 1.0)
      : fallback;
  GameSettings();
}
