import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/core/persistence/game_save_repository.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

void main() {
  late Directory dir;
  test('save rejects invalid numeric and progression fields', () {
    for (final modify in <void Function(Map<String, Object?>)>[
      (j) => j['distance'] = double.nan,
      (j) => j['kills'] = -1,
      (j) => j['stage'] = 0,
      (j) => j['stageKills'] = -1,
      (j) => j['stageKills'] = 5,
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

  test('old twelve-fight saves preserve stage and scale completed waves', () {
    for (var completed = 0; completed < 12; completed++) {
      final game = GameSimulation()
        ..stage = 10
        ..kills = 118;
      game.character.gold = Amount.fromNum(123);
      final json = GameSave.capture(game, DateTime.now()).toJson()
        ..['saveVersion'] = 5
        ..['stageKills'] = completed;
      final restored = GameSave.fromJson(json);
      expect(restored.stage, 10);
      expect(restored.stageKills, completed * 5 ~/ 12);
      expect(restored.kills, 118);
      expect(restored.character.gold.toDouble(), closeTo(123, 1e-8));
    }
  });

  test(
    'legacy kill counters still use twelve-fight stages before migration',
    () {
      for (final version in [1, 2, 3, 4]) {
        final json =
            GameSave.capture(
                GameSimulation()..kills = 118,
                DateTime.now(),
              ).toJson()
              ..['saveVersion'] = version
              ..remove('stage')
              ..remove('stageKills');
        if (version == 3) json['enemyProgressKills'] = 118;
        final restored = GameSave.fromJson(json);
        expect(restored.stage, 10);
        expect(restored.stageKills, 4);
        expect(restored.kills, 118);
      }
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

  test('loading an old save keeps rewards exactly as saved', () async {
    final repository = FileGameSaveRepository(dir);
    final game = GameSimulation();
    game.character.gold = Amount.fromNum(123);
    game.character.books = Amount.fromNum(7);
    game.character.xp = Amount.fromNum(42);
    final character = game.character.toJson();
    await repository.save(GameSave.capture(game, DateTime(2020, 1, 1)));

    final save = (await repository.load())!;
    final restored = GameSimulation(
      character: save.character,
      activity: save.activity,
      settings: save.settings,
    );
    expect(restored.character.toJson(), character);
  });
}
