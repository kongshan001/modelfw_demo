class_name EnemyView
extends Node3D
## 3D low-poly enemy presentation. Art interface for T-030:
## replace scenes/enemy_view.tscn, this script, or materials/*.tres.
## One merged vertex-colored mesh + a few animated parts per enemy.

const GData = preload("res://scripts/game_data.gd")
const MK = preload("res://scripts/mesh_kit.gd")
const Mat = preload("res://scripts/material_lib.gd")

static var _white_tex: ImageTexture

var type: String = "walker"
var _body_root: Node3D
var _body_mi: MeshInstance3D
var _overlay_mat: StandardMaterial3D
var _wing_l: Node3D
var _wing_r: Node3D
var _spinner: Node3D
var _hp_bg: Sprite3D
var _hp_fill: Sprite3D
var _hp_width := 0.72
var _hover_height := 0.0
var _bar_height := 1.5
var _time := 0.0
var _phase := 0.0
var _overlay_on := false
var _slow_tint := false


static func white_texture() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


func setup(type_key: String) -> void:
	type = type_key
	for child in get_children():
		child.queue_free()
	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	add_child(_body_root)
	var body := MK.new_st()
	var glow := MK.new_st()
	match type:
		"walker":
			_build_walker(body, glow)
		"moth":
			_build_moth(body, glow)
		"brute":
			_build_brute(body, glow)
		"spore":
			_build_spore(body, glow)
		"boss":
			_build_boss(body, glow)
	_body_mi = MK.make_material_instance(MK.finish(body), Mat.get_mat("char_vertex"))
	_body_mi.name = "Body"
	_body_root.add_child(_body_mi)
	_overlay_mat = Mat.unshaded(Color.WHITE, 0.0, 0.0)
	_overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gm := MeshInstance3D.new()
	gm.mesh = MK.finish(glow)
	gm.material_override = Mat.emissive(_glow_color(), 1.45)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gm.name = "Glow"
	_body_root.add_child(gm)
	_build_health_bar()
	_build_ground_shadow()
	_phase = float(absi(hash(type)) % 100) * 0.13


func _build_ground_shadow() -> void:
	var radius := 0.42
	match type:
		"moth":
			radius = 0.30
		"brute":
			radius = 0.72
		"spore":
			radius = 0.58
		"boss":
			radius = 1.15
	var st := MK.new_st()
	MK.add_disc(st, Vector3.ZERO, radius, 18, Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = MK.finish(st)
	mi.material_override = Mat.unshaded(Color(0, 0, 0), 1.0, 0.24)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.04
	add_child(mi)


func _glow_color() -> Color:
	match type:
		"moth":
			return Color(0.55, 0.95, 0.85)
		"spore":
			return Color(0.72, 0.58, 1.0)
		"boss":
			return Color(1.0, 0.42, 0.18)
		"brute":
			return Color(1.0, 0.55, 0.3)
		_:
			return Color(1.0, 0.55, 0.35)


func _build_health_bar() -> void:
	var tex := white_texture()
	var height := 0.075
	_hp_bg = Sprite3D.new()
	_hp_bg.texture = tex
	_hp_bg.pixel_size = 1.0
	_hp_bg.scale = Vector3(_hp_width + 0.035, height, 1.0)
	_hp_bg.modulate = Color(0.04, 0.035, 0.06, 0.9)
	_hp_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bg.no_depth_test = true
	_hp_bg.render_priority = 8
	_hp_bg.position = Vector3(0, _bar_height, 0)
	_hp_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hp_bg)
	_hp_fill = Sprite3D.new()
	_hp_fill.texture = tex
	_hp_fill.pixel_size = 1.0
	_hp_fill.scale = Vector3(_hp_width, height * 0.7, 1.0)
	_hp_fill.modulate = Color(0.72, 0.86, 0.55, 1)
	_hp_fill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_fill.no_depth_test = true
	_hp_fill.render_priority = 9
	_hp_fill.position = Vector3(0, _bar_height, 0.001)
	_hp_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hp_fill)


