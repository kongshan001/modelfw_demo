extends Node2D

# 场景构建：320×180 美术像素的夜间工坊。
# 墙、地板、石狐、木桶、苔灵五张受光 Sprite，每张都有 albedo + 高度图生成的
# 法线图。Shader 路径用自定义 CanvasItem 材质；原生路径把同一张贴图包进
# CanvasTexture（Diffuse + NormalMap）交给 Light2D。

const SHADER_PATH := "res://shaders/sprite_normal_light.gdshader"
const SPRITE_DIR := "res://assets/sprites/"

# name, albedo, normal, position, size, shadow, shadow position, shadow size
const LIT_SPRITES := [
	{
		"name": "room_wall",
		"albedo": "room_wall.png", "normal": "room_wall_normal.png",
		"pos": Vector2(0, 0), "size": Vector2i(320, 116), "z": -20,
	},
	{
		"name": "room_floor",
		"albedo": "room_floor.png", "normal": "room_floor_normal.png",
		"pos": Vector2(0, 116), "size": Vector2i(320, 64), "z": -19,
	},
	{
		"name": "guardian",
		"albedo": "guardian.png", "normal": "guardian_normal.png",
		"pos": Vector2(96, 68), "size": Vector2i(64, 88), "z": 0,
		"shadow": "shadow_guardian.png", "shadow_pos": Vector2(89, 152),
		"shadow_size": Vector2i(78, 18),
	},
	{
		"name": "barrel",
		"albedo": "barrel.png", "normal": "barrel_normal.png",
		"pos": Vector2(180, 100), "size": Vector2i(44, 54), "z": 1,
		"shadow": "shadow_barrel.png", "shadow_pos": Vector2(173, 151),
		"shadow_size": Vector2i(58, 15),
	},
	{
		"name": "golem",
		"albedo": "golem.png", "normal": "golem_normal.png",
		"pos": Vector2(248, 106), "size": Vector2i(36, 48), "z": 2,
		"shadow": "shadow_golem.png", "shadow_pos": Vector2(241, 150),
		"shadow_size": Vector2i(50, 13),
	},
]

const DEBUG_ANCHORS := {
	"guardian": Vector2(128, 112),
	"barrel": Vector2(202, 124),
	"golem": Vector2(266, 126),
	"room_floor": Vector2(208, 160),
	"room_wall": Vector2(230, 56),
}

var _entries: Dictionary = {}
var _shader: Shader
var _native_mode := false
var _golem_rest_pos := Vector2.ZERO
var _scale_test := false


func _ready() -> void:
	_shader = load(SHADER_PATH)
	_build_room()
	_golem_rest_pos = _entries["golem"]["sprite"].position


func _build_room() -> void:
	for spec in LIT_SPRITES:
		var entry := _make_lit_sprite(spec)
		_entries[spec["name"]] = entry
		if spec.has("shadow"):
			_make_shadow(spec)


