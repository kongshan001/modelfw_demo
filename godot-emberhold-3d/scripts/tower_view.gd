class_name TowerView
extends Node3D
## 3D low-poly tower presentation. Art interface for T-030:
## replace scenes/tower_view.tscn, this script, or materials/*.tres.
## Gameplay values are never read here; state is pushed by main.gd.

const GData = preload("res://scripts/game_data.gd")
const MK = preload("res://scripts/mesh_kit.gd")
const Mat = preload("res://scripts/material_lib.gd")

var type: String = "bolt"
var level: int = 0
var is_ghost := false
var _rig: Node3D
var _turret: Node3D
var _spinner: Node3D
var _flame: Node3D
var _muzzle: MeshInstance3D
var _glow_nodes: Array[Node3D] = []
var _time := 0.0
var _fire_flash := 0.0
var _ghost_mat: StandardMaterial3D
var _accent := Color(1, 0.5, 0.2)


func setup(type_key: String, lvl: int = 0, ghost: bool = false) -> void:
	type = type_key
	level = lvl
	is_ghost = ghost
	_accent = Color(GData.TOWERS[type]["color"])
	if ghost:
		_ghost_mat = Mat.unshaded(Color(0.5, 0.95, 0.5, 0.55), 1.0, 0.55)
	_rebuild()


func set_level(lvl: int) -> void:
	if lvl == level:
		return
	level = lvl
	_rebuild()


func set_ghost_valid(valid: bool) -> void:
	if _ghost_mat == null:
		return
	_ghost_mat.albedo_color = Color(0.45, 0.95, 0.5, 0.55) if valid else Color(0.95, 0.3, 0.28, 0.55)


func set_facing(angle_rad: float) -> void:
	if _turret != null:
		_turret.rotation.y = -angle_rad


func pulse_fire() -> void:
	_fire_flash = 1.0
	if _muzzle != null:
		_muzzle.visible = true


func muzzle_height() -> float:
	match type:
		"bolt":
			return 1.25
		"flame":
			return 1.35
		"frost":
			return 1.35
		_:
			return 1.1


func _clear_rig() -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = null
	_turret = null
	_spinner = null
	_flame = null
	_muzzle = null
	_glow_nodes.clear()


func _rebuild() -> void:
	_clear_rig()
	_rig = Node3D.new()
	_rig.name = "TowerModel"
	add_child(_rig)
	var body := MK.new_st()
	var glow := MK.new_st()
	match type:
		"bolt":
			_build_bolt(body, glow)
		"flame":
			_build_flame(body, glow)
		"frost":
			_build_frost(body, glow)
		"mint":
			_build_mint(body, glow)
	_add_body(body)
	_add_glow(glow)
	if not is_ghost:
		var sh_st := MK.new_st()
		MK.add_disc(sh_st, Vector3.ZERO, 0.95, 20, Color.WHITE)
		var sh := MeshInstance3D.new()
		sh.mesh = MK.finish(sh_st)
		sh.material_override = Mat.unshaded(Color(0, 0, 0), 1.0, 0.25)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.position.y = 0.055
		_rig.add_child(sh)


func _add_body(st: SurfaceTool) -> void:
	var mi := MK.make_material_instance(MK.finish(st), _ghost_mat if is_ghost else Mat.get_mat("char_vertex"))
	mi.name = "Body"
	_rig.add_child(mi)


func _add_glow(st: SurfaceTool, color: Color = Color.TRANSPARENT) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MK.finish(st)
	if is_ghost:
		mi.material_override = _ghost_mat
	else:
		mi.material_override = Mat.emissive(color if color != Color.TRANSPARENT else _accent, 1.35)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Glow"
	_rig.add_child(mi)
	_glow_nodes.append(mi)


