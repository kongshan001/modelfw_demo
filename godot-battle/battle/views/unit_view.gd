class_name UnitView
extends Node2D

signal clicked(view: UnitView)
signal hovered(view: UnitView)

# 原创程序化 Q 版角色。所有角色共用同一套描边 / 高光 / 脸部语言，
# 只在轮廓、配色、发型与武器上区分职业与阵营。
# 设计坐标系：脚底 y=0，向上为负；普通角色身体约 250–270px、含武器约 300px，
# 小妖约 225px，妖将约 300px（draw_set_transform 缩放；名字/血条文字不缩放，
# 只随剪影高度移动锚点，命中区按缩小后的身体调整）。
# 全局 BASE_ART_SCALE 把角色压到约 2/3（170px 上下，贴合梦幻 10–14% 屏高）；阵型 depth 再乘在美术层上。
# 镜头位于我方背后：我方 view=back 叠加后脑/袍背，敌方 view=front 保持正面。

const BASE_ART_SCALE := 0.66
const BAR_WIDTH := 96.0
const BAR_HEIGHT := 8.0
const HP_Y := -225.0
const MP_Y := -214.0
const NAME_Y := -253.0
const STATUS_Y := -277.0
const CLICK_SIZE := Vector2(96, 208)
const CLICK_CENTER := Vector2(0, -100)
const BUBBLE_GAP := 20.0
# 信息带锚点：head_top=-256 的标准角色在 0.75 全局缩放后头顶约 -192。
# 锚点再下移 4px（-196），为放大后的敌方后排信息带避开左上出手顺序条留余量。
const INFO_BASE_HEAD_TOP := -196.0

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
var _target_arrow_outline: Polygon2D
var _click_area: Area2D
var _click_shape: CollisionShape2D
var _click_rect: RectangleShape2D
var _idle_tween: Tween
var _body_color := Color(0.35, 0.6, 1.0)
var _visual_rng := RandomNumberGenerator.new()
var _art_scale := 1.0
var _has_texture := false
var _info_offset_y := 0.0
var _formation_depth := 1.0
var _facing := 1
var _art_view := "front"
var _sprite_base_scale := 1.0
var _sprite_base_position := Vector2.ZERO

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
	_refresh_info_anchor()
	_name_label.text = unit.data.display_name
	_apply_click_bounds()
	_apply_visual_override()
	_apply_shadow_scale()
	queue_redraw()
	refresh_from_state(unit)
	visible = true
	_start_idle()

func apply_formation(depth: float, facing: int, view: String = "front") -> void:
	# 只影响美术层：名字/血条字号与命中区尺寸不变、不镜像；
	# 信息条/气泡仅按新剪影高度移动锚点，命中区不随 depth 缩放。
	# view 决定正面/背影造型（我方 back / 敌方 front），同样只改美术层。
	_formation_depth = maxf(0.05, depth)
	_facing = -1 if facing < 0 else 1
	var normalized_view := "back" if view == "back" else "front"
	var view_changed := normalized_view != _art_view
	_art_view = normalized_view
	if view_changed:
		_apply_visual_override()
	_refresh_info_anchor()
	_apply_shadow_scale()
	_apply_sprite_formation()
	queue_redraw()

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

func _refresh_info_anchor() -> void:
	# 信息带随造型缩放/深度移动：底部始终贴在该单位剪影头顶上方 14px。
	if _info_root == null:
		return
	_info_offset_y = _silhouette_top() * _art_scale * BASE_ART_SCALE * _formation_depth - INFO_BASE_HEAD_TOP
	_info_root.position = Vector2(0, _info_offset_y)

func _silhouette_top() -> float:
	# 未缩放设计坐标中的剪影最高点（不含手持武器，避免法杖/长剑把血条顶得过高）。
	match String(unit_id):
		"mob_a", "mob_b":
			return -246.0
		"boss_brute":
			return -284.0
		"boss_fox":
			return -292.0
		"hero_healer":
			return -276.0
		_:
			return -256.0

