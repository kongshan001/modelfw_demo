class_name RainField
extends MeshInstance2D

# 360 条渐变雨丝（默认），不用粒子节点：
# 每帧把条带四边形写进一张动态 ArrayMesh，尾透明、头亮，一次绘制。
# 密度是实例数，雨强影响透明度/速度/涟漪频率，风改变倾角。

const MAX_DROPS := 600
const WORLD := Vector2(640.0, 360.0)

var density := 360
var wind := 0.18              # -0.6..0.6，横向速度 = wind * 300 px/s
var speed_scale := 1.0
var length_scale := 1.0
var intensity := 0.85
var paused := false

var _pos := PackedVector2Array()
var _vel := PackedFloat32Array()
var _len := PackedFloat32Array()
var _wid := PackedFloat32Array()
var _alpha := PackedFloat32Array()
var _near := PackedByteArray()
var _rng := RandomNumberGenerator.new()
var _mesh := ArrayMesh.new()
var _indices := PackedInt32Array()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/rain.gdshader")
	material = mat
	mesh = _mesh
	_rng.seed = 20261125
	_init_drops()
	_build_indices(MAX_DROPS)
	_rebuild()


func _init_drops() -> void:
	_pos.resize(MAX_DROPS)
	_vel.resize(MAX_DROPS)
	_len.resize(MAX_DROPS)
	_wid.resize(MAX_DROPS)
	_alpha.resize(MAX_DROPS)
	_near.resize(MAX_DROPS)
	for i in MAX_DROPS:
		_respawn(i, true)


func _respawn(i: int, anywhere := false) -> void:
	_pos[i] = Vector2(
		_rng.randf_range(-60.0, WORLD.x + 60.0),
		_rng.randf_range(-WORLD.y, WORLD.y) if anywhere else _rng.randf_range(-90.0, -20.0))
	_vel[i] = _rng.randf_range(650.0, 1010.0)
	_len[i] = _rng.randf_range(22.0, 52.0)
	_wid[i] = _rng.randf_range(0.8, 1.55)
	_near[i] = 1 if _rng.randf() < 0.22 else 0
	_alpha[i] = _rng.randf_range(0.40, 0.78) * (1.06 if _near[i] == 1 else 0.72)


func _build_indices(count: int) -> void:
	_indices.resize(count * 6)
	for i in count:
		var v := i * 4
		var o := i * 6
		_indices[o] = v
		_indices[o + 1] = v + 1
		_indices[o + 2] = v + 2
		_indices[o + 3] = v
		_indices[o + 4] = v + 2
		_indices[o + 5] = v + 3


func step(dt: float) -> void:
	if paused or dt <= 0.0:
		return
	var spd := speed_scale * (0.72 + 0.45 * intensity)
	var drift := wind * 300.0 * spd
	for i in MAX_DROPS:
		var p := _pos[i]
		p.y += _vel[i] * spd * dt
		p.x += drift * dt
		if p.y > WORLD.y + 70.0:
			_respawn(i, false)
			p = _pos[i]
		if p.x < -90.0:
			p.x += WORLD.x + 180.0
		elif p.x > WORLD.x + 90.0:
			p.x -= WORLD.x + 180.0
		_pos[i] = p
	_rebuild()


func _rebuild() -> void:
	var count := clampi(density, 0, MAX_DROPS)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(count * 4)
	colors.resize(count * 4)
	uvs.resize(count * 4)
	idx.resize(count * 6)
	var dir := Vector2(wind * 0.9, 1.0).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var head_alpha := (0.26 + 0.62 * intensity)
	for i in count:
		var p := _pos[i]
		var length := _len[i] * length_scale
		var tail := p - dir * length
		var head_n := normal * (_wid[i] * 0.5)
		var tail_n := normal * (_wid[i] * 0.18)
		var v := i * 4
		verts[v] = Vector3(tail.x + tail_n.x, tail.y + tail_n.y, 0.0)
		verts[v + 1] = Vector3(tail.x - tail_n.x, tail.y - tail_n.y, 0.0)
		verts[v + 2] = Vector3(p.x - head_n.x, p.y - head_n.y, 0.0)
		verts[v + 3] = Vector3(p.x + head_n.x, p.y + head_n.y, 0.0)
		var a := _alpha[i] * head_alpha
		var head := Color(0.76, 0.88, 1.0, a)
		var tail_col := Color(0.58, 0.72, 0.92, 0.0)
		colors[v] = tail_col
		colors[v + 1] = tail_col
		colors[v + 2] = head
		colors[v + 3] = head
		uvs[v] = Vector2(0, 0)
		uvs[v + 1] = Vector2(1, 0)
		uvs[v + 2] = Vector2(1, 1)
		uvs[v + 3] = Vector2(0, 1)
		var o := i * 6
		var base := i * 4
		idx[o] = base
		idx[o + 1] = base + 1
		idx[o + 2] = base + 2
		idx[o + 3] = base
		idx[o + 4] = base + 2
		idx[o + 5] = base + 3

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	if count > 0:
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	visible = count > 0 and intensity > 0.01


func set_density(value: int) -> void:
	density = clampi(value, 0, MAX_DROPS)
	_rebuild()


func set_wind(value: float) -> void:
	wind = clampf(value, -0.6, 0.6)
	_rebuild()


func set_speed_scale(value: float) -> void:
	speed_scale = clampf(value, 0.25, 2.5)


func set_length_scale(value: float) -> void:
	length_scale = clampf(value, 0.4, 2.0)
	_rebuild()


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	_rebuild()


func set_paused(value: bool) -> void:
	paused = value


func reset_drops() -> void:
	_rng.seed = 20261125
	for i in MAX_DROPS:
		_respawn(i, true)
	_rebuild()


func get_active_count() -> int:
	return clampi(density, 0, MAX_DROPS)


func get_length_scale() -> float:
	return length_scale


func debug_drift_per_second() -> float:
	return wind * 300.0 * speed_scale * (0.72 + 0.45 * intensity)


func get_vertex_count() -> int:
	return get_active_count() * 4


func get_draw_call_hint() -> int:
	return 1


func debug_first_drop() -> Dictionary:
	return {
		"pos": _pos[0],
		"speed": _vel[0],
		"length": _len[0],
		"width": _wid[0],
		"near": _near[0] == 1,
	}
