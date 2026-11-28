class_name LegionUI
extends Control

# Legionfall HUD (T-020 art pass).
# Design canvas 1280x720 (1x at 720p, 1.5x at 1080p). Thick-edged stone/ember
# panels, solid two-tone icons, key text >=16 design px, no debug chrome.
# Still drawn with Control._draw so it stays dependency-free.

const D := preload("res://scripts/legion_data.gd")

const DESIGN := Vector2(1280, 720)
const TOP_RECT := Rect2(12, 10, 1256, 58)
const BOTTOM_RECT := Rect2(12, 616, 1256, 92)
const MINIMAP_RECT := Rect2(1074, 78, 180, 132)
const PAD_PANEL_RECT := Rect2(310, 404, 660, 196)
const SELECT_RECT := Rect2(16, 546, 264, 62)

const PANEL := Color(0.047, 0.067, 0.078, 0.94)
const PANEL_2 := Color(0.075, 0.098, 0.102, 0.95)
const PANEL_DEEP := Color(0.027, 0.039, 0.047, 0.96)
const BORDER := Color("#2E423D")
const BORDER_LIGHT := Color("#3E5A55")
const INK := Color("#EFE6D4")
const MUTED := Color("#A9A092")
const FAINT := Color("#8E8779")

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
var _pulse := 0.0
var debug_hide_perf := false
var show_debug := false


func _ready() -> void:
	_font = _make_font(PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "Arial"]), 500)
	_font_bold = _make_font(PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "Arial"]), 700)
	_font_mono = _make_font(PackedStringArray(["Inter", "SF Mono", "Menlo", "Consolas", "PingFang SC"]), 600)
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


# ---------------------------------------------------------------- world overlay

func _draw_world_overlay() -> void:
	if game.drag_active:
		var r := Rect2(game.drag_start, game.drag_end - game.drag_start).abs()
		draw_rect(r, Color(0.37, 0.88, 0.75, 0.08))
		draw_rect(r, Color(0.55, 1.0, 0.92, 0.85), false, 1.4)
		var step := 16.0
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + 5), Color(0.55, 1.0, 0.92, 0.5), 1.0)
			draw_line(Vector2(x, r.end.y - 5), Vector2(x, r.end.y), Color(0.55, 1.0, 0.92, 0.5), 1.0)
			x += step
	if game.debug_box.size != Vector2.ZERO:
		var r2: Rect2 = game.debug_box
		draw_rect(r2, Color(0.37, 0.88, 0.75, 0.06))
		draw_rect(r2, Color(0.55, 1.0, 0.92, 0.8), false, 1.2)
	if game.attack_move_armed:
		var c := Color(1.0, 0.54, 0.28, 0.95)
		draw_arc(_mouse, 13, 0, TAU, 24, c, 1.8)
		for i in 4:
			var a := i * PI * 0.5 + PI * 0.25
			draw_line(_mouse + Vector2(cos(a), sin(a)) * 8, _mouse + Vector2(cos(a), sin(a)) * 18, c, 2.0)


# ---------------------------------------------------------------- top bar

func _draw_top_bar() -> void:
	_panel(TOP_RECT, PANEL, BORDER)
	draw_line(Vector2(TOP_RECT.position.x + 8, TOP_RECT.position.y + 1.5),
		Vector2(TOP_RECT.end.x - 8, TOP_RECT.position.y + 1.5), BORDER_LIGHT, 1.0)

	# resources: three ember-stone chips
	_res_chip(Rect2(24, 18, 108, 42), "coin", str(game.gold), "金币", D.C_GOLD)
	_res_chip(Rect2(140, 18, 102, 42), "crystal", str(game.essence), "精粹", D.C_ESSENCE)
	_res_chip(Rect2(250, 18, 104, 42), "pop", "%d/%d" % [game.pop_used, game.pop_cap], "人口", D.C_TEAL)

	# wave panel
	var mid := Rect2(366, 16, 392, 46)
	_chip_bg(mid, Color(0.03, 0.045, 0.05, 0.8))
	var wave_title := "准备阶段"
	var wave_name := ""
	var progress_ratio := 0.0
	if game.ui_state == "prep":
		var nw := mini(game.wave_index + 1, D.WAVES.size())
		wave_title = "第 %d / %d 波准备" % [nw, D.WAVES.size()]
		wave_name = String(D.wave_def(nw - 1).get("name", ""))
		progress_ratio = 1.0 - clampf(game.prep_t / maxf(0.01, game.prep_total), 0.0, 1.0)
	elif game.wave_index > 0:
		wave_title = "第 %d / %d 波" % [game.wave_index, D.WAVES.size()]
		wave_name = String(game.wave_def.get("name", ""))
		if game.wave_total > 0:
			progress_ratio = float(game.wave_killed) / float(game.wave_total)
	_text(Vector2(mid.position.x + 14, mid.position.y + 20), wave_title, 16, INK, _font_bold)
	if game.ui_state == "wave":
		_icon("skull", Vector2(mid.position.x + 250, mid.position.y + 18), 18, D.C_EMBER)
		var left := maxi(0, game.wave_total - game.wave_killed)
		_text(Vector2(mid.position.x + 263, mid.position.y + 24), str(left),
			16, INK, _font_mono)
	var mod_name := String(game.modifier.get("name", "常规攻势"))
	_text(Vector2(mid.position.x + 14, mid.position.y + 38), wave_name, 13, MUTED, _font)
	_text(Vector2(mid.position.x + 128, mid.position.y + 38), "· " + mod_name, 13,
		D.C_EMBER if mod_name != "常规攻势" else FAINT, _font)
	var bar := Rect2(mid.position.x + 14, mid.position.y + 41, 222, 3)
	draw_rect(bar, Color(0.12, 0.14, 0.13))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress_ratio, 0.0, 1.0), bar.size.y)),
		D.C_EMBER if game.ui_state == "wave" else D.C_TEAL)
	if game.ui_state == "prep":
		var secs := "%.0fs" % ceil(game.prep_t)
		_text(Vector2(mid.position.x + 248, mid.position.y + 24), secs, 18, D.C_TEAL, _font_bold)
	_button(Rect2(mid.position.x + 306, mid.position.y + 8, 74, 28), "开始 B", "start_wave",
		game.ui_state == "prep", "跳过准备，立即开始下一波")

	# core health
	var cx := 776.0
	_icon("crystal", Vector2(cx + 10, 36), 18, D.C_TEAL)
	_text(Vector2(cx + 24, 30), "余烬核心", 13, MUTED, _font)
	_text(Vector2(cx + 24, 52), "%d / %d" % [int(ceil(game.core_hp)), game.core_hp_max], 18,
		INK if game.core_hp > 30 else D.C_BLOOD, _font_bold)
	var cbar := Rect2(cx + 112, 34, 132, 9)
	draw_rect(cbar, Color(0.10, 0.12, 0.12))
	var cr := clampf(game.core_hp / float(maxi(1, game.core_hp_max)), 0.0, 1.0)
	var ccol := D.C_TEAL.lerp(D.C_BLOOD, 1.0 - cr) if cr < 0.5 else D.C_TEAL
	draw_rect(Rect2(cbar.position, Vector2(cbar.size.x * cr, cbar.size.y)), ccol)
	draw_rect(cbar, Color(0, 0, 0, 0.45), false, 1.0)
	for i in range(1, 5):
		var xx := cbar.position.x + cbar.size.x * i / 5.0
		draw_line(Vector2(xx, cbar.position.y + 1), Vector2(xx, cbar.end.y - 1), Color(0, 0, 0, 0.35), 1.0)

	# controls
	var bx := 1024.0
	_button(Rect2(bx, 20, 54, 34), "暂停" if not game.paused else "继续", "pause", true, "Space 暂停 / 继续")
	_button(Rect2(bx + 60, 20, 46, 34), "%d×" % int(game.speed), "speed", true, "Tab 切换 1× / 2×")
	_button(Rect2(bx + 112, 20, 54, 34), "帮助", "help", true, "H 显示操作说明")
	if game.paused:
		_text(Vector2(bx, 48), "已暂停", 12, D.C_GOLD, _font_bold)

	if show_debug:
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_text(Vector2(1188, 70), "%d FPS · %d dc" % [Engine.get_frames_per_second(), dc],
			12, FAINT, _font_mono)