func _apply_shadow_scale() -> void:
	if _shadow == null:
		return
	var wide := 1.25 if String(unit_id) == "boss_brute" else 1.08
	var scale_value := _art_scale * BASE_ART_SCALE * _formation_depth
	_shadow.scale = Vector2(scale_value * wide, scale_value)

func _apply_visual_override() -> void:
	if _sprite == null or unit_state == null or unit_state.data == null:
		return
	var sprite_info := VisualCatalog.unit_sprite(unit_id, _art_view)
	var path := String(sprite_info.get("path", "")).strip_edges()
	var scale_value := float(sprite_info.get("scale", 1.0))
	if not sprite_info.has("scale") and unit_state.data.visual_scale > 0.0:
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
	_sprite_base_scale = scale_value
	_sprite_base_position = Vector2(0, -texture.get_height() * 0.5 * scale_value)
	var offset: Variant = sprite_info.get("offset", [])
	if offset is Array and offset.size() >= 2:
		_sprite_base_position += Vector2(float(offset[0]), float(offset[1]))
	_sprite.visible = true
	_has_texture = true
	_apply_sprite_formation()
	queue_redraw()

func _apply_sprite_formation() -> void:
	if _sprite == null or not _has_texture:
		return
	var scale_value := _sprite_base_scale * BASE_ART_SCALE * _formation_depth
	_sprite.scale = Vector2(scale_value * _facing, scale_value)
	_sprite.position = Vector2(_sprite_base_position.x * _facing, _sprite_base_position.y) * BASE_ART_SCALE

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
	var art_scale_value := _art_scale * BASE_ART_SCALE * _formation_depth
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(art_scale_value * _facing, art_scale_value))
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
	if _art_view == "back":
		_draw_back_overlay()

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
	# 剑尖略收（116→104），避免剑刃探入右上角「逃跑」按钮。
	_poly(PackedVector2Array([Vector2(47, -121), Vector2(59, -126), Vector2(104, -300)]), Color(0.83, 0.89, 0.97), 3.0)
	draw_line(Vector2(53, -129), Vector2(96, -292), Color(1, 1, 1, 0.9), 2.2, true)
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
	# 法杖（身后侧方；杖身收在披背长发之外，背影下仍清晰可见）
	_line(Vector2(66, -8), Vector2(74, -264), Color(0.3, 0.22, 0.17), 7.0)
	for band_y: float in [-80.0, -158.0, -232.0]:
		draw_line(Vector2(68, band_y), Vector2(80, band_y + 3), GOLD_DARK, 4.0, true)
	draw_circle(Vector2(74, -280), 34.0, Color(0.5, 0.9, 1.0, 0.09))
	draw_circle(Vector2(74, -280), 24.0, Color(0.55, 0.93, 1.0, 0.16))
	_circle(Vector2(74, -280), 15.0, Color(0.58, 0.92, 1.0), 3.0)
	draw_circle(Vector2(70, -285), 5.0, Color(1, 1, 1, 0.85))
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
	_capsule(Vector2(34, -166), Vector2(66, -142), 16, teal)
	_capsule(Vector2(66, -142), Vector2(64, -120), 12, cream)
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
	for spark: Vector2 in [Vector2(54, -304), Vector2(84, -294), Vector2(56, -252), Vector2(84, -262)]:
		_circle(spark, 3.0, Color(0.75, 1.0, 1.0, 0.85), 1.0)
	# 握杖手
	_circle(Vector2(64, -118), 8.5, SKIN, 2.5)

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

# ---------------------------------------------------------------- 我方背影层
# 镜头在我方背后：先按正面画完（保留腿、侧臂、武器），再叠加背影层。
# 顺序：发带/饰物（最靠后）→ 袍背/腰带 → 后脑头发 → 发带/发簪（在头发上）。
# 后脑发团必须盖住眉眼与嘴；袍背面板盖住正面交领；再补背缝/背结/背带。