func _base(body: SurfaceTool, radius: float, tall: bool) -> void:
	var stone := Color(0.35, 0.32, 0.38)
	var stone_dark := Color(0.20, 0.18, 0.24)
	MK.add_cyl(body, Vector3.ZERO, radius + 0.18, radius + 0.10, 0.16, 8, stone_dark)
	MK.add_cyl(body, Vector3(0, 0.16, 0), radius + 0.05, radius, 0.16, 8, stone)
	MK.add_cyl(body, Vector3(0, 0.32, 0), radius * 0.72, radius * 0.62, 0.18, 8, stone_dark)
	if tall:
		MK.add_cyl(body, Vector3(0, 0.5, 0), radius * 0.38, radius * 0.30, 0.55, 6, stone)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var p := Vector3(cos(ang), 0, sin(ang)) * (radius + 0.02)
		MK.add_box(body, p + Vector3(0, 0.22, 0), Vector3(0.18, 0.30, 0.18), stone_dark, ang)
	for i in level + 1:
		MK.add_box(body, Vector3(0, 0.345 + i * 0.038, 0), Vector3(radius * 1.4, 0.022, 0.10),
			Color(0.85, 0.66, 0.32), i * 0.6)


func _build_bolt(body: SurfaceTool, glow: SurfaceTool) -> void:
	var wood := Color(0.31, 0.23, 0.18)
	var wood_hi := Color(0.45, 0.33, 0.23)
	_base(body, 0.62, true)
	var top := 1.05
	MK.add_cyl(body, Vector3(0, 0.5, 0), 0.26, 0.22, 0.55, 6, Color(0.42, 0.38, 0.36))
	MK.add_box(body, Vector3(0, top - 0.15, 0), Vector3(0.62, 0.10, 0.62), Color(0.30, 0.27, 0.30))
	_turret = Node3D.new()
	_turret.position = Vector3(0, top, 0)
	_rig.add_child(_turret)
	var tb := MK.new_st()
	var tg := MK.new_st()
	MK.add_box(tb, Vector3(0.02, 0.06, 0), Vector3(0.55, 0.16, 0.22), wood)
	MK.add_box(tb, Vector3(0.22, 0.06, 0), Vector3(0.22, 0.10, 0.54), wood_hi)
	MK.add_box(tb, Vector3(0.10, 0.18, 0.24), Vector3(0.34, 0.08, 0.10), wood_hi, 0.5)
	MK.add_box(tb, Vector3(0.10, 0.18, -0.24), Vector3(0.34, 0.08, 0.10), wood_hi, -0.5)
	MK.add_box(tb, Vector3(0.18, 0.20, 0), Vector3(0.06, 0.06, 0.56), wood_hi)
	MK.add_box(tb, Vector3(0.62, 0.06, 0), Vector3(0.55, 0.035, 0.035), Color(0.72, 0.65, 0.48))
	MK.add_octa(tg, Vector3(0.62, 0.06, 0), Vector3(0.10, 0.07, 0.07), Color.WHITE)
	if level >= 1:
		MK.add_box(tb, Vector3(-0.28, 0.06, 0), Vector3(0.16, 0.20, 0.30), Color(0.55, 0.45, 0.30))
	if level >= 2:
		MK.add_octa(tg, Vector3(0.05, 0.22, 0), Vector3(0.08, 0.14, 0.08), Color.WHITE)
		MK.add_box(tb, Vector3(-0.05, -0.02, 0.30), Vector3(0.6, 0.03, 0.03), Color(0.95, 0.72, 0.3))
	var turret_body := MK.make_material_instance(MK.finish(tb), _ghost_mat if is_ghost else Mat.get_mat("char_vertex"))
	_turret.add_child(turret_body)
	var tglow := MeshInstance3D.new()
	tglow.mesh = MK.finish(tg)
	tglow.material_override = _ghost_mat if is_ghost else Mat.emissive(_accent, 1.5)
	tglow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turret.add_child(tglow)
	_glow_nodes.append(tglow)
	MK.add_octa(glow, Vector3(0, 0.46, 0), Vector3(0.30, 0.06, 0.30), Color.WHITE)
	_muzzle = MeshInstance3D.new()
	var mst := MK.new_st()
	MK.add_octa(mst, Vector3.ZERO, Vector3(0.16, 0.16, 0.16), Color.WHITE)
	_muzzle.mesh = MK.finish(mst)
	_muzzle.material_override = Mat.unshaded(_accent, 2.0, 0.9)
	_muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle.position = Vector3(0.95, 0.06, 0)
	_muzzle.visible = false
	_turret.add_child(_muzzle)


