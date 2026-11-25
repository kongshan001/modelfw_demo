extends Node3D
## 苔光浮庭 · 主控。
## 组装世界、天幕、环绕相机、轻交互、后处理、HUD 与程序化音效；
## 所有场景时间/暂停由这里统一推进，便于 smoke 与截图工具调用。

const WorldScript = preload("res://scripts/world.gd")
const AtmosphereScript = preload("res://scripts/atmosphere.gd")
const CameraRigScript = preload("res://scripts/camera_rig.gd")
const InteractionScript = preload("res://scripts/interaction.gd")
const HUDScript = preload("res://scripts/hud.gd")
const PostFXScript = preload("res://scripts/post_fx.gd")
const ProceduralAudioScript = preload("res://scripts/procedural_audio.gd")

const UI_DESIGN := Vector2(1280.0, 720.0)

var world
var atmosphere
var rig
var interaction
var hud
var post
var audio

var night_mode := true
var rain_mode := false
var quality_high := true
var paused := false
var debug_overlay := false
var hud_visible := true

var _fps := 60
var _draw_calls := 0
var _triangles := 0
var _stats_timer := 0.0
var _fps_visible := true
var _markers_visible := true
var _ready_world := false


func _ready() -> void:
	name = "MosslightIsle"
	process_mode = Node.PROCESS_MODE_ALWAYS
	atmosphere = AtmosphereScript.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.setup()

	world = WorldScript.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.setup()
	world.interaction_feedback.connect(_on_interaction_feedback)

	rig = CameraRigScript.new()
	rig.name = "CameraRig"
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rig)

	post = PostFXScript.new()
	post.name = "PostFX"
	post.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(post)

	hud = HUDScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)

	interaction = InteractionScript.new()
	interaction.name = "Interaction"
	interaction.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(interaction)
	interaction.setup(self, world, rig.camera, hud)

	audio = ProceduralAudioScript.new()
	audio.name = "ProceduralAudio"
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio)

	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale()
	_ready_world = true
	atmosphere.set_night(true, true)
	atmosphere.set_weather(false, true)
	world.set_quality(true)
	world.tick(0.016, atmosphere.nightness, atmosphere.rain_amount, true)
	post.tick(0.016, atmosphere.nightness, atmosphere.rain_amount)
	hud.sync_from_main()
	_update_stats(true)


func _process(delta: float) -> void:
	if _ready_world:
		if not paused:
			atmosphere.advance(delta)
			world.tick(delta, atmosphere.nightness, atmosphere.rain_amount, quality_high)
			post.tick(delta, atmosphere.nightness, atmosphere.rain_amount)
		_stats_timer += delta
		if _stats_timer >= 0.25:
			_stats_timer = 0.0
			_update_stats(false)


func _update_stats(force: bool) -> void:
	_fps = Engine.get_frames_per_second()
	_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_triangles = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if hud != null:
		hud.set_fps(_fps, _draw_calls, _triangles)
		if force:
			hud.sync_from_main()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var handled := true
	match key_event.physical_keycode:
		KEY_N:
			toggle_phase()
		KEY_T:
			toggle_weather()
		KEY_P:
			toggle_pause()
		KEY_R:
			reset_demo()
		KEY_Q:
			toggle_quality()
		KEY_H:
			toggle_hud()
		KEY_F1:
			toggle_debug()
		KEY_SPACE:
			if not paused:
				rig.toggle_auto_orbit()
				hud.show_toast("环绕相机：" + ("开启" if rig.auto_orbit else "握住"))
			else:
				handled = false
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _apply_ui_scale() -> void:
	if hud == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var ratio := minf(vp.x / UI_DESIGN.x, vp.y / UI_DESIGN.y)
	hud.scale = Vector2(ratio, ratio)


func toggle_phase() -> void:
	night_mode = not night_mode
	atmosphere.set_night(night_mode, paused)
	if paused:
		world.tick(0.0, atmosphere.nightness, atmosphere.rain_amount, quality_high)
		post.tick(0.0, atmosphere.nightness, atmosphere.rain_amount)
	hud.show_toast("夜色漫上来，萤火醒了。" if night_mode else "晨光落在苔上，水塘亮了。")
	hud.sync_from_main()


func toggle_weather() -> void:
	rain_mode = not rain_mode
	atmosphere.set_weather(rain_mode, paused)
	if paused:
		world.tick(0.0, atmosphere.nightness, atmosphere.rain_amount, quality_high)
		post.tick(0.0, atmosphere.nightness, atmosphere.rain_amount)
	hud.show_toast("细雨落进池塘，风铃也湿了。" if rain_mode else "云散开，月光重新落在石径上。")
	hud.sync_from_main()


