extends SceneTree

const RACE_COMPETITION_SCRIPT := preload("res://scripts/race_competition.gd")
const MODEL_IDS := [
	"sport",
	"kenney_race_car",
	"kenney_sports_sedan",
	"kenney_suv",
	"kenney_luxury_suv",
]
const PAINTS := [
	Color("1689d2"),
	Color("e2e7e8"),
	Color("29a65a"),
	Color("e4b530"),
	Color("7a4ec5"),
]

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var competition = RACE_COMPETITION_SCRIPT.new()
	competition.configure(MODEL_IDS, PAINTS, 61.0, 120.0)
	_assert(
		competition.drivers.size() == 6
			and competition.standings.size() == 6,
		"A sprint grid contains one player and five AI rivals"
	)
	_assert(
		competition.player_place() == 4,
		"Three front-row rivals start ahead of the player on the grid"
	)
	_assert(
		competition.drivers[1].model_id == "sport"
			and competition.drivers[2].model_id == "kenney_race_car"
			and competition.drivers[3].model_id == "kenney_sports_sedan",
		"AI rivals use varied 3D car models"
	)

	var previous_time := 0.0
	for step in range(400):
		var elapsed := float(step + 1) * 0.1
		var player_distance := minf(132.0, elapsed * 55.0)
		competition.advance(0.1, player_distance, 55.0)
		if competition.all_finished():
			break
	_assert(competition.all_finished(), "Every driver finishes the point-to-point sprint")
	_assert(competition.player_finished(), "The player receives a recorded finish time")
	for index in range(competition.standings.size()):
		var driver = competition.standings[index]
		_assert(
			driver.finish_time_seconds >= 0.0,
			"Final standings only include drivers that crossed the finish line"
		)
		if index > 0:
			_assert(
				driver.finish_time_seconds >= previous_time,
				"Final classification sorts finishers by crossing time"
			)
		previous_time = driver.finish_time_seconds
	_assert(
		competition.player_reward_points() > 0,
		"Finishing place awards progression points"
	)

	var stationary_grid_competition = RACE_COMPETITION_SCRIPT.new()
	stationary_grid_competition.configure(MODEL_IDS, PAINTS, 61.0, 1200.0)
	for frame in range(180):
		stationary_grid_competition.advance(1.0 / 60.0, 0.0, 0.0)
	_assert(
		stationary_grid_competition.collision_driver_id == -1,
		"AI rivals keep a safe lane gap when the player waits at the starting grid"
	)

	var sprint_progression := RaceProgression.new(
		RaceProgression.Mode.COMPETITIVE_SPRINT,
		"user://competitive_sprint_progression_test.cfg"
	)
	_assert(
		sprint_progression.target_distance_m == 1200.0,
		"Competitive sprint progression exposes its fixed finish distance"
	)
	sprint_progression.advance(RaceProgression.COUNTDOWN_SECONDS, 0.0)
	sprint_progression.advance(1.0, sprint_progression.target_distance_m)
	_assert(
		sprint_progression.state == RaceProgression.State.FINISHED
			and sprint_progression.race_points == 1200,
		"Sprint progression finishes and scores at the finish line"
	)

	var race_scene_script := load("res://scripts/race_scene.gd") as Script
	_assert(race_scene_script != null, "The complete race scene script parses")
	if race_scene_script != null:
		var results_scene := race_scene_script.new() as Node3D
		var results_path := "user://competitive_sprint_results_test.cfg"
		results_scene._progression = RaceProgression.new(
			RaceProgression.Mode.COMPETITIVE_SPRINT,
			results_path
		)
		results_scene._progression.state = RaceProgression.State.FINISHED
		results_scene._competition = RACE_COMPETITION_SCRIPT.new()
		results_scene._competition.configure(MODEL_IDS, PAINTS, 61.0, 120.0)
		for driver_index in range(results_scene._competition.drivers.size()):
			results_scene._competition.drivers[driver_index].finish_time_seconds = (
				float(driver_index + 1)
			)
		results_scene._competition.call("_refresh_standings")
		results_scene._create_hud()
		results_scene._show_competitive_race_results()
		_assert(
			results_scene._race_overlay_title.text == "1ST PLACE"
				and results_scene._race_overlay_message.text.contains("FINAL ORDER"),
			"Sprint results render a classified six-driver finish"
		)
		results_scene.free()
		var results_absolute_path := ProjectSettings.globalize_path(results_path)
		if FileAccess.file_exists(results_absolute_path):
			DirAccess.remove_absolute(results_absolute_path)

	var collision_competition = RACE_COMPETITION_SCRIPT.new()
	collision_competition.configure(MODEL_IDS, PAINTS, 61.0, 120.0)
	var rival = collision_competition.drivers[1]
	rival.progress_m = 0.0
	rival.lane_index = 1
	rival.target_lane_index = 1
	rival.lateral_position = 0.0
	collision_competition.advance(0.016, 0.0, 0.0)
	_assert(
		collision_competition.collision_driver_id == rival.driver_id,
		"Close same-lane contact identifies the colliding AI rival"
	)

	var tied_competition = RACE_COMPETITION_SCRIPT.new()
	tied_competition.configure(MODEL_IDS, PAINTS, 61.0, 120.0)
	for driver in tied_competition.drivers:
		driver.progress_m = 0.0
	tied_competition.call("_refresh_standings")
	_assert(
		tied_competition.player_place() == 1,
		"Equal progress uses a stable deterministic player-first tie break"
	)

	if _failed:
		quit(1)
	else:
		print("Godot competitive sprint tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot competitive sprint test failed: %s" % message)
		_failed = true
