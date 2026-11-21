class_name BattleHUD
extends Control

# 指令阶段 HUD：右下指令面板、目标选择、25 秒倒计时、左上出手顺序、左下战斗日志、
# 右上播放控制。表现层只读状态，指令仅通过 BattleIntent 交给 Session。

enum MenuMode { IDLE, ROOT, SKILLS, ITEMS, TARGET }

const ALLY_COLOR := Color(0.58, 0.8, 1.0)
const ENEMY_COLOR := Color(1.0, 0.6, 0.48)
const GOLD := Color(1.0, 0.86, 0.5)
const MUTED := Color(0.68, 0.7, 0.74)

var context: BattleContext
var command_time := 25.0
var last_intents: Array = []

var _content: ContentDB
var _engine: BattleEngine
var _collecting := false
var _timed_out := false
var _time_left := 25.0
var _mode: int = MenuMode.IDLE
var _ally_index := 0
var _allies: Array[BattleUnitState] = []
var _intents: Array[BattleIntent] = []
var _awaiting_intent := false
var _target_kind := BattleTypes.IntentKind.ATTACK
var _target_skill: StringName = &""
var _target_item: StringName = &""
var _timeout_rng := RandomNumberGenerator.new()
var _built := false

signal phase_submitted(intents: Array)
signal _intent_ready(intent: BattleIntent)

var _hud_theme: Theme
var _command_panel: PanelContainer
var _title_label: Label
var _countdown_label: Label
var _ally_label: RichTextLabel
var _progress_label: Label
var _body: VBoxContainer
var _back_button: Button
var _order_panel: PanelContainer
var _order_title: Label
var _order_row: HBoxContainer
var _order_chips: Dictionary = {}
var _chip_normal: StyleBoxFlat
var _chip_active: StyleBoxFlat
var _log: BattleLog
var _speed_button: Button
var _skip_button: Button
var _flee_button: Button
var _badge_buttons: Array = []
var _selector := TargetSelector.new()

func setup(p_ctx: BattleContext) -> void:
	context = p_ctx
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeout_rng.seed = 0x5EED
	_build_theme()
	_build_ui()
	_selector.target_chosen.connect(_on_target_chosen)
	if context.sequencer != null and not context.sequencer.idle.is_connected(_on_sequencer_idle):
		context.sequencer.idle.connect(_on_sequencer_idle)
	_refresh_speed_label()
	set_process(true)
	log_system("战斗开始，等待指令…", MUTED)

# ---------------------------------------------------------------- public API

func is_collecting() -> bool:
	return _collecting

func get_time_left() -> float:
	return _time_left

func set_command_visible(value: bool) -> void:
	if _command_panel != null:
		_command_panel.visible = value
	if _flee_button != null:
		_flee_button.visible = value
	if not value:
		_exit_target_mode()
		_mode = MenuMode.IDLE

func refresh_all(_state: BattleState) -> void:
	if _collecting and _ally_index < _allies.size():
		_refresh_ally_info(_allies[_ally_index])

func set_story_active(active: bool) -> void:
	# 对白期间隐藏左下日志，避免透过电影黑边产生重影；播放控件保持可用。
	if _log != null:
		_log.visible = not active

func collect_intents(p_engine: BattleEngine, p_content: ContentDB) -> Array[BattleIntent]:
	last_intents = []
	_intents = []
	if p_engine == null or context == null:
		return _intents
	_engine = p_engine
	_content = p_content
	_allies = p_engine.state.living(BattleTypes.Side.ALLY)
	_ally_index = 0
	_timed_out = false
	_collecting = true
	_timeout_rng.seed = 0x5EED + p_engine.state.round * 977
	_time_left = command_time
	_update_countdown()
	_command_panel.visible = true
	_flee_button.visible = true
	_reset_order_bar()

	while _ally_index < _allies.size():
		var ally := _allies[_ally_index]
		if ally == null or not ally.is_alive():
			_ally_index += 1
			continue
		_show_root(ally)
		var intent := await _wait_intent()
		if _timed_out:
			for index in range(_ally_index, _allies.size()):
				_intents.append(_auto_intent(_allies[index]))
			break
		if intent == null:
			continue
		if intent.kind == BattleTypes.IntentKind.FLEE:
			_intents.clear()
			_intents.append(intent)
			break
		_intents.append(intent)
		_ally_index += 1

	_collecting = false
	_timed_out = false
	_exit_target_mode()
	_mode = MenuMode.IDLE
	_command_panel.visible = false
	_flee_button.visible = false
	last_intents = _intents.duplicate()
	phase_submitted.emit(last_intents)
	return _intents

