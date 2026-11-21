class_name HeroRoster
extends RefCounted

const DIR := "res://roster/heroes"
const SAVE_PATH := "user://character_select.cfg"
const SECTION := "selection"
const KEY := "hero_id"
const EXPECTED_COUNT := 6
const CLASSES := ["剑客", "法师", "医师"]
const RACES := ["人族", "仙族", "妖族"]

static func load_all() -> Array[HeroProfile]:
	var result: Array[HeroProfile] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("Hero roster directory missing: " + DIR)
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var resource: Resource = load(DIR + "/" + file_name)
		if resource is HeroProfile:
			result.append(resource)
		else:
			push_error("Invalid hero profile: " + file_name)
	result.sort_custom(func(a: HeroProfile, b: HeroProfile) -> bool: return a.sort_order < b.sort_order)
	for issue in validate(result):
		push_error("Hero roster: " + issue)
	return result

static func validate(profiles: Array[HeroProfile]) -> Array[String]:
	var issues: Array[String] = []
	if profiles.size() != EXPECTED_COUNT:
		issues.append("expected %d heroes, got %d" % [EXPECTED_COUNT, profiles.size()])
	var ids: Dictionary = {}
	var class_genders: Dictionary = {}
	var races: Dictionary = {}
	for profile in profiles:
		if profile.id == &"":
			issues.append("empty hero id")
			continue
		if ids.has(profile.id):
			issues.append("duplicate hero id: %s" % profile.id)
		ids[profile.id] = true
		if not CLASSES.has(profile.hero_class):
			issues.append("%s has unknown class: %s" % [profile.id, profile.hero_class])
		if profile.gender != "男" and profile.gender != "女":
			issues.append("%s has unknown gender: %s" % [profile.id, profile.gender])
		if not RACES.has(profile.race):
			issues.append("%s has unknown race: %s" % [profile.id, profile.race])
		if profile.description.length() < 20:
			issues.append("%s description too short" % profile.id)
		if profile.quote.is_empty():
			issues.append("%s quote is empty" % profile.id)
		for value in [profile.hp_bar, profile.atk_bar, profile.mag_bar, profile.spd_bar]:
			if value < 0 or value > 100:
				issues.append("%s stat out of range: %d" % [profile.id, value])
		if profile.skills.size() != 3:
			issues.append("%s expected 3 skills, got %d" % [profile.id, profile.skills.size()])
		if not profile.portrait_path.is_empty() and not FileAccess.file_exists(profile.portrait_path):
			issues.append("%s portrait missing: %s" % [profile.id, profile.portrait_path])
		var class_key := profile.hero_class
		if not class_genders.has(class_key):
			class_genders[class_key] = {}
		class_genders[class_key][profile.gender] = true
		races[profile.race] = true
	for class_name_value in CLASSES:
		if not class_genders.has(class_name_value):
			issues.append("missing class: " + class_name_value)
			continue
		var genders: Dictionary = class_genders[class_name_value]
		if not genders.has("男") or not genders.has("女"):
			issues.append("class %s must have both genders" % class_name_value)
	for race in RACES:
		if not races.has(race):
			issues.append("missing race: " + race)
	return issues

static func find(profiles: Array[HeroProfile], id: StringName) -> HeroProfile:
	for profile in profiles:
		if profile.id == id:
			return profile
	return null

static func save_id(id: StringName) -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY, String(id))
	return config.save(SAVE_PATH)

static func load_saved_id() -> StringName:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return &""
	var id := StringName(String(config.get_value(SECTION, KEY, "")))
	if id == &"":
		return &""
	for profile in load_all():
		if profile.id == id:
			return id
	return &""

static func clear_saved_id() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	config.erase_section_key(SECTION, KEY)
	config.save(SAVE_PATH)
