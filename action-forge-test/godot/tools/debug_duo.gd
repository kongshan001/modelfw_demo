extends SceneTree
func _initialize() -> void:
	var scene: Node3D = load("res://walkmove.tscn").instantiate()
	root.add_child(scene)
	await create_timer(2.0).timeout
	for k in 8:
		for i in scene.call("test_actor_count"):
			var d: Dictionary = scene.call("test_actor_debug", i)
			print("DBG t=%.1f i=%d %s clip=%s current=%s state=%s pos=(%.2f,%.2f) body=%+.0f move=%+.0f err=%.1f" % [
				k * 0.5, i, d["label"], d["clip_id"], d["current"], d["state"],
				d["pos"].x, d["pos"].z, d["body_yaw"], d["move_yaw"], d["body_err"]])
		if k == 0:
			print("DBG_CLIPS0 ", scene.call("test_actor_debug", 0)["clips"])
			print("DBG_CLIPS1 ", scene.call("test_actor_debug", 1)["clips"])
		await create_timer(0.5).timeout
	quit(0)
