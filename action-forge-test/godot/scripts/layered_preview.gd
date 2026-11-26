extends Node3D

## T-013 preview: Action Forge built-in Walk Loop (whole body) vs the same walk
## with an upper-body Idle Talking layer, both retargeted to KayKit Rogue.
## Left: base walk (in-place). Right: layered walk (in-place). V: base walk root-motion export.
## The layered composite root-motion export was not baked in this build; see docs.
## Space pause, B bones, C auto-orbit, H HUD, 1-6 camera, drag/wheel orbit/zoom.

const OrbitCameraScript := preload("res://scripts/orbit_camera.gd")
const BoneDebugScript := preload("res://scripts/bone_debug.gd")
const BASE_INPLACE := preload("res://assets/Rogue_WalkLoop_AF_inplace.glb")
const LAYER_INPLACE := preload("res://assets/Rogue_Walk_IdleTalkLayer_AF_inplace.glb")
const BASE_ROOTMOTION := preload("res://assets/Rogue_WalkLoop_AF_rootmotion.glb")

const BASE_TEXT := "Rogue · Walk Loop base (in-place)"
const LAYER_TEXT := "Rogue · Walk + Idle Talking upper layer (in-place)"
const ROOT_TEXT := "Rogue · Walk Loop base root-motion (0.337 m)"

var cam
var hud: CanvasLayer
var info_label: Label
var state_label: Label
var help_label: Label
var fps_label: Label

var base_actor: Dictionary
var layer_actor: Dictionary
var root_actor: Dictionary
var bones: Array = []

var paused := false
var bones_on := false
var root_shown := false
var demo_mode := false
var demo_t := 0.0
var demo_bones_on_done := false
var demo_bones_off_done := false
var demo_root_on_done := false
var demo_root_off_done := false
var demo_hud_hidden := false
var demo_side1_done := false
var demo_side2_done := false
var bench_mode := false
var bench_t := 0.0
var bench_samples: Array[int] = []
var shot_path := ""
var shot_delay := 1.6
var shot_done := false
var nohud := false
var boot_preset := 0
var boot_phase := -1.0
var still := false
var render_size := Vector2i.ZERO
var elapsed := 0.0

func _ready() -> void:
	_parse_args()
	_build_environment()
	_build_ground()
	base_actor = _spawn(BASE_INPLACE, Vector3(-1.05, 0, 0), 0.0, BASE_TEXT)
	layer_actor = _spawn(LAYER_INPLACE, Vector3(1.05, 0, 0), 0.0, LAYER_TEXT)
	root_actor = _spawn(BASE_ROOTMOTION, Vector3(0, 0, -1.8), 0.0, ROOT_TEXT)
	root_actor["node"].visible = false
	root_actor["label"].visible = false
	_build_camera()
	_build_hud()
	if nohud:
		hud.visible = false
	_setup_playback()
	_add_bone_debug(base_actor)
	_add_bone_debug(layer_actor)
	_add_bone_debug(root_actor)
	_measure()
	if boot_preset > 0:
		cam.preset(boot_preset)
	if still:
		cam.auto_orbit = false
	if boot_phase >= 0.0:
		for actor in [base_actor, layer_actor]:
			var ap: AnimationPlayer = actor["ap"]
			if ap:
				ap.seek(boot_phase, true)
				ap.speed_scale = 0.0
		paused = true
	if demo_mode:
		cam.auto_orbit = false
		cam.preset(1)
	print("LAYERED_BOOT base_bones=%d layer_bones=%d base_len=%.4f layer_len=%.4f" % [
		_skeleton_of(base_actor).get_bone_count(), _skeleton_of(layer_actor).get_bone_count(),
		_anim_len(base_actor), _anim_len(layer_actor)])

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo_mode = true
		elif a == "--bench":
			bench_mode = true
		elif a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-delay="):
			shot_delay = float(a.trim_prefix("--shot-delay="))
		elif a == "--nohud":
			nohud = true
		elif a.begins_with("--preset="):
			boot_preset = int(a.trim_prefix("--preset="))
		elif a.begins_with("--phase="):
			boot_phase = float(a.trim_prefix("--phase="))
		elif a == "--still":
			still = true
		elif a.begins_with("--render-size="):
			var rs := a.trim_prefix("--render-size=").split("x")
			if rs.size() == 2:
				render_size = Vector2i(int(rs[0]), int(rs[1]))

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.06, 0.10, 0.18)
	sm.sky_horizon_color = Color(0.30, 0.36, 0.46)
	sm.ground_bottom_color = Color(0.05, 0.06, 0.09)
	sm.ground_horizon_color = Color(0.16, 0.19, 0.26)
	sm.sky_energy_multiplier = 1.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 28, 0)
	key.light_energy = 2.6
	key.light_color = Color(1.0, 0.95, 0.86)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 18.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -55, 0)
	fill.light_energy = 1.2
	fill.light_color = Color(0.65, 0.78, 1.0)
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 168, 0)
	rim.light_energy = 1.4
	rim.light_color = Color(0.45, 0.72, 1.0)
	add_child(rim)
	var stage := OmniLight3D.new()
	stage.position = Vector3(0, 2.6, 1.6)
	stage.light_energy = 1.3
	stage.omni_range = 9.0
	stage.light_color = Color(0.72, 0.82, 1.0)
	add_child(stage)
	# Front fill for stills/interactive; disabled in --demo because the extra
	# directional light clipped the 8-bit Movie Maker AVI capture in this scene.
	if not demo_mode:
		var front := DirectionalLight3D.new()
		front.rotation_degrees = Vector3(-16, 0, 0)
		front.light_energy = 2.0
		front.light_color = Color(1.0, 0.93, 0.84)
		front.shadow_enabled = false
		add_child(front)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, cull_back;
