class_name PaintProps
extends RefCounted

# 气场/帽子/武器/挂饰：武器围绕手部旋转，帽饰围绕头心旋转。


static func paint(ci: CanvasItem, slot: String, variant: String, ctx: Dictionary) -> void:
	match slot:
		"aura":
			_aura(ci, variant, ctx)
		"hat":
			_hat(ci, variant, ctx)
		"weapon":
			_weapon(ci, variant, ctx)
		"accessory":
			_accessory(ci, variant, ctx)


static func _aura(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var light := PaintUtil.color(ctx, "light")
	var accent := PaintUtil.accent(ctx)
	var ink := PaintUtil.ink(ctx)
	var t := float(ctx["time"])
	var center: Vector2 = (p["hip"] as Vector2) + Vector2(0, -58)
	var head: Vector2 = p["head"]

	match variant:
		"spark":
			for i in 7:
				var a := t * 0.55 + TAU * float(i) / 7.0
				var pos := center + Vector2(cos(a) * 46.0, sin(a) * 66.0)
				var twinkle := 0.55 + 0.45 * sin(t * 3.0 + i * 1.7)
				DrawKit.star(ci, pos, 3.2 + twinkle * 2.6, 4,
						PaintUtil.with_alpha(col, 0.82), ink, 0.5, 0.34, a)
		"leaf":
			for i in 6:
				var a := t * 0.7 + TAU * float(i) / 6.0
				var pos := center + Vector2(cos(a) * 42.0, sin(a) * 58.0)
				DrawKit.ellipse(ci, pos, Vector2(5.2, 2.4), a + PI * 0.5,
						PaintUtil.with_alpha(col, 0.8), ink, 0.5)
				DrawKit.line(ci, pos, pos + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 5.0,
						PaintUtil.with_alpha(light, 0.8), 0.7)
		"flame":
			for i in 3:
				var base := center + Vector2(-17 + i * 17, 44 + sin(t * 3.0 + i) * 2.0)
				var h := 22.0 + sin(t * 5.0 + i * 1.4) * 4.0
				DrawKit.polygon(ci, PackedVector2Array([
					base + Vector2(-6, 8), base + Vector2(-2, -h * 0.4),
					base + Vector2(0, -h), base + Vector2(3, -h * 0.35),
					base + Vector2(7, 8),
				]), PaintUtil.with_alpha(col if i % 2 == 0 else accent, 0.55), ink, 0.0)
				DrawKit.circle(ci, base + Vector2(0, 1), 4.5,
						PaintUtil.with_alpha(light, 0.5), ink, 0.0)
		"bubble":
			for i in 8:
				var phase := fposmod(t * 0.22 + float(i) * 0.13, 1.0)
				var pos := center + Vector2(sin(i * 2.1 + t * 0.7) * 26.0, 58.0 - phase * 118.0)
				var r := 2.4 + float(i % 3) * 1.4
				DrawKit.circle(ci, pos, r, PaintUtil.with_alpha(col, 0.10), PaintUtil.with_alpha(col, 0.55), 0.7)
				DrawKit.circle(ci, pos + Vector2(-r * 0.3, -r * 0.3), r * 0.22,
						PaintUtil.with_alpha(light, 0.7), ink, 0.0)
		"halo":
			var halo := head + Vector2(0, -34)
			DrawKit.ellipse(ci, halo, Vector2(27, 7), 0.0, PaintUtil.with_alpha(col, 0.10),
					PaintUtil.with_alpha(accent, 0.85), 1.4)
			DrawKit.ellipse(ci, halo, Vector2(19, 4.5), 0.0, Color(0, 0, 0, 0),
					PaintUtil.with_alpha(light, 0.55), 0.8)
			for i in 4:
				var a := t * 0.8 + TAU * float(i) / 4.0
				var pos := halo + Vector2(cos(a) * 33.0, sin(a) * 10.0)
				DrawKit.star(ci, pos, 2.2 + sin(t * 3.0 + i) * 0.8, 4,
						PaintUtil.with_alpha(accent, 0.8), ink, 0.3, 0.35)


static func _hat(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var accent := PaintUtil.accent(ctx)
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)

	match variant:
		"beanie":
			DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, -21)), Vector2(19, 13), ha, col, ink, ow)
			DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -12)), Vector2(38, 7), 3.0, ha, shade, ink, ow * 0.8)
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(0, -34)), 5.2, light, ink, ow * 0.7)
			for i in 3:
				DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(-8 + i * 8, -22)), 3.0, 0.2, 2.6, light, 0.7)
		"acorn":
			DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, -20)), Vector2(18, 11), ha, col, ink, ow)
			DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -12)), Vector2(38, 7), 3.0, ha, shade, ink, ow * 0.8)
			DrawKit.capsule(ci, PaintUtil.head_point(ctx, Vector2(0, -28)), PaintUtil.head_point(ctx, Vector2(2, -35)),
					2.4, shade, ink, ow * 0.35)
			for i in 3:
				var x := -8.0 + i * 8.0
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(x, -26)),
						PaintUtil.head_point(ctx, Vector2(x + 4, -18)), PaintUtil.with_alpha(light, 0.6), 0.7)
		"wizard":
			DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, -12)), Vector2(24, 6), ha, shade, ink, ow * 0.8)
			var pts := PackedVector2Array()
			for pt in [Vector2(-14, -13), Vector2(-8, -36), Vector2(0, -46), Vector2(11, -13)]:
				pts.append(PaintUtil.head_point(ctx, pt))
			DrawKit.polygon(ci, pts, col, ink, ow)
			DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -15)), Vector2(29, 5), 2.0, ha, accent, ink, 0.0)
			DrawKit.star(ci, PaintUtil.head_point(ctx, Vector2(-1, -28)), 4.0, 5,
					PaintUtil.with_alpha(light, 0.9), ink, 0.4, 0.45)
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(2, -46)), 2.0, accent, ink, 0.3)
		"crown":
			var band := PaintUtil.head_point(ctx, Vector2(0, -20))
			DrawKit.rrect(ci, band, Vector2(27, 6), 2.0, ha, accent, ink, ow * 0.7)
			var spikes := PackedVector2Array([
				PaintUtil.head_point(ctx, Vector2(-13, -21)),
				PaintUtil.head_point(ctx, Vector2(-9, -32)),
				PaintUtil.head_point(ctx, Vector2(-4, -23)),
				PaintUtil.head_point(ctx, Vector2(0, -34)),
				PaintUtil.head_point(ctx, Vector2(4, -23)),
				PaintUtil.head_point(ctx, Vector2(9, -32)),
				PaintUtil.head_point(ctx, Vector2(13, -21)),
			])
			DrawKit.polygon(ci, spikes, accent, ink, ow * 0.7)
			for i in 3:
				DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(-8 + i * 8, -24)), 1.5,
						PaintUtil.with_alpha(Color.WHITE, 0.8), ink, 0.25)
		"leaf":
			var center := PaintUtil.head_point(ctx, Vector2(7, -26))
			DrawKit.ellipse(ci, center, Vector2(9, 17), ha + 0.55, col, ink, ow)
			DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(0, -14)),
					PaintUtil.head_point(ctx, Vector2(3, -38)), shade, 1.5)
			for i in 3:
				var y := -32.0 + i * 5.0
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(3, y)),
						PaintUtil.head_point(ctx, Vector2(10, y + 3)), light, 0.7)


