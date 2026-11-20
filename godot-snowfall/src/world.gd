extends Node2D

const SNOW_MASK := preload("res://assets/world/snow_mask.png")
const FLAKE := preload("res://assets/fx/flake.png")
const LIGHT_TEX := preload("res://assets/fx/light.png")
const GLOW_TEX := preload("res://assets/fx/glow.png")
const FOOT_TEX := preload("res://assets/fx/foot.png")

# tex name, base x/y, snow-cap threshold
const PROPS := [
	["pine_a", 70, 150, 0.06], ["pine_b", 160, 214, 0.14],
	["pine_a", 520, 150, 0.08], ["pine_b", 576, 236, 0.16],
	["pine_b", 110, 300, 0.18], ["pine_a", 548, 320, 0.10],
	["pine_b", 438, 122, 0.12], ["bush", 220, 250, 0.20],
	["bush", 400, 270, 0.22], ["bush", 94, 340, 0.24],
	["bush", 592, 350, 0.26], ["grave", 250, 178, 0.10],
	["grave", 390, 196, 0.12], ["grave", 200, 306, 0.14],
	["grave", 452, 312, 0.16], ["cross", 272, 150, 0.08],
	["cross", 372, 168, 0.10], ["bare", 42, 210, 0.18],
	["bare", 600, 252, 0.20],
]

const LAMPS := [Vector2(268, 236), Vector2(412, 232), Vector2(318, 128)]

@onready var ground: Sprite2D = $Ground
@onready var wall: Sprite2D = $Wall
@onready var wall_snow: Sprite2D = $WallSnow
@onready var world: Node2D = $World
@onready var footprints: Node2D = $World/Footprints
@onready var snow_back: Node2D = $SnowBack
@onready var snow_front: Node2D = $SnowFront
@onready var lights: Node2D = $Lights
@onready var canvas_mod: CanvasModulate = $CanvasModulate
@onready var player = $World/Player

var coverage := 0.74
var snow_amount := 0.85
var wind := 0.25
var night := 21.0

var ground_snow_on := true
var snow_on := true
var caps_on := true
var footprints_on := true

var caps: Array = []
var _snow_layers: Array = []
var _lamp_lights: Array = []
var _glow_sprites: Array = []
var _mask_debug := false
var _time := 0.0


func _ready() -> void:
	_build_props()
	_build_lamps()
	_build_snow()
	player.setup(self)
	set_coverage(coverage)
	set_snow_amount(snow_amount)
	set_wind(wind)
	set_night(night)


func _process(delta: float) -> void:
	_time += delta
	for i in _lamp_lights.size():
		var l: PointLight2D = _lamp_lights[i]
		var base: float = l.get_meta("base_energy", 1.4)
		l.energy = base * (1.0 + 0.05 * sin(_time * 7.0 + i * 1.7)
			+ 0.025 * sin(_time * 13.0 + i * 2.3))


# ── props ─────────────────────────────────────────────────────────────────
func _build_props() -> void:
	for item in PROPS:
		var name: String = item[0]
		var pos := Vector2(item[1], item[2])
		var threshold: float = item[3]
		var base_tex: Texture2D = load("res://assets/props/%s.png" % name)
		var cap_tex: Texture2D = load("res://assets/props/%s_snow.png" % name)
		var holder := Node2D.new()
		holder.position = pos
		var base := Sprite2D.new()
		base.texture = base_tex
		base.position.y = -base_tex.get_height() / 2.0
		holder.add_child(base)
		var cap := Sprite2D.new()
		cap.texture = cap_tex
		cap.position.y = -cap_tex.get_height() / 2.0
		cap.modulate.a = 0.0
		holder.add_child(cap)
		world.add_child(holder)
		caps.append({"cap": cap, "threshold": threshold})
	wall_snow.modulate.a = 0.0
	caps.append({"cap": wall_snow, "threshold": 0.02})


func _build_lamps() -> void:
	for pos in LAMPS:
		var base_tex: Texture2D = load("res://assets/props/lamp.png")
		var cap_tex: Texture2D = load("res://assets/props/lamp_snow.png")
		var holder := Node2D.new()
		holder.position = pos
		var base := Sprite2D.new()
		base.texture = base_tex
		base.position.y = -base_tex.get_height() / 2.0
		holder.add_child(base)
		var cap := Sprite2D.new()
		cap.texture = cap_tex
		cap.position.y = -cap_tex.get_height() / 2.0
		cap.modulate.a = 0.0
		holder.add_child(cap)
		world.add_child(holder)
		caps.append({"cap": cap, "threshold": 0.05})

		var light := PointLight2D.new()
		light.texture = LIGHT_TEX
		light.position = pos + Vector2(0.0, -59.0)
		light.color = Color(1.0, 0.72, 0.42)
		light.energy = 1.5
		light.texture_scale = 1.7
		light.set_meta("base_energy", 1.5)
		lights.add_child(light)
		_lamp_lights.append(light)

		var glow := Sprite2D.new()
		glow.texture = GLOW_TEX
		glow.position = light.position
		glow.scale = Vector2(2.4, 2.4)
		glow.modulate = Color(1.0, 0.68, 0.35, 0.32)
		glow.z_index = 40
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		lights.add_child(glow)
		_glow_sprites.append(glow)


