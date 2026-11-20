extends SceneTree

# 无头 mod 校验：安装 → 扫描 → 校验 valid / bad_scale / bad_hash。
# Run: godot --headless --path godot-iso-slice -s tools/mod_check.gd

func _initialize() -> void:
	var fails: Array[String] = []
	var installed := ModLoader.install_fixtures()
	print("INSTALLED=", installed)
	if installed != 3:
		fails.append("installed %d != 3" % installed)

	var mods := ModLoader.scan()
	if mods.size() != 3:
		fails.append("scanned %d != 3" % mods.size())
	var results := {}
	for entry in mods:
		var m: Dictionary = entry["manifest"]
		var id := str(m.get("id", "?"))
		var r := ModLoader.validate(entry)
		results[id] = r
		print("MOD %s ok=%s tris=%d meshes=%d reason=%s" % [
			id, str(r["ok"]), int(r["tris"]), int(r["meshes"]), str(r["reason"])])
		if r["scene"] != null:
			(r["scene"] as Node).free()

	if not results.has("crystal_lamp"):
		fails.append("valid mod missing")
	else:
		var good: Dictionary = results["crystal_lamp"]
		if not good["ok"]:
			fails.append("valid mod rejected: " + str(good["reason"]))
		if int(good["tris"]) != 26:
			fails.append("valid mod tris %d != 26" % int(good["tris"]))
		var box: AABB = good["aabb"]
		if absf(box.position.y) > 0.02:
			fails.append("valid mod pivot y %.3f" % box.position.y)

	if not results.has("bad_scale"):
		fails.append("bad_scale missing")
	else:
		var r: Dictionary = results["bad_scale"]
		if r["ok"]:
			fails.append("bad_scale should be rejected")
		elif not str(r["reason"]).contains("bounds"):
			fails.append("bad_scale wrong reason: " + str(r["reason"]))

	if not results.has("bad_hash"):
		fails.append("bad_hash missing")
	else:
		var r: Dictionary = results["bad_hash"]
		if r["ok"]:
			fails.append("bad_hash should be rejected")
		elif not str(r["reason"]).contains("sha256"):
			fails.append("bad_hash wrong reason: " + str(r["reason"]))

	if fails.is_empty():
		print("MOD_CHECK_OK")
		quit(0)
	else:
		for f in fails:
			printerr("MOD FAIL: ", f)
		quit(1)
