import 'package:flutter/material.dart';
import '../../core/numbers/amount.dart';
import '../../core/numbers/number_formatter.dart';

class HeroHealthBar extends StatelessWidget {
  const HeroHealthBar({
    super.key,
    required this.current,
    required this.maximum,
  });

  final Amount current;
  final Amount maximum;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 136,
    height: 18,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xff1b2924)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: current.ratio(maximum).clamp(0.0, 1.0),
            child: const ColoredBox(color: Color(0xff479d6c)),
          ),
          Center(
            child: Text(
              '${NumberFormatter.amount(current)}/${NumberFormatter.amount(maximum)}',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x99101720), blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
