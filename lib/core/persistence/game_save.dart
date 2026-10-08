import '../../domain/activity/activity_statistics.dart';
import '../../domain/character/character.dart';
import '../../domain/settings.dart';
import '../../game/systems/game_simulation.dart';

class GameSave {
  GameSave({
    required this.character,
    required this.activity,
    required this.settings,
    required this.lastSaveTime,
    this.distance = 0,
    this.kills = 0,
    this.enemyProgressKills = 0,
  });
  static const currentVersion = 3;
  final CharacterProgress character;
  final ActivityStatisticsService activity;
  final GameSettings settings;
  final DateTime lastSaveTime;
  final double distance;
  final int kills;
  final int enemyProgressKills;
  factory GameSave.capture(GameSimulation game, DateTime now) => GameSave(
    character: game.character,
    activity: game.activity,
    settings: game.settings,
    lastSaveTime: now,
    distance: game.distance,
    kills: game.kills,
    enemyProgressKills: game.enemyProgressKills,
  );
  Map<String, Object?> toJson() => {
    'saveVersion': currentVersion,
    'character': character.toJson(),
    'activity': activity.toJson(),
    'settings': settings.toJson(),
    'distance': distance,
    'kills': kills,
    'enemyProgressKills': enemyProgressKills,
    'lastSaveTime': lastSaveTime.toUtc().toIso8601String(),
  };
  factory GameSave.fromJson(Map<String, dynamic> source) {
    final json = SaveMigrator.migrate(source);
    final distance = (json['distance'] as num? ?? 0).toDouble();
    final kills = json['kills'] as int? ?? 0;
    final enemyProgressKills = json['enemyProgressKills'] as int? ?? 0;
    if (!distance.isFinite ||
        distance < 0 ||
        kills < 0 ||
        enemyProgressKills < 0) {
      throw const FormatException('Invalid distance or kill progression');
    }
    return GameSave(
      character: CharacterProgress.fromJson(
        Map<String, dynamic>.from(json['character'] as Map),
      ),
      activity: ActivityStatisticsService.fromJson(
        Map<String, dynamic>.from(json['activity'] as Map? ?? {}),
      ),
      settings: GameSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      ),
      lastSaveTime: DateTime.parse(json['lastSaveTime'] as String),
      distance: distance,
      kills: kills,
      enemyProgressKills: enemyProgressKills,
    );
  }
}

abstract final class SaveMigrator {
  static Map<String, dynamic> migrate(Map<String, dynamic> source) {
    final json = Map<String, dynamic>.from(source);
    var version = json['saveVersion'] as int? ?? 1;
    if (version > GameSave.currentVersion || version < 1) {
      throw UnsupportedError('Unsupported save version $version');
    }
    while (version < GameSave.currentVersion) {
      switch (version) {
        case 1:
          json.putIfAbsent('settings', () => <String, dynamic>{});
          json.putIfAbsent('activity', () => <String, dynamic>{});
          version = 2;
        case 2:
          json.putIfAbsent('enemyProgressKills', () => json['kills'] ?? 0);
          version = 3;
        default:
          throw UnsupportedError('No migration for $version');
      }
    }
    json['saveVersion'] = version;
    return json;
  }
}
