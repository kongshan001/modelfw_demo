class_name ShadowCaster
extends Node2D

# 一棵树 / 一块石头的地面投影。投影分成两段：
#   1) 树干：从树根沿影向延伸 trunk_height / tan(elev)；
#   2) 树冠：把树冠剪影的底边接在树干影子的末端，沿影向拉伸
#      crown_length = total_length - trunk_length，所以永远不会悬空、断脚。
# 总影长 = visual_height / tan(elev)，并 clamp 到 visual_height * cap_multiple。
# 影向 = -太阳平面向量（取反）。所有姿态只由节点变换实现，不改贴图。

var display_name := "shadow"
var visual_height := 100.0
var trunk_height := 30.0
var cap_multiple := 2.0
var direction := Vector2.DOWN
var raw_length := 0.0
var total_length := 0.0
var trunk_length := 0.0
var crown_length := 0.0
var capped := false
var elevated_clamped := 0.0

var shadow_trunk: Sprite2D
var shadow_crown: Sprite2D
var contact: Sprite2D

var _trunk_tex_h := 64.0
var _crown_tex_h := 1.0
var _enabled := true


func setup(spec: Dictionary, shadow_material: ShaderMaterial, contact_tex: Texture2D) -> void:
	display_name = spec.get("name", "shadow")
	position = spec.get("base", Vector2.ZERO)
	visual_height = float(spec.get("height", 100.0))
	trunk_height = float(spec.get("trunk_height", 0.0))
	cap_multiple = float(spec.get("cap", 2.0))
	z_index = int(spec.get("z", 0))

	var crown_tex: Texture2D = _texture_from(spec["crown_shadow"])
	_crown_tex_h = maxf(float(crown_tex.get_height()), 1.0)

	if trunk_height > 0.0:
		var trunk_img: Image = spec["trunk_shadow"]
		var trunk_tex := ImageTexture.create_from_image(trunk_img)
		_trunk_tex_h = maxf(float(trunk_tex.get_height()), 1.0)
		shadow_trunk = Sprite2D.new()
		shadow_trunk.name = "TrunkShadow"
		shadow_trunk.texture = trunk_tex
		shadow_trunk.centered = false
		shadow_trunk.offset = Vector2(-float(trunk_img.get_width()) * 0.5, 0.0)
		shadow_trunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow_trunk.material = shadow_material
		add_child(shadow_trunk)

	shadow_crown = Sprite2D.new()
	shadow_crown.name = "CrownShadow"
	shadow_crown.texture = crown_tex
	shadow_crown.centered = false
	shadow_crown.offset = Vector2(-float(crown_tex.get_width()) * 0.5,
			-float(crown_tex.get_height()))
	shadow_crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_crown.material = shadow_material
	add_child(shadow_crown)

	contact = Sprite2D.new()
	contact.name = "ContactShadow"
	contact.texture = contact_tex
	contact.centered = true
	contact.position = Vector2(0.0, -1.0)
	var contact_scale := float(spec.get("contact_scale", 1.0))
	contact.scale = Vector2(contact_scale, contact_scale)
	contact.modulate = Color(1.0, 1.0, 1.0, 0.52)
	contact.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	contact.material = shadow_material
	add_child(contact)


func _texture_from(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	var img: Image = value
	return ImageTexture.create_from_image(img)


func update_sun(hour: float, show: bool) -> void:
	_enabled = show
	# 即使当前隐藏也要更新数学姿态：否则关闭阴影时拖动时间轴，
	# 再打开会把旧时刻的影子“冻结”在屏幕上。
	var elev := clampf(SunModel.elevation_deg(hour),
			SunModel.MIN_TAN_ELEVATION, SunModel.MAX_TAN_ELEVATION)
	elevated_clamped = elev
	var tangent := tan(deg_to_rad(elev))
	raw_length = visual_height / tangent
	total_length = minf(raw_length, visual_height * cap_multiple)
	capped = raw_length > total_length + 0.001
	direction = SunModel.shadow_direction(hour)

	trunk_length = 0.0
	if shadow_trunk != null:
		trunk_length = minf(trunk_height / tangent, total_length)
		var trunk_scale := maxf(trunk_length, 0.01) / _trunk_tex_h
		shadow_trunk.position = Vector2.ZERO
		shadow_trunk.rotation = direction.angle() - PI * 0.5
		shadow_trunk.scale = Vector2(1.0, trunk_scale)
		shadow_trunk.visible = trunk_length > 0.25

	crown_length = maxf(total_length - trunk_length, 0.01)
	shadow_crown.position = direction * trunk_length
	shadow_crown.rotation = atan2(direction.x, -direction.y)
	shadow_crown.scale = Vector2(1.0, crown_length / _crown_tex_h)
	shadow_crown.visible = true

	if contact != null:
		contact.visible = true
	visible = show


func set_shadows_enabled(show: bool) -> void:
	_enabled = show
	visible = show


func get_report() -> Dictionary:
	return {
		"name": display_name,
		"base": position,
		"two_part": shadow_trunk != null,
		"direction": direction,
		"elevation": elevated_clamped,
		"visual_height": visual_height,
		"raw_length": raw_length,
		"total_length": total_length,
		"trunk_length": trunk_length,
		"crown_length": crown_length,
		"junction": direction * trunk_length,
		"tip": direction * total_length,
		"capped": capped,
		"trunk_visible": shadow_trunk != null and shadow_trunk.visible,
		"crown_visible": shadow_crown != null and shadow_crown.visible,
		"contact_visible": contact != null and contact.visible,
	}


func get_crown_sprite() -> Sprite2D:
	return shadow_crown


func get_trunk_sprite() -> Sprite2D:
	return shadow_trunk


func get_contact_sprite() -> Sprite2D:
	return contact


func is_two_part() -> bool:
	return shadow_trunk != null
