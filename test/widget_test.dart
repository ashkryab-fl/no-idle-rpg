import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_companion/app/companion_app.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'helpers/runtime_fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/game/desktop_game.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Quick Menu Exit is visible and saves before quitting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemoryRepository(), window = FakeWindow();
    final container = ProviderContainer(
      overrides: [
        runtimeProvider.overrideWithValue(fakeRuntime(repository, window)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CompanionApp(),
      ),
    );
    final controller = container.read(gameControllerProvider.notifier);
    await controller.show(OverlayPanel.menu);
    await tester.runAsync(() async {
      await controller.game.loaded;
    });
    await tester.pump();
    final exit = find.text('Exit');
    expect(exit, findsOneWidget);
    expect(exit.hitTestable(), findsOneWidget);
    await tester.tap(exit);
    await tester.pump();
    expect(repository.writes, 1);
    expect(window.quits, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  testWidgets('Flame viewport starts without sprite assets', (tester) async {
    final simulation = GameSimulation(random: Random(1));
    final game = DesktopGame(simulation);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 400, height: 190, child: GameWidget(game: game)),
      ),
    );
    await tester.runAsync(() async {
      await game.loaded;
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.isLoaded, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
