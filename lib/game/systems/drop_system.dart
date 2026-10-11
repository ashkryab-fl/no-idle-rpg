import '../../domain/economy/reward.dart';
import 'enemy_spawner.dart';

/// Individual enemies pay Gold only. Books belong to stage settlement.
abstract final class DropSystem {
  static Reward killReward(Enemy enemy, {double multiplier = 1}) =>
      Reward.fromLines({RewardSource.killGold: enemy.gold.scale(multiplier)});
}
