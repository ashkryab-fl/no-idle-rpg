import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../../../core/balance/game_balance.dart';
import '../../systems/game_simulation.dart';

class ScrollingEnvironment extends Component {
  ScrollingEnvironment(this.simulation, {this.sprites = const [], this.road});
  final GameSimulation simulation;
  final List<Sprite> sprites;
  final Sprite? road;
  final _backgroundPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;
  final _roadPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;
  @override
  void render(Canvas canvas) {
    final opacity = simulation.settings.backgroundOpacity;
    if (opacity > 0) {
      _backgroundPaint.color = Color.fromRGBO(255, 255, 255, opacity);
      if (sprites.isEmpty && opacity < 1) {
        canvas.saveLayer(
          const Rect.fromLTWH(
            0,
            37,
            GameBalance.viewportWidth,
            GameBalance.viewportHeight - 37,
          ),
          Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
        );
        _renderBackground(canvas);
        canvas.restore();
      } else {
        _renderBackground(canvas);
      }
    }
    if (road != null && simulation.settings.roadOpacity > 0) {
      const width = GameBalance.viewportWidth;
      final x = -(simulation.distance % width);
      _roadPaint.color = Color.fromRGBO(
        255,
        255,
        255,
        simulation.settings.roadOpacity,
      );
      canvas.save();
      canvas.clipRect(
        const Rect.fromLTWH(
          0,
          GameBalance.roadTop,
          width,
          GameBalance.roadHeight,
        ),
      );
      for (var tile = 0; tile < 2; tile++) {
        road!.render(
          canvas,
          position: Vector2(x + tile * width, GameBalance.roadTop),
          size: Vector2(width, GameBalance.roadHeight),
          overridePaint: _roadPaint,
        );
      }
      canvas.restore();
    }
  }

  void _renderBackground(Canvas canvas) {
    if (sprites.isNotEmpty) {
      const width = GameBalance.viewportWidth;
      const height = width / 3;
      final offset = simulation.distance % (width * sprites.length);
      final index = (offset / width).floor();
      final x = -(offset % width);
      canvas.save();
      canvas.clipRect(const Rect.fromLTWH(0, 37, width, height));
      for (var tile = 0; tile < 2; tile++) {
        sprites[(index + tile) % sprites.length].render(
          canvas,
          position: Vector2(x + tile * width, 37),
          size: Vector2(width, height),
          overridePaint: _backgroundPaint,
        );
      }
      canvas.restore();
      return;
    }
    final paint = Paint()..color = const Color(0x66527161);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, GameBalance.actorGroundY, 376, 8),
        const Radius.circular(4),
      ),
      paint,
    );
    paint.color = const Color(0x776e9c83);
    for (var i = 0; i < 18; i++) {
      final x = ((i * 26 - simulation.scroll) % 400);
      canvas.drawLine(
        Offset(x, GameBalance.actorGroundY + 5),
        Offset(x + 10, GameBalance.actorGroundY + 5),
        paint..strokeWidth = 2,
      );
    }
    paint.color = const Color(0x228eb5ac);
    for (var i = 0; i < 9; i++) {
      final x = ((i * 55 - simulation.scroll * .25) % 440) - 20;
      final height = 20 + sin(i.toDouble()) * 12;
      canvas.drawRect(
        Rect.fromLTWH(x, GameBalance.actorGroundY - height, 14, height),
        paint,
      );
    }
  }
}
