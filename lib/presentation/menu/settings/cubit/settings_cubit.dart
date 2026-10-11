import '../../../../app/session/session_cubit.dart';
import '../../../companion/cubit/overlay_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../app/session/session_updates_service.dart';
import 'settings_state.dart';
export 'settings_state.dart';

@injectable
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this.session, this.overlay, this.updates)
    : super(SettingsState.fromSession(session));
  final OverlayCubit overlay;
  final SessionCubit session;
  final SessionUpdatesService updates;

  @postConstruct
  void subscribeToSession() => updates.subscribe(this, refresh);

  void refresh() {
    if (!isClosed) emit(SettingsState.fromSession(session));
  }

  Future<void> update({
    bool? topmost,
    bool? sound,
    int? fps,
    double? backgroundOpacity,
    double? roadOpacity,
    double? overallOpacity,
    bool persist = true,
  }) async {
    if (!session.canMutate || isClosed) return;
    final simulation = session.simulation;
    final heroWasVisible = simulation.settings.overallOpacity > 0;
    if (topmost != null) simulation.settings.alwaysOnTop = topmost;
    if (sound != null) simulation.settings.sound = sound;
    if (backgroundOpacity != null && backgroundOpacity.isFinite) {
      simulation.settings.backgroundOpacity = backgroundOpacity.clamp(0.0, 1.0);
    }
    if (roadOpacity != null && roadOpacity.isFinite) {
      simulation.settings.roadOpacity = roadOpacity.clamp(0.0, 1.0);
    }
    if (overallOpacity != null && overallOpacity.isFinite) {
      simulation.settings.overallOpacity = overallOpacity.clamp(0.0, 1.0);
    }
    if (fps != null && [15, 30, 60].contains(fps)) {
      simulation.settings.fps = fps;
      session.game.setFps(fps);
    }
    if (topmost != null ||
        heroWasVisible != (simulation.settings.overallOpacity > 0)) {
      await overlay.configureWindow();
    } else {
      refresh();
    }
    session.refresh();
    refresh();
    if (persist) await session.save();
  }

  Future<void> save() async {
    if (!isClosed) await session.save();
  }

  Future<void> quit() async {
    if (!isClosed) await session.quit();
  }

  Future<void> reset() async {
    if (isClosed || !session.canMutate) return;
    final reset = session.resetProgress();
    refresh();
    await reset;
    refresh();
  }
}
