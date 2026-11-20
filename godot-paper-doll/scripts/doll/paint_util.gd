class_name PaintUtil
extends RefCounted

# 画师共享的坐标/取色助手。ctx 由 PaperDollRenderer 提供。


static func pose(ctx: Dictionary) -> Dictionary:
	return ctx["pose"]


static func color(ctx: Dictionary, role: String) -> Color:
	var pal: Dictionary = ctx["pal"]
	return pal.get(role, pal["primary"])


static func ink(ctx: Dictionary) -> Color:
	return color(ctx, "ink")


static func accent(ctx: Dictionary) -> Color:
	return color(ctx, "accent")


static func is_far(ctx: Dictionary) -> bool:
	return float(ctx["yaw"]) > 0.18


static func far_visible(ctx: Dictionary) -> bool:
	return float(ctx["yaw"]) <= 0.85


static func ow(ctx: Dictionary) -> float:
	return 0.95 if bool(ctx.get("mini", false)) else 1.6


static func head_angle(ctx: Dictionary) -> float:
	return float(pose(ctx)["head_angle"])


static func head_point(ctx: Dictionary, offset: Vector2) -> Vector2:
	var p := pose(ctx)
	return (p["head"] as Vector2) + offset.rotated(float(p["head_angle"]))


static func face_point(ctx: Dictionary, x: float, y: float) -> Vector2:
	# 3/4 侧脸：横向压缩远侧间距，并把五官整体往朝向侧推。
	var yaw: float = ctx["yaw"]
	var xx := x * (1.0 - 0.38 * yaw) + yaw * 3.0
	return head_point(ctx, Vector2(xx, y))


static func eye_positions(ctx: Dictionary) -> Array:
	var far := face_point(ctx, -5.8, 2.4)
	var near := face_point(ctx, 5.8, 2.4)
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
