class_name MapInfo
extends RefCounted
## Prepared map: polyline path, samples, build cells and props.
## All coordinates are field-local HTML pixels: x 0..464, y 0..336.

const GData = preload("res://scripts/game_data.gd")
const EMath = preload("res://scripts/ember_math.gd")

var id: String
var def: Dictionary
var points: Array[Vector2] = []
var segments: Array[Dictionary] = []
var samples: Array[Vector2] = []
var props: Array[Dictionary] = []
var blocked: Dictionary = {}
var build_cells: Array[Vector2i] = []
var buildable_set: Dictionary = {}
var total_len: float = 0.0
var beacon: Vector2
var portal: Vector2


func cell_key(cx: int, cy: int) -> String:
	return str(cx) + "," + str(cy)


func cell_center(cx: int, cy: int) -> Vector2:
	return Vector2(cx * GData.TILE + GData.TILE * 0.5,
		cy * GData.TILE + GData.TILE * 0.5)


func distance_to_path(x: float, y: float) -> float:
	var best := 1e9
	for seg in segments:
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var dx := b.x - a.x
		var dy := b.y - a.y
		var t := clampf(((x - a.x) * dx + (y - a.y) * dy) / (seg["len"] * seg["len"]), 0.0, 1.0)
		var px := a.x + dx * t
		var py := a.y + dy * t
		var d := EMath.dist(x, y, px, py)
		if d < best:
			best = d
	return best


func point_at(distance: float) -> Dictionary:
	distance = clampf(distance, 0.0, total_len)
	for i in segments.size():
		var seg: Dictionary = segments[i]
		if distance <= seg["end"] or i == segments.size() - 1:
			var t := clampf((distance - seg["start"]) / seg["len"], 0.0, 1.0)
			var a: Vector2 = seg["a"]
			var b: Vector2 = seg["b"]
			return {"pos": a.lerp(b, t), "seg": seg}
	return {"pos": points[points.size() - 1], "seg": segments[segments.size() - 1]}


func is_buildable(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= GData.GW or cy < 0 or cy >= GData.GH:
		return false
	return buildable_set.has(cell_key(cx, cy))
