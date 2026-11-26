extends Control

## Swarmforge 主场景：UI、流程、调试/截图钩子。
## 设计分辨率 1280×720，canvas_items 拉伸到 1080p；所有控件程序化生成。

const State = preload("res://scripts/swarm_state.gd")
const Cards = preload("res://scripts/swarm_cards.gd")
const Roster = preload("res://scripts/swarm_roster.gd")
const Battle = preload("res://scripts/swarm_battle.gd")
const View = preload("res://scripts/swarm_battle_view.gd")
const CardButton = preload("res://scripts/swarm_card_button.gd")
const HeroChip = preload("res://scripts/swarm_hero_chip.gd")
const ThemeKit = preload("res://scripts/swarm_theme.gd")
const Chrome = preload("res://scripts/swarm_chrome.gd")
const SwarmArt = preload("res://scripts/swarm_art.gd")

var state = State.new()
var battle_view = null
var font_regular: Font = null
var font_bold: Font = null

var board_buttons: Array = []
var shop_buttons: Array = []
var hero_chips: Array = []

var shop_group: Control = null
var battle_group: Control = null

var round_label: Label = null
var phase_label: Label = null
var ally_count_label: Label = null
var enemy_count_label: Label = null
var arena_center_label: Label = null

var board_count_label: Label = null
var board_header_label: Label = null
var sell_button: Button = null
var shop_header_label: Label = null
var shop_odds_label: Label = null
var battle_lineup_label: Label = null
var battle_hint_label: Label = null
var battle_score_ally: Label = null
var battle_score_enemy: Label = null
var battle_vs_label: Label = null
var battle_score_caption: Label = null

var gold_label: Label = null
var income_label: Label = null
var level_label: Label = null
var units_label: Label = null
var greed_label: Label = null
var greed_help: Label = null
var gold_icon: TextureRect = null
var refresh_button: Button = null
var level_button: Button = null
var greed_button: Button = null
var code_button: Button = null
var mirror_button: Button = null
var flood_button: Button = null
var start_button: Button = null

var battle_title_label: Label = null
var battle_status_label: Label = null
var battle_ally_label: Label = null
var battle_enemy_label: Label = null
var battle_log_label: Label = null
var battle_seed_label: Label = null
var pause_button: Button = null
var speed_button: Button = null

var toast_panel: Panel = null
var toast_label: Label = null
var _toast_tween: Tween = null

var perf_panel: Panel = null
var perf_label: Label = null
var perf_visible := false

var result_overlay: Control = null
var result_title: Label = null
var result_body: Label = null
var result_button: Button = null

var end_overlay: Control = null
var end_title: Label = null
var end_sub: Label = null
var end_body: Label = null
var end_button: Button = null

var code_overlay: Control = null
var code_edit: TextEdit = null
var code_status: Label = null

var modal_open := false
var _custom_battle := false
var _live_accum := 0.0
var _perf_accum := 0.0
var _demo_mode := false


func _ready() -> void:
	theme = ThemeKit.build_theme()
	font_regular = ThemeKit.make_font(false)
	font_bold = ThemeKit.make_font(true)
	_build_background()
	_build_arena()
	_build_top_bar()
	_build_bottom_panels()
	_build_overlays()
	battle_view.battle_finished.connect(_on_battle_finished)
	state.new_run()
	_refresh_all()
	_enter_shop_preview()
	set_process(true)
	if OS.get_environment("SWARM_DEMO") == "1":
		_run_demo.call_deferred()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := ColorRect.new()
	glow.color = Color(0.03, 0.12, 0.14, 0.35)
	glow.position = Vector2(0, 66)
	glow.size = Vector2(1280, 406)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var chrome = Chrome.new()
	chrome.size = Vector2(1280, 720)
	add_child(chrome)


