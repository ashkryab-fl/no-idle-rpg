import 'package:idle_companion/core/balance/talent_profile.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/core/persistence/game_save_repository.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/game/systems/game_state_machine.dart';
import '../helpers/simulation_fixture.dart' show ConstantRandom;

void settle(GameSimulation game) {
  for (var i = 0; game.phase == GamePhase.enemyDeath && i < 300; i++) {
    game.advance(1 / 60);
  }
  expect(game.phase, GamePhase.reward);
}

void main() {
  test(
    'backup restores whole pre-settlement checkpoint and next actual boss settlement pays once',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'adventure-recovery-test-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final repository = FileGameSaveRepository(dir);
      final game = GameSimulation(random: ConstantRandom())
        ..heroHp = Amount.fromNum(50);
      for (var wave = 1; wave <= 4; wave++) {
        game.spawnEnemy();
        game.killEnemy();
        settle(game);
        game.advance(1);
      }
      game.spawnEnemy();
      game.killEnemy();
      await repository.save(GameSave.capture(game, DateTime.now()));
      settle(game);
      expect(game.character.books.toDouble(), closeTo(3, 1e-9));
      await repository.save(GameSave.capture(game, DateTime.now()));
      await File('${dir.path}/save.json').writeAsString('{bad');
      final restored = (await repository.load())!.restoreSimulation();
      expect(restored.stage, 1);
      expect(restored.stageKills, 4);
      expect(restored.kills, 4);
      expect(restored.character.books.isZero, isTrue);
      expect(restored.heroHp.toDouble(), closeTo(50, 1e-9));
      settle(restored);
      expect(restored.kills, 5);
      expect(restored.stage, 2);
      expect(restored.character.books.toDouble(), closeTo(3, 1e-9));
      await repository.save(GameSave.capture(restored, DateTime.now()));
      final again = (await repository.load())!.restoreSimulation();
      again.advance(.1);
      expect(again.kills, 5);
      expect(again.character.books.toDouble(), closeTo(3, 1e-9));
      expect(again.heroHp.toDouble(), closeTo(50, 1e-9));
    },
  );
  test(
    'unknown snapshot profile recovers valid current backup; without backup explicit recovery error',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'saved-talent-profile-test-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final repository = FileGameSaveRepository(dir),
          game = GameSimulation(random: ConstantRandom());
      game.spawnEnemy();
      final good = GameSave.capture(game, DateTime.now()).toJson();
      await File(
        '${dir.path}/save.backup.json',
      ).writeAsString(jsonEncode(good));
      final bad = jsonDecode(jsonEncode(good));
      bad['adventure']['attempt']['profileId'] = 'unknown';
      await File('${dir.path}/save.json').writeAsString(jsonEncode(bad));
      expect(
        (await repository.load())!.adventure.attempt!.profileId,
        TalentProfile.candidate.id,
      );
      await File('${dir.path}/save.backup.json').delete();
      await expectLater(repository.load(), throwsFormatException);
      expect(
        await File('${dir.path}/save.json').readAsString(),
        jsonEncode(bad),
      );
    },
  );
}
