extends SceneTree

const SAVE_PATH := "user://race_progression_test.cfg"
const COLLISION_SAVE_PATH := "user://race_collision_progression_test.cfg"
const TIME_TRIAL_SAVE_PATH := "user://race_progression_time_trial_test.cfg"
const TIMEOUT_SAVE_PATH := "user://race_progression_timeout_test.cfg"

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var race_scene_script := load("res://scripts/race_scene.gd") as Script
	_assert(race_scene_script != null, "The race scene script loads")
	if race_scene_script != null:
		var race_scene := race_scene_script.new() as Node3D
		var expected_mode := RaceProgression.Mode.QUICK_RACE
		if OS.get_cmdline_user_args().has("--race-mode=career"):
			expected_mode = RaceProgression.Mode.CAREER
		elif OS.get_cmdline_user_args().has("--race-mode=competitiveSprint"):
			expected_mode = RaceProgression.Mode.COMPETITIVE_SPRINT
		elif OS.get_cmdline_user_args().has("--race-mode=timeTrial"):
			expected_mode = RaceProgression.Mode.TIME_TRIAL
		_assert(
			race_scene._requested_race_mode() == expected_mode,
			"The native race mode argument selects the correct gameplay mode"
		)
		race_scene.free()

	var absolute_save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(absolute_save_path):
		var remove_error := DirAccess.remove_absolute(absolute_save_path)
		_assert(remove_error == OK, "Old test progress is removed")
	for save_path in [TIME_TRIAL_SAVE_PATH, TIMEOUT_SAVE_PATH]:
		var stale_path := ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(stale_path):
			var stale_remove_error := DirAccess.remove_absolute(stale_path)
			_assert(stale_remove_error == OK, "Old time-trial test progress is removed")

	var progression := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(progression.state == RaceProgression.State.COUNTDOWN, "Career begins with a countdown")
	_assert(
		progression.target_distance_m == 2000.0,
		"Career starts with the 2 km opening event"
	)
	_assert(
		progression.event_name == "COASTAL SPRINT",
		"Career loads the correct first event name"
	)
	progression.advance(2.0, 0.0)
	_assert(progression.state == RaceProgression.State.COUNTDOWN, "Countdown lasts three seconds")
	progression.advance(1.0, 0.0)
	_assert(progression.state == RaceProgression.State.RACING, "Countdown starts the race")
	progression.advance(20.0, 2000.0)
	_assert(progression.state == RaceProgression.State.FINISHED, "Career finishes at its target")
	_assert(progression.race_points == 2000, "Career distance earns one point per meter")
	_assert(progression.complete_race(), "Completing a career event saves its rewards")
	_assert(progression.complete_race(), "Repeating event completion is idempotent")
	_assert(progression.career_event_unlocked == 1, "Completing an event unlocks the next one")
	_assert(progression.credits == 350, "A new event record awards credits and a bonus")
	_assert(progression.is_personal_best, "The first completion is a personal best")
	_assert(progression.total_points == 2000, "Race score is saved to the player profile")
	_assert(progression.experience == 2000, "Race score contributes to experience")
	_assert(progression.player_level == 3, "Career distance advances player levels")

	var sprint := RaceProgression.new(RaceProgression.Mode.COMPETITIVE_SPRINT, SAVE_PATH)
	_assert(
		sprint.target_distance_m == RaceProgression.COMPETITIVE_SPRINT_DISTANCE_M
			and sprint.target_distance_m == 3000.0
			and sprint.event_name == "GRID SPRINT",
		"Competitive sprint has a fixed 3 km point-to-point finish distance"
	)
	sprint.advance(RaceProgression.COUNTDOWN_SECONDS, 0.0)
	sprint.advance(20.0, sprint.target_distance_m)
	_assert(
		sprint.state == RaceProgression.State.FINISHED,
		"Competitive sprint progression stops at its finish distance"
	)

	var time_trial := RaceProgression.new(
		RaceProgression.Mode.TIME_TRIAL,
		TIME_TRIAL_SAVE_PATH
	)
	_assert(
		time_trial.target_distance_m == RaceProgression.TIME_TRIAL_DISTANCE_M
			and time_trial.target_distance_m == 3000.0
			and time_trial.event_name == "GHOST TIME TRIAL"
			and RaceProgression.TIME_TRIAL_TIME_LIMIT_SECONDS == 75.0,
		"Ghost time trial sets a 3 km finish and achievable 75-second time limit"
	)
	_assert(
		is_equal_approx(
			time_trial.time_trial_seconds_remaining(),
			RaceProgression.TIME_TRIAL_TIME_LIMIT_SECONDS
		),
		"The time-trial timer begins at its full limit after the countdown"
	)
	time_trial.advance(RaceProgression.COUNTDOWN_SECONDS, 0.0)
	time_trial.advance(RaceProgression.TIME_TRIAL_TIME_LIMIT_SECONDS - 0.1, 2999.0)
	_assert(
		time_trial.state == RaceProgression.State.RACING
			and is_equal_approx(time_trial.time_trial_seconds_remaining(), 0.1),
		"A racer can reach the final meters with time remaining"
	)
	time_trial.advance(0.1, time_trial.target_distance_m)
	_assert(
		time_trial.state == RaceProgression.State.FINISHED,
		"Crossing the finish exactly at the deadline is a win"
	)
	_assert(
		is_equal_approx(time_trial.time_trial_seconds_remaining(), 0.0),
		"A completed time trial has no remaining time"
	)
	for build_id in ["street", "sprint", "grip"]:
		var test_vehicle := RaceVehicleModel.new()
		test_vehicle.configure(build_id)
		var simulated_trial := RaceProgression.new(
			RaceProgression.Mode.TIME_TRIAL,
			TIME_TRIAL_SAVE_PATH
		)
		simulated_trial.advance(RaceProgression.COUNTDOWN_SECONDS, 0.0)
		while simulated_trial.state == RaceProgression.State.RACING:
			test_vehicle.update(1.0 / 60.0, true, false, 0.0)
			simulated_trial.advance(1.0 / 60.0, test_vehicle.distance_m)
		_assert(
			simulated_trial.state == RaceProgression.State.FINISHED
				and simulated_trial.race_time_seconds
				< RaceProgression.TIME_TRIAL_TIME_LIMIT_SECONDS,
			"Full-throttle %s build can finish before the time-trial deadline" % build_id
		)
	_assert(time_trial.record_race(), "Time-trial race score can be recorded")
	_assert(
		time_trial.record_race(),
		"Recording a completed time-trial score is idempotent"
	)
	var expired_trial := RaceProgression.new(
		RaceProgression.Mode.TIME_TRIAL,
		TIMEOUT_SAVE_PATH
	)
	expired_trial.advance(RaceProgression.COUNTDOWN_SECONDS, 0.0)
	expired_trial.advance(RaceProgression.TIME_TRIAL_TIME_LIMIT_SECONDS, 2999.0)
	_assert(
		expired_trial.state == RaceProgression.State.GAME_OVER
			and expired_trial.race_time_seconds == RaceProgression.TIME_TRIAL_TIME_LIMIT_SECONDS
			and expired_trial.time_trial_seconds_remaining() == 0.0,
		"Failing to reach 3 km before the deadline ends the race"
	)
	expired_trial.advance(10.0, 3000.0)
	_assert(
		expired_trial.state == RaceProgression.State.GAME_OVER,
		"A timed-out run cannot finish after game over"
	)
	var timeout_scene := race_scene_script.new() as Node3D
	timeout_scene._progression = expired_trial
	timeout_scene._vehicle.distance_m = 2999.0
	timeout_scene._create_hud()
	timeout_scene._finish_time_trial_timeout()
	_assert(
		timeout_scene._race_overlay.visible
			and timeout_scene._race_overlay_title.text == "GAME OVER"
			and timeout_scene._race_overlay_message.text.contains("TIME UP"),
		"Time expiry displays clear game-over results"
	)
	var timeout_retry_button := timeout_scene._race_overlay_actions.get_child(0) as Button
	_assert(
		timeout_scene._race_overlay_actions.get_child_count() == 2
			and timeout_retry_button != null
			and timeout_retry_button.text == "TRY AGAIN",
		"Time expiry offers retry and main-menu actions"
	)
	timeout_scene.free()

	var next_event := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(next_event.career_event_unlocked == 1, "Unlocked events persist across sessions")
	_assert(next_event.event_index == 1, "The next event keeps its own stable event index")
	_assert(next_event.credits == 350, "Credits persist across sessions")
	_assert(next_event.target_distance_m == 4000.0, "The next career event is 4 km long")
	var saved_progress := ConfigFile.new()
	_assert(saved_progress.load(SAVE_PATH) == OK, "Career progress can be read back")
	_assert(
		float(saved_progress.get_value("career", "event_0_best", 0.0)) > 0.0,
		"The event record persists"
	)

	next_event.advance(3.0, 0.0)
	next_event.advance(30.0, 4000.0)
	_assert(next_event.complete_race(), "The second career event can be completed")
	_assert(next_event.career_event_unlocked == 2, "The second event unlocks the finale")
	_assert(next_event.event_index == 1, "Finishing does not change the displayed event")
	var finale := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(finale.event_name == "DESERT ENDURANCE", "Career reaches its final event")
	finale.advance(3.0, 0.0)
	finale.advance(40.0, 6000.0)
	var completion_scene := race_scene_script.new() as Node3D
	completion_scene._progression = finale
	completion_scene._create_hud()
	completion_scene._finish_career_race()
	_assert(
		completion_scene._race_overlay_title.text == "CAREER COMPLETE",
		"Finishing the final event immediately displays career completion"
	)
	var replay_button := completion_scene._race_overlay_actions.get_child(0) as Button
	_assert(
		completion_scene._race_overlay_actions.get_child_count() == 2
			and replay_button != null
			and replay_button.text == "REPLAY CAREER",
		"Career completion offers replay and main-menu actions"
	)
	completion_scene.free()
	_assert(finale.career_complete, "Completing the final event finishes the current career")
	var completed_career := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(completed_career.career_complete, "Completing all events finishes the career")
	_assert(
		completed_career.state == RaceProgression.State.FINISHED,
		"A completed career cannot start another event"
	)
	_assert(completed_career.restart_career(), "A completed career can be replayed")
	_assert(
		completed_career.state == RaceProgression.State.COUNTDOWN
			and completed_career.event_index == 0,
		"Replaying career starts at the first event"
	)
	_assert(completed_career.credits == 1050, "Replaying career retains earned credits")
	_assert(completed_career.total_points == 12000, "Career score persists across all events")
	_assert(completed_career.player_level == 13, "Accumulated experience advances player levels")
	var replay_progress := ConfigFile.new()
	_assert(replay_progress.load(SAVE_PATH) == OK, "Replayed career progress is persisted")
	_assert(
		int(replay_progress.get_value("career", "unlocked_event", -1)) == 0
			and int(replay_progress.get_value("career", "credits", 0)) == 1050
			and int(replay_progress.get_value("career", "total_points", 0)) == 12000
			and float(replay_progress.get_value("career", "event_0_best", 0.0)) > 0.0,
		"Replay resets event unlocks and preserves rewards, score, and records"
	)

	var results_scene := race_scene_script.new() as Node3D
	results_scene._progression = progression
	results_scene._create_hud()
	results_scene._finish_career_race()
	_assert(results_scene._race_overlay.visible, "A finished event displays its results")
	_assert(
		results_scene._race_overlay_title.text == "EVENT COMPLETE",
		"Career results have a clear completion state"
	)
	results_scene._update_hud(0.1)
	_assert(
		results_scene._race_info_label.text.begins_with("EVENT 01  COASTAL SPRINT"),
		"Finishing an event keeps its title and goal stable"
	)
	results_scene.free()

	var collision_race_scene := race_scene_script.new() as Node3D
	var collision_progression := RaceProgression.new(
		RaceProgression.Mode.CAREER,
		COLLISION_SAVE_PATH
	)
	collision_progression.state = RaceProgression.State.RACING
	collision_progression.target_distance_m = 0.0
	collision_race_scene._progression = collision_progression
	collision_race_scene._traffic.configure(1, 20.0, 91)
	collision_race_scene._vehicle.lateral_position = collision_race_scene._traffic.lane_position(0)
	var collision_car: RaceTraffic.TrafficCar = collision_race_scene._traffic.cars[0]
	collision_car.z_position = 0.0
	collision_car.previous_z_position = 0.0
	collision_race_scene._create_hud()
	collision_race_scene._create_camera()
	var body_batch := _make_traffic_test_batch()
	var detail_batch := _make_traffic_test_batch()
	collision_race_scene.add_child(body_batch)
	collision_race_scene.add_child(detail_batch)
	collision_race_scene._traffic_model_batches["sedan"] = {
		"traffic_indices": [0],
		"body": body_batch,
		"details": detail_batch,
	}
	collision_race_scene._race_initialized = true
	collision_race_scene._process(0.016)
	collision_race_scene._physics_process(0.016)
	_assert(
		collision_progression.state == RaceProgression.State.GAME_OVER
			and collision_progression.career_event_unlocked == 0
			and not collision_progression.complete_race(),
		"A collision on the career finish frame ends the race without unlocking the next event"
	)
	_assert(
		collision_race_scene._race_overlay_title.text == "RACE OVER",
		"A career collision takes precedence over event completion"
	)
	collision_race_scene.free()
	if FileAccess.file_exists(ProjectSettings.globalize_path(COLLISION_SAVE_PATH)):
		var remove_collision_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(COLLISION_SAVE_PATH)
		)
		_assert(remove_collision_error == OK, "Career collision test progress is cleaned up")

	var clean_finish_scene := race_scene_script.new() as Node3D
	var clean_finish_progression := RaceProgression.new(
		RaceProgression.Mode.CAREER,
		COLLISION_SAVE_PATH
	)
	clean_finish_progression.state = RaceProgression.State.RACING
	clean_finish_progression.target_distance_m = 0.0
	clean_finish_scene._progression = clean_finish_progression
	clean_finish_scene._create_hud()
	clean_finish_scene._create_camera()
	clean_finish_scene._race_initialized = true
	clean_finish_scene._process(0.016)
	clean_finish_scene._physics_process(0.016)
	_assert(
		clean_finish_progression.state == RaceProgression.State.FINISHED
			and clean_finish_progression.career_event_unlocked == 1
			and clean_finish_scene._race_overlay_title.text == "EVENT COMPLETE",
		"A clean career finish still completes and unlocks the next event"
	)
	clean_finish_scene.free()
	if FileAccess.file_exists(ProjectSettings.globalize_path(COLLISION_SAVE_PATH)):
		var remove_finish_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(COLLISION_SAVE_PATH)
		)
		_assert(remove_finish_error == OK, "Career finish test progress is cleaned up")

	var quick_race := RaceProgression.new(RaceProgression.Mode.QUICK_RACE, SAVE_PATH)
	quick_race.advance(3.0, 0.0)
	quick_race.advance(5.0, 400.0)
	_assert(quick_race.state == RaceProgression.State.RACING, "Quick Race remains unlimited")
	_assert(not quick_race.complete_race(), "Quick Race does not award career rewards")
	quick_race.update_distance_score(400.0)
	quick_race.award_points(150)
	quick_race.finish_with_collision()
	_assert(quick_race.state == RaceProgression.State.GAME_OVER, "A collision ends the current race")
	_assert(quick_race.record_race(), "A collision result persists earned points")
	_assert(quick_race.record_race(), "Recording a result is idempotent")
	var saved_profile := RaceProgression.new(RaceProgression.Mode.QUICK_RACE, SAVE_PATH)
	_assert(saved_profile.total_points == 12550, "Collision score adds to the persistent profile")
	_assert(saved_profile.player_level == 13, "Collision score contributes to level progress")

	var collision_scene := race_scene_script.new() as Node3D
	collision_scene._progression = RaceProgression.new(
		RaceProgression.Mode.QUICK_RACE,
		SAVE_PATH
	)
	collision_scene._vehicle_model_ready = true
	collision_scene._create_hud()
	collision_scene._race_initialized = true
	collision_scene._process(3.1)
	_assert(
		collision_scene._race_overlay.visible
			and collision_scene._race_overlay_title.text == "GO!",
		"The race countdown shows the GO prompt"
	)
	collision_scene._process(0.5)
	collision_scene._process(0.3)
	_assert(not collision_scene._race_overlay.visible, "The GO prompt clears during racing")
	collision_scene._finish_collision_race()
	_assert(
		collision_scene._race_overlay.visible
			and collision_scene._race_overlay_title.text == "RACE OVER",
		"A collision result remains visible after the countdown prompt clears"
	)
	collision_scene.free()

	if FileAccess.file_exists(absolute_save_path):
		var remove_error := DirAccess.remove_absolute(absolute_save_path)
		_assert(remove_error == OK, "Test progress is cleaned up")
	for save_path in [TIME_TRIAL_SAVE_PATH, TIMEOUT_SAVE_PATH]:
		var stale_path := ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(stale_path):
			var stale_remove_error := DirAccess.remove_absolute(stale_path)
			_assert(stale_remove_error == OK, "Time-trial test progress is cleaned up")

	if _failed:
		quit(1)
	else:
		print("Godot race progression tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot race progression test failed: %s" % message)
		_failed = true


func _make_traffic_test_batch() -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = 1
	batch.multimesh = multimesh
	return batch
