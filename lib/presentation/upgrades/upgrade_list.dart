import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../core/balance/progression_balance.dart';
import '../../core/numbers/amount.dart';
import '../../core/numbers/number_formatter.dart';
import '../../domain/character/character.dart';
import '../../domain/progression/infinite_upgrade.dart';

class UpgradeList extends StatefulWidget {
  const UpgradeList({
    super.key,
    required this.controller,
    required this.definitions,
    required this.equipment,
  });
  final GameController controller;
  final List<InfiniteUpgradeDefinition> definitions;
  final bool equipment;
  @override
  State<UpgradeList> createState() => _UpgradeListState();
}

class _UpgradeListState extends State<UpgradeList> {
  int? count = 1;
  @override
  Widget build(BuildContext context) {
    final game = widget.controller.simulation;
    final wallet = widget.equipment
        ? game.character.gold
        : game.character.books;
    final levels = widget.equipment
        ? game.character.equipment
        : game.character.upgrades;
    final stats = game.stats;
    String preciseAmount(Amount value) => value.log10 < 3
        ? value.toDouble().toStringAsFixed(2)
        : NumberFormatter.amount(value);
    String statValue(CharacterStat stat, CombatStats values) => switch (stat) {
      CharacterStat.damage => preciseAmount(values.damage),
      CharacterStat.maxHp => preciseAmount(values.maxHp),
      CharacterStat.critChance =>
        '${(values.critChance * 100).toStringAsFixed(2)}%',
      CharacterStat.critDamage => '${values.critDamage.toStringAsFixed(2)}×',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.equipment ? 'Gold' : 'Knowledge Books'}  ${NumberFormatter.amount(wallet)}',
          style: const TextStyle(color: Color(0xffffd58a)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Stats: now → after selected purchase',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('x1')),
            ButtonSegment(value: 10, label: Text('x10')),
            ButtonSegment(value: 0, label: Text('MAX')),
          ],
          selected: {count ?? 0},
          onSelectionChanged: (v) =>
              setState(() => count = v.first == 0 ? null : v.first),
        ),
        const SizedBox(height: 12),
        for (final definition in widget.definitions)
          Builder(
            builder: (context) {
              final level = levels[definition.id] ?? 0;
              final affordable = definition.affordable(level, wallet);
              final buying = count == null
                  ? affordable
                  : count!.clamp(0, affordable);
              final effect = definition.effect(level);
              final statLabel = switch (definition.stat) {
                CharacterStat.damage => 'Damage',
                CharacterStat.maxHp => 'Max HP',
                CharacterStat.critChance => 'Crit chance',
                CharacterStat.critDamage => 'Crit damage',
              };
              final source = widget.equipment ? 'equipment' : 'upgrade';
              final effectText = switch (definition.curve) {
                UpgradeCurve.exponential =>
                  'Total $source bonus: +${preciseAmount(effect.percentageBonus)}% ${statLabel.toLowerCase()}',
                UpgradeCurve.additive => switch (definition.stat) {
                  CharacterStat.critChance =>
                    'Total $source bonus: +${(effect.additive * 100).toStringAsFixed(1)} percentage points crit chance. Limit: ${(ProgressionBalance.critChanceCap * 100).toStringAsFixed(0)}%.',
                  CharacterStat.critDamage =>
                    'Total $source bonus: +${effect.additive.toStringAsFixed(2)}× crit damage',
                  _ =>
                    'Total $source bonus: +${effect.additive.toStringAsFixed(2)} ${statLabel.toLowerCase()}',
                },
                UpgradeCurve.softCap => switch (definition.stat) {
                  CharacterStat.critChance =>
                    'Limit: ${(ProgressionBalance.critChanceCap * 100).toStringAsFixed(0)}%. Gains decrease near the limit.',
                  _ => 'Gains decrease near the stat limit.',
                },
              };
              final current = statValue(definition.stat, stats);
              var statText = '$statLabel: $current';
              if (buying > 0) {
                final preview = CharacterProgress()
                  ..level = game.character.level
                  ..upgrades.addAll(game.character.upgrades)
                  ..equipment.addAll(game.character.equipment);
                final previewLevels = widget.equipment
                    ? preview.equipment
                    : preview.upgrades;
                previewLevels[definition.id] = level + buying;
                final after = statValue(
                  definition.stat,
                  CharacterStats.calculate(preview),
                );
                statText += ' → $after (after +$buying)';
              }
              return Card(
                color: const Color(0x88232c3d),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          Text('Lv $level'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff9bdfcc),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        effectText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: buying > 0
                              ? () => widget.controller.upgrade(
                                  definition,
                                  widget.equipment,
                                  count,
                                )
                              : null,
                          child: Text(
                            buying > 0
                                ? 'Upgrade +$buying · ${NumberFormatter.amount(definition.batchCost(level, buying))}'
                                : 'Upgrade · ${NumberFormatter.amount(definition.cost(level))}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
