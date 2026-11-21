extends Control

const AtlasAnimScript = preload("res://scripts/atlas_anim.gd")
const BattleAIScript = preload("res://scripts/battle_ai.gd")
const BattleCoreScript = preload("res://scripts/battle_core.gd")
const BoardViewScript = preload("res://scripts/board_view.gd")
const CardDBScript = preload("res://scripts/card_db.gd")
const CardViewScript = preload("res://scripts/card_view.gd")
const ManaBarScript = preload("res://scripts/mana_bar.gd")
const UnitViewScript = preload("res://scripts/unit_view.gd")

signal ai_turn_finished

# 格间牌战主控：搭 UI、接 BattleCore、播放切帧动画与特效。
# 设计分辨率 1280×720；只使用 2D Control/Sprite，目标 GL Compatibility。

const DESIGN_SIZE := Vector2(1280, 720)
const BOARD_POS := Vector2(236, 104)
const HAND_BASE_Y := 546.0
const PLAYER := BattleCoreScript.PLAYER
const AI := BattleCoreScript.AI

# T-019：手牌基线 564→546（悬停 1.24 时不再裁出屏幕）；
# 凤火/召唤按动作节奏裁剪时长，避免叠到下一次行动。
const FX_VISUAL_SCALE := {
	"fx_impact": 2.3,
	"fx_slashfrenzy": 0.92,
	"fx_heal": 1.15,
	"fx_buff": 1.8,
	"fx_summonlegendary": 0.70,
	"fx_f2_phoenixfire": 0.85,
}
const FX_DURATION_LIMIT := {
	"fx_slashfrenzy": 0.34,
	"fx_summonlegendary": 0.60,
	"fx_f2_phoenixfire": 1.10,
}

var db: CardDBScript
var core: BattleCoreScript
var ai: BattleAIScript

var _font: SystemFont
var _bold_font: SystemFont

var board: BoardViewScript
var _unit_layer: Node2D
var _fx_layer: Node2D
var _hand_layer: Control
var _unit_views: Dictionary = {}
var _hand_cards: Array[CardViewScript] = []
var _hand_signature := ""

var _selected_hand := -1
var _selected_unit := -1
var _awaiting_ai := false
var _game_over := false
var _hint_override := ""

var _title: Label
var _subtitle: Label
var _turn_label: Label
var _player_title: Label
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _player_deck_label: Label
var _ai_title: Label
var _ai_hp_bar: ProgressBar
var _ai_hp_label: Label
var _ai_deck_label: Label
var _log: RichTextLabel
var _mana_bar: ManaBarScript
var _mana_label: Label
var _replace_button: Button
var _end_turn_button: Button
var _help: RichTextLabel
var _status_label: Label
var _overlay: Control
var _overlay_title: Label
var _overlay_sub: Label
var _overlay_seed: Label
var _overlay_button: Button
var _active_fx: Array[Node] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size != DESIGN_SIZE:
		# 供 1920×1080 SubViewport 截图用；正常窗口的 canvas_items 拉伸仍是 1280×720。
		scale = viewport_size / DESIGN_SIZE
	_setup_theme()
	db = CardDBScript.new()
	_build_board()
	_build_header()
	_build_left_panel()
	_build_right_panel()
	_build_bottom_panels()
	_build_hand_layer()
	_build_status()
	_build_overlay()
	start_new_game(20260227)


func _setup_theme() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Noto Sans CJK SC",
		"Microsoft YaHei", "WenQuanYi Micro Hei", "sans-serif",
	])
	_font.font_weight = 500
	_font.allow_system_fallback = true

	_bold_font = SystemFont.new()
	_bold_font.font_names = _font.font_names
	_bold_font.font_weight = 700
	_bold_font.allow_system_fallback = true

	theme = Theme.new()
	theme.default_font = _font
	theme.default_font_size = 13


func _build_board() -> void:
	board = BoardViewScript.new()
	board.position = BOARD_POS
	add_child(board)
	board.tile_clicked.connect(_on_board_click)

	_unit_layer = Node2D.new()
	_unit_layer.position = BOARD_POS
	add_child(_unit_layer)

	_fx_layer = Node2D.new()
	_fx_layer.position = BOARD_POS
	# 单位 z 最高约 250（徽章层），FX 必须整体压在其上；飘字/残影再相对 +55/+60。
	_fx_layer.z_index = 300
	add_child(_fx_layer)


func _build_header() -> void:
	_title = _make_label(self, Vector2(22, 8), Vector2(360, 38), "格间牌战", 30, Color("#f2dfb0"))
	_title.add_theme_font_override("font", _bold_font)
	_title.add_theme_constant_override("outline_size", 4)
	_title.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05, 0.9))

	# 回合数只出现在这里；法力只在左下，牌库/手牌只在双方面板，各数据一次。
	_subtitle = _make_label(self, Vector2(24, 45), Vector2(420, 18),
		"", 12, Color(0.68, 0.76, 0.78, 0.92))

	_turn_label = _make_label(self, Vector2(470, 2), Vector2(340, 32), "你的回合", 26, Color("#f2dfb0"))
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_override("font", _bold_font)


