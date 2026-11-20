class_name RaftWorld
extends Node3D

# 核心循环：蓄力自瞄抛钩 → 追踪漂浮物 → 资源入包 → 建造/净水/烤鱼 → 生存与胜负。
# 所有世界与玩法逻辑集中在这里，HUD 只读快照，方便 headless 验收。

signal toast(text: String, color: Color)
signal float_text(text: String, color: Color, world_pos: Vector3)

const TILE := 2.0
const DECK_Y := 0.34
const START_CELLS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const WIN_TILES := 12
const WIN_DAY := 4
const DAY_LENGTH := 80.0
const THIRST_RATE := 0.28
const HUNGER_RATE := 0.18
const LOCK_RANGE := 20.0
const HOOK_COOLDOWN := 0.5
const MAX_LOOT := 8
const SPAWN_EVERY := 2.7
const STATE_PLAYING := "playing"
const STATE_WON := "won"
const STATE_LOST := "lost"

const COSTS := {
	"expand": {"planks": 2},
	"crate": {"planks": 3},
	"purifier": {"planks": 2, "wood": 2},
	"grill": {"planks": 3, "wood": 2},
}
const BUILD_NAMES := {
	"expand": "扩建木筏",
	"crate": "木箱",
	"purifier": "净水器",
	"grill": "烤鱼架",
}
const TEAL := Color("#8fe0d0")
const GOLD := Color("#f3c46f")
const CORAL_C := Color("#ee8a72")
const GREEN := Color("#9fe8b0")
const BLUE := Color("#8fe0e3")

var rng := RandomNumberGenerator.new()
var state := STATE_PLAYING
var inventory := {"wood": 4, "planks": 3, "fish": 1, "water": 1, "cooked": 0}
var thirst := 62.0
var hunger := 66.0
var stamina := 100.0
var day := 1
var day_time := 0.0
var end_reason := ""

var raft: Dictionary = {}
var stations: Dictionary = {}
var loot: Array[FloatLoot] = []
var player: RaftPlayer
var camera: Camera3D
var raft_root: Node3D
var station_root: Node3D
var loot_root: Node3D
var fx_root: Node3D
var water_mat: ShaderMaterial
var env: Environment
var lamp_glow_mat: StandardMaterial3D

var placement_mode := false
var placement_type := ""
var hover_cell := Vector2i(9999, 9999)
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var marker: MeshInstance3D
var charge_ring: MeshInstance3D
var rope: MeshInstance3D
var hook_sprite: Sprite3D
var hook_bead: MeshInstance3D
var _hook_ripple_t := 0.0

var hook_state := "idle"
var charge := 0.0
var locked_loot: FloatLoot = null
var hook_target: FloatLoot = null
var hook_pos := Vector3.ZERO
var hook_vel := Vector3.ZERO
var cooldown := 0.0
var hook_flight_time := 0.0
var last_catch := {}
var spawn_enabled := true
var spawn_timer := 2.5

var cam_yaw := deg_to_rad(42.0)
var cam_pitch := deg_to_rad(36.0)
var cam_size := 12.6
var cam_focus := Vector3.ZERO
var shake := 0.0
var world_time := 0.0
var _ripples := PackedVector4Array()
var _ripple_i := 0
var _sfx: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _fx: Array[Dictionary] = []
var _ambient_t := 2.2
var _was_lock: FloatLoot = null
var intro_enabled := true


func _ready() -> void:
	rng.seed = 20261120
	day_time = DAY_LENGTH * 0.10
	_init_ripples()
	_build_environment()
	_build_water()
	raft_root = Node3D.new()
	raft_root.name = "Raft"
	add_child(raft_root)
	station_root = Node3D.new()
	station_root.name = "Stations"
	add_child(station_root)
	loot_root = Node3D.new()
	loot_root.name = "Loot"
	add_child(loot_root)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	for cell in START_CELLS:
		_add_tile(cell, false)
	_build_decor()
	_build_player()
	_build_camera()
	_build_tools()
	_build_audio()
	_update_water_bounds()
	_spawn_initial_loot()
	_update_camera(1.0)
	_update_daylight()
	_intro()


func _process(delta: float) -> void:
	world_time += delta
	if water_mat != null:
		water_mat.set_shader_parameter("time", world_time)
	_update_camera(delta)
	_update_fx(delta)
	_update_spawns(delta)
	_update_loot(delta)
	if state != STATE_PLAYING:
		_update_visual_tools(delta)
		return

	# 日夜 + 生存
	day_time += delta
	if day_time >= DAY_LENGTH:
		day_time -= DAY_LENGTH
		day += 1
		_toast("第 %d 天 · 海面又亮了一点" % day, GOLD)
		_play("lock")
		if day >= WIN_DAY:
			_win("你撑过了三个夜晚，木筏成了真正的家。")
			return
	thirst = maxf(0.0, thirst - THIRST_RATE * delta)
	hunger = maxf(0.0, hunger - HUNGER_RATE * delta)
	if thirst <= 0.0:
		_lose("你渴倒了。净水器应该早点造出来。")
		return
	if hunger <= 0.0:
		_lose("你饿得举不起钓竿了。")
		return

	# 钩子
	cooldown = maxf(0.0, cooldown - delta)
	match hook_state:
		"charging":
			charge = minf(1.0, charge + delta / 1.1)
			_update_lock()
		"flying":
			_update_flight(delta)
		"returning":
			_update_return(delta)
		_:
			locked_loot = null
	_update_auto_collect()
	_update_visual_tools(delta)
	_update_daylight()
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = rng.randf_range(3.2, 6.5)
		var a := rng.randf() * TAU
		var d := maxf(_raft_half().x, _raft_half().y) + rng.randf_range(1.5, 4.0)
		_splash(Vector3(_raft_center().x + cos(a) * d, 0.0, _raft_center().z + sin(a) * d), 0.32)


# ── 构建世界 ──────────────────────────────────────────────────────────────
func _init_ripples() -> void:
	_ripples.resize(8)
	for i in 8:
		_ripples[i] = Vector4(0.0, 0.0, -100.0, 0.0)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#7fc9c2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(160.0, 160.0)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water_mat.set_shader_parameter("ripples", _ripples)
	water.material_override = water_mat
	add_child(water)


