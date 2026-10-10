import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_companion/app/companion_app.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'helpers/runtime_fakes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/game/desktop_game.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/core/assets/asset_catalog.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/animation/ids.dart';
import 'package:idle_companion/game/components/hero/actor_component.dart';
import 'package:idle_companion/game/components/environment/scrolling_environment.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

Future<void> preloadHeroSprites(DesktopGame game) async {
  game.images.prefix = '';
  await game.images.loadAll(
    game.simulation.resources.frames.values
        .map((frame) => frame.asset)
        .whereType<String>()
        .toSet()
        .toList(),
  );
}

Future<void> preloadEnvironment(DesktopGame game) async {
  game.images.prefix = '';
  await game.images.loadAll([...AssetCatalog.backgrounds, AssetCatalog.road]);
}

void main() {
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
    final resources = game.simulation.resources;
    final cache = actor.frameCache;
    final walk = resources.clip(const ClipId('hero.walk'));
    expect(walk.frames, hasLength(10));
    for (var index = 0; index < walk.frames.length; index++) {
      final sprite = cache.sprite(walk.frames[index].frameId);
      expect(sprite.srcPosition.x, index * 512);
      expect(sprite.srcPosition.y, 0);
      expect(sprite.srcSize.x, 512);
      expect(sprite.srcSize.y, 512);
      expect(sprite.image.width, 5120);
      expect(sprite.image.height, 512);
    }
    for (final (id, count, sheetWidth) in [
      ('hero.attack', 4, 2048),
      ('hero.death', 4, 2048),
      ('hero.standUp', 6, 3072),
    ]) {
      final clip = resources.clip(ClipId(id));
      expect(clip.frames, hasLength(count));
      for (var index = 0; index < count; index++) {
        final sprite = cache.sprite(clip.frames[index].frameId);
        expect(sprite.srcPosition.x, index * 512);
        expect(sprite.srcPosition.y, 0);
        expect(sprite.srcSize.x, 512);
        expect(sprite.srcSize.y, 512);
        expect(sprite.image.width, sheetWidth);
        expect(sprite.image.height, 512);
      }
    }
    final guard = cache.sprite(
      resources.clip(const ClipId('hero.idle')).frames.single.frameId,
    );
    expect(guard.image.width, 512);
    expect(guard.image.height, 512);
    final seated = cache.sprite(resources.pose(PoseId.seatedNeutral).frameId);
    final sit = resources.clip(const ClipId('hero.sitDown'));
    final sharpen = resources.clip(const ClipId('hero.sharpen'));
    expect(identical(cache.sprite(sit.frames.last.frameId), seated), isTrue);
    expect(
      identical(cache.sprite(sharpen.frames.first.frameId), seated),
      isTrue,
    );
    expect(seated.image.width, 512);
    expect(cache.sprite(sharpen.frames[1].frameId).image.width, 4608);
    expect(cache.sprite(sit.frames.first.frameId).image.width, 2048);
    // Render real sprite pixels across the end hold. The earlier renderer
    // wrapped every idle sprite here and replayed the standing entry frame.
    game.suspended = true;
    final idle = game.simulation.idle;
    idle.setIdleSeconds(30);
    idle.advance(.01);
    idle.advance(.95);
    await tester.runAsync(() async {
      Future<List<int>> captureActor() async {
        final recorder = ui.PictureRecorder();
        actor.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 190);
        picture.dispose();
        final pixels = (await image.toByteData())!.buffer.asUint8List();
        image.dispose();
        return pixels;
      }

      final end = await captureActor();
      idle.advance(.4);
      expect(game.simulation.heroPlayback.nodeId, HeroRestGraphs.sitHold);
      final held = await captureActor();
      var differentBytes = 0;
      for (var index = 0; index < end.length; index++) {
        if (end[index] != held[index]) differentBytes++;
      }
      expect(
        differentBytes,
        0,
        reason: 'The completed seated pose must stay still',
      );
      idle.advance(.34);
      expect(game.simulation.heroPlayback.nodeId, HeroRestGraphs.sharpen);
      expect(game.simulation.heroPlayback.frameIndex, 0);
      expect(await captureActor(), orderedEquals(end));
      idle.advance(.225);
      expect(game.simulation.heroPlayback.frameIndex, 1);
      idle.setIdleSeconds(0);
      idle.advance(0);
      expect(game.simulation.heroPlayback.nodeId, HeroRestGraphs.exitHold);
      expect(game.simulation.heroPlayback.clipId, isNull);
      expect(await captureActor(), orderedEquals(end));
    });
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