func _build_left_panel() -> void:
	var panel := _make_panel(self, Vector2(14, 104), Vector2(208, 440), Color(0.04, 0.065, 0.095, 0.9), Color(0.36, 0.5, 0.56, 0.4))
	_player_title = _make_label(panel, Vector2(10, 7), Vector2(188, 24), "你 · 晨光将军", 15, Color("#f0dca8"))
	_player_title.add_theme_font_override("font", _bold_font)

	var hp := _make_hp_bar(panel, Vector2(10, 34), 188, Color("#c9a24a"))
	_player_hp_bar = hp["bar"]
	_player_hp_label = hp["label"]

	_player_deck_label = _make_label(panel, Vector2(10, 58), Vector2(188, 18), "", 11, Color(0.7, 0.78, 0.78, 0.9))
	_make_divider(panel, Vector2(10, 82), Vector2(188, 1))
	var log_title := _make_label(panel, Vector2(10, 87), Vector2(188, 20), "战斗记录", 12, Color(0.75, 0.82, 0.82, 0.95))
	log_title.add_theme_font_override("font", _bold_font)

	_log = RichTextLabel.new()
	_log.position = Vector2(10, 108)
	_log.size = Vector2(188, 322)
	_log.bbcode_enabled = false
	_log.scroll_active = true
	_log.scroll_following = true
	_log.mouse_filter = Control.MOUSE_FILTER_STOP
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_constant_override("line_separation", 3)
	_log.add_theme_color_override("default_color", Color(0.78, 0.83, 0.80, 0.95))
	panel.add_child(_log)


func _build_right_panel() -> void:
	var panel := _make_panel(self, Vector2(1042, 104), Vector2(224, 440), Color(0.075, 0.055, 0.085, 0.9), Color(0.56, 0.42, 0.48, 0.42))
	_ai_title = _make_label(panel, Vector2(10, 7), Vector2(204, 24), "对手 · 风间将军", 15, Color("#ecc9cc"))
	_ai_title.add_theme_font_override("font", _bold_font)

	var hp := _make_hp_bar(panel, Vector2(10, 34), 204, Color("#b5525c"))
	_ai_hp_bar = hp["bar"]
	_ai_hp_label = hp["label"]

	_ai_deck_label = _make_label(panel, Vector2(10, 58), Vector2(204, 18), "", 11, Color(0.78, 0.7, 0.72, 0.9))
	_make_divider(panel, Vector2(10, 82), Vector2(204, 1))

	var help_title := _make_label(panel, Vector2(10, 89), Vector2(204, 20), "操作与图例", 12, Color(0.82, 0.86, 0.86, 0.95))
	help_title.add_theme_font_override("font", _bold_font)
	_help = RichTextLabel.new()
	_help.position = Vector2(10, 110)
	_help.size = Vector2(204, 238)
	_help.bbcode_enabled = true
	_help.scroll_active = false
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_font_size_override("normal_font_size", 11)
	_help.add_theme_constant_override("line_separation", 5)
	_help.text = "[color=#6ff2cf]■[/color] 青框 · 移动一格\n[color=#e5484d]■[/color] 红环 · 攻击目标\n[color=#7aa2ff]◆[/color] 蓝虚 · 法术目标\n[color=#e8c56a]○[/color] 金圈 · 召唤位置\n[color=#f7f2df]◎[/color] 白环 · 当前选中\n\n[color=#d4657a]━[/color] 上绯 = 敌方阵地\n[color=#e8c56a]━[/color] 下金 = 己方阵地\n\n空格 结束回合\nR 重开 · Esc 取消"
	panel.add_child(_help)

	_end_turn_button = _make_button(panel, Vector2(10, 356), Vector2(204, 54), "结束回合", 19)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)


func _build_bottom_panels() -> void:
	var left := _make_panel(self, Vector2(14, 560), Vector2(208, 146), Color(0.04, 0.065, 0.095, 0.9), Color(0.36, 0.5, 0.56, 0.4))
	_make_label(left, Vector2(10, 6), Vector2(188, 18), "法力池", 11, Color(0.75, 0.82, 0.82, 0.95))
	_mana_bar = ManaBarScript.new()
	_mana_bar.position = Vector2(10, 26)
	_mana_bar.size = Vector2(188, 30)
	left.add_child(_mana_bar)
	_mana_label = _make_label(left, Vector2(10, 58), Vector2(188, 18), "1 / 1", 11, Color(0.62, 0.82, 0.9, 0.95))
	_replace_button = _make_button(left, Vector2(10, 86), Vector2(188, 44), "换一张手牌", 13)
	_replace_button.pressed.connect(_on_replace_pressed)

	var right := _make_panel(self, Vector2(1042, 560), Vector2(224, 146), Color(0.075, 0.055, 0.085, 0.9), Color(0.56, 0.42, 0.48, 0.42))
	var control_title := _make_label(right, Vector2(12, 10), Vector2(200, 18), "对局控制", 12, Color(0.82, 0.8, 0.84, 0.95))
	control_title.add_theme_font_override("font", _bold_font)
	var restart := _make_button(right, Vector2(12, 42), Vector2(200, 46), "重新开始", 15)
	restart.pressed.connect(_on_restart_pressed)
	_make_label(right, Vector2(12, 102), Vector2(200, 18), "R 键 · 随时开新局", 10, Color(0.70, 0.68, 0.72, 0.9))


func _build_hand_layer() -> void:
	_hand_layer = Control.new()
	_hand_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)


func _build_status() -> void:
	# 状态提示从手牌上方 (236,545) 移到顶栏底部 y=62，任何悬停/选中卡都不会遮住它。
	_status_label = _make_label(self, Vector2(BOARD_POS.x, 62), Vector2(792, 16), "", 12, Color(0.72, 0.90, 0.87, 0.95))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 1000
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.025, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var panel := _make_panel(_overlay, Vector2(400, 220), Vector2(480, 280), Color(0.045, 0.06, 0.085, 0.98), Color(0.62, 0.52, 0.32, 0.7), 14)
	_overlay_title = _make_label(panel, Vector2(20, 26), Vector2(440, 58), "", 40, Color("#f6e3b3"))
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_override("font", _bold_font)
	_overlay_title.add_theme_constant_override("outline_size", 6)
	_overlay_title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))

	_overlay_sub = _make_label(panel, Vector2(20, 92), Vector2(440, 56), "", 14, Color(0.82, 0.84, 0.8, 0.95))
	_overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_overlay_seed = _make_label(panel, Vector2(20, 150), Vector2(440, 20), "", 11, Color(0.62, 0.68, 0.66, 0.9))
	_overlay_seed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_overlay_button = _make_button(panel, Vector2(140, 196), Vector2(200, 52), "再来一局", 18)
	_overlay_button.pressed.connect(_on_overlay_restart)