func _mat(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _mk_mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_decor() -> void:
	# 桅杆与原创浪纹旗
	var mast := CylinderMesh.new()
	mast.top_radius = 0.045
	mast.bottom_radius = 0.065
	mast.height = 2.6
	mast.radial_segments = 6
	_mk_mesh(mast, _mat(Color("#6b4a30")), Vector3(-1.8, DECK_Y + 1.3, -1.8), raft_root)
	var flag := Sprite3D.new()
	flag.name = "Flag"
	flag.texture = Art.flag()
	flag.pixel_size = 0.026
	flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flag.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	flag.position = Vector3(-1.8, DECK_Y + 2.55, -1.8)
	flag.render_priority = 3
	raft_root.add_child(flag)

	# 小灯柱与暖光晕：亮芯 + 笼柱，夜里更明显
	var post := CylinderMesh.new()
	post.top_radius = 0.035
	post.bottom_radius = 0.05
	post.height = 1.35
	post.radial_segments = 6
	_mk_mesh(post, _mat(Color("#4f4036")), Vector3(1.8, DECK_Y + 0.68, -1.8), raft_root)
	var core := BoxMesh.new()
	core.size = Vector3(0.26, 0.30, 0.26)
	_mk_mesh(core, _mat(Color("#ffd06a")), Vector3(1.8, DECK_Y + 1.46, -1.8), raft_root)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(0.04, 0.42, 0.04)
			_mk_mesh(bar, _mat(Color("#36464a")), Vector3(1.8 + sx * 0.16, DECK_Y + 1.46, -1.8 + sz * 0.16), raft_root)
	var cap_top := BoxMesh.new()
	cap_top.size = Vector3(0.36, 0.06, 0.36)
	_mk_mesh(cap_top, _mat(Color("#36464a")), Vector3(1.8, DECK_Y + 1.68, -1.8), raft_root)
	var cap_bottom := BoxMesh.new()
	cap_bottom.size = Vector3(0.34, 0.06, 0.34)
	_mk_mesh(cap_bottom, _mat(Color("#36464a")), Vector3(1.8, DECK_Y + 1.25, -1.8), raft_root)
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(3.2, 3.2)
	lamp_glow_mat = StandardMaterial3D.new()
	lamp_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lamp_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lamp_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lamp_glow_mat.albedo_texture = Art.glow()
	lamp_glow_mat.albedo_color = Color(1.0, 0.78, 0.42, 0.34)
	lamp_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lamp_glow_mat.no_depth_test = true
	lamp_glow_mat.render_priority = 6
	var glow_mesh := MeshInstance3D.new()
	glow_mesh.name = "LampGlow"
	glow_mesh.mesh = glow_quad
	glow_mesh.material_override = lamp_glow_mat
	glow_mesh.position = Vector3(1.8, DECK_Y + 1.46, -1.8)
	raft_root.add_child(glow_mesh)


func _build_player() -> void:
	player = RaftPlayer.new()
	player.name = "Player"
	player.setup(self)
	player.position = Vector3(0.0, DECK_Y, 0.0)
	add_child(player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = cam_size
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	cam_focus = Vector3(0.0, DECK_Y, 0.0)


func _build_tools() -> void:
	ghost_mat = _mat(Color(0.55, 0.98, 0.84, 0.72), 0.72)
	ghost_mat.albedo_texture = Art.ghost_tile()
	ghost_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ghost_mat.no_depth_test = true
	ghost = MeshInstance3D.new()
	ghost.name = "BuildGhost"
	ghost.material_override = ghost_mat
	ghost.visible = false
	add_child(ghost)

	marker = MeshInstance3D.new()
	marker.name = "LockMarker"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.58
	torus.outer_radius = 0.74
	torus.rings = 14
	torus.ring_segments = 6
	marker.mesh = torus
	var mm := _mat(Color("#9ff3df"))
	mm.albedo_color = Color("#9ff3df")
	marker.material_override = mm
	marker.visible = false
	add_child(marker)

	charge_ring = MeshInstance3D.new()
	charge_ring.name = "ChargeRing"
	var torus2 := TorusMesh.new()
	torus2.inner_radius = 0.68
	torus2.outer_radius = 0.80
	torus2.rings = 16
	torus2.ring_segments = 6
	charge_ring.mesh = torus2
	charge_ring.material_override = _mat(Color("#ffd98a"))
	charge_ring.visible = false
	add_child(charge_ring)

	rope = MeshInstance3D.new()
	rope.name = "Rope"
	var rope_mesh := BoxMesh.new()
	rope_mesh.size = Vector3(0.105, 0.105, 1.0)
	rope.mesh = rope_mesh
	rope.material_override = _mat(Color("#f1d39b"))
	rope.visible = false
	add_child(rope)

	hook_sprite = Sprite3D.new()
	hook_sprite.name = "HookSprite"
	hook_sprite.texture = Art.hook()
	hook_sprite.pixel_size = 0.068
	hook_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hook_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hook_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	hook_sprite.visible = false
	hook_sprite.render_priority = 5
	add_child(hook_sprite)

	hook_bead = MeshInstance3D.new()
	hook_bead.name = "HookBead"
	var bead := SphereMesh.new()
	bead.radius = 0.11
	bead.height = 0.22
	bead.radial_segments = 6
	bead.rings = 3
	hook_bead.mesh = bead
	var bead_mat := _mat(Color("#ffe08a"))
	bead_mat.no_depth_test = true
	hook_bead.material_override = bead_mat
	hook_bead.visible = false
	add_child(hook_bead)


# ── 木筏网格与建造 ────────────────────────────────────────────────────────
func _add_tile(cell: Vector2i, animate: bool) -> void:
	var tile := Node3D.new()
	tile.name = "Tile_%d_%d" % [cell.x, cell.y]
	tile.position = Vector3((cell.x - 0.5) * TILE, 0.0, (cell.y - 0.5) * TILE)
	var box := BoxMesh.new()
	box.size = Vector3(2.03, DECK_Y, 2.03)
	var side := MeshInstance3D.new()
	side.mesh = box
	side.material_override = _mat(Color("#6b4a30"))
	side.position.y = DECK_Y * 0.5
	tile.add_child(side)

	var top_mat := StandardMaterial3D.new()
	top_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top_mat.albedo_texture = Art.wood_tile()
	top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.97, 1.97)
	top.mesh = plane
	top.material_override = top_mat
	top.position.y = DECK_Y + 0.006
	tile.add_child(top)

	# 四条护边
	for dir in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var rim := BoxMesh.new()
		rim.size = Vector3(2.02, 0.07, 0.06) if dir.y != 0.0 else Vector3(0.06, 0.07, 2.02)
		var rim_mesh := MeshInstance3D.new()
		rim_mesh.mesh = rim
		rim_mesh.material_override = _mat(Color("#4c3324"))
		rim_mesh.position = Vector3(dir.x * 0.985, DECK_Y + 0.035, dir.y * 0.985)
		tile.add_child(rim_mesh)

	raft_root.add_child(tile)
	raft[cell] = tile
	if animate:
		tile.position.y = -0.75
		var tw := create_tween()
		tw.tween_property(tile, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_splash(Vector3(tile.position.x, 0.0, tile.position.z), 1.2)


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - 0.5) * TILE, DECK_Y, (cell.y - 0.5) * TILE)


