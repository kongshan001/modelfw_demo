extends SceneTree

# 广角手持灯识别探针：默认相机、深夜、把提灯人放到远离路灯的池南岸；
# 以灯笼屏幕坐标为中心 200×200 窗口统计“亮芯”（R>220 且暖色）bbox。

func _initialize() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene = load("res://scenes/garden.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(false)
	scene.set_time(0.0)
	scene.toggle_feature("lamps")
	var npc = scene._world.patrols[0]
	npc.global_position = Vector3(2.5, 0.0, 3.5)
	npc.force_pause(8.0)
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var cam: Camera3D = scene._camera
	var center: Vector2 = cam.unproject_position(npc._lantern_body.global_transform * Vector3(0, 0.34, 0)) * 2.0
	var cw = npc._lantern_halo_core_wide
	print("CORE_WIDE vis=", cw.visible, " a=", cw.modulate.a, " scale=", cw.scale, " pos=", cw.global_position)
	var img: Image = vp.get_texture().get_image()
	var minx := 99999; var miny := 99999; var maxx := -1; var maxy := -1; var count := 0
	for y in range(int(center.y) - 80, int(center.y) + 80):
		for x in range(int(center.x) - 80, int(center.x) + 80):
			if x < 0 or y < 0 or x >= 1920 or y >= 1080:
				continue
			var c := img.get_pixel(x, y)
			if c.r * 255.0 > 200.0 and (c.r - c.b) * 255.0 > 25.0 and (c.r - c.g) * 255.0 > 8.0:
				count += 1
				minx = mini(minx, x); miny = mini(miny, y); maxx = maxi(maxx, x); maxy = maxi(maxy, y)
	var w := maxx - minx + 1 if count > 0 else 0
	var h := maxy - miny + 1 if count > 0 else 0
	print("WIDE_LANTERN_TH200 center=", center, " count=", count, " bbox=", w, "x", h)
	var path := "user://screenshots/wide_lantern_probe.png"
	img.save_png(path)
	print("SCREENSHOT: ", ProjectSettings.globalize_path(path))
	scene.queue_free(); vp.queue_free(); await process_frame; quit(0)
