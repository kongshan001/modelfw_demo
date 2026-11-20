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
var show_effects := true
var silhouette := false
var explode := 0.0
var highlight_slot := ""
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


func set_explode(value: float) -> void:
	explode = clampf(value, 0.0, 1.0)
	queue_redraw()


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
	if show_shadow and not silhouette and explode <= 0.01:
		# 环境影 223×34 + 接触影 168×32（1280 口径），整体下移 2px。
		DrawKit.contact_shadow(self, Vector2(0, 0), 1.0)

	DrawKit.begin_batch(self)
	DrawKit.set_silhouette(silhouette)
	# 侧身 x 压缩：正 1.0 / 斜 0.835 / 侧 0.70，让相邻方向剪影分开。
	var yaw_scale := 1.0 - 0.38 * float(dir["yaw"])
	DrawKit.set_xscale(yaw_scale)
	# 木偶身 build：grain 瘦 / plain 标准 / patch 敦实 / rivet 宽肩。
	# 只作用于身体与衣物轮廓，不拉宽头/五官/武器，保证换装一致。
	var build_x := 1.0
	match str(outfit.get("body", {}).get("variant", "plain")):
		"grain":
			build_x = 0.90
		"patch":
			build_x = 1.08
		"rivet":
			build_x = 1.16
	var order := DollData.draw_order(direction, outfit)
	var layer_index := 0
	for entry in order:
		var slot_id: String = entry["id"]
		var entry_outfit: Dictionary = outfit.get(slot_id, {})
		var variant_id := str(entry_outfit.get("variant", "none"))
		if variant_id == "none":
			continue
		var color: Color = entry_outfit.get("color", Color.WHITE)
		if explode > 0.01:
			DrawKit.set_offset(Vector2(4.6, 5.2) * (float(layer_index) - 8.0) * explode)
			DrawKit.set_alpha(1.0 if highlight_slot.is_empty() or highlight_slot == slot_id else 0.42)
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
			"outfit": outfit,
			"silhouette": silhouette,
			"explode": explode,
			"build_x": build_x,
		}
		# build 只影响身体/衣物/背饰轮廓；头、发、帽、武器保持原宽。
		var body_slots := ["body", "pants", "shirt", "cape", "belt", "shoes", "gloves", "backpack", "weapon", "accessory"]
		DrawKit.set_xscale(yaw_scale * (build_x if slot_id in body_slots else 1.0))
		PartPainter.paint(self, slot_id, variant_id, ctx)
		layer_index += 1

	DrawKit.set_offset(Vector2.ZERO)
	DrawKit.set_alpha(1.0)
	DrawKit.set_xscale(yaw_scale)
	if show_effects and not silhouette and explode <= 0.01:
		_draw_effects(pose, outfit)
	DrawKit.set_silhouette(false)
	DrawKit.end_batch()


func _draw_effects(pose: Dictionary, outfit_now: Dictionary) -> void:
	var slash: float = pose.get("slash", 0.0)
	if slash > 0.05:
		# 三层斩击：深边（对舞台 ≥3:1）+ 珊瑚外圈 + 金色核心；半径 40–56 local。
		var hand: Vector2 = pose["hand_r"]
		var arm_angle: float = pose["weapon_angle"]
		var start := arm_angle - 2.4
		var finish := arm_angle + 1.0
		var radius := 46.0 + 6.0 * slash
		DrawKit.arc(self, hand, radius, start, finish,
				PaintUtil.with_alpha(Color("#8f3030"), 0.92 * slash), 4.6)
		DrawKit.arc(self, hand, radius - 1.0, start + 0.04, finish - 0.04,
				PaintUtil.with_alpha(Color("#b23c33"), 0.85 * slash), 2.6)
		DrawKit.arc(self, hand, radius - 2.4, start + 0.10, finish - 0.12,
				PaintUtil.with_alpha(Color("#ffd27a"), 0.96 * slash), 2.0)
		for i in 3:
			var a := start + (finish - start) * (0.18 + 0.28 * float(i))
			var tip := hand + Vector2(cos(a), sin(a)) * (radius + 4.0)
			DrawKit.circle(self, tip, 1.4, PaintUtil.with_alpha(Color("#fff0cd"), 0.9 * slash), Color("#8f3030"), 0.4)

	var hit_k: float = pose.get("hit", 0.0)
	if hit_k > 0.18:
		var head: Vector2 = pose["head"]
		var colors := [Color("#f2b34c"), Color("#e86a5c")]
		for i in 2:
			var a := -PI * 0.9 + float(i) * 1.1
			var center := head + Vector2(cos(a), sin(a)) * (31.0 + float(i) * 5.0)
			DrawKit.star(self, center, 7.0 + hit_k * 3.0, 4, colors[i], DrawKit.INK, 0.8, 0.4, float(i) * 0.3)
		DrawKit.arc(self, head, 28.0, -2.4, -0.5,
				PaintUtil.with_alpha(Color("#b23c33"), 0.75 * hit_k), 1.8)