func _build_flame(body: SurfaceTool, glow: SurfaceTool) -> void:
	_base(body, 0.70, false)
	var stone := Color(0.30, 0.24, 0.25)
	var stone_hi := Color(0.42, 0.33, 0.31)
	var r := 0.62 + level * 0.05
	MK.add_cyl(body, Vector3(0, 0.48, 0), r, r * 0.88, 0.34, 8, stone)
	MK.add_cyl(body, Vector3(0, 0.80, 0), r * 0.88, r * 0.94, 0.08, 8, stone_hi)
	MK.add_disc(glow, Vector3(0, 0.83, 0), r * 0.72, 16, Color.WHITE)
	for i in 3:
		var ang := TAU * float(i) / 3.0
		MK.add_cyl(body, Vector3(cos(ang) * (r + 0.05), 0.5, sin(ang) * (r + 0.05)),
			0.09, 0.02, 0.55 + level * 0.1, 5, stone_hi)
	_flame = Node3D.new()
	_flame.position = Vector3(0, 1.05, 0)
	_rig.add_child(_flame)
	var fst := MK.new_st()
	MK.add_cyl(fst, Vector3.ZERO, 0.26 + level * 0.03, 0.0, 0.65 + level * 0.12, 6, Color.WHITE)
	MK.add_cyl(fst, Vector3(0.06, 0.05, 0.04), 0.13, 0.0, 0.45, 5, Color.WHITE)
	var fmi := MeshInstance3D.new()
	fmi.mesh = MK.finish(fst)
	fmi.material_override = _ghost_mat if is_ghost else Mat.emissive(_accent, 1.45)
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.add_child(fmi)
	for i in 4 + level:
		var ang := TAU * float(i) / (4.0 + level) + _time
		MK.add_octa(glow, Vector3(cos(ang) * (r + 0.15), 0.95 + sin(ang * 2.0) * 0.08, sin(ang) * (r + 0.15)),
			Vector3(0.05, 0.08, 0.05), Color.WHITE)


func _build_frost(body: SurfaceTool, glow: SurfaceTool) -> void:
	_base(body, 0.68, false)
	var ice := Color(0.42, 0.72, 0.72)
	var ice_dark := Color(0.20, 0.42, 0.46)
	for i in 4 + level:
		var ang := TAU * float(i) / float(4 + level) + 0.3
		var radius := 0.48
		var h := 0.55 + (i % 3) * 0.18 + level * 0.08
		MK.add_cyl(body, Vector3(cos(ang) * radius, 0.42, sin(ang) * radius), 0.14, 0.0, h, 5, ice_dark)
	MK.add_ring(glow, Vector3(0, 0.44, 0), 0.50, 0.58, 20, Color.WHITE)
	_spinner = Node3D.new()
	_spinner.position = Vector3(0, 1.30, 0)
	_rig.add_child(_spinner)
	var cst := MK.new_st()
	MK.add_octa(cst, Vector3.ZERO, Vector3(0.26 + level * 0.04, 0.45 + level * 0.05, 0.26), Color.WHITE)
	MK.add_octa(cst, Vector3(0, 0.5, 0), Vector3(0.12, 0.22, 0.12), Color.WHITE)
	var cmi := MeshInstance3D.new()
	cmi.mesh = MK.finish(cst)
	cmi.material_override = _ghost_mat if is_ghost else Mat.emissive(Color(0.6, 0.95, 0.92), 1.35)
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spinner.add_child(cmi)
	for i in 3:
		var ang := TAU * float(i) / 3.0
		MK.add_octa(glow, Vector3(cos(ang) * 0.6, 0.7 + sin(ang) * 0.12, sin(ang) * 0.6),
			Vector3(0.05, 0.12, 0.05), Color.WHITE)


