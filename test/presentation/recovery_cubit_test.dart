import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_companion/presentation/recovery/cubit/recovery_cubit.dart';
import '../helpers/runtime_fakes.dart';

void main() {
  test(
    'Recovery serializes retries and reports asynchronous failures',
    () async {
      final gate = Completer<void>();
      var retries = 0;
      final cubit = RecoveryCubit(
        error: 'Cannot read save',
        window: FakeWindow(),
        retryBootstrap: () async {
          retries++;
          await gate.future;
          throw StateError('Load failed again');
        },
      );
      addTearDown(cubit.close);
      final retry = cubit.retry();
      expect(cubit.state.busy, isTrue);
      await cubit.retry();
      expect(retries, 1);
      gate.complete();
      await retry;
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.error, contains('Load failed again'));
    },
  );

  test(
    'Recovery waits for deletion before retrying and handles disposal',
    () async {
      final repository = MemoryRepository()..resetGate = Completer<void>();
      var retries = 0;
      final cubit = RecoveryCubit(
        error: 'Cannot read save',
        repository: repository,
        window: FakeWindow(),
        retryBootstrap: () async => retries++,
      );
      final reset = cubit.reset();
      expect(cubit.state.busy, isTrue);
      expect(retries, 0);
      await cubit.close();
      repository.resetGate!.complete();
      await reset;
      expect(cubit.isClosed, isTrue);
      expect(retries, 0);
    },
  );
}
