extends RefCounted

# Pure slot logic: seeded reels, weighted symbols, 3x3 payline resolution.
# No nodes, no rendering — the smoke test drives this directly.

const SYMBOLS := ["blade", "bow", "shield", "steed", "orb", "crown"]
const DEFAULT_WEIGHTS := {
	"blade": 24, "bow": 22, "shield": 18,
	"steed": 16, "orb": 14, "crown": 6,
}
const PAIR_COINS := 1

# Every payline as (col, row) cells: 3 rows, 3 columns, 2 diagonals.
const LINES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
	[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)],
	[Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2)],
]

var seed_value := 1
var weights := {}
var rng := RandomNumberGenerator.new()
var last_grid: Array = []


func _init(p_seed: int = 1) -> void:
	seed_value = p_seed
	weights = DEFAULT_WEIGHTS.duplicate()
	rng.seed = p_seed


# Returns grid[row][col]: 3 rows, 3 columns of symbol names.
func spin() -> Array:
	var grid: Array = []
	for r in 3:
		var row: Array = []
		for c in 3:
			row.append(_pick())
		grid.append(row)
	last_grid = grid
	return grid


func total_weight() -> int:
	var total := 0
	for s in SYMBOLS:
		total += int(weights.get(s, 0))
	return total


func _pick() -> String:
	var total := total_weight()
	if total <= 0:
		return "blade"
	var roll := rng.randi_range(1, total)
	for s in SYMBOLS:
		roll -= int(weights.get(s, 0))
		if roll <= 0:
			return s
	return "blade"


# Pure resolution of a grid — used by the game and by the smoke test.
# triples: 3-in-a-line (crown is wild; 3 crowns = upgrade).
# pairs: exactly two identical non-crown symbols on a line = consolation coins.
static func resolve_grid(grid: Array) -> Dictionary:
	var lines: Array = []
	var triples: Array = []
	var pairs: Array = []
	var payout := 0
	for line in LINES:
		var cells: Array = []
		var counts := {}
		var crowns := 0
		for p in line:
			var s: String = grid[p.y][p.x]
			cells.append(p)
			if s == "crown":
				crowns += 1
			else:
				counts[s] = int(counts.get(s, 0)) + 1
		var triple_symbol := ""
		if crowns == 3:
			triple_symbol = "crown"
		else:
			for s in counts.keys():
				if int(counts[s]) + crowns >= 3:
					triple_symbol = s
					break
		if triple_symbol != "":
			var triple := {
				"kind": "triple", "symbol": triple_symbol, "cells": cells,
				"wild": crowns > 0 and triple_symbol != "crown",
			}
			triples.append(triple)
			lines.append(triple)
			continue
		var pair_symbol := ""
		for s in counts.keys():
			if int(counts[s]) >= 2:
				pair_symbol = s
				break
		if pair_symbol != "":
			var pair := {"kind": "pair", "symbol": pair_symbol, "cells": cells}
			pairs.append(pair)
			lines.append(pair)
			payout += PAIR_COINS
	return {
		"grid": grid, "lines": lines, "triples": triples, "pairs": pairs,
		"payout": payout, "triple_count": triples.size(), "pair_count": pairs.size(),
	}


# Shop: bend the odds (magnet) or recast a symbol face (resymbol).
func add_weight(symbol: String, amount: int) -> void:
	weights[symbol] = int(weights.get(symbol, 0)) + amount


func recast_symbol(from_symbol: String, to_symbol: String) -> int:
	var moved := int(weights.get(from_symbol, 0))
	weights[from_symbol] = 0
	weights[to_symbol] = int(weights.get(to_symbol, 0)) + moved
	return moved
