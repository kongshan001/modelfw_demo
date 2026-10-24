class_name UnitView
extends Node2D

signal clicked(view: UnitView)

# 原创程序化 Q 版角色。所有角色共用同一套描边 / 高光 / 脸部语言，
# 只在轮廓、配色、发型与武器上区分职业与阵营。
# 设计坐标系：脚底 y=0，向上为负；普通角色身体约 250–270px、含武器约 300px，
# 小妖约 225px，妖将约 300px（draw_set_transform 缩放，UI 与命中区不受影响）。

const BAR_WIDTH := 104.0
const BAR_HEIGHT := 8.0
const HP_Y := -332.0
const MP_Y := -321.0
const NAME_Y := -360.0
const STATUS_Y := -384.0
const CLICK_SIZE := Vector2(130, 320)
const CLICK_CENTER := Vector2(0, -170)
const BUBBLE_GAP := 26.0

const OUTLINE := Color(0.105, 0.072, 0.125, 0.96)
const SKIN := Color(1.0, 0.84, 0.71)
const SKIN_SHADE := Color(0.9, 0.67, 0.57)
const GOLD := Color(1.0, 0.84, 0.46)
const GOLD_DARK := Color(0.66, 0.47, 0.18)
const WHITE := Color(0.94, 0.95, 0.98)
const EYE_DARK := Color(0.1, 0.1, 0.16)
const BLUSH := Color(1.0, 0.5, 0.5, 0.18)

var unit_id: StringName
var side: int = BattleTypes.Side.ALLY
var home_position := Vector2.ZERO
var unit_state: BattleUnitState
var is_ally := false

var _sprite: Sprite2D
var _shadow: Polygon2D
var _info_root: Node2D
var _name_label: Label
var _hp_bg: ColorRect
var _hp_trail: ColorRect
var _hp_fill: ColorRect
var _mp_bg: ColorRect
var _mp_fill: ColorRect
var _status_row: HBoxContainer
var _selection: Polygon2D
var _target_arrow: Polygon2D
var _click_area: Area2D
var _idle_tween: Tween
var _body_color := Color(0.35, 0.6, 1.0)
var _visual_rng := RandomNumberGenerator.new()
var _art_scale := 1.0
var _has_texture := false
var _info_offset_y := 0.0

func _ready() -> void:
	_build_placeholder()
	_build_bars()
	_build_click_area()

func setup(unit: BattleUnitState, home: Vector2, ally: bool) -> void:
	unit_state = unit
	unit_id = unit.id
	side = unit.side
	is_ally = ally
	home_position = home
	position = home
	_visual_rng.seed = hash(String(unit_id)) + 17
	_body_color = Color(0.32, 0.62, 1.0) if ally else Color(0.95, 0.36, 0.3)
	_art_scale = _art_scale_for(String(unit_id))
	_info_offset_y = _info_offset_for(String(unit_id))
	if _info_root != null:
		_info_root.position = Vector2(0, _info_offset_y)
	_name_label.text = unit.data.display_name
	_apply_visual_override()
	_apply_shadow_scale()
	queue_redraw()
	refresh_from_state(unit)
	visible = true
	_start_idle()

func refresh_from_state(unit: BattleUnitState) -> void:
	unit_state = unit
	set_hp(unit.hp, false)
	set_mp(unit.mp, false)
	set_statuses(unit.statuses)
	visible = unit.is_alive() or unit.hp > 0
	if not unit.is_alive():
		modulate.a = 0.35
		rotation = deg_to_rad(-12.0)
		position = home_position + Vector2(0, 26)

# ---------------------------------------------------------------- 视觉目录 / 兜底

func _art_scale_for(id: String) -> float:
	match id:
		"boss_brute":
			return 1.06
		"mob_a":
			return 0.92
		"mob_b":
			return 0.94
		"boss_fox":
			return 1.0
		_:
			return 1.0

func _info_offset_for(id: String) -> float:
	# 小妖实际身高约 225px，信息条贴近头顶；其他单位保持原有悬空高度。
	match id:
		"mob_a", "mob_b":
			return 76.0
		_:
			return 0.0

func _apply_shadow_scale() -> void:
	if _shadow == null:
		return
	var wide := 1.25 if String(unit_id) == "boss_brute" else 1.08
	_shadow.scale = Vector2(_art_scale * wide, _art_scale)

func _apply_visual_override() -> void:
	if _sprite == null or unit_state == null or unit_state.data == null:
		return
	var entry := VisualCatalog.unit_entry(unit_id)
	var path := String(entry.get("sprite", entry.get("path", ""))).strip_edges()
	var scale_value := float(entry.get("scale", 1.0))
	if not entry.has("scale") and unit_state.data.visual_scale > 0.0:
		scale_value = unit_state.data.visual_scale
	if path.is_empty() and not unit_state.data.sprite_path.is_empty():
		path = unit_state.data.sprite_path
	var texture := VisualCatalog.load_texture(path)
	if texture == null:
		_has_texture = false
		_sprite.visible = false
		return
	scale_value = maxf(0.05, scale_value)
	_sprite.texture = texture
	_sprite.scale = Vector2(scale_value, scale_value)
	_sprite.position = Vector2(0, -texture.get_height() * 0.5 * scale_value)
	var offset: Variant = entry.get("offset", [])
	if offset is Array and offset.size() >= 2:
		_sprite.position += Vector2(float(offset[0]), float(offset[1]))
	_sprite.visible = true
	_has_texture = true
	queue_redraw()

func _build_placeholder() -> void:
	_sprite = Sprite2D.new()
	_sprite.visible = false
	add_child(_sprite)
	_shadow = Polygon2D.new()
	_shadow.polygon = _ellipse_points(64, 18)
	_shadow.color = Color(0.04, 0.05, 0.03, 0.32)
	_shadow.position = Vector2(0, 8)
	add_child(_shadow)

func _draw() -> void:
	if _has_texture:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_art_scale, _art_scale))
	match String(unit_id):
		"hero_swordsman":
			_draw_swordsman()
		"hero_mage":
			_draw_mage()
		"hero_healer":
			_draw_healer()
		"mob_a":
			_draw_goblin(false)
		"mob_b":
			_draw_goblin(true)
		"boss_brute":
			_draw_brute()
		"boss_fox":
			_draw_fox()
		_:
			_draw_generic()

func _draw_generic() -> void:
	_circle(Vector2(0, -196), 50, SKIN, 4.0)
	_poly(PackedVector2Array([Vector2(-36, -158), Vector2(36, -158), Vector2(48, -50), Vector2(-48, -50)]), _body_color)
	_capsule(Vector2(-18, -80), Vector2(-26, -14), 14, _body_color.darkened(0.2))
	_capsule(Vector2(18, -80), Vector2(26, -14), 14, _body_color.darkened(0.2))
	_eye(Vector2(-18, -198))
	_eye(Vector2(18, -198))
	_mouth_smile(Vector2(0, -178), 12, OUTLINE)

# ---------------------------------------------------------------- 剑客·凌霄