# 供工具/截图脚本以程序化方式完成指令；与按钮走同一条路径。
func select_attack() -> void:
	if not _input_active() or _mode != MenuMode.ROOT:
		return
	_target_kind = BattleTypes.IntentKind.ATTACK
	_target_skill = &""
	_target_item = &""
	_begin_target(BattleTypes.Side.ENEMY, "攻击：选择敌方目标")

func select_skill(skill_id: StringName) -> bool:
	if not _input_active() or _mode != MenuMode.ROOT:
		return false
	var skill: SkillData = _get_content().get_skill(skill_id) if _get_content() != null else null
	var ally := _current_ally()
	if skill == null or ally == null or ally.mp < skill.mp_cost:
		return false
	_on_skill_pressed(skill_id)
	return true

func select_item(item_id: StringName) -> bool:
	if not _input_active() or _mode != MenuMode.ROOT:
		return false
	var item: ItemData = _get_content().get_item(item_id) if _get_content() != null else null
	if item == null or _get_engine() == null:
		return false
	if _get_engine().state.item_remaining(item.id) <= 0:
		return false
	_on_item_pressed(item_id)
	return true

func select_defend() -> void:
	if not _input_active():
		return
	var ally := _current_ally()
	if ally == null:
		return
	_submit(BattleIntent.make(ally.id, BattleTypes.IntentKind.DEFEND))

func select_flee() -> void:
	if not _input_active():
		return
	_submit(BattleIntent.make(&"party", BattleTypes.IntentKind.FLEE))

func choose_target(unit_id: StringName) -> bool:
	if not _input_active() or _mode != MenuMode.TARGET:
		return false
	return _selector.choose(unit_id)

func go_back() -> void:
	if not _collecting or not _input_active():
		return
	if _mode == MenuMode.ROOT:
		if _ally_index <= 0 or _intents.is_empty():
			return
		_ally_index -= 1
		_intents.pop_back()
		_show_root(_allies[_ally_index])
		return
	_exit_target_mode()
	_show_root(_current_ally())

func toggle_speed() -> void:
	if context == null or context.sequencer == null:
		return
	var speed := 1.0 if context.sequencer.playback_speed >= 1.5 else 2.0
	context.sequencer.playback_speed = speed
	_refresh_speed_label()

func _on_sequencer_idle() -> void:
	_refresh_speed_label()

func _refresh_speed_label() -> void:
	if _speed_button == null or context == null or context.sequencer == null:
		return
	var speed := context.sequencer.playback_speed
	_speed_button.text = "倍速 %dx" % int(speed)

# ---------------------------------------------------------------- 事件 → 日志 / 顺序条

func show_round(round_number: int, order: Array) -> void:
	_order_title.text = "第 %d 回合 · 出手顺序" % round_number
	for child in _order_row.get_children():
		_order_row.remove_child(child)
		child.queue_free()
	_order_chips.clear()
	for index in order.size():
		var unit_id := StringName(String(order[index]))
		_order_row.add_child(_make_order_chip(unit_id, index + 1))

func highlight_actor(unit_id: StringName) -> void:
	for key in _order_chips:
		var chip: PanelContainer = _order_chips[key]
		if chip == null or not is_instance_valid(chip):
			continue
		chip.add_theme_stylebox_override("panel", _chip_active if key == unit_id else _chip_normal)

func _reset_order_bar() -> void:
	if _order_title != null:
		_order_title.text = "下一回合 · 出手顺序待定"
	for key in _order_chips:
		var chip: PanelContainer = _order_chips[key]
		if chip == null or not is_instance_valid(chip):
			continue
		chip.add_theme_stylebox_override("panel", _chip_normal)

