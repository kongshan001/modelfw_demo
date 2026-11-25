extends Control
## 中文 HUD：主城 HP / 金币 / 波次 / 阶段倒计时 / 塔与城墙状态 /
## 建造与升级面板 / 三选一构筑 / 失败胜利结算 / 重开。全部点击命中区在这里统一判定。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")

const TOP_LEFT := Rect2(16, 14, 306, 80)
const TOP_MID := Rect2(336, 14, 596, 80)
const TOP_RIGHT := Rect2(946, 14, 318, 80)
const BOT_LEFT := Rect2(16, 622, 338, 84)
const BOT_MID := Rect2(368, 622, 326, 84)
const BOT_RIGHT := Rect2(708, 622, 556, 84)

const BUILD_PANEL := Rect2(280, 210, 720, 312)
const TOWER_PANEL := Rect2(320, 210, 640, 332)
const UPGRADE_PANEL := Rect2(120, 130, 1040, 430)
const RESULT_PANEL := Rect2(340, 120, 600, 470)

var main
var mouse_pos := Vector2(-100, -100)
var toast_text := ""
var toast_color := Art.TEXT
var toast_t := 0.0


func setup(main_ref) -> void:
	main = main_ref
	position = Vector2.ZERO
	size = Data.ARENA_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func toast(value: String, color := Art.TEXT, duration := 2.4) -> void:
	toast_text = value
	toast_color = color
	toast_t = duration


func tick(delta: float) -> void:
	if toast_t > 0.0:
		toast_t = maxf(0.0, toast_t - delta)


func skip_rect() -> Rect2:
	return Rect2(812, 22, 106, 27)


func repair_rect() -> Rect2:
	return Rect2(30, 670, 156, 27)


func build_card_rect(index: int) -> Rect2:
	return Rect2(308 + index * 356, 292, 324, 190)


func tower_upgrade_rect() -> Rect2:
	return Rect2(360, 426, 260, 44)


func tower_sell_rect() -> Rect2:
	return Rect2(640, 426, 260, 44)


func upgrade_card_rect(index: int) -> Rect2:
	return Rect2(152 + index * 310, 232, 288, 252)


func restart_rect() -> Rect2:
	return Rect2(510, 498, 260, 50)


func hit_test(pos: Vector2) -> Dictionary:
	if main == null:
		return {"kind": "none"}
	if main.run_over:
		if restart_rect().has_point(pos):
			return {"kind": "restart"}
		return {"kind": "block"}
	if main.upgrade_open:
		for i in range(3):
			if upgrade_card_rect(i).has_point(pos):
				return {"kind": "upgrade", "index": i}
		return {"kind": "block"}
	if main.menu_mode == "build":
		for i in range(Data.TOWER_ORDER.size()):
			if build_card_rect(i).has_point(pos):
				return {"kind": "build", "type": Data.TOWER_ORDER[i]}
		return {"kind": "cancel"}
	if main.menu_mode == "tower":
		if tower_upgrade_rect().has_point(pos):
			return {"kind": "upgrade_tower"}
		if tower_sell_rect().has_point(pos):
			return {"kind": "sell_tower"}
		return {"kind": "cancel"}
	if main.waves != null and main.waves.phase == "prep" and skip_rect().has_point(pos):
		return {"kind": "skip"}
	if repair_rect().has_point(pos):
		return {"kind": "repair"}
	return {"kind": "none"}


func _draw() -> void:
	if main == null:
		return
	_draw_top()
	_draw_bottom()
	_draw_boss_bar()
	if main.upgrade_open:
		_draw_upgrade()
	elif main.run_over:
		_draw_result()
	elif main.menu_mode == "build":
		_draw_build_menu()
	elif main.menu_mode == "tower":
		_draw_tower_menu()
	_draw_toast()