func _draw_swordsman() -> void:
	var blue := Color(0.22, 0.43, 0.79)
	var blue_dark := Color(0.13, 0.27, 0.55)
	var blue_light := Color(0.49, 0.7, 0.96)
	var hair := Color(0.12, 0.14, 0.24)
	var hair_hi := Color(0.27, 0.31, 0.48)
	# 发带尾（身后）
	_poly(PackedVector2Array([Vector2(-34, -224), Vector2(-88, -208), Vector2(-96, -190), Vector2(-70, -188), Vector2(-30, -206)]), blue_dark)
	_poly(PackedVector2Array([Vector2(-32, -216), Vector2(-76, -198), Vector2(-72, -192), Vector2(-28, -204)]), blue_light)
	# 后发
	_circle(Vector2(0, -205), 56, hair, 4.0)
	# 腿与靴
	_capsule(Vector2(-20, -84), Vector2(-29, -18), 15, Color(0.88, 0.92, 0.99))
	_capsule(Vector2(20, -84), Vector2(31, -18), 15, Color(0.88, 0.92, 0.99))
	_poly(PackedVector2Array([Vector2(-46, -18), Vector2(-16, -18), Vector2(-14, 0), Vector2(-48, 0)]), Color(0.12, 0.15, 0.25))
	_poly(PackedVector2Array([Vector2(16, -18), Vector2(46, -18), Vector2(48, 0), Vector2(14, 0)]), Color(0.12, 0.15, 0.25))
	draw_line(Vector2(-45, -3), Vector2(-17, -3), GOLD_DARK, 2.0, true)
	draw_line(Vector2(17, -3), Vector2(45, -3), GOLD_DARK, 2.0, true)
	# 长袍下摆
	_poly(PackedVector2Array([Vector2(-38, -156), Vector2(38, -156), Vector2(56, -56), Vector2(36, -40), Vector2(0, -36), Vector2(-36, -40), Vector2(-56, -56)]), blue)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -150), Vector2(38, -156), Vector2(56, -56), Vector2(36, -40), Vector2(14, -37)]), blue_dark)
	_poly(PackedVector2Array([Vector2(-13, -150), Vector2(13, -150), Vector2(15, -42), Vector2(-15, -42)]), Color(0.86, 0.92, 1.0), 2.5)
	draw_polyline(PackedVector2Array([Vector2(-44, -46), Vector2(-18, -40), Vector2(18, -40), Vector2(46, -46)]), GOLD_DARK, 3.0, true)
	# 躯干
	_poly(PackedVector2Array([Vector2(-36, -178), Vector2(36, -178), Vector2(42, -144), Vector2(-42, -144)]), blue)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -178), Vector2(36, -178), Vector2(42, -144), Vector2(10, -144)]), blue_dark)
	# 白色交领
	_poly(PackedVector2Array([Vector2(-22, -176), Vector2(0, -146), Vector2(22, -176), Vector2(12, -180), Vector2(0, -158), Vector2(-12, -180)]), WHITE, 2.0)
	# 腰带
	_poly(PackedVector2Array([Vector2(-39, -138), Vector2(39, -138), Vector2(37, -120), Vector2(-37, -120)]), blue_dark)
	_circle(Vector2(0, -129), 6.5, GOLD, 2.0)
	# 左臂（叉腰）
	_capsule(Vector2(-34, -162), Vector2(-58, -130), 17, blue)
	_capsule(Vector2(-58, -130), Vector2(-40, -112), 13, blue_dark)
	_circle(Vector2(-37, -108), 8, SKIN, 2.5)
	# 右臂（握剑）
	_capsule(Vector2(34, -162), Vector2(58, -136), 17, blue)
	_capsule(Vector2(58, -136), Vector2(52, -112), 13, blue_dark)
	draw_line(Vector2(46, -120), Vector2(58, -116), WHITE, 4.0, true)
	# 颈与头
	_poly(PackedVector2Array([Vector2(-12, -166), Vector2(12, -166), Vector2(12, -146), Vector2(-12, -146)]), SKIN_SHADE, 2.0)
	_circle(Vector2(0, -201), 50, SKIN, 4.0)
	_circle(Vector2(-47, -202), 8, SKIN, 2.5)
	_circle(Vector2(47, -202), 8, SKIN, 2.5)
	_rim_arc(Vector2(0, -201), 55, -62.0, 52.0)
	# 前发 / 鬓角
	_poly(PackedVector2Array([Vector2(-52, -214), Vector2(-49, -240), Vector2(-24, -252), Vector2(2, -244), Vector2(28, -253), Vector2(50, -236), Vector2(52, -210), Vector2(30, -226), Vector2(16, -214), Vector2(2, -228), Vector2(-16, -212), Vector2(-32, -230)]), hair)
	_poly(PackedVector2Array([Vector2(-53, -220), Vector2(-58, -178), Vector2(-48, -158), Vector2(-38, -198)]), hair, 3.0)
	_poly(PackedVector2Array([Vector2(53, -220), Vector2(58, -180), Vector2(49, -160), Vector2(40, -198)]), hair, 3.0)
	draw_line(Vector2(-30, -244), Vector2(-18, -226), hair_hi, 3.0, true)
	draw_line(Vector2(20, -246), Vector2(34, -228), hair_hi, 3.0, true)
	# 深色发带
	_poly(PackedVector2Array([Vector2(-52, -226), Vector2(-26, -234), Vector2(26, -234), Vector2(52, -226), Vector2(50, -216), Vector2(0, -222), Vector2(-50, -216)]), blue_dark, 2.5)
	draw_line(Vector2(-49, -222), Vector2(49, -222), GOLD_DARK, 2.0, true)
	# 五官（自信）
	_eye(Vector2(-18, -200), Vector2.ZERO, Color(0.1, 0.12, 0.22))
	_eye(Vector2(18, -200), Vector2.ZERO, Color(0.1, 0.12, 0.22))
	draw_line(Vector2(-31, -214), Vector2(-9, -207), hair, 2.8, true)
	draw_line(Vector2(9, -207), Vector2(31, -214), hair, 2.8, true)
	_mouth_smile(Vector2(1, -178), 13, Color(0.42, 0.2, 0.2))
	_blush(Vector2(-29, -185))
	_blush(Vector2(29, -185))
	# 长剑
	_line(Vector2(38, -102), Vector2(52, -122), Color(0.34, 0.21, 0.14), 8.0)
	_line(Vector2(39, -118), Vector2(64, -109), GOLD_DARK, 5.0)
	_poly(PackedVector2Array([Vector2(47, -121), Vector2(59, -126), Vector2(116, -300)]), Color(0.83, 0.89, 0.97), 3.0)
	draw_line(Vector2(53, -129), Vector2(108, -292), Color(1, 1, 1, 0.9), 2.2, true)
	_circle(Vector2(36, -100), 5.0, GOLD, 2.0)
	draw_line(Vector2(45, -116), Vector2(54, -148), Color(0.82, 0.24, 0.28), 4.0, true)
	_circle(Vector2(55, -152), 4.0, Color(0.82, 0.24, 0.28), 2.0)
	# 握剑手
	_circle(Vector2(50, -109), 9.0, SKIN, 2.5)

# ---------------------------------------------------------------- 法师·青鸾