func start_new_game(seed_in := -1) -> void:
	if seed_in < 0:
		seed_in = int(Time.get_unix_time_from_system() * 1000.0) % 999983
	core = BattleCoreScript.new(db)
	core.setup(seed_in, db.deck("player"), db.deck("ai"))
	ai = BattleAIScript.new()
	_selected_hand = -1
	_selected_unit = -1
	_awaiting_ai = false
	_game_over = false
	_hint_override = ""
	for view in _unit_views.values():
		view.queue_free()
	_unit_views.clear()
	for card in _hand_cards:
		card.queue_free()
	_hand_cards.clear()
	_hand_signature = ""
	for child in _fx_layer.get_children():
		child.queue_free()
	_active_fx.clear()
	_overlay.visible = false
	board.set_core(core)
	refresh_all()


func refresh_all(skip_pos_uid := -1) -> void:
	if core == null:
		return
	if _selected_hand >= core.hands[PLAYER].size():
		_selected_hand = -1
	_sync_units(skip_pos_uid)
	_rebuild_hand()
	_update_texts()
	_update_highlights()


func sync_all(skip_pos_uid := -1) -> void:
	refresh_all(skip_pos_uid)


func get_core() -> BattleCoreScript:
	return core


func _sync_units(skip_pos_uid: int) -> void:
	var alive := {}
	for unit in core.units:
		var uid := int(unit["uid"])
		alive[uid] = true
		var pos := board.cell_center(Vector2i(unit["x"], unit["y"]))
		var view: UnitViewScript = _unit_views.get(uid)
		if view == null:
			view = UnitViewScript.new()
			_unit_layer.add_child(view)
			view.configure(unit)
			view.position = pos
			view.scale = Vector2(0.25, 0.25)
			var tw := view.create_tween()
			tw.tween_property(view, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_unit_views[uid] = view
		else:
			view.set_stats(unit)
			if uid != skip_pos_uid:
				view.position = pos
	for uid in _unit_views.keys():
		if not alive.has(uid):
			var view: UnitViewScript = _unit_views[uid]
			view.queue_free()
			_unit_views.erase(uid)


func _rebuild_hand() -> void:
	var hand: Array = core.hands[PLAYER]
	var count := hand.size()
	var signature := "|".join(hand)
	if signature == _hand_signature and _hand_cards.size() == count:
		for i in count:
			_hand_cards[i].set_selected(i == _selected_hand)
		return
	_hand_signature = signature
	for card in _hand_cards:
		card.queue_free()
	_hand_cards.clear()
	for i in count:
		var card := CardViewScript.new()
		card.setup(core.hand_card(PLAYER, i), i, db)
		_hand_layer.add_child(card)
		var spacing := 118.0 if count > 1 else 0.0
		var total := float(count - 1) * spacing
		var center_offset := float(i) - float(count - 1) * 0.5
		card.position = Vector2(
			640.0 - total * 0.5 + float(i) * spacing - CardViewScript.CARD_SIZE.x * 0.5,
			HAND_BASE_Y + absf(center_offset) * 7.0 - (26.0 if i == _selected_hand else 0.0))
		card.rotation = deg_to_rad(center_offset * 2.2)
		card.set_selected(i == _selected_hand)
		card.clicked.connect(_on_card_clicked)
		_hand_cards.append(card)


func _update_texts() -> void:
	if core == null:
		return
	var p_hp := core.general_hp(PLAYER)
	var p_max := int(core.general_unit(PLAYER).get("max_hp", 20))
	var a_hp := core.general_hp(AI)
	var a_max := int(core.general_unit(AI).get("max_hp", 20))
	_update_bar(_player_hp_bar, _player_hp_label, p_hp, p_max, Color("#c9a24a"))
	_update_bar(_ai_hp_bar, _ai_hp_label, a_hp, a_max, Color("#b5525c"))
	_player_deck_label.text = "牌库 %d · 手牌 %d / %d" % [
		core.decks[PLAYER].size(), core.hands[PLAYER].size(), BattleCoreScript.HAND_LIMIT]
	_ai_deck_label.text = "牌库 %d · 手牌 %d / %d" % [
		core.decks[AI].size(), core.hands[AI].size(), BattleCoreScript.HAND_LIMIT]
	_mana_bar.set_values(core.mana[PLAYER], core.max_mana[PLAYER])
	_mana_label.text = "法力 %d / %d" % [core.mana[PLAYER], core.max_mana[PLAYER]]
	_subtitle.text = "第 %d 回合 · 先手 你" % maxi(1, core.started_turns[PLAYER])

	# 顶栏是回合状态的唯一来源：玩家金 / 对手绯 / 结束后“对局结束”。
	var player_turn := core.turn_owner == PLAYER and not _awaiting_ai
	if _game_over:
		_turn_label.text = "对局结束"
		_turn_label.add_theme_color_override("font_color", Color("#d8d2c2"))
	elif player_turn:
		_turn_label.text = "你的回合"
		_turn_label.add_theme_color_override("font_color", Color("#f2dfb0"))
	else:
		_turn_label.text = "对手回合"
		_turn_label.add_theme_color_override("font_color", Color("#ecc9cc"))

	# 胜负覆盖层期间隐藏顶栏状态，避免“对局已结束”与“你的回合”同屏。
	_turn_label.visible = not _game_over
	_subtitle.visible = not _game_over
	_status_label.visible = not _game_over

	# AI 回合手牌降亮 + 不可点，和“对手正在行动”保持一致。
	var hand_dim := _awaiting_ai or core.turn_owner != PLAYER or _game_over
	_hand_layer.modulate = Color(0.60, 0.60, 0.64, 1.0) if hand_dim else Color.WHITE
	for card in _hand_cards:
		card.set_interactive(not hand_dim)

	_end_turn_button.disabled = _awaiting_ai or _game_over or core.turn_owner != PLAYER
	if _game_over:
		_end_turn_button.text = "对局结束"
	elif _awaiting_ai:
		_end_turn_button.text = "对手行动中…"
	else:
		_end_turn_button.text = "结束回合"
	_replace_button.disabled = _awaiting_ai or _game_over or core.turn_owner != PLAYER or core.replace_used[PLAYER] or core.hands[PLAYER].is_empty()
	_log.text = "\n".join(core.log_lines.slice(maxi(0, core.log_lines.size() - 10)))
	_update_status()


func _update_bar(bar: ProgressBar, label: Label, hp: int, max_hp: int, color: Color) -> void:
	if bar == null:
		return
	bar.max_value = maxi(1, max_hp)
	bar.value = clampi(hp, 0, max_hp)
	label.text = "%d / %d" % [hp, max_hp]
	var fill := StyleBoxFlat.new()
	fill.bg_color = color if hp > 5 else Color("#d45a4f")
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5
	bar.add_theme_stylebox_override("fill", fill)


func _update_highlights() -> void:
	if core == null:
		return
	var moves: Array[Vector2i] = []
	var attacks: Array[Vector2i] = []
	var summons: Array[Vector2i] = []
	var spells: Array[Vector2i] = []

	if not _awaiting_ai and not _game_over and core.turn_owner == PLAYER:
		if _selected_hand >= 0:
			var card := core.hand_card(PLAYER, _selected_hand)
			if not card.is_empty() and int(card.get("cost", 99)) <= core.mana[PLAYER]:
				if card.get("type", "") == "unit":
					summons = core.get_summon_tiles(PLAYER)
				elif card.get("type", "") == "spell":
					for unit in core.units:
						if core.can_cast(PLAYER, _selected_hand, int(unit["uid"])):
							spells.append(Vector2i(unit["x"], unit["y"]))
		elif _selected_unit >= 0:
			var unit := core.find_unit(_selected_unit)
			if unit.is_empty() or int(unit["owner"]) != PLAYER:
				_selected_unit = -1
			else:
				moves = core.get_move_tiles(_selected_unit)
				for target_uid in core.get_attack_targets(_selected_unit):
					var target := core.find_unit(target_uid)
					if not target.is_empty():
						attacks.append(Vector2i(target["x"], target["y"]))

	board.set_highlights(moves, attacks, summons, spells, _selected_unit)
	var can_act := not _awaiting_ai and not _game_over and core.turn_owner == PLAYER
	for i in _hand_cards.size():
		_hand_cards[i].set_selected(i == _selected_hand)
		var data := core.hand_card(PLAYER, i)
		var affordable := (not can_act) or int(data.get("cost", 99)) <= core.mana[PLAYER]
		_hand_cards[i].set_affordable(affordable)


const STATUS_HINT := Color("#b8e6df")
const STATUS_AI := Color("#e7a0a8")
const STATUS_WARN := Color("#ffcf8a")


func _update_status() -> void:
	if _status_label == null:
		return
	if not _hint_override.is_empty():
		_set_status(_hint_override, STATUS_WARN)
		return
	if _game_over:
		_set_status("", STATUS_HINT)
		return
	if _awaiting_ai or core == null:
		_set_status("对手正在行动…" if _awaiting_ai else "", STATUS_AI)
		return
	if core.turn_owner != PLAYER:
		_set_status("对手回合", STATUS_AI)
		return
	if _selected_hand >= 0:
		var card := core.hand_card(PLAYER, _selected_hand)
		if card.is_empty():
			_set_status("点击手牌出牌，或点击己方单位行动", STATUS_HINT)
		elif int(card.get("cost", 99)) > core.mana[PLAYER]:
			_set_status("法力不足：%s 需要 %d 点" % [card["name"], int(card["cost"])], STATUS_WARN)
		elif card.get("type", "") == "unit":
			_set_status("点击金圈格召唤 %s" % card["name"], STATUS_HINT)
		else:
			_set_status("点击蓝虚圈目标施放 %s" % card["name"], STATUS_HINT)
		return
	if _selected_unit >= 0:
		var unit := core.find_unit(_selected_unit)
		if unit.is_empty():
			_set_status("点击手牌出牌，或点击己方单位行动", STATUS_HINT)
		elif not unit["can_move"] and not unit["can_attack"]:
			_set_status("%s 本回合已行动完毕" % unit["name"], STATUS_HINT)
		elif unit["can_move"] and not core.get_move_tiles(_selected_unit).is_empty():
			_set_status("%s：青框格移动一格；红环敌人可攻击" % unit["name"], STATUS_HINT)
		else:
			_set_status("%s：红环敌人可攻击" % unit["name"], STATUS_HINT)
		return
	_set_status("点击手牌出牌，或点击己方单位行动", STATUS_HINT)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _on_card_clicked(index: int) -> void:
	if _awaiting_ai or _game_over or core == null or core.turn_owner != PLAYER:
		return
	if _selected_hand == index:
		_selected_hand = -1
	else:
		_selected_hand = index
		_selected_unit = -1
	_hint_override = ""
	_update_highlights()
	_update_status()


func _on_board_click(pos: Vector2i) -> void:
	if _awaiting_ai or _game_over or core.turn_owner != PLAYER:
		return
	var occupant := core.unit_at(pos)
	if _selected_hand >= 0:
		var card := core.hand_card(PLAYER, _selected_hand)
		if card.is_empty():
			_selected_hand = -1
			_update_highlights()
			return
		if card.get("type", "") == "unit":
			if int(card.get("cost", 99)) > core.mana[PLAYER]:
				_flash_hint("法力不足")
			elif not core.can_play_unit(PLAYER, _selected_hand, pos):
				_flash_hint("需要与己方将军或随从相邻的空格")
			else:
				_player_summon(_selected_hand, pos)
			return
		if occupant.is_empty():
			_flash_hint("请选择高亮的单位目标")
		elif not core.can_cast(PLAYER, _selected_hand, int(occupant["uid"])):
			_flash_hint("该目标不能施放这张法术")
		else:
			_player_cast(_selected_hand, int(occupant["uid"]))
		return

	if _selected_unit >= 0:
		var selected := core.find_unit(_selected_unit)
		if selected.is_empty():
			_selected_unit = -1
			_update_highlights()
			return
		if not occupant.is_empty() and int(occupant["uid"]) in core.get_attack_targets(_selected_unit):
			_player_attack(_selected_unit, int(occupant["uid"]))
			return
		if pos in core.get_move_tiles(_selected_unit):
			_player_move(_selected_unit, pos)
			return
		if not occupant.is_empty() and int(occupant["owner"]) == PLAYER:
			if int(occupant["uid"]) == _selected_unit:
				_selected_unit = -1
			else:
				_selected_unit = int(occupant["uid"])
			_update_highlights()
			_update_status()
			return
		_selected_unit = -1
		_hint_override = ""
		_update_highlights()
		_update_status()
		return

	if not occupant.is_empty() and int(occupant["owner"]) == PLAYER:
		_selected_unit = int(occupant["uid"])
		_selected_hand = -1
		_hint_override = ""
		_update_highlights()
		_update_status()


func _player_summon(hand_index: int, pos: Vector2i) -> void:
	var action := core.play_unit(PLAYER, hand_index, pos)
	if action.is_empty():
		return
	_selected_hand = -1
	_selected_unit = -1
	_animate_action(action)
	refresh_all()


func _player_move(uid: int, pos: Vector2i) -> void:
	var action := core.move_unit(uid, pos)
	if action.is_empty():
		return
	_animate_action(action)
	refresh_all(uid)
	_update_status()


func _player_attack(attacker_uid: int, target_uid: int) -> void:
	var action := core.attack(attacker_uid, target_uid)
	if action.is_empty():
		return
	_selected_unit = -1
	_animate_action(action)
	refresh_all()
	_maybe_game_over()


func _player_cast(hand_index: int, target_uid: int) -> void:
	var action := core.cast_spell(PLAYER, hand_index, target_uid)
	if action.is_empty():
		return
	_selected_hand = -1
	_selected_unit = -1
	_animate_action(action)
	refresh_all()
	_maybe_game_over()


func _on_end_turn_pressed() -> void:
	if core == null or _awaiting_ai or _game_over or core.turn_owner != PLAYER:
		return
	_selected_hand = -1
	_selected_unit = -1
	_hint_override = ""
	core.end_turn()
	refresh_all()
	_run_ai_turn()


func _run_ai_turn() -> void:
	if core == null or core.winner >= 0:
		_maybe_game_over()
		ai_turn_finished.emit()
		return
	_awaiting_ai = true
	ai.begin_turn(core)
	refresh_all()
	await get_tree().create_timer(0.45).timeout
	var steps := 0
	while steps < 120 and core.winner < 0 and core.turn_owner == AI:
		var action := ai.next_action(core)
		var kind := String(action.get("type", "none"))
		if action.is_empty() or kind == "none":
			break
		if kind == "end_turn":
			break
		_animate_action(action)
		var skip := int(action.get("uid", -1)) if kind == "move" else -1
		refresh_all(skip)
		await get_tree().create_timer(_action_delay(kind)).timeout
		if not is_inside_tree():
			return
		steps += 1
	if core.winner < 0 and core.turn_owner == AI:
		core.end_turn()
	_awaiting_ai = false
	refresh_all()
	_maybe_game_over()
	ai_turn_finished.emit()


func _action_delay(kind: String) -> float:
	# 表现节奏（不是 AI 决策）：召唤/法术的 FX 已裁到 0.6 / 1.1s，
	# 动作间隔同步放大，保证特效不与下一次行动首帧重叠。
	match kind:
		"summon": return 0.66
		"move": return 0.36
		"attack": return 0.62
		"spell": return 1.05
		_: return 0.25


func _animate_action(action: Dictionary) -> void:
	var kind := String(action.get("type", ""))
	match kind:
		"summon":
			_spawn_fx("fx_summonlegendary", action["pos"], 0.82)
		"move":
			var view: UnitViewScript = _unit_views.get(int(action["uid"]))
			if view:
				view.move_to(board.cell_center(action["to"]))
		"attack":
			_animate_attack(action)
		"spell":
			_animate_spell(action)
	_spawn_deaths(action.get("deaths", []))


func _animate_attack(action: Dictionary) -> void:
	var attacker: UnitViewScript = _unit_views.get(int(action["attacker_uid"]))
	var target: UnitViewScript = _unit_views.get(int(action["target_uid"]))
	var target_pos: Vector2i = action["target_pos"]
	if attacker:
		attacker.play_attack()
		attacker.set_facing_toward(board.cell_center(target_pos).x)
		if target:
			attacker.lunge_toward(target.position)
	if target:
		target.play_hit()
	var fx_id := "fx_slashfrenzy"
	if attacker and attacker.sprite and attacker.sprite.sheet_id == "f1_backlinearcher":
		fx_id = "fx_impact"
	_spawn_fx(fx_id, target_pos, float(FX_VISUAL_SCALE.get(fx_id, 1.0)))
	if fx_id == "fx_slashfrenzy":
		_spawn_hit_flash(target_pos, Color("#fff3d0"), Color("#ffb347"), 1.0)
	else:
		_spawn_hit_flash(target_pos, Color("#eaf2ff"), Color("#7aa2ff"), 0.72)
	_float_text("-%d" % int(action["damage"]), Color("#ff7d72"), target_pos)


func _animate_spell(action: Dictionary) -> void:
	var target_pos: Vector2i = action["target_pos"]
	var card_id := String(action.get("card_id", ""))
	var target: UnitViewScript = _unit_views.get(int(action["target_uid"]))
	match card_id:
		"f1_sundropelixir":
			_spawn_fx("fx_heal", target_pos, float(FX_VISUAL_SCALE["fx_heal"]))
			if action.get("healed", 0) > 0:
				_float_text("+%d" % int(action["healed"]), Color("#8ef0a5"), target_pos)
		"f1_truestrike":
			_spawn_fx("fx_impact", target_pos, float(FX_VISUAL_SCALE["fx_impact"]))
			_spawn_hit_flash(target_pos, Color("#eaf2ff"), Color("#7aa2ff"), 0.72)
			if target:
				target.play_hit()
			_float_text("-%d" % int(action.get("damage", 0)), Color("#ff7d72"), target_pos)
		"f2_phoenixfire":
			_spawn_fx("fx_f2_phoenixfire", target_pos, float(FX_VISUAL_SCALE["fx_f2_phoenixfire"]))
			_spawn_hit_flash(target_pos, Color("#fff3d0"), Color("#ff8a4a"), 0.9)
			if target:
				target.play_hit()
			_float_text("-%d" % int(action.get("damage", 0)), Color("#ff9a62"), target_pos)
		"f2_cobrastrike":
			_spawn_fx("fx_buff", target_pos, float(FX_VISUAL_SCALE["fx_buff"]))
			_spawn_hit_flash(target_pos, Color("#fff3d0"), Color("#e8c56a"), 0.55)
			_float_text("+2 攻", Color("#ffd36e"), target_pos)
		_:
			_spawn_fx("fx_buff", target_pos, 1.4)


func _spawn_deaths(deaths: Array) -> void:
	for death in deaths:
		var ghost := AtlasAnimScript.new()
		ghost.position = board.cell_center(Vector2i(death["x"], death["y"]))
		var scale_base := 1.22 * (1.1 if death.get("is_general", false) else 1.0)
		ghost.scale = Vector2(scale_base, scale_base)
		ghost.z_index = 55
		_fx_layer.add_child(ghost)
		if ghost.load_sheet(str(death.get("sprite", "")), "units"):
			ghost.play("death", 14.0, false)
			ghost.finished.connect(func(_name): _fade_free(ghost))
		else:
			ghost.queue_free()


func _spawn_fx(anim_id: String, pos: Vector2i, visual_scale := 1.0, max_duration := -1.0, tint := Color.WHITE, fade := 0.12) -> void:
	var fx := AtlasAnimScript.new()
	fx.position = board.cell_center(pos)
	fx.scale = Vector2(visual_scale, visual_scale)
	fx.z_index = 60
	fx.modulate = tint
	_fx_layer.add_child(fx)
	if fx.load_sheet(anim_id, "fx"):
		var limit := max_duration
		if limit <= 0.0:
			limit = float(FX_DURATION_LIMIT.get(anim_id, 0.0))
		var fps := 24.0
		var frames := fx.frame_count("")
		if limit > 0.0 and frames > 0:
			fps = float(frames) / limit
		fx.play("", fps, false)
		fx.finished.connect(func(_name): _fade_free(fx, fade))
		_track_fx(fx)
	else:
		fx.queue_free()


# 原创程序化命中闪光：白热核心 + 暖色外焰，0.10s 展开、0.06s 停留后淡出；
# 不引入新素材，弥补图集截击帧在高亮背景上的对比不足。
func _spawn_hit_flash(pos: Vector2i, core_color: Color, outer_color: Color, size := 1.0) -> void:
	var flash := Node2D.new()
	flash.position = board.cell_center(pos)
	flash.z_index = 70
	_fx_layer.add_child(flash)

	var outer := Polygon2D.new()
	outer.polygon = _star_points(34.0 * size, 21.0 * size, 8)
	outer.color = Color(outer_color.r, outer_color.g, outer_color.b, 0.72)
	flash.add_child(outer)

	var core := Polygon2D.new()
	core.polygon = _star_points(20.0 * size, 11.0 * size, 8)
	core.color = Color(core_color.r, core_color.g, core_color.b, 0.98)
	flash.add_child(core)

	flash.scale = Vector2(0.55, 0.55)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.16).set_delay(0.06)
	tw.chain().tween_callback(flash.queue_free)
	_track_fx(flash)


