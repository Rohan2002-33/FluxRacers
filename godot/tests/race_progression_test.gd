extends SceneTree

const SAVE_PATH := "user://race_progression_test.cfg"

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var race_scene_script := load("res://scripts/race_scene.gd") as Script
	_assert(race_scene_script != null, "The race scene script loads")
	if race_scene_script != null:
		var race_scene := race_scene_script.new() as Node3D
		var expected_mode := (
			RaceProgression.Mode.CAREER
			if OS.get_cmdline_user_args().has("--race-mode=career")
			else RaceProgression.Mode.QUICK_RACE
		)
		_assert(
			race_scene._requested_race_mode() == expected_mode,
			"The native race mode argument selects the correct gameplay mode"
		)
		race_scene.free()

	var absolute_save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(absolute_save_path):
		var remove_error := DirAccess.remove_absolute(absolute_save_path)
		_assert(remove_error == OK, "Old test progress is removed")

	var progression := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(progression.state == RaceProgression.State.COUNTDOWN, "Career begins with a countdown")
	_assert(progression.target_distance_m == 750.0, "Career starts at the first event distance")
	_assert(
		progression.event_name == "COASTAL SPRINT",
		"Career loads the correct first event name"
	)
	progression.advance(2.0, 0.0)
	_assert(progression.state == RaceProgression.State.COUNTDOWN, "Countdown lasts three seconds")
	progression.advance(1.0, 0.0)
	_assert(progression.state == RaceProgression.State.RACING, "Countdown starts the race")
	progression.advance(20.0, 750.0)
	_assert(progression.state == RaceProgression.State.FINISHED, "Career finishes at its target")
	_assert(progression.complete_race(), "Completing a career event saves its rewards")
	_assert(progression.complete_race(), "Repeating event completion is idempotent")
	_assert(progression.career_event_unlocked == 1, "Completing an event unlocks the next one")
	_assert(progression.credits == 350, "A new event record awards credits and a bonus")
	_assert(progression.is_personal_best, "The first completion is a personal best")

	var next_event := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(next_event.career_event_unlocked == 1, "Unlocked events persist across sessions")
	_assert(next_event.event_index == 1, "The next event keeps its own stable event index")
	_assert(next_event.credits == 350, "Credits persist across sessions")
	_assert(next_event.target_distance_m == 1500.0, "The next event has a distinct target")
	var saved_progress := ConfigFile.new()
	_assert(saved_progress.load(SAVE_PATH) == OK, "Career progress can be read back")
	_assert(
		float(saved_progress.get_value("career", "event_0_best", 0.0)) > 0.0,
		"The event record persists"
	)

	next_event.advance(3.0, 0.0)
	next_event.advance(30.0, 1500.0)
	_assert(next_event.complete_race(), "The second career event can be completed")
	_assert(next_event.career_event_unlocked == 2, "The second event unlocks the finale")
	_assert(next_event.event_index == 1, "Finishing does not change the displayed event")
	var finale := RaceProgression.new(RaceProgression.Mode.CAREER, SAVE_PATH)
	_assert(finale.event_name == "DESERT ENDURANCE", "Career reaches its final event")
	finale.advance(3.0, 0.0)
	finale.advance(40.0, 2500.0)
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
	var replay_progress := ConfigFile.new()
	_assert(replay_progress.load(SAVE_PATH) == OK, "Replayed career progress is persisted")
	_assert(
		int(replay_progress.get_value("career", "unlocked_event", -1)) == 0
			and int(replay_progress.get_value("career", "credits", 0)) == 1050
			and float(replay_progress.get_value("career", "event_0_best", 0.0)) > 0.0,
		"Replay resets only event unlocks and preserves rewards and records"
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

	var quick_race := RaceProgression.new(RaceProgression.Mode.QUICK_RACE, SAVE_PATH)
	quick_race.advance(3.0, 0.0)
	quick_race.advance(60.0, 10000.0)
	_assert(quick_race.state == RaceProgression.State.RACING, "Quick Race remains unlimited")
	_assert(not quick_race.complete_race(), "Quick Race does not award career rewards")

	if FileAccess.file_exists(absolute_save_path):
		var remove_error := DirAccess.remove_absolute(absolute_save_path)
		_assert(remove_error == OK, "Test progress is cleaned up")

	if _failed:
		quit(1)
	else:
		print("Godot race progression tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot race progression test failed: %s" % message)
		_failed = true