func _res_chip(r: Rect2, icon: String, value: String, label: String, col: Color) -> void:
	_chip_bg(r)
	_icon(icon, Vector2(r.position.x + 24, r.position.y + r.size.y * 0.5), 22, col)
	_text(Vector2(r.position.x + 44, r.position.y + 27), value, 22, INK, _font_bold)
	_text(Vector2(r.position.x + 44, r.position.y + 39), label, 12, FAINT, _font)


# ---------------------------------------------------------------- bottom bar

func _draw_bottom_bar() -> void:
	_panel(BOTTOM_RECT, PANEL, BORDER)
	draw_line(Vector2(BOTTOM_RECT.position.x + 8, BOTTOM_RECT.position.y + 1.5),
		Vector2(BOTTOM_RECT.end.x - 8, BOTTOM_RECT.position.y + 1.5), BORDER_LIGHT, 1.0)

	# hero card
	var hr := Rect2(22, 622, 252, 80)
	_chip_bg(hr, Color(0.06, 0.08, 0.08, 0.95))
	_icon("portrait", Vector2(hr.position.x + 36, hr.position.y + 40), 54, D.C_GOLD)
	_text(Vector2(hr.position.x + 70, hr.position.y + 20), "焰语者 · 凯尔", 17, INK, _font_bold)
	if game.hero != null and game.hero.is_alive():
		var hpr := clampf(game.hero.hp / game.hero.max_hp, 0.0, 1.0)
		_health_bar(Rect2(hr.position.x + 70, hr.position.y + 28, 164, 7), hpr, D.C_GOLD)
		_text(Vector2(hr.position.x + 70, hr.position.y + 48),
			"%d / %d  ·  攻击 %d" % [int(ceil(game.hero.hp)), int(game.hero.max_hp), int(game.hero.current_damage())],
			12, MUTED, _font_mono)
		var cd: float = game.hero.skill_cd
		var ready: bool = cd <= 0.0
		_button(Rect2(hr.position.x + 70, hr.position.y + 53, 118, 23),
			"Q 熔火震击" if ready else "Q 冷却 %.0fs" % cd, "hero_skill", ready,
			"英雄范围伤害并减速周围敌人")
		if ready:
			draw_circle(Vector2(hr.position.x + 202, hr.position.y + 65), 3.0,
				D.C_TEAL * Color(1, 1, 1, 0.9))
	else:
		_text(Vector2(hr.position.x + 70, hr.position.y + 42), "英雄阵亡", 16, D.C_BLOOD, _font_bold)
		_text(Vector2(hr.position.x + 70, hr.position.y + 62),
			"%.0fs 后在兵营复活" % ceil(game.hero_respawn_t), 13, MUTED, _font)

	# recruit cards
	var start_x := 286.0
	_text(Vector2(start_x, 633), "招募军团", 13, MUTED, _font)
	var hotkeys := ["Z", "X", "C"]
	for i in D.UNIT_ORDER.size():
		var kind: String = D.UNIT_ORDER[i]
		var def: Dictionary = D.unit_def(kind)
		var r := Rect2(start_x + i * 162, 640, 154, 62)
		var cd: float = game.cooldowns.get(kind, 0.0)
		var afford: bool = game.gold >= int(def.cost) and game.essence >= int(def.essence) and game.can_recruit_pop(kind)
		_recruit_card(r, def.icon, def.name, def.role, def.cost, def.essence,
			"recruit:" + kind, afford, hotkeys[i])
		if cd > 0.0:
			var frac := clampf(cd / maxf(0.01, float(def.cooldown)), 0.0, 1.0)
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - frac), r.size.x, r.size.y * frac),
				Color(0.02, 0.02, 0.03, 0.55))
			_text_c(r.position.x + r.size.x * 0.5, r.position.y + 40, "%.1fs" % cd, 16, INK, _font_bold)
		_tooltip_for("recruit:" + kind, r, def.name,
			"%s · 人口 %d · 冷却 %.0fs\n%s\n%d 金币%s" % [def.role, def.pop, def.cooldown, def.desc,
				def.cost, (" + %d 精粹" % def.essence) if int(def.essence) > 0 else ""])

	# command buttons
	_text(Vector2(790, 633), "指挥", 13, MUTED, _font)
	_button(Rect2(790, 640, 96, 32), "全选 F", "select_all", true, "选择所有存活单位", "banner", D.C_TEAL)
	_button(Rect2(892, 640, 92, 32), "停止 S", "stop", true, "停止移动/攻击，原地警戒", "shield", D.C_DIM)
	_button(Rect2(990, 640, 114, 32), "攻击移动 A", "attack_move", true,
		"进入攻击移动：左键点地，沿途自动交战", "sword", D.C_EMBER)
	_text(Vector2(1112, 633), "1/2/3 建塔或编队", 12, FAINT, _font)
	_text(Vector2(790, 682), "左键单选 / 拖拽框选 · 右键移动 / 攻击 · Shift 追加", 12, MUTED, _font)
	_text(Vector2(790, 698), "Space 暂停 · Tab 倍速 · H 帮助 · B 开波", 12, FAINT, _font)
	if game.rally_point_set:
		_text(Vector2(1112, 682), "集结点已设置", 12, D.C_TEAL, _font)
	else:
		_text(Vector2(1112, 682), "兵营可设集结点", 12, FAINT, _font)