# ── snow particles ────────────────────────────────────────────────────────
func _build_snow() -> void:
	_snow_layers.append(_make_layer(snow_back, 170, 0.7, 9.0, 0.6))
	_snow_layers.append(_make_layer(snow_front, 55, 1.4, 7.0, 1.0))


func _make_layer(parent: Node2D, base_amount: int, scale: float,
		lifetime: float, alpha: float) -> Dictionary:
	var p := GPUParticles2D.new()
	p.texture = FLAKE
	p.position = Vector2(320.0, 180.0)
	p.amount = base_amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.one_shot = false
	p.emitting = true
	p.visibility_rect = Rect2(-320, -200, 960, 760)

	var cm := CanvasItemMaterial.new()
	cm.particles_animation = true
	cm.particles_anim_h_frames = 8
	cm.particles_anim_v_frames = 3
	cm.particles_anim_loop = true
	p.material = cm

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(340.0, 200.0, 1.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0.0, 22.0, 0.0)
	pm.scale_min = scale * 0.7
	pm.scale_max = scale * 1.25
	pm.color = Color(0.92, 0.96, 1.0, alpha)
	p.process_material = pm
	parent.add_child(p)
	return {"node": p, "base": base_amount, "pm": pm}


# ── controls from the HUD ─────────────────────────────────────────────────
func set_coverage(v: float) -> void:
	coverage = clampf(v, 0.0, 1.0)
	(ground.material as ShaderMaterial).set_shader_parameter("coverage", coverage)
	for c in caps:
		var a: float = clampf((coverage - float(c["threshold"])) / 0.32, 0.0, 1.0)
		(c["cap"] as Sprite2D).modulate.a = a if caps_on else 0.0


func set_snow_amount(v: float) -> void:
	snow_amount = clampf(v, 0.0, 1.0)
	for layer in _snow_layers:
		var p: GPUParticles2D = layer["node"]
		p.amount = maxi(1, int(round(float(layer["base"]) * snow_amount)))
		p.emitting = snow_on and snow_amount > 0.01


func set_wind(v: float) -> void:
	wind = clampf(v, -1.0, 1.0)
	for layer in _snow_layers:
		var pm: ParticleProcessMaterial = layer["pm"]
		pm.gravity = Vector3(wind * 55.0, 22.0, 0.0)


func set_night(t: float) -> void:
	night = clampf(t, 18.0, 24.0)
	var k := (night - 18.0) / 6.0
	canvas_mod.color = Color(0.58, 0.62, 0.76).lerp(Color(0.20, 0.26, 0.44), k)
	for l in _lamp_lights:
		var base: float = 1.1 + 0.7 * k
		l.set_meta("base_energy", base)
	for g in _glow_sprites:
		(g as Sprite2D).modulate.a = 0.22 + 0.18 * k


func set_ground_snow(on: bool) -> void:
	ground_snow_on = on
	(ground.material as ShaderMaterial).set_shader_parameter("snow_on", 1.0 if on else 0.0)


func set_snow_enabled(on: bool) -> void:
	snow_on = on
	set_snow_amount(snow_amount)


func set_caps(on: bool) -> void:
	caps_on = on
	set_coverage(coverage)


func set_footprints(on: bool) -> void:
	footprints_on = on


func toggle_mask_debug() -> bool:
	_mask_debug = not _mask_debug
	(ground.material as ShaderMaterial).set_shader_parameter("debug_mask", 1 if _mask_debug else 0)
	return _mask_debug


func add_footprint(pos: Vector2, facing: int, side: int) -> void:
	if not footprints_on or coverage < 0.10:
		return
	var s := Sprite2D.new()
	s.texture = FOOT_TEX
	var off := Vector2.ZERO
	var ang := 0.0
	match facing:
		0:
			off = Vector2(side * 2.0, 0.0)
			ang = PI / 2.0
		1:
			off = Vector2(side * 2.0, 0.0)
			ang = PI / 2.0
		2:
			off = Vector2(0.0, side * 2.0)
		3:
			off = Vector2(0.0, side * 2.0)
	s.position = pos + off
	s.rotation = ang + (0.12 * side)
	s.scale = Vector2(1.35, 1.35)
	s.modulate = Color(1.0, 1.0, 1.0, 0.82)
	footprints.add_child(s)
	var t := create_tween()
	t.tween_property(s, "modulate:a", 0.0, 12.0)
	t.tween_callback(s.queue_free)


func clear_footprints() -> void:
	for c in footprints.get_children():
		c.queue_free()
