class_name FloatLoot
extends Node3D

# 漂浮物：木桶 / 木箱 / 鱼。视觉用 billboard 像素图，逻辑数据由世界生成。
var kind := "barrel"
var wood := 0
var planks := 0
var fish := 0
var label_cn := "木桶"
var world: Node
var sprite: Sprite3D
var shadow: MeshInstance3D
var ring: MeshInstance3D
var bob_phase := 0.0
var drift := Vector3.ZERO
var age := 0.0
var lifetime := 58.0
var alive := true
var base_sprite_y := 0.36
var _blink := 0.0


func setup(kind_name: String, payload: Dictionary, world_ref: Node) -> void:
	world = world_ref
	kind = kind_name
	wood = int(payload.get("wood", 0))
	planks = int(payload.get("planks", 0))
	fish = int(payload.get("fish", 0))
	var tex: Texture2D
	var pix := 0.042
	match kind:
		"crate":
			tex = Art.crate()
			label_cn = "木箱"
			pix = 0.048
			base_sprite_y = 0.36
		"fish":
			tex = Art.fish()
			label_cn = "银鱼"
			pix = 0.042
			base_sprite_y = 0.26
			drift = Vector3(0.42, 0.0, 0.18)
		_:
			tex = Art.barrel()
			label_cn = "木桶"
			pix = 0.044
			base_sprite_y = 0.38
			drift = Vector3(0.12, 0.0, -0.08)
	bob_phase = randf() * TAU

	sprite = Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	sprite.pixel_size = pix
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.double_sided = true
	sprite.render_priority = 2
	sprite.position = Vector3(0.0, base_sprite_y, 0.0)
	add_child(sprite)

	shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 0.55)
	shadow.mesh = quad
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = Art.shadow()
	smat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = smat
	shadow.rotation.x = -PI / 2.0
	shadow.position.y = 0.012
	add_child(shadow)

	ring = MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(1.6, 1.6)
	ring.mesh = rq
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_texture = Art.water_ring()
	rmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = rmat
	ring.rotation.x = -PI / 2.0
	ring.position.y = 0.006
	add_child(ring)


func _process(delta: float) -> void:
	if not alive:
		return
	age += delta
	bob_phase += delta
	var bob := sin(bob_phase * 2.1 + float(kind.length())) * 0.055
	if sprite != null:
		sprite.position.y = base_sprite_y + bob
	if world != null and world.is_playing():
		global_position += drift * delta
		if age > lifetime - 8.0:
			_blink += delta
			var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink * 9.0))
			if sprite != null:
				sprite.modulate.a = a
			if shadow != null:
				shadow.transparency = 1.0 - a


func aim_pos() -> Vector3:
	return global_position + Vector3(0.0, base_sprite_y + 0.3, 0.0)


func payload() -> Dictionary:
	return {"kind": kind, "wood": wood, "planks": planks, "fish": fish}
