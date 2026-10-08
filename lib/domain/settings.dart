class GameSettings {
  bool alwaysOnTop = true;
  bool sound = false;
  int fps = 30;
  Map<String, Object> toJson() => {
    'alwaysOnTop': alwaysOnTop,
    'sound': sound,
    'fps': fps,
  };
  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings()
    ..alwaysOnTop = j['alwaysOnTop'] as bool? ?? true
    ..sound = j['sound'] as bool? ?? false
    ..fps = [15, 30, 60].contains(j['fps']) ? j['fps'] as int : 30;
  GameSettings();
}
