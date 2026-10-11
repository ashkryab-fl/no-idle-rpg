import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/numbers/amount.dart';
import 'package:idle_companion/presentation/overlay/debug_panel.dart';
import 'package:idle_companion/presentation/settings/settings_panel.dart';
import 'package:idle_companion/presentation/statistics/statistics_panel.dart';
import '../helpers/runtime_fakes.dart';

void main() {
  testWidgets(
    'statistics, debug and reset show the new model at desktop width',
    (tester) async {
      tester.view.physicalSize = const Size(400, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryRepository();
      final container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            fakeRuntime(repository, FakeWindow()),
          ),
        ],
      );
      final controller = container.read(gameControllerProvider.notifier);
      Future<void> show(Widget panel) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: panel)),
        ),
      );
      await show(StatisticsPanel(controller: controller));
      expect(find.text('Stage'), findsOneWidget);
      expect(find.text('Wave'), findsOneWidget);
      expect(find.text('DPS'), findsOneWidget);
      expect(find.text('HP / max HP'), findsOneWidget);
      expect(find.text('Character level'), findsNothing);
      expect(find.text('Experience'), findsNothing);
      expect(find.textContaining('XP'), findsNothing);
      expect(tester.takeException(), isNull);
      await show(DebugPanel(controller: controller));
      expect(find.text('+100 Gold'), findsOneWidget);
      expect(find.text('+100 Books'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      for (final level in [1, 2, 3]) {
        expect(find.text('Level $level'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await show(SettingsPanel(controller: controller));
      final reset = find.text('Reset save data');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.text('Reset all progress?'), findsOneWidget);
      expect(find.textContaining('Stage progress, currencies'), findsOneWidget);
      expect(find.textContaining('XP'), findsNothing);
      expect(find.textContaining('Levels,'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );

  test(
    'controller HP purchase and reset persist without hero levels',
    () async {
      final repository = MemoryRepository();
      final container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            fakeRuntime(repository, FakeWindow()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.simulation.heroHp = Amount.fromNum(50);
      controller.simulation.character.gold = Amount.fromNum(100);
      controller.purchaseEquipment('armor', 1);
      expect(controller.simulation.heroHp.toDouble(), closeTo(56, 1e-9));
      expect(
        (repository.snapshot!['character'] as Map).keys,
        isNot(contains('level')),
      );
      expect(
        (repository.snapshot!['character'] as Map).keys,
        isNot(contains('xp')),
      );
      controller.simulation.stage = 100;
      await controller.reset();
      expect(controller.simulation.stage, 1);
      expect(controller.simulation.character.equipment, isEmpty);
      expect(controller.simulation.heroHp.toDouble(), closeTo(120, 1e-9));
      expect(
        (repository.snapshot!['character'] as Map).keys,
        isNot(contains('level')),
      );
    },
  );
}
