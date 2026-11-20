extends Node2D

# Reelward — one-lane slot auto-battler.
# Reels/handling live in reel_slot.gd; this file owns the run, battle and presentation.
# All art is drawn here or built pixel-by-pixel in reel_art.gd.

const SlotLogic := preload("res://src/reel_slot.gd")
const ReelArt := preload("res://src/reel_art.gd")

const VIEW := Vector2(1280, 720)
const TOP_H := 56.0
const CABINET := Rect2(20, 70, 580, 596)
const BATTLE := Rect2(616, 70, 640, 596)
const GROUND_Y := 560.0
const HEART_X := 656.0
const SLOT_XS := [840.0, 910.0, 980.0, 1050.0, 1120.0]
const SPAWN_X := 1238.0
const REEL_X := 120.0
const REEL_Y := 156.0
const CELL := 116.0
const CELL_PITCH := 128.0
const SPIN_BTN := Rect2(120, 568, 300, 48)
const LEVER_RECT := Rect2(512, 262, 84, 220)
const SHOP_CARDS := [
	Rect2(110, 196, 340, 330),
	Rect2(470, 196, 340, 330),
	Rect2(830, 196, 340, 330),
]
const REROLL_BTN := Rect2(430, 566, 180, 46)
const CONTINUE_BTN := Rect2(630, 566, 220, 46)
const MAX_WAVE := 6
const MAX_HEARTS := 7
const MAX_LEVEL := 5

const C_VOID := Color("#0c0a14")
const C_NIGHT := Color("#1a1430")
const C_NIGHT2 := Color("#2c2050")
const C_VIOLET := Color("#46306b")
const C_BRASS := Color("#e0a94a")
const C_BRASS_DK := Color("#8f5f22")
const C_BRASS_L := Color("#ffe6a6")
const C_CREAM := Color("#f4e6c8")
const C_MINT := Color("#7fe0c3")
const C_CYAN := Color("#35d8d0")
const C_CYAN_L := Color("#b9fff4")
const C_CYAN_DK := Color("#0d5a63")
const C_CRIM := Color("#d94a68")
const C_CRIM_L := Color("#ff9db0")
const C_BONE := Color("#f4e6c8")
const C_LEATHER_H := Color("#5a3b2a")
const C_STEEL_D := Color("#3f4f76")
const C_ROSE := Color("#ff6f9c")
const C_RED := Color("#e8485f")
const C_DIM := Color("#a89bc4")
const C_DIM2 := Color("#6f6288")
const C_CELL := Color("#0e0a18")
const C_CELL_HI := Color("#241c3a")
const C_PANEL := Color("#141020")
const C_GROUND := Color("#2a1f35")
const C_INK := Color("#0a0712")

const UNIT_BASE := {
	"blade": {"hp": 150.0, "dmg": 22.0, "rate": 0.85, "range": 210.0},
	"bow": {"hp": 100.0, "dmg": 18.0, "rate": 1.0, "range": 520.0},
	"shield": {"hp": 460.0, "dmg": 9.0, "rate": 1.3, "range": 120.0},
	"steed": {"hp": 120.0, "dmg": 14.0, "rate": 0.45, "range": 220.0},
	"orb": {"hp": 110.0, "dmg": 20.0, "rate": 1.4, "range": 500.0},
}

const ENEMY_BASE := {
	"grunt": {"hp": 34.0, "speed": 26.0, "dmg": 7.0, "rate": 1.3, "gold": 1},
	"runner": {"hp": 24.0, "speed": 46.0, "dmg": 5.0, "rate": 0.9, "gold": 1},
	"brute": {"hp": 115.0, "speed": 17.0, "dmg": 16.0, "rate": 1.6, "gold": 3},
	"boss": {"hp": 900.0, "speed": 12.0, "dmg": 26.0, "rate": 1.4, "gold": 12},
}

const ITEM_ORDER := ["blade_magnet", "crown_swap", "ledger", "quench"]
const ITEM_POOL := {
	"blade_magnet": {
		"name": "磁石·刃", "name_en": "BLADE MAGNET", "cost": 3, "kind": "odds",
		"desc": "Blade 权重 +10。\n更容易摇出剑。",
	},
	"crown_swap": {
		"name": "冠冕换面", "name_en": "CROWN RECAST", "cost": 4, "kind": "symbol",
		"desc": "把 Steed 的全部权重\n并入 Crown 符号。",
	},
	"ledger": {
		"name": "双账本", "name_en": "TWIN LEDGER", "cost": 4, "kind": "economy",
		"desc": "旋转费用 -1（最低 1）。\n击杀金币 +1。",
	},
	"quench": {
		"name": "淬火砂", "name_en": "QUENCH SAND", "cost": 4, "kind": "stats",
		"desc": "所有单位伤害 +25%，\n生命 +20%（含已有）。",
	},
}

var slot: RefCounted
var shop_rng := RandomNumberGenerator.new()
var seed_value := 1

var state := "idle"  # idle | wave | shop | win | lose
var wave := 0
var gold := 8
var hearts := MAX_HEARTS
var spin_cost := 2
var kill_bonus := 0
var dmg_mult := 1.0
var hp_mult := 1.0
var speed := 1.0

var units: Array = []
var enemies: Array = []
var spawn_queue: Array = []
var wave_time := 0.0
var wave_clear_t := -1.0
var boss_alive := false
var boss_max_hp := 0.0
var boss_killed := false
var victory_t := -1.0

var spinning := false
var spin_t := 0.0
var spin_duration := 0.95
var spin_grid: Array = []
var spin_result: Dictionary = {}
var settled_cols := 0
var highlight_lines: Array = []
var highlight_t := 0.0

var floats: Array = []
var particles: Array = []
var shake_t := 0.0
var shake_mag := 0.0

var shop_offers: Array = []
var shop_sold: Array = []
var shop_open_t := 0.0

var stats := {"spins": 0, "coins": 0, "kills": 0, "summons": 0, "upgrades": 0}
var total_elapsed := 0.0

var symbol_tex := {}
var heart_tex := {}
var heart_strips: Array = []
var stars: Array = []
var _font: Font
var _font_display: Font
var _font_mono: Font
var sfx := {}
var _sfx_rng := RandomNumberGenerator.new()

# Presentation-only state (never read by the gameplay rules).
var backdrop := {}
var glow_tex: Texture2D
var vignette_tex: Texture2D
var coin_tex: Texture2D
var cabinet_tex: Texture2D
var reel_cells_tex: Texture2D
var spin_ready_tex: Texture2D
var spin_off_tex: Texture2D
var shadow_tex: Texture2D
var page_sky_tex: Texture2D
var banner_t := 0.0
var banner_kind := ""
var banner_dur := 1.6
var end_t := 0.0
var flash_t := 0.0
var flash_dur := 1.0
var flash_col := Color.WHITE
var gold_bump := 0.0
var last_gold := 0
var col_stop_t := [-9.0, -9.0, -9.0]
var lever_anim := 0.0
var spin_press := 0.0
var boss_intro_t := 0.0
var deaths: Array = []
var sparks: Array = []
var projectiles: Array = []
var slashes: Array = []


func _ready() -> void:
	_font = _make_system_font(
		PackedStringArray(["Avenir Next", "Helvetica Neue", "PingFang SC", "Noto Sans CJK SC", "Arial"]), 500)
	_font_display = _make_system_font(
		PackedStringArray(["SF Mono", "Menlo", "Consolas", "PingFang SC", "Noto Sans CJK SC"]), 800)
	_font_mono = _make_system_font(
		PackedStringArray(["SF Mono", "Menlo", "Consolas", "DejaVu Sans Mono", "PingFang SC"]), 600)
	symbol_tex = ReelArt.build_symbol_textures()
	heart_tex = ReelArt.build_heart_textures()
	heart_strips = _build_heart_strips()
	coin_tex = ReelArt.build_coin_texture()
	glow_tex = ReelArt.build_glow_texture()
	vignette_tex = ReelArt.build_vignette_texture()
	cabinet_tex = ReelArt.build_cabinet_shell()
	reel_cells_tex = ReelArt.build_reel_cells()
	spin_ready_tex = ReelArt.build_spin_button(true)
	spin_off_tex = ReelArt.build_spin_button(false)
	shadow_tex = ReelArt.build_shadow_texture()
	page_sky_tex = ReelArt.build_page_sky()
	backdrop = ReelArt.build_backdrop()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	for i in 56:
		stars.append({
			"pos": Vector2(16 + rng.randf() * 608, 14 + rng.randf() * 360),
			"a": 0.12 + rng.randf() * 0.4,
			"s": 1.0 + rng.randf() * 2.0,
		})
	_build_sfx()
	start_run(0)