func cell_water_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - 0.5) * TILE, 0.0, (cell.y - 0.5) * TILE)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE + 0.5), roundi(p.z / TILE + 0.5))


func _raft_center() -> Vector3:
	var c := Vector2.ZERO
	if not raft.is_empty():
		var min_c := Vector2i(9999, 9999)
		var max_c := Vector2i(-9999, -9999)
		for cell in raft.keys():
			min_c.x = mini(min_c.x, cell.x)
			min_c.y = mini(min_c.y, cell.y)
			max_c.x = maxi(max_c.x, cell.x)
			max_c.y = maxi(max_c.y, cell.y)
		c = Vector2((float(min_c.x + max_c.x) * 0.5 - 0.5) * TILE, (float(min_c.y + max_c.y) * 0.5 - 0.5) * TILE)
	return Vector3(c.x, 0.0, c.y)


func _raft_half() -> Vector2:
	if raft.is_empty():
		return Vector2(2.0, 2.0)
	var min_c := Vector2i(9999, 9999)
	var max_c := Vector2i(-9999, -9999)
	for cell in raft.keys():
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
	return Vector2(float(max_c.x - min_c.x + 1) * TILE * 0.5, float(max_c.y - min_c.y + 1) * TILE * 0.5)


func _update_water_bounds() -> void:
	if water_mat == null:
		return
	var c := _raft_center()
	var h := _raft_half()
	water_mat.set_shader_parameter("raft_center", Vector3(c.x, 0.0, c.z))
	water_mat.set_shader_parameter("raft_half", h)


func can_place(type: String, cell: Vector2i) -> bool:
	if not is_playing() or not COSTS.has(type):
		return false
	if type == "expand":
		if raft.has(cell) or stations.has(cell):
			return false
		if absi(cell.x) > 12 or absi(cell.y) > 12:
			return false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if raft.has(cell + d):
				return true
		return false
	if not raft.has(cell) or stations.has(cell):
		return false
	var p := cell_center(cell)
	if player != null:
		var pp := player.global_position
		if absf(pp.x - p.x) < 0.95 and absf(pp.z - p.z) < 0.95:
			return false
	return true


func build(type: String, cell: Vector2i) -> bool:
	if not can_place(type, cell):
		_toast("这里放不下 · 扩建需贴着木筏，设施需放在空甲板", CORAL_C)
		_play("error")
		return false
	if not _pay(COSTS[type]):
		_toast("材料不够：%s 需要 %s" % [BUILD_NAMES[type], _cost_text(type)], CORAL_C)
		_play("error")
		return false
	if type == "expand":
		var before := raft.size()
		_add_tile(cell, true)
		_update_water_bounds()
		_toast("木筏扩建 %d / %d 格（-2 木板）" % [raft.size(), WIN_TILES], TEAL)
		_play("build")
		_add_shake(0.3)
		if before < WIN_TILES and raft.size() >= WIN_TILES:
			_win("木筏扩到了 %d 格，浮木湾有了新的港湾。" % WIN_TILES)
		return true
	var station := RaftStation.new()
	station.setup(type, cell, self)
	station_root.add_child(station)
	stations[cell] = station
	_toast("%s 造好了 · %s" % [BUILD_NAMES[type], _cost_text(type)], GREEN)
	_play("build")
	_add_shake(0.35)
	_splash(cell_water_center(cell), 0.8)
	return true


func begin_place(type: String) -> void:
	if not is_playing() or not COSTS.has(type):
		return
	placement_mode = true
	placement_type = type
	ghost.visible = true
	var mesh: Mesh
	if type == "expand":
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.98, 1.98)
		mesh = plane
	else:
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 1.0, 1.2)
		mesh = box
	ghost.mesh = mesh
	update_ghost(Vector2i(9999, 9999))
	_toast("放置 %s · 左键放下 · 右键/ESC 取消" % BUILD_NAMES[type], TEAL)


func cancel_placement() -> void:
	placement_mode = false
	placement_type = ""
	hover_cell = Vector2i(9999, 9999)
	if ghost != null:
		ghost.visible = false


func update_ghost(cell: Vector2i) -> void:
	hover_cell = cell
	if not placement_mode or ghost == null:
		return
	var valid := can_place(placement_type, cell)
	ghost.visible = cell.x < 9000
	if not ghost.visible:
		return
	var c := cell_center(cell)
	if placement_type == "expand":
		ghost.position = Vector3(c.x, DECK_Y + 0.02, c.z)
	else:
		ghost.position = Vector3(c.x, DECK_Y + 0.55, c.z)
	ghost_mat.albedo_color = Color(0.55, 1.0, 0.82, 0.78) if valid else Color(1.0, 0.38, 0.32, 0.70)