func _recruit_card(r: Rect2, icon: String, title: String, role: String, gold: int, essence: int,
		id: String, enabled: bool, key: String) -> void:
	var hovered := r.has_point(_mouse)
	var fill := PANEL_2 if enabled else Color(0.04, 0.05, 0.055, 0.9)
	var border := BORDER_LIGHT if enabled else Color(0.2, 0.22, 0.22, 0.5)
	if hovered and enabled:
		fill = Color(0.11, 0.15, 0.15, 0.98)
		border = D.C_TEAL
	draw_style_box(_style(fill, border, 1, 5), r)
	var ic := D.C_TEAL if enabled else FAINT
	_chip_bg(Rect2(r.position.x + 7, r.position.y + 9, 44, 44), Color(0.03, 0.045, 0.05, 0.85))
	_icon(icon, Vector2(r.position.x + 29, r.position.y + 31), 32, ic)
	_text(Vector2(r.position.x + 58, r.position.y + 22), title, 16, INK if enabled else FAINT, _font_bold)
	_text(Vector2(r.position.x + 58, r.position.y + 38), role, 12, MUTED, _font)
	var cost := "%dg" % gold
	_text(Vector2(r.position.x + 58, r.position.y + 55), cost, 15, D.C_GOLD if enabled else FAINT, _font_mono)
	if essence > 0:
		_text(Vector2(r.position.x + 94, r.position.y + 55), "+%de" % essence, 14, D.C_ESSENCE if enabled else FAINT, _font_mono)
	var kr := Rect2(r.end.x - 24, r.position.y + 6, 18, 18)
	draw_style_box(_style(Color(0.02, 0.03, 0.04, 0.85), BORDER, 1, 3), kr)
	_text_c(kr.get_center().x, kr.position.y + 13, key, 12, MUTED, _font_mono)
	_buttons.append({"rect": r, "id": id, "enabled": enabled, "data": 0})


func _draw_selected_panel() -> void:
	_panel(SELECT_RECT, PANEL, BORDER)
	var units: Array = game.selected_units
	var shown := mini(units.size(), 5)
	_text(Vector2(SELECT_RECT.position.x + 10, SELECT_RECT.position.y + 16),
		"已选 %d 个单位" % units.size(), 13, MUTED, _font)
	for i in shown:
		var u: LegionActor = units[i]
		var r := Rect2(SELECT_RECT.position.x + 8 + i * 50, SELECT_RECT.position.y + 22, 44, 34)
		_chip_bg(r, Color(0.07, 0.09, 0.095, 0.9))
		var def: Dictionary = D.unit_def(u.kind)
		_icon(def.icon, Vector2(r.position.x + 22, r.position.y + 13), 18,
			D.C_GOLD if u.is_hero else D.C_TEAL)
		_health_bar(Rect2(r.position.x + 5, r.position.y + 25, 34, 4),
			clampf(u.hp / u.max_hp, 0.0, 1.0), D.C_GOLD if u.is_hero else D.C_TEAL)
		_buttons.append({"rect": r, "id": "unit:%d" % i, "enabled": true, "data": i})
	if units.size() > shown:
		_text(Vector2(SELECT_RECT.end.x - 28, SELECT_RECT.position.y + 42), "+%d" % (units.size() - shown),
			12, MUTED, _font_mono)


# ---------------------------------------------------------------- pad / barracks

