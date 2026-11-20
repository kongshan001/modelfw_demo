class_name PaintCloth
extends RefCounted

# 披风/背饰/下装/上衣/鞋/腰带/手套：全部锚定到同一骨架的关节与骨链。
# 布 = 折线 + 下摆 shade；皮 = 针脚 + 孔；金 = 铆钉 + 2px 高光；纸 = 切边 + 层影。


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


static func _slot_color(ctx: Dictionary, slot: String, fallback: Color) -> Color:
	var outfit: Dictionary = ctx.get("outfit", {})
	var entry: Dictionary = outfit.get(slot, {})
	return entry.get("color", fallback)


static func _slot_variant(ctx: Dictionary, slot: String) -> String:
	var outfit: Dictionary = ctx.get("outfit", {})
	var entry: Dictionary = outfit.get(slot, {})
	return str(entry.get("variant", "none"))


static func _studio(ctx: Dictionary) -> bool:
	return not PaintUtil.is_mini(ctx) and not bool(ctx.get("silhouette", false))


# ------------------------------------------------------------------ 披风

static func _cape(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var t := float(ctx["time"])
	var lag := float(p.get("secondary", 0.0))
	var sway := sin(t * 3.1) * 1.6 + lag * 1.4
	var studio := _studio(ctx)

	if variant == "scarf":
		var neck: Vector2 = p["neck"] + Vector2(0, 3)
		var lean: float = p["torso_lean"]
		var a := neck + Vector2(-11, 0).rotated(lean)
		var b := neck + Vector2(11, 0).rotated(lean)
		var tail_end := neck + Vector2(-12 - sway, 24).rotated(lean * 0.5)
		DrawKit.capsule(ci, neck, tail_end, 9.0, shade, ink, 0.0)
		DrawKit.capsule(ci, a, b, 8.6, col, ink, ow * 0.8)
		DrawKit.line(ci, a + Vector2(0, 2.6), b + Vector2(0, 2.6),
				PaintUtil.with_alpha(deep, 0.55), PaintUtil.ol(ctx, "struct"))
		if studio:
			for i in 3:
				DrawKit.line(ci, tail_end + Vector2(-3 + i * 3, 1), tail_end + Vector2(-4 - sway * 0.4 + i * 3, 8),
						PaintUtil.with_alpha(light, 0.75), PaintUtil.detail_w(ctx))
		return

	var is_back := bool(ctx["back"])
	var turn := 5.0 * float(ctx["yaw"])
	var drop := (40.0 if variant == "short" else 56.0) if is_back else (15.0 if variant == "short" else 40.0)
	var top_l: Vector2 = p["shoulder_l"] + Vector2(-3, 2)
	var top_r: Vector2 = p["shoulder_r"] + Vector2(3, 2)
	var hip: Vector2 = p["hip"]
	# 背向披风比正面宽 3 local、下摆再垂 4 local + 兜帽，让正/背剪影分开。
	var hem := 40.0 if is_back else 17.0
	var drop_b := drop
	# 侧向/斜向：下摆整体向后拖 5.5×yaw local，让“侧面”与“正面”剪影分开。
	var trail := -10.5 * float(ctx["yaw"])
	var bottom_r := hip + Vector2(hem + sway * 0.4 + trail, drop_b)
	var bottom_l := hip + Vector2(-hem - sway + trail, drop_b)
	if is_back:
		# 兜帽（z 在头发之上，帽槽 z65 再盖上来）：背向独有的头部轮廓。
		var neck: Vector2 = p["neck"]
		var hood := PackedVector2Array([
			top_l + Vector2(-2 + turn, 0),
			neck + Vector2(-25 + turn, -4),
			neck + Vector2(-21 + turn, -19),
			neck + Vector2(-9 + turn, -27),
			neck + Vector2(0 + turn, -29),
			neck + Vector2(9 + turn, -26),
			neck + Vector2(21 + turn, -18),
			neck + Vector2(24 + turn, -3),
			top_r + Vector2(2 + turn, 0),
		])
		if studio:
			DrawKit.layer_shadow(ci, hood, 0.12)
		DrawKit.polygon(ci, hood, shade.darkened(0.06), ink, ow * 0.85)
		DrawKit.ellipse(ci, neck + Vector2(0, -10), Vector2(13.5, 9.5), 0.0,
				PaintUtil.with_alpha(deep, 0.50), Color.WHITE, 0.0)
		# 后发 3 缕从兜帽下露出，避免背面只有一块布。
		var hair_col := _slot_color(ctx, "hair", col.darkened(0.35))
		for i in 3:
			var hx := -6.0 + float(i) * 6.0
			DrawKit.line(ci, neck + Vector2(hx, -2.0),
					neck + Vector2(hx - 1.0, 4.0 + absf(hx) * 0.25),
					PaintUtil.with_alpha(hair_col, 0.95), PaintUtil.ol(ctx, "struct"))
	# V 形下摆：中心下垂，两侧起翘，读得出“纸片裁切”。
	var pts := PackedVector2Array([
		top_l, top_r, bottom_r,
		hip + Vector2(15 + trail * 0.8, drop_b + 3 + sway * 0.3),
		hip + Vector2(4 + trail * 0.75, drop_b + 9),
		hip + Vector2(-7 + trail * 0.7, drop_b + 4),
		hip + Vector2(-18 + trail * 0.8, drop_b + 8 - sway * 0.3),
		bottom_l,
	])
	if studio:
		DrawKit.layer_shadow(ci, pts, 0.13)
	DrawKit.polygon(ci, pts, col, ink, ow * 0.9)

	# 受光面 / 背光面 / 2 条折线。
	if studio:
		DrawKit.polygon(ci, PackedVector2Array([
			top_l.lerp(top_r, 0.20), top_r.lerp(top_l, 0.18),
			hip + Vector2(15 + trail * 0.8, drop - 4), hip + Vector2(2 + trail * 0.75, drop + 4),
			hip + Vector2(-12 + trail * 0.7, drop - 2),
		]), PaintUtil.with_alpha(light, 0.42), Color.WHITE, 0.0)
		DrawKit.line(ci, top_l + Vector2(3, 6), bottom_l + Vector2(5, -4),
				PaintUtil.with_alpha(deep, 0.5), PaintUtil.detail_w(ctx) * 1.2)
		DrawKit.line(ci, top_l.lerp(top_r, 0.58) + Vector2(0, 6), hip + Vector2(9, drop + 2),
				PaintUtil.with_alpha(deep, 0.45), PaintUtil.detail_w(ctx))
		DrawKit.line(ci, top_r + Vector2(2, 4), bottom_r + Vector2(0, -3),
				PaintUtil.with_alpha(PaintUtil.rim_warm(ctx), 0.8), 0.9)
		DrawKit.line(ci, top_l + Vector2(-1, 4), bottom_l + Vector2(-1, -2),
				PaintUtil.with_alpha(PaintUtil.rim_cool(ctx), 0.35), 0.6)
		DrawKit.paper_fibers(ci, hip + Vector2(0, drop * 0.45), Vector2(36, 30), variant.hash(), PaintUtil.with_alpha(deep, 0.05))
	DrawKit.circle(ci, (p["neck"] as Vector2) + Vector2(0, 3), 3.0,
			PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.4)

	if is_back:
		# 背向：加宽肩部披肩（比正面宽 ~9 local），双臂外张、刀鞘横跨背部。
		var mantle := PackedVector2Array([
			top_l + Vector2(-6 + turn, -1),
			p["neck"] + Vector2(-26 + turn, 0),
			p["neck"] + Vector2(-16 + turn, -6),
			p["neck"] + Vector2(0 + turn, -3),
			p["neck"] + Vector2(16 + turn, -6),
			p["neck"] + Vector2(26 + turn, 0),
			top_r + Vector2(6 + turn, -1),
			(p["chest"] as Vector2) + Vector2(18, 10),
			(p["chest"] as Vector2) + Vector2(0, 13),
			(p["chest"] as Vector2) + Vector2(-18, 10),
		])
		if studio:
			DrawKit.layer_shadow(ci, mantle, 0.10)
		DrawKit.polygon(ci, mantle, col.lightened(0.06), ink, ow * 0.75)
		if studio:
			DrawKit.line(ci, p["neck"] + Vector2(-16, -1), p["chest"] + Vector2(-10, 10),
					PaintUtil.with_alpha(shade, 0.7), PaintUtil.detail_w(ctx) * 1.6)
			DrawKit.line(ci, p["neck"] + Vector2(16, -1), p["chest"] + Vector2(10, 10),
					PaintUtil.with_alpha(shade, 0.6), PaintUtil.detail_w(ctx) * 1.6)
			DrawKit.line(ci, p["neck"] + Vector2(20, -4), p["chest"] + Vector2(15, 8),
					PaintUtil.with_alpha(PaintUtil.rim_warm(ctx), 0.75), 0.8)
		_back_arms(ci, ctx)
		_back_weapon(ci, ctx)
	else:
		DrawKit.line(ci, top_l + Vector2(2, 5), bottom_l + Vector2(4, -3),
				PaintUtil.with_alpha(shade, 0.7), PaintUtil.detail_w(ctx))


static func _back_arms(ci: CanvasItem, ctx: Dictionary) -> void:
	# 背向时披风压在身体上，手臂必须作为“背向覆盖层”重画，避免手套悬空。
	var p := PaintUtil.pose(ctx)
	var shirt_col := _slot_color(ctx, "shirt", PaintUtil.color(ctx, "primary"))
	var skirt_shade := shirt_col.darkened(0.22)
	var glove_variant := _slot_variant(ctx, "gloves")
	var glove_col := _slot_color(ctx, "gloves", PaintUtil.color(ctx, "primary"))
	var skin := _slot_color(ctx, "body", PaintUtil.color(ctx, "primary"))
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	for side in ["l", "r"]:
		var outward := 4.5 if side == "r" else -4.5
		var shoulder: Vector2 = (p["shoulder_" + side] as Vector2) + Vector2(outward * 0.35, 0)
		var elbow: Vector2 = (p["elbow_" + side] as Vector2) + Vector2(outward, 0)
		var hand: Vector2 = (p["hand_" + side] as Vector2) + Vector2(outward * 0.65, 0)
		# 背向袖子压在披风上：用更深的布色 + L0.55 结构线，读得出“手臂在披风上”。
		var col := shirt_col.darkened(0.22) if side == "r" else shirt_col.darkened(0.34)
		DrawKit.capsule(ci, shoulder, elbow, 10.0, col, ink, ow * 0.55)
		var cuff := elbow.lerp(hand, 0.16)
		DrawKit.capsule(ci, cuff, hand, 7.4, col.darkened(0.08), ink, ow * 0.45)
		DrawKit.line(ci, shoulder.lerp(elbow, 0.12) + Vector2(0, -3.6),
				elbow.lerp(shoulder, 0.12) + Vector2(0, -3.6),
				PaintUtil.with_alpha(PaintUtil.color(ctx, "light"), 0.45), PaintUtil.detail_w(ctx))
		DrawKit.line(ci, shoulder.lerp(elbow, 0.68), shoulder.lerp(elbow, 0.86),
				PaintUtil.with_alpha(skirt_shade, 0.8), PaintUtil.detail_w(ctx) * 2.0)
		var hand_col := glove_col if glove_variant != "none" else skin
		DrawKit.circle(ci, hand, 4.6, hand_col, ink, ow * 0.5)
		DrawKit.circle(ci, hand + (elbow - hand).normalized().rotated(0.7) * 3.2, 1.8,
				hand_col.lightened(0.12), ink, 0.0)


static func _back_weapon(ci: CanvasItem, ctx: Dictionary) -> void:
	var variant := _slot_variant(ctx, "weapon")
	if variant == "none":
		return
	var p := PaintUtil.pose(ctx)
	var hip: Vector2 = p["hip"]
	var chest: Vector2 = p["chest"]
	var leather := PaintUtil.mat_color(ctx, "leather", "shade")
	var deep := PaintUtil.mat_color(ctx, "leather", "deep")
	var metal := PaintUtil.mat_color(ctx, "metal", "base")
	var metal_hi := PaintUtil.mat_color(ctx, "metal", "hi")
	var ink := PaintUtil.ink(ctx)
	var a := hip + Vector2(-17, 10)
	var b := chest + Vector2(15, -12)
	match variant:
		"sword":
			DrawKit.capsule(ci, a, b, 5.4, leather, ink, 0.5)
			DrawKit.capsule(ci, a, a.lerp(b, 0.18), 5.8, deep, ink, 0.0)
			DrawKit.line(ci, a, a.lerp(b, 0.9), PaintUtil.with_alpha(metal_hi, 0.65), 0.7)
			DrawKit.circle(ci, a, 2.0, metal, ink, 0.4)
			# 剑柄/护手从右肩伸出，保证背向也能读出武器。
			var guard := b + Vector2(1, -1)
			DrawKit.rrect(ci, guard, Vector2(17, 3.0), 1.2, -0.7,
					PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.4)
			DrawKit.capsule(ci, guard + Vector2(9, -6), guard + Vector2(14, -9), 3.6,
					PaintUtil.mat_color(ctx, "wood", "shade"), ink, 0.4)
			DrawKit.line(ci, hip + Vector2(-18, -2), chest + Vector2(8, -4),
					PaintUtil.with_alpha(deep, 0.55), 1.2)
		"staff":
			DrawKit.capsule(ci, a + Vector2(-2, 6), b + Vector2(2, -10), 4.2,
					PaintUtil.mat_color(ctx, "wood", "shade"), ink, 0.5)
			DrawKit.star(ci, b + Vector2(3, -10), 4.6, 4,
					PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.4, 0.4)
		"hammer":
			DrawKit.capsule(ci, a, b, 4.4, PaintUtil.mat_color(ctx, "wood", "shade"), ink, 0.4)
			var head := b + Vector2(2, -2)
			DrawKit.rrect(ci, head, Vector2(17, 10), 2.6, -0.7,
					PaintUtil.mat_color(ctx, "metal", "base"), ink, 0.5)
			DrawKit.line(ci, head + Vector2(-6, -4), head + Vector2(6, -4),
					PaintUtil.with_alpha(metal_hi, 0.9), 1.2)
		"fan":
			DrawKit.ellipse(ci, b + Vector2(-2, -3), Vector2(10, 12), -0.7,
					PaintUtil.with_alpha(_slot_color(ctx, "weapon", PaintUtil.color(ctx, "primary")), 0.9), ink, 0.4)
			DrawKit.capsule(ci, a, b + Vector2(0, 4), 3.2,
					PaintUtil.mat_color(ctx, "wood", "shade"), ink, 0.4)
		"spoon":
			DrawKit.capsule(ci, a, b, 3.6, PaintUtil.mat_color(ctx, "wood", "shade"), ink, 0.4)
			DrawKit.ellipse(ci, b + Vector2(1, -6), Vector2(5.2, 6.6), -0.7,
					PaintUtil.mat_color(ctx, "wood", "light"), ink, 0.4)


# ------------------------------------------------------------------ 背饰

static func _backpack(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var chest: Vector2 = p["chest"]
	var hip: Vector2 = p["hip"]
	var t := float(ctx["time"])
	var studio := _studio(ctx)

	match variant:
		"satchel":
			var center := chest + Vector2(-10, 9)
			DrawKit.layer_shadow(ci, DrawKit._ellipse_points(center + Vector2(1, 2), Vector2(12, 13), 0.0, 18), 0.10)
			DrawKit.rrect(ci, center, Vector2(23, 25), 4.5, 0.0, col, ink, ow * 0.8)
			DrawKit.rrect(ci, center + Vector2(0, -6), Vector2(24, 11), 4.0, 0.0, shade, ink, 0.0)
			DrawKit.circle(ci, center + Vector2(0, -1), 2.2,
					PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.4)
			DrawKit.line(ci, hip + Vector2(-18, -12), hip + Vector2(-10, 14),
					PaintUtil.with_alpha(deep, 0.7), 1.1)
			if studio:
				for i in 3:
					DrawKit.line(ci, center + Vector2(-8 + i * 4, -10),
							center + Vector2(-7 + i * 4, 10), PaintUtil.with_alpha(deep, 0.35), PaintUtil.detail_w(ctx))
		"shell":
			var center := chest + Vector2(-8, 7)
			DrawKit.layer_shadow(ci, DrawKit._ellipse_points(center + Vector2(2, 3), Vector2(30, 32), 0.0, 22), 0.12)
			DrawKit.ellipse(ci, center, Vector2(30, 32), 0.0, col, ink, ow * 0.9)
			for i in 3:
				DrawKit.arc(ci, center + Vector2(0, 4 + i * 5), 20.0 - i * 5.0, PI + 0.2, TAU - 0.2,
						PaintUtil.with_alpha(deep, 0.7), PaintUtil.ol(ctx, "struct"))
			DrawKit.arc(ci, center, 27.0, -2.6, -0.5, PaintUtil.with_alpha(light, 0.9), 1.2)
		"wings":
			var flap := sin(t * 7.0) * 4.0
			for side in [-1.0, 1.0]:
				var root := chest + Vector2(0, -3)
				var tip := root + Vector2(42 * side, -21 + flap)
				var mid1 := root + Vector2(18 * side, 2 + flap * 0.5)
				var mid2 := root + Vector2(30 * side, 15 + flap)
				var wing_col: Color = PaintUtil.far_color(ctx) if side < 0 else col
				var pts := PackedVector2Array([root, tip, tip + Vector2(-4 * side, 10), mid2, mid1])
				DrawKit.layer_shadow(ci, pts, 0.08)
				DrawKit.polygon(ci, pts, wing_col, ink, ow * 0.6)
				DrawKit.line(ci, root, tip, PaintUtil.with_alpha(light, 0.85), 1.0)
				DrawKit.line(ci, root, mid2, PaintUtil.with_alpha(deep, 0.55), 0.8)
			for i in 2:
				DrawKit.circle(ci, chest + Vector2(-3 + i * 6, 1), 1.2,
						PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)
		"lantern":
			var top := chest + Vector2(-16, -4)
			var center := chest + Vector2(-16, 18)
			DrawKit.line(ci, top, center + Vector2(0, -9), ink, 1.0)
			DrawKit.circle(ci, center, 11.5, PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "light"), 0.22), ink, 0.0)
			DrawKit.rrect(ci, center, Vector2(11, 15), 3.0, 0.0, col, ink, ow * 0.55)
			DrawKit.line(ci, center + Vector2(-4.5, -7.5), center + Vector2(4.5, -7.5), shade, 1.6)
			DrawKit.line(ci, center + Vector2(-4.5, 7.5), center + Vector2(4.5, 7.5), shade, 1.6)
			DrawKit.star(ci, center, 3.0, 4, PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3, 0.4)