func _make_lit_sprite(spec: Dictionary) -> Dictionary:
	var albedo: Texture2D = load(SPRITE_DIR + spec["albedo"])
	var normal: Texture2D = load(SPRITE_DIR + spec["normal"])
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("normal_tex", normal)
	mat.set_shader_parameter("flip_x", 1.0)

	var sprite := Sprite2D.new()
	sprite.name = String(spec["name"]).to_pascal_case()
	sprite.centered = false
	sprite.position = spec["pos"]
	sprite.texture = albedo
	sprite.material = mat
	sprite.z_index = int(spec["z"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	var canvas_tex := CanvasTexture.new()
	canvas_tex.diffuse_texture = albedo
	canvas_tex.normal_texture = normal
	canvas_tex.specular_color = Color(0.36, 0.33, 0.28, 1.0)
	canvas_tex.specular_shininess = 0.28
	canvas_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	return {
		"name": String(spec["name"]),
		"albedo": albedo,
		"normal": normal,
		"material": mat,
		"canvas_texture": canvas_tex,
		"sprite": sprite,
		"size": spec["size"],
		"pos": spec["pos"],
	}


func _make_shadow(spec: Dictionary) -> void:
	var shadow := Sprite2D.new()
	shadow.name = String(spec["name"]).to_pascal_case() + "Shadow"
	shadow.centered = false
	shadow.texture = load(SPRITE_DIR + spec["shadow"])
	shadow.position = spec["shadow_pos"]
	shadow.z_index = -2
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	shadow.material = mat
	add_child(shadow)


# ── 路径切换 / 参数入口 ──────────────────────────────────────────────────
func set_native_mode(enabled: bool) -> void:
	if enabled == _native_mode:
		return
	_native_mode = enabled
	for entry in _entries.values():
		var sprite: Sprite2D = entry["sprite"]
		if enabled:
			sprite.material = null
			sprite.texture = entry["canvas_texture"]
		else:
			sprite.material = entry["material"]
			sprite.texture = entry["albedo"]


func is_native_mode() -> bool:
	return _native_mode


func set_flip(name: String, flipped: bool) -> void:
	var entry: Dictionary = _entries.get(name, {})
	if entry.is_empty():
		return
	var sprite: Sprite2D = entry["sprite"]
	sprite.flip_h = flipped
	var mat: ShaderMaterial = entry["material"]
	mat.set_shader_parameter("flip_x", -1.0 if flipped else 1.0)


func set_scale_test(enabled: bool) -> void:
	_scale_test = enabled
	var entry: Dictionary = _entries.get("golem", {})
	if entry.is_empty():
		return
	var sprite: Sprite2D = entry["sprite"]
	var size: Vector2i = entry["size"]
	var anchor := _golem_rest_pos + Vector2(size.x * 0.5, size.y)
	sprite.scale = Vector2(2.0, 2.0) if enabled else Vector2.ONE
	if enabled:
		# keep the feet anchored when scaling from centered=false
		sprite.position = anchor - Vector2(size.x, size.y * 2.0)
	else:
		sprite.position = _golem_rest_pos


func is_scale_test() -> bool:
	return _scale_test


func get_entry(name: String) -> Dictionary:
	return _entries.get(name, {})


func get_entries() -> Dictionary:
	return _entries


func get_debug_anchor(name: String) -> Vector2:
	return DEBUG_ANCHORS.get(name, Vector2.ZERO)


func get_light_sample_points() -> Array:
	return [
		DEBUG_ANCHORS["room_wall"],
		DEBUG_ANCHORS["room_floor"],
		DEBUG_ANCHORS["guardian"],
		DEBUG_ANCHORS["barrel"],
		DEBUG_ANCHORS["golem"],
	]


func get_report() -> Dictionary:
	var report := {
		"entries": _entries.size(),
		"native_mode": _native_mode,
		"sprites": [],
	}
	for name in _entries:
		var e: Dictionary = _entries[name]
		var sprite: Sprite2D = e["sprite"]
		var normal_image: Image = e["normal"].get_image()
		var normal_flat := _normal_is_flat(normal_image)
		report["sprites"].append({
			"name": name,
			"size": e["size"],
			"position": sprite.position,
			"material_shader": e["material"].shader.resource_path if \
					e["material"].shader != null else "",
			"has_normal": e["normal"] != null,
			"canvas_diffuse": e["canvas_texture"].diffuse_texture == e["albedo"],
			"canvas_normal": e["canvas_texture"].normal_texture == e["normal"],
			"normal_size": normal_image.get_size(),
			"normal_nonflat": not normal_flat,
			"flip_h": sprite.flip_h,
			"scale": sprite.scale,
			"texture_is_canvas": sprite.texture is CanvasTexture,
			"material_is_null": sprite.material == null,
		})
	return report


func _normal_is_flat(image: Image) -> bool:
	var w := image.get_width()
	var h := image.get_height()
	var step := maxi(1, w / 24)
	for y in range(0, h, maxi(1, h / 24)):
		for x in range(0, w, step):
			var c := image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if absf(c.r - 0.5) > 0.03 or absf(c.g - 0.5) > 0.03:
				return false
	return true
