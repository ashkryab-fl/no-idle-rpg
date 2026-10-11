import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../core/balance/progression_balance.dart';
import '../../core/numbers/number_formatter.dart';
import '../../core/numbers/amount.dart';

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final game = controller.simulation, stats = game.stats;
    final activity = game.activity;
    String number(Amount a) => NumberFormatter.amount(a);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(color: Color(0xff9bdfcc))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Gold', number(game.character.gold)),
        row('Knowledge Books', number(game.character.books)),
        row('Stage', '${game.stage}'),
        row(
          'Wave',
          '${game.wave}/${ProgressionBalance.enemiesPerStage}${game.isBossWave ? ' · Boss' : ''}',
        ),
        const Text(
          'Purchases improve combat stats. Death returns you to the previous stage; currencies and equipment are kept.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        row('DPS', number(stats.dps.scale(game.dpsMultiplier))),
        row('Damage', number(stats.damage)),
        row('Crit chance', '${(stats.critChance * 100).toStringAsFixed(1)}%'),
        row('Crit damage', '${stats.critDamage.toStringAsFixed(2)}×'),
        row('HP / max HP', '${number(game.heroHp)} / ${number(stats.maxHp)}'),
        const Divider(),
        row('Distance traveled', '${game.distance.toStringAsFixed(0)} m'),
        row('Enemies killed', '${game.kills}'),
        row(
          'Active today',
          NumberFormatter.duration(activity.today.activeSeconds),
        ),
        row('Idle today', NumberFormatter.duration(activity.today.idleSeconds)),
        row(
          'Average active session',
          NumberFormatter.duration(activity.today.averageActive),
        ),
        row(
          'Average idle session',
          NumberFormatter.duration(activity.today.averageIdle),
        ),
        row(
          'Total active',
          NumberFormatter.duration(activity.total.activeSeconds),
        ),
        row('Total idle', NumberFormatter.duration(activity.total.idleSeconds)),
        const SizedBox(height: 8),
        const Text(
          'Averages use completed sessions. Offline time is excluded.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
