extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var traffic := RaceTraffic.new()
	traffic.configure(2, 22.0, 1234)
	_assert(traffic.cars.size() == 6, "Traffic density scales the vehicle pool")
	_assert(traffic.cars[0].lane_index != traffic.cars[1].lane_index, "Cars start in separate lanes")
	_assert(traffic.cars[0].model_id == "sedan", "Traffic includes passenger cars")
	_assert(
		traffic.cars[1].model_id == "kenney_truck",
		"Low-density traffic includes an imported 3D truck"
	)
	_assert(
		traffic.cars[0].paint_color != traffic.cars[1].paint_color,
		"Traffic vehicles spawn with visibly different paint colors"
	)
	_assert(traffic.cars[1].body_width > traffic.cars[0].body_width, "Truck collision width reflects its model")
	_assert(traffic.cars[1].body_length > traffic.cars[0].body_length, "Truck collision length reflects its model")

	var collision_car := traffic.cars[0]
	collision_car.z_position = -1.0
	collision_car.speed_mps = 20.0
	var collision := traffic.advance(
		0.05,
		20.0,
		traffic.lane_position(0),
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
	var near_miss := near_miss_traffic.advance(0.1, 20.0, -0.5, -0.5)
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
	var distant_pass := distant_pass_traffic.advance(0.1, 20.0, 4.0, 4.0)
	_assert(
		int(distant_pass["awarded_points"]) == RaceTraffic.OVERTAKE_POINTS,
		"A safe overtake awards points without a near-miss bonus"
	)

	var truck_traffic := RaceTraffic.new()
	truck_traffic.configure(1, 20.0, 17)
	var truck := truck_traffic.cars[1]
	truck.lane_index = 1
	truck.z_position = 0.0
	truck.previous_z_position = 0.0
	truck.speed_mps = 20.0
	var truck_side_contact := truck_traffic.advance(0.016, 20.0, -2.0, -2.0)
	_assert(
		bool(truck_side_contact["collided"])
			and int(truck_side_contact["collision_car_index"]) == 1,
		"A side contact with the wide box truck ends the race"
	)

	var swept_traffic := RaceTraffic.new()
	swept_traffic.configure(1, 20.0, 23)
	var swept_car := swept_traffic.cars[0]
	swept_car.z_position = -30.0
	swept_car.previous_z_position = -30.0
	swept_car.speed_mps = 10.0
	var swept_collision := swept_traffic.advance(0.1, 610.0, -2.8, -2.8)
	_assert(
		bool(swept_collision["collided"]),
		"High-speed traffic contact cannot tunnel through the collision check"
	)

	var lane_change_traffic := RaceTraffic.new()
	lane_change_traffic.configure(1, 20.0, 29)
	var lane_change_car := lane_change_traffic.cars[1]
	lane_change_car.z_position = 0.0
	lane_change_car.previous_z_position = 0.0
	lane_change_car.speed_mps = 20.0
	var lane_change_collision := lane_change_traffic.advance(0.016, 20.0, -4.0, 0.0)
	_assert(
		bool(lane_change_collision["collided"])
			and int(lane_change_collision["collision_car_index"]) == 1,
		"Crossing a vehicle laterally causes a collision on the contact frame"
	)

	var overtaking_traffic := RaceTraffic.new()
	overtaking_traffic.configure(1, 20.0, 37)
	var overtaking_car := overtaking_traffic.cars[0]
	var overtaken_car := overtaking_traffic.cars[1]
	var passing_lane_car := overtaking_traffic.cars[2]
	overtaken_car.lane_index = 0
	overtaken_car.target_lane_index = 0
	overtaken_car.lateral_position = RaceTraffic.LANE_POSITIONS[0]
	overtaken_car.previous_lateral_position = overtaken_car.lateral_position
	passing_lane_car.lane_index = 1
	passing_lane_car.target_lane_index = 1
	passing_lane_car.lateral_position = RaceTraffic.LANE_POSITIONS[1]
	passing_lane_car.previous_lateral_position = passing_lane_car.lateral_position
	overtaking_car.z_position = -30.0
	overtaking_car.speed_mps = 30.0
	overtaking_car.cruise_speed_mps = 30.0
	overtaken_car.z_position = -50.0
	overtaken_car.speed_mps = 20.0
	overtaken_car.cruise_speed_mps = 20.0
	overtaking_traffic.advance(0.1, 20.0, 10.0, 10.0)
	_assert(
		overtaking_car.target_lane_index == 1
			and overtaking_car.lateral_position > RaceTraffic.LANE_POSITIONS[0],
		"A faster vehicle starts a smooth lane change to overtake"
	)
	for _step in range(50):
		overtaking_traffic.advance(0.1, 20.0, 10.0, 10.0)
	_assert(
		overtaking_car.lane_index == 0 and overtaking_car.target_lane_index == 0,
		"An overtaking vehicle safely returns to its original lane"
	)
	_assert(
		overtaking_car.z_position < overtaken_car.z_position,
		"The faster vehicle completes the overtake before returning"
	)

	var blocked_overtake_traffic := RaceTraffic.new()
	blocked_overtake_traffic.configure(2, 20.0, 41)
	var blocked_follower := blocked_overtake_traffic.cars[0]
	var blocked_leader := blocked_overtake_traffic.cars[3]
	var lane_blocker := blocked_overtake_traffic.cars[1]
	blocked_follower.z_position = -30.0
	blocked_follower.speed_mps = 30.0
	blocked_leader.z_position = -50.0
	blocked_leader.speed_mps = 20.0
	lane_blocker.z_position = -35.0
	var blocked_result := blocked_overtake_traffic.advance(0.1, 20.0, 10.0, 10.0)
	_assert(
		blocked_follower.target_lane_index == blocked_follower.lane_index
			and blocked_follower.speed_mps <= blocked_leader.speed_mps,
		"A vehicle slows down instead of entering an occupied passing lane"
	)
	_assert(
		not bool(blocked_result["collided"]),
		"Traffic safely follows when no passing lane is available"
	)

	var full_roster := RaceTraffic.new()
	full_roster.configure(3, 25.0, 31)
	var model_ids: Array[String] = []
	for car in full_roster.cars:
		if not model_ids.has(car.model_id):
			model_ids.append(car.model_id)
	_assert(
		model_ids.size() == 9,
		"High traffic density deploys nine different 3D vehicle models"
	)
	var alternate_roster := RaceTraffic.new()
	alternate_roster.configure(3, 25.0, 97)
	var alternate_model_ids: Array[String] = []
	for car in alternate_roster.cars:
		if not alternate_model_ids.has(car.model_id):
			alternate_model_ids.append(car.model_id)
	var shared_model_count := 0
	for model_id in model_ids:
		if alternate_model_ids.has(model_id):
			shared_model_count += 1
	_assert(
		shared_model_count < model_ids.size(),
		"Traffic model combinations vary between race seeds"
	)
	var race_roster := RaceTraffic.new()
	race_roster.configure_competitive_roster()
	var competitive_models: Array[String] = []
	for race_car in race_roster.cars:
		competitive_models.append(race_car.model_id)
	_assert(
		race_roster.cars.size() == 5
			and competitive_models.has("kenney_race_car")
			and competitive_models.has("kenney_sports_sedan")
			and not competitive_models.has("kenney_police")
			and not competitive_models.has("kenney_fire_truck"),
		"Competitive grids use dedicated race and road-car models, not emergency traffic"
	)
	for target_index in range(full_roster.cars.size()):
		for car in full_roster.cars:
			car.lane_index = 0
			car.target_lane_index = 0
			car.lateral_position = RaceTraffic.LANE_POSITIONS[0]
			car.previous_lateral_position = car.lateral_position
			car.z_position = -1000.0
			car.previous_z_position = -1000.0
			car.speed_mps = 20.0
		var target_car := full_roster.cars[target_index]
		target_car.lane_index = 1
		target_car.target_lane_index = 1
		target_car.lateral_position = RaceTraffic.LANE_POSITIONS[1]
		target_car.previous_lateral_position = target_car.lateral_position
		target_car.z_position = 0.0
		target_car.previous_z_position = 0.0
		var impact := full_roster.advance(0.016, 20.0, 0.0, 0.0)
		_assert(
			bool(impact["collided"])
				and int(impact["collision_car_index"]) == target_index,
			"A direct contact with %s ends the race" % target_car.model_id
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
