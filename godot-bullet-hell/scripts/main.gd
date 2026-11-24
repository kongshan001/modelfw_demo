extends Node2D

const ArtRes = preload("res://scripts/art.gd")
const BackgroundRes = preload("res://scripts/background.gd")
const FieldRes = preload("res://scripts/bullet_field.gd")
const BossRes = preload("res://scripts/boss.gd")
const PlayerRes = preload("res://scripts/player.gd")
const ShotRes = preload("res://scripts/shot_layer.gd")
const FxRes = preload("res://scripts/fx.gd")
const HudRes = preload("res://scripts/hud.gd")
const TimelineRes = preload("res://scripts/boss_timeline.gd")
const RunnerRes = preload("res://scripts/pattern_runner.gd")
const PoolRes = preload("res://scripts/bullet_pool.gd")

# 绯星弹幕 · Scarlet Orbit
# 主循环：玩家/自动射击 -> Boss 时间轴 -> pattern 发射 -> 弹池推进/碰撞 -> HUD。
# 所有推进集中在 _simulate(dt)，因此 headless 测试与真机跑的是同一套逻辑。

const SEED := 0xB17B17
const BOARD := Rect2(0.0, 0.0, 1280.0, 720.0)
const PLAYER_BOUNDS := Rect2(28.0, 88.0, 1224.0, 606.0)
const SHOT_INTERVAL := 0.10
const SHOT_DAMAGE := 10.0
const PHASE_TRANSITION := 1.5
const BOSS_RADIUS := 34.0
const PLAYER_HIT_RADIUS := 2.6
const PLAYER_GRAZE_RADIUS := 20.0
const PLAYER_MAX_LIVES := 5
const SHOWCASE_TOTAL := 10.0
const SHOWCASE_SCHEDULE := [
	{"t": 0.0, "pattern": 0},
	{"t": 0.8, "pattern": 1},
	{"t": 1.5, "pattern": 2},
	{"t": 2.2, "pattern": 3},
	{"t": 3.1, "pattern": 4},
	{"t": 4.2, "pattern": 5},
	{"t": 5.0, "pattern": 6},
	{"t": 6.0, "pattern": 7},
	{"t": 6.9, "pattern": 8},
	{"t": 8.0, "pattern": 9},
]

var world: Node2D
var bg: BackgroundRes
var field: FieldRes
var boss: BossRes
var player: PlayerRes
var shots: ShotRes
var fx: FxRes
var hud: HudRes
var timeline: TimelineRes
var runner: RunnerRes

var demo := true
var paused := false
var game_over := false
var victory := false
var inspect_id := -1
var timeline_enabled := true
var showcase := false
var phase_index := 0
var current_pattern := 0
var transition_left := 0.0
var run_time := 0.0
var fire_timer := 0.0
var shake := 0.0
var auto_restart_timer := 0.0
var fps := 0
var _shot_side := 1.0
var _graze_fx_cd := 0.0
var _rng := RandomNumberGenerator.new()
var _showcase_t := 0.0
var _showcase_id := -1
var _stress_target := 0
var _movie_mode := false
var _debug_immunity := false
var _debug_force_hits := false

func _ready() -> void:
	_rng.seed = 0xDEC0DE
	showcase = OS.get_cmdline_user_args().has("--showcase")
	_movie_mode = OS.has_feature("movie")
	for arg in OS.get_cmdline_args():
		if String(arg).begins_with("--write-movie"):
			_movie_mode = true
	_build()
	field.pool.grazed.connect(_on_graze)
	field.pool.split_burst.connect(_on_split)
	reset_run()

func _build() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	bg = BackgroundRes.new()
	world.add_child(bg)
	field = FieldRes.new()
	world.add_child(field)
	boss = BossRes.new()
	world.add_child(boss)
	player = PlayerRes.new()
	world.add_child(player)
	shots = ShotRes.new()
	world.add_child(shots)
	fx = FxRes.new()
	world.add_child(fx)
	hud = HudRes.new()
	hud.name = "Hud"
	add_child(hud)

