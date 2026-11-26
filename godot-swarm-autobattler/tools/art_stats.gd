extends SceneTree

## Art acceptance support: node counts / draw calls / MultiMesh instances at
## 100 / 1000 / 3000 units. Writes docs/shots/art-impl/tech_stats.json.
## Run: godot --path godot-swarm-autobattler -s tools/art_stats.gd

const OUT := "res://docs/shots/art-impl/tech_stats.json"
var sv: SubViewport
var holder: Control
var game

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	sv = SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	holder = Control.new()
	holder.size = Vector2(1280, 720)
	holder.scale = Vector2(1.5, 1.5)
	sv.add_child(holder)
	game = load("res://scenes/main.tscn").instantiate()
	holder.add_child(game)
	for i in 3:
		await process_frame
	var results := []
	for units in [100, 1000, 3000]:
		game.debug_mount_battle(units, 0.0, false, false, false)
		for i in 10:
			await process_frame
		game.debug_get_view().set_paused(true)
		for i in 3:
			await process_frame
		var view = game.debug_get_view()
		var names := []
		for c in view.get_children():
			names.append(c.get_class())
		results.append({
			"units_target": units,
			"unit_instances": view._unit_mm.instance_count,
			"multimesh_nodes": names.count("MultiMeshInstance2D"),
			"view_children": view.get_child_count(),
			"view_child_types": names,
			"nodes_total": _count(game),
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"adapter": RenderingServer.get_video_adapter_name(),
			"viewport": "1920x1080",
		})
		print("ART_STATS units=%d children=%d nodes=%d draw=%d" % [
			units, view.get_child_count(), _count(game),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"timestamp": Time.get_datetime_string_from_system(),
			"results": results}, "  "))
		f.close()
	print("ART_STATS_JSON=", ProjectSettings.globalize_path(OUT))
	print("ART_STATS_OK")
	quit(0)

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