func _draw_mage() -> void:
	var teal := Color(0.12, 0.52, 0.55)
	var teal_dark := Color(0.07, 0.3, 0.4)
	var aqua := Color(0.5, 0.87, 0.9)
	var cream := Color(0.9, 0.96, 0.95)
	var hair := Color(0.11, 0.18, 0.28)
	var hair_hi := Color(0.22, 0.38, 0.5)
	# 法杖（身后，杖身贴近身体，法球落在自身命中区内）
	_line(Vector2(44, -8), Vector2(52, -264), Color(0.3, 0.22, 0.17), 7.0)
	for band_y: float in [-80.0, -158.0, -232.0]:
		draw_line(Vector2(46, band_y), Vector2(58, band_y + 3), GOLD_DARK, 4.0, true)
	draw_circle(Vector2(52, -280), 34.0, Color(0.5, 0.9, 1.0, 0.09))
	draw_circle(Vector2(52, -280), 24.0, Color(0.55, 0.93, 1.0, 0.16))
	_circle(Vector2(52, -280), 15.0, Color(0.58, 0.92, 1.0), 3.0)
	draw_circle(Vector2(48, -285), 5.0, Color(1, 1, 1, 0.85))
	# 后发（长发及腰）
	_circle(Vector2(0, -210), 56, hair, 4.0)
	_poly(PackedVector2Array([Vector2(-50, -226), Vector2(-66, -160), Vector2(-72, -86), Vector2(-48, -70), Vector2(-34, -150), Vector2(-28, -196)]), hair)
	_poly(PackedVector2Array([Vector2(50, -226), Vector2(68, -160), Vector2(72, -88), Vector2(48, -72), Vector2(34, -150), Vector2(28, -196)]), hair)
	draw_line(Vector2(-58, -208), Vector2(-62, -104), hair_hi, 4.0, true)
	draw_line(Vector2(60, -204), Vector2(64, -108), hair_hi, 3.5, true)
	# 腿 / 鞋
	_capsule(Vector2(-18, -80), Vector2(-24, -14), 13, Color(0.86, 0.94, 0.94))
	_capsule(Vector2(18, -80), Vector2(26, -14), 13, Color(0.86, 0.94, 0.94))
	_poly(PackedVector2Array([Vector2(-38, -16), Vector2(-14, -16), Vector2(-12, 0), Vector2(-40, 0)]), teal_dark)
	_poly(PackedVector2Array([Vector2(14, -16), Vector2(38, -16), Vector2(40, 0), Vector2(12, 0)]), teal_dark)
	# 长袍
	_poly(PackedVector2Array([Vector2(-38, -158), Vector2(38, -158), Vector2(56, -58), Vector2(34, -40), Vector2(0, -46), Vector2(-34, -40), Vector2(-56, -58)]), teal)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -154), Vector2(38, -158), Vector2(56, -58), Vector2(34, -40), Vector2(14, -44)]), teal_dark)
	_poly(PackedVector2Array([Vector2(-15, -152), Vector2(15, -152), Vector2(18, -46), Vector2(-18, -46)]), cream, 2.5)
	draw_polyline(PackedVector2Array([Vector2(-46, -50), Vector2(-20, -43), Vector2(20, -43), Vector2(46, -50)]), GOLD_DARK, 3.0, true)
	# 上衣
	_poly(PackedVector2Array([Vector2(-36, -180), Vector2(36, -180), Vector2(42, -148), Vector2(-42, -148)]), teal)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -180), Vector2(36, -180), Vector2(42, -148), Vector2(10, -148)]), teal_dark)
	_poly(PackedVector2Array([Vector2(-24, -178), Vector2(0, -150), Vector2(24, -178), Vector2(13, -182), Vector2(0, -164), Vector2(-13, -182)]), cream, 2.0)
	# 腰带
	_poly(PackedVector2Array([Vector2(-38, -142), Vector2(38, -142), Vector2(36, -126), Vector2(-36, -126)]), Color(0.85, 0.56, 0.44))
	_circle(Vector2(0, -134), 5.5, GOLD, 2.0)
	# 左臂抬手施法
	_capsule(Vector2(-34, -166), Vector2(-62, -142), 16, teal)
	_capsule(Vector2(-62, -142), Vector2(-54, -178), 12, cream)
	_circle(Vector2(-54, -182), 7.5, SKIN, 2.5)
	draw_circle(Vector2(-58, -196), 8.0, Color(0.55, 0.95, 1.0, 0.28))
	draw_circle(Vector2(-58, -196), 3.0, Color(0.8, 1.0, 1.0, 0.9))
	# 右臂握杖
	_capsule(Vector2(34, -166), Vector2(52, -142), 16, teal)
	_capsule(Vector2(52, -142), Vector2(50, -120), 12, cream)
	# 颈与头
	_poly(PackedVector2Array([Vector2(-11, -168), Vector2(11, -168), Vector2(11, -148), Vector2(-11, -148)]), SKIN_SHADE, 2.0)
	_circle(Vector2(0, -204), 50, SKIN, 4.0)
	_rim_arc(Vector2(0, -204), 55, -62.0, 52.0)
	# 前发：中分长刘海
	_poly(PackedVector2Array([Vector2(-52, -220), Vector2(-48, -246), Vector2(-22, -256), Vector2(0, -246), Vector2(24, -256), Vector2(49, -242), Vector2(53, -218), Vector2(34, -240), Vector2(16, -218), Vector2(4, -240), Vector2(-14, -216), Vector2(-32, -242)]), hair)
	_poly(PackedVector2Array([Vector2(-51, -226), Vector2(-60, -170), Vector2(-44, -138), Vector2(-36, -184)]), hair, 3.0)
	_poly(PackedVector2Array([Vector2(51, -226), Vector2(60, -172), Vector2(46, -140), Vector2(38, -184)]), hair, 3.0)
	draw_line(Vector2(-26, -248), Vector2(-12, -228), hair_hi, 3.0, true)
	draw_line(Vector2(26, -250), Vector2(12, -228), hair_hi, 3.0, true)
	# 金色发簪
	draw_line(Vector2(30, -240), Vector2(48, -228), GOLD, 3.0, true)
	_circle(Vector2(34, -238), 4.0, GOLD, 2.0)
	draw_circle(Vector2(49, -224), 3.5, Color(0.7, 0.95, 0.95, 0.9))
	# 五官（沉静）
	_eye(Vector2(-18, -202), Vector2.ZERO, Color(0.08, 0.2, 0.28))
	_eye(Vector2(18, -202), Vector2.ZERO, Color(0.08, 0.2, 0.28))
	draw_line(Vector2(-30, -210), Vector2(-34, -206), hair, 2.2, true)
	draw_line(Vector2(30, -210), Vector2(34, -206), hair, 2.2, true)
	draw_line(Vector2(-7, -182), Vector2(0, -180), Color(0.55, 0.3, 0.35), 2.2, true)
	draw_line(Vector2(0, -180), Vector2(7, -182), Color(0.55, 0.3, 0.35), 2.2, true)
	_blush(Vector2(-29, -188))
	_blush(Vector2(29, -188))
	# 杖顶碎光
	for spark: Vector2 in [Vector2(32, -304), Vector2(62, -294), Vector2(34, -252), Vector2(62, -262)]:
		_circle(spark, 3.0, Color(0.75, 1.0, 1.0, 0.85), 1.0)
	# 握杖手
	_circle(Vector2(50, -118), 8.5, SKIN, 2.5)

# ---------------------------------------------------------------- 医师·白术

func _draw_healer() -> void:
	var cream := Color(0.93, 0.96, 0.9)
	var green := Color(0.36, 0.62, 0.42)
	var green_dark := Color(0.22, 0.43, 0.3)
	var hair := Color(0.44, 0.29, 0.22)
	var hair_hi := Color(0.63, 0.44, 0.32)
	# 药杖（身后）
	_line(Vector2(62, -6), Vector2(68, -228), Color(0.38, 0.27, 0.17), 6.0)
	draw_line(Vector2(60, -196), Vector2(74, -192), GOLD_DARK, 3.0, true)
	# 后发
	_circle(Vector2(0, -206), 55, hair, 4.0)
	_poly(PackedVector2Array([Vector2(-48, -226), Vector2(-58, -166), Vector2(-52, -104), Vector2(-36, -120), Vector2(-30, -190)]), hair)
	_poly(PackedVector2Array([Vector2(48, -226), Vector2(58, -166), Vector2(52, -104), Vector2(36, -120), Vector2(30, -190)]), hair)
	# 腿 / 布鞋
	_capsule(Vector2(-18, -80), Vector2(-25, -14), 13, Color(0.86, 0.9, 0.82))
	_capsule(Vector2(18, -80), Vector2(27, -14), 13, Color(0.86, 0.9, 0.82))
	_poly(PackedVector2Array([Vector2(-38, -16), Vector2(-14, -16), Vector2(-12, 0), Vector2(-40, 0)]), green_dark)
	_poly(PackedVector2Array([Vector2(14, -16), Vector2(38, -16), Vector2(40, 0), Vector2(12, 0)]), green_dark)
	# 长袍
	_poly(PackedVector2Array([Vector2(-38, -156), Vector2(38, -156), Vector2(54, -54), Vector2(32, -38), Vector2(0, -44), Vector2(-32, -38), Vector2(-54, -54)]), cream)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -152), Vector2(38, -156), Vector2(54, -54), Vector2(32, -38), Vector2(12, -42)]), Color(0.82, 0.89, 0.8))
	# 绿色对襟外袍
	_poly(PackedVector2Array([Vector2(-38, -156), Vector2(-20, -158), Vector2(-24, -44), Vector2(-44, -48), Vector2(-52, -56)]), green)
	_poly(PackedVector2Array([Vector2(38, -156), Vector2(20, -158), Vector2(24, -44), Vector2(44, -48), Vector2(52, -56)]), green)
	draw_polyline(PackedVector2Array([Vector2(-44, -48), Vector2(-20, -43), Vector2(20, -43), Vector2(44, -48)]), green_dark, 3.0, true)
	# 上衣
	_poly(PackedVector2Array([Vector2(-36, -178), Vector2(36, -178), Vector2(40, -146), Vector2(-40, -146)]), cream)
	_poly(PackedVector2Array([Vector2(-22, -176), Vector2(0, -150), Vector2(22, -176), Vector2(12, -180), Vector2(0, -162), Vector2(-12, -180)]), green, 2.0)
	# 腰带
	_poly(PackedVector2Array([Vector2(-38, -142), Vector2(38, -142), Vector2(36, -126), Vector2(-36, -126)]), green)
	draw_line(Vector2(-32, -134), Vector2(32, -134), Color(0.85, 0.93, 0.7), 2.0, true)
	# 左臂
	_capsule(Vector2(-34, -164), Vector2(-58, -136), 16, cream)
	_capsule(Vector2(-58, -136), Vector2(-42, -116), 12, green)
	_circle(Vector2(-40, -112), 7.5, SKIN, 2.5)
	# 右臂握杖
	_capsule(Vector2(34, -164), Vector2(58, -140), 16, cream)
	_capsule(Vector2(58, -140), Vector2(66, -122), 12, green)
	# 药囊（左胯）
	draw_line(Vector2(28, -172), Vector2(-44, -104), Color(0.36, 0.25, 0.16), 5.0, true)
	_poly(PackedVector2Array([Vector2(-60, -108), Vector2(-34, -112), Vector2(-26, -84), Vector2(-50, -74)]), Color(0.55, 0.38, 0.22), 3.0)
	draw_line(Vector2(-52, -104), Vector2(-34, -90), Color(0.85, 0.7, 0.4), 2.0, true)
	_poly(PackedVector2Array([Vector2(-48, -112), Vector2(-55, -128), Vector2(-46, -122)]), green, 2.0)
	_poly(PackedVector2Array([Vector2(-42, -113), Vector2(-36, -132), Vector2(-30, -118)]), green, 2.0)
	# 颈与头
	_poly(PackedVector2Array([Vector2(-11, -166), Vector2(11, -166), Vector2(11, -146), Vector2(-11, -146)]), SKIN_SHADE, 2.0)
	_circle(Vector2(0, -202), 49, SKIN, 4.0)
	_rim_arc(Vector2(0, -202), 54, -62.0, 52.0)
	# 发髻
	_circle(Vector2(0, -252), 19, hair, 3.5)
	draw_line(Vector2(-14, -252), Vector2(14, -254), hair_hi, 2.5, true)
	draw_line(Vector2(14, -258), Vector2(30, -268), GOLD, 3.0, true)
	_circle(Vector2(15, -258), 3.5, GOLD, 2.0)
	# 前发
	_poly(PackedVector2Array([Vector2(-50, -216), Vector2(-46, -242), Vector2(-20, -252), Vector2(0, -244), Vector2(24, -252), Vector2(48, -238), Vector2(51, -214), Vector2(30, -230), Vector2(14, -212), Vector2(-2, -226), Vector2(-18, -210), Vector2(-34, -230)]), hair)
	_poly(PackedVector2Array([Vector2(-50, -224), Vector2(-56, -176), Vector2(-44, -148), Vector2(-36, -190)]), hair, 3.0)
	_poly(PackedVector2Array([Vector2(50, -224), Vector2(56, -176), Vector2(44, -148), Vector2(36, -190)]), hair, 3.0)
	draw_line(Vector2(-28, -244), Vector2(-16, -222), hair_hi, 3.0, true)
	draw_line(Vector2(22, -246), Vector2(34, -226), hair_hi, 3.0, true)
	# 五官（温柔闭眼笑）
	_closed_eye(Vector2(-18, -200), 14, Color(0.3, 0.18, 0.16))
	_closed_eye(Vector2(18, -200), 14, Color(0.3, 0.18, 0.16))
	draw_line(Vector2(-29, -212), Vector2(-10, -211), hair, 2.2, true)
	draw_line(Vector2(10, -211), Vector2(29, -212), hair, 2.2, true)
	_mouth_smile(Vector2(0, -180), 12, Color(0.5, 0.24, 0.24))
	_blush(Vector2(-27, -186))
	_blush(Vector2(27, -186))
	# 杖顶药草
	_poly(PackedVector2Array([Vector2(68, -228), Vector2(46, -248), Vector2(60, -258), Vector2(74, -238)]), green, 2.5)
	_poly(PackedVector2Array([Vector2(68, -228), Vector2(84, -256), Vector2(76, -266), Vector2(62, -240)]), green, 2.5)
	_poly(PackedVector2Array([Vector2(68, -230), Vector2(66, -266), Vector2(74, -262), Vector2(76, -234)]), Color(0.47, 0.74, 0.5), 2.5)
	draw_circle(Vector2(70, -260), 9.0, Color(0.6, 1.0, 0.65, 0.18))
	_circle(Vector2(70, -260), 4.0, Color(0.75, 1.0, 0.72), 1.5)
	# 握杖手
	_circle(Vector2(68, -120), 8.0, SKIN, 2.5)

