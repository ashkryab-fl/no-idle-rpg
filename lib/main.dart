import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app/companion_app.dart';
import 'app/app_runtime.dart';
import 'presentation/recovery/widgets/recovery_app.dart';
import 'core/persistence/game_save_repository.dart';
import 'core/persistence/app_instance_lock.dart';
import 'game/systems/game_simulation.dart';
import 'platform/desktop_window_service.dart';
import 'platform/user_activity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
}

Future<void> bootstrap() async {
  final window = NativeDesktopWindowService();
  window.onCloseRequested(window.quit);
  FileGameSaveRepository? repository;
  try {
    const isolatedPath = String.fromEnvironment(
      'IDLE_COMPANION_SAVE_DIRECTORY',
    );
    final saveDirectory = isolatedPath.isNotEmpty
        ? Directory(isolatedPath)
        : Directory(
            '${(await getApplicationSupportDirectory()).path}/idle_companion',
          );
    _instanceLock ??= await AppInstanceLock.acquire(saveDirectory);
    repository = FileGameSaveRepository(saveDirectory);
    final save = await repository.load();
    final simulation = save?.restoreSimulation() ?? GameSimulation();
    await window.configure(
      alwaysOnTop: simulation.settings.alwaysOnTop,
      expanded: repository.lastLoadStatus.notice != null,
      heroVisible: simulation.settings.overallOpacity > 0,
      scale: simulation.settings.windowScale,
    );
    runApp(
      CompanionApp(
        runtime: AppRuntime(
          simulation,
          repository,
          window,
          UserActivityService.native(),
          startupNotice: repository.lastLoadStatus.notice,
        ),
      ),
    );
  } catch (error) {
    await window.configure(alwaysOnTop: true, expanded: true);
    runApp(
      RecoveryApp(
        error: error,
        retry: bootstrap,
        window: window,
        repository: repository,
      ),
    );
  }
}

AppInstanceLock? _instanceLock;
