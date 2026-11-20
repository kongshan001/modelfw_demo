class_name PartPainter
extends RefCounted

# 17 槽位的绘制调度 + 变体覆盖校验（headless smoke 使用）。

const PAINTED := {
	"aura": ["none", "spark", "leaf", "flame", "bubble", "halo"],
	"cape": ["none", "short", "long", "scarf"],
	"backpack": ["none", "satchel", "shell", "wings", "lantern"],
	"body": ["plain", "grain", "patch", "rivet"],
	"pants": ["shorts", "trousers", "skirt", "leggings"],
	"shoes": ["boots", "sneakers", "clogs", "bare"],
	"shirt": ["tunic", "hoodie", "vest", "armor", "dress"],
	"belt": ["none", "rope", "sash", "pouch"],
	"head": ["round", "square", "acorn", "pebble"],
	"ear": ["none", "round", "pointy", "horn", "antenna"],
	"mask": ["none", "fox", "owl", "bandit", "specs"],
	"eyes": ["dot", "happy", "fierce", "sleepy", "sparkle", "visor"],
	"hair": ["short", "mess", "bob", "bun", "long", "spiky"],
	"hat": ["none", "beanie", "acorn", "wizard", "crown", "leaf"],
	"gloves": ["none", "mittens", "bracers", "claws"],
	"weapon": ["none", "sword", "hammer", "staff", "fan", "spoon"],
	"accessory": ["none", "bell", "pendant", "badge", "charm"],
}


static func validate() -> Array[String]:
	var issues: Array[String] = []
	for slot in DollData.SLOTS:
		var slot_id: String = slot["id"]
		if not PAINTED.has(slot_id):
			issues.append("no painter for slot " + slot_id)
			continue
		for variant in slot["variants"]:
			var variant_id: String = variant["id"]
			if not PAINTED[slot_id].has(variant_id):
				issues.append("no painter for %s/%s" % [slot_id, variant_id])
	if PAINTED.size() != DollData.SLOTS.size():
		issues.append("painter slot table size mismatch")
	return issues


static func paint(ci: CanvasItem, slot: String, variant: String, ctx: Dictionary) -> void:
	if variant == "none":
		return
	match slot:
		"body", "head", "ear", "eyes", "mask", "hair":
			PaintFigure.paint(ci, slot, variant, ctx)
		"cape", "backpack", "pants", "shirt", "shoes", "belt", "gloves":
			PaintCloth.paint(ci, slot, variant, ctx)
		"aura", "hat", "weapon", "accessory":
			PaintProps.paint(ci, slot, variant, ctx)