func log_event(event: BattleEvent) -> void:
	if _log == null or event == null:
		return
	var prefix := "[color=#7f8a96][R%d][/color] " % event.round
	var actor := _unit_name(event.source_id)
	var targets := _target_names(event.target_ids)
	match event.type:
		&"round_start":
			_log.append_line("[color=#c9ad6d]━━ 第 %d 回合 ━━[/color]" % event.round)
		&"action_start":
			var kind := String(event.data.get("kind", "attack"))
			match kind:
				"attack":
					_log.append_line(prefix + "[color=#dfe7ee]%s[/color] 攻击 [color=#ffb38a]%s[/color]" % [actor, targets])
				"skill":
					var skill_name := _skill_name(StringName(event.data.get("skill_id", "")))
					_log.append_line(prefix + "[color=#9ad0ff]%s[/color] 施放 [color=#ffd54a]%s[/color] → %s" % [actor, skill_name, targets])
				"defend":
					_log.append_line(prefix + "[color=#9ad0ff]%s[/color] 进入防御姿态" % actor)
				"item":
					pass
		&"damage", &"status_tick":
			var amount := int(event.data.get("amount", 0))
			var source_type := String(event.data.get("source_type", ""))
			if event.type == &"status_tick" or source_type == "status_tick":
				_log.append_line(prefix + "[color=#c78dff]%s[/color] 受到 [color=#b98cff]%d[/color] 点持续伤害" % [targets, amount])
			elif bool(event.data.get("crit", false)):
				_log.append_line(prefix + "[b][color=#ff5c4d]暴击！%s 受到 %d 点伤害[/color][/b]" % [targets, amount])
			else:
				_log.append_line(prefix + "[color=#ff9a4d]%s 受到 %d 点伤害[/color]" % [targets, amount])
		&"heal":
			_log.append_line(prefix + "[color=#6fe39a]%s 恢复 %d 点生命[/color]" % [targets, int(event.data.get("amount", 0))])
		&"status_apply", &"status_refresh", &"status_expire", &"status_resist":
			var status_id := StringName(event.data.get("status_id", ""))
			# 防御动作已由 action_start(kind=defend) 记录，跳过随后的状态行，避免三连重复。
			if status_id == &"defending" and (event.type == &"status_apply" or event.type == &"status_refresh"):
				return
			var status_name := _status_name(status_id)
			match event.type:
				&"status_apply":
					_log.append_line(prefix + "[color=#c78dff]%s 陷入 [b]%s[/b][/color]" % [targets, status_name])
				&"status_refresh":
					_log.append_line(prefix + "[color=#c78dff]%s 的 [b]%s[/b] 被刷新[/color]" % [targets, status_name])
				&"status_expire":
					_log.append_line(prefix + "[color=#8f8fa0]%s 的 %s 消失[/color]" % [targets, status_name])
				_:
					_log.append_line(prefix + "[color=#8f8fa0]%s 抵抗了 %s[/color]" % [targets, status_name])
		&"death":
			_log.append_line(prefix + "[color=#ff6b5e]%s 倒下了[/color]" % targets)
		&"defend":
			# 与 action_start(kind=defend) 重复，不单独记录。
			pass
		&"item_used":
			var item_name := _item_name(StringName(event.data.get("item_id", "")))
			_log.append_line(prefix + "[color=#8fe3b0]%s 对 %s 使用了 %s（剩余 %d）[/color]" % [actor, targets, item_name, int(event.data.get("remaining", 0))])
		&"flee_attempt":
			_log.append_line(prefix + "[color=#ffd54a]全队尝试逃跑（成功率 %d%%）[/color]" % roundi(float(event.data.get("chance", 0.0)) * 100.0))
		&"flee_result":
			if bool(event.data.get("success", false)):
				_log.append_line(prefix + "[color=#8fe3b0]逃跑成功！[/color]")
			else:
				_log.append_line(prefix + "[color=#ffb36b]逃跑失败，本回合无法行动[/color]")
		&"action_skipped":
			var reason := String(event.data.get("reason", ""))
			var reason_text := "无法行动"
			if reason == "dead":
				reason_text = "已阵亡"
			elif reason == "no_target":
				reason_text = "没有有效目标"
			elif not reason.is_empty():
				reason_text = _status_name(StringName(reason))
			_log.append_line(prefix + "[color=#8f8fa0]%s %s，跳过行动[/color]" % [actor, reason_text])
		&"intent_rejected":
			var rejected_reason := String(event.data.get("reason", ""))
			var hint := "目标无效"
			match rejected_reason:
				"mp":
					hint = "MP 不足"
				"item":
					hint = "道具已用尽"
				"target_dead":
					hint = "目标已阵亡"
				"missing":
					hint = "未下达指令"
			_log.append_line(prefix + "[color=#8f8fa0]%s 的指令无效（%s），转为防御[/color]" % [actor, hint])
		&"battle_end":
			var outcome := int(event.data.get("outcome", BattleTypes.Outcome.NONE))
			match outcome:
				BattleTypes.Outcome.VICTORY:
					_log.append_line("[b][color=#ffd54a]战斗结束：胜利！[/color][/b]")
				BattleTypes.Outcome.DEFEAT:
					_log.append_line("[b][color=#ff6b5e]战斗结束：战败…[/color][/b]")
				BattleTypes.Outcome.ESCAPED:
					_log.append_line("[b][color=#8fe3b0]战斗结束：逃跑成功[/color][/b]")
				_:
					_log.append_line("[color=#8f8fa0]战斗结束[/color]")

