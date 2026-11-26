class_name HueSim
extends RefCounted

# Pure puzzle rule engine for HueRoll.
# No nodes, no rendering, no audio: the headless smoke suite drives this class directly,
# and the 3D scene only visualises its state.
#
# Rules (clean-room adaptation, see docs/TECH.md):
#   * The cube occupies one cell. Rolling moves it one cell and turns it 90 degrees.
#   * A paint pool repaints the face that is on the bottom after the roll.
#     base + different base -> one secondary colour; wet paint over dried secondary
#     simply repaints (forgiving, lets the player fix a face without resetting).
#   * Landing on an open target stamps the bottom colour (blank does nothing).
#     A correct stamp locks that tile; unlocked stamps may be repainted later.
#   * Win when every target tile is locked with its required colour.

const FACE_DIRS := ["up", "down", "north", "south", "east", "west"]
const DIR_VECTORS := {
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
	"south": Vector2i(0, 1),
	"north": Vector2i(0, -1),
}
const BASE_COLORS := ["red", "yellow", "blue"]
const MIX_TABLE := {
	"blue+red": "purple",
	"blue+yellow": "green",
	"red+yellow": "orange",
}
const WALKABLE_CHARS := ".SrybRYBOGP"

var level_id := ""
var level_name := ""
var subtitle := ""
var hint := ""
var theme: Dictionary = {}
var par := 0
var solution := ""
var width := 0
var height := 0

var walkable: Dictionary = {}      # Vector2i -> true
var props: Dictionary = {}         # Vector2i -> true (solid decorative blocks)
var pools: Dictionary = {}         # Vector2i -> colour id
var target_req: Dictionary = {}    # Vector2i -> required colour id
var start_pos := Vector2i.ZERO
var start_faces: Dictionary = {}

var pos := Vector2i.ZERO
var faces: Dictionary = {}         # world direction -> colour id
var stamps: Dictionary = {}        # Vector2i -> stamped colour id
var locked: Dictionary = {}        # Vector2i -> true once a correct stamp lands
var moves := 0
var won := false
var history: Array[Dictionary] = []

var _initial: Dictionary = {}
var _target_order: Array[Vector2i] = []


func load_level(data: Dictionary) -> bool:
	level_id = str(data.get("id", ""))
	level_name = str(data.get("name", ""))
	subtitle = str(data.get("subtitle", ""))
	hint = str(data.get("hint", ""))
	theme = data.get("theme", {})
	par = int(data.get("par", 0))
	solution = str(data.get("solution", ""))
	walkable.clear()
	props.clear()
	pools.clear()
	target_req.clear()
	start_pos = Vector2i(-999, -999)
	start_faces = {}
	width = 0
	height = 0

	var board: Array = data.get("board", [])
	if board.is_empty():
		push_error("HueSim: level %s has an empty board" % level_id)
		return false
	height = board.size()
	for row in board:
		width = maxi(width, str(row).length())

	var pool_map := {"r": "red", "y": "yellow", "b": "blue"}
	var target_map := {
		"R": "red", "Y": "yellow", "B": "blue",
		"O": "orange", "G": "green", "P": "purple",
	}
	for z in height:
		var row := str(board[z])
		for x in row.length():
			var ch := row[x]
			var cell := Vector2i(x, z)
			if ch == "#":
				props[cell] = true
				continue
			if ch == " " or ch == "":
				continue
			if ch == "S":
				if start_pos.x != -999:
					push_error("HueSim: level %s has more than one start" % level_id)
					return false
				start_pos = cell
				walkable[cell] = true
				continue
			if WALKABLE_CHARS.contains(ch):
				walkable[cell] = true
			if pool_map.has(ch):
				pools[cell] = pool_map[ch]
			if target_map.has(ch):
				target_req[cell] = target_map[ch]

	if start_pos.x == -999 or not walkable.has(start_pos):
		push_error("HueSim: level %s has no usable start" % level_id)
		return false
	for cell in target_req:
		if pools.has(cell):
			push_error("HueSim: level %s has a pool on a target at %s" % [level_id, cell])
			return false

	if data.has("start_faces"):
		var sf: Dictionary = data["start_faces"]
		for dir in FACE_DIRS:
			start_faces[dir] = str(sf.get(dir, "blank"))
	else:
		for dir in FACE_DIRS:
			start_faces[dir] = "blank"

	_target_order.clear()
	for cell in target_req:
		_target_order.append(cell)
	_target_order.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	reset()
	return true


