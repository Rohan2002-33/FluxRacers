class_name RaceCompetition
extends RefCounted

const TRAFFIC_MODELS := preload("res://scripts/race_traffic_models.gd")

class Driver:
	extends RefCounted

	var driver_id: int
	var display_name: String
	var model_id: String
	var paint_color: Color
	var is_player: bool
	var lane_index: int
	var target_lane_index: int
	var lateral_position: float
	var progress_m: float
	var speed_mps: float
	var target_speed_mps: float
	var acceleration_mps2: float
	var finish_time_seconds := -1.0

	func _init(
		start_id: int,
		start_name: String,
		start_model_id: String,
		start_paint: Color,
		player_controlled: bool,
		start_lane: int,
		start_progress: float,
		max_speed_mps: float
	) -> void:
		driver_id = start_id
		display_name = start_name
		model_id = start_model_id
		paint_color = start_paint
		is_player = player_controlled
		lane_index = start_lane
		target_lane_index = start_lane
		lateral_position = RaceCompetition.LANE_POSITIONS[start_lane]
		progress_m = start_progress
		target_speed_mps = max_speed_mps


const LANE_POSITIONS := [-2.8, 0.0, 2.8]
const DRIVER_NAMES := ["NOVA", "APEX", "RUSH", "VOLT", "BLAZE"]
const GRID_PROGRESS_M := [8.0, 8.0, 8.0, -8.0, -8.0]
const GRID_LANES := [0, 1, 2, 0, 2]
const RIVAL_SPEED_FACTORS := [0.90, 0.95, 0.98, 1.02, 1.05]
const PLAYER_ID := 0
const FINISH_REWARDS := [500, 350, 250, 175, 125, 100]
const OVERTAKE_LOOKAHEAD_M := 22.0
const LANE_CLEARANCE_M := 20.0
const LANE_CHANGE_SPEED := 3.2
const LANE_CHANGE_DURATION_S := 0.9
const PLAYER_LENGTH_M := 4.2

var drivers: Array[Driver] = []
var standings: Array[Driver] = []
var finish_distance_m := 0.0
var race_time_seconds := 0.0
var collision_driver_id := -1


func configure(
	model_ids: Array,
	paint_colors: Array,
	player_max_speed_mps: float,
	race_distance_m: float
) -> void:
	drivers.clear()
	standings.clear()
	finish_distance_m = maxf(1.0, race_distance_m)
	race_time_seconds = 0.0
	collision_driver_id = -1
	drivers.append(
		Driver.new(
			PLAYER_ID,
			"YOU",
			"player",
			Color.WHITE,
			true,
			1,
			0.0,
			player_max_speed_mps
		)
	)

	var rival_count: int = mini(
		DRIVER_NAMES.size(),
		mini(model_ids.size(), paint_colors.size())
	)
	if rival_count != 5:
		push_error("A competitive sprint requires exactly five AI rivals")
		return

	for rival_index in range(rival_count):
		var rival_paint: Color = paint_colors[rival_index]
		var rival := Driver.new(
			rival_index + 1,
			DRIVER_NAMES[rival_index],
			str(model_ids[rival_index]),
			rival_paint,
			false,
			GRID_LANES[rival_index],
			GRID_PROGRESS_M[rival_index],
			player_max_speed_mps
		)
		rival.target_speed_mps *= RIVAL_SPEED_FACTORS[rival_index]
		rival.acceleration_mps2 = 7.4 + float(rival_index % 3) * 0.7
		drivers.append(rival)
	_refresh_standings()


func advance(
	delta: float,
	player_distance_m: float,
	player_speed_mps: float,
	player_lateral_position: float = 0.0
) -> void:
	if delta <= 0.0 or all_finished():
		return
	race_time_seconds += delta
	var player := drivers[PLAYER_ID]
	player.progress_m = maxf(player.progress_m, player_distance_m)
	player.lateral_position = player_lateral_position
	player.speed_mps = maxf(0.0, player_speed_mps)
	player.lane_index = _nearest_lane(player_lateral_position)
	player.target_lane_index = player.lane_index
	if player.progress_m >= finish_distance_m and player.finish_time_seconds < 0.0:
		player.finish_time_seconds = _crossing_time(
			player.progress_m,
			player_speed_mps
		)

	_plan_rival_lane_changes()
	for driver_index in range(1, drivers.size()):
		var rival := drivers[driver_index]
		rival.speed_mps = move_toward(
			rival.speed_mps,
			rival.target_speed_mps,
			rival.acceleration_mps2 * delta
		)
		rival.progress_m += rival.speed_mps * delta
		rival.lateral_position = move_toward(
			rival.lateral_position,
			LANE_POSITIONS[rival.target_lane_index],
			LANE_CHANGE_SPEED * delta
		)
		if (
			is_equal_approx(
				rival.lateral_position,
				LANE_POSITIONS[rival.target_lane_index]
			)
		):
			rival.lane_index = rival.target_lane_index
		if rival.progress_m >= finish_distance_m and rival.finish_time_seconds < 0.0:
			rival.finish_time_seconds = _crossing_time(
				rival.progress_m,
				rival.speed_mps
			)
		_check_player_collision(rival)
	_refresh_standings()


