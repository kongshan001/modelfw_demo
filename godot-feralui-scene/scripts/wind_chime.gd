extends Node3D
## 玻璃风铃：亭檐下的可交互小物。程序化玻璃管、纸签与星屑；交互会摇响并生成微光。
## 音频由主控统一触发，避免场景脚本耦合音频设备。

signal interacted(id: String, message: String, anchor: Vector3)

const Geo = preload("res://scripts/geo.gd")

var display_name := "风铃"
var display_id := "wind_chime"
var focused := false
var nightness := 1.0
var rain_amount := 0.0
var quality_high := true
var struck_count := 0
var impulse := 0.0

var swing_pivot: Node3D
var chime_body: MeshInstance3D
var charm: MeshInstance3D
var charm_material: StandardMaterial3D
var chime_light: OmniLight3D
var sparks: CPUParticles3D
var time := 0.0
var phase := 0.0


func _ready() -> void:
	phase = fmod(absf(position.x) * 0.87 + absf(position.z) * 1.31, TAU)
	_build()


func _build() -> void:
	swing_pivot = Node3D.new()
	swing_pivot.name = "SwingPivot"
	swing_pivot.position = Vector3(0, 0.02, 0)
	add_child(swing_pivot)

	var mat := Geo.make_vcol_material(0.32)
	mat.metallic = 0.18
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.52, 0.20)
	mat.emission_energy_multiplier = 0.30
	var st := Geo.surface()
	var cord := Color(0.55, 0.47, 0.35)
	var wood := Color(0.32, 0.23, 0.18)
	var glass_colors := [
		Color(1.00, 0.83, 0.50), Color(0.56, 0.80, 0.68),
		Color(0.69, 0.58, 0.84), Color(0.96, 0.72, 0.55),
	]
	# 顶部横木和小铜环。
	Geo.add_cylinder(st, Vector3(0, 0.16, 0), Vector3(0, 0.02, 0), 0.018, 0.018, 5, cord)
	Geo.add_cylinder(st, Vector3(-0.18, 0.02, 0), Vector3(0.18, 0.02, 0), 0.024, 0.024, 6, wood)
	var xs := [-0.135, -0.045, 0.045, 0.135]
	var lens := [0.48, 0.60, 0.53, 0.42]
	for i in range(4):
		var x: float = xs[i]
		var l: float = lens[i]
		Geo.add_cylinder(st, Vector3(x, 0.01, 0), Vector3(x, -0.15, 0),
				0.0045, 0.0045, 4, cord)
		Geo.add_cylinder(st, Vector3(x, -0.15, 0), Vector3(x, -0.15 - l, 0),
				0.025, 0.023, 6, glass_colors[i], true)
	# 中间木槌。
	Geo.add_cylinder(st, Vector3(0, -0.14, 0), Vector3(0, -0.46, 0),
			0.005, 0.005, 4, cord)
	Geo.add_ico(st, Vector3(0, -0.50, 0), Vector3(0.062, 0.075, 0.062),
			Color(0.64, 0.46, 0.27), Basis.IDENTITY, 77, 0.10)
	# 底部浅米色纸签，给视觉一个轻盈落点。
	Geo.add_cylinder(st, Vector3(0, -0.56, 0), Vector3(0, -0.68, 0),
			0.004, 0.004, 4, cord)
	Geo.add_quad(st,
		Vector3(-0.09, -0.66, 0.0), Vector3(0.09, -0.66, 0.0),
		Vector3(0.10, -0.94, 0.025), Vector3(-0.08, -0.93, 0.02),
		Color(0.90, 0.82, 0.63), Vector3(0, 0, 1))

	chime_body = MeshInstance3D.new()
	chime_body.name = "GlassChime"
	chime_body.mesh = Geo.finish(st)
	chime_body.material_override = mat
	chime_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	swing_pivot.add_child(chime_body)

	var charm_mesh := SphereMesh.new()
	charm_mesh.radius = 0.037
	charm_mesh.height = 0.074
	charm_mesh.radial_segments = 8
	charm_mesh.rings = 4
	charm_material = StandardMaterial3D.new()
	charm_material.albedo_color = Color(1.0, 0.78, 0.44)
	charm_material.emission_enabled = true
	charm_material.emission = Color(1.0, 0.65, 0.30)
	charm_material.emission_energy_multiplier = 2.8
	charm_material.roughness = 0.2
	charm = MeshInstance3D.new()
	charm.name = "MoonCharm"
	charm.mesh = charm_mesh
	charm.material_override = charm_material
	charm.position = Vector3(0, -0.15 - 0.60, 0)
	charm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swing_pivot.add_child(charm)

	var charm_halo_mat := StandardMaterial3D.new()
	charm_halo_mat.albedo_texture = Geo.make_radial_texture(32, 2.2)
	charm_halo_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.18)
	charm_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	charm_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	charm_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	charm_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	charm_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	charm_halo_mat.disable_receive_shadows = true
	var charm_halo_quad := QuadMesh.new()
	charm_halo_quad.size = Vector2(0.42, 0.42)
	var charm_halo := MeshInstance3D.new()
	charm_halo.name = "CharmHalo"
	charm_halo.mesh = charm_halo_quad
	charm_halo.material_override = charm_halo_mat
	charm_halo.position = charm.position
	charm_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	swing_pivot.add_child(charm_halo)

	chime_light = OmniLight3D.new()
	chime_light.name = "ChimeWarmLight"
	chime_light.position = charm.position
	chime_light.light_color = Color(1.0, 0.48, 0.16)
	chime_light.omni_range = 1.8
	chime_light.omni_attenuation = 1.1
	chime_light.light_energy = 0.45
	chime_light.shadow_enabled = false
	swing_pivot.add_child(chime_light)

	var tex := Geo.make_radial_texture(32, 2.0)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_texture = tex
	spark_mat.albedo_color = Color(1.0, 0.82, 0.54, 0.95)
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)

	sparks = CPUParticles3D.new()
	sparks.name = "ChimeSparks"
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 18
	sparks.lifetime = 1.7
	sparks.explosiveness = 0.92
	sparks.randomness = 0.55
	sparks.mesh = quad
	sparks.material_override = spark_mat
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.22
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 0.16
	sparks.initial_velocity_max = 0.74
	sparks.gravity = Vector3(0, 0.18, 0)
	sparks.scale_amount_min = 0.32
	sparks.scale_amount_max = 0.85
	sparks.color = Color(1.0, 0.85, 0.60, 0.85)
	sparks.position = Vector3(0, -0.50, 0)
	sparks.local_coords = false
	add_child(sparks)