func _star_points(outer: float, inner: float, spikes: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := TAU * float(i) / float(spikes * 2) - PI * 0.5
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _track_fx(node: Node) -> void:
	_active_fx.append(node)
	_prune_fx()
	# 同屏最多 2 个 FX；更旧的一个立即进入 0.08s 淡出，防止叠到下一次行动。
	while _active_fx.size() > 2:
		var oldest: Node = _active_fx.pop_front()
		if is_instance_valid(oldest):
			_fade_free(oldest, 0.08)


func _prune_fx() -> void:
	var kept: Array[Node] = []
	for node in _active_fx:
		if is_instance_valid(node):
			kept.append(node)
	_active_fx = kept


func _fade_free(node: Node, duration := 0.12) -> void:
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, duration)
	tw.finished.connect(node.queue_free)


func _float_text(text: String, color: Color, pos: Vector2i) -> void:
	var label := Label.new()
	label.text = text
	label.position = board.cell_center(pos) + Vector2(-30, -62)
	label.size = Vector2(60, 26)
	label.pivot_offset = Vector2(30, 13)
	label.scale = Vector2(0.8, 0.8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_font_override("font", _bold_font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(label)
	var move := create_tween()
	move.set_parallel(true)
	move.tween_property(label, "position:y", label.position.y - 34.0, 0.80).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(label, "scale", Vector2(1.15, 1.15), 0.06)
	var settle := create_tween()
	settle.tween_interval(0.06)
	settle.tween_property(label, "scale", Vector2.ONE, 0.10)
	var fade := create_tween()
	fade.tween_interval(0.42)
	fade.tween_property(label, "modulate:a", 0.0, 0.38)
	fade.tween_callback(label.queue_free)


func _flash_hint(text: String) -> void:
	_hint_override = text
	_update_status()
	var token := text
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree() and _hint_override == token:
		_hint_override = ""
		_update_status()


func _on_replace_pressed() -> void:
	if core == null or _awaiting_ai or _game_over or core.turn_owner != PLAYER:
		return
	if _selected_hand < 0:
		_flash_hint("先点一张手牌，再按换牌")
		return
	if not core.replace_card(PLAYER, _selected_hand):
		_flash_hint("本回合已经换过牌，或手牌不可换")
		return
	_selected_hand = -1
	refresh_all()
	_flash_hint("已换一张牌")


func _on_restart_pressed() -> void:
	if _awaiting_ai:
		_flash_hint("对手行动中，稍后再重开")
		return
	start_new_game(-1)
	_flash_hint("新的一局")


func _on_overlay_restart() -> void:
	start_new_game(-1)


func _maybe_game_over() -> void:
	if core == null or core.winner < 0 or _game_over:
		return
	_game_over = true
	_awaiting_ai = false
	_selected_hand = -1
	_selected_unit = -1
	_update_highlights()
	_update_texts()
	var won := core.winner == PLAYER
	_overlay_title.text = "胜利" if won else "败北"
	_overlay_title.add_theme_color_override("font_color", Color("#f6e3b3") if won else Color("#e8a1a1"))
	_overlay_sub.text = "对手的将军倒下了。" if won else "你的将军倒下了。"
	_overlay_seed.text = "Seed %d · 第 %d 回合" % [core.seed_value, maxi(1, core.started_turns[PLAYER])]
	_overlay.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE, KEY_ENTER:
			_on_end_turn_pressed()
		KEY_R:
			_on_restart_pressed()
		KEY_ESCAPE:
			_selected_hand = -1
			_selected_unit = -1
			_hint_override = ""
			_update_highlights()
			_update_status()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080c15"))
	draw_circle(Vector2(110, 140), 300.0, Color(0.10, 0.22, 0.28, 0.16))
	draw_circle(Vector2(1190, 630), 390.0, Color(0.28, 0.12, 0.16, 0.13))
	for x in range(0, 1281, 80):
		draw_line(Vector2(x, 78), Vector2(x, 720), Color(1, 1, 1, 0.018), 1.0)
	for y in range(80, 721, 80):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, 0.018), 1.0)
	draw_rect(Rect2(0, 0, 1280, 78), Color(0.02, 0.03, 0.05, 0.62))
	draw_line(Vector2(0, 78), Vector2(1280, 78), Color(0.42, 0.58, 0.62, 0.28), 1.0)
	draw_line(Vector2(22, 72), Vector2(326, 72), Color(0.78, 0.64, 0.33, 0.42), 1.0)
	for i in 4:
		var cx := 1200.0 + i * 16.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, 20), Vector2(cx + 5, 25), Vector2(cx, 30), Vector2(cx - 5, 25),
		]), Color(0.78, 0.64, 0.33, 0.18 + i * 0.07))


