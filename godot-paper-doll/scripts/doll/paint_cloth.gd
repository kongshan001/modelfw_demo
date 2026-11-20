class_name PaintCloth
extends RefCounted

# 披风/背饰/下装/上衣/鞋/腰带/手套：全部锚定到同一骨架的关节与骨链。


static func paint(ci: CanvasItem, slot: String, variant: String, ctx: Dictionary) -> void:
	match slot:
		"cape":
			_cape(ci, variant, ctx)
		"backpack":
			_backpack(ci, variant, ctx)
		"pants":
			_pants(ci, variant, ctx)
		"shirt":
			_shirt(ci, variant, ctx)
		"shoes":
			_shoes(ci, variant, ctx)
		"belt":
			_belt(ci, variant, ctx)
		"gloves":
			_gloves(ci, variant, ctx)


static func _cape(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var t := float(ctx["time"])
	var sway := sin(t * 3.1) * 2.2 + absf(float(p["stride"])) * 2.5

	if variant == "scarf":
		var neck: Vector2 = p["neck"] + Vector2(0, 3)
		var lean: float = p["torso_lean"]
		var a := neck + Vector2(-11, 0).rotated(lean)
		var b := neck + Vector2(11, 0).rotated(lean)
		var tail_end := neck + Vector2(-12 - sway, 23).rotated(lean * 0.5)
		DrawKit.capsule(ci, neck, tail_end, 9.0, shade, ink, ow * 0.8)
		DrawKit.capsule(ci, a, b, 8.0, col, ink, ow * 0.8)
		for i in 3:
			DrawKit.line(ci, tail_end + Vector2(-3 + i * 3, 1), tail_end + Vector2(-4 + i * 3, 7),
					col.lightened(0.2), 1.0)
		return

	var drop := 14.0 if variant == "short" else 38.0
	var top_l: Vector2 = p["shoulder_l"] + Vector2(-3, 2)
	var top_r: Vector2 = p["shoulder_r"] + Vector2(3, 2)
	var hip: Vector2 = p["hip"]
	var bottom_r := hip + Vector2(24, drop)
	var bottom_l := hip + Vector2(-24 - sway, drop)
	var mid_r := hip + Vector2(10, drop + 3 + sway * 0.4)
	var mid_l := hip + Vector2(-10, drop - 1 - sway * 0.4)
	var pts := PackedVector2Array([top_l, top_r, bottom_r, mid_r, mid_l, bottom_l])
	DrawKit.polygon(ci, pts, col, ink, ow)

	var inner := PackedVector2Array([
		top_l.lerp(top_r, 0.38), top_r.lerp(top_l, 0.24),
		hip + Vector2(14, drop - 4), hip + Vector2(2, drop + 5),
		hip + Vector2(-13, drop - 2),
	])
	DrawKit.polygon(ci, inner, PaintUtil.with_alpha(light, 0.55), ink, 0.0)
	DrawKit.circle(ci, (p["neck"] as Vector2) + Vector2(0, 3), 3.0, PaintUtil.accent(ctx), ink, ow * 0.4)

	if bool(ctx["back"]):
		DrawKit.star(ci, hip + Vector2(0, drop * 0.45), 6.0, 4,
				PaintUtil.with_alpha(light, 0.8), ink, 0.6, 0.4, 0.4)
		DrawKit.arc(ci, hip + Vector2(0, drop * 0.45), 10.0, 0.3, 2.8, shade, 0.8)
	else:
		DrawKit.line(ci, top_l + Vector2(2, 5), bottom_l + Vector2(4, -3), shade, 0.9)


static func _backpack(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var chest: Vector2 = p["chest"]
	var hip: Vector2 = p["hip"]
	var t := float(ctx["time"])

	match variant:
		"satchel":
			var center := chest + Vector2(-9, 9)
			DrawKit.rrect(ci, center, Vector2(22, 24), 4.5, 0.0, col, ink, ow)
			DrawKit.rrect(ci, center + Vector2(0, -5), Vector2(23, 11), 4.0, 0.0, shade, ink, ow * 0.8)
			DrawKit.circle(ci, center + Vector2(0, -1), 2.2, PaintUtil.accent(ctx), ink, 0.5)
			DrawKit.line(ci, hip + Vector2(-17, -10), hip + Vector2(-9, 13), PaintUtil.with_alpha(ink, 0.6), 1.2)
		"shell":
			var center := chest + Vector2(0, 7)
			DrawKit.ellipse(ci, center, Vector2(24, 26), 0.0, col, ink, ow)
			for i in 3:
				DrawKit.arc(ci, center + Vector2(0, 4 + i * 5), 19.0 - i * 5.0, PI + 0.2, TAU - 0.2, shade, 1.2)
			DrawKit.arc(ci, center, 23.0, -2.6, -0.5, light, 1.4)
		"wings":
			var flap := sin(t * 7.0) * 4.0
			for side in [-1.0, 1.0]:
				var root := chest + Vector2(0, -2)
				var tip := root + Vector2(33 * side, -16 + flap)
				var mid1 := root + Vector2(17 * side, 2 + flap * 0.5)
				var mid2 := root + Vector2(24 * side, 13 + flap)
				var wing_col: Color = PaintUtil.far_color(ctx) if side < 0 else col
				DrawKit.polygon(ci, PackedVector2Array([
					root, tip, tip + Vector2(-4 * side, 9), mid2, mid1,
				]), wing_col, ink, ow * 0.7)
				DrawKit.line(ci, root, tip, PaintUtil.with_alpha(light, 0.7), 1.0)
			for i in 2:
				DrawKit.circle(ci, chest + Vector2(-3 + i * 6, 1), 1.2, PaintUtil.accent(ctx), ink, 0.3)
		"lantern":
			var top := chest + Vector2(-15, -3)
			var center := chest + Vector2(-15, 17)
			DrawKit.line(ci, top, center + Vector2(0, -8), ink, 1.0)
			DrawKit.circle(ci, center, 10.0, PaintUtil.with_alpha(PaintUtil.accent(ctx), 0.20), ink, 0.0)
			DrawKit.rrect(ci, center, Vector2(10, 14), 3.0, 0.0, col, ink, ow * 0.7)
			DrawKit.line(ci, center + Vector2(-4, -7), center + Vector2(4, -7), shade, 2.0)
			DrawKit.line(ci, center + Vector2(-4, 7), center + Vector2(4, 7), shade, 2.0)
			DrawKit.star(ci, center, 2.4, 4, PaintUtil.accent(ctx), ink, 0.3, 0.4)


static func _pants(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col

	if variant == "skirt":
		var hip: Vector2 = p["hip"]
		var lean: float = p["torso_lean"]
		var sway := sin(float(ctx["time"]) * 3.0) * 1.2
		var pts := PackedVector2Array([
			hip + Vector2(-13, -3).rotated(lean),
			hip + Vector2(13, -3).rotated(lean),
			hip + Vector2(23 + sway, 22),
			hip + Vector2(13, 27),
			hip + Vector2(0, 24 + sway),
			hip + Vector2(-14, 27),
			hip + Vector2(-23 - sway, 21),
		])
		DrawKit.polygon(ci, pts, col, ink, ow)
		DrawKit.line(ci, hip + Vector2(-20, 19), hip + Vector2(20, 19), light, 1.4)
		for i in 3:
			DrawKit.line(ci, hip + Vector2(-10 + i * 8, 5), hip + Vector2(-14 + i * 9, 25),
					shade, 0.9)
		return

	_pants_leg(ci, p["hip_l"], p["knee_l"], p["foot_l"], far, variant, ctx)
	_pants_leg(ci, p["hip_r"], p["knee_r"], p["foot_r"], col, variant, ctx)
	var hip: Vector2 = p["hip"]
	var lean: float = p["torso_lean"]
	DrawKit.capsule(ci, hip + Vector2(-11, -6).rotated(lean), hip + Vector2(11, -6).rotated(lean),
			10.0, col, ink, ow * 0.7)


static func _pants_leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, col: Color, variant: String, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var width := 8.6
	if variant == "leggings":
		width = 7.2
	DrawKit.capsule(ci, hip, knee, width, col, ink, ow * 0.8)
	if variant == "shorts":
		DrawKit.capsule(ci, knee + (hip - knee) * 0.16, knee, width + 0.6, col, ink, ow * 0.6)
	else:
		var ankle := foot.lerp(knee, 0.12)
		DrawKit.capsule(ci, knee, ankle, width - 0.6, col, ink, ow * 0.8)
		DrawKit.line(ci, ankle + Vector2(-3, 0), ankle + Vector2(3, 0), PaintUtil.color(ctx, "shade"), 1.0)
	if variant == "leggings":
		DrawKit.line(ci, hip.lerp(knee, 0.25), knee.lerp(foot, 0.2), PaintUtil.color(ctx, "light"), 0.8)


static func _shirt(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var lean: float = p["torso_lean"]
	var hip: Vector2 = p["hip"]
	var chest: Vector2 = p["chest"]
	var neck: Vector2 = p["neck"]
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col

	var sleeves := true
	var full_sleeves := false
	match variant:
		"vest":
			sleeves = false
		"hoodie":
			full_sleeves = true
		"dress":
			full_sleeves = false

	if variant == "hoodie":
		DrawKit.ellipse(ci, neck + Vector2(0, -1).rotated(lean), Vector2(22, 15), lean,
				shade, ink, ow * 0.8)
	if variant == "dress":
		for side in [-1.0, 1.0]:
			var shoulder: Vector2 = p["shoulder_r"] if side > 0 else p["shoulder_l"]
			DrawKit.circle(ci, shoulder + Vector2(2 * side, 1), 6.4,
					far if side < 0 else col, ink, ow * 0.7)

	if sleeves:
		_sleeve(ci, p["shoulder_l"], p["elbow_l"], p["hand_l"], far, full_sleeves, ctx)
	DrawKit.capsule(ci, hip, chest, 26.0, col, ink, ow)
	DrawKit.capsule(ci, (p["shoulder_l"] as Vector2).lerp(chest, 0.25),
			(p["shoulder_r"] as Vector2).lerp(chest, 0.25), 14.0, col, ink, ow)
	match variant:
		"tunic":
			DrawKit.rrect(ci, hip + Vector2(0, 5).rotated(lean), Vector2(31, 11), 3.5, lean, col, ink, ow * 0.9)
			DrawKit.line(ci, hip + Vector2(-13, 7).rotated(lean), hip + Vector2(13, 7).rotated(lean),
					shade, 1.2)
			DrawKit.line(ci, neck + Vector2(-5, 3), neck + Vector2(0, 12), shade, 1.1)
			DrawKit.line(ci, neck + Vector2(5, 3), neck + Vector2(0, 12), shade, 1.1)
			DrawKit.circle(ci, neck + Vector2(0, 13), 1.3, PaintUtil.accent(ctx), ink, 0.3)
		"hoodie":
			DrawKit.line(ci, hip + Vector2(-12, 6).rotated(lean), hip + Vector2(12, 6).rotated(lean),
					shade, 1.1)
			DrawKit.rrect(ci, hull(hip, -6, 13, lean), Vector2(15, 9), 3.0, lean, shade, ink, 0.0)
			for side in [-1.0, 1.0]:
				DrawKit.line(ci, neck + Vector2(4 * side, 8), neck + Vector2(6 * side, 15), light, 1.0)
				DrawKit.circle(ci, neck + Vector2(6 * side, 16), 1.1, PaintUtil.accent(ctx), ink, 0.2)
		"vest":
			DrawKit.rrect(ci, chest.lerp(hip, 0.35), Vector2(6, 31), 2.0, lean,
					PaintUtil.color(ctx, "paper"), ink, 0.0)
			DrawKit.poly_at(ci, neck + Vector2(-5, 1).rotated(lean),
					[Vector2(0, 0), Vector2(5, 1), Vector2(2, 9)], lean, shade, ink, ow * 0.4)
			DrawKit.poly_at(ci, neck + Vector2(5, 1).rotated(lean),
					[Vector2(0, 0), Vector2(-5, 1), Vector2(-2, 9)], lean, shade, ink, ow * 0.4)
			for i in 3:
				DrawKit.circle(ci, chest.lerp(hip, 0.30 + i * 0.18) + Vector2(-1, 0), 1.25,
						PaintUtil.accent(ctx), ink, 0.3)
		"armor":
			var plate := chest.lerp(hip, 0.38)
			DrawKit.rrect(ci, plate, Vector2(27, 28), 7.0, lean, col, ink, ow)
			DrawKit.line(ci, plate + Vector2(-8, -8).rotated(lean), plate + Vector2(8, -8).rotated(lean),
					light, 1.4)
			for side in [-1.0, 1.0]:
				var shoulder: Vector2 = p["shoulder_r"] if side > 0 else p["shoulder_l"]
				DrawKit.circle(ci, shoulder + Vector2(4 * side, -1), 6.6, col, ink, ow)
				DrawKit.circle(ci, shoulder + Vector2(2 * side, -1), 2.1, PaintUtil.accent(ctx), ink, 0.4)
			for i in 2:
				DrawKit.circle(ci, plate + Vector2(-10 + i * 20, 7).rotated(lean), 1.6,
						PaintUtil.accent(ctx), ink, 0.3)
			DrawKit.line(ci, plate + Vector2(0, -12), plate + Vector2(0, 12).rotated(lean), shade, 1.0)
		"dress":
			var skirt := PackedVector2Array([
				hip + Vector2(-14, -2).rotated(lean),
				hip + Vector2(14, -2).rotated(lean),
				hip + Vector2(23, 27),
				hip + Vector2(10, 31),
				hip + Vector2(0, 28),
				hip + Vector2(-11, 31),
				hip + Vector2(-23, 26),
			])
			DrawKit.polygon(ci, skirt, col, ink, ow)
			DrawKit.line(ci, hip + Vector2(-21, 23), hip + Vector2(21, 23), light, 1.5)
			for i in 3:
				DrawKit.line(ci, hip + Vector2(-9 + i * 9, 3), hip + Vector2(-13 + i * 10, 28),
						shade, 0.9)
			DrawKit.arc(ci, neck + Vector2(0, 3), 8.0, 0.2, PI - 0.2, PaintUtil.color(ctx, "paper"), 1.4)
		_:
			DrawKit.line(ci, hip + Vector2(-11, 3).rotated(lean), hip + Vector2(11, 3).rotated(lean),
					shade, 1.0)
	if sleeves:
		_sleeve(ci, p["shoulder_r"], p["elbow_r"], p["hand_r"], col, full_sleeves, ctx)


static func hull(center: Vector2, dx: float, dy: float, rot: float) -> Vector2:
	return center + Vector2(dx, dy).rotated(rot)


static func _sleeve(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, col: Color, full: bool, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	DrawKit.capsule(ci, shoulder, elbow.lerp(shoulder, 0.06), 10.0, col, ink, ow * 0.8)
	if full:
		DrawKit.capsule(ci, elbow, hand.lerp(elbow, 0.10), 7.6, col, ink, ow * 0.75)
		DrawKit.capsule(ci, hand.lerp(elbow, 0.16), hand.lerp(elbow, 0.06), 7.0,
				PaintUtil.color(ctx, "shade"), ink, ow * 0.5)
	else:
		DrawKit.capsule(ci, elbow.lerp(shoulder, 0.02), elbow.lerp(shoulder, 0.14), 10.0,
				PaintUtil.color(ctx, "shade"), ink, ow * 0.5)


static func _shoes(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col
	_shoe(ci, p["foot_l"], float(p["foot_angle_l"]), far, variant, ctx)
	_shoe(ci, p["foot_r"], float(p["foot_angle_r"]), col, variant, ctx)


static func _shoe(ci: CanvasItem, foot: Vector2, angle: float, col: Color, variant: String, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var center := foot + Vector2(2.5, 0.5).rotated(angle)
	match variant:
		"boots":
			DrawKit.capsule(ci, center + Vector2(-1, -7), center + Vector2(0, 1), 8.0, shade, ink, ow * 0.6)
			DrawKit.rrect(ci, center, Vector2(16.5, 9.5), 3.6, angle, col, ink, ow)
			DrawKit.line(ci, center + Vector2(-6, 3.6).rotated(angle), center + Vector2(6, 3.6).rotated(angle),
					shade, 1.2)
			DrawKit.arc(ci, center + Vector2(4, -1).rotated(angle), 3.4, -0.6, 1.2, light, 1.0)
		"sneakers":
			DrawKit.rrect(ci, center + Vector2(0, 3).rotated(angle), Vector2(17, 5), 2.4, angle,
					PaintUtil.color(ctx, "paper"), ink, ow * 0.7)
			DrawKit.rrect(ci, center, Vector2(14.5, 8), 3.2, angle, col, ink, ow)
			DrawKit.ellipse(ci, center + Vector2(5, 1).rotated(angle), Vector2(3.4, 3.0), angle, light, ink, ow * 0.3)
			for i in 2:
				DrawKit.line(ci, center + Vector2(-4 + i * 3, -2).rotated(angle),
						center + Vector2(-2 + i * 3, 1).rotated(angle), PaintUtil.color(ctx, "paper"), 1.0)
		"clogs":
			DrawKit.rrect(ci, center + Vector2(0, 2.5).rotated(angle), Vector2(16, 5), 2.4, angle,
					PaintUtil.color(ctx, "primary").lightened(0.20), ink, ow * 0.7)
			DrawKit.rrect(ci, center - Vector2(0, 1).rotated(angle), Vector2(12, 5), 2.4, angle,
					col, ink, ow * 0.6)
			for i in 2:
				DrawKit.capsule(ci, center + Vector2(-4 + i * 7, -4).rotated(angle),
						center + Vector2(-1 + i * 7, 2).rotated(angle), 2.2, PaintUtil.accent(ctx), ink, 0.3)
		"bare":
			DrawKit.ellipse(ci, center, Vector2(7.5, 4.5), angle, col, ink, ow * 0.6)
			for i in 3:
				DrawKit.circle(ci, center + Vector2(4.2 + i * 1.2, -1 + i * 1.0).rotated(angle), 1.2,
						col.lightened(0.16), ink, 0.2)


static func _belt(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var hip: Vector2 = p["hip"]
	var lean: float = p["torso_lean"]
	var a := hip + Vector2(-14, -5).rotated(lean)
	var b := hip + Vector2(14, -5).rotated(lean)

	DrawKit.capsule(ci, a, b, 7.0, col, ink, ow * 0.7)
	match variant:
		"rope":
			DrawKit.line(ci, a.lerp(b, 0.15), a.lerp(b, 0.85), shade, 1.2)
			var knot := b + Vector2(-2, 0)
			DrawKit.circle(ci, knot, 3.0, col, ink, ow * 0.4)
			for i in 2:
				var tail := knot + Vector2(3 + i * 2, 5 + i * 6 + sin(float(ctx["time"]) * 3.0 + i) * 1.2)
				DrawKit.capsule(ci, knot, tail, 2.6 - i * 0.5, shade, ink, ow * 0.35)
		"sash":
			DrawKit.capsule(ci, a + Vector2(0, 1), b + Vector2(0, 1), 9.0, col, ink, ow * 0.75)
			DrawKit.line(ci, a + Vector2(1, -2), b + Vector2(-1, -2), PaintUtil.color(ctx, "light"), 1.0)
			var tail := PackedVector2Array([
				b + Vector2(-3, 3), b + Vector2(4, 3),
				b + Vector2(6, 17), b + Vector2(1, 20), b + Vector2(-2, 14),
			])
			DrawKit.polygon(ci, tail, shade, ink, ow * 0.5)
		"pouch":
			var pouch := hip + Vector2(12, 7).rotated(lean)
			DrawKit.rrect(ci, pouch, Vector2(11, 13), 3.0, lean, shade, ink, ow * 0.6)
			DrawKit.rrect(ci, pouch + Vector2(0, -5).rotated(lean), Vector2(11.5, 5), 2.0, lean,
					col, ink, ow * 0.4)
			DrawKit.circle(ci, pouch + Vector2(0, -1).rotated(lean), 1.3, PaintUtil.accent(ctx), ink, 0.3)


static func _gloves(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col
	if PaintUtil.far_visible(ctx):
		_glove(ci, variant, p["elbow_l"], p["hand_l"], far, ctx)
	_glove(ci, variant, p["elbow_r"], p["hand_r"], col, ctx)


static func _glove(ci: CanvasItem, variant: String, elbow: Vector2, hand: Vector2, col: Color, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var shade := PaintUtil.color(ctx, "shade")
	match variant:
		"mittens":
			DrawKit.capsule(ci, elbow.lerp(hand, 0.66), hand, 6.6, col, ink, ow * 0.65)
			DrawKit.circle(ci, hand, 5.2, col, ink, ow * 0.75)
			DrawKit.circle(ci, hand + (elbow - hand).normalized().rotated(0.9) * 4.0, 2.2, col, ink, ow * 0.4)
			DrawKit.line(ci, elbow.lerp(hand, 0.72) + Vector2(-2, -2), elbow.lerp(hand, 0.72) + Vector2(2, 2),
					PaintUtil.color(ctx, "light"), 1.0)
		"bracers":
			DrawKit.capsule(ci, elbow.lerp(hand, 0.42), hand, 6.8, col, ink, ow * 0.7)
			for i in 2:
				var t := 0.55 + i * 0.22
				var c := elbow.lerp(hand, t)
				DrawKit.line(ci, c + Vector2(-3, -2), c + Vector2(3, 2), PaintUtil.accent(ctx), 1.0)
			DrawKit.circle(ci, hand, 4.2, col, ink, ow * 0.55)
		"claws":
			DrawKit.circle(ci, hand, 5.0, col, ink, ow * 0.7)
			var dir := (hand - elbow).normalized()
			for i in 3:
				var a := dir.rotated(-0.45 + i * 0.45)
				var tip := hand + a * 8.0
				DrawKit.poly_at(ci, hand + a * 2.0, [
					Vector2(-1.6, 0), Vector2(0, 6.5), Vector2(1.6, 0),
				], a.angle() + PI * 0.5, PaintUtil.color(ctx, "paper"), ink, 0.3)
			DrawKit.line(ci, elbow.lerp(hand, 0.55), hand, shade, 1.0)
