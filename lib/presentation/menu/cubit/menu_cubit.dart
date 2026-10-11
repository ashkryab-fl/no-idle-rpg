import 'package:flutter/foundation.dart';
import '../../companion/cubit/overlay_cubit.dart';
import '../../../app/session/session_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../app/session/session_updates_service.dart';
import 'menu_state.dart';
export 'menu_state.dart';

@injectable
class MenuCubit extends Cubit<MenuState> {
  MenuCubit(this.session, this.overlay, this.updates)
    : super(
        MenuState(session.state.idleSeconds, [
          for (final destination in OverlayPanel.values)
            if (destination != OverlayPanel.menu &&
                (destination != OverlayPanel.debug || kDebugMode))
              destination,
        ]),
      );
  final OverlayCubit overlay;
  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (!isClosed) {
      emit(MenuState(session.state.idleSeconds, state.destinations));
    }
  }

  Future<void> open(OverlayPanel panel) => overlay.show(panel);
  Future<void> quit() => session.quit();
}