# ------------------------------------------------------------------ 下装

static func _pants(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col
	var studio := _studio(ctx)

	if variant == "skirt":
		var hip: Vector2 = p["hip"]
		var lean: float = p["torso_lean"]
		var sway := sin(float(ctx["time"]) * 3.0) * 1.2 + float(p.get("secondary", 0.0)) * 0.5
		var pts := PackedVector2Array([
			hip + Vector2(-13, -3).rotated(lean),
			hip + Vector2(13, -3).rotated(lean),
			hip + Vector2(24 + sway, 23),
			hip + Vector2(13, 28),
			hip + Vector2(1, 25 + sway),
			hip + Vector2(-14, 28),
			hip + Vector2(-24 - sway, 22),
		])
		if studio:
			DrawKit.layer_shadow(ci, pts, 0.12)
		DrawKit.polygon(ci, pts, col, ink, ow * 0.9)
		DrawKit.line(ci, hip + Vector2(-21, 20), hip + Vector2(21, 20),
				PaintUtil.with_alpha(light, 0.8), 1.0)
		if studio:
			for i in 3:
				DrawKit.line(ci, hip + Vector2(-10 + i * 8, 5), hip + Vector2(-15 + i * 9, 26),
						PaintUtil.with_alpha(shade, 0.7), PaintUtil.detail_w(ctx))
		return

	_pants_leg(ci, p["hip_l"], p["knee_l"], p["foot_l"], far, variant, ctx, true)
	_pants_leg(ci, p["hip_r"], p["knee_r"], p["foot_r"], col, variant, ctx, false)
	var hip: Vector2 = p["hip"]
	var lean: float = p["torso_lean"]
	DrawKit.capsule(ci, hip + Vector2(-11, -6).rotated(lean), hip + Vector2(11, -6).rotated(lean),
			10.0, col, ink, 0.0)
	DrawKit.line(ci, hip + Vector2(-11, -2).rotated(lean), hip + Vector2(11, -2).rotated(lean),
			PaintUtil.with_alpha(deep, 0.6), PaintUtil.ol(ctx, "struct"))


static func _pants_leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, col: Color, variant: String, ctx: Dictionary, is_far: bool) -> void:
	var ink := PaintUtil.ink(ctx)
	var shade := PaintUtil.color(ctx, "shade")
	var ow := PaintUtil.ow(ctx)
	var outline := 0.0 if PaintUtil.is_mini(ctx) else ow * (0.24 if is_far else 0.30)
	var width := 8.8
	if variant == "leggings":
		width = 7.2
	DrawKit.capsule(ci, hip, knee, width, col, ink, outline)
	if variant == "shorts":
		var cuff := knee + (hip - knee) * 0.16
		DrawKit.capsule(ci, cuff, knee, width + 0.6, col, ink, outline)
		DrawKit.line(ci, cuff + Vector2(-width * 0.5, 0), cuff + Vector2(width * 0.5, 0),
				PaintUtil.with_alpha(shade, 0.8), PaintUtil.ol(ctx, "struct"))
	else:
		var ankle := foot.lerp(knee, 0.12)
		DrawKit.capsule(ci, knee, ankle, width - 0.6, col, ink, outline)
		DrawKit.line(ci, ankle + Vector2(-3, 0), ankle + Vector2(3, 0),
				PaintUtil.with_alpha(shade, 0.9), PaintUtil.ol(ctx, "struct"))
	if variant == "leggings" and not PaintUtil.is_mini(ctx):
		DrawKit.line(ci, hip.lerp(knee, 0.25), knee.lerp(foot, 0.2),
				PaintUtil.with_alpha(PaintUtil.color(ctx, "light"), 0.7), PaintUtil.detail_w(ctx))


