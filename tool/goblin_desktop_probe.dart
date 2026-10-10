// flutter run -d macos --no-pub -t tool/goblin_desktop_probe.dart
// Captures the production renderer with an isolated save directory.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_companion/app/companion_app.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/balance/game_balance.dart';
import 'package:idle_companion/core/persistence/game_save_repository.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/platform/desktop_window_service.dart';
import 'package:idle_companion/platform/user_activity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final output = (await Directory.systemTemp.createTemp(
    'idle-goblin-native-',
  )).path;
  final simulation = GameSimulation(random: _GoblinRoll())
    ..encounterRemaining = 1e6;
  final window = NativeDesktopWindowService();
  final directory = await Directory.systemTemp.createTemp('goblin-probe-save-');
  final container = ProviderContainer(
    overrides: [
      runtimeProvider.overrideWithValue(
        AppRuntime(
          simulation,
          FileGameSaveRepository(directory),
          window,
          _ActiveInput(),
        ),
      ),
    ],
  );
  final controller = container.read(gameControllerProvider.notifier);
  controller.game.suspended = true;
  await window.configure(alwaysOnTop: true, expanded: false);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CompanionApp(),
    ),
  );
  await controller.game.loaded;
  await Future<void>.delayed(const Duration(seconds: 1));
  // Drain Flame's component lifecycle queue even though playback is paused.
  await controller.game.ready();
  controller.game.updateTree(0);
  final lines = <String>[];
  Future<void> capture(String name) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(4);
    controller.game.renderTree(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1600, 760);
    final rgba = await image.toByteData();
    final pixels = rgba!.buffer.asUint8List();
    if (!pixels.any((value) => value != 0)) {
      throw StateError('Empty native capture: $name');
    }
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    final playback = simulation.enemyPlayback!;
    final line =
        '$name phase=${simulation.phase.name} clip=${playback.clipId} cell=${playback.frameIndex} distance=${simulation.distance.toStringAsFixed(3)} enemyX=${simulation.enemyX.toStringAsFixed(3)}';
    lines.add(line);
    stdout.writeln(line);
  }

  simulation.spawnEnemy();
  await capture('01-approach-start');
  simulation.advance(GameBalance.approachDuration - .2);
  await capture('02-approach-guard');
  simulation.advance(.4);
  await capture('03-attack');
  simulation.advance(.16);
  await capture('04-knife-extended');
  simulation.advance(.34);
  await capture('05-between-attacks');
  simulation.killEnemy();
  simulation.advance(.4);
  await capture('06-death-fade');
  await File('$output/playback.txt').writeAsString('${lines.join('\n')}\n');
  stdout.writeln('GOBLIN_PROBE_COMPLETE output=$output');
  await window.quit();
}

class _ActiveInput implements UserActivityService {
  @override
  Future<Duration> idleDuration() async => Duration.zero;
}

class _GoblinRoll implements Random {
  @override
  double nextDouble() => .99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