func _draw_back_overlay() -> void:
	match String(unit_id):
		"hero_swordsman":
			_draw_swordsman_back()
		"hero_mage":
			_draw_mage_back()
		"hero_healer":
			_draw_healer_back()

func _draw_swordsman_back() -> void:
	var blue := Color(0.22, 0.43, 0.79)
	var blue_dark := Color(0.13, 0.27, 0.55)
	var blue_light := Color(0.49, 0.7, 0.96)
	var hair := Color(0.12, 0.14, 0.24)
	var hair_hi := Color(0.27, 0.31, 0.48)
	# 蓝色发带尾（两条窄飘带，先画，根部随后被头发/发带压住）
	_poly(PackedVector2Array([Vector2(-24, -224), Vector2(-56, -210), Vector2(-76, -184), Vector2(-86, -156), Vector2(-72, -152), Vector2(-62, -178), Vector2(-44, -200), Vector2(-20, -212)]), blue_dark, 2.5)
	draw_line(Vector2(-30, -212), Vector2(-66, -168), blue_light, 2.5, true)
	_poly(PackedVector2Array([Vector2(24, -224), Vector2(58, -208), Vector2(78, -182), Vector2(88, -158), Vector2(74, -154), Vector2(62, -180), Vector2(44, -200), Vector2(20, -212)]), blue_dark, 2.5)
	draw_line(Vector2(30, -212), Vector2(68, -170), blue_light, 2.5, true)
	# 袍背：上衣后片（盖住正面白色交领）
	_poly(PackedVector2Array([Vector2(-37, -180), Vector2(37, -180), Vector2(44, -146), Vector2(-44, -146)]), blue)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -180), Vector2(37, -180), Vector2(44, -146), Vector2(10, -146)]), blue_dark)
	draw_line(Vector2(0, -176), Vector2(0, -148), blue_dark, 2.4, true)
	# 袍背：下摆后片（盖住正面白色中缝）
	_poly(PackedVector2Array([Vector2(-34, -152), Vector2(34, -152), Vector2(48, -62), Vector2(30, -42), Vector2(0, -36), Vector2(-30, -42), Vector2(-48, -62)]), blue)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -150), Vector2(34, -152), Vector2(48, -62), Vector2(30, -42), Vector2(12, -40)]), blue_dark)
	draw_line(Vector2(0, -150), Vector2(0, -42), blue_dark, 2.4, true)
	draw_polyline(PackedVector2Array([Vector2(-40, -48), Vector2(-14, -42), Vector2(14, -42), Vector2(40, -48)]), GOLD_DARK, 2.5, true)
	# 背腰带 + 背结 + 垂带
	_poly(PackedVector2Array([Vector2(-40, -140), Vector2(40, -140), Vector2(38, -122), Vector2(-38, -122)]), blue_dark, 2.4)
	_poly(PackedVector2Array([Vector2(-9, -139), Vector2(9, -139), Vector2(8, -123), Vector2(-8, -123)]), blue_light, 2.0)
	draw_line(Vector2(0, -140), Vector2(0, -122), blue_dark, 1.6, true)
	draw_line(Vector2(-8, -137), Vector2(-21, -112), blue_dark, 5.0, true)
	draw_line(Vector2(8, -137), Vector2(21, -112), blue_dark, 5.0, true)
	# 后脑短发：整圆发团盖住面部，下缘补后颈发尾
	_circle(Vector2(0, -202), 54, hair, 4.0)
	_poly(PackedVector2Array([Vector2(-46, -230), Vector2(-41, -176), Vector2(-26, -150), Vector2(0, -143), Vector2(26, -150), Vector2(41, -176), Vector2(46, -230)]), hair, 3.0)
	draw_line(Vector2(-30, -240), Vector2(-18, -162), hair_hi, 3.0, true)
	draw_line(Vector2(28, -242), Vector2(16, -164), hair_hi, 2.6, true)
	draw_line(Vector2(0, -234), Vector2(0, -150), Color(0.08, 0.09, 0.16), 1.6, true)
	# 后脑发带 + 中心结
	_poly(PackedVector2Array([Vector2(-52, -228), Vector2(-24, -235), Vector2(24, -235), Vector2(52, -228), Vector2(50, -216), Vector2(0, -224), Vector2(-50, -216)]), blue_dark, 2.5)
	draw_line(Vector2(-48, -223), Vector2(48, -223), blue_light, 2.0, true)
	_circle(Vector2(0, -226), 6.5, blue_dark, 2.0)
	_circle(Vector2(0, -226), 3.0, blue_light, 1.5)