func record_player_finish(
	player_distance_m: float,
	player_speed_mps: float,
	finish_time_seconds: float
) -> void:
	var player := drivers[PLAYER_ID]
	player.progress_m = maxf(player.progress_m, player_distance_m)
	if player.finish_time_seconds < 0.0:
		race_time_seconds = maxf(race_time_seconds, finish_time_seconds)
		player.finish_time_seconds = _crossing_time(
			player.progress_m,
			player_speed_mps
		)
	_refresh_standings()


func _plan_rival_lane_changes() -> void:
	for driver_index in range(1, drivers.size()):
		var rival := drivers[driver_index]
		if rival.target_lane_index != rival.lane_index:
			continue
		var blocked_ahead := false
		for other in drivers:
			if (
				other == rival
				or other.target_lane_index != rival.lane_index
				or other.progress_m <= rival.progress_m
			):
				continue
			if other.progress_m - rival.progress_m <= OVERTAKE_LOOKAHEAD_M:
				blocked_ahead = true
				break
		if not blocked_ahead:
			continue
		for lane_offset in [-1, 1]:
			var candidate_lane: int = rival.lane_index + int(lane_offset)
			if candidate_lane < 0 or candidate_lane >= LANE_POSITIONS.size():
				continue
			if _lane_is_clear(candidate_lane, rival.progress_m, rival):
				rival.target_lane_index = candidate_lane
				break


func _lane_is_clear(lane_index: int, progress_m: float, except_driver: Driver) -> bool:
	for other in drivers:
		if other == except_driver or other.target_lane_index != lane_index:
			continue
		var other_length_m := (
			PLAYER_LENGTH_M
			if other.is_player
			else float(TRAFFIC_MODELS.get_spec(other.model_id)["length"])
		)
		var changing_length_m := (
			PLAYER_LENGTH_M
			if except_driver.is_player
			else float(TRAFFIC_MODELS.get_spec(except_driver.model_id)["length"])
		)
		var relative_speed_mps := absf(other.speed_mps - except_driver.speed_mps)
		var relative_acceleration_mps2 := absf(
			other.acceleration_mps2 - except_driver.acceleration_mps2
		)
		var transition_closure_m := (
			relative_speed_mps * LANE_CHANGE_DURATION_S
			+ 0.5 * relative_acceleration_mps2 * pow(LANE_CHANGE_DURATION_S, 2.0)
		)
		var vehicle_clearance_m := (
			(other_length_m + changing_length_m) * 0.5 + 6.0
		)
		var required_gap_m := maxf(
			LANE_CLEARANCE_M,
			transition_closure_m + vehicle_clearance_m
		)
		if absf(other.progress_m - progress_m) < required_gap_m:
			return false
	return true


func _nearest_lane(lateral_position: float) -> int:
	var nearest_lane := 0
	var nearest_distance := INF
	for lane_index in range(LANE_POSITIONS.size()):
		var lane_distance := absf(LANE_POSITIONS[lane_index] - lateral_position)
		if lane_distance < nearest_distance:
			nearest_distance = lane_distance
			nearest_lane = lane_index
	return nearest_lane


func _crossing_time(progress_m: float, speed_mps: float) -> float:
	if speed_mps <= 0.0:
		return race_time_seconds
	var distance_past_line := maxf(0.0, progress_m - finish_distance_m)
	return maxf(0.0, race_time_seconds - distance_past_line / speed_mps)


func _check_player_collision(rival: Driver) -> void:
	if collision_driver_id >= 0:
		return
	var model_spec: Dictionary = TRAFFIC_MODELS.get_spec(rival.model_id)
	var longitudinal_clearance: float = PLAYER_LENGTH_M * 0.5 + float(model_spec["length"]) * 0.5
	var lateral_clearance: float = 0.95 + float(model_spec["width"]) * 0.5
	if (
		absf(rival.progress_m - drivers[PLAYER_ID].progress_m) <= longitudinal_clearance
		and absf(rival.lateral_position - drivers[PLAYER_ID].lateral_position)
			<= lateral_clearance
	):
		collision_driver_id = rival.driver_id


func _refresh_standings() -> void:
	standings = drivers.duplicate()
	standings.sort_custom(_is_ahead)


func _is_ahead(first: Driver, second: Driver) -> bool:
	var first_finished := first.finish_time_seconds >= 0.0
	var second_finished := second.finish_time_seconds >= 0.0
	if first_finished != second_finished:
		return first_finished
	if first_finished and not is_equal_approx(first.finish_time_seconds, second.finish_time_seconds):
		return first.finish_time_seconds < second.finish_time_seconds
	if not is_equal_approx(first.progress_m, second.progress_m):
		return first.progress_m > second.progress_m
	return first.driver_id < second.driver_id


func player_place() -> int:
	for index in range(standings.size()):
		if standings[index].is_player:
			return index + 1
	return 0


func player_finished() -> bool:
	return drivers.size() > PLAYER_ID and drivers[PLAYER_ID].finish_time_seconds >= 0.0


func all_finished() -> bool:
	if drivers.is_empty():
		return false
	for driver in drivers:
		if driver.finish_time_seconds < 0.0:
			return false
	return true


func player_reward_points() -> int:
	var place := player_place()
	if place <= 0 or place > FINISH_REWARDS.size():
		return 0
	return FINISH_REWARDS[place - 1]


func player_gap_to_leader_m() -> float:
	if standings.is_empty() or standings[0].is_player:
		return 0.0
	return maxf(0.0, standings[0].progress_m - drivers[PLAYER_ID].progress_m)
