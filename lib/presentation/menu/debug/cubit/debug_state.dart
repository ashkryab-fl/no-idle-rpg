import '../../../../app/session/session_cubit.dart';
import '../../../../content/animations/hero/debug_previews.dart';

class DebugState {
  DebugState.fromSession(SessionCubit session)
    : idleOverride = session.activityOverride,
      animation = session.simulation.heroAnimations.preview,
      canWakeAnimation = session.simulation.heroAnimations.canWakePreview,
      speed = session.simulation.speed,
      details =
          'State: ${session.simulation.phase.name}\nIdle: ${session.simulation.idle.level.name}\nAnimation: ${session.simulation.heroPlayback.displayLabel}\n'
          'Frame: ${session.simulation.heroPlayback.frameId}\n'
          'Graph/node: ${session.simulation.heroPlayback.graphId} / ${session.simulation.heroPlayback.nodeId}\n'
          'Local time: ${session.simulation.heroPlayback.elapsed.toStringAsFixed(3)} s\n'
          'Transition: ${session.simulation.heroPlayback.lastTransition?.reason.name ?? '-'}\n'
          'Generation: ${session.simulation.heroPlayback.generation}';
  final double? idleOverride;
  final HeroAnimationPreview? animation;
  final bool canWakeAnimation;
  final double speed;
  final String details;
}
