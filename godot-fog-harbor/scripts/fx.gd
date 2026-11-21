class_name FogFx
extends Node2D
## 轻量世界特效：曳光、火花、浮动数字、圆环、近战弧光。无粒子节点开销。

var effects: Array = []
var _rng := RandomNumberGenerator.new()
var _counter := 0


func _ready() -> void:
	z_index = 6
	_rng.seed = 20261121


func _process(delta: float) -> void:
	if effects.is_empty():
		return
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["t"] = float(effects[i]["t"]) + delta
		if float(effects[i]["t"]) >= float(effects[i]["life"]):
			effects.remove_at(i)
	queue_redraw()


func tracer(from: Vector2, to: Vector2, color := Color("ffd795")) -> void:
	effects.append({"kind": "tracer", "from": from, "to": to, "color": color, "t": 0.0, "life": 0.09})


func spark(pos: Vector2, color := Color("e9b35c"), count := 6) -> void:
	_counter += 1
	_rng.seed = _counter * 977 + 23
	for i in range(count):
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(40.0, 150.0)
		effects.append({
			"kind": "spark", "pos": pos, "vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": color, "t": 0.0, "life": _rng.randf_range(0.18, 0.35),
		})


func float_text(pos: Vector2, text: String, color := Color("f0c66c")) -> void:
	effects.append({"kind": "text", "pos": pos, "text": text, "color": color, "t": 0.0, "life": 0.85})


func ring(pos: Vector2, color := Color("6fe0c2"), radius := 28.0) -> void:
	effects.append({"kind": "ring", "pos": pos, "color": color, "radius": radius, "t": 0.0, "life": 0.4})


func slash(pos: Vector2, angle: float, color := Color("df655b")) -> void:
	effects.append({"kind": "slash", "pos": pos, "angle": angle, "color": color, "t": 0.0, "life": 0.22})


func _draw() -> void:
	for e in effects:
		var t := float(e["t"])
		var life := float(e["life"])
		var k := clampf(t / life, 0.0, 1.0)
		match String(e["kind"]):
			"tracer":
				var color: Color = e["color"]
				draw_line(e["from"], e["to"], Color(color.r, color.g, color.b, 0.9 * (1.0 - k)), 2.0)
				draw_circle(e["to"], 3.0 * (1.0 - k), Color(color.r, color.g, color.b, 0.8 * (1.0 - k)), true)
			"spark":
				var pos: Vector2 = e["pos"] + e["vel"] * t
				var color: Color = e["color"]
				draw_circle(pos, 2.2 * (1.0 - k) + 0.6, Color(color.r, color.g, color.b, 1.0 - k), true)
			"text":
				var y_off := -28.0 * k
				var color: Color = e["color"]
				FogUITheme.draw_text(self, e["pos"] + Vector2(-4, y_off), String(e["text"]), 15,
					Color(color.r, color.g, color.b, 1.0 - k * 0.8), true)
			"ring":
				var color: Color = e["color"]
				draw_arc(e["pos"], float(e["radius"]) * (0.5 + k * 1.6), 0.0, TAU, 24,
					Color(color.r, color.g, color.b, 0.8 * (1.0 - k)), 2.0)
			"slash":
				var color: Color = e["color"]
				draw_arc(e["pos"], 24.0, float(e["angle"]) - 0.8, float(e["angle"]) + 0.8, 12,
					Color(color.r, color.g, color.b, 0.8 * (1.0 - k)), 3.5)
