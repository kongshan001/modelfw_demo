extends MeshInstance3D

# 程序化像素海面。
# 顶点位移完全在 water.gdshader 里完成；这里的 height_at() 是同一套 Gerstner
# 公式的 CPU 版本，供木筏五点浮力采样。改波形参数时两边必须一起改。

const TWO_PI := 6.283185307179586
const GRAVITY := 9.81
const PLANE_SIZE := 140.0
const SUBDIVISIONS := 220

const WAVE_ANGLE_OFFSET := [-0.38, 0.72, 1.90]
const WAVE_LENGTH := [15.0, 7.0, 4.6]
const WAVE_AMP := [0.62, 0.30, 0.16]
const WAVE_SPEED := [1.00, 1.25, 1.50]
const WAVE_CHOP := [0.90, 0.80, 0.70]

# 可调参数（HUD / 按键 / 测试脚本都通过这些字段改）
var wave_height := 1.0
var wave_speed := 1.0
var choppiness := 0.85
var stretch := 0.35
var grouping := 0.55
var wave_angle := 0.0
var foam := 0.9
var sparkle := 1.0
var opacity := 0.86
var reflection_strength := 0.85
var reflection_enabled := true
var refl_tint := 0.7
var raft_position := Vector3.ZERO
var raft_radius := 1.9

var wave_time := 0.0
var water_material: ShaderMaterial

var _deep := Color(0.07, 0.22, 0.32)
var _mid := Color(0.12, 0.40, 0.50)
var _light := Color(0.26, 0.68, 0.65)
var _crest := Color(0.58, 0.90, 0.82)
var _foam := Color(0.95, 0.99, 1.0)
var _sun := Color(1.0, 0.88, 0.58)
var _horizon := Color(0.62, 0.80, 0.86)
var _sun_dir := Vector3(-0.52, 0.14, -0.84).normalized()
var _reflection_tex: Texture2D


func _ready() -> void:
	name = "Ocean"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = 1 << 1  # 倒影相机只渲染第 1 层，海面不参与自身倒影
	extra_cull_margin = 3.0

	var plane := PlaneMesh.new()
	plane.size = Vector2(PLANE_SIZE, PLANE_SIZE)
	plane.subdivide_width = SUBDIVISIONS - 1
	plane.subdivide_depth = SUBDIVISIONS - 1
	mesh = plane

	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	material_override = water_material
	_push_uniforms()


func tick(delta: float) -> void:
	wave_time += delta
	if water_material != null:
		water_material.set_shader_parameter("u_time", wave_time)


func height_at(x: float, z: float) -> float:
	# 必须与 water.gdshader 的 vertex() 完全一致。
	var p := Vector2(x, z)
	p.x *= lerpf(1.0, 0.55, clampf(stretch, 0.0, 1.0))
	p.y += sin(p.x * 0.055 + wave_time * 0.18) * 2.0 * stretch

	var group_env := 0.5 + 0.5 * sin(p.dot(Vector2(0.055, 0.031)) - wave_time * 0.24)
	var gmul := lerpf(1.0, 0.62 + 0.72 * group_env, clampf(grouping, 0.0, 1.0))
	var amp := wave_height * gmul

	var h := 0.0
	for i in WAVE_ANGLE_OFFSET.size():
		var k: float = TWO_PI / WAVE_LENGTH[i]
		var angle: float = wave_angle + WAVE_ANGLE_OFFSET[i]
		var dir := Vector2(cos(angle), sin(angle))
		var omega: float = sqrt(GRAVITY * k) * WAVE_SPEED[i] * wave_speed
		var phase: float = k * dir.dot(p) - omega * wave_time
		h += WAVE_AMP[i] * amp * sin(phase)
	return h


func sample_five(x: float, z: float) -> Array[float]:
	# 返回顺序：中心、前(-z)、后(+z)、左(-x)、右(+x)
	return [
		height_at(x, z),
		height_at(x, z - 1.55),
		height_at(x, z + 1.55),
		height_at(x - 1.15, z),
		height_at(x + 1.15, z),
	]


