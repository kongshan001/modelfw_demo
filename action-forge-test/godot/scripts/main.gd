extends Node3D

## Action Forge -> Godot 4.6 retarget preview.
## Left: Rogue retargeted by Action Forge (in-place). Right: Michelle, the Mixamo source clip.
## V shows the same Action Forge export with root motion; B draws skeletons.
## Space pause, C auto-orbit, 1-6 camera presets, drag/wheel to orbit/zoom.

const OrbitCameraScript := preload("res://scripts/orbit_camera.gd")
const BoneDebugScript := preload("res://scripts/bone_debug.gd")
const AF_INPLACE := preload("res://assets/Rogue_MichelleWalk_AF_inplace.glb")
const AF_ROOTMOTION := preload("res://assets/Rogue_MichelleWalk_AF_rootmotion.glb")
const AF_ANIMONLY := preload("res://assets/Rogue_MichelleWalk_AF_inplace_animonly.glb")
const MICHELLE := preload("res://assets/Michelle_Walk_source.glb")
const ROGUE_ORIGINAL := preload("res://assets/Rogue_original.glb")

const AF_CLIP_HINT := "Michelle Walk_fit"
const AF_YAW := 180.0
const MICHELLE_YAW := 0.0

var cam
var hud: CanvasLayer
var fps_label: Label
var state_label: Label
var info_label: Label
var warn_label: Label
var help_label: Label

var af_inplace: Dictionary
var af_root: Dictionary
var michelle: Dictionary
var bones: Array = []

var paused := false
var bones_on := false
var root_shown := false
var demo_mode := false
var demo_t := 0.0
var bench_mode := false
var bench_t := 0.0
var bench_samples: Array[int] = []
var shot_path := ""
var shot_delay := 1.6
var shot_done := false
var nohud := false
var boot_bones := false
var boot_root := false
var boot_preset := 0
var boot_phase := -1.0
var still := false
var render_size := Vector2i.ZERO
var elapsed := 0.0
var boot_printed := false
var demo_bones_on_done := false
var demo_bones_off_done := false
var demo_root_on_done := false
var demo_root_off_done := false
var demo_side_done := false
var demo_hud_hidden := false

func _ready() -> void:
	_parse_args()
	_build_environment()
	_build_ground()
	af_inplace = _spawn(AF_INPLACE, Vector3(-1.1, 0, 0), AF_YAW, "Rogue · Action Forge (in-place)", 2.00)
	michelle = _spawn(MICHELLE, Vector3(1.1, 0, 0), MICHELLE_YAW, "Michelle · Mixamo source", 1.86)
	af_root = _spawn(AF_ROOTMOTION, Vector3(0, 0, -1.7), AF_YAW, "Rogue · Action Forge (root motion)", 2.00)
	af_root["node"].visible = false
	_set_labels_visible(af_root, false)
	_build_camera()
	_build_hud()
	if nohud:
		hud.visible = false
	_setup_playback()
	_add_bone_debug(af_inplace)
	_add_bone_debug(michelle)
	_add_bone_debug(af_root)
	_measure_exports()
	if boot_preset > 0:
		cam.preset(boot_preset)
	if still:
		cam.auto_orbit = false
	if boot_phase >= 0.0:
		for key in ["af_inplace", "michelle"]:
			var ap: AnimationPlayer = self[key]["ap"]
			if ap:
				ap.seek(boot_phase, true)
				ap.speed_scale = 0.0
		paused = true
	if boot_bones:
		bones_on = true
		for b in bones: b.enabled = true
	if boot_root:
		root_shown = true
		af_root["node"].visible = true
		af_root["ap"].seek(0, true)
		af_root["ap"].speed_scale = 1.0
	if demo_mode:
		cam.auto_orbit = true
		cam.preset(2)
	print("PREVIEW_BOOT actors=3 af_bones=%d michelle_bones=%d clip_af=%.4fs clip_ref=%.4fs" % [
		_skeleton_of(af_inplace).get_bone_count(),
		_skeleton_of(michelle).get_bone_count(),
		_anim_len(af_inplace), _anim_len(michelle)])
	boot_printed = true

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
		elif a == "--bones":
			boot_bones = true
		elif a == "--root":
			boot_root = true
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
	fill.shadow_enabled = false
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 168, 0)
	rim.light_energy = 1.4
	rim.light_color = Color(0.45, 0.72, 1.0)
	rim.shadow_enabled = false
	add_child(rim)
	var stage := OmniLight3D.new()
	stage.position = Vector3(0, 2.6, 1.2)
	stage.light_energy = 1.3
	stage.omni_range = 9.0
	stage.light_color = Color(0.72, 0.82, 1.0)
	stage.shadow_enabled = false
	add_child(stage)

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
	mi.position = Vector3.ZERO
	add_child(mi)

