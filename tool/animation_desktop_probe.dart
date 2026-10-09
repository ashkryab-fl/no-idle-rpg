// Native playback probe using the production app, renderer and coordinators.
// flutter run -d macos --no-pub -t tool/animation_desktop_probe.dart
// For demo content, add --dart-define=IDLE_PROBE_DEMO=true.
// Saves go into a fresh temporary directory; the ordinary game is untouched.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idle_companion/app/companion_app.dart';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/content/animations/animation_resources.dart';
import 'package:idle_companion/content/animations/hero/rest_graphs.dart';
import 'package:idle_companion/core/persistence/game_save_repository.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/platform/desktop_window_service.dart';
import 'package:idle_companion/platform/user_activity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('IDLE_PROBE_DEMO');
  final logFile = File(
    '/tmp/idle-stage5-native-${demo ? 'demo' : 'default'}.log',
  );
  logFile.writeAsStringSync('');
  void log(String message) {
    stdout.writeln(message);
    logFile.writeAsStringSync('$message\n', mode: FileMode.append);
  }

  final simulation = GameSimulation(
    random: Random(7),
    idleRandom: _LastVariant(),
    resources: demo ? demoAnimationResources() : defaultAnimationResources(),
    restGraph: demo ? HeroRestGraphs.authoringDemo() : null,
  )..encounterRemaining = 1e6;
  final window = NativeDesktopWindowService();
  final directory = await Directory.systemTemp.createTemp(
    'idle-playback-probe-',
  );
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
  log('PROBE_START demo=$demo saves=${directory.path}');
  var last = '';
  final watch = Stopwatch()..start();
  final observer = Timer.periodic(const Duration(milliseconds: 10), (_) {
    final state = simulation.heroPlayback;
    final key =
        '${simulation.phase.name}/${state.nodeId}/${state.clipId}/${state.frameIndex}/${state.generation}';
    if (key != last) {
      last = key;
      log(
        '${watch.elapsedMilliseconds}ms $key frame=${state.frameId} pose=${state.poseId} distance=${simulation.distance.toStringAsFixed(3)}',
      );
    }
  });
  controller.game.suspended = false;
  void idle(double seconds) => controller.setDebugIdle(seconds);
  Future<void> pause(int milliseconds) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));
  idle(120);
  await pause(4000);
  idle(0);
  await pause(100);
  idle(0); // Repeated input must not restart exit.
  await pause(600);
  idle(120); // New inactivity must finish standing before another entry.
  await pause(4300);
  idle(0);
  await pause(3300);
  idle(120);
  await pause(400);
  idle(0); // Pending return during entry.
  simulation.killHero();
  await pause(2600);
  idle(120);
  await pause(400);
  simulation.resetEncounter();
  simulation.encounterRemaining = 1e6;
  await pause(2400);
  idle(0);
  await pause(3300);
  simulation.spawnEnemy();
  idle(120); // Rest must wait for approach/combat/reward.
  await pause(1500);
  simulation.killEnemy();
  await pause(3900);
  idle(0);
  await pause(3300);
  controller.game.suspended = true;
  observer.cancel();
  log(
    'PROBE_COMPLETE demo=$demo phase=${simulation.phase.name} clip=${simulation.heroPlayback.clipId} kills=${simulation.kills}',
  );
  await window.quit();
}

class _ActiveInput implements UserActivityService {
  @override
  Future<Duration> idleDuration() async => Duration.zero;
}

class _LastVariant implements Random {
  @override
  double nextDouble() => .99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}
