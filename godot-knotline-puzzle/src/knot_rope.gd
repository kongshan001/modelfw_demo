class_name KnotRope
extends RefCounted

## Core one-stroke rope model, independent of rendering.
##
## The rope is one continuous polyline: an anchored start plus user control
## points. Two approximations are deliberate and documented in docs/TECH.md:
##   * segments that would cut through a pillar are replaced by an arc around
##     it (the rope cannot pass through posts), which also makes winding easy
##     to read;
##   * a "knot" is scored as signed winding around pillars plus planar (XZ)
##     self-crossings whose two strands differ in height (over/under), not as
##     a full knot invariant.

const TAU_F := TAU

var anchor := Vector3.ZERO
var points := PackedVector3Array()
var _user := PackedByteArray()
var obstacles: Array[Dictionary] = []
var ground_y := 0.0
var bounds_radius := 4.6
var rope_radius := 0.045
var clearance := 0.055
var min_step := 0.075
var max_points := 520
var max_jump := 2.8
var wrap_band := 0.58
var crossing_min_delta := 0.12
var crossing_min_separation := 0.45


func setup(start_point: Vector3, obstacle_list: Array = [], options: Dictionary = {}) -> void:
	anchor = start_point
	obstacles.clear()
	for o in obstacle_list:
		obstacles.append(o)
	if options.has("ground_y"):
		ground_y = float(options["ground_y"])
	if options.has("bounds_radius"):
		bounds_radius = float(options["bounds_radius"])
	if options.has("rope_radius"):
		rope_radius = float(options["rope_radius"])
	if options.has("clearance"):
		clearance = float(options["clearance"])
	if options.has("wrap_band"):
		wrap_band = float(options["wrap_band"])
	if options.has("crossing_min_delta"):
		crossing_min_delta = float(options["crossing_min_delta"])
	reset()


func reset() -> void:
	points = PackedVector3Array([anchor])
	_user = PackedByteArray([1])


func is_empty() -> bool:
	return points.size() <= 1


func last_point() -> Vector3:
	if points.is_empty():
		return anchor
	return points[points.size() - 1]


func user_count() -> int:
	var n := 0
	for v in _user:
		if v == 1:
			n += 1
	return n


func step_count() -> int:
	return maxi(0, user_count() - 1)


func length() -> float:
	return KnotTube.polyline_length(points)


func sample(subdivisions: int = 3) -> PackedVector3Array:
	return KnotTube.sample_catmull(points, subdivisions)


func can_add() -> bool:
	return points.size() < max_points


## Adds one user control point. Returns the number of raw points inserted
## (arc points around pillars included); 0 means the move was ignored.
func add_point(raw: Vector3) -> int:
	if points.is_empty():
		reset()
	if points.size() >= max_points:
		return 0
	var target := _sanitize(raw)
	var last := last_point()
	var delta := target - last
	var dist := delta.length()
	if dist < min_step:
		return 0
	if dist > max_jump:
		target = last + delta / dist * max_jump
		dist = max_jump
	var inserted := 0
	var cursor := last
	for obs in obstacles:
		if points.size() + inserted >= max_points - 1:
			break
		var arcs := _arc_around(cursor, target, obs)
		for p in arcs:
			_push(p, 0)
			inserted += 1
			cursor = p
	_push(target, 1)
	return inserted + 1


func _push(p: Vector3, kind: int) -> void:
	if not points.is_empty() and points[points.size() - 1].distance_squared_to(p) < 1e-8:
		return
	points.append(p)
	_user.append(kind)


func _sanitize(raw: Vector3) -> Vector3:
	var p := raw
	p.x = clampf(p.x, -bounds_radius, bounds_radius)
	p.z = clampf(p.z, -bounds_radius, bounds_radius)
	p.y = clampf(p.y, ground_y + rope_radius + 0.012, 3.8)
	for obs in obstacles:
		var c: Vector2 = obs["center"]
		var r: float = float(obs["radius"]) + rope_radius + clearance
		var y0: float = float(obs.get("y0", 0.0))
		var y1: float = float(obs.get("y1", 1.5))
		if p.y < y0 - 0.05 or p.y > y1 + 0.05:
			continue
		var off := Vector2(p.x, p.z) - c
		if off.length() < r:
			if off.length_squared() < 1e-8:
				off = Vector2.RIGHT
			var q := c + off.normalized() * (r + 0.002)
			p.x = q.x
			p.z = q.y
	return p


