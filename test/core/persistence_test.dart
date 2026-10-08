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
      (j) => j['enemyProgressKills'] = -1,
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
        ..enemyProgressKills = 3;
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
      expect(restored.enemyProgressKills, 3);
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
  test('legacy saves initialize difficulty from lifetime victories', () {
    for (final version in [1, 2]) {
      final json = GameSave.capture(GameSimulation(), DateTime.now()).toJson()
        ..['saveVersion'] = version
        ..['kills'] = 25
        ..remove('enemyProgressKills');
      final restored = GameSave.fromJson(Map<String, dynamic>.from(json));
      expect(restored.kills, 25);
      expect(restored.enemyProgressKills, 25);
    }
  });

  test('death difficulty reduction survives save and reload', () {
    final game = GameSimulation()
      ..kills = 25
      ..enemyProgressKills = 25;
    game.killHero();
    final save = GameSave.fromJson(
      Map<String, dynamic>.from(
        GameSave.capture(game, DateTime.now()).toJson(),
      ),
    );
    final restored = GameSimulation(character: save.character)
      ..kills = save.kills
      ..enemyProgressKills = save.enemyProgressKills;
    expect(restored.kills, 25);
    expect(restored.enemyProgressKills, 13);
    expect(restored.enemyTier, 1);
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
