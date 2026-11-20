class_name PaintFigure
extends RefCounted

# 身体、头、耳、眼、面具、头发。严格跟随 DollPose 的脊柱/四肢关节。


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


static func _body(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col

	_limb(ci, p["shoulder_l"], p["elbow_l"], p["hand_l"], far, ctx)
	_leg(ci, p["hip_l"], p["knee_l"], p["foot_l"], far, ctx)
	DrawKit.capsule(ci, p["hip"], p["chest"], 24.0, col, ink, ow)
	DrawKit.capsule(ci, (p["shoulder_l"] as Vector2).lerp(p["chest"], 0.25),
			(p["shoulder_r"] as Vector2).lerp(p["chest"], 0.25), 12.0, col, ink, ow)
	DrawKit.capsule(ci, (p["chest"] as Vector2).lerp(p["neck"], 0.62),
			(p["neck"] as Vector2) + Vector2(0, -2), 9.0, shade, ink, ow * 0.6)
	_leg(ci, p["hip_r"], p["knee_r"], p["foot_r"], col, ctx)
	_limb(ci, p["shoulder_r"], p["elbow_r"], p["hand_r"], col, ctx)

	var near_shin := PaintUtil.lerp_pt(p["knee_r"], p["foot_r"], 0.55)
	match variant:
		"grain":
			DrawKit.arc(ci, near_shin, 3.4, 0.2, 2.4, PaintUtil.color(ctx, "light"), 0.8)
			DrawKit.arc(ci, near_shin + Vector2(0, 3), 2.4, 0.4, 2.2, PaintUtil.color(ctx, "deep"), 0.7)
			var fore := PaintUtil.lerp_pt(p["elbow_r"], p["hand_r"], 0.5)
			DrawKit.line(ci, fore + Vector2(-2, -1), fore + Vector2(2, 1), PaintUtil.color(ctx, "deep"), 0.7)
		"patch":
			var fore := PaintUtil.lerp_pt(p["elbow_r"], p["hand_r"], 0.56)
			var angle: float = p["forearm_angle_r"]
			DrawKit.rrect(ci, fore, Vector2(8.5, 6.5), 1.5, angle, shade, ink, ow * 0.55)
			for sx in [-1.0, 1.0]:
				DrawKit.line(ci, fore + Vector2(-3.0 * sx, -2.6).rotated(angle),
						fore + Vector2(-3.0 * sx, -4.0).rotated(angle), PaintUtil.color(ctx, "light"), 0.7)
		"rivet":
			for joint in [p["elbow_r"], p["knee_r"], p["shoulder_r"]]:
				DrawKit.circle(ci, joint, 1.7, PaintUtil.accent(ctx), ink, 0.5)
			var shin := PaintUtil.lerp_pt(p["knee_r"], p["foot_r"], 0.35)
			DrawKit.line(ci, shin + Vector2(-3, 0), shin + Vector2(3, 0), PaintUtil.color(ctx, "deep"), 0.7)
		_:
			DrawKit.line(ci, (p["chest"] as Vector2) + Vector2(4, 4), (p["hip"] as Vector2) + Vector2(5, -2),
					PaintUtil.color(ctx, "shade"), 0.7)


static func _limb(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, col: Color, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	DrawKit.capsule(ci, shoulder, elbow, 7.4, col, ink, ow * 0.85)
	DrawKit.capsule(ci, elbow, hand, 6.4, col, ink, ow * 0.85)
	DrawKit.circle(ci, elbow, 3.5, col.lightened(0.12), ink, ow * 0.55)
	DrawKit.circle(ci, hand, 4.2, col, ink, ow * 0.7)
	var seam := PaintUtil.lerp_pt(shoulder, elbow, 0.55)
	DrawKit.line(ci, seam + Vector2(-2, 0), seam + Vector2(2, 0), col.darkened(0.18), 0.7)


static func _leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, col: Color, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	DrawKit.capsule(ci, hip, knee, 8.8, col, ink, ow * 0.85)
	DrawKit.capsule(ci, knee, foot, 7.6, col, ink, ow * 0.85)
	DrawKit.circle(ci, knee, 4.1, col.lightened(0.12), ink, ow * 0.55)
	DrawKit.ellipse(ci, foot + Vector2(1, -1), Vector2(4.5, 3.6), 0.0, col, ink, ow * 0.45)


static func _head(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var light := PaintUtil.color(ctx, "light")
	var shade := PaintUtil.color(ctx, "shade")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var center: Vector2 = p["head"]
	DrawKit.capsule(ci, p["neck"], center + Vector2(0, 14).rotated(ha), 8.5, shade, ink, ow * 0.55)

	match variant:
		"square":
			DrawKit.rrect(ci, center, Vector2(32, 32), 8.0, ha, col, ink, ow)
		"acorn":
			DrawKit.ellipse(ci, center + Vector2(0, 1).rotated(ha), Vector2(17.5, 19.5), ha, col, ink, ow)
			DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(0, -18)),
					PaintUtil.head_point(ctx, Vector2(2, -24)), shade, 2.0)
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(2, -24)), 2.2, light, ink, ow * 0.45)
		"pebble":
			DrawKit.ellipse(ci, center, Vector2(20, 16.5), ha, col, ink, ow)
		_:
			DrawKit.circle(ci, center, 18.0, col, ink, ow)

	if bool(ctx["back"]):
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(0, 3)), 8.0, 0.4, 2.7, shade, 1.0)
		return

	DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(-6, -7)), Vector2(4.6, 2.8), ha,
			PaintUtil.color(ctx, "light"), ink, 0.0)
	var far_pos := PaintUtil.face_point(ctx, -9.5, 7.0)
	if PaintUtil.far_visible(ctx):
		DrawKit.circle(ci, far_pos, 2.4, PaintUtil.with_alpha(PaintUtil.color(ctx, "blush"), 0.32), ink, 0.0)
	DrawKit.circle(ci, PaintUtil.face_point(ctx, 9.5, 7.0), 2.8,
			PaintUtil.with_alpha(PaintUtil.color(ctx, "blush"), 0.38), ink, 0.0)
	var yaw := float(ctx["yaw"])
	if yaw >= 0.55:
		var nose_bump := PaintUtil.head_point(ctx, Vector2(16.4, 4.5))
		DrawKit.ellipse(ci, nose_bump, Vector2(2.6, 2.0), ha, col, ink, ow * 0.45)
	else:
		var nose := PaintUtil.face_point(ctx, 0.8, 5.4)
		DrawKit.circle(ci, nose, 1.1, PaintUtil.color(ctx, "shade"), ink, 0.0)
	var mouth := PaintUtil.face_point(ctx, 2.4, 9.6)
	DrawKit.arc(ci, mouth, 2.8, 0.32, PI - 0.32, PaintUtil.color(ctx, "deep"), 1.0)