func _process(delta: float) -> void:
	fps = Engine.get_frames_per_second()
	if paused:
		_update_hud()
		return
	var dt := minf(delta, 0.05)
	_simulate(dt)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	var handled := true
	if key == KEY_R:
		reset_run()
	elif key == KEY_P or key == KEY_ESCAPE:
		if not game_over and not victory:
			set_paused(not paused)
	elif key == KEY_TAB:
		if not game_over and not victory:
			demo = not demo
			player.autopilot = demo
			if demo:
				player.manual_input = false
			hud.toast("演示自动操作" if demo else "手动操控 · TAB 切回演示", 1.4)
	elif key == KEY_Q:
		if inspect_id >= 0:
			exit_inspect()
		else:
			handled = false
	elif key >= KEY_1 and key <= KEY_9:
		if not game_over and not victory:
			set_inspect(key - KEY_1)
	elif key == KEY_0:
		if not game_over and not victory:
			set_inspect(9)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func reset_run() -> void:
	timeline = TimelineRes.new()
	timeline.reset()
	field.clear()
	shots.reset()
	fx.reset()
	player.reset()
	player.visible = true
	player.autopilot = demo
	paused = false
	game_over = false
	victory = false
	inspect_id = -1
	timeline_enabled = true
	transition_left = 0.0
	phase_index = 0
	current_pattern = timeline.current_pattern()
	run_time = 0.0
	fire_timer = 0.0
	shake = 0.0
	auto_restart_timer = 0.0
	_stress_target = 0
	_debug_immunity = false
	_debug_force_hits = false
	world.position = Vector2.ZERO
	hud.paused = false
	hud.game_over = false
	hud.victory = false
	hud.flash_alpha = 0.0
	hud.transition_left = 0.0
	if showcase:
		_showcase_t = 0.0
		_showcase_id = -1
		boss.set_phase(0, timeline.phase_hp())
		boss.invuln = true
		runner = RunnerRes.new(0, SEED)
		hud.transition_left = 0.0
		_update_hud()
	else:
		_enter_phase(0, true)

func _enter_phase(index: int, intro: bool) -> void:
	phase_index = index
	timeline.phase_index = index
	timeline.elapsed = 0.0
	timeline.finished = false
	current_pattern = timeline.current_pattern()
	boss.set_phase(index, timeline.phase_hp())
	boss.invuln = true
	field.clear()
	shots.reset()
	transition_left = PHASE_TRANSITION
	player.invuln = maxf(player.invuln, 1.2)
	player.autopilot = demo
	runner = RunnerRes.new(current_pattern, SEED + index * 7919)
	fx.ring(boss.position, boss.phase_color, 150.0, 4.0, 1.0)
	fx.burst(boss.position, boss.phase_color, 28, 240.0, 3.6)
	hud.show_transition(timeline.phase_title(), timeline.phase_subtitle(), PHASE_TRANSITION)
	hud.flash(boss.phase_color, 0.30 if intro else 0.22)
	shake = 10.0
	fire_timer = 0.0
	_update_hud()

