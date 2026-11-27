extends MultiMeshInstance3D

# 原创萤火虫群：单个 MultiMesh（1 draw call），CPU 逐只更新位置与闪烁。
# 不依赖 GPU 粒子，headless 可测试，Intel GL Compatibility 下开销可忽略。

const DEFAULT_COUNT := 160

var count := DEFAULT_COUNT
var activity := 0.0
var enabled := true
var paused := false
var time := 0.0
var visible_count := 0

var _data: Array = []
var _multimesh: MultiMesh
var _material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _zones: Array = []


func setup(firefly_count: int, zones: Array, seed_value: int = 20261127, glow_texture: Texture2D = null) -> void:
	count = maxi(firefly_count, 1)
	_zones = zones.duplicate(true)
	_rng.seed = seed_value
	_build_material(glow_texture)
	_build_multimesh()
	_distribute()
	_update_instances(0.0)


func _build_material(glow_texture: Texture2D) -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.billboard_keep_scale = true
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(1, 1, 1, 1)
	if glow_texture != null:
		_material.albedo_texture = glow_texture
	_material.disable_receive_shadows = true
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.no_depth_test = false


func _build_multimesh() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = count
	_multimesh.visible_instance_count = count
	_multimesh.custom_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 18, 48))
	multimesh = _multimesh
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	extra_cull_margin = 40.0


func _distribute() -> void:
	_data.clear()
	var total_weight := 0.0
	for z in _zones:
		total_weight += float(z.get("weight", 1.0))
	if total_weight <= 0.0:
		total_weight = 1.0
	for i in count:
		var pick := _rng.randf() * total_weight
		var zone: Dictionary = _zones[0]
		for z in _zones:
			pick -= float(z.get("weight", 1.0))
			if pick <= 0.0:
				zone = z
				break
		var center: Vector3 = zone.get("center", Vector3.ZERO)
		var radius := float(zone.get("radius", 2.0))
		var ang := _rng.randf() * TAU
		var orbit := sqrt(_rng.randf()) * radius
		var base_h := float(zone.get("min_y", 0.45)) + _rng.randf() * float(zone.get("spread_y", 1.5))
		var warm := _rng.randf()
		var tint := Color(0.82, 1.0, 0.52).lerp(Color(1.0, 0.82, 0.42), warm)
		_data.append({
			"center": center,
			"radius": orbit,
			"angle": ang,
			"angular_speed": _rng.randf_range(0.06, 0.24) * (1.0 if _rng.randf() > 0.25 else -1.0),
			"height": base_h,
			"bob": _rng.randf_range(0.10, 0.42),
			"bob_speed": _rng.randf_range(0.5, 1.4),
			"phase": _rng.randf() * TAU,
			"size": _rng.randf_range(0.090, 0.160),
			"tint": tint,
			"blink_speed": _rng.randf_range(0.8, 2.2),
			"blink_offset": _rng.randf() * TAU,
			"drift": _rng.randf_range(0.15, 0.5),
		})


func set_activity(value: float) -> void:
	activity = clampf(value, 0.0, 1.0)


func set_enabled(value: bool) -> void:
	enabled = value


func set_paused(value: bool) -> void:
	paused = value


func advance(seconds: float) -> void:
	time += seconds
	_update_instances(0.0)


func _process(delta: float) -> void:
	if paused:
		return
	time += delta
	_update_instances(delta)


func _update_instances(_delta: float) -> void:
	if _multimesh == null:
		return
	var active := activity if enabled else 0.0
	var vis := 0
	for i in _data.size():
		var f: Dictionary = _data[i]
		var a: float = float(f["angle"]) + time * float(f["angular_speed"])
		var drift := float(f["drift"])
		var c: Vector3 = f["center"]
		var pos := c + Vector3(
			cos(a) * float(f["radius"]) + sin(time * 0.37 + float(f["phase"])) * drift,
			float(f["height"]) + sin(time * float(f["bob_speed"]) + float(f["phase"])) * float(f["bob"]),
			sin(a) * float(f["radius"]) + cos(time * 0.29 + float(f["phase"]) * 1.7) * drift)
		# 闪烁：每只独立相位；活动度同时控制显隐与尺寸。
		var twinkle := pow(maxf(0.0, sin(time * float(f["blink_speed"]) + float(f["blink_offset"]))), 2.2)
		var pulse := 0.55 + 0.45 * sin(time * 0.6 + float(f["phase"]))
		var alpha := active * (0.16 + 0.84 * twinkle) * (0.72 + 0.28 * pulse)
		var scale := float(f["size"]) * (0.85 + 0.3 * twinkle) * (0.4 + 0.6 * active)
		if alpha < 0.012:
			scale = 0.0001
		var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
		_multimesh.set_instance_transform(i, Transform3D(basis, pos))
		var tint: Color = f["tint"]
		_multimesh.set_instance_color(i, Color(tint.r, tint.g, tint.b, clampf(alpha, 0.0, 1.0)))
		if alpha >= 0.06:
			vis += 1
	visible_count = vis


func get_visible_count() -> int:
	return visible_count


func get_count() -> int:
	return count


func get_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in _data.size():
		out.append(_multimesh.get_instance_transform(i).origin)
	return out


func get_activity() -> float:
	return activity if enabled else 0.0
