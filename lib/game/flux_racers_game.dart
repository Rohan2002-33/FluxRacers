import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'components/road_component.dart';
import 'components/player_car_component.dart';
import 'components/controls_component.dart';

class FluxRacersGame extends FlameGame with HasCollisionDetection {
  FluxRacersGame()
    : super(
        camera: CameraComponent.withFixedResolution(width: 800, height: 450),
      );

  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> timeNotifier = ValueNotifier<double>(0.0);

  late RoadComponent road;
  late PlayerCarComponent playerCar;
  late ControlsComponent controls;

  double _raceTime = 0.0;

  @override
  Future<void> onLoad() async {
    // 1. Add the road (background/scrolling element)
    road = RoadComponent();
    camera.viewport.add(road);

    // 2. Add the player car
    playerCar = PlayerCarComponent(road);
    camera.viewport.add(playerCar);

    // 3. Add touch controls
    controls = ControlsComponent(playerCar);
    camera.viewport.add(controls);

    // Set camera to follow the player slightly for dynamic feel (optional, keeping fixed for now for stability)
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (paused) return;

    _raceTime += dt;
    timeNotifier.value = _raceTime;
    speedNotifier.value = playerCar.currentSpeed;
  }

  @override
  void onRemove() {
    speedNotifier.dispose();
    timeNotifier.dispose();
    super.onRemove();
  }
}