func _build_heart_strips() -> Array:
	var out: Array = []
	var full: Image = heart_tex["full"].get_image()
	full.resize(28, 24, Image.INTERPOLATE_NEAREST)
	var empty: Image = heart_tex["empty"].get_image()
	empty.resize(28, 24, Image.INTERPOLATE_NEAREST)
	for count in MAX_HEARTS + 1:
		var img := Image.create(208, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in MAX_HEARTS:
			img.blit_rect(full if i < count else empty, Rect2i(0, 0, 28, 24), Vector2i(i * 30, 0))
		out.append(ImageTexture.create_from_image(img))
	return out


func _make_system_font(names: PackedStringArray, weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = names
	f.font_weight = weight
	f.allow_system_fallback = true
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fallbacks: Array[Font] = [ThemeDB.fallback_font]
	f.fallbacks = fallbacks
	return f


# ---------------------------------------------------------------------------
# Run lifecycle
# ---------------------------------------------------------------------------

func start_run(p_seed: int = 0) -> void:
	if p_seed == 0:
		p_seed = int(Time.get_ticks_usec() % 999983)
		if p_seed <= 0:
			p_seed = 1
	seed_value = p_seed
	slot = SlotLogic.new(seed_value)
	shop_rng.seed = seed_value * 31 + 17
	state = "idle"
	wave = 0
	gold = 8
	hearts = MAX_HEARTS
	spin_cost = 2
	kill_bonus = 0
	dmg_mult = 1.0
	hp_mult = 1.0
	speed = 1.0
	units.clear()
	enemies.clear()
	spawn_queue.clear()
	wave_time = 0.0
	wave_clear_t = -1.0
	boss_alive = false
	boss_max_hp = 0.0
	boss_killed = false
	victory_t = -1.0
	spinning = false
	spin_t = 0.0
	spin_grid = []
	spin_result = {}
	settled_cols = 0
	highlight_lines = []
	highlight_t = 0.0
	floats.clear()
	particles.clear()
	shake_t = 0.0
	shake_mag = 0.0
	shop_offers.clear()
	shop_sold.clear()
	shop_open_t = 0.0
	stats = {"spins": 0, "coins": 0, "kills": 0, "summons": 0, "upgrades": 0}
	total_elapsed = 0.0
	# presentation-only state
	banner_t = 0.0
	banner_kind = ""
	end_t = 0.0
	flash_t = 0.0
	gold_bump = 0.0
	last_gold = gold
	col_stop_t = [-9.0, -9.0, -9.0]
	lever_anim = 0.0
	spin_press = 0.0
	boss_intro_t = 0.0
	deaths.clear()
	sparks.clear()
	projectiles.clear()
	slashes.clear()
	queue_redraw()


func toggle_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0
	_float(Vector2(1130, 40), "x%d" % int(speed), C_MINT, 15)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if state == "shop":
					continue_shop()
				elif state == "win" or state == "lose":
					start_run(0)
				else:
					request_spin()
			KEY_1, KEY_2, KEY_3:
				if state == "shop":
					buy_offer(event.keycode - KEY_1)
			KEY_E:
				if state == "shop":
					reroll_shop()
			KEY_F:
				toggle_speed()
			KEY_R:
				start_run(0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if state == "shop":
			for i in SHOP_CARDS.size():
				if SHOP_CARDS[i].has_point(p):
					buy_offer(i)
					return
			if REROLL_BTN.has_point(p):
				reroll_shop()
			elif CONTINUE_BTN.has_point(p):
				continue_shop()
		elif state == "win" or state == "lose":
			start_run(0)
		elif LEVER_RECT.has_point(p) or SPIN_BTN.has_point(p):
			request_spin()


# ---------------------------------------------------------------------------
# Reels
# ---------------------------------------------------------------------------

func request_spin() -> bool:
	if spinning or (state != "idle" and state != "wave"):
		return false
	if gold < spin_cost:
		play_sfx("deny")
		_float(Vector2(270, 640), "金币不足 GOLD SHORT", C_RED, 14)
		return false
	gold -= spin_cost
	spinning = true
	spin_press = 0.18
	spin_t = 0.0
	settled_cols = 0
	highlight_lines = []
	highlight_t = 0.0
	spin_grid = slot.spin()
	spin_result = SlotLogic.resolve_grid(spin_grid)
	stats.spins += 1
	play_sfx("spin")
	queue_redraw()
	return true


func _update_spin(dt: float) -> void:
	spin_t += dt
	var stops := [0.55, 0.72, 0.95]
	while settled_cols < 3 and spin_t >= float(stops[settled_cols]):
		col_stop_t[settled_cols] = spin_t
		settled_cols += 1
		play_sfx("stop")
		var cx := REEL_X + (settled_cols - 1) * CELL_PITCH + CELL * 0.5
		_burst(Vector2(cx, 548), C_BRASS, 7)
		_spark(Vector2(cx, 548), C_BRASS_L, 4, Vector2.UP)
		_shake(0.05, 1.0)
	if spin_t >= spin_duration:
		spinning = false
		_apply_slot_result(spin_result)


func _apply_slot_result(res: Dictionary) -> void:
	if res.is_empty():
		return
	for triple in res.get("triples", []):
		var symbol: String = triple.symbol
		if symbol == "crown":
			_upgrade_weakest()
		else:
			summon(symbol)
	var payout := int(res.get("payout", 0))
	if payout > 0:
		gold += payout
		stats.coins += payout
		_float(Vector2(270, 545), "+%d 金币" % payout, C_BRASS, 18)
		play_sfx("coin")
	if res.get("triples", []).is_empty() and payout == 0:
		_float(Vector2(270, 545), "空转 · NO LINE", C_DIM, 13)
	highlight_lines = res.get("lines", [])
	highlight_t = 1.1
	var triples: Array = res.get("triples", [])
	if not triples.is_empty() or payout > 0:
		_flash(Color(1.0, 0.86, 0.52), 0.10)
		for triple in triples:
			var cells: Array = triple.cells
			var mid: Vector2i = cells[1]
			var cell_center := Vector2(
				REEL_X + mid.x * CELL_PITCH + CELL * 0.5,
				REEL_Y + mid.y * CELL_PITCH + CELL * 0.5)
			var col := C_CYAN if triple.symbol == "crown" else C_BRASS_L
			_coin_burst(cell_center, 5 if triple.symbol != "crown" else 3)
			_spark(cell_center, col, 8, Vector2.UP)
		if triples.size() >= 2:
			_confetti(12)
	if state == "idle":
		start_wave(1)


# ---------------------------------------------------------------------------
# Units
# ---------------------------------------------------------------------------

func summon(symbol: String) -> void:
	if not UNIT_BASE.has(symbol):
		return
	stats.summons += 1
	var used := {}
	for u in units:
		used[int(u.slot)] = true
	var slot_idx := -1
	for i in _preferred_slots(symbol):
		if not used.has(i):
			slot_idx = i
			break
	if slot_idx >= 0:
		var base: Dictionary = UNIT_BASE[symbol]
		var unit := {
			"type": symbol,
			"slot": slot_idx,
			"level": 1,
			"max_hp": base.hp * hp_mult,
			"hp": base.hp * hp_mult,
			"dmg": base.dmg * dmg_mult,
			"rate": base.rate,
			"range": base.range,
			"cd": 0.25 + slot_idx * 0.12,
			"flash": 0.0,
			"phase": slot_idx * 0.9,
			"lunge": 0.0,
		}
		units.append(unit)
		_float(Vector2(SLOT_XS[slot_idx], GROUND_Y - 108), symbol.to_upper(), ReelArt.symbol_color(symbol), 15)
		_burst(Vector2(SLOT_XS[slot_idx], GROUND_Y - 34), ReelArt.symbol_color(symbol), 14)
		play_sfx("summon")
	else:
		var target: Dictionary = {}
		for u in units:
			if u.type == symbol:
				target = u
				break
		if target.is_empty():
			for u in units:
				if target.is_empty() or u.level < target.level:
					target = u
		_upgrade_unit(target)


func _preferred_slots(symbol: String) -> Array:
	match symbol:
		"shield", "steed":
			return [4, 3, 2, 1, 0]
		"blade":
			return [3, 2, 1, 4, 0]
		_:
			return [0, 1, 2, 3, 4]


func _upgrade_unit(unit: Dictionary) -> void:
	if unit.is_empty():
		return
	var base: Dictionary = UNIT_BASE[unit.type]
	unit.level = mini(MAX_LEVEL, int(unit.level) + 1)
	var ratio := 1.0
	if float(unit.max_hp) > 0.0:
		ratio = float(unit.hp) / float(unit.max_hp)
	unit.max_hp = base.hp * hp_mult * (1.0 + 0.35 * (unit.level - 1))
	unit.hp = unit.max_hp
	unit.dmg = base.dmg * dmg_mult * (1.0 + 0.45 * (unit.level - 1))
	unit.flash = 0.15
	stats.upgrades += 1
	_float(Vector2(SLOT_XS[int(unit.slot)], GROUND_Y - 118), "LV %d" % int(unit.level), C_BRASS, 17)
	_burst(Vector2(SLOT_XS[int(unit.slot)], GROUND_Y - 36), C_BRASS, 18)
	play_sfx("upgrade")


func _upgrade_weakest() -> void:
	if units.is_empty():
		gold += 2
		stats.coins += 2
		_float(Vector2(270, 545), "无单位 · +2 金币", C_BRASS, 14)
		play_sfx("coin")
		return
	var target: Dictionary = units[0]
	for u in units:
		if int(u.level) < int(target.level):
			target = u
	_upgrade_unit(target)


# ---------------------------------------------------------------------------
# Waves and enemies
# ---------------------------------------------------------------------------

func start_wave(index: int) -> void:
	if index > MAX_WAVE:
		_win()
		return
	state = "wave"
	wave = index
	wave_time = 0.0
	wave_clear_t = -1.0
	boss_killed = false
	victory_t = -1.0
	shop_offers.clear()
	shop_sold.clear()
	spawn_queue = _wave_plan(index)
	play_sfx("wave")
	_show_banner("boss" if index == MAX_WAVE else "wave")


func _wave_plan(index: int) -> Array:
	var plan: Array = []
	match index:
		1:
			for i in 6:
				plan.append({"t": 2.0 + i * 1.3, "type": "grunt"})
		2:
			for i in 8:
				plan.append({"t": 1.4 + i * 1.1, "type": "grunt"})
			plan.append({"t": 10.2, "type": "brute"})
		3:
			for i in 6:
				plan.append({"t": 1.2 + i * 1.25, "type": "grunt"})
			for i in 3:
				plan.append({"t": 3.0 + i * 2.7, "type": "runner"})
			for i in 2:
				plan.append({"t": 8.5 + i * 3.2, "type": "brute"})
		4:
			for i in 10:
				plan.append({"t": 1.2 + i * 0.95, "type": "grunt"})
			for i in 4:
				plan.append({"t": 2.4 + i * 2.4, "type": "runner"})
			for i in 3:
				plan.append({"t": 6.0 + i * 2.6, "type": "brute"})
		5:
			for i in 12:
				plan.append({"t": 1.0 + i * 0.85, "type": "grunt"})
			for i in 4:
				plan.append({"t": 2.2 + i * 2.6, "type": "runner"})
			for i in 4:
				plan.append({"t": 5.0 + i * 2.4, "type": "brute"})
		6:
			plan.append({"t": 2.0, "type": "boss"})
			for i in 6:
				plan.append({"t": 8.0 + i * 4.5, "type": "grunt"})
	plan.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return plan


func _spawn_enemy(type: String) -> void:
	var base: Dictionary = ENEMY_BASE[type]
	var hp_scale := 1.0 + 0.12 * maxi(0, wave - 1)
	var dmg_scale := 1.0 + 0.06 * maxi(0, wave - 1)
	var hp: float = base.hp * hp_scale
	var enemy := {
		"type": type,
		"x": SPAWN_X,
		"hp": hp,
		"max_hp": hp,
		"speed": base.speed,
		"dmg": base.dmg * dmg_scale,
		"rate": base.rate,
		"cd": 0.6,
		"gold": int(base.gold),
		"flash": 0.0,
		"phase": enemies.size() * 1.7,
		"lunge": 0.0,
	}
	enemies.append(enemy)
	if type == "boss":
		boss_alive = true
		boss_max_hp = hp
		play_sfx("boss")
		boss_intro_t = 2.2
		_flash(Color(1.0, 0.28, 0.24), 0.34)
		_shake(0.5, 8.0)


func _update_wave(dt: float) -> void:
	wave_time += dt
	while not spawn_queue.is_empty() and float(spawn_queue[0].t) <= wave_time:
		var s: Dictionary = spawn_queue.pop_front()
		_spawn_enemy(s.type)

	for e in enemies.duplicate():
		e.flash = maxf(0.0, float(e.flash) - dt)
		e.lunge = maxf(0.0, float(e.lunge) - dt)
		var target: Dictionary = {}
		var best_x := -100000.0
		for u in units:
			var ux: float = SLOT_XS[int(u.slot)]
			if float(e.x) - ux <= 58.0 and float(e.x) > ux - 36.0 and ux > best_x:
				target = u
				best_x = ux
		if not target.is_empty():
			e.cd = float(e.cd) - dt
			if float(e.cd) <= 0.0:
				e.cd = float(e.rate)
				e.lunge = 0.18
				target.hp = float(target.hp) - float(e.dmg)
				target.flash = 0.14
				_float(Vector2(best_x, GROUND_Y - 92), "-%d" % int(e.dmg), C_RED, 14)
				_burst(Vector2(best_x, GROUND_Y - 46), C_RED, 5)
				_spark(Vector2(best_x, GROUND_Y - 48), C_RED, 5, Vector2.LEFT)
				_slash(Vector2(best_x - 6, GROUND_Y - 50), Color("#ff9db0"), 20.0, -1.0)
				_shake(0.14, 3.0)
				play_sfx("hit")
		else:
			e.x = float(e.x) - float(e.speed) * dt
			if float(e.x) <= HEART_X:
				var loss := 3 if e.type == "boss" else 1
				hearts = maxi(0, hearts - loss)
				_float(Vector2(HEART_X + 20, GROUND_Y - 150), "-%d ♥" % loss, C_RED, 20)
				_shake(0.4, 9.0)
				_burst(Vector2(HEART_X + 20, GROUND_Y - 120), C_RED, 20)
				_spark(Vector2(HEART_X + 20, GROUND_Y - 120), C_RED, 12, Vector2.LEFT)
				_flash(Color(0.9, 0.12, 0.22), 0.30)
				play_sfx("hurt")
				enemies.erase(e)
				if hearts <= 0:
					_lose()
					return

	# units attack the enemy closest to the heart inside their range
	for u in units:
		u.flash = maxf(0.0, float(u.flash) - dt)
		u.lunge = maxf(0.0, float(u.lunge) - dt)
		u.cd = float(u.cd) - dt
		if float(u.cd) > 0.0:
			continue
		var target: Dictionary = {}
		var best_x := 100000.0
		for e in enemies:
			var ex: float = e.x
			var ux: float = SLOT_XS[int(u.slot)]
			if ex >= ux - 30.0 and ex - ux <= float(u.range) and ex < best_x:
				target = e
				best_x = ex
		if target.is_empty():
			continue
		u.cd = float(u.rate)
		u.lunge = 0.16
		var dmg: float = float(u.dmg)
		target.hp = float(target.hp) - dmg
		target.flash = 0.12
		_float(Vector2(best_x, GROUND_Y - 76), "%d" % int(dmg), C_CREAM, 15)
		_burst(Vector2(best_x, GROUND_Y - 40), Color("#ffd9a0"), 5)
		var ux2: float = SLOT_XS[int(u.slot)]
		match String(u.type):
			"bow":
				_projectile("arrow", Vector2(ux2 + 20, GROUND_Y - 58), Vector2(best_x, GROUND_Y - 48), C_CREAM, 0.13)
			"orb":
				_projectile("orb", Vector2(ux2 + 18, GROUND_Y - 64), Vector2(best_x, GROUND_Y - 50), Color("#c77bff"), 0.20)
			_:
				_slash(Vector2(best_x, GROUND_Y - 46), Color("#ffe6a6"), 26.0, 1.0)
		_spark(Vector2(best_x, GROUND_Y - 46), Color("#ffd9a0"), 4, Vector2.RIGHT)
		play_sfx("hit")
		if u.type == "orb":
			for other in enemies:
				if other == target:
					continue
				if absf(float(other.x) - best_x) <= 78.0:
					other.hp = float(other.hp) - dmg * 0.55
					other.flash = 0.1
					_float(Vector2(float(other.x), GROUND_Y - 66), "%d" % int(dmg * 0.55), Color("#d8b6ff"), 12)
					_spark(Vector2(float(other.x), GROUND_Y - 46), Color("#c79bf2"), 4, Vector2.RIGHT)
			_burst(Vector2(best_x, GROUND_Y - 40), Color("#b07aff"), 12)

	# reap dead enemies
	var i := 0
	while i < enemies.size():
		var e: Dictionary = enemies[i]
		if float(e.hp) <= 0.0:
			var reward := int(e.gold) + kill_bonus
			gold += reward
			stats.kills += 1
			stats.coins += reward
			_float(Vector2(float(e.x), GROUND_Y - 96), "+%d g" % reward, C_BRASS, 14)
			_burst(Vector2(float(e.x), GROUND_Y - 36), C_ROSE, 16)
			_spark(Vector2(float(e.x), GROUND_Y - 48), C_ROSE, 8, Vector2.RIGHT)
			_coin_burst(Vector2(float(e.x), GROUND_Y - 44), 3)
			_death("enemy", String(e.type), float(e.x), _enemy_color(String(e.type)))
			if e.type == "boss":
				boss_alive = false
				boss_killed = true
				victory_t = 1.6
				spawn_queue.clear()
				_shake(0.6, 12.0)
				_flash(Color(1.0, 0.95, 0.85), 0.45)
				_confetti(36)
				_death("boss", "boss", float(e.x), Color("#ff4f8b"))
				play_sfx("bossdown")
			enemies.remove_at(i)
		else:
			i += 1

	# reap dead units
	i = 0
	while i < units.size():
		var u: Dictionary = units[i]
		if float(u.hp) <= 0.0:
			_float(Vector2(SLOT_XS[int(u.slot)], GROUND_Y - 100), "阵亡", C_RED, 14)
			_burst(Vector2(SLOT_XS[int(u.slot)], GROUND_Y - 40), C_RED, 18)
			_spark(Vector2(SLOT_XS[int(u.slot)], GROUND_Y - 50), C_RED, 10, Vector2.LEFT)
			_death("unit", String(u.type), SLOT_XS[int(u.slot)], ReelArt.symbol_color(String(u.type)))
			units.remove_at(i)
		else:
			i += 1

	# boss killed: short victory beat, ignore leftover minions
	if victory_t > 0.0:
		victory_t -= dt
		if victory_t <= 0.0:
			_win()
			return

	if wave_clear_t > 0.0:
		wave_clear_t -= dt
		if wave_clear_t <= 0.0:
			if wave >= MAX_WAVE:
				_win()
			else:
				open_shop()
		return

	if spawn_queue.is_empty() and enemies.is_empty() and not boss_killed:
		wave_clear_t = 1.2
		gold += 2
		stats.coins += 2
		_float(Vector2(930, 250), "波次奖励 +2 g", C_BRASS, 16)


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

func open_shop() -> void:
	state = "shop"
	shop_open_t = 0.0
	shop_offers = _roll_offers()
	shop_sold = [false, false, false]
	play_sfx("shop")


func _roll_offers() -> Array:
	var ids := ITEM_ORDER.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := shop_rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var out: Array = []
	for i in 3:
		out.append(ids[i])
	return out


func reroll_shop() -> void:
	if state != "shop" or gold < 1:
		play_sfx("deny")
		return
	gold -= 1
	shop_offers = _roll_offers()
	shop_sold = [false, false, false]
	play_sfx("coin")
	_float(Vector2(520, 610), "重摇 -1 g", C_BRASS, 13)


func buy_offer(index: int) -> bool:
	if state != "shop" or index < 0 or index >= shop_offers.size():
		return false
	if shop_sold[index]:
		return false
	var id: String = shop_offers[index]
	var item: Dictionary = ITEM_POOL[id]
	if gold < int(item.cost):
		play_sfx("deny")
		_float(Vector2(250 + index * 360, 560), "金币不足", C_RED, 14)
		return false
	gold -= int(item.cost)
	shop_sold[index] = true
	_apply_item(id)
	play_sfx("buy")
	return true


func _apply_item(id: String) -> void:
	match id:
		"blade_magnet":
			slot.add_weight("blade", 10)
		"crown_swap":
			slot.recast_symbol("steed", "crown")
		"ledger":
			spin_cost = maxi(1, spin_cost - 1)
			kill_bonus += 1
		"quench":
			dmg_mult += 0.25
			hp_mult += 0.20
			for u in units:
				_rebuild_unit_stats(u)


func _rebuild_unit_stats(unit: Dictionary) -> void:
	var base: Dictionary = UNIT_BASE[unit.type]
	var ratio := 1.0
	if float(unit.max_hp) > 0.0:
		ratio = clampf(float(unit.hp) / float(unit.max_hp), 0.1, 1.0)
	unit.max_hp = base.hp * hp_mult * (1.0 + 0.35 * (int(unit.level) - 1))
	unit.dmg = base.dmg * dmg_mult * (1.0 + 0.45 * (int(unit.level) - 1))
	unit.hp = float(unit.max_hp) * ratio


func continue_shop() -> void:
	if state != "shop":
		return
	start_wave(wave + 1)


# ---------------------------------------------------------------------------
# Outcome
# ---------------------------------------------------------------------------

func _win() -> void:
	if state == "win":
		return
	state = "win"
	end_t = 0.0
	_flash(Color(0.95, 1.0, 0.95), 0.5)
	_confetti(56)
	play_sfx("win")
	queue_redraw()


func _lose() -> void:
	if state == "lose":
		return
	state = "lose"
	end_t = 0.0
	_flash(Color(0.9, 0.12, 0.2), 0.5)
	play_sfx("lose")
	queue_redraw()


func _enemy_color(type: String) -> Color:
	match type:
		"grunt": return Color("#d1588f")
		"runner": return Color("#e08a52")
		"brute": return Color("#9a3f6e")
		"boss": return Color("#a24ad8")
	return C_ROSE


# ---------------------------------------------------------------------------
# Frame loop and FX
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt := delta * speed
	total_elapsed += delta
	shake_t = maxf(0.0, shake_t - dt)
	if shake_t <= 0.0:
		shake_mag = 0.0
	highlight_t = maxf(0.0, highlight_t - dt)
	banner_t = maxf(0.0, banner_t - delta)
	boss_intro_t = maxf(0.0, boss_intro_t - delta)
	flash_t = maxf(0.0, flash_t - dt)
	spin_press = maxf(0.0, spin_press - delta * 4.0)
	gold_bump = maxf(0.0, gold_bump - delta * 2.4)
	if gold != last_gold:
		gold_bump = 1.0
		last_gold = gold
	var lever_target := 1.0 if spinning else 0.0
	lever_anim = lerpf(lever_anim, lever_target, clampf(delta * 10.0, 0.0, 1.0))
	if state == "win" or state == "lose":
		end_t += delta
	if spinning:
		_update_spin(dt)
	if state == "wave":
		_update_wave(dt)
	if state == "shop":
		shop_open_t += dt
	_update_fx(dt)
	queue_redraw()


func _update_fx(dt: float) -> void:
	var i := 0
	while i < floats.size():
		var f: Dictionary = floats[i]
		f.life = float(f.life) - dt
		f.pos.y = float(f.pos.y) - 26.0 * dt
		if float(f.life) <= 0.0:
			floats.remove_at(i)
		else:
			i += 1
	i = 0
	while i < particles.size():
		var p: Dictionary = particles[i]
		p.life = float(p.life) - dt
		p.pos += Vector2(p.vel) * dt
		p.vel = Vector2(p.vel) + Vector2(0, float(p.get("grav", 120.0))) * dt
		p.rot = float(p.get("rot", 0.0)) + float(p.get("spin", 0.0)) * dt
		if float(p.life) <= 0.0:
			particles.remove_at(i)
		else:
			i += 1
	i = 0
	while i < sparks.size():
		var s: Dictionary = sparks[i]
		s.life = float(s.life) - dt
		s.pos += Vector2(s.vel) * dt
		s.vel = Vector2(s.vel) * (1.0 - 3.5 * dt)
		if float(s.life) <= 0.0:
			sparks.remove_at(i)
		else:
			i += 1
	i = 0
	while i < projectiles.size():
		var pr: Dictionary = projectiles[i]
		pr.t = float(pr.t) + dt
		if float(pr.t) >= float(pr.dur):
			projectiles.remove_at(i)
		else:
			i += 1
	i = 0
	while i < slashes.size():
		var sl: Dictionary = slashes[i]
		sl.t = float(sl.t) + dt
		if float(sl.t) >= float(sl.dur):
			slashes.remove_at(i)
		else:
			i += 1
	i = 0
	while i < deaths.size():
		var d: Dictionary = deaths[i]
		d.t = float(d.t) + dt
		if float(d.t) >= float(d.dur):
			deaths.remove_at(i)
		else:
			i += 1


func _float(pos: Vector2, text: String, color: Color, size: int) -> void:
	if floats.size() > 60:
		floats.pop_front()
	floats.append({"pos": pos, "text": text, "color": color, "size": size, "life": 0.9})


func _burst(pos: Vector2, color: Color, count: int) -> void:
	if particles.size() > 300:
		return
	for i in count:
		var ang := TAU * float(i) / float(maxi(1, count)) + total_elapsed * 3.0
		var sp := 40.0 + float((i * 37) % 90)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang) - 0.5) * sp,
			"life": 0.35 + 0.25 * float(i % 4) / 3.0,
			"color": color,
			"size": 2.0 + float(i % 3),
			"grav": 120.0,
		})


