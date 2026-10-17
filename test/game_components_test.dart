import 'package:flutter_test/flutter_test.dart';
import 'package:flux_racers/game/components/player_car_component.dart';
import 'package:flux_racers/game/components/road_component.dart';

void main() {
  test('accelerating, coasting, and braking update speed and road motion', () {
    final road = RoadComponent();
    final car = PlayerCarComponent(road);

    car.setAccelerate(true);
    car.update(1);
    expect(car.currentSpeed, 80);
    expect(road.cameraZ, 800);

    car.setAccelerate(false);
    car.update(1);
    expect(car.currentSpeed, 60);

    car.setAccelerate(true);
    car.update(1);
    expect(car.currentSpeed, 140);

    car.setAccelerate(false);
    car.setBrake(true);
    car.update(0.25);
    expect(car.currentSpeed, 102.5);
    car.update(1);
    expect(car.currentSpeed, 0);
  });

  test('steering moves the car and shifts the road', () {
    final road = RoadComponent();
    final car = PlayerCarComponent(road);

    car.setAccelerate(true);
    car.update(1);
    car.setSteer(1);
    car.update(1);

    expect(road.playerX, greaterThan(0));
    expect(car.position.x, greaterThan(380));

    final previousPosition = road.playerX;
    car.setSteer(-1);
    car.update(1);
    expect(road.playerX, lessThan(previousPosition));

    car.setAccelerate(true);
    car.setSteer(1);
    for (var i = 0; i < 10; i++) {
      car.update(1);
    }
    expect(road.playerX, 0.6);
    expect(car.position.x + car.size.x, lessThan(road.size.x));
  });
}
