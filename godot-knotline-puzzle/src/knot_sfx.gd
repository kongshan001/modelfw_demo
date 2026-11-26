class_name KnotSfx
extends Node

## Tiny procedural chime synth (no audio files, no third-party libs).
## Every note is a soft sine pluck; disabled automatically in headless runs.

const RATE := 22050.0

var muted := false
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _time := 0.0
var _enabled := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.22
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.volume_db = -12.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_enabled = _playback != null
	set_process(_enabled)


func toggle_mute() -> bool:
	muted = not muted
	if _player != null:
		_player.volume_db = -80.0 if muted else -12.0
	return muted


func note(freq: float, dur: float = 0.24, amp: float = 0.22, delay: float = 0.0, pan: float = 0.0) -> void:
	if not _enabled or muted:
		return
	if _voices.size() > 12:
		_voices.pop_front()
	_voices.append({
		"freq": freq,
		"start": _time + delay,
		"dur": dur,
		"amp": amp,
		"pan": clampf(pan, -0.8, 0.8),
	})


func start_stroke() -> void:
	note(523.25, 0.2, 0.14)
	note(659.25, 0.2, 0.09, 0.05)


func undo() -> void:
	note(392.0, 0.16, 0.12)
	note(311.13, 0.2, 0.09, 0.06)


func wrap_done() -> void:
	note(659.25, 0.32, 0.18)
	note(987.77, 0.36, 0.12, 0.08)


func crossing() -> void:
	note(783.99, 0.3, 0.16)
	note(1046.5, 0.3, 0.10, 0.07)


func win() -> void:
	note(523.25, 0.45, 0.18)
	note(659.25, 0.45, 0.15, 0.13)
	note(783.99, 0.5, 0.14, 0.26)
	note(1046.5, 0.7, 0.12, 0.4)


func error() -> void:
	note(220.0, 0.14, 0.12)
	note(196.0, 0.2, 0.1, 0.08)


func click() -> void:
	note(880.0, 0.08, 0.07)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var avail := _playback.get_frames_available()
	if avail <= 0:
		return
	var sr := RATE
	for i in avail:
		var t := _time + float(i) / sr
		var l := 0.0
		var r := 0.0
		for v in _voices:
			var start: float = v["start"]
			if t < start:
				continue
			var age := t - start
			var dur: float = v["dur"]
			if age > dur:
				continue
			var env := exp(-5.5 * age / dur) * (1.0 - age / dur)
			var s := sin(TAU * float(v["freq"]) * age) * env * float(v["amp"])
			var pan: float = v["pan"]
			l += s * (1.0 - maxf(0.0, pan))
			r += s * (1.0 - maxf(0.0, -pan))
		_playback.push_frame(Vector2(clampf(l, -1.0, 1.0), clampf(r, -1.0, 1.0)))
	_time += float(avail) / sr
	if _voices.size() > 0:
		var keep: Array[Dictionary] = []
		for v in _voices:
			if _time < float(v["start"]) + float(v["dur"]) + 0.2:
				keep.append(v)
		_voices = keep