func log_system(text: String, color: Color = MUTED) -> void:
	if _log == null:
		return
	_log.append_line("[color=#%s]%s[/color]" % [color.to_html(false), text])

# ---------------------------------------------------------------- 指令阶段内部

func _wait_intent() -> BattleIntent:
	_awaiting_intent = true
	var result: BattleIntent = await _intent_ready
	_awaiting_intent = false
	return result

func _submit(intent: BattleIntent) -> void:
	if not _awaiting_intent:
		return
	_exit_target_mode()
	_mode = MenuMode.IDLE
	_awaiting_intent = false
	_intent_ready.emit(intent)

func _process(delta: float) -> void:
	_refresh_control_states()
	_refresh_badge_states()
	if not _collecting or _timed_out:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_countdown()
	if _time_left <= 0.0:
		_timed_out = true
		_exit_target_mode()
		_mode = MenuMode.IDLE
		if _awaiting_intent:
			_awaiting_intent = false
			_intent_ready.emit(null)

func _update_countdown() -> void:
	if _countdown_label == null:
		return
	var seconds := int(ceil(_time_left))
	_countdown_label.text = "倒计时 %ds" % seconds
	_countdown_label.add_theme_color_override("font_color", GOLD if seconds > 10 else Color(1.0, 0.42, 0.32))

func _auto_intent(ally: BattleUnitState) -> BattleIntent:
	if _engine == null or ally == null:
		return BattleIntent.make(&"", BattleTypes.IntentKind.DEFEND)
	var enemies := _engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return BattleIntent.make(ally.id, BattleTypes.IntentKind.DEFEND)
	var target := enemies[_timeout_rng.randi_range(0, enemies.size() - 1)]
	return BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [target.id])

func _input_active() -> bool:
	return _collecting and _awaiting_intent

func _current_ally() -> BattleUnitState:
	if _ally_index >= 0 and _ally_index < _allies.size():
		return _allies[_ally_index]
	return null

