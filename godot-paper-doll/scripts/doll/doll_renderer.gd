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
# 缩略图的接触影略压扁，避免在 85px 高的卡片预览里被下缘裁平。
var shadow_scale_y := 1.0
var show_effects := true
var silhouette := false
var explode := 0.0
var highlight_slot := ""
# 定格木偶质感 + Intel 集显余量：动作以 24Hz 重绘，画面本身仍按显示器帧率合成。
var redraw_hz := 24.0

var _base_scale := 1.0
var _flip := false
var _redraw_accum := 0.0
var _blink_last := false
# 烘焙成本观测（T-010）：_draw 的 CPU 耗时。
var last_draw_usec := 0
var draw_count := 0


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
	# 自适应重绘：idle 6Hz（呼吸 1.4 local，幅度小）；walk 18Hz；命中/受击 24Hz。
	# 展示物料（GIF/录屏）用 animate=false + 强制 clock，仍是 30fps，不受影响。
	var hz := 24.0
	match action:
		"walk":
			hz = 18.0
		"attack", "hit":
			hz = 24.0
		_:
			hz = 6.0
	hz = minf(hz, redraw_hz)
	if mini:
		hz = minf(hz, 7.0)
	var interval := 1.0 / maxf(hz, 1.0)
	# 眨眼是 0.16s 的瞬时状态：状态翻转时强制重绘一帧，低 idle 频率下也不会丢。
	var blink_now := action != "hit" and action != "attack" and fposmod(anim_time + 1.4, 4.3) < 0.16
	if blink_now != _blink_last:
		_blink_last = blink_now
		queue_redraw()
		_redraw_accum = 0.0
		return
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
	draw_count += 1
	var draw_started := Time.get_ticks_usec()
	var dir: Dictionary = DollData.DIRS[clampi(direction, 0, 7)]
	var local_time := anim_time + time_offset
	var pose := DollPose.compute(local_time, action, direction)
	var blink := action != "hit" and action != "attack" and fposmod(local_time + 1.4, 4.3) < 0.16
	# 屏幕轻震 2–3px（local 1.2 @2.1× ≈ 2.5px）：命中帧起 0.16s 内衰减；
	# 只平移角色 + 影子（舞台是静态纸卡，不动相机）。
	var impact_shake := _impact_shake(pose, local_time)
	if show_shadow and not silhouette and explode <= 0.01:
		# 双层接触影：半影 + 本影（影子随轻震一起动）。
		DrawKit.contact_shadow(self, Vector2(0, 0), shadow_scale_y, impact_shake)

	DrawKit.begin_batch(self)
	DrawKit.set_mini(mini)
	DrawKit.set_silhouette(silhouette)
	DrawKit.set_shake(impact_shake)
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
			# 被覆盖层的渲染预算：身体躯干/腿在 shirt/pants 之下，不必画 7 档；
			# 只保留手/前臂（袖子外的部分）的材质。这是 FPS 预算，不改变可见外观。
			"torso_covered": str(outfit.get("shirt", {}).get("variant", "none")) != "none",
			"legs_covered": str(outfit.get("pants", {}).get("variant", "none")) != "none",
			"arms_covered": str(outfit.get("shirt", {}).get("variant", "none")) in ["tunic", "hoodie", "dress", "armor"],
		}
		# build 只影响身体/衣物/背饰轮廓；头、发、帽、武器保持原宽。
		var body_slots := ["body", "pants", "shirt", "cape", "belt", "shoes", "gloves", "backpack", "weapon", "accessory"]
		DrawKit.set_xscale(yaw_scale * (build_x if slot_id in body_slots else 1.0))
		PartPainter.paint(self, slot_id, variant_id, ctx)
		layer_index += 1

	DrawKit.set_offset(Vector2.ZERO)
	DrawKit.set_alpha(1.0)
	# VFX 在屏幕空间绘制：不随 2.5D 侧向 x 压缩，保证 640×360 下核心 ≥4px。
	DrawKit.set_xscale(1.0)
	if show_effects and not silhouette and explode <= 0.01:
		_draw_effects(pose, outfit)
	DrawKit.set_silhouette(false)
	DrawKit.end_batch()
	last_draw_usec = Time.get_ticks_usec() - draw_started