static func _weapon(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var hand: Vector2 = p["hand_r"]
	var ang: float = p["weapon_angle"]
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var light := PaintUtil.color(ctx, "light")
	var accent := PaintUtil.accent(ctx)
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)

	match variant:
		"sword":
			DrawKit.rrect(ci, hand + Vector2(0, -22).rotated(ang), Vector2(7, 30), 2.0, ang, light, ink, ow * 0.7)
			DrawKit.line(ci, hand + Vector2(0, -10).rotated(ang), hand + Vector2(0, -33).rotated(ang),
					PaintUtil.with_alpha(Color.WHITE, 0.55), 1.0)
			DrawKit.rrect(ci, hand + Vector2(0, -6).rotated(ang), Vector2(18, 3.2), 1.2, ang, accent, ink, ow * 0.5)
			DrawKit.rrect(ci, hand + Vector2(0, 2).rotated(ang), Vector2(5, 11), 1.8, ang, shade, ink, ow * 0.5)
			DrawKit.circle(ci, hand + Vector2(0, 8.5).rotated(ang), 3.0, accent, ink, ow * 0.4)
		"hammer":
			DrawKit.capsule(ci, hand + Vector2(0, 11).rotated(ang), hand + Vector2(0, -22).rotated(ang),
					5.0, shade, ink, ow * 0.5)
			DrawKit.rrect(ci, hand + Vector2(0, -26).rotated(ang), Vector2(22, 13), 3.2, ang, col, ink, ow)
			DrawKit.line(ci, hand + Vector2(-8, -29).rotated(ang), hand + Vector2(8, -29).rotated(ang),
					light, 1.2)
			DrawKit.circle(ci, hand + Vector2(0, -26).rotated(ang), 1.8, accent, ink, 0.3)
		"staff":
			DrawKit.capsule(ci, hand + Vector2(0, 15).rotated(ang), hand + Vector2(0, -43).rotated(ang),
					4.6, col, ink, ow * 0.55)
			var crook := PackedVector2Array()
			for pt in [Vector2(0, -43), Vector2(6, -48), Vector2(5, -55), Vector2(-1, -55), Vector2(-5, -49)]:
				crook.append(hand + pt.rotated(ang))
			DrawKit.polyline(ci, crook, ink, 4.4)
			DrawKit.polyline(ci, crook, light, 2.2)
			DrawKit.star(ci, hand + Vector2(-1, -55).rotated(ang), 5.2, 4, accent, ink, 0.5, 0.4)
			DrawKit.line(ci, hand + Vector2(0, -6).rotated(ang), hand + Vector2(0, -37).rotated(ang),
					PaintUtil.with_alpha(light, 0.5), 0.8)
		"fan":
			var pivot := hand + Vector2(0, -5).rotated(ang)
			var pts := PackedVector2Array([pivot])
			for i in 9:
				var a := PI + 0.3 + (PI - 0.6) * float(i) / 8.0
				pts.append(pivot + Vector2(cos(a), sin(a)).rotated(ang) * 23.0)
			DrawKit.polygon(ci, pts, light, ink, ow * 0.8)
			for i in 5:
				var a := PI + 0.45 + (PI - 0.9) * float(i) / 4.0
				DrawKit.line(ci, pivot, pivot + Vector2(cos(a), sin(a)).rotated(ang) * 21.0, shade, 0.8)
			DrawKit.polyline(ci, pts, accent, 1.3)
			DrawKit.capsule(ci, hand + Vector2(0, 9).rotated(ang), pivot, 4.0, shade, ink, ow * 0.5)
			DrawKit.circle(ci, pivot, 2.2, accent, ink, 0.4)
		"spoon":
			DrawKit.capsule(ci, hand + Vector2(0, 10).rotated(ang), hand + Vector2(0, -18).rotated(ang),
					4.2, col, ink, ow * 0.5)
			DrawKit.ellipse(ci, hand + Vector2(0, -26).rotated(ang), Vector2(8, 10), ang, light, ink, ow * 0.8)
			DrawKit.ellipse(ci, hand + Vector2(0, -26).rotated(ang), Vector2(4.5, 6.2), ang,
					PaintUtil.with_alpha(shade, 0.5), ink, 0.0)
			DrawKit.line(ci, hand + Vector2(-2, -35).rotated(ang), hand + Vector2(1, -30).rotated(ang),
					PaintUtil.with_alpha(Color.WHITE, 0.6), 1.0)


