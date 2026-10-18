class_name RaceProgression
extends RefCounted

enum Mode { QUICK_RACE, CAREER }
enum State { COUNTDOWN, RACING, FINISHED }

const CAREER_EVENT_NAMES := [
	"COASTAL SPRINT",
	"PALM CIRCUIT",
	"DESERT ENDURANCE",
]
const CAREER_EVENT_DISTANCES_M := [750.0, 1500.0, 2500.0]
const CAREER_EVENT_REWARD := 250
const PERSONAL_BEST_BONUS := 100
const COUNTDOWN_SECONDS := 3.0

var mode: Mode
var state := State.COUNTDOWN
var countdown_remaining := COUNTDOWN_SECONDS
var race_time_seconds := 0.0
var career_event_unlocked := 0
var event_index := -1
var credits := 0
var target_distance_m := 0.0
var event_name := ""
var is_personal_best := false
var career_complete := false
var persistence_error := ""
var reward_credits := 0
var _save_path: String
var _reward_claimed := false


func _init(requested_mode: Mode, save_path := "user://career_progress.cfg") -> void:
	mode = requested_mode
	_save_path = save_path
	_load_progress()
	if mode == Mode.CAREER:
		career_complete = career_event_unlocked >= CAREER_EVENT_DISTANCES_M.size()
		if career_complete:
			state = State.FINISHED
		else:
			event_index = career_event_unlocked
			event_name = CAREER_EVENT_NAMES[event_index]
			target_distance_m = CAREER_EVENT_DISTANCES_M[event_index]


func advance(delta: float, distance_m: float) -> void:
	if delta <= 0.0 or state == State.FINISHED:
		return
	if state == State.COUNTDOWN:
		countdown_remaining -= delta
		if countdown_remaining <= 0.0:
			race_time_seconds += -countdown_remaining
			countdown_remaining = 0.0
			state = State.RACING
		return

	race_time_seconds += delta
	if mode == Mode.CAREER and distance_m >= target_distance_m:
		state = State.FINISHED


func complete_race() -> bool:
	if mode != Mode.CAREER or state != State.FINISHED or career_complete:
		return false
	if _reward_claimed:
		return true

	var config := ConfigFile.new()
	var load_error := config.load(_save_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return _set_persistence_error("Could not read career progress before saving", load_error)

	var stored_best := float(config.get_value("career", "event_%d_best" % career_event_unlocked, 0.0))
	is_personal_best = stored_best <= 0.0 or race_time_seconds < stored_best
	if is_personal_best:
		config.set_value("career", "event_%d_best" % career_event_unlocked, race_time_seconds)
	career_event_unlocked += 1
	reward_credits = CAREER_EVENT_REWARD + (PERSONAL_BEST_BONUS if is_personal_best else 0)
	credits += reward_credits
	config.set_value("career", "unlocked_event", career_event_unlocked)
	config.set_value("career", "credits", credits)

	var save_error := config.save(_save_path)
	if save_error != OK:
		career_event_unlocked -= 1
		credits -= reward_credits
		reward_credits = 0
		return _set_persistence_error("Could not save career progress", save_error)

	_reward_claimed = true
	career_complete = career_event_unlocked >= CAREER_EVENT_DISTANCES_M.size()
	return true


func restart_career() -> bool:
	if mode != Mode.CAREER:
		return false

	var config := ConfigFile.new()
	var load_error := config.load(_save_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		return _set_persistence_error("Could not read career progress before restarting", load_error)
	config.set_value("career", "unlocked_event", 0)
	var save_error := config.save(_save_path)
	if save_error != OK:
		return _set_persistence_error("Could not restart career progress", save_error)

	career_event_unlocked = 0
	event_index = 0
	event_name = CAREER_EVENT_NAMES[0]
	target_distance_m = CAREER_EVENT_DISTANCES_M[0]
	career_complete = false
	state = State.COUNTDOWN
	countdown_remaining = COUNTDOWN_SECONDS
	race_time_seconds = 0.0
	is_personal_best = false
	reward_credits = 0
	_reward_claimed = false
	return true


func _load_progress() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(_save_path)
	if load_error == ERR_FILE_NOT_FOUND:
		return
	if load_error != OK:
		_set_persistence_error("Could not load career progress", load_error)
		return

	career_event_unlocked = clampi(
		int(config.get_value("career", "unlocked_event", 0)),
		0,
		CAREER_EVENT_DISTANCES_M.size()
	)
	credits = maxi(0, int(config.get_value("career", "credits", 0)))


func _set_persistence_error(context: String, error: Error) -> bool:
	persistence_error = "%s (error %d)" % [context, error]
	push_error(persistence_error)
	return false