# ------------------------------------------------------------------ 上衣

static func _shirt(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.color(ctx, "light")
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var lean: float = p["torso_lean"]
	var hip: Vector2 = p["hip"]
	var chest: Vector2 = p["chest"]
	var neck: Vector2 = p["neck"]
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col
	var studio := _studio(ctx)

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
				shade, ink, 0.0)
		DrawKit.arc(ci, neck + Vector2(0, 0).rotated(lean), 13.0, 0.2, PI - 0.2,
				PaintUtil.with_alpha(deep, 0.55), PaintUtil.ol(ctx, "struct"))
	if variant == "dress":
		for side in [-1.0, 1.0]:
			var shoulder: Vector2 = p["shoulder_r"] if side > 0 else p["shoulder_l"]
			DrawKit.circle(ci, shoulder + Vector2(2 * side, 1), 6.6,
					far if side < 0 else col, ink, 0.0)

	if sleeves:
		_sleeve(ci, p["shoulder_l"], p["elbow_l"], p["hand_l"], far, full_sleeves, ctx)
	# 躯干在木偶身之上：不再加第二条 ink，靠受光/背光与结构线分界。
	var torso_pts := DrawKit._ellipse_points((hip + chest) * 0.5, Vector2(14.0, 22.0), lean, 18)
	if studio:
		DrawKit.layer_shadow(ci, torso_pts, 0.09)
	DrawKit.capsule(ci, hip, chest, 26.0, col, ink, 0.0)
	DrawKit.capsule(ci, (p["shoulder_l"] as Vector2).lerp(chest, 0.25),
			(p["shoulder_r"] as Vector2).lerp(chest, 0.25), 14.0, col, ink, 0.0)
	if studio:
		var lit := (hip + chest) * 0.5 + Vector2(-4.8, -2.0).rotated(lean)
		DrawKit.ellipse(ci, lit, Vector2(6.6, 18.0), lean,
				PaintUtil.with_alpha(light, 0.40), Color.WHITE, 0.0)
		var dark := (hip + chest) * 0.5 + Vector2(7.2, 2.2).rotated(lean)
		DrawKit.ellipse(ci, dark, Vector2(4.2, 16.5), lean,
				PaintUtil.with_alpha(shade, 0.32), Color.WHITE, 0.0)
		DrawKit.line(ci, chest + Vector2(11.6, 2).rotated(lean), hip + Vector2(11.6, -4).rotated(lean),
				PaintUtil.with_alpha(PaintUtil.rim_warm(ctx), 0.75), 0.8)
		DrawKit.paper_fibers(ci, (hip + chest) * 0.5, Vector2(30, 32), variant.hash(),
				PaintUtil.with_alpha(deep, 0.04))

	match variant:
		"tunic":
			DrawKit.rrect(ci, hip + Vector2(0, 5).rotated(lean), Vector2(32, 11.5), 3.5, lean,
					col, ink, ow * 0.55)
			DrawKit.line(ci, hip + Vector2(-13, 9).rotated(lean), hip + Vector2(13, 9).rotated(lean),
					PaintUtil.with_alpha(deep, 0.6), PaintUtil.ol(ctx, "struct"))
			DrawKit.line(ci, neck + Vector2(-5, 3), neck + Vector2(0, 12),
					PaintUtil.with_alpha(shade, 0.9), 1.0)
			DrawKit.line(ci, neck + Vector2(5, 3), neck + Vector2(0, 12),
					PaintUtil.with_alpha(shade, 0.9), 1.0)
			DrawKit.circle(ci, neck + Vector2(0, 13), 1.4,
					PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)
		"hoodie":
			DrawKit.line(ci, hip + Vector2(-12, 6).rotated(lean), hip + Vector2(12, 6).rotated(lean),
					PaintUtil.with_alpha(deep, 0.55), PaintUtil.ol(ctx, "struct"))
			DrawKit.rrect(ci, hull(hip, -6, 13, lean), Vector2(15, 9), 3.0, lean, shade, ink, 0.0)
			for side in [-1.0, 1.0]:
				DrawKit.line(ci, neck + Vector2(5 * side, 8), neck + Vector2(7 * side, 15),
						PaintUtil.with_alpha(light, 0.85), 0.9)
				DrawKit.circle(ci, neck + Vector2(7 * side, 16), 1.2,
						PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.2)
		"vest":
			DrawKit.rrect(ci, chest.lerp(hip, 0.35), Vector2(6.4, 32), 2.0, lean,
					PaintUtil.mat_color(ctx, "paper", "base"), ink, 0.0)
			DrawKit.poly_at(ci, neck + Vector2(-5, 1).rotated(lean),
					[Vector2(0, 0), Vector2(5, 1), Vector2(2, 9)], lean, shade, ink, 0.0)
			DrawKit.poly_at(ci, neck + Vector2(5, 1).rotated(lean),
					[Vector2(0, 0), Vector2(-5, 1), Vector2(-2, 9)], lean, shade, ink, 0.0)
			for i in 3:
				DrawKit.circle(ci, chest.lerp(hip, 0.30 + i * 0.18) + Vector2(-1, 0), 1.3,
						PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)
		"armor":
			var plate := chest.lerp(hip, 0.38)
			DrawKit.rrect(ci, plate, Vector2(28, 29), 7.0, lean, col, ink, ow * 0.6)
			DrawKit.line(ci, plate + Vector2(-8, -9).rotated(lean), plate + Vector2(8, -9).rotated(lean),
					PaintUtil.with_alpha(light, 0.9), 1.2)
			DrawKit.line(ci, plate + Vector2(0, -12), plate + Vector2(0, 12).rotated(lean),
					PaintUtil.with_alpha(deep, 0.55), PaintUtil.ol(ctx, "struct"))
			for side in [-1.0, 1.0]:
				var shoulder: Vector2 = p["shoulder_r"] if side > 0 else p["shoulder_l"]
				DrawKit.circle(ci, shoulder + Vector2(4 * side, -1), 6.8,
						PaintUtil.mat_color(ctx, "metal", "base"), ink, ow * 0.5)
				DrawKit.arc(ci, shoulder + Vector2(4 * side, -1), 4.4, -2.2, -0.6,
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "metal", "hi"), 0.9), 1.0)
				DrawKit.circle(ci, shoulder + Vector2(2 * side, -1), 1.6,
						PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)
			for i in 2:
				DrawKit.circle(ci, plate + Vector2(-10 + i * 20, 7).rotated(lean), 1.7,
						PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)
		"dress":
			var skirt := PackedVector2Array([
				hip + Vector2(-14, -2).rotated(lean),
				hip + Vector2(14, -2).rotated(lean),
				hip + Vector2(24, 28),
				hip + Vector2(10, 32),
				hip + Vector2(0, 29),
				hip + Vector2(-11, 32),
				hip + Vector2(-24, 27),
			])
			if studio:
				DrawKit.layer_shadow(ci, skirt, 0.12)
			DrawKit.polygon(ci, skirt, col, ink, ow * 0.9)
			DrawKit.line(ci, hip + Vector2(-22, 24), hip + Vector2(22, 24),
					PaintUtil.with_alpha(light, 0.8), 1.0)
			if studio:
				for i in 3:
					DrawKit.line(ci, hip + Vector2(-9 + i * 9, 3), hip + Vector2(-14 + i * 10, 29),
							PaintUtil.with_alpha(shade, 0.6), PaintUtil.detail_w(ctx))
			DrawKit.arc(ci, neck + Vector2(0, 3), 8.0, 0.2, PI - 0.2,
					PaintUtil.mat_color(ctx, "paper", "base"), 1.2)
		_:
			DrawKit.line(ci, hip + Vector2(-11, 3).rotated(lean), hip + Vector2(11, 3).rotated(lean),
					PaintUtil.with_alpha(deep, 0.5), PaintUtil.ol(ctx, "struct"))
	if sleeves:
		_sleeve(ci, p["shoulder_r"], p["elbow_r"], p["hand_r"], col, full_sleeves, ctx)


