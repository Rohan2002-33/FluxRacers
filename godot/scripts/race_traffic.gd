class_name RaceTraffic
extends RefCounted

const TRAFFIC_MODEL_GENERATOR := preload("res://scripts/race_traffic_models.gd")

class TrafficCar:
	extends RefCounted

	var lane_index: int
	var z_position: float
	var speed_mps: float
	var previous_z_position: float
	var model_id: String
	var paint_color: Color
	var body_width: float
	var body_length: float

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
		z_position = start_z
		speed_mps = speed
		previous_z_position = start_z
		model_id = start_model_id
		paint_color = start_paint_color
		body_width = width
		body_length = length


const LANE_POSITIONS := [-2.8, 0.0, 2.8]
const PLAYER_HALF_WIDTH := 0.95
const PLAYER_HALF_LENGTH := 2.1
const NEAR_MISS_LATERAL_RANGE := 2.8
const NEAR_MISS_POINTS := 50
const OVERTAKE_POINTS := 100
const TRAFFIC_MODEL_IDS := ["sedan", "box_truck", "sport", "pickup", "suv", "sedan"]
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
	var car_count := clampi(density, 1, 3) * 2
	for index in range(car_count):
		var lane_index := index % LANE_POSITIONS.size()
		var start_z := -95.0 - float(index) * 62.0
		var speed_variation := _random.randf_range(-4.0, 4.0)
		var model_id: String = TRAFFIC_MODEL_IDS[index % TRAFFIC_MODEL_IDS.size()]
		var color_index := (
			index + _random.randi_range(0, TRAFFIC_PAINT_COLORS.size() - 1)
		) % TRAFFIC_PAINT_COLORS.size()
		if index > 0 and TRAFFIC_PAINT_COLORS[color_index] == cars[index - 1].paint_color:
			color_index = (color_index + 1) % TRAFFIC_PAINT_COLORS.size()
		var model_spec: Dictionary = TRAFFIC_MODEL_GENERATOR.get_spec(model_id)
		cars.append(
			TrafficCar.new(
				lane_index,
				start_z,
				clampf(_base_speed_mps + speed_variation, 10.0, 60.0),
				model_id,
				TRAFFIC_PAINT_COLORS[color_index],
				float(model_spec["width"]),
				float(model_spec["length"])
			)
		)
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
	for index in range(cars.size()):
		var car := cars[index]
		car.previous_z_position = car.z_position
		car.z_position += (player_speed_mps - car.speed_mps) * delta
		var longitudinal_overlap := _overlap_time_range(
			car.previous_z_position,
			car.z_position - car.previous_z_position,
			PLAYER_HALF_LENGTH + car.body_length * 0.5
		)
		var lateral_overlap := _overlap_time_range(
			LANE_POSITIONS[car.lane_index] - previous_player_x,
			previous_player_x - player_x,
			PLAYER_HALF_WIDTH + car.body_width * 0.5
		)
		var lateral_gap := absf(LANE_POSITIONS[car.lane_index] - player_x)
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

		if car.z_position > 18.0 or car.z_position < -380.0:
			car.z_position = -100.0 - _random.randf_range(0.0, 85.0)
			car.lane_index = _next_lane_index
			_next_lane_index = (_next_lane_index + 1) % LANE_POSITIONS.size()

	return {
		"collided": collided,
		"collision_car_index": collision_car_index,
		"awarded_points": awarded_points,
	}


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
	return LANE_POSITIONS[cars[car_index].lane_index]
