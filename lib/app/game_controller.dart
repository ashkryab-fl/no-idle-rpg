import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/balance/game_balance.dart';
import '../core/numbers/amount.dart';
import '../core/persistence/game_save.dart';
import '../core/persistence/game_save_repository.dart';
import '../domain/activity/idle_level.dart';
import '../domain/talents/talents.dart';
import '../game/desktop_game.dart';
import '../game/systems/game_simulation.dart';
import '../platform/desktop_window_service.dart';
import '../platform/user_activity_service.dart';

enum OverlayPanel { menu, statistics, equipment, talents, settings, debug }

class AppRuntime {
  AppRuntime(
    this.simulation,
    this.repository,
    this.window,
    this.activity, {
    this.startupNotice,
  });
  final GameSimulation simulation;
  final GameSaveRepository repository;
  final DesktopWindowService window;
  final UserActivityService activity;
  final String? startupNotice;
}

final runtimeProvider = Provider<AppRuntime>(
  (ref) => throw StateError('Runtime must be initialized'),
);

class AppUiState {
  const AppUiState({
    this.revision = 0,
    this.panel,
    this.error,
    this.notice,
    this.idleSeconds = 0,
  });
  final int revision;
  final OverlayPanel? panel;
  final String? error;
  final String? notice;
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
    return AppUiState(
      panel: runtime.startupNotice == null ? null : OverlayPanel.menu,
      notice: runtime.startupNotice,
    );
  }

  GameSimulation get simulation => runtime.simulation;
  void refresh() {
    if (!_disposed) {
      state = AppUiState(
        revision: state.revision + 1,
        panel: state.panel,
        error: state.error,
        notice: state.notice,
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
        notice: state.notice,
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
      notice: state.notice,
      idleSeconds: state.idleSeconds,
    );
    try {
      await runtime.window.configure(
        alwaysOnTop: simulation.settings.alwaysOnTop,
        expanded: panel != null,
        heroVisible: simulation.settings.overallOpacity > 0,
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
      notice: state.notice,
      idleSeconds: state.idleSeconds,
    );
  }

  void dismissError() {
    state = AppUiState(
      revision: state.revision + 1,
      panel: state.panel,
      notice: state.notice,
      idleSeconds: state.idleSeconds,
    );
  }

  void dismissNotice() {
    state = AppUiState(
      revision: state.revision + 1,
      panel: state.panel,
      error: state.error,
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

  void purchaseEquipment(String id, int? count) {
    if (_closing || _resetting || _disposed) return;
    final bought = simulation.purchaseEquipment(id, count: count);
    if (bought == 0) return;
    refresh();
    unawaited(save());
  }

  void purchaseTalent(String id, int? count) {
    if (_closing || _resetting || _disposed) return;
    if (simulation.purchaseTalent(id, count: count) == 0) return;
    refresh();
    unawaited(save());
  }

  void selectTalent(TalentPair pair, String? id) {
    if (_closing || _resetting || _disposed) return;
    simulation.selectTalent(pair, id);
    refresh();
    unawaited(save());
  }

  Future<void> updateSettings({
    bool? topmost,
    bool? sound,
    int? fps,
    double? backgroundOpacity,
    double? roadOpacity,
    double? overallOpacity,
    bool persist = true,
  }) async {
    if (_closing || _resetting || _disposed) return;
    final heroWasVisible = simulation.settings.overallOpacity > 0;
    if (topmost != null) simulation.settings.alwaysOnTop = topmost;
    if (sound != null) simulation.settings.sound = sound;
    if (backgroundOpacity != null && backgroundOpacity.isFinite) {
      simulation.settings.backgroundOpacity = backgroundOpacity.clamp(0.0, 1.0);
    }
    if (roadOpacity != null && roadOpacity.isFinite) {
      simulation.settings.roadOpacity = roadOpacity.clamp(0.0, 1.0);
    }
    if (overallOpacity != null && overallOpacity.isFinite) {
      simulation.settings.overallOpacity = overallOpacity.clamp(0.0, 1.0);
    }
    if (fps != null) {
      simulation.settings.fps = fps;
      game.setFps(fps);
    }
    if (topmost != null ||
        heroWasVisible != (simulation.settings.overallOpacity > 0)) {
      await show(state.panel);
    } else {
      refresh();
    }
    if (persist) await save();
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
      hero.gold = Amount.zero;
      hero.books = Amount.zero;
      hero.equipment.clear();
      hero.talents.reset();
      simulation.distance = 0;
      simulation.kills = 0;
      simulation.stage = 1;
      simulation.stageKills = 0;
      simulation.heroHp = simulation.stats.maxHp;
      simulation.resetEncounter();
      simulation.activity.reset(DateTime.now());
      simulation.idle.reset();
      simulation.hitboxes = false;
      simulation.scroll = 0;
      simulation.settings.alwaysOnTop = true;
      simulation.settings.sound = false;
      simulation.settings.fps = 30;
      simulation.settings.backgroundOpacity = 1;
      simulation.settings.roadOpacity = 1;
      simulation.settings.overallOpacity = 1;
      game.setFps(30);
      debugIdleSeconds = null;
      simulation.speed = 1;
      dismissError();
      dismissNotice();
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
