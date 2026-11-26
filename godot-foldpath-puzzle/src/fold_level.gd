class_name FoldLevel
extends RefCounted

## Level schema, node world transforms, screen-space fold links and the
## walkable path graph. Levels are pure JSON in res://levels.

const LEVEL_DIR := "res://levels"
const KINDS := ["start", "path", "goal"]


static func load_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		push_error("Foldpath: cannot open %s" % LEVEL_DIR)
		return out
	var files := dir.get_files()
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(LEVEL_DIR + "/" + file)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			parsed["_file"] = file
			out.append(parsed)
		else:
			push_error("Foldpath: bad JSON in %s" % file)
	out.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return out


static func validate(level: Dictionary) -> String:
	for key in ["id", "name", "objective", "camera", "platforms", "nodes", "edges", "start", "goal"]:
		if not level.has(key):
			return "missing key " + key
	if not (level["platforms"] is Array) or (level["platforms"] as Array).is_empty():
		return "platforms must be a non-empty array"
	var pids := {}
	var platforms := {}
	for p in level["platforms"]:
		if not (p is Dictionary):
			return "platform entry is not an object"
		var pid := String(p.get("id", ""))
		if pid == "":
			return "platform without id"
		if pids.has(pid):
			return "duplicate platform id " + pid
		pids[pid] = true
		platforms[pid] = p
		if not (p.get("pivot") is Array) or (p["pivot"] as Array).size() != 3:
			return "platform pivot needs 3 numbers: " + pid
		if String(p.get("shape", "")) == "":
			return "platform shape missing: " + pid
		if not (p.get("size") is Array) or (p["size"] as Array).size() != 3:
			return "platform size needs 3 numbers: " + pid
		if bool(p.get("rotatable", false)) and float(p.get("step", 15.0)) <= 0.0:
			return "rotatable platform needs a positive step: " + pid
	var nodes := {}
	for n in level["nodes"]:
		if not (n is Dictionary):
			return "node entry is not an object"
		var nid := String(n.get("id", ""))
		if nid == "":
			return "node without id"
		if nodes.has(nid):
			return "duplicate node id " + nid
		nodes[nid] = n
		var pid := String(n.get("platform", ""))
		if not pids.has(pid):
			return "node %s references unknown platform %s" % [nid, pid]
		if not (n.get("pos") is Array) or (n["pos"] as Array).size() != 3:
			return "node pos needs 3 numbers: " + nid
		if not KINDS.has(String(n.get("kind", "path"))):
			return "node kind invalid: " + nid
	if not nodes.has(String(level["start"])):
		return "start node missing"
	if not nodes.has(String(level["goal"])):
		return "goal node missing"
	if String(nodes[String(level["start"])].get("kind", "")) != "start":
		return "start node kind should be start"
	if String(nodes[String(level["goal"])].get("kind", "")) != "goal":
		return "goal node kind should be goal"
	var seen := {}
	for e in level["edges"]:
		if not (e is Array) or (e as Array).size() != 2:
			return "edge must be [a, b]"
		var a := String(e[0])
		var b := String(e[1])
		if not nodes.has(a) or not nodes.has(b):
			return "edge references unknown node: %s-%s" % [a, b]
		if a == b:
			return "self edge on " + a
		if String(nodes[a]["platform"]) != String(nodes[b]["platform"]):
			return "edge must stay inside one platform: %s-%s" % [a, b]
		var key := a + "|" + b
		if b < a:
			key = b + "|" + a
		if seen.has(key):
			return "duplicate edge " + key
		seen[key] = true
	var folds := {}
	for pair in level.get("fold_pairs", []):
		if not (pair is Array) or (pair as Array).size() != 2:
			return "fold_pairs entries must be [a, b]"
		var fa := String(pair[0])
		var fb := String(pair[1])
		if not nodes.has(fa) or not nodes.has(fb):
			return "fold pair references unknown node: %s-%s" % [fa, fb]
		if String(nodes[fa]["platform"]) == String(nodes[fb]["platform"]):
			return "fold pair must cross platforms: %s-%s" % [fa, fb]
		if String(nodes[fa].get("kind", "path")) != "path" or String(nodes[fb].get("kind", "path")) != "path":
			return "fold pairs only join path endpoints: %s-%s" % [fa, fb]
		var key := fa + "|" + fb
		if fb < fa:
			key = fb + "|" + fa
		if folds.has(key):
			return "duplicate fold pair " + key
		folds[key] = true
	var camera: Dictionary = level["camera"]
	if not (camera.get("focus") is Array) or (camera["focus"] as Array).size() != 3:
		return "camera focus needs 3 numbers"
	if float(camera.get("size", 0.0)) <= 0.0:
		return "camera size must be positive"
	return ""


