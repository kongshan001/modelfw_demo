class_name HeroPortraitView
extends Control

# 立绘舞台：优先加载 assets/visuals/heroes/<id>.png（1024×1536，脚底贴底边），
# 缺失时回退到程序化 Q 版立绘；两种路径共用石台、光尘和呼吸动效。

const PORTRAIT_ASPECT := 1024.0 / 1536.0

var _profile: HeroProfile
var _current_id: StringName = &""
var _texture_rect: TextureRect
var _accent := Color(0.45, 0.8, 1.0)
var _fallback := true
var _time := 0.0
var _base_y := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect = TextureRect.new()
	_texture_rect.name = "Artwork"
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_texture_rect)
	_layout_art()
	set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(_texture_rect):
		_layout_art()

func _layout_art() -> void:
	if _texture_rect == null:
		return
	var art_h := size.y
	var art_w := art_h * PORTRAIT_ASPECT
	if art_w > size.x:
		art_w = size.x
		art_h = art_w / PORTRAIT_ASPECT
	_texture_rect.size = Vector2(art_w, art_h)
	_texture_rect.position = Vector2((size.x - art_w) * 0.5, size.y - art_h)
	_base_y = _texture_rect.position.y
	_texture_rect.pivot_offset = Vector2(art_w * 0.5, art_h)

func _process(delta: float) -> void:
	_time += delta
	if _fallback:
		queue_redraw()
	if is_instance_valid(_texture_rect) and _texture_rect.visible:
		var breathe := sin(_time * 1.3) * 2.5
		_texture_rect.position.y = _base_y + breathe
		_texture_rect.scale = Vector2(1.0, 1.0 + sin(_time * 1.3 + 0.6) * 0.0018)
	else:
		queue_redraw()

func show_profile(profile: HeroProfile, animated: bool) -> void:
	if profile == null:
		return
	_profile = profile
	_current_id = profile.id
	_accent = profile.accent
	var texture: Texture2D = null
	if not profile.portrait_path.is_empty() and ResourceLoader.exists(profile.portrait_path):
		texture = load(profile.portrait_path) as Texture2D
	if texture != null:
		_texture_rect.texture = texture
		_texture_rect.visible = true
		_fallback = false
	else:
		_texture_rect.texture = null
		_texture_rect.visible = false
		_fallback = true
	pivot_offset = Vector2(size.x * 0.5, size.y)
	if animated:
		modulate.a = 0.0
		scale = Vector2(0.975, 0.975)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0
		scale = Vector2.ONE
	queue_redraw()

func current_id() -> StringName:
	return _current_id

func has_ai_art() -> bool:
	return not _fallback

func set_accent(color: Color) -> void:
	_accent = color
	queue_redraw()