func _draw_top() -> void:
	var st = main.state
	var waves = main.waves
	Art.panel(self, TOP_LEFT)
	Art.text(self, Vector2(30, 38), "苔关主城", 18, Art.TEXT, true)
	var wave_num: int = int(waves.wave_index) + 1
	Art.text_right(self, Rect2(180, 24, 128, 20), "第 %d / 8 波" % wave_num, 13, Art.TEAL, true)
	var ratio := clampf(float(st.castle_hp) / float(Data.CASTLE_MAX_HP), 0.0, 1.0)
	Art.bar(self, Rect2(30, 52, 278, 16), ratio, Art.GREEN.lerp(Art.AMBER, 1.0 - ratio))
	Art.text_center(self, Rect2(30, 52, 278, 16), "主城 HP  %d / %d" % [st.castle_hp, Data.CASTLE_MAX_HP], 12, Art.CREAM, true)
	Art.text(self, Vector2(30, 84), "击杀 %d · 当前构筑 %d 项" % [st.kills, st.chosen_upgrades.size()], 12, Art.DIM)

	# 阶段面板。
	Art.panel(self, TOP_MID)
	var phase_title := "准备阶段"
	var phase_sub := ""
	var preview := ""
	var progress := 0.0
	match String(waves.phase):
		"prep":
			var total_prep := float(Data.WAVES[waves.wave_index]["prep"])
			phase_title = "第 %d / 8 波 · 准备阶段" % wave_num
			phase_sub = "%02d 秒后开战 · 按 N 或点击提前开战" % int(ceil(waves.prep_left))
			preview = "下一波：" + waves.summary()
			progress = 1.0 - clampf(waves.prep_left / maxf(0.01, total_prep), 0.0, 1.0)
			_draw_small_button(skip_rect(), "N 提前开战", true, Art.TEAL_DARK)
		"combat":
			phase_title = "第 %d / 8 波 · 战斗中" % wave_num
			var remaining: int = int(waves.spawn_plan.size()) - int(waves.spawn_cursor) + main.enemies.size()
			phase_sub = "剩余敌人 %d / %d · %s" % [remaining, waves.wave_total(), "守住卡口"]
			preview = "本波：" + waves.summary()
			progress = 1.0 - clampf(float(remaining) / maxf(1.0, float(waves.wave_total())), 0.0, 1.0)
		"cleared":
			phase_title = "第 %d 波已守住" % maxi(1, waves.wave_cleared)
			phase_sub = "波次结算 · 准备下一波"
			preview = waves.summary()
			progress = 1.0
		"victory":
			phase_title = "八波已守住"
			phase_sub = "苔关仍在手中"
			preview = "最终结算"
			progress = 1.0
		_:
			phase_title = "准备阶段"
	Art.text_center(self, Rect2(356, 20, 500, 26), phase_title, 20, Art.CREAM, true)
	Art.text(self, Vector2(356, 62), phase_sub, 13, Art.DIM)
	Art.text(self, Vector2(356, 83), preview, 12, Color(0.74, 0.70, 0.56, 0.85))
	Art.bar(self, Rect2(356, 88, 556, 3), progress, Art.TEAL if waves.phase != "combat" else Art.AMBER)

	# 金币面板。
	Art.panel(self, TOP_RIGHT)
	Art.coin(self, Vector2(976, 48), 12.0)
	Art.text(self, Vector2(998, 34), "金币", 12, Art.DIM)
	Art.text(self, Vector2(998, 61), str(st.gold), 25, Art.GOLD, true)
	Art.text_right(self, Rect2(1090, 30, 158, 20), "最高分  %d" % st.best_score, 12, Art.DIM)
	var best_grade: String = String(st.best_grade) if String(st.best_grade) != "" else "—"
	Art.text_right(self, Rect2(1090, 52, 158, 20), "最佳评级  %s" % best_grade, 12,
		Art.GOLD if best_grade == "S" else Art.DIM)
	Art.text_right(self, Rect2(1000, 76, 248, 18), "击杀额外 +%d 金" % int(st.mods.get("gold_bonus", 0)), 11, Art.DIM)


