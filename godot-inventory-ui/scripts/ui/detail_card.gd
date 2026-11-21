class_name DetailCard
extends Control

signal use_requested(item)
signal discard_requested(item)
signal sell_requested(item)
signal closed

const CARD_SIZE := Vector2(290, 440)
const BASE_POS := Vector2(898, 132)

var _state: InventoryState
var _item: Dictionary = {}
var _mode := "bag"
var _bg: GradientRect
var _inner: GradientRect
var _name: Label
var _quality: Label
var _icon_frame: GradientRect
var _icon: TextureRect
var _type: Label
var _level: Label
var _amount: Label
var _bind: Label
var _desc: Label
var _stats: Label
var _tags: Label
var _reason: Label
var _btn_use: UIButton
var _btn_discard: UIButton
var _btn_sell: UIButton
var _close: UIButton
var _tween: Tween
var _showing := false


func setup(state: InventoryState) -> void:
	_state = state
	size = CARD_SIZE
	position = BASE_POS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_bg = GradientRect.new()
	_bg.setup(CARD_SIZE, 14.0, Color(0.055, 0.15, 0.215, 0.965), Color(0.025, 0.075, 0.12, 0.975),
		Color(0.91, 0.77, 0.46, 0.95), 2.0, 0.0)
	add_child(_bg)
	_inner = GradientRect.new()
	_inner.setup(CARD_SIZE - Vector2(10, 10), 11.0, Color(0, 0, 0, 0), Color(0, 0, 0, 0),
		Color(0.94, 0.98, 1.0, 0.20), 1.0, 0.0)
	_inner.position = Vector2(5, 5)
	add_child(_inner)

	_name = ThemeKit.make_label(self, "", 22, ThemeKit.GOLD_BRIGHT, Vector2(16, 10), Vector2(216, 30),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 3, Color(0.02, 0.06, 0.1, 0.9))
	_quality = ThemeKit.make_label(self, "", 11, ThemeKit.TEXT_LIGHT, Vector2(18, 44), Vector2(110, 18),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_close = UIButton.new()
	_close.setup("✕", UIButton.Kind.GHOST, Vector2(26, 26), 13)
	_close.position = Vector2(252, 10)
	add_child(_close)
	_close.pressed.connect(func() -> void: close_card())

	_icon_frame = GradientRect.new()
	_icon_frame.position = Vector2(16, 70)
	_icon_frame.setup(Vector2(88, 88), 10.0, ThemeKit.CELL_TOP, ThemeKit.CELL_BOTTOM,
		ThemeKit.quality_color(0), 2.5, 0.5)
	add_child(_icon_frame)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(24, 78)
	_icon.size = Vector2(72, 72)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_type = ThemeKit.make_label(self, "", 13, Color("d2e6f1"), Vector2(116, 70), Vector2(158, 20),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_level = ThemeKit.make_label(self, "", 12, Color("a9c8d9"), Vector2(116, 92), Vector2(158, 18),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_amount = ThemeKit.make_label(self, "", 12, Color("f3d99b"), Vector2(116, 112), Vector2(158, 18),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_bind = ThemeKit.make_label(self, "", 11, Color("a9c8d9"), Vector2(116, 132), Vector2(158, 18),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))

	var divider := GradientRect.new()
	divider.position = Vector2(16, 168)
	divider.setup(Vector2(258, 1.5), 0.7, Color(0.91, 0.77, 0.46, 0.55), Color(0.91, 0.77, 0.46, 0.25),
		Color.TRANSPARENT, 0.0, 0.0)
	add_child(divider)

	_desc = ThemeKit.make_label(self, "", 13, Color("d5e7f1"), Vector2(16, 178), Vector2(258, 72),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.7))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_stats = ThemeKit.make_label(self, "", 13, Color("f2dca4"), Vector2(16, 254), Vector2(258, 48),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.7))
	_stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tags = ThemeKit.make_label(self, "", 10, Color("93b0c2"), Vector2(16, 306), Vector2(258, 18),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.6))
	_reason = ThemeKit.make_label(self, "", 10, Color("ffb3a6"), Vector2(16, 328), Vector2(258, 30),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.6))
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_btn_use = UIButton.new()
	_btn_use.setup("使用", UIButton.Kind.GOLD, Vector2(76, 38), 15)
	_btn_use.position = Vector2(16, 366)
	add_child(_btn_use)
	_btn_use.pressed.connect(func() -> void: use_requested.emit(_item))
	_btn_discard = UIButton.new()
	_btn_discard.setup("丢弃", UIButton.Kind.DANGER, Vector2(76, 38), 15)
	_btn_discard.position = Vector2(100, 366)
	add_child(_btn_discard)
	_btn_discard.pressed.connect(func() -> void: discard_requested.emit(_item))
	_btn_sell = UIButton.new()
	_btn_sell.setup("出售", UIButton.Kind.SLATE, Vector2(82, 38), 15)
	_btn_sell.position = Vector2(184, 366)
	add_child(_btn_sell)
	_btn_sell.pressed.connect(func() -> void: sell_requested.emit(_item))

	ThemeKit.make_label(self, "Esc 关闭背包 · 空格切换详情", 9, Color(0.8, 0.9, 0.96, 0.38),
		Vector2(16, 412), Vector2(258, 16), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.body_font(), 0)