func _draw_mage_back() -> void:
	var teal := Color(0.12, 0.52, 0.55)
	var teal_dark := Color(0.07, 0.3, 0.4)
	var rust := Color(0.85, 0.56, 0.44)
	var hair := Color(0.11, 0.18, 0.28)
	var hair_hi := Color(0.22, 0.38, 0.5)
	# 袍背：上衣后片 + 下摆后片（盖住正面米色交领/中缝）
	_poly(PackedVector2Array([Vector2(-36, -180), Vector2(36, -180), Vector2(42, -148), Vector2(-42, -148)]), teal)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -180), Vector2(36, -180), Vector2(42, -148), Vector2(10, -148)]), teal_dark)
	_poly(PackedVector2Array([Vector2(-30, -150), Vector2(30, -150), Vector2(40, -56), Vector2(28, -42), Vector2(0, -46), Vector2(-28, -42), Vector2(-40, -56)]), teal)
	draw_polyline(PackedVector2Array([Vector2(-38, -50), Vector2(-12, -44), Vector2(12, -44), Vector2(38, -50)]), GOLD_DARK, 2.5, true)
	# 后腰带（长发会盖住中间，只露出两侧）
	_poly(PackedVector2Array([Vector2(-40, -143), Vector2(40, -143), Vector2(38, -127), Vector2(-38, -127)]), rust, 2.4)
	_circle(Vector2(-36, -135), 5.0, rust, 1.5)
	_circle(Vector2(36, -135), 5.0, rust, 1.5)
	# 后脑发团 + 披背长发（盖住面部、颈与正面交领）
	_circle(Vector2(0, -204), 54, hair, 4.0)
	_poly(PackedVector2Array([
		Vector2(-50, -244), Vector2(-56, -214), Vector2(-52, -176), Vector2(-46, -138),
		Vector2(-38, -104), Vector2(-26, -78), Vector2(-12, -62), Vector2(0, -58),
		Vector2(12, -62), Vector2(26, -78), Vector2(38, -104), Vector2(46, -138),
		Vector2(52, -176), Vector2(56, -214), Vector2(50, -244),
	]), hair, 3.5)
	draw_line(Vector2(-30, -236), Vector2(-42, -132), hair_hi, 3.0, true)
	draw_line(Vector2(-10, -238), Vector2(-18, -92), hair_hi, 2.2, true)
	draw_line(Vector2(14, -238), Vector2(20, -94), hair_hi, 2.2, true)
	draw_line(Vector2(30, -240), Vector2(40, -128), hair_hi, 2.6, true)
	draw_line(Vector2(0, -236), Vector2(2, -92), Color(0.07, 0.12, 0.2), 1.6, true)
	draw_polyline(PackedVector2Array([Vector2(-26, -78), Vector2(-10, -64), Vector2(10, -64), Vector2(26, -78)]), hair_hi, 2.2, true)
	# 发尾错层，避免整片长发读成斗篷
	draw_line(Vector2(-32, -112), Vector2(-22, -76), Color(0.08, 0.14, 0.23), 2.0, true)
	draw_line(Vector2(34, -116), Vector2(24, -80), Color(0.08, 0.14, 0.23), 2.0, true)
	# 金色发簪（背视横簪 + 簪头）
	_line(Vector2(-36, -232), Vector2(36, -238), GOLD, 3.0)
	_circle(Vector2(38, -238), 4.0, GOLD, 2.0)
	draw_circle(Vector2(38, -238), 2.0, Color(1, 1, 1, 0.8))
	draw_line(Vector2(-38, -230), Vector2(-46, -225), GOLD, 2.0, true)
	# 背腰带垂饰（发侧露出）
	draw_line(Vector2(-34, -132), Vector2(-42, -100), rust, 4.0, true)
	draw_line(Vector2(34, -132), Vector2(42, -102), rust, 4.0, true)

