import '../../../core/numbers/amount.dart';
import '../../../app/session/session_cubit.dart';

enum OverlayPanel {
  menu,
  statistics,
  equipment,
  talents,
  settings,
  debug;

  String get title => switch (this) {
    menu => 'Idle Companion',
    statistics => 'Statistics',
    equipment => 'Equipment',
    talents => 'Talents',
    settings => 'Settings',
    debug => 'Debug Tools',
  };
}

class CompanionOverlayState {
  CompanionOverlayState.fromSession(SessionCubit session, this.panel)
    : error = session.state.error,
      notice = session.state.notice,
      overallOpacity = session.simulation.settings.overallOpacity,
      backgroundOpacity = session.simulation.settings.backgroundOpacity,
      heroHp = session.simulation.heroHp,
      maxHp = session.simulation.stats.maxHp,
      stage = session.simulation.stage,
      wave = session.simulation.wave;
  final OverlayPanel? panel;
  final String? error, notice;
  final double overallOpacity, backgroundOpacity;
  final Amount heroHp, maxHp;
  final int stage, wave;
}
