class_name SakuraWorld
extends Node2D

# 固定机位的 640×360 像素庭院。所有造型都来自 SakuraArt 的程序化像素图；
# 光照只走 3 个共享 shader + 全局 uniform，没有 Light2D / 3D 灯光。

const WORLD := Vector2(640.0, 360.0)
const TUFTS := 180
const FLOWERS := 64

const TREE_SPECS: Array[Dictionary] = [
	{
		"name": "hero", "art": "tree_hero", "base": Vector2(300.0, 185.0),
		"z": 6, "cap": 1.8, "contact_scale": 1.35,
	},
	{
		"name": "right", "art": "tree_right", "base": Vector2(505.0, 162.0),
		"z": 4, "cap": 1.8, "contact_scale": 1.05,
	},
	{
		"name": "sapling", "art": "tree_sapling", "base": Vector2(404.0, 292.0),
		"z": 8, "cap": 1.8, "contact_scale": 0.72,
	},
]

const ROCK_SPECS: Array[Dictionary] = [
	{
		"name": "rock_big", "art": "rock_big", "base": Vector2(78.0, 318.0),
		"z": 9, "cap": 1.6, "contact_scale": 1.20,
	},
	{
		"name": "rock_mid", "art": "rock_mid", "base": Vector2(392.0, 326.0),
		"z": 9, "cap": 1.6, "contact_scale": 0.82,
	},
	{
		"name": "rock_small", "art": "rock_small", "base": Vector2(186.0, 334.0),
		"z": 7, "cap": 1.6, "contact_scale": 0.62,
	},
]

var art: Dictionary = {}
var foliage_material: ShaderMaterial
var ground_material: ShaderMaterial
var shadow_material: ShaderMaterial
var trees: Array[Dictionary] = []
var rocks: Array[Dictionary] = []
var shadows: Array[ShadowCaster] = []
var petals: PetalField
var debug_overlay: SunDebugOverlay

var _solar: Dictionary = {}
var _shadows_enabled := true
var _debug_enabled := false
var _petals_enabled := true
var _ground: Sprite2D
var _hedge: Sprite2D
var _shadow_root: Node2D


func _ready() -> void:
	art = SakuraArt.build()
	_make_materials()
	_build_ground()
	_build_scatter()
	_build_trees()
	_build_rocks()
	_build_shadows()
	_build_petals()
	_build_vignette()
	_build_debug()
	apply_solar(SunModel.state(SunModel.DAY_START_HOUR), _shadows_enabled)
	print("SAKURA_WORLD_READY trees=%d rocks=%d petals=%d" % [
		trees.size(), rocks.size(), petals.get_active_count()])


func _make_materials() -> void:
	foliage_material = ShaderMaterial.new()
	foliage_material.shader = load("res://shaders/foliage_light.gdshader")
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/ground_light.gdshader")
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = load("res://shaders/cast_shadow.gdshader")


func _build_ground() -> void:
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.centered = false
	_ground.texture = ImageTexture.create_from_image(art["ground"])
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.material = ground_material
	_ground.z_index = -10
	add_child(_ground)

	_hedge = Sprite2D.new()
	_hedge.name = "FarHedge"
	_hedge.centered = false
	var hedge_img: Image = art["hedge"]
	_hedge.texture = ImageTexture.create_from_image(hedge_img)
	_hedge.position = Vector2(0.0, 84.0 - float(hedge_img.get_height()))
	_hedge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hedge.material = ground_material
	_hedge.z_index = -8
	add_child(_hedge)