# ---- 演示/截图工具用公开接口（正常游玩不会调用） ----

func demo_showcase() -> Dictionary:
	start_new_game(20260227)
	var keep: Array[Dictionary] = []
	for unit in core.units:
		if unit["is_general"]:
			keep.append(unit)
	core.units = keep
	var placements := [
		["f1_silverguardsquire", PLAYER, Vector2i(3, 3)],
		["f1_backlinearcher", PLAYER, Vector2i(5, 4)],
		["f1_sunstonetemplar", PLAYER, Vector2i(4, 2)],
		["f1_windbladecommander", PLAYER, Vector2i(2, 4)],
		["neutral_healingmystic", PLAYER, Vector2i(6, 4)],
		["f2_onyxjaguar", AI, Vector2i(3, 2)],
		["f2_sparrowhawk", AI, Vector2i(3, 0)],
		["f2_lanternfox", AI, Vector2i(5, 1)],
		["f2_mage4winds", AI, Vector2i(6, 2)],
		["f2_heartofthesonghai", AI, Vector2i(2, 2)],
	]
	var uids := {}
	for placement in placements:
		var uid := core.debug_spawn(placement[0], placement[1], placement[2])
		uids[placement[0]] = uid
	core.hands[PLAYER] = [
		"f1_ironcliffeguardian", "f1_windbladecommander", "f2_phoenixfire",
		"f1_sundropelixir", "f1_silverguardsquire", "f1_backlinearcher",
	]
	core.hands[AI] = ["f2_phoenixfire", "f2_heartofthesonghai", "f2_onyxjaguar"]
	core.mana = [9, 6]
	core.max_mana = [9, 6]
	core.log_lines.clear()
	core.log_line("—— 第 9 回合 · 你的回合 ——")
	core.log_line("你召唤了 白银侍从 与 日石骑士。")
	core.log_line("对手召唤了 猛虎刺客、灯笼狐 与 四方法师。")
	core.log_line("前阵弓手 对 雀鹰 造成 1 点伤害。")
	core.log_line("风刃指挥官 对 猛虎刺客 造成 3 点伤害。")
	core.log_line("—— 法力恢复到 9 / 9 ——")
	core.started_turns = [9, 9]
	while core.decks[PLAYER].size() > 14:
		core.decks[PLAYER].pop_back()
	core.turn_owner = PLAYER
	core.replace_used = [false, false]
	var player_general := core.general_unit(PLAYER)
	if not player_general.is_empty():
		player_general["hp"] = 14
	var ai_general := core.general_unit(AI)
	if not ai_general.is_empty():
		ai_general["hp"] = 11
	for unit in core.units:
		unit["can_move"] = int(unit["owner"]) == PLAYER
		unit["can_attack"] = int(unit["owner"]) == PLAYER
	refresh_all()
	return uids


