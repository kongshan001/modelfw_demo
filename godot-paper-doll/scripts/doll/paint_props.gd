class_name PaintProps
extends RefCounted

# 气场/帽子/武器/挂饰：武器围绕手部旋转，帽饰围绕头心旋转。
# 武器预算：剑刃 38–42 local、法杖高过头顶 30 local、锤头 24 local；
# 金属有独立 ramp + 2px 高光，金色只做扣/饰。


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
	var light := PaintUtil.highlight(ctx)
	var accent := PaintUtil.accent(ctx)
	var ink := PaintUtil.ink(ctx)
	var t := float(ctx["time"])
	var center: Vector2 = (p["hip"] as Vector2) + Vector2(0, -58)
	var head: Vector2 = p["head"]
	var mini := PaintUtil.is_mini(ctx)

	match variant:
		"spark":
			for i in 5 if mini else 7:
				var a := t * 0.55 + TAU * float(i) / 7.0
				var pos := center + Vector2(cos(a) * 46.0, sin(a) * 66.0)
				var twinkle := 0.55 + 0.45 * sin(t * 3.0 + i * 1.7)
				DrawKit.star(ci, pos, 3.2 + twinkle * 2.6, 4,
						PaintUtil.with_alpha(col, 0.82), ink, 0.45, 0.34, a)
		"leaf":
			for i in 6:
				var a := t * 0.7 + TAU * float(i) / 6.0
				var pos := center + Vector2(cos(a) * 42.0, sin(a) * 58.0)
				DrawKit.ellipse(ci, pos, Vector2(5.4, 2.6), a + PI * 0.5,
						PaintUtil.with_alpha(col, 0.8), ink, 0.4)
				DrawKit.line(ci, pos, pos + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 5.0,
						PaintUtil.with_alpha(light, 0.8), 0.6)
		"flame":
			for i in 3:
				var base := center + Vector2(-17 + i * 17, 44 + sin(t * 3.0 + i) * 2.0)
				var h := 24.0 + sin(t * 5.0 + i * 1.4) * 4.0
				DrawKit.polygon(ci, PackedVector2Array([
					base + Vector2(-6, 8), base + Vector2(-2, -h * 0.4),
					base + Vector2(0, -h), base + Vector2(3, -h * 0.35),
					base + Vector2(7, 8),
				]), PaintUtil.with_alpha(col if i % 2 == 0 else accent, 0.52), ink, 0.0)
				DrawKit.circle(ci, base + Vector2(0, 1), 4.6,
						PaintUtil.with_alpha(light, 0.55), ink, 0.0)
		"bubble":
			for i in 8:
				var phase := fposmod(t * 0.22 + float(i) * 0.13, 1.0)
				var pos := center + Vector2(sin(i * 2.1 + t * 0.7) * 26.0, 58.0 - phase * 118.0)
				var r := 2.5 + float(i % 3) * 1.4
				DrawKit.circle(ci, pos, r, PaintUtil.with_alpha(col, 0.12),
						PaintUtil.with_alpha(col, 0.58), 0.6)
				DrawKit.circle(ci, pos + Vector2(-r * 0.3, -r * 0.3), r * 0.22,
						PaintUtil.with_alpha(light, 0.75), ink, 0.0)
		"halo":
			var halo := head + Vector2(0, -36)
			DrawKit.ellipse(ci, halo, Vector2(28, 7.4), 0.0, PaintUtil.with_alpha(col, 0.12),
					PaintUtil.with_alpha(accent, 0.9), 1.2)
			DrawKit.ellipse(ci, halo, Vector2(20, 4.6), 0.0, Color(0, 0, 0, 0),
					PaintUtil.with_alpha(light, 0.6), 0.8)
			for i in 4:
				var a := t * 0.8 + TAU * float(i) / 4.0
				var pos := halo + Vector2(cos(a) * 34.0, sin(a) * 10.0)
				DrawKit.star(ci, pos, 2.3 + sin(t * 3.0 + i) * 0.8, 4,
						PaintUtil.with_alpha(accent, 0.85), ink, 0.3, 0.35)