func _spark(pos: Vector2, color: Color, count: int, dir: Vector2 = Vector2.RIGHT) -> void:
	if sparks.size() > 160:
		return
	for i in count:
		var ang := atan2(dir.y, dir.x) + randf_range(-0.9, 0.9)
		var sp := randf_range(90.0, 260.0)
		sparks.append({
			"pos": pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.12, 0.3),
			"dur": 0.3,
			"color": color,
			"len": randf_range(5.0, 13.0),
		})


func _projectile(kind: String, from: Vector2, to: Vector2, color: Color, dur: float = 0.16) -> void:
	if projectiles.size() > 24:
		return
	projectiles.append({"kind": kind, "from": from, "to": to, "t": 0.0, "dur": dur, "color": color})


func _slash(pos: Vector2, color: Color, size: float = 30.0, dir: float = 1.0) -> void:
	if slashes.size() > 20:
		return
	slashes.append({"pos": pos, "color": color, "t": 0.0, "dur": 0.18, "size": size, "dir": dir})


func _death(kind: String, type: String, x: float, color: Color) -> void:
	if deaths.size() > 24:
		deaths.pop_front()
	deaths.append({"kind": kind, "type": type, "x": x, "t": 0.0, "dur": 0.7, "color": color})


func _coin_burst(pos: Vector2, count: int) -> void:
	if particles.size() > 300:
		return
	for i in count:
		var ang := -PI * 0.5 + randf_range(-1.1, 1.1)
		var sp := randf_range(80.0, 220.0)
		particles.append({
			"pos": pos + Vector2(randf_range(-30, 30), randf_range(-10, 10)),
			"vel": Vector2(cos(ang), sin(ang)) * sp,
			"life": randf_range(0.5, 0.9),
			"color": C_BRASS,
			"size": 10.0,
			"grav": 260.0,
			"coin": true,
			"rot": randf_range(-0.5, 0.5),
			"spin": randf_range(-9.0, 9.0),
		})


func _confetti(count: int) -> void:
	if particles.size() > 320:
		return
	var palette := [C_MINT, C_CYAN, C_BRASS, C_ROSE, C_CREAM]
	for i in count:
		particles.append({
			"pos": Vector2(randf_range(300, 980), randf_range(-40, 120)),
			"vel": Vector2(randf_range(-30, 30), randf_range(30, 90)),
			"life": randf_range(2.0, 3.6),
			"color": palette[i % palette.size()],
			"size": 5.0,
			"grav": 22.0,
			"confetti": true,
			"rot": randf_range(0.0, TAU),
			"spin": randf_range(-6.0, 6.0),
		})


func _flash(color: Color, dur: float) -> void:
	flash_col = color
	flash_dur = maxf(0.01, dur)
	flash_t = flash_dur


func _show_banner(kind: String) -> void:
	banner_kind = kind
	banner_dur = 1.6 if kind != "boss" else 2.0
	banner_t = banner_dur


func _shake(time: float, mag: float) -> void:
	shake_t = maxf(shake_t, time)
	shake_mag = maxf(shake_mag, mag)


func _shake_offset() -> Vector2:
	if shake_t <= 0.0:
		return Vector2.ZERO
	var m := shake_mag * (shake_t / 0.4)
	return Vector2(sin(total_elapsed * 91.0) * m, cos(total_elapsed * 77.0) * m * 0.6)


# ---------------------------------------------------------------------------
# Debug hooks (smoke test / screenshots)
# ---------------------------------------------------------------------------

func debug_tick(seconds: float, step: float = 0.05) -> void:
	var t := 0.0
	while t < seconds:
		_process(step)
		t += step


func debug_add_gold(n: int) -> void:
	gold += n


func debug_set_hearts(n: int) -> void:
	hearts = clampi(n, 0, MAX_HEARTS)


func debug_summon(symbol: String) -> void:
	summon(symbol)


func debug_apply_result(res: Dictionary) -> void:
	_apply_slot_result(res)


func debug_clear_wave() -> void:
	spawn_queue.clear()
	enemies.clear()


func debug_kill_all_enemies() -> void:
	for e in enemies:
		_death("enemy", String(e.type), float(e.x), _enemy_color(String(e.type)))
		if e.type == "boss":
			boss_alive = false
			boss_killed = true
			victory_t = 1.6
			spawn_queue.clear()
			_death("boss", "boss", float(e.x), Color("#ff4f8b"))
			_flash(Color(1.0, 0.95, 0.85), 0.45)
			_confetti(36)
			_shake(0.6, 12.0)
	enemies.clear()


func debug_spawn(type: String) -> void:
	_spawn_enemy(type)


func debug_start_wave(index: int) -> void:
	enemies.clear()
	spawn_queue.clear()
	start_wave(index)


func debug_start_boss() -> void:
	enemies.clear()
	spawn_queue.clear()
	start_wave(6)
	spawn_queue.clear()
	_spawn_enemy("boss")


func debug_open_shop() -> void:
	open_shop()


func debug_buy(index: int) -> bool:
	return buy_offer(index)


func debug_apply_item(id: String) -> void:
	_apply_item(id)


func debug_force_win() -> void:
	_win()


func debug_force_lose() -> void:
	hearts = 0
	_lose()


# Presentation-only cleanup used by the screenshot / GIF tools between beats.
func _clear_present_fx() -> void:
	particles.clear()
	sparks.clear()
	floats.clear()
	deaths.clear()
	projectiles.clear()
	slashes.clear()
	flash_t = 0.0
	shake_t = 0.0
	shake_mag = 0.0


# ---------------------------------------------------------------------------
# Drawing — background, cabinet, reels, HUD
# ---------------------------------------------------------------------------

const IDLE_GRID := [
	["bow", "crown", "blade"],
	["shield", "orb", "steed"],
	["blade", "bow", "crown"],
]


func _draw() -> void:
	var shake := _shake_offset()
	_draw_sky()
	_draw_battle_bg()
	_draw_cabinet()
	_draw_reels()
	_draw_controls()
	_draw_battle_world(shake)
	_draw_fx()
	draw_texture_rect(vignette_tex, BATTLE, false)
	_draw_battle_ui(shake)
	_draw_hud()
	_draw_bottom()
	_draw_banner()
	if state == "shop":
		_draw_shop()
	elif state == "win":
		_draw_end(true)
	elif state == "lose":
		_draw_end(false)
	_draw_flash()


func _rect(r: Rect2, color: Color) -> void:
	draw_rect(r, color)


func _frame(r: Rect2, color: Color, width: float = 2.0) -> void:
	draw_rect(r, color, false, width)


func _text(pos: Vector2, text: String, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	if size >= 14:
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			maxi(1, int(round(size / 12.0))), Color(0.02, 0.01, 0.05, 0.82))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_c(cx: float, baseline_y: float, text: String, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(cx - w * 0.5, baseline_y), text, size, color, f)


func _text_glow(cx: float, baseline_y: float, text: String, size: int, color: Color, glow: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font_display
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(cx - w * 0.5, baseline_y)
	draw_texture_rect(glow_tex, Rect2(cx - w * 0.8, baseline_y - size * 0.9, w * 1.6, size * 1.5), false,
		Color(glow.r, glow.g, glow.b, 0.16))
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		maxi(1, int(round(size / 14.0))), Color(0.03, 0.02, 0.06, 0.9))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_glow(center: Vector2, size: float, color: Color, alpha: float) -> void:
	draw_texture_rect(glow_tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false,
		Color(color.r, color.g, color.b, alpha))


func _draw_diamond(center: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -r), center + Vector2(r, 0),
		center + Vector2(0, r), center + Vector2(-r, 0),
	]), color)


func _atmo() -> Color:
	if state == "shop":
		return Color(1.0, 0.84, 0.62)
	if state == "win":
		return Color(0.70, 1.0, 0.92)
	if state == "lose":
		return Color(1.0, 0.52, 0.58)
	if wave == MAX_WAVE or boss_alive:
		return Color(1.0, 0.58, 0.50)
	match wave:
		2:
			return Color(0.74, 1.0, 0.90)
		3:
			return Color(0.90, 0.74, 1.0)
		4:
			return Color(1.0, 0.84, 0.66)
		5:
			return Color(1.0, 0.72, 0.80)
	return Color(0.78, 0.92, 1.0)


func _draw_sky() -> void:
	var atmo := _atmo()
	_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color("#05050c"))
	# The baked page sky is only visible in the thin margins around the
	# cabinet and battle frames; draw just those regions instead of a full quad.
	var regions := [
		Rect2(0, 56, 20, 612),
		Rect2(600, 70, 16, 596),
		Rect2(1256, 56, 24, 612),
		Rect2(0, 56, 1280, 14),
		Rect2(0, 666, 1280, 2),
	]
	for r in regions:
		var src := Rect2(
			r.position.x / VIEW.x * 640.0, r.position.y / VIEW.y * 360.0,
			r.size.x / VIEW.x * 640.0, r.size.y / VIEW.y * 360.0)
		draw_texture_rect_region(page_sky_tex, r, src, Color(atmo.r, atmo.g, atmo.b, 1.0))
	# twelve live twinkles over the baked star field
	for i in 12:
		var s: Dictionary = stars[i % stars.size()]
		var sp: Vector2 = s.pos + Vector2(616, 70)
		var tw := 0.55 + 0.45 * sin(total_elapsed * 1.6 + sp.x * 0.05)
		var sz: float = s.s
		draw_rect(Rect2(sp, Vector2(sz, sz)), Color(1.0, 0.93, 0.82, s.a * tw * 0.8))


func _draw_battle_bg() -> void:
	var atmo := _atmo()
	var bx := BATTLE.position.x
	var by := BATTLE.position.y
	var t := total_elapsed
	# baked sky (gradient, nebula, aurora, stars, moon)
	draw_texture_rect(backdrop["sky"], Rect2(bx, by, 640, 490), false, Color(atmo.r, atmo.g, atmo.b, 1.0))
	# pulsing moon halo
	var moon := Vector2(1140, 166)
	var pulse := 0.85 + 0.15 * sin(t * 1.3)
	_draw_glow(moon, 260.0 * pulse, Color("#ffe9b8"), 0.10)
	_draw_glow(moon, 150.0 * pulse, Color("#fff3cf"), 0.14)
	# parallax clouds
	var far_x := bx + sin(t * 0.030) * 14.0
	var near_x := bx + sin(t * 0.047 + 1.7) * 22.0
	draw_texture_rect(backdrop["clouds_far"], Rect2(far_x, by + 14, 640, 240), false,
		Color(atmo.r, atmo.g, atmo.b, 0.9))
	draw_texture_rect(backdrop["clouds_near"], Rect2(near_x, by + 82, 640, 240), false,
		Color(atmo.r, atmo.g, atmo.b, 0.85))
	# moonlight shafts
	var beam := 0.040 + 0.014 * sin(t * 0.7)
	draw_colored_polygon(PackedVector2Array([
		Vector2(1122, 190), Vector2(1170, 176), Vector2(1080, 560), Vector2(940, 560),
	]), Color(atmo.r, atmo.g, atmo.b, beam))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1138, 196), Vector2(1160, 188), Vector2(1200, 560), Vector2(1120, 560),
	]), Color(1.0, 0.94, 0.8, beam * 0.8))
	draw_colored_polygon(PackedVector2Array([
		Vector2(1146, 184), Vector2(1152, 182), Vector2(1066, 560), Vector2(1020, 560),
	]), Color(1.0, 0.9, 0.7, beam * 0.35))
	# shooting star
	var cyc := fmod(t, 6.5)
	if cyc < 0.7:
		var p := cyc / 0.7
		var start := Vector2(bx + 40.0 + p * 260.0, by + 34.0 + p * 62.0)
		var streak := start + Vector2(64.0, 24.0) * (0.4 + p * 0.6)
		draw_line(start, streak, Color(1.0, 0.95, 0.8, 0.5 * (1.0 - p)), 2.0)
		draw_line(start, streak, Color(1.0, 1.0, 1.0, 0.14 * (1.0 - p)), 6.0)
	# mountains / temple / ruins
	draw_texture_rect(backdrop["mountains"], Rect2(bx + sin(t * 0.012) * 5.0, by + 250, 640, 240), false,
		Color(atmo.r, atmo.g, atmo.b, 1.0))
	draw_texture_rect(backdrop["temple"], Rect2(bx + sin(t * 0.016) * 2.0, by + 130, 640, 360), false,
		Color(atmo.r, atmo.g, atmo.b, 1.0))
	# flickering temple windows (positions mirror reel_art._temple_image)
	for i in 4:
		var wy := 200.0 + (82.0 + i * 20.0) * 2.0
		var flick := 0.7 + 0.3 * sin(t * 5.0 + i * 1.7)
		_draw_glow(Vector2(736, wy), 26.0, Color("#ffcf8a"), 0.10 * flick)
		_draw_glow(Vector2(1134, wy), 26.0, Color("#62e6d6"), 0.10 * flick)
	# central doorway glow
	_draw_glow(Vector2(938, 500), 90.0, Color("#62e6d6"), 0.10 + 0.03 * sin(t * 2.0))
	draw_texture_rect(backdrop["ruins"], Rect2(bx, by + 270, 640, 220), false,
		Color(atmo.r, atmo.g, atmo.b, 1.0))
	draw_texture_rect(backdrop["ground"], Rect2(bx, GROUND_Y, 640, 160), false,
		Color(atmo.r * 1.02, atmo.g * 1.02, atmo.b * 1.02, 1.0))
	# animated rune glints on the flagstones
	for i in 4:
		var rp := Vector2(bx + 120.0 + i * 132.0, GROUND_Y + 30.0 + (i % 2) * 24.0)
		var flick := 0.5 + 0.5 * sin(t * 3.0 + i * 1.9)
		_draw_glow(rp, 28.0, C_CYAN, 0.08 * flick)
		_draw_diamond(rp, 2.5, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.30 + 0.35 * flick))
	# drifting fog
	var fog_x := bx + sin(t * 0.12) * 20.0
	draw_texture_rect(backdrop["fog"], Rect2(fog_x, GROUND_Y - 74, 640, 96), false,
		Color(atmo.r, atmo.g, atmo.b, 0.46))
	# floating dust motes
	for i in 16:
		var mx := bx + fmod(float(i) * 97.0 + t * (7.0 + i % 5), 640.0)
		var my := by + 60.0 + fmod(float(i) * 53.0 + t * (4.0 + i % 4), 460.0)
		var a := 0.16 + 0.18 * sin(t * 2.0 + i * 2.1)
		draw_rect(Rect2(Vector2(mx, my), Vector2(2, 2)), Color(atmo.r, atmo.g, atmo.b, a))
	# boss embers
	if wave == MAX_WAVE or boss_alive:
		for i in 12:
			var ex := bx + fmod(float(i) * 131.0 + t * (14.0 + i % 6), 640.0)
			var ey := by + 420.0 - fmod(float(i) * 37.0 + t * (20.0 + i % 8), 380.0)
			var ea := 0.35 + 0.3 * sin(t * 4.0 + i)
			draw_rect(Rect2(Vector2(ex, ey), Vector2(2, 3)), Color(1.0, 0.55, 0.28, ea))


func _draw_cabinet() -> void:
	var atmo := _atmo()
	# one baked quad for all static chrome
	draw_texture_rect(cabinet_tex, CABINET, false)
	# chase bulbs: a sparse subset is animated over the baked sockets
	for i in 20:
		if i % 2 != 0:
			continue
		var bx := 76.0 + i * 22.0
		var on := fmod(total_elapsed * 2.2 + float(i) * 0.37, 1.0) > 0.45
		if not on:
			continue
		var col := C_BRASS_L
		if i % 4 == 0:
			col = C_CYAN
		draw_circle(Vector2(bx, 87), 2.4, col)
		draw_circle(Vector2(bx, 131), 2.4, col)
	# marquee title
	_text_glow(310, 119, "转 运 轮 盘", 24, Color("#ffe9c7"), Color(1.0, 0.78, 0.35), _font_display)
	_text(Vector2(54, 117), "3×3", 11, C_DIM2, _font_mono)
	_text(Vector2(512, 117), "8 LINES", 10, Color(0.55, 0.8, 0.95, 0.85), _font_mono)
	_draw_diamond(Vector2(62, 111), 3.5, C_BRASS)
	_draw_diamond(Vector2(558, 111), 3.5, C_CYAN)
	# payline lamps: only lit lines are drawn, sockets stay baked
	var lit_lines := highlight_lines.size() if highlight_t > 0.0 else 0
	for i in mini(8, lit_lines):
		var ly := 172.0 + i * 22.0
		_draw_glow(Vector2(88, ly), 26.0, C_BRASS, 0.35)
		_draw_diamond(Vector2(88, ly), 4.0, C_BRASS_L)
	# caption
	var caption := "SYMBOLS LOCKED"
	if spinning:
		caption = "SPINNING…"
	elif not spin_result.is_empty():
		caption = "%d 线 · +%d g" % [spin_result.get("lines", []).size(), int(spin_result.get("payout", 0))]
	_text_c(312, 563, caption, 11, Color(atmo.r, atmo.g, atmo.b, 0.85), _font_mono)
	_draw_diamond(Vector2(310, 658), 5.0, Color(atmo.r * 0.8, atmo.g * 0.8, atmo.b * 0.8))


