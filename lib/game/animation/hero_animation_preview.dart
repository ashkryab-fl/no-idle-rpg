import '../../content/animations/hero/debug_previews.dart';
import '../../core/animation/animation_player.dart';
import '../../core/animation/animation_resources.dart';
import '../../core/animation/graph/graph_runner.dart';
import '../../core/animation/graph/selection_policy.dart';
import '../../core/animation/ids.dart';
import '../../core/animation/playback_snapshot.dart';

/// Independent playback leaves the paused game's clocks and rest RNG intact.
final class HeroAnimationPreviewPlayback {
  HeroAnimationPreviewPlayback(this.selection, this.resources) {
    final clip = selection.clipId;
    if (clip != null) {
      _player = AnimationPlayer(resources.clip(clip));
    } else {
      _graph = AnimationGraphRunner(
        graph: selection.graph(resources),
        resources: resources,
        selectionPolicy: const _PreviewSelectionPolicy(),
      );
      _graph!.advance(0);
    }
  }

  final HeroAnimationPreview selection;
  final AnimationResources resources;
  AnimationPlayer? _player;
  AnimationGraphRunner? _graph;
  bool _returnRequested = false;
  bool get canWake => _graph?.isRunning == true && !_returnRequested;

  void advance(double dt) {
    _player?.advance(dt);
    _graph?.advance(dt);
  }

  void wake() {
    if (!canWake) return;
    _returnRequested = true;
    _graph!.signal(GraphSignalId.activityReturned);
    _graph!.advance(0);
  }

  PlaybackSnapshot snapshot(int generation) {
    final graph = _graph;
    if (graph != null) {
      return PlaybackSnapshot.graph(
        graph.snapshot,
        resources,
        generation: generation,
        displayLabel: 'Preview: ${selection.label}',
      );
    }
    return PlaybackSnapshot.clip(
      _player!.snapshot,
      resources,
      generation: generation,
      displayLabel: 'Preview: ${selection.label}',
    );
  }
}

final class _PreviewSelectionPolicy implements GraphSelectionPolicy {
  const _PreviewSelectionPolicy();
  @override
  GraphChoice? choose(
    List<GraphChoice> choices,
    Map<GraphFactId, double> facts,
    double clock,
  ) {
    for (final choice in choices) {
      if (choice.conditions.every((condition) => condition.matches(facts))) {
        return choice;
      }
    }
    return null;
  }

  @override
  void started(GraphChoice choice, double clock) {}
  @override
  void completed(GraphChoice choice, double clock) {}
}