static func platform_map(level: Dictionary) -> Dictionary:
	var out := {}
	for p in level["platforms"]:
		out[String(p["id"])] = p
	return out


static func node_map(level: Dictionary) -> Dictionary:
	var out := {}
	for n in level["nodes"]:
		out[String(n["id"])] = n
	return out


static func initial_angles(level: Dictionary) -> Dictionary:
	var out := {}
	for p in level["platforms"]:
		out[String(p["id"])] = float(p.get("initial", 0.0))
	return out


static func node_world(level: Dictionary, angles: Dictionary, nid: String) -> Vector3:
	var nodes := node_map(level)
	if not nodes.has(nid):
		return Vector3.ZERO
	var n: Dictionary = nodes[nid]
	var platforms := platform_map(level)
	var p: Dictionary = platforms[String(n["platform"])]
	var local := FoldMath.vec3(n["pos"])
	var angle := float(angles.get(String(p["id"]), p.get("initial", 0.0)))
	return FoldMath.vec3(p["pivot"]) + FoldMath.rotate_y(local, angle)


static func all_world(level: Dictionary, angles: Dictionary) -> Dictionary:
	var out := {}
	var platforms := platform_map(level)
	var defaults := initial_angles(level)
	for n in level["nodes"]:
		var nid := String(n["id"])
		var p: Dictionary = platforms[String(n["platform"])]
		var angle := float(angles.get(String(p["id"]), defaults.get(String(p["id"]), 0.0)))
		out[nid] = FoldMath.vec3(p["pivot"]) + FoldMath.rotate_y(FoldMath.vec3(n["pos"]), angle)
	return out


static func edge_ends(level: Dictionary) -> Array:
	var out := []
	for e in level["edges"]:
		out.append([String(e[0]), String(e[1])])
	return out


static func degree_map(level: Dictionary) -> Dictionary:
	var out := {}
	for n in level["nodes"]:
		out[String(n["id"])] = 0
	for e in level["edges"]:
		out[String(e[0])] = int(out[String(e[0])]) + 1
		out[String(e[1])] = int(out[String(e[1])]) + 1
	return out


## Loose path ends on different platforms are the only nodes allowed to fold
## across depths. When a level lists explicit fold_pairs (the intended seams),
## only those endpoints can pair; the screen-space check still decides whether
## a seam is open right now.
static func link_candidates(level: Dictionary) -> Array[Dictionary]:
	var degrees := degree_map(level)
	var nodes := node_map(level)
	var out: Array[Dictionary] = []
	var seen := {}
	if level.has("fold_pairs"):
		for pair in level["fold_pairs"]:
			for raw in pair:
				var nid := String(raw)
				if seen.has(nid):
					continue
				seen[nid] = true
				if int(degrees.get(nid, 0)) != 1:
					continue
				if String(nodes[nid].get("kind", "path")) != "path":
					continue
				out.append({"id": nid, "platform": String(nodes[nid]["platform"])})
		return out
	for n in level["nodes"]:
		var nid := String(n["id"])
		if int(degrees.get(nid, 0)) != 1:
			continue
		if String(n.get("kind", "path")) != "path":
			continue
		out.append({"id": nid, "platform": String(n["platform"])})
	return out


