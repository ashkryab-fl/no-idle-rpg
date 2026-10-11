import '../../core/numbers/amount.dart';
import '../economy/reward.dart';
import 'stage_attempt.dart';

class AdventureCheckpoint {
  const AdventureCheckpoint({
    required this.hp,
    this.attempt,
    this.phase = 'traveling',
    this.elapsed = 0,
    this.travelRemaining = 0,
    this.needsTravelTarget = true,
    this.lastReward,
  });
  final Amount hp;
  final StageAttempt? attempt;
  final String phase;
  final double elapsed, travelRemaining;
  final bool needsTravelTarget;
  final Reward? lastReward;
  Map<String, Object?> toJson() => {
    'hp': hp.toJson(),
    'attempt': attempt?.toJson(),
    'phase': phase,
    'elapsed': elapsed,
    'travelRemaining': travelRemaining,
    'needsTravelTarget': needsTravelTarget,
    'lastReward': lastReward?.toJson(),
  };
  factory AdventureCheckpoint.fromJson(Map<String, dynamic> json) {
    final elapsed = (json['elapsed'] as num).toDouble();
    final remaining = (json['travelRemaining'] as num).toDouble();
    final phase = json['phase'] as String;
    if (!elapsed.isFinite ||
        elapsed < 0 ||
        !remaining.isFinite ||
        remaining < 0 ||
        remaining > 160 ||
        !const [
          'traveling',
          'enemyApproach',
          'combat',
          'enemyDeath',
          'reward',
          'heroDeath',
          'respawn',
        ].contains(phase)) {
      throw const FormatException('Invalid adventure checkpoint');
    }
    return AdventureCheckpoint(
      hp: Amount.fromJson(json['hp']),
      attempt: json['attempt'] == null
          ? null
          : StageAttempt.fromJson(
              Map<String, dynamic>.from(json['attempt'] as Map),
            ),
      phase: phase,
      elapsed: elapsed,
      travelRemaining: remaining,
      needsTravelTarget: json['needsTravelTarget'] as bool,
      lastReward: json['lastReward'] == null
          ? null
          : Reward.fromJson(
              Map<String, dynamic>.from(json['lastReward'] as Map),
            ),
    );
  }
}