func try_place(cell: Vector2i) -> bool:
	if not placement_mode:
		return false
	var type := placement_type
	var built := build(type, cell)
	if built:
		if type == "expand":
			if _can_pay(COSTS[type]):
				if ghost != null:
					ghost.visible = false
				placement_mode = false
				placement_type = ""
			else:
				cancel_placement()
		else:
			cancel_placement()
	return built


func _can_pay(cost: Dictionary) -> bool:
	for res in cost:
		if total_resource(res) < int(cost[res]):
			return false
	return true


func _pay(cost: Dictionary) -> bool:
	if not _can_pay(cost):
		return false
	for res in cost:
		var need := int(cost[res])
		var take: int = mini(inventory[res], need)
		inventory[res] -= take
		need -= take
		if need > 0:
			_withdraw_from_crates(res, need)
	return true


func _cost_text(type: String) -> String:
	var parts: Array[String] = []
	for res in COSTS[type]:
		parts.append("%d %s" % [COSTS[type][res], "木板" if res == "planks" else "木材"])
	return " + ".join(parts)


func get_build_entries() -> Array:
	var out: Array = []
	for type in ["expand", "crate", "purifier", "grill"]:
		var icon_kind: String = type
		if type == "crate":
			icon_kind = "storage"
		out.append({
			"type": type,
			"name": BUILD_NAMES[type],
			"cost": _cost_text(type),
			"icon": icon_kind,
		})
	return out


# ── 资源 / 箱子 / 生存 ────────────────────────────────────────────────────
func add_resource(res: String, amount: int, silent := false) -> void:
	if amount <= 0 or not inventory.has(res):
		return
	inventory[res] += amount
	if not silent:
		_play("sip")


func total_resource(res: String) -> int:
	var n: int = inventory.get(res, 0)
	if res == "wood" or res == "planks":
		for st in stations.values():
			if is_instance_valid(st) and st.kind == "crate":
				n += int(st.stored[res])
	return n


func _withdraw_from_crates(res: String, amount: int) -> int:
	var left := amount
	for st in stations.values():
		if left <= 0:
			break
		if is_instance_valid(st) and st.kind == "crate":
			left -= st.withdraw(res, left)
	return amount - left


func _nearest_crate() -> RaftStation:
	var best: RaftStation = null
	var best_d := 1.0e20
	if player == null:
		return null
	for st in stations.values():
		if not is_instance_valid(st) or st.kind != "crate":
			continue
		var d: float = player.global_position.distance_to(st.global_position)
		if d < best_d:
			best_d = d
			best = st
	return best


func auto_store(silent := false) -> int:
	var crate := _nearest_crate()
	if crate == null:
		return 0
	var moved := 0
	var limits := {"wood": 22, "planks": 12}
	for res in limits:
		var extra: int = int(inventory[res]) - int(limits[res])
		if extra > 0:
			inventory[res] -= extra
			crate.deposit(res, extra)
			moved += extra
	if moved > 0 and not silent:
		_toast("木箱自动存入 %d 件材料 · 建造时会自动取出" % moved, TEAL)
	return moved


func consume_wood_any(n: int) -> bool:
	if total_resource("wood") < n:
		return false
	var take: int = mini(inventory["wood"], n)
	inventory["wood"] -= take
	var left := n - take
	if left > 0:
		_withdraw_from_crates("wood", left)
	return true


func consume_fish(n: int) -> bool:
	if int(inventory["fish"]) < n:
		return false
	inventory["fish"] -= n
	return true


func drink_water() -> bool:
	if not is_playing():
		return false
	if int(inventory["water"]) <= 0:
		_toast("没有净水了 · 造一台净水器，或先省着点", CORAL_C)
		_play("error")
		return false
	inventory["water"] -= 1
	thirst = minf(100.0, thirst + 38.0)
	_toast("喝下净水 · 水分 +38", BLUE)
	_float("+38 水分", BLUE, player.global_position + Vector3(0, 1.7, 0))
	_play("gulp")
	return true


func eat_cooked() -> bool:
	if not is_playing():
		return false
	if int(inventory["cooked"]) <= 0:
		if int(inventory["fish"]) > 0:
			_toast("只有生鱼 · 按 3 生吃，或放到烤鱼架上", GOLD)
		else:
			_toast("背包里没有鱼了 · 钩几条银鱼吧", CORAL_C)
		_play("error")
		return false
	inventory["cooked"] -= 1
	hunger = minf(100.0, hunger + 46.0)
	_toast("吃掉烤银鳕鱼 · 食物 +46", GOLD)
	_float("+46 食物", GOLD, player.global_position + Vector3(0, 1.7, 0))
	_play("chomp")
	return true


func eat_raw() -> bool:
	if not is_playing():
		return false
	if int(inventory["fish"]) <= 0:
		_toast("没有生鱼 · 按住空格自动锁定漂浮物", CORAL_C)
		_play("error")
		return false
	inventory["fish"] -= 1
	hunger = minf(100.0, hunger + 18.0)
	thirst = maxf(0.0, thirst - 2.0)
	_toast("生吃银鱼 · 食物 +18（烤过更好）", GOLD)
	_float("+18 食物", GOLD, player.global_position + Vector3(0, 1.7, 0))
	_play("chomp")
	return true


func update_stamina(delta: float, want_sprint: bool) -> bool:
	if not is_playing():
		return false
	if want_sprint and stamina > 0.5:
		stamina = maxf(0.0, stamina - 23.0 * delta)
		return stamina > 0.5
	stamina = minf(100.0, stamina + 13.0 * delta)
	return false


func _update_auto_collect() -> void:
	if player == null:
		return
	for st in stations.values():
		if not is_instance_valid(st) or st.kind == "crate":
			continue
		if player.global_position.distance_to(st.global_position) > 3.0:
			continue
		var out: Dictionary = st.take_output()
		if out.is_empty():
			continue
		for res in out:
			add_resource(res, int(out[res]), true)
		var bits: Array[String] = []
		if out.has("water"):
			bits.append("+%d 净水" % out["water"])
		if out.has("cooked"):
			bits.append("+%d 烤鱼" % out["cooked"])
		var txt := " · ".join(bits)
		_toast("%s 自动收取 %s" % [BUILD_NAMES[st.kind], txt], GREEN)
		_float(txt, GREEN, st.global_position + Vector3(0, 1.2, 0))
		_play("sip")