func _begin_target(side: int, prompt: String) -> void:
	_mode = MenuMode.TARGET
	_selector.begin(context, _engine.state, side)
	_clear_body()
	var hint := Label.new()
	hint.text = prompt
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", GOLD)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(470, 0)
	_body.add_child(hint)
	var keys := Label.new()
	keys.text = "1–4 / QWE 选择目标（点击目标也可）"
	keys.add_theme_font_size_override("font_size", 17)
	keys.add_theme_color_override("font_color", MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size = Vector2(470, 0)
	_body.add_child(keys)
	var mapping := Label.new()
	mapping.text = _target_key_map(side)
	mapping.add_theme_font_size_override("font_size", 16)
	mapping.add_theme_color_override("font_color", Color(0.82, 0.78, 0.66))
	mapping.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mapping.custom_minimum_size = Vector2(470, 0)
	_body.add_child(mapping)
	_add_back_button()

func _target_key_map(side: int) -> String:
	if _engine == null:
		return ""
	var key_names := ["1", "2", "3", "4"] if side == BattleTypes.Side.ENEMY else ["Q", "W", "E"]
	var units := _engine.state.living(side)
	units.sort_custom(func(a: BattleUnitState, b: BattleUnitState) -> bool: return a.slot < b.slot)
	var parts: Array[String] = []
	for unit in units:
		if unit.slot < 0 or unit.slot >= key_names.size():
			continue
		parts.append("%s %s" % [key_names[unit.slot], unit.data.display_name])
	return "目标键位：" + "　".join(parts)

func _exit_target_mode() -> void:
	_selector.end()

func _on_target_chosen(unit_id: StringName) -> void:
	if _mode != MenuMode.TARGET or not _awaiting_intent:
		return
	var ally := _current_ally()
	if ally == null:
		return
	_submit(BattleIntent.make(ally.id, _target_kind, [unit_id], _target_skill, _target_item))

func _on_skill_pressed(skill_id: StringName) -> void:
	if not _input_active() or (_mode != MenuMode.ROOT and _mode != MenuMode.SKILLS):
		return
	var ally := _current_ally()
	var skill: SkillData = _get_content().get_skill(skill_id) if _get_content() != null else null
	if ally == null or skill == null or ally.mp < skill.mp_cost:
		return
	_target_kind = BattleTypes.IntentKind.SKILL
	_target_skill = skill.id
	_target_item = &""
	if skill.target_type == SkillData.TargetType.SELF:
		_submit(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [], skill.id))
		return
	var side := BattleTypes.Side.ENEMY
	if skill.target_type == SkillData.TargetType.SINGLE_ALLY or skill.target_type == SkillData.TargetType.ALL_ALLIES:
		side = BattleTypes.Side.ALLY
	_begin_target(side, "法术 · %s：选择目标" % skill.display_name)

func _on_item_pressed(item_id: StringName) -> void:
	if not _input_active() or (_mode != MenuMode.ROOT and _mode != MenuMode.ITEMS):
		return
	var item: ItemData = _get_content().get_item(item_id) if _get_content() != null else null
	if item == null or _get_engine() == null or _get_engine().state.item_remaining(item.id) <= 0:
		return
	_target_kind = BattleTypes.IntentKind.ITEM
	_target_skill = &""
	_target_item = item.id
	_begin_target(BattleTypes.Side.ALLY, "道具 · %s：选择我方目标" % item.display_name)

func _on_flee_pressed() -> void:
	select_flee()

func _on_speed_pressed() -> void:
	toggle_speed()

func _on_skip_pressed() -> void:
	if context == null or context.sequencer == null or not context.sequencer.is_playing():
		return
	log_system("跳过本回合", MUTED)
	await context.sequencer.skip_all()
	if context.session != null and context.session.engine != null:
		context.apply_snapshot(context.session.engine.state)

func _refresh_control_states() -> void:
	if _skip_button != null:
		_skip_button.disabled = _collecting or context == null or context.sequencer == null or not context.sequencer.is_playing()
	if _flee_button != null:
		_flee_button.disabled = not _input_active() or _mode != MenuMode.ROOT

func _refresh_badge_states() -> void:
	var alive: Array = []
	for pair in _badge_buttons:
		var button = pair[0]
		var badge = pair[1]
		if not is_instance_valid(button) or not is_instance_valid(badge):
			continue
		badge.modulate = Color(0.55, 0.52, 0.5, 0.65) if button.disabled else Color.WHITE
		alive.append(pair)
	_badge_buttons = alive

func _unhandled_input(event: InputEvent) -> void:
	if not _collecting or not _input_active():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		go_back()
		get_viewport().set_input_as_handled()
		return
	if _mode != MenuMode.TARGET:
		return
	if _selector.side() == BattleTypes.Side.ENEMY:
		if key >= KEY_1 and key <= KEY_4:
			if _selector.choose_slot(key - KEY_1):
				get_viewport().set_input_as_handled()
	elif _selector.side() == BattleTypes.Side.ALLY:
		var slot := -1
		match key:
			KEY_Q:
				slot = 0
			KEY_W:
				slot = 1
			KEY_E:
				slot = 2
		if slot >= 0 and _selector.choose_slot(slot):
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- 面板构建

