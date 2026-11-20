class_name RaftStation
extends Node3D

# 木筏设施：木箱（自动存取）、净水器（木头→净水，35% 省木）、烤鱼架（鱼→烤鱼）。
const PURIFY_BATCH := 18.0
const GRILL_BATCH := 12.0
const MAX_READY := 3
const FREE_WOOD_CHANCE := 0.35

var kind := "crate"
var cell := Vector2i.ZERO
var world: Node
var stored := {"wood": 0, "planks": 0}
var timer := 0.0
var ready_water := 0
var ready_cooked := 0
var produced := 0
var free_batches := 0
var visual_t := 0.0
var icon: Sprite3D
var droplet: Sprite3D
var fish_sprite: Sprite3D


func setup(kind_name: String, at_cell: Vector2i, world_ref: Node) -> void:
	kind = kind_name
	cell = at_cell
	world = world_ref
	name = "Station_" + kind
	position = world.cell_center(cell) + Vector3(0.0, world.DECK_Y, 0.0)
	match kind:
		"purifier":
			_build_purifier()
		"grill":
			_build_grill()
		_:
			_build_crate()
	_build_icon()


func _mat(color: Color, unshaded := true, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _box(size: Vector3, color: Color, pos: Vector3, alpha := 1.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(bm, _mat(color, true, alpha), pos)


func _build_crate() -> void:
	var tex_mat := StandardMaterial3D.new()
	tex_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tex_mat.albedo_texture = Art.crate_panel()
	tex_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var bm := BoxMesh.new()
	bm.size = Vector3(1.12, 0.86, 1.12)
	_mesh(bm, tex_mat, Vector3(0.0, 0.43, 0.0))
	var lid := BoxMesh.new()
	lid.size = Vector3(1.2, 0.12, 1.2)
	_mesh(lid, _mat(Color("#a8743f")), Vector3(0.0, 0.9, 0.0))
	var rim := BoxMesh.new()
	rim.size = Vector3(1.24, 0.07, 1.24)
	_mesh(rim, _mat(Color("#5b3a25")), Vector3(0.0, 0.83, 0.0))


func _build_purifier() -> void:
	var base := CylinderMesh.new()
	base.top_radius = 0.44
	base.bottom_radius = 0.5
	base.height = 0.24
	base.radial_segments = 8
	_mesh(base, _mat(Color("#6d7f7d")), Vector3(0.0, 0.12, 0.0))

	var tank := CylinderMesh.new()
	tank.top_radius = 0.3
	tank.bottom_radius = 0.36
	tank.height = 0.95
	tank.radial_segments = 8
	_mesh(tank, _mat(Color("#4b94a4"), true, 0.9), Vector3(0.0, 0.72, 0.0))
	var inner := CylinderMesh.new()
	inner.top_radius = 0.22
	inner.bottom_radius = 0.26
	inner.height = 0.5
	inner.radial_segments = 8
	_mesh(inner, _mat(Color("#8fe0e3"), true, 0.85), Vector3(0.0, 0.58, 0.0))

	var funnel := CylinderMesh.new()
	funnel.top_radius = 0.33
	funnel.bottom_radius = 0.15
	funnel.height = 0.22
	funnel.radial_segments = 8
	_mesh(funnel, _mat(Color("#c47a4a")), Vector3(0.0, 1.31, 0.0))
	_box(Vector3(0.1, 0.09, 0.3), Color("#c47a4a"), Vector3(0.0, 1.19, 0.24))
	_box(Vector3(0.34, 0.05, 0.34), Color("#8d6a43"), Vector3(0.0, 1.45, 0.0))
	# 侧边水位窗
	_box(Vector3(0.08, 0.42, 0.05), Color("#bfeef2"), Vector3(0.31, 0.65, 0.1))

	var drop := Sprite3D.new()
	drop.name = "Droplet"
	drop.texture = Art.icon("water")
	drop.pixel_size = 0.035
	drop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	drop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	drop.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	drop.position = Vector3(0.0, 0.98, 0.24)
	drop.visible = false
	add_child(drop)
	droplet = drop


func _build_grill() -> void:
	_box(Vector3(0.94, 0.2, 0.94), Color("#6d7f7d"), Vector3(0.0, 0.1, 0.0))
	_box(Vector3(0.8, 0.34, 0.8), Color("#435355"), Vector3(0.0, 0.34, 0.0))
	# 炉膛火
	for i in 3:
		_box(Vector3(0.17, 0.1, 0.17), Color("#e8743b"), Vector3(-0.24 + i * 0.24, 0.3, 0.24))
	# 四角柱
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(Vector3(0.07, 0.5, 0.07), Color("#2c393b"), Vector3(x * 0.36, 0.45, z * 0.36))
	# 烤网
	for i in 5:
		_box(Vector3(0.72, 0.025, 0.035), Color("#9aa9a4"), Vector3(0.0, 0.53, -0.3 + i * 0.15))
	for i in 2:
		_box(Vector3(0.035, 0.025, 0.72), Color("#9aa9a4"), Vector3(-0.3 + i * 0.6, 0.53, 0.0))
	# 侧把手
	_box(Vector3(0.5, 0.04, 0.05), Color("#8d6a43"), Vector3(0.0, 0.5, -0.46))
	_box(Vector3(0.05, 0.16, 0.05), Color("#8d6a43"), Vector3(-0.22, 0.44, -0.46))
	_box(Vector3(0.05, 0.16, 0.05), Color("#8d6a43"), Vector3(0.22, 0.44, -0.46))

	var fish := Sprite3D.new()
	fish.name = "Fish"
	fish.texture = Art.fish()
	fish.pixel_size = 0.036
	fish.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fish.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	fish.position = Vector3(0.0, 0.75, 0.0)
	fish.visible = false
	add_child(fish)
	fish_sprite = fish


func _build_icon() -> void:
	icon = Sprite3D.new()
	icon.name = "Icon"
	var kind_icon := "storage" if kind == "crate" else kind
	icon.texture = Art.icon(kind_icon)
	icon.pixel_size = 0.022
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	icon.position = Vector3(0.0, 1.62, 0.0)
	icon.render_priority = 4
	icon.visible = false
	add_child(icon)


func _process(delta: float) -> void:
	visual_t += delta
	if icon != null:
		var ready := ready_water + ready_cooked
		icon.visible = ready > 0 and kind != "crate"
		var bounce := absf(sin(visual_t * 3.0)) * 0.10 if ready > 0 else 0.0
		icon.position.y = 1.62 + bounce
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if kind == "purifier" and droplet != null:
		droplet.visible = ready_water > 0
		droplet.position.y = 0.98 + sin(visual_t * 4.0) * 0.06
		droplet.modulate.a = 0.8 + 0.2 * sin(visual_t * 5.0)
	elif kind == "grill" and fish_sprite != null:
		fish_sprite.visible = timer > 0.2 or ready_cooked > 0
		fish_sprite.position.y = 0.72 + sin(visual_t * 3.5) * 0.03
		fish_sprite.modulate = Color(0.85, 0.8, 0.75) if ready_cooked == 0 else Color.WHITE


# ── simulation ────────────────────────────────────────────────────────────
func tick(delta: float) -> void:
	if world == null or not world.is_playing():
		return
	match kind:
		"purifier":
			if ready_water >= MAX_READY:
				return
			timer += delta
			while timer >= PURIFY_BATCH and ready_water < MAX_READY:
				timer -= PURIFY_BATCH
				var free: bool = world.rng.randf() < FREE_WOOD_CHANCE
				if free:
					free_batches += 1
				elif not world.consume_wood_any(1):
					timer = 0.0
					break
				ready_water += 1
				produced += 1
				world.on_station_produced(self, "water")
		"grill":
			if ready_cooked >= MAX_READY:
				return
			timer += delta
			while timer >= GRILL_BATCH and ready_cooked < MAX_READY:
				timer -= GRILL_BATCH
				if not world.consume_fish(1):
					timer = 0.0
					break
				ready_cooked += 1
				produced += 1
				world.on_station_produced(self, "cooked")


func take_output() -> Dictionary:
	var out := {}
	if ready_water > 0:
		out["water"] = ready_water
		ready_water = 0
	if ready_cooked > 0:
		out["cooked"] = ready_cooked
		ready_cooked = 0
	return out


func status_text() -> String:
	match kind:
		"purifier":
			var left := maxf(0.0, PURIFY_BATCH - timer)
			return "净水器 · 下杯 %ds · 待取 %d · 省木 35%%" % [ceili(left), ready_water]
		"grill":
			var left := maxf(0.0, GRILL_BATCH - timer)
			return "烤鱼架 · 下条 %ds · 待取 %d" % [ceili(left), ready_cooked]
		_:
			return "木箱 · 自动存取 · 存 %d 木材 / %d 木板" % [stored["wood"], stored["planks"]]


func deposit(res: String, amount: int) -> int:
	if not stored.has(res) or amount <= 0:
		return 0
	stored[res] += amount
	return amount


func withdraw(res: String, amount: int) -> int:
	if not stored.has(res):
		return 0
	var taken: int = mini(amount, stored[res])
	stored[res] -= taken
	return taken


func storage_total() -> int:
	return int(stored["wood"]) + int(stored["planks"])
