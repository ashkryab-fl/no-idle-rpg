import 'dart:math';
import '../../core/animation/graph/selection_policy.dart';

final class WeightedVariantSelector {
  const WeightedVariantSelector(this.random);
  final Random random;
  GraphChoice? choose(List<GraphChoice> eligible) {
    if (eligible.isEmpty) return null;
    final total = eligible.fold<double>(0, (sum, c) => sum + c.weight);
    if (!total.isFinite || total <= 0) {
      throw ArgumentError('Invalid selection weight');
    }
    var roll = random.nextDouble() * total;
    for (final choice in eligible) {
      roll -= choice.weight;
      if (roll < 0) return choice;
    }
    return eligible.last;
  }
}
