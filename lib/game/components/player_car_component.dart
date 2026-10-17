import 'dart:ui';

import 'package:flame/components.dart';

import '../../app/theme/app_colors.dart';
import 'road_component.dart';

class PlayerCarComponent extends PositionComponent {
  static const double _maxRoadOffset = 0.6;

  double currentSpeed = 0.0;
  final double maxSpeed = 200.0; // Arbitrary game units
  final double acceleration = 80.0;
  final double braking = 150.0;
  final double friction = 20.0;
  final double maxSteer = 1.2; // Max lateral offset

  double _steerInput = 0.0; // -1.0 (left) to 1.0 (right)
  bool _isAccelerating = false;
  bool _isBraking = false;

  final RoadComponent _road;

  PlayerCarComponent(this._road) : super(size: Vector2(40, 70)) {
    position = Vector2(380, 350);
  }

  void setSteer(double value) => _steerInput = value.clamp(-1.0, 1.0);
  void setAccelerate(bool value) => _isAccelerating = value;
  void setBrake(bool value) => _isBraking = value;

  @override
  void update(double dt) {
    super.update(dt);

    if (_isAccelerating) {
      currentSpeed += acceleration * dt;
    } else if (_isBraking) {
      currentSpeed -= braking * dt;
    } else {
      // Natural friction
      currentSpeed -= friction * dt;
    }
    currentSpeed = currentSpeed.clamp(0.0, maxSpeed);

    if (currentSpeed > 1.0) {
      final double steerFactor = (currentSpeed / maxSpeed) * 0.8;
      final double moveAmount = _steerInput * maxSteer * steerFactor * dt * 5.0;

      _road.playerX = (_road.playerX + moveAmount).clamp(
        -_maxRoadOffset,
        _maxRoadOffset,
      );
      position.x =
          (_road.size.x - size.x) / 2 + _road.playerX * _road.size.x * 0.25;
    }

    _road.updateRoad(dt, currentSpeed);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final bodyPaint = Paint()..color = AppColors.primaryCyan;
    final shadowPaint = Paint()..color = const Color(0x80000000);
    final detailPaint = Paint()..color = AppColors.backgroundDark;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.x, size.y),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(8),
      ),
      bodyPaint,
    );

    canvas.drawRect(Rect.fromLTWH(6, 15, size.x - 12, 15), detailPaint);

    canvas.drawRect(Rect.fromLTWH(8, 45, size.x - 16, 10), detailPaint);

    final tailLightPaint = Paint()..color = AppColors.warningRed;
    canvas.drawRect(Rect.fromLTWH(2, 65, 10, 4), tailLightPaint);
    canvas.drawRect(Rect.fromLTWH(size.x - 12, 65, 10, 4), tailLightPaint);
  }
}
