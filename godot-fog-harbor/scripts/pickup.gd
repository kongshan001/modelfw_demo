class_name FogPickup
extends Node2D
## 丢弃/地面物资：0.6 秒后可自动拾取，背包满则留在地上。

signal collected(id: String, count: int)

var item_id := "brass_parts"
var count := 1
var player: Node2D = null
var inventory: FogInventory = null
var delay := 0.6
var _bob := 0.0


func configure(id: String, amount: int, pos: Vector2, player_node: Node2D, inv: FogInventory) -> void:
	item_id = id
	count = amount
	global_position = pos
	player = player_node
	inventory = inv
	_bob = randf() * TAU


func _ready() -> void:
	z_index = 2
	queue_redraw()


func _process(delta: float) -> void:
	_bob += delta
	delay = maxf(0.0, delay - delta)
	if delay <= 0.0 and player != null and inventory != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) < 34.0 and not bool(player.get("dead")):
			var got := inventory.add_item(item_id, count)
			if got > 0:
				count -= got
				collected.emit(item_id, got)
				queue_redraw()
				if count <= 0:
					queue_free()
					return
	queue_redraw()


func _draw() -> void:
	var lift := sin(_bob * 2.4) * 2.0
	draw_circle(Vector2(0, 6), 11.0, Color(0, 0, 0, 0.3), true)
	draw_circle(Vector2(0, lift - 2), 15.0, Color(0.4, 0.85, 0.75, 0.06), true)
	var rect := Rect2(Vector2(-11, -12 + lift), Vector2(22, 22))
	FogItemArt.draw_icon(self, rect, item_id)
	var rarity := int(FogItems.get_item(item_id).get("rarity", 0))
	draw_rect(rect.grow(2), Color(FogItems.rarity_color(rarity), 0.55), false, 1.2)
	if count > 1:
		FogUITheme.draw_text(self, Vector2(6, 16), str(count), 11, Color("f0dba6"), true)
