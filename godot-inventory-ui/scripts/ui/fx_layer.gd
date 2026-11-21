class_name FxLayer
extends Control

var _particles: Array = []
var _spark_tex: Texture2D


func setup() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_tex = ThemeKit.ui_tex("sparkle")
	set_process(false)


func burst(center: Vector2, main_color: Color = Color("ffe39a"), count: int = 26) -> void:
	var palette := [main_color, Color("fff4c8"), Color("ffd06a"), Color("bffcf0")]
	for i in range(count):
		var ang := randf() * TAU
		var speed := randf_range(50.0, 210.0)
		var life := randf_range(0.38, 0.72)
		_particles.append({
			"pos": center + Vector2(randf_range(-12, 12), randf_range(-10, 10)),
			"vel": Vector2(cos(ang), sin(ang)) * speed + Vector2(0, -50.0),
			"life": life,
			"max_life": life,
			"size": randf_range(2.0, 5.2),
			"color": palette[randi() % palette.size()],
			"kind": "dot",
		})
	for i in range(3):
		var ang2 := randf() * TAU
		var life2 := randf_range(0.28, 0.42)
		_particles.append({
			"pos": center,
			"vel": Vector2(cos(ang2), sin(ang2)) * randf_range(20, 50),
			"life": life2,
			"max_life": life2,
			"size": randf_range(34.0, 56.0),
			"color": Color(1.0, 0.93, 0.7, 0.9),
			"kind": "spark",
			"rot": randf() * TAU,
		})
	_particles.append({
		"pos": center,
		"vel": Vector2.ZERO,
		"life": 0.30,
		"max_life": 0.30,
		"size": 18.0,
		"color": Color(1.0, 0.95, 0.75, 0.65),
		"kind": "ring",
	})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var alive: Array = []
	for p in _particles:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			continue
		var t := 1.0 - float(p["life"]) / float(p["max_life"])
		if p["kind"] == "dot":
			p["vel"] = p["vel"] + Vector2(0, 260.0 * delta)
			p["vel"] = p["vel"] * (1.0 - 1.4 * delta)
			p["pos"] = p["pos"] + p["vel"] * delta
		elif p["kind"] == "spark":
			p["pos"] = p["pos"] + p["vel"] * delta
		alive.append(p)
	_particles = alive
	queue_redraw()
	if _particles.is_empty():
		set_process(false)


func _draw() -> void:
	for p in _particles:
		var t := 1.0 - float(p["life"]) / float(p["max_life"])
		var a := clampf(1.0 - t, 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= a
		match str(p["kind"]):
			"dot":
				draw_circle(p["pos"], float(p["size"]) * (0.5 + a * 0.6), col)
			"spark":
				var s: float = float(p["size"])
				var rect := Rect2(p["pos"] - Vector2(s, s) * 0.5, Vector2(s, s))
				draw_texture_rect(_spark_tex, rect, false, col)
			"ring":
				draw_arc(p["pos"], 24.0 + t * 46.0, 0, TAU, 32, col, 2.5, true)