# ---------------------------------------------------------------- 妖兵·甲 / 乙

func _draw_goblin(poison: bool) -> void:
	var skin := Color(0.78, 0.36, 0.31)
	var skin_dark := Color(0.6, 0.24, 0.22)
	var leather := Color(0.17, 0.14, 0.16)
	var leather_hi := Color(0.31, 0.26, 0.27)
	var accent := Color(0.42, 0.78, 0.32) if poison else Color(0.8, 0.2, 0.16)
	var accent_hi := Color(0.66, 0.95, 0.4) if poison else Color(1.0, 0.45, 0.25)
	var hair := Color(0.12, 0.1, 0.12)
	# 后耳
	_poly(PackedVector2Array([Vector2(-38, -188), Vector2(-78, -204), Vector2(-46, -162)]), skin, 3.0)
	_poly(PackedVector2Array([Vector2(38, -188), Vector2(78, -204), Vector2(46, -162)]), skin, 3.0)
	draw_line(Vector2(-62, -190), Vector2(-46, -180), skin_dark, 2.0, true)
	draw_line(Vector2(62, -190), Vector2(46, -180), skin_dark, 2.0, true)
	# 短腿与绑腿
	_capsule(Vector2(-16, -74), Vector2(-27, -16), 15, skin)
	_capsule(Vector2(16, -74), Vector2(26, -16), 15, skin)
	_poly(PackedVector2Array([Vector2(-38, -18), Vector2(-16, -18), Vector2(-14, 0), Vector2(-40, 0)]), leather)
	_poly(PackedVector2Array([Vector2(14, -18), Vector2(38, -18), Vector2(40, 0), Vector2(12, 0)]), leather)
	for wrap_y: float in [-30.0, -42.0]:
		draw_line(Vector2(-32, wrap_y), Vector2(-18, wrap_y + 2), leather_hi, 2.0, true)
		draw_line(Vector2(18, wrap_y + 2), Vector2(32, wrap_y), leather_hi, 2.0, true)
	# 躯干（红皮肤 + 黑皮甲）
	_poly(PackedVector2Array([Vector2(-30, -152), Vector2(30, -152), Vector2(38, -104), Vector2(26, -66), Vector2(-26, -66), Vector2(-38, -104)]), skin)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -150), Vector2(30, -152), Vector2(38, -104), Vector2(26, -66), Vector2(12, -66)]), skin_dark)
	_poly(PackedVector2Array([Vector2(-31, -150), Vector2(31, -150), Vector2(34, -112), Vector2(0, -100), Vector2(-34, -112)]), leather, 3.0)
	draw_line(Vector2(-26, -140), Vector2(26, -140), leather_hi, 2.0, true)
	draw_line(Vector2(0, -148), Vector2(0, -104), leather_hi, 1.5, true)
	# 腰带
	_poly(PackedVector2Array([Vector2(-34, -108), Vector2(34, -108), Vector2(32, -92), Vector2(-32, -92)]), Color(0.3, 0.2, 0.12))
	_circle(Vector2(0, -100), 5.0, GOLD_DARK, 2.0)
	# 左肩甲 / 绿披肩
	if poison:
		_poly(PackedVector2Array([Vector2(-34, -152), Vector2(-2, -156), Vector2(-6, -132), Vector2(-36, -126)]), accent, 2.5)
		_poly(PackedVector2Array([Vector2(-34, -128), Vector2(-18, -120), Vector2(-28, -102), Vector2(-42, -112)]), accent, 2.0)
	else:
		_poly(PackedVector2Array([Vector2(-36, -154), Vector2(-8, -156), Vector2(-12, -130), Vector2(-38, -124)]), Color(0.24, 0.2, 0.21), 2.5)
		for spike: Vector2 in [Vector2(-34, -158), Vector2(-26, -162), Vector2(-18, -160)]:
			_poly(PackedVector2Array([spike + Vector2(-3, 0), spike + Vector2(3, 0), spike + Vector2(0, -10)]), Color(0.75, 0.7, 0.62), 1.5)
	# 左臂
	_capsule(Vector2(-30, -144), Vector2(-48, -116), 14, skin)
	_capsule(Vector2(-48, -116), Vector2(-52, -98), 12, skin)
	draw_line(Vector2(-54, -108), Vector2(-38, -104), leather_hi, 5.0, true)
	_circle(Vector2(-54, -94), 8.0, skin, 2.5)
	# 右臂
	_capsule(Vector2(30, -144), Vector2(46, -128), 14, skin)
	draw_line(Vector2(36, -122), Vector2(52, -126), leather_hi, 5.0, true)
	# 头
	_circle(Vector2(0, -180), 45, skin, 4.0)
	_circle(Vector2(-42, -184), 10, skin, 2.5)
	_circle(Vector2(42, -184), 10, skin, 2.5)
	_rim_arc(Vector2(0, -180), 49, -58.0, 48.0)
	# 角
	_poly(PackedVector2Array([Vector2(-18, -220), Vector2(-26, -246), Vector2(-6, -224)]), Color(0.88, 0.82, 0.68), 2.5)
	if poison:
		_poly(PackedVector2Array([Vector2(17, -220), Vector2(22, -236), Vector2(28, -218)]), Color(0.8, 0.76, 0.64), 2.0)
	else:
		_poly(PackedVector2Array([Vector2(17, -220), Vector2(24, -246), Vector2(29, -219)]), Color(0.88, 0.82, 0.68), 2.5)
	# 头发 / 头巾
	_poly(PackedVector2Array([Vector2(-42, -204), Vector2(-26, -226), Vector2(-8, -216), Vector2(8, -228), Vector2(28, -220), Vector2(42, -202), Vector2(24, -210), Vector2(6, -202), Vector2(-10, -212), Vector2(-28, -202)]), hair)
	if poison:
		_poly(PackedVector2Array([Vector2(-46, -214), Vector2(-26, -224), Vector2(26, -224), Vector2(46, -214), Vector2(44, -202), Vector2(0, -210), Vector2(-44, -202)]), accent, 2.0)
		_poly(PackedVector2Array([Vector2(-42, -204), Vector2(-72, -190), Vector2(-66, -178), Vector2(-36, -196)]), accent, 2.0)
	else:
		draw_line(Vector2(-42, -210), Vector2(42, -210), leather_hi, 4.0, true)
	# 五官（凶）
	_eye(Vector2(-16, -184), Vector2.ZERO, Color(0.95, 0.8, 0.3), 5.5, 5.0)
	_eye(Vector2(16, -184), Vector2.ZERO, Color(0.95, 0.8, 0.3), 5.5, 5.0)
	draw_line(Vector2(-28, -196), Vector2(-7, -190), hair, 3.0, true)
	draw_line(Vector2(7, -190), Vector2(28, -196), hair, 3.0, true)
	# 咧嘴 + 獠牙
	_poly(PackedVector2Array([Vector2(-16, -168), Vector2(16, -168), Vector2(10, -158), Vector2(-10, -158)]), Color(0.28, 0.1, 0.1), 1.5)
	_poly(PackedVector2Array([Vector2(-12, -168), Vector2(-6, -168), Vector2(-9, -174)]), Color(0.96, 0.92, 0.8), 1.0)
	_poly(PackedVector2Array([Vector2(6, -168), Vector2(12, -168), Vector2(9, -174)]), Color(0.96, 0.92, 0.8), 1.0)
	if poison:
		_blush(Vector2(-28, -172), Color(0.45, 0.85, 0.35, 0.3))
		_blush(Vector2(28, -172), Color(0.45, 0.85, 0.35, 0.3))
		for mark_x: float in [-32.0, -22.0]:
			draw_line(Vector2(mark_x, -194), Vector2(mark_x + 6, -188), accent_hi, 2.0, true)
	# 武器
	if poison:
		# 毒矛
		_line(Vector2(44, -112), Vector2(98, -292), Color(0.34, 0.24, 0.16), 6.0)
		_poly(PackedVector2Array([Vector2(95, -288), Vector2(103, -318), Vector2(111, -292), Vector2(103, -280)]), Color(0.45, 0.9, 0.35), 2.5)
		draw_line(Vector2(99, -292), Vector2(105, -308), Color(0.85, 1.0, 0.6), 2.0, true)
		draw_circle(Vector2(105, -275), 5.0, Color(0.45, 0.95, 0.35, 0.35))
		_poly(PackedVector2Array([Vector2(86, -268), Vector2(66, -256), Vector2(78, -250), Vector2(92, -258)]), accent, 1.5)
	else:
		# 狼牙棒
		_line(Vector2(42, -116), Vector2(70, -246), Color(0.34, 0.24, 0.16), 8.0)
		_circle(Vector2(74, -258), 20.0, Color(0.4, 0.29, 0.19), 3.5)
		for spike: Vector2 in [Vector2(56, -262), Vector2(70, -282), Vector2(88, -272), Vector2(92, -250), Vector2(74, -240)]:
			_poly(PackedVector2Array([spike + Vector2(-3, 1), spike + Vector2(3, 1), spike * 1.06 + Vector2(0, -10)]), Color(0.72, 0.66, 0.56), 1.5)
		_circle(Vector2(74, -258), 6.0, leather_hi, 1.5)
	# 握武器手
	_circle(Vector2(48, -116), 8.5, skin, 2.5)

