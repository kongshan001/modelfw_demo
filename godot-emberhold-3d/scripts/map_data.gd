class_name MapData
extends RefCounted
## Map definitions + deterministic preparation, ported from the HTML build.

const GData = preload("res://scripts/game_data.gd")
const EMath = preload("res://scripts/ember_math.gd")
const MInfo = preload("res://scripts/map_info.gd")

const MAP_DEFS := {
	"ashen": {
		"id": "ashen",
		"name": "灰烬小径",
		"latin": "ASHEN PATH",
		"diff": "普通",
		"desc": "折返长道 · 火力覆盖充足",
		"seed": 7319,
		"decor_seed": 9137,
		"waypoints": [[-1, 5], [20, 5], [20, 12], [6, 12], [6, 17], [27, 17], [29, 17]],
		"art": {
			"ground": ["#33452a", "#40572f", "#4d6838", "#5c7a42"],
			"ground_dark": "#1e2818",
			"speck": ["#12160f", "#34422b", "#4a5739", "#626845"],
			"path_edge": "#191410",
			"path_base": "#6a563f",
			"path_mid": "#856b4e",
			"path_lit": "#b09565",
			"accent": "#ff8a3d",
			"accent2": "#ffd27a",
			"sky": "#1b1622",
			"fog": "#2b2824",
			"sun": "#ffb878",
			"ambient": "#7a7468",
			"grass": "#6b7d4a",
			"grass_dark": "#3a492c",
			"rock": "#7f7568",
		},
	},
	"frost": {
		"id": "frost",
		"name": "冻苔回廊",
		"latin": "FROSTMOSS PASS",
		"diff": "险峻",
		"desc": "多弯近路 · 减速价值更高",
		"seed": 4271,
		"decor_seed": 5801,
		"waypoints": [[-1, 16], [5, 16], [5, 6], [12, 6], [12, 15], [19, 15], [19, 4], [27, 4], [29, 4]],
		"art": {
			"ground": ["#28454f", "#335561", "#3f6572", "#4c7885"],
			"ground_dark": "#14242b",
			"speck": ["#0e171d", "#304650", "#4b6670", "#718b90"],
			"path_edge": "#0f1d24",
			"path_base": "#55727a",
			"path_mid": "#749199",
			"path_lit": "#a8c4c4",
			"accent": "#7cd7d0",
			"accent2": "#d8f4ee",
			"sky": "#12202a",
			"fog": "#1c2b31",
			"sun": "#c4dcec",
			"ambient": "#748895",
			"grass": "#5d857d",
			"grass_dark": "#2f4c4c",
			"rock": "#7b8f92",
		},
	},
}


static func prepare(map_id: String):
	var def: Dictionary = MAP_DEFS[map_id]
	var m := MInfo.new()
	m.id = map_id
	m.def = def

	for wp in def["waypoints"]:
		m.points.append(Vector2(wp[0] * GData.TILE + GData.TILE * 0.5,
			wp[1] * GData.TILE + GData.TILE * 0.5))

	var total := 0.0
	for i in m.points.size() - 1:
		var a: Vector2 = m.points[i]
		var b: Vector2 = m.points[i + 1]
		var length := a.distance_to(b)
		m.segments.append({
			"a": a, "b": b, "len": length, "start": total, "end": total + length,
		})
		total += length
	m.total_len = total

	for seg in m.segments:
		var n: int = max(1, int(floor(seg["len"] / 6.0)))
		for i in n:
			var t := float(i) / float(n)
			m.samples.append((seg["a"] as Vector2).lerp(seg["b"], t))
	m.samples.append(m.points[m.points.size() - 1])

	var mid: Dictionary = m.point_at(m.total_len - 24.0)
	var mid_pos: Vector2 = mid["pos"]
	m.beacon = Vector2(roundi(mid_pos.x), roundi(mid_pos.y - 16.0))
	var entry: Dictionary = m.point_at(18.0)
	var entry_pos: Vector2 = entry["pos"]
	m.portal = Vector2(roundi(entry_pos.x), roundi(entry_pos.y))

	var base_cells: Array[Vector2i] = []
	for cy in GData.GH:
		for cx in GData.GW:
			var p := m.cell_center(cx, cy)
			if m.distance_to_path(p.x, p.y) >= 15.0:
				base_cells.append(Vector2i(cx, cy))

	var rng := EMath.Rng.new(int(def["decor_seed"]) ^ 0x50A1)
	var candidates: Array[Vector2i] = []
	for c in base_cells:
		if c.x < 2 or c.x > GData.GW - 3 or c.y < 2 or c.y > GData.GH - 2:
			continue
		var p := m.cell_center(c.x, c.y)
		var d := m.distance_to_path(p.x, p.y)
		if d >= 27.0 and d <= 92.0:
			candidates.append(c)
	for i in range(candidates.size() - 1, 0, -1):
		var j := int(rng.next() * float(i + 1))
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	for c in candidates:
		if m.props.size() >= 8:
			break
		var too_close := false
		for q in m.props:
			if absi(q["cx"] - c.x) <= 1 and absi(q["cy"] - c.y) <= 1:
				too_close = true
				break
		if too_close:
			continue
		var roll := rng.next()
		var type := ""
		if map_id == "frost":
			type = "crystal" if roll < 0.46 else ("stones" if roll < 0.76 else "bones")
		else:
			type = "tree" if roll < 0.48 else ("stones" if roll < 0.78 else "bones")
		m.props.append({"cx": c.x, "cy": c.y, "type": type, "seed": rng.next()})
		m.blocked[m.cell_key(c.x, c.y)] = true

	for c in base_cells:
		if not m.blocked.has(m.cell_key(c.x, c.y)):
			m.build_cells.append(c)
			m.buildable_set[m.cell_key(c.x, c.y)] = true
	return m
