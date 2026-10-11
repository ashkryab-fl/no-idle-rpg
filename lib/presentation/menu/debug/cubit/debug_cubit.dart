import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/numbers/amount.dart';
import '../../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../app/session/session_updates_service.dart';
import 'debug_state.dart';
export 'debug_state.dart';

@injectable
class DebugCubit extends Cubit<DebugState> {
  DebugCubit(this.session, this.updates)
    : super(DebugState.fromSession(session));
  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (!isClosed) emit(DebugState.fromSession(session));
  }

  void runAction(String action) {
    if (!kDebugMode || !session.canMutate || isClosed) return;
    final simulation = session.simulation;
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
    session.refresh();
    refresh();
  }

  void setDebugIdle(double? seconds) {
    if (kDebugMode && session.canMutate && !isClosed) {
      session.activityOverride = seconds;
      refresh();
      unawaited(session.pollActivity());
    }
  }

  void setSpeed(double speed) {
    if (!kDebugMode || !session.canMutate || isClosed) return;
    if (![1.0, 5.0, 20.0].contains(speed)) return;
    session.simulation.speed = speed;
    session.refresh();
    refresh();
  }
}
