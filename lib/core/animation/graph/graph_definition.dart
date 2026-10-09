import '../ids.dart';
import 'node.dart';

final class AnimationGraphDefinition {
  AnimationGraphDefinition({
    required this.id,
    required this.entryNode,
    required Iterable<AnimationGraphNode> nodes,
  }) : nodes = _index(nodes) {
    validateAnimationId(id.value);
    validateAnimationId(entryNode.value);
  }
  final GraphId id;
  final NodeId entryNode;
  final Map<NodeId, AnimationGraphNode> nodes;
  AnimationGraphNode node(NodeId id) =>
      nodes[id] ??
      (throw ArgumentError('Unknown node $id in graph ${this.id}'));

  static Map<NodeId, AnimationGraphNode> _index(
    Iterable<AnimationGraphNode> nodes,
  ) {
    final result = <NodeId, AnimationGraphNode>{};
    for (final node in nodes) {
      validateAnimationId(node.id.value);
      if (result.containsKey(node.id)) {
        throw ArgumentError('Duplicate graph node: ${node.id}');
      }
      result[node.id] = node;
    }
    return Map.unmodifiable(result);
  }
}
