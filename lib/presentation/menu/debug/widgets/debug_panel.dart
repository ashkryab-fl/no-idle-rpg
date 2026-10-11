import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../cubit/debug_cubit.dart';

class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.read<GetIt>()<DebugCubit>(),
    child: BlocBuilder<DebugCubit, DebugState>(
      builder: (context, state) {
        final cubit = context.read<DebugCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(state.details),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in [
                  ('spawn', 'Spawn enemy'),
                  ('enemy', 'Kill enemy'),
                  ('hero', 'Kill hero'),
                  ('gold', '+100 Gold'),
                  ('books', '+100 Books'),
                  ('hitboxes', 'Hitboxes'),
                ])
                  OutlinedButton(
                    onPressed: () => cubit.runAction(item.$1),
                    child: Text(item.$2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Global idle override'),
            Wrap(
              spacing: 6,
              children: [
                for (final item in <(double?, String)>[
                  (null, 'OS'),
                  (0, 'Active'),
                  (31, 'Level 1'),
                  (121, 'Level 2'),
                  (301, 'Level 3'),
                ])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: state.idleOverride == item.$1,
                    onSelected: (_) => cubit.setDebugIdle(item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Simulation speed'),
            Wrap(
              spacing: 6,
              children: [
                for (final speed in [1.0, 5.0, 20.0])
                  ChoiceChip(
                    label: Text('x${speed.toInt()}'),
                    selected: state.speed == speed,
                    onSelected: (_) => cubit.setSpeed(speed),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
