class_name PaintUtil
extends RefCounted

# 画师共享的坐标/取色助手。ctx 由 PaperDollRenderer 提供。
#
# 线宽层级（评审 P0-1）：
#   outer  = 外剪影，Studio 1.15 local（≈2.4px @2.1×）
#   struct = 结构分界，0.55 × outer
#   detail = 细节线，0.40 local（≈0.8px @2.1×）
# mini 只保留 outer：缩略图删除所有 <1.5px 的线。


static func pose(ctx: Dictionary) -> Dictionary:
	return ctx["pose"]


static func color(ctx: Dictionary, role: String) -> Color:
	var pal: Dictionary = ctx["pal"]
	return pal.get(role, pal["primary"])


static func ink(ctx: Dictionary) -> Color:
	return color(ctx, "ink")


static func accent(ctx: Dictionary) -> Color:
	return color(ctx, "accent")


static func is_mini(ctx: Dictionary) -> bool:
	return bool(ctx.get("mini", false))


static func is_far(ctx: Dictionary) -> bool:
	return float(ctx["yaw"]) > 0.18


static func far_visible(ctx: Dictionary) -> bool:
	return float(ctx["yaw"]) <= 0.85


static func ow(ctx: Dictionary) -> float:
	return DrawKit.OUTER_MINI if is_mini(ctx) else DrawKit.OUTER_STUDIO


static func ol(ctx: Dictionary, kind := "outer") -> float:
	# 供新代码使用：ol(ctx, "outer"/"struct"/"0")
	if is_mini(ctx):
		return ow(ctx) if kind == "outer" else 0.0
	match kind:
		"outer":
			return DrawKit.OUTER_STUDIO
		"struct":
			return DrawKit.OUTER_STUDIO * 0.55
		_:
			return 0.0


static func detail_w(ctx: Dictionary) -> float:
	return 0.0 if is_mini(ctx) else DrawKit.DETAIL_STUDIO


static func mat(ctx: Dictionary, key: String) -> Dictionary:
	var pal: Dictionary = ctx["pal"]
	# "paper" 在旧色板里是单色；材质 ramp 存在 paper_ramp。
	if key == "paper" and pal.has("paper_ramp"):
		return pal["paper_ramp"]
	var value: Variant = pal.get(key, pal)
	if value is Dictionary:
		return value
	return pal


static func mat_color(ctx: Dictionary, key: String, tone := "base") -> Color:
	var ramp: Dictionary = mat(ctx, key)
	if ramp.has(tone):
		return ramp[tone]
	return color(ctx, tone)


static func rim_warm(ctx: Dictionary) -> Color:
	return color(ctx, "rim")


static func rim_cool(ctx: Dictionary) -> Color:
	return color(ctx, "rim_cool")


static func highlight(ctx: Dictionary) -> Color:
	return color(ctx, "highlight")


static func head_angle(ctx: Dictionary) -> float:
	return float(pose(ctx)["head_angle"])


static func head_point(ctx: Dictionary, offset: Vector2) -> Vector2:
	var p := pose(ctx)
	return (p["head"] as Vector2) + offset.rotated(float(p["head_angle"]))


static func face_point(ctx: Dictionary, x: float, y: float) -> Vector2:
	# 3/4 侧脸：横向压缩远侧间距，并把五官整体往朝向侧推。
	var yaw: float = ctx["yaw"]
	var xx := x * (1.0 - 0.40 * yaw) + yaw * 4.8
	return head_point(ctx, Vector2(xx, y))


static func eye_positions(ctx: Dictionary) -> Array:
	var far := face_point(ctx, -6.2, 2.6)
	var near := face_point(ctx, 6.2, 2.6)
	var out: Array = [near]
	if far_visible(ctx):
		out.append(far)
	return out


static func torso_point(ctx: Dictionary, offset: Vector2) -> Vector2:
	var p := pose(ctx)
	return (p["hip"] as Vector2) + offset.rotated(float(p["torso_lean"]))


static func lerp_pt(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(b, t)


static func with_alpha(c: Color, a: float) -> Color:
	var out := c
	out.a = a
	return out


static func shade_of(ctx: Dictionary) -> Color:
	return color(ctx, "shade")


static func far_color(ctx: Dictionary) -> Color:
	return DrawKit.far(ctx["pal"])


static func sway(ctx: Dictionary, speed: float, amount: float, phase := 0.0) -> float:
	return sin(float(ctx["time"]) * speed + phase) * amount


static func secondary(ctx: Dictionary) -> float:
	# 披风/头发的滞后摆动，由 DollPose 按动作相位给出（local）。
	return float(pose(ctx).get("secondary", 0.0))