func _simulate(dt: float) -> void:
	run_time += dt
	_graze_fx_cd = maxf(0.0, _graze_fx_cd - dt)
	_tick_ambient(dt)
	if showcase:
		_simulate_showcase(dt)
		return
	if game_over or victory:
		_tick_end_state(dt)
		return
	if transition_left > 0.0:
		transition_left -= dt
		player.tick(dt, field.pool, PLAYER_BOUNDS)
		boss.tick(dt)
		shots.tick(dt, boss.position, BOSS_RADIUS, false)
		field.pool.step(dt, player.position, 0.0, 0.0, BOARD)
		field.sync()
		if transition_left <= 0.0:
			transition_left = 0.0
			boss.invuln = false
			fire_timer = 0.0
			hud.toast("弹幕开始 · 120 BPM", 1.0)
		return
	if timeline_enabled:
		var ev := timeline.update(dt)
		if bool(ev["finished"]):
			_start_victory()
			return
		if bool(ev["phase_changed"]):
			_enter_phase(int(ev["phase"]), false)
			return
		if bool(ev["pattern_changed"]):
			current_pattern = int(ev["pattern"])
			runner.setup(current_pattern, SEED + phase_index * 7919 + current_pattern)
			hud.toast("%s  %s" % [RunnerRes.code_of(current_pattern), RunnerRes.name_of(current_pattern)], 1.1)

	player.tick(dt, field.pool, PLAYER_BOUNDS)
	if player.manual_input and demo:
		demo = false
		player.autopilot = false
		hud.toast("手动操控 · TAB 切回演示", 1.3)
	boss.tick(dt)

	if player.alive:
		fire_timer -= dt
		var guard := 0
		while fire_timer <= 0.0 and guard < 3:
			_fire_player_shot()
			fire_timer += SHOT_INTERVAL
			guard += 1

	runner.update(dt, field.pool, boss.position, player.position)

	var boss_active := boss.alive and not boss.invuln and inspect_id < 0
	var hits := shots.tick(dt, boss.position, BOSS_RADIUS, boss_active)
	for hit_pos in hits:
		var dealt := boss.take_damage(SHOT_DAMAGE)
		if dealt > 0.0:
			fx.burst(hit_pos, ArtRes.CYAN, 2, 80.0, 1.7)

	var hit_radius := 0.0
	var graze_radius := 0.0
	if player.alive:
		graze_radius = PLAYER_GRAZE_RADIUS
		if player.invuln <= 0.0 and _stress_target <= 0 and not _debug_immunity and (inspect_id < 0 or _debug_force_hits):
			hit_radius = PLAYER_HIT_RADIUS
	if _stress_target > 0:
		graze_radius = 0.0
		hit_radius = 0.0
	var res := field.pool.step(dt, player.position, hit_radius, graze_radius, BOARD)
	field.sync()
	player.graze += int(res["grazes"])
	if int(res["hits"]) > 0 and player.alive:
		if player.apply_hit():
			_on_player_hit()
	if _stress_target > 0:
		_top_up_stress()
	if boss.hp <= 0.0 and not game_over and not victory and inspect_id < 0:
		if timeline.phase_index >= timeline.phase_count() - 1:
			_start_victory()
		else:
			if timeline.force_next_phase():
				_enter_phase(timeline.phase_index, false)

func _simulate_showcase(dt: float) -> void:
	_showcase_t += dt
	if _showcase_t >= SHOWCASE_TOTAL:
		_showcase_t = fmod(_showcase_t, SHOWCASE_TOTAL)
		_showcase_id = -1
		field.clear()
		shots.reset()
	var idx := 0
	for i in SHOWCASE_SCHEDULE.size():
		if _showcase_t + 0.0001 >= float(SHOWCASE_SCHEDULE[i]["t"]):
			idx = i
	if idx != _showcase_id:
		_showcase_id = idx
		current_pattern = int(SHOWCASE_SCHEDULE[idx]["pattern"])
		runner.setup(current_pattern, SEED + current_pattern)
		boss.invuln = true
		hud.flash(ArtRes.bullet_color(current_pattern), 0.055)
	player.autopilot = true
	player.tick(dt, field.pool, PLAYER_BOUNDS)
	boss.tick(dt)
	boss.invuln = true
	runner.update(dt, field.pool, boss.position, player.position)
	fire_timer -= dt
	var guard := 0
	while fire_timer <= 0.0 and guard < 3:
		_fire_player_shot()
		fire_timer += SHOT_INTERVAL
		guard += 1
	shots.tick(dt, boss.position, BOSS_RADIUS, false)
	var res := field.pool.step(dt, player.position, 0.0, PLAYER_GRAZE_RADIUS, BOARD)
	field.sync()
	player.graze += int(res["grazes"])

func _tick_ambient(dt: float) -> void:
	bg.phase_color = boss.phase_color
	if timeline_enabled and not showcase:
		bg.beat_pulse = timeline.beat_pulse()
	else:
		bg.beat_pulse = 1.0 - fmod(run_time, 0.5) / 0.5
	bg.tick(dt)
	fx.tick(dt)
	if shake > 0.001:
		shake = maxf(0.0, shake - dt * 30.0)
		world.position = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * shake
	else:
		world.position = Vector2.ZERO
	hud.beat_pulse = bg.beat_pulse