func on_station_produced(st: RaftStation, res: String) -> void:
	if player == null or st == null:
		return
	if player.global_position.distance_to(st.global_position) < 4.5:
		_play("sip")
		_float("+" + ("1 净水" if res == "water" else "1 烤鱼"), BLUE if res == "water" else GOLD,
			st.global_position + Vector3(0.0, 1.0, 0.0))


func try_interact() -> void:
	if not is_playing():
		return
	var st := nearest_station(3.0)
	if st == null:
		_toast("靠近木箱 / 净水器 / 烤鱼架再按 F", GOLD)
		return
	if st.kind == "crate":
		var moved := auto_store(true)
		if moved == 0 and int(inventory["wood"]) < 5:
			var got := _withdraw_from_crates("wood", 5)
			if got > 0:
				inventory["wood"] += got
				_toast("从木箱取出 %d 木材" % got, TEAL)
				_play("build")
				return
		_toast("木箱里有 %d 木材 / %d 木板 · 自动存入/取出已开启" % [st.stored["wood"], st.stored["planks"]], TEAL)
		return
	var out: Dictionary = st.take_output()
	if out.is_empty():
		_toast("还没有产出 · %s" % st.status_text(), GOLD)
		return
	for res in out:
		add_resource(res, int(out[res]), true)
	_toast("收取了设施产出", GREEN)
	_play("sip")


func nearest_station(max_dist: float) -> RaftStation:
	var best: RaftStation = null
	var best_d := max_dist
	if player == null:
		return null
	for st in stations.values():
		if not is_instance_valid(st):
			continue
		var d: float = player.global_position.distance_to(st.global_position)
		if d <= best_d:
			best_d = d
			best = st
	return best


# ── 漂浮物 ────────────────────────────────────────────────────────────────
func _spawn_initial_loot() -> void:
	spawn_loot("barrel", Vector3(5.6, 0.0, -2.4))
	spawn_loot("crate", Vector3(-4.6, 0.0, 4.6))
	spawn_loot("fish", Vector3(2.2, 0.0, -5.5))


func spawn_loot(kind: String, pos: Vector3) -> FloatLoot:
	var node := FloatLoot.new()
	node.setup(kind, roll_loot(kind), self)
	node.position = Vector3(pos.x, 0.0, pos.z)
	loot_root.add_child(node)
	loot.append(node)
	return node


func roll_loot(kind: String) -> Dictionary:
	var out := {"kind": kind, "wood": 0, "planks": 0, "fish": 0}
	match kind:
		"crate":
			out["wood"] = rng.randi_range(2, 4)
			out["planks"] = rng.randi_range(1, 2)
		"fish":
			out["fish"] = 1
		_:
			out["wood"] = rng.randi_range(2, 4)
			if rng.randf() < 0.22:
				out["planks"] = 1
	return out


func roll_kind() -> String:
	var r := rng.randf()
	if r < 0.50:
		return "barrel"
	if r < 0.80:
		return "crate"
	return "fish"


func _update_spawns(delta: float) -> void:
	if not spawn_enabled or state != STATE_PLAYING:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = SPAWN_EVERY
	_clean_loot()
	if loot.size() >= MAX_LOOT:
		return
	var a := rng.randf() * TAU
	var base := Vector2(_raft_center().x, _raft_center().z)
	var half := _raft_half()
	var radius := maxf(half.x, half.y) + rng.randf_range(3.5, 9.0)
	var pos := base + Vector2(cos(a), sin(a)) * radius
	spawn_loot(roll_kind(), Vector3(pos.x, 0.0, pos.y))


func _update_loot(delta: float) -> void:
	if loot.is_empty():
		return
	var center := _raft_center()
	var half := _raft_half()
	for i in range(loot.size() - 1, -1, -1):
		var l: FloatLoot = loot[i]
		if not is_instance_valid(l) or not l.alive:
			loot.remove_at(i)
			continue
		if l.age > l.lifetime:
			_remove_loot(l)
			continue
		var rel := Vector2(l.global_position.x - center.x, l.global_position.z - center.z)
		if absf(rel.x) < half.x + 0.9 and absf(rel.y) < half.y + 0.9:
			var push := rel.normalized() if rel.length() > 0.01 else Vector2.RIGHT
			l.global_position.x += push.x * delta * 2.0
			l.global_position.z += push.y * delta * 2.0
			l.drift = Vector3(push.x, 0.0, push.y) * 0.30
		if l.global_position.distance_to(Vector3(center.x, 0.0, center.z)) > 30.0:
			_remove_loot(l)


func _remove_loot(l: FloatLoot) -> void:
	if l == null:
		return
	if locked_loot == l:
		locked_loot = null
	if hook_target == l:
		hook_target = null
	l.alive = false
	loot.erase(l)
	l.queue_free()


func _clean_loot() -> void:
	for i in range(loot.size() - 1, -1, -1):
		if not is_instance_valid(loot[i]) or not loot[i].alive:
			loot.remove_at(i)


func clear_loot() -> void:
	for l in loot.duplicate():
		if is_instance_valid(l):
			_remove_loot(l)
	loot.clear()
	locked_loot = null
	hook_target = null


# ── 钩子 ──────────────────────────────────────────────────────────────────
func begin_charge() -> void:
	if not is_playing() or placement_mode:
		return
	if cooldown > 0.0 or hook_state == "flying" or hook_state == "returning":
		return
	hook_state = "charging"
	charge = 0.0
	_was_lock = null
	_update_lock()
	if locked_loot != null:
		_play("lock")


func release_cast() -> void:
	if hook_state != "charging":
		return
	_update_lock()
	if locked_loot == null:
		hook_state = "idle"
		cooldown = 0.30
		_toast("射程内没有漂浮物 · 等海面漂近一点", GOLD)
		_play("error")
		return
	hook_target = locked_loot
	hook_pos = _rod_tip()
	var dir := (hook_target.aim_pos() - hook_pos)
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	hook_vel = dir.normalized() * (17.0 + charge * 11.0)
	hook_state = "flying"
	hook_flight_time = 0.0
	_toast("抛钩 · 追踪%s" % hook_target.label_cn, TEAL)
	_play("cast")
	_add_shake(0.12)