func _draw_bottom() -> void:
	var st = main.state
	# 城墙。
	Art.panel(self, BOT_LEFT)
	var wall = main.wall
	var wall_ratio: float = float(wall.ratio())
	Art.text(self, Vector2(30, 645), "最后卡口 · 城墙", 15, Art.TEXT, true)
	Art.text_right(self, Rect2(200, 632, 140, 18), "%d / %d" % [int(ceil(wall.hp)), int(wall.max_hp)], 13,
		Art.RED if wall_ratio < 0.4 else Art.DIM)
	Art.bar(self, Rect2(30, 650, 310, 12), wall_ratio, Art.RED.lerp(Art.AMBER, wall_ratio))
	var cost: int = int(wall.repair_cost())
	var prep: bool = String(main.waves.phase) == "prep"
	var label := "城墙完好"
	if cost > 0:
		label = ("F 重建 · %d 金" % cost) if not wall.alive else ("F 修缮 · %d 金" % cost)
	var enabled: bool = cost > 0 and prep and int(st.gold) >= cost
	_draw_small_button(repair_rect(), label, enabled, Art.GOLD_DIM if cost > 0 else Art.BORDER_SOFT)
	var status := "敌人会先拆墙"
	if not prep and cost > 0:
		status = "战斗期不可修缮"
	elif wall.alive and wall_ratio < 0.4:
		status = "城墙危急"
	elif not wall.alive:
		status = "缺口敞开！"
	Art.text(self, Vector2(196, 690), status, 11, Art.DIM)

	# 领主与技能。
	Art.panel(self, BOT_MID)
	var player = main.player
	Art.text(self, Vector2(382, 645), "守关人", 15, Art.TEXT, true)
	Art.text_right(self, Rect2(540, 632, 140, 18), "%d / %d" % [int(ceil(player.hp)), int(player.max_hp)], 13, Art.DIM)
	var hp_ratio: float = float(player.hp) / maxf(1.0, float(player.max_hp))
	Art.bar(self, Rect2(382, 650, 298, 10), hp_ratio, Art.GREEN.lerp(Art.RED, 1.0 - hp_ratio))
	var skill_ratio: float = float(player.skill_ready_ratio())
	var skill_ready: bool = skill_ratio >= 0.999
	Art.bar(self, Rect2(382, 678, 206, 8), skill_ratio, Art.TEAL if skill_ready else Art.TEAL_DARK)
	var skill_text := "空格 · 回旋斩"
	if not player.alive:
		skill_text = "复活中 %.1fs" % player.respawn_left
	elif not skill_ready:
		skill_text = "回旋斩 %.1fs" % player.skill_left
	Art.text(self, Vector2(382, 700), skill_text, 12, Art.TEAL if skill_ready and player.alive else Art.DIM)
	Art.text_right(self, Rect2(596, 666, 84, 18), "就绪" if skill_ready and player.alive else "充能", 11,
		Art.TEAL if skill_ready and player.alive else Art.DIM)
	if player.flash > 0.0:
		Art.text_right(self, Rect2(596, 680, 84, 18), "受击", 11, Art.RED)

	# 塔状态与提示。
	Art.panel(self, BOT_RIGHT)
	var parts: Array[String] = []
	for i in range(main.towers_by_pad.size()):
		var pad: Dictionary = Data.BUILD_PADS[i]
		var tower = main.towers_by_pad[i]
		if tower != null and is_instance_valid(tower):
			parts.append("%s %s Lv.%d" % [String(pad["id"]), String(tower.def["name"]), tower.level])
		else:
			parts.append("%s 空位" % String(pad["id"]))
	Art.text(self, Vector2(722, 645), "塔： " + " · ".join(parts), 13, Art.TEXT, true)
	var hint := "点击基座建造/升级 · N 提前开战 · F 修墙"
	if main.waves.phase == "combat":
		hint = "WASD 走位 · 空格回旋斩 · 把敌人拉进塔的射程"
	elif main.run_over:
		hint = "R 或点击按钮立即重开"
	Art.text(self, Vector2(722, 670), hint, 12, Art.DIM)
	Art.text(self, Vector2(722, 692), "波间可建造/升级/出售；锁定目标自动普攻。", 11, Color(0.62, 0.67, 0.56, 0.85))


func _draw_boss_bar() -> void:
	var boss = main.get_active_boss()
	if boss == null:
		return
	var rect := Rect2(420, 100, 440, 38)
	Art.panel(self, rect, Color(0.11, 0.055, 0.04, 0.95), Color("6d3b2b"), false)
	Art.text(self, rect.position + Vector2(14, 18), "裂关巨兽", 14, Art.GOLD, true)
	Art.text_right(self, Rect2(rect.position.x + 220, rect.position.y + 6, 200, 18),
		"%d / %d" % [int(ceil(boss.hp)), int(boss.max_hp)], 12, Art.DIM)
	Art.bar(self, Rect2(rect.position.x + 14, rect.position.y + 23, 412, 8),
		clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0), Art.RUST)