func _tick_end_state(dt: float) -> void:
	boss.tick(dt)
	if demo and not paused:
		auto_restart_timer -= dt
		if auto_restart_timer <= 0.0:
			reset_run()

func _fire_player_shot() -> void:
	if not player.alive:
		return
	var origin := player.shot_origin() + Vector2(5.0 * _shot_side, 0.0)
	_shot_side = -_shot_side
	shots.fire(origin, boss.position)

func _on_graze(pos: Vector2) -> void:
	if _graze_fx_cd > 0.0:
		return
	_graze_fx_cd = 0.035
	fx.graze_spark(pos)
	fx.ring(pos, ArtRes.CYAN, 10.0, 1.5, 0.28)

func _on_split(pos: Vector2, color: Color, count: int) -> void:
	fx.ring(pos, color, 26.0, 2.0, 0.42)
	fx.burst(pos, color, mini(10, count), 140.0, 2.4)
	shake = maxf(shake, 3.0)

func _on_player_hit() -> void:
	fx.hit_burst(player.position)
	fx.ring(player.position, ArtRes.MAGENTA, 120.0, 3.0, 0.6)
	hud.flash(ArtRes.RED, 0.34)
	shake = 16.0
	var cleared := field.pool.clear_radius(player.position, 132.0)
	field.sync()
	hud.toast("被弹！清弹屏障 · 消除 %d" % cleared, 1.1)
	if not player.alive:
		_start_game_over()

func _start_game_over() -> void:
	if game_over:
		return
	game_over = true
	timeline_enabled = false
	player.autopilot = false
	player.visible = false
	field.clear()
	shots.reset()
	fx.burst(player.position, ArtRes.RED, 60, 320.0, 4.0)
	fx.ring(player.position, ArtRes.RED, 90.0, 4.0, 0.9)
	hud.flash(ArtRes.RED, 0.5)
	hud.game_over = true
	hud.victory = false
	shake = 18.0
	auto_restart_timer = 5.0

func _start_victory() -> void:
	if victory or game_over:
		return
	victory = true
	timeline_enabled = false
	inspect_id = -1
	player.autopilot = false
	field.clear()
	shots.reset()
	boss.defeat()
	fx.burst(boss.position, ArtRes.GOLD, 90, 430.0, 4.8)
	fx.ring(boss.position, ArtRes.GOLD, 150.0, 5.0, 1.2)
	fx.ring(boss.position, ArtRes.CYAN, 90.0, 3.0, 0.8)
	hud.flash(ArtRes.GOLD, 0.5)
	hud.victory = true
	hud.game_over = false
	shake = 22.0
	auto_restart_timer = 6.0

func set_paused(value: bool) -> void:
	if game_over or victory:
		value = false
	paused = value
	hud.paused = value

func set_inspect(id: int) -> void:
	if game_over or victory:
		return
	paused = false
	hud.paused = false
	inspect_id = clampi(id, 0, RunnerRes.COUNT - 1)
	timeline_enabled = false
	transition_left = 0.0
	current_pattern = inspect_id
	field.clear()
	shots.reset()
	fx.reset()
	shake = 0.0
	world.position = Vector2.ZERO
	runner = RunnerRes.new(inspect_id, SEED + 0x100 + inspect_id)
	boss.invuln = true
	player.autopilot = demo
	hud.transition_left = 0.0
	hud.flash_alpha = 0.0
	hud.toast("观察模式 · %s %s" % [RunnerRes.code_of(inspect_id), RunnerRes.name_of(inspect_id)], 1.3)
	hud.flash(ArtRes.CYAN, 0.10)
	_update_hud()

