class_name StylizedOcean
extends MeshInstance3D

# 海面：单张环形渐变 LOD 网格（近岸密、远海疏），6 层 Gerstner 波 + 12 路涟漪源。
# 无 CPU 流体；所有波浪/法线/泡沫/焦散在 shader 内解析计算。

const WAVE_COUNT := 6
const RIPPLE_MAX := 12
const WATER_RADIUS := 420.0
const RING_COUNT := 140
const SEGMENT_COUNT := 160

var field: IslandField
var material: ShaderMaterial
var sim_time := 0.0

var wave_height := 0.72
var wave_speed := 1.0
var wave_dir_deg := 18.0
var foam_amount := 0.85
var sun_glint := 1.0
var night := 0.0

var ripple_amp := 1.0
var ripple_life := 3.2
var ripple_speed := 2.8
var water_style := 0

var ripples: Array[Dictionary] = []
var _waves: Array[Vector4] = []
var _ripple_uniforms: Array[Vector4] = []
var _rain := 0.0
var _debug_view := 0

var _palette_day := {
	"deep": Color("#12669d"),
	"mid": Color("#1a74a8"),
	"shelf": Color("#1e95b4"),
	"lagoon": Color("#3fc9cf"),
	"sandwater": Color("#b3e6d2"),
	"sky_reflect": Color("#c2e9f2"),
	"foam": Color("#fbffff"),
	"caustic": Color("#b8fff4"),
	"sun": Color("#fff3dd"),
	"fog": Color("#b9dce8"),
}
var _palette: Dictionary = {}


