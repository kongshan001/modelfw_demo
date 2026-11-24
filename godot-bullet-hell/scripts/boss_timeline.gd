class_name BossTimeline
extends RefCounted

# Boss 三阶段时间轴：120 BPM，1 beat = 0.5s。
# 每个事件只声明 pattern 与持续 beats；主循环检测 phase/pattern 变化。

const BPM := 120.0
const BEAT := 60.0 / BPM
const PHASES := [
	{
		"title": "第一阶 · 校准",
		"subtitle": "PHASE 1 // CALIBRATE",
		"hp": 1200.0,
		"beats": 20,
		"events": [
			{"beat": 0, "pattern": 0, "beats": 5},
			{"beat": 5, "pattern": 1, "beats": 5},
			{"beat": 10, "pattern": 2, "beats": 5},
			{"beat": 15, "pattern": 3, "beats": 5},
		],
	},
	{
		"title": "第二阶 · 改速",
		"subtitle": "PHASE 2 // VELOCITY",
		"hp": 1450.0,
		"beats": 24,
		"events": [
			{"beat": 0, "pattern": 4, "beats": 6},
			{"beat": 6, "pattern": 5, "beats": 6},
			{"beat": 12, "pattern": 6, "beats": 6},
			{"beat": 18, "pattern": 7, "beats": 6},
		],
	},
	{
		"title": "第三阶 · 终曲",
		"subtitle": "PHASE 3 // FINALE",
		"hp": 1900.0,
		"beats": 32,
		"events": [
			{"beat": 0, "pattern": 8, "beats": 8},
			{"beat": 8, "pattern": 9, "beats": 8},
			{"beat": 16, "pattern": 6, "beats": 8},
			{"beat": 24, "pattern": 4, "beats": 8},
		],
	},
]

var phase_index := 0
var elapsed := 0.0
var finished := false
var _event_index := 0
var _pattern := 0

func reset() -> void:
	phase_index = 0
	elapsed = 0.0
	finished = false
	_event_index = 0
	_pattern = int(PHASES[0]["events"][0]["pattern"])

func phase_data() -> Dictionary:
	return PHASES[phase_index]

func phase_title() -> String:
	return String(PHASES[phase_index]["title"])

func phase_subtitle() -> String:
	return String(PHASES[phase_index]["subtitle"])

func phase_hp() -> float:
	return float(PHASES[phase_index]["hp"])

func phase_duration() -> float:
	return float(PHASES[phase_index]["beats"]) * BEAT

func phase_count() -> int:
	return PHASES.size()

func current_pattern() -> int:
	return _pattern

func current_event_index() -> int:
	return _event_index

func beat_float() -> float:
	return elapsed / BEAT

func beat_pulse() -> float:
	# 返回 1..0 的节拍脉冲，供背景/HUD 使用。
	var b := fmod(beat_float(), 1.0)
	return 1.0 - b

func update(dt: float) -> Dictionary:
	var out := {
		"phase_changed": false,
		"pattern_changed": false,
		"finished": false,
		"phase": phase_index,
		"pattern": _pattern,
		"event": _event_index,
	}
	if finished:
		out["finished"] = true
		return out
	elapsed += dt
	var duration := phase_duration()
	if elapsed >= duration:
		if phase_index + 1 < PHASES.size():
			phase_index += 1
			elapsed = 0.0
			_event_index = 0
			_pattern = int(PHASES[phase_index]["events"][0]["pattern"])
			out["phase_changed"] = true
			out["pattern_changed"] = true
			out["phase"] = phase_index
			out["pattern"] = _pattern
			out["event"] = 0
			return out
		else:
			finished = true
			out["finished"] = true
			return out
	var ev_i := _find_event_index(elapsed)
	var new_pattern := int(PHASES[phase_index]["events"][ev_i]["pattern"])
	if ev_i != _event_index or new_pattern != _pattern:
		_event_index = ev_i
		_pattern = new_pattern
		out["pattern_changed"] = true
		out["event"] = ev_i
		out["pattern"] = new_pattern
	return out

func force_next_phase() -> bool:
	# 提前打空 HP 时跳阶段，时间轴从新阶段 0 开始；最后一阶段返回 false。
	if finished:
		return false
	if phase_index + 1 >= PHASES.size():
		finished = true
		return false
	phase_index += 1
	elapsed = 0.0
	_event_index = 0
	_pattern = int(PHASES[phase_index]["events"][0]["pattern"])
	return true

func event_at_current() -> Dictionary:
	return PHASES[phase_index]["events"][_find_event_index(elapsed)]

func _find_event_index(t: float) -> int:
	var events: Array = PHASES[phase_index]["events"]
	var idx := 0
	for i in events.size():
		if t >= float(events[i]["beat"]) * BEAT:
			idx = i
		else:
			break
	return idx
