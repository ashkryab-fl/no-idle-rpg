import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../domain/equipment/equipment.dart';
import '../../core/numbers/amount.dart';
import '../../core/numbers/number_formatter.dart';
import '../../domain/character/character.dart';

class EquipmentList extends StatefulWidget {
  const EquipmentList({super.key, required this.controller});
  final GameController controller;
  @override
  State<EquipmentList> createState() => _EquipmentListState();
}

class _EquipmentListState extends State<EquipmentList> {
  int? count = 1;
  @override
  Widget build(BuildContext context) {
    final game = widget.controller.simulation;
    final wallet = game.character.gold;
    final levels = game.character.equipment;
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
          'Gold  ${NumberFormatter.amount(wallet)}',
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
        for (final definition in EquipmentCatalog.items)
          Builder(
            builder: (context) {
              final level = levels[definition.id] ?? 0;
              final quote = game.purchases.quote(
                game.character,
                definition.id,
                count: count,
              );
              final buying = quote.count;
              final statLabel = switch (definition.stat) {
                CharacterStat.damage => 'Damage',
                CharacterStat.maxHp => 'Max HP',
                CharacterStat.critChance => 'Crit chance',
                CharacterStat.critDamage => 'Crit damage',
              };
              final profile = game.curveProfile;
              final effectText = switch (definition.stat) {
                CharacterStat.critChance =>
                  'Gains decrease after ${(profile.chance.atThreshold * 100).toStringAsFixed(0)}% crit chance.',
                CharacterStat.critDamage =>
                  'Gains decrease after ${profile.multiplier.value(profile.multiplier.threshold).toStringAsFixed(2)}× crit damage.',
                _ =>
                  'Each level increases ${statLabel.toLowerCase()}; percentage gains gradually decrease.',
              };
              final current = statValue(definition.stat, stats);
              var statText = '$statLabel: $current';
              if (buying > 0) {
                final preview = CharacterProgress()
                  ..equipment.addAll(game.character.equipment);
                preview.equipment[definition.id] = level + buying;
                final after = statValue(
                  definition.stat,
                  CharacterStats.calculate(preview, profile: profile),
                );
                statText += ' → $after (after +$buying)';
              }
              String gain(double value) => value.abs() >= .01
                  ? value.toStringAsFixed(4)
                  : value.toStringAsPrecision(6);
              final relativePercent =
                  (Amount.fromLog(quote.after.log10 - quote.before.log10) -
                          Amount.one)
                      .scale(100);
              final relativeGain = relativePercent.log10 < 6
                  ? gain(relativePercent.toDouble())
                  : NumberFormatter.amount(relativePercent);
              final deltaText = buying == 0
                  ? quote.blockedReason ?? 'No purchase selected'
                  : switch (definition.stat) {
                      CharacterStat.critChance =>
                        'Gain: +${gain(100 * (profile.chance.value(level + buying) - profile.chance.value(level)))} percentage points',
                      CharacterStat.critDamage =>
                        'Gain: +${gain(profile.multiplier.value(level + buying) - profile.multiplier.value(level))}×',
                      _ => 'Gain: +$relativeGain%',
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
                        statText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff9bdfcc),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deltaText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        effectText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: buying > 0
                              ? () => widget.controller.purchaseEquipment(
                                  definition.id,
                                  count,
                                )
                              : null,
                          child: Text(
                            buying > 0
                                ? 'Upgrade +$buying · ${NumberFormatter.amount(quote.cost)}'
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