func tick(delta: float, t: float, night: float, rain: float, high: bool) -> void:
	time = t
	nightness = night
	rain_amount = rain
	quality_high = high
	impulse = maxf(0.0, impulse - delta * 1.25)
	var wind := 0.010 + rain * 0.030 + (0.010 if focused else 0.0)
	var idle := sin(t * 1.3 + phase)
	var struck := sin((1.0 - impulse) * 11.0 + phase) * impulse * 0.38
	swing_pivot.rotation.z = idle * wind + struck
	swing_pivot.rotation.x = cos(t * 1.08 + phase) * wind * 0.55 + struck * 0.28
	swing_pivot.position.y = 0.02 + sin(t * 0.9 + phase) * 0.006
	charm_material.emission_energy_multiplier = (0.45 + 3.2 * nightness) * (1.0 + impulse * 0.8)
	if chime_light != null:
		chime_light.light_energy = 0.10 + nightness * 0.45


func interact() -> bool:
	struck_count += 1
	impulse = 1.0
	sparks.restart()
	sparks.emitting = true
	var messages := [
		"风铃把月色摇成三声轻响。",
		"第二阵风，恰好经过檐下。",
		"玻璃轻碰，萤火停了一瞬。",
	]
	var message: String = messages[(struck_count - 1) % messages.size()]
	interacted.emit(display_id, message, get_interaction_anchor())
	return true


func set_focused(value: bool) -> void:
	focused = value


func get_interaction_anchor() -> Vector3:
	return global_position + Vector3(0, -0.40, 0)


func get_display_name() -> String:
	return display_name


func get_display_id() -> String:
	return display_id


func reset() -> void:
	struck_count = 0
	impulse = 0.0
	focused = false
	sparks.emitting = false
	swing_pivot.rotation = Vector3.ZERO
