import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app/companion_app.dart';
import 'app/game_controller.dart';
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
    final support = await getApplicationSupportDirectory();
    final saveDirectory = Directory('${support.path}/idle_companion');
    _instanceLock ??= await AppInstanceLock.acquire(saveDirectory);
    repository = FileGameSaveRepository(
      Directory('${support.path}/idle_companion'),
    );
    final save = await repository.load();
    final simulation = save?.restoreSimulation() ?? GameSimulation();
    await window.configure(
      alwaysOnTop: simulation.settings.alwaysOnTop,
      expanded: false,
      heroVisible: simulation.settings.overallOpacity > 0,
    );
    runApp(
      ProviderScope(
        overrides: [
          runtimeProvider.overrideWithValue(
            AppRuntime(
              simulation,
              repository,
              window,
              UserActivityService.native(),
            ),
          ),
        ],
        child: const CompanionApp(),
      ),
    );
  } catch (error) {
    await window.configure(alwaysOnTop: true, expanded: true);
    runApp(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xff151c2b),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Could not load companion',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text('$error'),
                const SizedBox(height: 16),
                FilledButton(onPressed: bootstrap, child: const Text('Retry')),
                if (repository != null)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: _errorNavigator.currentContext!,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete unreadable save?'),
                          content: const Text(
                            'This permanently clears existing progress.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await repository!.reset();
                        await bootstrap();
                      }
                    },
                    child: const Text('Reset save'),
                  ),
                TextButton(onPressed: window.quit, child: const Text('Quit')),
              ],
            ),
          ),
        ),
        navigatorKey: _errorNavigator,
      ),
    );
  }
}

AppInstanceLock? _instanceLock;
final _errorNavigator = GlobalKey<NavigatorState>();