func _build_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125
	var tuft_tex := ImageTexture.create_from_image(art["tuft"])
	var grass := MultiMeshInstance2D.new()
	grass.name = "GrassTufts"
	grass.texture = tuft_tex
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.material = foliage_material
	grass.z_index = -1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(14.0, 12.0)
	mm.mesh = quad
	mm.instance_count = TUFTS
	# 草丛按“簇”分布，而不是均匀撒点；靠近底部的草更高更密。
	var clump_count := 45
	var clumps: Array[Vector2] = []
	for i in clump_count:
		clumps.append(Vector2(rng.randf_range(8.0, 632.0),
				rng.randf_range(84.0, 350.0)))
	for i in TUFTS:
		var anchor: Vector2 = clumps[i % clump_count]
		var x := anchor.x + rng.randf_range(-14.0, 14.0)
		var y := anchor.y + rng.randf_range(-10.0, 10.0)
		var depth := clampf((y - 76.0) / 279.0, 0.0, 1.0)
		var s := rng.randf_range(0.66, 1.06) * lerpf(0.92, 1.48, depth)
		if y > 300.0 and rng.randf() > 0.72:
			s *= rng.randf_range(1.25, 1.55)
		var flip := -1.0 if rng.randf() < 0.5 else 1.0
		mm.set_instance_transform_2d(i, Transform2D(0.0,
				Vector2(s * flip, s), 0.0, Vector2(x, y - 6.0 * s)))
		var tint := Color(
			rng.randf_range(0.96, 1.06),
			rng.randf_range(0.98, 1.05),
			rng.randf_range(0.90, 1.00),
			1.0)
		mm.set_instance_color(i, tint)
	grass.multimesh = mm
	add_child(grass)

	# 前景草：沿画面下缘和左右边缘压一层较暗的草叶，增加景深。
	var fg := MultiMeshInstance2D.new()
	fg.name = "ForegroundGrass"
	fg.texture = tuft_tex
	fg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fg.material = foliage_material
	fg.z_index = 28
	var fgmm := MultiMesh.new()
	fgmm.transform_format = MultiMesh.TRANSFORM_2D
	fgmm.use_colors = true
	var fgquad := QuadMesh.new()
	fgquad.size = Vector2(14.0, 12.0)
	fgmm.mesh = fgquad
	fgmm.instance_count = 38
	for i in 38:
		var px: float
		var py: float
		var ps: float
		if i < 24:
			px = rng.randf_range(-6.0, 646.0)
			py = rng.randf_range(354.0, 370.0)
			ps = rng.randf_range(1.8, 2.8)
		elif i < 31:
			px = rng.randf_range(-4.0, 12.0)
			py = rng.randf_range(220.0, 354.0)
			ps = rng.randf_range(1.6, 2.4)
		else:
			px = rng.randf_range(628.0, 644.0)
			py = rng.randf_range(220.0, 354.0)
			ps = rng.randf_range(1.6, 2.4)
		var flip := -1.0 if rng.randf() < 0.5 else 1.0
		fgmm.set_instance_transform_2d(i, Transform2D(0.0,
				Vector2(ps * flip, ps), 0.0, Vector2(px, py - 6.0 * ps)))
		fgmm.set_instance_color(i, Color(
			rng.randf_range(0.74, 0.88), rng.randf_range(0.88, 0.98),
			rng.randf_range(0.72, 0.84), 1.0))
	fg.multimesh = fgmm
	add_child(fg)

	var flower_tex := ImageTexture.create_from_image(art["flower"])
	var flowers := MultiMeshInstance2D.new()
	flowers.name = "Flowers"
	flowers.texture = flower_tex
	flowers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flowers.material = foliage_material
	flowers.z_index = -1
	var fmm := MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_2D
	fmm.use_colors = true
	var fquad := QuadMesh.new()
	fquad.size = Vector2(8.0, 12.0)
	fmm.mesh = fquad
	fmm.instance_count = FLOWERS
	for i in FLOWERS:
		var x := rng.randf_range(6.0, 634.0)
		var y := rng.randf_range(100.0, 352.0)
		var s := rng.randf_range(0.78, 1.20)
		fmm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(s, s), 0.0,
				Vector2(x, y - 6.0 * s)))
		var roll := rng.randf()
		var tint := Color(1.0, 0.91, 0.95, 1.0)
		if roll > 0.62:
			tint = Color(1.0, 0.82, 0.87, 1.0)
		elif roll > 0.86:
			tint = Color(1.0, 0.96, 0.78, 1.0)
		fmm.set_instance_color(i, tint)
	flowers.multimesh = fmm
	add_child(flowers)


