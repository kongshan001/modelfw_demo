class_name PaintFigure
extends RefCounted

# 身体、头、耳、眼、面具、头发。严格跟随 DollPose 的脊柱/四肢关节。
#
# 渲染语言：只有最外缘使用 ink L0；衣服/肢体内部用 shade 结构线（L1），
# 木纹/缝线/铆钉等细节只在 Studio 且 ≥3px 时绘制（L2）。


static func paint(ci: CanvasItem, slot: String, variant: String, ctx: Dictionary) -> void:
	match slot:
		"body":
			_body(ci, variant, ctx)
		"head":
			_head(ci, variant, ctx)
		"ear":
			_ear(ci, variant, ctx)
		"mask":
			_mask(ci, variant, ctx)
		"eyes":
			_eyes(ci, variant, ctx)
		"hair":
			_hair(ci, variant, ctx)


# ------------------------------------------------------------------ 木偶身

static func _body(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var deep := PaintUtil.color(ctx, "deep")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var hi := PaintUtil.highlight(ctx)
	var ow := PaintUtil.ow(ctx)
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col
	var lean: float = p["torso_lean"]
	var studio := not PaintUtil.is_mini(ctx) and not bool(ctx.get("silhouette", false))
	var ramp := PaintUtil.ramp(ctx)

	# 被 shirt/pants 覆盖的身体层只画平面：7 档留给 1× 可见的衣物与皮肤，
	# 不把预算花在看不见的层上（studio 重绘 20Hz，FPS 门 ≥30）。
	var torso_covered := bool(ctx.get("torso_covered", false))
	var legs_covered := bool(ctx.get("legs_covered", false))
	var arms_covered := bool(ctx.get("arms_covered", false))
	_limb(ci, p["shoulder_l"], p["elbow_l"], p["hand_l"], far, true, ctx, arms_covered)
	if not legs_covered:
		_leg(ci, p["hip_l"], p["knee_l"], p["foot_l"], far, true, ctx)

	# 躯干：7 档色阶（deep→hi）+ 12% AO + 2px 6500K 轮廓光 + 8–12% 暖反弹。
	# 被上衣覆盖时整段跳过（z 序保证不可见），只保留颈/手等露出部分。
	var hip: Vector2 = p["hip"]
	var chest: Vector2 = p["chest"]
	if not torso_covered:
		if studio:
			DrawKit.layer_shadow(ci, DrawKit._ellipse_points((hip + chest) * 0.5, Vector2(14.5, 22.0), lean, 20), 0.10)
		DrawKit.capsule_tones(ci, hip, chest, 24.0, ramp, 4, 1.55, PaintUtil.ink(ctx), ow)
		if studio:
			DrawKit.ao_ellipse(ci, hip + Vector2(0, -4).rotated(lean), Vector2(10.0, 4.6), lean, 0.12)
			DrawKit.ellipse(ci, (hip + chest) * 0.5 + Vector2(-4.6, -1.8).rotated(lean),
					Vector2(5.4, 14.0), lean, PaintUtil.with_alpha(PaintUtil.key_light(ctx), 0.10), Color.WHITE, 0.0)
			DrawKit.rim_stroke(ci, chest + Vector2(10.6, 2).rotated(lean), hip + Vector2(10.6, -4).rotated(lean), 0.5, 0.95)
			DrawKit.bounce_stroke(ci, hip + Vector2(-9.5, 1).rotated(lean), hip + Vector2(-4.0, 6).rotated(lean), 0.10)
		DrawKit.capsule_tones(ci, (p["shoulder_l"] as Vector2).lerp(chest, 0.25),
				(p["shoulder_r"] as Vector2).lerp(chest, 0.25), 13.0, ramp, 3, 1.2, PaintUtil.ink(ctx), 0.0)
		DrawKit.line(ci, (p["shoulder_l"] as Vector2).lerp(chest, 0.10) + Vector2(0, -5.6),
				(p["shoulder_r"] as Vector2).lerp(chest, 0.10) + Vector2(0, -5.6),
				PaintUtil.with_alpha(PaintUtil.shade_of(ctx), 0.8), PaintUtil.detail_w(ctx) * 1.4)
	else:
		DrawKit.capsule(ci, (chest as Vector2).lerp(p["neck"], 0.72),
				(p["neck"] as Vector2) + Vector2(0, -1), 8.6, PaintUtil.shade_of(ctx), PaintUtil.ink(ctx), 0.0)
	DrawKit.capsule(ci, (chest as Vector2).lerp(p["neck"], 0.62),
			(p["neck"] as Vector2) + Vector2(0, -2), 9.0, PaintUtil.shade_of(ctx), PaintUtil.ink(ctx), 0.0)
	if studio:
		DrawKit.ao_ellipse(ci, (chest as Vector2).lerp(p["neck"], 0.75), Vector2(6.2, 2.4), lean, 0.12)

	if not legs_covered:
		_leg(ci, p["hip_r"], p["knee_r"], p["foot_r"], col, false, ctx)
	_limb(ci, p["shoulder_r"], p["elbow_r"], p["hand_r"], col, false, ctx, arms_covered)

	if studio and not torso_covered:
		# 黄铜两脚钉：解释“为什么能动”。4 处关节，mini/被衣物覆盖时删除。
		for joint in [p["shoulder_l"], p["shoulder_r"], p["hip_l"], p["hip_r"]]:
			DrawKit.circle(ci, joint, 1.7, PaintUtil.mat_color(ctx, "metal", "light"),
					PaintUtil.mat_color(ctx, "metal", "deep"), 0.45)
			DrawKit.circle(ci, joint + Vector2(-0.5, -0.5), 0.55,
					PaintUtil.mat_color(ctx, "gold", "light"), Color.WHITE, 0.0)

	# 木纹签名（1× 可见）：2 条年轮弧 0.8px `#9a653f` 60%，间距 3–4px，只画在裸露木面。
	if studio and not torso_covered and not arms_covered:
		var wood_grain := PaintUtil.with_alpha(Color("#9a653f"), 0.60)
		var ring_c := chest.lerp(hip, 0.46) + Vector2(0.5, 0).rotated(lean)
		var ring_n := 2 if variant == "grain" else 1
		for i in ring_n:
			DrawKit.arc(ci, ring_c + Vector2(0, float(i) * 3.6), 6.2 - float(i) * 1.4, 0.35, 2.55,
					wood_grain, 0.40)

	match variant:
		"grain":
			if studio and not (torso_covered and legs_covered and arms_covered):
				var near_shin := PaintUtil.lerp_pt(p["knee_r"], p["foot_r"], 0.55)
				var grain := PaintUtil.with_alpha(Color("#9a653f"), 0.60)
				DrawKit.arc(ci, near_shin, 3.8, 0.2, 2.4, grain, 0.40)
				DrawKit.arc(ci, near_shin + Vector2(0, 3.4), 2.7, 0.4, 2.2, grain, 0.40)
				var fore := PaintUtil.lerp_pt(p["elbow_r"], p["hand_r"], 0.5)
				DrawKit.arc(ci, fore, 2.6, -1.2, 1.4, grain, 0.40)
		"patch":
			var fore := PaintUtil.lerp_pt(p["elbow_r"], p["hand_r"], 0.56)
			var angle: float = p["forearm_angle_r"]
			DrawKit.rrect(ci, fore, Vector2(9.0, 6.8), 1.5, angle, shade,
					PaintUtil.with_alpha(deep, 0.8), PaintUtil.ol(ctx, "struct"))
			if studio:
				for sx in [-1.0, 1.0]:
					DrawKit.line(ci, fore + Vector2(-3.0 * sx, -2.6).rotated(angle),
							fore + Vector2(-3.0 * sx, -3.9).rotated(angle), light, PaintUtil.detail_w(ctx))
		"rivet":
			var rivet_col := PaintUtil.mat_color(ctx, "metal", "light")
			for joint in [p["elbow_r"], p["knee_r"], p["shoulder_r"]]:
				DrawKit.circle(ci, joint, 1.8, rivet_col, PaintUtil.mat_color(ctx, "metal", "deep"), 0.45)
				if studio:
					DrawKit.circle(ci, joint + Vector2(-0.4, -0.5), 0.5, hi, Color.WHITE, 0.0)
		_:
			pass


static func _limb(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, col: Color, is_far: bool, ctx: Dictionary, covered := false) -> void:
	var shade := PaintUtil.shade_of(ctx)
	var light := PaintUtil.highlight(ctx)
	var ow := PaintUtil.ow(ctx)
	var ramp := PaintUtil.ramp(ctx)
	var outline := 0.0 if PaintUtil.is_mini(ctx) else ow * (0.28 if is_far else 0.35)
	if covered:
		# 袖子内：上臂/肘由袖子承担；前臂到手腕必须画满（否则露袖子与手之间会断）。
		DrawKit.capsule(ci, elbow, hand, 6.2, PaintUtil.color(ctx, "base"), PaintUtil.ink(ctx), outline)
	else:
		DrawKit.capsule_tones(ci, shoulder, elbow, 7.6, ramp, 3, 0.95, PaintUtil.ink(ctx), outline)
		DrawKit.capsule_tones(ci, elbow, hand, 6.6, ramp, 3, 0.85, PaintUtil.ink(ctx), outline)
	if not covered:
		DrawKit.circle(ci, elbow, 3.6, PaintUtil.color(ctx, "base").lightened(0.08), PaintUtil.ink(ctx), 0.0)
	DrawKit.circle(ci, hand, 4.3, PaintUtil.color(ctx, "base"), PaintUtil.ink(ctx), 0.0)
	if not PaintUtil.is_mini(ctx):
		# 8–10% 红润 SSS：手；木偶手也要有“肤色受光”。
		DrawKit.ellipse(ci, hand + Vector2(-1.2, -1.4), Vector2(2.8, 2.2), 0.0,
				PaintUtil.with_alpha(PaintUtil.sss(ctx), 0.10), Color.WHITE, 0.0)
		if covered:
			return
		var seam := PaintUtil.lerp_pt(shoulder, elbow, 0.55)
		DrawKit.line(ci, seam + Vector2(-2, 0), seam + Vector2(2, 0),
				PaintUtil.with_alpha(shade, 0.75), PaintUtil.detail_w(ctx))
		var lit := PaintUtil.lerp_pt(shoulder, elbow, 0.45) + Vector2(-1.4, -1.6)
		DrawKit.line(ci, lit, lit + Vector2(1.4, 2.2), PaintUtil.with_alpha(light, 0.55), PaintUtil.detail_w(ctx))
		if not is_far:
			# 轮廓光：2px @2.1×、α0.5、6500K；环境反弹在左下。
			DrawKit.rim_stroke(ci, shoulder + Vector2(3.2, 2.4), elbow + Vector2(3.2, 2.0), 0.5, 0.95)
			DrawKit.rim_stroke(ci, elbow + Vector2(2.8, 2.0), hand + Vector2(2.6, 1.6), 0.5, 0.95)
			DrawKit.bounce_stroke(ci, hand + Vector2(-3.4, 2.4), hand + Vector2(-1.0, 4.0), 0.10)


static func _leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, col: Color, is_far: bool, ctx: Dictionary) -> void:
	var shade := PaintUtil.shade_of(ctx)
	var ow := PaintUtil.ow(ctx)
	var ramp := PaintUtil.ramp(ctx)
	var outline := 0.0 if PaintUtil.is_mini(ctx) else ow * (0.30 if is_far else 0.38)
	DrawKit.capsule_tones(ci, hip, knee, 9.0, ramp, 3, 1.0, PaintUtil.ink(ctx), outline)
	DrawKit.capsule_tones(ci, knee, foot, 7.8, ramp, 3, 0.9, PaintUtil.ink(ctx), outline)
	DrawKit.circle(ci, knee, 4.2, PaintUtil.color(ctx, "base").lightened(0.08), PaintUtil.ink(ctx), 0.0)
	DrawKit.ellipse(ci, foot + Vector2(1, -1), Vector2(4.6, 3.6), 0.0, PaintUtil.color(ctx, "base"),
			PaintUtil.ink(ctx), 0.0)
	if not PaintUtil.is_mini(ctx):
		DrawKit.line(ci, PaintUtil.lerp_pt(hip, knee, 0.55) + Vector2(-2, 0),
				PaintUtil.lerp_pt(hip, knee, 0.55) + Vector2(2, 0),
				PaintUtil.with_alpha(shade, 0.7), PaintUtil.detail_w(ctx))
		if not is_far:
			DrawKit.rim_stroke(ci, hip + Vector2(3.6, 1.0), knee + Vector2(3.4, 0.6), 0.5, 0.95)
			DrawKit.rim_stroke(ci, knee + Vector2(3.2, 0.4), foot + Vector2(3.0, -1.0), 0.5, 0.95)


