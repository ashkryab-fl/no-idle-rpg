import '../../domain/activity/activity_statistics.dart';
import '../../domain/character/character.dart';
import '../../domain/settings.dart';
import '../../game/systems/game_simulation.dart';
import '../balance/progression_balance.dart';
import '../../domain/adventure/adventure_checkpoint.dart';
import '../../game/systems/enemy_spawner.dart';

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
    AdventureCheckpoint? adventure,
  }) : adventure =
           adventure ??
           AdventureCheckpoint(hp: CharacterStats.calculate(character).maxHp);
  static const currentVersion = 10;
  final AdventureCheckpoint adventure;
  final CharacterProgress character;
  final ActivityStatisticsService activity;
  final GameSettings settings;
  final DateTime lastSaveTime;
  final double distance;
  final int kills;
  final int stage, stageKills;
  factory GameSave.capture(GameSimulation game, DateTime now) => GameSave(
    character: CharacterProgress.fromJson(game.character.toJson()),
    activity: ActivityStatisticsService.fromJson(game.activity.toJson()),
    settings: GameSettings.fromJson(game.settings.toJson()),
    lastSaveTime: now,
    distance: game.distance,
    kills: game.kills,
    stage: game.stage,
    stageKills: game.stageKills,
    adventure: game.captureAdventure(),
  );
  GameSimulation restoreSimulation() {
    final simulation =
        GameSimulation(
            character: CharacterProgress.fromJson(character.toJson()),
            activity: ActivityStatisticsService.fromJson(activity.toJson()),
            settings: GameSettings.fromJson(settings.toJson()),
          )
          ..distance = distance
          ..kills = kills
          ..stage = stage
          ..stageKills = stageKills;
    simulation.restoreAdventure(adventure);
    return simulation;
  }

  Map<String, Object?> toJson() => {
    'saveVersion': currentVersion,
    'character': character.toJson(),
    'activity': activity.toJson(),
    'settings': settings.toJson(),
    'distance': distance,
    'kills': kills,
    'stage': stage,
    'stageKills': stageKills,
    'adventure': adventure.toJson(),
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
    final character = CharacterProgress.fromJson(
      Map<String, dynamic>.from(json['character'] as Map),
    );
    final adventure = AdventureCheckpoint.fromJson(
      Map<String, dynamic>.from(json['adventure'] as Map),
    );
    final attempt = adventure.attempt;
    final dead = adventure.phase == 'heroDeath' || adventure.phase == 'respawn';
    if (stage > character.talents.highestFirstClearedStage + 1 ||
        adventure.hp > CharacterStats.calculate(character).maxHp ||
        dead != adventure.hp.isZero ||
        (attempt != null &&
            (attempt.stage != stage ||
                attempt.id != character.talents.nextAttemptId - 1 ||
                attempt.id < character.talents.lastSettledAttempt ||
                attempt.ranks.entries.any(
                  (e) => e.value > (character.talents.ownedRanks[e.key] ?? 0),
                ) ||
                attempt.encounters.any(
                  (e) =>
                      !EnemyCatalog.definitions.any((d) => d.id == e.enemyId),
                ))) ||
        (attempt == null &&
            (stageKills != 0 ||
                !const [
                  'traveling',
                  'reward',
                  'heroDeath',
                  'respawn',
                ].contains(adventure.phase) ||
                (adventure.phase == 'traveling' &&
                    (!adventure.needsTravelTarget ||
                        adventure.travelRemaining != 0))))) {
      throw const FormatException('Inconsistent adventure checkpoint');
    }
    if (attempt != null) {
      final cursor = character.talents.lastSettledAttempt == attempt.id
          ? character.talents.lastSettledWave
          : 0;
      if (cursor != stageKills ||
          dead ||
          (adventure.phase == 'reward' &&
              (cursor == 0 || adventure.lastReward == null)) ||
          (adventure.phase == 'traveling' &&
              !adventure.needsTravelTarget &&
              adventure.travelRemaining == 0)) {
        throw const FormatException('Inconsistent wave settlement cursor');
      }
    }
    return GameSave(
      character: character,
      adventure: adventure,
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