func _draw_reels() -> void:
	var atmo := _atmo()
	var grid := spin_grid
	if grid.is_empty():
		grid = IDLE_GRID
	# one baked quad for all nine cell backplates, plus one broad bay bloom
	_draw_glow(Vector2(312, 348), 540.0, Color("#6c4bb8"), 0.07)
	draw_texture_rect(reel_cells_tex, Rect2(104, 144, 416, 408), false)
	for c in 3:
		for r in 3:
			var cell_rect := Rect2(
				REEL_X + c * CELL_PITCH, REEL_Y + r * CELL_PITCH, CELL, CELL)
			var symbol: String = grid[r][c]
			var rolling := spinning and c >= settled_cols
			var center := cell_rect.position + Vector2(CELL * 0.5, CELL * 0.5)
			var icon_size := 96.0
			var wob := 0.0
			var alpha := 1.0
			if rolling:
				var idx := int(spin_t * 44.0 + c * 7.0 + r * 3.0) % SlotLogic.SYMBOLS.size()
				symbol = SlotLogic.SYMBOLS[idx]
				wob = sin(spin_t * 52.0 + c * 2.1 + r * 1.7) * 9.0
				alpha = 0.82
				# vertical motion ghosts
				for ghop in [-22.0, 22.0]:
					var gtex: Texture2D = symbol_tex[symbol]
					draw_texture_rect(gtex,
						Rect2(center - Vector2(32, 32) + Vector2(0, wob + ghop), Vector2(64, 64)),
						false, Color(1, 1, 1, 0.10))
				_rect(Rect2(cell_rect.position, Vector2(CELL, 7)), Color(0, 0, 0, 0.28))
				_rect(Rect2(cell_rect.position.x, cell_rect.end.y - 7, CELL, 7), Color(0, 0, 0, 0.28))
				# motion blur streaks
				for k in 3:
					var sx := cell_rect.position.x + 16.0 + fmod(float(k) * 37.0 + spin_t * 90.0, 84.0)
					var sh := 18.0 + 28.0 * absf(sin(spin_t * 30.0 + k))
					_rect(Rect2(sx, center.y - sh * 0.5, 2, sh), Color(1, 1, 1, 0.055))
			# settle bounce + stop flash
			var since_stop := spin_t - float(col_stop_t[c])
			if not rolling and since_stop >= 0.0 and since_stop < 0.30:
				var bp := since_stop / 0.30
				wob = -sin(bp * PI) * 8.0 * (1.0 - bp)
				_rect(cell_rect, Color(1.0, 0.85, 0.5, 0.10 * (1.0 - bp)))
			# rarity gem + glow
			var sym_col := ReelArt.symbol_color(symbol)
			var glow_a := 0.0
			for line in highlight_lines:
				for p in line.cells:
					if p == Vector2i(c, r) and highlight_t > 0.0:
						glow_a = 0.42 + 0.10 * sin(total_elapsed * 18.0)
			if glow_a > 0.0:
				_draw_glow(center + Vector2(0, wob), 104.0, sym_col, glow_a)
			_draw_diamond(cell_rect.position + Vector2(11, 11), 3.5, sym_col)
			_rect(Rect2(cell_rect.position + Vector2(6, CELL - 8), Vector2(CELL - 12, 2)), Color(0, 0, 0, 0.3))
			var tex: Texture2D = symbol_tex[symbol]
			draw_texture_rect(tex,
				Rect2(center - Vector2(icon_size, icon_size) * 0.5 + Vector2(0, wob), Vector2(icon_size, icon_size)),
				false, Color(alpha, alpha, alpha, alpha))
			# inner corner ticks
			_rect(Rect2(cell_rect.position + Vector2(6, 6), Vector2(6, 1)), Color(1, 1, 1, 0.10))
			_rect(Rect2(cell_rect.position + Vector2(6, 6), Vector2(1, 6)), Color(1, 1, 1, 0.10))
	if highlight_t > 0.0 and not highlight_lines.is_empty():
		var pulse := 0.35 + 0.3 * sin(total_elapsed * 18.0)
		var seen := {}
		for line in highlight_lines:
			for p in line.cells:
				var key: Vector2i = p
				if seen.has(key):
					continue
				seen[key] = true
				var cr := Rect2(REEL_X + p.x * CELL_PITCH, REEL_Y + p.y * CELL_PITCH, CELL, CELL)
				_rect(cr, Color(1.0, 0.82, 0.35, 0.08 + pulse * 0.08))
				_frame(cr.grow(-1.0), Color(1.0, 0.82, 0.35, 0.5 + pulse * 0.45), 3.0)
		for line in highlight_lines:
			var pts: PackedVector2Array = []
			for p in line.cells:
				pts.append(Vector2(
					REEL_X + p.x * CELL_PITCH + CELL * 0.5,
					REEL_Y + p.y * CELL_PITCH + CELL * 0.5))
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i + 1], Color(1.0, 0.82, 0.35, 0.15), 7.0)
				draw_line(pts[i], pts[i + 1], Color(1.0, 0.82, 0.35, 0.65 + pulse * 0.3), 2.0)
			# travelling spark
			var prog := fmod(total_elapsed * 1.1, 1.0)
			var seg := mini(1, int(prog * 2.0))
			var local := fmod(prog * 2.0, 1.0)
			var dot := pts[seg].lerp(pts[mini(2, seg + 1)], local)
			_draw_glow(dot, 34.0, C_BRASS_L, 0.7)
			draw_circle(dot, 2.5, C_CREAM)
	# glass reflections over the symbol faces
	draw_colored_polygon(PackedVector2Array([
		Vector2(112, 150), Vector2(238, 150), Vector2(160, 546), Vector2(112, 546),
	]), Color(0.75, 0.85, 1.0, 0.022))
	draw_colored_polygon(PackedVector2Array([
		Vector2(404, 150), Vector2(432, 150), Vector2(502, 546), Vector2(468, 546),
	]), Color(1.0, 0.95, 0.85, 0.016))
	# glass glare sweep during a spin
	if spinning:
		var sweep := fmod(spin_t * 0.9, 1.4) - 0.2
		var sx := 104.0 + sweep * 416.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, 144), Vector2(sx + 34, 144), Vector2(sx - 46, 552), Vector2(sx - 80, 552),
		]), Color(1, 1, 1, 0.035))
	_rect(Rect2(104, 552, 416, 2), Color(atmo.r, atmo.g, atmo.b, 0.12))


func _draw_controls() -> void:
	var atmo := _atmo()
	var can_spin := not spinning and (state == "idle" or state == "wave") and gold >= spin_cost
	var hover := SPIN_BTN.has_point(get_local_mouse_position())
	var btn := SPIN_BTN
	var y_off := 3.0 if spinning else 0.0
	if hover and can_spin:
		y_off = -1.5
	if spin_press > 0.0:
		y_off += 2.0
	var br := Rect2(btn.position + Vector2(0, y_off), btn.size)
	# outer glow when ready
	if can_spin:
		_draw_glow(br.get_center(), 380.0, C_BRASS, 0.10 + 0.04 * sin(total_elapsed * 3.0))
	# one baked quad per button state
	_rect(Rect2(btn.position + Vector2(0, 6), btn.size), Color(0, 0, 0, 0.5))
	draw_texture_rect(spin_ready_tex if can_spin else spin_off_tex, br, false)
	if spin_press > 0.0:
		_rect(br, Color(1, 1, 1, 0.10 * spin_press / 0.18))
	# shine sweep
	if can_spin:
		var sw := fmod(total_elapsed * 0.33, 1.6) - 0.3
		var shine_x := br.position.x + sw * br.size.x
		if shine_x > br.position.x and shine_x < br.end.x - 10.0:
			_rect(Rect2(shine_x, br.position.y + 3, 10, br.size.y - 6), Color(1, 1, 1, 0.10))
	var label := "SPIN  -%d g" % spin_cost
	if spinning:
		label = "SPINNING" + ".".repeat(1 + int(total_elapsed * 4.0) % 3)
	elif state == "shop":
		label = "商店中 · SHOP"
	elif state == "win" or state == "lose":
		label = "按 R 重开"
	_text_c(br.position.x + br.size.x * 0.5, br.position.y + 31, label, 19,
		C_VOID if can_spin else C_DIM, _font_display)
	# lever arm (base plate is baked into the cabinet shell)
	var pivot := Vector2(548, 508)
	var wobble := 0.06 * sin(total_elapsed * 3.0) if can_spin else 0.0
	var angle := -0.26 + lever_anim * 0.86 + wobble + sin(total_elapsed * 22.0) * 0.04 * lever_anim
	var knob := pivot + Vector2(sin(angle), -cos(angle)) * 92.0
	# motion arc trail
	if lever_anim > 0.05:
		for i in 4:
			var ta := -0.26 + lever_anim * 0.86 * (0.6 + i * 0.1)
			var tp := pivot + Vector2(sin(ta), -cos(ta)) * 92.0
			draw_circle(tp, 8.0 - i * 1.5, Color(1.0, 0.85, 0.5, 0.04 + i * 0.01))
	draw_line(pivot, knob, Color("#2a1a12"), 12.0)
	draw_line(pivot + Vector2(1, 1), knob + Vector2(1, 1), C_BRASS, 7.0)
	draw_line(pivot + Vector2(-1, 0), knob + Vector2(-1, 0), C_BRASS_L, 2.0)
	draw_circle(knob, 20.0, Color("#4a2a10"))
	draw_circle(knob, 17.0, Color("#a86a24"))
	draw_circle(knob, 14.0, C_BRASS)
	draw_circle(knob - Vector2(3, 3), 7.0, Color("#ffe7b3"))
	draw_circle(knob - Vector2(5, 5), 2.5, Color("#fff8dd"))
	draw_circle(pivot, 8.0, C_BRASS_DK)
	draw_circle(pivot, 4.5, C_BRASS)
	# odds strip
	_text(Vector2(48, 633), "ODDS", 9, C_DIM2, _font_mono)
	for i in SlotLogic.SYMBOLS.size():
		var s: String = SlotLogic.SYMBOLS[i]
		var x := 50.0 + i * 87.0
		var w := int(slot.weights.get(s, 0))
		var tex: Texture2D = symbol_tex[s]
		draw_texture_rect(tex, Rect2(x + 18, 618, 18, 18), false)
		_text(Vector2(x + 40, 632), str(w), 11, C_CREAM, _font_mono)
		_rect(Rect2(x + 18, 639, 40.0 * clampf(float(w) / 30.0, 0.0, 1.0), 2), ReelArt.symbol_color(s))
	_draw_diamond(Vector2(310, 628), 3.0, Color(atmo.r, atmo.g, atmo.b, 0.5))


func _draw_hud() -> void:
	var atmo := _atmo()
	# bar body
	for i in 4:
		_rect(Rect2(0, i * 14, VIEW.x, 15), Color("#0b0813").lerp(Color("#171026"), float(i) / 3.0))
	_rect(Rect2(0, TOP_H - 3, VIEW.x, 3), C_BRASS_DK)
	_rect(Rect2(0, TOP_H - 3, VIEW.x, 1), C_BRASS)
	_rect(Rect2(0, 0, VIEW.x, 1), Color(1, 1, 1, 0.05))
	# brand
	_text(Vector2(24, 38), "REELWARD", 26, C_CREAM, _font_display)
	draw_circle(Vector2(17, 30), 3.0, C_CYAN)
	_text(Vector2(182, 37), "转轮守卫", 14, C_BRASS)
	_draw_diamond(Vector2(268, 30), 3.0, C_BRASS_DK)
	# hearts (one baked strip normally; per-heart pulse only at low health)
	var low := hearts <= 2
	if not low:
		draw_texture_rect(heart_strips[hearts], Rect2(342, 15, 208, 24), false)
	else:
		var beat := 1.0 + 0.06 * sin(total_elapsed * 6.0)
		for i in MAX_HEARTS:
			var full := i < hearts
			var tex: Texture2D = heart_tex["full"] if full else heart_tex["empty"]
			var hs := Vector2(28, 24) * (beat if full else 1.0)
			var hp := Vector2(356 + i * 30 - hs.x * 0.5, 15 + (24 - hs.y) * 0.5)
			if full:
				_draw_glow(hp + hs * 0.5, 40.0, C_RED, 0.16 + 0.06 * sin(total_elapsed * 6.0))
			draw_texture_rect(tex, Rect2(hp, hs), false)
	# gold
	_draw_glow(Vector2(588, 28), 54.0, C_BRASS, 0.10)
	draw_texture_rect(coin_tex, Rect2(574, 16, 26, 26), false)
	var gsize := 19 + int(round(gold_bump * 3.0))
	_text(Vector2(608, 37), str(gold), gsize, C_CREAM, _font_mono)
	# wave pips
	for i in MAX_WAVE:
		var c := Color("#33243f")
		if i < wave:
			c = C_RED if i == MAX_WAVE - 1 else C_CYAN
		if i == wave and state == "wave":
			c = Color(1, 1, 1, 0.7 + 0.3 * sin(total_elapsed * 5.0))
		_draw_diamond(Vector2(712 + i * 14, 19), 4.0, c)
	var wave_txt := "WAVE %d/%d" % [wave, MAX_WAVE]
	if wave == 0:
		wave_txt = "WAVE -/%d" % MAX_WAVE
	_text(Vector2(700, 44), wave_txt, 12, C_MINT if wave > 0 else C_DIM, _font_mono)
	_text(Vector2(850, 35), "SEED %d" % seed_value, 11, C_DIM2, _font_mono)
	# speed chip
	var chip := Rect2(1076, 14, 126, 29)
	_rect(Rect2(chip.position + Vector2(0, 3), chip.size), Color(0, 0, 0, 0.35))
	_rect(chip, Color("#1c1530"))
	_frame(chip, C_CYAN if speed > 1.5 else C_BRASS_DK, 1.5)
	if speed > 1.5:
		_draw_glow(chip.get_center(), 120.0, C_CYAN, 0.10 + 0.04 * sin(total_elapsed * 4.0))
	_text_c(chip.position.x + chip.size.x * 0.5, chip.position.y + 20, "x%d  [F]" % int(speed), 13,
		C_CYAN if speed > 1.5 else C_CREAM, _font_mono)
	# thin accent underline
	_rect(Rect2(0, TOP_H, VIEW.x, 1), Color(atmo.r, atmo.g, atmo.b, 0.12))