func _draw_build_menu() -> void:
	_draw_dim()
	Art.panel(self, BUILD_PANEL, Art.PANEL_2)
	var pad: Dictionary = Data.BUILD_PADS[main.selected_pad]
	Art.text(self, Vector2(304, 246), "建造防御塔 · %s %s" % [String(pad["id"]), String(pad["name"])], 21, Art.CREAM, true)
	Art.text_right(self, Rect2(700, 228, 276, 20), "选择时准备计时暂停 · Esc 取消", 12, Art.DIM)
	for i in range(Data.TOWER_ORDER.size()):
		var type_id: String = String(Data.TOWER_ORDER[i])
		var tower_def: Dictionary = Data.TOWERS[type_id]
		var rect := build_card_rect(i)
		var hover := rect.has_point(mouse_pos)
		var affordable: bool = int(main.state.gold) >= int(tower_def["cost"])
		var fill := Color(0.075, 0.135, 0.105, 0.98) if hover else Color(0.06, 0.11, 0.088, 0.98)
		Art.panel(self, rect, fill, Art.TEAL if hover else Art.BORDER, false)
		_draw_tower_icon(rect.position + Vector2(44, 64), type_id, 1.0)
		Art.text(self, rect.position + Vector2(84, 40), String(tower_def["name"]), 22, Art.CREAM, true)
		var tag := "单体连射" if type_id == "crossbow" else "范围爆炸"
		Art.text(self, rect.position + Vector2(84, 60), tag, 12, Art.TEAL if type_id == "crossbow" else Art.GOLD)
		_draw_hotkey(Rect2(rect.end.x - 38, rect.position.y + 14, 24, 24), str(i + 1))
		var cost_text := "%d 金" % int(tower_def["cost"])
		Art.coin(self, rect.position + Vector2(92, 86), 8.0)
		Art.text(self, rect.position + Vector2(106, 91), cost_text, 16, Art.GOLD if affordable else Art.RED, true)
		var stats_text := ""
		if type_id == "crossbow":
			stats_text = "射程 %d · 攻速 %.1f/s · 单体伤害 %d" % [int(tower_def["range"]), float(tower_def["rate"]), int(tower_def["damage"])]
		else:
			stats_text = "射程 %d · 攻速 %.1f/s · 范围伤害 %d" % [int(tower_def["range"]), float(tower_def["rate"]), int(tower_def["damage"])]
		Art.text(self, rect.position + Vector2(24, 122), stats_text, 12, Art.TEXT)
		Art.wrapped(self, rect.position + Vector2(24, 146), String(tower_def["desc"]), 12, Art.DIM, 276.0, 3.0)
		if not affordable:
			Art.text(self, rect.position + Vector2(190, 91), "金币不足", 12, Art.RED, true)
	Art.text_center(self, Rect2(BUILD_PANEL.position.x, 502, BUILD_PANEL.size.x, 18),
		"点击卡片 / 按 1–2 建造 · 点击空白处或 Esc 取消", 12, Art.DIM)


