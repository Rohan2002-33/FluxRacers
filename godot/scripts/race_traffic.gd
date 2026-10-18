class_name RaceTraffic
extends RefCounted

const TRAFFIC_MODEL_GENERATOR := preload("res://scripts/race_traffic_models.gd")

class TrafficCar:
	extends RefCounted

	var lane_index: int
	var target_lane_index: int
	var z_position: float
	var speed_mps: float
	var cruise_speed_mps: float
	var previous_z_position: float
	var lateral_position: float
	var previous_lateral_position: float
	var model_id: String
	var paint_color: Color
	var body_width: float
	var body_length: float
	var passing_leader_index := -1
	var return_lane_index := -1
	var is_following := false

	func _init(
		start_lane: int,
		start_z: float,
		speed: float,
		start_model_id: String,
		start_paint_color: Color,
		width: float,
		length: float
	) -> void:
		lane_index = start_lane
		target_lane_index = start_lane
		z_position = start_z
		speed_mps = speed
		cruise_speed_mps = speed
		previous_z_position = start_z
		model_id = start_model_id
		paint_color = start_paint_color
		body_width = width
		body_length = length


const LANE_POSITIONS := [-2.8, 0.0, 2.8]
const PLAYER_HALF_WIDTH := 0.95
const PLAYER_HALF_LENGTH := 2.1
const LANE_CHANGE_SPEED := 3.5
const OVERTAKE_LOOKAHEAD_DISTANCE := 24.0
const FOLLOWING_DISTANCE := 22.0
const MINIMUM_TRAFFIC_GAP := 1.2
const LANE_CHANGE_CLEARANCE := 10.0
const PASS_RETURN_GAP := 14.0
const NEAR_MISS_LATERAL_RANGE := 2.8
const NEAR_MISS_POINTS := 50
const OVERTAKE_POINTS := 100
const TRAFFIC_MODEL_IDS := [
	"sedan",
	"kenney_truck",
	"sport",
	"kenney_suv",
	"pickup",
	"kenney_sports_sedan",
	"suv",
	"kenney_garbage_truck",
	"box_truck",
	"kenney_hatchback",
	"kenney_delivery",
	"kenney_taxi",
	"kenney_ambulance",
	"kenney_flatbed",
	"kenney_van",
	"kenney_police",
	"kenney_fire_truck",
	"kenney_luxury_suv",
	"kenney_race_car",
]
const REQUIRED_TRAFFIC_MODELS := ["sedan", "kenney_truck", "sport"]
const TRAFFIC_PAINT_COLORS := [
	Color("1689d2"),
	Color("e2e7e8"),
	Color("29a65a"),
	Color("e4b530"),
	Color("7a4ec5"),
	Color("d05d2b"),
]

var cars: Array[TrafficCar] = []
var _random := RandomNumberGenerator.new()
var _base_speed_mps := 25.0
var _next_lane_index := 0


func configure(density: int, base_speed_mps: float, seed_value: int = 0) -> void:
	cars.clear()
	_base_speed_mps = clampf(base_speed_mps, 10.0, 60.0)
	_random.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	var car_count := clampi(density, 1, 3) * 3
	var available_model_ids: Array[String] = []
	available_model_ids.append_array(TRAFFIC_MODEL_IDS)
	for required_model in REQUIRED_TRAFFIC_MODELS:
		available_model_ids.erase(required_model)
	for index in range(car_count):
		var lane_index := index % LANE_POSITIONS.size()
		var start_z := -95.0 - float(index) * 42.0
		var speed_variation := _random.randf_range(-4.0, 4.0)
		var model_id: String
		if index < REQUIRED_TRAFFIC_MODELS.size():
			model_id = REQUIRED_TRAFFIC_MODELS[index]
		else:
			var selection_index := _random.randi_range(0, available_model_ids.size() - 1)
			model_id = available_model_ids[selection_index]
			available_model_ids.remove_at(selection_index)
		var color_index := (
			index + _random.randi_range(0, TRAFFIC_PAINT_COLORS.size() - 1)
		) % TRAFFIC_PAINT_COLORS.size()
		if index > 0 and TRAFFIC_PAINT_COLORS[color_index] == cars[index - 1].paint_color:
			color_index = (color_index + 1) % TRAFFIC_PAINT_COLORS.size()
		var model_spec: Dictionary = TRAFFIC_MODEL_GENERATOR.get_spec(model_id)
		var traffic_car := TrafficCar.new(
			lane_index,
			start_z,
			clampf(_base_speed_mps + speed_variation, 10.0, 60.0),
			model_id,
			TRAFFIC_PAINT_COLORS[color_index],
			float(model_spec["width"]),
			float(model_spec["length"])
		)
		traffic_car.lateral_position = LANE_POSITIONS[lane_index]
		traffic_car.previous_lateral_position = traffic_car.lateral_position
		cars.append(traffic_car)
	_next_lane_index = car_count % LANE_POSITIONS.size()


