extends Node2D

# Owns the water shader inputs, the day/night tint, the waterfall and the
# event ripple slots.

const MASK_PATH := "res://assets/world/water_mask.png"
const DEPTH_PATH := "res://assets/world/water_depth.png"
const WF_SHEET := preload("res://assets/world/waterfall.png")
const WF_CELL := Vector2i(32, 80)

@onready var water: ColorRect = $Water
@onready var props: Sprite2D = $Props
@onready var waterfall: AnimatedSprite2D = $Waterfall
@onready var player = $Player

var mask_img: Image
var depth_img: Image
var mat: ShaderMaterial

var time := 0.0
var time_of_day := 12.0
var day := 1.0

var _ripples := PackedVector4Array()
var _wf_t := 0.0
var _caustic_on := true
var _refract_on := true
var _foam_on := true


func _ready() -> void:
	mask_img = Image.load_from_file(MASK_PATH)
	depth_img = Image.load_from_file(DEPTH_PATH)
	mat = water.material as ShaderMaterial
	_build_waterfall()
	player.setup(self)

	_ripples.resize(8)
	for i in 8:
		_ripples[i] = Vector4(0.0, 0.0, -100.0, 0.0)
	mat.set_shader_parameter("ripples", _ripples)
	mat.set_shader_parameter("resolution", Vector2(640.0, 360.0))
	set_time(12.0)


func _process(delta: float) -> void:
	time += delta
	mat.set_shader_parameter("time", time)

	_wf_t -= delta
	if _wf_t <= 0.0:
		if is_water(Vector2(156.0, 128.0)):
			spawn_ripple(Vector2(156.0, 128.0), 0.45)
		_wf_t = 1.15


# ── queries ───────────────────────────────────────────────────────────────
func depth_at(pos: Vector2) -> float:
	if depth_img == null:
		return 0.0
	var x := clampi(int(pos.x), 0, 639)
	var y := clampi(int(pos.y), 0, 359)
	return depth_img.get_pixel(x, y).r


func is_water(pos: Vector2) -> bool:
	if mask_img == null:
		return false
	var x := clampi(int(pos.x), 0, 639)
	var y := clampi(int(pos.y), 0, 359)
	return mask_img.get_pixel(x, y).r > 0.5


# ── interaction ───────────────────────────────────────────────────────────
func spawn_ripple(pos: Vector2, strength: float) -> void:
	if not is_water(pos):
		return
	var uv := pos / Vector2(640.0, 360.0)
	var oldest := 0
	var oldest_time := 1.0e20
	for i in 8:
		if _ripples[i].z < oldest_time:
			oldest_time = _ripples[i].z
			oldest = i
	_ripples[oldest] = Vector4(uv.x, uv.y, time, strength)
	mat.set_shader_parameter("ripples", _ripples)


func set_time(t: float) -> void:
	time_of_day = clampf(t, 0.0, 24.0)
	day = smoothstep(5.5, 7.5, time_of_day) * (1.0 - smoothstep(17.5, 19.5, time_of_day))
	mat.set_shader_parameter("day", day)
	var tint := Color(
		0.42 + 0.58 * day,
		0.50 + 0.50 * day,
		0.72 + 0.28 * day)
	props.modulate = tint
	waterfall.modulate = tint
	player.set_day(day, tint)


# ── teaching toggles ──────────────────────────────────────────────────────
func set_debug(mode: int) -> void:
	mat.set_shader_parameter("debug_mode", mode)


func toggle_caustic() -> bool:
	_caustic_on = not _caustic_on
	mat.set_shader_parameter("caustic_on", 1.0 if _caustic_on else 0.0)
	return _caustic_on


func toggle_refract() -> bool:
	_refract_on = not _refract_on
	mat.set_shader_parameter("refract_on", 1.0 if _refract_on else 0.0)
	return _refract_on


func toggle_foam() -> bool:
	_foam_on = not _foam_on
	mat.set_shader_parameter("foam_on", 1.0 if _foam_on else 0.0)
	return _foam_on


# ── waterfall ─────────────────────────────────────────────────────────────
func _build_waterfall() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("flow")
	sf.set_animation_speed("flow", 9.0)
	for i in 4:
		var tex := AtlasTexture.new()
		tex.atlas = WF_SHEET
		tex.region = Rect2(i * WF_CELL.x, 0, WF_CELL.x, WF_CELL.y)
		sf.add_frame("flow", tex)
	waterfall.sprite_frames = sf
	waterfall.play("flow")
