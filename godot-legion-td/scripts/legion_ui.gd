class_name LegionUI
extends Control

# 中文 HUD：资源 / 人口 / 核心 / 波次 / 单位选择 / 招募 / 建造 / 三选一 / 胜负 / 小地图。
# 全部用 Control._draw 自绘，不依赖 Theme 或外部 UI 资源；设计尺寸 1280×720。

const D := preload("res://scripts/legion_data.gd")

const DESIGN := Vector2(1280, 720)
const TOP_RECT := Rect2(12, 10, 1256, 58)
const BOTTOM_RECT := Rect2(12, 604, 1256, 104)
const MINIMAP_RECT := Rect2(1062, 78, 198, 152)
const PAD_PANEL_RECT := Rect2(302, 420, 676, 170)
const SELECT_RECT := Rect2(16, 520, 268, 76)

var game: Node
var _font: Font
var _font_bold: Font
var _font_mono: Font
var _buttons: Array[Dictionary] = []
var _hover_id := ""
var _mouse := Vector2.ZERO
var _help_visible := false
var _styles: Dictionary = {}
var _tooltip_text := ""
var _tooltip_title := ""
var _tooltip_rect := Rect2()
var _pulse := 0.0
var debug_hide_perf := false


func _ready() -> void:
	_font = _make_font(PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "Arial"]), 500)
	_font_bold = _make_font(PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "Arial"]), 700)
	_font_mono = _make_font(PackedStringArray(["SF Mono", "Menlo", "Consolas", "PingFang SC", "Noto Sans CJK SC"]), 600)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = DESIGN
	set_process(true)


func _make_font(names: PackedStringArray, weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = names
	f.font_weight = weight
	f.allow_system_fallback = true
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fb: Array[Font] = [ThemeDB.fallback_font]
	f.fallbacks = fb
	return f


func set_game(g: Node) -> void:
	game = g


func set_help_visible(v: bool) -> void:
	_help_visible = v


func is_help_visible() -> bool:
	return _help_visible


func _process(delta: float) -> void:
	_pulse += delta
	_mouse = get_local_mouse_position()
	queue_redraw()


func is_modal() -> bool:
	if game == null:
		return false
	return game.ui_state == "upgrade" or game.ui_state == "win" or game.ui_state == "lose"


func is_point_blocked(p: Vector2) -> bool:
	if is_modal():
		return true
	if TOP_RECT.has_point(p) or BOTTOM_RECT.has_point(p) or MINIMAP_RECT.has_point(p):
		return true
	if _help_visible and _help_rect().has_point(p):
		return true
	if game != null:
		if game.selected_pad_index >= 0 and PAD_PANEL_RECT.has_point(p):
			return true
		if not game.selected_units.is_empty() and SELECT_RECT.has_point(p):
			return true
	return false


func handle_click(p: Vector2) -> bool:
	for b in _buttons:
		if b.rect.has_point(p):
			if not b.enabled:
				return true
			if b.id == "minimap":
				var mr: Rect2 = b.get("map_rect", MINIMAP_RECT)
				var wx := (p.x - mr.position.x) / mr.size.x * 100.0 - 50.0
				var wz := (p.y - mr.position.y) / mr.size.y * 104.0 - 52.0
				game.jump_camera_world(Vector3(wx, 0, wz))
				return true
			if b.id.begins_with("unit:"):
				game.select_single_index(int(b.id.substr(5)))
				return true
			_activate(b)
			return true
	return is_modal()


func handle_hover(p: Vector2) -> void:
	_mouse = p


func _activate(b: Dictionary) -> void:
	if game == null:
		return
	match b.id:
		"pause":
			game.toggle_pause()
		"speed":
			game.toggle_speed()
		"help":
			_help_visible = not _help_visible
		"select_all":
			game.select_all_units()
		"stop":
			game.stop_selected()
		"attack_move":
			game.arm_attack_move()
		"start_wave":
			game.start_next_wave_early()
		"recruit:guard":
			game.recruit("guard")
		"recruit:bolt":
			game.recruit("bolt")
		"recruit:adept":
			game.recruit("adept")
		"hero_skill":
			game.hero_skill()
		"build:prism":
			game.build_tower_at_selected("prism")
		"build:mortar":
			game.build_tower_at_selected("mortar")
		"build:frost":
			game.build_tower_at_selected("frost")
		"upgrade_tower":
			game.upgrade_selected_tower()
		"sell_tower":
			game.sell_selected_tower()
		"close_pad":
			game.clear_selection()
		"upgrade:0":
			game.pick_upgrade(0)
		"upgrade:1":
			game.pick_upgrade(1)
		"upgrade:2":
			game.pick_upgrade(2)
		"reroll":
			game.reroll_upgrades()
		"restart":
			game.restart_run()


func _draw() -> void:
	if game == null:
		return
	_buttons.clear()
	_tooltip_text = ""
	_tooltip_title = ""
	_draw_world_overlay()
	_draw_top_bar()
	_draw_minimap()
	_draw_bottom_bar()
	if game.selected_pad_index >= 0 or game.barracks_selected:
		_draw_pad_panel()
	if not game.selected_units.is_empty() and game.selected_pad_index < 0 and not game.barracks_selected:
		_draw_selected_panel()
	if _help_visible:
		_draw_help()
	if game.ui_state != "upgrade" and game.ui_state != "win" and game.ui_state != "lose":
		_draw_banner()
	if game.ui_state == "upgrade":
		_draw_upgrade_overlay()
	elif game.ui_state == "win" or game.ui_state == "lose":
		_draw_end_overlay()
	_draw_tooltip()
	_draw_cursor()


# ---------------------------------------------------------------- 世界叠加层

func _draw_world_overlay() -> void:
	if game.drag_active:
		var r := Rect2(game.drag_start, game.drag_end - game.drag_start).abs()
		draw_rect(r, Color(0.28, 0.92, 0.80, 0.10))
		draw_rect(r, Color(0.55, 1.0, 0.92, 0.9), false, 1.4)
		var step := 14.0
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + 4), Color(0.55, 1.0, 0.92, 0.55), 1.0)
			draw_line(Vector2(x, r.end.y - 4), Vector2(x, r.end.y), Color(0.55, 1.0, 0.92, 0.55), 1.0)
			x += step
	if game.debug_box.size != Vector2.ZERO:
		var r2: Rect2 = game.debug_box
		draw_rect(r2, Color(0.28, 0.92, 0.80, 0.08))
		draw_rect(r2, Color(0.55, 1.0, 0.92, 0.85), false, 1.2)
	if game.attack_move_armed:
		draw_arc(_mouse, 12, 0, TAU, 24, Color(1.0, 0.42, 0.32, 0.9), 1.6)
		draw_line(_mouse + Vector2(-16, 0), _mouse + Vector2(-5, 0), Color(1.0, 0.42, 0.32, 0.9), 1.6)
		draw_line(_mouse + Vector2(5, 0), _mouse + Vector2(16, 0), Color(1.0, 0.42, 0.32, 0.9), 1.6)
		draw_line(_mouse + Vector2(0, -16), _mouse + Vector2(0, -5), Color(1.0, 0.42, 0.32, 0.9), 1.6)
		draw_line(_mouse + Vector2(0, 5), _mouse + Vector2(0, 16), Color(1.0, 0.42, 0.32, 0.9), 1.6)


