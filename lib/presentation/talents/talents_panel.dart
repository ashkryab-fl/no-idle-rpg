import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../core/numbers/amount.dart';
import '../../core/numbers/number_formatter.dart';
import '../../domain/economy/reward.dart';
import '../../domain/talents/talents.dart';

class TalentsPanel extends StatefulWidget {
  const TalentsPanel({super.key, required this.controller});
  final GameController controller;

  @override
  State<TalentsPanel> createState() => _TalentsPanelState();
}

class _TalentsPanelState extends State<TalentsPanel> {
  int? count = 1;

  String books(Amount value) => NumberFormatter.price(value);
  String percent(double value) => '${NumberFormatter.decimal(value * 100)}%';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final game = controller.simulation;
    final progress = game.character.talents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${books(game.character.books)} Books',
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
          onSelectionChanged: (selection) => setState(
            () => count = selection.first == 0 ? null : selection.first,
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
                onPressed: progress.selectedForNextAttempt[pair] != null
                    ? () => controller.selectTalent(pair, null)
                    : null,
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final definition in TalentCatalog.items.where(
            (d) => d.pair == pair,
          ))
            Builder(
              builder: (context) {
                final rank = progress.ownedRanks[definition.id] ?? 0;
                final curve = game.talentProfile.curves[definition.id]!;
                final quote = game.talentPurchases.quote(
                  game.character,
                  definition.id,
                  count: count,
                );
                final limit = progress.rankLimit(
                  definition,
                  game.talentProfile,
                );
                final active = game.activeAttempt?.ranks[definition.id];
                final selected =
                    progress.selectedForNextAttempt[pair] == definition.id;
                final remaining = game.stage > progress.highestFirstClearedStage
                    ? 1 + game.talentProfile.stageGoldRepeatLimit
                    : progress.repeatsRemaining(
                        game.stage,
                        game.talentProfile.stageGoldRepeatLimit,
                      );
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
                              '$rank/${curve.cap}',
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
                                : 'Active this stage: ${percent(game.activeAttempt!.effects[definition.id])}',
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
                                ? 'Stage ${game.stage}: bonus used up'
                                : 'Stage ${game.stage}: $remaining rewarded clears left',
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
                                        ? () => controller.purchaseTalent(
                                            definition.id,
                                            count,
                                          )
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
                                          style: const TextStyle(fontSize: 11),
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
                                    ? () => controller.selectTalent(
                                        pair,
                                        definition.id,
                                      )
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
        if (game.lastReward != null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Last rewards', style: TextStyle(fontSize: 12)),
            children: [
              for (final line in game.lastReward!.lines.entries)
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
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
