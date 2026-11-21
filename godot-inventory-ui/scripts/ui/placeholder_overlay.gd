class_name PlaceholderOverlay
extends Control

signal closed

var _dim: ColorRect
var _card: Control
var _icon: TextureRect
var _glow: TextureRect
var _eyebrow: Label
var _title: Label
var _body: Label
var _tag: Label
var _btn: UIButton
var _close: UIButton
var _open := false
var _tween: Tween


func setup() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.04, 0.07, 0.62)
	_dim.size = Vector2(1280, 720)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_card = Control.new()
	_card.position = Vector2(320, 170)
	_card.size = Vector2(640, 380)
	_card.pivot_offset = _card.size * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var bg := GradientRect.new()
	bg.setup(Vector2(640, 380), 16.0, Color(0.06, 0.16, 0.225, 0.98), Color(0.025, 0.075, 0.12, 0.99),
		Color(0.92, 0.78, 0.47, 0.98), 2.2, 0.0)
	_card.add_child(bg)
	var glow := ThemeKit.glow_texture_rect("glow", Color(0.5, 0.9, 1.0, 0.20))
	glow.position = Vector2(30, 60)
	glow.size = Vector2(230, 230)
	_card.add_child(glow)
	var icon_frame := GradientRect.new()
	icon_frame.position = Vector2(52, 92)
	icon_frame.setup(Vector2(170, 170), 18.0, ThemeKit.CELL_TOP, ThemeKit.CELL_BOTTOM,
		ThemeKit.quality_color(2), 3.0, 0.5)
	_card.add_child(icon_frame)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(64, 104)
	_icon.size = Vector2(146, 146)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_icon)
	_eyebrow = ThemeKit.make_label(_card, "", 11, Color("f0d69b"), Vector2(260, 70), Vector2(330, 22),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.8))
	_title = ThemeKit.make_label(_card, "", 34, ThemeKit.GOLD_BRIGHT, Vector2(258, 90), Vector2(330, 52),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.title_font(), 4, Color(0.03, 0.08, 0.12, 0.9))
	var line := GradientRect.new()
	line.position = Vector2(260, 148)
	line.setup(Vector2(320, 1.5), 0.7, Color(0.92, 0.78, 0.47, 0.6), Color(0.92, 0.78, 0.47, 0.15),
		Color.TRANSPARENT, 0.0, 0.0)
	_card.add_child(line)
	_body = ThemeKit.make_label(_card, "", 15, Color("d8e9f2"), Vector2(260, 164), Vector2(330, 120),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.7))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tag = ThemeKit.make_label(_card, "", 11, Color(0.84, 0.93, 0.97, 0.6), Vector2(52, 300), Vector2(360, 20),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.7))
	_btn = UIButton.new()
	_btn.setup("返回背包", UIButton.Kind.GOLD, Vector2(150, 42), 17)
	_btn.position = Vector2(438, 296)
	_card.add_child(_btn)
	_btn.pressed.connect(func() -> void: hide_overlay())
	_close = UIButton.new()
	_close.setup("✕", UIButton.Kind.GHOST, Vector2(30, 30), 14)
	_close.position = Vector2(596, 12)
	_card.add_child(_close)
	_close.pressed.connect(func() -> void: hide_overlay())


func show_kind(kind: String) -> void:
	visible = true
	_open = true
	match kind:
		"alchemy":
			_icon.texture = ThemeKit.icon("potion_red")
			_eyebrow.text = "洞府 · 丹房"
			_title.text = "丹 房"
			_body.text = "炉火照天地，红星乱紫烟。\n\n炼丹玩法为占位演示；本次交付聚焦物品背包的视觉、信息层级与交互链路。"
			_tag.text = "占位界面 · 炼丹"
		"codex":
			_icon.texture = ThemeKit.icon("scroll")
			_eyebrow.text = "山河 · 风物"
			_title.text = "九 州 谱"
			_body.text = "山河为卷，风物为注。\n\n九州谱收集玩法为占位演示；此处展示右侧竖排导航的可点击切换。"
			_tag.text = "占位界面 · 九州谱"
		"compendium":
			_icon.texture = ThemeKit.icon("tome")
			_eyebrow.text = "青丘 · 灵狐"
			_title.text = "灵 狐 图 鉴"
			_body.text = "云璃，青丘一脉的灵狐少女。\n\n图鉴为占位界面，用于演示人物环右上「图鉴」按钮的交互。"
			_tag.text = "占位界面 · 图鉴"
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_card.scale = Vector2(0.97, 0.97)
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.16)


func hide_overlay() -> void:
	if not _open:
		return
	_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.13)
	_tween.tween_property(_card, "scale", Vector2(0.97, 0.97), 0.13)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())


func is_open() -> bool:
	return _open
