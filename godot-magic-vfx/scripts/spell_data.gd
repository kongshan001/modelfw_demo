class_name SpellData
extends RefCounted

# Three original spell variants in the spirit of the reference tutorial
# (head + scrolling flame trail + sparks + moving light), not copies of its art.
# Colors are hex strings to keep the table readable; parsed once and cached.

const TEX_SPARK := "res://assets/textures/spark.png"
const TEX_STREAK := "res://assets/textures/spark_streak.png"
const TEX_SMOKE := "res://assets/textures/smoke.png"
const TEX_GLOW := "res://assets/textures/glow.png"
const TEX_SHARD := "res://assets/textures/shard.png"
const TEX_STAR := "res://assets/textures/flare.png"
const TEX_FIRE_STRIP := "res://assets/textures/flame_strip.png"
const TEX_FROST_STRIP := "res://assets/textures/frost_strip.png"

static var _cache: Array[Dictionary] = []

static func all() -> Array[Dictionary]:
	if not _cache.is_empty():
		return _cache
	_cache = [
		{
			"id": "ember", "name": "炎爆", "en": "EMBER", "tag": "FIREBALL",
			"accent": "#ff8a3d", "hot": "#fff2c0", "mid": "#ffa53a", "deep": "#d92a0e",
			"light": "#ff8a3d",
			"head_style": 0.0, "head_scale": 1.0,
			"trail_tex": TEX_FIRE_STRIP, "trail_len": 3.4, "trail_width": 1.25,
			"trail_repeat": 1.9, "trail_speed": 1.25,
			"speed": 13.5, "arc": 0.55, "spin": 0.0,
			"spark_tex": TEX_STREAK, "spark_amount": 40, "spark_size": 0.38,
			"spark_vel": 4.2, "spark_gravity": 7.0,
			"puff_amount": 16, "puff_size": 0.62, "puff_color": "#ff8a3d",
			"burst": 22, "burst_size": 1.0, "burst_vel": 5.2,
			"sparks_burst": 36, "embers": 14, "smoke": 0,
			"ring_color": "#ffb060", "shake": 0.11, "light_energy": 4.2,
			"impact_rune": 0.0, "mist": 0.0,
			"desc": "重击 · 长焰拖尾 · 余烬",
		},
		{
			"id": "arcane", "name": "奥术", "en": "ARCANE", "tag": "ARC BOLT",
			"accent": "#a98bff", "hot": "#e8f4ff", "mid": "#8f7bff", "deep": "#3c2aa8",
			"light": "#9b7bff",
			"head_style": 1.0, "head_scale": 0.92,
			"trail_tex": TEX_FIRE_STRIP, "trail_len": 2.8, "trail_width": 0.9,
			"trail_repeat": 2.3, "trail_speed": 1.6,
			"speed": 16.5, "arc": 0.28, "spin": 1.0,
			"spark_tex": TEX_STAR, "spark_amount": 32, "spark_size": 0.28,
			"spark_vel": 3.0, "spark_gravity": 1.2,
			"puff_amount": 10, "puff_size": 0.44, "puff_color": "#8f7bff",
			"burst": 18, "burst_size": 0.8, "burst_vel": 4.4,
			"sparks_burst": 28, "embers": 0, "smoke": 0,
			"ring_color": "#a98bff", "shake": 0.08, "light_energy": 3.0,
			"impact_rune": 1.0, "mist": 0.0,
			"desc": "高速 · 符文冲击环 · 星火",
		},
		{
			"id": "frost", "name": "霜晶", "en": "FROST", "tag": "ICE SHARD",
			"accent": "#7fd8ff", "hot": "#ffffff", "mid": "#b9ecff", "deep": "#2f74e0",
			"light": "#7fd8ff",
			"head_style": 2.0, "head_scale": 1.0,
			"trail_tex": TEX_FROST_STRIP, "trail_len": 2.5, "trail_width": 1.0,
			"trail_repeat": 1.5, "trail_speed": 0.8,
			"speed": 19.0, "arc": 0.12, "spin": 2.0,
			"spark_tex": TEX_SHARD, "spark_amount": 26, "spark_size": 0.24,
			"spark_vel": 3.4, "spark_gravity": 3.5,
			"puff_amount": 12, "puff_size": 0.72, "puff_color": "#bfefff",
			"burst": 16, "burst_size": 0.9, "burst_vel": 4.8,
			"sparks_burst": 24, "embers": 0, "smoke": 0,
			"ring_color": "#8fdcff", "shake": 0.09, "light_energy": 3.2,
			"impact_rune": 0.0, "mist": 1.0,
			"desc": "急速 · 冰晶碎屑 · 寒雾",
		},
	]
	for s in _cache:
		for key in ["accent", "hot", "mid", "deep", "light", "puff_color", "ring_color"]:
			s[key] = Color.from_string(String(s[key]), Color.MAGENTA)
	return _cache


static func get_spell(index: int) -> Dictionary:
	var arr := all()
	return arr[posmod(index, arr.size())]


static func count() -> int:
	return all().size()