func _build_arena() -> void:
	battle_view = View.new()
	battle_view.position = Vector2(40, 78)
	add_child(battle_view)
	ally_count_label = _mk_label(self, "蔚蓝铸群 · 0 单位", Rect2(52, 82, 430, 20), 12, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true)
	enemy_count_label = _mk_label(self, "赤锈铸群 · 0 单位", Rect2(798, 82, 430, 20), 12, ThemeKit.RED, HORIZONTAL_ALIGNMENT_RIGHT, true)
	arena_center_label = _mk_label(self, "布阵预览", Rect2(440, 82, 400, 20), 11, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _build_top_bar() -> void:
	var panel := Panel.new()
	panel.position = Vector2(12, 10)
	panel.size = Vector2(1256, 64)
	panel.add_theme_stylebox_override("panel", ThemeKit.panel_style(ThemeKit.PANEL, ThemeKit.LINE, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_mk_label(self, "群铸", Rect2(28, 16, 64, 32), 23, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_mk_label(self, "SWARMFORGE", Rect2(94, 18, 160, 16), 11, ThemeKit.MUTED)
	_mk_label(self, "MICRO-FOUNDRY · 潮铸协议", Rect2(94, 34, 210, 14), 10, ThemeKit.DIM)
	var sep := ColorRect.new()
	sep.color = ThemeKit.LINE
	sep.position = Vector2(1088, 20)
	sep.size = Vector2(1, 44)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)
	round_label = _mk_label(self, "回合 1", Rect2(1102, 14, 150, 24), 18, ThemeKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	phase_label = _mk_label(self, "铸巢阶段", Rect2(1102, 38, 150, 18), 11, ThemeKit.MUTED)
	for i in 4:
		var chip = HeroChip.new()
		chip.size = Vector2(190, 44)
		chip.position = Vector2(300 + i * 198, 18)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
		hero_chips.append(chip)


func _build_bottom_panels() -> void:
	# 左面板：编队 + 商店
	var left := Panel.new()
	left.position = Vector2(12, 470)
	left.size = Vector2(896, 242)
	left.add_theme_stylebox_override("panel", ThemeKit.panel_style(ThemeKit.PANEL, ThemeKit.LINE, 6))
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	board_header_label = _mk_label(self, "你的编队", Rect2(26, 472, 130, 22), 14, ThemeKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	board_count_label = _mk_label(self, "0/7 格 · 0 单位", Rect2(146, 472, 420, 22), 11, ThemeKit.MUTED)
	sell_button = _mk_button(self, "出售选中 · 0◆ [Del]", Rect2(698, 470, 190, 24), ThemeKit.GOLD, 11, Callable(self, "_on_sell_pressed"))
	for i in 7:
		var b = CardButton.new()
		b.position = Vector2(26 + i * 122, 494)
		b.size = Vector2(116, 92)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = true
		b.pressed.connect(_on_board_pressed.bind(i))
		b.gui_input.connect(_on_board_gui_input.bind(i))
		add_child(b)
		board_buttons.append(b)
	shop_header_label = _mk_label(self, "铸巢商店", Rect2(26, 588, 140, 20), 14, ThemeKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	shop_header_label.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_header_label.tooltip_text = "商店权重随熔炉等级变化：T1–T5。完整表在 docs/TECH.md §2.1。卡面数字均为每单位数值。"
	shop_odds_label = _mk_label(self, "", Rect2(300, 590, 574, 16), 10, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	battle_lineup_label = _mk_label(self, "", Rect2(26, 508, 860, 34), 12, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	battle_score_ally = _mk_label(self, "0", Rect2(26, 540, 370, 52), 32, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, true)
	battle_score_ally.add_theme_font_override("font", ThemeKit.make_num_font())
	battle_vs_label = _mk_label(self, "VS", Rect2(396, 552, 60, 30), 14, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	battle_score_enemy = _mk_label(self, "0", Rect2(456, 540, 408, 52), 32, ThemeKit.RED, HORIZONTAL_ALIGNMENT_LEFT, true)
	battle_score_enemy.add_theme_font_override("font", ThemeKit.make_num_font())
	battle_score_caption = _mk_label(self, "存活单位 · 实时", Rect2(26, 592, 500, 18), 11, ThemeKit.MUTED)
	battle_hint_label = _mk_label(self, "战斗期间商店与编队操作暂停；右栏可暂停 / 倍速 / 查看战报。", Rect2(26, 650, 860, 40), 11, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	for l in [battle_lineup_label, battle_score_ally, battle_score_enemy, battle_vs_label, battle_score_caption, battle_hint_label]:
		l.visible = false
	for i in 5:
		var b = CardButton.new()
		b.position = Vector2(26 + i * 172, 608)
		b.size = Vector2(164, 104)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = true
		b.pressed.connect(_on_shop_pressed.bind(i))
		add_child(b)
		shop_buttons.append(b)

	# 右面板：动作 / 战斗侧栏
	var right := Panel.new()
	right.position = Vector2(916, 470)
	right.size = Vector2(352, 242)
	right.add_theme_stylebox_override("panel", ThemeKit.panel_style(ThemeKit.PANEL, ThemeKit.LINE, 6))
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	shop_group = Control.new()
	shop_group.position = Vector2(930, 480)
	shop_group.size = Vector2(324, 222)
	shop_group.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(shop_group)
	gold_label = _mk_label(shop_group, "10", Rect2(24, 0, 100, 26), 22, ThemeKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	gold_label.add_theme_font_override("font", ThemeKit.make_num_font())
	income_label = _mk_label(shop_group, "", Rect2(120, 5, 204, 18), 10, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	level_label = _mk_label(shop_group, "", Rect2(0, 28, 170, 18), 11, ThemeKit.TEXT)
	units_label = _mk_label(shop_group, "", Rect2(150, 28, 174, 18), 11, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	greed_label = _mk_label(shop_group, "", Rect2(0, 48, 324, 18), 12, ThemeKit.GOLD)
	greed_help = _mk_label(shop_group, "每层：友军 +15% · 敌军 +30% · 立即 +2◆", Rect2(0, 66, 324, 14), 11, ThemeKit.MUTED)
	refresh_button = _mk_button(shop_group, "刷新 ◆1 [R]", Rect2(0, 84, 100, 32), ThemeKit.CYAN, 12, Callable(self, "_on_refresh_pressed"))
	level_button = _mk_button(shop_group, "升本 [L]", Rect2(104, 84, 100, 32), ThemeKit.CYAN, 12, Callable(self, "_on_level_pressed"))
	greed_button = _mk_button(shop_group, "追潮 +2◆ [G]", Rect2(208, 84, 116, 32), ThemeKit.GOLD, 12, Callable(self, "_on_greed_pressed"))
	greed_button.tooltip_text = "贪婪潮：每层友军 +15%、敌军 +30% 编队，立即 +2◆，本局持续。\n洪流 ×100 封顶后，数量溢出转为敌方每层 +6% HP/ATK。"
	code_button = _mk_button(shop_group, "阵容码 [C]", Rect2(0, 120, 158, 32), ThemeKit.CYAN, 12, Callable(self, "_on_code_pressed"))
	mirror_button = _mk_button(shop_group, "镜像试炼 [M]", Rect2(166, 120, 158, 32), ThemeKit.VIOLET, 12, Callable(self, "_on_mirror_pressed"))
	flood_button = _mk_button(shop_group, "洪流协议 ×100 [F2]", Rect2(0, 156, 324, 30), ThemeKit.CYAN, 12, Callable(self, "_on_flood_pressed"))
	start_button = _mk_button(shop_group, "开战 [Enter]", Rect2(0, 190, 324, 32), ThemeKit.CYAN, 14, Callable(self, "_on_start_pressed"), true)
	gold_icon = TextureRect.new()
	gold_icon.texture = SwarmArt.icon_texture("coin")
	gold_icon.position = Vector2(0, 3)
	gold_icon.size = Vector2(20, 20)
	gold_icon.modulate = ThemeKit.GOLD
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_group.add_child(gold_icon)
	_decorate_action_icons()

	battle_group = Control.new()
	battle_group.position = Vector2(930, 480)
	battle_group.size = Vector2(324, 222)
	battle_group.mouse_filter = Control.MOUSE_FILTER_PASS
	battle_group.visible = false
	add_child(battle_group)
	battle_title_label = _mk_label(battle_group, "潮汐交战", Rect2(0, 0, 324, 22), 14, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true)
	battle_status_label = _mk_label(battle_group, "", Rect2(0, 22, 324, 18), 11, ThemeKit.MUTED)
	battle_ally_label = _mk_label(battle_group, "", Rect2(0, 42, 324, 18), 11, ThemeKit.CYAN)
	battle_enemy_label = _mk_label(battle_group, "", Rect2(0, 60, 324, 18), 11, ThemeKit.RED)
	pause_button = _mk_button(battle_group, "暂停 [Space]", Rect2(0, 82, 100, 32), ThemeKit.CYAN, 11, Callable(self, "_on_pause_pressed"))
	speed_button = _mk_button(battle_group, "速度 1× [F]", Rect2(106, 82, 100, 32), ThemeKit.CYAN, 11, Callable(self, "_on_speed_pressed"))
	battle_log_label = _mk_label(battle_group, "", Rect2(0, 120, 324, 90), 11, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, false, true)
	battle_seed_label = _mk_label(battle_group, "", Rect2(0, 210, 324, 12), 9, ThemeKit.DIM)


func _build_overlays() -> void:
	# 临时提示
	toast_panel = Panel.new()
	toast_panel.position = Vector2(340, 84)
	toast_panel.size = Vector2(600, 42)
	toast_panel.add_theme_stylebox_override("panel", ThemeKit.panel_style(Color(0.04, 0.12, 0.14, 0.96), ThemeKit.CYAN_DIM, 5))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	add_child(toast_panel)
	toast_label = _mk_label(toast_panel, "", Rect2(12, 4, 576, 34), 12, ThemeKit.CYAN_SOFT, HORIZONTAL_ALIGNMENT_CENTER, false, true)

	# 性能叠层
	perf_panel = Panel.new()
	perf_panel.position = Vector2(994, 110)
	perf_panel.size = Vector2(254, 110)
	perf_panel.add_theme_stylebox_override("panel", ThemeKit.panel_style(Color(0.02, 0.05, 0.07, 0.9), ThemeKit.CYAN_DIM, 4))
	perf_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perf_panel.visible = false
	add_child(perf_panel)
	perf_label = _mk_label(perf_panel, "", Rect2(12, 8, 230, 94), 11, ThemeKit.CYAN_SOFT)

	# 战斗结算
	result_overlay = Control.new()
	result_overlay.size = Vector2(1280, 720)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.visible = false
	add_child(result_overlay)
	var rdim := ColorRect.new()
	rdim.color = Color(0.01, 0.02, 0.03, 0.55)
	rdim.size = Vector2(1280, 720)
	rdim.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.add_child(rdim)
	var rpanel := Panel.new()
	rpanel.position = Vector2(310, 210)
	rpanel.size = Vector2(660, 330)
	rpanel.add_theme_stylebox_override("panel", ThemeKit.panel_style(ThemeKit.PANEL2, ThemeKit.CYAN_DIM, 8))
	result_overlay.add_child(rpanel)
	result_title = _mk_label(result_overlay, "", Rect2(330, 224, 620, 52), 34, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER, true)
	result_body = _mk_label(result_overlay, "", Rect2(350, 286, 580, 166), 13, ThemeKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	result_body.add_theme_constant_override("line_spacing", 6)
	result_button = _mk_button(result_overlay, "继续 [Enter]", Rect2(510, 466, 260, 44), ThemeKit.CYAN, 14, Callable(self, "_on_result_continue"), true)

	# 终局：原创 key art 全屏 + 顶部标题 + 底部战报
	end_overlay = Control.new()
	end_overlay.size = Vector2(1280, 720)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.visible = false
	add_child(end_overlay)
	var keyart := TextureRect.new()
	keyart.texture = SwarmArt.KEYART
	keyart.position = Vector2.ZERO
	keyart.size = Vector2(1280, 720)
	keyart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	keyart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	keyart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_overlay.add_child(keyart)
	var edim := ColorRect.new()
	edim.color = Color(0.01, 0.02, 0.03, 0.28)
	edim.size = Vector2(1280, 720)
	edim.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.add_child(edim)
	_mk_label(end_overlay, "RUN COMPLETE · 潮汐记录", Rect2(0, 36, 1280, 18), 11, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	end_title = _mk_label(end_overlay, "", Rect2(0, 64, 1280, 56), 36, ThemeKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	end_sub = _mk_label(end_overlay, "", Rect2(0, 124, 1280, 20), 13, ThemeKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var estats := Panel.new()
	estats.position = Vector2(170, 534)
	estats.size = Vector2(940, 126)
	estats.add_theme_stylebox_override("panel", ThemeKit.panel_style(Color(0.02, 0.05, 0.07, 0.82), ThemeKit.LINE_HI, 6))
	estats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_overlay.add_child(estats)
	end_body = _mk_label(end_overlay, "", Rect2(190, 544, 900, 104), 13, ThemeKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, false, true)
	end_body.add_theme_constant_override("line_spacing", 5)
	end_button = _mk_button(end_overlay, "再来一局 [R]", Rect2(520, 668, 240, 44), ThemeKit.CYAN, 14, Callable(self, "_on_restart_pressed"), true)

	# 阵容码
	code_overlay = Control.new()
	code_overlay.size = Vector2(1280, 720)
	code_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	code_overlay.visible = false
	add_child(code_overlay)
	var cdim := ColorRect.new()
	cdim.color = Color(0.01, 0.02, 0.03, 0.6)
	cdim.size = Vector2(1280, 720)
	cdim.mouse_filter = Control.MOUSE_FILTER_STOP
	code_overlay.add_child(cdim)
	var cpanel := Panel.new()
	cpanel.position = Vector2(230, 150)
	cpanel.size = Vector2(820, 420)
	cpanel.add_theme_stylebox_override("panel", ThemeKit.panel_style(ThemeKit.PANEL2, ThemeKit.CYAN_DIM, 8))
	code_overlay.add_child(cpanel)
	_mk_label(code_overlay, "阵容码 / ROSTER TRANSMIT", Rect2(258, 170, 764, 30), 20, ThemeKit.CYAN, HORIZONTAL_ALIGNMENT_LEFT, true)
	_mk_label(code_overlay, "SWF1: base64(JSON) · 只含编队 / 等级 / 贪婪潮 / 洪流开关 · 不占外部服务", Rect2(258, 204, 764, 18), 9.5, ThemeKit.MUTED)
	code_edit = TextEdit.new()
	code_edit.position = Vector2(258, 228)
	code_edit.size = Vector2(764, 170)
	code_edit.add_theme_font_override("font", font_regular)
	code_edit.add_theme_font_size_override("font_size", 11)
	code_edit.add_theme_color_override("font_color", ThemeKit.TEXT)
	var tstyle := ThemeKit.make_style(Color(0.02, 0.04, 0.06, 1.0), ThemeKit.LINE_HI, 4)
	tstyle.content_margin_left = 10
	tstyle.content_margin_right = 10
	tstyle.content_margin_top = 8
	tstyle.content_margin_bottom = 8
	code_edit.add_theme_stylebox_override("normal", tstyle)
	code_edit.add_theme_stylebox_override("focus", tstyle)
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code_overlay.add_child(code_edit)
	_mk_button(code_overlay, "保存并导出", Rect2(258, 416, 170, 38), ThemeKit.CYAN, 11, Callable(self, "_on_code_export"))
	_mk_button(code_overlay, "复制", Rect2(436, 416, 130, 38), ThemeKit.CYAN, 11, Callable(self, "_on_code_copy"))
	_mk_button(code_overlay, "导入", Rect2(574, 416, 130, 38), ThemeKit.GOLD, 11, Callable(self, "_on_code_import"))
	_mk_button(code_overlay, "关闭 [Esc]", Rect2(792, 416, 230, 38), ThemeKit.MUTED, 11, Callable(self, "_on_code_close"))
	code_status = _mk_label(code_overlay, "", Rect2(258, 464, 764, 18), 10, ThemeKit.MUTED)
	_mk_label(code_overlay, "镜像试炼会用最近一次保存的编队作为对手；没有保存码时使用内置 AI 编队。", Rect2(258, 492, 764, 40), 9, ThemeKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, false, true)


func _decorate_action_icons() -> void:
	var pairs := [
		[refresh_button, "refresh", ThemeKit.CYAN],
		[level_button, "level", ThemeKit.CYAN],
		[greed_button, "greed", ThemeKit.GOLD],
		[code_button, "code", ThemeKit.CYAN],
		[mirror_button, "support", ThemeKit.VIOLET],
		[flood_button, "flood", ThemeKit.CYAN],
		[start_button, "melee", ThemeKit.CYAN_SOFT],
		[pause_button, "refresh", ThemeKit.CYAN],
		[speed_button, "aspd", ThemeKit.CYAN],
	]
	for pair in pairs:
		var b: Button = pair[0]
		if b == null:
			continue
		b.icon = SwarmArt.icon_texture(String(pair[1]))
		b.add_theme_constant_override("icon_max_width", 16)
		b.expand_icon = false
		b.add_theme_color_override("icon_normal_color", pair[2])
		b.add_theme_color_override("icon_hover_color", ThemeKit.CYAN_SOFT)
		b.add_theme_color_override("icon_disabled_color", ThemeKit.DIM)


func _mk_label(parent: Node, text: String, rect: Rect2, fs: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = false, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if not wrap else VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_override("font", font_bold if bold else font_regular)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("line_spacing", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _mk_button(parent: Node, text: String, rect: Rect2, accent: Color, fs: int, cb: Callable, big: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	ThemeKit.style_button(b, accent, fs, big)
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_shop_pressed(index: int) -> void:
	if state.phase != "shop":
		return
	var res: Dictionary = state.buy_slot(index)
	_toast(String(res.get("msg", "")))
	_refresh_all()
	_refresh_preview()
	_update_live_labels()


func _on_board_pressed(index: int) -> void:
	if state.phase != "shop":
		return
	if index >= state.board.size():
		return
	state.selected = -1 if state.selected == index else index
	_refresh_all()


func _on_board_gui_input(event: InputEvent, index: int) -> void:
	if state.phase != "shop":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and index < state.board.size():
			var res: Dictionary = state.sell_card(index)
			_toast(String(res.get("msg", "")))
			_refresh_all()
			_refresh_preview()


func _on_sell_pressed() -> void:
	if state.selected < 0 or state.phase != "shop":
		return
	var res: Dictionary = state.sell_card(state.selected)
	_toast(String(res.get("msg", "")))
	_refresh_all()
	_refresh_preview()


func _on_refresh_pressed() -> void:
	if state.phase != "shop":
		return
	var res: Dictionary = state.refresh_shop()
	_toast(String(res.get("msg", "")))
	_refresh_all()


func _on_level_pressed() -> void:
	if state.phase != "shop":
		return
	var res: Dictionary = state.level_up()
	_toast(String(res.get("msg", "")))
	_refresh_all()
	_refresh_preview()


func _on_greed_pressed() -> void:
	if state.phase != "shop":
		return
	var res: Dictionary = state.add_greed()
	if not bool(res.get("ok", false)):
		_toast(String(res.get("msg", "")))
		return
	_toast("贪婪潮 Lv.%d！本局持续：友军 +%d%% / 敌军 +%d%% 编队，立即 +2◆。" % [
		state.greed, int(state.get_ally_greed_mult() * 100 - 100), int(state.get_enemy_greed_mult() * 100 - 100)])
	_refresh_all()
	_refresh_preview()


func _on_flood_pressed() -> void:
	if state.phase != "shop":
		return
	var res: Dictionary = state.toggle_flood()
	if state.flood:
		_toast("洪流协议 ×100 开启：双方编队放大 100 倍，每边上限 %s 单位。" % Cards.format_units(Cards.UNIT_CAP_PER_SIDE))
	else:
		_toast("洪流协议关闭，回到常规编队。")
	_refresh_all()
	_refresh_preview()


func _on_code_pressed() -> void:
	if state.phase != "shop":
		return
	code_edit.text = state.saved_code if not state.saved_code.is_empty() else state.export_code()
	code_status.text = "当前编队 %d 张 · Lv.%d · 贪婪潮 %d" % [state.board.size(), state.level, state.greed]
	modal_open = true
	code_overlay.visible = true
	code_edit.grab_focus()


func _on_code_export() -> void:
	var code: String = state.save_current_code()
	code_edit.text = code
	code_status.text = "已保存并导出 · %d 字符 · 可用于镜像试炼" % code.length()
	_refresh_all()


func _on_code_copy() -> void:
	var code := code_edit.text.strip_edges()
	if code.is_empty():
		code_status.text = "没有可复制的阵容码"
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(code)
		code_status.text = "已复制到剪贴板 · %d 字符" % code.length()
	else:
		code_status.text = "headless 模式不访问剪贴板"


func _on_code_import() -> void:
	var res: Dictionary = state.import_code(code_edit.text)
	if bool(res.get("ok", false)):
		state.save_current_code()
		code_edit.text = state.saved_code
		code_status.text = "导入成功 · %d 张卡 · Lv.%d · 贪婪潮 %d" % [state.board.size(), state.level, state.greed]
		_refresh_all()
		_refresh_preview()
	else:
		code_status.text = String(res.get("msg", "导入失败"))


func _on_code_close() -> void:
	_close_code()


func _close_code() -> void:
	modal_open = false
	code_overlay.visible = false
	if code_edit != null:
		code_edit.release_focus()


func _on_mirror_pressed() -> void:
	if state.phase != "shop":
		return
	if state.board.is_empty():
		_toast("至少上场 1 个单位才能镜像试炼")
		return
	var res: Dictionary = state.start_battle(true)
	if not bool(res.get("ok", false)):
		_toast(String(res.get("msg", "无法开始试炼")))
		return
	_custom_battle = false
	result_overlay.visible = false
	end_overlay.visible = false
	modal_open = false
	code_overlay.visible = false
	battle_view.set_battle(state.battle, false)
	_refresh_all()
	_update_live_labels()
	_toast("镜像试炼 · 对手从保存编队生成；本场不改变战役血量与回合。")


func _on_start_pressed() -> void:
	if state.phase != "shop":
		return
	if state.board.is_empty():
		_toast("至少上场 1 个单位")
		return
	var res: Dictionary = state.start_battle(false)
	if not bool(res.get("ok", false)):
		_toast(String(res.get("msg", "无法开始战斗")))
		return
	_custom_battle = false
	result_overlay.visible = false
	end_overlay.visible = false
	battle_view.set_battle(state.battle, false)
	_refresh_all()
	_update_live_labels()
	_toast("第 %d 回合开战 · %s vs %s" % [
		state.round_no, Cards.format_units(state.battle.side_count[0]),
		Cards.format_units(state.battle.side_count[1])])


func _on_battle_finished(result: Dictionary) -> void:
	if state.phase != "battle":
		return
	var res: Dictionary = state.finish_battle(result)
	_refresh_all()
	_update_live_labels()
	if state.phase == "gameover":
		_show_end_overlay()
	else:
		_show_result_overlay()


func _show_result_overlay() -> void:
	var r: Dictionary = state.last_result
	var winner := int(r.get("winner", 2))
	var title := "平局"
	var col := ThemeKit.GOLD
	if bool(r.get("training", false)):
		title = "试炼胜利" if winner == 0 else ("试炼失败" if winner == 1 else "试炼平局")
		col = ThemeKit.VIOLET if winner != 1 else ThemeKit.RED
	else:
		title = "潮汐胜利" if winner == 0 else ("潮铸失守" if winner == 1 else "潮汐平局")
		col = ThemeKit.CYAN if winner == 0 else (ThemeKit.RED if winner == 1 else ThemeKit.GOLD)
	result_title.text = title
	result_title.add_theme_color_override("font_color", col)
	var lines: Array[String] = []
	lines.append("对局 %.1fs · 种子 %d · %s" % [
		float(r.get("duration", 0.0)), int(r.get("seed", 0)),
		"超时判定" if bool(r.get("timeout", false)) else "歼灭判定"])
	lines.append("剩余单位：%s / %s" % [
		Cards.format_units(int(r.get("units", [0, 0])[0])),
		Cards.format_units(int(r.get("units", [0, 0])[1]))])
	lines.append("存活编队：%d / %d · 本场击破 %d" % [
		int(r.get("surviving_cards", [0, 0])[0]), int(r.get("surviving_cards", [0, 0])[1]),
		int(r.get("kills", 0))])
	if state.pending_damage > 0:
		lines.append("英雄损伤：%s -%d HP" % [state.pending_target, state.pending_damage])
	if bool(r.get("training", false)):
		lines.append("镜像试炼不推进回合，也不改变英雄血量。")
	lines.append("")
	var log_lines: Array = r.get("log", [])
	for i in range(maxi(0, log_lines.size() - 3), log_lines.size()):
		lines.append("· " + String(log_lines[i]))
	result_body.text = "\n".join(lines)
	result_button.text = "返回铸巢 [Enter]" if bool(r.get("training", false)) else "继续 [Enter]"
	result_overlay.visible = true


func _on_result_continue() -> void:
	if modal_open:
		return
	result_overlay.visible = false
	var res: Dictionary = state.continue_after_result()
	if not bool(res.get("ok", false)):
		_toast(String(res.get("msg", "")))
		return
	if state.phase == "shop":
		_enter_shop_preview()
		_toast("第 %d 回合 · 收入 +%d◆" % [state.round_no, int(res.get("income", 0))])


func _show_end_overlay() -> void:
	var win: bool = state.final_outcome == "victory"
	end_title.text = "群铸完成 · 潮汐归一" if win else "铸巢熄灭 · 潮声止息"
	end_title.add_theme_color_override("font_color", ThemeKit.GOLD if win else ThemeKit.RED)
	end_sub.text = "ORIGINAL SWARM AUTOBATTLER · RUN SEED %d" % state.run_seed
	var lines: Array[String] = []
	lines.append("回合 %d · 交手 %d 场 · 胜利 %d 场 · 峰值 %s 单位" % [
		state.round_no, state.stats_battles, state.stats_wins, Cards.format_units(state.stats_peak_units)])
	lines.append("贪婪潮 Lv.%d · 洪流协议 %s" % [state.greed, "开" if state.flood else "关"])
	if win:
		lines.append("三座敌对铸巢全部熄灭，你的编队已经涨成一场会移动的潮汐。")
	else:
		lines.append("蔚蓝铸巢的最后一炉冷掉了，潮汐吞掉了你的编队。")
	var short_code := Roster.short(state.saved_code if not state.saved_code.is_empty() else state.export_code(), 52)
	lines.append("最后阵容码：%s" % short_code)
	end_body.text = "\n".join(lines)
	end_overlay.visible = true
	result_overlay.visible = false


func _on_restart_pressed() -> void:
	end_overlay.visible = false
	result_overlay.visible = false
	_close_code()
	state.new_run()
	_custom_battle = false
	_refresh_all()
	_enter_shop_preview()
	_toast("新的铸巢已点火。R 刷新商店，Enter 开战。")


func _enter_shop_preview() -> void:
	if state.phase != "shop":
		return
	var preview = state.make_preview_battle()
	battle_view.set_battle(preview, true)
	_refresh_all()
	_update_live_labels()


func _refresh_preview() -> void:
	if state.phase == "shop":
		var preview = state.make_preview_battle()
		battle_view.set_battle(preview, true)
		_update_live_labels()


func _refresh_all() -> void:
	round_label.text = "回合 %d" % state.round_no
	var phase_map := {"shop": "铸巢阶段", "battle": "潮汐交战", "result": "战斗结算", "gameover": "终局"}
	phase_label.text = String(phase_map.get(state.phase, state.phase))
	_refresh_heroes()
	_refresh_board()
	_refresh_shop()
	_refresh_actions()
	_refresh_battle_lineup()
	_refresh_phase_visibility()
	_update_live_labels()


func _refresh_heroes() -> void:
	var active := -1
	if state.phase == "battle" or state.phase == "result":
		active = state.encounter_index
	elif state.phase == "shop":
		active = state.next_opponent_index()
	for i in hero_chips.size():
		if i < state.heroes.size():
			hero_chips[i].setup(state.heroes[i], i == active, font_regular)


func _refresh_board() -> void:
	var units: Array = state.ally_unit_counts()
	for i in board_buttons.size():
		var b = board_buttons[i]
		if i < state.board.size():
			b.configure_board(state.board[i], int(units[i]) if i < units.size() else 0, state.selected == i, i)
		else:
			b.configure_empty(i, false)
		if state.phase != "shop":
			b.disabled = true
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.modulate = Color(1, 1, 1, 1) if state.phase == "shop" else Color(0.52, 0.58, 0.64, 1)
	board_header_label.text = "战斗进行中" if state.phase in ["battle", "result"] else "你的编队"
	var total := 0
	for n in units:
		total += int(n)
	board_count_label.text = "%d/7 格 · %s 单位 · %s" % [
		state.board.size(), Cards.format_units(total),
		(("洪流 ×100 · 预览" if state.flood else "常规编队 · 预览") if state.phase == "shop" else "初始编队")]
	if state.selected >= 0 and state.selected < state.board.size() and state.phase == "shop":
		sell_button.disabled = false
		sell_button.text = "出售选中 +%d◆ [Del]" % state.selected_sell_value()
	else:
		sell_button.disabled = true
		sell_button.text = "出售选中 · 0◆ [Del]"
	sell_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not sell_button.disabled else Control.CURSOR_ARROW


func _refresh_shop() -> void:
	for i in shop_buttons.size():
		var b = shop_buttons[i]
		if i >= state.shop.size() or String(state.shop[i]).is_empty():
			b.configure_empty(i, true)
			continue
		var id := String(state.shop[i])
		var cost := int(Cards.get_card(id).get("cost", 0))
		var units := _preview_shop_units(id)
		b.configure_shop(id, units, state.gold >= cost, i)
		if state.phase != "shop":
			b.disabled = true
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.modulate = Color(1, 1, 1, 1) if state.phase == "shop" else Color(0.52, 0.58, 0.64, 1)
	var odds := Cards.shop_odds(state.level)
	var parts: Array[String] = []
	for t in 5:
		parts.append("T%d %d%%" % [t + 1, int(odds[t])])
	shop_odds_label.text = ""
	shop_header_label.tooltip_text = "Lv.%d 商店权重：%s\n卡面数字均为每单位数值；更多数值见悬停 tooltip。" % [state.level, " · ".join(parts)]


func _preview_shop_units(id: String) -> int:
	var tmp: Array = state.board.duplicate(true)
	var copies: Array[int] = []
	for i in tmp.size():
		if String(tmp[i]["id"]) == id and int(tmp[i]["star"]) == 1:
			copies.append(i)
	var target_idx := 0
	if copies.size() >= 2:
		var hi := maxi(copies[0], copies[1])
		tmp.remove_at(hi)
		var lo := mini(copies[0], copies[1])
		tmp.remove_at(lo)
		tmp.append({"id": id, "star": 2})
		target_idx = tmp.size() - 1
	else:
		tmp.append({"id": id, "star": 1})
		target_idx = tmp.size() - 1
	var counts := Cards.allocate_units(tmp, state.get_ally_greed_mult(), state.flood, Cards.UNIT_CAP_PER_SIDE, 1.0)
	if target_idx < counts.size():
		return int(counts[target_idx])
	return 0


func _refresh_actions() -> void:
	gold_label.text = "%d" % state.gold
	var inc: Dictionary = state.income_preview()
	income_label.text = "下回合基础 +%d◆ · 利息 +%d◆" % [int(inc["base"]), int(inc["interest"])]
	level_label.text = "熔炉 Lv.%d · 上场 %d/%d" % [state.level, state.board.size(), Cards.BOARD_MAX]
	var total: int = state.ally_unit_total()
	units_label.text = ("洪流 %s/边" % Cards.format_units(Cards.UNIT_CAP_PER_SIDE)) if state.flood else ("编队 %s 单位" % Cards.format_units(total))
	var pips := ""
	for i in state.greed:
		pips += "◆"
	for i in Cards.MAX_GREED - state.greed:
		pips += "◇"
	greed_label.text = "贪婪潮 Lv.%d  %s" % [state.greed, pips]
	if state.flood and state.greed > 0:
		greed_help.text = "封顶后敌方额外 +6%%/层 HP/ATK（数量溢出转攻防）"
	else:
		greed_help.text = "每层：友军 +%d%% · 敌军 +%d%% · 立即 +2◆" % [
			int(state.get_ally_greed_mult() * 100 - 100), int(state.get_enemy_greed_mult() * 100 - 100)]
	var lc := Cards.level_cost(state.level)
	level_button.text = ("熔炉满级 [L]" if lc < 0 else "升本 ◆%d [L]" % lc)
	level_button.disabled = state.phase != "shop" or lc < 0 or state.gold < lc
	refresh_button.disabled = state.phase != "shop" or state.gold < 1
	greed_button.disabled = state.phase != "shop" or state.greed >= Cards.MAX_GREED
	code_button.disabled = state.phase != "shop"
	mirror_button.disabled = state.phase != "shop" or state.board.is_empty()
	flood_button.text = "洪流协议 ×100：%s [F2]" % ("开" if state.flood else "关")
	flood_button.add_theme_color_override("font_color", ThemeKit.GOLD if state.flood else ThemeKit.CYAN)
	start_button.text = "开战 [Enter] · 我方 %s 单位" % Cards.format_units(total)
	start_button.disabled = state.phase != "shop" or state.board.is_empty()
	if battle_view.battle != null and (state.phase == "battle" or state.phase == "result"):
		var b = battle_view.battle
		battle_title_label.text = "镜像试炼" if state.training else "潮汐交战"
		battle_ally_label.text = "%s · %s / %s" % [b.side_labels[0], Cards.format_units(int(b.side_count[0])), Cards.format_units(int(b.side_start_count[0]))]
		battle_enemy_label.text = "%s · %s / %s" % [b.side_labels[1], Cards.format_units(int(b.side_count[1])), Cards.format_units(int(b.side_start_count[1]))]
		battle_seed_label.text = "种子 %d · 5–10Hz 自适应 · MultiMesh 批渲染" % int(b.seed_value)
		pause_button.text = "继续 [Space]" if battle_view.paused else "暂停 [Space]"
		speed_button.text = "速度 %d× [F]" % int(battle_view.speed)


func _refresh_battle_lineup() -> void:
	var units: Array = state.ally_unit_counts()
	var bits: Array[String] = []
	for i in state.board.size():
		var entry: Dictionary = state.board[i]
		var card := Cards.get_card(String(entry.get("id", "")))
		if card.is_empty():
			continue
		var star := int(entry.get("star", 1))
		bits.append("%s%s ×%s" % [
			String(card["name"]), "★★" if star >= 2 else "",
			Cards.format_units(int(units[i]) if i < units.size() else 0)])
	if bits.is_empty():
		battle_lineup_label.text = "编队为空"
	else:
		battle_lineup_label.text = "编队 · " + " · ".join(bits)
	battle_hint_label.text = "战斗期间商店与编队操作暂停；右栏可暂停 / 倍速 / 查看战报。"


func _refresh_phase_visibility() -> void:
	shop_group.visible = state.phase == "shop"
	battle_group.visible = state.phase == "battle" or state.phase == "result"
	var battle_ui: bool = state.phase == "battle" or state.phase == "result" or state.phase == "gameover"
	for b in board_buttons:
		b.visible = not battle_ui
	for b in shop_buttons:
		b.visible = not battle_ui
	shop_header_label.visible = not battle_ui
	shop_odds_label.visible = false
	sell_button.visible = state.phase == "shop"
	battle_lineup_label.visible = battle_ui
	battle_hint_label.visible = battle_ui
	battle_score_ally.visible = battle_ui
	battle_score_enemy.visible = battle_ui
	battle_vs_label.visible = battle_ui
	battle_score_caption.visible = battle_ui
	perf_panel.visible = perf_visible


func _update_live_labels() -> void:
	var b = battle_view.battle
	if b == null:
		return
	var preview := bool(battle_view.is_preview)
	var ally_text := "%s · %s 单位" % [b.side_labels[0], Cards.format_units(int(b.side_count[0]))]
	var enemy_text := "%s · %s 单位" % [b.side_labels[1], Cards.format_units(int(b.side_count[1]))]
	if preview:
		ally_text += " · 布阵"
		enemy_text += " · 对手预览"
	ally_count_label.text = ally_text
	enemy_count_label.text = enemy_text
	if preview:
		var bits: Array[String] = ["编队预览 · 开战后自动索敌"]
		if state.flood:
			bits.append("洪流 ×100")
		if state.greed > 0:
			bits.append("贪婪潮 Lv.%d" % state.greed)
		arena_center_label.text = " · ".join(bits)
	elif state.phase == "battle":
		if battle_view.paused:
			arena_center_label.text = "已暂停 · %.1fs / 30s" % b.time
		else:
			arena_center_label.text = "交战中 · %.1fs / 30s · 速度 %d×" % [b.time, int(battle_view.speed)]
	elif state.phase == "result" or state.phase == "gameover":
		arena_center_label.text = "战斗结束 · 潮汐结算"
	if battle_group.visible:
		battle_status_label.text = "计时 %.1fs / 30s · 击破 %d · %s" % [b.time, b.kill_count(), "已暂停" if battle_view.paused else "自动索敌"]
	if battle_score_ally.visible:
		battle_score_ally.text = Cards.format_units(int(b.side_count[0]))
		battle_score_enemy.text = Cards.format_units(int(b.side_count[1]))
		battle_score_caption.text = "存活单位 · 实时 · 击破 %d · %.1fs / 30s" % [b.kill_count(), b.time]
		var logs: Array = b.battle_log
		var show: Array[String] = []
		for i in range(maxi(0, logs.size() - 5), logs.size()):
			show.append(String(logs[i]))
		battle_log_label.text = "\n".join(show)


func _process(delta: float) -> void:
	_live_accum += delta
	if _live_accum >= 0.1:
		_live_accum = 0.0
		_update_live_labels()
	if perf_visible:
		_perf_accum += delta
		if _perf_accum >= 0.25:
			_perf_accum = 0.0
			_update_perf()


func _update_perf() -> void:
	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var units: int = battle_view.total_units()
	var fx: int = battle_view._fx_active
	var vsize := get_viewport().get_visible_rect().size
	perf_label.text = "FPS %d · DRAW %d\n单位 %s · FX %d\nSIM %.2fms/tick · REN %.2fms\nOBJ %d · 视图 %dx%d\n%s" % [
		fps, draws, Cards.format_units(units), fx,
		battle_view.avg_sim_ms(), battle_view.avg_render_ms(),
		objs, int(vsize.x), int(vsize.y),
		"洪流 ×100" if state.flood else "常规编队"]


func _hide_toast() -> void:
	toast_panel.visible = false


func _toast(text: String) -> void:
	if text.is_empty():
		return
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_hide_toast)


func _on_pause_pressed() -> void:
	if battle_view.battle == null:
		return
	battle_view.set_paused(not battle_view.paused)
	_refresh_actions()
	_update_live_labels()


func _on_speed_pressed() -> void:
	if battle_view.battle == null:
		return
	var s: float = battle_view.speed
	battle_view.set_speed(2.0 if s == 1.0 else (4.0 if s == 2.0 else 1.0))
	_refresh_actions()
	_update_live_labels()


func _toggle_perf() -> void:
	perf_visible = not perf_visible
	perf_panel.visible = perf_visible
	if perf_visible:
		_update_perf()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if modal_open:
		if key.keycode == KEY_ESCAPE:
			_close_code()
			get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if state.phase == "shop":
				_on_start_pressed()
			elif state.phase == "result" and result_overlay.visible:
				_on_result_continue()
			elif state.phase == "gameover" and end_overlay.visible:
				_on_restart_pressed()
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			if state.phase == "battle":
				_on_pause_pressed()
				get_viewport().set_input_as_handled()
		KEY_F:
			if state.phase == "battle":
				_on_speed_pressed()
				get_viewport().set_input_as_handled()
		KEY_F2:
			if state.phase == "shop":
				_on_flood_pressed()
				get_viewport().set_input_as_handled()
		KEY_F3:
			_toggle_perf()
			get_viewport().set_input_as_handled()
		KEY_R:
			if state.phase == "gameover":
				_on_restart_pressed()
			elif state.phase == "shop":
				_on_refresh_pressed()
			get_viewport().set_input_as_handled()
		KEY_L:
			if state.phase == "shop":
				_on_level_pressed()
				get_viewport().set_input_as_handled()
		KEY_G:
			if state.phase == "shop":
				_on_greed_pressed()
				get_viewport().set_input_as_handled()
		KEY_C:
			if state.phase == "shop":
				_on_code_pressed()
				get_viewport().set_input_as_handled()
		KEY_M:
			if state.phase == "shop":
				_on_mirror_pressed()
				get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			if state.phase == "shop" and state.selected >= 0:
				_on_sell_pressed()
				get_viewport().set_input_as_handled()


# ---------------- 调试 / 截图 / 录像钩子 ----------------

func debug_button_counts() -> Dictionary:
	return {"shop": shop_buttons.size(), "board": board_buttons.size(), "heroes": hero_chips.size()}


func debug_shop_scene() -> void:
	state.new_run(424242)
	state.debug_set_gold(34)
	state.debug_set_level(4)
	state.debug_set_greed(2)
	state.debug_set_round(3)
	state.debug_set_board([
		{"id": "spark_flea", "star": 2},
		{"id": "prism_gadfly", "star": 1},
		{"id": "magwire_mantis", "star": 1},
		{"id": "arc_ant", "star": 1},
		{"id": "molten_weaver", "star": 2},
		{"id": "crown_colossus", "star": 1},
	])
	state.debug_set_shop(["tideheart_engine", "weave_moth", "molten_weaver", "arc_ant", "spark_flea"])
	state.flood = false
	state.saved_code = state.export_code()
	_custom_battle = false
	_hide_all_overlays()
	_refresh_all()
	_enter_shop_preview()


func debug_flood_scene() -> void:
	state.new_run(9001)
	state.debug_set_gold(42)
	state.debug_set_level(6)
	state.debug_set_greed(3)
	state.debug_set_round(5)
	state.debug_set_board(_golden_seven())
	state.debug_set_shop(["tideheart_engine", "crown_colossus", "molten_weaver", "weave_moth", "spore_ballista"])
	state.flood = true
	state.saved_code = state.export_code()
	state.stats_battles = 5
	state.stats_wins = 4
	state.stats_peak_units = Cards.UNIT_CAP_PER_SIDE
	_custom_battle = false
	_hide_all_overlays()
	_refresh_all()
	_enter_shop_preview()
	_toast("洪流协议 ×100 · 每边 %s 单位 · 贪婪潮 Lv.3 封顶后敌方 +18%% HP/ATK" % Cards.format_units(Cards.UNIT_CAP_PER_SIDE))


func debug_greed_scene() -> void:
	state.new_run(777)
	state.debug_set_gold(28)
	state.debug_set_level(5)
	state.debug_set_greed(4)
	state.debug_set_round(4)
	state.debug_set_board([
		{"id": "spark_flea", "star": 2},
		{"id": "rivet_grub", "star": 1},
		{"id": "arc_ant", "star": 2},
		{"id": "molten_weaver", "star": 1},
		{"id": "spore_ballista", "star": 1},
	])
	state.debug_set_shop(["tideheart_engine", "weave_moth", "crown_colossus", "magwire_mantis", "prism_gadfly"])
	state.flood = false
	state.saved_code = state.export_code()
	_custom_battle = false
	_hide_all_overlays()
	_refresh_all()
	_enter_shop_preview()
	_toast("贪婪潮 Lv.4：友军 +60% / 敌军 +120% 编队；已累计 +8◆。风险：敌潮涨得更快；收益：本局滚雪球。")


func debug_victory_scene() -> void:
	debug_flood_scene()
	debug_perf_overlay(false)
	state.debug_set_hero_hp(0, 11)
	state.stats_battles = 7
	state.stats_wins = 6
	state.stats_rounds_won = 6
	state.stats_peak_units = Cards.UNIT_CAP_PER_SIDE
	state.debug_force_victory()
	end_overlay.visible = false
	_refresh_all()
	_show_end_overlay()
	toast_panel.visible = false


func debug_code_scene() -> void:
	debug_flood_scene()
	debug_perf_overlay(false)
	_toast("")
	toast_panel.visible = false
	state.save_current_code()
	_on_code_pressed()
	code_edit.text = state.saved_code


func debug_perf_overlay(on: bool) -> void:
	perf_visible = on
	perf_panel.visible = on
	if on:
		_update_perf()


func debug_mount_battle(total_units: int, advance: float = 6.0, pause_after: bool = true, perf_on: bool = false, manual: bool = false) -> void:
	var half := clampi(int(total_units / 2), 1, Cards.UNIT_CAP_PER_SIDE)
	var ally := [
		{"id": "spark_flea", "star": 2}, {"id": "rivet_grub", "star": 1},
		{"id": "prism_gadfly", "star": 1}, {"id": "arc_ant", "star": 1},
		{"id": "molten_weaver", "star": 1}, {"id": "crown_colossus", "star": 1},
		{"id": "tideheart_engine", "star": 1},
	]
	var enemy := [
		{"id": "magwire_mantis", "star": 1}, {"id": "spore_ballista", "star": 1},
		{"id": "arc_ant", "star": 1}, {"id": "weave_moth", "star": 1},
		{"id": "crown_colossus", "star": 1}, {"id": "prism_gadfly", "star": 2},
		{"id": "spark_flea", "star": 1},
	]
	var b = Battle.new()
	b.setup(ally, enemy, {
		"seed": 20261126,
		"ally_greed": 1.0,
		"enemy_greed": 1.0,
		"flood": true,
		"cap": half,
		"ally_scale": 1000.0,
		"enemy_scale": 1000.0,
		"ally_label": "蔚蓝铸群",
		"enemy_label": "赤锈议会",
		"fx": true,
	})
	state.phase = "battle"
	state.battle = b
	state.training = false
	state.encounter_index = 1
	state.encounter_label = "赤锈议会"
	state.encounter_mirror = false
	state.board = ally.duplicate(true)
	state.flood = true
	state.greed = 3
	_custom_battle = true
	_hide_all_overlays()
	_hide_toast()
	battle_view.set_battle(b, false)
	battle_view.manual = manual
	battle_view.speed = 2.0
	if advance > 0.0:
		battle_view.debug_advance(advance)
	if pause_after:
		battle_view.set_paused(true)
	_refresh_all()
	_update_live_labels()
	debug_perf_overlay(perf_on)


func debug_step_battle(seconds: float) -> void:
	if battle_view.battle == null:
		return
	battle_view.debug_advance(seconds)
	_update_live_labels()


func debug_video_start(total_units: int = 3000) -> void:
	debug_mount_battle(total_units, 0.0, false, false, true)
	battle_view.speed = 3.0
	battle_view.set_paused(false)


func debug_video_frame(dt: float) -> void:
	if battle_view.battle != null and state.phase == "battle":
		battle_view.advance_manual(dt)


func debug_video_finish() -> void:
	if state.phase == "battle" and battle_view.battle != null:
		battle_view.debug_advance(32.0)
		_update_live_labels()


func debug_hide_toast() -> void:
	toast_panel.visible = false


func debug_show_toast(text: String) -> void:
	_toast(text)


func debug_get_view():
	return battle_view


func _hide_all_overlays() -> void:
	result_overlay.visible = false
	end_overlay.visible = false
	code_overlay.visible = false
	modal_open = false


func _golden_seven() -> Array:
	return [
		{"id": "crown_colossus", "star": 2},
		{"id": "tideheart_engine", "star": 2},
		{"id": "molten_weaver", "star": 2},
		{"id": "weave_moth", "star": 2},
		{"id": "spore_ballista", "star": 2},
		{"id": "arc_ant", "star": 2},
		{"id": "prism_gadfly", "star": 2},
	]


func _run_demo() -> void:
	_demo_mode = true
	debug_flood_scene()
	await get_tree().create_timer(1.8).timeout
	debug_mount_battle(3000, 0.0, false, false, false)
	battle_view.speed = 2.0
	await get_tree().create_timer(9.0).timeout
	if state.phase == "battle" and battle_view.battle != null and not battle_view.battle.finished:
		battle_view.debug_advance(31.0)