func _draw_pad_panel() -> void:
	_panel(PAD_PANEL_RECT, PANEL_2, BORDER_LIGHT)
	var p := PAD_PANEL_RECT.position
	if game.barracks_selected:
		_text(p + Vector2(20, 30), "兵营 · 余烬集结点", 20, INK, _font_bold)
		_text(p + Vector2(20, 56), "右键点击地面设置新兵集结点；新招募单位会自动前往。", 13, MUTED, _font)
		_text(p + Vector2(20, 82), "当前集结点：(%d, %d)" % [int(game.rally_point.x), int(game.rally_point.z)],
			14, D.C_TEAL, _font_mono)
		_button(Rect2(PAD_PANEL_RECT.end.x - 90, p.y + 14, 70, 26), "关闭", "close_pad", true, "")
		return
	var pad_index: int = game.selected_pad_index
	var pad: Dictionary = game.world.pads[pad_index]
	var tower: LegionTower = pad.get("tower", null)
	if tower == null:
		_text(p + Vector2(20, 30), "建造点 %02d · 选择防御塔" % (pad_index + 1), 20, INK, _font_bold)
		_text(p + Vector2(20, 52), "固定建造点；塔自动索敌，升级提升伤害与射程。", 13, MUTED, _font)
		var hover_kind := ""
		for i in D.TOWER_ORDER.size():
			var kind: String = D.TOWER_ORDER[i]
			var def: Dictionary = D.tower_def(kind)
			var r := Rect2(p.x + 20 + i * 206, p.y + 64, 194, 112)
			var afford: bool = game.gold >= int(def.cost) and game.essence >= int(def.essence)
			_tower_card(r, def, kind, afford, str(i + 1))
			if r.has_point(_mouse):
				hover_kind = kind
			_tooltip_for("build:" + kind, r, def.name,
				"%s\n%s\n伤害 %.0f · 射程 %.1f · 间隔 %.2fs\n价格 %d 金币 + %d 精粹" % [
					def.role, def.desc, def.damage, def.range, def.interval, def.cost, def.essence])
		game.set_build_preview(hover_kind if hover_kind != "" else "prism")
		_button(Rect2(PAD_PANEL_RECT.end.x - 82, p.y + 14, 62, 26), "关闭", "close_pad", true, "")
	else:
		var def: Dictionary = D.tower_def(tower.kind)
		_text(p + Vector2(20, 32), "%s · Lv.%d" % [def.name, tower.level], 20, INK, _font_bold)
		_text(p + Vector2(20, 54), def.desc, 13, MUTED, _font)
		_text(p + Vector2(20, 82),
			"伤害 %.0f · 射程 %.1f · 间隔 %.2fs%s" % [tower.effective_damage(), tower.effective_range(),
				tower.effective_interval(),
				(" · 减速 %d%%" % int(tower.effective_slow() * 100.0)) if tower.effective_slow() > 0.0 else ""],
			14, D.C_TEAL, _font_mono)
		for i in 3:
			var pr := Rect2(p.x + 20 + i * 26, p.y + 96, 18, 10)
			draw_rect(pr, def.accent if i < tower.level else Color("#26312E"))
		var cost: Array = tower.upgrade_cost()
		var up_ok: bool = tower.level < D.TOWER_MAX_LEVEL and game.gold >= int(cost[0]) and game.essence >= int(cost[1])
		var label := "已满级"
		if tower.level < D.TOWER_MAX_LEVEL:
			label = "升级  %dg  %de" % [cost[0], cost[1]]
		_button(Rect2(p.x + 20, p.y + 118, 176, 36), label, "upgrade_tower", up_ok,
			"提升伤害 50%、射程 8%")
		var sv: Array = tower.sell_value()
		_button(Rect2(p.x + 204, p.y + 118, 168, 36), "出售  +%dg +%de" % [sv[0], sv[1]], "sell_tower",
			true, "返还投入的 60%")
		_button(Rect2(PAD_PANEL_RECT.end.x - 82, p.y + 14, 62, 26), "关闭", "close_pad", true, "")
		_text(p + Vector2(392, 142), "射程环已显示 · 选择目标自动开火", 12, FAINT, _font)
		_tooltip_for("upgrade_tower", Rect2(p.x + 20, p.y + 118, 176, 36),
			"塔升级", "最多 Lv.3，每级 +50% 伤害、+8% 射程。")


func _tower_card(r: Rect2, def: Dictionary, kind: String, enabled: bool, key: String) -> void:
	var hovered := r.has_point(_mouse)
	var fill := Color(0.07, 0.095, 0.098, 0.96) if enabled else Color(0.04, 0.05, 0.055, 0.9)
	var border := BORDER_LIGHT if enabled else Color(0.2, 0.22, 0.22, 0.5)
	if hovered and enabled:
		fill = Color(0.11, 0.15, 0.15, 0.98)
		border = def.accent
	draw_style_box(_style(fill, border, 1, 5), r)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), def.accent)
	_chip_bg(Rect2(r.position.x + 8, r.position.y + 12, 52, 52), Color(0.03, 0.045, 0.05, 0.85))
	_icon(def.icon, Vector2(r.position.x + 34, r.position.y + 38), 38, Color(def.accent))
	_text(Vector2(r.position.x + 68, r.position.y + 26), def.name, 17, INK, _font_bold)
	_text(Vector2(r.position.x + 68, r.position.y + 44), def.role, 12, MUTED, _font)
	_text(Vector2(r.position.x + 68, r.position.y + 64), "%dg" % def.cost, 16, D.C_GOLD, _font_mono)
	_text(Vector2(r.position.x + 110, r.position.y + 64), "+%de" % def.essence, 15, D.C_ESSENCE, _font_mono)
	_text(Vector2(r.position.x + 10, r.position.y + 90), "伤害 %d · 射程 %.1f" % [int(def.damage), def.range],
		12, MUTED, _font)
	_text(Vector2(r.position.x + 10, r.position.y + 105), "建造快捷键 %s" % key, 12, FAINT, _font)
	_buttons.append({"rect": r, "id": "build:" + kind, "enabled": enabled, "data": 0})


# ---------------------------------------------------------------- minimap