func _draw_bottom() -> void:
	_rect(Rect2(0, 668, VIEW.x, 52), Color("#0b0813"))
	_rect(Rect2(0, 668, VIEW.x, 2), C_BRASS_DK)
	_rect(Rect2(0, 669, VIEW.x, 1), Color(1, 1, 1, 0.04))
	var items := [
		["SPACE", "拉杆"],
		["1-3", "购买"],
		["E", "重摇"],
		["F", "倍速"],
		["R", "重开"],
	]
	var widths: Array[float] = []
	var total := 0.0
	for it in items:
		var kw := _font_mono.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14.0
		var lw := _font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		widths.append(kw + 6.0 + lw)
		total += kw + 6.0 + lw + 26.0
	var x := 640.0 - (total - 26.0) * 0.5
	for i in items.size():
		var kw := widths[i] - _font.get_string_size(items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x - 6.0
		var kr := Rect2(x, 682, kw, 22)
		_rect(Rect2(kr.position + Vector2(0, 2), kr.size), Color(0, 0, 0, 0.4))
		_rect(kr, Color("#1c1530"))
		_frame(kr, C_BRASS_DK, 1.0)
		_text_c(kr.get_center().x, 697, items[i][0], 10, C_CREAM, _font_mono)
		_text(Vector2(x + kw + 6.0, 698), items[i][1], 12, C_DIM)
		x += widths[i] + 26.0
	_text_c(640, 712, "守 住 城 门 · 转 动 命 运", 10, Color(0.45, 0.38, 0.58, 0.8), _font_mono)


# ---------------------------------------------------------------------------
# Drawing — battlefield, units, enemies, FX
# ---------------------------------------------------------------------------

func _draw_battle_world(shake: Vector2) -> void:
	_draw_gate(shake)
	for u in units:
		_draw_unit(u, shake)
	for e in enemies:
		_draw_enemy(e, shake)
	_draw_deaths(shake)
	_draw_projectiles(shake)
	for sl in slashes:
		var p := float(sl.t) / float(sl.dur)
		var a := (1.0 - p) * 0.9
		var pos: Vector2 = sl.pos + shake
		var ang := -0.9 * float(sl.dir)
		var col: Color = sl.color
		draw_arc(pos, float(sl.size) * (0.7 + p * 0.5), ang - 0.8, ang + 0.8, 9,
			Color(col.r, col.g, col.b, a * 0.35), 5.0)
		draw_arc(pos, float(sl.size) * (0.7 + p * 0.5), ang - 0.8, ang + 0.8, 9,
			Color(1, 1, 1, a * 0.8), 1.5)


func _draw_battle_ui(shake: Vector2) -> void:
	var atmo := _atmo()
	# frame
	_frame(Rect2(BATTLE.position + Vector2(-3, -3), BATTLE.size + Vector2(6, 6)), C_BRASS_DK, 3.0)
	_frame(Rect2(BATTLE.position + Vector2(-1, -1), BATTLE.size + Vector2(2, 2)), C_BRASS, 1.0)
	# wave tag
	var tag := Rect2(630, 84, 150, 28)
	_rect(tag, Color(0.04, 0.03, 0.08, 0.7))
	_frame(tag, Color(atmo.r, atmo.g, atmo.b, 0.5), 1.0)
	_rect(Rect2(tag.position, Vector2(4, tag.size.y)), atmo)
	_text(Vector2(642, 103), "WAVE %d" % wave if wave > 0 else "WAVE --", 15,
		atmo, _font_display)
	if state == "wave" and wave > 0:
		var left := spawn_queue.size() + enemies.size()
		_text(Vector2(640, 126), "剩余 %d" % left, 11, C_DIM, _font_mono)
	# boss bar
	if boss_alive and boss_max_hp > 0.0:
		var ratio := 1.0
		for e in enemies:
			if e.type == "boss":
				ratio = clampf(float(e.hp) / boss_max_hp, 0.0, 1.0)
		var bar := Rect2(786, 84, 424, 40)
		_rect(Rect2(bar.position + Vector2(0, 3), bar.size), Color(0, 0, 0, 0.5))
		_rect(bar, Color(0.06, 0.025, 0.07, 0.82))
		_frame(bar, C_BRASS_DK, 1.5)
		_rect(Rect2(bar.position, Vector2(4, bar.size.y)), C_RED)
		_text(Vector2(798, 100), "齿轮暴君", 14, C_CREAM, _font_display)
		_text(Vector2(898, 99), "GEAR TYRANT", 9, Color("#ff8fa8"), _font_mono)
		_text(Vector2(1148, 99), "%d%%" % int(round(ratio * 100.0)), 10, C_CREAM, _font_mono)
		var track := Rect2(798, 106, 400, 9)
		_rect(track, Color("#1c0c18"))
		var fill := Rect2(track.position, Vector2(track.size.x * ratio, track.size.y))
		_rect(fill, Color("#e2395c"))
		_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), Color("#ff8fa8"))
		_rect(Rect2(fill.position.x, fill.end.y - 2, fill.size.x, 2), Color("#8a1430"))
		for i in 10:
			_rect(Rect2(track.position.x + i * 40 - 1, track.position.y, 1, track.size.y), Color(0, 0, 0, 0.28))
		_frame(track, Color("#5a2438"), 1.0)
		_draw_glow(Vector2(798 + 400 * ratio, 110), 36.0, Color("#ff4f6e"), 0.5)
	# boss intro stamp
	if boss_intro_t > 0.0:
		var p := 1.0 - boss_intro_t / 2.2
		var a := minf(1.0, p * 5.0) * minf(1.0, (1.0 - p) * 4.0)
		draw_texture_rect(vignette_tex, BATTLE, false, Color(1.0, 0.1, 0.15, 0.35 * a))
		_text_c(936, 188, "BOSS INCOMING", 18, Color(1.0, 0.45, 0.45, a), _font_display)
		_text_c(936, 208, "齿轮暴君 · 突破城门", 11, Color(1.0, 0.75, 0.7, a), _font_mono)
	# hints
	if state == "idle" and not spinning:
		_draw_glow(Vector2(936, 260), 320.0, Color(atmo.r, atmo.g, atmo.b), 0.05)
		_text_glow(936, 296, "按 SPACE 转动命运", 26, C_CREAM, Color(atmo.r, atmo.g, atmo.b))
		_text_c(936, 326, "3 连 = 召唤守卫 · 2 连 = 金币", 14, C_DIM)
		_text_c(936, 350, "7 颗心 · 6 波 · 1 个 Boss", 12, Color(0.8, 0.72, 0.95, 0.7))
	if wave_clear_t > 0.0:
		_text_glow(936, 300, "WAVE CLEAR", 28, C_MINT, C_MINT)
		_text_c(936, 326, "进入商店…", 14, C_DIM)


func _draw_gate(shake: Vector2) -> void:
	var gx := 640.0 + shake.x
	var gy := GROUND_Y + shake.y
	var atmo := _atmo()
	# shadow + plinth
	_rect(Rect2(gx - 34, gy - 6, 68, 10), Color(0, 0, 0, 0.35))
	_rect(Rect2(gx - 30, gy - 12, 60, 12), Color("#241a33"))
	_rect(Rect2(gx - 30, gy - 12, 60, 2), Color("#4a395e"))
	# pillars
	for px in [-30.0, 18.0]:
		var pr := Rect2(gx + px, gy - 168, 12, 156)
		_rect(Rect2(pr.position + Vector2(2, 2), pr.size), Color(0, 0, 0, 0.35))
		_rect(pr, Color("#33254a"))
		_rect(Rect2(pr.position, Vector2(3, pr.size.y)), Color("#4f3a6c"))
		_rect(Rect2(pr.position.x + pr.size.x - 2, pr.position.y, 2, pr.size.y), Color("#1b1428"))
		_rect(Rect2(pr.position.x - 2, pr.position.y + 4, pr.size.x + 4, 4), Color("#221834"))
		_rect(Rect2(pr.position.x - 2, pr.position.y + 12, pr.size.x + 4, 3), Color("#2c2040"))
	# lintel + crenellations
	_rect(Rect2(gx - 38, gy - 184, 76, 20), Color("#2b1f3d"))
	_rect(Rect2(gx - 38, gy - 184, 76, 2), Color("#5a4278"))
	for i in 5:
		_rect(Rect2(gx - 36 + i * 15, gy - 194, 9, 10), Color("#241a33"))
		_rect(Rect2(gx - 36 + i * 15, gy - 194, 9, 2), Color("#3f2e5a"))
	# arch
	for i in 7:
		var a := PI + PI * float(i) / 6.0
		var ax := gx + cos(a) * 27.0
		var ay := gy - 164 + sin(a) * 27.0
		_rect(Rect2(ax - 5, ay - 4, 10, 9), Color("#3a2a52"))
		_rect(Rect2(ax - 5, ay - 4, 10, 2), Color("#5a4278"))
	# opening
	_rect(Rect2(gx - 24, gy - 158, 48, 158), Color("#090510"))
	for i in 10:
		_rect(Rect2(gx - 24, gy - 158 + i * 16, 48, 16), Color(0.06, 0.03, 0.09, 0.10 + i * 0.006))
	# glowing heart niche
	_draw_glow(Vector2(gx, gy - 118), 150.0, C_RED, 0.14 + 0.04 * sin(total_elapsed * 3.0))
	_rect(Rect2(gx - 26, gy - 128, 52, 4), C_BRASS_DK)
	_rect(Rect2(gx - 22, gy - 126, 44, 36), Color("#4a1830"))
	_frame(Rect2(gx - 22, gy - 126, 44, 36), Color("#7a2a46"), 1.5)
	var hs := 40.0 if hearts > 2 else 42.0 + sin(total_elapsed * 6.0) * 2.0
	var tex: Texture2D = heart_tex["full"] if hearts > 0 else heart_tex["empty"]
	draw_texture_rect(tex, Rect2(gx - hs * 0.5, gy - 120, hs, hs * 0.875), false)
	_text_c(gx, gy - 82, "%d / %d" % [hearts, MAX_HEARTS], 12, C_CREAM, _font_mono)
	# runes + lanterns
	for i in 4:
		var rx := gx - 20 + i * 13
		_px_runes(Vector2(rx, gy - 174), atmo)
	var flick := 0.75 + 0.25 * sin(total_elapsed * 6.3)
	_draw_glow(Vector2(gx - 34, gy - 150), 36.0, C_BRASS_L, 0.22 * flick)
	_draw_glow(Vector2(gx + 34, gy - 150), 36.0, C_CYAN_L, 0.18 * flick)
	draw_circle(Vector2(gx - 34, gy - 150), 3.0, C_BRASS_L)
	draw_circle(Vector2(gx + 34, gy - 150), 3.0, C_CYAN_L)
	# vines
	for i in 6:
		_px_runes(Vector2(gx - 28 + (i * 11) % 56, gy - 60 - i * 13), Color("#3f8a5e"))


func _px_runes(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(2, 2)), Color(color.r, color.g, color.b, 0.7))


func _draw_deaths(shake: Vector2) -> void:
	for d in deaths:
		var p := float(d.t) / float(d.dur)
		var a := 1.0 - p
		var x: float = float(d.x) + shake.x
		var base := GROUND_Y + shake.y
		var col: Color = d.color
		if d.kind == "boss":
			_draw_glow(Vector2(x, base - 70), 260.0 * (0.6 + p), col, 0.35 * a)
			for i in 10:
				var ang := TAU * float(i) / 10.0 + p * 1.5
				var r := 30.0 + p * 80.0
				draw_circle(Vector2(x, base - 70) + Vector2(cos(ang), sin(ang)) * r, 8.0 * a,
					Color(col.r, col.g, col.b, a * 0.5))
		else:
			_draw_glow(Vector2(x, base - 50), 90.0, col, 0.18 * a)
			# dissolving silhouette so a death reads as a death, not a pop-out
			var ghost := Color(col.r, col.g, col.b, 0.28 * a)
			if d.kind == "unit":
				draw_rect(Rect2(x - 10, base - 48 - p * 10.0, 20, 40), ghost)
				draw_circle(Vector2(x, base - 58 - p * 10.0), 8.0, ghost)
				draw_line(Vector2(x + 10, base - 42), Vector2(x + 26, base - 60), ghost, 3.0)
			else:
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 13, base - 12), Vector2(x, base - 44 - p * 8.0),
					Vector2(x + 13, base - 12),
				]), ghost)
		# fragments + rising embers
		for i in 5:
			var ang := float(i) * 1.25 + 0.4
			var r := 8.0 + p * (26.0 + i * 4.0)
			var fp := Vector2(x + cos(ang) * r, base - 34 + sin(ang) * r * 0.5 - p * 22.0)
			draw_rect(Rect2(fp, Vector2(4, 4)), Color(col.r, col.g, col.b, a * 0.8))
		for i in 6:
			var ex := x - 24 + fmod(float(i) * 13.0, 48.0)
			var ey := base - 20.0 - fmod(float(i) * 17.0 + p * 60.0, 64.0)
			draw_rect(Rect2(Vector2(ex, ey), Vector2(2, 2)), Color(1.0, 0.68, 0.35, a * 0.7))


func _draw_projectiles(shake: Vector2) -> void:
	for pr in projectiles:
		var t := clampf(float(pr.t) / float(pr.dur), 0.0, 1.0)
		var from: Vector2 = pr.from + shake
		var to: Vector2 = pr.to + shake
		var dir := (to - from).normalized()
		if pr.kind == "arrow":
			var pos := from.lerp(to, t)
			var tail := pos - dir * 16.0
			draw_line(tail, pos, Color(1.0, 0.9, 0.7, 0.45), 2.0)
			draw_line(pos - dir * 9.0, pos, C_CREAM, 2.0)
			draw_line(pos, pos + dir * 4.0, WHITE_COL, 2.0)
			draw_line(pos + dir * 1.0 + Vector2(-dir.y, dir.x) * 2.0, pos + dir * 3.0, C_CREAM, 1.0)
		else:
			var pos := from.lerp(to, t)
			_draw_glow(pos, 52.0, pr.color, 0.65)
			draw_circle(pos, 7.0, pr.color)
			draw_circle(pos, 4.0, Color("#f3ddff"))
			for i in 3:
				var tp := pos - dir * (10.0 + i * 9.0)
				draw_circle(tp, 4.0 - i, Color(pr.color.r, pr.color.g, pr.color.b, 0.35 - i * 0.1))


const WHITE_COL := Color("#fff6e8")


func _draw_unit(u: Dictionary, shake: Vector2) -> void:
	var base := GROUND_Y + shake.y
	var hit_ratio := clampf(float(u.flash) / 0.14, 0.0, 1.0)
	var x: float = SLOT_XS[int(u.slot)] + shake.x + float(u.lunge) * 46.0 - hit_ratio * 4.0
	var bob := sin(total_elapsed * 3.6 + float(u.phase)) * 2.4
	var flash := float(u.flash) > 0.0
	var ap := clampf(1.0 - float(u.lunge) / 0.16, 0.0, 1.0)
	var sway := sin(total_elapsed * 2.1 + float(u.phase)) * 1.6
	_shadow(x, base, 26.0, 0.34)
	match String(u.type):
		"blade":
			_unit_blade(x, base, bob, flash, ap, sway)
		"bow":
			_unit_bow(x, base, bob, flash, ap, sway)
		"shield":
			_unit_shield(x, base, bob, flash, ap, sway)
		"steed":
			_unit_steed(x, base, bob, flash, ap, sway)
		"orb":
			_unit_orb(x, base, bob, flash, ap, sway)
	# hp bar + level pips
	var lv := int(u.level)
	if float(u.hp) < float(u.max_hp) - 0.01:
		var ratio := clampf(float(u.hp) / float(u.max_hp), 0.0, 1.0)
		_unit_bar(Vector2(x - 21, base - 82), 42.0, ratio, C_MINT if ratio > 0.4 else C_RED)
	for i in lv:
		_draw_diamond(Vector2(x - lv * 4.0 + i * 8.0 + 4.0, base - 90), 2.6, C_BRASS)


func _unit_blade(x: float, base: float, bob: float, flash: bool, ap: float, sway: float) -> void:
	var white := Color(1, 1, 1, 0.96)
	var red := white if flash else Color("#b8324f")
	var red_d := white if flash else Color("#741a31")
	var steel := white if flash else Color("#8fa6d8")
	var steel_l := white if flash else Color("#d8e4ff")
	var skin := white if flash else Color("#f0c9a0")
	# cape
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 10 + sway, base - 50 + bob), Vector2(x - 24 + sway, base - 8),
		Vector2(x - 6 + sway, base - 14), Vector2(x - 2, base - 48 + bob),
	]), red_d)
	# legs
	_frect(Rect2(x - 11, base - 22, 8, 22), Color("#2b1e38"))
	_frect(Rect2(x + 3, base - 22, 8, 22), Color("#2b1e38"))
	_rect(Rect2(x - 12, base - 4, 10, 4), C_INK)
	_rect(Rect2(x + 2, base - 4, 10, 4), C_INK)
	# torso + tabard
	_orect(Rect2(x - 13, base - 51 + bob, 26, 30), red)
	_rect(Rect2(x - 9, base - 47 + bob, 18, 20), Color("#d14661") if not flash else white)
	_rect(Rect2(x - 3, base - 47 + bob, 6, 22), C_BRASS)
	_draw_diamond(Vector2(x, base - 42 + bob), 3.0, C_CREAM)
	# shoulders
	_frect(Rect2(x - 18, base - 51 + bob, 9, 11), steel)
	_frect(Rect2(x + 9, base - 51 + bob, 9, 11), steel)
	_rect(Rect2(x - 18, base - 51 + bob, 9, 2), steel_l)
	# head + helm
	_orect(Rect2(x - 8, base - 68 + bob, 16, 15), skin)
	_frect(Rect2(x - 10, base - 74 + bob, 20, 9), steel)
	_rect(Rect2(x - 10, base - 74 + bob, 20, 2), steel_l)
	_rect(Rect2(x - 1, base - 70 + bob, 3, 8), steel_l)
	_rect(Rect2(x - 6, base - 64 + bob, 3, 2), C_INK)
	_rect(Rect2(x + 3, base - 64 + bob, 3, 2), C_INK)
	_px_plate(Vector2(x - 6, base - 64 + bob), Color("#fff0c0"))
	# plume
	draw_line(Vector2(x, base - 74 + bob), Vector2(x - 5, base - 82 + bob), Color("#f2536b"), 3.0)
	draw_line(Vector2(x - 4, base - 80 + bob), Vector2(x - 8, base - 86 + bob), Color("#ff9db0"), 2.0)
	# sword arm
	var hand := Vector2(x + 13, base - 38 + bob)
	var ang := lerpf(-1.75, 1.15, ap)
	var tip := hand + Vector2(cos(ang), sin(ang)) * 46.0
	draw_line(hand, tip, C_INK, 7.0)
	draw_line(hand, tip, steel_l, 4.0)
	draw_line(hand, tip, Color(1, 1, 1, 0.85), 1.0)
	var guard := hand + Vector2(cos(ang), sin(ang)) * 12.0
	var perp := Vector2(-sin(ang), cos(ang)) * 8.0
	draw_line(guard - perp, guard + perp, C_BRASS, 3.0)
	draw_line(guard - perp * 0.7, guard + perp * 0.7, C_BRASS_L, 1.0)
	_draw_glow(hand.lerp(tip, 0.62), 26.0, C_CYAN, 0.20)
	if ap > 0.05 and ap < 0.95:
		draw_arc(hand, 42.0, ang - 1.0, ang, 10, Color(1.0, 0.95, 0.8, 0.35), 2.5)
	# trailing plume of embers on attack
	if ap > 0.4:
		for i in 3:
			draw_circle(tip - Vector2(cos(ang), sin(ang)) * (i * 9.0), 1.5,
				Color(1.0, 0.85, 0.5, 0.35 - i * 0.1))


