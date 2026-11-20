extends SceneTree

# QA Cycle 3 终验补充只读探针：核对提灯人光晕节点是否真实创建（含新增 wide 层）。
# 只读运行时实例，不修改游戏逻辑，结束释放场景。

func _initialize() -> void:
	var scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(false)
	scene.set_time(0.0)
	await create_timer(1.2).timeout

	var lantern = scene._world.patrols[0]
	var halos := {
		"core": lantern._lantern_halo_core,
		"outer": lantern._lantern_halo_outer,
		"far": lantern._lantern_halo_far,
		"wide": lantern._lantern_halo_wide,
	}
	for key in halos:
		var halo = halos[key]
		if halo == null:
			print("HALO %s=NULL" % key)
			continue
		var world_m: float = halo.scale.x * float(halo.texture.get_width()) * halo.pixel_size
		print("HALO %s visible=%s alpha=%.3f world_m=%.3f pos_y=%.3f" % [
			key, str(halo.visible), halo.modulate.a, world_m, halo.position.y])

	var sprites: Array = lantern._lantern_rig.find_children("*", "Sprite3D", true, false)
	var names: Array[String] = []
	for node in sprites:
		names.append(String(node.name))
	print("HALO rig_sprite_count=%d names=%s" % [sprites.size(), str(names)])
	print("HALO light_range=%.2f light_energy=%.3f pool_visible=%s" % [
		lantern._lantern_light.omni_range, lantern._lantern_light.light_energy,
		str(lantern._lantern_pool != null and lantern._lantern_pool.visible)])

	scene.queue_free()
	await process_frame
	quit(0)
