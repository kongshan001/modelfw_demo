class_name UnitView
extends Node2D

const AtlasAnimScript = preload("res://scripts/atlas_anim.gd")
const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 棋盘上的单位视图：切帧精灵 + 攻击/受击/移动动画 + 攻血徽章。
# 规则数据仍以 BattleCore 为准，这里只做显示。
# T-019 美术整改：队伍色基座环、8 方向实色轮廓、徽章独立层、将军冠饰、
# 命中白闪 + 0.10s 红闪、20px 冲刺；同行 z 序按 x 稳定排序。

const SPRITE_SCALE := 1.22
const OUTLINE_SHADER := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.91, 0.77, 0.42, 0.65);
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	COLOR = vec4(outline_color.rgb, outline_color.a * src.a);
}
"""

const PLAYER_COLOR := Color("#e8c56a")
const ENEMY_COLOR := Color("#d4657a")
const PLAYER_RIM := Color("#f2d98a")
const ENEMY_RIM := Color("#f08a9c")
const DARK_RING := Color(0.04, 0.05, 0.07, 0.62)
# 三张 CC0 单位图整体过暗（评审实测 52% 像素 <1.5:1）；
# 仅对这三张做逐图上调，保留其余单位的原画明度结构。
const DARK_SPRITE_BOOST := {
	"f2_lanternfox": 1.55,
	"f2_onyxjaguar": 1.32,
	"f2_mage4winds": 1.45,
	"f2_sparrowhawk": 1.12,
}

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
var _hit_tween: Tween
var _outline: Array[Sprite2D] = []
var _outline_tex: Texture2D = null
var _team_color := PLAYER_COLOR
var _rim_color := PLAYER_RIM

static var _outline_shader: Shader
static var _outline_materials: Dictionary = {}
static var _badge_font: SystemFont


func configure(unit: Dictionary) -> void:
	unit_uid = int(unit["uid"])
	owner_id = int(unit["owner"])
	is_general = bool(unit["is_general"])
	# 同一行内按 x 稳定排序；徽章另用 +100 的相对 z，永远盖在所有精灵之上。
	z_index = 10 + int(unit["y"]) * 10 + int(unit["x"])
	_team_color = PLAYER_COLOR if owner_id == BattleCoreScript.PLAYER else ENEMY_COLOR
	_rim_color = PLAYER_RIM if owner_id == BattleCoreScript.PLAYER else ENEMY_RIM

	sprite = AtlasAnimScript.new()
	sprite.position = Vector2(0, -2)
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	# 轻微提亮（不改变色板结构）+ 三张过暗图的逐图补偿，让暗部单位从格面上浮出来。
	var boost := 1.10 * float(DARK_SPRITE_BOOST.get(str(unit.get("sprite", "")), 1.0))
	sprite.modulate = Color(boost, boost, boost, 1.0)
	if is_general:
		sprite.scale = Vector2(SPRITE_SCALE * 1.1, SPRITE_SCALE * 1.1)
	add_child(sprite)
	if not sprite.load_sheet(str(unit.get("sprite", "")), "units"):
		# 缺图回退：画一个阵营色的圆，不影响规则。
		var fallback := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * 24.0)
		fallback.polygon = pts
		fallback.color = _team_color
		add_child(fallback)
	else:
		_build_outline()
		sprite.play("idle", 8.0, true)
		sprite.set_anim_phase(unit_uid * 3)
		set_process(true)

	_atk_badge = _make_badge(Vector2(-33, 17), Color("#e9b45b"), Color("#fff0c4"), 22)
	_atk_label = _make_badge_label(_atk_badge, str(int(unit.get("atk", 0))), 12, Color("#2a1606"))
	var hp_size := 24 if is_general else 22
	_hp_badge = _make_badge(Vector2(11, 17), Color("#7fd39a"), Color("#d9ffe4"), hp_size)
	_hp_label = _make_badge_label(_hp_badge, str(int(unit.get("hp", 0))), 12, Color("#0a2013"))

	_keyword_label = Label.new()
	_keyword_label.position = Vector2(13, -51)
	_keyword_label.size = Vector2(38, 18)
	_keyword_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keyword_label.add_theme_font_size_override("font_size", 10)
	_keyword_label.add_theme_constant_override("outline_size", 3)
	_keyword_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	_keyword_label.add_theme_color_override("font_color", Color("#ffe6a6"))
	_keyword_label.z_index = 100
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
		_keyword_label.text = ""


func set_stats(unit: Dictionary) -> void:
	if _hp_label:
		_hp_label.text = str(int(unit["hp"]))
	if _atk_label:
		_atk_label.text = str(int(unit["atk"]))
	z_index = 10 + int(unit["y"]) * 10 + int(unit["x"])
	if unit.get("hp", 1) < unit.get("max_hp", 1):
		_hp_badge.add_theme_stylebox_override("panel", _badge_style(Color("#ef8b80"), Color("#ffd6cf")))
	else:
		_hp_badge.add_theme_stylebox_override("panel", _badge_style(Color("#7fd39a"), Color("#d9ffe4")))


func set_facing_toward(x: float) -> void:
	if sprite:
		sprite.flip_h = x < global_position.x
		for ol in _outline:
			ol.flip_h = sprite.flip_h


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
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		# 0.03s 白闪 → 0.10s 红闪 → 0.14s 恢复；命中帧从 2 帧延长到可辨认。
		_hit_tween = create_tween()
		_hit_tween.tween_property(self, "modulate", Color(1.55, 1.55, 1.55, 1.0), 0.03)
		_hit_tween.tween_property(self, "modulate", Color(1.0, 0.42, 0.38, 1.0), 0.10)
		_hit_tween.tween_property(self, "modulate", Color.WHITE, 0.14)


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
	_tween.tween_property(self, "position", start + dir * 20.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", start, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func move_to(target: Vector2, duration := 0.24) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	play_run()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration)
	_tween.finished.connect(play_idle)


func _process(_delta: float) -> void:
	if sprite == null or _outline.is_empty():
		return
	var tex := sprite.texture
	if tex == _outline_tex:
		return
	_outline_tex = tex
	for ol in _outline:
		ol.texture = tex
		ol.flip_h = sprite.flip_h


func _build_outline() -> void:
	if sprite == null:
		return
	# 评审 brief：2px 队伍色外轮廓（将军 3px）。4 方向偏移的实色剪影
	# 足以覆盖上下左右轮廓，同时把额外精灵控制在 4 个/单位（44 个总开销）。
	var radius := 3.0 if is_general else 2.0
	var mat := _outline_material(Color(_rim_color.r, _rim_color.g, _rim_color.b, 0.65))
	for i in 4:
		var angle := TAU * float(i) / 4.0
		var ol := Sprite2D.new()
		ol.position = sprite.position + Vector2(cos(angle), sin(angle)) * radius
		ol.scale = sprite.scale
		ol.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ol.material = mat
		ol.z_index = -1
		ol.flip_h = sprite.flip_h
		add_child(ol)
		move_child(ol, sprite.get_index())
		_outline.append(ol)


func _outline_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _outline_materials.has(key):
		return _outline_materials[key] as ShaderMaterial
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_parameter("outline_color", color)
	_outline_materials[key] = mat
	return mat


func _draw() -> void:
	# 接触影：30px、55% 黑、下移 3px，先把单位从格面上“托”起来。
	draw_set_transform(Vector2(0, 31), 0.0, Vector2(1.0, 0.40))
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 队伍色基座环：玩家金 / 敌方绯；将军额外内环 + 冠饰。
	_draw_ellipse_ring(Vector2(0, 31), 15.5, 7.2, DARK_RING, 1.5)
	_draw_ellipse_ring(Vector2(0, 31), 13.0, 6.0, Color(_team_color.r, _team_color.g, _team_color.b, 0.88), 3.0)
	if is_general:
		_draw_ellipse_ring(Vector2(0, 31), 10.0, 4.6, Color(_team_color.r, _team_color.g, _team_color.b, 0.95), 2.0)
		_draw_crown(Vector2(0, -64), 6.0)


func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, width, true)


func _draw_crown(center: Vector2, size: float) -> void:
	var w := size
	var h := size * 0.9
	var pts := PackedVector2Array([
		center + Vector2(-w, h * 0.55),
		center + Vector2(-w, -h * 0.15),
		center + Vector2(-w * 0.5, h * 0.15),
		center + Vector2(0, -h * 0.65),
		center + Vector2(w * 0.5, h * 0.15),
		center + Vector2(w, -h * 0.15),
		center + Vector2(w, h * 0.55),
	])
	draw_colored_polygon(pts, Color(_team_color.r, _team_color.g, _team_color.b, 0.98))
	var closed := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[6], pts[0]])
	draw_polyline(closed, Color(0.04, 0.04, 0.05, 0.9), 1.0, true)


func _make_badge(pos: Vector2, bg: Color, border: Color, badge_size := 22) -> Panel:
	var badge := Panel.new()
	badge.position = pos
	badge.size = Vector2(badge_size, badge_size)
	badge.add_theme_stylebox_override("panel", _badge_style(bg, border))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 100
	add_child(badge)
	return badge


func _make_badge_label(badge: Panel, text: String, font_size := 12, color := Color("#241505")) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", _badge_type())
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.38))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return label


func _badge_type() -> SystemFont:
	if _badge_font == null:
		_badge_font = SystemFont.new()
		_badge_font.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Noto Sans CJK SC",
			"Microsoft YaHei", "WenQuanYi Micro Hei", "sans-serif",
		])
		_badge_font.font_weight = 700
		_badge_font.allow_system_fallback = true
	return _badge_font


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
	style.shadow_color = Color(0.02, 0.02, 0.03, 0.85)
	style.shadow_size = 2
	return style