func _unit_bow(x: float, base: float, bob: float, flash: bool, ap: float, sway: float) -> void:
	var white := Color(1, 1, 1, 0.96)
	var cloak := white if flash else Color("#2f7a4e")
	var cloak_l := white if flash else Color("#48b070")
	var cloak_d := white if flash else Color("#1c4a32")
	var skin := white if flash else Color("#e9c9a3")
	# quiver + arrows behind
	_frect(Rect2(x - 20, base - 50 + bob, 9, 26), Color("#3a2a1e"))
	for i in 3:
		draw_line(Vector2(x - 17 + i * 3, base - 52 + bob), Vector2(x - 19 + i * 3, base - 66 + bob), C_CREAM, 1.5)
		_px_plate(Vector2(x - 20 + i * 3, base - 66 + bob), C_CRIM_L)
	# cloak / body
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 12, base - 50 + bob), Vector2(x - 18 + sway, base - 16),
		Vector2(x - 10 + sway, base - 6), Vector2(x + 12, base - 10),
		Vector2(x + 12, base - 48 + bob),
	]), cloak_d)
	_orect(Rect2(x - 12, base - 48 + bob, 24, 26), cloak)
	_rect(Rect2(x - 8, base - 44 + bob, 16, 12), cloak_l)
	_rect(Rect2(x - 2, base - 44 + bob, 4, 18), C_BRASS_DK)
	# legs
	_frect(Rect2(x - 10, base - 22, 7, 22), Color("#1d2438"))
	_frect(Rect2(x + 4, base - 22, 7, 22), Color("#1d2438"))
	# hood + face
	_orect(Rect2(x - 10, base - 66 + bob, 20, 17), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 10, base - 64 + bob), Vector2(x, base - 76 + bob), Vector2(x + 10, base - 64 + bob),
	]), cloak_l)
	_frect(Rect2(x - 6, base - 62 + bob, 12, 10), Color("#141021"))
	_rect(Rect2(x - 5, base - 59 + bob, 3, 2), C_MINT)
	_rect(Rect2(x + 2, base - 59 + bob, 3, 2), C_MINT)
	_draw_glow(Vector2(x, base - 59 + bob), 18.0, C_MINT, 0.18)
	# bow
	var bow_c := Vector2(x + 17, base - 40 + bob)
	var pull := ap * 6.0
	draw_arc(bow_c, 21.0, -1.35, 1.35, 14, C_INK, 5.0)
	draw_arc(bow_c, 21.0, -1.35, 1.35, 14, cloak_l if not flash else white, 3.0)
	var a1 := bow_c + Vector2(cos(-1.35), sin(-1.35)) * 21.0
	var a2 := bow_c + Vector2(cos(1.35), sin(1.35)) * 21.0
	var nock := Vector2(bow_c.x - 6.0 - pull, bow_c.y)
	draw_line(a1, nock, Color(0.9, 0.86, 0.75, 0.8), 1.0)
	draw_line(nock, a2, Color(0.9, 0.86, 0.75, 0.8), 1.0)
	if ap > 0.2:
		draw_line(Vector2(bow_c.x - 10 - pull, bow_c.y), Vector2(bow_c.x + 24, bow_c.y), C_CREAM, 2.0)
		_px_plate(Vector2(bow_c.x + 24, bow_c.y), C_CREAM)
	# hand
	draw_circle(Vector2(x + 12, base - 40 + bob), 4.0, skin)


func _unit_shield(x: float, base: float, bob: float, flash: bool, ap: float, sway: float) -> void:
	var white := Color(1, 1, 1, 0.96)
	var armor := white if flash else Color("#4f8fe8")
	var armor_d := white if flash else Color("#1e3768")
	var steel := white if flash else Color("#a8bdd8")
	var skin := white if flash else Color("#e9c9a3")
	# legs
	_frect(Rect2(x - 13, base - 24, 10, 24), Color("#20243c"))
	_frect(Rect2(x + 3, base - 24, 10, 24), Color("#20243c"))
	_rect(Rect2(x - 15, base - 5, 12, 5), C_INK)
	_rect(Rect2(x + 2, base - 5, 12, 5), C_INK)
	# torso (broad)
	_orect(Rect2(x - 16, base - 54 + bob, 32, 32), armor_d)
	_orect(Rect2(x - 13, base - 52 + bob, 26, 26), armor)
	_rect(Rect2(x - 13, base - 52 + bob, 26, 3), Color("#8fc4ff") if not flash else white)
	_rect(Rect2(x - 13, base - 30 + bob, 26, 3), C_BRASS_DK)
	_draw_diamond(Vector2(x, base - 42 + bob), 4.0, C_BRASS)
	# pauldrons
	_frect(Rect2(x - 22, base - 54 + bob, 10, 14), steel)
	_frect(Rect2(x + 12, base - 54 + bob, 10, 14), steel)
	# helm
	_frect(Rect2(x - 10, base - 71 + bob, 20, 15), steel)
	_rect(Rect2(x - 10, base - 71 + bob, 20, 3), Color("#e8eef8") if not flash else white)
	_rect(Rect2(x - 2, base - 66 + bob, 4, 9), C_INK)
	_rect(Rect2(x - 9, base - 64 + bob, 18, 2), C_INK)
	_px_plate(Vector2(x - 8, base - 64 + bob), C_CYAN_L)
	_px_plate(Vector2(x + 6, base - 64 + bob), C_CYAN_L)
	# plume
	draw_line(Vector2(x, base - 71 + bob), Vector2(x - 8, base - 82 + bob), C_BRASS, 4.0)
	draw_line(Vector2(x - 6, base - 80 + bob), Vector2(x - 12, base - 88 + bob), C_BRASS_L, 2.0)
	# kite shield in front
	var sh_x := x + 16 + ap * 10.0
	var shield_pts := PackedVector2Array([
		Vector2(sh_x - 12, base - 56 + bob), Vector2(sh_x + 10, base - 56 + bob),
		Vector2(sh_x + 13, base - 34 + bob), Vector2(sh_x, base - 16 + bob),
		Vector2(sh_x - 13, base - 34 + bob),
	])
	draw_colored_polygon(shield_pts, C_INK)
	var inner := PackedVector2Array()
	for p in shield_pts:
		inner.append(p.lerp(Vector2(sh_x, base - 38 + bob), 0.10))
	draw_colored_polygon(inner, armor_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(sh_x - 8, base - 52 + bob), Vector2(sh_x + 6, base - 52 + bob),
		Vector2(sh_x + 8, base - 36 + bob), Vector2(sh_x, base - 22 + bob),
		Vector2(sh_x - 8, base - 36 + bob),
	]), armor)
	draw_line(Vector2(sh_x, base - 52 + bob), Vector2(sh_x, base - 26 + bob), C_BRASS, 3.0)
	draw_line(Vector2(sh_x - 9, base - 42 + bob), Vector2(sh_x + 9, base - 42 + bob), C_BRASS, 3.0)
	_draw_glow(Vector2(sh_x, base - 42 + bob), 36.0, C_BRASS, 0.16)
	draw_circle(Vector2(sh_x, base - 42 + bob), 4.0, C_BRASS_L)
	# arm
	draw_line(Vector2(x + 10, base - 44 + bob), Vector2(sh_x - 6, base - 42 + bob), armor, 6.0)
	draw_circle(Vector2(x + 12, base - 44 + bob), 5.0, skin)


func _unit_steed(x: float, base: float, bob: float, flash: bool, ap: float, sway: float) -> void:
	var white := Color(1, 1, 1, 0.96)
	var horse := white if flash else Color("#e07a3f")
	var horse_d := white if flash else Color("#8f3d1c")
	var mane := white if flash else Color("#e8b24a")
	var cloth := white if flash else Color("#b8324f")
	# legs
	for i in 4:
		var lx := x - 22 + i * 11
		var step := sin(total_elapsed * 7.0 + float(i) * 1.6) * 4.0
		draw_line(Vector2(lx, base - 24), Vector2(lx + step, base - 3), horse_d, 5.0)
		draw_line(Vector2(lx, base - 24), Vector2(lx + step * 0.7, base - 8), horse, 2.0)
	# tail
	draw_line(Vector2(x - 24, base - 40 + bob), Vector2(x - 34 + sway, base - 24), mane, 4.0)
	# body
	_orect(Rect2(x - 26, base - 46 + bob, 42, 22), horse)
	_rect(Rect2(x - 26, base - 46 + bob, 42, 3), Color("#ffc888") if not flash else white)
	_rect(Rect2(x - 26, base - 26 + bob, 42, 3), horse_d)
	# saddle cloth
	_rect(Rect2(x - 14, base - 48 + bob, 18, 16), cloth)
	_rect(Rect2(x - 14, base - 48 + bob, 18, 2), C_BRASS)
	# neck + head
	_orect(Rect2(x + 10, base - 58 + bob, 14, 26), horse)
	_orect(Rect2(x + 16, base - 64 + bob, 16, 14), horse)
	_rect(Rect2(x + 17, base - 66 + bob, 4, 5), horse)
	_rect(Rect2(x + 24, base - 66 + bob, 4, 5), horse)
	_px_plate(Vector2(x + 27, base - 58 + bob), C_INK)
	_px_plate(Vector2(x + 28, base - 57 + bob), Color("#fff0c0"))
	_rect(Rect2(x + 26, base - 54 + bob, 4, 2), C_INK)
	# mane
	for i in 5:
		_px_plate(Vector2(x + 20 + i % 2, base - 66 + bob + i * 2), mane)
	# rider
	_orect(Rect2(x - 8, base - 70 + bob, 16, 22), cloth)
	_frect(Rect2(x - 10, base - 76 + bob, 20, 9), C_BRASS_DK)
	_frect(Rect2(x - 6, base - 84 + bob, 12, 10), Color("#f0c9a0") if not flash else white)
	_frect(Rect2(x - 8, base - 90 + bob, 16, 7), Color("#8fa6d8") if not flash else white)
	draw_line(Vector2(x, base - 90 + bob), Vector2(x - 4, base - 98 + bob), C_CRIM, 3.0)
	# lance
	var lx0 := x + 4
	var lx1 := x + 34 + ap * 22.0
	draw_line(Vector2(lx0, base - 64 + bob), Vector2(lx1, base - 58 + bob), Color("#5a3b2a"), 4.0)
	draw_line(Vector2(lx1 - 8, base - 59 + bob), Vector2(lx1 + 6, base - 57 + bob), C_CREAM, 3.0)
	_draw_glow(Vector2(lx1 + 6, base - 57 + bob), 26.0, C_BRASS, 0.25)
	# dust at hooves
	for i in 3:
		var dx := x - 20 + fmod(total_elapsed * 30.0 + i * 19.0, 44.0)
		draw_rect(Rect2(dx, base - 3, 3, 2), Color(0.6, 0.5, 0.7, 0.18))


func _unit_orb(x: float, base: float, bob: float, flash: bool, ap: float, sway: float) -> void:
	var white := Color(1, 1, 1, 0.96)
	var robe := white if flash else Color("#5d2b8f")
	var robe_d := white if flash else Color("#341a54")
	var trim := white if flash else Color("#9a5ce0")
	var lev := bob + sin(total_elapsed * 2.2 + 1.0) * 3.0
	var b2 := base - 8 + lev
	# robe bell
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 13, b2 - 42), Vector2(x - 20 + sway, b2 - 4),
		Vector2(x + 20 + sway, b2 - 4), Vector2(x + 13, b2 - 42),
	]), robe_d)
	_orect(Rect2(x - 14, b2 - 44, 28, 34), robe)
	_rect(Rect2(x - 14, b2 - 12, 28, 4), trim)
	_rect(Rect2(x - 6, b2 - 40, 12, 24), robe_d)
	_rect(Rect2(x - 2, b2 - 40, 4, 24), trim)
	# hood + face
	_orect(Rect2(x - 10, b2 - 58, 20, 17), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 10, b2 - 56), Vector2(x, b2 - 68), Vector2(x + 10, b2 - 56),
	]), trim)
	_frect(Rect2(x - 6, b2 - 56, 12, 9), Color("#160f24"))
	_rect(Rect2(x - 4, b2 - 53, 2, 2), C_CYAN_L)
	_rect(Rect2(x + 2, b2 - 53, 2, 2), C_CYAN_L)
	_draw_glow(Vector2(x, b2 - 53), 24.0, C_CYAN, 0.20)
	# staff
	var sx := x + 18
	draw_line(Vector2(sx, b2 - 4), Vector2(sx, b2 - 70), Color("#5a3b2a"), 3.0)
	draw_line(Vector2(sx - 1, b2 - 4), Vector2(sx - 1, b2 - 70), Color("#8a5f3c"), 1.0)
	draw_circle(Vector2(sx, b2 - 24), 6.0, C_BRASS_DK)
	var orb_c := Vector2(sx, b2 - 74)
	var pulse := 1.0 + 0.12 * sin(total_elapsed * 4.0)
	_draw_glow(orb_c, 66.0 * pulse, Color("#c77bff"), 0.35)
	draw_circle(orb_c, 10.0 * pulse, Color("#9a5ce0") if not flash else white)
	draw_circle(orb_c, 6.0 * pulse, Color("#f3ddff"))
	draw_circle(orb_c - Vector2(2, 2), 2.5, Color(1, 1, 1, 0.95))
	for i in 3:
		var ang := total_elapsed * 2.4 + float(i) * TAU / 3.0
		var op := orb_c + Vector2(cos(ang) * 18.0, sin(ang) * 10.0)
		draw_circle(op, 2.0, Color(0.78, 0.9, 1.0, 0.8))
	if ap > 0.1:
		_draw_glow(orb_c, 48.0 + ap * 30.0, Color("#e2c2ff"), 0.55 * ap)


func _orect(r: Rect2, fill: Color) -> void:
	draw_rect(r.grow(1.5), C_INK)
	draw_rect(r, fill)


# Single-draw rect for secondary parts that already sit inside an outline.
func _frect(r: Rect2, fill: Color) -> void:
	draw_rect(r, fill)


func _shadow(x: float, base: float, w: float, alpha: float) -> void:
	draw_texture_rect(shadow_tex, Rect2(x - w, base - 7.0, w * 2.0, w * 0.95), false,
		Color(1, 1, 1, alpha * 1.7))


func _unit_bar(pos: Vector2, w: float, ratio: float, color: Color) -> void:
	_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, 7)), C_INK)
	_rect(Rect2(pos, Vector2(w, 5)), Color("#201528"))
	_rect(Rect2(pos, Vector2(w * ratio, 5)), color)
	_rect(Rect2(pos, Vector2(w * ratio, 1)), Color(1, 1, 1, 0.45))


func _px_plate(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(2, 2)), color)


func _draw_enemy(e: Dictionary, shake: Vector2) -> void:
	var base := GROUND_Y + shake.y
	var hit_ratio := clampf(float(e.flash) / 0.12, 0.0, 1.0)
	var x: float = float(e.x) + shake.x - float(e.lunge) * 40.0 + hit_ratio * 5.0
	var flash := float(e.flash) > 0.0
	var white := Color(1, 1, 1, 0.96)
	var bob := sin(total_elapsed * 5.0 + float(e.phase)) * 2.0
	var ap := clampf(1.0 - float(e.lunge) / 0.18, 0.0, 1.0)
	_shadow(x, base, 24.0, 0.35)
	match String(e.type):
		"grunt":
			_enemy_grunt(x, base, bob, flash, ap, white)
		"runner":
			_enemy_runner(x, base, bob, flash, ap, white)
		"brute":
			_enemy_brute(x, base, bob, flash, ap, white)
		"boss":
			_enemy_boss(x, base, flash, ap, white)
	if float(e.hp) < float(e.max_hp) - 0.01 and e.type != "boss":
		var ratio := clampf(float(e.hp) / float(e.max_hp), 0.0, 1.0)
		_unit_bar(Vector2(x - 20, base - 64), 40.0, ratio, C_ROSE)


func _enemy_grunt(x: float, base: float, bob: float, flash: bool, ap: float, white: Color) -> void:
	var body := white if flash else Color("#b8447a")
	var body_d := white if flash else Color("#6e1f4c")
	var hood := white if flash else Color("#7d2f56")
	var eye := Color("#ffd9e4")
	# legs
	draw_line(Vector2(x - 8, base - 12), Vector2(x - 11, base - 2), body_d, 4.0)
	draw_line(Vector2(x + 6, base - 12), Vector2(x + 9, base - 2), body_d, 4.0)
	# tattered cloak silhouette
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 15, base - 38 + bob), Vector2(x - 18, base - 8 + bob),
		Vector2(x - 8, base - 14 + bob), Vector2(x, base - 6 + bob),
		Vector2(x + 10, base - 14 + bob), Vector2(x + 15, base - 38 + bob),
	]), C_INK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 13, base - 36 + bob), Vector2(x - 15, base - 11 + bob),
		Vector2(x - 7, base - 16 + bob), Vector2(x, base - 10 + bob),
		Vector2(x + 8, base - 16 + bob), Vector2(x + 13, base - 36 + bob),
	]), body_d)
	# torso + hood
	_frect(Rect2(x - 12, base - 40 + bob, 24, 22), body)
	_rect(Rect2(x - 12, base - 40 + bob, 24, 2), Color("#f2b3c9") if not flash else white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 12, base - 42 + bob), Vector2(x, base - 56 + bob), Vector2(x + 12, base - 42 + bob),
	]), hood)
	_rect(Rect2(x - 7, base - 46 + bob, 14, 7), Color("#1c0f18"))
	_rect(Rect2(x - 5, base - 44 + bob, 3, 3), eye)
	_rect(Rect2(x + 2, base - 44 + bob, 3, 3), eye)
	_draw_glow(Vector2(x, base - 44 + bob), 24.0, Color("#ff9db0"), 0.15)
	# cleaver arm
	var hand := Vector2(x - 15, base - 30 + bob)
	var tip := hand + Vector2(-18 - ap * 10.0, 8.0 - ap * 8.0)
	draw_line(Vector2(x - 8, base - 32 + bob), hand, body_d, 4.0)
	draw_line(hand, tip, C_INK, 7.0)
	draw_line(hand, tip, Color("#a8bdd8") if not flash else white, 4.0)
	draw_line(hand, tip, Color(1, 1, 1, 0.6), 1.0)
	# bone charms
	draw_line(Vector2(x + 8, base - 34 + bob), Vector2(x + 14, base - 28 + bob), C_BONE, 2.0)


