class_name RaceTraffic
extends RefCounted

class TrafficCar:
	extends RefCounted

	var lane_index: int
	var z_position: float
	var speed_mps: float
	var previous_z_position: float

	func _init(start_lane: int, start_z: float, speed: float) -> void:
		lane_index = start_lane
		z_position = start_z
		speed_mps = speed
		previous_z_position = start_z


const LANE_POSITIONS := [-2.8, 0.0, 2.8]
const COLLISION_LATERAL_RANGE := 1.55
const COLLISION_LONGITUDINAL_RANGE := 3.2
const NEAR_MISS_LATERAL_RANGE := 2.8
const NEAR_MISS_POINTS := 50
const OVERTAKE_POINTS := 100

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
		cars.append(
			TrafficCar.new(
				lane_index,
				start_z,
				clampf(_base_speed_mps + speed_variation, 10.0, 60.0)
			)
		)
	_next_lane_index = car_count % LANE_POSITIONS.size()


func advance(delta: float, player_speed_mps: float, player_x: float) -> Dictionary:
	var collided := false
	var awarded_points := 0
	var collision_car_index := -1
	for index in range(cars.size()):
		var car := cars[index]
		car.previous_z_position = car.z_position
		car.z_position += (player_speed_mps - car.speed_mps) * delta
		var lateral_gap := absf(LANE_POSITIONS[car.lane_index] - player_x)
		if (
			absf(car.z_position) <= COLLISION_LONGITUDINAL_RANGE
			and lateral_gap < COLLISION_LATERAL_RANGE
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


func lane_position(car_index: int) -> float:
	if car_index < 0 or car_index >= cars.size():
		push_error("Traffic car index is outside the active pool")
		return 0.0
	return LANE_POSITIONS[cars[car_index].lane_index]
