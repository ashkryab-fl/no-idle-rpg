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
  static const currentVersion = 8;
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
    final version = source['saveVersion'];
    if (version is! int) {
      throw const FormatException('Missing or invalid save version');
    }
    if (version != currentVersion) {
      throw UnsupportedError('Unsupported save version $version');
    }
    final json = source;
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