func _enemy_runner(x: float, base: float, bob: float, flash: bool, ap: float, white: Color) -> void:
	var body := white if flash else Color("#d97a4a")
	var body_d := white if flash else Color("#8f3d1c")
	var scarf := white if flash else Color("#ff9db0")
	# legs mid-stride
	var step := sin(total_elapsed * 12.0 + float(x) * 0.1) * 6.0
	draw_line(Vector2(x - 6, base - 14), Vector2(x - 14 - step, base - 2), body_d, 4.0)
	draw_line(Vector2(x + 6, base - 14), Vector2(x + 13 + step, base - 2), body_d, 4.0)
	# lean body
	_frect(Rect2(x - 10, base - 38 + bob, 20, 25), body)
	_rect(Rect2(x - 10, base - 38 + bob, 20, 2), Color("#ffc888") if not flash else white)
	_rect(Rect2(x - 10, base - 20 + bob, 20, 3), body_d)
	# scarf trailing behind
	for i in 3:
		var sy := base - 36 + bob + i * 3.0
		draw_line(Vector2(x - 6, sy), Vector2(x - 20 - i * 4.0 + sin(total_elapsed * 10.0 + i) * 3.0, sy - 2.0),
			Color(scarf.r, scarf.g, scarf.b, 0.8 - i * 0.15), 3.0 - i * 0.5)
	# head + goggles
	_frect(Rect2(x - 8, base - 50 + bob, 16, 14), body)
	_rect(Rect2(x - 8, base - 52 + bob, 16, 4), body_d)
	_rect(Rect2(x - 6, base - 46 + bob, 12, 4), C_INK)
	draw_circle(Vector2(x - 3, base - 44 + bob), 2.0, C_CYAN)
	draw_circle(Vector2(x + 4, base - 44 + bob), 2.0, C_CYAN)
	_draw_glow(Vector2(x, base - 44 + bob), 20.0, C_CYAN, 0.18)
	# twin daggers
	var thrust := ap * 8.0
	draw_line(Vector2(x + 10, base - 32 + bob), Vector2(x + 26 + thrust, base - 30 + bob), C_CREAM, 2.0)
	draw_line(Vector2(x - 10, base - 32 + bob), Vector2(x + 20 + thrust, base - 26 + bob), C_CREAM, 2.0)
	# speed lines
	if ap < 0.5:
		for i in 2:
			draw_line(Vector2(x - 22 - i * 6, base - 24 + i * 8), Vector2(x - 32 - i * 6, base - 24 + i * 8),
				Color(1.0, 0.7, 0.4, 0.25), 1.0)


func _enemy_brute(x: float, base: float, bob: float, flash: bool, ap: float, white: Color) -> void:
	var body := white if flash else Color("#7d2f56")
	var body_d := white if flash else Color("#4d1b3a")
	var armor := white if flash else Color("#4a3044")
	# legs
	_frect(Rect2(x - 14, base - 20, 11, 20), body_d)
	_frect(Rect2(x + 4, base - 20, 11, 20), body_d)
	# torso
	_orect(Rect2(x - 20, base - 54 + bob, 40, 36), body_d)
	_orect(Rect2(x - 16, base - 50 + bob, 32, 28), body)
	_rect(Rect2(x - 16, base - 50 + bob, 32, 3), Color("#b05a86") if not flash else white)
	_rect(Rect2(x - 16, base - 30 + bob, 32, 3), body_d)
	# shoulder spikes
	for i in 2:
		var sx := x - 22.0 + i * 38.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, base - 50 + bob), Vector2(sx - 6, base - 62 + bob), Vector2(sx + 6, base - 56 + bob),
		]), C_BONE if not flash else white)
	# head + horns
	_orect(Rect2(x - 11, base - 70 + bob, 22, 18), body)
	_rect(Rect2(x - 11, base - 72 + bob, 22, 3), body_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 10, base - 70 + bob), Vector2(x - 20, base - 84 + bob), Vector2(x - 13, base - 68 + bob),
	]), C_BONE if not flash else white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 10, base - 70 + bob), Vector2(x + 20, base - 84 + bob), Vector2(x + 13, base - 68 + bob),
	]), C_BONE if not flash else white)
	_rect(Rect2(x - 8, base - 62 + bob, 6, 4), Color("#fff0c0"))
	_rect(Rect2(x + 3, base - 62 + bob, 6, 4), Color("#fff0c0"))
	_draw_glow(Vector2(x, base - 60 + bob), 34.0, Color("#ffcf8a"), 0.15)
	# hammer arm (swings at the gate side)
	var hand := Vector2(x - 24, base - 38 + bob)
	var hx := x - 38 - ap * 16.0
	draw_line(Vector2(x - 18, base - 44 + bob), hand, body_d, 7.0)
	draw_line(hand, Vector2(hx, base - 26 + bob), C_LEATHER_H, 5.0)
	_frect(Rect2(hx - 12, base - 38 + bob, 20, 18), armor)
	_rect(Rect2(hx - 12, base - 38 + bob, 20, 2), C_STEEL_D)
	_rect(Rect2(hx - 12, base - 22 + bob, 20, 2), C_INK)
	_draw_glow(Vector2(hx, base - 30 + bob), 40.0, Color("#8a4ab8"), 0.18)


func _enemy_boss(x: float, base: float, flash: bool, ap: float, white: Color) -> void:
	x = minf(x - 36.0, 1188.0)
	var center := Vector2(x, base - 78)
	var body := white if flash else Color("#4a2360")
	var body_d := white if flash else Color("#2a1238")
	var rim := white if flash else Color("#a24ad8")
	var gold := white if flash else C_BRASS
	var t := total_elapsed
	_draw_glow(center, 330.0, Color("#ff4f8b"), 0.16 + 0.04 * sin(t * 2.2))
	_draw_glow(center, 210.0, Color("#a24ad8"), 0.12)
	# rotating gear ring
	for i in 12:
		var a := TAU * float(i) / 12.0 + t * 0.55
		var a2 := a + 0.16
		var p1 := center + Vector2(cos(a), sin(a)) * 52.0
		var p2 := center + Vector2(cos(a), sin(a)) * 68.0
		var p3 := center + Vector2(cos(a2), sin(a2)) * 68.0
		var p4 := center + Vector2(cos(a2), sin(a2)) * 52.0
		draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), body_d if not flash else white)
		draw_colored_polygon(PackedVector2Array([
			p1.lerp(p2, 0.55), p2, p3, p3.lerp(p4, 0.55),
		]), rim)
	draw_arc(center, 52.0, 0.0, TAU, 32, C_INK, 10.0)
	draw_arc(center, 52.0, 0.0, TAU, 32, rim, 5.0)
	draw_arc(center, 44.0, 0.0, TAU, 28, body_d, 8.0)
	for i in 8:
		var a := TAU * float(i) / 8.0 - t * 0.9
		var p := center + Vector2(cos(a), sin(a)) * 34.0
		draw_circle(p, 3.0, gold)
	# core eye
	var eye_y := center.y + sin(t * 2.8) * 3.0
	_draw_glow(Vector2(x, eye_y), 160.0, Color("#ff4f6e"), 0.34)
	draw_circle(Vector2(x, eye_y), 30.0, body_d)
	draw_circle(Vector2(x, eye_y), 22.0, Color("#ff4f6e"))
	draw_circle(Vector2(x, eye_y), 14.0, Color("#ffd9e4"))
	draw_circle(Vector2(x, eye_y), 6.0, C_INK)
	# crown of gears
	for i in 5:
		var cx := x - 32.0 + i * 16.0
		var ch := 16.0 + (8.0 if i % 2 == 0 else 0.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 6, center.y - 58), Vector2(cx, center.y - 58 - ch),
			Vector2(cx + 6, center.y - 58),
		]), gold)
		_px_plate(Vector2(cx - 2, center.y - 60 - ch), C_BRASS_L)
	# arms
	var thrust := ap * 14.0
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(x + side * 50.0, center.y + 8.0)
		var elbow := Vector2(x + side * 72.0, center.y + 40.0)
		var claw := Vector2(x + side * 84.0 - thrust, center.y + 60.0)
		draw_line(shoulder, elbow, C_INK, 14.0)
		draw_line(shoulder, elbow, body_d, 10.0)
		draw_line(elbow, claw, C_INK, 11.0)
		draw_line(elbow, claw, rim, 6.0)
		draw_circle(claw, 8.0, gold)
		draw_line(claw, claw + Vector2(side * 8.0, 8.0), C_INK, 4.0)
		draw_line(claw, claw + Vector2(side * 2.0, 10.0), C_INK, 4.0)
	# legs / stand
	_frect(Rect2(x - 26, base - 32, 14, 32), body_d)
	_frect(Rect2(x + 12, base - 32, 14, 32), body_d)
	_frect(Rect2(x - 34, base - 8, 22, 8), C_INK)
	_frect(Rect2(x + 12, base - 8, 22, 8), C_INK)
	# orbiting embers
	for i in 8:
		var a := t * 1.4 + float(i) * TAU / 8.0
		var r := 74.0 + 8.0 * sin(t * 3.0 + i)
		var p := center + Vector2(cos(a) * r, sin(a) * r * 0.6)
		draw_circle(p, 2.5, Color(1.0, 0.55, 0.3, 0.6))


func _draw_fx() -> void:
	for p in particles:
		var a := clampf(float(p.life) / 0.5, 0.0, 1.0)
		var col: Color = p.color
		col.a *= a
		var pos := Vector2(p.pos)
		if bool(p.get("coin", false)):
			draw_set_transform(pos, float(p.get("rot", 0.0)), Vector2(1.0, 0.86))
			draw_texture_rect(coin_tex, Rect2(Vector2(-8, -8), Vector2(16, 16)), false, Color(col.r, col.g, col.b, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif bool(p.get("confetti", false)):
			draw_set_transform(pos, float(p.get("rot", 0.0)), Vector2.ONE)
			draw_rect(Rect2(Vector2(-2.5, -4.5), Vector2(5, 9)), col)
			draw_rect(Rect2(Vector2(-2.5, -4.5), Vector2(5, 2)), Color(1, 1, 1, a * 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var sz: float = p.size
			if sz >= 3.0 and a > 0.15:
				_draw_glow(pos, sz * 5.0, col, 0.10 * a)
			draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	for s in sparks:
		var a := clampf(float(s.life) / float(s.dur), 0.0, 1.0)
		var col: Color = s.color
		var pos := Vector2(s.pos)
		var tail := pos - Vector2(s.vel).normalized() * float(s.len)
		draw_line(tail, pos, Color(col.r, col.g, col.b, a * 0.30), 4.0)
		draw_line(tail, pos, Color(1, 1, 1, a * 0.85), 1.5)
	for f in floats:
		var a := clampf(float(f.life) / 0.9, 0.0, 1.0)
		var col: Color = f.color
		col.a *= a
		var size := int(f.size)
		if size >= 14:
			col = col.lightened(0.08 * a)
		_text_c(float(f.pos.x), float(f.pos.y), String(f.text), size, col, _font_mono if size <= 15 else _font_display)


func _draw_banner() -> void:
	if banner_t <= 0.0:
		return
	var p := 1.0 - banner_t / banner_dur
	var env := minf(1.0, p * 6.0) * minf(1.0, (1.0 - p) * 5.0)
	if env <= 0.01:
		return
	var boss := banner_kind == "boss"
	var accent := C_RED if boss else _atmo()
	var band_h := 96.0 * env
	var cy := 300.0
	_rect(Rect2(0, cy - band_h * 0.5, VIEW.x, band_h), Color(0.03, 0.02, 0.05, 0.72 * env))
	_rect(Rect2(0, cy - band_h * 0.5, VIEW.x, 2), Color(accent.r, accent.g, accent.b, env))
	_rect(Rect2(0, cy + band_h * 0.5 - 2, VIEW.x, 2), Color(accent.r, accent.g, accent.b, env))
	var title := "WAVE %d" % wave
	var sub := "守住城门"
	if boss:
		title = "齿 轮 暴 君"
		sub = "GEAR TYRANT · 最终波"
	elif wave == 1:
		sub = "转动命运 · 召唤守卫"
	var pop := 1.0 + 0.12 * (1.0 - minf(1.0, p * 8.0))
	_text_glow(640, cy + 8, title, int(46 * pop), C_CREAM, accent)
	_text_c(640, cy + 34, sub, 14, Color(accent.r, accent.g, accent.b, 0.9))
	if boss:
		for i in 12:
			var a := TAU * float(i) / 12.0 + total_elapsed
			var r := 150.0 + 20.0 * sin(total_elapsed * 2.0 + i)
			draw_circle(Vector2(640, cy) + Vector2(cos(a) * r, sin(a) * r * 0.35), 2.0,
				Color(1.0, 0.5, 0.35, 0.35 * env))


func _draw_flash() -> void:
	if flash_t <= 0.0:
		return
	var a := clampf(flash_t / flash_dur, 0.0, 1.0)
	var red := flash_col.r > 0.6 and flash_col.g < 0.4
	if red:
		draw_texture_rect(vignette_tex, Rect2(0, 0, VIEW.x, VIEW.y), false,
			Color(flash_col.r, flash_col.g, flash_col.b, a * 0.55))
		_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(flash_col.r, flash_col.g, flash_col.b, a * 0.06))
	else:
		_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(flash_col.r, flash_col.g, flash_col.b, a * 0.22))


# ---------------------------------------------------------------------------
# Drawing — shop and end screens
# ---------------------------------------------------------------------------

func _draw_shop() -> void:
	var ease := _ease_out(clampf(shop_open_t * 2.4, 0.0, 1.0))
	# full-screen veil with a warm arcane vignette
	_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.025, 0.018, 0.045, 0.90))
	draw_texture_rect(vignette_tex, Rect2(0, 0, VIEW.x, VIEW.y), false, Color(1.0, 0.72, 0.4, 0.35))
	for i in 26:
		var dx := fmod(float(i) * 97.0 + total_elapsed * 9.0, VIEW.x)
		var dy := 100.0 + fmod(float(i) * 61.0 + total_elapsed * 11.0, 520.0)
		draw_rect(Rect2(Vector2(dx, dy), Vector2(2, 2)), Color(1.0, 0.8, 0.5, 0.12))
	# title
	_text_glow(640, 104, "军 械 商 店", 37, C_CREAM, Color(1.0, 0.78, 0.35))
	_text_c(640, 132, "QUARTERMASTER · 买下的道具跨波生效", 13, Color("#d8b06a"), _font_mono)
	draw_line(Vector2(440, 146), Vector2(840, 146), Color(1.0, 0.8, 0.45, 0.18), 1.0)
	_draw_diamond(Vector2(440, 146), 3.0, C_BRASS_DK)
	_draw_diamond(Vector2(840, 146), 3.0, C_BRASS_DK)
	# gold readout
	var gp := Rect2(1020, 78, 190, 40)
	_rect(gp, Color(0.05, 0.035, 0.08, 0.8))
	_frame(gp, C_BRASS_DK, 1.5)
	draw_texture_rect(coin_tex, Rect2(1030, 86, 24, 24), false)
	_text(Vector2(1062, 107), str(gold), 22, C_BRASS_L, _font_mono)
	_text(Vector2(1122, 105), "GOLD", 10, C_DIM2, _font_mono)
	var mouse := get_local_mouse_position()
	for i in 3:
		if i >= shop_offers.size():
			continue
		var id: String = shop_offers[i]
		var item: Dictionary = ITEM_POOL[id]
		var base_card: Rect2 = SHOP_CARDS[i]
		var sold: bool = shop_sold[i]
		var hover := base_card.has_point(mouse) and not sold
		var appear := _ease_out(clampf(shop_open_t * 2.6 - i * 0.18, 0.0, 1.0))
		var card := Rect2(base_card.position + Vector2(0, (1.0 - appear) * 46.0 - (8.0 if hover else 0.0)), base_card.size)
		_draw_shop_card(card, item, i, sold, hover)
	# buttons
	var can_reroll := gold >= 1
	var mouse2 := get_local_mouse_position()
	var reroll_hover := REROLL_BTN.has_point(mouse2) and can_reroll
	var cont_hover := CONTINUE_BTN.has_point(mouse2)
	_rect(Rect2(REROLL_BTN.position + Vector2(0, 4), REROLL_BTN.size), Color(0, 0, 0, 0.4))
	_rect(REROLL_BTN, Color("#241a36"))
	_frame(REROLL_BTN, C_BRASS if reroll_hover else C_BRASS_DK, 2.0)
	_text_c(REROLL_BTN.position.x + REROLL_BTN.size.x * 0.5, REROLL_BTN.position.y + 30, "重摇 -1g  [E]", 15,
		C_CREAM if can_reroll else C_DIM)
	_rect(Rect2(CONTINUE_BTN.position + Vector2(0, 4), CONTINUE_BTN.size), Color(0, 0, 0, 0.45))
	_draw_glow(CONTINUE_BTN.get_center(), 280.0, C_BRASS, 0.10 + (0.06 if cont_hover else 0.0))
	for i in 5:
		_rect(Rect2(CONTINUE_BTN.position.x, CONTINUE_BTN.position.y + i * CONTINUE_BTN.size.y / 5.0,
			CONTINUE_BTN.size.x, CONTINUE_BTN.size.y / 5.0 + 1),
			Color("#f0bd5a").lerp(Color("#9a6423"), float(i) / 4.0))
	_frame(CONTINUE_BTN, C_BRASS_L, 2.0)
	_text_c(CONTINUE_BTN.position.x + CONTINUE_BTN.size.x * 0.5, CONTINUE_BTN.position.y + 30, "下一波  [SPACE]", 17, C_VOID, _font_display)
	_text_c(640, 644, "点击卡片或按 1 / 2 / 3 购买 · E 重摇 · SPACE 开战", 12, C_DIM, _font_mono)
	# entrance flash line
	if shop_open_t < 0.35:
		var a := 1.0 - shop_open_t / 0.35
		_rect(Rect2(0, 160, VIEW.x, 2), Color(1.0, 0.85, 0.5, 0.35 * a))


