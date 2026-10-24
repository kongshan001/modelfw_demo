class_name ContentDB
extends RefCounted

var units: Dictionary = {}
var skills: Dictionary = {}
var statuses: Dictionary = {}
var items: Dictionary = {}
var encounters: Dictionary = {}
var _hash_cache: String = ""

static func load_all(base_dir: String = "res://data") -> ContentDB:
	var db := ContentDB.new()
	db._load_dir(base_dir + "/units", db.units)
	db._load_dir(base_dir + "/skills", db.skills)
	db._load_dir(base_dir + "/statuses", db.statuses)
	db._load_dir(base_dir + "/items", db.items)
	db._load_dir(base_dir + "/encounters", db.encounters)
	return db

func _load_dir(dir_path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Content directory missing: " + dir_path)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var resource: Resource = load(dir_path + "/" + file_name)
		if resource == null:
			push_error("Cannot load content: " + dir_path + "/" + file_name)
			continue
		target[resource.get("id")] = resource

func get_unit(id: StringName) -> UnitData:
	return units.get(id)
func get_skill(id: StringName) -> SkillData:
	return skills.get(id)
func get_status(id: StringName) -> StatusData:
	return statuses.get(id)
func get_item(id: StringName) -> ItemData:
	return items.get(id)
func get_encounter(id: StringName) -> EncounterData:
	return encounters.get(id)

func content_hash() -> String:
	if not _hash_cache.is_empty():
		return _hash_cache
	var files := _collect_tres("res://data")
	files.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		context.update(path.to_utf8_buffer())
		context.update(text.to_utf8_buffer())
	_hash_cache = "sha256:" + context.finish().hex_encode()
	return _hash_cache

func _collect_tres(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			result.append(dir_path + "/" + file_name)
	for sub_dir in dir.get_directories():
		result.append_array(_collect_tres(dir_path + "/" + sub_dir))
	return result
