extends SceneTree

# Headless 冒烟：baked demo 场景加载、目标模型、baked AnimationPlayer 存在。
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

	print("BAKED_DEMO_SMOKE_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	printerr("BAKED_DEMO_SMOKE_FAIL: " + message)
	quit(1)
