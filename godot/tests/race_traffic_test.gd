extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var traffic := RaceTraffic.new()
	traffic.configure(2, 22.0, 1234)
	_assert(traffic.cars.size() == 4, "Traffic density scales the vehicle pool")
	_assert(traffic.cars[0].lane_index != traffic.cars[1].lane_index, "Cars start in separate lanes")

	var collision_car := traffic.cars[0]
	collision_car.z_position = -1.0
	collision_car.speed_mps = 20.0
	var collision := traffic.advance(
		0.05,
		20.0,
		traffic.lane_position(0)
	)
	_assert(bool(collision["collided"]), "A close same-lane vehicle causes a collision")
	_assert(
		int(collision["collision_car_index"]) == 0,
		"The collision result identifies the impacting traffic car"
	)

	var near_miss_traffic := RaceTraffic.new()
	near_miss_traffic.configure(1, 20.0, 42)
	var near_miss_car := near_miss_traffic.cars[0]
	near_miss_car.z_position = -0.5
	near_miss_car.speed_mps = 10.0
	var near_miss := near_miss_traffic.advance(0.1, 20.0, -0.5)
	_assert(not bool(near_miss["collided"]), "Adjacent-lane passing remains collision-free")
	_assert(
		int(near_miss["awarded_points"]) == RaceTraffic.OVERTAKE_POINTS + RaceTraffic.NEAR_MISS_POINTS,
		"A close overtake awards overtake and near-miss points"
	)

	var distant_pass_traffic := RaceTraffic.new()
	distant_pass_traffic.configure(1, 20.0, 7)
	var distant_car := distant_pass_traffic.cars[0]
	distant_car.z_position = -0.5
	distant_car.speed_mps = 10.0
	var distant_pass := distant_pass_traffic.advance(0.1, 20.0, 4.0)
	_assert(
		int(distant_pass["awarded_points"]) == RaceTraffic.OVERTAKE_POINTS,
		"A safe overtake awards points without a near-miss bonus"
	)

	if _failed:
		quit(1)
	else:
		print("Godot traffic tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot traffic test failed: %s" % message)
		_failed = true
