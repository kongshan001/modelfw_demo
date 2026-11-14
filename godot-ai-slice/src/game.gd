extends Node

# Small game state shared by the slice. Kept intentionally tiny so an AI agent
# can extend it without reading a large framework.

signal state_changed(state: int)
signal cores_changed(collected: int, total: int)

const TITLE := 0
const PLAYING := 1
const WON := 2
const TOTAL_CORES := 3

var state: int = TITLE
var collected := 0

func reset_to_title() -> void:
	state = TITLE
	collected = 0
	state_changed.emit(state)
	cores_changed.emit(collected, TOTAL_CORES)

func start() -> void:
	state = PLAYING
	collected = 0
	state_changed.emit(state)
	cores_changed.emit(collected, TOTAL_CORES)

func collect_core() -> void:
	if state != PLAYING:
		return
	collected = mini(collected + 1, TOTAL_CORES)
	cores_changed.emit(collected, TOTAL_CORES)

func win() -> void:
	if state != PLAYING:
		return
	state = WON
	state_changed.emit(state)

func is_playing() -> bool:
	return state == PLAYING

func is_title() -> bool:
	return state == TITLE

func is_won() -> bool:
	return state == WON

func total_cores() -> int:
	return TOTAL_CORES

func all_cores_collected() -> bool:
	return collected >= TOTAL_CORES

func state_name() -> String:
	match state:
		TITLE:
			return "TITLE"
		PLAYING:
			return "PLAYING"
		WON:
			return "WON"
	return "UNKNOWN"
