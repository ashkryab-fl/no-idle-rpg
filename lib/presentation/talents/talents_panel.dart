import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../core/numbers/number_formatter.dart';
import '../../domain/progression/upgrade_price.dart';
import '../../domain/talents/talents.dart';
import '../../domain/economy/reward.dart';
import '../../core/numbers/amount.dart';

class TalentsPanel extends StatelessWidget {
  const TalentsPanel({super.key, required this.controller});
  final GameController controller;
  String books(Amount value) {
    if (value.log10 >= 6) return NumberFormatter.amount(value);
    var text = value.toDouble().toStringAsFixed(6);
    while (text.endsWith('0') && text.length - text.indexOf('.') > 3) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final game = controller.simulation;
    final progress = game.character.talents;
    String percent(double value) => '${(value * 100).toStringAsFixed(2)}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${books(game.character.books)} Books'),
        const Text(
          'Buy ranks with Books, then select one talent per pair. Changes apply when the next stage attempt starts.',
          style: TextStyle(fontSize: 11, color: Colors.white70),
        ),
        Text(
          'Current attempt: ${game.activeAttempt == null ? "waiting to start" : "Stage ${game.activeAttempt!.stage}"}',
        ),
        for (final pair in TalentPair.values) ...[
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(switch (pair) {
                  TalentPair.boss => 'Boss hunting',
                  TalentPair.endurance => 'Endurance',
                  TalentPair.travel => 'Travel',
                }),
              ),
              TextButton(
                onPressed: () => controller.selectTalent(pair, null),
                child: const Text('Select none'),
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
                );
                final limit = progress.rankLimit(
                  definition,
                  game.talentProfile,
                );
                final active = game.activeAttempt?.ranks[definition.id];
                final selected =
                    progress.selectedForNextAttempt[pair] == definition.id;
                final nextValue = curve.value(
                  rank < curve.cap ? rank + 1 : rank,
                );
                final cost = UpgradePrice(
                  baseCost: curve.baseCost,
                  costGrowth: curve.costGrowth,
                ).batchCost(rank, 1);
                final remaining = game.stage > progress.highestFirstClearedStage
                    ? 3
                    : progress.repeatsRemaining(
                        game.stage,
                        game.talentProfile.stageGoldRepeatLimit,
                      );
                return Card(
                  key: ValueKey('talent_${definition.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${definition.name} · Owned $rank/${curve.cap}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          definition.description,
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          'Owned effect ${percent(curve.value(rank))} → ${percent(nextValue)}',
                        ),
                        Text(
                          'Current attempt: ${active == null ? "inactive" : "rank $active"} · Next attempt: ${selected ? "rank $rank" : "inactive"}',
                        ),
                        Text(
                          'Active effect: ${percent(game.activeAttempt?.effects[definition.id] ?? 0)} · Selected next effect: ${percent(selected ? curve.value(rank) : 0)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          rank >= limit
                              ? (quote.reason ?? '')
                              : 'Next rank: ${books(cost)} Books · available through rank $limit',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (definition.id == 'stage_gold')
                          Text(
                            'Stage ${game.stage}: $remaining eligible clears remaining${remaining == 0 ? " · reward exhausted" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final count in <int?>[1, 10, null])
                              Builder(
                                builder: (context) {
                                  final q = game.talentPurchases.quote(
                                    game.character,
                                    definition.id,
                                    count: count,
                                  );
                                  return TextButton(
                                    key: ValueKey(
                                      'buy_${definition.id}_${count ?? "max"}',
                                    ),
                                    onPressed: q.count > 0
                                        ? () => controller.purchaseTalent(
                                            definition.id,
                                            count,
                                          )
                                        : null,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          count == null ? 'MAX' : 'Buy ×$count',
                                        ),
                                        Text(
                                          '${q.count} ranks · ${books(q.cost)} Books',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            TextButton(
                              key: ValueKey('select_${definition.id}'),
                              onPressed: rank > 0 && limit > 0
                                  ? () => controller.selectTalent(
                                      pair,
                                      definition.id,
                                    )
                                  : null,
                              child: Text(selected ? 'Selected' : 'Select'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
        const Divider(),
        const Text(
          'Latest reward sources',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        if (game.lastReward == null)
          const Text('Complete a wave to receive a reward.'),
        for (final line
            in game.lastReward?.lines.entries ??
                <MapEntry<RewardSource, Amount>>[])
          Text(
            '${switch (line.key) {
              RewardSource.killGold => 'Enemy defeat',
              RewardSource.firstClearBaseGold => 'First-clear reward',
              RewardSource.firstClearBonusGold => 'First-clear talent bonus',
              RewardSource.stageBonusGold => 'Stage talent bonus',
              RewardSource.firstBooks => 'First-clear Books',
              RewardSource.repeatBooks => 'Repeat-clear Books',
              RewardSource.milestoneBooks => 'Milestone Books',
            }}: ${(line.key.index < 4 ? NumberFormatter.amount(line.value) : books(line.value))} ${line.key.index < 4 ? "Gold" : "Books"}',
          ),
      ],
    );
  }
}