func _build_trees() -> void:
	for spec in TREE_SPECS:
		var tree_art: Dictionary = art[spec["art"]]
		var base: Vector2 = spec["base"]
		var trunk_img: Image = tree_art["trunk"]
		var canopy_img: Image = tree_art["canopy"]
		var trunk_visible := int(tree_art["trunk_visible"])
		var z := int(spec["z"])

		var trunk := Sprite2D.new()
		trunk.name = "Trunk_%s" % spec["name"]
		trunk.centered = false
		trunk.texture = ImageTexture.create_from_image(trunk_img)
		trunk.offset = Vector2(-float(trunk_img.get_width()) * 0.5,
				-float(trunk_img.get_height()))
		trunk.position = base
		trunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		trunk.material = foliage_material
		trunk.z_index = z
		add_child(trunk)

		var canopy := Sprite2D.new()
		canopy.name = "Canopy_%s" % spec["name"]
		canopy.centered = false
		canopy.texture = ImageTexture.create_from_image(canopy_img)
		canopy.offset = Vector2(-float(canopy_img.get_width()) * 0.5,
				-float(canopy_img.get_height()))
		canopy.position = base + Vector2(0.0, -float(trunk_visible))
		canopy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		canopy.material = foliage_material
		canopy.z_index = z + 1
		add_child(canopy)

		trees.append({
			"name": spec["name"],
			"base": base,
			"trunk": trunk,
			"canopy": canopy,
			"art": tree_art,
			"height": float(tree_art["visual_height"]),
			"trunk_visible": float(trunk_visible),
			"canopy_center": base + Vector2(0.0,
					-float(trunk_visible) - float(canopy_img.get_height()) * 0.45),
			"canopy_radius": Vector2(float(canopy_img.get_width()) * 0.38,
					float(canopy_img.get_height()) * 0.30),
			"z": z,
		})


func _build_rocks() -> void:
	for spec in ROCK_SPECS:
		var rock_art: Dictionary = art[spec["art"]]
		var img: Image = rock_art["image"]
		var base: Vector2 = spec["base"]
		var sprite := Sprite2D.new()
		sprite.name = "Rock_%s" % spec["name"]
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.offset = Vector2(-float(img.get_width()) * 0.5, -float(img.get_height()))
		sprite.position = base
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.material = foliage_material
		sprite.z_index = int(spec["z"])
		add_child(sprite)
		rocks.append({
			"name": spec["name"],
			"base": base,
			"image": img,
			"height": float(img.get_height()),
			"art": rock_art,
			"spec": spec,
		})


func _build_shadows() -> void:
	_shadow_root = Node2D.new()
	_shadow_root.name = "GroundShadows"
	_shadow_root.z_index = 2
	add_child(_shadow_root)

	var contact_tex := ImageTexture.create_from_image(art["contact"])
	var trunk_shadow: Image = art["trunk_shadow"]

	for tree in trees:
		var tree_art: Dictionary = tree["art"]
		var caster := ShadowCaster.new()
		caster.name = "Shadow_%s" % tree["name"]
		_shadow_root.add_child(caster)
		var spec := {
			"name": tree["name"],
			"base": tree["base"],
			"height": tree["height"],
			"trunk_height": tree["trunk_visible"],
			"cap": _tree_cap(tree["name"]),
			"contact_scale": _tree_contact(tree["name"]),
			"trunk_shadow": trunk_shadow,
			"crown_shadow": tree_art["crown_shadow"],
			"z": 0,
		}
		caster.setup(spec, shadow_material, contact_tex)
		shadows.append(caster)

	for rock in rocks:
		var caster := ShadowCaster.new()
		caster.name = "Shadow_%s" % rock["name"]
		_shadow_root.add_child(caster)
		var rock_art: Dictionary = rock["art"]
		var spec := {
			"name": rock["name"],
			"base": rock["base"],
			"height": rock["height"],
			"trunk_height": 0.0,
			"cap": float(rock["spec"]["cap"]),
			"contact_scale": float(rock["spec"]["contact_scale"]),
			"crown_shadow": rock_art["shadow"],
			"z": 0,
		}
		caster.setup(spec, shadow_material, contact_tex)
		shadows.append(caster)