# ---------------------------------------------------------------- 妖将·裂山

func _draw_brute() -> void:
	var fur := Color(0.24, 0.16, 0.13)
	var fur_hi := Color(0.38, 0.27, 0.2)
	var body := Color(0.47, 0.28, 0.22)
	var body_hi := Color(0.6, 0.38, 0.29)
	var skin := Color(0.6, 0.34, 0.26)
	var skin_dark := Color(0.45, 0.23, 0.19)
	# 披毛（身后）
	_poly(PackedVector2Array([Vector2(-74, -160), Vector2(-98, -108), Vector2(-84, -52), Vector2(-52, -76), Vector2(-36, -40), Vector2(-10, -66), Vector2(12, -38), Vector2(38, -64), Vector2(58, -42), Vector2(78, -74), Vector2(96, -54), Vector2(100, -110), Vector2(76, -160)]), fur, 4.0)
	# 粗腿
	_capsule(Vector2(-34, -92), Vector2(-48, -16), 26, body)
	_capsule(Vector2(34, -92), Vector2(48, -16), 26, body)
	_poly(PackedVector2Array([Vector2(-72, -18), Vector2(-26, -18), Vector2(-22, 0), Vector2(-76, 0)]), Color(0.18, 0.12, 0.1))
	_poly(PackedVector2Array([Vector2(24, -18), Vector2(72, -18), Vector2(76, 0), Vector2(20, 0)]), Color(0.18, 0.12, 0.1))
	# 躯干
	_poly(PackedVector2Array([Vector2(-68, -184), Vector2(68, -184), Vector2(84, -122), Vector2(58, -70), Vector2(0, -54), Vector2(-58, -70), Vector2(-84, -122)]), body)
	_poly(PackedVector2Array([Vector2(-46, -140), Vector2(46, -140), Vector2(50, -86), Vector2(0, -70), Vector2(-50, -86)]), body_hi, 3.0)
	draw_line(Vector2(-36, -126), Vector2(36, -126), skin_dark, 2.5, true)
	# 毛皮肩甲
	_circle(Vector2(-62, -174), 34, fur_hi, 4.0)
	_circle(Vector2(62, -174), 34, fur_hi, 4.0)
	_poly(PackedVector2Array([Vector2(-92, -172), Vector2(-74, -194), Vector2(-54, -180), Vector2(-46, -202), Vector2(-32, -178)]), fur, 2.5)
	_poly(PackedVector2Array([Vector2(32, -178), Vector2(46, -202), Vector2(58, -180), Vector2(78, -194), Vector2(92, -172)]), fur, 2.5)
	# 腰带
	_poly(PackedVector2Array([Vector2(-62, -96), Vector2(62, -96), Vector2(58, -70), Vector2(-58, -70)]), Color(0.24, 0.15, 0.11), 3.0)
	_poly(PackedVector2Array([Vector2(-10, -92), Vector2(10, -92), Vector2(8, -76), Vector2(-8, -76)]), Color(0.87, 0.82, 0.7), 2.0)
	# 左臂（前伸拳头）
	_capsule(Vector2(-66, -168), Vector2(-96, -128), 26, skin)
	_capsule(Vector2(-96, -128), Vector2(-88, -94), 22, skin)
	_circle(Vector2(-86, -82), 19, skin, 4.0)
	draw_line(Vector2(-98, -84), Vector2(-74, -84), skin_dark, 2.5, true)
	# 右臂（握斧，收拢在自身命中区内）
	_capsule(Vector2(66, -170), Vector2(86, -136), 26, skin)
	_capsule(Vector2(86, -136), Vector2(60, -108), 22, skin)
	# 颈与头
	_poly(PackedVector2Array([Vector2(-16, -180), Vector2(16, -180), Vector2(16, -158), Vector2(-16, -158)]), skin_dark, 2.0)
	_circle(Vector2(0, -214), 46, skin, 4.0)
	_rim_arc(Vector2(0, -214), 50, -58.0, 48.0)
	# 大角
	_poly(PackedVector2Array([Vector2(-30, -246), Vector2(-62, -284), Vector2(-76, -278), Vector2(-44, -238)]), Color(0.9, 0.84, 0.68), 3.5)
	_poly(PackedVector2Array([Vector2(30, -246), Vector2(62, -284), Vector2(76, -278), Vector2(44, -238)]), Color(0.9, 0.84, 0.68), 3.5)
	draw_line(Vector2(-52, -268), Vector2(-64, -277), Color(0.72, 0.64, 0.5), 3.0, true)
	draw_line(Vector2(52, -268), Vector2(64, -277), Color(0.72, 0.64, 0.5), 3.0, true)
	# 鬃毛
	_poly(PackedVector2Array([Vector2(-40, -236), Vector2(-20, -260), Vector2(-4, -242), Vector2(14, -262), Vector2(30, -238), Vector2(20, -226), Vector2(-26, -226)]), fur, 3.0)
	# 五官（怒）
	_eye(Vector2(-18, -218), Vector2.ZERO, Color(1.0, 0.62, 0.25), 6.0, 5.0)
	_eye(Vector2(18, -218), Vector2.ZERO, Color(1.0, 0.62, 0.25), 6.0, 5.0)
	draw_line(Vector2(-34, -230), Vector2(-8, -224), fur, 4.0, true)
	draw_line(Vector2(8, -224), Vector2(34, -230), fur, 4.0, true)
	draw_line(Vector2(-12, -208), Vector2(12, -208), skin_dark, 3.0, true)
	# 下颚 + 獠牙
	_poly(PackedVector2Array([Vector2(-22, -198), Vector2(22, -198), Vector2(16, -184), Vector2(-16, -184)]), skin_dark, 2.0)
	_poly(PackedVector2Array([Vector2(-16, -190), Vector2(-10, -190), Vector2(-13, -176)]), Color(0.96, 0.92, 0.8), 1.5)
	_poly(PackedVector2Array([Vector2(10, -190), Vector2(16, -190), Vector2(13, -176)]), Color(0.96, 0.92, 0.8), 1.5)
	# 战纹
	draw_line(Vector2(-26, -236), Vector2(-14, -228), Color(0.82, 0.26, 0.2), 4.0, true)
	draw_line(Vector2(26, -236), Vector2(14, -228), Color(0.82, 0.26, 0.2), 4.0, true)
	# 巨斧（斧头收在局部 x≈76 内，避开右侧狐妖命中区）
	_line(Vector2(48, -66), Vector2(54, -240), Color(0.33, 0.23, 0.15), 11.0)
	_poly(PackedVector2Array([Vector2(54, -242), Vector2(34, -276), Vector2(18, -260), Vector2(32, -240), Vector2(14, -224), Vector2(44, -216), Vector2(72, -230)]), Color(0.62, 0.64, 0.66), 4.0)
	draw_line(Vector2(34, -272), Vector2(22, -250), Color(0.9, 0.94, 0.97), 3.0, true)
	draw_line(Vector2(44, -220), Vector2(70, -232), Color(0.9, 0.94, 0.97), 3.0, true)
	draw_line(Vector2(34, -244), Vector2(54, -244), Color(0.4, 0.4, 0.43), 4.0, true)
	# 握斧手
	_circle(Vector2(56, -106), 15.0, skin, 3.5)

