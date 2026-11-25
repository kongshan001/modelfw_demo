class_name RippleField
extends MultiMeshInstance2D

# 72 组双环扩散涟漪：MultiMesh + 一张 32×32 双环像素贴图，一次绘制。
# 生命周期、相位、半径、透明度都在 CPU 上算；雨强只调 SPawn 频率与目标数量。
# 每个实例都被 shader 用同一份 puddle mask 裁切，只在积水里出现。

const POOL := 72
const AVG_LIFE := 1.55

var enabled := true
var field: PuddleField

var _pos := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _amp := PackedFloat32Array()
var _active := PackedByteArray()
var _spawn_accum := 0.0
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _ring_tex: ImageTexture


func setup(p_field: PuddleField, ring_image: Image) -> void:
	field = p_field
	texture = ImageTexture.create_from_image(ring_image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = POOL
	multimesh = mm

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ripple.gdshader")
	_mat.set_shader_parameter("u_field", field.get_field_texture())
	_mat.set_shader_parameter("u_on", 1.0)
	material = _mat

	_rng.seed = 818181
	_pos.resize(POOL)
	_age.resize(POOL)
	_life.resize(POOL)
	_size.resize(POOL)
	_amp.resize(POOL)
	_active.resize(POOL)
	_active.fill(0)
	_zero_instances()


func reset() -> void:
	_active.fill(0)
	_spawn_accum = 0.0
	_zero_instances()


func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if not value:
		_active.fill(0)
		_spawn_accum = 0.0
		_zero_instances()
	else:
		_spawn_accum = 0.0


func step(dt: float, waterline: float, intensity: float) -> void:
	if not enabled:
		return
	_mat.set_shader_parameter("u_waterline", waterline)
	var target := float(POOL) * clampf(intensity, 0.0, 1.0)

	for i in POOL:
		if _active[i] == 0:
			continue
		_age[i] += dt
		if _age[i] >= _life[i]:
			_active[i] = 0

	if intensity > 0.02 and target > 0.5:
		_spawn_accum += dt * target / AVG_LIFE
		var budget := 5
		while _spawn_accum >= 1.0 and budget > 0:
			if not _spawn_one(waterline):
				_spawn_accum = 0.0
				break
			_spawn_accum -= 1.0
			budget -= 1
	else:
		_spawn_accum = minf(_spawn_accum, 0.0)

	_refresh_instances(target)


func _spawn_one(waterline: float) -> bool:
	var slot := -1
	for i in POOL:
		if _active[i] == 0:
			slot = i
			break
	if slot < 0:
		return false
	var p: Vector2 = field.pick_spawn_point(_rng, waterline)
	if p.x < 0.0:
		return false
	_pos[slot] = p
	_age[slot] = 0.0
	_life[slot] = _rng.randf_range(1.1, 2.1)
	_size[slot] = _rng.randf_range(12.0, 30.0)
	_amp[slot] = _rng.randf_range(0.55, 1.0)
	_active[slot] = 1
	return true


func _refresh_instances(_target: float) -> void:
	for i in POOL:
		if _active[i] == 0:
			multimesh.set_instance_transform_2d(i,
					Transform2D(0.0, Vector2.ZERO, 0.0, Vector2(-100.0, -100.0)))
			multimesh.set_instance_color(i, Color(1, 1, 1, 0))
			continue
		var t := clampf(_age[i] / _life[i], 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - t, 2.3)
		var diameter := lerpf(5.0, _size[i], ease_out)
		var alpha := pow(sin(PI * t), 0.65) * 0.52 * _amp[i]
		var aspect := 1.16 + fmod(_pos[i].x, 9.0) / 9.0 * 0.34
		var sx := diameter * aspect
		var sy := diameter * 0.72
		var xf := Transform2D(0.0, Vector2(sx, sy), 0.0, _pos[i])
		multimesh.set_instance_transform_2d(i, xf)
		multimesh.set_instance_color(i, Color(0.82, 0.98, 0.94, alpha))


func _zero_instances() -> void:
	if multimesh == null:
		return
	for i in POOL:
		multimesh.set_instance_transform_2d(i,
				Transform2D(0.0, Vector2.ZERO, 0.0, Vector2(-100.0, -100.0)))
		multimesh.set_instance_color(i, Color(1, 1, 1, 0))


func get_active_count() -> int:
	var n := 0
	for i in POOL:
		n += _active[i]
	return n


func get_pool_size() -> int:
	return POOL


func get_draw_call_hint() -> int:
	return 1


func get_life_span() -> Vector2:
	var lo := 99.0
	var hi := 0.0
	for i in POOL:
		if _active[i] == 0:
			continue
		lo = minf(lo, _life[i])
		hi = maxf(hi, _life[i])
	if hi <= 0.0:
		return Vector2.ZERO
	return Vector2(lo, hi)


func get_phase_spread() -> float:
	var lo := 2.0
	var hi := -1.0
	for i in POOL:
		if _active[i] == 0:
			continue
		var t := clampf(_age[i] / _life[i], 0.0, 1.0)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	if hi < 0.0:
		return 0.0
	return hi - lo


func get_shader_material() -> ShaderMaterial:
	return _mat
