class_name PaperDollRenderer
extends Node2D

# 单个纸偶的渲染节点：按 effective z-order 逐个槽位绘制。
# 部件全部由 PartPainter 即时绘制，没有任何贴图依赖；同一套关节保证换装对齐。

var outfit: Dictionary = DollData.default_outfit()
var direction := 0
var action := "idle"
var anim_time := 0.0
var time_offset := 0.0
var animate := true
var mini := false
var show_shadow := true
# 定格木偶质感 + Intel 集显余量：动作以 24Hz 重绘，画面本身仍按显示器帧率合成。
var redraw_hz := 24.0

var _base_scale := 1.0
var _flip := false
var _redraw_accum := 0.0


func _ready() -> void:
	outfit = DollData.normalize_outfit(outfit)
	_sync_flip()
	_apply_transform()
	queue_redraw()


func _process(delta: float) -> void:
	if not animate:
		return
	anim_time += delta
	_redraw_accum += delta
	var hz := minf(redraw_hz, 15.0) if mini else redraw_hz
	var interval := 1.0 / maxf(hz, 1.0)
	if _redraw_accum >= interval:
		_redraw_accum = 0.0
		queue_redraw()


func set_doll(new_outfit: Dictionary, new_direction: int, new_action: String) -> void:
	outfit = DollData.normalize_outfit(new_outfit)
	direction = clampi(new_direction, 0, DollData.DIRS.size() - 1)
	action = new_action if DollData.is_action(new_action) else "idle"
	_sync_flip()
	_apply_transform()
	queue_redraw()


func set_outfit(new_outfit: Dictionary) -> void:
	outfit = DollData.normalize_outfit(new_outfit)
	queue_redraw()


func set_direction(new_direction: int) -> void:
	direction = clampi(new_direction, 0, DollData.DIRS.size() - 1)
	_sync_flip()
	_apply_transform()
	queue_redraw()


func set_action(new_action: String) -> void:
	action = new_action if DollData.is_action(new_action) else "idle"
	queue_redraw()


func set_clock(value: float) -> void:
	anim_time = value
	queue_redraw()


func set_display_scale(value: float) -> void:
	_base_scale = maxf(value, 0.05)
	_apply_transform()


func set_flip(value: bool) -> void:
	_flip = value
	_apply_transform()


func current_pose() -> Dictionary:
	return DollPose.compute(anim_time + time_offset, action, direction)


func outfit_signature() -> String:
	var parts: Array[String] = []
	for slot in DollData.SLOTS:
		var slot_id: String = slot["id"]
		var entry: Dictionary = outfit.get(slot_id, {})
		parts.append("%s:%s:%s" % [
			slot_id,
			str(entry.get("variant", "")),
			(entry.get("color", Color.WHITE) as Color).to_html(false),
		])
	return "|".join(parts)


func _sync_flip() -> void:
	_flip = bool(DollData.DIRS[clampi(direction, 0, DollData.DIRS.size() - 1)]["flip"])


func _apply_transform() -> void:
	scale = Vector2(-_base_scale if _flip else _base_scale, _base_scale)


func _draw() -> void:
	var dir: Dictionary = DollData.DIRS[clampi(direction, 0, 7)]
	var local_time := anim_time + time_offset
	var pose := DollPose.compute(local_time, action, direction)
	var blink := action != "hit" and fposmod(local_time + 1.4, 4.3) < 0.10
	if show_shadow:
		DrawKit.shadow(self, Vector2(0, -1), Vector2(30, 8), 0.16)

	DrawKit.begin_batch(self)
	var order := DollData.draw_order(direction, outfit)
	for entry in order:
		var slot_id: String = entry["id"]
		var entry_outfit: Dictionary = outfit.get(slot_id, {})
		var variant_id := str(entry_outfit.get("variant", "none"))
		if variant_id == "none":
			continue
		var color: Color = entry_outfit.get("color", Color.WHITE)
		var ctx := {
			"pose": pose,
			"yaw": float(dir["yaw"]),
			"back": bool(dir["back"]),
			"side": float(dir["yaw"]) >= 0.85,
			"flip": bool(dir["flip"]),
			"time": local_time,
			"pal": DrawKit.make_palette(color),
			"head_r": DollPose.HEAD_R,
			"mini": mini,
			"blink": blink,
			"weapon_color": color,
		}
		PartPainter.paint(self, slot_id, variant_id, ctx)

	_draw_effects(pose, outfit)
	DrawKit.end_batch()


func _draw_effects(pose: Dictionary, outfit_now: Dictionary) -> void:
	var slash: float = pose.get("slash", 0.0)
	if slash > 0.05:
		var hand: Vector2 = pose["hand_r"]
		var arm_angle: float = pose["weapon_angle"]
		var start := arm_angle - 2.3
		var finish := arm_angle + 0.9
		var shine := Color(1.0, 0.96, 0.84, 0.70 * slash)
		DrawKit.arc(self, hand, 34.0, start, finish, shine, 4.2)
		DrawKit.arc(self, hand, 28.0, start + 0.2, finish - 0.1, Color(0.99, 0.80, 0.42, 0.55 * slash), 2.0)

	var hit_k: float = pose.get("hit", 0.0)
	if hit_k > 0.18:
		var head: Vector2 = pose["head"]
		var colors := [Color("#f2b34c"), Color("#e86a5c"), Color("#fffaf0")]
		for i in 3:
			var a := -PI * 0.9 + float(i) * 0.9
			var center := head + Vector2(cos(a), sin(a)) * (30.0 + float(i) * 4.0)
			DrawKit.star(self, center, 7.0 + hit_k * 3.0, 4, colors[i], DrawKit.INK, 0.9, 0.4, float(i) * 0.3)
		DrawKit.arc(self, head, 27.0, -2.4, -0.5, Color(1, 0.92, 0.82, 0.6 * hit_k), 2.2)
