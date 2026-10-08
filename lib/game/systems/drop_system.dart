import 'dart:math';
import '../../core/numbers/amount.dart';
import '../../domain/economy/reward.dart';
import 'enemy_spawner.dart';

class DropSystem {
  DropSystem(this.random);
  final Random random;
  Reward roll(Enemy enemy, {double multiplier = 1}) => Reward(
    gold: enemy.gold.scale(multiplier),
    books: random.nextDouble() < enemy.definition.rewardBookChance
        ? Amount.fromNum(multiplier)
        : Amount.zero,
    xp: enemy.xp,
  );
}
