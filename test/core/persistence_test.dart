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
