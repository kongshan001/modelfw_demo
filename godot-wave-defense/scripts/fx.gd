extends Node2D
## 轻量反馈层：伤害数字、金币飘字、箭线、炮塔弹道、爆炸、火花、挥砍弧。
## 不创建子节点；所有效果在单个 _draw 中批量绘制，主循环调用 tick。

const Art = preload("res://scripts/art.gd")

var effects: Array = []
var _rng := RandomNumberGenerator.new()
var _seed_counter := 0


func _ready() -> void:
	_rng.seed = 20261122


func clear() -> void:
	effects.clear()
	queue_redraw()


func tick(delta: float) -> void:
	if effects.is_empty():
		return
	for i in range(effects.size() - 1, -1, -1):
		var eff: Dictionary = effects[i]
		eff["age"] = float(eff["age"]) + delta
		if float(eff["age"]) >= float(eff["life"]):
			effects.remove_at(i)
	queue_redraw()


func damage_text(pos: Vector2, amount: int, color: Color, big := false) -> void:
	var life := 0.9 if big else 0.78
	effects.append({
		"kind": "text",
		"pos": pos + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3)),
		"text": str(amount),
		"color": color,
		"size": 20 if big else 15,
		"age": 0.0,
		"life": life,
	})
	_trim()


func gold_text(pos: Vector2, amount: int) -> void:
	effects.append({
		"kind": "text",
		"pos": pos + Vector2(_rng.randf_range(-5, 5), -4),
		"text": "+%d 金" % amount,
		"color": Art.GOLD,
		"size": 14,
		"age": 0.0,
		"life": 0.95,
	})
	_trim()


func notice_text(pos: Vector2, value: String, color: Color) -> void:
	effects.append({
		"kind": "text",
		"pos": pos,
		"text": value,
		"color": color,
		"size": 16,
		"age": 0.0,
		"life": 1.15,
	})
	_trim()


func beam(from: Vector2, to: Vector2, color: Color, width := 2.5) -> void:
	effects.append({
		"kind": "beam",
		"from": from,
		"to": to,
		"color": color,
		"width": width,
		"age": 0.0,
		"life": 0.16,
	})
	_trim()


func ring(pos: Vector2, radius: float, color: Color, life := 0.35, width := 2.0) -> void:
	effects.append({
		"kind": "ring",
		"pos": pos,
		"radius": radius,
		"color": color,
		"width": width,
		"age": 0.0,
		"life": life,
	})
	_trim()


func burst(pos: Vector2, color: Color, count := 7, power := 70.0, life := 0.38) -> void:
	var parts: Array = []
	for i in range(count):
		var a := _rng.randf_range(0.0, TAU)
		parts.append({
			"dir": Vector2(cos(a), sin(a)) * _rng.randf_range(0.35, 1.0),
			"speed": power * _rng.randf_range(0.5, 1.15),
			"size": _rng.randf_range(1.2, 3.0),
		})
	effects.append({
		"kind": "burst",
		"pos": pos,
		"color": color,
		"parts": parts,
		"age": 0.0,
		"life": life,
	})
	_trim()


func explosion(pos: Vector2, radius: float, color := Color("ffb45e")) -> void:
	effects.append({
		"kind": "explosion",
		"pos": pos,
		"radius": radius,
		"color": color,
		"age": 0.0,
		"life": 0.38,
	})
	burst(pos, color, 12, 145.0, 0.5)
	_trim()


func slash(pos: Vector2, angle: float, radius: float, color := Color("b9f0dc")) -> void:
	effects.append({
		"kind": "slash",
		"pos": pos,
		"angle": angle,
		"radius": radius,
		"color": color,
		"age": 0.0,
		"life": 0.24,
	})
	_trim()


func shell(from: Vector2, to: Vector2, travel: float) -> void:
	effects.append({
		"kind": "shell",
		"from": from,
		"to": to,
		"age": 0.0,
		"life": maxf(0.05, travel),
	})
	_trim()


func coin_fly(from: Vector2, to: Vector2, amount: int) -> void:
	effects.append({
		"kind": "coin",
		"from": from,
		"to": to,
		"amount": amount,
		"age": 0.0,
		"life": 0.55,
	})
	_trim()


func _trim() -> void:
	while effects.size() > 100:
		effects.remove_at(0)


