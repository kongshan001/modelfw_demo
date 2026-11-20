extends SceneTree

# 跨语言确定性校验：Python 离线烘焙的 PNG/RGBA 哈希 vs GDScript 运行时生成。
# Run: godot --headless --path godot-iso-slice -s tools/pipeline_check.gd

func _initialize() -> void:
	var fails: Array[String] = []
	var rules := SigilRules.load_rules()
	if rules.is_empty():
		printerr("PIPELINE FAIL: rules.json")
		quit(1)
		return

	var manifest_text := FileAccess.get_file_as_string(
		"res://assets/generated/manifest.json")
	if manifest_text.is_empty():
		printerr("PIPELINE FAIL: manifest.json missing (run tools/bake_pipeline.py)")
		quit(1)
		return
	var manifest: Variant = JSON.parse_string(manifest_text)
	if typeof(manifest) != TYPE_DICTIONARY:
		printerr("PIPELINE FAIL: manifest.json invalid")
		quit(1)
		return

	if int(manifest["rules_version"]) != int(rules["version"]):
		fails.append("rules version mismatch")
	if str(manifest["rule"]) != str(rules["rule"]):
		fails.append("rule name mismatch")

	for seed_value in manifest["seeds"]:
		var seed := int(seed_value)
		var entry: Dictionary = manifest["assets"][str(seed)]
		var expected := str(entry["sha256_rgba"])

		var img := SigilRules.generate(rules, seed)
		var runtime_hash := SigilRules.sha256_rgba(img)
		if runtime_hash != expected:
			fails.append("seed %d runtime hash %s != %s" % [
				seed, runtime_hash.substr(0, 16), expected.substr(0, 16)])
		else:
			print("RUNTIME MATCH seed=", seed, " ", runtime_hash.substr(0, 16))

		var disk := Image.load_from_file("res://assets/generated/" + str(entry["file"]))
		if disk == null:
			fails.append("seed %d baked PNG failed to load" % seed)
		else:
			var disk_hash := SigilRules.sha256_rgba(disk)
			if disk_hash != expected:
				fails.append("seed %d baked PNG hash mismatch" % seed)
			if disk.get_width() != int(manifest["size"]):
				fails.append("seed %d baked PNG wrong size" % seed)

	# 运行时缓存回环：生成 → user:// → 重新导入
	var cache_seed := int(manifest["baked_seed"])
	var cache_img := SigilRules.generate(rules, cache_seed)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://pipeline_cache"))
	var cache_path := "user://pipeline_cache/sigil_%d.png" % cache_seed
	var save_err := cache_img.save_png(cache_path)
	var cached := Image.load_from_file(cache_path) if save_err == OK else null
	var expected_cache := str(manifest["assets"][str(cache_seed)]["sha256_rgba"])
	if cached == null:
		fails.append("cache round-trip failed to load")
	elif SigilRules.sha256_rgba(cached) != expected_cache:
		fails.append("cache round-trip hash mismatch")
	else:
		print("CACHE ROUNDTRIP OK seed=", cache_seed, " ", cache_path)

	if fails.is_empty():
		print("PIPELINE_OK seeds=", manifest["seeds"].size())
		quit(0)
	else:
		for f in fails:
			printerr("PIPELINE FAIL: ", f)
		quit(1)