# ---------------------------------------------------------------- 顶栏

func _draw_top_bar() -> void:
	_panel(TOP_RECT, D.C_PANEL, D.C_LINE)
	var x := 28.0
	_icon("coin", Vector2(x + 10, 39), 22, D.C_GOLD)
	_text(Vector2(x + 26, 45), str(game.gold), 18, D.C_TEXT, _font_bold)
	_chip_bg(Rect2(x, 20, 106, 36))
	x += 118
	_icon("crystal", Vector2(x + 10, 39), 22, D.C_ESSENCE)
	_text(Vector2(x + 26, 45), str(game.essence), 18, D.C_TEXT, _font_bold)
	_chip_bg(Rect2(x, 20, 100, 36))
	x += 112
	_icon("pop", Vector2(x + 10, 39), 22, D.C_TEAL)
	_text(Vector2(x + 26, 45), "%d/%d" % [game.pop_used, game.pop_cap], 18, D.C_TEXT, _font_bold)
	_chip_bg(Rect2(x, 20, 106, 36))

	# 中部：波次 + 进度 / 准备倒计时
	var mid := Rect2(478, 16, 322, 46)
	_chip_bg(mid, Color(0.03, 0.035, 0.05, 0.75))
	var wtxt := "准备阶段"
	if game.ui_state == "prep":
		var nw := mini(game.wave_index + 1, D.WAVES.size())
		wtxt = "下一波 · 第 %d / %d 波 · %s" % [nw, D.WAVES.size(), D.wave_def(nw - 1).get("name", "")]
	elif game.wave_index > 0:
		wtxt = "第 %d / %d 波 · %s" % [game.wave_index, D.WAVES.size(), game.wave_def.get("name", "")]
	_text(Vector2(mid.position.x + 12, mid.position.y + 18), wtxt, 13, D.C_TEXT, _font_bold)
	var mod_txt: String = game.modifier.get("name", "常规攻势")
	var mod_col: Color = D.C_DIM
	if mod_txt != "常规攻势":
		mod_col = D.C_EMBER
	_text(Vector2(mid.position.x + 12, mid.position.y + 34), "修饰 · " + mod_txt, 10, mod_col, _font)
	var bar := Rect2(mid.position.x + 12, mid.position.y + 38, 226, 5)
	draw_rect(bar, Color(0.15, 0.13, 0.18))
	var ratio := 0.0
	if game.ui_state == "wave" and game.wave_total > 0:
		ratio = float(game.wave_killed) / float(game.wave_total)
	elif game.ui_state == "prep":
		ratio = 1.0 - clampf(game.prep_t / maxf(0.01, game.prep_total), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)),
		D.C_EMBER if game.ui_state == "wave" else D.C_TEAL)
	_icon("skull", Vector2(mid.position.x + 276, mid.position.y + 23), 22, D.C_EMBER)
	if game.ui_state == "wave":
		var left := maxi(0, game.wave_total - game.wave_killed)
		_text(Vector2(mid.position.x + 288, mid.position.y + 40), "%d" % left, 11, D.C_DIM, _font_mono)
	elif game.ui_state == "prep":
		var btn := Rect2(mid.position.x + 246, mid.position.y + 4, 68, 19)
		_button(btn, "开始 (B)", "start_wave", true, "跳过准备，立即开始下一波")
		_text(Vector2(mid.position.x + 12, mid.position.y + 46), "", 9, D.C_DIM, _font)

	# 右：核心 HP + 控制
	var cx := 812.0
	_text(Vector2(cx, 28), "余烬核心", 10, D.C_DIM, _font)
	_text(Vector2(cx, 51), "%d / %d" % [int(ceil(game.core_hp)), game.core_hp_max], 17,
		D.C_TEXT if game.core_hp > 30 else D.C_BLOOD, _font_bold)
	var cbar := Rect2(cx + 92, 27, 168, 8)
	draw_rect(cbar, Color(0.12, 0.10, 0.14))
	var cr := clampf(game.core_hp / float(game.core_hp_max), 0.0, 1.0)
	var ccol := D.C_TEAL.lerp(D.C_BLOOD, 1.0 - cr) if cr < 0.5 else D.C_TEAL
	draw_rect(Rect2(cbar.position, Vector2(cbar.size.x * cr, cbar.size.y)), ccol)
	for i in range(1, 5):
		var xx := cbar.position.x + cbar.size.x * i / 5.0
		draw_line(Vector2(xx, cbar.position.y), Vector2(xx, cbar.end.y), Color(0, 0, 0, 0.35), 1.0)
	var seed_txt := "SEED %d" % game.seed_value
	_text(Vector2(cx + 92, 49), seed_txt, 9, D.C_FAINT, _font_mono)
	var btn_y := 20.0
	_button(Rect2(1062, btn_y, 42, 34), "暂停" if not game.paused else "继续", "pause", true,
		"Space 暂停 / 继续")
	_button(Rect2(1108, btn_y, 42, 34), "%d×" % int(game.speed), "speed", true,
		"Tab 切换 1× / 2×")
	_button(Rect2(1154, btn_y, 38, 34), "帮助", "help", true, "H 显示操作说明")
	if not debug_hide_perf:
		_text(Vector2(1200, 33), "%d FPS" % Engine.get_frames_per_second(), 10,
			D.C_DIM if Engine.get_frames_per_second() >= 30 else D.C_BLOOD, _font_mono)
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_text(Vector2(1200, 49), "%d dc" % dc, 9, D.C_FAINT, _font_mono)
	if game.paused:
		_text(Vector2(1198, 64), "已暂停", 10, D.C_GOLD, _font_bold)


