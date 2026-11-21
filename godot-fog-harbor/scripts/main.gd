extends Node2D
## 《雾港余烬》主控：基地 ↔ 行动 ↔ 结算的状态机；接 UI、地图、玩家、敌人与规则。
## 单局 6 分钟；撤离成功入库，阵亡/超时丢失随身物资，仓库与升级持久化。

const GameStateScript = preload("res://scripts/game_state.gd")
const RaidRulesScript = preload("res://scripts/raid_rules.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const HarborMapScript = preload("res://scripts/harbor_map.gd")
const FxScript = preload("res://scripts/fx.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const EnemyBulletScript = preload("res://scripts/enemy_bullet.gd")
const ChestScript = preload("res://scripts/loot_chest.gd")
const ExtractionScript = preload("res://scripts/extraction_zone.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const HudScript = preload("res://scripts/hud.gd")
const BackpackScript = preload("res://scripts/backpack_panel.gd")
const BaseScript = preload("res://scripts/base_screen.gd")
const ResultScript = preload("res://scripts/result_screen.gd")

const SEARCH_DISTANCE := 64.0

var state: FogGameState
var mode := "boot"
var raid_active := false

var ui_layer: CanvasLayer
var fog_layer: CanvasLayer
var fog_rect: ColorRect
var base_screen: FogBaseScreen
var hud: FogHud
var backpack: FogBackpackPanel
var result_screen: FogResultScreen

var world: Node2D
var map: HarborMap
var fx: FogFx
var player: FogPlayer
var camera: Camera2D
var chests: Array = []
var enemies: Array = []
var extraction: FogExtractionZone
var rules: FogRaidRules
var inventory: FogInventory

var chests_opened := 0
var kills := 0
var demo_god := false
var rules_frozen := false
var demo_manual_interaction := false

var _shake := 0.0
var _hud_accum := 0.0
var _cull_accum := 0.0
var _nearest_chest: FogChest = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	state = GameStateScript.new()
	state.load_save()
	_build_ui_layers()
	show_base()


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false


func _build_ui_layers() -> void:
	fog_layer = CanvasLayer.new()
	fog_layer.name = "FogLayer"
	fog_layer.layer = 3
	fog_layer.visible = false
	add_child(fog_layer)
	fog_rect = ColorRect.new()
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_rect.position = Vector2.ZERO
	fog_rect.size = Vector2(1280, 720)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/fog_overlay.gdshader")
	material.set_shader_parameter("fog_tex", FogArt.fog_noise())
	fog_rect.material = material
	fog_layer.add_child(fog_rect)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 10
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	hud = HudScript.new()
	hud.name = "Hud"
	hud.visible = false
	ui_layer.add_child(hud)

	backpack = BackpackScript.new()
	backpack.name = "Backpack"
	backpack.visible = false
	ui_layer.add_child(backpack)
	backpack.use_requested.connect(_on_backpack_use)
	backpack.drop_requested.connect(_on_backpack_drop)
	backpack.closed.connect(_on_backpack_closed)


func show_base() -> void:
	if get_tree() != null:
		get_tree().paused = false
	raid_active = false
	_clear_world()
	_clear_result()
	if hud != null:
		hud.visible = false
	if backpack != null:
		backpack.visible = false
	fog_layer.visible = false
	if base_screen != null:
		base_screen.queue_free()
	base_screen = BaseScript.new()
	base_screen.name = "BaseScreen"
	ui_layer.add_child(base_screen)
	base_screen.configure(state)
	base_screen.deploy_requested.connect(start_raid)
	base_screen.upgrade_requested.connect(_on_upgrade_requested)
	base_screen.sell_requested.connect(_on_sell_requested)
	mode = "base"


func start_raid() -> void:
	if get_tree().paused:
		get_tree().paused = false
	_clear_world()
	_clear_result()
	if base_screen != null:
		base_screen.queue_free()
		base_screen = null
	raid_active = true
	demo_god = false
	rules_frozen = false
	demo_manual_interaction = false
	chests_opened = 0
	kills = 0
	_shake = 0.0
	rules = RaidRulesScript.new()
	inventory = InventoryScript.new(6, 4)
	inventory.add_item("medkit", state.starting_medkits())
	world = Node2D.new()
	world.name = "RaidWorld"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	map = HarborMapScript.new()
	map.visible = false
	world.add_child(map)
	# 静态地图预渲染成一张纹理：把 ~100 个 2D 绘制命令降为 1 个精灵绘制。
	var map_vp := SubViewport.new()
	map_vp.name = "MapPreRender"
	map_vp.size = Vector2i(int(HarborMap.WORLD_RECT.size.x), int(HarborMap.WORLD_RECT.size.y))
	map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	map_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	map_vp.transparent_bg = false
	world.add_child(map_vp)
	var visual_map := HarborMapScript.new()
	visual_map.build_collisions = false
	map_vp.add_child(visual_map)
	var map_sprite := Sprite2D.new()
	map_sprite.name = "MapSprite"
	map_sprite.texture = map_vp.get_texture()
	map_sprite.centered = false
	map_sprite.position = Vector2.ZERO
	map_sprite.z_index = -10
	world.add_child(map_sprite)
	_bake_map_texture(map_vp, map_sprite, map)
	fx = FxScript.new()
	world.add_child(fx)

	extraction = ExtractionScript.new()
	extraction.configure(HarborMap.EXTRACTION_RECT)
	world.add_child(extraction)
	extraction.set_status(false, 0.0, rules.time_left())

	for i in range(HarborMap.CHESTS.size()):
		var data: Dictionary = HarborMap.CHESTS[i]
		var chest := ChestScript.new()
		chest.configure(String(data["id"]), data["pos"], int(data["tier"]), i + 1)
		world.add_child(chest)
		chests.append(chest)

	player = PlayerScript.new()
	player.name = "Player"
	player.position = HarborMap.PLAYER_SPAWN
	player.weapon_damage = state.weapon_damage()
	world.add_child(player)
	player.fired.connect(_on_player_fired)
	player.died.connect(_on_player_died)
	player.hurt.connect(_on_player_hurt)
	player.notify.connect(_on_player_notify)
	player.dash_started.connect(_on_player_dash)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(HarborMap.WORLD_RECT.size.x)
	camera.limit_bottom = int(HarborMap.WORLD_RECT.size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.make_current()

	for spawn in HarborMap.ENEMY_SPAWNS:
		var enemy := EnemyScript.new()
		enemy.configure(String(spawn["type"]), spawn["pos"], spawn["patrol"], player, fx)
		world.add_child(enemy)
		enemy.shoot_requested.connect(_spawn_enemy_bullet)
		enemy.killed.connect(_on_enemy_killed)
		enemy.melee_hit.connect(_on_melee_hit)
		enemies.append(enemy)

	backpack.configure(inventory)
	backpack.visible = false
	hud.configure(player, rules, inventory, HarborMap.EXTRACTION_RECT.get_center())
	hud.chests_opened = 0
	hud.kills = 0
	hud.demo_crosshair = Vector2(-1, -1)
	hud.visible = true
	fog_layer.visible = true
	hud.toast("行动开始：搜箱、交火，活着撤离", FogUITheme.AMBER)
	hud.toast("撤离点：02:00 后 或 搜箱 2 次激活", FogUITheme.DIM)
	mode = "raid"
	_update_lighting()


func _process(delta: float) -> void:
	_update_shake(delta)
	if mode != "raid" or not raid_active or rules == null or get_tree().paused:
		return
	if player == null or not is_instance_valid(player):
		return
	_update_lighting()
	var in_zone := extraction != null and extraction.active and extraction.contains(player.global_position)
	if not rules_frozen:
		var events: Dictionary = rules.tick(delta, in_zone)
		extraction.set_status(rules.active, rules.progress_ratio(), rules.time_left())
		if bool(events.get("activated", false)):
			hud.toast("撤离点已激活：东南栈桥", FogUITheme.TEAL)
		if bool(events.get("timeout", false)):
			_finish_run(false, "雾潮吞没")
			return
		if bool(events.get("extracted", false)):
			_finish_run(true, "撤离成功")
			return
	else:
		extraction.set_status(rules.active, rules.progress_ratio(), rules.time_left())
	if not demo_manual_interaction:
		_update_interaction(delta, in_zone)
	_cull_accum += delta
	if _cull_accum >= 0.12:
		_cull_accum = 0.0
		_update_culling()
	_hud_accum += delta
	if _hud_accum >= 0.1:
		_hud_accum = 0.0
		hud.chests_opened = chests_opened
		hud.kills = kills
		hud.queue_redraw()


func _update_interaction(delta: float, in_zone: bool) -> void:
	var prompt := ""
	var ratio := -1.0
	var hint := ""
	_nearest_chest = _find_nearest_chest(SEARCH_DISTANCE)
	for chest in chests:
		var should_highlight: bool = chest == _nearest_chest
		if chest.highlight != should_highlight:
			chest.highlight = should_highlight
			chest.queue_redraw()
	if in_zone and rules.active:
		prompt = "撤离中 · 保持在圈内"
		ratio = rules.progress_ratio()
		hint = "还剩 %.1f 秒" % (RaidRulesScript.EXTRACT_HOLD * (1.0 - rules.progress_ratio()))
	elif _nearest_chest != null:
		if _nearest_chest.is_empty():
			prompt = "空补给箱"
			hint = "已经被搜空了"
			_nearest_chest.cancel_search()
		elif Input.is_physical_key_pressed(KEY_E):
			var result: Dictionary = _nearest_chest.search_tick(delta, inventory)
			if String(result.get("state", "")) == "searched":
				_handle_chest_result(_nearest_chest, result)
				prompt = "补给箱已搜索"
				hint = "背包 %d / %d 格" % [inventory.cells_used(), inventory.capacity_cells()]
			else:
				prompt = "正在搜索补给箱"
				ratio = float(result.get("ratio", 0.0))
				hint = "保持按住 E · 箱内 %d 件" % _nearest_chest.loot_count()
		else:
			_nearest_chest.cancel_search()
			prompt = "按住 E 搜索补给箱"
			hint = "箱内约 %d 件 · 背包 %d / %d 格" % [
				_nearest_chest.loot_count(), inventory.cells_used(), inventory.capacity_cells(),
			]
	hud.prompt_text = prompt
	hud.prompt_ratio = ratio
	hud.prompt_hint = hint
	hud.chests_opened = chests_opened
	hud.kills = kills


func _bake_map_texture(map_vp: SubViewport, map_sprite: Sprite2D, collision_map: HarborMap) -> void:
	## 预渲染只做一次；烘焙成独立 ImageTexture 后释放 SubViewport，
	## 避免每帧渲染 2400×1500 的地图纹理。
	for _i in range(3):
		await RenderingServer.frame_post_draw
	if not is_instance_valid(map_vp) or not is_instance_valid(map_sprite) or not is_instance_valid(collision_map):
		return
	if DisplayServer.get_name() == "headless":
		map_vp.queue_free()
		return
	var image := map_vp.get_texture().get_image()
	if image != null and not image.is_empty():
		map_sprite.texture = ImageTexture.create_from_image(image)
		map_vp.queue_free()
	else:
		# 烘焙失败时回退为直接绘制静态地图（保持可玩）。
		map_sprite.visible = false
		collision_map.visible = true
		map_vp.queue_free()


func _update_lighting() -> void:
	if fog_rect == null or player == null:
		return
	var material: ShaderMaterial = fog_rect.material
	if material == null:
		return
	var viewport := get_viewport()
	var size := viewport.get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		return
	var xform := viewport.get_canvas_transform()
	material.set_shader_parameter("player_uv", (xform * player.global_position) / size)
	material.set_shader_parameter("aim_dir", player.aim)
	material.set_shader_parameter("aspect", size.x / size.y)
	var candidates: Array = []
	for lamp in HarborMap.LAMPS:
		var dist := player.global_position.distance_to(lamp["pos"])
		if dist < 900.0:
			candidates.append({"pos": lamp["pos"], "dist": dist})
	if extraction != null:
		var zone_center: Vector2 = HarborMap.EXTRACTION_RECT.get_center()
		if player.global_position.distance_to(zone_center) < 900.0:
			candidates.append({"pos": zone_center, "dist": 0.0})
	candidates.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	for i in range(3):
		var key := "lamp%d_uv" % i
		if i < candidates.size():
			material.set_shader_parameter(key, (xform * candidates[i]["pos"]) / size)
		else:
			material.set_shader_parameter(key, Vector2(-1.0, -1.0))


func _update_culling() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var center := camera.get_screen_center_position()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dx := absf(enemy.global_position.x - center.x)
		var dy := absf(enemy.global_position.y - center.y)
		enemy.visible = dx < 850.0 and dy < 560.0
	for chest in chests:
		if not is_instance_valid(chest):
			continue
		var dx := absf(chest.global_position.x - center.x)
		var dy := absf(chest.global_position.y - center.y)
		chest.visible = dx < 700.0 and dy < 480.0


func _find_nearest_chest(max_distance: float) -> FogChest:
	if player == null:
		return null
	var best: FogChest = null
	var best_dist := max_distance
	for chest in chests:
		if not is_instance_valid(chest):
			continue
		var d := player.global_position.distance_to(chest.global_position)
		if d <= best_dist:
			best_dist = d
			best = chest
	return best


func _handle_chest_result(chest: FogChest, result: Dictionary) -> void:
	var added := 0
	for entry in result.get("added", []):
		added += int(entry["count"])
	var missed := 0
	for entry in result.get("missed", []):
		missed += int(entry["count"])
	if bool(result.get("first", false)):
		chests_opened += 1
		var activated: bool = rules.register_chest_search()
		if activated:
			hud.toast("撤离点已激活：东南栈桥", FogUITheme.TEAL)
	if added > 0:
		hud.toast("+%d 件物资" % added, FogUITheme.AMBER)
		fx.float_text(chest.global_position + Vector2(0, -34), "+%d" % added, FogUITheme.AMBER)
	if missed > 0:
		hud.toast("背包已满，箱内还剩 %d 件" % missed, FogUITheme.RED)
	if bool(result.get("empty", false)):
		hud.toast("补给箱已搜空", FogUITheme.DIM)
	hud.chests_opened = chests_opened


func _on_player_fired(from: Vector2, to: Vector2, hit_enemy: bool) -> void:
	if fx == null:
		return
	fx.tracer(from, to, FogUITheme.AMBER if hit_enemy else Color("c7d4cf"))
	if hit_enemy:
		fx.spark(to, FogUITheme.AMBER, 6)
		hud.show_hit()
		_add_shake(1.2)
	else:
		fx.spark(to, Color("a9b3ae"), 3)
		_add_shake(0.6)


func _on_player_hurt(amount: int) -> void:
	if hud == null or player == null:
		return
	hud.toast("受伤 -%d" % amount, FogUITheme.RED)
	if fx != null:
		fx.float_text(player.global_position + Vector2(0, -30), "-%d" % amount, FogUITheme.RED)
	_add_shake(2.6)


func _on_player_died() -> void:
	_finish_run(false, "阵亡")


func _on_player_notify(text: String, color: Color) -> void:
	if hud != null:
		hud.toast(text, color)


func _on_player_dash() -> void:
	if fx != null and player != null:
		fx.ring(player.global_position, FogUITheme.TEAL, 20.0)
	_add_shake(0.6)


func _spawn_enemy_bullet(from: Vector2, dir: Vector2, damage: int, speed: float, color: Color) -> void:
	if world == null or player == null:
		return
	var bullet := EnemyBulletScript.new()
	bullet.configure(player, from, dir, damage, speed, color)
	bullet.impacted.connect(_on_bullet_impact)
	world.add_child(bullet)


func _on_bullet_impact(pos: Vector2) -> void:
	if fx != null:
		fx.spark(pos, Color("f0a35c"), 5)


func _on_enemy_killed(enemy: FogEnemy) -> void:
	kills += 1
	if hud != null:
		hud.toast("击杀 %s" % String(enemy.data.get("name", "敌人")), FogUITheme.AMBER)
	if fx != null:
		fx.ring(enemy.global_position, FogUITheme.RED, 26.0)


func _on_melee_hit(pos: Vector2, dir: Vector2) -> void:
	if fx != null:
		fx.slash(pos, dir.angle(), FogUITheme.RED)
	_add_shake(2.0)


func _on_upgrade_requested(id: String) -> void:
	if state.buy_upgrade(id):
		base_screen.show_message("升级完成：%s" % String(FogGameState.UPGRADE_DEFS[id]["name"]))
	else:
		base_screen.show_message("信用点不足或已满级")
	base_screen.refresh()


func _on_sell_requested() -> void:
	var gained: int = state.sell_all_warehouse()
	base_screen.show_message("回收完成，+%d 信用点" % gained)
	base_screen.refresh()


func _on_backpack_use(index: int) -> void:
	if player == null or inventory == null:
		return
	if player.hp >= player.max_hp:
		backpack.flash_message("生命已满，暂不使用")
		return
	var result: Dictionary = inventory.use_at(index)
	if not bool(result.get("ok", false)):
		backpack.flash_message(String(result.get("reason", "无法使用")))
		return
	var healed := player.heal(int(result.get("heal", 0)))
	backpack.flash_message("回复 %d 生命" % healed)
	backpack.refresh()
	if hud != null:
		hud.toast("使用医疗包 +%d" % healed, FogUITheme.GREEN)
		hud.queue_redraw()


func _on_backpack_drop(index: int) -> void:
	if inventory == null or world == null or player == null:
		return
	var dropped: Dictionary = inventory.drop_at(index)
	if dropped.is_empty():
		return
	var pickup := PickupScript.new()
	var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
	pickup.configure(String(dropped["id"]), int(dropped["count"]),
		player.global_position + offset, player, inventory)
	pickup.collected.connect(func(id: String, count: int):
		if hud != null:
			hud.toast("拾回 %s ×%d" % [String(FogItems.get_item(id).get("name", id)), count], FogUITheme.TEAL)
	)
	world.add_child(pickup)
	backpack.flash_message("已丢弃 %s ×%d" % [
		String(FogItems.get_item(String(dropped["id"])).get("name", dropped["id"])),
		int(dropped["count"]),
	])
	backpack.refresh()


func _on_backpack_closed() -> void:
	if hud != null:
		hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if mode == "raid" and backpack != null and backpack.visible:
		if backpack.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if mode == "raid" and raid_active and (key.keycode == KEY_TAB or key.keycode == KEY_B or key.keycode == KEY_I):
		if player != null and not player.dead:
			backpack.open()
			get_viewport().set_input_as_handled()


func _toggle_backpack() -> void:
	if backpack.visible:
		backpack.close()
	elif player != null and not player.dead and raid_active:
		backpack.open()


func _update_shake(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 22.0)
	if camera != null and is_instance_valid(camera):
		if _shake > 0.01:
			camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		else:
			camera.offset = Vector2.ZERO


func _add_shake(amount: float) -> void:
	_shake = minf(7.0, _shake + amount)


func _finish_run(success: bool, reason: String) -> void:
	if mode != "raid" or not raid_active:
		return
	raid_active = false
	if backpack.visible:
		backpack.visible = false
		get_tree().paused = false
	if rules != null:
		rules.finish_now(success, reason)
	if player != null:
		player.control_enabled = false
	if hud != null:
		hud.visible = false
	_shake = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	var summary: Dictionary = {}
	if success:
		summary = state.transfer_loot(inventory)
		var count := 0
		for item in summary.get("items", []):
			count += int(item["count"])
		summary["count"] = count
		state.record_run(true)
	else:
		summary = state.lose_run(inventory)
	if world != null:
		world.process_mode = Node.PROCESS_MODE_DISABLED
	if result_screen != null:
		result_screen.queue_free()
	result_screen = ResultScript.new()
	result_screen.name = "ResultScreen"
	ui_layer.add_child(result_screen)
	result_screen.configure(success, reason, summary, state)
	result_screen.return_requested.connect(show_base)
	result_screen.retry_requested.connect(start_raid)
	mode = "result"


func _clear_world() -> void:
	raid_active = false
	if world != null:
		world.queue_free()
		world = null
	map = null
	fx = null
	player = null
	camera = null
	extraction = null
	rules = null
	inventory = null
	chests.clear()
	enemies.clear()
	_nearest_chest = null
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


func _clear_result() -> void:
	if result_screen != null:
		result_screen.queue_free()
		result_screen = null


# ---------------------------------------------------------------------------
# Demo / 截图 / 冒烟测试 API
# ---------------------------------------------------------------------------

func demo_use_save_path(path: String) -> void:
	state.set_path(path)


func demo_reset_state() -> void:
	state.reset()
	state.save()
	if mode == "base":
		show_base()


func demo_seed_state() -> void:
	state.reset()
	state.seed_demo()
	state.save()
	show_base()


func demo_start_raid() -> void:
	start_raid()


func demo_finish(success: bool, reason := "") -> void:
	_finish_run(success, reason if reason != "" else ("撤离成功" if success else "阵亡"))


func demo_set_god(enabled: bool) -> void:
	demo_god = enabled
	if player != null:
		player.demo_god = enabled


func demo_freeze_rules(enabled: bool) -> void:
	rules_frozen = enabled


func demo_set_manual_interaction(enabled: bool) -> void:
	demo_manual_interaction = enabled


func demo_teleport(pos: Vector2) -> void:
	if player == null:
		return
	player.global_position = pos
	if camera != null:
		camera.reset_smoothing()


func demo_move(pos: Vector2) -> void:
	if player != null:
		player.global_position = pos


func demo_aim_at(point: Vector2) -> void:
	if player != null:
		player.demo_aim_at(point)


func demo_clear_aim() -> void:
	if player != null:
		player.demo_clear_aim()


func demo_fire_at(point: Vector2) -> void:
	if player != null:
		player.demo_fire_at(point)


func demo_set_crosshair(screen_pos: Vector2) -> void:
	if hud != null:
		hud.demo_crosshair = screen_pos
		hud.queue_redraw()


func demo_open_backpack() -> void:
	if backpack != null and player != null and not player.dead:
		backpack.open()


func demo_close_backpack() -> void:
	if backpack != null and backpack.visible:
		backpack.close()


func demo_add_loot(loot: Array) -> Dictionary:
	if inventory == null:
		return {}
	return inventory.add_loot(loot)


func demo_prompt(text: String, ratio := -1.0, hint := "") -> void:
	if hud == null:
		return
	hud.prompt_text = text
	hud.prompt_ratio = ratio
	hud.prompt_hint = hint
	hud.queue_redraw()


func demo_search_chest(index: int, delta: float) -> Dictionary:
	if index < 0 or index >= chests.size():
		return {}
	var chest: FogChest = chests[index]
	chest.highlight = true
	var result := chest.search_tick(delta, inventory)
	if String(result.get("state", "")) == "searched":
		_handle_chest_result(chest, result)
		demo_prompt("补给箱已搜索", -1.0, "背包 %d / %d 格" % [inventory.cells_used(), inventory.capacity_cells()])
	elif String(result.get("state", "")) == "searching":
		demo_prompt("正在搜索补给箱", float(result.get("ratio", 0.0)), "保持按住 E · 箱内 %d 件" % chest.loot_count())
	elif String(result.get("state", "")) == "empty":
		demo_prompt("空补给箱", -1.0, "已经被搜空了")
	if hud != null:
		hud.queue_redraw()
	return result


func demo_force_extraction_progress(seconds: float) -> void:
	if rules == null or extraction == null:
		return
	rules.force_activate()
	rules.force_progress(seconds)
	extraction.set_status(true, rules.progress_ratio(), rules.time_left())
	if player != null:
		demo_prompt("撤离中 · 保持在圈内", rules.progress_ratio(),
			"还剩 %.1f 秒" % (RaidRulesScript.EXTRACT_HOLD * (1.0 - rules.progress_ratio())))
	if hud != null:
		hud.queue_redraw()


func demo_set_enemy_alert(index: int) -> void:
	if index >= 0 and index < enemies.size():
		enemies[index].demo_alert()
		enemies[index].global_position = player.global_position + Vector2(170, -40)


func demo_stage_combat() -> void:
	if player == null or enemies.size() < 4:
		return
	demo_god = true
	player.demo_god = true
	demo_teleport(Vector2(960, 720))
	player.demo_aim_at(Vector2(1300, 660))
	var places := [
		Vector2(1180, 620), Vector2(1300, 690), Vector2(1010, 880), Vector2(1260, 900),
	]
	for i in range(mini(4, enemies.size())):
		var enemy: FogEnemy = enemies[i]
		enemy.global_position = places[i]
		enemy.demo_alert()
		if i == 0:
			enemy.demo_show_telegraph("ranged")
		elif i == 2:
			enemy.demo_show_telegraph("melee")
		if fx != null:
			fx.ring(enemy.global_position, FogUITheme.RED, 20.0)
	if hud != null:
		hud.toast("遭遇敌人：保持移动，冲刺有无敌帧", FogUITheme.RED)
	demo_prompt("", -1.0, "")


func demo_loot_setup() -> void:
	if player == null or chests.is_empty():
		return
	demo_teleport(Vector2(500, 520))
	player.demo_aim_at(Vector2(500, 470))
	chests[0].highlight = true
	demo_set_manual_interaction(true)
	demo_search_chest(0, 0.48)
	demo_set_crosshair(Vector2(636, 320))


func demo_extraction_setup() -> void:
	if player == null or extraction == null:
		return
	demo_god = true
	player.demo_god = true
	demo_freeze_rules(true)
	demo_teleport(HarborMap.EXTRACTION_RECT.get_center())
	player.demo_aim_at(HarborMap.EXTRACTION_RECT.get_center() + Vector2(0, -80))
	demo_force_extraction_progress(1.7)
	demo_set_crosshair(Vector2(792, 376))


func demo_add_demo_loot() -> void:
	demo_add_loot([
		{"id": "fog_crystal", "count": 2},
		{"id": "precision_rig", "count": 1},
		{"id": "black_box", "count": 1},
		{"id": "old_script", "count": 5},
		{"id": "medkit", "count": 1},
		{"id": "shipping_chip", "count": 2},
	])


func demo_get_world() -> Node2D:
	return world


func demo_get_map() -> HarborMap:
	return map


func demo_get_player() -> FogPlayer:
	return player


func demo_get_rules() -> FogRaidRules:
	return rules


func demo_get_inventory() -> FogInventory:
	return inventory


func demo_get_state() -> FogGameState:
	return state


func demo_get_chests() -> Array:
	return chests


func demo_get_enemies() -> Array:
	return enemies


func demo_get_base() -> FogBaseScreen:
	return base_screen


func demo_get_hud() -> FogHud:
	return hud


func demo_get_backpack() -> FogBackpackPanel:
	return backpack


func demo_get_result() -> FogResultScreen:
	return result_screen


func demo_get_mode() -> String:
	return mode
