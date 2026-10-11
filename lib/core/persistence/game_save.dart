import '../../domain/activity/activity_statistics.dart';
import '../../domain/character/character.dart';
import '../../domain/settings.dart';
import '../../game/systems/game_simulation.dart';
import '../balance/progression_balance.dart';

class GameSave {
  GameSave({
    required this.character,
    required this.activity,
    required this.settings,
    required this.lastSaveTime,
    this.distance = 0,
    this.kills = 0,
    this.stage = 1,
    this.stageKills = 0,
  });
  static const currentVersion = 6;
  final CharacterProgress character;
  final ActivityStatisticsService activity;
  final GameSettings settings;
  final DateTime lastSaveTime;
  final double distance;
  final int kills;
  final int stage, stageKills;
  factory GameSave.capture(GameSimulation game, DateTime now) => GameSave(
    character: game.character,
    activity: game.activity,
    settings: game.settings,
    lastSaveTime: now,
    distance: game.distance,
    kills: game.kills,
    stage: game.stage,
    stageKills: game.stageKills,
  );
  Map<String, Object?> toJson() => {
    'saveVersion': currentVersion,
    'character': character.toJson(),
    'activity': activity.toJson(),
    'settings': settings.toJson(),
    'distance': distance,
    'kills': kills,
    'stage': stage,
    'stageKills': stageKills,
    'lastSaveTime': lastSaveTime.toUtc().toIso8601String(),
  };
  factory GameSave.fromJson(Map<String, dynamic> source) {
    final json = SaveMigrator.migrate(source);
    final distance = (json['distance'] as num? ?? 0).toDouble();
    final kills = json['kills'] as int? ?? 0;
    final stage = json['stage'] as int? ?? 1;
    final stageKills = json['stageKills'] as int? ?? 0;
    if (!distance.isFinite ||
        distance < 0 ||
        kills < 0 ||
        stage < 1 ||
        stageKills < 0 ||
        stageKills >= ProgressionBalance.enemiesPerStage) {
      throw const FormatException(
        'Invalid distance, kills or stage progression',
      );
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
      stage: stage,
      stageKills: stageKills,
    );
  }
}

abstract final class SaveMigrator {
  // Save versions 1–5 used twelve victories per stage.
  static const _legacyEnemiesPerStage = 12;
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
          version = 3;
        case 3:
          final progress = json['enemyProgressKills'] ?? json['kills'] ?? 0;
          if (progress is! int || progress < 0) {
            throw const FormatException('Invalid legacy enemy progression');
          }
          json.putIfAbsent(
            'stage',
            () => progress ~/ _legacyEnemiesPerStage + 1,
          );
          json.putIfAbsent(
            'stageKills',
            () => progress % _legacyEnemiesPerStage,
          );
          json.remove('enemyProgressKills');
          version = 4;
        case 4:
          final kills = json['kills'] ?? 0;
          if (kills is! int || kills < 0) {
            throw const FormatException('Invalid legacy kill count');
          }
          json.putIfAbsent('stage', () => kills ~/ _legacyEnemiesPerStage + 1);
          json.putIfAbsent('stageKills', () => kills % _legacyEnemiesPerStage);
          version = 5;
        case 5:
          final progress = json['stageKills'] ?? 0;
          if (progress is! int ||
              progress < 0 ||
              progress >= _legacyEnemiesPerStage) {
            throw const FormatException('Invalid legacy stage progression');
          }
          // Preserve the stage and its approximate completion, leaving the boss
          // undefeated even when migrating a nearly completed old stage.
          json['stageKills'] =
              progress *
              ProgressionBalance.enemiesPerStage ~/
              _legacyEnemiesPerStage;
          version = 6;
        default:
          throw UnsupportedError('No migration for $version');
      }
    }
    json['saveVersion'] = version;
    return json;
  }
}
