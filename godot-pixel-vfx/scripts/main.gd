extends Node

# Pixel VFX Lab — interactive playground.
#
# World: 640x360 SubViewport (2x at 1280x720, 3x at 1920x1080), nearest.
# HUD: native 1280x720 CanvasLayer.
# VFX: PixelFX (MIT) sprite sheets, driven by Aseprite-style JSON timing.
# All effect playback is manual (tick) so the smoke test and deterministic
# recorder can step exact frames.

const WORLD_SIZE := Vector2i(640, 360)
const GROUND_Y := 300.0
const PLAYER_POS := Vector2(180, 300)
const DUMMY_POS := Vector2(246, 300)
const COIN_VALUE := 10
const SPEEDS := [0.5, 1.0, 2.0]

var lib: FxLibrary
var world: VfxWorld
var hud: PixelVfxHud
var viewport: SubViewport
var display: TextureRect

var speed_mult := 1.0
var score := 0
var time := 0.0
var hitstop := 0.0
var shake_time := 0.0
var shake_duration := 0.001
var shake_amp := 0.0
var rng := RandomNumberGenerator.new()

var active_fx: Array[Dictionary] = []
var projectile: FireballProjectile = null
var slash_pending := 0.0
var cooldowns := {"slash": 0.0, "fireball": 0.0, "freeze": 0.0}
var coin_feedback: Array[Dictionary] = []
var capture_mode := false
var _freeze_fx: SpriteFX = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 20261121
	lib = FxLibrary.new()
	var ok := lib.load_all()
	if not ok:
		for e in lib.errors:
			push_error("PixelFX asset: " + e)
	_build_view()
	_build_hud()
	print("PIXEL_VFX_READY effects=%d world=%dx%d" % [lib.defs.size(), WORLD_SIZE.x, WORLD_SIZE.y])

func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.size = WORLD_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	add_child(viewport)

	world = VfxWorld.new()
	world.name = "World"
	viewport.add_child(world)
	world.setup(lib)

	display = TextureRect.new()
	display.name = "WorldDisplay"
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.layer = 10
	add_child(layer)
	hud = PixelVfxHud.new()
	hud.name = "HUD"
	layer.add_child(hud)
	hud.setup(self)
	hud.update_state(score, speed_mult, 60)

func _process(delta: float) -> void:
	tick(delta)

# ── simulation ────────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	time += delta
	# hit-stop only consumes the part of this tick it owns; the rest still runs.
	var remaining := delta
	if hitstop > 0.0:
		var used := minf(hitstop, remaining)
		hitstop -= used
		remaining -= used
	if remaining > 0.0:
		var dt := remaining * speed_mult
		for key in cooldowns.keys():
			cooldowns[key] = maxf(0.0, float(cooldowns[key]) - dt)
		if slash_pending > 0.0:
			slash_pending -= dt
			if slash_pending <= 0.0:
				_apply_slash_hit()
		if projectile != null:
			var still_flying := projectile.step(dt)
			if not still_flying:
				var p := projectile
				projectile = null
				p.queue_free()
				_apply_fireball_hit()
		for i in range(active_fx.size() - 1, -1, -1):
			var entry: Dictionary = active_fx[i]
			var node: SpriteFX = entry["node"]
			if node == null or not is_instance_valid(node):
				active_fx.remove_at(i)
				continue
			if not node.step(dt):
				active_fx.remove_at(i)
				if node == _freeze_fx:
					_freeze_fx = null
				node.queue_free()
		for i in range(coin_feedback.size() - 1, -1, -1):
			var fb: Dictionary = coin_feedback[i]
			fb["delay"] = float(fb["delay"]) - dt
			if float(fb["delay"]) <= 0.0:
				_spawn_coin_feedback(fb["pos"])
				coin_feedback.remove_at(i)
		# freeze the frame when a hit lands, so contact flash / hit-stop stay in sync
		if hitstop <= 0.0:
			world.step(dt)
	_update_shake(delta)
	hud.tick_visual(delta)
	hud.update_state(score, speed_mult, Engine.get_frames_per_second())