func _draw_healer_back() -> void:
	var cream := Color(0.93, 0.96, 0.9)
	var green := Color(0.36, 0.62, 0.42)
	var green_dark := Color(0.22, 0.43, 0.3)
	var hair := Color(0.44, 0.29, 0.22)
	var hair_hi := Color(0.63, 0.44, 0.32)
	# 袍背：米色后片 + 绿色侧缘（盖住正面绿色交领）
	_poly(PackedVector2Array([Vector2(-37, -180), Vector2(37, -180), Vector2(42, -146), Vector2(-42, -146)]), cream)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -180), Vector2(37, -180), Vector2(42, -146), Vector2(10, -146)]), Color(0.87, 0.92, 0.83))
	_poly(PackedVector2Array([Vector2(-38, -158), Vector2(-24, -158), Vector2(-28, -48), Vector2(-44, -50), Vector2(-50, -58)]), green, 2.5)
	_poly(PackedVector2Array([Vector2(38, -158), Vector2(24, -158), Vector2(28, -48), Vector2(44, -50), Vector2(50, -58)]), green, 2.5)
	_poly(PackedVector2Array([Vector2(-32, -156), Vector2(32, -156), Vector2(44, -58), Vector2(28, -42), Vector2(0, -46), Vector2(-28, -42), Vector2(-44, -58)]), cream)
	draw_polyline(PackedVector2Array([Vector2(-38, -48), Vector2(-14, -43), Vector2(14, -43), Vector2(38, -48)]), green_dark, 2.5, true)
	# 背腰带 + 背结（盖住正面绿腰带）
	_poly(PackedVector2Array([Vector2(-40, -142), Vector2(40, -142), Vector2(38, -126), Vector2(-38, -126)]), green, 2.4)
	draw_line(Vector2(-32, -134), Vector2(32, -134), Color(0.85, 0.93, 0.7), 2.0, true)
	_circle(Vector2(0, -134), 6.0, green_dark, 1.8)
	draw_line(Vector2(-3, -130), Vector2(-10, -108), green_dark, 4.0, true)
	draw_line(Vector2(3, -130), Vector2(10, -108), green_dark, 4.0, true)
	# 药囊背带（斜跨后背，接到左胯药囊）+ 扣环
	_line(Vector2(34, -176), Vector2(-30, -112), Color(0.36, 0.25, 0.16), 7.0)
	draw_line(Vector2(30, -171), Vector2(-27, -115), Color(0.6, 0.44, 0.27), 2.4, true)
	_poly(PackedVector2Array([Vector2(-8, -146), Vector2(3, -150), Vector2(6, -140), Vector2(-5, -136)]), GOLD_DARK, 1.5)
	draw_line(Vector2(-30, -112), Vector2(-40, -102), Color(0.36, 0.25, 0.16), 5.0, true)
	# 后脑发团 + 后颈发尾（盖住面部与正面衣领）
	_circle(Vector2(0, -202), 53, hair, 4.0)
	_poly(PackedVector2Array([Vector2(-46, -228), Vector2(-41, -176), Vector2(-26, -148), Vector2(0, -140), Vector2(26, -148), Vector2(41, -176), Vector2(46, -228)]), hair, 3.0)
	draw_line(Vector2(-24, -238), Vector2(-16, -162), hair_hi, 3.0, true)
	draw_line(Vector2(22, -240), Vector2(14, -164), hair_hi, 2.6, true)
	# 背视发髻（盖住正面发髻）：突出于后脑发团之上 + 绿色发圈 + 金簪
	_circle(Vector2(0, -256), 20, hair, 3.5)
	draw_arc(Vector2(0, -256), 13.0, deg_to_rad(-150.0), deg_to_rad(40.0), 14, hair_hi, 2.5, true)
	draw_line(Vector2(-18, -242), Vector2(-8, -238), green, 4.0, true)
	draw_line(Vector2(18, -242), Vector2(8, -238), green, 4.0, true)
	draw_line(Vector2(-9, -240), Vector2(9, -240), green_dark, 2.0, true)
	_line(Vector2(-24, -260), Vector2(24, -268), GOLD, 3.0)
	_circle(Vector2(26, -268), 4.0, GOLD, 2.0)
	draw_circle(Vector2(26, -268), 2.0, Color(1, 1, 1, 0.8))
	_circle(Vector2(-26, -260), 2.6, GOLD, 1.5)

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
		# 狼牙棒：面向右时收在身体右侧，棒头不探入医师命中区（+1 阵型下 x 上限约 855）。
		_line(Vector2(47, -116), Vector2(47, -236), Color(0.34, 0.24, 0.16), 8.0)
		_circle(Vector2(47, -250), 16.0, Color(0.4, 0.29, 0.19), 3.5)
		for spike: Vector2 in [Vector2(33, -254), Vector2(45, -272), Vector2(60, -263), Vector2(62, -242), Vector2(47, -232)]:
			_poly(PackedVector2Array([spike + Vector2(-3, 1), spike + Vector2(3, 1), spike * 1.06 + Vector2(0, -10)]), Color(0.72, 0.66, 0.56), 1.5)
		_circle(Vector2(47, -250), 5.0, leather_hi, 1.5)
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
	# 左臂（握拳贴腰，拳心收在自身命中区内）
	_capsule(Vector2(-66, -168), Vector2(-90, -132), 26, skin)
	_capsule(Vector2(-90, -132), Vector2(-68, -100), 22, skin)
	_circle(Vector2(-56, -82), 19, skin, 4.0)
	draw_line(Vector2(-68, -84), Vector2(-44, -84), skin_dark, 2.5, true)
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

	# 单一目标箭头：深色描边 + 金色主体，只显示在当前选中的目标头顶。
	_target_arrow_outline = Polygon2D.new()
	_target_arrow_outline.polygon = PackedVector2Array([Vector2(-21, -340), Vector2(21, -340), Vector2(0, -298)])
	_target_arrow_outline.color = Color(0.09, 0.06, 0.07, 0.85)
	_target_arrow_outline.visible = false
	_info_root.add_child(_target_arrow_outline)
	_target_arrow = Polygon2D.new()
	_target_arrow.polygon = PackedVector2Array([Vector2(-16, -333), Vector2(16, -333), Vector2(0, -305)])
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
	_click_shape = CollisionShape2D.new()
	_click_rect = RectangleShape2D.new()
	_click_shape.shape = _click_rect
	_click_area.add_child(_click_shape)
	add_child(_click_area)
	_click_area.input_event.connect(_on_input_event)
	_click_area.mouse_entered.connect(_on_mouse_entered)
	_apply_click_bounds()