# ---------------------------------------------------------------- 狐妖·媚娘

func _draw_fox() -> void:
	var plum := Color(0.5, 0.22, 0.5)
	var plum_dark := Color(0.32, 0.12, 0.36)
	var pink := Color(0.92, 0.54, 0.68)
	var pink_hi := Color(1.0, 0.78, 0.86)
	var cream := Color(1.0, 0.9, 0.88)
	var hair := Color(0.78, 0.4, 0.56)
	var hair_hi := Color(0.95, 0.62, 0.72)
	# 双尾（身后）：一尾向上卷起，一尾绕向侧上方，避免对称成“手臂”。
	# 尾尖收进自身命中区（局部 x∈[-65,65]）；中段外扩但远离相邻单位命中区。
	_fluffy_tail(Vector2(-16, -84), Vector2(-86, -74), Vector2(-106, -140), Vector2(-58, -162), 21.0, 6.0, Color(0.78, 0.38, 0.58), cream)
	_fluffy_tail(Vector2(18, -86), Vector2(82, -64), Vector2(106, -128), Vector2(58, -150), 20.0, 6.0, Color(0.9, 0.52, 0.68), Color(1.0, 0.82, 0.9))
	# 后发
	_circle(Vector2(0, -212), 54, hair, 4.0)
	_poly(PackedVector2Array([Vector2(-48, -232), Vector2(-62, -170), Vector2(-72, -92), Vector2(-48, -74), Vector2(-32, -156), Vector2(-26, -204)]), hair)
	_poly(PackedVector2Array([Vector2(48, -232), Vector2(62, -170), Vector2(72, -92), Vector2(48, -74), Vector2(32, -156), Vector2(26, -204)]), hair)
	draw_line(Vector2(-56, -212), Vector2(-60, -106), hair_hi, 3.5, true)
	draw_line(Vector2(58, -210), Vector2(62, -108), hair_hi, 3.0, true)
	# 腿 / 足
	_capsule(Vector2(-16, -82), Vector2(-22, -14), 12, cream)
	_capsule(Vector2(16, -82), Vector2(24, -14), 12, cream)
	_poly(PackedVector2Array([Vector2(-34, -14), Vector2(-12, -14), Vector2(-10, 0), Vector2(-36, 0)]), plum_dark)
	_poly(PackedVector2Array([Vector2(12, -14), Vector2(34, -14), Vector2(36, 0), Vector2(10, 0)]), plum_dark)
	# 长裙
	_poly(PackedVector2Array([Vector2(-38, -156), Vector2(38, -156), Vector2(64, -66), Vector2(42, -20), Vector2(0, -30), Vector2(-42, -20), Vector2(-64, -66)]), plum)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -152), Vector2(38, -156), Vector2(64, -66), Vector2(42, -20), Vector2(14, -28)]), plum_dark)
	_poly(PackedVector2Array([Vector2(-16, -150), Vector2(16, -150), Vector2(24, -26), Vector2(-24, -26)]), pink, 2.5)
	draw_polyline(PackedVector2Array([Vector2(-52, -34), Vector2(-24, -24), Vector2(24, -24), Vector2(52, -34)]), GOLD_DARK, 3.0, true)
	# 上衣
	_poly(PackedVector2Array([Vector2(-36, -182), Vector2(36, -182), Vector2(40, -148), Vector2(-40, -148)]), plum)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -182), Vector2(36, -182), Vector2(40, -148), Vector2(10, -148)]), plum_dark)
	_poly(PackedVector2Array([Vector2(-24, -180), Vector2(0, -152), Vector2(24, -180), Vector2(12, -184), Vector2(0, -166), Vector2(-12, -184)]), cream, 2.0)
	# 金腰带 + 蝴蝶结
	_poly(PackedVector2Array([Vector2(-38, -150), Vector2(38, -150), Vector2(36, -134), Vector2(-36, -134)]), Color(0.85, 0.6, 0.26))
	_poly(PackedVector2Array([Vector2(-34, -142), Vector2(-52, -152), Vector2(-52, -132), Vector2(-34, -138)]), pink, 2.0)
	_poly(PackedVector2Array([Vector2(-34, -142), Vector2(-16, -154), Vector2(-16, -130), Vector2(-34, -136)]), pink_hi, 2.0)
	_circle(Vector2(-34, -142), 5.0, GOLD, 1.5)
	# 左袖 / 手
	_capsule(Vector2(-34, -172), Vector2(-64, -142), 18, plum)
	_capsule(Vector2(-64, -142), Vector2(-48, -118), 14, pink)
	_circle(Vector2(-45, -114), 7.5, SKIN, 2.5)
	# 右袖 / 持扇手
	_capsule(Vector2(34, -172), Vector2(58, -146), 18, plum)
	_capsule(Vector2(58, -146), Vector2(54, -126), 14, pink)
	# 颈与头
	_poly(PackedVector2Array([Vector2(-11, -168), Vector2(11, -168), Vector2(11, -150), Vector2(-11, -150)]), SKIN_SHADE, 2.0)
	_circle(Vector2(0, -206), 48, SKIN, 4.0)
	_rim_arc(Vector2(0, -206), 52, -60.0, 50.0)
	# 狐耳
	_poly(PackedVector2Array([Vector2(-44, -238), Vector2(-58, -292), Vector2(-18, -254)]), hair, 3.5)
	_poly(PackedVector2Array([Vector2(-43, -244), Vector2(-52, -280), Vector2(-26, -254)]), pink, 2.0)
	_poly(PackedVector2Array([Vector2(44, -238), Vector2(58, -292), Vector2(18, -254)]), hair, 3.5)
	_poly(PackedVector2Array([Vector2(43, -244), Vector2(52, -280), Vector2(26, -254)]), pink, 2.0)
	draw_line(Vector2(-57, -288), Vector2(-52, -278), cream, 3.0, true)
	draw_line(Vector2(57, -288), Vector2(52, -278), cream, 3.0, true)
	# 前发
	_poly(PackedVector2Array([Vector2(-50, -222), Vector2(-44, -250), Vector2(-20, -254), Vector2(0, -244), Vector2(22, -254), Vector2(46, -248), Vector2(51, -220), Vector2(32, -240), Vector2(16, -218), Vector2(2, -238), Vector2(-14, -216), Vector2(-32, -242)]), hair)
	_poly(PackedVector2Array([Vector2(-51, -228), Vector2(-58, -180), Vector2(-42, -150), Vector2(-34, -190)]), hair, 3.0)
	_poly(PackedVector2Array([Vector2(51, -228), Vector2(58, -180), Vector2(42, -150), Vector2(34, -190)]), hair, 3.0)
	draw_line(Vector2(-28, -246), Vector2(-12, -226), hair_hi, 3.0, true)
	draw_line(Vector2(26, -248), Vector2(12, -226), hair_hi, 3.0, true)
	# 金色花饰
	_circle(Vector2(36, -244), 7.0, GOLD, 2.0)
	for petal_angle: float in [0.0, 1.26, 2.51, 3.77, 5.03]:
		var petal := Vector2(36, -244) + Vector2(cos(petal_angle), sin(petal_angle)) * 9.0
		draw_circle(petal, 3.5, pink_hi)
	# 五官（媚）
	_eye(Vector2(-18, -208), Vector2.ZERO, Color(0.55, 0.32, 0.12), 5.8, 6.5)
	_eye(Vector2(18, -208), Vector2.ZERO, Color(0.55, 0.32, 0.12), 5.8, 6.5)
	draw_line(Vector2(-29, -216), Vector2(-36, -212), plum_dark, 2.6, true)
	draw_line(Vector2(29, -216), Vector2(36, -212), plum_dark, 2.6, true)
	draw_line(Vector2(-26, -196), Vector2(-19, -198), Color(0.72, 0.36, 0.45), 1.8, true)
	draw_line(Vector2(26, -196), Vector2(19, -198), Color(0.72, 0.36, 0.45), 1.8, true)
	_sly_mouth(Vector2(2, -180))
	_blush(Vector2(-28, -192), Color(1.0, 0.55, 0.65, 0.22))
	_blush(Vector2(28, -192), Color(1.0, 0.55, 0.65, 0.22))
	# 额间花钿
	draw_line(Vector2(0, -230), Vector2(0, -224), Color(0.85, 0.25, 0.4), 2.5, true)
	draw_line(Vector2(-4, -227), Vector2(4, -227), Color(0.85, 0.25, 0.4), 2.0, true)
	# 折扇（前景）
	_draw_fan(Vector2(64, -120))
	# 持扇手
	_circle(Vector2(64, -118), 8.0, SKIN, 2.5)

