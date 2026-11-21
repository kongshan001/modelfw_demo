class_name FxLibrary
extends RefCounted

# Sprite sheets exported by the official PixelFX renderer
# (patch-gg/pixelfx @ 5294518ce7c72e48b6100a744596e0acf57f2826, MIT).
# JSON is Aseprite-style and carries meta.pixelfx with fps / loop / columns / pivot.
const EFFECTS := {
	"slash": {
		"png": "res://assets/pixelfx/melee/double-slash/double-slash.png",
		"json": "res://assets/pixelfx/melee/double-slash/double-slash.json",
	},
	"fireball": {
		"png": "res://assets/pixelfx/fire/fireball/fireball.png",
		"json": "res://assets/pixelfx/fire/fireball/fireball.json",
	},
	"explosion": {
		"png": "res://assets/pixelfx/explosions/small-explosion/small-explosion.png",
		"json": "res://assets/pixelfx/explosions/small-explosion/small-explosion.json",
	},
	"freeze": {
		"png": "res://assets/pixelfx/ice/freeze/freeze.png",
		"json": "res://assets/pixelfx/ice/freeze/freeze.json",
	},
	"coin": {
		"png": "res://assets/pixelfx/pickups/coin-spin/coin-spin.png",
		"json": "res://assets/pixelfx/pickups/coin-spin/coin-spin.json",
	},
	"burst": {
		"png": "res://assets/pixelfx/pickups/collect-burst/collect-burst.png",
		"json": "res://assets/pixelfx/pickups/collect-burst/collect-burst.json",
	},
}

var defs: Dictionary = {}
var errors: Array[String] = []

func load_all() -> bool:
	defs.clear()
	errors.clear()
	for key in EFFECTS:
		var entry: Dictionary = EFFECTS[key]
		var text := FileAccess.get_file_as_string(entry["json"])
		if text.is_empty():
			errors.append("%s: missing %s" % [key, entry["json"]])
			continue
		var data = JSON.parse_string(text)
		if data == null or not (data is Dictionary):
			errors.append("%s: bad JSON" % key)
			continue
		var frames: Array = data.get("frames", [])
		var meta: Dictionary = data.get("meta", {})
		var px: Dictionary = meta.get("pixelfx", {})
		if frames.is_empty() or px.is_empty():
			errors.append("%s: JSON missing frames/meta.pixelfx" % key)
			continue
		var tex: Texture2D = load(entry["png"])
		if tex == null:
			errors.append("%s: missing texture %s" % [key, entry["png"]])
			continue
		var fs: Array = px.get("frameSize", [1, 1])
		var pivot: Array = px.get("pivot", [0, 0])
		var fps: float = float(px.get("fps", 30))
		defs[key] = {
			"key": key,
			"id": str(px.get("id", key)),
			"texture": tex,
			"frame_size": Vector2i(int(fs[0]), int(fs[1])),
			"columns": int(px.get("columns", 1)),
			"frame_count": frames.size(),
			"fps": fps,
			"loop": bool(px.get("loop", false)),
			"pivot": Vector2(float(pivot[0]), float(pivot[1])),
			"duration": float(frames.size()) / fps,
			"sheet_size": Vector2i(int(meta.get("size", {}).get("w", 0)), int(meta.get("size", {}).get("h", 0))),
		}
	return errors.is_empty()

func get_def(key: String) -> Dictionary:
	return defs.get(key, {})

func keys() -> Array:
	return defs.keys()
