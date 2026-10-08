import 'package:flutter/material.dart';
import '../../app/game_controller.dart';
import '../../core/numbers/number_formatter.dart';
import '../../core/numbers/amount.dart';

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final game = controller.simulation,
        hero = game.character,
        stats = game.stats;
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
        row('Level', '${hero.level}'),
        row('Experience', number(hero.xp)),
        row(
          'XP to next level',
          number(game.progression.xpRequired(hero.level) - hero.xp),
        ),
        row('DPS', number(stats.dps.scale(game.dpsMultiplier))),
        row('Damage', number(stats.damage)),
        row('Attack speed', '${stats.attackSpeed.toStringAsFixed(2)}/s'),
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
        if (controller.runtime.offline.duration.inSeconds > 0)
          Text(
            'Last offline interval: ${NumberFormatter.duration(controller.runtime.offline.duration.inSeconds.toDouble())}',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
      ],
    );
  }
}