func _draw_fan(pivot: Vector2) -> void:
	var ribs := 6
	var radius := 54.0
	var colors: Array[Color] = [Color(0.95, 0.6, 0.72), Color(1.0, 0.84, 0.86)]
	for i in ribs:
		var a0 := deg_to_rad(-150.0 + float(i) * 20.0)
		var a1 := deg_to_rad(-150.0 + float(i + 1) * 20.0)
		var wedge := PackedVector2Array([pivot, pivot + Vector2(cos(a0), sin(a0)) * radius, pivot + Vector2(cos(a1), sin(a1)) * radius])
		_poly(wedge, colors[i % 2], 2.0)
	for i in ribs + 1:
		var angle := deg_to_rad(-150.0 + float(i) * 20.0)
		draw_line(pivot, pivot + Vector2(cos(angle), sin(angle)) * (radius + 2.0), GOLD_DARK, 2.0, true)
	draw_circle(pivot, 6.0, GOLD)
	draw_circle(pivot, 3.0, _plum_dark())


# ---------------------------------------------------------------- 绘制原语

func _circle(center: Vector2, radius: float, fill: Color, outline_width: float = 3.0) -> void:
	draw_circle(center, radius + outline_width, OUTLINE)
	draw_circle(center, radius, fill)

func _poly(points: PackedVector2Array, fill: Color, outline_width: float = 3.5) -> void:
	draw_colored_polygon(points, fill)
	if outline_width > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, OUTLINE, outline_width, true)

func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, OUTLINE, width + 4.0, true)
	draw_line(from, to, color, width, true)

func _capsule(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, OUTLINE, width + 5.0, true)
	draw_line(from, to, color, width, true)
	draw_circle(from, width * 0.5 + 2.5, OUTLINE)
	draw_circle(from, width * 0.5, color)
	draw_circle(to, width * 0.5 + 2.5, OUTLINE)
	draw_circle(to, width * 0.5, color)

func _ellipse(center: Vector2, rx: float, ry: float, fill: Color, count: int = 20) -> void:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, fill)

func _eye(pos: Vector2, look: Vector2 = Vector2.ZERO, color: Color = EYE_DARK, rx: float = 5.2, ry: float = 6.8) -> void:
	_ellipse(pos, rx, ry, color)
	draw_circle(pos + look + Vector2(-rx * 0.35, -ry * 0.38), maxf(1.2, rx * 0.32), Color(1, 1, 1, 0.95))

func _closed_eye(pos: Vector2, width: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([
		pos + Vector2(-width * 0.5, 0.0),
		pos + Vector2(0.0, -4.0),
		pos + Vector2(width * 0.5, 0.0),
	]), color, 2.6, true)

func _mouth_smile(center: Vector2, width: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([
		center + Vector2(-width * 0.5, -1.0),
		center + Vector2(0.0, 2.5),
		center + Vector2(width * 0.5, -1.0),
	]), color, 2.4, true)

func _sly_mouth(center: Vector2) -> void:
	draw_polyline(PackedVector2Array([
		center + Vector2(-7.0, 0.0),
		center + Vector2(2.0, 2.0),
		center + Vector2(8.0, -1.5),
	]), Color(0.62, 0.2, 0.28), 2.4, true)

func _blush(center: Vector2, color: Color = BLUSH) -> void:
	draw_circle(center, 7.0, color)

func _rim_arc(center: Vector2, radius: float, start_deg: float, end_deg: float) -> void:
	var points := PackedVector2Array()
	for i in 9:
		var angle := deg_to_rad(lerpf(start_deg, end_deg, float(i) / 8.0))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, Color(1.0, 0.87, 0.62, 0.34), 3.2, true)

func _fluffy_tail(start: Vector2, c1: Vector2, c2: Vector2, end: Vector2, r_start: float, r_end: float, color: Color, tip: Color) -> void:
	# 单一锥形带：宽度沿曲线单调收窄，尾尖用同带宽的浅色段叠染。
	# 相比一串圆形堆叠，不会出现“珠子链”式轮廓。
	var samples := 26
	var left: Array[Vector2] = []
	var right: Array[Vector2] = []
	for i in samples + 1:
		var t := float(i) / float(samples)
		var center := _cubic(start, c1, c2, end, t)
		var ahead := _cubic(start, c1, c2, end, minf(t + 0.02, 1.0))
		var behind := _cubic(start, c1, c2, end, maxf(t - 0.02, 0.0))
		var tangent := (ahead - behind).normalized()
		var perp := Vector2(-tangent.y, tangent.x)
		var radius := lerpf(r_start, r_end, t) * (1.0 + 0.1 * sin(t * PI))
		left.append(center + perp * radius)
		right.append(center - perp * radius)
	var outline := PackedVector2Array()
	for point in left:
		outline.append(point)
	for i in range(right.size() - 1, -1, -1):
		outline.append(right[i])
	outline.append(left[0])
	draw_polyline(outline, OUTLINE, 7.0, true)
	draw_colored_polygon(outline, color)
	draw_circle(start, r_start + 3.5, OUTLINE)
	draw_circle(start, r_start, color)

	var tip_points := PackedVector2Array()
	var tip_left: Array[Vector2] = []
	var tip_right: Array[Vector2] = []
	for i in samples + 1:
		var t := lerpf(0.78, 1.0, float(i) / float(samples))
		var center := _cubic(start, c1, c2, end, t)
		var ahead := _cubic(start, c1, c2, end, minf(t + 0.02, 1.0))
		var behind := _cubic(start, c1, c2, end, maxf(t - 0.02, 0.0))
		var tangent := (ahead - behind).normalized()
		var perp := Vector2(-tangent.y, tangent.x)
		var radius := lerpf(r_start, r_end, t) * (1.0 + 0.1 * sin(t * PI))
		tip_left.append(center + perp * radius)
		tip_right.append(center - perp * radius)
	for point in tip_left:
		tip_points.append(point)
	for i in range(tip_right.size() - 1, -1, -1):
		tip_points.append(tip_right[i])
	draw_colored_polygon(tip_points, tip)
	draw_circle(end, r_end + 3.5, OUTLINE)
	draw_circle(end, r_end, tip)