func _arc_around(a: Vector3, b: Vector3, obs: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c: Vector2 = obs["center"]
	var r: float = float(obs["radius"]) + rope_radius + clearance
	var y0: float = float(obs.get("y0", 0.0))
	var y1: float = float(obs.get("y1", 1.5))
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var d := b2 - a2
	var f := a2 - c
	var aa := d.dot(d)
	if aa < 1e-8:
		return out
	var bb := 2.0 * f.dot(d)
	var cc := f.dot(f) - r * r
	var disc := bb * bb - 4.0 * aa * cc
	if disc <= 0.0:
		return out
	var sq := sqrt(disc)
	var t1 := (-bb - sq) / (2.0 * aa)
	var t2 := (-bb + sq) / (2.0 * aa)
	if t2 <= 0.02 or t1 >= 0.98:
		return out
	var te := clampf(t1, 0.0, 1.0)
	var tx := clampf(t2, 0.0, 1.0)
	var h_in := lerpf(a.y, b.y, te)
	var h_out := lerpf(a.y, b.y, tx)
	if minf(h_in, h_out) > y1 + 0.05:
		return out
	if maxf(h_in, h_out) < y0 - 0.04:
		return out
	var entry := a2 + d * te
	var exit := b2 - d * (1.0 - tx)
	var ang_a := atan2(entry.y - c.y, entry.x - c.x)
	var ang_b := atan2(exit.y - c.y, exit.x - c.x)
	var sweep := wrapf(ang_b - ang_a, -PI, PI)
	if absf(sweep) < 0.04:
		return out
	var steps := maxi(2, int(ceil(absf(sweep) / deg_to_rad(15.0))))
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var ang := ang_a + sweep * t
		var p := Vector3(c.x + cos(ang) * r, lerpf(h_in, h_out, t), c.y + sin(ang) * r)
		if p.distance_to(a) > 0.02 and p.distance_to(b) > 0.02:
			out.append(p)
	return out


## Removes the newest user control point and everything generated after the
## previous one. Returns false when only the anchored start remains.
func undo_last_control() -> bool:
	var last_user := _last_user_index()
	if last_user <= 0:
		return false
	var prev_user := _previous_user_index(last_user)
	var keep := prev_user + 1
	if keep >= points.size():
		return false
	points = points.slice(0, keep)
	_user = _user.slice(0, keep)
	return true


func undo_info() -> Dictionary:
	var last_user := _last_user_index()
	if last_user <= 0:
		return {}
	var prev_user := _previous_user_index(last_user)
	return {
		"last_index": last_user,
		"prev_index": prev_user,
		"last_point": points[last_user],
		"target_point": points[prev_user],
		"keep_count": prev_user + 1,
	}


func _last_user_index() -> int:
	for i in range(_user.size() - 1, -1, -1):
		if _user[i] == 1:
			return i
	return -1


func _previous_user_index(last_idx: int) -> int:
	for i in range(last_idx - 1, -1, -1):
		if _user[i] == 1:
			return i
	return 0


func analyze(pillars: Array, subdivisions: int = 3) -> Dictionary:
	var samples := decimate(sample(subdivisions), 420)
	var winding := compute_winding(samples, pillars)
	var crossings := find_crossings(samples, crossing_min_delta, crossing_min_separation)
	var resolved := 0
	var flat := 0
	for c in crossings:
		if c["resolved"]:
			resolved += 1
		else:
			flat += 1
	return {
		"samples": samples,
		"winding": winding,
		"crossings": crossings,
		"resolved_crossings": resolved,
		"flat_crossings": flat,
		"steps": step_count(),
		"length": length(),
	}


## Keeps metric work bounded while the visual tube keeps full smoothing.
static func decimate(points: PackedVector3Array, max_count: int) -> PackedVector3Array:
	if points.size() <= max_count or max_count < 3:
		return points
	var out := PackedVector3Array()
	out.append(points[0])
	var step := float(points.size() - 1) / float(max_count - 1)
	for i in range(1, max_count - 1):
		var idx := int(round(float(i) * step))
		if idx > 0 and idx < points.size() - 1:
			out.append(points[idx])
	out.append(points[points.size() - 1])
	return out


func compute_winding(samples: PackedVector3Array, pillars: Array) -> Dictionary:
	var out := {}
	for pillar in pillars:
		var center: Vector2 = _pillar_center(pillar)
		var radius: float = float(pillar.get("radius", 0.25))
		var height: float = float(pillar.get("height", 1.5))
		var band := radius + wrap_band
		# Only contiguous passes near the pillar count. Taking the strongest
		# run (instead of a signed sum) means leaving the pillar or swinging
		# the tail away cannot erase a completed loop.
		var runs: Array[float] = []
		var total := 0.0
		var prev_angle := 0.0
		var prev_ok := false
		for p in samples:
			var ok := p.y >= -0.03 and p.y <= height + 0.16
			var off := Vector2(p.x, p.z) - center
			var dist := off.length()
			ok = ok and dist <= band and dist >= 0.02
			if ok:
				var ang := atan2(off.y, off.x)
				if prev_ok:
					var d := wrapf(ang - prev_angle, -PI, PI)
					if absf(d) < 1.1:
						total += d
				prev_angle = ang
				prev_ok = true
			else:
				if prev_ok:
					runs.append(total)
				total = 0.0
				prev_ok = false
		if prev_ok:
			runs.append(total)
		var best := 0.0
		for r in runs:
			if absf(r) > absf(best):
				best = r
		var turns := best / TAU_F
		out[String(pillar.get("id", "?"))] = {
			"turns": turns,
			"angle_deg": absf(turns) * 360.0,
			"signed_deg": turns * 360.0,
		}
	return out


static func _pillar_center(pillar: Dictionary) -> Vector2:
	if pillar.has("center"):
		return pillar["center"]
	var pos = pillar.get("pos", [0.0, 0.0])
	if pos is Vector2:
		return pos
	return Vector2(float(pos[0]), float(pos[1]))


## Planar self-crossing test. The XZ plane is the diorama floor, so "over" is
## the strand with the greater height at the intersection. Crossings closer
## than crossing_min_delta vertically are recorded but flagged unresolved.
static func find_crossings(samples: PackedVector3Array, min_delta: float = 0.12, min_separation: float = 0.45) -> Array:
	var out: Array = []
	var n := samples.size()
	if n < 4:
		return out
	var prefix := PackedFloat32Array()
	prefix.resize(n)
	prefix[0] = 0.0
	for i in range(1, n):
		prefix[i] = prefix[i - 1] + samples[i].distance_to(samples[i - 1])
	var raw: Array = []
	for i in range(n - 1):
		var a := samples[i]
		var b := samples[i + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var r2 := b2 - a2
		if r2.length_squared() < 1e-10:
			continue
		for j in range(i + 2, n - 1):
			if j - i < 2:
				continue
			if prefix[j] - prefix[i] < min_separation:
				continue
			var c := samples[j]
			var d := samples[j + 1]
			var c2 := Vector2(c.x, c.z)
			var d2 := Vector2(d.x, d.z)
			if maxf(a2.x, b2.x) < minf(c2.x, d2.x) - 0.0001:
				continue
			if maxf(c2.x, d2.x) < minf(a2.x, b2.x) - 0.0001:
				continue
			if maxf(a2.y, b2.y) < minf(c2.y, d2.y) - 0.0001:
				continue
			if maxf(c2.y, d2.y) < minf(a2.y, b2.y) - 0.0001:
				continue
			var s2 := d2 - c2
			if s2.length_squared() < 1e-10:
				continue
			var den := r2.cross(s2)
			if absf(den) < 1e-7:
				continue
			var qp := c2 - a2
			var t := qp.cross(s2) / den
			var u := qp.cross(r2) / den
			if t < 0.03 or t > 0.97 or u < 0.03 or u > 0.97:
				continue
			var ya := lerpf(a.y, b.y, t)
			var yc := lerpf(c.y, d.y, u)
			var delta := absf(ya - yc)
			var over_i := i if ya >= yc else j
			var under_i := j if ya >= yc else i
			var y_hi := maxf(ya, yc)
			var y_lo := minf(ya, yc)
			var xz := a2 + r2 * t
			raw.append({
				"pos": Vector3(xz.x, (y_hi + y_lo) * 0.5, xz.y),
				"above": Vector3(xz.x, y_hi, xz.y),
				"below": Vector3(xz.x, y_lo, xz.y),
				"delta": delta,
				"resolved": delta >= min_delta,
				"over_seg": over_i,
				"under_seg": under_i,
				"i": i,
				"j": j,
			})
	# Merge the many sampled pairs that describe the same visual crossing.
	for cand in raw:
		var merged := false
		for existing in out:
			var ep: Vector3 = existing["pos"]
			var cp: Vector3 = cand["pos"]
			if Vector2(ep.x - cp.x, ep.z - cp.z).length() < 0.16:
				if float(cand["delta"]) > float(existing["delta"]):
					existing["above"] = cand["above"]
					existing["below"] = cand["below"]
					existing["delta"] = cand["delta"]
					existing["resolved"] = cand["resolved"]
					existing["over_seg"] = cand["over_seg"]
					existing["under_seg"] = cand["under_seg"]
					existing["i"] = cand["i"]
					existing["j"] = cand["j"]
				merged = true
				break
		if not merged:
			out.append(cand)
	out.sort_custom(func(x, y): return int(x["i"]) < int(y["i"]))
	return out