# ---------------------------------------------------------------- 底栏

func _draw_bottom_bar() -> void:
	_panel(BOTTOM_RECT, D.C_PANEL, D.C_LINE)
	# 英雄卡
	var hr := Rect2(22, 612, 250, 88)
	_chip_bg(hr, Color(0.04, 0.05, 0.065, 0.9))
	_icon("portrait", Vector2(hr.position.x + 34, hr.position.y + 42), 52, D.C_TEAL)
	_text(Vector2(hr.position.x + 66, hr.position.y + 20), "焰语者 · 凯尔", 13, D.C_TEXT, _font_bold)
	if game.hero != null and game.hero.is_alive():
		var hpr := clampf(game.hero.hp / game.hero.max_hp, 0.0, 1.0)
		_health_bar(Rect2(hr.position.x + 66, hr.position.y + 32, 158, 7), hpr, D.C_TEAL)
		_text(Vector2(hr.position.x + 66, hr.position.y + 53),
			"%d / %d" % [int(ceil(game.hero.hp)), int(game.hero.max_hp)], 10, D.C_DIM, _font_mono)
		var cd: float = game.hero.skill_cd
		var maxcd: float = game.hero_skill_cooldown()
		var ready: bool = cd <= 0.0
		_button(Rect2(hr.position.x + 66, hr.position.y + 58, 78, 24),
			"Q 熔火震击" if ready else "Q %.0fs" % cd, "hero_skill", ready,
			"英雄范围伤害并减速周围敌人")
		_text(Vector2(hr.position.x + 150, hr.position.y + 75),
			"技能就绪" if ready else "冷却中", 9, D.C_TEAL if ready else D.C_FAINT, _font)
	else:
		_text(Vector2(hr.position.x + 66, hr.position.y + 42), "英雄阵亡", 13, D.C_BLOOD, _font_bold)
		_text(Vector2(hr.position.x + 66, hr.position.y + 60),
			"%.0fs 后在兵营复活" % ceil(game.hero_respawn_t), 10, D.C_DIM, _font)

	# 招募卡
	var start_x := 288.0
	_text(Vector2(start_x, 610), "招募军团", 10, D.C_DIM, _font)
	var hotkeys := ["Z", "X", "C"]
	for i in D.UNIT_ORDER.size():
		var kind: String = D.UNIT_ORDER[i]
		var def: Dictionary = D.unit_def(kind)
		var r := Rect2(start_x + i * 166, 618, 156, 82)
		var cd: float = game.cooldowns.get(kind, 0.0)
		var afford: bool = game.gold >= int(def.cost) and game.essence >= int(def.essence) and game.can_recruit_pop(kind)
		_card(r, def.icon, def.name, "%dg %de" % [def.cost, def.essence], "",
			"recruit:" + kind, afford, hotkeys[i])
		if cd > 0.0:
			var frac := clampf(cd / maxf(0.01, float(def.cooldown)), 0.0, 1.0)
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - frac), r.size.x, r.size.y * frac),
				Color(0.02, 0.02, 0.03, 0.62))
			_text_c(r.position.x + r.size.x * 0.5, r.position.y + 50, "%.1fs" % cd, 13, D.C_TEXT, _font_bold)
		elif not game.can_recruit_pop(kind):
			draw_rect(r, Color(0.4, 0.1, 0.1, 0.15))
		_tooltip_for("recruit:" + kind, r, def.name,
			"%s\n%s\n价格 %d 金币%s · 人口 %d · 冷却 %.0fs\n快捷键 %s" % [
				def.role, def.desc, def.cost,
				(" + %d 精粹" % def.essence) if int(def.essence) > 0 else "",
				def.pop, def.cooldown, hotkeys[i]])

	# 右侧指令
	_text(Vector2(792, 610), "指挥", 10, D.C_DIM, _font)
	_button(Rect2(792, 618, 92, 30), "全选 F", "select_all", true, "选择所有存活单位")
	_button(Rect2(890, 618, 92, 30), "停止 S", "stop", true, "停止移动/攻击，原地警戒")
	_button(Rect2(988, 618, 104, 30), "攻击移动 A", "attack_move", true,
		"进入攻击移动：左键点地，沿途自动交战")
	_text(Vector2(792, 664), "左键单选 / 拖拽框选 · 右键移动 / 攻击", 9, D.C_DIM, _font)
	_text(Vector2(792, 680), "Space 暂停 · Tab 倍速 · H 帮助 · B 开始下一波", 9, D.C_FAINT, _font)
	_text(Vector2(1104, 664), "Shift 追加选择", 9, D.C_FAINT, _font)
	_text(Vector2(1104, 680), "Ctrl+1/2/3 编队 · 1/2/3 呼叫", 9, D.C_FAINT, _font)
	if game.rally_point_set:
		_text(Vector2(950, 690), "集结点已设置", 9, D.C_TEAL, _font)
	else:
		_text(Vector2(950, 690), "选中兵营可设集结点", 9, D.C_FAINT, _font)


func _draw_selected_panel() -> void:
	_panel(SELECT_RECT, Color(0.04, 0.05, 0.065, 0.88), D.C_LINE)
	var units: Array = game.selected_units
	var shown := mini(units.size(), 5)
	_text(Vector2(SELECT_RECT.position.x + 10, SELECT_RECT.position.y + 16),
		"已选 %d 个单位" % units.size(), 10, D.C_DIM, _font)
	for i in shown:
		var u: LegionActor = units[i]
		var r := Rect2(SELECT_RECT.position.x + 8 + i * 50, SELECT_RECT.position.y + 24, 44, 42)
		var def: Dictionary = D.unit_def(u.kind)
		_chip_bg(r, Color(0.07, 0.08, 0.1, 0.9))
		_icon(def.icon, Vector2(r.position.x + 22, r.position.y + 17), 20,
			D.C_GOLD if u.is_hero else D.C_TEAL)
		_health_bar(Rect2(r.position.x + 5, r.position.y + 30, 34, 4),
			clampf(u.hp / u.max_hp, 0.0, 1.0), D.C_GOLD if u.is_hero else D.C_TEAL)
		_buttons.append({"rect": r, "id": "unit:%d" % i, "enabled": true, "data": i})
	if units.size() > shown:
		_text(Vector2(SELECT_RECT.end.x - 28, SELECT_RECT.position.y + 48), "+%d" % (units.size() - shown),
			10, D.C_DIM, _font_mono)


