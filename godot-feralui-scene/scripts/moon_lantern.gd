extends Node3D
## 苔灯：可轻触的点亮/收暗小物。程序化石灯、暖光珠、地面光池与一盏无阴影点光。
## 微动画：火焰呼吸、交互闪光、悬停轻亮。声音由主控按信号统一播放。

signal interacted(id: String, message: String, anchor: Vector3)

const Geo = preload("res://scripts/geo.gd")

var display_name := "苔灯"
var display_id := "lantern_path"
var lit := true
var focused := false
var nightness := 1.0
var rain_amount := 0.0
var quality_high := true
var time := 0.0
var phase := 0.0

var stone_body: MeshInstance3D
var orb: MeshInstance3D
var halo: MeshInstance3D
var light_pool: MeshInstance3D
var lamp_light: OmniLight3D
var orb_material: StandardMaterial3D
var halo_material: StandardMaterial3D
var pool_material: StandardMaterial3D
var _flash := 0.0


func _ready() -> void:
	phase = fmod(absf(position.x) * 1.73 + absf(position.z) * 0.91, TAU)
	_build()


func _build() -> void:
	var stone_mat := Geo.make_vcol_material(0.94)
	var st := Geo.surface()
	var stone := Color(0.43, 0.40, 0.53)
	var stone_light := Color(0.61, 0.58, 0.70)
	var stone_moss := Color(0.27, 0.39, 0.32)
	Geo.add_ico(st, Vector3(0, 0.09, 0), Vector3(0.44, 0.13, 0.41),
			stone, Basis.IDENTITY, 31, 0.16)
	Geo.add_cylinder(st, Vector3(0, 0.15, 0), Vector3(0, 0.70, 0),
			0.17, 0.12, 6, stone_light)
	Geo.add_ico(st, Vector3(0, 0.72, 0), Vector3(0.30, 0.07, 0.28),
			stone_light, Basis.IDENTITY, 32, 0.10)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.add_cylinder(st,
				Vector3(sx * 0.16, 0.76, sz * 0.16),
				Vector3(sx * 0.14, 1.06, sz * 0.14),
				0.025, 0.022, 4, stone)
	Geo.add_ico(st, Vector3(0, 1.08, 0), Vector3(0.34, 0.055, 0.32),
			stone_light, Basis.IDENTITY, 33, 0.08)
	Geo.add_cone(st, Vector3(0, 1.11, 0), 0.31, 0.22, 6,
			stone, stone_moss)
	Geo.add_ico(st, Vector3(0.24, 0.06, 0.15), Vector3(0.11, 0.035, 0.10),
			stone_moss, Basis.IDENTITY, 34, 0.22)
	stone_body = MeshInstance3D.new()
	stone_body.name = "StoneBody"
	stone_body.mesh = Geo.finish(st)
	stone_body.material_override = stone_mat
	stone_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(stone_body)

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.115
	orb_mesh.height = 0.23
	orb_mesh.radial_segments = 12
	orb_mesh.rings = 6
	orb_material = StandardMaterial3D.new()
	orb_material.albedo_color = Color(1.0, 0.48, 0.18)
	orb_material.emission_enabled = true
	orb_material.emission = Color(1.0, 0.36, 0.08)
	orb_material.emission_energy_multiplier = 1.6
	orb_material.roughness = 0.35
	orb = MeshInstance3D.new()
	orb.name = "WarmOrb"
	orb.mesh = orb_mesh
	orb.material_override = orb_material
	orb.position = Vector3(0, 0.92, 0)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)

	var tex := Geo.make_radial_texture(64, 2.15)
	halo_material = StandardMaterial3D.new()
	halo_material.albedo_texture = tex
	halo_material.albedo_color = Color(1.0, 0.36, 0.08, 0.24)
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo_material.disable_receive_shadows = true
	halo_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(0.72, 0.72)
	halo = MeshInstance3D.new()
	halo.name = "WarmHalo"
	halo.mesh = halo_quad
	halo.material_override = halo_material
	halo.position = Vector3(0, 0.92, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	pool_material = StandardMaterial3D.new()
	pool_material.albedo_texture = tex
	pool_material.albedo_color = Color(1.0, 0.33, 0.06, 0.18)
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pool_material.disable_receive_shadows = true
	pool_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var pool_quad := QuadMesh.new()
	pool_quad.size = Vector2(5.2, 3.9)
	light_pool = MeshInstance3D.new()
	light_pool.name = "LightPool"
	light_pool.mesh = pool_quad
	light_pool.material_override = pool_material
	light_pool.position = Vector3(0, 0.078, 0)
	light_pool.rotation_degrees = Vector3(-90, 0, 0)
	light_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(light_pool)

	lamp_light = OmniLight3D.new()
	lamp_light.name = "WarmLight"
	lamp_light.position = Vector3(0, 0.98, 0)
	lamp_light.light_color = Color(1.0, 0.42, 0.12)
	lamp_light.omni_range = 7.0
	lamp_light.omni_attenuation = 0.72
	lamp_light.light_energy = 5.0
	lamp_light.shadow_enabled = false
	add_child(lamp_light)


func tick(delta: float, t: float, night: float, rain: float, high: bool) -> void:
	time = t
	nightness = night
	rain_amount = rain
	quality_high = high
	_flash = maxf(0.0, _flash - delta * 1.6)
	var level := 1.0 if lit else 0.38
	var noct := 0.22 + nightness * 0.78
	var breathe := 1.0 + 0.055 * sin(t * 2.15 + phase) + 0.025 * sin(t * 5.7 + phase * 2.1)
	var focus_boost := 0.12 if focused else 0.0
	var flash_boost := _flash * 0.85
	var energy := (1.4 + 5.1 * noct) * level * breathe * (1.0 + focus_boost * 0.5 + flash_boost)
	if not quality_high:
		energy *= 0.84
	lamp_light.light_energy = energy
	lamp_light.omni_range = 5.4 + 2.2 * noct + flash_boost
	orb_material.emission_energy_multiplier = (0.32 + 0.78 * noct) * level * (1.0 + flash_boost * 0.55)
	orb.scale = Vector3.ONE * (1.0 + 0.025 * sin(t * 3.1 + phase) + flash_boost * 0.10)
	var halo_alpha := (0.025 + 0.095 * noct) * level * (1.0 + focus_boost * 0.8 + flash_boost * 0.9)
	halo_material.albedo_color = Color(1.0, 0.25, 0.025, clampf(halo_alpha, 0.0, 0.26))
	halo.scale = Vector3.ONE * (1.0 + 0.05 * sin(t * 1.7 + phase) + flash_boost * 0.30)
	var pool_alpha := (0.075 + 0.27 * noct) * level * (1.0 + focus_boost * 0.4 + flash_boost * 1.0)
	pool_material.albedo_color = Color(1.0, 0.22, 0.018, clampf(pool_alpha, 0.0, 0.46))
	light_pool.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 1.15 + phase) + flash_boost * 0.15)


func interact() -> bool:
	lit = not lit
	_flash = 1.0
	var message := "苔灯亮了，暖色顺着石缝漫开。" if lit else "灯影轻下来，萤火替你守夜。"
	interacted.emit(display_id, message, get_interaction_anchor())
	return true


func set_focused(value: bool) -> void:
	focused = value


func get_interaction_anchor() -> Vector3:
	return global_position + Vector3(0, 1.02, 0)


func get_display_name() -> String:
	return display_name


func get_display_id() -> String:
	return display_id


func reset() -> void:
	lit = true
	_flash = 0.0
	focused = false
