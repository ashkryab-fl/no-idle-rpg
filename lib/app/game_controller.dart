import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/balance/game_balance.dart';
import '../core/numbers/amount.dart';
import '../core/persistence/game_save.dart';
import '../core/persistence/game_save_repository.dart';
import '../core/persistence/offline_progress_service.dart';
import '../domain/activity/idle_animation.dart';
import '../domain/progression/infinite_upgrade.dart';
import '../game/desktop_game.dart';
import '../game/systems/game_simulation.dart';
import '../platform/desktop_window_service.dart';
import '../platform/user_activity_service.dart';

enum OverlayPanel { menu, statistics, upgrades, equipment, settings, debug }

class AppRuntime {
  AppRuntime(
    this.simulation,
    this.repository,
    this.window,
    this.activity,
    this.offline,
  );
  final GameSimulation simulation;
  final GameSaveRepository repository;
  final DesktopWindowService window;
  final UserActivityService activity;
  final OfflineProgressResult offline;
}

final runtimeProvider = Provider<AppRuntime>(
  (ref) => throw StateError('Runtime must be initialized'),
);

class AppUiState {
  const AppUiState({
    this.revision = 0,
    this.panel,
    this.error,
    this.idleSeconds = 0,
  });
  final int revision;
  final OverlayPanel? panel;
  final String? error;
  final double idleSeconds;
}

final gameControllerProvider = NotifierProvider<GameController, AppUiState>(
  GameController.new,
);