func _draw_minimap() -> void:
	_panel(MINIMAP_RECT, Color(0.03, 0.045, 0.05, 0.95), BORDER)
	var inner := MINIMAP_RECT.grow(-5)
	draw_rect(inner, Color(0.055, 0.07, 0.06, 0.95))
	_text(Vector2(MINIMAP_RECT.position.x + 10, MINIMAP_RECT.position.y - 4), "裂隙回廊", 12, MUTED, _font)
	var map_w := inner.size.x / 100.0
	var map_h := inner.size.y / 104.0
	var cx := inner.position.x + inner.size.x * 0.5
	var cy := inner.position.y + inner.size.y * 0.52
	draw_set_transform(Vector2(cx, cy), 0.0, Vector2(map_w, map_h))
	draw_circle(Vector2.ZERO, 43, Color(0.24, 0.22, 0.17, 0.95))
	draw_circle(Vector2(-36, -28), 13, Color(0.24, 0.22, 0.17, 0.95))
	draw_circle(Vector2(36, -28), 13, Color(0.24, 0.22, 0.17, 0.95))
	draw_circle(Vector2(0, -43), 12, Color(0.24, 0.22, 0.17, 0.95))
	draw_circle(Vector2(0, 31), 15, Color(0.27, 0.24, 0.19, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var to_mini := func(p: Vector3) -> Vector2:
		return Vector2(inner.position.x + (p.x + 50.0) / 100.0 * inner.size.x,
			inner.position.y + (p.z + 52.0) / 104.0 * inner.size.y)
	for lane in game.world.lane_paths:
		var pts := PackedVector2Array()
		for p in lane:
			pts.append(to_mini.call(p))
		draw_polyline(pts, Color(0.66, 0.59, 0.46, 0.75), 2.0)
	for p in game.world.portals:
		var mp: Vector2 = to_mini.call(p.pos)
		var tri := PackedVector2Array([mp + Vector2(0, -6), mp + Vector2(5.2, 4), mp + Vector2(-5.2, 4)])
		draw_colored_polygon(tri, Color(0.66, 0.42, 0.85, 0.95))
	var core_p: Vector2 = to_mini.call(game.world.CORE_POS)
	draw_colored_polygon(PackedVector2Array([
		core_p + Vector2(0, -6), core_p + Vector2(6, 0), core_p + Vector2(0, 6), core_p + Vector2(-6, 0)
	]), D.C_TEAL)
	draw_colored_polygon(PackedVector2Array([
		core_p + Vector2(0, -3), core_p + Vector2(3, 0), core_p + Vector2(0, 3), core_p + Vector2(-3, 0)
	]), Color("#102A26"))
	for pad in game.world.pads:
		var mp2: Vector2 = to_mini.call(pad.pos)
		draw_circle(mp2, 2.2, D.C_TEAL if pad.get("tower", null) != null else Color(0.55, 0.5, 0.42, 0.8))
	for u in game.units:
		if u == null or not u.is_alive():
			continue
		var mp3: Vector2 = to_mini.call(u.global_position)
		draw_circle(mp3, 2.4 if u.is_hero else 1.6, D.C_GOLD if u.is_hero else D.C_TEAL)
	for e in game.enemies:
		if e == null or not e.is_alive():
			continue
		var mp4: Vector2 = to_mini.call(e.global_position)
		if e.kind == "colossus":
			draw_colored_polygon(PackedVector2Array([mp4 + Vector2(0, -4), mp4 + Vector2(4, 0),
				mp4 + Vector2(0, 4), mp4 + Vector2(-4, 0)]), Color(1.0, 0.36, 0.45))
		else:
			draw_circle(mp4, 1.4, Color(1.0, 0.36, 0.45))
	var ct: Vector3 = game.world.get_cam_target()
	var cp: Vector2 = to_mini.call(ct)
	draw_rect(Rect2(cp - Vector2(22, 15), Vector2(44, 30)), Color(0.85, 0.88, 0.8, 0.55), false, 1.0)
	_buttons.append({"rect": MINIMAP_RECT, "id": "minimap", "enabled": true,
		"data": ct, "map_rect": inner})


# ---------------------------------------------------------------- upgrade overlay

func _draw_upgrade_overlay() -> void:
	_buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.015, 0.02, 0.022, 0.82))
	draw_line(Vector2(0, 0), Vector2(DESIGN.x, 0), D.C_GOLD, 2.0)
	_text_c(DESIGN.x * 0.5, 74, "波 次 肃 清", 34, INK, _font_bold)
	_text_c(DESIGN.x * 0.5, 102, "选择一项军团强化 · 迎接下一波", 15, MUTED, _font)
	var sub := "第 %d 波结束 · 击杀 %d · 金币 +%d · 精粹 +%d" % [
		game.wave_index, game.kills, game.gold_earned, game.essence_earned]
	_text_c(DESIGN.x * 0.5, 126, sub, 13, FAINT, _font_mono)
	var choices: Array = game.upgrade_choices
	var card_w := 300.0
	var gap := 24.0
	var total_w := choices.size() * card_w + (choices.size() - 1) * gap
	var x0 := (DESIGN.x - total_w) * 0.5
	for i in choices.size():
		var id: String = choices[i]
		var def: Dictionary = D.upgrade_def(id)
		var hovered := Rect2(x0 + i * (card_w + gap), 150, card_w, 366).has_point(_mouse)
		var r := Rect2(x0 + i * (card_w + gap), 150 - (4 if hovered else 0), card_w, 366)
		var col := Color(def.color)
		_card_bg(r, hovered, col)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), col)
		var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + 92)
		_hex(c, 62, col, hovered)
		_icon(def.icon, c, 56, col.lightened(0.35))
		_text_c(c.x, r.position.y + 182, def.name, 26, INK, _font_bold)
		var lv := int(game.upgrade_levels.get(id, 0))
		for k in def.max:
			var pr := Rect2(c.x - def.max * 9 + k * 18, r.position.y + 194, 12, 6)
			draw_rect(pr, Color(col if k < lv else "#2A3430"))
		_text_c(c.x, r.position.y + 224, "等级 %d / %d" % [lv, def.max], 14, col, _font_mono)
		_text_c(c.x, r.position.y + 258, def.desc, 16, INK, _font)
		_text_c(c.x, r.position.y + 280, def.detail, 13, MUTED, _font)
		_text_c(c.x, r.position.y + 336, "按 %d 选择" % (i + 1), 14, FAINT, _font_mono)
		_buttons.append({"rect": r, "id": "upgrade:%d" % i, "enabled": true, "data": i})
		if hovered:
			_tooltip_title = def.name
			_tooltip_text = def.desc + "\n" + def.detail
	var rr := Rect2(DESIGN.x * 0.5 - 84, 546, 168, 36)
	var can_reroll: bool = game.rerolls_left > 0
	_button(rr, "重掷（%d）" % game.rerolls_left, "reroll", can_reroll,
		"重新随机三张强化")
	_text_c(DESIGN.x * 0.5, 606, "强化只在本局生效 · 失败或重开会重置", 12, FAINT, _font)


func _card_bg(r: Rect2, hovered: bool, accent: Color) -> void:
	draw_style_box(_style(Color(0.055, 0.072, 0.075, 0.98), accent.darkened(0.45), 1, 6), r)
	if hovered:
		draw_style_box(_style(Color(0.10, 0.125, 0.125, 0.99), accent, 2, 6), r)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		draw_line(corner + Vector2(0, 0), corner + Vector2(12 * sx, 0), Color(accent, 0.5), 1.2)
		draw_line(corner + Vector2(0, 0), corner + Vector2(0, 12 * sy), Color(accent, 0.5), 1.2)


