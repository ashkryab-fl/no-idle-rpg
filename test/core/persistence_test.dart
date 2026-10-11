import 'dart:io';
import 'dart:convert';
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
      (j) => (j['character'] as Map)['equipment'] = {'weapon': -1},
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
    'save/load round trips currencies, equipment, activity and settings',
    () async {
      final repository = FileGameSaveRepository(dir);
      final game = GameSimulation()
        ..distance = 100
        ..kills = 9
        ..stage = 10
        ..stageKills = 3;
      game.character.gold = Amount.fromLog(900);
      game.character.equipment['weapon'] = 30;
      game.character.equipment['helmet'] = 4;
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
      expect(restored.character.equipment['helmet'], 4);
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

  test('restart keeps saved rewards without offline income', () async {
    final repository = FileGameSaveRepository(dir);
    final game = GameSimulation();
    game.character.gold = Amount.fromNum(123);
    game.character.books = Amount.fromNum(7);
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
  test('current schema ignores injected hero level and experience', () async {
    final game = GameSimulation();
    game.character.equipment['armor'] = 2000;
    final json = GameSave.capture(game, DateTime.now()).toJson();
    final hero = json['character'] as Map;
    expect(hero.containsKey('level'), isFalse);
    expect(hero.containsKey('xp'), isFalse);
    hero['level'] = 1000000;
    hero['xp'] = 'NaN';
    final save = GameSave.fromJson(json);
    final restored = GameSimulation(character: save.character);
    expect(restored.stats.maxHp.log10, game.stats.maxHp.log10);
    expect(restored.stats.damage.log10, game.stats.damage.log10);
    expect(restored.heroHp.log10, game.stats.maxHp.log10);
    expect(save.character.toJson().keys, isNot(contains('level')));
    expect(save.character.toJson().keys, isNot(contains('xp')));
  });

  for (var version = 1; version <= 7; version++) {
    test('v$version primary and backup reset without migrating', () async {
      final repository = FileGameSaveRepository(dir);
      final legacy = {'saveVersion': version, 'stage': 100000};
      for (final name in ['save.json', 'save.backup.json']) {
        await File('${dir.path}/$name').writeAsString(jsonEncode(legacy));
      }
      expect(await repository.load(), isNull);
      expect(await File('${dir.path}/save.json').exists(), isFalse);
      expect(await File('${dir.path}/save.backup.json').exists(), isFalse);
      await repository.save(GameSave.capture(GameSimulation(), DateTime.now()));
      expect((await repository.load())!.stage, 1);
    });
  }

  test('legacy primary cannot block a valid current backup', () async {
    final repository = FileGameSaveRepository(dir);
    final current = GameSave.capture(
      GameSimulation()..kills = 99,
      DateTime.now(),
    );
    await File(
      '${dir.path}/save.backup.json',
    ).writeAsString(jsonEncode(current.toJson()));
    await File('${dir.path}/save.json').writeAsString('{"saveVersion":6}');
    expect((await repository.load())!.kills, 99);
    await repository.save(current);
    expect((await repository.load())!.kills, 99);
    expect(
      GameSave.fromJson(
        jsonDecode(await File('${dir.path}/save.backup.json').readAsString()),
      ).kills,
      99,
    );
  });

  test(
    'corrupt current files are errors; legacy backup is not recovery',
    () async {
      final repository = FileGameSaveRepository(dir);
      await File(
        '${dir.path}/save.json',
      ).writeAsString('{"saveVersion":8,"stage":-1}');
      for (final backup in ['{"saveVersion":6}', '{bad', '{"saveVersion":8}']) {
        await File('${dir.path}/save.backup.json').writeAsString(backup);
        await expectLater(repository.load(), throwsFormatException);
        expect(
          await File('${dir.path}/save.json').readAsString(),
          '{"saveVersion":8,"stage":-1}',
        );
      }
    },
  );

  test('unversioned corruption is not treated as known legacy', () async {
    final repository = FileGameSaveRepository(dir);
    for (final contents in ['{bad', '{}', '{"saveVersion":"6"}']) {
      await File('${dir.path}/save.json').writeAsString(contents);
      await expectLater(repository.load(), throwsFormatException);
      expect(await File('${dir.path}/save.json').readAsString(), contents);
    }
  });

  test('future files are preserved on load and automatic save', () async {
    final repository = FileGameSaveRepository(dir);
    final current = GameSave.capture(GameSimulation(), DateTime.now());
    for (final futureName in ['save.json', 'save.backup.json']) {
      final otherName = futureName == 'save.json'
          ? 'save.backup.json'
          : 'save.json';
      await File('${dir.path}/$futureName').writeAsString('{"saveVersion":9}');
      await File(
        '${dir.path}/$otherName',
      ).writeAsString(jsonEncode(current.toJson()));
      await expectLater(repository.load(), throwsUnsupportedError);
      await expectLater(repository.save(current), throwsUnsupportedError);
      expect(
        await File('${dir.path}/$futureName').readAsString(),
        '{"saveVersion":9}',
      );
      await repository.reset();
    }
  });

  test(
    'legacy load, queued save and reset share the same operation queue',
    () async {
      final repository = FileGameSaveRepository(dir);
      await File('${dir.path}/save.json').writeAsString('{"saveVersion":6}');
      final load = repository.load();
      final write = repository.save(
        GameSave.capture(GameSimulation()..kills = 11, DateTime.now()),
      );
      expect(await load, isNull);
      await write;
      expect((await repository.load())!.kills, 11);
      final beforeReset = repository.save(
        GameSave.capture(GameSimulation()..kills = 12, DateTime.now()),
      );
      final reset = repository.reset();
      final afterReset = repository.save(
        GameSave.capture(GameSimulation()..kills = 13, DateTime.now()),
      );
      await Future.wait([beforeReset, reset, afterReset]);
      expect((await repository.load())!.kills, 13);
      expect(await File('${dir.path}/save.backup.json').exists(), isFalse);
    },
  );
  test(
    'current save rejects any old stat map and recovers only current backup',
    () async {
      final repository = FileGameSaveRepository(dir);
      final current = GameSave.capture(
        GameSimulation()..kills = 77,
        DateTime.now(),
      ).toJson();
      await File(
        '${dir.path}/save.backup.json',
      ).writeAsString(jsonEncode(current));
      final bad = GameSave.capture(
        GameSimulation()..kills = 88,
        DateTime.now(),
      ).toJson();
      (bad['character'] as Map)['upgrades'] = <String, int>{};
      expect(() => GameSave.fromJson(bad), throwsFormatException);
      await File('${dir.path}/save.json').writeAsString(jsonEncode(bad));
      expect((await repository.load())!.kills, 77);
      await File('${dir.path}/save.backup.json').delete();
      await expectLater(repository.load(), throwsFormatException);
      expect(
        await File('${dir.path}/save.json').readAsString(),
        jsonEncode(bad),
      );
    },
  );
}
