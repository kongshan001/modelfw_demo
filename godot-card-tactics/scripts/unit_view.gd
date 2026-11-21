class_name UnitView
extends Node2D

const AtlasAnimScript = preload("res://scripts/atlas_anim.gd")
const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 棋盘上的单位视图：切帧精灵 + 攻击/受击/移动动画 + 攻血徽章。
# 规则数据仍以 BattleCore 为准，这里只做显示。

const SPRITE_SCALE := 1.22

var unit_uid := -1
var owner_id := 0
var is_general := false

var sprite: AtlasAnimScript
var _hp_label: Label
var _atk_label: Label
var _keyword_label: Label
var _hp_badge: Panel
var _atk_badge: Panel
var _tween: Tween


func configure(unit: Dictionary) -> void:
	unit_uid = int(unit["uid"])
	owner_id = int(unit["owner"])
	is_general = bool(unit["is_general"])
	z_index = 10 + int(unit["y"])

	sprite = AtlasAnimScript.new()
	sprite.position = Vector2(0, -2)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)
	if not sprite.load_sheet(str(unit.get("sprite", "")), "units"):
		# 缺图回退：画一个阵营色的圆，不影响规则。
		var fallback := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * 24.0)
		fallback.polygon = pts
		fallback.color = Color("#e8c56a") if owner_id == BattleCoreScript.PLAYER else Color("#c86a86")
		add_child(fallback)
	else:
		sprite.play("idle", 8.0, true)
		sprite.set_anim_phase(unit_uid * 3)

	_atk_badge = _make_badge(Vector2(-31, 17), Color("#8d5a24"), Color("#ffd98e"))
	_atk_label = _make_badge_label(_atk_badge, str(unit.get("atk", 0)))
	_hp_badge = _make_badge(Vector2(11, 17), Color("#2f6346"), Color("#b9f0c0"))
	_hp_label = _make_badge_label(_hp_badge, str(unit.get("hp", 0)))

	_keyword_label = Label.new()
	_keyword_label.position = Vector2(15, -46)
	_keyword_label.size = Vector2(35, 16)
	_keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keyword_label.add_theme_font_size_override("font_size", 9)
	_keyword_label.add_theme_constant_override("outline_size", 3)
	_keyword_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	_keyword_label.add_theme_color_override("font_color", Color("#ffe6a6"))
	add_child(_keyword_label)
	var marks: Array[String] = []
	if unit.get("provoke", false):
		marks.append("嘲")
	if unit.get("ranged", false):
		marks.append("远")
	if unit.get("rush", false):
		marks.append("疾")
	_keyword_label.text = "".join(marks)

	if is_general:
		sprite.scale = Vector2(SPRITE_SCALE * 1.1, SPRITE_SCALE * 1.1)
		_keyword_label.text = "将"


func set_stats(unit: Dictionary) -> void:
	if _hp_label:
		_hp_label.text = str(unit["hp"])
	if _atk_label:
		_atk_label.text = str(unit["atk"])
	z_index = 10 + int(unit["y"])
	if unit.get("hp", 1) < unit.get("max_hp", 1):
		_hp_badge.add_theme_stylebox_override("panel", _badge_style(Color("#7b3a34"), Color("#ffb0a0")))
	else:
		_hp_badge.add_theme_stylebox_override("panel", _badge_style(Color("#2f6346"), Color("#b9f0c0")))


func set_facing_toward(x: float) -> void:
	if sprite:
		sprite.flip_h = x < global_position.x


func play_idle() -> void:
	if sprite:
		sprite.play("idle", 8.0, true)


func play_run() -> void:
	if sprite:
		sprite.play("run", 13.0, true)


func play_attack() -> void:
	if sprite:
		_ensure_finish_hook()
		sprite.play("attack", 17.0, false)


func play_hit() -> void:
	if sprite:
		_ensure_finish_hook()
		sprite.play("hit", 15.0, false)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.0, 0.55, 0.5), 0.06)
		tw.tween_property(self, "modulate", Color.WHITE, 0.16)


func _ensure_finish_hook() -> void:
	if sprite and not sprite.finished.is_connected(_on_anim_finished):
		sprite.finished.connect(_on_anim_finished)


func _on_anim_finished(_anim: String) -> void:
	play_idle()


func lunge_toward(target: Vector2) -> void:
	var dir := (target - position).normalized()
	var start := position
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", start + dir * 13.0, 0.09)
	_tween.tween_property(self, "position", start, 0.12)


func move_to(target: Vector2, duration := 0.24) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	play_run()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration)
	_tween.finished.connect(play_idle)


func _make_badge(pos: Vector2, bg: Color, border: Color) -> Panel:
	var badge := Panel.new()
	badge.position = pos
	badge.size = Vector2(21, 21)
	badge.add_theme_stylebox_override("panel", _badge_style(bg, border))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	return badge


func _make_badge_label(badge: Panel, text: String) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#fff5df"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return label


func _badge_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	style.border_color = border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	return style


func _draw() -> void:
	draw_set_transform(Vector2(0, 31), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 28.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