class GameController extends Notifier<AppUiState> {
  late AppRuntime runtime;
  late DesktopGame game;
  Timer? _uiTimer, _activityTimer, _saveTimer;
  bool _polling = false,
      _disposed = false,
      _closing = false,
      _resetting = false;
  double? debugIdleSeconds;
  @override
  AppUiState build() {
    runtime = ref.read(runtimeProvider);
    game = DesktopGame(runtime.simulation);
    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => refresh(),
    );
    _activityTimer = Timer.periodic(
      GameBalance.activityPollInterval,
      (_) => unawaited(pollActivity()),
    );
    _saveTimer = Timer.periodic(
      GameBalance.saveInterval,
      (_) => unawaited(save()),
    );
    runtime.window.onCloseRequested(close);
    ref.onDispose(() {
      _disposed = true;
      _uiTimer?.cancel();
      _activityTimer?.cancel();
      _saveTimer?.cancel();
    });
    Future.microtask(pollActivity);
    return const AppUiState();
  }

  GameSimulation get simulation => runtime.simulation;
  void refresh() {
    if (!_disposed) {
      state = AppUiState(
        revision: state.revision + 1,
        panel: state.panel,
        error: state.error,
        idleSeconds: state.idleSeconds,
      );
    }
  }

  Future<void> pollActivity() async {
    if (_polling || _disposed || _closing || _resetting) return;
    _polling = true;
    try {
      final nativeSeconds =
          (await runtime.activity.idleDuration()).inMilliseconds / 1000;
      final seconds = debugIdleSeconds ?? nativeSeconds;
      if (_disposed || _closing || _resetting) return;
      simulation.idle.setIdleSeconds(seconds);
      simulation.activity.sample(
        DateTime.now(),
        simulation.idle.levelFor(nativeSeconds) == IdleLevel.active,
      );
      state = AppUiState(
        revision: state.revision + 1,
        panel: state.panel,
        error: state.error,
        idleSeconds: seconds,
      );
    } catch (error) {
      reportError('Global activity unavailable: $error');
    } finally {
      _polling = false;
    }
  }

  Future<void> show(OverlayPanel? panel) async {
    state = AppUiState(
      revision: state.revision + 1,
      panel: panel,
      error: state.error,
      idleSeconds: state.idleSeconds,
    );
    try {
      await runtime.window.configure(
        alwaysOnTop: simulation.settings.alwaysOnTop,
        expanded: panel != null,
      );
    } catch (error) {
      reportError('Window configuration failed: $error');
    }
  }

  void reportError(String message) {
    if (_disposed) return;
    state = AppUiState(
      revision: state.revision + 1,
      panel: state.panel,
      error: message,
      idleSeconds: state.idleSeconds,
    );
  }

  void dismissError() {
    state = AppUiState(
      revision: state.revision + 1,
      panel: state.panel,
      idleSeconds: state.idleSeconds,
    );
  }

  Future<bool> save() async {
    try {
      await runtime.repository.save(
        GameSave.capture(simulation, DateTime.now()),
      );
      return true;
    } catch (error) {
      reportError('Save failed: $error');
      return false;
    }
  }

  Future<void> close() async {
    if (_closing || _disposed) return;
    if (_resetting) {
      await runtime.window.cancelClose();
      return;
    }
    _closing = true;
    game.suspended = true;
    simulation.activity.pause();
    var completed = false;
    try {
      if (await save()) {
        await runtime.window.quit();
        completed = true;
      } else {
        await runtime.window.cancelClose();
        await show(OverlayPanel.settings);
      }
    } catch (error) {
      reportError('Exit failed: $error');
      try {
        await runtime.window.cancelClose();
      } catch (_) {}
      await show(OverlayPanel.settings);
    } finally {
      if (!completed) {
        _closing = false;
        game.suspended = false;
      } else {
        _uiTimer?.cancel();
        _activityTimer?.cancel();
        _saveTimer?.cancel();
      }
    }
  }

  void upgrade(
    InfiniteUpgradeDefinition definition,
    bool equipment,
    int? count,
  ) {
    if (_closing || _resetting || _disposed) return;
    final oldMax = simulation.stats.maxHp;
    final bought = simulation.progression.upgrade(
      simulation.character,
      definition,
      equipment: equipment,
      count: count,
    );
    if (bought == 0) return;
    if (!simulation.heroHp.isZero) {
      simulation.heroHp = simulation.heroHp + (simulation.stats.maxHp - oldMax);
    }
    refresh();
    unawaited(save());
  }

  Future<void> updateSettings({bool? topmost, bool? sound, int? fps}) async {
    if (_closing || _resetting || _disposed) return;
    if (topmost != null) simulation.settings.alwaysOnTop = topmost;
    if (sound != null) simulation.settings.sound = sound;
    if (fps != null) {
      simulation.settings.fps = fps;
      game.setFps(fps);
    }
    await show(state.panel);
    await save();
    refresh();
  }

  Future<void> reset() async {
    if (_closing || _resetting || _disposed) return;
    _resetting = true;
    game.suspended = true;
    _saveTimer?.cancel();
    try {
      await runtime.repository.reset();
      final hero = simulation.character;
      hero.level = 1;
      hero.xp = Amount.zero;
      hero.gold = Amount.zero;
      hero.books = Amount.zero;
      hero.upgrades.clear();
      hero.equipment.clear();
      simulation.distance = 0;
      simulation.kills = 0;
      simulation.heroHp = simulation.stats.maxHp;
      simulation.resetEncounter();
      simulation.activity.reset(DateTime.now());
      simulation.idle.reset();
      simulation.hitboxes = false;
      simulation.scroll = 0;
      simulation.settings.alwaysOnTop = true;
      simulation.settings.sound = false;
      simulation.settings.fps = 30;
      game.setFps(30);
      debugIdleSeconds = null;
      simulation.speed = 1;
      dismissError();
      await save();
      await show(OverlayPanel.settings);
    } catch (error) {
      reportError('Reset failed: $error');
    } finally {
      _resetting = false;
      game.suspended = false;
      if (!_disposed) {
        _saveTimer = Timer.periodic(
          GameBalance.saveInterval,
          (_) => unawaited(save()),
        );
      }
    }
  }

  void debugAction(String action) {
    if (!kDebugMode || _closing || _resetting || _disposed) return;
    switch (action) {
      case 'spawn':
        simulation.spawnEnemy();
      case 'enemy':
        simulation.killEnemy();
      case 'hero':
        simulation.killHero();
      case 'gold':
        simulation.character.gold =
            simulation.character.gold + Amount.fromNum(100);
      case 'books':
        simulation.character.books =
            simulation.character.books + Amount.fromNum(100);
      case 'xp':
        simulation.progression.addXp(simulation.character, Amount.fromNum(100));
      case 'hitboxes':
        simulation.hitboxes = !simulation.hitboxes;
    }
    refresh();
  }

  void setDebugIdle(double? seconds) {
    if (kDebugMode) {
      debugIdleSeconds = seconds;
      unawaited(pollActivity());
    }
  }
}
