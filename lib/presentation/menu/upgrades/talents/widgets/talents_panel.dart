import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/talents_cubit.dart';
import '../../../../../core/numbers/amount.dart';
import '../../../../../core/numbers/number_formatter.dart';
import '../../../../../domain/economy/reward.dart';
import '../../../../../domain/talents/talents.dart';

class TalentsPanel extends StatelessWidget {
  const TalentsPanel({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.read<GetIt>()<TalentsCubit>(),
    child: const _TalentsView(),
  );
}

class _TalentsView extends StatelessWidget {
  const _TalentsView();
  String books(Amount value) => NumberFormatter.price(value);
  String percent(double value) => '${NumberFormatter.decimal(value * 100)}%';

  @override
  Widget build(BuildContext context) => BlocBuilder<TalentsCubit, TalentsState>(
    builder: (context, state) {
      final cubit = context.read<TalentsCubit>();
      final count = state.count;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${books(state.books)} Books',
            style: const TextStyle(color: Color(0xffffd58a)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose one talent per pair. Changes apply next attempt.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('×1')),
              ButtonSegment(value: 10, label: Text('×10')),
              ButtonSegment(value: 0, label: Text('MAX')),
            ],
            selected: {count ?? 0},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => cubit.selectCount(
              selection.first == 0 ? null : selection.first,
            ),
          ),
          for (final pair in TalentPair.values) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(switch (pair) {
                    TalentPair.boss => 'Boss hunting',
                    TalentPair.endurance => 'Endurance',
                    TalentPair.travel => 'Travel',
                  }, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: state.selected[pair] != null
                      ? () => cubit.select(pair, null)
                      : null,
                  child: const Text('Clear'),
                ),
              ],
            ),
            for (final item in state.items.where(
              (item) => item.definition.pair == pair,
            ))
              Builder(
                builder: (context) {
                  final definition = item.definition;
                  final rank = item.rank;
                  final quote = item.quote;
                  final limit = item.limit;
                  final active = item.activeRank;
                  final selected = item.selected;
                  final remaining = state.remaining;
                  final description = switch (definition.id) {
                    'boss_damage' => 'Extra damage against bosses.',
                    'first_clear_gold' =>
                      'Bonus Gold on the first clear of a stage.',
                    'stage_heal' => 'Heal after a stage; cannot revive.',
                    'crit_protection' => 'Less bonus damage from enemy crits.',
                    'shorter_travel' => 'Less travel time between enemies.',
                    'stage_gold' =>
                      'Bonus Gold for a limited number of stage clears.',
                    _ => definition.description,
                  };
                  return Card(
                    key: ValueKey('talent_${definition.id}'),
                    color: const Color(0x88232c3d),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  definition.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$rank/${item.cap}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Tooltip(
                            message: definition.description,
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                          if (limit > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              quote.canPurchase
                                  ? 'Bonus: ${percent(quote.before)} → ${percent(quote.after)}'
                                  : 'Bonus: ${percent(quote.before)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff9bdfcc),
                              ),
                            ),
                          ],
                          if (active != null && active > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              active == rank
                                  ? 'Active this stage'
                                  : 'Active this stage: ${percent(item.activeEffect!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xff9bdfcc),
                              ),
                            ),
                          ],
                          if (definition.id == 'stage_gold' && limit > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              remaining == 0
                                  ? 'Stage ${state.stage}: bonus used up'
                                  : 'Stage ${state.stage}: $remaining rewarded clears left',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                          if (quote.blockedReason != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              quote.blockedReason!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                          if (limit > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (rank < limit)
                                  Expanded(
                                    child: FilledButton.tonal(
                                      key: ValueKey(
                                        'buy_${definition.id}_${count ?? "max"}',
                                      ),
                                      onPressed: quote.canPurchase
                                          ? () => cubit.purchase(definition.id)
                                          : null,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            quote.canPurchase
                                                ? 'Buy +${quote.count}'
                                                : 'Buy +1',
                                          ),
                                          Text(
                                            '${books(quote.canPurchase ? quote.cost : quote.nextCost)} Books',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  const Spacer(),
                                const SizedBox(width: 8),
                                TextButton(
                                  key: ValueKey('select_${definition.id}'),
                                  onPressed: rank > 0 && !selected
                                      ? () => cubit.select(pair, definition.id)
                                      : null,
                                  child: Text(
                                    selected ? 'Selected' : 'Select',
                                    style: selected
                                        ? const TextStyle(
                                            color: Color(0xff9bdfcc),
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
          if (state.rewards.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: state.rewardsExpanded,
              onExpansionChanged: cubit.setRewardsExpanded,
              title: const Text('Last rewards', style: TextStyle(fontSize: 12)),
              children: [
                for (final line in state.rewards.entries)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${switch (line.key) {
                        RewardSource.killGold => 'Enemy defeat',
                        RewardSource.firstClearBaseGold => 'First-clear reward',
                        RewardSource.firstClearBonusGold => 'First-clear bonus',
                        RewardSource.stageBonusGold => 'Stage bonus',
                        RewardSource.firstBooks => 'First-clear Books',
                        RewardSource.repeatBooks => 'Repeat-clear Books',
                        RewardSource.milestoneBooks => 'Milestone Books',
                      }}: ${line.key.index < 4 ? NumberFormatter.amount(line.value) : books(line.value)} ${line.key.index < 4 ? "Gold" : "Books"}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}