static func hull(center: Vector2, dx: float, dy: float, rot: float) -> Vector2:
	return center + Vector2(dx, dy).rotated(rot)


static func _sleeve(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, col: Color, full: bool, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	DrawKit.capsule(ci, shoulder, elbow.lerp(shoulder, 0.06), 10.2, col, ink, 0.0)
	if full:
		DrawKit.capsule(ci, elbow, hand.lerp(elbow, 0.10), 7.8, col, ink, 0.0)
		DrawKit.capsule(ci, hand.lerp(elbow, 0.16), hand.lerp(elbow, 0.06), 7.2,
				PaintUtil.color(ctx, "shade"), ink, 0.0)
	else:
		DrawKit.capsule(ci, elbow.lerp(shoulder, 0.02), elbow.lerp(shoulder, 0.14), 10.2,
				PaintUtil.color(ctx, "shade"), ink, 0.0)
	if not PaintUtil.is_mini(ctx):
		DrawKit.line(ci, shoulder.lerp(elbow, 0.15) + Vector2(0, -4.2),
				shoulder.lerp(elbow, 0.85) + Vector2(0, -4.2),
				PaintUtil.with_alpha(PaintUtil.color(ctx, "light"), 0.55), PaintUtil.detail_w(ctx))


# ------------------------------------------------------------------ 鞋

static func _shoes(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var far := PaintUtil.far_color(ctx) if PaintUtil.is_far(ctx) else col
	_shoe(ci, p["foot_l"], float(p["foot_angle_l"]), far, variant, ctx)
	_shoe(ci, p["foot_r"], float(p["foot_angle_r"]), col, variant, ctx)


static func _shoe(ci: CanvasItem, foot: Vector2, angle: float, col: Color, variant: String, ctx: Dictionary) -> void:
	var ink := PaintUtil.ink(ctx)
	var ow := PaintUtil.ow(ctx)
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var light := PaintUtil.color(ctx, "light")
	var center := foot + Vector2(2.5, 0.5).rotated(angle)
	var outline := ow * 0.50
	var studio := _studio(ctx)
	match variant:
		"boots":
			DrawKit.capsule(ci, center + Vector2(-1, -7), center + Vector2(0, 1), 8.2, shade, ink, 0.0)
			DrawKit.rrect(ci, center, Vector2(17.0, 9.8), 3.6, angle, col, ink, outline)
			DrawKit.line(ci, center + Vector2(-6, 4.0).rotated(angle), center + Vector2(6, 4.0).rotated(angle),
					PaintUtil.with_alpha(deep, 0.7), PaintUtil.ol(ctx, "struct"))
			DrawKit.arc(ci, center + Vector2(4, -1).rotated(angle), 3.6, -0.6, 1.2,
					PaintUtil.with_alpha(light, 0.8), 0.8)
			if studio:
				for i in 3:
					DrawKit.circle(ci, center + Vector2(-5 + i * 4, 1.0).rotated(angle), 0.55,
							PaintUtil.mat_color(ctx, "gold", "light"), Color.WHITE, 0.0)
		"sneakers":
			DrawKit.rrect(ci, center + Vector2(0, 3).rotated(angle), Vector2(17.5, 5), 2.4, angle,
					PaintUtil.mat_color(ctx, "paper", "base"), ink, 0.0)
			DrawKit.rrect(ci, center, Vector2(15.0, 8.2), 3.2, angle, col, ink, outline)
			DrawKit.ellipse(ci, center + Vector2(5, 1).rotated(angle), Vector2(3.5, 3.0), angle,
					PaintUtil.with_alpha(light, 0.85), ink, 0.0)
			if studio:
				for i in 2:
					DrawKit.line(ci, center + Vector2(-4 + i * 3, -2).rotated(angle),
							center + Vector2(-2 + i * 3, 1).rotated(angle),
							PaintUtil.mat_color(ctx, "paper", "base"), PaintUtil.detail_w(ctx))
		"clogs":
			DrawKit.rrect(ci, center + Vector2(0, 2.5).rotated(angle), Vector2(16.5, 5.2), 2.4, angle,
					PaintUtil.mat_color(ctx, "wood", "shade"), ink, 0.0)
			DrawKit.rrect(ci, center - Vector2(0, 1).rotated(angle), Vector2(12.4, 5.2), 2.4, angle,
					col, ink, outline)
			for i in 2:
				DrawKit.capsule(ci, center + Vector2(-4 + i * 7, -4).rotated(angle),
						center + Vector2(-1 + i * 7, 2).rotated(angle), 2.3,
						PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)
		"bare":
			DrawKit.ellipse(ci, center, Vector2(7.8, 4.8), angle, col, ink, outline * 0.8)
			if studio:
				for i in 3:
					DrawKit.circle(ci, center + Vector2(4.2 + i * 1.2, -1 + i * 1.0).rotated(angle), 1.2,
							PaintUtil.with_alpha(light, 0.9), ink, 0.0)
	if studio:
		# 鞋头右侧 1px 暖轮廓，和主光方向一致。
		DrawKit.arc(ci, center + Vector2(4.0, 0).rotated(angle), 4.2, -0.8, 1.1,
				PaintUtil.with_alpha(PaintUtil.rim_warm(ctx), 0.55), 0.9)


# ------------------------------------------------------------------ 腰带 / 手套

static func _belt(ci: CanvasItem, variant: String, ctx: Dictionary) -> void:
	var p := PaintUtil.pose(ctx)
	var col := PaintUtil.color(ctx, "primary")
	var shade := PaintUtil.color(ctx, "shade")
	var deep := PaintUtil.color(ctx, "deep")
	var ink := PaintUtil.ink(ctx)
	var hip: Vector2 = p["hip"]
	var lean: float = p["torso_lean"]
	var a := hip + Vector2(-14, -5).rotated(lean)
	var b := hip + Vector2(14, -5).rotated(lean)
	var studio := _studio(ctx)

	DrawKit.capsule(ci, a, b, 7.2, col, ink, PaintUtil.ow(ctx) * 0.55)
	match variant:
		"rope":
			DrawKit.line(ci, a.lerp(b, 0.15), a.lerp(b, 0.85), PaintUtil.with_alpha(deep, 0.7), 1.0)
			var knot := b + Vector2(-2, 0)
			DrawKit.circle(ci, knot, 3.2, col, ink, 0.4)
			for i in 2:
				var tail := knot + Vector2(3 + i * 2, 5 + i * 6 + sin(float(ctx["time"]) * 3.0 + i) * 1.2)
				DrawKit.capsule(ci, knot, tail, 2.7 - i * 0.5, shade, ink, 0.0)
			if studio:
				DrawKit.line(ci, a.lerp(b, 0.25), a.lerp(b, 0.75), PaintUtil.with_alpha(shade, 0.8), PaintUtil.detail_w(ctx))
		"sash":
			DrawKit.capsule(ci, a + Vector2(0, 1), b + Vector2(0, 1), 9.2, col, ink, 0.0)
			DrawKit.line(ci, a + Vector2(1, -2), b + Vector2(-1, -2),
					PaintUtil.with_alpha(PaintUtil.color(ctx, "light"), 0.85), 0.9)
			var tail := PackedVector2Array([
				b + Vector2(-3, 3), b + Vector2(4, 3),
				b + Vector2(6, 18), b + Vector2(1, 21), b + Vector2(-2, 14),
			])
			DrawKit.polygon(ci, tail, shade, ink, 0.0)
		"pouch":
			var pouch := hip + Vector2(12, 7).rotated(lean)
			DrawKit.rrect(ci, pouch, Vector2(11.5, 13.5), 3.0, lean, shade, ink, 0.5)
			DrawKit.rrect(ci, pouch + Vector2(0, -5).rotated(lean), Vector2(12.0, 5), 2.0, lean,
					col, ink, 0.0)
			DrawKit.circle(ci, pouch + Vector2(0, -1).rotated(lean), 1.3,
					PaintUtil.mat_color(ctx, "gold", "base"), ink, 0.3)


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
	var deep := PaintUtil.color(ctx, "deep")
	var studio := _studio(ctx)
	match variant:
		"mittens":
			DrawKit.capsule(ci, elbow.lerp(hand, 0.66), hand, 6.8, col, ink, 0.0)
			DrawKit.circle(ci, hand, 5.4, col, ink, ow * 0.5)
			DrawKit.circle(ci, hand + (elbow - hand).normalized().rotated(0.9) * 4.0, 2.3, col, ink, 0.0)
			DrawKit.line(ci, elbow.lerp(hand, 0.72) + Vector2(-2, -2), elbow.lerp(hand, 0.72) + Vector2(2, 2),
					PaintUtil.with_alpha(PaintUtil.color(ctx, "light"), 0.8), 0.9)
		"bracers":
			DrawKit.capsule(ci, elbow.lerp(hand, 0.42), hand, 7.0, col, ink, 0.0)
			for i in 2:
				var c := elbow.lerp(hand, 0.55 + i * 0.22)
				DrawKit.line(ci, c + Vector2(-3, -2), c + Vector2(3, 2),
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "gold", "base"), 0.95), 1.0)
			DrawKit.circle(ci, hand, 4.4, col, ink, ow * 0.4)
			if studio:
				DrawKit.arc(ci, elbow.lerp(hand, 0.55), 3.6, -1.0, 0.8,
						PaintUtil.with_alpha(PaintUtil.mat_color(ctx, "metal", "hi"), 0.8), 0.8)
		"claws":
			DrawKit.circle(ci, hand, 5.2, col, ink, ow * 0.5)
			var dir := (hand - elbow).normalized()
			for i in 3:
				var a := dir.rotated(-0.45 + i * 0.45)
				DrawKit.poly_at(ci, hand + a * 2.0, [
					Vector2(-1.6, 0), Vector2(0, 6.8), Vector2(1.6, 0),
				], a.angle() + PI * 0.5, PaintUtil.mat_color(ctx, "paper", "hi"), ink, 0.3)
			DrawKit.line(ci, elbow.lerp(hand, 0.55), hand, PaintUtil.with_alpha(deep, 0.7), 0.8)