func setup(p_field: IslandField) -> void:
	field = p_field
	name = "Ocean"
	mesh = _build_mesh()
	custom_aabb = AABB(Vector3(-WATER_RADIUS, -4.0, -WATER_RADIUS),
			Vector3(WATER_RADIUS * 2.0, 8.0, WATER_RADIUS * 2.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/water.gdshader")
	material.set_shader_parameter("height_map", field.bake_height_texture())
	material.set_shader_parameter("height_area", IslandField.AREA)
	material.set_shader_parameter("max_depth", IslandField.MAX_DEPTH)
	material.set_shader_parameter("foam_tex", TexFactory.foam_texture())
	material.set_shader_parameter("detail_tex", TexFactory.detail_normal_texture())
	material.set_shader_parameter("caustic_tex", TexFactory.caustic_texture())
	material.set_shader_parameter("ripple_life", ripple_life)
	material.set_shader_parameter("ripple_speed", ripple_speed)

	_waves = [
		Vector4(1.0, 0.28, 0.30, 22.0),
		Vector4(0.62, 0.85, 0.18, 12.0),
		Vector4(-0.35, 1.0, 0.105, 7.0),
		Vector4(0.92, -0.40, 0.055, 4.0),
		Vector4(-0.75, -0.65, 0.034, 2.6),
		Vector4(0.15, -1.0, 0.022, 1.7),
	]
	for i in WAVE_COUNT:
		var v := _waves[i]
		_waves[i] = Vector4(Vector2(v.x, v.y).normalized().x,
				Vector2(v.x, v.y).normalized().y, v.z, v.w)
	_ripple_uniforms.resize(RIPPLE_MAX)
	for i in RIPPLE_MAX:
		_ripple_uniforms[i] = Vector4.ZERO

	material.set_shader_parameter("waves", _waves)
	material.set_shader_parameter("wave_count", WAVE_COUNT)
	material.set_shader_parameter("ripples", _ripple_uniforms)
	material.set_shader_parameter("ripple_count", 0)
	material_override = material
	set_palette(_palette_day, Color("#fff3dd"), Vector3(0.35, 0.8, 0.25))
	_push_params()


func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in RING_COUNT + 1:
		var t := float(i) / float(RING_COUNT)
		var r := 0.5 + (WATER_RADIUS - 0.5) * pow(t, 2.2)
		for j in SEGMENT_COUNT:
			var a := TAU * float(j) / float(SEGMENT_COUNT)
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
			normals.append(Vector3.UP)
			uvs.append(Vector2(float(j) / SEGMENT_COUNT, t))
	for i in RING_COUNT:
		for j in SEGMENT_COUNT:
			var j2 := (j + 1) % SEGMENT_COUNT
			var a := i * SEGMENT_COUNT + j
			var b := i * SEGMENT_COUNT + j2
			var c := (i + 1) * SEGMENT_COUNT + j
			var d := (i + 1) * SEGMENT_COUNT + j2
			indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _push_params() -> void:
	if material == null:
		return
	material.set_shader_parameter("time", sim_time)
	material.set_shader_parameter("wave_height", wave_height)
	material.set_shader_parameter("wave_speed", wave_speed)
	material.set_shader_parameter("wave_dir", deg_to_rad(wave_dir_deg))
	material.set_shader_parameter("foam_amount", foam_amount)
	material.set_shader_parameter("sun_glint", sun_glint)
	material.set_shader_parameter("ripple_amp", ripple_amp)
	material.set_shader_parameter("rain", _rain)
	material.set_shader_parameter("night", night)
	material.set_shader_parameter("debug_view", _debug_view)


func tick(delta: float) -> void:
	sim_time += delta
	_prune_ripples()
	_sync_ripples()
	material.set_shader_parameter("time", sim_time)


func set_paused_time(t: float) -> void:
	sim_time = t
	material.set_shader_parameter("time", sim_time)


func spawn_ripple(x: float, z: float, strength := 1.0, age := 0.0) -> Dictionary:
	var strength_c := clampf(strength, 0.15, 2.0)
	_prune_ripples()
	if ripples.size() >= RIPPLE_MAX:
		# 先淘汰最老的一路，保持连续拖尾
		ripples.sort_custom(func(a, b): return a["start"] < b["start"])
		ripples.remove_at(0)
	var entry := {
		"pos": Vector2(x, z),
		"start": sim_time - age,
		"strength": strength_c,
		"life": ripple_life,
	}
	ripples.append(entry)
	_sync_ripples()
	return entry


func clear_ripples() -> void:
	ripples.clear()
	_sync_ripples()


func _prune_ripples() -> void:
	var keep: Array[Dictionary] = []
	for r in ripples:
		if sim_time - float(r["start"]) <= ripple_life:
			keep.append(r)
	ripples = keep


func _sync_ripples() -> void:
	if material == null:
		return
	for i in RIPPLE_MAX:
		if i < ripples.size():
			var r: Dictionary = ripples[i]
			var pos: Vector2 = r["pos"]
			_ripple_uniforms[i] = Vector4(pos.x, pos.y, r["start"], r["strength"])
		else:
			_ripple_uniforms[i] = Vector4.ZERO
	material.set_shader_parameter("ripples", _ripple_uniforms)
	material.set_shader_parameter("ripple_count", mini(ripples.size(), RIPPLE_MAX))


func set_wave_height(v: float) -> void:
	wave_height = clampf(v, 0.0, 2.5)
	material.set_shader_parameter("wave_height", wave_height)


func set_wave_speed(v: float) -> void:
	wave_speed = clampf(v, 0.0, 2.5)
	material.set_shader_parameter("wave_speed", wave_speed)


func set_wave_direction(deg: float) -> void:
	wave_dir_deg = fmod(deg, 360.0)
	material.set_shader_parameter("wave_dir", deg_to_rad(wave_dir_deg))


func set_foam_amount(v: float) -> void:
	foam_amount = clampf(v, 0.0, 1.6)
	material.set_shader_parameter("foam_amount", foam_amount)


func set_ripple_strength(v: float) -> void:
	ripple_amp = clampf(v, 0.0, 2.0)
	material.set_shader_parameter("ripple_amp", ripple_amp)


func set_ripple_decay(v: float) -> void:
	# 0 = 衰减慢（3.2s→5.0s），1 = 衰减快（3.2s→1.6s）
	ripple_life = lerpf(5.0, 1.6, clampf(v, 0.0, 1.0))
	material.set_shader_parameter("ripple_life", ripple_life)


func set_sun_glint(v: float) -> void:
	sun_glint = clampf(v, 0.0, 2.0)
	material.set_shader_parameter("sun_glint", sun_glint)


func set_rain(v: float) -> void:
	_rain = clampf(v, 0.0, 1.0)
	material.set_shader_parameter("rain", _rain)


func set_debug_view(v: int) -> void:
	_debug_view = v
	material.set_shader_parameter("debug_view", _debug_view)


func get_debug_view() -> int:
	return _debug_view


func set_night(v: float) -> void:
	night = clampf(v, 0.0, 1.0)
	material.set_shader_parameter("night", night)


func set_water_style(idx: int) -> void:
	water_style = clampi(idx, 0, 2)


func set_palette(palette: Dictionary, sun: Color, sun_dir: Vector3) -> void:
	_palette = palette
	var deep: Color = palette["deep"]
	var mid: Color = palette["mid"]
	var shelf: Color = palette["shelf"]
	var lagoon: Color = palette["lagoon"]
	var sandwater: Color = palette["sandwater"]
	var sky_reflect: Color = palette["sky_reflect"]
	if water_style == 1:
		deep = deep.lerp(Color("#0e7c9e"), 0.4)
		mid = mid.lerp(Color("#18a3b4"), 0.45)
		shelf = shelf.lerp(Color("#2fd9c0"), 0.45)
		lagoon = lagoon.lerp(Color("#6ff0d8"), 0.5)
		sandwater = sandwater.lerp(Color("#d6f6e4"), 0.5)
		sky_reflect = sky_reflect.lerp(Color("#d8fff4"), 0.3)
	elif water_style == 2:
		deep = deep.lerp(Color("#0a3566"), 0.55)
		mid = mid.lerp(Color("#0f4a7e"), 0.5)
		shelf = shelf.lerp(Color("#15648e"), 0.4)
		lagoon = lagoon.lerp(Color("#2a8fa2"), 0.35)
		sandwater = sandwater.lerp(Color("#a6cec0"), 0.35)
		sky_reflect = sky_reflect.lerp(Color("#9cc8de"), 0.3)
	material.set_shader_parameter("deep_color", deep)
	material.set_shader_parameter("mid_color", mid)
	material.set_shader_parameter("shelf_color", shelf)
	material.set_shader_parameter("lagoon_color", lagoon)
	material.set_shader_parameter("sandwater_color", sandwater)
	material.set_shader_parameter("sky_reflect", sky_reflect)
	material.set_shader_parameter("foam_color", palette["foam"])
	material.set_shader_parameter("caustic_color", palette["caustic"])
	material.set_shader_parameter("sun_color", sun)
	material.set_shader_parameter("fog_color", palette["fog"])
	material.set_shader_parameter("sun_dir", sun_dir.normalized())


func get_wave_height_at(x: float, z: float) -> float:
	var total := 0.0
	var depth := maxf(0.0, -field.base_height(x, z))
	var damp := smoothstep(0.0, 2.2, depth)
	var ca := cos(deg_to_rad(wave_dir_deg))
	var sa := sin(deg_to_rad(wave_dir_deg))
	for i in range(_waves.size()):
		var w: Vector4 = _waves[i]
		var dir := Vector2(w.x * ca - w.y * sa, w.x * sa + w.y * ca)
		var amp := w.z * wave_height * damp
		var k := TAU / maxf(w.w, 0.5)
		var c := sqrt(9.8 / k) * 0.42 * wave_speed
		total += amp * sin(k * (dir.dot(Vector2(x, z)) - c * sim_time) + float(i) * 1.7)
	return total


func debug_snapshot() -> Dictionary:
	return {
		"time": sim_time,
		"wave_height": wave_height,
		"wave_speed": wave_speed,
		"wave_dir_deg": wave_dir_deg,
		"wave_count": WAVE_COUNT,
		"foam": foam_amount,
		"ripple_amp": ripple_amp,
		"ripple_life": ripple_life,
		"ripple_count": ripples.size(),
		"rain": _rain,
		"debug_view": _debug_view,
		"water_style": water_style,
		"vertices": (RING_COUNT + 1) * SEGMENT_COUNT,
	}