# ------------------------------------------------------------------ 头

static func _head(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var light := PaintUtil.color(ctx, "light")
	var deep := PaintUtil.color(ctx, "deep")
	var shade := PaintUtil.color(ctx, "shade")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var center: Vector2 = p["head"]
	var studio := not PaintUtil.is_mini(ctx) and not bool(ctx.get("silhouette", false))
	var back: bool = bool(ctx["back"])
	var ramp := PaintUtil.ramp(ctx)
	DrawKit.capsule(ci, p["neck"], center + Vector2(0, 14).rotated(ha), 8.5, shade, ink, 0.0)

	# 头是 7 档色阶的主展示面：deep→shade→base→light→hi，1× 下 ≥5 阶可见。
	match variant:
		"square":
			DrawKit.polygon_tones(ci, DrawKit.rrect_points(center, Vector2(32, 32), 8.0, ha),
					ramp, 5, 1.05, ink, ow)
		"acorn":
			DrawKit.ellipse_tones(ci, center + Vector2(0, 1).rotated(ha), Vector2(17.5, 19.5), ha,
					ramp, 3, 1.3, ink, ow, 32, 1)
			DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(0, -18)),
					PaintUtil.head_point(ctx, Vector2(2, -24)), shade, PaintUtil.ol(ctx, "struct"))
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(2, -24)), 2.2, light, ink, 0.0)
		"pebble":
			DrawKit.ellipse_tones(ci, center, Vector2(20.5, 16.5), ha, ramp, 3, 1.3, ink, ow, 32, 1)
		_:
			DrawKit.ellipse_tones(ci, center, Vector2(18.0, 18.0), ha, ramp, 3, 1.3, ink, ow, 32, 1)

	if studio:
		# 8–10% 红润 SSS（受光面）+ 12% 下颌 AO + 2px α0.5 6500K 轮廓光。
		DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(-5.0, -5.4)), Vector2(7.2, 6.2), ha,
				PaintUtil.with_alpha(PaintUtil.sss(ctx), 0.09), Color.WHITE, 0.0)
		DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(-5.4, -6.6)), Vector2(4.6, 4.0), ha,
				PaintUtil.with_alpha(PaintUtil.key_light(ctx), 0.08), Color.WHITE, 0.0)
		DrawKit.ao_ellipse(ci, PaintUtil.head_point(ctx, Vector2(1.2, 13.4)), Vector2(7.4, 2.4), ha, 0.12)
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(1, 1)), 15.6, -1.35, -0.30,
				PaintUtil.with_alpha(PaintUtil.rim_warm(ctx), 0.50), 0.95)
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(-1, 1)), 15.8, 2.2, 3.1,
				PaintUtil.with_alpha(PaintUtil.rim_cool(ctx), 0.32), 0.6)
		DrawKit.paper_fibers(ci, center, Vector2(28, 28), variant.hash(), PaintUtil.with_alpha(deep, 0.06))

	if back:
		# 后脑不是纯圆球：加发际线、颈窝与两缕碎发；头发槽位会在其上继续画。
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(0, -2)), 11.4, 0.5, 2.6,
				PaintUtil.with_alpha(shade, 0.7), PaintUtil.ol(ctx, "struct"))
		DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-7, 12)),
				PaintUtil.head_point(ctx, Vector2(-4, 17)), PaintUtil.with_alpha(deep, 0.65), PaintUtil.ol(ctx, "struct"))
		DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(7, 12)),
				PaintUtil.head_point(ctx, Vector2(4, 17)), PaintUtil.with_alpha(deep, 0.65), PaintUtil.ol(ctx, "struct"))
		return

	var far_pos := PaintUtil.face_point(ctx, -10.0, 7.4)
	if PaintUtil.far_visible(ctx):
		DrawKit.circle(ci, far_pos, 2.6, PaintUtil.with_alpha(PaintUtil.color(ctx, "blush"), 0.30), ink, 0.0)
	DrawKit.circle(ci, PaintUtil.face_point(ctx, 10.0, 7.4), 3.0,
			PaintUtil.with_alpha(PaintUtil.color(ctx, "blush"), 0.38), ink, 0.0)
	var yaw := float(ctx["yaw"])
	if yaw >= 0.55:
		# 3/4 侧面：3–4px 鼻梁 + 鼻尖，正面不再用 1px 点。
		var nose_base := PaintUtil.face_point(ctx, 11.0, 1.8)
		var nose_tip := PaintUtil.face_point(ctx, 15.8, 4.4)
		DrawKit.polygon(ci, PackedVector2Array([
			nose_base + Vector2(0, -1.6).rotated(ha),
			nose_tip,
			nose_base + Vector2(0.4, 2.6).rotated(ha),
		]), PaintUtil.with_alpha(shade, 0.65), PaintUtil.with_alpha(deep, 0.7), 0.0)
		DrawKit.circle(ci, nose_tip, 1.4, PaintUtil.with_alpha(light, 0.8), ink, 0.0)
	else:
		var nose := PaintUtil.face_point(ctx, 0.8, 5.2)
		DrawKit.polygon(ci, PackedVector2Array([
			nose + Vector2(-1.5, -1.2), nose + Vector2(1.5, -1.2), nose + Vector2(0.2, 1.4),
		]), PaintUtil.with_alpha(shade, 0.55), PaintUtil.with_alpha(deep, 0.55), 0.0)
	# 嘴：6–8% 头宽；微笑 / 张口两态（受击时张口）。
	var mouth := PaintUtil.face_point(ctx, 2.0, 9.4)
	var mouth_w := 1.9 if not PaintUtil.is_mini(ctx) else 2.2
	if float(p.get("hit", 0.0)) > 0.35:
		DrawKit.circle(ci, mouth + Vector2(0, 0.6), 1.8, deep, ink, mouth_w)
	else:
		DrawKit.arc(ci, mouth, 1.9, 0.35, PI - 0.35, deep, mouth_w)
	# 下巴 / 颈下 1px shade。
	DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(1.2, 12.6)), 5.4, 0.5, PI - 0.5,
			PaintUtil.with_alpha(shade, 0.55), PaintUtil.ol(ctx, "struct"))


