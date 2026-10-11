import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/statistics_cubit.dart';

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.read<GetIt>()<StatisticsCubit>(),
    child: BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, state) {
        Widget row(String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                state.values[label]!,
                style: const TextStyle(color: Color(0xff9bdfcc)),
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final label in ['Gold', 'Knowledge Books', 'Stage', 'Wave'])
              row(label),
            const Text(
              'Purchases improve combat stats. Death returns you to the previous stage; currencies and equipment are kept.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            for (final label in [
              'DPS',
              'Damage',
              'Crit chance',
              'Crit damage',
              'HP / max HP',
            ])
              row(label),
            const Divider(),
            for (final label in [
              'Distance traveled',
              'Enemies killed',
              'Active today',
              'Idle today',
              'Average active session',
              'Average idle session',
              'Total active',
              'Total idle',
            ])
              row(label),
            const SizedBox(height: 8),
            const Text(
              'Averages use completed sessions. Offline time is excluded.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        );
      },
    ),
  );
}
