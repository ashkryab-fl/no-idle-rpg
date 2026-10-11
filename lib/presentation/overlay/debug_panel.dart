import 'package:flutter/material.dart';
import '../../app/game_controller.dart';

class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'State: ${controller.simulation.phase.name}\nIdle: ${controller.simulation.idle.level.name}\nAnimation: ${controller.simulation.heroPlayback.displayLabel}\n'
        'Frame: ${controller.simulation.heroPlayback.frameId}\n'
        'Graph/node: ${controller.simulation.heroPlayback.graphId} / ${controller.simulation.heroPlayback.nodeId}\n'
        'Local time: ${controller.simulation.heroPlayback.elapsed.toStringAsFixed(3)} s\n'
        'Transition: ${controller.simulation.heroPlayback.lastTransition?.reason.name ?? '-'}\n'
        'Generation: ${controller.simulation.heroPlayback.generation}',
      ),
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
              onPressed: () => controller.debugAction(item.$1),
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
              selected: controller.debugIdleSeconds == item.$1,
              onSelected: (_) => controller.setDebugIdle(item.$1),
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
              selected: controller.simulation.speed == speed,
              onSelected: (_) {
                controller.simulation.speed = speed;
                controller.refresh();
              },
            ),
        ],
      ),
    ],
  );
}
