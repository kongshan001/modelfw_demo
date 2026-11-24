class_name MistFx
extends Node3D
## 轻量程序化反馈：命中火星、刀光、尘土、扩散圈、漂浮文字。全部即时生成。

const Models = preload("res://scripts/models.gd")

var _effects: Array = []
var _spark_mesh: BoxMesh
var _materials: Dictionary = {}


func _ready() -> void:
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.09, 0.09, 0.09)


func hit(pos: Vector3, color := Color("f0d49a")) -> void:
	for i in range(4):
		var node := MeshInstance3D.new()
		node.mesh = _spark_mesh
		node.material_override = _mat(color)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = pos
		var vel := Vector3(randf_range(-1.6, 1.6), randf_range(0.8, 2.3), randf_range(-1.6, 1.6))
		_effects.append({"node": node, "kind": "spark", "life": 0.38, "max": 0.38, "vel": vel, "mat": null})


func death(pos: Vector3, color := Color("d96a55")) -> void:
	for i in range(7):
		var node := MeshInstance3D.new()
		node.mesh = _spark_mesh
		node.material_override = _mat(Color("b7a08c") if i % 3 == 0 else color)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0, 0.5), randf_range(-0.3, 0.3))
		node.scale = Vector3.ONE * randf_range(0.8, 1.7)
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.4), randf_range(-1.0, 1.0))
		_effects.append({"node": node, "kind": "spark", "life": 0.6, "max": 0.6, "vel": vel, "mat": null})
	ring(pos + Vector3(0, -0.5, 0), color)


func slash(from: Vector3, to: Vector3, color := Color("f0d49a")) -> void:
	var delta := to - from
	delta.y = 0.0
	var dist := delta.length()
	if dist < 0.05:
		return
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, minf(1.4, dist))
	node.mesh = box
	var mat := _mat(color)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = (from + to) * 0.5 + Vector3(0, 0.55, 0)
	node.look_at(to + Vector3(0, 0.55, 0), Vector3.UP)
	_effects.append({"node": node, "kind": "slash", "life": 0.16, "max": 0.16, "vel": Vector3.ZERO, "mat": null})


func ring(pos: Vector3, color := Color("e9b45f")) -> void:
	var node := Models.make_ring(color, 0.72, 0.98, 0.75)
	add_child(node)
	node.global_position = pos + Vector3(0, 0.08, 0)
	var mat := node.material_override as StandardMaterial3D
	_effects.append({"node": node, "kind": "ring", "life": 0.55, "max": 0.55, "vel": Vector3.ZERO, "mat": mat, "base": 0.7})


func float_text(pos: Vector3, text: String, color := Color("f3e8cc"), size := 32) -> void:
	var label := Models.make_label(text, size, color)
	label.pixel_size = 0.011
	label.outline_size = 10
	add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.2, 0.2))
	_effects.append({"node": label, "kind": "text", "life": 1.0, "max": 1.0, "vel": Vector3(0, 0.55, 0), "mat": null})


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = mat
	return mat


func clear_all() -> void:
	for effect in _effects:
		if effect.has("node") and is_instance_valid(effect["node"]):
			effect["node"].queue_free()
	_effects.clear()


func _process(delta: float) -> void:
	var i := 0
	while i < _effects.size():
		var effect: Dictionary = _effects[i]
		effect["life"] = float(effect["life"]) - delta
		var node = effect["node"]
		if not is_instance_valid(node) or float(effect["life"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			_effects.remove_at(i)
			continue
		var t := 1.0 - float(effect["life"]) / float(effect["max"])
		match str(effect["kind"]):
			"spark":
				effect["vel"] = (effect["vel"] as Vector3) + Vector3(0, -5.5, 0) * delta
				node.global_position += (effect["vel"] as Vector3) * delta
				node.scale = Vector3.ONE * maxf(0.05, 1.1 - t * 1.1)
			"slash":
				node.scale = Vector3(1.0, 1.0, maxf(0.01, 1.0 - t * 1.6))
			"ring":
				node.scale = Vector3.ONE * (0.7 + t * 2.6)
				if effect["mat"] != null:
					var m := effect["mat"] as StandardMaterial3D
					m.albedo_color.a = maxf(0.0, 0.75 * (1.0 - t))
			"text":
				node.global_position += (effect["vel"] as Vector3) * delta
				if t > 0.6:
					var label := node as Label3D
					label.modulate.a = clampf((1.0 - t) / 0.4, 0.0, 1.0)
		i += 1

	if _effects.size() > 140:
		var excess := _effects.size() - 140
		for _k in range(excess):
			var old: Dictionary = _effects.pop_front()
			if is_instance_valid(old["node"]):
				old["node"].queue_free()