static func _accessory(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var chest: Vector2 = p["chest"]
	var neck: Vector2 = p["neck"]
	var lean: float = p["torso_lean"]
	var col := PaintUtil.color(ctx, "primary")
	var light := PaintUtil.color(ctx, "light")
	var accent := PaintUtil.accent(ctx)
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var t := float(ctx["time"])
	var back: bool = ctx["back"]

	match variant:
		"bell":
			if back:
				return
			var ring := chest + Vector2(0, 8).rotated(lean)
			DrawKit.line(ci, neck + Vector2(0, 5), ring + Vector2(PaintUtil.sway(ctx, 4.0, 1.2), -4),
					ink, 1.0)
			var jiggle := PaintUtil.sway(ctx, 5.0, 1.5)
			DrawKit.circle(ci, ring + Vector2(jiggle, 0), 4.6, col, ink, ow * 0.6)
			DrawKit.circle(ci, ring + Vector2(jiggle - 1.2, -1.5), 1.2,
					PaintUtil.with_alpha(Color.WHITE, 0.7), ink, 0.0)
			DrawKit.circle(ci, ring + Vector2(jiggle, 4.6), 1.1, PaintUtil.color(ctx, "shade"), ink, 0.25)
		"pendant":
			if back:
				DrawKit.circle(ci, neck + Vector2(0, 3), 2.4, accent, ink, ow * 0.35)
				return
			var low := chest + Vector2(0, 11).rotated(lean)
			DrawKit.polyline(ci, PackedVector2Array([
				neck + Vector2(-9, 3).rotated(lean), low, neck + Vector2(9, 3).rotated(lean),
			]), accent, 1.3)
			DrawKit.star(ci, low + Vector2(0, 2), 6.2, 5, col, ink, ow * 0.5, 0.44, -PI * 0.5)
			DrawKit.circle(ci, low + Vector2(-2.2, 0), 1.0, PaintUtil.with_alpha(Color.WHITE, 0.65), ink, 0.0)
		"badge":
			if back:
				return
			var center := chest + Vector2(10, 7).rotated(lean)
			DrawKit.ellipse(ci, center, Vector2(5.0, 7.0), lean + 0.4, col, ink, ow * 0.5)
			DrawKit.line(ci, center + Vector2(-2, 6).rotated(lean), center + Vector2(0, 9).rotated(lean),
					accent, 1.0)
			DrawKit.line(ci, center + Vector2(-3, 0).rotated(lean), center + Vector2(3, 0).rotated(lean),
					PaintUtil.with_alpha(light, 0.8), 0.8)
		"charm":
			var bob := sin(t * 2.5) * 3.0
			var center := chest + Vector2(-19, -8 + bob)
			DrawKit.ring(ci, center, 6.5, 1.0, PaintUtil.with_alpha(col, 0.8))
			DrawKit.diamond(ci, center, Vector2(6, 9), col, ink, ow * 0.5)
			DrawKit.star(ci, center + Vector2(9, -7), 2.4, 4, accent, ink, 0.3, 0.4, t * 0.8)
			DrawKit.star(ci, center + Vector2(-8, 6), 1.7, 4, PaintUtil.with_alpha(light, 0.8), ink, 0.2, 0.4, -t)
			DrawKit.line(ci, center + Vector2(0, -10), center + Vector2(0, -13),
					PaintUtil.with_alpha(col, 0.5), 0.8)