# ---------------------------------------------------------------- 建造 / 兵营

func _draw_pad_panel() -> void:
	_panel(PAD_PANEL_RECT, D.C_PANEL_2, D.C_LINE)
	if game.barracks_selected:
		_text(PAD_PANEL_RECT.position + Vector2(18, 28), "兵营 · 余烬集结点", 18, D.C_TEXT, _font_bold)
		_text(PAD_PANEL_RECT.position + Vector2(18, 52), "右键点击地面设置新兵集结点；新招募单位会自动前往。", 11, D.C_DIM, _font)
		_text(PAD_PANEL_RECT.position + Vector2(18, 74), "当前集结点：(%d, %d)" % [int(game.rally_point.x), int(game.rally_point.z)],
			11, D.C_TEAL, _font_mono)
		_button(Rect2(PAD_PANEL_RECT.end.x - 96, PAD_PANEL_RECT.position.y + 14, 80, 28),
			"关闭", "close_pad", true, "")
		return
	var pad_index: int = game.selected_pad_index
	var pad: Dictionary = game.world.pads[pad_index]
	var tower: LegionTower = pad.get("tower", null)
	if tower == null:
		_text(PAD_PANEL_RECT.position + Vector2(18, 28), "建造点 %02d · 选择防御塔" % (pad_index + 1), 18, D.C_TEXT, _font_bold)
		_text(PAD_PANEL_RECT.position + Vector2(18, 48), "固定建造点不可移动；塔自动索敌，升级后射程与伤害提高。", 10, D.C_DIM, _font)
		for i in D.TOWER_ORDER.size():
			var kind: String = D.TOWER_ORDER[i]
			var def: Dictionary = D.tower_def(kind)
			var r := Rect2(PAD_PANEL_RECT.position.x + 18 + i * 214, PAD_PANEL_RECT.position.y + 60, 198, 96)
			var afford: bool = game.gold >= int(def.cost) and game.essence >= int(def.essence)
			_card(r, def.icon, def.name, "%dg %de" % [def.cost, def.essence], def.role,
				"build:" + kind, afford, str(i + 1), true)
			_tooltip_for("build:" + kind, r, def.name,
				"%s\n%s\n伤害 %.0f · 射程 %.1f · 间隔 %.2fs\n价格 %d 金币 + %d 精粹" % [
					def.role, def.desc, def.damage, def.range, def.interval, def.cost, def.essence])
		_button(Rect2(PAD_PANEL_RECT.end.x - 82, PAD_PANEL_RECT.position.y + 14, 66, 24),
			"关闭", "close_pad", true, "")
	else:
		var def: Dictionary = D.tower_def(tower.kind)
		_text(PAD_PANEL_RECT.position + Vector2(18, 28), "%s · Lv.%d" % [def.name, tower.level], 18, D.C_TEXT, _font_bold)
		_text(PAD_PANEL_RECT.position + Vector2(18, 50), def.desc, 10, D.C_DIM, _font)
		_text(PAD_PANEL_RECT.position + Vector2(18, 74),
			"伤害 %.0f · 射程 %.1f · 间隔 %.2fs%s" % [tower.effective_damage(), tower.effective_range(),
				tower.effective_interval(),
				(" · 减速 %d%%" % int(tower.effective_slow() * 100.0)) if tower.effective_slow() > 0.0 else ""],
			11, D.C_TEAL, _font_mono)
		var cost: Array = tower.upgrade_cost()
		var up_ok: bool = tower.level < D.TOWER_MAX_LEVEL and game.gold >= int(cost[0]) and game.essence >= int(cost[1])
		var label := "已满级"
		if tower.level < D.TOWER_MAX_LEVEL:
			label = "升级 %dg %de" % [cost[0], cost[1]]
		_button(Rect2(PAD_PANEL_RECT.position.x + 18, PAD_PANEL_RECT.position.y + 96, 160, 34),
			label, "upgrade_tower", up_ok, "提升伤害 50%、射程 8%")
		var sv: Array = tower.sell_value()
		_button(Rect2(PAD_PANEL_RECT.position.x + 186, PAD_PANEL_RECT.position.y + 96, 150, 34),
			"出售 +%dg +%de" % [sv[0], sv[1]], "sell_tower", true, "返还投入的 60%")
		_button(Rect2(PAD_PANEL_RECT.end.x - 82, PAD_PANEL_RECT.position.y + 14, 66, 24),
			"关闭", "close_pad", true, "")
		_text(PAD_PANEL_RECT.position + Vector2(352, 116), "射程环已显示", 10, D.C_FAINT, _font)
		_tooltip_for("upgrade_tower", Rect2(PAD_PANEL_RECT.position.x + 18, PAD_PANEL_RECT.position.y + 96, 160, 34),
			"塔升级", "最多 Lv.3，每级 +50% 伤害、+8% 射程。")


# ---------------------------------------------------------------- 小地图