func _hex(c: Vector2, radius: float, col: Color, hovered: bool) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := -PI * 0.5 + i * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, Color(col.r * 0.13, col.g * 0.15, col.b * 0.15, 0.98))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(col.r, col.g, col.b, 0.95 if hovered else 0.6), 2.0)
	var inner := PackedVector2Array()
	for i in 6:
		var a := -PI * 0.5 + i * TAU / 6.0
		inner.append(c + Vector2(cos(a), sin(a)) * (radius - 8))
	inner.append(inner[0])
	draw_polyline(inner, Color(col.r, col.g, col.b, 0.22), 1.0)


# ---------------------------------------------------------------- win / lose

func _draw_end_overlay() -> void:
	_buttons.clear()
	var win: bool = game.ui_state == "win"
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.012, 0.016, 0.018, 0.86))
	var accent := D.C_TEAL if win else D.C_BLOOD
	draw_line(Vector2(0, 0), Vector2(DESIGN.x, 0), accent, 3.0)
	_icon("flame" if win else "skull", Vector2(DESIGN.x * 0.5, 132), 44, accent)
	_text_c(DESIGN.x * 0.5, 196, "裂 隙 肃 清" if win else "核 心 失 守", 46, accent, _font_bold)
	_text_c(DESIGN.x * 0.5, 226, "余烬守望守住了三线" if win else "虚空蠕群淹没了余烬核心",
		16, MUTED, _font)
	var r := Rect2(DESIGN.x * 0.5 - 240, 262, 480, 196)
	_panel(r, Color(0.05, 0.07, 0.075, 0.98), Color(accent.r, accent.g, accent.b, 0.5))
	var rows := [
		["到达波次", "%d / %d" % [game.wave_index, D.WAVES.size()]],
		["击杀敌人", str(game.kills)],
		["累计金币", str(game.gold_earned)],
		["累计精粹", str(game.essence_earned)],
		["本局用时", "%02d:%02d" % [int(game.run_time / 60.0), int(game.run_time) % 60]],
	]
	for i in rows.size():
		var y := r.position.y + 34 + i * 30
		_text(Vector2(r.position.x + 32, y), rows[i][0], 14, MUTED, _font)
		_text(Vector2(r.position.x + 240, y), rows[i][1], 17, INK, _font_mono)
		draw_line(Vector2(r.position.x + 28, y + 10), Vector2(r.end.x - 28, y + 10),
			Color(0.2, 0.28, 0.26, 0.6), 1.0)
	var btn := Rect2(DESIGN.x * 0.5 - 116, 486, 232, 46)
	_button(btn, "再来一局  R", "restart", true, "新种子，重新开始", "flame", accent)
	_text_c(DESIGN.x * 0.5, 562, "第 %d 波 · %s" % [game.wave_index, game.wave_def.get("name", "")],
		13, FAINT, _font)
	_text_c(DESIGN.x * 0.5, 584, "本局强化已重置 · 每局都是新的种子", 12, FAINT, _font)


# ---------------------------------------------------------------- banner / help

func _draw_banner() -> void:
	if game.banner_t <= 0.0:
		return
	var t: float = game.banner_t
	var a := clampf(minf(t, 1.0), 0.0, 1.0)
	var y := 92.0 - (1.0 - clampf(t / 0.5, 0.0, 1.0)) * 10.0
	var txt: String = game.banner_text
	var sub: String = game.banner_sub
	var w := 520.0
	var r := Rect2(DESIGN.x * 0.5 - w * 0.5, y, w, 52 if sub == "" else 66)
	draw_style_box(_style(Color(0.03, 0.045, 0.05, 0.84 * a), Color(0.45, 0.72, 0.62, 0.5 * a), 1, 4), r)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(D.C_GOLD.r, D.C_GOLD.g, D.C_GOLD.b, 0.6 * a))
	_text_c(DESIGN.x * 0.5, y + (26 if sub == "" else 28), txt, 22, Color(1, 0.95, 0.87, a), _font_bold)
	if sub != "":
		_text_c(DESIGN.x * 0.5, y + 50, sub, 13, Color(0.75, 0.72, 0.66, a), _font)


func _help_rect() -> Rect2:
	return Rect2(330, 140, 620, 438)


func _draw_help() -> void:
	var r := _help_rect()
	_panel(r, Color(0.04, 0.055, 0.06, 0.98), BORDER_LIGHT)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), D.C_TEAL)
	_text(r.position + Vector2(24, 34), "操作说明", 22, INK, _font_bold)
	_text(r.position + Vector2(24, 56), "RTS 指挥 · 三线塔防 · 每波三选一", 13, MUTED, _font)
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
		["1/2/3", "选中建造点时建塔；否则呼叫编队"],
		["Ctrl+1/2/3", "记录当前选择为编队"],
		["R / Esc", "结算重开 / 取消选择"],
	]
	for i in rows.size():
		var col := i / 6
		var row := i % 6
		var x := r.position.x + 24 + col * 296
		var y := r.position.y + 90 + row * 42
		draw_style_box(_style(Color(0.08, 0.1, 0.1, 0.9), BORDER, 1, 3),
			Rect2(x, y - 18, 100, 28))
		_text(Vector2(x + 8, y + 2), rows[i][0], 13, D.C_TEAL, _font_mono)
		_text(Vector2(x + 110, y + 2), rows[i][1], 13, INK, _font)
	_text(r.position + Vector2(24, 396), "提示：塔建在固定建造点；框选后右键集火；每波结束三选一。",
		12, FAINT, _font)
	_text(r.position + Vector2(r.size.x - 90, 34), "H 关闭", 12, FAINT, _font_mono)


# ---------------------------------------------------------------- tooltip / cursor

func _draw_tooltip() -> void:
	if _tooltip_title == "":
		return
	var pos := _mouse + Vector2(18, 18)
	var w := 300.0
	var lines := _tooltip_text.split("\n")
	var h := 38.0 + lines.size() * 18.0
	if pos.x + w > DESIGN.x - 12:
		pos.x = _mouse.x - w - 16
	if pos.y + h > DESIGN.y - 12:
		pos.y = _mouse.y - h - 14
	var r := Rect2(pos, Vector2(w, h))
	_panel(r, Color(0.03, 0.045, 0.05, 0.98), BORDER_LIGHT)
	_text(r.position + Vector2(12, 22), _tooltip_title, 15, INK, _font_bold)
	for i in lines.size():
		_text(r.position + Vector2(12, 42 + i * 18), lines[i], 13, MUTED, _font)