func _spawn(scene: PackedScene, pos: Vector3, yaw: float, label_text: String, label_y: float) -> Dictionary:
	var node: Node3D = scene.instantiate()
	node.position = pos
	node.rotation_degrees = Vector3(0, yaw, 0)
	add_child(node)
	var sk := _find_skeleton(node)
	var ap := _find_anim_player(node)
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 38
	label.pixel_size = 0.0018
	label.outline_size = 10
	label.modulate = Color(0.85, 0.95, 1.0)
	label.outline_modulate = Color(0.01, 0.02, 0.03, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = Vector3(0, label_y, 0)
	node.add_child(label)
	return {"node": node, "sk": sk, "ap": ap, "label": label, "sub": label, "label_text": label_text}

func _set_labels_visible(actor: Dictionary, v: bool) -> void:
	(actor["label"] as Label3D).visible = v

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
	var title_layer := CanvasLayer.new()
	title_layer.name = "TitleLayer"
	add_child(title_layer)
	var titlebar := Label.new()
	titlebar.text = "ACTION FORGE → GODOT 4.6 · RETARGET PREVIEW    ·    Rogue (Action Forge, in-place) vs Michelle (Mixamo source)"
	titlebar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlebar.anchor_left = 0.0
	titlebar.anchor_right = 1.0
	titlebar.offset_left = 0
	titlebar.offset_right = 0
	titlebar.offset_top = 10
	titlebar.add_theme_font_size_override("font_size", 18)
	titlebar.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	titlebar.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	titlebar.add_theme_constant_override("outline_size", 4)
	titlebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(titlebar)
	var panel := PanelContainer.new()
	panel.name = "DetailPanel"
	panel.position = Vector2(14, 12)
	panel.custom_minimum_size = Vector2(600, 0)
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
	title.text = "ACTION FORGE → GODOT 4.6 · RETARGET PREVIEW"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	vbox.add_child(title)
	var rule := HSeparator.new()
	vbox.add_child(rule)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	vbox.add_child(info_label)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
	vbox.add_child(state_label)
	warn_label = Label.new()
	warn_label.add_theme_font_size_override("font_size", 12)
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn_label.custom_minimum_size = Vector2(570, 0)
	vbox.add_child(warn_label)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	vbox.add_child(fps_label)
	help_label = Label.new()
	help_label.text = "SPACE pause   B bones   V root-motion   C auto-orbit   H HUD   1-6 camera   drag / wheel"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	vbox.add_child(help_label)

func _setup_playback() -> void:
	for key in ["af_inplace", "af_root", "michelle"]:
		var actor: Dictionary = self[key]
		var ap: AnimationPlayer = actor["ap"]
		if ap == null:
			continue
		var names := ap.get_animation_list()
		if names.is_empty():
			continue
		var an: Animation = ap.get_animation(names[0])
		an.loop_mode = Animation.LOOP_LINEAR
		ap.play(names[0])
		ap.seek(0, true)
		ap.speed_scale = 1.0
		var lab: Label3D = actor["label"]
		lab.text = "%s\n%d bones · %.3f s · %s" % [actor["label_text"], _skeleton_of(actor).get_bone_count(), an.length, names[0]]
	af_root["ap"].speed_scale = 0.0

func _measure_exports() -> void:
	var inplace_drift := _track_drift(af_inplace, "root")
	var root_drift := _track_drift(af_root, "root")
	var hip_bob := _track_y_range(af_inplace, "hips")
	var hip_bob_ref := _track_y_range(michelle, "mixamorig_Hips")
	info_label.text = "L  Rogue · Action Forge retarget (in-place) — 41 bones\nR  Michelle · Mixamo source — 65 bones, same 1.033 s clip"
	var ws_af := _world_scale(af_inplace)
	var ws_ref := _world_scale(michelle)
	state_label.text = "Root XZ drift: in-place %.1f cm · root-motion %.1f cm   |   hips local Y %.1f cm (source %.1f cm)" % [
		inplace_drift * ws_af * 100.0, root_drift * ws_af * 100.0, hip_bob * ws_af * 100.0, hip_bob_ref * ws_ref * 100.0]
	var anim_only_note := _anim_only_check()
	warn_label.text = anim_only_note

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
		var path := str(an.track_get_path(t))
		if not path.ends_with(":" + bone):
			continue
		for k in an.track_get_key_count(t):
			var v: Vector3 = an.track_get_key_value(t, k)
			mn = mn.min(v)
			mx = mx.max(v)
	if mx.x == -INF:
		return 0.0
	return Vector2(mx.x - mn.x, mx.z - mn.z).length()

func _track_y_range(actor: Dictionary, bone: String) -> float:
	var ap: AnimationPlayer = actor["ap"]
	if ap == null or ap.get_animation_list().is_empty():
		return 0.0
	var an: Animation = ap.get_animation(ap.get_animation_list()[0])
	var lo := INF
	var hi := -INF
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path := str(an.track_get_path(t))
		if not path.ends_with(":" + bone):
			continue
		for k in an.track_get_key_count(t):
			var v: Vector3 = an.track_get_key_value(t, k)
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
	if hi == -INF:
		return 0.0
	return hi - lo

func _anim_only_check() -> String:
	var ps: PackedScene = load("res://assets/Rogue_MichelleWalk_AF_inplace_animonly.glb")
	if ps == null:
		return "Animation-only export: could not load."
	var inst: Node = ps.instantiate()
	var ap := _find_anim_player(inst)
	var has_sk := _find_skeleton(inst) != null
	var note := "Animation-only export: no Skeleton3D (node names only)."
	if ap and not ap.get_animation_list().is_empty():
		var an: Animation = ap.get_animation(ap.get_animation_list()[0])
		var dotted := 0
		var sanitized := 0
		var sk := _skeleton_of(af_inplace)
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).contains("."):
				dotted += 1
		for t in an.get_track_count():
			var p := str(an.track_get_path(t))
			if p.contains("upperarm_l") or p.contains("lowerleg_r") or p.contains("handslot_l"):
				sanitized += 1
		note = "Anim-only GLB: %d tracks, no Skeleton3D; Godot renames upperarm.l → upperarm_l (%d dotted bones) → not directly bindable. Use the character GLB." % [
			an.get_track_count(), dotted]
	inst.free()
	return note

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
			for key in ["af_inplace", "michelle"]:
				var ap: AnimationPlayer = self[key]["ap"]
				if ap: ap.speed_scale = 0.0 if paused else 1.0
			if root_shown:
				af_root["ap"].speed_scale = 0.0 if paused else 1.0
		KEY_B:
			bones_on = not bones_on
			for b in bones:
				b.enabled = bones_on
		KEY_V:
			root_shown = not root_shown
			af_root["node"].visible = root_shown
			_set_labels_visible(af_root, root_shown)
			if root_shown:
				af_root["ap"].seek(0, true)
				af_root["ap"].speed_scale = 0.0 if paused else 1.0
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
		if demo_t >= 1.4 and not demo_hud_hidden:
			demo_hud_hidden = true
			var panel := hud.get_node_or_null("DetailPanel") as Control
			if panel: panel.visible = false
		if demo_t >= 2.4 and not demo_bones_on_done:
			demo_bones_on_done = true
			bones_on = true
			for b in bones: b.enabled = true
		if demo_t >= 4.8 and not demo_bones_off_done:
			demo_bones_off_done = true
			bones_on = false
			for b in bones: b.enabled = false
		if demo_t >= 5.2 and not demo_root_on_done:
			demo_root_on_done = true
			root_shown = true
			af_root["node"].visible = true
			_set_labels_visible(af_root, true)
			af_root["ap"].seek(0, true)
			af_root["ap"].speed_scale = 1.0
		if demo_t >= 8.4 and not demo_root_off_done:
			demo_root_off_done = true
			root_shown = false
			af_root["node"].visible = false
			_set_labels_visible(af_root, false)
		if demo_t >= 9.2 and not demo_side_done:
			demo_side_done = true
			cam.preset(3)
	if fps_label:
		fps_label.text = "FPS %d · render %s · %s" % [Engine.get_frames_per_second(), _renderer_name(), _window_size()]
	if shot_path != "" and not shot_done and elapsed >= shot_delay:
		shot_done = true
		_capture_shot()
	if bench_mode:
		bench_t += delta
		if bench_t > 2.0:
			bench_samples.append(Engine.get_frames_per_second())
		if bench_t > 9.0:
			_finish_bench()

func _renderer_name() -> String:
	return RenderingServer.get_video_adapter_name()

func _window_size() -> String:
	var s := get_window().size
	return "%dx%d" % [s.x, s.y]

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
		avg, mn, mx, bench_samples.size(), _renderer_name(), _window_size()])
	get_tree().quit()