# ------------------------------------------------------------------ 耳

static func _ear(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var col := PaintUtil.color(ctx, "primary")
	var far := PaintUtil.far_color(ctx)
	var near_x := 17.5 - 5.2 * float(ctx["yaw"])
	var near := PaintUtil.head_point(ctx, Vector2(near_x, -1.0))
	var far_pos := PaintUtil.head_point(ctx, Vector2(-17.5, 0))
	if PaintUtil.far_visible(ctx):
		_ear_shape(ci, variant, far_pos, -1.0, far, ctx)
	_ear_shape(ci, variant, near, 1.0, col, ctx)


static func _ear_shape(ci: CanvasItem, variant: String, center: Vector2, side: float, col: Color, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var light := PaintUtil.highlight(ctx)
	var outline := PaintUtil.ol(ctx, "struct") * 1.25
	match variant:
		"round":
			DrawKit.circle(ci, center + Vector2(0, 1).rotated(ha), 6.4, col, ink, outline)
			DrawKit.circle(ci, center + Vector2(0, 1).rotated(ha), 3.0,
					PaintUtil.with_alpha(light, 0.75), ink, 0.0)
			DrawKit.ellipse(ci, center + Vector2(-1.4, -1.2).rotated(ha), Vector2(2.0, 1.6), ha,
					PaintUtil.with_alpha(PaintUtil.sss(ctx), 0.10), Color.WHITE, 0.0)
		"pointy":
			# 更长的尖耳：作为许多无帽角色的剪影破形件。
			DrawKit.poly_at(ci, center, [
				Vector2(-4.0 * side, -8.0), Vector2(11.0 * side, 0.0),
				Vector2(-4.0 * side, 8.0), Vector2(-1.0 * side, 0.0),
			], ha, col, ink, outline)
			DrawKit.poly_at(ci, center, [
				Vector2(-1.5 * side, -3.6), Vector2(7.0 * side, 0.0),
				Vector2(-1.5 * side, 3.6), Vector2(-0.2 * side, 0.0),
			], ha, light, Color.WHITE, 0.0)
			DrawKit.line(ci, center + Vector2(-1.0 * side, 0).rotated(ha),
					center + Vector2(6.0 * side, 0).rotated(ha),
					PaintUtil.with_alpha(light, 0.8), PaintUtil.detail_w(ctx))
			DrawKit.ellipse(ci, center + Vector2(1.0 * side, 1.6).rotated(ha), Vector2(2.4, 1.4), ha,
					PaintUtil.with_alpha(PaintUtil.sss(ctx), 0.10), Color.WHITE, 0.0)
		"horn":
			var base := center + Vector2(0, -4).rotated(ha)
			var tip := center + Vector2(6.5 * side, -17).rotated(ha)
			DrawKit.capsule(ci, base, tip, 5.2, col, ink, outline)
			DrawKit.circle(ci, tip, 2.2, PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.4)
		"antenna":
			var base := PaintUtil.head_point(ctx, Vector2(8.0 * side, -13.0))
			var wig := PaintUtil.sway(ctx, 2.2, 2.0, float(side))
			var tip := base + Vector2(4.0 * side + wig, -18.0)
			DrawKit.line(ci, base, tip, ink, ow * 0.65)
			DrawKit.line(ci, base, tip, col, ow * 0.34)
			DrawKit.circle(ci, tip, 2.8, PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.5)


# ------------------------------------------------------------------ 面具

static func _mask(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	if bool(ctx["back"]):
		return
	var col := PaintUtil.color(ctx, "primary")
	var deep := PaintUtil.color(ctx, "deep")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var eyes := PaintUtil.eye_positions(ctx)
	var outline := PaintUtil.ol(ctx, "outer") * 0.85

	match variant:
		"fox":
			var pts := PackedVector2Array()
			for pt in [
				Vector2(-19, -11), Vector2(-14, -21), Vector2(-5, -17), Vector2(0, -19),
				Vector2(5, -17), Vector2(14, -21), Vector2(19, -11), Vector2(16, 6),
				Vector2(0, 18), Vector2(-16, 6),
			]:
				pts.append(PaintUtil.head_point(ctx, pt))
			DrawKit.layer_shadow(ci, pts, 0.12)
			DrawKit.polygon(ci, pts, col, ink, outline)
			for side in [-1.0, 1.0]:
				DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(14.5 * side, -16)),
						[Vector2(-4, 3), Vector2(2 * side, -10), Vector2(4, 4)], ha,
						col, ink, PaintUtil.ol(ctx, "struct"))
			DrawKit.ellipse(ci, PaintUtil.face_point(ctx, 0, 8), Vector2(6, 5), ha,
					PaintUtil.mat_color(ctx, "paper", "base"), ink, 0.0)
			DrawKit.poly_at(ci, PaintUtil.face_point(ctx, 0, 10), [
				Vector2(-2.4, -1.5), Vector2(2.4, -1.5), Vector2(0, 2.5),
			], ha, deep, deep, 0.0)
			for e in eyes:
				DrawKit.line(ci, e + Vector2(-6, 5), e + Vector2(-2, 5),
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "base"), 0.95), 0.9)
				DrawKit.line(ci, e + Vector2(-6, 5.8), e + Vector2(-2, 5.8),
						PaintUtil.with_alpha(deep, 0.55), PaintUtil.detail_w(ctx))
		"owl":
			for e in eyes:
				DrawKit.ring(ci, e, 6.6, 3.6, ink)
				DrawKit.ring(ci, e, 6.6, 2.2, col)
			var beak := PaintUtil.face_point(ctx, 0, 6)
			DrawKit.poly_at(ci, beak, [
				Vector2(-3.6, -3), Vector2(3.6, -3), Vector2(0, 4.8),
			], ha, PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.5)
			for side in [-1.0, 1.0]:
				var a := PaintUtil.face_point(ctx, 12.0 * side, 2.0)
				DrawKit.line(ci, a, a + Vector2(4.0 * side, -2),
						PaintUtil.with_alpha(deep, 0.8), PaintUtil.detail_w(ctx))
		"bandit":
			var band := PaintUtil.face_point(ctx, 0, -2)
			DrawKit.rrect(ci, band, Vector2(31.0, 10.5), 4.0, ha, col, ink, outline)
			if not PaintUtil.is_mini(ctx):
				DrawKit.rrect(ci, band + Vector2(0, -2.2).rotated(ha), Vector2(30.0, 3.0), 1.5, ha,
						PaintUtil.with_alpha(PaintUtil.color(ctx, "light"), 0.45), Color.WHITE, 0.0)
			var knot := PaintUtil.head_point(ctx, Vector2(17, -2))
			DrawKit.circle(ci, knot, 2.6, deep, ink, 0.45)
			for i in 2:
				var tip := knot + Vector2(8 + i * 2, 5 + i * 5 + PaintUtil.sway(ctx, 3.0, 1.2, i))
				DrawKit.capsule(ci, knot, tip, 3.6 - i * 0.8, deep, ink, 0.0)
		"specs":
			for e in eyes:
				DrawKit.ring(ci, e, 5.6, 1.1, ink)
				DrawKit.ring(ci, e, 5.6, 0.5,
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "light"), 0.9))
				DrawKit.line(ci, e + Vector2(-2, -2), e + Vector2(0, -3.2),
						PaintUtil.with_alpha(Color.WHITE, 0.7), PaintUtil.detail_w(ctx))
			if eyes.size() == 2:
				DrawKit.line(ci, (eyes[0] as Vector2) + Vector2(-5.6, 0),
						(eyes[1] as Vector2) + Vector2(5.6, 0), ink, 1.0)


