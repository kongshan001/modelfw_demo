extends Node3D

## Godot 4.6 preview for the MediaPipe fast-mode reproduction retargeted to
## KayKit Rogue. Space pause, B bones, C auto-orbit, H HUD, 1-4 camera,
## mouse drag/wheel. --demo for recording, --shot, --bench for acceptance.

const OrbitCameraScript := preload("res://scripts/orbit_camera.gd")
const BoneDebugScript := preload("res://scripts/bone_debug.gd")
const DEFAULT_GLB := "res://assets/Rogue_MediaPipe_walk.glb"

var cam
var hud: CanvasLayer
var info_label: Label
var state_label: Label
var help_label: Label
var fps_label: Label
var actor: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var bones
var clip_name := ""
var clip_len := 0.0
var bone_count := 0
var mesh_count := 0

var paused := false
var bones_on := false
var demo_mode := false
var bench_mode := false
var shot_path := ""
var shot_delay := 1.6
var shot_done := false
var nohud := false
var still := false
var boot_phase := -1.0
var boot_preset := 2
var glb_path := DEFAULT_GLB
var demo_t := 0.0

var bench_t := 0.0
var bench_frames := 0
var bench_elapsed := 0.0
var bench_done := false

var foot_info := {}

func _ready() -> void:
	_parse_args()
	_build_environment()
	_build_ground()
	_load_actor()
	_build_camera()
	_build_hud()
	if nohud:
		hud.visible = false
	if boot_preset > 0:
		cam.preset(boot_preset)
	if still:
		cam.auto_orbit = false
	if boot_phase >= 0.0 and ap:
		ap.seek(boot_phase, true)
		ap.speed_scale = 0.0
		paused = true
	if demo_mode:
		cam.auto_orbit = true
		cam.auto_speed = 5.0
		cam.preset(2)
	await get_tree().process_frame
	await _measure()
	bones.enabled = bones_on
	state_label.text = "clip %s · %.3f s · %d bones · %d meshes" % [clip_name, clip_len, bone_count, mesh_count]
	if not foot_info.is_empty():
		state_label.text += "\nfoot min %+.1f cm · stance slide %.3f m · hip bounce %.1f cm" % [
			foot_info.get("min_foot_y", 0.0) * 100.0,
			foot_info.get("max_ground_slide", 0.0),
			foot_info.get("hip_y_range", 0.0) * 100.0]
	print("PREVIEW_BOOT clip=%s len=%.4f bones=%d meshes=%d foot_min=%.4f slide=%.4f" % [
		clip_name, clip_len, bone_count, mesh_count, foot_info.get("min_foot_y", 0.0),
		foot_info.get("max_ground_slide", 0.0)])

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo": demo_mode = true
		elif a == "--bench": bench_mode = true
		elif a.begins_with("--shot="): shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-delay="): shot_delay = float(a.trim_prefix("--shot-delay="))
		elif a == "--nohud": nohud = true
		elif a == "--still": still = true
		elif a == "--bones": bones_on = true
		elif a.begins_with("--preset="): boot_preset = int(a.trim_prefix("--preset="))
		elif a.begins_with("--phase="): boot_phase = float(a.trim_prefix("--phase="))
		elif a.begins_with("--glb="): glb_path = a.trim_prefix("--glb=")
		elif a == "--help":
			print("args: --demo --bench --shot=path --nohud --still --preset=N --phase=F --glb=res://...")
			get_tree().quit()

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
	env.ambient_light_energy = 1.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.5
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 28, 0)
	key.light_energy = 2.8
	key.light_color = Color(1.0, 0.95, 0.86)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 18.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -55, 0)
	fill.light_energy = 2.0
	fill.light_color = Color(0.65, 0.78, 1.0)
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 168, 0)
	rim.light_energy = 1.7
	rim.light_color = Color(0.45, 0.72, 1.0)
	add_child(rim)
	var stage := OmniLight3D.new()
	stage.position = Vector3(0, 2.6, 1.6)
	stage.light_energy = 2.0
	stage.omni_range = 9.0
	stage.light_color = Color(0.72, 0.82, 1.0)
	add_child(stage)
	# A 4th directional light clips the 8-bit Movie Maker capture in this
	# GL Compatibility scene (same issue as action-forge-test T-013).
	if not demo_mode:
		var front := DirectionalLight3D.new()
		front.rotation_degrees = Vector3(-16, 0, 0)
		front.light_energy = 1.7
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

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls): return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null

func _find_named(n: Node, target: String) -> Node:
	if n.name == target: return n
	for c in n.get_children():
		var r := _find_named(c, target)
		if r: return r
	return null

func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children(): c += _count_meshes(ch)
	return c

func _load_actor() -> void:
	var ps: PackedScene = load(glb_path)
	if ps == null:
		push_error("cannot load " + glb_path)
		return
	actor = ps.instantiate()
	add_child(actor)
	sk = _find(actor, "Skeleton3D") as Skeleton3D
	ap = _find(actor, "AnimationPlayer") as AnimationPlayer
	bone_count = sk.get_bone_count() if sk else 0
	mesh_count = _count_meshes(actor)
	# Hide KayKit weapon props; this test is about body motion.
	for weapon in ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]:
		var w := _find_named(actor, weapon)
		if w: w.visible = false
	if ap and not ap.get_animation_list().is_empty():
		clip_name = ap.get_animation_list()[0]
		var an := ap.get_animation(clip_name)
		an.loop_mode = Animation.LOOP_LINEAR
		clip_len = an.length
		ap.play(clip_name)
	bones = BoneDebugScript.new()
	bones.name = "BoneDebug"
	sk.add_child(bones)
	bones.setup(sk)

