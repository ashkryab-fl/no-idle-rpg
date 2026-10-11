import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'session_cubit.dart';
import 'session_state.dart';

/// One session subscription fans out updates to live feature Cubits.
@lazySingleton
class SessionUpdatesService {
  SessionUpdatesService(SessionCubit session) {
    _sessionSubscription = session.stream.listen((_) => _refreshSubscribers());
  }

  late final StreamSubscription<SessionState> _sessionSubscription;
  final _subscribers =
      <
        Cubit<Object?>,
        ({void Function() refresh, StreamSubscription<Object?> lifecycle})
      >{};
  bool _disposed = false;
  int get subscriberCount => _subscribers.length;

  void subscribe(Cubit<Object?> cubit, void Function() refresh) {
    if (_disposed) throw StateError('Session updates service is disposed');
    if (cubit.isClosed || _subscribers.containsKey(cubit)) return;
    final lifecycle = cubit.stream.listen(
      (_) {},
      onDone: () => _unsubscribe(cubit),
    );
    _subscribers[cubit] = (refresh: refresh, lifecycle: lifecycle);
  }

  void _unsubscribe(Cubit<Object?> cubit) {
    final registration = _subscribers.remove(cubit);
    if (registration != null) unawaited(registration.lifecycle.cancel());
  }

  void _refreshSubscribers() {
    // A refresh can close or register another Cubit. Iterate over a snapshot.
    for (final cubit in _subscribers.keys.toList()) {
      if (cubit.isClosed) {
        _unsubscribe(cubit);
      } else {
        _subscribers[cubit]?.refresh();
      }
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final cancellations = [
      _sessionSubscription.cancel(),
      for (final registration in _subscribers.values)
        registration.lifecycle.cancel(),
    ];
    _subscribers.clear();
    await Future.wait(cancellations);
  }
}