# ── 参数入口 ─────────────────────────────────────────────────────────────
func set_wave_height(value: float) -> void:
	wave_height = clampf(value, 0.0, 2.5)
	_push_uniforms()


func set_wave_direction(degrees: float) -> void:
	wave_angle = deg_to_rad(degrees)
	_push_uniforms()


func set_foam(value: float) -> void:
	foam = clampf(value, 0.0, 2.0)
	_push_uniforms()


func set_sparkle(value: float) -> void:
	sparkle = clampf(value, 0.0, 2.0)
	_push_uniforms()


func set_opacity(value: float) -> void:
	opacity = clampf(value, 0.25, 1.0)
	_push_uniforms()


func set_reflection_strength(value: float) -> void:
	reflection_strength = clampf(value, 0.0, 1.2)
	_push_uniforms()


func set_reflection_enabled(value: bool) -> void:
	reflection_enabled = value
	_push_uniforms()


func set_reflection_texture(tex: Texture2D) -> void:
	_reflection_tex = tex
	_push_uniforms()


func set_palette(deep: Color, mid: Color, light: Color, crest: Color,
		foam_color: Color, sun_color: Color, horizon_color: Color) -> void:
	_deep = deep
	_mid = mid
	_light = light
	_crest = crest
	_foam = foam_color
	_sun = sun_color
	_horizon = horizon_color
	_push_uniforms()


func set_sun(direction: Vector3, color: Color) -> void:
	_sun_dir = direction.normalized()
	_sun = color
	_push_uniforms()


func set_raft(position: Vector3, radius: float) -> void:
	raft_position = position
	raft_radius = radius
	_push_uniforms()


func _push_uniforms() -> void:
	if water_material == null:
		return
	water_material.set_shader_parameter("u_time", wave_time)
	water_material.set_shader_parameter("u_wave_height", wave_height)
	water_material.set_shader_parameter("u_wave_speed", wave_speed)
	water_material.set_shader_parameter("u_choppiness", choppiness)
	water_material.set_shader_parameter("u_stretch", stretch)
	water_material.set_shader_parameter("u_grouping", grouping)
	water_material.set_shader_parameter("u_wave_angle", wave_angle)
	water_material.set_shader_parameter("u_foam", foam)
	water_material.set_shader_parameter("u_sparkle", sparkle)
	water_material.set_shader_parameter("u_opacity", opacity)
	water_material.set_shader_parameter("u_reflection", reflection_strength)
	water_material.set_shader_parameter("u_reflection_on", 1.0 if reflection_enabled else 0.0)
	water_material.set_shader_parameter("u_refl_tint", refl_tint)
	water_material.set_shader_parameter("u_deep_color", _deep)
	water_material.set_shader_parameter("u_mid_color", _mid)
	water_material.set_shader_parameter("u_light_color", _light)
	water_material.set_shader_parameter("u_crest_color", _crest)
	water_material.set_shader_parameter("u_foam_color", _foam)
	water_material.set_shader_parameter("u_sun_color", _sun)
	water_material.set_shader_parameter("u_horizon_color", _horizon)
	water_material.set_shader_parameter("u_sun_dir", _sun_dir)
	water_material.set_shader_parameter("u_raft_pos", raft_position)
	water_material.set_shader_parameter("u_raft_radius", raft_radius)
	if _reflection_tex != null:
		water_material.set_shader_parameter("u_reflection_tex", _reflection_tex)


func get_wave_config() -> Array:
	# 供验收/文档读取：三道波的原始配置
	var out: Array = []
	for i in WAVE_ANGLE_OFFSET.size():
		out.append({
			"angle_offset": WAVE_ANGLE_OFFSET[i],
			"wavelength": WAVE_LENGTH[i],
			"amplitude": WAVE_AMP[i],
			"speed": WAVE_SPEED[i],
			"chop": WAVE_CHOP[i],
		})
	return out


func get_mesh_vertex_count() -> int:
	var arrays: Array = mesh.get_mesh_arrays()
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return 0
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