func _apply_click_bounds() -> void:
	if _click_rect == null:
		return
	_click_rect.size = CLICK_SIZE
	_click_shape.position = CLICK_CENTER

func hit_rect() -> Rect2:
	# 世界坐标下的点击矩形（用于工具校验间距 / 与 HUD 面板的边界）。
	# 阵型只缩放美术层，命中区保持身体大小（96×208）且不镜像。
	return Rect2(global_position + CLICK_CENTER - CLICK_SIZE * 0.5, CLICK_SIZE)

func visual_scale() -> float:
	# 程序化绘制的整体缩放（_draw 内 draw_set_transform 使用），含全局缩放与阵型深度。
	return _art_scale * BASE_ART_SCALE * _formation_depth

func art_view() -> String:
	# 当前美术视图：back=我方背影 / front=敌方正面。
	return _art_view

func appendage_points() -> Array[Vector2]:
	# 关键附属件的局部坐标点（已按 _facing 镜像，未乘 visual_scale()），供输入探针校验：
	# 探针按 visual_scale() 缩放后，附属件允许伸出自身命中区，但不得落入邻居命中区。
	# 法师法球 / 狐妖双尾尖与右尾外缘 / 妖将左拳与斧刃外缘 / 妖兵乙毒矛头 /
	# 妖兵甲棒头外缘 / 剑客剑尖。
	var points: Array[Vector2] = []
	match String(unit_id):
		"hero_swordsman":
			points.append(Vector2(104, -300))
		"hero_mage":
			points.append(Vector2(74, -280))
		"boss_fox":
			points.append(Vector2(-58, -162))
			points.append(Vector2(58, -150))
			points.append(Vector2(98, -100))
		"boss_brute":
			points.append(Vector2(-56, -82))
			points.append(Vector2(54, -244))
			points.append(Vector2(72, -230))
		"mob_b":
			points.append(Vector2(111, -292))
		"mob_a":
			points.append(Vector2(66.5, -250))
	if _facing < 0:
		for index in points.size():
			points[index] = Vector2(-points[index].x, points[index].y)
	return points