func advance(
	delta: float,
	player_speed_mps: float,
	previous_player_x: float,
	player_x: float
) -> Dictionary:
	var collided := false
	var awarded_points := 0
	var collision_car_index := -1
	_plan_lane_changes(player_x)
	_apply_following_speeds()
	for index in range(cars.size()):
		var car := cars[index]
		car.previous_z_position = car.z_position
		car.previous_lateral_position = car.lateral_position
		car.z_position += (player_speed_mps - car.speed_mps) * delta
		car.lateral_position = move_toward(
			car.lateral_position,
			LANE_POSITIONS[car.target_lane_index],
			LANE_CHANGE_SPEED * delta
		)
		if is_equal_approx(car.lateral_position, LANE_POSITIONS[car.target_lane_index]):
			car.lane_index = car.target_lane_index
			if car.return_lane_index == car.lane_index:
				car.passing_leader_index = -1
				car.return_lane_index = -1
		var longitudinal_overlap := _overlap_time_range(
			car.previous_z_position,
			car.z_position - car.previous_z_position,
			PLAYER_HALF_LENGTH + car.body_length * 0.5
		)
		var lateral_overlap := _overlap_time_range(
			car.previous_lateral_position - previous_player_x,
			car.lateral_position
				- car.previous_lateral_position
				- (player_x - previous_player_x),
			PLAYER_HALF_WIDTH + car.body_width * 0.5
		)
		var lateral_gap := absf(car.lateral_position - player_x)
		if (
			longitudinal_overlap.x <= longitudinal_overlap.y
			and lateral_overlap.x <= lateral_overlap.y
			and maxf(longitudinal_overlap.x, lateral_overlap.x)
				<= minf(longitudinal_overlap.y, lateral_overlap.y)
		):
			collided = true
			collision_car_index = index
			break

		if car.previous_z_position < 0.0 and car.z_position >= 0.0:
			awarded_points += OVERTAKE_POINTS
			if lateral_gap < NEAR_MISS_LATERAL_RANGE:
				awarded_points += NEAR_MISS_POINTS

		if car.z_position > 18.0 or car.z_position < -500.0:
			car.z_position = -100.0 - _random.randf_range(0.0, 85.0)
			car.lane_index = _next_lane_index
			car.target_lane_index = _next_lane_index
			car.lateral_position = LANE_POSITIONS[_next_lane_index]
			car.previous_lateral_position = car.lateral_position
			car.passing_leader_index = -1
			car.return_lane_index = -1
			car.is_following = false
			car.speed_mps = car.cruise_speed_mps
			_next_lane_index = (_next_lane_index + 1) % LANE_POSITIONS.size()

	_prevent_traffic_overlap()
	return {
		"collided": collided,
		"collision_car_index": collision_car_index,
		"awarded_points": awarded_points,
	}