func _add_wing(side: float, color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.08, 0.05, 0)
	_body_root.add_child(pivot)
	var st := MK.new_st()
	MK.add_tri(st, Vector3(0, 0, 0), Vector3(-0.08, 0, side * 0.34), Vector3(0.16, 0, side * 0.62), color)
	MK.add_tri(st, Vector3(0, 0, 0), Vector3(0.16, 0, side * 0.62), Vector3(0.30, 0, side * 0.30), color.lightened(0.15))
	MK.add_tri(st, Vector3(0, 0, 0), Vector3(0.30, 0, side * 0.30), Vector3(0.24, 0, side * 0.02), color.darkened(0.1))
	var mi := MeshInstance3D.new()
	mi.mesh = MK.finish(st)
	mi.material_override = Mat.get_mat("char_vertex")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	if side > 0.0:
		_wing_r = pivot
	else:
		_wing_l = pivot


func _build_walker(body: SurfaceTool, glow: SurfaceTool) -> void:
	var dim := Color(0.27, 0.23, 0.33)
	var main := Color(0.38, 0.33, 0.45)
	var skin := Color(0.16, 0.14, 0.20)
	_hover_height = 0.0
	_bar_height = 1.55
	MK.add_cyl(body, Vector3(0, 0.12, 0), 0.34, 0.20, 0.70, 6, dim)
	MK.add_sphere(body, Vector3(0, 0.20, 0), 0.28, main, 7, 4, Vector3(1.0, 0.75, 0.9))
	MK.add_box(body, Vector3(0, 0.80, 0), Vector3(0.36, 0.34, 0.30), main)
	MK.add_box(body, Vector3(-0.01, 0.86, 0.17), Vector3(0.24, 0.22, 0.05), skin)
	MK.add_sphere(body, Vector3(0, 1.02, 0), 0.17, skin, 7, 4)
	MK.add_cyl(body, Vector3(0, 1.10, 0), 0.22, 0.06, 0.20, 6, main.darkened(0.15))
	MK.add_box(body, Vector3(-0.30, 0.68, 0), Vector3(0.12, 0.40, 0.14), main.darkened(0.1), 0.2)
	MK.add_box(body, Vector3(0.30, 0.68, 0), Vector3(0.12, 0.40, 0.14), main.darkened(0.1), -0.2)
	MK.add_box(body, Vector3(-0.12, 0.06, 0.04), Vector3(0.13, 0.12, 0.20), dim.darkened(0.3))
	MK.add_box(body, Vector3(0.12, 0.06, 0.04), Vector3(0.13, 0.12, 0.20), dim.darkened(0.3))
	MK.add_box(body, Vector3(0, 0.62, -0.20), Vector3(0.5, 0.10, 0.10), Color(0.5, 0.38, 0.3))
	MK.add_octa(glow, Vector3(-0.065, 1.03, 0.155), Vector3(0.026, 0.026, 0.02), Color.WHITE)
	MK.add_octa(glow, Vector3(0.065, 1.03, 0.155), Vector3(0.026, 0.026, 0.02), Color.WHITE)


func _build_moth(body: SurfaceTool, glow: SurfaceTool) -> void:
	var pale := Color(0.45, 0.72, 0.66)
	var dim := Color(0.25, 0.46, 0.44)
	_hover_height = 0.88
	_bar_height = 1.30
	MK.add_sphere(body, Vector3(0, 0, 0), 0.17, pale, 7, 4, Vector3(1.7, 0.8, 0.9))
	MK.add_sphere(body, Vector3(0.20, 0.02, 0), 0.10, dim, 6, 4)
	MK.add_sphere(body, Vector3(-0.20, 0.0, 0), 0.12, dim, 6, 4)
	MK.add_cyl(body, Vector3(-0.32, 0.02, 0), 0.04, 0.015, 0.28, 4, pale, 0, false)
	MK.add_cyl(body, Vector3(-0.32, 0.02, 0), 0.02, 0.01, 0.22, 4, pale, 1.0, false)
	MK.add_octa(glow, Vector3(0.26, 0.02, 0), Vector3(0.04, 0.05, 0.04), Color.WHITE)
	_add_wing(1.0, Color(0.55, 0.85, 0.78))
	_add_wing(-1.0, Color(0.48, 0.78, 0.72))


