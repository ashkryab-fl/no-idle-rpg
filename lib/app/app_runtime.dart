import '../core/persistence/game_save_repository.dart';
import '../game/systems/game_simulation.dart';
import '../platform/desktop_window_service.dart';
import '../platform/user_activity_service.dart';

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
