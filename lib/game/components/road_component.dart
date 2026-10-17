import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';

import '../../app/theme/app_colors.dart';

class RoadComponent extends PositionComponent {
  final double segmentLength = 100.0;
  final double cameraDepth = 1.0;
  final int drawDistance = 50;

  double cameraZ = 0.0;
  double playerX = 0.0; // Player's lateral position (-1.0 to 1.0)

  RoadComponent() : super(size: Vector2(800, 450));

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final horizonY = size.y * 0.4;
    final roadHalfWidthAtMax = size.x * 0.42;
    canvas.drawColor(const Color(0xFF0A1A0A), BlendMode.src);

    final int startSegment = (cameraZ / segmentLength).floor();
    final int endSegment = startSegment + drawDistance;

    for (int i = endSegment; i > startSegment; i--) {
      final double z1 = (i * segmentLength) - cameraZ;
      final double z2 = ((i + 1) * segmentLength) - cameraZ;

      final scale1 = cameraDepth / (z1 / segmentLength);
      final scale2 = cameraDepth / (z2 / segmentLength);
      final y1 = horizonY + (scale1 * size.y * 0.6);
      final y2 = horizonY + (scale2 * size.y * 0.6);
      final x1Center = (size.x / 2) - (playerX * scale1 * size.x * 0.4);
      final x2Center = (size.x / 2) - (playerX * scale2 * size.x * 0.4);
      final w1 = scale1 * roadHalfWidthAtMax;
      final w2 = scale2 * roadHalfWidthAtMax;

      final bool isDark = (i ~/ 2) % 2 == 0;
      final Color grassColor = isDark
          ? const Color(0xFF0A1A0A)
          : const Color(0xFF0D220D);
      final Color rumbleColor = isDark
          ? AppColors.warningRed
          : BasicPalette.white.color;
      final Color roadColor = isDark
          ? const Color(0xFF333333)
          : const Color(0xFF3A3A3A);
      final Color laneColor = isDark
          ? BasicPalette.white.color
          : const Color(0x00000000);

      canvas.drawRect(
        Rect.fromLTWH(0, y2, size.x, y1 - y2),
        Paint()..color = grassColor,
      );

      _drawTrapezoid(
        canvas,
        x1Center - w1 * 1.1,
        y1,
        x1Center + w1 * 1.1,
        y1,
        x2Center - w2 * 1.1,
        y2,
        x2Center + w2 * 1.1,
        y2,
        rumbleColor,
      );

      _drawTrapezoid(
        canvas,
        x1Center - w1,
        y1,
        x1Center + w1,
        y1,
        x2Center - w2,
        y2,
        x2Center + w2,
        y2,
        roadColor,
      );

      if (laneColor != const Color(0x00000000)) {
        final double laneW1 = w1 * 0.05;
        final double laneW2 = w2 * 0.05;
        _drawTrapezoid(
          canvas,
          x1Center - laneW1,
          y1,
          x1Center + laneW1,
          y1,
          x2Center - laneW2,
          y2,
          x2Center + laneW2,
          y2,
          laneColor,
        );
      }
    }
  }

  void _drawTrapezoid(
    Canvas canvas,
    double x1Left,
    double y1,
    double x1Right,
    double y1Top,
    double x2Left,
    double y2,
    double x2Right,
    double y2Top,
    Color color,
  ) {
    final path = Path()
      ..moveTo(x1Left, y1)
      ..lineTo(x1Right, y1Top)
      ..lineTo(x2Right, y2Top)
      ..lineTo(x2Left, y2)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void updateRoad(double dt, double speed) {
    cameraZ += speed * dt * 10.0;
  }
}
