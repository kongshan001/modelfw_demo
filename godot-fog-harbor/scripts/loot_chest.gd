class_name FogChest
extends Node2D
## 可搜索补给箱。按住 E 搜 0.9 秒，把能装下的物资塞进背包；
## 装不下时剩余物资留在箱内，可清背包后再搜。

const SEARCH_TIME := 0.9

var chest_id := "chest"
var tier := 0
var loot: Array = []
var progress := 0.0
var highlight := false
var opened_once := false
var rng := RandomNumberGenerator.new()


func configure(id: String, pos: Vector2, chest_tier: int, seed_value: int) -> void:
	chest_id = id
	tier = chest_tier
	global_position = pos
	rng.seed = seed_value * 7919 + tier * 131 + 17
	loot = FogItems.roll_chest(rng, tier)


func _ready() -> void:
	z_index = 1
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 16)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	queue_redraw()


func is_empty() -> bool:
	return loot.is_empty()


func loot_count() -> int:
	var total := 0
	for entry in loot:
		total += int(entry["count"])
	return total


func cancel_search() -> void:
	progress = 0.0
	queue_redraw()


func search_tick(delta: float, inventory: FogInventory) -> Dictionary:
	if loot.is_empty():
		progress = 0.0
		queue_redraw()
		return {"state": "empty"}
	progress += maxf(0.0, delta)
	if progress < SEARCH_TIME:
		queue_redraw()
		return {"state": "searching", "ratio": clampf(progress / SEARCH_TIME, 0.0, 1.0)}
	progress = 0.0
	var first := not opened_once
	opened_once = true
	var transfer := inventory.add_loot(loot)
	var remaining: Array = []
	for raw in loot:
		var id := String(raw["id"])
		var left := int(raw["count"])
		for added in transfer["added"]:
			if String(added["id"]) == id:
				left -= int(added["count"])
		if left > 0:
			remaining.append({"id": id, "count": left})
	loot = remaining
	queue_redraw()
	return {
		"state": "searched",
		"added": transfer["added"],
		"missed": transfer["missed"],
		"first": first,
		"empty": loot.is_empty(),
	}


func search_instant(inventory: FogInventory) -> Dictionary:
	return search_tick(SEARCH_TIME + 0.1, inventory)


func _draw() -> void:
	var body := Rect2(-16, -10, 32, 20)
	draw_rect(Rect2(body.position + Vector2(3, 4), body.size), Color(0, 0, 0, 0.38), true)
	if is_empty():
		draw_rect(body, Color("2c3738"), true)
		draw_rect(body, Color("566465"), false, 1.2)
		draw_line(Vector2(-15, -2), Vector2(15, -8), Color("596565"), 2.0)
		draw_circle(Vector2(5, 1), 2.0, Color(0.5, 0.55, 0.55, 0.5), true)
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + global_position.x)
	draw_circle(Vector2.ZERO, 22.0, Color(0.92, 0.72, 0.38, 0.045 + 0.025 * pulse), true)
	draw_rect(body, Color("5e4a31"), true)
	draw_rect(Rect2(-16, -10, 32, 8), Color("7d6440"), true)
	draw_rect(body, Color("b08b51"), false, 1.4)
	draw_line(Vector2(-16, -2), Vector2(16, -2), Color("3e3020"), 1.5)
	draw_rect(Rect2(-3, -4, 6, 7), Color("d0a75e"), true)
	draw_circle(Vector2(0, 0), 1.4, Color("2b2319"), true)
	if local_highlight():
		FogUITheme.draw_text(self, Vector2(-4, -18), "E", 14, Color("f0c66c"), true)
	if progress > 0.0:
		var ratio := clampf(progress / SEARCH_TIME, 0.0, 1.0)
		draw_rect(Rect2(-18, -28, 36, 4), Color(0, 0, 0, 0.7), true)
		draw_rect(Rect2(-18, -28, 36 * ratio, 4), Color("e9b35c"), true)


func local_highlight() -> bool:
	return highlight