func demo_select_hand(index: int) -> void:
	_selected_hand = index
	_selected_unit = -1
	_hint_override = ""
	_update_highlights()
	_update_status()


func demo_select_unit(uid: int) -> void:
	_selected_unit = uid
	_selected_hand = -1
	_hint_override = ""
	_update_highlights()
	_update_status()


func demo_hover_card(index: int, entered := true) -> void:
	if index < 0 or index >= _hand_cards.size():
		return
	var card := _hand_cards[index]
	if entered:
		card._on_mouse_entered()
	else:
		card._on_mouse_exited()


func demo_hover_tile(pos: Vector2i) -> void:
	board.hovered = pos
	board.queue_redraw()


func demo_summon(hand_index: int, pos: Vector2i) -> Dictionary:
	var action := core.play_unit(PLAYER, hand_index, pos)
	if action.is_empty():
		return {}
	_selected_hand = -1
	_selected_unit = -1
	_animate_action(action)
	refresh_all()
	return action


func demo_move(uid: int, pos: Vector2i) -> Dictionary:
	var action := core.move_unit(uid, pos)
	if action.is_empty():
		return {}
	_selected_hand = -1
	_selected_unit = -1
	_animate_action(action)
	refresh_all(uid)
	return action


func demo_attack(attacker_uid: int, target_uid: int) -> Dictionary:
	var action := core.attack(attacker_uid, target_uid)
	if action.is_empty():
		return {}
	_selected_hand = -1
	_selected_unit = -1
	_animate_action(action)
	refresh_all()
	return action


