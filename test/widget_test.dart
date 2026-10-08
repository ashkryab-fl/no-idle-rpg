import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_companion/app/companion_app.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'helpers/runtime_fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/game/desktop_game.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/core/assets/animation_catalog.dart';
import 'package:idle_companion/game/components/hero/actor_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

Future<void> preloadHeroSprites(DesktopGame game) async {
  game.images.prefix = '';
  for (final definition in game.simulation.animations.definitions.values) {
    if (definition.id.startsWith('hero.') && definition.asset != null) {
      await game.images.load(definition.asset!);
    }
  }
}

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
    final controller = container.read(gameControllerProvider.notifier);
    // Decode outside FakeAsync so the engine image callback can complete.
    await tester.runAsync(() async {
      await preloadHeroSprites(controller.game);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CompanionApp(),
      ),
    );
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
  testWidgets('Flame viewport starts without a hero sprite asset', (
    tester,
  ) async {
    final simulation = GameSimulation(
      random: Random(1),
      animations: AnimationCatalog({
        for (final definition in AnimationCatalog().definitions.values)
          if (definition.asset != null)
            definition.id: AnimationDefinition(
              id: definition.id,
              asset: 'assets/characters/hero/missing.png',
            ),
      }),
    );
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
    await tester.runAsync(() => game.ready());
    expect(game.isLoaded, isTrue);
    final actor = game.children.whereType<ActorComponent>().first;
    expect(actor.animationSprites, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Flame loads walk', (
    tester,
  ) async {
    final game = DesktopGame(GameSimulation(random: Random(1)));
    await tester.runAsync(() async {
      await preloadHeroSprites(game);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 400, height: 190, child: GameWidget(game: game)),
      ),
    );
    await tester.runAsync(() async {
      await game.loaded;
    });
    await tester.pump();
    await tester.runAsync(() => game.ready());
    final actor = game.children.whereType<ActorComponent>().first;
    final walk = actor.animationSprites['hero.walk']!;
    expect(walk.frames, hasLength(10));
    expect(walk.loop, isTrue);
    for (var index = 0; index < walk.frames.length; index++) {
      final frame = walk.frames[index];
      expect(frame.stepTime, .125);
      expect(frame.sprite.srcPosition.x, index * 512);
      expect(frame.sprite.srcPosition.y, 0);
      expect(frame.sprite.srcSize.x, 512);
      expect(frame.sprite.srcSize.y, 512);
      expect(frame.sprite.image.width, 5120);
      expect(frame.sprite.image.height, 512);
    }
    await tester.pump(const Duration(milliseconds: 125));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