func _build_theme() -> void:
	_hud_theme = Theme.new()
	_hud_theme.default_font = FontUtil.cjk_font()
	_hud_theme.default_font_size = 20
	theme = _hud_theme

func _make_panel_style() -> StyleBoxFlat:
	return UiStyle.panel_style(12, Vector2i(16, 12))

func _make_button_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	return UiStyle.button_style(bg, border, width, 9)

func _style_button(button: Button, danger := false) -> Button:
	return UiStyle.apply_button(button, danger, 22)

func _new_button(text: String, danger := false, badge := "", command_id := "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, danger)
	if not command_id.is_empty():
		var icon := VisualCatalog.command_icon(StringName(command_id))
		if icon != null:
			button.icon = icon
			# expand_icon=true 让按钮最小尺寸不含图标原始像素，避免 512px SVG 把面板撑开；
			# icon_max_width 再把绘制尺寸钳到 26px。
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 26)
			button.add_theme_constant_override("h_separation", 10)
		elif not badge.is_empty():
			var badge_node := UiStyle.attach_button_badge(button, badge)
			if badge_node != null:
				_badge_buttons.append([button, badge_node])
	button.pressed.connect(_play_click)
	return button

func _play_click() -> void:
	if context != null:
		context.play_sfx(&"click")

func _build_ui() -> void:
	_build_order_panel()
	_build_playback_panel()
	_build_command_panel()
	_build_flee_button()
	_build_log_panel()

func _build_order_panel() -> void:
	_order_panel = PanelContainer.new()
	_order_panel.name = "TurnOrderBar"
	_order_panel.position = Vector2(24, 164)
	_order_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_order_panel)
	UiStyle.attach_inner_border(_order_panel, 9)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_order_panel.add_child(box)

	_order_title = Label.new()
	_order_title.text = "出手顺序 · 待命"
	_order_title.add_theme_font_size_override("font_size", 18)
	_order_title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.5))
	box.add_child(_order_title)

	_order_row = HBoxContainer.new()
	_order_row.add_theme_constant_override("separation", 6)
	box.add_child(_order_row)

	_chip_normal = StyleBoxFlat.new()
	_chip_normal.bg_color = Color(0.05, 0.05, 0.07, 0.5)
	_chip_normal.border_color = Color(1.0, 0.9, 0.55, 0.18)
	_chip_normal.set_border_width_all(1)
	_chip_normal.set_corner_radius_all(6)
	_chip_normal.content_margin_left = 8
	_chip_normal.content_margin_right = 8
	_chip_normal.content_margin_top = 3
	_chip_normal.content_margin_bottom = 3

	_chip_active = _chip_normal.duplicate() as StyleBoxFlat
	_chip_active.bg_color = Color(0.48, 0.34, 0.12, 0.95)
	_chip_active.border_color = GOLD
	_chip_active.set_border_width_all(2)

	var waiting := Label.new()
	waiting.text = "待命中"
	waiting.add_theme_font_size_override("font_size", 16)
	waiting.add_theme_color_override("font_color", MUTED)
	_order_row.add_child(waiting)

func _build_playback_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "PlaybackControls"
	panel.position = Vector2(1512, 24)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)
	UiStyle.attach_inner_border(panel, 9)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	_speed_button = _new_button("倍速 1x")
	_speed_button.custom_minimum_size = Vector2(132, 44)
	_speed_button.pressed.connect(_on_speed_pressed)
	row.add_child(_speed_button)

	_skip_button = _new_button("跳过本回合")
	_skip_button.custom_minimum_size = Vector2(190, 44)
	_skip_button.pressed.connect(_on_skip_pressed)
	row.add_child(_skip_button)

