class_name PetalField
extends MultiMeshInstance2D

# 飘落花瓣：一个 MultiMesh / 一次 draw call。
# 每片花瓣的 transform 与 instance color 由本脚本更新；受光仍然只依赖
# foliage_light.gdshader 里的全局太阳参数，不逐片传光照。

const DEFAULT_COUNT := 66

var _count := 0
var _pos: Array[Vector2] = []
var _vel: Array[float] = []
var _sway_phase: Array[float] = []
var _sway_amp: Array[float] = []
var _rot: Array[float] = []
var _rot_speed: Array[float] = []
var _scale: Array[float] = []
var _colors: Array[Color] = []
var _sources: Array[Dictionary] = []
var _bounds := Rect2(8.0, 40.0, 624.0, 306.0)
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _enabled := true


func setup(texture: Texture2D, material: ShaderMaterial, sources: Array[Dictionary],
		bounds: Rect2, seed := 20261125, count := DEFAULT_COUNT) -> void:
	name = "Petals"
	self.texture = texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	self.material = material
	z_index = 20
	_bounds = bounds
	_sources = sources
	_count = count
	_rng.seed = seed

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(6.0, 5.0)
	mm.mesh = quad
	mm.instance_count = _count
	multimesh = mm

	for i in _count:
		_pos.append(Vector2.ZERO)
		_vel.append(0.0)
		_sway_phase.append(0.0)
		_sway_amp.append(0.0)
		_rot.append(0.0)
		_rot_speed.append(0.0)
		_scale.append(1.0)
		_colors.append(Color.WHITE)
		_spawn(i, true)
	_write_all()


func _spawn(index: int, anywhere: bool) -> void:
	var source: Dictionary = _sources[_rng.randi_range(0, _sources.size() - 1)] \
			if not _sources.is_empty() else {"pos": Vector2(320, 130), "radius": Vector2(100, 40)}
	var center: Vector2 = source["pos"]
	var radius: Vector2 = source["radius"]
	_pos[index] = Vector2(
		center.x + _rng.randf_range(-radius.x, radius.x),
		center.y + _rng.randf_range(-radius.y, radius.y))
	if anywhere:
		_pos[index].y = _rng.randf_range(70.0, _bounds.position.y + _bounds.size.y)
	_vel[index] = _rng.randf_range(7.0, 19.0)
	_sway_phase[index] = _rng.randf_range(0.0, TAU)
	_sway_amp[index] = _rng.randf_range(3.0, 13.0)
	_rot[index] = _rng.randf_range(0.0, TAU)
	_rot_speed[index] = _rng.randf_range(-2.2, 2.2)
	_scale[index] = _rng.randf_range(0.85, 1.45)
	var roll := _rng.randf()
	if roll < 0.38:
		_colors[index] = Color(1.0, 0.88, 0.93, 1.0)
	elif roll < 0.72:
		_colors[index] = Color(1.0, 0.71, 0.80, 1.0)
	else:
		_colors[index] = Color(1.0, 0.96, 0.93, 1.0)


func step(delta: float) -> void:
	if not _enabled:
		return
	_time += delta
	for i in _count:
		var p := _pos[i]
		p.y += _vel[i] * delta
		var sway := _sway_phase[i] + _time * (0.55 + _sway_amp[i] * 0.035)
		p.x += cos(sway) * _sway_amp[i] * delta + 2.2 * delta
		_rot[i] += _rot_speed[i] * delta
		if p.y > _bounds.position.y + _bounds.size.y + 8.0 \
				or p.x < _bounds.position.x - 24.0 \
				or p.x > _bounds.position.x + _bounds.size.x + 24.0:
			_spawn(i, false)
			# 从树冠上边缘重新落下。
			p = _pos[i]
			p.y = _bounds.position.y + _rng.randf_range(0.0, 60.0)
			_pos[i] = p
		else:
			_pos[i] = p
	_write_all()


func _write_all() -> void:
	if multimesh == null:
		return
	for i in _count:
		var tf := Transform2D(_rot[i], Vector2(_scale[i], _scale[i]), 0.0, _pos[i])
		multimesh.set_instance_transform_2d(i, tf)
		multimesh.set_instance_color(i, _colors[i])


func set_petals_enabled(value: bool) -> void:
	_enabled = value
	visible = value


func is_petals_enabled() -> bool:
	return _enabled


func get_active_count() -> int:
	return _count


func get_draw_call_hint() -> int:
	return 1


func get_petal_position(index: int) -> Vector2:
	return _pos[index]
