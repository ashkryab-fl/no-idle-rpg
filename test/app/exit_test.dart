import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/game_controller.dart';
import '../helpers/runtime_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryRepository repository;
  late FakeWindow window;
  late FakeActivity activity;
  late ProviderContainer container;
  late GameController controller;
  setUp(() {
    repository = MemoryRepository();
    window = FakeWindow();
    activity = FakeActivity();
    container = ProviderContainer(
      overrides: [
        runtimeProvider.overrideWithValue(
          fakeRuntime(repository, window, activity),
        ),
      ],
    );
    container.read(gameControllerProvider);
    controller = container.read(gameControllerProvider.notifier);
  });
  tearDown(() {
    container.dispose();
  });

  test(
    'Exit waits for save, freezes simulation and ignores repeated requests',
    () async {
      repository.gate = Completer<void>();
      final exit = controller.close();
      await controller.close();
      expect(controller.game.suspended, isTrue);
      expect(window.quits, 0);
      expect(repository.writes, 1);
      repository.gate!.complete();
      await exit;
      expect(window.quits, 1);
    },
  );
  test(
    'Save failure cancels native exit and allows a successful retry',
    () async {
      repository.fail = true;
      await window.closeHandler!();
      expect(window.quits, 0);
      expect(window.cancellations, 1);
      expect(controller.game.suspended, isFalse);
      expect(
        container.read(gameControllerProvider).panel,
        OverlayPanel.settings,
      );
      expect(
        container.read(gameControllerProvider).error,
        contains('Disk full'),
      );
      repository.fail = false;
      await controller.close();
      expect(window.quits, 1);
    },
  );
  test('Native close during reset is cancelled and can be retried', () async {
    controller.simulation.stage = 10;
    controller.simulation.stageKills = 5;
    controller.simulation.settings.backgroundOpacity = 0;
    controller.simulation.settings.roadOpacity = .5;
    controller.simulation.settings.overallOpacity = 0;
    repository.resetGate = Completer<void>();
    final reset = controller.reset();
    await window.closeHandler!();
    expect(window.quits, 0);
    expect(window.cancellations, 1);
    repository.resetGate!.complete();
    await reset;
    expect(controller.simulation.stage, 1);
    expect(controller.simulation.stageKills, 0);
    expect(controller.simulation.settings.backgroundOpacity, 1);
    expect(controller.simulation.settings.roadOpacity, 1);
    expect(controller.simulation.settings.overallOpacity, 1);
    await controller.close();
    expect(window.quits, 1);
  });
  test('Native exit failure resumes game and reports the error', () async {
    window.failQuit = true;
    await controller.close();
    expect(controller.game.suspended, isFalse);
    expect(window.cancellations, 1);
    expect(
      container.read(gameControllerProvider).error,
      contains('Native quit failed'),
    );
  });
  test(
    'Debug idle override does not falsify real activity classification',
    () async {
      controller.debugIdleSeconds = 301;
      await Future<void>.delayed(Duration.zero);
      await controller.pollActivity();
      expect(controller.simulation.activity.active, isTrue);
      expect(container.read(gameControllerProvider).idleSeconds, 301);
    },
  );
}
