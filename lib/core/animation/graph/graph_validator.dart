import '../animation_clip.dart';
import '../animation_resources.dart';
import '../ids.dart';
import 'graph_definition.dart';
import 'node.dart';
import 'transition.dart';

final class AnimationGraphValidator {
  const AnimationGraphValidator(this.resources);
  final AnimationResources resources;

  void validate(AnimationGraphDefinition graph) {
    graph.node(graph.entryNode);
    final variants = <VariantId>{};
    for (final node in graph.nodes.values) {
      switch (node) {
        case PlayClip():
          final clip = resources.clip(node.clipId);
          final duration = clip.loopRange == null
              ? clip.duration * node.repetitions
              : clip.firstPassDuration +
                    clip.loopDuration * (node.repetitions - 1);
          if (node.repetitions < 1 || !duration.isFinite) {
            throw ArgumentError('Invalid repetitions: ${node.id}');
          }
        case LoopClip():
          final clip = resources.clip(node.clipId);
          if (clip.loopRange == null ||
              node.interruption == InterruptionPolicy.afterClip) {
            throw ArgumentError('Invalid indefinite loop: ${node.id}');
          }
          if (node.interruptibleFrames.isNotEmpty &&
              (node.interruption != InterruptionPolicy.afterCycle ||
                  node.interruptibleFrames.any(
                    (index) => index < 0 || index >= clip.loopRange!.end,
                  ))) {
            throw ArgumentError('Invalid interruption frames: ${node.id}');
          }
        case HoldPose():
          resources.pose(node.poseId);
          if ((node.duration != null &&
                  (!node.duration!.isFinite || node.duration! <= 0)) ||
              node.interruption == InterruptionPolicy.afterCycle ||
              (node.duration == null &&
                  node.interruption == InterruptionPolicy.afterClip)) {
            throw ArgumentError('Invalid hold: ${node.id}');
          }
        case Select():
          final fallback = graph.node(node.fallback);
          if (fallback is! HoldPose || fallback.duration != null) {
            throw ArgumentError('Selection needs a waiting pose: ${node.id}');
          }
          var totalWeight = 0.0;
          for (final choice in node.choices) {
            validateAnimationId(choice.id.value);
            graph.node(choice.target);
            graph.node(choice.completionNode);
            final reachable = <NodeId>{};
            _visit(graph, choice.target, reachable);
            if (!reachable.contains(choice.completionNode)) {
              throw ArgumentError(
                'Unreachable variant completion: ${choice.id}',
              );
            }
            totalWeight += choice.weight;
            if (!variants.add(choice.id) ||
                !choice.weight.isFinite ||
                choice.weight <= 0 ||
                !totalWeight.isFinite) {
              throw ArgumentError('Invalid graph choice: ${choice.id}');
            }
            for (final condition in choice.conditions) {
              condition.validate();
            }
            final cooldown = choice.cooldown;
            if (cooldown != null) {
              validateAnimationId(cooldown.key.value);
              if (!cooldown.seconds.isFinite || cooldown.seconds < 0) {
                throw ArgumentError('Invalid variant cooldown: ${choice.id}');
              }
            }
          }
        case Finish():
          validateAnimationId(node.result.value);
          _validateContract(node.entryPose);
      }
      for (final edge in node.transitions) {
        graph.node(edge.target);
        for (final condition in edge.conditions) {
          condition.validate();
        }
        switch (edge.trigger) {
          case Completed():
            if (node is! PlayClip &&
                !(node is HoldPose && node.duration != null)) {
              throw ArgumentError('Node cannot complete: ${node.id}');
            }
          case Elapsed(:final seconds):
            if (!seconds.isFinite ||
                seconds <= 0 ||
                node is Select ||
                node is Finish) {
              throw ArgumentError('Invalid elapsed trigger: ${node.id}');
            }
          case Signal(:final id):
            validateAnimationId(id.value);
          case ActivityReturned():
            break;
        }
      }
    }
    final reached = <NodeId>{};
    _visit(graph, graph.entryNode, reached);
    if (reached.length != graph.nodes.length) {
      throw ArgumentError(
        'Unreachable graph nodes: '
        '${graph.nodes.keys.where((id) => !reached.contains(id)).join(', ')}',
      );
    }

    // Only Select edges run unconditionally without consuming time/signals.
    // Positive-duration clips/holds and signal-driven cycles are allowed.
    final checked = <NodeId>{};
    void instantVisit(NodeId id, Set<NodeId> path) {
      if (path.contains(id)) {
        throw ArgumentError('Zero-time graph cycle at $id');
      }
      if (!checked.add(id)) return;
      final node = graph.node(id);
      if (node is Select) {
        path.add(id);
        for (final next in [
          node.fallback,
          ...node.choices.map((c) => c.target),
        ]) {
          instantVisit(next, path);
        }
        path.remove(id);
      }
    }

    for (final id in graph.nodes.keys) {
      instantVisit(id, <NodeId>{});
    }

    // Select is transparent to pose contracts. Check every possible branch,
    // including fallback, without guessing a root from incoming edges.
    for (final node in graph.nodes.values) {
      final exit = _exitPose(node);
      if (exit == null) continue;
      void checkTarget(NodeId target, Set<NodeId> visited) {
        if (!visited.add(target)) return;
        final next = graph.node(target);
        if (next is Select) {
          for (final id in _targets(next)) {
            checkTarget(id, visited);
          }
        } else {
          final entry = _entryPose(next);
          if (entry != null && !_compatible(exit, entry)) {
            throw ArgumentError('Incompatible poses: ${node.id} -> $target');
          }
        }
      }

      for (final target in _targets(node)) {
        checkTarget(target, <NodeId>{});
      }
    }
  }

  Iterable<NodeId> _targets(AnimationGraphNode node) sync* {
    yield* node.transitions.map((edge) => edge.target);
    if (node is Select) {
      yield node.fallback;
      yield* node.choices.map((choice) => choice.target);
    }
  }

  void _visit(AnimationGraphDefinition graph, NodeId id, Set<NodeId> seen) {
    if (!seen.add(id)) return;
    for (final next in _targets(graph.node(id))) {
      _visit(graph, next, seen);
    }
  }

  AnimationPoseContract? _entryPose(AnimationGraphNode node) => switch (node) {
    PlayClip() => resources.clip(node.clipId).entryPose,
    LoopClip() => resources.clip(node.clipId).entryPose,
    HoldPose() => AnimationPoseContract.pose(node.poseId),
    Finish() => node.entryPose,
    Select() => null,
  };
  AnimationPoseContract? _exitPose(AnimationGraphNode node) => switch (node) {
    PlayClip() => resources.clip(node.clipId).exitPose,
    LoopClip() => resources.clip(node.clipId).exitPose,
    HoldPose() => AnimationPoseContract.pose(node.poseId),
    _ => null,
  };
  void _validateContract(AnimationPoseContract? contract) {
    if (contract?.pose != null) resources.pose(contract!.pose!);
    if (contract?.family != null) validateAnimationId(contract!.family!.value);
  }

  bool _compatible(AnimationPoseContract exit, AnimationPoseContract entry) {
    if (exit.pose != null && entry.pose != null) return exit.pose == entry.pose;
    final from = exit.family ?? resources.pose(exit.pose!).family;
    final to = entry.family ?? resources.pose(entry.pose!).family;
    return from == to;
  }
}