func _build_brute(body: SurfaceTool, glow: SurfaceTool) -> void:
	var rust := Color(0.48, 0.30, 0.23)
	var rust_hi := Color(0.62, 0.40, 0.30)
	var dark := Color(0.22, 0.15, 0.13)
	_hover_height = 0.0
	_bar_height = 1.55
	MK.add_box(body, Vector3(0, 0.62, 0), Vector3(1.0, 0.55, 0.62), rust)
	MK.add_box(body, Vector3(0.27, 0.82, 0), Vector3(0.46, 0.34, 0.50), rust_hi)
	MK.add_box(body, Vector3(0.46, 0.88, 0), Vector3(0.30, 0.26, 0.40), rust, 0.1)
	MK.add_box(body, Vector3(0.63, 0.78, 0), Vector3(0.22, 0.20, 0.30), dark)
	MK.add_cyl(body, Vector3(0.55, 1.02, 0.16), 0.06, 0.0, 0.30, 5, Color(0.78, 0.72, 0.58), 0.5)
	MK.add_cyl(body, Vector3(0.55, 1.02, -0.16), 0.06, 0.0, 0.30, 5, Color(0.78, 0.72, 0.58), -0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.add_box(body, Vector3(0.28 * sx, 0.23, 0.22 * sz), Vector3(0.18, 0.46, 0.18), dark)
			MK.add_box(body, Vector3(0.28 * sx, 0.03, 0.24 * sz), Vector3(0.22, 0.10, 0.26), rust.lightened(0.06))
	MK.add_box(body, Vector3(0, 0.70, 0.32), Vector3(0.72, 0.28, 0.08), rust_hi.darkened(0.12))
	MK.add_octa(glow, Vector3(0.55, 0.88, 0.17), Vector3(0.035, 0.035, 0.02), Color.WHITE)
	MK.add_octa(glow, Vector3(0.55, 0.88, -0.17), Vector3(0.035, 0.035, 0.02), Color.WHITE)
	MK.add_octa(glow, Vector3(-0.05, 0.78, 0.36), Vector3(0.06, 0.08, 0.02), Color.WHITE)


func _build_spore(body: SurfaceTool, glow: SurfaceTool) -> void:
	var violet := Color(0.52, 0.42, 0.68)
	var violet_dark := Color(0.30, 0.24, 0.42)
	_hover_height = 0.78
	_bar_height = 1.55
	MK.add_sphere(body, Vector3(0, 0, 0), 0.38, violet, 8, 5, Vector3(1.0, 0.95, 1.0))
	MK.add_sphere(body, Vector3(0, 0.26, 0), 0.24, violet_dark, 7, 4, Vector3(1.2, 0.6, 1.2))
	for i in 6:
		var ang := TAU * float(i) / 6.0
		var base := Vector3(cos(ang) * 0.26, -0.18, sin(ang) * 0.26)
		var b := Basis.from_euler(Vector3(sin(ang) * 0.6, ang, cos(ang) * 0.6))
		MK.add_cyl_xf(body, Transform3D(b, base), 0.05, 0.015, 0.42, 4, violet_dark)
	MK.add_octa(glow, Vector3(0, 0.05, 0), Vector3(0.14, 0.18, 0.14), Color.WHITE)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + 0.5
		MK.add_octa(glow, Vector3(cos(ang) * 0.5, 0.18 + sin(ang) * 0.1, sin(ang) * 0.5),
			Vector3(0.035, 0.06, 0.035), Color.WHITE)


func _build_boss(body: SurfaceTool, glow: SurfaceTool) -> void:
	var obsidian := Color(0.16, 0.13, 0.16)
	var rock := Color(0.26, 0.20, 0.20)
	var ember := Color(0.86, 0.36, 0.18)
	_hover_height = 0.0
	_bar_height = 2.65
	_hp_width = 1.5
	MK.add_cyl(body, Vector3(0, 0.1, 0), 0.62, 0.45, 0.65, 6, obsidian)
	MK.add_box(body, Vector3(0, 1.05, 0), Vector3(1.05, 0.85, 0.70), rock)
	MK.add_box(body, Vector3(0, 1.55, 0), Vector3(0.78, 0.36, 0.56), obsidian)
	MK.add_box(body, Vector3(0.40, 1.18, 0), Vector3(0.44, 0.62, 0.60), rock.darkened(0.1), 0.1)
	MK.add_box(body, Vector3(-0.40, 1.18, 0), Vector3(0.44, 0.62, 0.60), rock.darkened(0.1), -0.1)
	MK.add_box(body, Vector3(0.62, 0.80, 0.12), Vector3(0.36, 0.90, 0.36), obsidian, 0.15)
	MK.add_box(body, Vector3(-0.62, 0.80, 0.12), Vector3(0.36, 0.90, 0.36), obsidian, -0.15)
	MK.add_box(body, Vector3(0, 1.42, 0.36), Vector3(0.34, 0.22, 0.12), ember.darkened(0.4))
	MK.add_box(body, Vector3(-0.50, 0.10, 0.12), Vector3(0.30, 0.35, 0.30), obsidian)
	MK.add_box(body, Vector3(0.50, 0.10, 0.12), Vector3(0.30, 0.35, 0.30), obsidian)
	for i in 3:
		var ang := -0.55 + i * 0.55
		MK.add_cyl(body, Vector3(sin(ang) * 0.35, 1.72, 0.10), 0.10, 0.0, 0.55 + i * 0.1, 5,
			Color(0.55, 0.48, 0.42), ang * 0.4)
	MK.add_octa(glow, Vector3(0.19, 1.57, 0.29), Vector3(0.055, 0.055, 0.03), Color.WHITE)
	MK.add_octa(glow, Vector3(-0.19, 1.57, 0.29), Vector3(0.055, 0.055, 0.03), Color.WHITE)
	for y in [0.75, 0.95, 1.30]:
		MK.add_box(glow, Vector3(0.02, y, 0.36), Vector3(0.55 - y * 0.15, 0.035, 0.02), ember)
	MK.add_box(glow, Vector3(0.32, 1.10, 0.33), Vector3(0.03, 0.36, 0.02), ember)
	MK.add_box(glow, Vector3(-0.32, 1.10, 0.33), Vector3(0.03, 0.36, 0.02), ember)


func head_height() -> float:
	return _bar_height - 0.25


func sync(enemy, world_pos: Vector3, delta: float) -> void:
	_time += delta
	position = world_pos
	rotation.y = -enemy.angle
	var bob := 0.0
	match type:
		"moth":
			bob = sin(_time * 7.0 + _phase) * 0.09
			if _wing_l != null:
				_wing_l.rotation.x = 0.15 + sin(_time * 26.0 + _phase) * 0.85
			if _wing_r != null:
				_wing_r.rotation.x = -(0.15 + sin(_time * 26.0 + _phase) * 0.85)
		"spore":
			bob = sin(_time * 1.8 + _phase) * 0.14
			if _body_root != null:
				var s := 1.0 + sin(_time * 2.2 + _phase) * 0.035
				_body_root.scale = Vector3(s, s, s)
		"walker":
			bob = absf(sin(_time * 7.0 + _phase)) * 0.045
			if _body_root != null:
				_body_root.rotation.z = sin(_time * 7.0 + _phase) * 0.035
		"brute":
			bob = absf(sin(_time * 4.0 + _phase)) * 0.035
			if _body_root != null:
				_body_root.rotation.z = sin(_time * 4.0 + _phase) * 0.02
		"boss":
			bob = absf(sin(_time * 2.0 + _phase)) * 0.05
			if _body_root != null:
				_body_root.rotation.z = sin(_time * 2.0 + _phase) * 0.015
	if _body_root != null:
		_body_root.position.y = _hover_height + bob
	if _hp_bg != null:
		_hp_bg.position.y = _bar_height + bob
		_hp_fill.position.y = _bar_height + bob + 0.001
		var ratio: float = clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
		_hp_fill.scale.x = _hp_width * maxf(0.0, ratio)
		_hp_fill.modulate = Color(0.95, 0.55, 0.35, 1.0) if type == "boss" else Color(0.72, 0.86, 0.55, 1.0)
	# hit flash / slow tint, using material_overlay
	if _body_mi != null:
		var flash: bool = enemy.flash > 0.0
		var slowed: bool = enemy.slow_t > 0.0
		if flash:
			_overlay_mat.albedo_color = Color(1, 0.96, 0.9, 0.6)
			_overlay_mat.emission_enabled = false
			_body_mi.material_overlay = _overlay_mat
			_overlay_on = true
			_slow_tint = false
		elif slowed:
			_overlay_mat.albedo_color = Color(0.35, 0.8, 0.9, 0.20)
			if not _slow_tint or not _overlay_on:
				_body_mi.material_overlay = _overlay_mat
			_overlay_on = true
			_slow_tint = true
		else:
			if _overlay_on:
				_body_mi.material_overlay = null
			_overlay_on = false
			_slow_tint = false
	if _hp_fill != null:
		_hp_fill.visible = enemy.hp < enemy.max_hp or type == "boss"


func set_health_visible(on: bool) -> void:
	if _hp_bg != null:
		_hp_bg.visible = on
	if _hp_fill != null:
		_hp_fill.visible = on