func _impact_shake(pose: Dictionary, t: float) -> Vector2:
	if silhouette:
		return Vector2.ZERO
	var vfx_t: float = pose.get("vfx_t", -1.0)
	if action == "attack" and vfx_t >= 0.10 and vfx_t <= 0.30:
		var k := 1.0 if vfx_t <= 0.126 else 1.0 - (vfx_t - 0.126) / 0.174
		# 用 attack_p 而非 wall clock：impact hold 2 帧内轻震也保持同相位，帧差可测。
		var ap: float = pose.get("attack_p", 0.0)
		return Vector2(sin(ap * 611.0), cos(ap * 457.0)) * 1.2 * k
	if action == "hit":
		return Vector2(sin(t * 83.0), cos(t * 59.0)) * 1.2 * float(pose.get("hit", 0.0))
	return Vector2.ZERO


func _draw_effects(pose: Dictionary, outfit_now: Dictionary) -> void:
	var slash: float = pose.get("slash", 0.0)
	var vfx_t: float = pose.get("vfx_t", -1.0)
	var yaw_scale := 1.0 - 0.38 * float(DollData.DIRS[clampi(direction, 0, 7)]["yaw"])
	var hand: Vector2 = pose["hand_r"]
	hand.x *= yaw_scale
	var arm_angle: float = pose["weapon_angle"]
	# 109°–143° 前挥弧：从右上到右下，经过身前；不再绕成“呼啦圈”。
	var start := arm_angle - 2.15
	var finish := arm_angle - 0.25
	var radius := 46.0 + 6.0 * clampf(slash, 0.0, 1.0)
	if slash > 0.05:
		# 三层斩击（G5 / P1-2）：
		#   辉光 8–12px@640（local 4.9，α0.6）+ 16px 外晕；
		#   深边 1px `#8f3030`（local 0.5 每侧 → 总宽 3.0）；
		#   核心 2px `#8f5f1f`（local 2.0 ≈ 4.1px@640，对纸面 ≈5.6:1）；
		#   1px `#ffd27a` 装饰高光不计入对比。
		DrawKit.arc(self, hand, radius, start - 0.03, finish + 0.03,
				PaintUtil.with_alpha(Color("#ffd27a"), 0.14 * slash), 9.0)
		DrawKit.arc(self, hand, radius, start, finish,
				PaintUtil.with_alpha(Color("#f4c76a"), 0.60 * slash), 4.9)
		DrawKit.arc(self, hand, radius + 0.35, start + 0.02, finish - 0.02,
				PaintUtil.with_alpha(Color("#8f3030"), 0.95 * slash), 3.0)
		DrawKit.arc(self, hand, radius + 0.35, start + 0.03, finish - 0.03,
				PaintUtil.with_alpha(Color("#8f5f1f"), 0.98 * slash), 2.50)
		DrawKit.arc(self, hand, radius + 0.35, start + 0.05, finish - 0.05,
				PaintUtil.with_alpha(Color("#ffd27a"), 0.90 * slash), 0.5)

	# 粒子 12–24 粒、寿命 0.2–0.45s：命中后继续飞散，不依赖 slash 曲线。
	if vfx_t >= 0.0 and vfx_t <= 0.48:
		var wave_dir := finish - start
		for i in 18:
			var spawn := 0.012 * float(i) + 0.004 * float(i % 3)
			var life := 0.22 + 0.06 * float(i % 4)
			var age := vfx_t - spawn
			if age < 0.0 or age > life:
				continue
			var u := 0.08 + 0.86 * float(i) / 17.0
			var a := start + wave_dir * u
			var dir := Vector2(cos(a), sin(a))
			var tangent := Vector2(-dir.y, dir.x) * (1.0 if sin(a) < 0.0 else -1.0)
			var jitter := Vector2(sin(float(i) * 12.9898), cos(float(i) * 7.233)) * 0.25
			var vel := (dir * (46.0 + 34.0 * float(i % 5) * 0.25) + tangent * 42.0 + jitter * 30.0)
			var pos: Vector2 = hand + dir * (radius + 2.0) + vel * age + Vector2(0, 92.0 * age * age)
			var fade := 1.0 - age / life
			var col: Color = [Color("#ffd27a"), Color("#e86a5c"), Color("#fff0cd")][i % 3]
			var r := (1.0 + float(i % 4) * 0.35) * (0.6 + fade * 0.4)
			if i % 4 == 0:
				DrawKit.star(self, pos, r + 1.4, 4,
						PaintUtil.with_alpha(col, 0.95 * fade), Color("#8f3030"), 0.3, 0.38, a)
			else:
				DrawKit.circle(self, pos, r, PaintUtil.with_alpha(col, 0.92 * fade), Color("#8f3030"), 0.25)

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
