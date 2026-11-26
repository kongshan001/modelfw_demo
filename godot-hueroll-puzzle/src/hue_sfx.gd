class_name HueSfx
extends Node

# Tiny procedural sound kit. 22050 Hz 16-bit mono WAVs are synthesised at startup;
# no audio files ship with the project.

const RATE := 22050

var players: Dictionary = {}
var muted := false


func _ready() -> void:
	players["roll"] = _make_player(_tone(190.0, 95.0, 0.13, 26.0, 0.22, 0.0))
	players["dip"] = _make_player(_tone(310.0, 640.0, 0.20, 13.0, 0.06, 0.06))
	players["stamp"] = _make_player(_tone(150.0, 72.0, 0.26, 17.0, 0.30, 0.03))
	players["wrong"] = _make_player(_tone(150.0, 105.0, 0.20, 14.0, 0.16, 0.0))
	players["bump"] = _make_player(_tone(96.0, 62.0, 0.10, 30.0, 0.24, 0.0))
	players["undo"] = _make_player(_tone(560.0, 230.0, 0.16, 16.0, 0.03, 0.0))
	players["reset"] = _make_player(_tone(330.0, 150.0, 0.24, 13.0, 0.06, 0.02))
	players["camera"] = _make_player(_tone(210.0, 300.0, 0.22, 11.0, 0.03, 0.10))
	players["win"] = _make_player(_win_stream())
	players["click"] = _make_player(_tone(700.0, 500.0, 0.06, 40.0, 0.0, 0.0))


func _make_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -9.0
	add_child(p)
	return p


func play(key: String) -> void:
	if muted or not players.has(key):
		return
	var p: AudioStreamPlayer = players[key]
	p.pitch_scale = randf_range(0.985, 1.015)
	p.play()


func toggle_mute() -> bool:
	muted = not muted
	for p in players.values():
		(p as AudioStreamPlayer).volume_db = -80.0 if muted else -9.0
	return not muted


func _tone(f0: float, f1: float, dur: float, decay: float, noise: float, wobble: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq := lerpf(f0, f1, t) * (1.0 + sin(t * TAU * 3.0) * wobble)
		phase += TAU * freq / float(RATE)
		var env := exp(-decay * t) * minf(1.0, t * 90.0) * minf(1.0, (1.0 - t) * 18.0)
		var v := sin(phase) * 0.75 + sin(phase * 2.0) * 0.18
		v += randf_range(-1.0, 1.0) * noise
		v *= env * 0.55
		var iv := int(clampf(v, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, iv)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _win_stream() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var per := 0.14
	var dur := per * notes.size() + 0.45
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := PackedFloat64Array()
	phases.resize(notes.size())
	for i in n:
		var t := float(i) / float(RATE)
		var v := 0.0
		for k in notes.size():
			var start := float(k) * per
			if t < start:
				continue
			var local := t - start
			var env := exp(-5.2 * local) * minf(1.0, local * 60.0)
			phases[k] += TAU * float(notes[k]) / float(RATE)
			v += sin(phases[k]) * env * 0.22
		# A small shimmer on top.
		var bell := sin(t * TAU * 2093.0) * exp(-3.0 * t) * 0.05
		v += bell
		var iv := int(clampf(v, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, iv)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
