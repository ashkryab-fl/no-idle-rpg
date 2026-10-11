import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/domain/talents/talents.dart';
import 'package:idle_companion/presentation/talents/talents_panel.dart';
import '../helpers/runtime_fakes.dart';

void main() {
  testWidgets(
    'talents show locked/owned/current/next, purchases stay separate from selection, quota exhausted',
    (tester) async {
      tester.view.physicalSize = const Size(400, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MemoryRepository(),
          container = ProviderContainer(
            overrides: [
              runtimeProvider.overrideWithValue(
                fakeRuntime(repo, FakeWindow()),
              ),
            ],
          );
      final controller = container.read(gameControllerProvider.notifier),
          game = controller.simulation;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TalentsPanel(controller: controller),
            ),
          ),
        ),
      );
      await show();
      expect(
        find.textContaining('Requires first clear of Stage 1'),
        findsNWidgets(2),
      );
      final locked = tester.widget<TextButton>(
        find.byKey(const ValueKey('buy_boss_damage_1')),
      );
      expect(locked.onPressed, isNull);
      game.character.talents.highestFirstClearedStage = 5;
      game.character.books = Amount.fromNum(30);
      await show();
      await tester.ensureVisible(
        find.byKey(const ValueKey('buy_boss_damage_1')),
      );
      await tester.tap(find.byKey(const ValueKey('buy_boss_damage_1')));
      await tester.pump();
      await show();
      expect(game.character.talents.ownedRanks['boss_damage'], 1);
      expect(game.character.talents.selectedForNextAttempt, isEmpty);
      expect(find.textContaining('Owned 1/10'), findsOneWidget);
      expect(find.textContaining('Next rank: 4.80 Books'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('select_boss_damage')));
      await tester.pump();
      await show();
      expect(
        game.character.talents.selectedForNextAttempt[TalentPair.boss],
        'boss_damage',
      );
      game.spawnEnemy();
      controller.purchaseTalent('first_clear_gold', 1);
      controller.selectTalent(TalentPair.boss, 'first_clear_gold');
      await show();
      expect(
        find.text('Current attempt: rank 1 · Next attempt: inactive'),
        findsOneWidget,
      );
      expect(
        find.text('Current attempt: inactive · Next attempt: rank 1'),
        findsOneWidget,
      );
      game.character.talents.usedRepeats[1] = 2;
      await show();
      await tester.ensureVisible(
        find.byKey(const ValueKey('talent_stage_gold')),
      );
      expect(
        find.textContaining('0 eligible clears remaining · reward exhausted'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
  test(
    'controller reset clears ranks, pending selection, history and snapshot',
    () async {
      final container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            fakeRuntime(MemoryRepository(), FakeWindow()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final c = container.read(gameControllerProvider.notifier),
          g = c.simulation;
      g.character.talents.highestFirstClearedStage = 5;
      g.character.books = Amount.fromNum(30);
      c.purchaseTalent('boss_damage', 1);
      c.selectTalent(TalentPair.boss, 'boss_damage');
      g.spawnEnemy();
      g.character.talents.usedRepeats[1] = 2;
      await c.reset();
      expect(g.activeAttempt, isNull);
      expect(g.character.talents.ownedRanks, isEmpty);
      expect(g.character.talents.selectedForNextAttempt, isEmpty);
      expect(g.character.talents.usedRepeats, isEmpty);
      expect(g.character.talents.highestFirstClearedStage, 0);
    },
  );
}