func _tooltip_for(id: String, r: Rect2, title: String, text: String) -> void:
	if r.has_point(_mouse):
		_tooltip_title = title
		_tooltip_text = text


func _draw_cursor() -> void:
	if not is_modal() and not is_point_blocked(_mouse):
		draw_circle(_mouse + Vector2(1, 1), 2.4, Color(0.95, 0.88, 0.7, 0.65))
		draw_circle(_mouse, 2.4, Color(0.1, 0.12, 0.12, 0.9))
		draw_arc(_mouse, 7, 0, TAU, 16, Color(0.95, 0.88, 0.7, 0.35), 1.0)


# ---------------------------------------------------------------- primitives

func _panel(r: Rect2, fill: Color, border: Color) -> void:
	draw_style_box(_style(fill, border, 1, 5), r)


func _chip_bg(r: Rect2, fill: Color = Color(0.035, 0.05, 0.055, 0.7)) -> void:
	draw_style_box(_style(fill, Color(0.22, 0.32, 0.3, 0.55), 1, 4), r)


func _health_bar(r: Rect2, ratio: float, color: Color) -> void:
	draw_rect(r, Color(0.07, 0.08, 0.08, 0.95))
	var rr := Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y))
	draw_rect(rr, color)
	draw_rect(r, Color(0, 0, 0, 0.5), false, 1.0)