static func _hat(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.color(ctx, "light")
	var accent := PaintUtil.mat_color(ctx, "gold", "base")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var ha := PaintUtil.head_angle(ctx)
	var outline := PaintUtil.ol(ctx, "outer") * 0.9
	var studio := not PaintUtil.is_mini(ctx) and not bool(ctx.get("silhouette", false))

	match variant:
		"beanie":
			var pts := DrawKit._ellipse_points(PaintUtil.head_point(ctx, Vector2(0, -22)), Vector2(19.5, 13.5), ha, 24)
			if studio:
				DrawKit.layer_shadow(ci, pts, 0.11)
			DrawKit.ellipse_tones(ci, PaintUtil.head_point(ctx, Vector2(0, -22)), Vector2(19.5, 13.5), ha,
					PaintUtil.ramp(ctx), 4, 1.2, ink, outline)
			DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -12.5)), Vector2(39, 7.4), 3.0, ha,
					shade, ink, PaintUtil.ol(ctx, "struct"))
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(0, -36)), 6.2, light, ink, 0.5)
			if studio:
				for i in 3:
					DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(-8 + i * 8, -23)), 3.2, 0.2, 2.6,
							PaintUtil.with_alpha(light, 0.8), PaintUtil.detail_w(ctx))
		"acorn":
			DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, -21)), Vector2(19, 11.5), ha,
					col, ink, outline)
			DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -12.5)), Vector2(39, 7.4), 3.0, ha,
					shade, ink, PaintUtil.ol(ctx, "struct"))
			DrawKit.capsule(ci, PaintUtil.head_point(ctx, Vector2(0, -29)),
					PaintUtil.head_point(ctx, Vector2(2, -37)), 2.6, shade, ink, 0.4)
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(2, -37)), 2.0, accent, ink, 0.3)
			if studio:
				for i in 3:
					var x := -8.0 + i * 8.0
					DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(x, -27)),
							PaintUtil.head_point(ctx, Vector2(x + 4, -19)),
							PaintUtil.with_alpha(light, 0.65), PaintUtil.detail_w(ctx))
		"wizard":
			var brim := DrawKit._ellipse_points(PaintUtil.head_point(ctx, Vector2(0, -12)), Vector2(27, 6.8), ha, 24)
			if studio:
				DrawKit.layer_shadow(ci, brim, 0.12)
			DrawKit.ellipse(ci, PaintUtil.head_point(ctx, Vector2(0, -12)), Vector2(27, 6.8), ha,
					shade, ink, outline)
			var pts := PackedVector2Array()
			for pt in [Vector2(-15, -13), Vector2(-9, -39), Vector2(0, -50), Vector2(12, -13)]:
				pts.append(PaintUtil.head_point(ctx, pt))
			if studio:
				DrawKit.polygon_tones(ci, pts, PaintUtil.ramp(ctx), 3, 2.2, ink, outline)
			else:
				DrawKit.polygon(ci, pts, col, ink, outline)
			DrawKit.rrect(ci, PaintUtil.head_point(ctx, Vector2(0, -16)), Vector2(30, 5.4), 2.0, ha,
					accent, ink, 0.0)
			DrawKit.star(ci, PaintUtil.head_point(ctx, Vector2(-1, -30)), 4.2, 5,
					PaintUtil.with_alpha(light, 0.95), ink, 0.35, 0.45)
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(2, -50)), 2.2, accent, ink, 0.3)
			if studio:
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-5, -17)),
						PaintUtil.head_point(ctx, Vector2(-2, -44)),
						PaintUtil.with_alpha(light, 0.6), PaintUtil.detail_w(ctx))
		"crown":
			var band := PaintUtil.head_point(ctx, Vector2(0, -21))
			DrawKit.rrect(ci, band, Vector2(28, 6.4), 2.0, ha, accent, ink, 0.55)
			var spikes := PackedVector2Array([
				PaintUtil.head_point(ctx, Vector2(-14, -22)),
				PaintUtil.head_point(ctx, Vector2(-10, -34)),
				PaintUtil.head_point(ctx, Vector2(-4, -24)),
				PaintUtil.head_point(ctx, Vector2(0, -42)),
				PaintUtil.head_point(ctx, Vector2(4, -24)),
				PaintUtil.head_point(ctx, Vector2(10, -34)),
				PaintUtil.head_point(ctx, Vector2(14, -22)),
			])
			DrawKit.polygon(ci, spikes, accent, ink, 0.6)
			for i in 3:
				DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(-8 + i * 8, -25)), 1.6,
						PaintUtil.mat_color(ctx, "metal", "hi"), ink, 0.25)
		"leaf":
			# 折叶帽：宽 48 local 的叶冠 + 上翘叶尖（剪影破形件），不是头顶“鱼鳍”。
			var leaf_pts := PackedVector2Array([
				PaintUtil.head_point(ctx, Vector2(-21, -11)),
				PaintUtil.head_point(ctx, Vector2(-24, -20)),
				PaintUtil.head_point(ctx, Vector2(-10, -27)),
				PaintUtil.head_point(ctx, Vector2(3, -42)),
				PaintUtil.head_point(ctx, Vector2(12, -30)),
				PaintUtil.head_point(ctx, Vector2(23, -21)),
				PaintUtil.head_point(ctx, Vector2(19, -9)),
				PaintUtil.head_point(ctx, Vector2(4, -17)),
				PaintUtil.head_point(ctx, Vector2(-9, -16)),
			])
			if studio:
				DrawKit.layer_shadow(ci, leaf_pts, 0.12)
				DrawKit.polygon_tones(ci, leaf_pts, PaintUtil.ramp(ctx), 3, 2.4, ink, outline)
			else:
				DrawKit.polygon(ci, leaf_pts, col, ink, outline)
			DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-9, -15)),
					PaintUtil.head_point(ctx, Vector2(3, -41)),
					PaintUtil.with_alpha(deep, 0.75), 1.1)
			for i in 3:
				var y := -30.0 + i * 5.0
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-2, -17)),
						PaintUtil.head_point(ctx, Vector2(15, y)),
						PaintUtil.with_alpha(deep, 0.45), PaintUtil.detail_w(ctx))
			DrawKit.circle(ci, PaintUtil.head_point(ctx, Vector2(3, -42)), 2.2, accent, ink, 0.3)
			if studio:
				DrawKit.line(ci, PaintUtil.head_point(ctx, Vector2(-8, -17)),
						PaintUtil.head_point(ctx, Vector2(4, -38)),
						PaintUtil.with_alpha(light, 0.75), 1.0)
	# 主光左上 / 轮廓光右侧：帽顶右缘 2px α0.5 6500K 轮廓光（mini 删除）。
	if not PaintUtil.is_mini(ctx):
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(0, -13)), 20.0, -1.15, -0.05,
				PaintUtil.with_alpha(PaintUtil.rim_warm(ctx), 0.50), 0.95)
		DrawKit.arc(ci, PaintUtil.head_point(ctx, Vector2(0, -13)), 20.6, 2.05, 2.75,
				PaintUtil.with_alpha(PaintUtil.rim_cool(ctx), 0.30), 0.8)