# ------------------------------------------------------------------ 眼

static func _eyes(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	if bool(ctx["back"]):
		return
	var eye_col := PaintUtil.color(ctx, "primary")
	var deep := PaintUtil.color(ctx, "deep")
	var ink := PaintUtil.ink(ctx)
	var paper := PaintUtil.mat_color(ctx, "paper", "hi")
	var eyes := PaintUtil.eye_positions(ctx)
	var blink: bool = ctx.get("blink", false)
	var mini := PaintUtil.is_mini(ctx)
	var detail := PaintUtil.detail_w(ctx)
	var brow_w := 1.7 if mini else 0.9

	if variant == "visor":
		var band := PaintUtil.face_point(ctx, 0, -2)
		var size := Vector2(23.0 - float(ctx["yaw"]) * 5.0, 7.6)
		DrawKit.layer_shadow(ci, DrawKit._ellipse_points(band, size * 0.5, PaintUtil.head_angle(ctx), 20), 0.10)
		DrawKit.rrect(ci, band, size, 3.0, PaintUtil.head_angle(ctx),
				PaintUtil.with_alpha(eye_col, 0.66), ink, 0.55)
		DrawKit.line(ci, band + Vector2(-6, -1.6), band + Vector2(2, -1.6),
				PaintUtil.with_alpha(Color.WHITE, 0.8), 0.9)
		DrawKit.circle(ci, band + Vector2(size.x * 0.5 - 1, 0), 1.3,
				PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.0)
		return

	for i in eyes.size():
		var e: Vector2 = eyes[i]
		var r := 3.9 if i == 0 else 3.4
		if blink:
			DrawKit.arc(ci, e + Vector2(0, 1), r, PI, TAU, ink, brow_w)
			continue
		match variant:
			"happy":
				DrawKit.arc(ci, e + Vector2(0, 1), r + 0.2, PI, TAU, eye_col, brow_w)
			"fierce":
				DrawKit.circle(ci, e, r, paper, ink, 0.5)
				DrawKit.circle(ci, e + Vector2(0.2, 0.3), r * 0.70, eye_col, ink, 0.0)
				DrawKit.circle(ci, e + Vector2(-r * 0.26, -r * 0.26), r * 0.22, paper, ink, 0.0)
				DrawKit.line(ci, e + Vector2(-r - 1.3, -r - 2.2), e + Vector2(r * 0.6, -r * 0.7),
						ink, brow_w)
			"sleepy":
				DrawKit.arc(ci, e, r + 0.1, 0.0, PI, eye_col, brow_w)
				DrawKit.line(ci, e + Vector2(-r, -r * 0.55), e + Vector2(r, -r * 0.55), ink, 0.8 if mini else 0.45)
			"sparkle":
				DrawKit.star(ci, e, r + 1.0, 4, eye_col, ink, 0.4, 0.36, 0.0)
				DrawKit.circle(ci, e, 0.9, paper, ink, 0.0)
			_:
				DrawKit.circle(ci, e, r, paper, ink, 0.5)
				DrawKit.circle(ci, e + Vector2(0, 0.35), r * 0.70, eye_col, ink, 0.0)
				DrawKit.circle(ci, e + Vector2(-r * 0.28, -r * 0.30), r * 0.24, paper, ink, 0.0)
		# 眉毛：1.5–2px；表情跟随。
		var brow_y := -r - 2.6
		var tilt := 0.0
		if variant == "fierce":
			brow_y = -r - 1.5
			tilt = -0.9 if i == 0 else 0.9
		elif variant == "happy":
			brow_y = -r - 3.4
			tilt = 0.25 if i == 0 else -0.25
		var a := e + Vector2(-3.0, brow_y + tilt)
		var b := e + Vector2(3.2, brow_y - tilt)
		DrawKit.line(ci, a, b, PaintUtil.with_alpha(deep, 0.95), brow_w)
		if not mini:
			DrawKit.line(ci, a + Vector2(0.4, 0.7), b + Vector2(0.4, 0.7),
					PaintUtil.with_alpha(ink, 0.28), detail)


# ------------------------------------------------------------------ 头发

static func _hair(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var hair_base := PaintUtil.color(ctx, "primary")
	# 近黑发色抬到冷炭灰（避免落入“墨色族”），同时让 3–5 束高光可读。
	var col := hair_base.lerp(Color("#5f5868"), 0.55) if hair_base.v < 0.32 \
			else hair_base.lerp(PaintUtil.color(ctx, "light"), 0.30)
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var t := float(ctx["time"])
	var is_back: bool = ctx["back"]
	var mini := PaintUtil.is_mini(ctx)
	var outline := 0.0 if mini else ow * 0.55
	var strand := 0.0 if mini else PaintUtil.detail_w(ctx) * 1.4
	var lag := float(PaintUtil.pose(ctx).get("secondary", 0.0))
	if not is_back:
		lag *= 0.6

	if is_back:
		# 后脑：帽盖 + 3 缕后发，避免“纯圆球”。
		DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, 1)), Vector2(20.5, 21.0), ha, col, ink, ow)
		var base := PaintUtil.head_point(ctx, Vector2(0, 6))
		match variant:
			"long":
				var pts := PackedVector2Array([
					PaintUtil.head_point(ctx, Vector2(-19, -8)),
					PaintUtil.head_point(ctx, Vector2(19, -8)),
					PaintUtil.head_point(ctx, Vector2(23 + lag, 29)),
					PaintUtil.head_point(ctx, Vector2(12, 41 + lag * 0.4)),
					PaintUtil.head_point(ctx, Vector2(1, 37 - lag * 0.2)),
					PaintUtil.head_point(ctx, Vector2(-11, 40 + lag * 0.3)),
					PaintUtil.head_point(ctx, Vector2(-23 + lag, 18)),
				])
				DrawKit.layer_shadow(ci, pts, 0.12)
				DrawKit.polygon(ci, pts, col, ink, outline)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-7, 11)),
						PaintUtil.head_point(ctx, Vector2(-10 + lag, 34)), shade, strand)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(0, 13)),
						PaintUtil.head_point(ctx, Vector2(1 + lag * 0.5, 35)), shade, strand)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(7, 11)),
						PaintUtil.head_point(ctx, Vector2(10 + lag, 33)), shade, strand)
			"bob":
				DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, 9)), Vector2(24, 18), ha, col, ink, outline)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-9, 10)),
						PaintUtil.head_point(ctx, Vector2(-11, 24)), shade, strand)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(9, 10)),
						PaintUtil.head_point(ctx, Vector2(11, 24)), shade, strand)
			"bun":
				for side in [-1.0, 1.0]:
					var bun := PaintUtil.head_point(ctx, Vector2(13.5 * side, -19))
					DrawKit.circle(ci, bun, 7.4, col, ink, outline)
					DrawKit.arc(ci, bun, 4.2, 0.2, 2.5, shade, strand)
					DrawKit.ring(ci, PaintUtil.head_point(ctx, Vector2(10 * side, -15)), 2.2, 1.1,
							PaintUtil.mat_color(ctx, "gold", "base"))
			"mess", "spiky":
				var tufts := 6 if variant == "spiky" else 5
				for i in tufts:
					var a := -PI + PI * float(i) / float(tufts - 1)
					var tuft := PaintUtil.head_point(ctx, Vector2(cos(a) * 17, sin(a) * 17))
					var h := 9.0 if variant == "spiky" else 7.0
					DrawKit.poly_at(ci, tuft, [Vector2(-4, 2), Vector2(0, -h), Vector2(4, 2)], ha,
							col, ink, outline)
			_:
				# 短发背面也加 3 缕短碎发，保证不是圆球。
				for i in 3:
					var x := -11.0 + float(i) * 11.0
					var tip := PaintUtil.head_point(ctx, Vector2(x + lag * 0.4, 22 + absf(x) * 0.12))
					DrawKit.poly_at(ci, tip, [Vector2(-3.6, -6), Vector2(0, 2), Vector2(3.6, -6)],
							ha, col, ink, outline)
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(-3, -5)), 10.5, 3.3, 4.6,
				PaintUtil.with_alpha(light, 0.85), 0.9 if mini else 1.1)
		DrawKit.line(ci, base + Vector2(-13, 4), base + Vector2(-14 + lag, 12), shade, strand)
		DrawKit.line(ci, base + Vector2(13, 4), base + Vector2(14 + lag, 12), shade, strand)
		if not mini:
			# 头发 3–5 束高光带：后脑 4 束，1.5px 宽，1× 可数。
			for i in 4:
				var bx := -1.5 + float(i)
				var top := PaintUtil.head_point(ctx, Vector2(bx * 9.0, 2.0))
				var bot := PaintUtil.head_point(ctx, Vector2(bx * 11.0 + lag * 0.4, 24.0 + absf(bx) * 1.2))
				DrawKit.line(ci, top, bot, PaintUtil.with_alpha(light, 0.55), 0.60)
				DrawKit.line(ci, top + Vector2(0.4, 0.0), bot + Vector2(0.6, 0.0),
						PaintUtil.with_alpha(PaintUtil.highlight(ctx), 0.22), 0.28)
		return

	# 正面/侧面：帽盖 + 鬓发 + 刘海，中央留出脸（眼睛在 y≈+2.6，不能被帽盖压住）。
	DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -14)), Vector2(38.5, 14.5), 7.0, ha,
			col, ink, outline)
	DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-11, -18)),
			PaintUtil.head_point(ctx, Vector2(3, -21)), PaintUtil.with_alpha(light, 0.9), 1.2 if mini else 1.5)
	if not mini:
		# 头顶 4 束高光带（阴影/高光成对，读“发束”而不是一块色）。
		for i in 4:
			var hx := -1.0 + 2.0 * float(i) / 3.0
			var top := PaintUtil.head_point(ctx, Vector2(hx * 12.0 - 1.0, -20.0 + absf(hx) * 1.6))
			var bot := PaintUtil.head_point(ctx, Vector2(hx * 16.5 + 1.5, -7.0 + absf(hx) * 2.6))
			DrawKit.line(ci, top, bot, PaintUtil.with_alpha(shade, 0.55), 0.95)
			DrawKit.line(ci, top + Vector2(-0.5, 0.0), bot + Vector2(-0.4, 0.0),
					PaintUtil.with_alpha(light, 0.55), 0.58)
			DrawKit.line(ci, top + Vector2(0.1, 0.0), bot + Vector2(0.2, 0.0),
					PaintUtil.with_alpha(PaintUtil.highlight(ctx), 0.24), 0.28)

	match variant:
		"short":
			for side in [-1.0, 1.0]:
				if side > 0.0 and float(ctx["yaw"]) >= 0.55:
					continue
				DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(16 * side, 1)),
						[Vector2(-2.5, -5), Vector2(4.0 * side, 5.5), Vector2(-1, 6.5)], ha,
						col, ink, 0.0)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-5, -19)),
					[Vector2(-5, 2), Vector2(0, -5.5), Vector2(5, 2)], ha, col, ink, 0.0)
		"mess":
			for i in 5:
				var x := -16.0 + float(i) * 8.0
				var y := -19.0 - (4.0 if i % 2 == 0 else 0.0)
				DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(x, y)),
						[Vector2(-4, 3), Vector2(0, -8), Vector2(4, 3)], ha, col, ink, 0.0)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-12, -8)),
					[Vector2(-2, 3), Vector2(2, -3), Vector2(4, 3)], ha, col, ink, 0.0)
		"bob":
			for side in [-1.0, 1.0]:
				if side > 0.0 and float(ctx["yaw"]) >= 0.55:
					continue
				var top := PaintUtil.head_point(ctx, Vector2(16.5 * side, -2))
				var bottom := PaintUtil.head_point(ctx, Vector2(19.0 * side + lag * 0.3, 11))
				DrawKit.capsule(ci, top, bottom, 8.4, col, ink, 0.0)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-9, -8)),
					[Vector2(-2, 2), Vector2(6, -2), Vector2(2, 3)], ha, col, ink, 0.0)
		"bun":
			for side in [-1.0, 1.0]:
				var bun := PaintUtil.head_point(ctx, Vector2(13.5 * side, -19))
				DrawKit.circle(ci, bun, 6.8, col, ink, ow * 0.55)
				DrawKit.arc(ci, bun, 3.6, 0.2, 2.6, shade, strand)
				DrawKit.ring(ci, PaintUtil.head_point(ctx, Vector2(10 * side, -15)), 2.2, 1.1,
						PaintUtil.mat_color(ctx, "gold", "base"))
		"long":
			for side in [-1.0, 1.0]:
				if side > 0.0 and float(ctx["yaw"]) >= 0.55:
					continue
				var top := PaintUtil.head_point(ctx, Vector2(16.5 * side, -2))
				var bottom := PaintUtil.head_point(ctx, Vector2(20.5 * side + lag * side, 29))
				DrawKit.capsule(ci, top, bottom, 8.8, col, ink, 0.0)
				DrawKit.line(ci, PaintUtil.lerp_pt(top, bottom, 0.35),
						PaintUtil.lerp_pt(top, bottom, 0.9),
						PaintUtil.with_alpha(light, 0.9), strand)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(9, -8)),
					[Vector2(-1, 2), Vector2(5, -2), Vector2(3, 3)], ha, col, ink, 0.0)
		"spiky":
			for i in 6:
				var a := -PI * 0.92 + PI * 0.84 * float(i) / 5.0
				var base := PaintUtil.head_point(ctx, Vector2(cos(a) * 16.5, sin(a) * 14.5 - 6))
				DrawKit.poly_at(ci, base, [Vector2(-3.2, 3), Vector2(0.8, -9.5), Vector2(3.8, 4)],
						ha + a * 0.12, col, ink, 0.0)
		_:
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-8, -8)),
					[Vector2(-2, 2), Vector2(5, -2), Vector2(2, 3)], ha, col, ink, 0.0)

	if float(ctx["yaw"]) >= 0.55:
		DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-4, -18)),
				[Vector2(-7, 3), Vector2(2, -6.5), Vector2(8, 2)], ha, col, ink, 0.0)
	if not mini:
		DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-12, -16)),
				PaintUtil.head_point(ctx, Vector2(-4, -18)),
				PaintUtil.with_alpha(light, 0.65), PaintUtil.detail_w(ctx))
