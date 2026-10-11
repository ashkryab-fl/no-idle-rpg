import '../../../../app/session/session_cubit.dart';

class SettingsState {
  SettingsState.fromSession(SessionCubit session)
    : alwaysOnTop = session.simulation.settings.alwaysOnTop,
      sound = session.simulation.settings.sound,
      fps = session.simulation.settings.fps,
      backgroundOpacity = session.simulation.settings.backgroundOpacity,
      roadOpacity = session.simulation.settings.roadOpacity,
      overallOpacity = session.simulation.settings.overallOpacity,
      busy = !session.canMutate;
  final bool alwaysOnTop, sound, busy;
  final int fps;
  final double backgroundOpacity, roadOpacity, overallOpacity;
}
