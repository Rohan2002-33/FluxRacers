extends SceneTree

const SAMPLE_RATE := 22050
const RACE_AUDIO := preload("res://scripts/race_audio.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var music := RACE_AUDIO.build_music_stream()
	var engine := RACE_AUDIO.build_engine_stream()
	var wind := RACE_AUDIO.build_wind_stream()
	_assert(
		music.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and music.mix_rate == SAMPLE_RATE
			and is_equal_approx(music.get_length(), 8.0)
			and music.loop_end == 8 * SAMPLE_RATE,
		"The original race score is a complete, seamless eight-second audio loop"
	)
	_assert(
		engine.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and is_equal_approx(engine.get_length(), 1.0)
			and engine.loop_end == SAMPLE_RATE,
		"The vehicle engine uses a continuous loop that supports RPM pitch control"
	)
	_assert(
		wind.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and is_equal_approx(wind.get_length(), 2.0)
			and wind.loop_end == 2 * SAMPLE_RATE,
		"Road and wind ambience use a continuous audio loop"
	)

	var audio := RACE_AUDIO.new() as Node
	root.add_child(audio)
	audio.configure(0.5, 0.75)
	_assert(audio._music_player.playing, "Race music starts when the audio mix is configured")
	_assert(
		audio._music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and audio._engine_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and audio._wind_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"All continuous race sounds are configured to loop in the live mix"
	)
	_assert(
		is_equal_approx(audio._music_player.volume_db, linear_to_db(0.5)),
		"The music volume setting controls the score level"
	)
	_assert(
		is_equal_approx(audio._engine_player.volume_db, linear_to_db(0.0001)),
		"The vehicle engine is silent before the race begins"
	)
	audio.update_vehicle(24.0, 60.0, true)
	_assert(
		audio._engine_player.volume_db > linear_to_db(0.0001)
			and audio._engine_player.pitch_scale > 0.72,
		"Acceleration and road speed raise the engine pitch and level"
	)
	_assert(
		audio._wind_player.volume_db > linear_to_db(0.0001),
		"Road and wind ambience scales with vehicle speed"
	)
	audio.update_vehicle(0.0, 60.0, false, true)
	_assert(
		audio._engine_player.volume_db > linear_to_db(0.0001),
		"The engine remains audible at idle during the race countdown"
	)
	audio.update_vehicle(0.0, 60.0, false, false)
	_assert(
		is_equal_approx(audio._engine_player.volume_db, linear_to_db(0.0001)),
		"The engine is muted outside an active race"
	)
	audio.update_vehicle(24.0, 60.0, true)
	audio.stop_vehicle()
	_assert(
		is_equal_approx(audio._engine_player.volume_db, linear_to_db(0.0001))
			and is_equal_approx(audio._wind_player.volume_db, linear_to_db(0.0001)),
		"Vehicle and road loops stop after the race ends"
	)
	audio.play_countdown()
	_assert(
		audio._effect_player.stream is AudioStreamWAV
			and audio._effect_player.stream.data.size() > 0,
		"Countdown feedback plays a generated audio cue"
	)
	audio.play_collision()
	_assert(
		audio._effect_player.stream is AudioStreamWAV
			and audio._effect_player.stream.data.size() == roundi(0.48 * SAMPLE_RATE) * 2,
		"A traffic impact produces a dedicated collision sound"
	)
	audio.play_event_complete()
	_assert(
		audio._effect_player.stream is AudioStreamWAV
			and audio._effect_player.stream.data.size() == roundi(0.65 * SAMPLE_RATE) * 2,
		"A completed career event produces a dedicated success cue"
	)
	audio.play_horn()
	_assert(
		audio._effect_player.stream is AudioStreamWAV
			and is_equal_approx(audio._effect_player.stream.get_length(), 0.48),
		"The horn plays a dedicated, pre-baked one-shot sound"
	)
	audio.free()

	if _failed:
		quit(1)
	else:
		print("Godot race audio tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot race audio test failed: %s" % message)
		_failed = true
