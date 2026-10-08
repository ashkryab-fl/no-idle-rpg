import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../../systems/game_simulation.dart';

class ScrollingEnvironment extends Component {
  ScrollingEnvironment(this.simulation, {this.sprite});
  final GameSimulation simulation;
  final Sprite? sprite;
  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      for (final tile in [0.0, 400.0]) {
        sprite!.render(
          canvas,
          position: Vector2(tile - simulation.scroll, 37),
          size: Vector2(400, 120),
        );
      }
    }
    final paint = Paint()..color = const Color(0x66527161);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 157, 376, 8),
        const Radius.circular(4),
      ),
      paint,
    );
    paint.color = const Color(0x776e9c83);
    for (var i = 0; i < 18; i++) {
      final x = ((i * 26 - simulation.scroll) % 400);
      canvas.drawLine(
        Offset(x, 162),
        Offset(x + 10, 162),
        paint..strokeWidth = 2,
      );
    }
    paint.color = const Color(0x228eb5ac);
    for (var i = 0; i < 9; i++) {
      final x = ((i * 55 - simulation.scroll * .25) % 440) - 20;
      final height = 20 + sin(i.toDouble()) * 12;
      canvas.drawRect(Rect.fromLTWH(x, 157 - height, 14, height), paint);
    }
  }
}
