import '../ids.dart';
import 'transition.dart';

enum CooldownStart { started, completed }

final class VariantCooldown {
  const VariantCooldown(
    this.key,
    this.seconds, {
    this.start = CooldownStart.started,
  });
  final CooldownKey key;
  final double seconds;
  final CooldownStart start;
}

/// Variant identity and cooldown scope are independent of clip/node identity.
final class GraphChoice {
  GraphChoice({
    required this.id,
    required this.target,
    this.weight = 1,
    List<GraphCondition> conditions = const [],
    this.cooldown,
    NodeId? completionNode,
  }) : conditions = List.unmodifiable(conditions),
       completionNode = completionNode ?? target;
  final VariantId id;
  final NodeId target, completionNode;
  final double weight;
  final List<GraphCondition> conditions;
  final VariantCooldown? cooldown;
}

abstract class GraphSelectionPolicy {
  GraphChoice? choose(
    List<GraphChoice> choices,
    Map<GraphFactId, double> facts,
    double clock,
  );
  void started(GraphChoice choice, double clock);

  /// Called when the declared completion node exits (including interruption),
  /// or is entered if it is Finish. Cleanup chains can name their last node.
  void completed(GraphChoice choice, double clock);
}