func _draw_shop_card(card: Rect2, item: Dictionary, index: int, sold: bool, hover: bool) -> void:
	var kind := String(item.kind)
	var strip := _kind_color(kind)
	var cx := card.position.x + card.size.x * 0.5
	# shadow + body
	_rect(Rect2(card.position + Vector2(0, 8), card.size), Color(0, 0, 0, 0.5))
	for i in 9:
		var t := float(i) / 8.0
		_rect(Rect2(card.position.x, card.position.y + i * card.size.y / 9.0, card.size.x, card.size.y / 9.0 + 1),
			Color("#241a3a").lerp(Color("#120d1f"), t))
	if hover:
		_draw_glow(card.get_center(), 420.0, strip, 0.10)
	# border layers
	_frame(card, Color(0, 0, 0, 0.9), 5.0)
	_frame(card.grow(-1.0), strip if hover else Color(strip.r * 0.55, strip.g * 0.55, strip.b * 0.55, 1.0), 2.5)
	_frame(card.grow(-6.0), Color(strip.r, strip.g, strip.b, 0.16), 1.0)
	# top ribbon
	_rect(Rect2(card.position.x + 8, card.position.y + 8, card.size.x - 16, 22), Color(0.04, 0.03, 0.07, 0.8))
	_rect(Rect2(card.position.x + 8, card.position.y + 8, 4, 22), strip)
	_text(Vector2(card.position.x + 20, card.position.y + 24), _kind_label(kind), 10, strip, _font_mono)
	_text(Vector2(card.end.x - 36, card.position.y + 24), "[%d]" % (index + 1), 11, C_DIM, _font_mono)
	# corner ticks
	for corner in [
		Vector2(card.position.x + 10, card.position.y + 36),
		Vector2(card.end.x - 10, card.position.y + 36),
		Vector2(card.position.x + 10, card.end.y - 10),
		Vector2(card.end.x - 10, card.end.y - 10),
	]:
		draw_circle(corner, 2.0, Color(strip.r, strip.g, strip.b, 0.45))
	# icon pedestal
	var iy := card.position.y + 84
	_draw_glow(Vector2(cx, iy), 150.0, strip, 0.18 if not hover else 0.28)
	draw_circle(Vector2(cx, iy + 14), 44.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(cx, iy + 14), 40.0, Color("#100b1c"))
	draw_arc(Vector2(cx, iy + 14), 40.0, 0.0, TAU, 32, Color(strip.r, strip.g, strip.b, 0.35), 2.0)
	draw_arc(Vector2(cx, iy + 14), 34.0, -2.6, -0.6, 16, Color(1, 1, 1, 0.12), 1.0)
	match kind:
		"odds":
			draw_texture_rect(symbol_tex["blade"], Rect2(cx - 40, iy - 42, 80, 80), false)
		"symbol":
			draw_texture_rect(symbol_tex["crown"], Rect2(cx - 40, iy - 42, 80, 80), false)
		"economy":
			draw_texture_rect(coin_tex, Rect2(cx - 30, iy - 24, 60, 60), false)
			_draw_diamond(Vector2(cx + 26, iy - 18), 4.0, C_BRASS_L)
		"stats":
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 24, iy + 26), Vector2(cx - 12, iy - 12),
				Vector2(cx, iy - 32), Vector2(cx + 12, iy - 6),
				Vector2(cx + 24, iy + 20), Vector2(cx + 4, iy + 12),
				Vector2(cx - 4, iy + 28),
			]), Color("#ff7a4a"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 8, iy + 18), Vector2(cx + 2, iy - 14),
				Vector2(cx + 10, iy + 8), Vector2(cx + 2, iy + 18),
			]), Color("#ffd9a0"))
			_draw_glow(Vector2(cx, iy), 110.0, Color("#ff7a4a"), 0.25)
	# hover shine sweep
	if hover:
		var sw := fmod(total_elapsed * 0.8, 1.6) - 0.3
		var sx := card.position.x + sw * card.size.x
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, card.position.y + 32), Vector2(sx + 26, card.position.y + 32),
			Vector2(sx - 24, card.end.y - 12), Vector2(sx - 50, card.end.y - 12),
		]), Color(1, 1, 1, 0.028))
	# copy
	_text_c(cx, card.position.y + 164, String(item.name), 23, C_CREAM, _font_display)
	_text_c(cx, card.position.y + 184, String(item.name_en), 10, strip, _font_mono)
	var desc: PackedStringArray = String(item.desc).split("\n")
	for d in desc.size():
		_text_c(cx, card.position.y + 216 + d * 21, desc[d], 13, Color("#c9bcdd"))
	# cost + buy
	var afford := gold >= int(item.cost)
	var cost_col := C_BRASS_L if afford else C_RED
	var pill := Rect2(cx - 66, card.position.y + 272, 132, 30)
	_rect(pill, Color(0, 0, 0, 0.4))
	_frame(pill, cost_col, 1.5)
	draw_texture_rect(coin_tex, Rect2(pill.position.x + 8, pill.position.y + 7, 16, 16), false)
	_text(Vector2(pill.position.x + 30, pill.position.y + 21), "%d 金币" % int(item.cost), 14, cost_col, _font_mono)
	_text_c(cx, card.position.y + 322, "按 %d 或点击购买" % (index + 1), 10, C_DIM2, _font_mono)
	if sold:
		_rect(card, Color(0.03, 0.02, 0.05, 0.72))
		_frame(card, C_BRASS_DK, 2.0)
		_text_c(cx, card.position.y + 176, "已 购", 30, C_BRASS, _font_display)
		_text_c(cx, card.position.y + 198, "SOLD", 12, C_DIM, _font_mono)
		_draw_diamond(Vector2(cx, card.position.y + 218), 5.0, C_BRASS_DK)


func _kind_color(kind: String) -> Color:
	match kind:
		"odds": return C_MINT
		"symbol": return C_BRASS
		"economy": return Color("#e8b24a")
		"stats": return Color("#ff7a4a")
	return C_DIM


func _kind_label(kind: String) -> String:
	match kind:
		"odds": return "概率 · ODDS"
		"symbol": return "换面 · RECAST"
		"economy": return "经济 · LEDGER"
		"stats": return "淬炼 · FORGE"
	return kind.to_upper()


func _ease_out(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


func _draw_end(won: bool) -> void:
	var ease := _ease_out(clampf(end_t * 2.2, 0.0, 1.0))
	var accent := C_MINT if won else C_RED
	_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.02, 0.015, 0.035, 0.88))
	draw_texture_rect(vignette_tex, Rect2(0, 0, VIEW.x, VIEW.y), false,
		Color(accent.r, accent.g, accent.b, 0.22 * ease))
	var center := Vector2(640, 300)
	if won:
		for i in 10:
			var a := TAU * float(i) / 10.0 + total_elapsed * 0.12
			var a2 := a + 0.10
			draw_colored_polygon(PackedVector2Array([
				Vector2(640, 308),
				Vector2(640, 308) + Vector2(cos(a), sin(a)) * 620.0,
				Vector2(640, 308) + Vector2(cos(a2), sin(a2)) * 620.0,
			]), Color(accent.r, accent.g, accent.b, 0.025))
	var panel := Rect2(300, 130 + (1.0 - ease) * 46.0, 680, 460)
	_draw_glow(panel.get_center(), 720.0, accent, 0.08)
	_rect(Rect2(panel.position + Vector2(0, 10), panel.size), Color(0, 0, 0, 0.5))
	for i in 11:
		var t := float(i) / 10.0
		_rect(Rect2(panel.position.x, panel.position.y + i * panel.size.y / 11.0, panel.size.x, panel.size.y / 11.0 + 1),
			Color("#1d142c").lerp(Color("#0e0a17"), t))
	_frame(panel, Color(0, 0, 0, 0.9), 6.0)
	_frame(panel.grow(-1.0), C_BRASS_DK, 4.0)
	_frame(panel.grow(-7.0), C_BRASS, 1.5)
	_frame(panel.grow(-12.0), Color(accent.r, accent.g, accent.b, 0.55), 1.0)
	for corner in [
		Vector2(panel.position.x + 18, panel.position.y + 18),
		Vector2(panel.end.x - 18, panel.position.y + 18),
		Vector2(panel.position.x + 18, panel.end.y - 18),
		Vector2(panel.end.x - 18, panel.end.y - 18),
	]:
		draw_circle(corner, 4.0, C_BRASS_DK)
		draw_circle(corner - Vector2(1, 1), 2.0, C_BRASS_L)
	# crest
	if won:
		_draw_glow(Vector2(640, panel.position.y + 76), 210.0, C_MINT, 0.20)
		draw_texture_rect(symbol_tex["crown"], Rect2(596, panel.position.y + 24, 88, 88), false)
		_text_glow(640, panel.position.y + 170, "VICTORY", 54, C_MINT, C_MINT)
		_text_c(640, panel.position.y + 200, "转轮守住了废墟花园", 17, C_CREAM)
	else:
		_draw_glow(Vector2(640, panel.position.y + 76), 220.0, C_RED, 0.22)
		draw_texture_rect(heart_tex["empty"], Rect2(592, panel.position.y + 34, 96, 84), false,
			Color(1.0, 0.42, 0.52, 1.0))
		draw_line(Vector2(636, panel.position.y + 40), Vector2(644, panel.position.y + 62), C_INK, 3.0)
		draw_line(Vector2(644, panel.position.y + 62), Vector2(634, panel.position.y + 82), C_INK, 3.0)
		draw_line(Vector2(644, panel.position.y + 62), Vector2(652, panel.position.y + 74), C_INK, 2.0)
		for i in 5:
			draw_rect(Rect2(Vector2(610 + i * 14, panel.position.y + 100 + (i % 2) * 8), Vector2(2, 2)),
				Color(1.0, 0.5, 0.3, 0.35))
		_text_glow(640, panel.position.y + 170, "DEFEAT", 54, C_RED, C_RED)
		_text_c(640, panel.position.y + 200, "花园失守 · 但轮盘还能再转", 17, C_CREAM)
	draw_line(Vector2(400, panel.position.y + 222), Vector2(880, panel.position.y + 222),
		Color(accent.r, accent.g, accent.b, 0.20), 1.0)
	_draw_diamond(Vector2(400, panel.position.y + 222), 3.0, C_BRASS_DK)
	_draw_diamond(Vector2(880, panel.position.y + 222), 3.0, C_BRASS_DK)
	var rows := [
		["到达波次", "WAVE %d / %d" % [wave, MAX_WAVE]],
		["旋转次数", str(stats.spins)],
		["击杀 / 升级", "%d / %d" % [stats.kills, stats.upgrades]],
		["累计金币", str(stats.coins)],
		["种子", str(seed_value)],
	]
	for i in rows.size():
		var y := panel.position.y + 258.0 + i * 30.0
		_text(Vector2(408, y), String(rows[i][0]), 13, C_DIM)
		var vw := _font_mono.get_string_size(String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(Vector2(872 - vw, y), String(rows[i][1]), 14, C_CREAM, _font_mono)
		var lx := 408.0 + _font.get_string_size(String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
		var rx := 872.0 - vw - 12.0
		var dots := int((rx - lx) / 8.0)
		for d in dots:
			draw_rect(Rect2(Vector2(lx + d * 8.0, y - 4), Vector2(2, 2)), Color(0.6, 0.5, 0.75, 0.25))
	var pulse := 0.55 + 0.45 * sin(total_elapsed * 3.0)
	var prompt_y := panel.position.y + 422.0
	var key := Rect2(506, prompt_y - 20, 76, 28)
	_rect(key, Color("#1c1530"))
	_frame(key, Color(accent.r, accent.g, accent.b, 0.8), 1.5)
	_text_c(key.get_center().x, prompt_y - 1, "R / SPACE", 10, C_CREAM, _font_mono)
	_text(Vector2(596, prompt_y), "重新开始", 18, Color(accent.r, accent.g, accent.b, pulse), _font_display)
	# victory sparkles
	if won:
		for i in 14:
			var a := total_elapsed * (0.6 + i % 3 * 0.2) + float(i) * 1.7
			var r := 190.0 + 40.0 * sin(total_elapsed * 1.4 + i)
			var p := center + Vector2(cos(a) * r, sin(a) * r * 0.42)
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.9, 0.6, 0.25 + 0.25 * sin(a * 2.0)))


# ---------------------------------------------------------------------------
# Procedural audio (skipped in headless runs)
# ---------------------------------------------------------------------------

func _build_sfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_sfx_rng.seed = 20261119
	_add_sfx("spin", _tone(760, 1180, 0.07, 0.10, true))
	_add_sfx("stop", _tone(260, 120, 0.08, 0.16, false))
	_add_sfx("coin", _melody([[880.0, 0.055], [1320.0, 0.09]], 0.18))
	_add_sfx("summon", _melody([[440.0, 0.06], [660.0, 0.06], [880.0, 0.12]], 0.16))
	_add_sfx("upgrade", _melody([[660.0, 0.05], [990.0, 0.05], [1320.0, 0.14]], 0.16))
	_add_sfx("hit", _noise(0.045, 0.10))
	_add_sfx("hurt", _tone(160, 65, 0.28, 0.20, true))
	_add_sfx("buy", _melody([[523.0, 0.05], [784.0, 0.05], [1046.0, 0.12]], 0.16))
	_add_sfx("deny", _tone(190, 130, 0.12, 0.16, true))
	_add_sfx("shop", _melody([[392.0, 0.07], [523.0, 0.07], [659.0, 0.14]], 0.14))
	_add_sfx("wave", _melody([[330.0, 0.08], [392.0, 0.08], [523.0, 0.16]], 0.14))
	_add_sfx("boss", _tone(96, 52, 0.6, 0.22, true))
	_add_sfx("bossdown", _melody([[392.0, 0.09], [330.0, 0.09], [262.0, 0.09], [196.0, 0.3]], 0.20))
	_add_sfx("win", _melody([[523.0, 0.11], [659.0, 0.11], [784.0, 0.11], [1046.0, 0.34]], 0.18))
	_add_sfx("lose", _melody([[294.0, 0.16], [262.0, 0.16], [196.0, 0.4]], 0.18))


func _add_sfx(name: String, stream: AudioStreamWAV) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -7.0
	add_child(player)
	sfx[name] = player


func play_sfx(name: String) -> void:
	if not sfx.has(name):
		return
	var player: AudioStreamPlayer = sfx[name]
	player.stop()
	player.play()


func _tone(f0: float, f1: float, dur: float, vol: float, square: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var k := t / dur
		var phase := TAU * (f0 * t + 0.5 * (f1 - f0) * t * t / dur)
		var s := sin(phase)
		if square:
			s = 1.0 if s >= 0.0 else -1.0
		var env := clampf((1.0 - k) * 3.0, 0.0, 1.0) * clampf(k * 40.0, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var k := float(i) / float(n)
		var env := (1.0 - k) * (1.0 - k)
		var s := _sfx_rng.randf_range(-1.0, 1.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _melody(notes: Array, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var total := 0.0
	for note in notes:
		total += float(note[1])
	var n := int(rate * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	var cursor := 0
	for note in notes:
		var freq: float = note[0]
		var dur: float = note[1]
		var count := int(rate * dur)
		for i in count:
			if cursor >= n:
				break
			var t := float(i) / float(rate)
			var k := float(i) / float(count)
			var env := clampf(k * 60.0, 0.0, 1.0) * clampf((1.0 - k) * 6.0, 0.0, 1.0)
			var s := sin(TAU * freq * t) * 0.75 + sin(TAU * freq * 2.0 * t) * 0.25
			data.encode_s16(cursor * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
			cursor += 1
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