static func _ear(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var col := PaintUtil.color(ctx, "primary")
	var far := PaintUtil.far_color(ctx)
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var near_x := 17.5 - 5.0 * float(ctx["yaw"])
	var near := PaintUtil.head_point(ctx, Vector2(near_x, -1.0))
	var far_pos := PaintUtil.head_point(ctx, Vector2(-17.5, 0))
	if PaintUtil.far_visible(ctx):
		_ear_shape(ci, variant, far_pos, -1.0, far, ctx)
	_ear_shape(ci, variant, near, 1.0, col, ctx)


static func _ear_shape(ci: CanvasItem, variant: String, center: Vector2, side: float, col: Color, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var light := col.lightened(0.25)
	match variant:
		"round":
			DrawKit.circle(ci, center + Vector2(0, 1).rotated(ha), 6.3, col, ink, ow * 0.7)
			DrawKit.circle(ci, center + Vector2(0, 1).rotated(ha), 3.0, light, ink, 0.0)
		"pointy":
			DrawKit.poly_at(ci, center, [
				Vector2(-4.0 * side, -7.0), Vector2(8.5 * side, 0.0),
				Vector2(-4.0 * side, 7.0), Vector2(-1.0 * side, 0.0),
			], ha, col, ink, ow * 0.7)
			DrawKit.line(ci, center + Vector2(-1.0 * side, 0).rotated(ha),
					center + Vector2(4.0 * side, 0).rotated(ha), light, 1.0)
		"horn":
			var base := center + Vector2(0, -4).rotated(ha)
			var tip := center + Vector2(5.5 * side, -15).rotated(ha)
			DrawKit.capsule(ci, base, tip, 5.0, col, ink, ow * 0.65)
			DrawKit.circle(ci, tip, 2.1, PaintUtil.accent(ctx), ink, ow * 0.35)
		"antenna":
			var base := PaintUtil.head_point(ctx, Vector2(8.0 * side, -13.0))
			var wig := PaintUtil.sway(ctx, 2.2, 2.0, float(side))
			var tip := base + Vector2(4.0 * side + wig, -16.0)
			DrawKit.line(ci, base, tip, ink, 2.0)
			DrawKit.line(ci, base, tip, col, 1.0)
			DrawKit.circle(ci, tip, 2.6, PaintUtil.accent(ctx), ink, ow * 0.45)


static func _mask(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	if bool(ctx["back"]):
		return
	var col := PaintUtil.color(ctx, "primary")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var eyes := PaintUtil.eye_positions(ctx)

	match variant:
		"fox":
			var pts := PackedVector2Array()
			for pt in [
				Vector2(-19, -11), Vector2(-14, -21), Vector2(-5, -17), Vector2(0, -19),
				Vector2(5, -17), Vector2(14, -21), Vector2(19, -11), Vector2(16, 6),
				Vector2(0, 18), Vector2(-16, 6),
			]:
				pts.append(PaintUtil.head_point(ctx, pt))
			DrawKit.polygon(ci, pts, col, ink, ow)
			for side in [-1.0, 1.0]:
				DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(14.5 * side, -16)),
						[Vector2(-4, 3), Vector2(2 * side, -9), Vector2(4, 4)], ha,
						col, ink, ow * 0.6)
			DrawKit.ellipse(ci, PaintUtil.face_point(ctx, 0, 8), Vector2(6, 5), ha,
					PaintUtil.color(ctx, "paper"), ink, ow * 0.5)
			DrawKit.poly_at(ci, PaintUtil.face_point(ctx, 0, 10), [
				Vector2(-2.4, -1.5), Vector2(2.4, -1.5), Vector2(0, 2.5),
			], ha, PaintUtil.color(ctx, "ink"), PaintUtil.color(ctx, "ink"), 0.0)
			for e in eyes:
				DrawKit.line(ci, e + Vector2(-6, 5), e + Vector2(-2, 5),
						PaintUtil.color(ctx, "accent"), 1.0)
		"owl":
			for e in eyes:
				DrawKit.ring(ci, e, 6.4, 3.4, ink)
				DrawKit.ring(ci, e, 6.4, 2.0, col)
			var beak := PaintUtil.face_point(ctx, 0, 6)
			DrawKit.poly_at(ci, beak, [
				Vector2(-3.6, -3), Vector2(3.6, -3), Vector2(0, 4.5),
			], ha, PaintUtil.color(ctx, "accent"), ink, ow * 0.45)
			for side in [-1.0, 1.0]:
				var a := PaintUtil.face_point(ctx, 12.0 * side, 2.0)
				DrawKit.line(ci, a, a + Vector2(4.0 * side, -2), PaintUtil.color(ctx, "shade"), 1.0)
		"bandit":
			var band := PaintUtil.face_point(ctx, 0, -2)
			DrawKit.rrect(ci, band, Vector2(30.0, 10.0), 4.0, ha, col, ink, ow)
			var knot := PaintUtil.head_point(ctx, Vector2(17, -2))
			DrawKit.circle(ci, knot, 2.6, PaintUtil.color(ctx, "shade"), ink, ow * 0.4)
			for i in 2:
				var tip := knot + Vector2(8 + i * 2, 5 + i * 5 + PaintUtil.sway(ctx, 3.0, 1.2, i))
				DrawKit.capsule(ci, knot, tip, 3.6 - i * 0.8, PaintUtil.color(ctx, "shade"), ink, ow * 0.4)
		"specs":
			for e in eyes:
				DrawKit.ring(ci, e, 5.4, 1.1, ink)
				DrawKit.ring(ci, e, 5.4, 0.6, col)
				DrawKit.line(ci, e + Vector2(-2, -2), e + Vector2(0, -3.2),
						PaintUtil.with_alpha(Color.WHITE, 0.7), 0.8)
			if eyes.size() == 2:
				DrawKit.line(ci, (eyes[0] as Vector2) + Vector2(-5.4, 0),
						(eyes[1] as Vector2) + Vector2(5.4, 0), ink, 1.1)


static func _eyes(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	if bool(ctx["back"]):
		return
	var eye_col := PaintUtil.color(ctx, "primary")
	var ink := PaintUtil.ink(ctx)
	var eyes := PaintUtil.eye_positions(ctx)
	var blink: bool = ctx.get("blink", false)

	if variant == "visor":
		var band := PaintUtil.face_point(ctx, 0, -2)
		var size := Vector2(22.0 - float(ctx["yaw"]) * 5.0, 7.0)
		DrawKit.rrect(ci, band, size, 3.0, PaintUtil.head_angle(ctx),
				PaintUtil.with_alpha(eye_col, 0.62), ink, 0.9)
		DrawKit.line(ci, band + Vector2(-6, -1.6), band + Vector2(1, -1.6),
				PaintUtil.with_alpha(Color.WHITE, 0.75), 0.9)
		DrawKit.circle(ci, band + Vector2(size.x * 0.5 - 1, 0), 1.2,
				PaintUtil.accent(ctx), ink, 0.3)
		return

	for i in eyes.size():
		var e: Vector2 = eyes[i]
		var r := 3.2 if i == 0 else 2.7
		if blink:
			DrawKit.arc(ci, e + Vector2(0, 1), r, PI, TAU, ink, 1.5)
			continue
		match variant:
			"happy":
				DrawKit.arc(ci, e + Vector2(0, 1), r + 0.3, PI, TAU, eye_col, 1.6)
			"fierce":
				DrawKit.circle(ci, e, r, PaintUtil.color(ctx, "paper"), ink, 0.6)
				DrawKit.circle(ci, e + Vector2(0, 0.3), r * 0.58, eye_col, ink, 0.0)
				DrawKit.line(ci, e + Vector2(-r - 1.2, -r - 2.4), e + Vector2(r * 0.7, -r * 0.9), ink, 1.3)
			"sleepy":
				DrawKit.arc(ci, e, r + 0.2, 0.0, PI, eye_col, 1.7)
				DrawKit.line(ci, e + Vector2(-r, -r * 0.6), e + Vector2(r, -r * 0.6), ink, 0.8)
			"sparkle":
				DrawKit.star(ci, e, r + 1.0, 4, eye_col, ink, 0.4, 0.36, 0.0)
				DrawKit.circle(ci, e, 0.8, PaintUtil.color(ctx, "white"), ink, 0.0)
			_:
				DrawKit.circle(ci, e, r, PaintUtil.color(ctx, "paper"), ink, 0.6)
				DrawKit.circle(ci, e + Vector2(0, 0.4), r * 0.58, eye_col, ink, 0.0)
				DrawKit.circle(ci, e + Vector2(-r * 0.25, -r * 0.25), r * 0.2,
						PaintUtil.color(ctx, "white"), ink, 0.0)


static func _hair(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var t := float(ctx["time"])
	var is_back: bool = ctx["back"]

	if is_back:
		DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, 1)), Vector2(20, 20.5), ha, col, ink, ow)
		match variant:
			"long":
				var sway := sin(t * 2.2) * 2.0
				var pts := PackedVector2Array([
					PaintUtil.head_point(ctx, Vector2(-19, -8)),
					PaintUtil.head_point(ctx, Vector2(19, -8)),
					PaintUtil.head_point(ctx, Vector2(22, 28 + sway)),
					PaintUtil.head_point(ctx, Vector2(9, 39 + sway)),
					PaintUtil.head_point(ctx, Vector2(-11, 36 - sway)),
					PaintUtil.head_point(ctx, Vector2(-23, 17)),
				])
				DrawKit.polygon(ci, pts, col, ink, ow)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-6, 12)),
						PaintUtil.head_point(ctx, Vector2(-9, 32)), shade, 1.1)
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(6, 14)),
						PaintUtil.head_point(ctx, Vector2(9, 34)), shade, 1.1)
			"bob":
				DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, 8)), Vector2(23, 17), ha, col, ink, ow)
			"bun":
				for side in [-1.0, 1.0]:
					var bun := PaintUtil.head_point(ctx, Vector2(12.5 * side, -18))
					DrawKit.circle(ci, bun, 7.0, col, ink, ow * 0.7)
					DrawKit.arc(ci, bun, 4.0, 0.2, 2.5, shade, 0.9)
			"mess":
				for i in 5:
					var a := -PI + PI * float(i) / 4.0
					var tuft := PaintUtil.head_point(ctx, Vector2(cos(a) * 17, sin(a) * 17))
					DrawKit.poly_at(ci, tuft, [Vector2(-4, 2), Vector2(0, -7), Vector2(4, 2)], ha, col, ink, ow * 0.5)
			"spiky":
				for i in 5:
					var a := -PI + PI * float(i) / 4.0
					var tuft := PaintUtil.head_point(ctx, Vector2(cos(a) * 16, sin(a) * 16))
					DrawKit.poly_at(ci, tuft, [Vector2(-3.5, 2), Vector2(1.5, -8), Vector2(4, 2)], ha, col, ink, ow * 0.5)
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(-3, -4)), 10.0, 3.3, 4.6, light, 1.0)
		return

	# 正面/侧面：帽盖 + 鬓发 + 刘海，中央留出脸（眼睛在 y≈+2.4，不能被帽盖压住）。
	DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -14)), Vector2(38, 14), 7.0, ha, col, ink, ow)
	DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-11, -18)),
			PaintUtil.head_point(ctx, Vector2(3, -21)), light, 1.6)

	match variant:
		"short":
			for side in [-1.0, 1.0]:
				if side > 0.0 and float(ctx["yaw"]) >= 0.55:
					continue
				DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(16 * side, 1)),
						[Vector2(-2.5, -5), Vector2(3.5 * side, 5), Vector2(-1, 6)], ha, col, ink, ow * 0.55)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-5, -19)),
					[Vector2(-5, 2), Vector2(0, -5), Vector2(5, 2)], ha, col, ink, ow * 0.55)
		"mess":
			for i in 5:
				var x := -16.0 + float(i) * 8.0
				var y := -19.0 - (4.0 if i % 2 == 0 else 0.0)
				DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(x, y)),
						[Vector2(-4, 3), Vector2(0, -7), Vector2(4, 3)], ha, col, ink, ow * 0.5)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-12, -8)),
					[Vector2(-2, 3), Vector2(2, -3), Vector2(4, 3)], ha, col, ink, ow * 0.5)
		"bob":
			for side in [-1.0, 1.0]:
				if side > 0.0 and float(ctx["yaw"]) >= 0.55:
					continue
				var top := PaintUtil.head_point(ctx, Vector2(16.5 * side, -2))
				var bottom := PaintUtil.head_point(ctx, Vector2(18.5 * side, 10))
				DrawKit.capsule(ci, top, bottom, 8.0, col, ink, ow * 0.7)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-9, -8)),
					[Vector2(-2, 2), Vector2(6, -2), Vector2(2, 3)], ha, col, ink, ow * 0.45)
		"bun":
			for side in [-1.0, 1.0]:
				var bun := PaintUtil.head_point(ctx, Vector2(13 * side, -19))
				DrawKit.circle(ci, bun, 6.6, col, ink, ow * 0.65)
				DrawKit.arc(ci, bun, 3.4, 0.2, 2.6, shade, 0.8)
				DrawKit.ring(ci, PaintUtil.head_point(ctx, Vector2(10 * side, -15)), 2.2, 1.2,
						PaintUtil.accent(ctx))
		"long":
			var sway := sin(t * 2.2) * 1.6
			for side in [-1.0, 1.0]:
				if side > 0.0 and float(ctx["yaw"]) >= 0.55:
					continue
				var top := PaintUtil.head_point(ctx, Vector2(16.5 * side, -2))
				var bottom := PaintUtil.head_point(ctx, Vector2(20.0 * side + sway * side, 28))
				DrawKit.capsule(ci, top, bottom, 8.5, col, ink, ow * 0.7)
				DrawKit.line(ci, PaintUtil.lerp_pt(top, bottom, 0.35),
						PaintUtil.lerp_pt(top, bottom, 0.9), light, 0.9)
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(9, -8)),
					[Vector2(-1, 2), Vector2(5, -2), Vector2(3, 3)], ha, col, ink, ow * 0.45)
		"spiky":
			for i in 6:
				var a := -PI * 0.92 + PI * 0.84 * float(i) / 5.0
				var base := PaintUtil.head_point(ctx, Vector2(cos(a) * 16, sin(a) * 14 - 6))
				DrawKit.poly_at(ci, base, [Vector2(-3.2, 3), Vector2(0.8, -8), Vector2(3.8, 4)],
						ha + a * 0.12, col, ink, ow * 0.5)
		_:
			DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-8, -8)),
					[Vector2(-2, 2), Vector2(5, -2), Vector2(2, 3)], ha, col, ink, ow * 0.45)

	if float(ctx["yaw"]) >= 0.55:
		DrawKit.poly_at(ci, PaintUtil.head_point(ctx, Vector2(-4, -18)),
				[Vector2(-7, 3), Vector2(2, -6), Vector2(8, 2)], ha, col, ink, ow * 0.5)