func reset() -> void:
	pos = start_pos
	faces = start_faces.duplicate()
	stamps.clear()
	locked.clear()
	moves = 0
	won = false
	history.clear()
	_initial = _snapshot()


func _snapshot() -> Dictionary:
	return {
		"pos": pos,
		"faces": faces.duplicate(),
		"stamps": stamps.duplicate(),
		"locked": locked.duplicate(),
		"moves": moves,
		"won": won,
	}


func _restore(snap: Dictionary) -> void:
	pos = snap.pos
	faces = snap.faces.duplicate()
	stamps = snap.stamps.duplicate()
	locked = snap.locked.duplicate()
	moves = int(snap.moves)
	won = bool(snap.won)


func can_roll(dir_name: String) -> bool:
	if won or not DIR_VECTORS.has(dir_name):
		return false
	return walkable.has(pos + DIR_VECTORS[dir_name])


func roll(dir_name: String) -> Dictionary:
	var out := {
		"ok": false, "painted": "", "stamp": "", "stamp_result": "",
		"won": won, "blocked": "", "target": "",
	}
	if won:
		out["blocked"] = "won"
		return out
	if not DIR_VECTORS.has(dir_name):
		out["blocked"] = "dir"
		return out
	var step: Vector2i = DIR_VECTORS[dir_name]
	var next := pos + step
	if not walkable.has(next):
		out["blocked"] = "wall"
		return out

	history.append(_snapshot())
	_rotate_faces(dir_name)
	pos = next
	moves += 1

	if pools.has(pos):
		var before: String = faces["down"]
		faces["down"] = mix_color(before, str(pools[pos]))
		out["painted"] = faces["down"]

	if target_req.has(pos) and not locked.has(pos):
		out["target"] = str(target_req[pos])
		var bottom: String = faces["down"]
		if bottom != "blank":
			stamps[pos] = bottom
			out["stamp"] = bottom
			if bottom == str(target_req[pos]):
				locked[pos] = true
				out["stamp_result"] = "ok"
			else:
				out["stamp_result"] = "bad"

	won = _check_win()
	out["ok"] = true
	out["won"] = won
	out["pos"] = pos
	out["moves"] = moves
	out["locked"] = locked.has(pos)
	return out


func _rotate_faces(dir_name: String) -> void:
	var old := faces.duplicate()
	match dir_name:
		"east":
			faces["up"] = old["west"]
			faces["east"] = old["up"]
			faces["down"] = old["east"]
			faces["west"] = old["down"]
		"west":
			faces["up"] = old["east"]
			faces["west"] = old["up"]
			faces["down"] = old["west"]
			faces["east"] = old["down"]
		"south":
			faces["up"] = old["north"]
			faces["south"] = old["up"]
			faces["down"] = old["south"]
			faces["north"] = old["down"]
		"north":
			faces["up"] = old["south"]
			faces["north"] = old["up"]
			faces["down"] = old["north"]
			faces["south"] = old["down"]


static func mix_color(a: String, b: String) -> String:
	if a == blank_color():
		return b
	if b == blank_color():
		return a
	if a == b:
		return a
	var pair := [a, b]
	pair.sort()
	var key := "%s+%s" % [pair[0], pair[1]]
	if MIX_TABLE.has(key):
		return str(MIX_TABLE[key])
	# Fresh base paint over a dried secondary/muddy layer simply covers it.
	return b


static func blank_color() -> String:
	return "blank"


func _check_win() -> bool:
	if target_req.is_empty():
		return false
	for cell in target_req:
		if not locked.has(cell):
			return false
	return true


func undo() -> bool:
	if history.is_empty():
		return false
	_restore(history.pop_back())
	return true


func target_color(cell: Vector2i) -> String:
	return str(target_req.get(cell, ""))


func stamp_color(cell: Vector2i) -> String:
	return str(stamps.get(cell, "blank"))


func is_locked(cell: Vector2i) -> bool:
	return locked.has(cell)


func target_progress() -> Array:
	return [locked.size(), target_req.size()]


func targets_sorted() -> Array[Vector2i]:
	return _target_order.duplicate()


func stats() -> Dictionary:
	return {
		"moves": moves,
		"par": par,
		"won": won,
		"pos": pos,
		"faces": faces.duplicate(),
		"stamps": stamps.duplicate(),
		"locked": locked.duplicate(),
		"progress": target_progress(),
	}


func stars() -> int:
	if not won:
		return 0
	if par <= 0:
		return 3
	if moves <= par:
		return 3
	if moves <= int(ceil(par * 1.5)):
		return 2
	return 1
