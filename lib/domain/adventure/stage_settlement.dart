import '../../core/balance/talent_profile.dart';
import '../../core/numbers/amount.dart';
import '../character/character.dart';
import '../economy/reward.dart';
import 'stage_attempt.dart';

class SettlementResult {
  const SettlementResult(this.applied, this.reward, this.hp, this.healed);
  final bool applied;
  final Reward reward;
  final Amount hp, healed;
}

/// Wallet, claims and settlement cursor mutate synchronously as one checkpoint.
class StageSettlement {
  const StageSettlement({this.profile = TalentProfile.candidate});
  final TalentProfile profile;
  SettlementResult settle(
    CharacterProgress hero,
    StageAttempt attempt,
    int wave, {
    required Amount hp,
    required Amount maxHp,
    double killMultiplier = 1,
  }) {
    if (wave < 1 ||
        wave > 5 ||
        !killMultiplier.isFinite ||
        killMultiplier < 0 ||
        attempt.id >= hero.talents.nextAttemptId ||
        attempt.profileId != profile.id) {
      throw ArgumentError('Invalid settlement');
    }
    final ledger = hero.talents;
    if (attempt.id < ledger.lastSettledAttempt ||
        (attempt.id == ledger.lastSettledAttempt &&
            wave <= ledger.lastSettledWave)) {
      return SettlementResult(false, Reward.fromLines({}), hp, Amount.zero);
    }
    final expected = attempt.id == ledger.lastSettledAttempt
        ? ledger.lastSettledWave + 1
        : 1;
    if (wave != expected || hp.isZero) {
      throw StateError('Out-of-order or dead settlement');
    }
    final lines = <RewardSource, Amount>{
      RewardSource.killGold: attempt.encounters[wave - 1].gold.scale(
        killMultiplier,
      ),
    };
    var restored = Amount.zero;
    if (wave == 5) {
      final first = attempt.stage > ledger.highestFirstClearedStage;
      if (first && attempt.stage != ledger.highestFirstClearedStage + 1) {
        throw StateError('First clears must be sequential');
      }
      final repeats = ledger.usedRepeats[attempt.stage] ?? 0;
      if (first) {
        final firstBase = attempt.encounters.last.gold.scale(
          profile.firstClearGoldBaseMultiplier,
        );
        lines[RewardSource.firstClearBaseGold] = firstBase;
        lines[RewardSource.firstClearBonusGold] = firstBase.scale(
          attempt.effects['first_clear_gold'],
        );
        lines[RewardSource.firstBooks] = Amount.fromNum(profile.firstBooks);
        if (attempt.stage == 5 ||
            attempt.stage == 10 ||
            attempt.stage % 20 == 0) {
          lines[RewardSource.milestoneBooks] = Amount.fromNum(
            profile.milestoneBooks,
          );
        }
      } else if (repeats < profile.repeatLimit) {
        lines[RewardSource.repeatBooks] = Amount.fromNum(profile.repeatBooks);
      }
      if (first || repeats < profile.stageGoldRepeatLimit) {
        lines[RewardSource.stageBonusGold] = attempt.nominalGold.scale(
          attempt.effects['stage_gold'],
        );
      }
      final possible = maxHp.scale(attempt.effects['stage_heal']);
      final missing = maxHp - hp;
      restored = possible < missing ? possible : missing;
      if (first) {
        ledger.highestFirstClearedStage = attempt.stage;
      } else {
        final cap = profile.repeatLimit > profile.stageGoldRepeatLimit
            ? profile.repeatLimit
            : profile.stageGoldRepeatLimit;
        if (repeats < cap) ledger.usedRepeats[attempt.stage] = repeats + 1;
      }
    }
    final reward = Reward.fromLines(lines);
    hero.gold = hero.gold + reward.gold;
    hero.books = hero.books + reward.books;
    ledger.lastSettledAttempt = attempt.id;
    ledger.lastSettledWave = wave;
    return SettlementResult(true, reward, hp + restored, restored);
  }
}