func _tree_cap(tree_name: String) -> float:
	for spec in TREE_SPECS:
		if spec["name"] == tree_name:
			return float(spec["cap"])
	return 2.0


func _tree_contact(tree_name: String) -> float:
	for spec in TREE_SPECS:
		if spec["name"] == tree_name:
			return float(spec["contact_scale"])
	return 1.0


func _build_petals() -> void:
	var sources: Array[Dictionary] = []
	for tree in trees:
		sources.append({
			"pos": tree["canopy_center"],
			"radius": tree["canopy_radius"],
		})
	petals = PetalField.new()
	var petal_tex := ImageTexture.create_from_image(art["petal"])
	petals.setup(petal_tex, foliage_material, sources, Rect2(4.0, 40.0, 632.0, 310.0),
			20261125, PetalField.DEFAULT_COUNT)
	add_child(petals)


func _build_vignette() -> void:
	var layer := ColorRect.new()
	layer.name = "Vignette"
	layer.position = Vector2.ZERO
	layer.size = WORLD
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 45
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	layer.material = mat
	add_child(layer)


func _build_debug() -> void:
	debug_overlay = SunDebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.world = self
	debug_overlay.z_index = 50
	debug_overlay.visible = false
	add_child(debug_overlay)


# ── 每帧 / 外部入口 ──────────────────────────────────────────────────────
func apply_solar(state: Dictionary, shadows_enabled: bool) -> void:
	_solar = state
	_shadows_enabled = shadows_enabled
	if _shadow_root != null:
		_shadow_root.visible = shadows_enabled
	for caster in shadows:
		caster.update_sun(float(state["hour"]), shadows_enabled)


func step_petals(delta: float) -> void:
	if petals != null:
		petals.step(delta)


func simulate_petals(seconds: float) -> void:
	var left := maxf(seconds, 0.0)
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		step_petals(dt)
		left -= dt


func set_shadows_enabled(value: bool) -> void:
	_shadows_enabled = value
	if _shadow_root != null:
		_shadow_root.visible = value
	for caster in shadows:
		caster.set_shadows_enabled(value)


func set_petals_enabled(value: bool) -> void:
	_petals_enabled = value
	if petals != null:
		petals.set_petals_enabled(value)


func set_debug_enabled(value: bool) -> void:
	_debug_enabled = value
	if debug_overlay != null:
		debug_overlay.visible = value
		debug_overlay.queue_redraw()


func get_debug_data() -> Dictionary:
	if _solar.is_empty():
		return {}
	var reports: Array = []
	for caster in shadows:
		reports.append(caster.get_report())
	return {
		"hour": _solar["hour"],
		"azimuth": _solar["azimuth"],
		"elevation": _solar["elevation"],
		"sun_dir": _solar["sun_dir"],
		"shadow_dir": _solar["shadow_dir"],
		"shadows": reports,
	}


# ── 测试 / UI 查询 ───────────────────────────────────────────────────────
func get_tree_count() -> int:
	return trees.size()


func get_tree_entry(index: int) -> Dictionary:
	return trees[index]


func get_rocks() -> Array[Dictionary]:
	return rocks


func get_shadow_reports() -> Array:
	var out: Array = []
	for caster in shadows:
		out.append(caster.get_report())
	return out


func get_hero_shadow() -> ShadowCaster:
	for caster in shadows:
		if caster.display_name == "hero":
			return caster
	return null


func get_petals() -> PetalField:
	return petals


func get_trees() -> Array[Dictionary]:
	return trees


func get_ground() -> Sprite2D:
	return _ground


func get_shadows_root() -> Node2D:
	return _shadow_root


func is_shadows_enabled() -> bool:
	return _shadows_enabled


func is_debug_enabled() -> bool:
	return _debug_enabled


func is_petals_enabled() -> bool:
	return _petals_enabled


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