func _draw_tower_menu() -> void:
	_draw_dim()
	var tower = main.towers_by_pad[main.selected_pad]
	if tower == null or not is_instance_valid(tower):
		return
	Art.panel(self, TOWER_PANEL, Art.PANEL_2)
	var pad: Dictionary = Data.BUILD_PADS[main.selected_pad]
	Art.text(self, Vector2(344, 246), "%s %s · %s Lv.%d" % [
		String(pad["id"]), String(pad["name"]), String(tower.def["name"]), tower.level], 21, Art.CREAM, true)
	Art.text_right(self, Rect2(700, 228, 240, 20), "准备阶段可升级/出售", 12, Art.DIM)
	_draw_tower_icon(Vector2(386, 320), tower.type_id, 1.35)
	var st: Dictionary = tower.stats()
	var stats_lines := [
		"射程：%d" % int(st["range"]),
		"攻速：%.2f / 秒" % float(st["rate"]),
		"伤害：%d" % int(st["damage"]),
	]
	if tower.type_id == "cannon":
		stats_lines.append("爆炸半径：%d" % int(st["splash"]))
	else:
		stats_lines.append("对铁盾卫：伤害 ×0.6")
	var y := 282.0
	for line in stats_lines:
		Art.text(self, Vector2(438, y), line, 14, Art.TEXT)
		y += 26.0
	Art.text(self, Vector2(438, 394), "塔 HP  %d / %d" % [int(ceil(tower.hp)), int(tower.max_hp)], 13, Art.DIM)
	Art.text(self, Vector2(438, 414), "总投入 %d 金 · 出售返还 50%%" % tower.invested, 12, Art.DIM)
	var prep: bool = String(main.waves.phase) == "prep"
	var up_cost: int = int(tower.upgrade_cost())
	var up_label := "已满级" if up_cost <= 0 else "升级 Lv.2 · %d 金" % up_cost
	var up_enabled: bool = prep and up_cost > 0 and int(main.state.gold) >= up_cost
	_draw_small_button(tower_upgrade_rect(), up_label, up_enabled, Art.GOLD_DIM)
	var sell_label: String = "出售 · +%d 金" % int(tower.sell_value())
	var sell_enabled: bool = prep
	_draw_small_button(tower_sell_rect(), sell_label, sell_enabled, Color("6b3f35"))
	Art.text_center(self, Rect2(TOWER_PANEL.position.x, 500, TOWER_PANEL.size.x, 18),
		"点击升级/出售 · 点击空白处或 Esc 取消", 12, Art.DIM)


func _draw_upgrade() -> void:
	_draw_dim()
	var data: Dictionary = main.upgrade_data
	Art.panel(self, UPGRADE_PANEL, Art.PANEL_2)
	Art.text_center(self, Rect2(150, 148, 980, 36), "战功构筑 · " + String(data.get("title", "三选一")), 27, Art.CREAM, true)
	Art.text_center(self, Rect2(150, 184, 980, 22), String(data.get("subtitle", "")), 13, Art.DIM)
	for i in range(3):
		var option_id := String(data["options"][i])
		var opt: Dictionary = Data.UPGRADES[option_id]
		var rect := upgrade_card_rect(i)
		var hover := rect.has_point(mouse_pos)
		var accent := _tag_color(String(opt["tag"]))
		Art.panel(self, rect, Color(0.07, 0.13, 0.10, 0.99) if not hover else Color(0.09, 0.17, 0.13, 0.99),
			accent if hover else Art.BORDER, false)
		_draw_hotkey(Rect2(rect.position.x + 16, rect.position.y + 14, 26, 24), str(i + 1))
		Art.text(self, rect.position + Vector2(54, 34), String(opt["tag"]), 13, accent, true)
		_draw_upgrade_icon(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 92), String(opt["icon"]), accent)
		Art.text(self, rect.position + Vector2(24, 148), String(opt["name"]), 20, Art.CREAM, true)
		Art.wrapped(self, rect.position + Vector2(24, 176), String(opt["desc"]), 13, Art.DIM, rect.size.x - 48, 5.0)
		Art.text_center(self, Rect2(rect.position.x, rect.end.y - 30, rect.size.x, 18), "点击卡片或按 %d" % (i + 1), 12, accent)
	var chosen_names: Array[String] = []
	for id in main.state.chosen_upgrades:
		if Data.UPGRADES.has(id):
			chosen_names.append(String(Data.UPGRADES[id]["name"]))
	var chosen_text := "尚未构筑任何战功"
	if not chosen_names.is_empty():
		chosen_text = "已构筑：" + " · ".join(chosen_names)
	Art.text_center(self, Rect2(150, 522, 980, 20), chosen_text, 12, Art.DIM)


