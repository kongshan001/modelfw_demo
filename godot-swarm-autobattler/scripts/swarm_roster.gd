class_name SwarmRoster
extends RefCounted

## 阵容码：原创的 base64(JSON) 格式。
## SWF1:<base64>  {v, name, level, greed, flood, cards:[{id,star}]}
## 只包含编队/等级/贪婪潮/洪流开关，不包含英雄血量与金币。

const PREFIX := "SWF1:"
const VERSION := 1
const MAX_BOARD := 7

const Cards = preload("res://scripts/swarm_cards.gd")


static func encode(cards: Array, level: int, greed: int, flood: bool) -> String:
	var clean: Array = []
	for entry in cards:
		var card := Cards.get_card(String(entry.get("id", "")))
		if card.is_empty():
			continue
		var star := 2 if int(entry.get("star", 1)) >= 2 else 1
		clean.append({"id": card["id"], "star": star})
	var payload := {
		"v": VERSION,
		"name": "SWARMFORGE",
		"level": clampi(level, 2, Cards.MAX_LEVEL),
		"greed": clampi(greed, 0, Cards.MAX_GREED),
		"flood": bool(flood),
		"cards": clean,
	}
	var json := JSON.stringify(payload)
	return PREFIX + Marshalls.utf8_to_base64(json)


static func decode(code: String) -> Dictionary:
	var text := code.strip_edges()
	if text.is_empty():
		return {"ok": false, "msg": "阵容码为空"}
	if not text.begins_with(PREFIX):
		return {"ok": false, "msg": "缺少 SWF1: 前缀"}
	var b64 := text.substr(PREFIX.length())
	if b64.is_empty():
		return {"ok": false, "msg": "阵容码没有内容"}
	if not _valid_base64(b64):
		return {"ok": false, "msg": "base64 字符/长度无效"}
	var json := Marshalls.base64_to_utf8(b64)
	if json.is_empty():
		return {"ok": false, "msg": "base64 解码失败"}
	var parsed = JSON.parse_string(json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "msg": "JSON 结构无效"}
	var data: Dictionary = parsed
	if int(data.get("v", 0)) != VERSION:
		return {"ok": false, "msg": "阵容码版本不支持"}
	var raw_cards = data.get("cards", [])
	if typeof(raw_cards) != TYPE_ARRAY:
		return {"ok": false, "msg": "cards 字段无效"}
	if raw_cards.size() > MAX_BOARD:
		return {"ok": false, "msg": "上场单位超过 7 个"}
	var cards: Array = []
	for entry in raw_cards:
		if typeof(entry) != TYPE_DICTIONARY:
			return {"ok": false, "msg": "卡牌条目无效"}
		var id := String(entry.get("id", ""))
		var card := Cards.get_card(id)
		if card.is_empty():
			return {"ok": false, "msg": "未知卡牌：%s" % id}
		var star := int(entry.get("star", 1))
		if star != 1 and star != 2:
			return {"ok": false, "msg": "卡牌星级无效"}
		cards.append({"id": id, "star": star})
	var level := int(data.get("level", 2))
	var greed := int(data.get("greed", 0))
	if level < 2 or level > Cards.MAX_LEVEL:
		return {"ok": false, "msg": "等级超出范围"}
	if greed < 0 or greed > Cards.MAX_GREED:
		return {"ok": false, "msg": "贪婪潮等级超出范围"}
	return {
		"ok": true,
		"msg": "阵容码解析成功",
		"cards": cards,
		"level": level,
		"greed": greed,
		"flood": bool(data.get("flood", false)),
	}


static func short(code: String, keep: int = 28) -> String:
	if code.length() <= keep:
		return code
	return code.substr(0, keep) + "…"


static func _valid_base64(s: String) -> bool:
	if s.length() == 0 or s.length() % 4 != 0:
		return false
	var pad := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c == 61: # '='
			pad += 1
			if i < s.length() - 2:
				return false
			continue
		if pad > 0:
			return false
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 43 or c == 47:
			continue
		return false
	return pad <= 2