func show_for(item: Dictionary, mode: String = "bag") -> void:
	if item.is_empty():
		return
	_item = item
	_mode = mode
	var q := int(item.get("quality", 0))
	_name.text = str(item.get("name", ""))
	_name.label_settings.font_color = ThemeKit.quality_color(q).lightened(0.18)
	_quality.text = ThemeKit.quality_name(q)
	_quality.label_settings.font_color = ThemeKit.quality_color(q).lightened(0.12)
	_icon.texture = ThemeKit.icon(str(item.get("icon", "pouch")))
	_icon_frame.setup(Vector2(88, 88), 10.0, ThemeKit.CELL_TOP, ThemeKit.CELL_BOTTOM,
		ThemeKit.quality_color(q), 2.5, 0.5)
	var cat := str(item.get("category", ""))
	if cat == "":
		cat = "装备" if mode == "equipped" else "杂项"
	_type.text = "%s · %s" % [ThemeKit.quality_name(q), cat]
	if cat == "装备" or mode == "equipped":
		_level.text = "%d 级" % int(item.get("level", 1))
	else:
		_level.text = "页签 · %s" % InventoryState.PAGE_NAMES[clampi(int(item.get("page", 1)) - 1, 0, 4)]
	var stack := int(item.get("stack", 1))
	_amount.text = "持有 ×%d" % stack if mode == "bag" else "已装备"
	_bind.text = "装备中" if mode == "equipped" else ("未绑定 · 可交易" if bool(item.get("bindable", true)) else "已绑定")
	_desc.text = str(item.get("desc", ""))
	var stats_lines: Array[String] = []
	for key in item.get("stats", {}).keys():
		stats_lines.append("%s  +%d" % [str(key), int(item["stats"][key])])
	if stats_lines.is_empty() and _state != null and _state.can_use(item):
		var preview := _state.apply_use_preview(item)
		if preview != "":
			stats_lines.append(preview)
	if mode == "equipped" and item.get("enchant", null) != null:
		stats_lines.append("附魔：%s" % str(item.get("enchant")))
	_stats.text = "\n".join(stats_lines) if not stats_lines.is_empty() else "—"
	var tag_bits: Array[String] = []
	if mode == "equipped":
		tag_bits.append("已装备 · %d级" % int(item.get("level", 1)))
		tag_bits.append("装备中 · 不可出售")
	else:
		tag_bits.append("未绑定 · 可交易" if bool(item.get("bindable", true)) else "已绑定")
		tag_bits.append("可出售 · %d 银两/件" % int(item.get("price", 0)) if bool(item.get("sellable", false)) else "不可出售")
	_tags.text = " · ".join(tag_bits)

	var reason := ""
	var use_ok := mode == "bag" and _state != null and _state.can_use(item)
	var discard_ok := mode == "bag" and _state != null and _state.can_discard(item)
	var sell_ok := mode == "bag" and _state != null and _state.can_sell(item)
	_btn_use.set_disabled(not use_ok)
	_btn_discard.set_disabled(not discard_ok)
	_btn_sell.set_disabled(not sell_ok)
	if mode == "equipped":
		reason = "已装备 · 请在装备栏中查看"
	elif not use_ok and not discard_ok and not sell_ok:
		reason = "任务物品 · 不可使用、丢弃或出售"
	elif not use_ok and cat == "消耗":
		reason = "该消耗品不可直接使用"
	elif not sell_ok and not bool(item.get("sellable", false)) and bool(item.get("bindable", true)):
		reason = "已认主 · 不可出售"
	_reason.text = reason

	visible = true
	_showing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	position = BASE_POS + Vector2(26, 0)
	scale = Vector2(0.985, 0.985)
	pivot_offset = Vector2(0, CARD_SIZE.y * 0.5)
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_tween.tween_property(self, "position", BASE_POS, 0.16)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16)


func close_card() -> void:
	if not _showing:
		return
	_showing = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_property(self, "position", BASE_POS + Vector2(20, 0), 0.12)
	_tween.chain().tween_callback(func() -> void: visible = false)
	closed.emit()


func is_showing() -> bool:
	return _showing and visible


func current_item() -> Dictionary:
	return _item


func current_mode() -> String:
	return _mode


func refresh() -> void:
	if _showing and not _item.is_empty():
		show_for(_item, _mode)
