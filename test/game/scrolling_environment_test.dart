import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/game/components/environment/scrolling_environment.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'road follows travel distance independently of scenery',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 200, 1),
        ui.Paint()..color = const ui.Color(0xffff0000),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(200, 0, 200, 1),
        ui.Paint()..color = const ui.Color(0xff0000ff),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 1);
      picture.dispose();
      addTearDown(image.dispose);
      final simulation = GameSimulation()..distance = 200;
      final environment = ScrollingEnvironment(
        simulation,
        sprites: [Sprite(image)],
        road: Sprite(image),
      );
      Future<List<int>> pixelAt(int x, int y) async {
        final recorder = ui.PictureRecorder();
        environment.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final frame = await picture.toImage(400, 190);
        picture.dispose();
        final bytes = (await frame.toByteData())!;
        frame.dispose();
        return List.generate(4, (i) => bytes.getUint8((y * 400 + x) * 4 + i));
      }

      expect(await pixelAt(10, 100), [0, 0, 255, 255]);
      expect(await pixelAt(10, 180), [0, 0, 255, 255]);
      expect(await pixelAt(390, 180), [255, 0, 0, 255]);
      simulation.distance = 0;
      expect(await pixelAt(10, 180), [255, 0, 0, 255]);
    },
  );

  test(
    'backgrounds advance in order across viewport and full-cycle wraps',
    () async {
      const red = ui.Color(0xffff0000);
      const green = ui.Color(0xff00ff00);
      const blue = ui.Color(0xff0000ff);
      final sprites = <Sprite>[];
      for (final color in [red, green, blue]) {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(
          const ui.Rect.fromLTWH(0, 0, 1, 1),
          ui.Paint()..color = color,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(1, 1);
        picture.dispose();
        addTearDown(image.dispose);
        sprites.add(Sprite(image));
      }
      final simulation = GameSimulation();
      final environment = ScrollingEnvironment(simulation, sprites: sprites);
      for (final (distance, left, right) in [
        (0.0, red, red),
        (350.0, red, green),
        (350.25, red, green),
        (400.0, green, green),
        (750.0, green, blue),
        (800.0, blue, blue),
        (1150.0, blue, red),
        (1150.75, blue, red),
        (1200.0, red, red),
        (1600.0, green, green),
      ]) {
        simulation.distance = distance;
        simulation.scroll = distance % 400;
        final recorder = ui.PictureRecorder();
        environment.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 190);
        picture.dispose();
        final pixels = (await image.toByteData())!;
        image.dispose();
        List<int> rgbaAt(int x, int y) {
          final offset = (y * 400 + x) * 4;
          return List.generate(4, (index) => pixels.getUint8(offset + index));
        }

        List<int> rgba(ui.Color color) => [
          (color.r * 255).round(),
          (color.g * 255).round(),
          (color.b * 255).round(),
          255,
        ];
        expect(rgbaAt(10, 100), rgba(left), reason: 'distance $distance');
        expect(rgbaAt(390, 100), rgba(right), reason: 'distance $distance');
        expect(
          List.generate(400, (x) => rgbaAt(x, 100)[3]),
          everyElement(255),
          reason: 'No transparent gap at fractional distance $distance',
        );
        expect(rgbaAt(10, 20), [0, 0, 0, 0]);
        expect(rgbaAt(10, 160), rgba(left));
        expect(rgbaAt(20, 172), [0, 0, 0, 0]);
      }
    },
  );
}
