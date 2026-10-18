class_name RaceGhost
extends RefCounted

const SAMPLE_INTERVAL_SECONDS := 0.1
const DEFAULT_SAVE_PATH := "user://time_trial_ghost.cfg"
const DATA_SECTION := "time_trial"
const BEST_TIME_KEY := "best_time_seconds"
const SAMPLES_KEY := "samples"
const SAMPLE_STRIDE := 3

var best_time_seconds := 0.0
var _best_samples := PackedFloat32Array()
var _run_samples := PackedFloat32Array()
var _next_sample_time := 0.0
var _playback_sample_index := 0
var persistence_error := ""


func load_best(save_path := DEFAULT_SAVE_PATH) -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(save_path)
	if load_error == ERR_FILE_NOT_FOUND:
		return false
	if load_error != OK:
		return _set_error("Could not load the time-trial ghost", load_error)

	var saved_time: Variant = config.get_value(DATA_SECTION, BEST_TIME_KEY, null)
	var saved_samples: Variant = config.get_value(DATA_SECTION, SAMPLES_KEY, null)
	if (
		not saved_time is float
		and not saved_time is int
	) or not saved_samples is PackedFloat32Array:
		return _set_error("Saved time-trial ghost data is invalid")
	var validated_samples := _validate_samples(saved_samples)
	if (
		not is_finite(float(saved_time))
		or float(saved_time) <= 0.0
		or validated_samples.is_empty()
		or float(validated_samples[-SAMPLE_STRIDE]) <= 0.0
	):
		return _set_error("Saved time-trial ghost samples are invalid")

	best_time_seconds = float(saved_time)
	_best_samples = validated_samples
	_playback_sample_index = 0
	persistence_error = ""
	return true


func start_run() -> void:
	_run_samples.clear()
	_next_sample_time = 0.0


func record_sample(elapsed_seconds: float, distance_m: float, lateral_position: float) -> void:
	if (
		not is_finite(elapsed_seconds)
		or not is_finite(distance_m)
		or not is_finite(lateral_position)
		or elapsed_seconds < 0.0
		or distance_m < 0.0
		or lateral_position < -12.0
		or lateral_position > 12.0
		or elapsed_seconds + 0.0001 < _next_sample_time
	):
		return
	var sample_count := _run_samples.size() / SAMPLE_STRIDE
	if sample_count > 0 and elapsed_seconds <= _run_samples[-SAMPLE_STRIDE]:
		return
	_run_samples.append(elapsed_seconds)
	_run_samples.append(distance_m)
	_run_samples.append(lateral_position)
	_next_sample_time = elapsed_seconds + SAMPLE_INTERVAL_SECONDS


func save_run_if_best(
	elapsed_seconds: float,
	distance_m: float,
	lateral_position: float,
	save_path := DEFAULT_SAVE_PATH
) -> bool:
	record_sample(elapsed_seconds, distance_m, lateral_position)
	if (
		_run_samples.size() < SAMPLE_STRIDE * 2
		or elapsed_seconds <= 0.0
		or (best_time_seconds > 0.0 and elapsed_seconds >= best_time_seconds)
	):
		return false

	var config := ConfigFile.new()
	var load_error := config.load(save_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return _set_error("Could not read the time-trial ghost before saving", load_error)
	if load_error == OK:
		var persisted_best: Variant = config.get_value(DATA_SECTION, BEST_TIME_KEY, null)
		if persisted_best is float or persisted_best is int:
			var persisted_best_time := float(persisted_best)
			if is_finite(persisted_best_time) and persisted_best_time > 0.0:
				if elapsed_seconds >= persisted_best_time:
					best_time_seconds = persisted_best_time
					return false
	config.set_value(DATA_SECTION, BEST_TIME_KEY, elapsed_seconds)
	config.set_value(DATA_SECTION, SAMPLES_KEY, _run_samples)
	var save_error := config.save(save_path)
	if save_error != OK:
		return _set_error("Could not save the time-trial ghost", save_error)

	best_time_seconds = elapsed_seconds
	_best_samples = _run_samples.duplicate()
	_playback_sample_index = 0
	persistence_error = ""
	return true


func playback_position(elapsed_seconds: float) -> Vector2:
	if _best_samples.size() < SAMPLE_STRIDE * 2:
		return Vector2.ZERO
	var sample_count := _best_samples.size() / SAMPLE_STRIDE
	while (
		_playback_sample_index < sample_count - 2
		and _sample_time(_playback_sample_index + 1) < elapsed_seconds
	):
		_playback_sample_index += 1

	var first_index := _playback_sample_index
	var second_index := mini(first_index + 1, sample_count - 1)
	var first_time := _sample_time(first_index)
	var second_time := _sample_time(second_index)
	var blend := (
		clampf((elapsed_seconds - first_time) / (second_time - first_time), 0.0, 1.0)
		if second_time > first_time
		else 0.0
	)
	var first_offset := first_index * SAMPLE_STRIDE
	var second_offset := second_index * SAMPLE_STRIDE
	return Vector2(
		lerpf(_best_samples[first_offset + 1], _best_samples[second_offset + 1], blend),
		lerpf(_best_samples[first_offset + 2], _best_samples[second_offset + 2], blend)
	)


func _sample_time(sample_index: int) -> float:
	return _best_samples[sample_index * SAMPLE_STRIDE]


func _validate_samples(samples: PackedFloat32Array) -> PackedFloat32Array:
	if samples.size() < SAMPLE_STRIDE * 2 or samples.size() % SAMPLE_STRIDE != 0:
		return PackedFloat32Array()
	var previous_time := -1.0
	var previous_distance := -1.0
	for offset in range(0, samples.size(), SAMPLE_STRIDE):
		var elapsed_seconds := samples[offset]
		var distance_m := samples[offset + 1]
		var lateral_position := samples[offset + 2]
		if (
			not is_finite(elapsed_seconds)
			or not is_finite(distance_m)
			or not is_finite(lateral_position)
			or elapsed_seconds < 0.0
			or distance_m < previous_distance
			or lateral_position < -12.0
			or lateral_position > 12.0
			or elapsed_seconds <= previous_time
		):
			return PackedFloat32Array()
		previous_time = elapsed_seconds
		previous_distance = distance_m
	return samples


func _set_error(message: String, error: Error = OK) -> bool:
	persistence_error = (
		"%s (error %d)" % [message, error]
		if error != OK
		else message
	)
	push_error(persistence_error)
	return false