func exit_inspect() -> void:
	if inspect_id < 0:
		return
	inspect_id = -1
	paused = false
	hud.paused = false
	timeline_enabled = true
	current_pattern = timeline.current_pattern()
	runner.setup(current_pattern, SEED + phase_index * 7919 + current_pattern)
	field.clear()
	shots.reset()
	boss.invuln = true
	transition_left = 0.8
	player.autopilot = demo
	hud.show_transition("回到时间轴", timeline.phase_subtitle(), 0.8)
	_update_hud()

func _update_hud() -> void:
	if hud == null:
		return
	if showcase:
		hud.phase_title = "弹幕展示 · SHOWCASE"
		hud.phase_subtitle = "10 PATTERNS / 120 BPM"
	else:
		hud.phase_title = timeline.phase_title()
		hud.phase_subtitle = timeline.phase_subtitle()
	hud.phase_index = phase_index
	hud.phase_count = timeline.phase_count()
	hud.phase_color = boss.phase_color
	hud.hp = boss.hp
	hud.max_hp = boss.max_hp
	hud.lives = player.lives
	hud.max_lives = PLAYER_MAX_LIVES
	hud.graze = player.graze
	hud.fps = Engine.get_frames_per_second() if fps <= 0 else fps
	hud.bullet_count = field.pool.count
	hud.bullet_capacity = field.pool.capacity
	if inspect_id >= 0:
		hud.pattern_code = RunnerRes.code_of(inspect_id)
		hud.pattern_name = RunnerRes.name_of(inspect_id)
		hud.pattern_summary = RunnerRes.summary_of(inspect_id)
	else:
		hud.pattern_code = RunnerRes.code_of(current_pattern)
		hud.pattern_name = RunnerRes.name_of(current_pattern)
		hud.pattern_summary = RunnerRes.summary_of(current_pattern)
	hud.inspect_id = inspect_id
	hud.rec_mode = _movie_mode and showcase
	hud.demo = demo
	hud.paused = paused
	hud.game_over = game_over
	hud.victory = victory

func _top_up_stress() -> void:
	var n := field.pool.count
	var guard := 0
	while n < _stress_target and guard < 800:
		var p := Vector2(_rng.randf_range(60.0, 1220.0), _rng.randf_range(140.0, 680.0))
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(18.0, 70.0)
		field.pool.spawn(
			p, Vector2.from_angle(a) * sp,
			_rng.randf_range(4.0, 7.0), ArtRes.bullet_color(n),
			PoolRes.Kind.ORB, PoolRes.Behavior.STRAIGHT, 20.0
		)
		n += 1
		guard += 1
	field.sync()

# ---- 测试 / 截图 / 性能工具接口（不参与正常输入） ----

func debug_step(seconds: float, fixed := 1.0 / 60.0) -> void:
	var left := seconds
	var guard := 0
	while left > 0.000001 and guard < 50000:
		var dt := minf(fixed, left)
		if not paused:
			_simulate(dt)
		left -= dt
		guard += 1
	fps = Engine.get_frames_per_second()
	_update_hud()
	hud.queue_redraw()

func debug_set_stress(enabled: bool, target := 1200) -> void:
	_stress_target = maxi(1, target) if enabled else 0
	if enabled:
		_top_up_stress()

func debug_set_immunity(enabled: bool) -> void:
	_debug_immunity = enabled

func debug_force_hits(enabled: bool) -> void:
	_debug_force_hits = enabled

func debug_place_player(pos: Vector2) -> void:
	player.position = pos
	player.velocity = Vector2.ZERO
	player.autopilot = false
	demo = false

func debug_nearest_bullet(center: Vector2) -> Vector2:
	var best := Vector2(-100000.0, -100000.0)
	var best_d := INF
	for i in field.pool.count:
		var d := field.pool.pos[i].distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = field.pool.pos[i]
	return best

func debug_snapshot() -> Dictionary:
	return {
		"phase": phase_index,
		"pattern": current_pattern,
		"inspect": inspect_id,
		"bullets": field.pool.count,
		"lives": player.lives,
		"graze": player.graze,
		"hp": boss.hp,
		"paused": paused,
		"game_over": game_over,
		"victory": victory,
		"transition": transition_left,
		"demo": demo,
		"timeline_enabled": timeline_enabled,
	}