func _draw_minimap() -> void:
	_panel(MINIMAP_RECT, Color(0.03, 0.035, 0.05, 0.93), D.C_LINE)
	var inner := MINIMAP_RECT.grow(-6)
	draw_rect(inner, Color(0.06, 0.04, 0.07, 0.9))
	# 岛体近似
	var map_w := inner.size.x / 100.0
	var map_h := inner.size.y / 104.0
	var cx := inner.position.x + inner.size.x * 0.5
	var cy := inner.position.y + inner.size.y * 0.52
	draw_set_transform(Vector2(cx, cy), 0.0, Vector2(map_w, map_h))
	draw_circle(Vector2.ZERO, 44, Color(0.16, 0.20, 0.16, 0.95))
	draw_circle(Vector2(-36, -28), 13, Color(0.16, 0.20, 0.16, 0.95))
	draw_circle(Vector2(36, -28), 13, Color(0.16, 0.20, 0.16, 0.95))
	draw_circle(Vector2(0, -43), 12, Color(0.16, 0.20, 0.16, 0.95))
	draw_circle(Vector2(0, 31), 15, Color(0.18, 0.22, 0.18, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var to_mini := func(p: Vector3) -> Vector2:
		return Vector2(inner.position.x + (p.x + 50.0) / 100.0 * inner.size.x,
			inner.position.y + (p.z + 52.0) / 104.0 * inner.size.y)
	for lane in game.world.lane_paths:
		var pts := PackedVector2Array()
		for p in lane:
			pts.append(to_mini.call(p))
		draw_polyline(pts, Color(0.55, 0.45, 0.40, 0.55), 1.2)
	for p in game.world.portals:
		var mp: Vector2 = to_mini.call(p.pos)
		draw_circle(mp, 3.0, Color(0.75, 0.42, 1.0, 0.95))
		draw_arc(mp, 5.0, 0, TAU, 12, Color(0.75, 0.42, 1.0, 0.35), 1.0)
	var core_p: Vector2 = to_mini.call(game.world.CORE_POS)
	draw_colored_polygon(PackedVector2Array([
		core_p + Vector2(0, -5), core_p + Vector2(5, 0), core_p + Vector2(0, 5), core_p + Vector2(-5, 0)
	]), D.C_TEAL)
	for pad in game.world.pads:
		var mp2: Vector2 = to_mini.call(pad.pos)
		draw_circle(mp2, 2.0, D.C_TEAL if pad.get("tower", null) != null else Color(0.4, 0.5, 0.5, 0.7))
	for u in game.units:
		if u == null or not u.is_alive():
			continue
		var mp3: Vector2 = to_mini.call(u.global_position)
		draw_circle(mp3, 1.8 if u.is_hero else 1.1, D.C_GOLD if u.is_hero else D.C_TEAL)
	for e in game.enemies:
		if e == null or not e.is_alive():
			continue
		var mp4: Vector2 = to_mini.call(e.global_position)
		draw_circle(mp4, 1.5 if e.kind == "colossus" else 1.0, Color(1.0, 0.35, 0.45))
	# 相机位置
	var ct: Vector3 = game.world.get_cam_target()
	var cp: Vector2 = to_mini.call(ct)
	draw_rect(Rect2(cp - Vector2(22, 16), Vector2(44, 32)), Color(0.8, 0.95, 0.9, 0.35), false, 1.0)
	_buttons.append({"rect": MINIMAP_RECT, "id": "minimap", "enabled": true,
		"data": ct, "map_rect": inner})


# ---------------------------------------------------------------- 升级三选一

func _draw_upgrade_overlay() -> void:
	_buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.015, 0.012, 0.028, 0.78))
	_text_c(DESIGN.x * 0.5, 86, "波 次 肃 清", 30, D.C_TEXT, _font_bold)
	_text_c(DESIGN.x * 0.5, 116, "选一个强化 · 进入下一波", 13, D.C_DIM, _font)
	var sub := "第 %d 波结束 · 击杀 %d · 金币 +%d · 精粹 +%d" % [
		game.wave_index, game.kills, game.gold_earned, game.essence_earned]
	_text_c(DESIGN.x * 0.5, 140, sub, 11, D.C_FAINT, _font_mono)
	var choices: Array = game.upgrade_choices
	var card_w := 300.0
	var gap := 36.0
	var total_w := choices.size() * card_w + (choices.size() - 1) * gap
	var x0 := (DESIGN.x - total_w) * 0.5
	for i in choices.size():
		var id: String = choices[i]
		var def: Dictionary = D.upgrade_def(id)
		var r := Rect2(x0 + i * (card_w + gap), 176, card_w, 336)
		var hovered := r.has_point(_mouse)
		var col := Color(def.color)
		_card_bg(r, hovered, col)
		# 六边形图标
		var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 104)
		_hex(c, 64, col, hovered)
		_icon(def.icon, c, 64, col.lightened(0.4))
		_text_c(c.x, r.position.y + 196, def.name, 25, D.C_TEXT, _font_bold)
		var lv := int(game.upgrade_levels.get(id, 0))
		_text_c(c.x, r.position.y + 220, "等级 %d / %d" % [lv, def.max], 11, col, _font_mono)
		_text_c(c.x, r.position.y + 252, def.desc, 14, D.C_TEXT, _font)
		_text_c(c.x, r.position.y + 274, def.detail, 10, D.C_DIM, _font)
		_text_c(c.x, r.position.y + 316, "按 %d 选择" % (i + 1), 11, D.C_FAINT, _font_mono)
		_buttons.append({"rect": r, "id": "upgrade:%d" % i, "enabled": true, "data": i})
		if hovered:
			_tooltip_title = def.name
			_tooltip_text = def.desc + "\n" + def.detail
	var rr := Rect2(DESIGN.x * 0.5 - 76, 538, 152, 34)
	var can_reroll: bool = game.rerolls_left > 0
	_button(rr, "重掷（%d）" % game.rerolls_left, "reroll", can_reroll,
		"重新随机三张强化；整局有限次数")
	_text_c(DESIGN.x * 0.5, 600, "强化只在本局生效 · 失败或重开会重置", 10, D.C_FAINT, _font)
	_text_c(DESIGN.x * 0.5, 618, "SEED %d" % game.seed_value, 9, D.C_FAINT, _font_mono)


func _card_bg(r: Rect2, hovered: bool, accent: Color) -> void:
	draw_style_box(_style(Color(0.055, 0.06, 0.082, 0.98), accent.darkened(0.3), 1, 8), r)
	if hovered:
		draw_style_box(_style(Color(0.10, 0.11, 0.14, 0.98), accent, 2, 8), r)
		draw_line(r.position + Vector2(18, 0), r.position + Vector2(r.size.x - 18, 0), accent, 2.0)
	# 四角装饰
	var c := Color(accent.r, accent.g, accent.b, 0.55)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		draw_line(corner, corner + Vector2(14 * sx, 0), c, 1.2)
		draw_line(corner, corner + Vector2(0, 14 * sy), c, 1.2)


