extends SceneTree

const GHOST_SCRIPT := preload("res://scripts/race_ghost.gd")
const SAVE_PATH := "user://race_ghost_test.cfg"
const CORRUPT_SAVE_PATH := "user://race_ghost_corrupt_test.cfg"

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_remove_test_save(SAVE_PATH)
	_remove_test_save(CORRUPT_SAVE_PATH)

	var ghost: RefCounted = GHOST_SCRIPT.new()
	_assert(not ghost.load_best(SAVE_PATH), "A missing ghost is treated as no prior record")
	ghost.start_run()
	for sample_index in range(11):
		var elapsed_seconds := float(sample_index) / 10.0
		ghost.record_sample(elapsed_seconds, elapsed_seconds * 300.0, elapsed_seconds)
	_assert(
		ghost.save_run_if_best(1.0, 300.0, 1.0, SAVE_PATH),
		"A completed run saves its first personal best"
	)
	_assert(is_equal_approx(ghost.best_time_seconds, 1.0), "The saved record keeps its time")

	var restored: RefCounted = GHOST_SCRIPT.new()
	_assert(restored.load_best(SAVE_PATH), "The saved ghost loads in a later session")
	var interpolated_position: Vector2 = restored.playback_position(0.05)
	_assert(
		is_equal_approx(interpolated_position.x, 15.0)
			and is_equal_approx(interpolated_position.y, 0.05),
		"Ghost playback interpolates distance and lane position"
	)

	var slower_run: RefCounted = GHOST_SCRIPT.new()
	slower_run.start_run()
	for sample_index in range(13):
		var elapsed_seconds := float(sample_index) / 10.0
		slower_run.record_sample(elapsed_seconds, elapsed_seconds * 250.0, 0.0)
	_assert(
		not slower_run.save_run_if_best(1.2, 300.0, 0.0, SAVE_PATH),
		"A slower run cannot overwrite a stored personal best"
	)
	var persisted := ConfigFile.new()
	_assert(persisted.load(SAVE_PATH) == OK, "The prior best remains readable")
	_assert(
		is_equal_approx(float(persisted.get_value("time_trial", "best_time_seconds", 0.0)), 1.0),
		"A slower run preserves the faster saved record"
	)

	var corrupt := ConfigFile.new()
	corrupt.set_value("time_trial", "best_time_seconds", 1.0)
	corrupt.set_value("time_trial", "samples", PackedFloat32Array([0.0, 0.0, 1.0, 1.0]))
	_assert(corrupt.save(CORRUPT_SAVE_PATH) == OK, "The malformed test fixture is written")
	var invalid_ghost: RefCounted = GHOST_SCRIPT.new()
	_assert(not invalid_ghost.load_best(CORRUPT_SAVE_PATH), "Malformed sample data is rejected")
	_assert(invalid_ghost.persistence_error != "", "Invalid data exposes a persistence error")

	_remove_test_save(SAVE_PATH)
	_remove_test_save(CORRUPT_SAVE_PATH)
	if _failed:
		quit(1)
	else:
		print("Race ghost tests passed")
		quit(0)


func _remove_test_save(save_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		_assert(remove_error == OK, "A previous test file is removed")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	printerr("FAIL: " + message)
