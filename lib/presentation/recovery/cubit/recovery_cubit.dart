import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'recovery_request.dart';
import '../../../core/persistence/game_save_repository.dart';
import '../../../platform/desktop_window_service.dart';
import 'recovery_state.dart';
export 'recovery_state.dart';

@injectable
class RecoveryCubit extends Cubit<RecoveryState> {
  RecoveryCubit({
    required Object error,
    required this.retryBootstrap,
    required this.window,
    this.repository,
  }) : super(RecoveryState(error: '$error'));
  @factoryMethod
  static RecoveryCubit create(@factoryParam RecoveryRequest request) =>
      RecoveryCubit(
        error: request.error,
        retryBootstrap: request.retry,
        window: request.window,
        repository: request.repository,
      );

  final Future<void> Function() retryBootstrap;
  final DesktopWindowService window;
  final GameSaveRepository? repository;

  Future<void> retry() => _run(retryBootstrap);
  Future<void> reset() => _run(() async {
    if (repository == null) return;
    await repository!.reset();
    if (!isClosed) await retryBootstrap();
  });
  Future<void> quit() => _run(window.quit);

  Future<void> _run(Future<void> Function() action) async {
    if (isClosed || state.busy) return;
    emit(RecoveryState(error: state.error, busy: true));
    try {
      await action();
      if (!isClosed) emit(RecoveryState(error: state.error));
    } catch (error) {
      if (!isClosed) emit(RecoveryState(error: '$error'));
    }
  }
}
