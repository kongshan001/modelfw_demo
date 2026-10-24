class_name AudioDirector
extends Node

# 程序化短音效（无外部素材，规格 6.6）。headless 下完全静默但仍生成音频流，
# 便于探针校验；BGM 仅在 encounter.bgm_path 可加载时播放，否则静默降级。

const MIX_RATE := 22050
const POOL_SIZE := 8
const SFX_NAMES: Array[StringName] = [
	&"hit", &"slash", &"cast", &"heal", &"status", &"death", &"victory", &"defeat", &"click",
]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _next_player := 0
var _silent := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"
	_ensure_streams()
	if _silent:
		return
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % index
		add_child(player)
		_players.append(player)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "Bgm"
	_bgm_player.volume_db = -10.0
	add_child(_bgm_player)

func is_silent() -> bool:
	return _silent

func stream_names() -> Array:
	_ensure_streams()
	return _streams.keys()

func has_sfx(sfx_name: StringName) -> bool:
	_ensure_streams()
	return _streams.has(sfx_name)

func play_sfx(sfx_name: StringName) -> void:
	if _silent:
		return
	_ensure_streams()
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null or _players.is_empty():
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()

func play_bgm(path: String) -> void:
	if _silent or _bgm_player == null or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		return
	var stream := load(path)
	if stream is AudioStream:
		_bgm_player.stream = stream
		_bgm_player.play()

# ---------------------------------------------------------------- 合成

func _ensure_streams() -> void:
	if not _streams.is_empty():
		return
	_rng.seed = 0xA0D10
	_streams[&"hit"] = _make_wav(_make_hit())
	_streams[&"slash"] = _make_wav(_make_slash())
	_streams[&"cast"] = _make_wav(_make_cast())
	_streams[&"heal"] = _make_wav(_make_heal())
	_streams[&"status"] = _make_wav(_make_status())
	_streams[&"death"] = _make_wav(_make_death())
	_streams[&"victory"] = _make_wav(_make_victory())
	_streams[&"defeat"] = _make_wav(_make_defeat())
	_streams[&"click"] = _make_wav(_make_click())

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in samples.size():
		data.encode_s16(index * 2, int(samples[index] * 32767.0))
	wav.data = data
	return wav