uniform vec3 base_color : source_color = vec3(0.11, 0.13, 0.17);
uniform vec3 line_color : source_color = vec3(0.34, 0.42, 0.54);
uniform vec3 accent_color : source_color = vec3(0.48, 0.66, 0.85);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 f = abs(fract(world_pos.xz) - 0.5);
	vec2 f5 = abs(fract(world_pos.xz * 5.0) - 0.5);
	float major = max(smoothstep(0.465, 0.5, f.x), smoothstep(0.465, 0.5, f.y));
	float minor = max(smoothstep(0.46, 0.5, f5.x), smoothstep(0.46, 0.5, f5.y));
	vec3 col = mix(base_color, line_color, major * 0.8);
	col = mix(col, accent_color * 0.5, minor * 0.22);
	float d = length(world_pos.xz);
	col *= mix(0.65, 1.15, smoothstep(7.0, 1.0, d));
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mi.material_override = mat
	add_child(mi)

func _spawn(scene: PackedScene, pos: Vector3, yaw: float, label_text: String) -> Dictionary:
	var node: Node3D = scene.instantiate()
	node.position = pos
	node.rotation_degrees = Vector3(0, yaw, 0)
	add_child(node)
	var sk := _find_skeleton(node)
	var ap := _find_anim_player(node)
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 36
	label.pixel_size = 0.0018
	label.outline_size = 10
	label.modulate = Color(0.85, 0.95, 1.0)
	label.outline_modulate = Color(0.01, 0.02, 0.03, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.0, 0)
	node.add_child(label)
	return {"node": node, "sk": sk, "ap": ap, "label": label, "label_text": label_text}

