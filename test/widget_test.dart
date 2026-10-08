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
import 'package:idle_companion/game/components/environment/scrolling_environment.dart';
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

Future<void> preloadEnvironment(DesktopGame game) async {
  game.images.prefix = '';
  await game.images.loadAll([...AssetCatalog.backgrounds, AssetCatalog.road]);
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
      await preloadEnvironment(controller.game);
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
    await tester.runAsync(() async {
      game.images.prefix = '';
      await preloadEnvironment(game);
    });
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
  testWidgets('Flame loads heroine walk, attack, death and combat guard', (
    tester,
  ) async {
    final game = DesktopGame(GameSimulation(random: Random(1)));
    await tester.runAsync(() async {
      await preloadHeroSprites(game);
      await preloadEnvironment(game);
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
    final environment = game.children.whereType<ScrollingEnvironment>().single;
    expect(environment.sprites, hasLength(3));
    expect(environment.road, isNotNull);
    expect(environment.road!.image.width, 2172);
    expect(environment.sprites.map((sprite) => sprite.image.width), [
      2172,
      2172,
      2171,
    ]);
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
    final attack = actor.animationSprites['hero.attack']!;
    expect(attack.frames, hasLength(4));
    expect(attack.loop, isFalse);
    for (var index = 0; index < attack.frames.length; index++) {
      final frame = attack.frames[index];
      expect(frame.stepTime, .15);
      expect(frame.sprite.srcPosition.x, index * 512);
      expect(frame.sprite.srcPosition.y, 0);
      expect(frame.sprite.srcSize.x, 512);
      expect(frame.sprite.srcSize.y, 512);
      expect(frame.sprite.image.width, 2048);
      expect(frame.sprite.image.height, 512);
    }
    final guard = actor.animationSprites['hero.idle']!;
    expect(guard.frames, hasLength(1));
    expect(guard.loop, isTrue);
    expect(guard.frames.single.sprite.srcSize.x, 512);
    expect(guard.frames.single.sprite.srcSize.y, 512);
    expect(guard.frames.single.sprite.image.width, 512);
    expect(guard.frames.single.sprite.image.height, 512);
    final death = actor.animationSprites['hero.death']!;
    expect(death.frames, hasLength(4));
    expect(death.loop, isFalse);
    for (var index = 0; index < death.frames.length; index++) {
      final frame = death.frames[index];
      expect(frame.stepTime, .4);
      expect(frame.sprite.srcPosition.x, index * 512);
      expect(frame.sprite.srcPosition.y, 0);
      expect(frame.sprite.srcSize.x, 512);
      expect(frame.sprite.srcSize.y, 512);
      expect(frame.sprite.image.width, 2048);
      expect(frame.sprite.image.height, 512);
    }
    await tester.pump(const Duration(milliseconds: 125));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('zero overall opacity keeps settings usable and restores game', (
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
    await tester.runAsync(() async {
      await preloadHeroSprites(controller.game);
      await preloadEnvironment(controller.game);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CompanionApp(),
      ),
    );
    await tester.runAsync(() => controller.game.loaded);
    await tester.pump();
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pump();
    expect(find.text('Background opacity'), findsOneWidget);
    expect(find.text('Road opacity'), findsOneWidget);
    final slider = find.byKey(const ValueKey('Overall opacity'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pump();
    expect(controller.simulation.settings.overallOpacity, 0);
    expect(window.heroVisible, isFalse);
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('gameOpacity'))).opacity,
      0,
    );
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('hudOpacity'))).opacity,
      0,
    );
    expect((repository.snapshot!['settings'] as Map)['overallOpacity'], 0);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(container.read(gameControllerProvider).panel, isNull);
    expect(find.byTooltip('Open settings').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Open settings'));
    await tester.pump();
    expect(container.read(gameControllerProvider).panel, OverlayPanel.settings);
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(400, 0));
    await tester.pump();
    expect(controller.simulation.settings.overallOpacity, 1);
    expect(window.heroVisible, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
}