func _update_shake(delta: float) -> void:
	if shake_time <= 0.0:
		return
	shake_time -= delta
	if shake_time <= 0.0:
		shake_time = 0.0
		world.set_shake_offset(Vector2i.ZERO)
		return
	var k := clampf(shake_time / shake_duration, 0.0, 1.0)
	var amp := maxi(1, int(round(shake_amp * k)))
	world.set_shake_offset(Vector2i(rng.randi_range(-amp, amp), rng.randi_range(-amp, amp)))

func shake(amp: float, seconds: float) -> void:
	shake_amp = amp
	shake_duration = maxf(seconds, 0.001)
	shake_time = seconds

func _spawn_fx(key: String, at: Vector2, z: int, loop_override: int = -1,
		time_limit: float = -1.0) -> SpriteFX:
	var def := lib.get_def(key)
	if def.is_empty():
		push_error("missing effect def: " + key)
		return null
	var fx := SpriteFX.new()
	fx.name = "FX_" + key
	fx.setup(def, loop_override, time_limit)
	fx.position = Vector2(round(at.x), round(at.y))
	fx.z_index = z
	world.fx_layer.add_child(fx)
	active_fx.append({"node": fx, "kind": key})
	return fx

func _remove_fx_kind(kind: String) -> void:
	for i in range(active_fx.size() - 1, -1, -1):
		var entry: Dictionary = active_fx[i]
		if str(entry["kind"]) == kind:
			var node: SpriteFX = entry["node"]
			active_fx.remove_at(i)
			if node != null and is_instance_valid(node):
				if node == _freeze_fx:
					_freeze_fx = null
				node.queue_free()

# ── effects ───────────────────────────────────────────────────────────────────

func trigger_effect_index(index: int) -> bool:
	match index:
		0: return trigger_slash()
		1: return trigger_fireball()
		2: return trigger_freeze()
		3: return trigger_coins()
	return false

func trigger_slash() -> bool:
	if float(cooldowns["slash"]) > 0.0:
		return false
	cooldowns["slash"] = 0.35
	world.knight.attack()
	slash_pending = 0.16
	_spawn_fx("slash", PLAYER_POS, 24, 0)
	hud.flash_effect(0)
	return true

func _apply_slash_hit() -> void:
	world.dummy.hit(1.0)
	var dmg := rng.randi_range(12, 18)
	world.spawn_popup("-%d" % dmg, DUMMY_POS + Vector2(2, -44),
			Color("#ffd2dd"), 2, 0.72)
	hitstop = 0.08
	shake(2.0, 0.18)

func trigger_fireball() -> bool:
	if float(cooldowns["fireball"]) > 0.0 or projectile != null:
		return false
	cooldowns["fireball"] = 0.8
	world.knight.cast()
	projectile = FireballProjectile.new()
	projectile.name = "Fireball"
	projectile.setup(lib.get_def("fireball"), Vector2(PLAYER_POS.x + 16, 260),
			238.0, 120.0)
	world.fx_layer.add_child(projectile)
	hud.flash_effect(1)
	return true

func _apply_fireball_hit() -> void:
	world.dummy.hit(1.2)
	world.dummy.apply_burn(3.0)
	_spawn_fx("explosion", DUMMY_POS, 26, 0, 2.2)
	var dmg := rng.randi_range(24, 32)
	world.spawn_popup("-%d" % dmg, DUMMY_POS + Vector2(4, -48),
			Color("#ffb066"), 3, 0.85)
	hitstop = 0.06
	shake(3.0, 0.26)

func trigger_freeze() -> bool:
	if float(cooldowns["freeze"]) > 0.0:
		return false
	cooldowns["freeze"] = 1.4
	world.knight.cast()
	_remove_fx_kind("freeze")
	_freeze_fx = _spawn_fx("freeze", DUMMY_POS, 22, 0)
	world.dummy.apply_freeze(2.9)
	world.dummy.hit(0.4)
	world.spawn_popup("-6", DUMMY_POS + Vector2(0, -46),
			Color("#a6ecff"), 2, 0.7)
	shake(1.0, 0.12)
	hud.flash_effect(2)
	return true