func _build_mint(body: SurfaceTool, glow: SurfaceTool) -> void:
	var gold := Color(0.85, 0.66, 0.32)
	var gold_hi := Color(1.0, 0.85, 0.5)
	var stone := Color(0.32, 0.29, 0.34)
	MK.add_box(body, Vector3(0, 0.09, 0), Vector3(1.1, 0.18, 1.1), stone)
	MK.add_box(body, Vector3(0, 0.26, 0), Vector3(0.82, 0.18, 0.82), stone.darkened(0.1))
	MK.add_box(body, Vector3(0, 0.41, 0), Vector3(0.58, 0.14, 0.58), gold.darkened(0.25))
	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		MK.add_cyl(body, Vector3(cos(ang) * 0.46, 0.18, sin(ang) * 0.46), 0.07, 0.05, 0.7, 5, gold)
	MK.add_ring(glow, Vector3(0, 0.50, 0), 0.34, 0.40, 16, Color.WHITE)
	_spinner = Node3D.new()
	_spinner.position = Vector3(0, 1.18, 0)
	_rig.add_child(_spinner)
	var cst := MK.new_st()
	MK.add_cyl(cst, Vector3(0, -0.05, 0), 0.30, 0.30, 0.06, 12, gold_hi, 0.0, true)
	MK.add_box(cst, Vector3(0, 0.02, 0), Vector3(0.05, 0.12, 0.16), gold.darkened(0.3))
	var cmi := MeshInstance3D.new()
	cmi.mesh = MK.finish(cst)
	cmi.material_override = _ghost_mat if is_ghost else Mat.get_mat("gold")
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmi.rotation.z = PI * 0.5
	_spinner.add_child(cmi)
	for i in 3 + level:
		var ang := TAU * float(i) / float(3 + level)
		MK.add_octa(glow, Vector3(cos(ang) * 0.55, 0.75 + sin(ang * 3.0) * 0.1, sin(ang) * 0.55),
			Vector3(0.04, 0.08, 0.04), Color.WHITE)
	if level >= 1:
		MK.add_cyl(body, Vector3(0, 0.48, 0), 0.20, 0.20, 0.06, 10, gold)
	if level >= 2:
		MK.add_octa(glow, Vector3(0, 1.7, 0), Vector3(0.08, 0.14, 0.08), Color.WHITE)


func _process(delta: float) -> void:
	_time += delta
	if _spinner != null:
		_spinner.rotation.y += delta * (1.8 if type == "frost" else 1.0)
		if type == "frost":
			_spinner.position.y = 1.30 + sin(_time * 1.6) * 0.06
		else:
			_spinner.position.y = 1.18 + sin(_time * 1.4) * 0.05
	if _flame != null:
		var s := 0.9 + sin(_time * 7.0) * 0.10
		_flame.scale = Vector3(1.0 + sin(_time * 5.0) * 0.04, s, 1.0)
	if _fire_flash > 0.0:
		_fire_flash = maxf(0.0, _fire_flash - delta * 7.0)
		if _muzzle != null:
			_muzzle.visible = _fire_flash > 0.0
			var s := 0.6 + _fire_flash * 0.9
			_muzzle.scale = Vector3(s, s, s)
	for i in _glow_nodes.size():
		var n: Node3D = _glow_nodes[i]
		if n is MeshInstance3D:
			var m := (n as MeshInstance3D).material_override as StandardMaterial3D
			if m != null and not is_ghost:
				m.emission_energy_multiplier = 1.5 + sin(_time * 2.4 + i) * 0.25
