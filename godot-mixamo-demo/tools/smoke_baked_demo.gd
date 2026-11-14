extends SceneTree

# Headless 冒烟：showcase 场景加载、原生 SambaDance 与 baked Run 双向切换。
# 用法：godot --headless --path godot-mixamo-demo -s tools/smoke_baked_demo.gd

func _initialize() -> void:
	var scene: Node = load("res://scenes/baked_demo.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.5).timeout

	var model: Node = scene.get_node_or_null("BakedMichelle")
	if model == null:
		_fail("BakedMichelle missing")
		return
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or ap.get_animation_list().is_empty():
		_fail("baked AnimationPlayer/clip missing")
		return

	var dancer: Node = scene.get_node_or_null("NativeMichelle")
	if dancer == null:
		_fail("NativeMichelle missing")
		return
	var dance_ap := dancer.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if dance_ap == null or not dance_ap.has_animation("SambaDance"):
		_fail("native SambaDance missing")
		return

	scene.call("set_run_mode")
	await process_frame
	if not (model as Node3D).visible:
		_fail("baked runner not visible in run mode")
		return
	scene.call("set_dance_mode")
	await process_frame
	if not (dancer as Node3D).visible:
		_fail("dancer not visible in dance mode")
		return

	print("BAKED_DEMO_SMOKE_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	printerr("BAKED_DEMO_SMOKE_FAIL: " + message)
	quit(1)
