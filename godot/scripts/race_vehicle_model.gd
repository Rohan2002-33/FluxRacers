class_name RaceVehicleModel
extends RefCounted

const MAX_SPEED_KMH := 220.0
const MAX_SPEED_MPS := MAX_SPEED_KMH / 3.6
const ENGINE_ACCELERATION_MPS2 := 8.0
const BRAKING_MPS2 := 22.0
const COAST_DECELERATION_MPS2 := 1.8
const MAX_LATERAL_OFFSET := 4.1

var speed_mps := 0.0
var distance_m := 0.0
var lateral_position := 0.0
var max_speed_kmh := MAX_SPEED_KMH
var engine_acceleration_mps2 := ENGINE_ACCELERATION_MPS2
var handling_multiplier := 1.0


var speed_kmh: float:
	get:
		return speed_mps * 3.6


func configure(build_id: String) -> void:
	match build_id:
		"sprint":
			max_speed_kmh = 250.0
			engine_acceleration_mps2 = 10.0
			handling_multiplier = 0.9
		"grip":
			max_speed_kmh = 205.0
			engine_acceleration_mps2 = 7.5
			handling_multiplier = 1.2
		"street":
			max_speed_kmh = MAX_SPEED_KMH
			engine_acceleration_mps2 = ENGINE_ACCELERATION_MPS2
			handling_multiplier = 1.0
		_:
			push_error("Unknown vehicle build: %s" % build_id)


func update(delta: float, accelerating: bool, braking: bool, steering: float) -> void:
	if delta <= 0.0:
		return

	if braking:
		speed_mps = maxf(0.0, speed_mps - BRAKING_MPS2 * delta)
	elif accelerating:
		speed_mps = minf(max_speed_kmh / 3.6, speed_mps + engine_acceleration_mps2 * delta)
	else:
		speed_mps = maxf(0.0, speed_mps - COAST_DECELERATION_MPS2 * delta)

	if speed_mps > 0.1:
		var steer_rate := (1.4 + (speed_mps / MAX_SPEED_MPS) * 4.0) * handling_multiplier
		lateral_position = clampf(
			lateral_position + clampf(steering, -1.0, 1.0) * steer_rate * delta,
			-MAX_LATERAL_OFFSET,
			MAX_LATERAL_OFFSET
		)

	distance_m += speed_mps * delta
