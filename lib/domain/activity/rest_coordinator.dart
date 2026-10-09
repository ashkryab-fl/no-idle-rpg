import 'dart:math';
import '../../content/animations/hero/rest_graphs.dart';
import '../../core/animation/graph/graph_runner.dart';
import '../../core/animation/ids.dart';
import '../../core/assets/animation_catalog.dart';
import '../../core/balance/game_balance.dart';
import 'idle_animation_definition.dart';
import 'idle_level.dart';
import 'legacy_idle_behavior.dart';
import 'rest_policy.dart';

/// Compatibility entry point. The default rest/exit path runs the typed graph;
/// custom nextAnimationId definitions retain their old adapter until stage 5.
class RestCoordinator {
  RestCoordinator(
    this.random,
    this.animations, {
    List<IdleAnimationDefinition>? definitions,
    this.thresholds = GameBalance.idleThresholds,
  }) : definitions = definitions ?? IdleAnimationCatalog.definitions,
       policy = RestPolicy(random, thresholds: thresholds) {
    if (definitions != null) {
      _legacy = LegacyIdleBehaviorSystem(
        random,
        animations,
        definitions: definitions,
        thresholds: thresholds,
      );
    }
  }
  final Random random;
  final AnimationCatalog animations;
  final List<IdleAnimationDefinition> definitions;
  final List<double> thresholds;
  final RestPolicy policy;
  LegacyIdleBehaviorSystem? _legacy;
  AnimationGraphRunner? _runner;
  IdleLevel _level = IdleLevel.active;
  double _clock = 0;
  bool _readyToTravel = true;
  List<GraphPlaybackEvent> events = const [];
  AnimationGraphRunner? get graphRunner => _runner;
  IdleLevel get level => _legacy?.level ?? _level;
  IdleLevel levelFor(double seconds) => policy.levelFor(seconds);
  double get caughtRemaining => _legacy?.caughtRemaining ?? 0;
  bool get blocksAdventure =>
      _legacy?.blocksAdventure ??
      (level != IdleLevel.active ||
          _runner?.isRunning == true ||
          !_readyToTravel);

  String? get animationId {
    if (_legacy != null) return _legacy!.animationId;
    final runner = _runner;
    if (runner == null || !runner.isRunning) return null;
    final state = runner.snapshot;
    return (state.clipId ?? HeroRestGraphs.holdClips[state.nodeId])?.value;
  }

  double get animationElapsed {
    if (_legacy != null) return _legacy!.animationElapsed;
    final runner = _runner;
    if (runner == null || !runner.isRunning) return 0;
    final state = runner.snapshot;
    if (state.clipId != null) return state.clipElapsed;
    if (state.nodeId == HeroRestGraphs.sitHold) {
      return animations.resources.clip(const ClipId('hero.sitDown')).duration +
          state.nodeElapsed;
    }
    return state.nodeElapsed;
  }

  IdleAnimationDefinition? get current {
    if (_legacy != null) return _legacy!.current;
    final id = animationId;
    return definitions.where((d) => d.id == id).firstOrNull;
  }

  void setIdleSeconds(double seconds) {
    if (_legacy != null) {
      _legacy!.setIdleSeconds(seconds);
      return;
    }
    final previous = _level;
    _level = levelFor(seconds);
    _runner?.setFacts({RestPolicy.idleLevelFact: _level.index.toDouble()});
    if (_level == IdleLevel.active) {
      _runner?.signal(GraphSignalId.activityReturned);
    } else if (_level != previous) {
      _runner?.signal(HeroRestGraphs.selectionChanged);
    }
  }

  double advance(double dt, {bool canRest = true, double? startTime}) {
    if (!dt.isFinite || dt < 0 || !(_clock + dt).isFinite) {
      throw ArgumentError.value(dt, 'dt');
    }
    if (startTime != null &&
        (!startTime.isFinite || startTime < 0 || !(startTime + dt).isFinite)) {
      throw ArgumentError.value(startTime, 'startTime');
    }
    events = const [];
    if (_legacy != null) {
      _legacy!.update(dt, canRest: canRest);
      return blocksAdventure ? 0 : dt;
    }
    final localStart = startTime ?? _clock;
    _clock = localStart + dt;
    // Track policy time while the semantic coordinator finishes an encounter.
    if (!canRest) return dt;
    if (_runner == null || !_runner!.isRunning) {
      if (_level == IdleLevel.active) return dt;
      _readyToTravel = false;
      _runner = AnimationGraphRunner(
        graph: HeroRestGraphs.seatedRest(),
        resources: animations.resources,
        selectionPolicy: policy,
        facts: {RestPolicy.idleLevelFact: _level.index.toDouble()},
        startTime: localStart,
      );
    }
    if (_level == IdleLevel.active) {
      _runner!.signal(GraphSignalId.activityReturned);
    }
    final result = _runner!.advance(dt);
    events = result.events;
    for (final completion in events.whereType<GraphCompletionEvent>()) {
      if (completion.result != GraphResultId.readyToTravel) {
        throw StateError('Unexpected rest completion: ${completion.result}');
      }
      _readyToTravel = true;
    }
    return result.remaining;
  }

  void update(double dt, {bool canRest = true}) =>
      advance(dt, canRest: canRest);

  void reset() {
    _legacy?.reset();
    _runner?.cancel();
    _runner = null;
    _level = IdleLevel.active;
    _clock = 0;
    _readyToTravel = true;
    events = const [];
    policy.reset();
  }

  /// Death/reset discard playback and pending return signals, while retaining
  /// the sampled idle level and policy cooldown history.
  void cancelPlayback() {
    _legacy?.cancelPlayback();
    _runner?.cancel();
    _runner = null;
    _readyToTravel = true;
    events = const [];
  }
}
