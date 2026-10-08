import 'dart:async';
import 'package:idle_companion/app/game_controller.dart';
import 'package:idle_companion/core/persistence/game_save.dart';
import 'package:idle_companion/core/persistence/game_save_repository.dart';
import 'package:idle_companion/core/persistence/offline_progress_service.dart';
import 'package:idle_companion/game/systems/game_simulation.dart';
import 'package:idle_companion/platform/desktop_window_service.dart';
import 'package:idle_companion/platform/user_activity_service.dart';

class MemoryRepository implements GameSaveRepository {
  int writes = 0;
  Map<String, Object?>? snapshot;
  Completer<void>? gate, resetGate;
  bool fail = false;
  @override
  Future<GameSave?> load() async => null;
  @override
  Future<void> reset() async {
    await resetGate?.future;
    snapshot = null;
  }

  @override
  Future<void> save(GameSave save) async {
    writes++;
    snapshot = save.toJson();
    await gate?.future;
    if (fail) throw StateError('Disk full');
  }
}

class FakeWindow implements DesktopWindowService {
  int quits = 0, cancellations = 0;
  bool failQuit = false;
  bool heroVisible = true;
  Future<void> Function()? closeHandler;
  @override
  Future<void> configure({
    required bool alwaysOnTop,
    required bool expanded,
    bool heroVisible = true,
  }) async {
    this.heroVisible = heroVisible;
  }

  @override
  Future<void> quit() async {
    quits++;
    if (failQuit) throw StateError('Native quit failed');
  }

  @override
  Future<void> cancelClose() async {
    cancellations++;
  }

  @override
  void onCloseRequested(Future<void> Function() handler) {
    closeHandler = handler;
  }
}

class FakeActivity implements UserActivityService {
  Duration idle = Duration.zero;
  @override
  Future<Duration> idleDuration() async => idle;
}

AppRuntime fakeRuntime(
  MemoryRepository repository,
  FakeWindow window, [
  FakeActivity? activity,
]) => AppRuntime(
  GameSimulation(),
  repository,
  window,
  activity ?? FakeActivity(),
  const OfflineProgressResult(Duration.zero),
);
