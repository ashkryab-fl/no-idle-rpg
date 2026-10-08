import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/core/persistence/game_save_repository.dart';
import 'package:idle_companion/core/persistence/offline_progress_service.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

void main() {
  late Directory dir;
  test('save rejects invalid numeric and progression fields', () {
    for (final modify in <void Function(Map<String, Object?>)>[
      (j) => j['distance'] = double.nan,
      (j) => j['kills'] = -1,
      (j) => j['stage'] = 0,
      (j) => j['stageKills'] = -1,
      (j) => j['stageKills'] = 12,
      (j) => (j['character'] as Map)['level'] = 0,
      (j) => (j['character'] as Map)['upgrades'] = {'damage': -1},
      (j) => ((j['activity'] as Map)['today'] as Map)['idle'] = -5,
      (j) => (j['activity'] as Map)['sessionSeconds'] = double.infinity,
    ]) {
      final json = GameSave.capture(GameSimulation(), DateTime.now()).toJson();
      modify(json);
      expect(
        () => GameSave.fromJson(Map<String, dynamic>.from(json)),
        throwsFormatException,
      );
    }
  });
  test(
    'valid JSON with invalid state falls back to last good backup',
    () async {
      final repository = FileGameSaveRepository(dir), game = GameSimulation();
      game.kills = 3;
      await repository.save(GameSave.capture(game, DateTime.now()));
      game.kills = 4;
      await repository.save(GameSave.capture(game, DateTime.now()));
      final broken = GameSave.capture(game, DateTime.now()).toJson()
        ..['distance'] = -10;
      await File('${dir.path}/save.json').writeAsString(jsonEncode(broken));
      expect((await repository.load())!.kills, 3);
    },
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('idle-save-test-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
    'save/load round trips currencies, upgrades, activity and settings',
    () async {
      final repository = FileGameSaveRepository(dir);
      final game = GameSimulation()
        ..distance = 100
        ..kills = 9
        ..stage = 10
        ..stageKills = 3;
      game.character.gold = Amount.fromLog(900);
      game.character.equipment['weapon'] = 30;
      game.character.upgrades['damage'] = 4;
      game.settings.fps = 15;
      game.settings.backgroundOpacity = .35;
      game.settings.roadOpacity = .65;
      game.settings.overallOpacity = 0;
      game.activity.total.activeSeconds = 200;
      final now = DateTime(2026, 10, 8);
      await repository.save(GameSave.capture(game, now));
      final restored = (await repository.load())!;
      expect(restored.character.gold.log10, 900);
      expect(restored.character.equipment['weapon'], 30);
      expect(restored.character.upgrades['damage'], 4);
      expect(restored.activity.total.activeSeconds, 200);
      expect(restored.settings.fps, 15);
      expect(restored.settings.backgroundOpacity, .35);
      expect(restored.settings.roadOpacity, .65);
      expect(restored.settings.overallOpacity, 0);
      expect(restored.distance, 100);
      expect(restored.kills, 9);
      expect(restored.stage, 10);
      expect(restored.stageKills, 3);
      expect(restored.lastSaveTime.toLocal(), now);
    },
  );
  test('version 1 migration preserves numeric legacy values', () {
    final json = GameSave.capture(GameSimulation(), DateTime.now()).toJson();
    json['saveVersion'] = 1;
    json.remove('settings');
    json.remove('activity');
    (json['character'] as Map)['gold'] = 1234;
    final restored = GameSave.fromJson(Map<String, dynamic>.from(json));
    expect(restored.character.gold.toDouble(), closeTo(1234, 1e-8));
    expect(restored.settings.fps, 30);
    expect(restored.settings.backgroundOpacity, 1);
    expect(restored.settings.roadOpacity, 1);
    expect(restored.settings.overallOpacity, 1);
    json['saveVersion'] = 999;
    expect(
      () => GameSave.fromJson(Map<String, dynamic>.from(json)),
      throwsUnsupportedError,
    );
  });
  test(
    'legacy saves initialize stage without changing character progression',
    () {
      for (final version in [1, 2, 3, 4]) {
        final json = GameSave.capture(GameSimulation(), DateTime.now()).toJson()
          ..['saveVersion'] = version
          ..['kills'] = 25
          ..remove('stage')
          ..remove('stageKills');
        (json['character'] as Map)['level'] = 10;
        final restored = GameSave.fromJson(Map<String, dynamic>.from(json));
        expect(restored.kills, 25);
        expect(restored.stage, 3);
        expect(restored.stageKills, 1);
        expect(restored.character.level, 10);
      }
    },
  );

  test(
    'version 3 preserves a previous difficulty rollback as stage progress',
    () {
      final json = GameSave.capture(GameSimulation(), DateTime.now()).toJson()
        ..['saveVersion'] = 3
        ..['kills'] = 100
        ..['enemyProgressKills'] = 13
        ..remove('stage')
        ..remove('stageKills');
      final restored = GameSave.fromJson(Map<String, dynamic>.from(json));
      expect(restored.stage, 2);
      expect(restored.stageKills, 1);
      expect(restored.kills, 100);
      expect(restored.toJson().containsKey('enemyProgressKills'), isFalse);
    },
  );
  test('death stage rollback survives save and reload', () {
    final game = GameSimulation()
      ..kills = 25
      ..stage = 10
      ..stageKills = 7;
    game.character.level = 20;
    game.killHero();
    final save = GameSave.fromJson(
      Map<String, dynamic>.from(
        GameSave.capture(game, DateTime.now()).toJson(),
      ),
    );
    final restored = GameSimulation(character: save.character)
      ..kills = save.kills
      ..stage = save.stage
      ..stageKills = save.stageKills;
    expect(restored.kills, 25);
    expect(restored.stage, 9);
    expect(restored.stageKills, 0);
    expect(restored.enemyTier, 8);
    expect(restored.character.level, 20);
  });
  test('queued snapshots, corrupt primary backup recovery and reset', () async {
    final repository = FileGameSaveRepository(dir), game = GameSimulation();
    game.kills = 1;
    final first = repository.save(GameSave.capture(game, DateTime.now()));
    game.kills = 2;
    final second = repository.save(GameSave.capture(game, DateTime.now()));
    await Future.wait([first, second]);
    expect((await repository.load())!.kills, 2);
    await File('${dir.path}/save.json').writeAsString('{bad json');
    expect((await repository.load())!.kills, 1);
    await repository.reset();
    expect(await repository.load(), isNull);
  });
  test('broken saves are surfaced instead of overwritten', () async {
    await File(
      '${dir.path}/save.json',
    ).writeAsString(jsonEncode({'saveVersion': 2}));
    expect(FileGameSaveRepository(dir).load(), throwsFormatException);
  });
  test(
    'offline infrastructure computes duration but awards no invented rewards',
    () {
      final now = DateTime(2026, 10, 8, 12);
      final service = OfflineProgressService();
      final result = service.calculate(
        now.subtract(const Duration(hours: 2)),
        now,
      );
      expect(result.duration.inHours, 2);
      expect(result.gold.isZero, true);
      expect(
        service.calculate(now.add(const Duration(hours: 1)), now).duration,
        Duration.zero,
      );
    },
  );
}