func _build_command_panel() -> void:
	_command_panel = PanelContainer.new()
	_command_panel.name = "CommandPanel"
	_command_panel.position = Vector2(1368, 612)
	_command_panel.custom_minimum_size = Vector2(528, 0)
	_command_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_command_panel.visible = false
	add_child(_command_panel)
	UiStyle.attach_inner_border(_command_panel, 9)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_command_panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "◆ 指令阶段"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_row.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	_countdown_label = Label.new()
	_countdown_label.text = "倒计时 25s"
	_countdown_label.add_theme_font_size_override("font_size", 22)
	_countdown_label.add_theme_color_override("font_color", GOLD)
	title_row.add_child(_countdown_label)

	_ally_label = RichTextLabel.new()
	_ally_label.bbcode_enabled = true
	_ally_label.fit_content = true
	_ally_label.scroll_active = false
	_ally_label.selection_enabled = false
	_ally_label.custom_minimum_size = Vector2(0, 30)
	_ally_label.add_theme_font_size_override("normal_font_size", 20)
	_ally_label.add_theme_font_size_override("bold_font_size", 20)
	box.add_child(_ally_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 17)
	_progress_label.add_theme_color_override("font_color", MUTED)
	box.add_child(_progress_label)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.76, 0.58, 0.28, 0.35))
	box.add_child(separator)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	box.add_child(_body)

func _build_flee_button() -> void:
	# 规格 6.4：逃跑是独立的整队按钮，不放在指令面板内。
	_flee_button = _new_button("逃跑", true, "逃", "flee")
	_flee_button.name = "PartyFleeButton"
	_flee_button.position = Vector2(1580, 552)
	_flee_button.custom_minimum_size = Vector2(180, 46)
	_flee_button.size = Vector2(180, 46)
	_flee_button.tooltip_text = "全队逃跑（丢弃已下指令）"
	_flee_button.visible = false
	_flee_button.pressed.connect(_on_flee_pressed)
	add_child(_flee_button)

func _build_log_panel() -> void:
	_log = BattleLog.new()
	_log.name = "BattleLog"
	_log.position = Vector2(20, 820)
	_log.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_log)

func _make_order_chip(unit_id: StringName, number: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _chip_normal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)

	var index_label := Label.new()
	index_label.text = "%d." % number
	index_label.add_theme_font_size_override("font_size", 14)
	index_label.add_theme_color_override("font_color", MUTED)
	row.add_child(index_label)

	var unit := _unit_state(unit_id)
	var team_dot := Label.new()
	team_dot.text = "●"
	team_dot.add_theme_font_size_override("font_size", 10)
	var team_color := ENEMY_COLOR
	if unit != null and unit.side == BattleTypes.Side.ALLY:
		team_color = ALLY_COLOR
	team_dot.add_theme_color_override("font_color", team_color)
	row.add_child(team_dot)

	var name_label := Label.new()
	name_label.text = unit.data.display_name if unit != null else String(unit_id)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", ENEMY_COLOR)
	if unit != null and unit.side == BattleTypes.Side.ALLY:
		name_label.add_theme_color_override("font_color", ALLY_COLOR)
	row.add_child(name_label)

	_order_chips[unit_id] = chip
	return chip

func _clear_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _add_back_button() -> void:
	var back := _new_button("返回")
	back.pressed.connect(go_back)
	_body.add_child(back)

func _show_root(ally: BattleUnitState) -> void:
	if ally == null:
		return
	_mode = MenuMode.ROOT
	_clear_body()
	_refresh_ally_info(ally)
	_progress_label.text = "第 %d / %d 名角色" % [_ally_index + 1, _allies.size()]

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)

	var attack := _new_button("攻击", false, "攻", "attack")
	attack.pressed.connect(select_attack)
	grid.add_child(attack)

	var skills := _new_button("法术", false, "法", "skill")
	skills.pressed.connect(_show_skills.bind(ally))
	grid.add_child(skills)

	var items := _new_button("道具", false, "药", "item")
	items.pressed.connect(_show_items.bind(ally))
	grid.add_child(items)

	var defend := _new_button("防御", false, "守", "defend")
	defend.pressed.connect(select_defend)
	grid.add_child(defend)

	_back_button = _new_button("返回")
	_back_button.disabled = _ally_index <= 0
	_back_button.pressed.connect(go_back)
	_body.add_child(_back_button)

