class_name ConfirmDialog
extends Control

signal confirmed
signal cancelled

var _item: Dictionary = {}
var _dim: ColorRect
var _card: Control
var _bg: GradientRect
var _icon: TextureRect
var _text: Label
var _btn_cancel: UIButton
var _btn_ok: UIButton
var _open := false
var _tween: Tween


func setup() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.015, 0.05, 0.08, 0.58)
	_dim.position = Vector2.ZERO
	_dim.size = Vector2(1280, 720)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var glow := ThemeKit.glow_texture_rect("glow", Color(0.35, 0.2, 0.12, 0.35))
	glow.position = Vector2(420 - 40, 242 - 40)
	glow.size = Vector2(520, 316)
	add_child(glow)

	_card = Control.new()
	_card.position = Vector2(420, 242)
	_card.size = Vector2(440, 236)
	_card.pivot_offset = _card.size * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_bg = GradientRect.new()
	_bg.setup(Vector2(440, 236), 14.0, Color(0.07, 0.175, 0.24, 0.98), Color(0.03, 0.09, 0.14, 0.99),
		Color(0.93, 0.78, 0.46, 0.98), 2.2, 0.0)
	_card.add_child(_bg)
	ThemeKit.make_label(_card, "丢弃确认", 23, ThemeKit.GOLD_BRIGHT, Vector2(22, 14), Vector2(300, 32),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.title_font(), 4, Color(0.03, 0.08, 0.12, 0.9))
	var line := GradientRect.new()
	line.position = Vector2(22, 52)
	line.setup(Vector2(396, 1.5), 0.7, Color(0.93, 0.78, 0.46, 0.55), Color(0.93, 0.78, 0.46, 0.2),
		Color.TRANSPARENT, 0.0, 0.0)
	_card.add_child(line)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(24, 70)
	_icon.size = Vector2(70, 70)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_icon)
	_text = ThemeKit.make_label(_card, "", 15, Color("e2f0f8"), Vector2(110, 68), Vector2(306, 60),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	ThemeKit.make_label(_card, "丢弃后无法找回，请确认物品与数量。", 11, Color(0.97, 0.71, 0.65, 0.9),
		Vector2(110, 132), Vector2(306, 24), HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1,
		Color(0.02, 0.06, 0.1, 0.7))
	_btn_cancel = UIButton.new()
	_btn_cancel.setup("取消", UIButton.Kind.SLATE, Vector2(150, 40), 16)
	_btn_cancel.position = Vector2(24, 176)
	_card.add_child(_btn_cancel)
	_btn_cancel.pressed.connect(func() -> void: cancel())
	_btn_ok = UIButton.new()
	_btn_ok.setup("确定丢弃", UIButton.Kind.DANGER, Vector2(150, 40), 16)
	_btn_ok.position = Vector2(266, 176)
	_card.add_child(_btn_ok)
	_btn_ok.pressed.connect(func() -> void: confirm())


func show_for(item: Dictionary) -> void:
	_item = item
	_icon.texture = ThemeKit.icon(str(item.get("icon", "pouch")))
	_text.text = "确定丢弃「%s」×%d 吗？" % [str(item.get("name", "")), int(item.get("stack", 1))]
	visible = true
	_open = true
	modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.15)


func is_open() -> bool:
	return _open


func item() -> Dictionary:
	return _item


func confirm() -> void:
	if not _open:
		return
	_close()
	confirmed.emit()


func cancel() -> void:
	if not _open:
		return
	_close()
	cancelled.emit()


func _close() -> void:
	_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_property(_card, "scale", Vector2(0.96, 0.96), 0.12)
	_tween.chain().tween_callback(func() -> void: visible = false)
