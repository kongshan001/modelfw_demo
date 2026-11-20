class_name SigilRules
extends RefCounted

# Runtime executor for rules.json.
# The offline executor is tools/bake_pipeline.py; both must produce the same
# RGBA bytes for the same seed. The rule is integer-only on purpose: no
# floating point, no anti-aliasing, no language-specific noise.

const RULES_PATH := "res://rules.json"
const Core := preload("res://src/core/portable_core.gd")


static func load_rules() -> Dictionary:
	var text := FileAccess.get_file_as_string(RULES_PATH)
	if text.is_empty():
		push_error("cannot read " + RULES_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("rules.json is not an object")
		return {}
	return parsed


static func hash32(x: int, y: int, seed: int) -> int:
	# 核心层实现；Python 烘焙端与 golden 向量保证逐位一致。
	return Core.hash32(x, y, seed)


static func generate(rules: Dictionary, seed: int) -> Image:
	var size := int(rules["size"])
	var dia: Dictionary = rules["diamond"]
	var runes: Dictionary = rules["runes"]
	var eye: Dictionary = rules["eye"]
	var det: Dictionary = rules["details"]
	var rx := int(dia["rx"])
	var ry := int(dia["ry"])
	var frame := int(dia["frame"])
	var hw := int(runes["half_w"])
	var hh := int(runes["half_h"])
	var jitter := int(runes["jitter"])
	var min_edge := int(runes["min_edge"])
	var min_center := int(runes["min_center"])
	var pupil := int(eye["pupil"])
	var iris := int(eye["iris"])
	var rim := int(eye["rim"])
	var ring := int(eye["ring"])
	var vignette := int(det["vignette"])
	var dither_hi := int(det["dither_hi_mod"])
	var dither_dark := int(det["dither_dark_mod"])
	var dither_dark_eq := int(det["dither_dark_eq"])
	var chip_mod := int(det["chip_mod"])

	var cols := {}
	for key in rules["palette"].keys():
		var a: Array = rules["palette"][key]
		cols[key] = [int(a[0]), int(a[1]), int(a[2])]

	var half := size >> 1
	var c := size - 1
	var k := 2 * rx * ry

	# rune bars: seeded jitter; skip if too close to the frame or the eye
	var bars: Array = []
	var offsets: Array = runes["offsets"]
	for i in offsets.size():
		var off: Array = offsets[i]
		var ox := int(off[0])
		var oy := int(off[1])
		var h := hash32(i, 777, seed)
		var bx := half + ox + (h % jitter) - 3
		var by := half + oy + ((h >> 8) % jitter) - 3
		var d := absi(2 * bx - c) * ry + absi(2 * by - c) * rx
		if k - d <= min_edge or d <= min_center:
			continue
		var color: Array = cols["gold"] if i % 2 == 0 else cols["gold_hi"]
		bars.append([bx - hw, by - hh, bx + hw, by + hh, color])

	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)

	for y in size:
		for x in size:
			var dx := absi(2 * x - c)
			var dy := absi(2 * y - c)
			var d := dx * ry + dy * rx
			if d > k:
				continue

			var edge := k - d
			var h := hash32(x, y, seed)
			var color: Array

			if edge < 120:
				color = cols["void"]
			elif edge < frame:
				color = cols["gold"]
			elif edge < frame + 70:
				color = cols["gold_hi"]
			else:
				color = cols["stone"]
				if dx * dx + dy * dy > vignette:
					color = cols["stone_dark"]
				if (h & dither_hi) == 0:
					color = cols["stone_hi"]
				elif (h & dither_dark) == dither_dark_eq:
					color = cols["stone_dark"]

			if edge < frame and (h & chip_mod) == 0:
				color = cols["void"]

			if d < pupil:
				color = cols["void"]
			elif d < iris:
				color = cols["ember"]
			elif d < rim:
				color = cols["ember_hi"]
			elif d < ring:
				color = cols["gold"]

			for bar: Array in bars:
				if bar[0] <= x and x < bar[2] and bar[1] <= y and y < bar[3]:
					color = bar[4]
					break

			var idx := (y * size + x) * 4
			bytes[idx] = color[0]
			bytes[idx + 1] = color[1]
			bytes[idx + 2] = color[2]
			bytes[idx + 3] = 255

	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)


static func sha256_rgba(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(img.get_data())
	return ctx.finish().hex_encode()
