import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../core/numbers/number_formatter.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.equipment ? 'Gold' : 'Knowledge Books'}  ${NumberFormatter.amount(wallet)}',
          style: const TextStyle(color: Color(0xffffd58a)),
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
              final effectText = switch (definition.curve) {
                UpgradeCurve.exponential =>
                  '+${NumberFormatter.amount(effect.percentageBonus)}%',
                UpgradeCurve.additive =>
                  '+${effect.additive.toStringAsFixed(2)}×',
                UpgradeCurve.softCap =>
                  '${effect.capProgressPercent.toStringAsFixed(1)}% toward stat cap',
              };
              final current = switch (definition.stat) {
                CharacterStat.damage => NumberFormatter.amount(stats.damage),
                CharacterStat.maxHp => NumberFormatter.amount(stats.maxHp),
                CharacterStat.attackSpeed =>
                  '${stats.attackSpeed.toStringAsFixed(2)}/s',
                CharacterStat.critChance =>
                  '${(stats.critChance * 100).toStringAsFixed(1)}%',
                CharacterStat.critDamage =>
                  '${stats.critDamage.toStringAsFixed(2)}×',
              };
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
                        'Current: $current · Effect: $effectText',
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