func _build_camera() -> void:
	cam = OrbitCameraScript.new()
	cam.name = "OrbitCamera"
	add_child(cam)
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 100.0
	cam.preset(boot_preset)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.size = Vector2(640, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.035, 0.06, 0.82)
	sb.border_color = Color(0.32, 0.52, 0.72, 0.65)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	hud.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 18)
	vb.add_child(info_label)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 15)
	vb.add_child(state_label)
	help_label = Label.new()
	help_label.add_theme_font_size_override("font_size", 14)
	help_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.84))
	vb.add_child(help_label)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color(0.62, 0.85, 0.72))
	hud.add_child(fps_label)
	fps_label.position = Vector2(20, 676)
	info_label.text = "MediaPipe fast-mode → KayKit Rogue"
	state_label.text = "clip %s · %.3f s · %d bones · %d meshes" % [clip_name, clip_len, bone_count, mesh_count]
	help_label.text = "Space pause · B bones · C orbit · H HUD · 1-4 camera · drag/wheel"
	if still:
		help_label.text = "still frame · %s" % glb_path

func _process(delta: float) -> void:
	if not hud.visible: return
	fps_label.text = "FPS %d · %s" % [Engine.get_frames_per_second(), "bones ON" if bones_on else "bones off"]
	if demo_mode:
		demo_t += delta
		if demo_t > 6.0 and hud.visible:
			hud.visible = false
	if bench_mode and not bench_done:
		bench_frames += 1
		bench_elapsed += delta
		if bench_elapsed > 5.0:
			bench_done = true
			var avg := bench_frames / bench_elapsed
			print("BENCH_FPS_AVG=%.1f MIN=0 MAX=0 FRAMES=%d WINDOW=%s" % [
				avg, bench_frames, str(get_viewport().get_visible_rect().size)])
	if shot_path != "" and not shot_done:
		shot_delay -= delta
		if shot_delay <= 0.0:
			shot_done = true
			_capture(shot_path)
	if bench_done:
		get_tree().quit()

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT " + path + " " + str(img.get_size()))
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				paused = not paused
				ap.paused = paused
			KEY_B:
				bones_on = not bones_on
				bones.enabled = bones_on
			KEY_C:
				cam.auto_orbit = not cam.auto_orbit
			KEY_H:
				hud.visible = not hud.visible
			KEY_1, KEY_2, KEY_3, KEY_4:
				cam.preset(event.keycode - KEY_0)
			KEY_R:
				ap.seek(0.0, true)

func _seek(t: float) -> void:
	ap.seek(t, true)
	await get_tree().process_frame

func _measure() -> void:
	if sk == null or ap == null:
		return
	var feet := ["foot.l", "foot.r", "toes.l", "toes.r"]
	var idxs := []
	for f in feet:
		var i := sk.find_bone(f)
		if i >= 0: idxs.append(i)
	var samples := 40
	var min_y := 1e9
	var frames: Array = []
	var hips_y_min := 1e9
	var hips_y_max := -1e9
	for s in samples:
		await _seek(clip_len * float(s) / float(samples - 1))
		var pos: Array = []
		for i in idxs:
			pos.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
		frames.append(pos)
		for p in pos: min_y = minf(min_y, p.y)
		var hi := sk.find_bone("hips")
		if hi >= 0:
			var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(hi).origin
			hips_y_min = minf(hips_y_min, hp.y); hips_y_max = maxf(hips_y_max, hp.y)
	var contact := 0
	for f in frames:
		for p in f:
			if p.y <= min_y + 0.03: contact += 1
	var worst_slide := 0.0
	var longest := 0
	for fi in idxs.size():
		var run_start := -1
		for s in frames.size():
			var g: bool = frames[s][fi].y <= min_y + 0.03
			if g and run_start < 0: run_start = s
			if (not g or s == frames.size() - 1) and run_start >= 0:
				var endi := s - 1 if not g else s
				var run_len := endi - run_start + 1
				if run_len > longest: longest = run_len
				var first: Vector3 = frames[run_start][fi]
				var last: Vector3 = frames[endi][fi]
				worst_slide = maxf(worst_slide, Vector2(last.x - first.x, last.z - first.z).length())
				run_start = -1
	var max_scale_dev := 0.0
	for s in 7:
		await _seek(clip_len * float(s) / 6.0)
		for i in sk.get_bone_count():
			var sc := sk.get_bone_pose_scale(i)
			max_scale_dev = maxf(max_scale_dev, maxf(absf(sc.x - 1.0), maxf(absf(sc.y - 1.0), absf(sc.z - 1.0))))
	foot_info = {
		"min_foot_y": min_y, "contact_frames": contact, "max_ground_slide": worst_slide,
		"longest_contact": longest, "hip_y_range": hips_y_max - hips_y_min,
		"max_scale_dev": max_scale_dev,
	}
	print("PREVIEW_DATA min_foot_y=%.4f contact=%d stance_slide=%.4f longest=%d hip_y_range=%.4f scale_dev=%.6f" % [
		min_y, contact, worst_slide, longest, hips_y_max - hips_y_min, max_scale_dev])
	if not still:
		ap.seek(0.0, true)