func is_charging() -> bool:
	return hook_state == "charging"


func _update_lock() -> void:
	if not is_playing():
		locked_loot = null
		return
	var best: FloatLoot = null
	var best_d := LOCK_RANGE
	for l in loot:
		if not is_instance_valid(l) or not l.alive:
			continue
		var d: float = player.global_position.distance_to(l.global_position)
		if d <= best_d:
			best_d = d
			best = l
	if best != _was_lock:
		_was_lock = best
		if best != null:
			_play("lock")
	locked_loot = best


func _rod_tip() -> Vector3:
	if player == null:
		return Vector3.ZERO
	return player.global_position + Vector3(0.0, 1.25, 0.0)


func _update_flight(delta: float) -> void:
	var step := minf(delta, 0.05)
	hook_flight_time += step
	if hook_target == null or not is_instance_valid(hook_target) or not hook_target.alive:
		hook_target = null
		var alt := _nearest_loot_to(hook_pos, 7.0)
		if alt == null:
			hook_state = "returning"
			return
		hook_target = alt
	var target_pos := hook_target.aim_pos()
	var to := target_pos - hook_pos
	var dist := to.length()
	if dist < 0.75:
		_catch(hook_target)
		return
	var speed := 17.0 + charge * 11.0
	var desired := to / dist * speed
	hook_vel = hook_vel.lerp(desired, clampf(step * 9.0, 0.0, 1.0))
	hook_pos += hook_vel * step
	_hook_ripple_t -= step
	if _hook_ripple_t <= 0.0:
		_hook_ripple_t = 0.13
		_splash(Vector3(hook_pos.x, 0.0, hook_pos.z), 0.28)
	if hook_flight_time > 3.2 or hook_pos.distance_to(_rod_tip()) > 30.0:
		hook_state = "returning"
		hook_target = null


func _catch(l: FloatLoot) -> void:
	if l == null or not is_instance_valid(l) or not l.alive:
		hook_state = "returning"
		return
	var payload := l.payload()
	last_catch = payload
	var wood := int(payload["wood"])
	var planks := int(payload["planks"])
	var fish := int(payload["fish"])
	add_resource("wood", wood, true)
	add_resource("planks", planks, true)
	add_resource("fish", fish, true)
	var bits: Array[String] = []
	if wood > 0:
		bits.append("+%d 木材" % wood)
	if planks > 0:
		bits.append("+%d 木板" % planks)
	if fish > 0:
		bits.append("+%d 银鱼" % fish)
	var txt := " · ".join(bits)
	_float(txt, TEAL, l.aim_pos() + Vector3(0.0, 0.35, 0.0))
	_toast("钩中%s：%s" % [l.label_cn, txt], TEAL)
	_splash(l.global_position, 1.35)
	_play("catch")
	_add_shake(0.32)
	_fly_to_player(l.kind, l.aim_pos())
	hook_pos = l.aim_pos()
	hook_target = null
	locked_loot = null
	hook_state = "returning"
	_remove_loot(l)
	auto_store()


func _fly_to_player(kind: String, from: Vector3) -> void:
	var tex: Texture2D = Art.barrel()
	if kind == "crate":
		tex = Art.crate()
	elif kind == "fish":
		tex = Art.fish()
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = 0.034
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.render_priority = 6
	s.position = from
	fx_root.add_child(s)
	var dest := player.global_position + Vector3(0.0, 1.0, 0.0)
	var tw := create_tween()
	tw.tween_property(s, "position", dest, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.45, 0.34)
	tw.chain().tween_callback(s.queue_free)


func _update_return(delta: float) -> void:
	var tip := _rod_tip()
	var to := tip - hook_pos
	var step := 30.0 * minf(delta, 0.05)
	if to.length() <= step + 0.15:
		hook_pos = tip
		hook_state = "idle"
		cooldown = HOOK_COOLDOWN
		charge = 0.0
	else:
		hook_pos += to.normalized() * step


func _nearest_loot_to(pos: Vector3, max_dist: float) -> FloatLoot:
	var best: FloatLoot = null
	var best_d := max_dist
	for l in loot:
		if not is_instance_valid(l) or not l.alive:
			continue
		var d: float = pos.distance_to(l.global_position)
		if d <= best_d:
			best_d = d
			best = l
	return best


# ── 视觉工具 / 相机 ───────────────────────────────────────────────────────
func _update_visual_tools(delta: float) -> void:
	var show_marker := false
	if locked_loot != null and is_instance_valid(locked_loot) and locked_loot.alive \
			and (hook_state == "charging" or hook_state == "flying"):
		show_marker = true
		marker.position = Vector3(locked_loot.global_position.x, 0.045, locked_loot.global_position.z)
		marker.rotation.y += delta * 1.8
		var s := 1.0 + 0.10 * sin(world_time * 6.0)
		marker.scale = Vector3(s, 1.0, s)
	if marker != null:
		marker.visible = show_marker

	var show_rope := hook_state == "flying" or hook_state == "returning"
	if rope != null:
		rope.visible = show_rope
	if hook_sprite != null:
		hook_sprite.visible = show_rope
		hook_sprite.position = hook_pos + Vector3(0.0, 0.20 + sin(world_time * 8.0) * 0.04, 0.0)
	if hook_bead != null:
		hook_bead.visible = show_rope
		hook_bead.position = hook_pos
	if show_rope:
		var tip := _rod_tip()
		var d := hook_pos - tip
		var mid := tip + d * 0.5
		rope.position = mid
		if d.length() > 0.05:
			var up := Vector3.UP
			if absf(d.normalized().y) > 0.96:
				up = Vector3.BACK
			rope.look_at(mid + d, up)
		rope.scale = Vector3(1.0, 1.0, maxf(d.length(), 0.05))

	if charge_ring != null:
		var charging := hook_state == "charging"
		charge_ring.visible = charging
		if charging:
			charge_ring.position = player.global_position + Vector3(0.0, 0.025, 0.0)
			charge_ring.rotation.y += delta * 2.4
			var cs := 0.85 + charge * 0.75
			charge_ring.scale = Vector3(cs, 1.0, cs)
			(charge_ring.material_override as StandardMaterial3D).albedo_color = GOLD.lerp(CORAL_C, charge)


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var focus := Vector3(0.0, DECK_Y, 0.0)
	if player != null:
		focus = player.global_position + Vector3(0.0, 0.35, 0.0)
	cam_focus = cam_focus.lerp(focus, 1.0 - exp(-6.0 * delta))
	var off := Vector3(
		cos(cam_yaw) * cos(cam_pitch),
		sin(cam_pitch),
		sin(cam_yaw) * cos(cam_pitch)) * 22.0
	camera.position = cam_focus + off
	var look := cam_focus + Vector3(0.0, 0.12, 0.0)
	if shake > 0.001:
		look += Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), 0.0) * shake * 0.16
	camera.look_at(look, Vector3.UP)
	camera.size = cam_size
	shake = maxf(0.0, shake - delta * 2.2)