static func _weapon(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	# 背向且披风不覆盖背部时，武器改为“横跨背部的刀鞘/杖”，保证背向可读。
	# 有短/长披风时由 PaintCloth._back_weapon 负责（披风压住背部）。
	var outfit: Dictionary = ctx.get("outfit", {})
	var cape_variant := str(outfit.get("cape", {}).get("variant", "none"))
	if bool(ctx["back"]) and (cape_variant == "none" or cape_variant == "scarf"):
		PaintCloth._back_weapon(ci, ctx)
		return
	var p := PaintUtil.pose(ctx)
	var hand: Vector2 = p["hand_r"]
	var ang: float = p["weapon_angle"]
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.highlight(ctx)
	var accent := PaintUtil.mat_color(ctx, "gold", "base")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var metal := PaintUtil.mat_color(ctx, "metal", "base")
	var metal_hi := PaintUtil.mat_color(ctx, "metal", "hi")
	var metal_deep := PaintUtil.mat_color(ctx, "metal", "deep")
	var wood := PaintUtil.mat_color(ctx, "wood", "base")
	var wood_deep := PaintUtil.mat_color(ctx, "wood", "deep")
	var outline := PaintUtil.ol(ctx, "outer") * 0.90
	var studio := not PaintUtil.is_mini(ctx) and not bool(ctx.get("silhouette", false))

	match variant:
		"sword":
			# 52 local 刃身 + 三角剑尖 + 深边；向外倾 0.30 rad，保证 1× 下轮廓外可见 ≥24px。
			var sword_ang := ang + (0.30 if not bool(ctx["back"]) else 0.0)
			var blade_base := hand + Vector2(0, -7).rotated(sword_ang)
			var tip := hand + Vector2(0, -52).rotated(sword_ang)
			var dir := (tip - blade_base).normalized()
			var side := Vector2(-dir.y, dir.x) * 4.4
			var pts := PackedVector2Array([
				blade_base - side, blade_base - side + dir * 38.0,
				tip, blade_base + side + dir * 38.0, blade_base + side,
			])
			DrawKit.polygon(ci, pts, metal, ink, outline)
			# 金属 4 阶 specular：deep 背光边 / hi 2px 高光 / reflect 环境反射带。
			DrawKit.line(ci, blade_base + dir * 3.0, blade_base + dir * 35.0,
					PaintUtil.with_alpha(metal_hi, 0.95), 1.35)
			DrawKit.line(ci, blade_base + dir * 5.0 + side * 0.7, blade_base + dir * 33.0 + side * 0.7,
					PaintUtil.with_alpha(PaintUtil.reflect(ctx), 0.62), 0.6)
			DrawKit.line(ci, blade_base + dir * 2.0 - side * 0.65,
					blade_base + dir * 37.0 - side * 0.65,
					PaintUtil.with_alpha(metal_deep, 0.80), 0.8)
			# 护手 + 木柄（2 条年轮签名）+ 金尾（2px 高光）。
			DrawKit.rrect(ci, hand + Vector2(0, -6).rotated(sword_ang), Vector2(20, 3.6), 1.2, sword_ang,
					accent, ink, 0.4)
			DrawKit.line(ci, hand + Vector2(-8.5, -6.8).rotated(sword_ang), hand + Vector2(8.5, -6.8).rotated(sword_ang),
					PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "hi"), 0.9), 0.95)
			DrawKit.capsule(ci, hand + Vector2(0, -2).rotated(sword_ang),
					hand + Vector2(0, 9).rotated(sword_ang), 5.2, wood, ink, 0.4)
			DrawKit.circle(ci, hand + Vector2(0, 10).rotated(sword_ang), 3.2, accent, ink, 0.4)
			if studio:
				var grain := PaintUtil.with_alpha(Color("#9a653f"), 0.60)
				DrawKit.arc(ci, hand + Vector2(0, 3.5).rotated(sword_ang), 2.3, -1.1, 1.1, grain, 0.50)
				DrawKit.arc(ci, hand + Vector2(0, 6.6).rotated(sword_ang), 1.8, -1.0, 1.2, grain, 0.50)
				DrawKit.line(ci, hand + Vector2(0.8, 0).rotated(sword_ang), hand + Vector2(0.8, 7).rotated(sword_ang),
						PaintUtil.with_alpha(wood_deep, 0.75), PaintUtil.detail_w(ctx))
		"hammer":
			DrawKit.capsule(ci, hand + Vector2(0, 14).rotated(ang),
					hand + Vector2(0, -26).rotated(ang), 5.2, wood, ink, 0.45)
			var head := hand + Vector2(0, -30).rotated(ang)
			DrawKit.rrect(ci, head, Vector2(27, 16), 3.2, ang, metal, ink, outline)
			DrawKit.line(ci, head + Vector2(-9, -4).rotated(ang), head + Vector2(9, -4).rotated(ang),
					PaintUtil.with_alpha(metal_hi, 0.95), 1.4)
			DrawKit.line(ci, head + Vector2(-8, 1.2).rotated(ang), head + Vector2(8, 1.2).rotated(ang),
					PaintUtil.with_alpha(PaintUtil.reflect(ctx), 0.60), 0.6)
			DrawKit.line(ci, head + Vector2(-9, 4).rotated(ang), head + Vector2(9, 4).rotated(ang),
					PaintUtil.with_alpha(metal_deep, 0.7), 0.8)
			for i in 2:
				DrawKit.circle(ci, head + Vector2(-6 + i * 12, 0).rotated(ang), 1.5, accent, ink, 0.25)
				DrawKit.circle(ci, head + Vector2(-6.4 + i * 12, -0.4).rotated(ang), 0.55,
						PaintUtil.mat_color(ctx, "gold", "hi"), Color.WHITE, 0.0)
			if studio:
				var grain := PaintUtil.with_alpha(Color("#9a653f"), 0.60)
				DrawKit.arc(ci, hand + Vector2(0.6, 2).rotated(ang), 2.0, -1.1, 1.2, grain, 0.40)
				DrawKit.arc(ci, hand + Vector2(0.6, 5.4).rotated(ang), 1.5, -1.0, 1.2, grain, 0.40)
				DrawKit.line(ci, hand + Vector2(1, 11).rotated(ang), hand + Vector2(1, -22).rotated(ang),
						PaintUtil.with_alpha(wood_deep, 0.7), PaintUtil.detail_w(ctx))
		"staff":
			DrawKit.capsule(ci, hand + Vector2(0, 17).rotated(ang),
					hand + Vector2(0, -48).rotated(ang), 4.8, wood, ink, 0.5)
			DrawKit.line(ci, hand + Vector2(1.4, 12).rotated(ang), hand + Vector2(1.4, -43).rotated(ang),
					PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "wood", "light"), 0.7), 0.7)
			var crook := PackedVector2Array()
			for pt in [Vector2(0, -48), Vector2(7, -53), Vector2(6, -61), Vector2(-1, -61), Vector2(-6, -54)]:
				crook.append(hand + pt.rotated(ang))
			DrawKit.polyline(ci, crook, ink, 4.6)
			DrawKit.polyline(ci, crook, wood, 2.6)
			var tip := hand + Vector2(-1, -61).rotated(ang)
			DrawKit.circle(ci, tip, 10.0, PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "light"), 0.16), ink, 0.0)
			DrawKit.star(ci, tip, 5.6, 4, accent, ink, 0.45, 0.4)
			DrawKit.circle(ci, hand + Vector2(0, 2).rotated(ang), 2.2, accent, ink, 0.3)
			# 白蜡杆 2 条年轮（0.8px 60%）+ 金饰 2px 高光 + 第二颗铆钉。
			if studio:
				var grain := PaintUtil.with_alpha(Color("#9a653f"), 0.60)
				DrawKit.arc(ci, hand + Vector2(0.8, 8).rotated(ang), 2.4, -1.1, 1.2, grain, 0.50)
				DrawKit.arc(ci, hand + Vector2(0.8, 12.6).rotated(ang), 1.9, -1.0, 1.2, grain, 0.50)
				DrawKit.line(ci, tip + Vector2(-3.4, -1.2), tip + Vector2(3.4, -1.2),
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "hi"), 0.90), 0.95)
				DrawKit.circle(ci, hand + Vector2(0, -3).rotated(ang), 1.2,
						PaintUtil.mat_color(ctx, "gold", "hi"), ink, 0.2)
		"fan":
			var pivot := hand + Vector2(0, -5).rotated(ang)
			var pts := PackedVector2Array([pivot])
			for i in 9:
				var a := PI + 0.3 + (PI - 0.6) * float(i) / 8.0
				pts.append(pivot + Vector2(cos(a), sin(a)).rotated(ang) * 30.0)
			DrawKit.layer_shadow(ci, pts, 0.10)
			DrawKit.polygon(ci, pts, light, ink, outline)
			for i in 5:
				var a := PI + 0.45 + (PI - 0.9) * float(i) / 4.0
				DrawKit.line(ci, pivot, pivot + Vector2(cos(a), sin(a)).rotated(ang) * 28.0,
						PaintUtil.with_alpha(shade, 0.8), 0.7)
			DrawKit.polyline(ci, pts, accent, 1.2)
			DrawKit.capsule(ci, hand + Vector2(0, 10).rotated(ang), pivot, 4.2, wood, ink, 0.4)
			DrawKit.circle(ci, pivot, 2.4, accent, ink, 0.35)
		"spoon":
			DrawKit.capsule(ci, hand + Vector2(0, 12).rotated(ang),
					hand + Vector2(0, -21).rotated(ang), 4.4, wood, ink, 0.45)
			DrawKit.ellipse(ci, hand + Vector2(0, -30).rotated(ang), Vector2(9.0, 11.0), ang,
					PaintUtil.mat_color(ctx, "wood", "light"), ink, 0.55)
			DrawKit.ellipse(ci, hand + Vector2(0, -30).rotated(ang), Vector2(5.0, 6.4), ang,
					PaintUtil.with_alpha(shade, 0.55), ink, 0.0)
			DrawKit.line(ci, hand + Vector2(-2, -39).rotated(ang),
					hand + Vector2(1, -34).rotated(ang), PaintUtil.with_alpha(Color.WHITE, 0.75), 0.9)
			if studio:
				DrawKit.line(ci, hand + Vector2(1.2, 9).rotated(ang), hand + Vector2(1.2, -17).rotated(ang),
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "wood", "deep"), 0.6), PaintUtil.detail_w(ctx))


