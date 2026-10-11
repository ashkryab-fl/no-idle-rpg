import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import '../app_runtime.dart';
import '../../core/balance/game_balance.dart';
import '../../core/numbers/amount.dart';
import '../../core/persistence/game_save.dart';
import '../../domain/activity/idle_level.dart';
import '../../game/desktop_game.dart';
import '../../game/systems/game_simulation.dart';
import 'session_state.dart';

@lazySingleton
class SessionCubit extends Cubit<SessionState> with WidgetsBindingObserver {
  SessionCubit(this.runtime)
    : game = DesktopGame(runtime.simulation),
      super(SessionState(notice: runtime.startupNotice)) {
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
    WidgetsBinding.instance.addObserver(this);
    runtime.window.onCloseRequested(quit);
    Future.microtask(pollActivity);
  }

  final AppRuntime runtime;
  final DesktopGame game;
  Timer? _uiTimer, _activityTimer, _saveTimer;
  bool _polling = false,
      _disposed = false,
      _closing = false,
      _resetting = false;
  double? activityOverride;
  bool get canMutate => !_disposed && !_closing && !_resetting;

  GameSimulation get simulation => runtime.simulation;
  void refresh() {
    if (!_disposed) {
      emit(
        SessionState(
          revision: state.revision + 1,
          error: state.error,
          notice: state.notice,
          settingsRequest: state.settingsRequest,
          idleSeconds: state.idleSeconds,
        ),
      );
    }
  }

  Future<void> pollActivity() async {
    if (_polling || _disposed || _closing || _resetting) return;
    _polling = true;
    try {
      final nativeSeconds =
          (await runtime.activity.idleDuration()).inMilliseconds / 1000;
      final seconds = activityOverride ?? nativeSeconds;
      if (_disposed || _closing || _resetting) return;
      simulation.idle.setIdleSeconds(seconds);
      simulation.activity.sample(
        DateTime.now(),
        simulation.idle.levelFor(nativeSeconds) == IdleLevel.active,
      );
      emit(
        SessionState(
          revision: state.revision + 1,
          error: state.error,
          notice: state.notice,
          settingsRequest: state.settingsRequest,
          idleSeconds: seconds,
        ),
      );
    } catch (error) {
      reportError('Global activity unavailable: $error');
    } finally {
      _polling = false;
    }
  }

  void reportError(String message) {
    if (_disposed) return;
    emit(
      SessionState(
        revision: state.revision + 1,
        error: message,
        notice: state.notice,
        idleSeconds: state.idleSeconds,
        settingsRequest: state.settingsRequest,
      ),
    );
  }

  void dismissError() {
    if (_disposed) return;
    emit(
      SessionState(
        revision: state.revision + 1,
        notice: state.notice,
        idleSeconds: state.idleSeconds,
        settingsRequest: state.settingsRequest,
      ),
    );
  }

  void dismissNotice() {
    if (_disposed) return;
    emit(
      SessionState(
        revision: state.revision + 1,
        error: state.error,
        idleSeconds: state.idleSeconds,
        settingsRequest: state.settingsRequest,
      ),
    );
  }

  Future<bool> save() => canMutate ? _saveSnapshot() : Future.value(false);

  Future<bool> _saveSnapshot() async {
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

  Future<void> quit() async {
    if (_closing || _disposed) return;
    if (_resetting) {
      await runtime.window.cancelClose();
      return;
    }
    _closing = true;
    game.suspended = true;
    simulation.activity.pause();
    refresh();
    var completed = false;
    try {
      final saved = await _saveSnapshot();
      if (_disposed) return;
      if (saved) {
        await runtime.window.quit();
        completed = true;
      } else {
        await runtime.window.cancelClose();
        requestSettings();
      }
    } catch (error) {
      reportError('Exit failed: $error');
      try {
        await runtime.window.cancelClose();
      } catch (_) {}
      requestSettings();
    } finally {
      if (!completed) {
        _closing = false;
        game.suspended = _disposed;
        refresh();
      } else {
        _uiTimer?.cancel();
        _activityTimer?.cancel();
        _saveTimer?.cancel();
      }
    }
  }

  Future<void> resetProgress() async {
    if (_closing || _resetting || _disposed) return;
    _resetting = true;
    game.suspended = true;
    _saveTimer?.cancel();
    refresh();
    try {
      await runtime.repository.reset();
      if (_disposed) return;
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
      await configureWindow(expanded: true);
      if (_disposed) return;
      activityOverride = null;
      simulation.speed = 1;
      dismissError();
      dismissNotice();
      await _saveSnapshot();
      requestSettings();
    } catch (error) {
      reportError('Reset failed: $error');
    } finally {
      _resetting = false;
      game.suspended = _disposed;
      if (!_disposed) {
        refresh();
        _saveTimer = Timer.periodic(
          GameBalance.saveInterval,
          (_) => unawaited(save()),
        );
      }
    }
  }

  void requestSettings() {
    if (_disposed) return;
    emit(
      SessionState(
        revision: state.revision + 1,
        error: state.error,
        notice: state.notice,
        idleSeconds: state.idleSeconds,
        settingsRequest: state.settingsRequest + 1,
      ),
    );
  }

  Future<void> configureWindow({required bool expanded}) async {
    if (_disposed) return;
    try {
      await runtime.window.configure(
        alwaysOnTop: simulation.settings.alwaysOnTop,
        expanded: expanded,
        heroVisible: simulation.settings.overallOpacity > 0,
      );
    } catch (error) {
      reportError('Window configuration failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(save());
    }
  }

  @disposeMethod
  @override
  Future<void> close() async {
    _disposed = true;
    game.suspended = true;
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _activityTimer?.cancel();
    _saveTimer?.cancel();
    runtime.window.onCloseRequested(() async {});
    await super.close();
  }
}