func demo_cast(owner: int, hand_index: int, target_uid: int) -> Dictionary:
	var action := core.cast_spell(owner, hand_index, target_uid)
	if action.is_empty():
		return {}
	_selected_hand = -1
	_selected_unit = -1
	_animate_action(action)
	refresh_all()
	return action


func demo_win(win_owner: int) -> void:
	if core == null or core.winner >= 0:
		return
	var loser := AI if win_owner == PLAYER else PLAYER
	var general := core.general_unit(loser)
	if general.is_empty():
		return
	core.damage_unit(int(general["uid"]), 999, "将军倒下")
	refresh_all()
	_maybe_game_over()


func demo_ai_turn() -> void:
	_run_ai_turn()


func demo_end_turn() -> void:
	_on_end_turn_pressed()


func is_ai_turn_active() -> bool:
	return _awaiting_ai


# ---- 小工具 ----

func _make_panel(parent: Node, pos: Vector2, panel_size: Vector2, bg: Color, border: Color, radius := 10) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _make_label(parent: Node, pos: Vector2, label_size: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_divider(parent: Node, pos: Vector2, div_size: Vector2) -> ColorRect:
	var line := ColorRect.new()
	line.position = pos
	line.size = div_size
	line.color = Color(0.5, 0.62, 0.64, 0.25)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


func _make_hp_bar(parent: Node, pos: Vector2, width: float, fill_color: Color) -> Dictionary:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(width, 20)
	bar.min_value = 0
	bar.max_value = 20
	bar.value = 20
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.1, 0.12, 0.95)
	bg.corner_radius_top_left = 5
	bg.corner_radius_top_right = 5
	bg.corner_radius_bottom_left = 5
	bg.corner_radius_bottom_right = 5
	bg.border_color = Color(0.45, 0.45, 0.42, 0.45)
	bg.set_border_width_all(1)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)

	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#fff4dc"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	return {"bar": bar, "label": label}


func _make_button(parent: Node, pos: Vector2, button_size: Vector2, text: String, font_size: int) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_font_override("font", _bold_font)
	button.add_theme_color_override("font_color", Color("#f1e6c9"))
	button.add_theme_color_override("font_hover_color", Color("#fff8df"))
	button.add_theme_color_override("font_pressed_color", Color("#d9cba9"))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.52, 0.6))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1c334b")
	normal.border_color = Color("#5b809b")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#2a4a69")
	hover.border_color = Color("#8fb4ca")

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#132438")

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#171c24")
	disabled.border_color = Color(0.3, 0.34, 0.36, 0.5)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	parent.add_child(button)
	return button