func _build_camera() -> void:
	cam = OrbitCameraScript.new()
	cam.name = "OrbitCamera"
	add_child(cam)
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 100.0
	cam.preset(2)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.name = "DetailPanel"
	panel.position = Vector2(14, 12)
	panel.custom_minimum_size = Vector2(660, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.025, 0.045, 0.82)
	sb.border_color = Color(0.18, 0.72, 0.95, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "ACTION FORGE → GODOT 4.6 · LAYERS (T-013)"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	vbox.add_child(info_label)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
	vbox.add_child(state_label)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	vbox.add_child(fps_label)
	help_label = Label.new()
	help_label.text = "SPACE pause   B bones   V base root-motion   C auto-orbit   H HUD   1-6 camera   drag / wheel"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	vbox.add_child(help_label)

func _setup_playback() -> void:
	for actor in [base_actor, layer_actor]:
		var ap: AnimationPlayer = actor["ap"]
		if ap == null or ap.get_animation_list().is_empty():
			continue
		var an: Animation = ap.get_animation(ap.get_animation_list()[0])
		an.loop_mode = Animation.LOOP_LINEAR
		ap.play(ap.get_animation_list()[0])
		ap.seek(0, true)
		ap.speed_scale = 1.0
		var lab: Label3D = actor["label"]
		lab.text = "%s\n%d bones · %.3f s · %d tracks" % [actor["label_text"], _skeleton_of(actor).get_bone_count(), an.length, an.get_track_count()]
	var rap: AnimationPlayer = root_actor["ap"]
	if rap:
		rap.play(rap.get_animation_list()[0])
		rap.seek(0, true)
		rap.speed_scale = 0.0

func _measure() -> void:
	var bi := _track_drift(base_actor, "root")
	var li := _track_drift(layer_actor, "root")
	var lr := _track_drift(root_actor, "root")
	var ws := _world_scale(base_actor)
	info_label.text = "L  Walk Loop retargeted by Action Forge — whole body\nR  Walk Loop + upper-body Idle Talking layer — same 41-bone Rogue"
	state_label.text = "Root XZ drift (world): base in-place %.1f cm · layered in-place %.1f cm · base root-motion %.0f cm (layered composite root-motion not baked)" % [
		bi * ws * 100.0, li * ws * 100.0, lr * ws * 100.0]
	help_label.text += "\nLayer mask/weight and leg-vs-arm deltas are printed by tools/smoke_layered.gd."

func _track_drift(actor: Dictionary, bone: String) -> float:
	var ap: AnimationPlayer = actor["ap"]
	if ap == null or ap.get_animation_list().is_empty():
		return 0.0
	var an: Animation = ap.get_animation(ap.get_animation_list()[0])
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not str(an.track_get_path(t)).ends_with(":" + bone):
			continue
		for k in an.track_get_key_count(t):
			var v: Vector3 = an.track_get_key_value(t, k)
			mn = mn.min(v); mx = mx.max(v)
	if mx.x == -INF:
		return 0.0
	return Vector2(mx.x - mn.x, mx.z - mn.z).length()

func _add_bone_debug(actor: Dictionary) -> void:
	var sk: Skeleton3D = actor["sk"]
	if sk == null:
		return
	var bd = BoneDebugScript.new()
	bd.name = "BoneDebug"
	sk.add_child(bd)
	bd.setup(sk)
	bd.enabled = false
	bones.append(bd)

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r != null:
			return r
	return null

func _skeleton_of(actor: Dictionary) -> Skeleton3D:
	return actor["sk"] as Skeleton3D

func _world_scale(actor: Dictionary) -> float:
	var sk: Skeleton3D = actor["sk"]
	if sk == null:
		return 1.0
	return sk.global_transform.basis.get_scale().x

func _anim_len(actor: Dictionary) -> float:
	var ap: AnimationPlayer = actor["ap"]
	if ap == null or ap.get_animation_list().is_empty():
		return 0.0
	return ap.get_animation(ap.get_animation_list()[0]).length

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			paused = not paused
			for actor in [base_actor, layer_actor]:
				var ap: AnimationPlayer = actor["ap"]
				if ap: ap.speed_scale = 0.0 if paused else 1.0
			if root_shown and root_actor["ap"]:
				root_actor["ap"].speed_scale = 0.0 if paused else 1.0
		KEY_B:
			bones_on = not bones_on
			for b in bones:
				b.enabled = bones_on
		KEY_V:
			root_shown = not root_shown
			root_actor["node"].visible = root_shown
			root_actor["label"].visible = root_shown
			if root_shown:
				root_actor["ap"].seek(0, true)
				root_actor["ap"].speed_scale = 0.0 if paused else 1.0
		KEY_C:
			cam.auto_orbit = not cam.auto_orbit
		KEY_H:
			hud.visible = not hud.visible
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			cam.preset(event.keycode - KEY_0)

func _process(delta: float) -> void:
	elapsed += delta
	if demo_mode:
		demo_t += delta
		if demo_t >= 1.2 and not demo_hud_hidden:
			demo_hud_hidden = true
			var panel := hud.get_node_or_null("DetailPanel") as Control
			if panel: panel.visible = false
		if demo_t >= 2.0 and not demo_bones_on_done:
			demo_bones_on_done = true
			bones_on = true
			for b in bones: b.enabled = true
		if demo_t >= 4.2 and not demo_bones_off_done:
			demo_bones_off_done = true
			bones_on = false
			for b in bones: b.enabled = false
		if demo_t >= 5.0 and not demo_root_on_done:
			demo_root_on_done = true
			root_shown = true
			root_actor["node"].visible = true
			root_actor["label"].visible = true
			root_actor["ap"].seek(0, true)
			root_actor["ap"].speed_scale = 1.0
		if demo_t >= 7.0 and not demo_root_off_done:
			demo_root_off_done = true
			root_shown = false
			root_actor["node"].visible = false
			root_actor["label"].visible = false
	if fps_label:
		fps_label.text = "FPS %d · render %s · %s" % [Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name(), "%dx%d" % [get_window().size.x, get_window().size.y]]
	if shot_path != "" and not shot_done and elapsed >= shot_delay:
		shot_done = true
		_capture_shot()
	if bench_mode:
		bench_t += delta
		if bench_t > 2.0:
			bench_samples.append(Engine.get_frames_per_second())
		if bench_t > 9.0:
			_finish_bench()

func _capture_shot() -> void:
	if render_size != Vector2i.ZERO:
		var sv := SubViewport.new()
		sv.size = render_size
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.world_3d = get_world_3d()
		sv.transparent_bg = false
		add_child(sv)
		var sc := Camera3D.new()
		sc.fov = cam.fov
		sc.near = cam.near
		sc.far = cam.far
		sv.add_child(sc)
		sc.global_transform = cam.global_transform
		sc.current = true
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img2 := sv.get_texture().get_image()
		var err2 := img2.save_png(shot_path)
		print("SHOT_SAVED=%s err=%d size=%dx%d" % [shot_path, err2, img2.get_width(), img2.get_height()])
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(shot_path)
	print("SHOT_SAVED=%s err=%d size=%dx%d" % [shot_path, err, img.get_width(), img.get_height()])
	get_tree().quit()

func _finish_bench() -> void:
	var total := 0
	var mn := 100000
	var mx := 0
	for f in bench_samples:
		total += f
		mn = mini(mn, f)
		mx = maxi(mx, f)
	var avg := float(total) / maxf(1.0, float(bench_samples.size()))
	print("BENCH_FPS_AVG=%.1f BENCH_FPS_MIN=%d BENCH_FPS_MAX=%d SAMPLES=%d RENDERER=%s WINDOW=%s" % [
		avg, mn, mx, bench_samples.size(), RenderingServer.get_video_adapter_name(), "%dx%d" % [get_window().size.x, get_window().size.y]])
	get_tree().quit()
