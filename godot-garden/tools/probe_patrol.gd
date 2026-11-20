extends SceneTree

# 巡逻探针：跑 12s 实测三个 NPC 的位移、与水池/石圈/石像/拱柱的最小距离，
# 以及窗口渲染 FPS。用于“真的在巡逻、没穿模、没拖垮帧率”的验收。

const DURATION := 12.0
const SAMPLE := 0.1
const POND_CENTER := Vector3(-5, 0, 3)
const POND_RADIUS := 4.2
const CIRCLE_CENTER := Vector3(8, 0, 5)
const STATUE := Vector3(-1, 0, 1.8)
const ARCH_PILLARS := [Vector3(6.51, 0, -3.9), Vector3(2.49, 0, -2.11)]

func _initialize() -> void:
	# 关垂直同步，测真实渲染帧率（与历史 80–85 FPS 口径一致）
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(false)
	scene.set_time(18.2)
	await create_timer(1.0).timeout

	var patrols = scene._world.patrols
	var travelled: Array[float] = []
	var min_pond: Array[float] = []
	var min_circle: Array[float] = []
	var min_statue: Array[float] = []
	var min_pillar: Array[float] = []
	var last: Array[Vector3] = []
	for npc in patrols:
		travelled.append(0.0)
		min_pond.append(999.0)
		min_circle.append(999.0)
		min_statue.append(999.0)
		min_pillar.append(999.0)
		last.append(npc.global_position)

	var fps_samples: Array[float] = []
	var elapsed := 0.0
	while elapsed < DURATION:
		await create_timer(SAMPLE).timeout
		elapsed += SAMPLE
		for index in patrols.size():
			var npc = patrols[index]
			var point: Vector3 = npc.global_position
			travelled[index] += Vector2(point.x - last[index].x, point.z - last[index].z).length()
			last[index] = point
			min_pond[index] = minf(min_pond[index], _flat_distance(point, POND_CENTER))
			min_circle[index] = minf(min_circle[index], _flat_distance(point, CIRCLE_CENTER))
			min_statue[index] = minf(min_statue[index], _flat_distance(point, STATUE))
			for pillar in ARCH_PILLARS:
				min_pillar[index] = minf(min_pillar[index], _flat_distance(point, pillar))
		if int(elapsed * 10.0) % 10 == 0:
			fps_samples.append(Engine.get_frames_per_second())

	var fps_avg := 0.0
	var fps_min := 999.0
	for value in fps_samples:
		fps_avg += value
		fps_min = minf(fps_min, value)
	if fps_samples.size() > 0:
		fps_avg /= float(fps_samples.size())

	var ok := true
	for index in patrols.size():
		var npc = patrols[index]
		var moved_ok: bool = travelled[index] > DURATION * 0.35
		var pond_ok: bool = min_pond[index] > POND_RADIUS + 0.6
		var circle_ok: bool = min_circle[index] > 2.6
		var statue_ok: bool = min_statue[index] > 1.8
		var pillar_ok: bool = min_pillar[index] > 1.0
		ok = ok and moved_ok and pond_ok and circle_ok and statue_ok and pillar_ok
		print("PATROL %s role=%s travelled=%.1f min_pond=%.2f min_circle=%.2f min_statue=%.2f min_pillar=%.2f" % [
			npc.name, npc.role, travelled[index], min_pond[index], min_circle[index],
			min_statue[index], min_pillar[index]])

	print("PATROL_FPS avg=%.1f min=%.1f samples=%d" % [fps_avg, fps_min, fps_samples.size()])

	# 5 键 / UI「游人」开关链路
	scene.toggle_feature("patrols")
	var hidden_ok := true
	for npc in patrols:
		hidden_ok = hidden_ok and not npc.visible
	scene.toggle_feature("patrols")
	var shown_ok := true
	for npc in patrols:
		shown_ok = shown_ok and npc.visible
	ok = ok and hidden_ok and shown_ok
	print("PATROL_TOGGLE hidden_ok=%s shown_ok=%s" % [hidden_ok, shown_ok])

	# A/B：隐藏巡逻角色再测 6s，量化三只 NPC 的帧率成本
	scene._world.set_patrol_visible(false)
	await create_timer(1.0).timeout
	var fps_hidden := await _sample_fps(6.0)
	scene._world.set_patrol_visible(true)
	await create_timer(1.0).timeout
	var fps_shown := await _sample_fps(6.0)
	print("PATROL_FPS_AB hidden=%.1f shown=%.1f cost=%.1f" % [fps_hidden, fps_shown, fps_hidden - fps_shown])

	print("PROBE_PATROL_OK" if ok else "PROBE_PATROL_FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)

func _sample_fps(duration: float) -> float:
	var total := 0.0
	var count := 0
	var elapsed := 0.0
	while elapsed < duration:
		await create_timer(0.5).timeout
		elapsed += 0.5
		total += Engine.get_frames_per_second()
		count += 1
	return total / float(maxi(count, 1))

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
