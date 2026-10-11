import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/equipment_cubit.dart';
import '../../../../../domain/equipment/equipment.dart';
import '../../../../../core/numbers/amount.dart';
import '../../../../../core/numbers/number_formatter.dart';

class EquipmentList extends StatelessWidget {
  const EquipmentList({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EquipmentCubit, EquipmentState>(
    builder: (context, state) {
      final cubit = context.read<EquipmentCubit>();
      final count = state.count;
      final wallet = state.gold;
      String statValue(CharacterStat stat, Amount value) => switch (stat) {
        CharacterStat.damage ||
        CharacterStat.maxHp => NumberFormatter.amount(value),
        CharacterStat.critChance =>
          '${NumberFormatter.decimal(value.toDouble() * 100)}%',
        CharacterStat.critDamage =>
          '${NumberFormatter.decimal(value.toDouble())}×',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Gold  ${NumberFormatter.amount(wallet)}',
            style: const TextStyle(color: Color(0xffffd58a)),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('×1')),
              ButtonSegment(value: 10, label: Text('×10')),
              ButtonSegment(value: 0, label: Text('MAX')),
            ],
            selected: {count ?? 0},
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                cubit.selectCount(v.first == 0 ? null : v.first),
          ),
          const SizedBox(height: 12),
          for (final item in state.items)
            Builder(
              builder: (context) {
                final definition = item.definition;
                final level = item.level;
                final quote = item.quote;
                final buying = quote.count;
                final statLabel = switch (definition.stat) {
                  CharacterStat.damage => 'Damage',
                  CharacterStat.maxHp => 'Max HP',
                  CharacterStat.critChance => 'Crit chance',
                  CharacterStat.critDamage => 'Crit damage',
                };
                final current = statValue(definition.stat, quote.before);
                var statText = '$statLabel: $current';
                if (buying > 0) {
                  final after = statValue(definition.stat, quote.after);
                  statText += ' → $after';
                }
                final relativePercent = quote.relativePercent;
                final relativeGain = relativePercent.log10 < 6
                    ? NumberFormatter.gain(relativePercent.toDouble())
                    : NumberFormatter.amount(relativePercent, whole: false);
                String gain(double value) {
                  final text = NumberFormatter.gain(value);
                  return text.startsWith('<') ? text : '+$text';
                }

                final deltaText = buying == 0
                    ? quote.blockedReason ?? 'No purchase selected'
                    : switch (definition.stat) {
                        CharacterStat.critChance =>
                          'Gain: ${gain(100 * quote.delta.toDouble())} pp',
                        CharacterStat.critDamage =>
                          'Gain: ${gain(quote.delta.toDouble())}×',
                        _ =>
                          'Gain: ${relativeGain.startsWith("<") ? relativeGain : "+$relativeGain"}%',
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
                        Tooltip(
                          message: deltaText,
                          child: Text(
                            statText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff9bdfcc),
                            ),
                          ),
                        ),
                        if (buying == 0 ||
                            current ==
                                statValue(definition.stat, quote.after)) ...[
                          const SizedBox(height: 4),
                          Text(
                            deltaText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: buying > 0
                                ? () => cubit.purchase(definition.id)
                                : null,
                            child: Text(
                              buying > 0
                                  ? 'Upgrade +$buying · ${NumberFormatter.price(quote.cost)} Gold'
                                  : quote.nextCost.isZero
                                  ? 'Upgrade unavailable'
                                  : 'Upgrade · ${NumberFormatter.price(quote.nextCost)} Gold',
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
    },
  );
}