func info_rect() -> Rect2:
	# 名字 / 血蓝条 / 状态徽章组成的悬浮信息带。
	return Rect2(global_position + Vector2(-100.0, STATUS_Y + _info_offset_y), Vector2(200.0, 74.0))

func bubble_anchor() -> Vector2:
	# 喊招气泡尾巴落在状态行上方，避免盖住名字与状态徽章。
	return get_global_transform_with_canvas().origin + Vector2(0, STATUS_Y + _info_offset_y - BUBBLE_GAP)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _on_mouse_entered() -> void:
	hovered.emit(self)

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

func set_target_highlight(value: bool) -> void:
	_target_arrow.visible = value
	_target_arrow_outline.visible = value

func is_target_highlighted() -> bool:
	return _target_arrow != null and _target_arrow.visible

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
	var windup := home_position - Vector2(direction * 12.0, 0)
	var tween := create_tween()
	# 预备：后拉半步并压扁蓄力，再向前冲出；冲势保留一点横向拉伸。
	tween.tween_property(self, "position", windup, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.92, 1.06), 0.08)
	tween.tween_property(self, "position", destination, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(1.05, 0.95), 0.18)
	await tween.finished

func return_pose() -> void:
	# 收势归位：先越过家门半步再收住，避免瞬移回位。
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	if position.distance_to(home_position) < 1.0:
		reset_pose()
		return
	var overshoot := home_position - Vector2(signf(position.x - home_position.x) * 16.0, 0)
	var tween := create_tween()
	tween.tween_property(self, "position", overshoot, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.98, 1.02), 0.10)
	tween.tween_property(self, "position", home_position, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.05)
	await tween.finished
	if unit_state == null or unit_state.is_alive():
		_start_idle()

func reset_pose() -> void:
	stop_animations()
	_start_idle()

func cast_pose() -> void:
	stop_animations()
	var tween := create_tween()
	# 蓄力：短暂压扁/后坐，再亮起施法闪光。
	tween.tween_property(self, "scale", Vector2(0.94, 1.06), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(0.9, 0.95, 1.05), 0.08)
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
