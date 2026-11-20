extends SceneTree

# 宣传片段驱动：配合 Movie Maker 录制 6–10 秒的换装/8 向/动作演示。
# 用法：godot --path godot-paper-doll --resolution 1280x720 --fixed-fps 30 \
#         --write-movie docs/paperdoll.avi -s tools/demo_paperdoll.gd
# 之后用 ffmpeg 把 AVI 转成 MP4 / GIF（见 tools/record_paperdoll.sh）。


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_fps_visible(false)

	# 0–1.2s：默认纸偶，待机。
	scene.load_lineup_entry(0)
	scene.set_action("idle")
	scene.set_direction(7)
	await _frames(36)

	# 1.2–2.0s：随机换一整套，展示槽位与配色即时生效。
	scene.randomize_current()
	scene.set_direction(7)
	await _frames(24)

	# 2.0–4.7s：行走并逐个扫过 8 个方向（左向由镜像完成）。
	scene.set_action("walk")
	for d in DollData.DIRS.size():
		scene.set_direction(d)
		await _frames(10)
	scene.set_direction(7)
	await _frames(10)

	# 4.7–6.2s：挥击一个完整周期。
	scene.set_action("attack")
	await _frames(45)

	# 6.2–7.5s：受击抖动。
	scene.set_action("hit")
	await _frames(40)

	# 7.5–8.2s：整队重掷，收尾在 4×4 阵容。
	scene.randomize_lineup()
	await _frames(20)
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