func _new_buffer(duration: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(maxi(1, int(duration * MIX_RATE)))
	return buffer

func _add_tone(buffer: PackedFloat32Array, start: float, duration: float, f0: float, f1: float, amp: float, decay := 5.0, square := false) -> PackedFloat32Array:
	var first := int(start * MIX_RATE)
	var count := int(duration * MIX_RATE)
	var phase := 0.0
	for index in count:
		var cursor := first + index
		if cursor >= buffer.size():
			break
		var t := float(index) / MIX_RATE
		var freq := lerpf(f0, f1, clampf(t / duration, 0.0, 1.0))
		phase += TAU * freq / MIX_RATE
		var wave := sin(phase)
		if square:
			wave = signf(wave) * 0.45
		buffer[cursor] += wave * amp * exp(-decay * t)
	return buffer

func _add_noise(buffer: PackedFloat32Array, start: float, duration: float, amp: float, decay: float) -> PackedFloat32Array:
	var first := int(start * MIX_RATE)
	var count := int(duration * MIX_RATE)
	for index in count:
		var cursor := first + index
		if cursor >= buffer.size():
			break
		var t := float(index) / MIX_RATE
		buffer[cursor] += _rng.randf_range(-1.0, 1.0) * amp * exp(-decay * t)
	return buffer

func _add_note(buffer: PackedFloat32Array, start: float, duration: float, freq: float, amp: float, decay := 5.0) -> PackedFloat32Array:
	return _add_tone(buffer, start, duration, freq, freq, amp, decay)

func _finalize(buffer: PackedFloat32Array) -> PackedFloat32Array:
	var total := buffer.size()
	var fade := maxi(1, int(total * 0.08))
	for index in total:
		var value := clampf(buffer[index], -1.0, 1.0)
		if index >= total - fade:
			value *= float(total - index) / float(fade)
		buffer[index] = value
	return buffer

func _make_hit() -> PackedFloat32Array:
	var buffer := _new_buffer(0.2)
	buffer = _add_noise(buffer, 0.0, 0.16, 0.8, 24.0)
	buffer = _add_tone(buffer, 0.0, 0.18, 150.0, 60.0, 0.75, 16.0)
	buffer = _add_tone(buffer, 0.0, 0.06, 1800.0, 320.0, 0.22, 30.0)
	return _finalize(buffer)

func _make_slash() -> PackedFloat32Array:
	var buffer := _new_buffer(0.24)
	buffer = _add_noise(buffer, 0.0, 0.22, 0.5, 9.0)
	buffer = _add_tone(buffer, 0.0, 0.21, 2400.0, 450.0, 0.4, 12.0)
	buffer = _add_tone(buffer, 0.03, 0.12, 3200.0, 1400.0, 0.16, 22.0)
	return _finalize(buffer)

func _make_cast() -> PackedFloat32Array:
	var buffer := _new_buffer(0.5)
	buffer = _add_tone(buffer, 0.0, 0.44, 380.0, 900.0, 0.45, 3.0)
	buffer = _add_note(buffer, 0.1, 0.28, 660.0, 0.28, 5.0)
	buffer = _add_tone(buffer, 0.16, 0.3, 1200.0, 1800.0, 0.18, 7.0)
	return _finalize(buffer)

func _make_heal() -> PackedFloat32Array:
	var buffer := _new_buffer(0.62)
	buffer = _add_note(buffer, 0.0, 0.42, 523.25, 0.38, 5.0)
	buffer = _add_note(buffer, 0.12, 0.42, 659.25, 0.36, 5.0)
	buffer = _add_note(buffer, 0.24, 0.4, 783.99, 0.34, 5.0)
	buffer = _add_tone(buffer, 0.0, 0.55, 261.63, 392.0, 0.12, 3.0)
	return _finalize(buffer)

func _make_status() -> PackedFloat32Array:
	var buffer := _new_buffer(0.36)
	buffer = _add_tone(buffer, 0.0, 0.34, 300.0, 420.0, 0.38, 4.0)
	buffer = _add_tone(buffer, 0.0, 0.34, 318.0, 442.0, 0.3, 4.0)
	buffer = _add_tone(buffer, 0.08, 0.2, 900.0, 640.0, 0.14, 9.0)
	return _finalize(buffer)

func _make_death() -> PackedFloat32Array:
	var buffer := _new_buffer(0.66)
	buffer = _add_tone(buffer, 0.0, 0.62, 320.0, 68.0, 0.55, 3.2)
	buffer = _add_noise(buffer, 0.02, 0.44, 0.26, 7.0)
	buffer = _add_note(buffer, 0.2, 0.4, 110.0, 0.2, 3.0)
	return _finalize(buffer)

func _make_victory() -> PackedFloat32Array:
	var buffer := _new_buffer(1.0)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for index in notes.size():
		buffer = _add_note(buffer, float(index) * 0.15, 0.62, notes[index], 0.4, 4.5)
	buffer = _add_tone(buffer, 0.45, 0.5, 1046.5, 1046.5, 0.22, 3.5)
	buffer = _add_note(buffer, 0.0, 0.9, 196.0, 0.12, 2.5)
	return _finalize(buffer)

func _make_defeat() -> PackedFloat32Array:
	var buffer := _new_buffer(1.0)
	var notes := [392.0, 329.63, 261.63, 196.0]
	for index in notes.size():
		buffer = _add_note(buffer, float(index) * 0.17, 0.6, notes[index], 0.4, 4.0)
	buffer = _add_note(buffer, 0.5, 0.48, 98.0, 0.2, 2.5)
	return _finalize(buffer)

func _make_click() -> PackedFloat32Array:
	var buffer := _new_buffer(0.07)
	buffer = _add_tone(buffer, 0.0, 0.06, 1300.0, 900.0, 0.45, 38.0)
	buffer = _add_noise(buffer, 0.0, 0.03, 0.16, 55.0)
	return _finalize(buffer)
