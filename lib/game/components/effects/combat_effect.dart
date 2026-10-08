import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../../../core/numbers/number_formatter.dart';
import '../../../core/balance/game_balance.dart';
import '../../systems/game_simulation.dart';

class CombatEffect extends Component {
  CombatEffect(this.event);
  final VisualEvent event;
  double elapsed = 0;
  final _text = TextPainter(textDirection: TextDirection.ltr);
  @override
  void update(double dt) {
    elapsed += dt;
    if (elapsed >= 1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final damage = event.damage;
    final x = damage == null
        ? 180.0
        : damage.fromHero
        ? 254.0
        : 104.0;
    final color = damage?.critical == true
        ? const Color(0xffffd478)
        : const Color(0xffebf2f2);
    final text = damage != null
        ? '${damage.critical ? 'CRIT ' : ''}${NumberFormatter.amount(damage.amount)}'
        : '+${NumberFormatter.amount(event.reward!.gold)} gold${event.reward!.books.isZero ? '' : '  +book'}';
    _text.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: damage?.critical == true ? 16 : 12,
        fontWeight: FontWeight.bold,
        color: color.withValues(alpha: 1 - elapsed),
        backgroundColor: const Color(0x99101720),
      ),
    );
    _text.layout();
    _text.paint(
      canvas,
      Offset(x - _text.width / 2, GameBalance.actorGroundY - 62 - elapsed * 34),
    );
    if (damage != null && elapsed < .4) {
      for (var i = 0; i < 6; i++) {
        final angle = i * pi / 3;
        canvas.drawCircle(
          Offset(
            x + cos(angle) * elapsed * 70,
            GameBalance.actorGroundY - 43 + sin(angle) * elapsed * 70,
          ),
          2,
          Paint()..color = color.withValues(alpha: 1 - elapsed * 2),
        );
      }
    }
  }
}
