import 'dart:async';
import '../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../app/session/session_updates_service.dart';
import 'overlay_state.dart';
export 'overlay_state.dart';

@lazySingleton
class OverlayCubit extends Cubit<CompanionOverlayState> {
  OverlayCubit(this.session, this.updates)
    : _settingsRequest = session.state.settingsRequest,
      super(
        CompanionOverlayState.fromSession(
          session,
          session.state.notice == null ? null : OverlayPanel.menu,
        ),
      );
  int _settingsRequest;

  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (isClosed) return;
    if (_settingsRequest != session.state.settingsRequest) {
      _settingsRequest = session.state.settingsRequest;
      unawaited(show(OverlayPanel.settings));
    } else {
      emit(CompanionOverlayState.fromSession(session, state.panel));
    }
  }

  Future<void> show(OverlayPanel? panel) async {
    if (isClosed) return;
    emit(CompanionOverlayState.fromSession(session, panel));
    await session.configureWindow(expanded: panel != null);
  }

  void toggleMenu() =>
      unawaited(show(state.panel == null ? OverlayPanel.menu : null));
  Future<void> configureWindow() =>
      session.configureWindow(expanded: state.panel != null);
  void dismissError() => session.dismissError();
  void dismissNotice() => session.dismissNotice();
  @disposeMethod
  Future<void> dispose() => close();
}
