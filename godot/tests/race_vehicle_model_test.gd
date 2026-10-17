extends SceneTree

var _failed := false


func _init() -> void:
	var vehicle := RaceVehicleModel.new()

	vehicle.update(1.0, true, false, 0.0)
	_assert(is_equal_approx(vehicle.speed_mps, 8.0), "Throttle acceleration")
	_assert(is_equal_approx(vehicle.distance_m, 8.0), "Distance accumulation")

	vehicle.update(1.0, false, false, 0.0)
	_assert(is_equal_approx(vehicle.speed_mps, 6.2), "Coasting deceleration")

	vehicle.update(0.4, false, true, 0.0)
	_assert(is_equal_approx(vehicle.speed_mps, 0.0), "Brake stops the car")
	vehicle.update(1.0, false, false, 0.0)
	_assert(is_equal_approx(vehicle.speed_mps, 0.0), "Speed cannot become negative")

	vehicle.update(1.0, true, false, 1.0)
	var previous_lateral_position: float = vehicle.lateral_position
	vehicle.update(1.0, false, false, 1.0)
	_assert(vehicle.lateral_position > previous_lateral_position, "Steering moves laterally")
	_assert(vehicle.lateral_position <= 4.1, "Steering is bounded by track width")

	vehicle.update(100.0, true, false, 1.0)
	_assert(is_equal_approx(vehicle.speed_kmh, 220.0), "Maximum speed is capped")
	_assert(vehicle.lateral_position <= 4.1, "Maximum steering remains within track")

	if _failed:
		quit(1)
	else:
		print("Godot vehicle model tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot vehicle model test failed: %s" % message)
		_failed = true
