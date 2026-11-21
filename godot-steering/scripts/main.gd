extends Node2D

## 入口：键盘快捷键、面板显隐、电影模式自动巡演。

@onready var sim = $Sim
@onready var ui = $UI
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	ui.bind(sim)
	sim.config_changed.connect(ui.refresh)
	var args := OS.get_cmdline_user_args()
	if args.has("--tour") or OS.get_environment("STEERING_TOUR") == "1":
		_run_tour()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			sim.toggle_pause()
			ui.refresh()
		KEY_R:
			sim.reset_sim(true)
		KEY_H:
			ui.visible = not ui.visible
		KEY_1:
			sim.apply_preset("video")
		KEY_2:
			sim.apply_preset("chase")
		KEY_3:
			sim.apply_preset("corridor")
		KEY_4:
			sim.apply_preset("flock")
		KEY_V:
			sim.set_show("vectors", not sim.show["vectors"])
		KEY_B:
			sim.set_show("rays", not sim.show["rays"])
		KEY_N:
			sim.set_show("neighbors", not sim.show["neighbors"])
		KEY_G:
			sim.set_show("flow", not sim.show["flow"])
		KEY_L:
			sim.set_show("highlight", not sim.show["highlight"])
		_:
			return
	get_viewport().set_input_as_handled()


func _run_tour() -> void:
	# 电影模式：先带 UI 展示 1.2s，再隐藏面板，让 150 体流场绕障占满画面。
	await get_tree().create_timer(0.2).timeout
	sim.apply_preset("video")
	sim.set_agent_count(150)
	sim.set_show("flow", true)
	sim.set_show("highlight", true)
	sim.set_show("rays", true)
	sim.set_show("neighbors", true)
	sim.set_show("vectors", true)
	sim.select_index(6)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(ui):
		ui.visible = false
	# 电影模式 30fps：允许每帧补 2 个物理步，保持 60Hz 模拟实时。
	Engine.max_physics_steps_per_frame = 2
	await get_tree().create_timer(2.2).timeout
	_select_tour_focus()


func _select_tour_focus() -> void:
	# 选一个靠近 C 形障碍且胡须真正命中的单位，展示三须探测与斥力。
	var best := 6
	var best_score := -INF
	for i in sim.agents.size():
		var a = sim.agents[i]
		if a.pos.distance_to(Vector2(680, 450)) > 280.0:
			continue
		sim.selected = i
		sim._avoidance_force(a)
		var hits := 0
		for rec in a.rays:
			if rec.get("hit", false):
				hits += 1
		if hits <= 0:
			continue
		var score: float = hits * 10000.0 - a.pos.distance_to(Vector2(620, 520))
		if score > best_score:
			best_score = score
			best = i
	sim.select_index(best)
