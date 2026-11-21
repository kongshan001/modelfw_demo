class_name CardDB
extends RefCounted

# 卡牌/将军/牌库的数据入口。所有卡面数值与套牌都在 res://data/cards.json。

const DATA_PATH := "res://data/cards.json"

var raw: Dictionary = {}
var cards: Dictionary = {}
var generals: Dictionary = {}
var decks: Dictionary = {}


func _init(path := DATA_PATH) -> void:
	load_from(path)


func load_from(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CardDB: cannot open %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CardDB: invalid JSON in %s" % path)
		return false
	raw = parsed
	cards.clear()
	for card in raw.get("cards", []):
		cards[card["id"]] = card
	generals = raw.get("generals", {})
	decks = raw.get("decks", {})
	return true


func card(card_id: String) -> Dictionary:
	return cards.get(card_id, {})


func general(faction: String) -> Dictionary:
	return generals.get(faction, {})


func deck(deck_id: String) -> Array:
	return decks.get(deck_id, [])


func faction_label(faction: String) -> String:
	match faction:
		"f1": return "晨光"
		"f2": return "风间"
		_: return "中立"


func card_frame_path(card: Dictionary) -> String:
	var faction: String = card.get("faction", "neutral")
	var kind: String = card.get("type", "unit")
	return "res://assets/duelyst_cc0/card_backgrounds/%s_%s.png" % [faction, kind]