func toggle_quality() -> void:
	quality_high = not quality_high
	world.set_quality(quality_high)
	atmosphere.set_quality(quality_high)
	post.set_quality(quality_high)
	world.tick(0.0, atmosphere.nightness, atmosphere.rain_amount, quality_high)
	hud.show_toast("画质：高 · 草叶与萤火全开" if quality_high else "画质：低 · 保留庭院轮廓与灯光")
	hud.sync_from_main()


func toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	if rig != null:
		rig.set_process(not paused)
	if interaction != null:
		interaction.enabled = not paused
		if paused:
			interaction.reset()
	hud.sync_from_main()
	if paused:
		hud.show_toast("庭院静止 · P 或按钮继续")
	else:
		hud.show_toast("时间重新流动")


func toggle_hud() -> void:
	hud_visible = not hud_visible
	hud.set_ui_visible(hud_visible)
	if not hud_visible:
		hud.set_markers([])


func toggle_debug() -> void:
	debug_overlay = not debug_overlay
	hud.set_debug_visible(debug_overlay)


func reset_demo() -> void:
	if paused:
		paused = false
		get_tree().paused = false
		if rig != null:
			rig.set_process(true)
		if interaction != null:
			interaction.enabled = true
	night_mode = true
	rain_mode = false
	quality_high = true
	atmosphere.reset()
	world.reset_state()
	rig.reset()
	post.set_quality(true)
	post.reset()
	if interaction != null:
		interaction.reset()
	hud_visible = true
	hud.set_ui_visible(true)
	hud.set_fps_visible(_fps_visible)
	debug_overlay = false
	hud.set_debug_visible(false)
	hud.sync_from_main()
	hud.show_toast("庭院回到最初的夜。")
	_update_stats(true)


func _on_interaction_feedback(id: String, message: String, _anchor: Vector3) -> void:
	if hud != null:
		hud.show_toast(message)
	if audio != null:
		match id:
			"lantern_path", "lantern_water":
				audio.play_lantern()
			"wind_chime":
				audio.play_chime()
			"moss_cat":
				audio.play_cat()


# ── 工具 / 验收 API ─────────────────────────────────────────────────────

func demo_set_phase(night: bool, immediate := true) -> void:
	night_mode = night
	atmosphere.set_night(night, immediate)
	if immediate:
		world.tick(0.0, atmosphere.nightness, atmosphere.rain_amount, quality_high)
		post.tick(0.0, atmosphere.nightness, atmosphere.rain_amount)
	hud.sync_from_main()


func demo_set_weather(rain: bool, immediate := true) -> void:
	rain_mode = rain
	atmosphere.set_weather(rain, immediate)
	if immediate:
		world.tick(0.0, atmosphere.nightness, atmosphere.rain_amount, quality_high)
		post.tick(0.0, atmosphere.nightness, atmosphere.rain_amount)
	hud.sync_from_main()


func demo_set_quality(high: bool) -> void:
	quality_high = high
	world.set_quality(high)
	atmosphere.set_quality(high)
	post.set_quality(high)
	world.tick(0.0, atmosphere.nightness, atmosphere.rain_amount, quality_high)
	hud.sync_from_main()


func demo_set_view(yaw: float, pitch: float, dist: float,
		focus := Vector3(0.0, 2.0, 0.45), auto := false) -> void:
	rig.set_view(yaw, pitch, dist, focus, auto)


func demo_set_paused(value: bool) -> void:
	if paused != value:
		toggle_pause()


func demo_set_hud_visible(value: bool) -> void:
	hud_visible = value
	hud.set_ui_visible(value)


func demo_set_fps_visible(value: bool) -> void:
	_fps_visible = value
	hud.set_fps_visible(value)


func demo_set_markers_visible(value: bool) -> void:
	_markers_visible = value
	hud.set_markers_visible(value)


func demo_interact(id: String) -> bool:
	for target in world.get_interaction_targets():
		if target.get_display_id() == id:
			return target.interact()
	return false


func demo_focus_target(id: String) -> void:
	if interaction != null:
		interaction.set_forced_hover(id)


func demo_clear_focus() -> void:
	if interaction != null:
		interaction.clear_forced_hover()


func demo_reset() -> void:
	reset_demo()


func demo_apply_ui_scale() -> void:
	_apply_ui_scale()


func get_fps() -> int:
	return _fps


func get_draw_calls() -> int:
	return _draw_calls


func get_triangles() -> int:
	return _triangles


func get_state() -> Dictionary:
	return {
		"night": night_mode,
		"rain": rain_mode,
		"quality_high": quality_high,
		"paused": paused,
		"nightness": atmosphere.nightness,
		"rain_amount": atmosphere.rain_amount,
		"fps": _fps,
		"draw_calls": _draw_calls,
		"triangles": _triangles,
		"interactables": world.get_interaction_targets().size(),
	}


func get_target_info() -> Array:
	var out: Array = []
	for target in world.get_interaction_targets():
		out.append({
			"id": target.get_display_id(),
			"name": target.get_display_name(),
			"anchor": target.get_interaction_anchor(),
		})
	return out