func orbit(amount: float) -> void:
	cam_yaw += amount


func zoom_by(steps: float) -> void:
	cam_size = clampf(cam_size + steps * 1.1, 8.5, 20.0)


func camera_relative(input: Vector2) -> Vector3:
	var forward := Vector3(-cos(cam_yaw), 0.0, -sin(cam_yaw))
	var right := Vector3(sin(cam_yaw), 0.0, -cos(cam_yaw))
	return right * input.x + forward * (-input.y)


func world_dir_to_screen(dir: Vector3) -> Vector2:
	var forward := Vector3(-cos(cam_yaw), 0.0, -sin(cam_yaw))
	var right := Vector3(sin(cam_yaw), 0.0, -cos(cam_yaw))
	return Vector2(dir.dot(right), -dir.dot(forward))


func cell_from_viewport(vp: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(9999, 9999)
	var origin := camera.project_ray_origin(vp)
	var dir := camera.project_ray_normal(vp)
	if absf(dir.y) < 0.0001:
		return Vector2i(9999, 9999)
	var t := (DECK_Y - origin.y) / dir.y
	if t < 0.0 or t > 120.0:
		return Vector2i(9999, 9999)
	return world_to_cell(origin + dir * t)


func world_to_viewport(pos: Vector3) -> Vector2:
	if camera == null:
		return Vector2(-1000, -1000)
	return camera.unproject_position(pos)


func move_player(pos: Vector3, motion: Vector3) -> Vector3:
	var next := pos
	var cand := Vector3(pos.x + motion.x, pos.y, pos.z)
	if can_stand(cand):
		next.x = cand.x
	cand = Vector3(next.x, pos.y, next.z + motion.z)
	if can_stand(cand):
		next.z = cand.z
	return next


func can_stand(pos: Vector3) -> bool:
	for cell in raft.keys():
		if stations.has(cell):
			continue
		var c := cell_center(cell)
		if absf(pos.x - c.x) < 0.72 and absf(pos.z - c.z) < 0.72:
			return true
	return false


func _add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


# ── 反馈：水花 / 飘字 / 音效 ──────────────────────────────────────────────
func _splash(pos: Vector3, strength: float) -> void:
	if water_mat != null and pos.y < 0.6:
		_ripple_i = (_ripple_i + 1) % 8
		_ripples[_ripple_i] = Vector4(pos.x, pos.z, world_time, clampf(strength, 0.2, 1.5))
		water_mat.set_shader_parameter("ripples", _ripples)
	var n := int(clampf(strength * 4.0, 2.0, 7.0))
	for i in n:
		var s := Sprite3D.new()
		s.texture = Art.droplet()
		s.pixel_size = 0.04
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.position = pos + Vector3(rng.randf_range(-0.2, 0.2), 0.15, rng.randf_range(-0.2, 0.2))
		s.modulate = Color(0.9, 1.0, 0.98, 0.95)
		fx_root.add_child(s)
		_fx.append({
			"node": s,
			"vel": Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(1.8, 3.3), rng.randf_range(-1.4, 1.4)),
			"life": 0.55,
			"max": 0.55,
		})
	if strength > 0.8:
		_play("splash")