func _draw_result() -> void:
	_draw_dim()
	var summary: Dictionary = main.state.result_summary()
	var win := bool(summary["victory"])
	Art.panel(self, RESULT_PANEL, Art.PANEL_2, Art.GOLD if win else Art.RED, false)
	Art.text_center(self, Rect2(RESULT_PANEL.position.x, 146, RESULT_PANEL.size.x, 40),
		"防线守住了！" if win else "主城失守", 31, Art.GOLD if win else Art.RED, true)
	var subtitle := "顶住全部 8 波，苔关仍在手中。" if win else "敌军攻破了最后卡口。再来一局？"
	Art.text_center(self, Rect2(RESULT_PANEL.position.x, 188, RESULT_PANEL.size.x, 22), subtitle, 13, Art.DIM)
	draw_line(Vector2(390, 220), Vector2(890, 220), Art.BORDER_SOFT, 1.0)
	_draw_result_row(250, "守住波次", "%d / 8" % int(summary["wave_cleared"]), "击杀", str(int(summary["kills"])))
	_draw_result_row(282, "主城 HP", "%d / 100" % int(summary["castle_hp"]), "剩余金币", str(int(summary["gold"])))
	Art.text_center(self, Rect2(360, 322, 360, 20), "总分", 13, Art.DIM)
	Art.text_center(self, Rect2(360, 340, 360, 48), str(int(summary["score"])), 38, Art.CREAM, true)
	var grade := String(summary["grade"])
	var grade_color := _grade_color(grade)
	draw_circle(Vector2(836, 360), 38.0, grade_color.darkened(0.55))
	draw_arc(Vector2(836, 360), 38.0, 0, TAU, 32, grade_color, 2.0)
	Art.text_center(self, Rect2(798, 336, 76, 48), grade, 30, grade_color, true)
	var best_line := "最高分 %d · 最佳 %s · 最佳波次 %d" % [
		int(summary["best_score"]), String(summary["best_grade"]), int(summary["best_wave"])]
	Art.text_center(self, Rect2(360, 412, 560, 20), best_line, 12, Art.DIM)
	if bool(summary.get("new_best", false)):
		Art.text_center(self, Rect2(360, 434, 560, 20), "新纪录！", 13, Art.GOLD, true)
	_draw_small_button(restart_rect(), "再来一局 · R", true, Art.GOLD_DIM)
	Art.text_center(self, Rect2(360, 558, 560, 18), "立即重开（<2 秒） · 最高分保留", 11, Art.DIM)


func _draw_result_row(y: float, label_a: String, value_a: String, label_b: String, value_b: String) -> void:
	Art.text(self, Vector2(392, y), label_a, 13, Art.DIM)
	Art.text_right(self, Rect2(462, y - 12, 126, 20), value_a, 16, Art.TEXT, true)
	Art.text(self, Vector2(632, y), label_b, 13, Art.DIM)
	Art.text_right(self, Rect2(702, y - 12, 126, 20), value_b, 16, Art.TEXT, true)


func _draw_toast() -> void:
	if toast_t <= 0.0 or toast_text == "":
		return
	var alpha := clampf(toast_t / 0.35, 0.0, 1.0)
	var width := clampf(Art.text_width(toast_text, 14, true) + 44.0, 220.0, 760.0)
	var rect := Rect2(640 - width * 0.5, 580, width, 34)
	draw_rect(rect, Color(0.04, 0.075, 0.06, 0.92 * alpha), true)
	draw_rect(rect, Color(toast_color.r, toast_color.g, toast_color.b, 0.65 * alpha), false, 1.0)
	Art.text_center(self, rect, toast_text, 14, Color(toast_color.r, toast_color.g, toast_color.b, alpha), true)


func _draw_dim() -> void:
	draw_rect(Rect2(Vector2.ZERO, Data.ARENA_SIZE), Color(0.015, 0.035, 0.025, 0.66), true)


func _draw_small_button(rect: Rect2, label: String, enabled: bool, accent: Color) -> void:
	var hover := enabled and rect.has_point(mouse_pos)
	var fill := accent.darkened(0.25) if enabled else Color(0.10, 0.14, 0.12, 0.9)
	if hover:
		fill = accent
	draw_rect(rect, fill, true)
	draw_rect(rect, accent.lightened(0.2) if enabled else Art.BORDER_SOFT, false, 1.0)
	Art.text_center(self, rect, label, 12, Art.INK if enabled and hover else (Art.CREAM if enabled else Art.DIM), true)


func _draw_hotkey(rect: Rect2, key: String) -> void:
	draw_rect(rect, Color(0.10, 0.16, 0.13, 0.95), true)
	draw_rect(rect, Art.GOLD_DIM, false, 1.0)
	Art.text_center(self, rect, key, 13, Art.GOLD, true)