func _cubic(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)

func _plum_dark() -> Color:
	return Color(0.32, 0.12, 0.36)

func _build_bars() -> void:
	_info_root = Node2D.new()
	_info_root.name = "Info"
	add_child(_info_root)

	_name_label = Label.new()
	_name_label.position = Vector2(-100, NAME_Y)
	_name_label.size = Vector2(200, 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", FontUtil.cjk_font())
	_name_label.add_theme_font_size_override("font_size", 19)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.09, 0.9))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_info_root.add_child(_name_label)

	_bar_frame(Vector2(-BAR_WIDTH / 2 - 1, HP_Y - 1))
	_hp_bg = _bar(Color(0.06, 0.05, 0.08, 0.92), Vector2(-BAR_WIDTH / 2, HP_Y))
	_hp_trail = _bar(Color(1, 1, 1, 0.55), Vector2(-BAR_WIDTH / 2, HP_Y))
	_hp_fill = _bar(Color(0.36, 0.86, 0.42), Vector2(-BAR_WIDTH / 2, HP_Y))
	_bar_frame(Vector2(-BAR_WIDTH / 2 - 1, MP_Y - 1))
	_mp_bg = _bar(Color(0.06, 0.05, 0.08, 0.92), Vector2(-BAR_WIDTH / 2, MP_Y))
	_mp_fill = _bar(Color(0.4, 0.68, 1.0), Vector2(-BAR_WIDTH / 2, MP_Y))

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-BAR_WIDTH / 2, STATUS_Y)
	_status_row.size = Vector2(BAR_WIDTH, 20)
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.add_theme_constant_override("separation", 4)
	_info_root.add_child(_status_row)

	_selection = Polygon2D.new()
	_selection.polygon = _ellipse_points(58, 16)
	_selection.color = Color(1.0, 0.85, 0.2, 0.55)
	_selection.position = Vector2(0, 8)
	_selection.visible = false
	add_child(_selection)

	_target_arrow = Polygon2D.new()
	_target_arrow.polygon = PackedVector2Array([Vector2(-14, -432), Vector2(14, -432), Vector2(0, -408)])
	_target_arrow.color = Color(1.0, 0.85, 0.15)
	_target_arrow.visible = false
	_info_root.add_child(_target_arrow)

func _bar(color: Color, pos: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_info_root.add_child(rect)
	return rect

func _bar_frame(pos: Vector2) -> void:
	var frame := ColorRect.new()
	frame.color = Color(0.05, 0.04, 0.07, 0.9)
	frame.position = pos
	frame.size = Vector2(BAR_WIDTH + 2, BAR_HEIGHT + 2)
	_info_root.add_child(frame)

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.input_pickable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = CLICK_SIZE
	collision.shape = shape
	collision.position = CLICK_CENTER
	_click_area.add_child(collision)
	add_child(_click_area)
	_click_area.input_event.connect(_on_input_event)

func hit_rect() -> Rect2:
	# 世界坐标下的点击矩形（用于工具校验间距 / 与 HUD 面板的边界）。
	return Rect2(global_position + CLICK_CENTER - CLICK_SIZE * 0.5, CLICK_SIZE)

func appendage_points() -> Array[Vector2]:
	# 关键附属件的局部坐标点（绘制坐标系），供输入探针校验：
	# 必须落在自身 hit_rect() 内，且不落入任何相邻单位命中区。
	# 仅法师法球 / 狐妖双尾尖 / 妖将斧头有附属件需要校验。
	var points: Array[Vector2] = []
	match String(unit_id):
		"hero_mage":
			points.append(Vector2(52, -280))
		"boss_fox":
			points.append(Vector2(-58, -162))
			points.append(Vector2(58, -150))
		"boss_brute":
			points.append(Vector2(54, -244) * _art_scale)
	return points

func info_rect() -> Rect2:
	# 名字 / 血蓝条 / 状态徽章组成的悬浮信息带。
	return Rect2(global_position + Vector2(-100.0, STATUS_Y + _info_offset_y), Vector2(200.0, 60.0))

func bubble_anchor() -> Vector2:
	# 喊招气泡尾巴落在状态行上方，避免盖住名字与状态徽章。
	return get_global_transform_with_canvas().origin + Vector2(0, STATUS_Y + _info_offset_y - BUBBLE_GAP)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _ellipse_points(rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func set_hp(value: int, animate: bool = true) -> void:
	if unit_state == null:
		return
	var ratio := clampf(float(value) / float(maxi(1, unit_state.data.max_hp)), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	_hp_fill.size.x = target_width
	if animate:
		var tween := create_tween()
		tween.tween_property(_hp_trail, "size:x", target_width, 0.35).set_delay(0.15)
	else:
		_hp_trail.size.x = target_width

func set_mp(value: int, animate: bool = true) -> void:
	if unit_state == null:
		return
	var ratio := clampf(float(value) / float(maxi(1, unit_state.data.max_mp)), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	if animate:
		create_tween().tween_property(_mp_fill, "size:x", target_width, 0.25)
	else:
		_mp_fill.size.x = target_width

func set_statuses(statuses: Array[StatusInstance]) -> void:
	for child in _status_row.get_children():
		child.queue_free()
	for status in statuses:
		var icon := VisualCatalog.status_icon(status.data.id)
		if icon != null:
			var texture_rect := TextureRect.new()
			texture_rect.texture = icon
			texture_rect.custom_minimum_size = Vector2(22, 22)
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.tooltip_text = status.data.display_name
			texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			_status_row.add_child(texture_rect)
			continue
		var glyph := _status_glyph(status)
		var badge := UiStyle.status_badge(glyph, status.data.display_color, 20, 12)
		badge.tooltip_text = status.data.display_name
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		_status_row.add_child(badge)

func _status_glyph(status: StatusInstance) -> String:
	match String(status.data.id):
		"poison":
			return "毒"
		"armor_down":
			return "破"
		"war_cry":
			return "吼"
		"defending":
			return "御"
		"sealed":
			return "封"
		_:
			var display := status.data.display_name
			return display.substr(0, 1) if not display.is_empty() else "?"

func set_selected(value: bool) -> void:
	_selection.visible = value
	if value:
		_position_glow()

func set_targetable(value: bool) -> void:
	_target_arrow.visible = value

func _position_glow() -> void:
	_selection.modulate.a = 0.4 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))

func _start_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	position = home_position
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", home_position.y - 4.0, 0.9).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(self, "position:y", home_position.y, 0.9).set_trans(Tween.TRANS_SINE)

func stop_animations() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	position = home_position
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE

func lunge_to(target_position: Vector2) -> void:
	stop_animations()
	var direction := signf(target_position.x - home_position.x)
	var destination := target_position - Vector2(direction * 120.0, 0)
	var tween := create_tween()
	tween.tween_property(self, "position", destination, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func reset_pose() -> void:
	stop_animations()
	_start_idle()

func cast_pose() -> void:
	stop_animations()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.18)
	tween.parallel().tween_property(self, "modulate", Color(1.4, 1.6, 2.0), 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.2)
	await tween.finished
	if unit_state != null and unit_state.is_alive():
		_start_idle()

func hurt() -> void:
	stop_animations()
	var base := position
	var knock := base + Vector2(14.0 if is_ally else -14.0, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	tween.parallel().tween_property(self, "position", knock, 0.08)
	tween.tween_property(self, "position", base, 0.12)
	await tween.finished
	if unit_state == null or unit_state.is_alive():
		_start_idle()

func die() -> void:
	stop_animations()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(self, "rotation", deg_to_rad(-70.0), 0.35)
	tween.parallel().tween_property(self, "position:y", home_position.y + 34.0, 0.35)
	await tween.finished
	visible = false
