import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/painting.dart';

import '../../app/theme/app_colors.dart';
import 'player_car_component.dart';

class ControlsComponent extends PositionComponent {
  final PlayerCarComponent player;

  ControlsComponent(this.player) : super(size: Vector2(800, 450));

  @override
  Future<void> onLoad() async {
    // Left Button
    final leftBtn = _buildButton(
      '◀',
      20,
      300,
      () {
        player.setSteer(-1.0);
      },
      () {
        player.setSteer(0.0);
      },
      () {
        player.setSteer(0.0);
      },
    );

    // Right Button
    final rightBtn = _buildButton(
      '▶',
      100,
      300,
      () {
        player.setSteer(1.0);
      },
      () {
        player.setSteer(0.0);
      },
      () {
        player.setSteer(0.0);
      },
    );

    // Brake Button
    final brakeBtn = _buildButton(
      'BRAKE',
      600,
      300,
      () {
        player.setBrake(true);
      },
      () {
        player.setBrake(false);
      },
      () {
        player.setBrake(false);
      },
      color: AppColors.warningRed,
    );

    // Gas Button
    final gasBtn = _buildButton(
      'GAS',
      700,
      280,
      () {
        player.setAccelerate(true);
      },
      () {
        player.setAccelerate(false);
      },
      () {
        player.setAccelerate(false);
      },
      color: AppColors.secondaryOrange,
      size: Vector2(70, 90),
    );

    addAll([leftBtn, rightBtn, brakeBtn, gasBtn]);
  }

  ButtonComponent _buildButton(
    String text,
    double x,
    double y,
    void Function() onPress,
    void Function() onRelease,
    void Function() onCancel, {
    Color color = AppColors.surfaceLight,
    Vector2? size,
  }) {
    final btnSize = size ?? Vector2(60, 60);
    return ButtonComponent(
      button: _ButtonSprite(text, color, btnSize),
      buttonDown: _ButtonSprite(text, color.withValues(alpha: 0.7), btnSize),
      position: Vector2(x, y),
      onPressed: onPress,
      onReleased: onRelease,
      onCancelled: onCancel,
    );
  }
}

// Custom sprite for button visuals
class _ButtonSprite extends PositionComponent with HasPaint {
  final String text;
  final Color color;

  _ButtonSprite(this.text, this.color, Vector2 size) : super(size: size) {
    paint.color = color;
  }

  @override
  void render(Canvas canvas) {
    // Button background
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, paint);

    // Button border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.primaryCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Button text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }
}