func _hex(c: Vector2, radius: float, col: Color, hovered: bool) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := -PI * 0.5 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, Color(col.r * 0.16, col.g * 0.18, col.b * 0.20, 0.95))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(col.r, col.g, col.b, 0.9 if hovered else 0.55), 2.0)
	var inner := PackedVector2Array()
	for i in 6:
		var a := -PI * 0.5 + i * TAU / 6.0
		inner.append(c + Vector2(cos(a), sin(a)) * (radius - 8))
	inner.append(inner[0])
	draw_polyline(inner, Color(col.r, col.g, col.b, 0.18), 1.0)


# ---------------------------------------------------------------- 胜负

func _draw_end_overlay() -> void:
	_buttons.clear()
	var win: bool = game.ui_state == "win"
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.012, 0.010, 0.022, 0.82))
	var accent := D.C_TEAL if win else D.C_BLOOD
	_text_c(DESIGN.x * 0.5, 176, "裂 隙 肃 清" if win else "核 心 失 守", 42, accent, _font_bold)
	_text_c(DESIGN.x * 0.5, 210, "余烬守望守住了三线" if win else "虚空蠕群淹没了余烬核心",
		14, D.C_DIM, _font)
	var r := Rect2(DESIGN.x * 0.5 - 230, 248, 460, 178)
	_panel(r, Color(0.045, 0.05, 0.07, 0.96), Color(accent.r, accent.g, accent.b, 0.45))
	var rows := [
		["到达波次", "%d / %d" % [game.wave_index, D.WAVES.size()]],
		["击杀敌人", str(game.kills)],
		["累计金币", str(game.gold_earned)],
		["累计精粹", str(game.essence_earned)],
		["本局用时", "%02d:%02d" % [int(game.run_time / 60.0), int(game.run_time) % 60]],
		["本局种子", str(game.seed_value)],
	]
	for i in rows.size():
		var y := r.position.y + 28 + i * 25
		_text(Vector2(r.position.x + 28, y), rows[i][0], 12, D.C_DIM, _font)
		_text(Vector2(r.position.x + 190, y), rows[i][1], 13, D.C_TEXT, _font_mono)
	var btn := Rect2(DESIGN.x * 0.5 - 110, 454, 220, 44)
	_button(btn, "再来一局  R", "restart", true, "新种子，重新开始")
	_text_c(DESIGN.x * 0.5, 528, "第 %d 波 · %s" % [game.wave_index, game.wave_def.get("name", "")],
		11, D.C_FAINT, _font)
	_text_c(DESIGN.x * 0.5, 550, "本局强化已重置 · 每局都是新的种子", 10, D.C_FAINT, _font)


# ---------------------------------------------------------------- 横幅 / 帮助

func _draw_banner() -> void:
	if game.banner_t <= 0.0:
		return
	var t: float = game.banner_t
	var a := clampf(minf(t, 1.0), 0.0, 1.0)
	var y := 92.0 - (1.0 - clampf(t / 0.5, 0.0, 1.0)) * 12.0
	var txt: String = game.banner_text
	var sub: String = game.banner_sub
	var w := 480.0
	var r := Rect2(DESIGN.x * 0.5 - w * 0.5, y, w, 48 if sub == "" else 62)
	draw_style_box(_style(Color(0.03, 0.035, 0.05, 0.82 * a), Color(0.35, 0.9, 0.8, 0.4 * a), 1, 5), r)
	_text_c(DESIGN.x * 0.5, y + (24 if sub == "" else 26), txt, 18, Color(1, 1, 1, a), _font_bold)
	if sub != "":
		_text_c(DESIGN.x * 0.5, y + 46, sub, 11, Color(0.7, 0.7, 0.75, a), _font)


func _help_rect() -> Rect2:
	return Rect2(410, 152, 460, 360)


func _draw_help() -> void:
	var r := _help_rect()
	_panel(r, Color(0.035, 0.04, 0.058, 0.97), D.C_LINE)
	_text(r.position + Vector2(20, 28), "操作说明", 18, D.C_TEXT, _font_bold)
	var rows := [
		["左键", "单选；拖拽框选；Shift 追加"],
		["右键", "移动到地面 / 攻击敌人"],
		["A + 左键", "攻击移动：沿途自动交战"],
		["S", "停止并原地警戒"],
		["F", "全选存活单位"],
		["Z / X / C", "招募卫士 / 弩手 / 术士"],
		["Q", "英雄熔火震击"],
		["Space / Tab", "暂停 / 1× 或 2× 速度"],
		["B", "准备阶段立即开波"],
		["H", "显示 / 收起本帮助"],
		["1/2/3", "选中空建造点时建塔；否则呼叫编队"],
		["Ctrl+1/2/3", "记录当前选择为编队"],
		["R", "结算画面重开；Esc 取消"],
	]
	for i in rows.size():
		var y := r.position.y + 60 + i * 21
		_text(r.position + Vector2(20, 60 + i * 21), rows[i][0], 11, D.C_TEAL, _font_mono)
		_text(r.position + Vector2(126, 60 + i * 21), rows[i][1], 11, D.C_TEXT, _font)
	_text(r.position + Vector2(20, 346), "提示：塔建在固定建造点；框选后右键集火；每波结束三选一。",
		9, D.C_FAINT, _font)


# ---------------------------------------------------------------- 工具提示 / 光标

func _draw_tooltip() -> void:
	if _tooltip_title == "":
		return
	var pos := _mouse + Vector2(18, 18)
	var w := 270.0
	var lines := _tooltip_text.split("\n")
	var h := 34.0 + lines.size() * 15.0
	if pos.x + w > DESIGN.x - 12:
		pos.x = _mouse.x - w - 16
	if pos.y + h > DESIGN.y - 12:
		pos.y = _mouse.y - h - 14
	var r := Rect2(pos, Vector2(w, h))
	_panel(r, Color(0.03, 0.035, 0.05, 0.97), Color(0.35, 0.8, 0.75, 0.5))
	_text(r.position + Vector2(12, 20), _tooltip_title, 12, D.C_TEXT, _font_bold)
	for i in lines.size():
		_text(r.position + Vector2(12, 38 + i * 15), lines[i], 9, D.C_DIM, _font)