func _draw() -> void:
	for eff in effects:
		var age: float = eff["age"]
		var life: float = eff["life"]
		var t := clampf(age / maxf(0.001, life), 0.0, 1.0)
		match String(eff["kind"]):
			"text":
				_draw_text_effect(eff, t)
			"beam":
				var col: Color = eff["color"]
				col.a = 0.9 * (1.0 - t)
				draw_line(eff["from"], eff["to"], Color(col.r, col.g, col.b, col.a * 0.28), float(eff["width"]) * 3.0, true)
				draw_line(eff["from"], eff["to"], col, float(eff["width"]), true)
				draw_circle(eff["to"], 3.0 * (1.0 - t), Color(1, 1, 1, 0.7 * (1.0 - t)))
			"ring":
				var col: Color = eff["color"]
				col.a = (1.0 - t) * 0.95
				var radius := float(eff["radius"]) * (0.25 + 0.75 * t)
				draw_arc(eff["pos"], radius, 0, TAU, 44, col, float(eff["width"]) * (1.0 - t * 0.5), true)
			"burst":
				var col: Color = eff["color"]
				col.a = 1.0 - t
				for part in eff["parts"]:
					var dir: Vector2 = part["dir"]
					var speed: float = part["speed"]
					var dist := speed * t
					var p: Vector2 = eff["pos"] + dir * dist + Vector2(0, 26.0 * t * t)
					draw_circle(p, float(part["size"]) * (1.0 - t * 0.6), col)
			"explosion":
				var col: Color = eff["color"]
				var radius: float = eff["radius"]
				draw_circle(eff["pos"], radius * (0.25 + 0.35 * t), Color(col.r, col.g, col.b, 0.26 * (1.0 - t)))
				col.a = 1.0 - t
				draw_arc(eff["pos"], radius * (0.3 + 0.75 * t), 0, TAU, 40, col, 3.0 * (1.0 - t), true)
			"slash":
				var col: Color = eff["color"]
				col.a = 1.0 - t
				var angle: float = eff["angle"]
				var radius: float = eff["radius"]
				draw_arc(eff["pos"], radius, angle - 0.85, angle + 0.85, 20, col, 5.0 * (1.0 - t * 0.4), true)
				draw_arc(eff["pos"], radius * 0.72, angle - 0.55, angle + 0.55, 16,
					Color(col.r, col.g, col.b, col.a * 0.5), 2.0, true)
			"shell":
				var p: Vector2 = (eff["from"] as Vector2).lerp(eff["to"], t)
				p.y -= sin(t * PI) * 45.0
				var tail: Vector2 = (eff["from"] as Vector2).lerp(eff["to"], maxf(0.0, t - 0.14))
				tail.y -= sin(maxf(0.0, t - 0.14) * PI) * 45.0
				draw_line(tail, p, Color(0.95, 0.75, 0.40, 0.45), 3.0, true)
				draw_circle(p, 4.0, Art.AMBER)
				draw_circle(p, 2.0, Art.CREAM)
			"coin":
				var a: Vector2 = eff["from"]
				var b: Vector2 = eff["to"]
				var p := a.lerp(b, t)
				p.y -= sin(t * PI) * 66.0
				Art.coin(self, p, 4.5)
				if t > 0.72:
					Art.text_center(self, Rect2(b.x - 26, b.y - 30, 52, 16), "+%d" % int(eff["amount"]), 12, Art.GOLD, true)


func _draw_text_effect(eff: Dictionary, t: float) -> void:
	var alpha := 1.0
	if t > 0.62:
		alpha = 1.0 - (t - 0.62) / 0.38
	var col: Color = eff["color"]
	col.a = clampf(alpha, 0.0, 1.0)
	var text_value := String(eff["text"])
	var base_size := int(eff["size"])
	var size := base_size
	if t < 0.18:
		size = base_size + int(round(3.0 * (1.0 - t / 0.18)))
	var pos: Vector2 = eff["pos"]
	pos.y -= 34.0 * t
	var f: Font = Art.bold_font()
	var width := f.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := pos.y
	draw_string(f, Vector2(pos.x - width * 0.5 + 1, baseline + 1), text_value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * alpha))
	draw_string(f, Vector2(pos.x - width * 0.5, baseline), text_value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