func _draw_tower_icon(center: Vector2, type_id: String, scale: float) -> void:
	draw_circle(center + Vector2(0, 10) * scale, 22.0 * scale, Art.STONE_DARK)
	draw_circle(center + Vector2(0, 8) * scale, 18.0 * scale, Art.STONE)
	if type_id == "crossbow":
		draw_rect(Rect2(center + Vector2(-6, -18) * scale, Vector2(12, 28) * scale), Color("5b4630"), true)
		draw_line(center + Vector2(-18, -16) * scale, center + Vector2(18, -16) * scale, Color("8a6a45"), 3.0 * scale)
		draw_line(center + Vector2(-18, -16) * scale, center + Vector2(0, -24) * scale, Art.CREAM, 2.0 * scale)
		draw_line(center + Vector2(18, -16) * scale, center + Vector2(0, -24) * scale, Art.CREAM, 2.0 * scale)
		draw_line(center + Vector2(0, -24) * scale, center + Vector2(0, -36) * scale, Art.TEAL, 2.0 * scale)
	else:
		draw_circle(center + Vector2(0, 2) * scale, 12.0 * scale, Color("3f453f"))
		draw_rect(Rect2(center + Vector2(-3, -22) * scale, Vector2(28, 12) * scale), Color("5c6259"), true)
		draw_circle(center + Vector2(25, -16) * scale, 6.0 * scale, Color("343a34"))
		draw_circle(center + Vector2(26, -16) * scale, 3.0 * scale, Art.AMBER)


func _draw_upgrade_icon(center: Vector2, icon: String, color: Color) -> void:
	draw_circle(center, 30.0, color.darkened(0.62))
	draw_arc(center, 30.0, 0, TAU, 28, color, 1.5)
	match icon:
		"range":
			for r in [8.0, 17.0, 26.0]:
				draw_arc(center, r, -0.8, 0.8, 12, color, 2.0, true)
			draw_line(center + Vector2(0, 4), center + Vector2(0, -20), Art.CREAM, 3.0)
			draw_circle(center + Vector2(0, 4), 3.5, Art.CREAM)
		"blade":
			draw_line(center + Vector2(-15, 16), center + Vector2(12, -16), Art.CREAM, 4.0)
			draw_line(center + Vector2(-15, 16), center + Vector2(18, -9), color, 2.0)
			draw_line(center + Vector2(-18, 9), center + Vector2(-9, 18), Art.GOLD, 3.0)
		"coin":
			Art.coin(self, center, 17.0, color)
		"shield":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-17, -15), center + Vector2(17, -15),
				center + Vector2(13, 12), center + Vector2(0, 23), center + Vector2(-13, 12),
			]), color.darkened(0.25))
			draw_arc(center + Vector2(0, -1), 19.0, -0.5, 3.6, 16, color.lightened(0.2), 2.0)
		"cannon":
			draw_rect(Rect2(center + Vector2(-22, -6), Vector2(40, 13)), color.darkened(0.2), true)
			draw_circle(center + Vector2(18, 0), 9.0, color)
			draw_circle(center + Vector2(19, 0), 4.0, Art.CREAM)
			draw_circle(center + Vector2(-7, 11), 3.0, Art.GOLD)
		"wind":
			for i in range(3):
				draw_arc(center + Vector2(0, -10 + i * 10), 14.0 + i * 2.0, -2.5, 0.5, 14, color, 2.0, true)
		"gear":
			draw_circle(center, 12.0, color.darkened(0.3))
			draw_circle(center, 5.0, color.lightened(0.3))
			for i in range(8):
				var a := TAU * float(i) / 8.0
				draw_line(center + Vector2(cos(a), sin(a)) * 13.0,
					center + Vector2(cos(a), sin(a)) * 19.0, color, 2.0)


func _tag_color(tag: String) -> Color:
	match tag:
		"工事":
			return Art.TEAL
		"领主":
			return Art.GOLD
		"经济":
			return Art.GREEN
		"城防":
			return Art.STONE_LIGHT
		"技能":
			return Color("8fc6d4")
		"炮塔":
			return Art.AMBER
	return Art.TEXT


func _grade_color(grade: String) -> Color:
	match grade:
		"S":
			return Art.GOLD
		"A":
			return Art.TEAL
		"B":
			return Art.GREEN
		"C":
			return Art.AMBER
	return Art.RED