static func active_links(level: Dictionary, angles: Dictionary, focus: Vector3, ortho_size: float) -> Array[Dictionary]:
	var world := all_world(level, angles)
	var candidates := link_candidates(level)
	var nodes := node_map(level)
	var pair_ids: Array = []
	if level.has("fold_pairs"):
		pair_ids = level["fold_pairs"]
	else:
		for i in candidates.size():
			for j in range(i + 1, candidates.size()):
				pair_ids.append([candidates[i]["id"], candidates[j]["id"]])
	var pairs: Array[Dictionary] = []
	var link_px := float(level.get("link_px", 26.0))
	var min_depth := float(level.get("link_depth", 0.35))
	for pair in pair_ids:
		var a := String(pair[0])
		var b := String(pair[1])
		if not world.has(a) or not world.has(b):
			continue
		if String(nodes[a]["platform"]) == String(nodes[b]["platform"]):
			continue
		var pa: Vector3 = world[a]
		var pb: Vector3 = world[b]
		var sa := FoldMath.project(pa, focus, ortho_size)
		var sb := FoldMath.project(pb, focus, ortho_size)
		var dist := sa.distance_to(sb)
		var depth := absf(FoldMath.project_depth(pa, focus) - FoldMath.project_depth(pb, focus))
		if dist <= link_px and depth >= min_depth:
			pairs.append({
				"a": a, "b": b, "pa": pa, "pb": pb,
				"sa": sa, "sb": sb, "dist": dist, "depth": depth
			})
	pairs.sort_custom(func(x, y): return float(x["dist"]) < float(y["dist"]))
	var used := {}
	var out: Array[Dictionary] = []
	for pair in pairs:
		if used.has(String(pair["a"])) or used.has(String(pair["b"])):
			continue
		used[String(pair["a"])] = true
		used[String(pair["b"])] = true
		out.append(pair)
	out.sort_custom(func(x, y): return String(x["a"]) < String(y["a"]))
	return out


static func adjacency(level: Dictionary, links: Array) -> Dictionary:
	var adj := {}
	for n in level["nodes"]:
		adj[String(n["id"])] = []
	for e in level["edges"]:
		var a := String(e[0])
		var b := String(e[1])
		(adj[a] as Array).append(b)
		(adj[b] as Array).append(a)
	for link in links:
		var a := String(link["a"])
		var b := String(link["b"])
		(adj[a] as Array).append(b)
		(adj[b] as Array).append(a)
	return adj


static func find_route(level: Dictionary, from_id: String, to_id: String, links: Array) -> Array[String]:
	var out: Array[String] = []
	if from_id == to_id:
		return out
	var adj := adjacency(level, links)
	if not adj.has(from_id) or not adj.has(to_id):
		return out
	var parent := {from_id: ""}
	var queue: Array[String] = [from_id]
	var head := 0
	while head < queue.size():
		var cur: String = queue[head]
		head += 1
		for next in adj[cur]:
			var nid := String(next)
			if parent.has(nid):
				continue
			parent[nid] = cur
			if nid == to_id:
				var chain: Array[String] = [nid]
				var walk := nid
				while String(parent[walk]) != "":
					walk = String(parent[walk])
					chain.push_front(walk)
				return chain
			queue.append(nid)
	return out


static func link_for(links: Array, a: String, b: String) -> Dictionary:
	for link in links:
		if (String(link["a"]) == a and String(link["b"]) == b) or (String(link["a"]) == b and String(link["b"]) == a):
			return link
	return {}


static func nodes_on_platform(level: Dictionary, pid: String) -> Array[String]:
	var out: Array[String] = []
	for n in level["nodes"]:
		if String(n["platform"]) == pid:
			out.append(String(n["id"]))
	return out


static func platform_of(level: Dictionary, nid: String) -> String:
	var nodes := node_map(level)
	if not nodes.has(nid):
		return ""
	return String(nodes[nid]["platform"])


## A hint may focus a platform, a node, or a link ("a+b").
static func hint_focus_ids(level: Dictionary, focus: String) -> Array[String]:
	if focus.contains("+"):
		var ids: Array[String] = []
		for part in focus.split("+"):
			ids.append(String(part))
		return ids
	var platforms := platform_map(level)
	if platforms.has(focus):
		return nodes_on_platform(level, focus)
	return [focus]
