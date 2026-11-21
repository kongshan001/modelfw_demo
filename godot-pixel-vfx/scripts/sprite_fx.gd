class_name SpriteFX
extends Node2D

# One playback instance of a PixelFX sprite sheet. Driven manually by Main.tick()
# so headless smoke tests and the deterministic recorder can step exact time.
# Draws one frame immediately (before the first step) and uses nearest-neighbour
# sampling at integer positions.

var def: Dictionary = {}
var texture: Texture2D
var frame_size := Vector2i(1, 1)
var columns := 1
var frame_count := 1
var fps := 30.0
var loop := false
var pivot := Vector2.ZERO
var tint := Color.WHITE
var speed := 1.0
var max_time := -1.0
var time := 0.0
var finished := false
var playing := true

func setup(source: Dictionary, loop_override: int = -1, time_limit: float = -1.0) -> void:
	def = source
	texture = source["texture"]
	frame_size = source["frame_size"]
	columns = source["columns"]
	frame_count = source["frame_count"]
	fps = source["fps"]
	loop = source["loop"] if loop_override < 0 else bool(loop_override)
	pivot = source["pivot"]
	max_time = time_limit
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = true
	queue_redraw()

func restart() -> void:
	time = 0.0
	finished = false
	playing = true
	queue_redraw()

func stop() -> void:
	playing = false
	finished = true

func step(dt: float) -> bool:
	if not playing or finished:
		return false
	time += dt * speed
	if max_time >= 0.0 and time >= max_time:
		time = max_time
		finished = true
		queue_redraw()
		return false
	var f := int(floor(time * fps))
	if f >= frame_count:
		if loop:
			time = fmod(time, float(frame_count) / fps)
		else:
			finished = true
			queue_redraw()
			return false
	queue_redraw()
	return true

func get_progress() -> float:
	if frame_count <= 0 or fps <= 0.0:
		return 0.0
	return clampf(time / (float(frame_count) / fps), 0.0, 1.0)

func get_frame_index() -> int:
	return clampi(int(floor(time * fps)), 0, frame_count - 1)

func get_duration() -> float:
	return float(frame_count) / fps

func _draw() -> void:
	if texture == null:
		return
	var f := clampi(int(floor(time * fps)), 0, frame_count - 1)
	var cx := f % columns
	var cy := int(f / columns)
	var src := Rect2(cx * frame_size.x, cy * frame_size.y, frame_size.x, frame_size.y)
	var dst := Rect2(Vector2(-pivot.x, -pivot.y), Vector2(frame_size))
	draw_texture_rect_region(texture, dst, src, tint)