static func _accessory(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var chest: Vector2 = p["chest"]
	var neck: Vector2 = p["neck"]
	var lean: float = p["torso_lean"]
	var col := PaintUtil.color(ctx, "primary")
	var light := PaintUtil.highlight(ctx)
	var accent := PaintUtil.mat_color(ctx, "gold", "base")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var t := float(ctx["time"])
	var back: bool = bool(ctx["back"])

	match variant:
		"bell":
			if back:
				return
			var ring := chest + Vector2(0, 8).rotated(lean)
			DrawKit.line(ci, neck + Vector2(0, 5), ring + Vector2(PaintUtil.sway(ctx, 4.0, 1.2), -4),
					ink, 0.9)
			var jiggle := PaintUtil.sway(ctx, 5.0, 1.5)
			DrawKit.circle(ci, ring + Vector2(jiggle, 0), 4.8, col, ink, ow * 0.45)
			DrawKit.circle(ci, ring + Vector2(jiggle - 1.2, -1.5), 1.3,
					PaintUtil.with_alpha(Color.WHITE, 0.8), ink, 0.0)
			DrawKit.circle(ci, ring + Vector2(jiggle, 4.8), 1.2, PaintUtil.color(ctx, "shade"), ink, 0.2)
		"pendant":
			if back:
				DrawKit.circle(ci, neck + Vector2(0, 3), 2.4, accent, ink, 0.35)
				return
			var low := chest + Vector2(0, 11).rotated(lean)
			DrawKit.polyline(ci, PackedVector2Array([
				neck + Vector2(-9, 3).rotated(lean), low, neck + Vector2(9, 3).rotated(lean),
			]), accent, 1.1)
			DrawKit.star(ci, low + Vector2(0, 2), 6.4, 5, col, ink, 0.45, 0.44, -PI * 0.5)
			DrawKit.circle(ci, low + Vector2(-2.2, 0), 1.0,
					PaintUtil.with_alpha(Color.WHITE, 0.8), ink, 0.0)
		"badge":
			if back:
				return
			var center := chest + Vector2(10, 7).rotated(lean)
			DrawKit.ellipse(ci, center, Vector2(5.2, 7.2), lean + 0.4, col, ink, 0.45)
			DrawKit.line(ci, center + Vector2(-2, 6).rotated(lean), center + Vector2(0, 9).rotated(lean),
					accent, 0.9)
			DrawKit.line(ci, center + Vector2(-3, 0).rotated(lean), center + Vector2(3, 0).rotated(lean),
					PaintUtil.with_alpha(light, 0.85), 0.7)
		"charm":
			var bob := sin(t * 2.5) * 3.0
			var center := chest + Vector2(-19, -8 + bob)
			DrawKit.ring(ci, center, 6.6, 0.9, PaintUtil.with_alpha(col, 0.8))
			DrawKit.diamond(ci, center, Vector2(6.2, 9.2), col, ink, 0.45)
			DrawKit.star(ci, center + Vector2(9, -7), 2.4, 4, accent, ink, 0.25, 0.4, t * 0.8)
			DrawKit.star(ci, center + Vector2(-8, 6), 1.8, 4,
					PaintUtil.with_alpha(light, 0.85), ink, 0.2, 0.4, -t)
			DrawKit.line(ci, center + Vector2(0, -10), center + Vector2(0, -13),
					PaintUtil.with_alpha(col, 0.55), 0.7)