func _plan_lane_changes(player_x: float) -> void:
	for index in range(cars.size()):
		var car := cars[index]
		if car.target_lane_index != car.lane_index:
			continue
		if car.passing_leader_index >= 0:
			if car.passing_leader_index >= cars.size():
				car.passing_leader_index = -1
				car.return_lane_index = -1
				continue
			var passed_leader := cars[car.passing_leader_index]
			if (
				car.z_position <= passed_leader.z_position - PASS_RETURN_GAP
				and car.return_lane_index >= 0
				and _can_change_lane(index, car.return_lane_index, player_x)
			):
				car.target_lane_index = car.return_lane_index
			continue

		var leader_index := -1
		var closest_gap := INF
		for other_index in range(cars.size()):
			if other_index == index:
				continue
			var other := cars[other_index]
			if other.lane_index != car.lane_index:
				continue
			var gap := car.z_position - other.z_position
			if gap > 0.0 and gap < closest_gap:
				closest_gap = gap
				leader_index = other_index
		if leader_index < 0:
			continue

		var leader := cars[leader_index]
		var closing_speed := car.speed_mps - leader.speed_mps
		if (
			closing_speed <= 0.5
			or closest_gap > maxf(OVERTAKE_LOOKAHEAD_DISTANCE, closing_speed * 2.5 + 8.0)
		):
			continue
		for candidate_lane in [car.lane_index - 1, car.lane_index + 1]:
			if candidate_lane < 0 or candidate_lane >= LANE_POSITIONS.size():
				continue
			if _can_change_lane(index, candidate_lane, player_x):
				car.return_lane_index = car.lane_index
				car.passing_leader_index = leader_index
				car.target_lane_index = candidate_lane
				break


func _can_change_lane(car_index: int, target_lane: int, player_x: float) -> bool:
	var car := cars[car_index]
	var target_x: float = LANE_POSITIONS[target_lane]
	for other_index in range(cars.size()):
		if other_index == car_index:
			continue
		var other := cars[other_index]
		if other.lane_index != target_lane and other.target_lane_index != target_lane:
			continue
		var safe_gap := (
			LANE_CHANGE_CLEARANCE + (car.body_length + other.body_length) * 0.5
		)
		if absf(car.z_position - other.z_position) < safe_gap:
			return false

	var player_safe_gap := LANE_CHANGE_CLEARANCE + car.body_length * 0.5
	return not (
		absf(car.z_position) < player_safe_gap
		and absf(player_x - target_x) < PLAYER_HALF_WIDTH + car.body_width * 0.5
	)


func _apply_following_speeds() -> void:
	for car in cars:
		if car.is_following:
			car.speed_mps = car.cruise_speed_mps
			car.is_following = false

	for _iteration in range(cars.size()):
		for car_index in range(cars.size()):
			var car := cars[car_index]
			if car.target_lane_index != car.lane_index or car.passing_leader_index >= 0:
				continue
			var leader: TrafficCar = null
			var closest_gap := INF
			for other_index in range(cars.size()):
				if other_index == car_index:
					continue
				var other := cars[other_index]
				if other.lane_index != car.lane_index:
					continue
				var gap := car.z_position - other.z_position
				if gap > 0.0 and gap < closest_gap:
					closest_gap = gap
					leader = other
			if leader == null or closest_gap > FOLLOWING_DISTANCE:
				continue
			if car.speed_mps > leader.speed_mps:
				car.speed_mps = leader.speed_mps
				car.is_following = true


func _prevent_traffic_overlap() -> void:
	for first_index in range(cars.size()):
		var first := cars[first_index]
		for second_index in range(first_index + 1, cars.size()):
			var second := cars[second_index]
			var lateral_clearance := (
				(first.body_width + second.body_width) * 0.5 + 0.15
			)
			if absf(first.lateral_position - second.lateral_position) >= lateral_clearance:
				continue
			var front: TrafficCar = first if first.z_position < second.z_position else second
			var follower: TrafficCar = second if front == first else first
			var safe_gap := (
				(front.body_length + follower.body_length) * 0.5 + MINIMUM_TRAFFIC_GAP
			)
			if follower.z_position - front.z_position < safe_gap:
				follower.z_position = front.z_position + safe_gap
				follower.speed_mps = minf(follower.speed_mps, front.speed_mps)
				follower.is_following = true


func _overlap_time_range(start: float, movement: float, half_extent: float) -> Vector2:
	if is_zero_approx(movement):
		return Vector2(0.0, 1.0) if absf(start) <= half_extent else Vector2(1.0, 0.0)
	var first_contact := (-half_extent - start) / movement
	var last_contact := (half_extent - start) / movement
	return Vector2(
		maxf(0.0, minf(first_contact, last_contact)),
		minf(1.0, maxf(first_contact, last_contact))
	)


func lane_position(car_index: int) -> float:
	if car_index < 0 or car_index >= cars.size():
		push_error("Traffic car index is outside the active pool")
		return 0.0
	return cars[car_index].lateral_position