func _text(pos: Vector2, txt: String, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_c(cx: float, y: float, txt: String, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(cx - w * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _button(r: Rect2, label: String, id: String, enabled: bool, tooltip: String = "",
		icon: String = "", accent: Color = Color("#5FE0C0")) -> void:
	var hovered := r.has_point(_mouse)
	var fill := Color(0.08, 0.105, 0.105, 0.96) if enabled else Color(0.045, 0.05, 0.055, 0.85)
	var border := Color(accent.r, accent.g, accent.b, 0.45) if enabled else Color(0.2, 0.22, 0.22, 0.45)
	if hovered and enabled:
		fill = Color(0.13, 0.17, 0.16, 0.99)
		border = accent
	draw_style_box(_style(fill, border, 1, 4), r)
	var tx := r.position.x + r.size.x * 0.5
	if icon != "":
		_icon(icon, Vector2(r.position.x + 16, r.position.y + r.size.y * 0.5), 16,
			accent if enabled else FAINT)
		tx = r.position.x + r.size.x * 0.5 + 8
	_text_c(tx, r.position.y + r.size.y * 0.5 + 5, label, 15,
		INK if enabled else FAINT, _font_bold)
	_buttons.append({"rect": r, "id": id, "enabled": enabled, "data": 0})
	if hovered and tooltip != "":
		_tooltip_title = label
		_tooltip_text = tooltip


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


# ---------------------------------------------------------------- solid icons

func _icon(kind: String, c: Vector2, s: float, col: Color) -> void:
	var h := s * 0.5
	var dark := Color(0.05, 0.07, 0.07, 0.94)
	var light := col.lightened(0.32)
	match kind:
		"coin":
			draw_circle(c, h, col)
			draw_circle(c, h * 0.74, col.darkened(0.25))
			draw_circle(c, h * 0.52, col)
			draw_rect(Rect2(c + Vector2(-h * 0.10, -h * 0.34), Vector2(h * 0.20, h * 0.68)), dark)
			draw_arc(c, h * 0.86, 0, TAU, 18, light, 1.4)
		"crystal":
			var outer := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.72, -h * 0.05),
				c + Vector2(0, h), c + Vector2(-h * 0.72, -h * 0.05)])
			draw_colored_polygon(outer, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(0, h),
				c + Vector2(-h * 0.72, -h * 0.05)]), col.darkened(0.22))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.30, -h * 0.32),
				c + Vector2(0, h * 0.12)]), light)
		"pop":
			draw_circle(c + Vector2(0, -h * 0.40), h * 0.30, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-h * 0.62, h * 0.62), c + Vector2(-h * 0.40, -h * 0.10),
				c + Vector2(0, -h * 0.26), c + Vector2(h * 0.40, -h * 0.10),
				c + Vector2(h * 0.62, h * 0.62)]), col.darkened(0.15))
			draw_circle(c + Vector2(-h * 0.15, h * 0.05), h * 0.10, light)
		"skull":
			draw_circle(c + Vector2(0, -h * 0.16), h * 0.66, col)
			draw_rect(Rect2(c + Vector2(-h * 0.34, h * 0.24), Vector2(h * 0.68, h * 0.48)), col)
			draw_circle(c + Vector2(-h * 0.24, -h * 0.18), h * 0.17, dark)
			draw_circle(c + Vector2(h * 0.24, -h * 0.18), h * 0.17, dark)
			draw_line(c + Vector2(0, h * 0.02), c + Vector2(0, h * 0.38), dark, 1.6)
		"sword":
			var blade := PackedVector2Array([c + Vector2(h * 0.62, -h * 0.78),
				c + Vector2(h * 0.84, -h * 0.60), c + Vector2(-h * 0.10, h * 0.34),
				c + Vector2(-h * 0.32, h * 0.12)])
			draw_colored_polygon(blade, col)
			draw_line(c + Vector2(-h * 0.50, h * 0.10), c + Vector2(-h * 0.02, h * 0.58), col.darkened(0.2), 5.0)
			draw_line(c + Vector2(-h * 0.62, h * 0.56), c + Vector2(-h * 0.22, h * 0.94), dark, 4.0)
			draw_line(c + Vector2(h * 0.30, -h * 0.52), c + Vector2(h * 0.72, -h * 0.10), light, 1.6)
		"bow":
			draw_arc(c + Vector2(-h * 0.25, 0), h * 0.66, -1.15, 1.15, 16, col, 3.2)
			draw_line(c + Vector2(-h * 0.25, -h * 0.62), c + Vector2(-h * 0.25, h * 0.62), col.darkened(0.3), 1.6)
			draw_line(c + Vector2(-h * 0.25, 0), c + Vector2(h * 0.70, 0), light, 2.4)
			draw_colored_polygon(PackedVector2Array([c + Vector2(h * 0.70, 0), c + Vector2(h * 0.40, -h * 0.16),
				c + Vector2(h * 0.40, h * 0.16)]), col)
		"staff":
			draw_line(c + Vector2(-h * 0.50, h * 0.86), c + Vector2(h * 0.10, -h * 0.20), col.darkened(0.2), 3.6)
			draw_circle(c + Vector2(h * 0.26, -h * 0.52), h * 0.30, col)
			draw_circle(c + Vector2(h * 0.26, -h * 0.52), h * 0.14, light)
			draw_arc(c + Vector2(h * 0.26, -h * 0.52), h * 0.40, 0, TAU, 16, col.darkened(0.2), 1.4)
		"flame":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -h * 0.92), c + Vector2(h * 0.56, -h * 0.02),
				c + Vector2(h * 0.32, h * 0.66), c + Vector2(0, h * 0.90),
				c + Vector2(-h * 0.32, h * 0.66), c + Vector2(-h * 0.56, -h * 0.02)]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -h * 0.30), c + Vector2(h * 0.24, h * 0.12),
				c + Vector2(0, h * 0.64), c + Vector2(-h * 0.24, h * 0.12)]), light)
		"tower":
			draw_rect(Rect2(c + Vector2(-h * 0.50, -h * 0.10), Vector2(h, h * 0.86)), col.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-h * 0.70, -h * 0.10), c + Vector2(-h * 0.42, -h * 0.62),
				c + Vector2(h * 0.42, -h * 0.62), c + Vector2(h * 0.70, -h * 0.10)]), col)
			draw_rect(Rect2(c + Vector2(-h * 0.16, h * 0.20), Vector2(h * 0.32, h * 0.56)), dark)
			draw_circle(c + Vector2(0, -h * 0.38), h * 0.14, light)
		"prism":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.95), c + Vector2(h * 0.52, h * 0.30),
				c + Vector2(0, h * 0.78), c + Vector2(-h * 0.52, h * 0.30)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.95), c + Vector2(0, h * 0.78),
				c + Vector2(-h * 0.52, h * 0.30)]), col.darkened(0.24))
			draw_line(c + Vector2(0, -h * 0.95), c + Vector2(0, h * 0.78), light, 1.6)
		"mortar":
			draw_circle(c + Vector2(0, h * 0.32), h * 0.52, col.darkened(0.28))
			draw_circle(c + Vector2(0, h * 0.20), h * 0.40, col)
			draw_line(c + Vector2(-h * 0.36, h * 0.18), c + Vector2(h * 0.34, -h * 0.56), col, 9.0)
			draw_circle(c + Vector2(h * 0.36, -h * 0.60), h * 0.20, light)
		"frost":
			for i in 3:
				var a := i * PI / 3.0
				draw_line(c - Vector2(cos(a), sin(a)) * h * 0.82, c + Vector2(cos(a), sin(a)) * h * 0.82, col, 2.6)
			draw_circle(c, h * 0.20, light)
		"shield":
			var sp := PackedVector2Array([c + Vector2(0, -h * 0.86), c + Vector2(h * 0.70, -h * 0.52),
				c + Vector2(h * 0.52, h * 0.30), c + Vector2(0, h * 0.90),
				c + Vector2(-h * 0.52, h * 0.30), c + Vector2(-h * 0.70, -h * 0.52)])
			draw_colored_polygon(sp, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.60), c + Vector2(h * 0.28, -h * 0.30),
				c + Vector2(0, h * 0.58), c + Vector2(-h * 0.28, -h * 0.30)]), col.darkened(0.30))
			draw_line(c + Vector2(0, -h * 0.48), c + Vector2(0, h * 0.58), light, 1.6)
		"gear":
			draw_circle(c, h * 0.62, col)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * h * 0.54,
					c + Vector2(cos(a), sin(a)) * h * 0.90, col, 3.4)
			draw_circle(c, h * 0.26, dark)
		"boot":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-h * 0.36, -h * 0.72), c + Vector2(h * 0.05, -h * 0.72),
				c + Vector2(h * 0.05, h * 0.06), c + Vector2(h * 0.66, h * 0.36),
				c + Vector2(h * 0.66, h * 0.68), c + Vector2(-h * 0.36, h * 0.68)]), col)
			draw_line(c + Vector2(-h * 0.36, h * 0.30), c + Vector2(h * 0.05, h * 0.30), dark, 1.4)
		"snow":
			_icon("frost", c, s, col)
		"banner":
			draw_line(c + Vector2(-h * 0.54, -h * 0.90), c + Vector2(-h * 0.54, h * 0.90), col, 3.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-h * 0.54, -h * 0.82), c + Vector2(h * 0.66, -h * 0.52),
				c + Vector2(h * 0.24, h * 0.02), c + Vector2(-h * 0.54, h * 0.02)]), col)
			draw_line(c + Vector2(-h * 0.40, -h * 0.40), c + Vector2(h * 0.30, -h * 0.26), light, 1.4)
		"portrait":
			draw_circle(c, h * 0.92, Color(col.r * 0.20, col.g * 0.25, col.b * 0.24, 0.95))
			draw_arc(c, h * 0.92, 0, TAU, 24, col, 2.0)
			draw_circle(c + Vector2(0, -h * 0.16), h * 0.30, Color("#D8A97F"))
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-h * 0.50, h * 0.56), c + Vector2(-h * 0.32, h * 0.04),
				c + Vector2(h * 0.32, h * 0.04), c + Vector2(h * 0.50, h * 0.56)]), col.darkened(0.25))
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.36
				draw_line(c + Vector2(cos(a), sin(a)) * h * 0.34 - Vector2(0, h * 0.44),
					c + Vector2(cos(a), sin(a)) * h * 0.58 - Vector2(0, h * 0.44), col, 2.6)
			draw_circle(c + Vector2(0, h * 0.50), h * 0.08, light)
		_:
			draw_circle(c, h * 0.5, col)
