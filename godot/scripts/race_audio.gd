class_name RaceAudio
extends Node

const SAMPLE_RATE := 22050
const MAX_AUDIO_SAMPLES := 32767.0
const RACE_MUSIC_STREAM: AudioStreamWAV = preload("res://assets/audio/race_music.wav")
const ENGINE_STREAM: AudioStreamWAV = preload("res://assets/audio/car_engine.wav")
const WIND_STREAM: AudioStreamWAV = preload("res://assets/audio/road_wind.wav")
const HORN_STREAM: AudioStreamWAV = preload("res://assets/audio/horn.wav")

var _music_player: AudioStreamPlayer
var _engine_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _effect_player: AudioStreamPlayer
var _music_volume := 0.35
var _effects_volume := 0.8


func configure(music_volume: float, effects_volume: float) -> void:
	_music_volume = clampf(music_volume, 0.0, 1.0)
	_effects_volume = clampf(effects_volume, 0.0, 1.0)

	_music_player = _make_player("RaceMusic")
	_music_player.stream = build_music_stream()
	_music_player.play()
	_update_player_volume(_music_player, _music_volume)

	_engine_player = _make_player("VehicleEngine")
	_engine_player.stream = build_engine_stream()
	_engine_player.play()
	_update_player_volume(_engine_player, 0.0)

	_wind_player = _make_player("RoadAndWind")
	_wind_player.stream = build_wind_stream()
	_wind_player.play()
	_update_player_volume(_wind_player, 0.0)

	_effect_player = _make_player("RaceEffects")


func update_vehicle(
	speed_mps: float,
	max_speed_mps: float,
	throttle: bool,
	race_active: bool = true
) -> void:
	if _engine_player == null or _wind_player == null:
		return
	var speed_ratio := clampf(speed_mps / maxf(max_speed_mps, 0.1), 0.0, 1.0)
	var engine_load := 1.0 if race_active else 0.0
	_engine_player.pitch_scale = 0.8 + speed_ratio * 0.82 + (0.12 if throttle else 0.0)
	_update_player_volume(_engine_player, _effects_volume * engine_load * 0.48)
	_wind_player.pitch_scale = 0.72 + speed_ratio * 1.55
	_update_player_volume(_wind_player, _effects_volume * speed_ratio * 0.14)


func play_countdown() -> void:
	_play_effect(_make_tone(740.0, 0.12, 0.45))


func play_go() -> void:
	_play_effect(_make_chord([587.33, 783.99], 0.24, 0.42))


func play_collision() -> void:
	_play_effect(_make_collision_sound())
	if _music_player != null:
		_update_player_volume(_music_player, _music_volume * 0.4)


func play_event_complete() -> void:
	_play_effect(_make_chord([523.25, 659.25, 783.99], 0.65, 0.32))
	if _music_player != null:
		_update_player_volume(_music_player, _music_volume * 0.55)


func play_horn() -> void:
	_play_effect(HORN_STREAM)


func stop_vehicle() -> void:
	if _engine_player != null:
		_update_player_volume(_engine_player, 0.0)
	if _wind_player != null:
		_update_player_volume(_wind_player, 0.0)


func set_music_volume(volume: float) -> void:
	_music_volume = clampf(volume, 0.0, 1.0)
	if _music_player != null:
		_update_player_volume(_music_player, _music_volume)


func set_effects_volume(volume: float) -> void:
	_effects_volume = clampf(volume, 0.0, 1.0)


static func build_music_stream() -> AudioStreamWAV:
	_configure_loop(RACE_MUSIC_STREAM)
	return RACE_MUSIC_STREAM


static func build_engine_stream() -> AudioStreamWAV:
	_configure_loop(ENGINE_STREAM)
	return ENGINE_STREAM


static func build_wind_stream() -> AudioStreamWAV:
	_configure_loop(WIND_STREAM)
	return WIND_STREAM


static func _configure_loop(stream: AudioStreamWAV) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)


static func _make_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count := roundi(duration * SAMPLE_RATE)
	return _make_one_shot(sample_count, func(time: float) -> float:
		var attack := minf(1.0, time / 0.006)
		var release := clampf((duration - time) / 0.025, 0.0, 1.0)
		return sin(TAU * frequency * time) * attack * release * amplitude
	)


static func _make_chord(
	frequencies: Array[float],
	duration: float,
	amplitude: float
) -> AudioStreamWAV:
	var sample_count := roundi(duration * SAMPLE_RATE)
	return _make_one_shot(sample_count, func(time: float) -> float:
		var attack := minf(1.0, time / 0.008)
		var release := clampf((duration - time) / 0.12, 0.0, 1.0)
		var chord := 0.0
		for frequency in frequencies:
			chord += sin(TAU * frequency * time)
		return chord / frequencies.size() * attack * release * amplitude
	)


static func _make_collision_sound() -> AudioStreamWAV:
	var duration := 0.48
	return _make_one_shot(roundi(duration * SAMPLE_RATE), func(time: float) -> float:
		var envelope := exp(-time * 8.0)
		var impact_frequency := 94.0 - time * 88.0
		var impact := sin(TAU * impact_frequency * time) * 0.42
		var grit := sin(TAU * time * 1327.0) * sin(TAU * time * 71.0) * 0.17
		return (impact + grit) * envelope
	)


static func _make_one_shot(sample_count: int, sample_generator: Callable) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for frame in range(sample_count):
		var sample := clampf(
			float(sample_generator.call(float(frame) / SAMPLE_RATE)),
			-1.0,
			1.0
		)
		data.encode_s16(frame * 2, roundi(sample * MAX_AUDIO_SAMPLES))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player


func _play_effect(stream: AudioStream) -> void:
	if _effect_player == null:
		return
	_effect_player.stream = stream
	_update_player_volume(_effect_player, _effects_volume)
	_effect_player.play()


func _update_player_volume(player: AudioStreamPlayer, volume: float) -> void:
	player.volume_db = linear_to_db(maxf(volume, 0.0001))