func _update_fx(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		var f: Dictionary = _fx[i]
		var node: Sprite3D = f["node"]
		if not is_instance_valid(node):
			_fx.remove_at(i)
			continue
		f["life"] = float(f["life"]) - delta
		var vel: Vector3 = f["vel"]
		vel.y -= 8.5 * delta
		f["vel"] = vel
		node.position += vel * delta
		node.modulate.a = clampf(float(f["life"]) / float(f["max"]), 0.0, 1.0)
		if float(f["life"]) <= 0.0:
			node.queue_free()
			_fx.remove_at(i)


func _float(text: String, color: Color, pos: Vector3) -> void:
	float_text.emit(text, color, pos)


func _toast(text: String, color := TEAL) -> void:
	toast.emit(text, color)


func toast_msg(text: String, color := TEAL) -> void:
	_toast(text, color)


func _build_audio() -> void:
	_sfx["lock"] = _tone(1350.0, 0.06, 0.02, 200.0, 2.0)
	_sfx["cast"] = _tone(540.0, 0.16, 0.55, -380.0, 1.4)
	_sfx["splash"] = _tone(220.0, 0.24, 0.85, -120.0, 1.6)
	_sfx["catch"] = _chime()
	_sfx["build"] = _tone(130.0, 0.20, 0.35, -70.0, 1.8)
	_sfx["error"] = _tone(190.0, 0.16, 0.10, -60.0, 2.0)
	_sfx["gulp"] = _tone(330.0, 0.20, 0.30, -180.0, 1.6)
	_sfx["chomp"] = _tone(260.0, 0.13, 0.75, 90.0, 2.2)
	_sfx["sip"] = _tone(700.0, 0.10, 0.05, 300.0, 2.0)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_sfx_players.append(p)


func _play(name: String) -> void:
	if not _sfx.has(name) or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx_players.size()
	p.stream = _sfx[name]
	p.play()


func _tone(freq: float, dur: float, noise: float, slide: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var env := pow(maxf(0.0, 1.0 - t / dur), decay)
		phase += TAU * (freq + slide * t) / float(rate)
		var s := sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		data.encode_s16(i * 2, int(clampf(s * env * 0.45, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _chime() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.26
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := pow(maxf(0.0, 1.0 - t / dur), 1.6)
		var f := 680.0 if t < 0.11 else 1020.0
		var s := sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.2
		data.encode_s16(i * 2, int(clampf(s * env * 0.5, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ── 日夜 / 胜负 / 外部查询 ────────────────────────────────────────────────
func _update_daylight() -> void:
	if water_mat == null:
		return
	var phase := day_time / DAY_LENGTH
	var night := smoothstep(0.74, 0.94, phase)
	var dawn := 1.0 - smoothstep(0.0, 0.18, phase)
	var light := 1.0 - night * 0.42 - dawn * 0.10
	water_mat.set_shader_parameter("light_level", light)
	water_mat.set_shader_parameter("night_mix", night)
	if env != null:
		var sky := Color("#8fd4c8")
		sky = sky.lerp(Color("#e2a56b"), dawn * 0.45)
		sky = sky.lerp(Color("#172a3a"), night * 0.86)
		env.background_color = sky
	if lamp_glow_mat != null:
		lamp_glow_mat.albedo_color.a = 0.30 + night * 0.75 + dawn * 0.12


func debug_set_day_phase(phase: float) -> void:
	day_time = clampf(phase, 0.0, 0.999) * DAY_LENGTH
	_update_daylight()


func _win(reason: String) -> void:
	if state != STATE_PLAYING:
		return
	state = STATE_WON
	end_reason = reason
	hook_state = "idle"
	locked_loot = null
	hook_target = null
	cancel_placement()
	_toast("达成目标 · %s" % reason, GREEN)
	_play("catch")


func _lose(reason: String) -> void:
	if state != STATE_PLAYING:
		return
	state = STATE_LOST
	end_reason = reason
	hook_state = "idle"
	locked_loot = null
	hook_target = null
	cancel_placement()
	_toast("本次结束 · %s" % reason, CORAL_C)
	_play("error")


func is_playing() -> bool:
	return state == STATE_PLAYING


func input_active() -> bool:
	return state == STATE_PLAYING


func get_prompt() -> String:
	if state != STATE_PLAYING:
		return ""
	if placement_mode:
		return "左键 放下 %s · 右键 / ESC 取消" % BUILD_NAMES[placement_type]
	match hook_state:
		"charging":
			if locked_loot != null:
				var d: float = player.global_position.distance_to(locked_loot.global_position)
				return "松开抛钩 · 已锁定%s · %.1fm · 蓄力 %d%%" % [locked_loot.label_cn, d, int(charge * 100.0)]
			return "蓄力中 · 射程内没有漂浮物"
		"flying":
			return "钩子追踪中…"
		"returning":
			return "收线中…"
	var st := nearest_station(3.0)
	if st != null:
		return st.status_text() + " · F 收取/整理"
	if cooldown > 0.0:
		return "收线冷却 %.1fs" % cooldown
	return "按住 空格 / 左键 自动锁定最近漂浮物 · 松手抛钩"


func get_ui_snapshot() -> Dictionary:
	var storage_wood := 0
	var storage_planks := 0
	for st in stations.values():
		if is_instance_valid(st) and st.kind == "crate":
			storage_wood += int(st.stored["wood"])
			storage_planks += int(st.stored["planks"])
	var lock_visible := locked_loot != null and is_instance_valid(locked_loot) and locked_loot.alive \
		and (hook_state == "charging" or hook_state == "flying")
	var target_name := ""
	var target_dist := 0.0
	if lock_visible:
		target_name = locked_loot.label_cn
		target_dist = player.global_position.distance_to(locked_loot.global_position)
	return {
		"state": state,
		"day": day,
		"day_fraction": day_time / DAY_LENGTH,
		"tiles": raft.size(),
		"target_tiles": WIN_TILES,
		"win_day": WIN_DAY,
		"thirst": thirst,
		"hunger": hunger,
		"stamina": stamina,
		"inv": inventory.duplicate(),
		"storage_wood": storage_wood,
		"storage_planks": storage_planks,
		"prompt": get_prompt(),
		"hook_state": hook_state,
		"charge": charge,
		"cooldown": cooldown,
		"lock_visible": lock_visible,
		"lock_world": locked_loot.aim_pos() if lock_visible else Vector3.ZERO,
		"player_world": player.global_position if player != null else Vector3.ZERO,
		"hook_visible": hook_state == "flying" or hook_state == "returning",
		"hook_world": hook_pos,
		"target_name": target_name,
		"target_dist": target_dist,
		"place_type": placement_type,
		"end_reason": end_reason,
	}


# ── 验收辅助（smoke tool 使用真实逻辑路径） ──────────────────────────────
func debug_spawn_loot(kind: String, pos: Vector3) -> FloatLoot:
	return spawn_loot(kind, pos)


func debug_tick_stations(total: float) -> void:
	var left := total
	while left > 0.0 and state == STATE_PLAYING:
		var dt := minf(0.5, left)
		for st in stations.values():
			if is_instance_valid(st):
				st.tick(dt)
		left -= dt


func debug_collect_stations() -> void:
	_update_auto_collect()


func debug_tick_survival(total: float) -> void:
	var left := total
	while left > 0.0 and state == STATE_PLAYING:
		var dt := minf(0.25, left)
		thirst = maxf(0.0, thirst - THIRST_RATE * dt)
		hunger = maxf(0.0, hunger - HUNGER_RATE * dt)
		if thirst <= 0.0:
			_lose("你渴倒了。净水器应该早点造出来。")
		elif hunger <= 0.0:
			_lose("你饿得举不起钓竿了。")
		left -= dt


func _intro() -> void:
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or not intro_enabled:
		return
	_toast("按住 空格 / 左键 · 自动锁定最近的漂浮物", TEAL)
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree() or not intro_enabled:
		return
	_toast("松手抛钩 · 钩子会追着目标跑", TEAL)
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree() or not intro_enabled:
		return
	_toast("按 B 建造：先净水器，再扩木筏。目标 12 格 / 第 4 天", GOLD)
