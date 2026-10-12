import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../../../core/animation/playback_snapshot.dart';
import '../../../core/animation/sprite_frame.dart';
import '../../../core/animation/sprite_rig.dart';
import '../../animation/flame_sprite_frame_cache.dart';
import '../../systems/game_simulation.dart';
import '../../../core/balance/game_balance.dart';

class ActorComponent extends Component {
  ActorComponent(this.simulation, this.frameCache, {required this.hero});
  final GameSimulation simulation;
  final FlameSpriteFrameCache frameCache;
  final bool hero;
  @override
  void render(Canvas canvas) {
    if (!hero && simulation.enemy == null) return;
    final snapshot = hero ? simulation.heroPlayback : simulation.enemyPlayback!;
    final x = hero ? 104.0 : simulation.enemyX;
    canvas.save();
    final enemy = hero ? null : simulation.enemy!;
    final scale = hero
        ? GameBalance.heroScale
        : enemy!.definition.scale * (enemy.isBoss ? GameBalance.bossScale : 1);
    // Scale around the ground anchor so every size stays planted on the road.
    canvas.translate(x, GameBalance.actorGroundY);
    canvas.scale(scale);
    canvas.translate(-x, -GameBalance.actorGroundY);
    final frame = snapshot.frame;
    if (frame != null && !frame.debugPlaceholder) {
      final fading = !hero && snapshot.proceduralPose == ProceduralPose.fallen;
      final opacity = fading
          ? (1 - snapshot.elapsed / snapshot.duration).clamp(0, 1).toDouble()
          : 1.0;
      final from = snapshot.fadeFromFrame;
      if (from != null) {
        // Add weighted premultiplied colors in an isolated layer, keeping
        // overlapping opaque pixels opaque throughout the crossfade.
        canvas.saveLayer(null, Paint());
        _sprite(
          canvas,
          x,
          from,
          snapshot.fadeFromRig!,
          opacity * (1 - snapshot.fadeProgress),
          snapshot.damageFlash,
        );
      }
      _sprite(
        canvas,
        x,
        frame,
        snapshot.rig!,
        opacity * (from == null ? 1 : snapshot.fadeProgress),
        snapshot.damageFlash,
        blendMode: from == null ? BlendMode.srcOver : BlendMode.plus,
      );
      if (from != null) canvas.restore();
    } else {
      _procedural(canvas, x, snapshot);
    }
    canvas.restore();
    if (simulation.hitboxes) {
      canvas.drawRect(
        Rect.fromLTWH(
          x - 36,
          GameBalance.viewportHeight - GameBalance.heroHitboxHeight,
          72,
          GameBalance.heroHitboxHeight,
        ),
        Paint()
          ..color = const Color(0xffeebc59)
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _sprite(
    Canvas canvas,
    double x,
    SpriteFrameDefinition frame,
    SpriteRigDefinition rig,
    double opacity,
    bool flash, {
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    if (opacity <= 0) return;
    final renderScale = rig.worldUnitsPerPixel * frame.scaleMultiplier;
    final w = rig.canvasWidth * renderScale, h = rig.canvasHeight * renderScale;
    final paint = opacity < 1 || flash || blendMode != BlendMode.srcOver
        ? (Paint()
            ..color = Color.fromRGBO(255, 255, 255, opacity)
            ..blendMode = blendMode)
        : null;
    if (flash) {
      paint!.colorFilter = const ColorFilter.mode(
        Color(0x99fff4d6),
        BlendMode.srcATop,
      );
    }
    frameCache
        .sprite(frame.id)
        .render(
          canvas,
          position: Vector2(
            x - w * rig.anchorX,
            GameBalance.actorGroundY - h * rig.anchorY,
          ),
          size: Vector2(w, h),
          overridePaint: paint,
        );
  }

  void _procedural(Canvas canvas, double x, PlaybackSnapshot snapshot) {
    final elapsed = snapshot.elapsed;
    final death = snapshot.proceduralPose == ProceduralPose.fallen;
    final attack = snapshot.proceduralPose == ProceduralPose.striking;
    final hit = snapshot.damageFlash;
    final walk = snapshot.proceduralPose == ProceduralPose.moving;
    final bob = walk ? sin(elapsed * 12) * 2 : 0.0;
    canvas.save();
    canvas.translate(x, GameBalance.actorGroundY - 1 + bob);
    if (death) {
      canvas.rotate(
        (hero ? -1 : 1) * pi / 2 * (elapsed / snapshot.duration).clamp(0, 1),
      );
    }
    if (hit) canvas.translate(hero ? -5 : 5, 0);
    final color = hit
        ? const Color(0xfffaf6dc)
        : hero
        ? const Color(0xff83bdc1)
        : const Color(0xffd48b87);
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-17, -56, 34, 44),
        const Radius.circular(7),
      ),
      paint,
    );
    canvas.drawCircle(const Offset(0, -65), 12, paint);
    paint.color = const Color(0xff304e5d);
    for (final sign in [-1, 1]) {
      final stride = walk ? sin(elapsed * 12) * 5 * sign : 0.0;
      canvas.drawLine(
        Offset(sign * 9.0, -13),
        Offset(sign * 9.0 + stride, 0),
        paint
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    if (attack) {
      final direction = hero ? 1 : -1;
      final thrust = sin((elapsed / snapshot.duration).clamp(0, 1) * pi) * 16;
      canvas.drawLine(
        Offset(direction * 14.0, -38),
        Offset(direction * (40 + thrust), -38),
        Paint()
          ..color = const Color(0xffedd898)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }
}