func _tooltip_for(id: String, r: Rect2, title: String, text: String) -> void:
	if r.has_point(_mouse):
		_tooltip_title = title
		_tooltip_text = text


func _draw_cursor() -> void:
	if not is_modal() and not is_point_blocked(_mouse):
		draw_circle(_mouse, 2.0, Color(0.7, 0.9, 0.85, 0.35))


# ---------------------------------------------------------------- 基础绘制

func _panel(r: Rect2, fill: Color, border: Color) -> void:
	draw_style_box(_style(fill, border, 1, 6), r)


func _chip_bg(r: Rect2, fill: Color = Color(0.035, 0.042, 0.058, 0.65)) -> void:
	draw_style_box(_style(fill, Color(0.28, 0.32, 0.38, 0.35), 1, 4), r)


func _health_bar(r: Rect2, ratio: float, color: Color) -> void:
	draw_rect(r, Color(0.06, 0.05, 0.07, 0.9))
	var rr := Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y))
	draw_rect(rr, color)
	draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)


func _text(pos: Vector2, txt: String, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_c(cx: float, y: float, txt: String, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(cx - w * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _button(r: Rect2, label: String, id: String, enabled: bool, tooltip: String = "") -> void:
	var hovered := r.has_point(_mouse)
	var fill := Color(0.07, 0.09, 0.115, 0.95) if enabled else Color(0.045, 0.045, 0.055, 0.8)
	var border := Color(0.30, 0.78, 0.72, 0.45) if enabled else Color(0.22, 0.22, 0.26, 0.4)
	if hovered and enabled:
		fill = Color(0.10, 0.15, 0.16, 0.98)
		border = Color(0.45, 1.0, 0.9, 0.8)
	draw_style_box(_style(fill, border, 1, 4), r)
	_text_c(r.get_center().x, r.position.y + r.size.y * 0.5 + 4, label, 11,
		D.C_TEXT if enabled else D.C_FAINT, _font_bold)
	_buttons.append({"rect": r, "id": id, "enabled": enabled, "data": 0})
	if hovered and tooltip != "":
		_tooltip_title = label
		_tooltip_text = tooltip


func _card(r: Rect2, icon: String, title: String, cost: String, subtitle: String,
		id: String, enabled: bool, key: String, show_full: bool = false) -> void:
	var hovered := r.has_point(_mouse)
	var fill := Color(0.055, 0.065, 0.085, 0.95) if enabled else Color(0.04, 0.04, 0.05, 0.9)
	var border := Color(0.3, 0.72, 0.66, 0.4) if enabled else Color(0.22, 0.22, 0.26, 0.4)
	if hovered and enabled:
		fill = Color(0.10, 0.13, 0.15, 0.98)
		border = Color(0.5, 1.0, 0.9, 0.85)
	draw_style_box(_style(fill, border, 1, 5), r)
	_icon(icon, Vector2(r.position.x + 28, r.position.y + 28), 34, D.C_TEAL if enabled else D.C_FAINT)
	_text(Vector2(r.position.x + 52, r.position.y + 23), title, 12, D.C_TEXT if enabled else D.C_FAINT, _font_bold)
	_text(Vector2(r.position.x + 52, r.position.y + 40), cost, 10,
		D.C_GOLD if enabled else D.C_FAINT, _font_mono)
	if subtitle != "":
		_text(Vector2(r.position.x + 10, r.position.y + 62), subtitle, 9,
			D.C_DIM, _font)
	if show_full:
		_text(Vector2(r.position.x + 10, r.position.y + 80), "自动索敌 · 可升级", 9, D.C_FAINT, _font)
	var kr := Rect2(r.end.x - 22, r.position.y + 6, 16, 16)
	draw_style_box(_style(Color(0.02, 0.03, 0.04, 0.8), Color(0.35, 0.55, 0.55, 0.5), 1, 3), kr)
	_text_c(kr.get_center().x, kr.position.y + 12, key, 9, D.C_DIM, _font_mono)
	_buttons.append({"rect": r, "id": id, "enabled": enabled, "data": 0})


func _style(fill: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), bw, radius]
	if _styles.has(key):
		return _styles[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	_styles[key] = sb
	return sb


func _icon(kind: String, c: Vector2, s: float, col: Color) -> void:
	var half := s * 0.5
	match kind:
		"coin":
			draw_circle(c, half, col)
			draw_circle(c, half * 0.68, Color(0.10, 0.08, 0.05, 0.85))
			draw_arc(c, half * 0.45, 0, TAU, 16, col.lightened(0.2), 1.4)
			draw_line(c + Vector2(-2, -half * 0.3), c + Vector2(-2, half * 0.3), col, 1.4)
		"crystal":
			var pts := PackedVector2Array([c + Vector2(0, -half), c + Vector2(half * 0.62, -half * 0.12),
				c + Vector2(0, half), c + Vector2(-half * 0.62, -half * 0.12)])
			draw_colored_polygon(pts, col)
			var inner := PackedVector2Array([c + Vector2(0, -half * 0.66), c + Vector2(half * 0.34, -half * 0.08),
				c + Vector2(0, half * 0.66), c + Vector2(-half * 0.34, -half * 0.08)])
			draw_colored_polygon(inner, col.lightened(0.45))
		"pop":
			draw_circle(c + Vector2(0, -half * 0.34), half * 0.30, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-half * 0.52, half * 0.52), c + Vector2(-half * 0.30, -half * 0.05),
				c + Vector2(half * 0.30, -half * 0.05), c + Vector2(half * 0.52, half * 0.52)
			]), col)
		"skull":
			draw_circle(c + Vector2(0, -half * 0.16), half * 0.62, col)
			draw_rect(Rect2(c + Vector2(-half * 0.30, half * 0.18), Vector2(half * 0.60, half * 0.42)), col)
			draw_circle(c + Vector2(-half * 0.22, -half * 0.18), half * 0.16, Color(0.04, 0.03, 0.05))
			draw_circle(c + Vector2(half * 0.22, -half * 0.18), half * 0.16, Color(0.04, 0.03, 0.05))
		"sword":
			draw_line(c + Vector2(-half * 0.42, half * 0.42), c + Vector2(half * 0.34, -half * 0.38), col, 2.4)
			draw_line(c + Vector2(-half * 0.52, half * 0.06), c + Vector2(-half * 0.02, half * 0.54), col, 2.2)
			draw_line(c + Vector2(half * 0.12, -half * 0.56), c + Vector2(half * 0.56, -half * 0.12), col, 2.0)
		"shield":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -half * 0.8), c + Vector2(half * 0.62, -half * 0.45),
				c + Vector2(half * 0.46, half * 0.28), c + Vector2(0, half * 0.82),
				c + Vector2(-half * 0.46, half * 0.28), c + Vector2(-half * 0.62, -half * 0.45)
			]), Color(col.r, col.g, col.b, 0.30))
			var pts := PackedVector2Array([c + Vector2(0, -half * 0.78), c + Vector2(half * 0.6, -half * 0.42),
				c + Vector2(half * 0.44, half * 0.26), c + Vector2(0, half * 0.78),
				c + Vector2(-half * 0.44, half * 0.26), c + Vector2(-half * 0.6, -half * 0.42)])
			pts.append(pts[0])
			draw_polyline(pts, col, 2.0)
			draw_line(c + Vector2(0, -half * 0.5), c + Vector2(0, half * 0.5), col, 1.4)
		"bow":
			draw_arc(c + Vector2(-half * 0.2, 0), half * 0.6, -1.1, 1.1, 14, col, 2.2)
			draw_line(c + Vector2(-half * 0.2, -half * 0.56), c + Vector2(-half * 0.2, half * 0.56), col, 1.3)
			draw_line(c + Vector2(-half * 0.2, 0), c + Vector2(half * 0.6, 0), col, 1.8)
			draw_line(c + Vector2(half * 0.6, 0), c + Vector2(half * 0.36, -half * 0.16), col, 1.6)
		"staff":
			draw_line(c + Vector2(-half * 0.45, half * 0.7), c + Vector2(half * 0.18, -half * 0.3), col, 2.2)
			draw_circle(c + Vector2(half * 0.3, -half * 0.48), half * 0.28, Color(col.r, col.g, col.b, 0.35))
			draw_arc(c + Vector2(half * 0.3, -half * 0.48), half * 0.28, 0, TAU, 14, col, 2.0)
		"flame":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -half * 0.85), c + Vector2(half * 0.50, -half * 0.05),
				c + Vector2(half * 0.30, half * 0.58), c + Vector2(0, half * 0.85),
				c + Vector2(-half * 0.30, half * 0.58), c + Vector2(-half * 0.50, -half * 0.05)
			]), Color(col.r, col.g, col.b, 0.65))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -half * 0.35), c + Vector2(half * 0.22, half * 0.1),
				c + Vector2(0, half * 0.6), c + Vector2(-half * 0.22, half * 0.1)
			]), col.lightened(0.5))
		"tower":
			draw_rect(Rect2(c + Vector2(-half * 0.42, -half * 0.1), Vector2(half * 0.84, half * 0.85)), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-half * 0.62, -half * 0.1), c + Vector2(-half * 0.36, -half * 0.55),
				c + Vector2(half * 0.36, -half * 0.55), c + Vector2(half * 0.62, -half * 0.1)
			]), col)
			draw_rect(Rect2(c + Vector2(-half * 0.18, half * 0.25), Vector2(half * 0.36, half * 0.45)),
				Color(0.05, 0.05, 0.06))
		"prism":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -half * 0.82), c + Vector2(half * 0.45, half * 0.62),
				c + Vector2(0, half * 0.30), c + Vector2(-half * 0.45, half * 0.62)
			]), Color(col.r, col.g, col.b, 0.9))
			draw_line(c + Vector2(0, -half * 0.82), c + Vector2(0, half * 0.3), col.lightened(0.5), 1.2)
		"mortar":
			draw_circle(c + Vector2(0, half * 0.32), half * 0.45, col.darkened(0.25))
			draw_line(c + Vector2(-half * 0.3, half * 0.3), c + Vector2(half * 0.28, -half * 0.48), col, 6.0)
			draw_circle(c + Vector2(half * 0.3, -half * 0.5), half * 0.18, col.lightened(0.4))
		"frost":
			for i in 3:
				var a := i * PI / 3.0
				draw_line(c - Vector2(cos(a), sin(a)) * half * 0.7, c + Vector2(cos(a), sin(a)) * half * 0.7, col, 1.8)
			draw_circle(c, half * 0.15, col)
		"gear":
			draw_arc(c, half * 0.5, 0, TAU, 16, col, 3.0)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * half * 0.5,
					c + Vector2(cos(a), sin(a)) * half * 0.8, col, 3.0)
			draw_circle(c, half * 0.18, Color(0.05, 0.05, 0.06))
		"boot":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-half * 0.35, -half * 0.6), c + Vector2(half * 0.05, -half * 0.6),
				c + Vector2(half * 0.05, half * 0.1), c + Vector2(half * 0.62, half * 0.38),
				c + Vector2(half * 0.62, half * 0.64), c + Vector2(-half * 0.35, half * 0.64)
			]), col)
		"snow":
			_icon("frost", c, s, col)
		"banner":
			draw_line(c + Vector2(-half * 0.5, -half * 0.8), c + Vector2(-half * 0.5, half * 0.8), col, 2.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-half * 0.5, -half * 0.7), c + Vector2(half * 0.55, -half * 0.45),
				c + Vector2(half * 0.2, half * 0.1), c + Vector2(-half * 0.5, half * 0.1)
			]), Color(col.r, col.g, col.b, 0.7))
		"portrait":
			draw_circle(c, half * 0.88, Color(col.r * 0.25, col.g * 0.3, col.b * 0.3, 0.85))
			draw_arc(c, half * 0.88, 0, TAU, 24, col, 1.6)
			draw_circle(c + Vector2(0, -half * 0.1), half * 0.28, Color("#c6a184"))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-half * 0.46, half * 0.55), c + Vector2(-half * 0.28, half * 0.02),
				c + Vector2(half * 0.28, half * 0.02), c + Vector2(half * 0.46, half * 0.55)
			]), Color("#276e68"))
			draw_line(c + Vector2(-half * 0.3, -half * 0.34), c + Vector2(half * 0.3, -half * 0.34), col, 2.0)
			draw_circle(c + Vector2(0, -half * 0.45), half * 0.12, col)
		_:
			draw_circle(c, half * 0.5, col)
