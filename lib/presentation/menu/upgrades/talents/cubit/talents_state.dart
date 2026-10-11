import '../../../../../core/numbers/amount.dart';
import '../../../../../domain/economy/reward.dart';
import '../../../../../domain/talents/talents.dart';
import '../../../../../domain/progression/purchase_quote.dart';
import '../../../../../app/session/session_cubit.dart';

class TalentItemState {
  const TalentItemState({
    required this.definition,
    required this.rank,
    required this.cap,
    required this.limit,
    required this.selected,
    required this.quote,
    this.activeRank,
    this.activeEffect,
  });
  final TalentDefinition definition;
  final int rank, cap, limit;
  final bool selected;
  final int? activeRank;
  final double? activeEffect;
  final PurchaseQuote<double> quote;
}

class TalentsState {
  TalentsState.fromSession(
    SessionCubit session,
    this.count, {
    this.rewardsExpanded = false,
  }) : books = session.simulation.character.books,
       stage = session.simulation.stage,
       selected = Map.unmodifiable(
         session.simulation.character.talents.selectedForNextAttempt,
       ),
       remaining =
           session.simulation.stage >
               session.simulation.character.talents.highestFirstClearedStage
           ? 1 + session.simulation.talentProfile.stageGoldRepeatLimit
           : session.simulation.character.talents.repeatsRemaining(
               session.simulation.stage,
               session.simulation.talentProfile.stageGoldRepeatLimit,
             ),
       rewards = Map.unmodifiable(
         session.simulation.lastReward?.lines ?? <RewardSource, Amount>{},
       ),
       items = List.unmodifiable([
         for (final d in TalentCatalog.items)
           TalentItemState(
             definition: d,
             rank: session.simulation.character.talents.ownedRanks[d.id] ?? 0,
             cap: session.simulation.talentProfile.curves[d.id]!.cap,
             limit: session.simulation.character.talents.rankLimit(
               d,
               session.simulation.talentProfile,
             ),
             selected:
                 session.simulation.character.talents.selectedForNextAttempt[d
                     .pair] ==
                 d.id,
             activeRank: session.simulation.activeAttempt?.ranks[d.id],
             activeEffect: session.simulation.activeAttempt?.effects[d.id],
             quote: session.simulation.talentPurchases.quote(
               session.simulation.character,
               d.id,
               count: count,
             ),
           ),
       ]);
  final int? count;
  final Amount books;
  final int stage, remaining;
  final Map<TalentPair, String> selected;
  final List<TalentItemState> items;
  final Map<RewardSource, Amount> rewards;
  final bool rewardsExpanded;
}
