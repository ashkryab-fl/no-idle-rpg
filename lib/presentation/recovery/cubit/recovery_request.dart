import '../../../core/persistence/game_save_repository.dart';
import '../../../platform/desktop_window_service.dart';

class RecoveryRequest {
  const RecoveryRequest({
    required this.error,
    required this.retry,
    required this.window,
    this.repository,
  });
  final Object error;
  final Future<void> Function() retry;
  final DesktopWindowService window;
  final GameSaveRepository? repository;
}