# ---------------------------------------------------------------- 石台

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y - 8.0)
	var shadow := Color(0, 0, 0, 0.42)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 188.0, shadow)
	draw_circle(Vector2.ZERO, 150.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ellipse_ring(center, 196.0, 46.0, Color(1.0, 0.84, 0.46, 0.42), 2.0)
	_draw_ellipse_ring(center, 168.0, 39.0, Color(1.0, 0.84, 0.46, 0.24), 1.0)
	for index in 8:
		var angle := TAU * index / 8.0 + _time * 0.05
		var inner := Vector2(cos(angle) * 174.0, sin(angle) * 41.0) + center
		var outer := Vector2(cos(angle) * 188.0, sin(angle) * 44.0) + center
		draw_line(inner, outer, Color(_accent.r, _accent.g, _accent.b, 0.45), 2.0)
	if _fallback:
		_draw_fallback(center)

func _draw_ellipse_ring(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 65:
		var angle := TAU * index / 64.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)

# ---------------------------------------------------------------- 程序化兜底

func _draw_fallback(center: Vector2) -> void:
	if _profile == null:
		return
	var h := size.y * 0.78
	var w := h * 0.42
	var feet := center + Vector2(0, -16.0)
	var cx := center.x
	var head_r := h * 0.105
	var head_y := feet.y - h * 0.72
	var body_top := head_y + head_r * 0.85
	var body_bottom := feet.y - h * 0.1
	var is_female := _profile.gender == "女"
	var is_yao := _profile.race == "妖族"
	var is_xian := _profile.race == "仙族"
	var robe := _accent.darkened(0.32)
	var robe_dark := _accent.darkened(0.55)
	var skin := Color(1.0, 0.84, 0.71)
	var hair := _accent.darkened(0.62)
	var gold := Color(1.0, 0.84, 0.46)

	# 裙摆/袍身
	var hem := w * (0.62 if is_female else 0.55)
	var body := PackedVector2Array([
		Vector2(cx - w * 0.36, body_top),
		Vector2(cx + w * 0.36, body_top),
		Vector2(cx + hem, body_bottom),
		Vector2(cx + hem * 0.35, body_bottom + h * 0.035),
		Vector2(cx - hem * 0.35, body_bottom + h * 0.035),
		Vector2(cx - hem, body_bottom),
	])
	draw_colored_polygon(body, robe)
	draw_polyline(PackedVector2Array([
		Vector2(cx - w * 0.36, body_top),
		Vector2(cx - hem, body_bottom),
		Vector2(cx - hem * 0.35, body_bottom + h * 0.035),
	]), robe_dark, 3.0, true)
	# 右侧暗部
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + w * 0.06, body_top + h * 0.01),
		Vector2(cx + w * 0.36, body_top),
		Vector2(cx + hem, body_bottom),
		Vector2(cx + hem * 0.35, body_bottom + h * 0.035),
		Vector2(cx + w * 0.1, body_bottom - h * 0.03),
	]), Color(0, 0, 0, 0.14))
	# 下摆金边
	draw_polyline(PackedVector2Array([
		Vector2(cx - hem, body_bottom),
		Vector2(cx - hem * 0.35, body_bottom + h * 0.035),
		Vector2(cx + hem * 0.35, body_bottom + h * 0.035),
		Vector2(cx + hem, body_bottom),
	]), Color(1.0, 0.84, 0.46, 0.5), 2.0, true)
	# 内襟
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.12, body_top + h * 0.02),
		Vector2(cx + w * 0.12, body_top + h * 0.02),
		Vector2(cx + w * 0.18, body_bottom - h * 0.04),
		Vector2(cx - w * 0.18, body_bottom - h * 0.04),
	]), Color(1.0, 0.93, 0.8, 0.9))
	# 交领
	draw_polyline(PackedVector2Array([
		Vector2(cx - w * 0.22, body_top + h * 0.01),
		Vector2(cx, body_top + h * 0.12),
		Vector2(cx + w * 0.22, body_top + h * 0.01),
	]), Color(1.0, 0.84, 0.46, 0.7), 2.0, true)
	# 腰带
	draw_rect(Rect2(cx - w * 0.3, body_top + h * 0.18, w * 0.6, h * 0.035), robe_dark)
	draw_rect(Rect2(cx - w * 0.3, body_top + h * 0.18, w * 0.6, 3.0), gold)
	# 袖子
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + side * w * 0.3, body_top + h * 0.02),
			Vector2(cx + side * w * 0.55, body_top + h * 0.12),
			Vector2(cx + side * w * 0.48, body_top + h * 0.28),
			Vector2(cx + side * w * 0.28, body_top + h * 0.24),
		]), robe.lightened(0.06))
	# 手
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(cx + side * w * 0.46, body_top + h * 0.28), head_r * 0.32, skin)
	# 腿/靴
	for side in [-1.0, 1.0]:
		var leg_x: float = cx + side * hem * 0.42
		draw_rect(Rect2(leg_x - w * 0.07, body_bottom, w * 0.14, feet.y - body_bottom), Color(0.92, 0.9, 0.86))
		draw_rect(Rect2(leg_x - w * 0.09, feet.y - h * 0.075, w * 0.18, h * 0.075), robe_dark)
	# 后发 / 长发
	draw_circle(Vector2(cx, head_y - head_r * 0.02), head_r * 1.12, hair)
	if is_female:
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx + side * head_r * 0.9, head_y - head_r * 0.1),
				Vector2(cx + side * head_r * 1.12, head_y + h * 0.2),
				Vector2(cx + side * head_r * 0.55, head_y + head_r * 0.5),
			]), hair.darkened(0.08))
	# 妖族耳
	if is_yao:
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx + side * head_r * 0.72, head_y - head_r * 0.3),
				Vector2(cx + side * head_r * 1.38, head_y - head_r * 1.2),
				Vector2(cx + side * head_r * 0.35, head_y - head_r * 0.78),
			]), hair.lightened(0.22))
	# 脖子
	draw_rect(Rect2(cx - head_r * 0.2, head_y + head_r * 0.55, head_r * 0.4, h * 0.05), skin.darkened(0.08))
	# 脸
	draw_circle(Vector2(cx, head_y + head_r * 0.04), head_r * 0.94, skin)
	# 刘海
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - head_r * 0.96, head_y - head_r * 0.15),
		Vector2(cx - head_r * 0.8, head_y + head_r * 0.28),
		Vector2(cx - head_r * 0.35, head_y + head_r * 0.02),
		Vector2(cx, head_y + head_r * 0.3),
		Vector2(cx + head_r * 0.35, head_y + head_r * 0.02),
		Vector2(cx + head_r * 0.8, head_y + head_r * 0.28),
		Vector2(cx + head_r * 0.96, head_y - head_r * 0.15),
		Vector2(cx, head_y - head_r * 1.02),
	]), hair)
	# 鬓角
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - head_r * 0.98, head_y - head_r * 0.18),
		Vector2(cx - head_r * 0.72, head_y + head_r * 0.55),
		Vector2(cx - head_r * 0.52, head_y + head_r * 0.1),
	]), hair)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx + head_r * 0.98, head_y - head_r * 0.18),
		Vector2(cx + head_r * 0.72, head_y + head_r * 0.55),
		Vector2(cx + head_r * 0.52, head_y + head_r * 0.1),
	]), hair)
	# 仙族光环
	if is_xian:
		draw_arc(Vector2(cx, head_y - head_r * 1.12), head_r * 0.72, PI * 1.08, PI * 1.92, 24, Color(_accent.r, _accent.g, _accent.b, 0.55), 3.0, true)
	# 脸部高光
	draw_arc(Vector2(cx, head_y + head_r * 0.05), head_r * 0.9, PI * 1.08, PI * 1.38, 12, Color(1, 1, 1, 0.18), 2.0, true)
	# 五官
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(cx + side * head_r * 0.32, head_y + head_r * 0.23), head_r * 0.13, Color(0.1, 0.09, 0.14))
		draw_circle(Vector2(cx + side * head_r * 0.32 + head_r * 0.04, head_y + head_r * 0.19), head_r * 0.045, Color(1, 1, 1, 0.9))
		draw_circle(Vector2(cx + side * head_r * 0.52, head_y + head_r * 0.4), head_r * 0.1, Color(1.0, 0.5, 0.5, 0.18))
	draw_arc(Vector2(cx, head_y + head_r * 0.52), head_r * 0.15, 0.15, PI - 0.15, 12, Color(0.45, 0.2, 0.2), 2.0, true)
	# 职业武器
	match _profile.hero_class:
		"剑客":
			var hilt := Vector2(cx + w * 0.5, body_top + h * 0.08)
			var tip := Vector2(cx + w * 0.82, feet.y - h * 0.22)
			draw_line(hilt, tip, Color(0.88, 0.9, 0.95), 5.0, true)
			draw_line(hilt, tip, Color(1.0, 0.96, 0.8, 0.5), 2.0, true)
			draw_line(hilt + Vector2(-w * 0.08, -h * 0.02), hilt + Vector2(w * 0.08, h * 0.02), gold, 5.0, true)
		"法师":
			var staff_x := cx + w * 0.55
			draw_line(Vector2(staff_x, body_top - h * 0.05), Vector2(staff_x, feet.y - h * 0.02), Color(0.45, 0.3, 0.2), 4.0, true)
			draw_circle(Vector2(staff_x, body_top - h * 0.09), head_r * 0.38, Color(_accent.r, _accent.g, _accent.b, 0.85))
			draw_circle(Vector2(staff_x, body_top - h * 0.09), head_r * 0.55, Color(_accent.r, _accent.g, _accent.b, 0.18))
		"医师":
			var staff_x := cx + w * 0.55
			draw_line(Vector2(staff_x, body_top - h * 0.02), Vector2(staff_x, feet.y - h * 0.02), Color(0.4, 0.3, 0.18), 4.0, true)
			for leaf in 3:
				var ly := body_top - h * 0.02 + leaf * h * 0.035
				draw_colored_polygon(PackedVector2Array([
					Vector2(staff_x, ly),
					Vector2(staff_x + w * 0.16, ly - h * 0.02),
					Vector2(staff_x + w * 0.05, ly + h * 0.02),
				]), Color(0.4, 0.78, 0.4, 0.9))
	# 底部光尘
	for index in 10:
		var angle := TAU * index / 10.0 + _time * 0.4
		var radius := 90.0 + sin(_time + index) * 12.0
		var point := Vector2(cx + cos(angle) * radius, feet.y - 20.0 + sin(angle) * 16.0)
		draw_circle(point, 2.2, Color(_accent.r, _accent.g, _accent.b, 0.45))
