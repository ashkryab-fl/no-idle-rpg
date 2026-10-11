import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../app/di/dependency_scope.dart';
import '../cubit/recovery_request.dart';
import '../../../core/persistence/game_save_repository.dart';
import '../../../platform/desktop_window_service.dart';
import '../cubit/recovery_cubit.dart';

class RecoveryApp extends StatelessWidget {
  const RecoveryApp({
    super.key,
    required this.error,
    required this.retry,
    required this.window,
    this.repository,
  });
  final Object error;
  final Future<void> Function() retry;
  final DesktopWindowService window;
  final GameSaveRepository? repository;

  @override
  Widget build(BuildContext context) => DependencyScope(
    child: BlocProvider(
      create: (context) => context.read<GetIt>()<RecoveryCubit>(
        param1: RecoveryRequest(
          error: error,
          retry: retry,
          window: window,
          repository: repository,
        ),
      ),
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: _RecoveryView(canReset: repository != null),
      ),
    ),
  );
}

class _RecoveryView extends StatelessWidget {
  const _RecoveryView({required this.canReset});
  final bool canReset;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<RecoveryCubit, RecoveryState>(
    builder: (context, state) {
      final cubit = context.read<RecoveryCubit>();
      return Scaffold(
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
              Text(state.error),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.busy ? null : cubit.retry,
                child: const Text('Retry'),
              ),
              if (canReset)
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete unreadable save?'),
                              content: const Text(
                                'This permanently clears existing progress.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) await cubit.reset();
                        },
                  child: const Text('Reset save'),
                ),
              TextButton(
                onPressed: state.busy ? null : cubit.quit,
                child: const Text('Quit'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