func _show_skills(ally: BattleUnitState) -> void:
	if not _input_active() or ally == null:
		return
	_mode = MenuMode.SKILLS
	_clear_body()
	_refresh_ally_info(ally)
	_progress_label.text = "第 %d / %d 名角色 · 选择法术" % [_ally_index + 1, _allies.size()]

	var content := _get_content()
	var found := false
	if content != null:
		for skill_id in ally.data.skills:
			var skill := content.get_skill(skill_id)
			if skill == null:
				continue
			found = true
			var button := _new_button("%s    %d MP" % [skill.display_name, skill.mp_cost])
			button.disabled = ally.mp < skill.mp_cost
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(_on_skill_pressed.bind(skill.id))
			_body.add_child(button)
	if not found:
		var empty := Label.new()
		empty.text = "该角色没有可用法术"
		empty.add_theme_font_size_override("font_size", 19)
		empty.add_theme_color_override("font_color", MUTED)
		_body.add_child(empty)
	_add_back_button()

func _show_items(ally: BattleUnitState) -> void:
	if not _input_active() or ally == null:
		return
	_mode = MenuMode.ITEMS
	_clear_body()
	_refresh_ally_info(ally)
	_progress_label.text = "第 %d / %d 名角色 · 选择道具" % [_ally_index + 1, _allies.size()]

	var content := _get_content()
	var engine := _get_engine()
	if content != null and engine != null:
		var item_ids: Array = content.items.keys()
		item_ids.sort()
		for item_id in item_ids:
			var item := content.get_item(StringName(item_id))
			if item == null:
				continue
			var remaining := engine.state.item_remaining(item.id)
			var button := _new_button("%s    ×%d" % [item.display_name, remaining])
			button.disabled = remaining <= 0
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(_on_item_pressed.bind(item.id))
			_body.add_child(button)
	_add_back_button()

func _refresh_ally_info(ally: BattleUnitState) -> void:
	if ally == null:
		return
	_ally_label.text = "[color=#9ad0ff]%s[/color]   [color=#8fe39a]HP %d/%d[/color]   [color=#8fb9ff]MP %d/%d[/color]" % [
		ally.data.display_name, ally.hp, ally.data.max_hp, ally.mp, ally.data.max_mp,
	]

# ---------------------------------------------------------------- 查询辅助

func _get_engine() -> BattleEngine:
	if _engine != null:
		return _engine
	if context != null and context.session != null:
		return (context.session as BattleSession).engine
	return null

func _get_content() -> ContentDB:
	if _content != null:
		return _content
	if context != null and context.session != null:
		return (context.session as BattleSession).content
	return null

func _unit_state(unit_id: StringName) -> BattleUnitState:
	var engine := _get_engine()
	if engine == null:
		return null
	return engine.state.get_unit(unit_id)

func _unit_name(unit_id: StringName) -> String:
	if unit_id == &"party":
		return "全队"
	if String(unit_id).is_empty():
		return "系统"
	var unit := _unit_state(unit_id)
	return unit.data.display_name if unit != null else String(unit_id)

func _target_names(target_ids: Array[StringName]) -> String:
	var names: Array[String] = []
	for target_id in target_ids:
		names.append(_unit_name(target_id))
	if names.is_empty():
		return "—"
	return "、".join(names)

func _skill_name(skill_id: StringName) -> String:
	var content := _get_content()
	if content != null:
		var skill := content.get_skill(skill_id)
		if skill != null:
			return skill.display_name
	return String(skill_id)

func _status_name(status_id: StringName) -> String:
	var content := _get_content()
	if content != null:
		var status := content.get_status(status_id)
		if status != null:
			return status.display_name
	return String(status_id)

func _item_name(item_id: StringName) -> String:
	var content := _get_content()
	if content != null:
		var item := content.get_item(item_id)
		if item != null:
			return item.display_name
	return String(item_id)

# ---------------------------------------------------------------- 剧情 beat

func play_beat(beat: Dictionary) -> void:
	if context == null:
		return
	var lines: Array = beat.get("lines", [])
	if String(beat.get("kind", "")) == "dialogue":
		for line in lines:
			log_system(String(line), Color(0.86, 0.88, 0.95))
		if context.dialogue != null:
			await context.dialogue.play_lines(lines)
		else:
			for line in lines:
				await context.wait(0.45)
	else:
		await context.wait(0.2)
