class_name ItemTooltip
extends Control

const W := 292.0
const H := 82.0

var _bg: GradientRect
var _name: Label
var _meta: Label
var _hint: Label
var _tween: Tween
var _showing := false


func setup() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_bg = GradientRect.new()
	_bg.position = Vector2.ZERO
	_bg.setup(Vector2(W, H), 10.0, Color(0.055, 0.15, 0.22, 0.96), Color(0.03, 0.09, 0.14, 0.98),
		Color(0.91, 0.77, 0.46, 0.95), 1.6, 0.0)
	add_child(_bg)
	_name = ThemeKit.make_label(self, "", 18, ThemeKit.GOLD_BRIGHT, Vector2(14, 8), Vector2(W - 28, 24),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 3, Color(0.03, 0.08, 0.12, 0.9))
	_meta = ThemeKit.make_label(self, "", 12, Color("b9d7e5"), Vector2(14, 33), Vector2(W - 28, 18),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(0.02, 0.06, 0.1, 0.85))
	_hint = ThemeKit.make_label(self, "", 10, Color(0.86, 0.94, 0.98, 0.6), Vector2(14, 56), Vector2(W - 28, 16),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1, Color(0.02, 0.06, 0.1, 0.7))


func show_for(item: Dictionary, screen_pos: Vector2, equipped: bool = false) -> void:
	if item.is_empty():
		return
	var q := int(item.get("quality", 0))
	_name.text = str(item.get("name", ""))
	_name.label_settings.font_color = ThemeKit.quality_color(q).lightened(0.16)
	if equipped:
		_meta.text = "已装备 · %d级 · %s" % [int(item.get("level", 1)), ThemeKit.quality_name(q)]
		_hint.text = "单击查看装备详情"
	else:
		var stack := int(item.get("stack", 1))
		var stack_text := "  ×%d" % stack if stack > 1 else ""
		_meta.text = "%s · %s%s" % [ThemeKit.quality_name(q), str(item.get("category", "")), stack_text]
		_hint.text = "单击查看详情 · 双击使用" if item.has("use") else "单击查看详情"
	position = ThemeKit.clamp_tooltip(screen_pos, Vector2(W, H), Vector2(1280, 720))
	visible = true
	_showing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)


func current_name() -> String:
	return _name.text if _name != null else ""


func hide_tooltip() -> void:
	if not _showing:
		return
	_showing = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.10)
	_tween.tween_callback(func() -> void: visible = false)