func trigger_coins() -> bool:
	var n := collect_all_coins()
	hud.flash_effect(3)
	return n > 0

func collect_all_coins() -> int:
	var n := 0
	for i in world.coins.size():
		if _collect_coin(i, i * 0.045):
			n += 1
	return n

func _collect_coin(index: int, delay: float = 0.0) -> bool:
	if index < 0 or index >= world.coins.size():
		return false
	var coin: CoinPickup = world.coins[index]
	if not coin.collect():
		return false
	score += COIN_VALUE
	coin_feedback.append({"delay": delay, "pos": coin.position})
	return true

func _spawn_coin_feedback(at: Vector2) -> void:
	_spawn_fx("burst", at, 24, 0)
	world.spawn_popup("+%d" % COIN_VALUE, at + Vector2(0, -52),
			Color("#ffd76a"), 2, 0.75)

func set_speed(value: float) -> void:
	var chosen := 1.0
	for s in SPEEDS:
		if absf(value - float(s)) < 0.01:
			chosen = float(s)
	speed_mult = chosen
	hud.queue_redraw()

func reset_all() -> void:
	score = 0
	speed_mult = 1.0
	hitstop = 0.0
	shake_time = 0.0
	shake_amp = 0.0
	world.set_shake_offset(Vector2i.ZERO)
	slash_pending = 0.0
	coin_feedback.clear()
	for key in cooldowns.keys():
		cooldowns[key] = 0.0
	for entry in active_fx:
		var node: SpriteFX = entry["node"]
		if node != null and is_instance_valid(node):
			node.queue_free()
	active_fx.clear()
	_freeze_fx = null
	if projectile != null:
		projectile.queue_free()
		projectile = null
	world.dummy.clear_status()
	world.reset_coins()
	world.clear_popups()
	hud.update_state(score, speed_mult, Engine.get_frames_per_second())

func enable_capture_mode() -> void:
	capture_mode = true
	set_process(false)
	hud.set_capture_mode(true)

func set_fps_override(value: int) -> void:
	hud.set_fps_override(value)

func set_hud_ui_scale(factor: float) -> void:
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2.ZERO
	hud.size = Vector2(1280, 720)
	hud.scale = Vector2(factor, factor)
	hud.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: trigger_effect_index(0)
			KEY_2: trigger_effect_index(1)
			KEY_3: trigger_effect_index(2)
			KEY_4: trigger_effect_index(3)
			KEY_5: set_speed(0.5)
			KEY_6: set_speed(1.0)
			KEY_7: set_speed(2.0)
			KEY_R: reset_all()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var wp := _screen_to_world(event.position)
		var idx := world.collect_coin_at(wp)
		if idx >= 0 and _collect_coin(idx):
			hud.flash_effect(3)

func _screen_to_world(screen: Vector2) -> Vector2:
	if display == null:
		return Vector2(-999, -999)
	var r := display.get_global_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Vector2(-999, -999)
	return Vector2(
		(screen.x - r.position.x) / r.size.x * WORLD_SIZE.x,
		(screen.y - r.position.y) / r.size.y * WORLD_SIZE.y)

# ── test / capture hooks ──────────────────────────────────────────────────────

func get_score() -> int:
	return score

func get_speed() -> float:
	return speed_mult

func get_active_fx_count() -> int:
	return active_fx.size()

func get_fx_count(kind: String) -> int:
	var n := 0
	for e in active_fx:
		if str(e["kind"]) == kind:
			n += 1
	return n

func get_last_fx() -> SpriteFX:
	if active_fx.is_empty():
		return null
	var node: SpriteFX = active_fx[active_fx.size() - 1]["node"]
	return node

func has_projectile() -> bool:
	return projectile != null

func get_dummy() -> TrainingDummy:
	return world.dummy

func get_world() -> VfxWorld:
	return world

func get_hud() -> PixelVfxHud:
	return hud

func get_display() -> TextureRect:
	return display

func get_world_viewport() -> SubViewport:
	return viewport

func get_lib() -> FxLibrary:
	return lib

func get_hitstop() -> float:
	return hitstop
