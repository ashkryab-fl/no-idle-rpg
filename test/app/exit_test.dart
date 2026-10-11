import 'dart:async';
import 'package:get_it/get_it.dart';
import 'package:idle_companion/app/di/injection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/app/session/session_cubit.dart';
import 'package:idle_companion/presentation/companion/cubit/overlay_cubit.dart';
import '../helpers/runtime_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryRepository repository;
  late FakeWindow window;
  late FakeActivity activity;
  late GetIt dependencies;
  late OverlayCubit overlay;
  late SessionCubit controller;
  setUp(() {
    repository = MemoryRepository();
    window = FakeWindow();
    activity = FakeActivity();
    dependencies = configureDependencies(
      runtime: fakeRuntime(repository, window, activity),
    );
    controller = dependencies<SessionCubit>();
    overlay = dependencies<OverlayCubit>();
  });
  tearDown(() async {
    await dependencies.reset();
  });

  test(
    'Exit waits for save, freezes simulation and ignores repeated requests',
    () async {
      repository.gate = Completer<void>();
      final exit = controller.quit();
      await controller.quit();
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
      final settingsOpened = overlay.stream.firstWhere(
        (state) => state.panel == OverlayPanel.settings,
      );
      await window.closeHandler!();
      await settingsOpened;
      expect(window.quits, 0);
      expect(window.cancellations, 1);
      expect(controller.game.suspended, isFalse);
      expect(overlay.state.panel, OverlayPanel.settings);
      expect(controller.state.error, contains('Disk full'));
      repository.fail = false;
      await controller.quit();
      expect(window.quits, 1);
    },
  );
  test('Native close during reset is cancelled and can be retried', () async {
    controller.simulation.stage = 10;
    controller.simulation.stageKills = 4;
    controller.simulation.settings.backgroundOpacity = 0;
    controller.simulation.settings.roadOpacity = .5;
    controller.simulation.settings.overallOpacity = 0;
    repository.resetGate = Completer<void>();
    final reset = controller.resetProgress();
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
    await controller.quit();
    expect(window.quits, 1);
  });
}
