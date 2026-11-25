extends Node
## 程序化交互音效：苔灯的风声木鱼、玻璃风铃的三连音、苔猫的低频呼噜。
## 全部波形在启动时本地合成，不包含外部音频资源。

const RATE := 22050

var _lantern_stream: AudioStreamWAV
var _chime_stream: AudioStreamWAV
var _cat_stream: AudioStreamWAV
var _lantern_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer
var _cat_player: AudioStreamPlayer


func _ready() -> void:
	_lantern_stream = _synth_lantern()
	_chime_stream = _synth_chime()
	_cat_stream = _synth_cat()
	_lantern_player = _make_player("LanternTone", _lantern_stream, -13.0)
	_chime_player = _make_player("ChimeTone", _chime_stream, -10.0)
	_cat_player = _make_player("CatPurr", _cat_stream, -17.0)


func _make_player(label: String, stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.stream = stream
	player.volume_db = volume
	player.bus = "Master"
	add_child(player)
	return player


func play_lantern() -> void:
	if _lantern_player != null:
		_lantern_player.play()


func play_chime() -> void:
	if _chime_player != null:
		_chime_player.play()


func play_cat() -> void:
	if _cat_player != null:
		_cat_player.play()


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -0.98, 0.98) * 32767.0)
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


func _synth_lantern() -> AudioStreamWAV:
	var seconds := 1.6
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / float(RATE)
		var env := exp(-t * 3.2) * (1.0 - exp(-t * 90.0))
		var tone := sin(TAU * 196.0 * t) * 0.38
		tone += sin(TAU * 293.7 * t + 0.25) * 0.15
		tone += sin(TAU * 441.0 * t) * 0.06
		var air := sin(TAU * 97.0 * t) * 0.05
		out[i] = (tone + air) * env * 0.70
	return _to_stream(out)


func _synth_chime() -> AudioStreamWAV:
	var seconds := 2.4
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var notes := [1318.51, 1567.98, 1760.0, 2093.0]
	var starts := [0.0, 0.16, 0.34, 0.58]
	var gains := [0.44, 0.32, 0.26, 0.20]
	for n in range(notes.size()):
		var freq: float = notes[n]
		var start: float = starts[n]
		var gain: float = gains[n]
		for i in range(count):
			var t := float(i) / float(RATE) - start
			if t < 0.0:
				continue
			var env := exp(-t * 2.35) * (1.0 - exp(-t * 140.0))
			var tone := sin(TAU * freq * t) * 0.62
			tone += sin(TAU * freq * 2.01 * t + 0.2) * 0.20
			tone += sin(TAU * freq * 3.02 * t + 0.7) * 0.11
			# 很轻的玻璃颤动。
			tone *= 1.0 + 0.025 * sin(TAU * 7.0 * t)
			out[i] += tone * env * gain
	for i in range(count):
		out[i] = clampf(out[i], -0.92, 0.92)
	return _to_stream(out)


func _synth_cat() -> AudioStreamWAV:
	var seconds := 1.8
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in range(count):
		var t := float(i) / float(RATE)
		var env := smoothstep(0.0, 0.25, t) * smoothstep(seconds, seconds - 0.55, t)
		var purr := sin(TAU * 92.0 * t) * (0.6 + 0.4 * sin(TAU * 23.0 * t))
		purr += sin(TAU * 138.0 * t + 0.4) * 0.22
		purr += sin(TAU * 46.0 * t) * 0.18
		var breath := sin(TAU * 3.2 * t) * 0.04
		out[i] = (purr * 0.35 + breath) * env
	return _to_stream(out)
