extends Node3D

## T-023 walk-direction lab.
##
## Findings this scene demonstrates (measured in tools/diag_facing.gd + diag_gait.gd):
##   * KayKit Rogue's rest forward is +Z (toes/hip line), not Godot's -Z.
##   * Action Forge's Quaternius "Walk Loop" clip is +Z aligned (0 deg).
##   * Action Forge's Mixamo "Michelle Walk" clip keeps a ~180 deg hips yaw:
##     body + boots face -Z while the model faces +Z -> back-walk (moonwalk).
##   * The fix is a 180 deg hips yaw baked into that clip
##     (exports/Rogue_MichelleWalk_AF_inplace_yawfix.glb), not a global mesh spin.
##
## RAW vs FIXED duo: both actors move along the same 4-direction path with the
## actor yaw following the movement direction. RAW (unsafe) keeps the -Z clip,
## so its body is always backwards; FIXED uses the baked +180 hips clip.
##
## Controls: WASD/arrows 8-dir, Shift run, 1 Idle, 2 Walk, 3 Dance, 4 Clip,
## 5 RAW/FIXED, P auto-path, C camera, H HUD, R reset, Space pause.
## Run flags: --demo=walk|dance|mixed, --duo, --clip=..., --calib=raw|fixed,
## --speed=, --shot=, --render-size=, --nohud, --bench, --phase=, --still.

const AF_WALK := preload("res://assets/Rogue_WalkLoop_AF_inplace.glb")
const MICHELLE_RAW := preload("res://assets/Rogue_MichelleWalk_AF_inplace.glb")
const MICHELLE_FIX := preload("res://assets/Rogue_MichelleWalk_AF_inplace_yawfix.glb")
const ROGUE_ORIGINAL := preload("res://assets/Rogue_original.glb")
const DANCE_PATH := "res://assets/Rogue_IdolChickenDance_original.glb"
const POS_SCALE_ORIG := 0.8032  # AF rig is 0.8032x the original KayKit rig

const HIDE_MESHES := ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]
const PATH_CORNERS := [Vector3(-1.25, 0, -1.25), Vector3(1.25, 0, -1.25), Vector3(1.25, 0, 1.25), Vector3(-1.25, 0, 1.25)]
const LEG_COLORS := [Color(0.25, 0.85, 1.0), Color(0.35, 1.0, 0.55), Color(1.0, 0.72, 0.28), Color(1.0, 0.38, 0.78)]

const CLIPS := {
	"michelle_fix": {
		"label": "Michelle Walk · hips yaw fixed",
		"anim": "Michelle Walk_fit_yawfix",
		"source": "michelle_fix",
		"offset_note": "+180° hips baked",
		"base_speed": 0.62,
	},
	"michelle_raw": {
		"label": "Michelle Walk · raw",
		"anim": "Michelle Walk_fit",
		"source": "michelle_raw",
		"offset_note": "0° (clip faces -Z)",
		"base_speed": 0.62,
	},
	"quat": {
		"label": "Quaternius Walk Loop",
		"anim": "walk_loop_fit",
		"source": "af_walk",
		"offset_note": "0° (already +Z)",
		"base_speed": 0.55,
	},
}

var cam: Camera3D
var hud: CanvasLayer
var stats_label: Label
var clip_label: Label
var status_label: Label
var help_label: Label
var fps_label: Label
var title_layer: CanvasLayer
var title_label: Label
var path_nodes: Array = []
var stage_disc: MeshInstance3D
var stage_mat: StandardMaterial3D
var ring_outer: MeshInstance3D
var dance_lights: Array = []
var cam_dir_light: DirectionalLight3D
var cam_spot: SpotLight3D
var button_panel: PanelContainer
var buttons: Dictionary = {}
var legend_label: Label

var actors: Array = []
var duo := false
var demo_mode := ""
var clip_mode := "michelle_fix"
var calib_fixed := true
var path_mode := false
var speed := 0.80
var paused := false
var forced_walk := false
var elapsed := 0.0
var demo_t := 0.0
var dance_started := false
var dance_stopped := false
var camera_mode := 0  # 0 fixed-wide, 1 follow, 2 dance-close, 3 top
var hud_on := true

var shot_path := ""
var shot_delay := 2.0
var shot_done := false
var render_size := Vector2i.ZERO
var still := false
var bench_mode := false
var bench_t := 0.0
var bench_samples: Array[int] = []
var boot_phase := -1.0
var nohud := false
var fullhud := false
var demo_bar: PanelContainer
var demo_bar_label: Label

var test_dir := Vector3.ZERO
var test_active := false
var scratch_anim: AnimationPlayer
var dance_clip := ""

var _tmp_sources: Dictionary = {}
var _src_cache: Dictionary = {}

var dance_ring: MeshInstance3D
var ring_mat: StandardMaterial3D
var ring_base_scale := 1.0

func _ready() -> void:
	_parse_args()
	_build_environment()
	_build_ground()
	_build_path_markers()
	await _load_sources()
	var dance_loaded := _load_dance_source()
	if demo_mode == "walk":
		duo = true
		path_mode = true
		camera_mode = 0
	elif demo_mode == "dance":
		camera_mode = 2
	elif demo_mode == "mixed":
		path_mode = true
		camera_mode = 1
	elif duo:
		path_mode = true
		camera_mode = 0
	if nohud:
		hud_on = false
	_build_actors()
	_build_camera()
	_build_hud()
	if nohud:
		hud.visible = false
		title_layer.visible = false
	if path_mode:
		for a in actors:
			a["path_index"] = _nearest_path_index(a["node"].position, a["path_offset"])
	if demo_mode == "dance":
		_set_state("dance")
		_set_dance_stage(true)
	if boot_phase >= 0.0:
		_apply_phase(boot_phase)
		paused = true
	print("WALKMOVE_BOOT actors=%d duo=%s clip=%s dance=%s speed=%.2f" % [
		actors.size(), duo, clip_mode, dance_clip, speed])
	_register_buttons()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			demo_mode = "walk"
		elif a.begins_with("--demo="):
			demo_mode = a.trim_prefix("--demo=")
		elif a == "--duo":
			duo = true
		elif a == "--path":
			path_mode = true
		elif a.begins_with("--clip="):
			clip_mode = a.trim_prefix("--clip=")
		elif a.begins_with("--calib="):
			calib_fixed = a.trim_prefix("--calib=") != "raw"
		elif a.begins_with("--speed="):
			speed = float(a.trim_prefix("--speed="))
		elif a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-delay="):
			shot_delay = float(a.trim_prefix("--shot-delay="))
		elif a.begins_with("--render-size="):
			var rs := a.trim_prefix("--render-size=").split("x")
			if rs.size() == 2:
				render_size = Vector2i(int(rs[0]), int(rs[1]))
		elif a == "--nohud":
			nohud = true
		elif a == "--fullhud":
			fullhud = true
		elif a == "--bench":
			bench_mode = true
		elif a.begins_with("--phase="):
			boot_phase = float(a.trim_prefix("--phase="))
		elif a == "--still":
			still = true
		elif a.begins_with("--cam="):
			camera_mode = int(a.trim_prefix("--cam="))

# ---------------------------------------------------------------- scene art

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.10, 0.14, 0.24)
	sm.sky_horizon_color = Color(0.38, 0.44, 0.56)
	sm.ground_bottom_color = Color(0.06, 0.07, 0.11)
	sm.ground_horizon_color = Color(0.20, 0.24, 0.33)
	sm.sky_energy_multiplier = 0.9
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.62, 0.82)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.10
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, 32, 0)
	key.light_energy = 2.75
	key.light_color = Color(1.0, 0.94, 0.84)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 18.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -60, 0)
	fill.light_energy = 1.0
	fill.light_color = Color(0.55, 0.74, 1.0)
	fill.shadow_enabled = false
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-26, 168, 0)
	rim.light_energy = 1.5
	rim.light_color = Color(0.55, 0.62, 1.0)
	rim.shadow_enabled = false
	add_child(rim)
	var front := DirectionalLight3D.new()
	front.rotation_degrees = Vector3(-24, 42, 0)
	front.light_energy = 1.7
	front.light_color = Color(1.0, 0.92, 0.84)
	front.shadow_enabled = false
	add_child(front)
	var side := DirectionalLight3D.new()
	side.rotation_degrees = Vector3(-30, -35, 0)
	side.light_energy = 1.0
	side.light_color = Color(0.7, 0.85, 1.0)
	side.shadow_enabled = false
	add_child(side)
	var stage := OmniLight3D.new()
	stage.position = Vector3(0, 2.8, 2.0)
	stage.light_energy = 1.4
	stage.omni_range = 10.0
	stage.light_color = Color(0.85, 0.78, 1.0)
	stage.shadow_enabled = false
	add_child(stage)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 26)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, cull_back;
uniform vec3 base_color : source_color = vec3(0.075, 0.09, 0.13);
uniform vec3 line_color : source_color = vec3(0.26, 0.34, 0.46);
uniform vec3 accent_color : source_color = vec3(0.35, 0.62, 0.88);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 f = abs(fract(world_pos.xz) - 0.5);
	vec2 f5 = abs(fract(world_pos.xz * 5.0) - 0.5);
	float major = max(smoothstep(0.465, 0.5, f.x), smoothstep(0.465, 0.5, f.y));
	float minor = max(smoothstep(0.46, 0.5, f5.x), smoothstep(0.46, 0.5, f5.y));
	vec3 col = mix(base_color, line_color, major * 0.75);
	col = mix(col, accent_color * 0.45, minor * 0.20);
	float d = length(world_pos.xz);
	col *= mix(0.60, 1.15, smoothstep(8.0, 1.0, d));
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mi.material_override = mat
	add_child(mi)

func _flat_mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _build_path_markers() -> void:
	for i in PATH_CORNERS.size():
		var a: Vector3 = PATH_CORNERS[i]
		var b: Vector3 = PATH_CORNERS[(i + 1) % PATH_CORNERS.size()]
		var mid := (a + b) * 0.5
		var d := b - a
		var length := d.length()
		var box := BoxMesh.new()
		box.size = Vector3(length, 0.012, 0.075)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = _flat_mat(LEG_COLORS[i], 0.6)
		mi.position = Vector3(mid.x, 0.014, mid.z)
		mi.rotation.y = atan2(d.x, d.z) - PI * 0.5
		add_child(mi)
		path_nodes.append(mi)
		# arrow head at 72% along the leg
		var head := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.13
		cone.height = 0.30
		cone.radial_segments = 12
		head.mesh = cone
		head.material_override = _flat_mat(LEG_COLORS[i], 0.8)
		var p := a + d * 0.72
		head.position = Vector3(p.x, 0.045, p.z)
		head.rotation = Vector3(PI * 0.5, 0, 0)
		head.rotate_y(atan2(d.x, d.z))
		add_child(head)
		path_nodes.append(head)
		var lab := Label3D.new()
		lab.text = ["MOVE +X", "MOVE +Z", "MOVE −X", "MOVE −Z"][i]
		lab.font_size = 30
		lab.pixel_size = 0.0032
		lab.outline_size = 8
		lab.modulate = LEG_COLORS[i]
		lab.outline_modulate = Color(0.01, 0.02, 0.03, 0.9)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = Vector3(mid.x, 0.55, mid.z)
		add_child(lab)
		path_nodes.append(lab)
	# corner posts
	for a in PATH_CORNERS:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.05
		cyl.height = 0.42
		post.mesh = cyl
		post.material_override = _flat_mat(Color(0.5, 0.75, 0.95), 0.5)
		post.position = Vector3(a.x, 0.21, a.z)
		add_child(post)
		path_nodes.append(post)
	# dance ring
	dance_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.70
	torus.rings = 48
	torus.ring_segments = 8
	dance_ring.mesh = torus
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.42, 0.78)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.35, 0.75)
	ring_mat.emission_energy_multiplier = 2.2
	dance_ring.material_override = ring_mat
	dance_ring.position = Vector3(0, 0.025, 0)
	dance_ring.visible = false
	add_child(dance_ring)
	# outer ring
	ring_outer = MeshInstance3D.new()
	var torus2 := TorusMesh.new()
	torus2.inner_radius = 1.55
	torus2.outer_radius = 1.60
	torus2.rings = 64
	torus2.ring_segments = 6
	ring_outer.mesh = torus2
	var rm2 := StandardMaterial3D.new()
	rm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm2.albedo_color = Color(0.55, 0.55, 1.0)
	rm2.emission_enabled = true
	rm2.emission = Color(0.45, 0.5, 1.0)
	rm2.emission_energy_multiplier = 1.1
	ring_outer.material_override = rm2
	ring_outer.position = Vector3(0, 0.02, 0)
	ring_outer.visible = false
	add_child(ring_outer)
	# stage disc
	stage_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.1
	disc.bottom_radius = 2.1
	disc.height = 0.07
	disc.radial_segments = 64
	stage_disc.mesh = disc
	stage_mat = StandardMaterial3D.new()
	stage_mat.albedo_color = Color(0.035, 0.045, 0.075)
	stage_mat.roughness = 0.42
	stage_mat.metallic = 0.25
	stage_mat.emission_enabled = true
	stage_mat.emission = Color(0.08, 0.05, 0.14)
	stage_mat.emission_energy_multiplier = 0.8
	stage_disc.material_override = stage_mat
	stage_disc.position = Vector3(0, -0.035, 0)
	stage_disc.visible = false
	add_child(stage_disc)
	# stage lights (dance only)
	var warm := SpotLight3D.new()
	warm.light_energy = 3.2
	warm.light_color = Color(1.0, 0.82, 0.66)
	warm.spot_range = 10.0
	warm.spot_angle = 46.0
	warm.shadow_enabled = false
	add_child(warm)
	warm.position = Vector3(-2.6, 3.2, 2.6)
	warm.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	warm.visible = false
	dance_lights.append(warm)
	var rim := SpotLight3D.new()
	rim.light_energy = 2.0
	rim.light_color = Color(0.48, 0.58, 1.0)
	rim.spot_range = 9.0
	rim.spot_angle = 44.0
	rim.shadow_enabled = false
	add_child(rim)
	rim.position = Vector3(1.8, 2.6, -2.4)
	rim.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	rim.visible = false
	dance_lights.append(rim)
	var floor_glow := OmniLight3D.new()
	floor_glow.light_energy = 0.6
	floor_glow.light_color = Color(0.7, 0.5, 1.0)
	floor_glow.omni_range = 4.5
	floor_glow.shadow_enabled = false
	add_child(floor_glow)
	floor_glow.position = Vector3(0, 0.35, 0.4)
	floor_glow.visible = false
	dance_lights.append(floor_glow)

func _make_arrow(color: Color) -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.055, 0.012, 0.46)
	shaft.mesh = box
	shaft.material_override = _flat_mat(color, 0.9)
	shaft.position = Vector3(0, 0.028, 0.23)
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.085
	cone.height = 0.17
	cone.radial_segments = 12
	head.mesh = cone
	head.material_override = _flat_mat(color, 0.9)
	head.position = Vector3(0, 0.028, 0.52)
	head.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(head)
	return root

# ---------------------------------------------------------------- actors

func _load_sources() -> void:
	_tmp_sources["af_walk"] = AF_WALK.instantiate()
	_tmp_sources["michelle_raw"] = MICHELLE_RAW.instantiate()
	_tmp_sources["michelle_fix"] = MICHELLE_FIX.instantiate()
	_tmp_sources["original"] = ROGUE_ORIGINAL.instantiate()
	for k in _tmp_sources:
		add_child(_tmp_sources[k])
	await get_tree().process_frame
	for k in _tmp_sources:
		var ap := _find_ap(_tmp_sources[k])
		if ap and not ap.get_animation_list().is_empty():
			var an_name := String(ap.get_animation_list()[0])
			_src_cache[k] = {"clip": an_name, "anim": ap.get_animation(an_name).duplicate(true)}
	# Idle is grafted from the larger original rig; position tracks are scaled.
	if _src_cache.has("original"):
		var oap := _find_ap(_tmp_sources["original"])
		if oap and oap.has_animation("Idle"):
			_src_cache["idle_anim"] = oap.get_animation("Idle").duplicate(true)
	for k in _tmp_sources:
		_tmp_sources[k].queue_free()
	_tmp_sources.clear()

func _load_dance_source() -> bool:
	if not ResourceLoader.exists(DANCE_PATH):
		print("WALKMOVE_DANCE_MISSING %s" % DANCE_PATH)
		return false
	var inst: Node3D = load(DANCE_PATH).instantiate()
	add_child(inst)
	var ap := _find_ap(inst)
	if ap and not ap.get_animation_list().is_empty():
		var name := String(ap.get_animation_list()[0])
		_src_cache["dance_anim"] = ap.get_animation(name).duplicate(true)
		_src_cache["dance_scale"] = 1.0
		dance_clip = name
		print("WALKMOVE_DANCE_SRC %s len=%.3f" % [name, _src_cache["dance_anim"].length])
	inst.queue_free()
	return dance_clip != ""

func _build_actors() -> void:
	if duo:
		var off_a := Vector3(-0.90, 0, 0.90)
		var off_b := Vector3(0.90, 0, -0.90)
		var corner: Vector3 = PATH_CORNERS[0]
		actors.append(_spawn_actor(corner + off_a, "michelle_raw", "RAW · clip -Z", Color(1.0, 0.42, 0.34), off_a))
		actors.append(_spawn_actor(corner + off_b, "michelle_fix", "FIXED · hips +180°", Color(0.4, 1.0, 0.55), off_b))
	else:
		var start: Vector3 = PATH_CORNERS[0] if path_mode else Vector3(0, 0, 1.2)
		if demo_mode == "dance":
			start = Vector3(0, 0, 0)
		var c := Color(0.4, 1.0, 0.55)
		var label := "WALK LAB"
		if clip_mode == "michelle_raw":
			c = Color(1.0, 0.42, 0.34)
			label = "RAW · clip -Z"
		elif clip_mode == "michelle_fix":
			label = "FIXED · hips +180°"
		elif clip_mode == "quat":
			label = "QUAT · +Z aligned"
		actors.append(_spawn_actor(start, clip_mode, label, c, Vector3.ZERO))

func _spawn_actor(pos: Vector3, clip_id: String, label_text: String, label_color: Color, path_offset: Vector3) -> Dictionary:
	var node := Node3D.new()
	node.name = "Walker_" + clip_id
	node.position = pos
	add_child(node)
	var model: Node3D = AF_WALK.instantiate()
	node.add_child(model)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if HIDE_MESHES.has(String(m.name)):
			(m as MeshInstance3D).visible = false
	var sk := _find_skel(model)
	var ap := _find_ap(model)
	var prefix := _track_prefix(ap)
	_graft_all(ap, prefix, sk)
	# rest foot rotations in world space at actor yaw 0 (for boot-forward measurement)
	var rest_l := Quaternion.IDENTITY
	var rest_r := Quaternion.IDENTITY
	if sk:
		var il := sk.find_bone("foot.l")
		var ir := sk.find_bone("foot.r")
		if il >= 0:
			rest_l = sk.get_bone_global_pose(il).basis.get_rotation_quaternion()
		if ir >= 0:
			rest_r = sk.get_bone_global_pose(ir).basis.get_rotation_quaternion()
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 34
	label.pixel_size = 0.0018
	label.outline_size = 10
	label.modulate = label_color
	label.outline_modulate = Color(0.01, 0.02, 0.03, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = Vector3(0, 2.05, 0)
	node.add_child(label)
	var move_arrow := _make_arrow(Color(0.25, 0.95, 0.65))
	var face_arrow := _make_arrow(Color(1.0, 0.35, 0.30))
	add_child(move_arrow)
	add_child(face_arrow)
	var marker := MeshInstance3D.new()
	var mt := TorusMesh.new()
	mt.inner_radius = 0.40
	mt.outer_radius = 0.47
	mt.rings = 40
	mt.ring_segments = 6
	marker.mesh = mt
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = label_color
	mm.emission_enabled = true
	mm.emission = label_color
	mm.emission_energy_multiplier = 1.6
	marker.material_override = mm
	add_child(marker)
	marker.position = node.position + Vector3(0, 0.02, 0)
	marker.visible = false
	move_arrow.position = Vector3(0, 0.01, 0)
	face_arrow.position = Vector3(0, 0.01, 0)
	move_arrow.visible = false
	face_arrow.visible = false
	var actor := {
		"node": node, "model": model, "sk": sk, "ap": ap, "prefix": prefix,
		"label": label, "label_text": label_text, "label_color": label_color,
		"rest_foot_l": rest_l, "rest_foot_r": rest_r,
		"clip_id": clip_id, "state": "idle", "desired": Vector3.ZERO,
		"moving": false, "path_offset": path_offset, "path_index": 0,
		"move_arrow": move_arrow, "face_arrow": face_arrow, "marker_ring": marker,
		"body_err": 0.0, "boot_err": 0.0, "body_yaw": 0.0, "move_yaw": 0.0,
		"frame_err": 0.0, "frame_boot_err": 0.0, "frame_body_yaw": 0.0,
		"anim_speed": 1.0, "distance": 0.0, "last_pos": node.position,
		"anim_name": "Idle_grafted",
	}
	if ap and ap.has_animation("Idle_grafted"):
		ap.play("Idle_grafted", 0.0)
	return actor

func _graft_all(target_ap: AnimationPlayer, prefix: String, sk: Skeleton3D) -> void:
	for id in CLIPS:
		var info: Dictionary = CLIPS[id]
		var src_key: String = info["source"]
		if not _src_cache.has(src_key):
			continue
		var anim_name: String = info["anim"]
		var an: Animation = (_src_cache[src_key]["anim"] as Animation).duplicate(true)
		_graft_into(an, target_ap, prefix, 1.0, anim_name, sk)
	# idle from the original, position-scaled
	if _src_cache.has("idle_anim"):
		var idle: Animation = (_src_cache["idle_anim"] as Animation).duplicate(true)
		_graft_into(idle, target_ap, prefix, POS_SCALE_ORIG, "Idle_grafted", sk)
	# dance (already authored on the AF rig, no scaling)
	if _src_cache.has("dance_anim"):
		var dance: Animation = (_src_cache["dance_anim"] as Animation).duplicate(true)
		_graft_into(dance, target_ap, prefix, 1.0, dance_clip, sk)

func _graft_into(an: Animation, target_ap: AnimationPlayer, prefix: String, pos_scale: float, new_name: String, sk: Skeleton3D) -> void:
	an.loop_mode = Animation.LOOP_LINEAR
	var mapped := 0
	for i in an.get_track_count():
		var path := str(an.track_get_path(i))
		var bone := path.get_slice(":", 1)
		if bone == "" or (sk != null and sk.find_bone(bone) < 0):
			continue
		an.track_set_path(i, prefix + ":" + bone)
		if an.track_get_type(i) == Animation.TYPE_POSITION_3D and not is_equal_approx(pos_scale, 1.0):
			for k in an.track_get_key_count(i):
				an.track_set_key_value(i, k, an.track_get_key_value(i, k) * pos_scale)
		mapped += 1
	var lib := target_ap.get_animation_library("")
	if lib.has_animation(new_name):
		lib.remove_animation(new_name)
	lib.add_animation(new_name, an)
	an.resource_name = new_name

func _track_prefix(ap: AnimationPlayer) -> String:
	if ap == null or ap.get_animation_list().is_empty():
		return ""
	var an := ap.get_animation(ap.get_animation_list()[0])
	for i in an.get_track_count():
		var p := str(an.track_get_path(i))
		if p.contains(":"):
			return p.get_slice(":", 0)
	return ""

# ---------------------------------------------------------------- state

func _target_anim(actor: Dictionary) -> String:
	var info: Dictionary = CLIPS.get(actor["clip_id"], CLIPS["michelle_fix"])
	return String(info["anim"])

func _play_clip(actor: Dictionary, clip_id: String, fade := 0.15) -> void:
	var info: Dictionary = CLIPS.get(clip_id, CLIPS["michelle_fix"])
	var an_name: String = info["anim"]
	var ap: AnimationPlayer = actor["ap"]
	if ap == null:
		return
	if not ap.has_animation(an_name):
		return
	ap.play(an_name, fade)
	actor["clip_id"] = clip_id
	actor["anim_name"] = an_name
	var base_speed: float = info["base_speed"]
	actor["anim_speed"] = clampf(speed / maxf(0.1, base_speed), 0.7, 1.7)

func _set_dance_stage(on: bool) -> void:
	for n in path_nodes:
		(n as Node).visible = not on
	stage_disc.visible = on
	ring_outer.visible = on
	dance_ring.visible = on
	for l in dance_lights:
		(l as Node).visible = on
	if cam_dir_light:
		cam_dir_light.light_energy = 1.2 if on else 3.0
	if cam_spot:
		cam_spot.light_energy = 4.0 if on else 8.0
	for a in actors:
		(a["label"] as Node3D).visible = not on
		(a["move_arrow"] as Node3D).visible = false
		(a["face_arrow"] as Node3D).visible = false
		(a["marker_ring"] as Node3D).visible = false
	if title_label:
		title_label.text = "IDOL-CHICK DANCE · ORIGINAL CHOREOGRAPHY (T-023) · KayKit Rogue (CC0) · no copyrighted music" if on else "IDOL FORGE · WALK DIRECTION LAB (T-023)    ·    model forward +Z    ·    RAW vs HIPS-YAW FIXED"

func _set_state(state: String) -> void:
	forced_walk = state == "walk"
	_set_dance_stage(state == "dance")
	if state == "dance":
		for a in actors:
			var n: Node3D = a["node"]
			stage_disc.global_position = Vector3(n.global_position.x, -0.035, n.global_position.z)
			ring_outer.global_position = Vector3(n.global_position.x, 0.02, n.global_position.z)
			dance_ring.global_position = Vector3(n.global_position.x, 0.025, n.global_position.z)
	if state == "dance" and demo_mode == "":
		camera_mode = 2
	elif state != "dance" and demo_mode == "":
		camera_mode = 1
	for a in actors:
		a["state"] = state
		var ap: AnimationPlayer = a["ap"]
		if ap == null:
			continue
		match state:
			"idle":
				a["moving"] = false
				if ap.has_animation("Idle_grafted"):
					ap.play("Idle_grafted", 0.2)
					a["anim_speed"] = 1.0
			"walk":
				_play_clip(a, a["clip_id"], 0.15)
			"dance":
				a["moving"] = false
				if dance_clip != "" and ap.has_animation(dance_clip):
					ap.play(dance_clip, 0.2)
					a["anim_speed"] = 1.0
					a["state"] = "dance"
	dance_ring.visible = state == "dance"

func _cycle_clip() -> void:
	var order := ["michelle_fix", "quat", "michelle_raw"]
	var idx := order.find(clip_mode)
	clip_mode = order[(idx + 1) % order.size()]
	if clip_mode == "michelle_raw":
		calib_fixed = false
	elif clip_mode == "michelle_fix":
		calib_fixed = true
	for a in actors:
		a["clip_id"] = clip_mode
		if duo:
			# duo keeps its raw/fixed assignment
			a["clip_id"] = "michelle_raw" if actors.find(a) == 0 else "michelle_fix"
		if a["state"] == "walk" or a["moving"]:
			_play_clip(a, a["clip_id"], 0.15)
	_update_hud_static()

func _toggle_calib() -> void:
	calib_fixed = not calib_fixed
	if duo:
		return
	clip_mode = "michelle_fix" if calib_fixed else "michelle_raw"
	for a in actors:
		a["clip_id"] = clip_mode
		if a["state"] == "walk" or a["moving"]:
			_play_clip(a, clip_mode, 0.15)
	_update_hud_static()

func _toggle_path() -> void:
	path_mode = not path_mode
	if path_mode:
		for a in actors:
			a["path_index"] = _nearest_path_index(a["node"].position, a["path_offset"])
	_update_hud_static()

func _nearest_path_index(pos: Vector3, offset: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in PATH_CORNERS.size():
		var p: Vector3 = PATH_CORNERS[i] + offset
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best

func _set_test_direction(dir: Vector3) -> void:
	test_active = dir.length_squared() > 0.001
	test_dir = Vector3(dir.x, 0, dir.z).normalized()
	for a in actors:
		a["state"] = "walk" if test_active else "idle"
		if test_active:
			_play_clip(a, a["clip_id"], 0.1)
		else:
			_set_state("idle")

func _apply_phase(phase: float) -> void:
	for a in actors:
		var ap: AnimationPlayer = a["ap"]
		if ap and ap.has_animation("Michelle Walk_fit_yawfix"):
			ap.play("Michelle Walk_fit_yawfix", 0.0)
			ap.seek(phase * ap.get_animation("Michelle Walk_fit_yawfix").length, true)
			ap.speed_scale = 0.0
			a["state"] = "walk"

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	elapsed += delta
	if paused:
		delta = 0.0
	_update_demo(delta)
	_update_input(delta)
	for a in actors:
		_update_actor(a, delta)
	_update_camera(delta)
	_update_dance_ring(delta)
	_update_hud()
	if shot_path != "" and not shot_done and elapsed >= shot_delay:
		shot_done = true
		_capture_shot()
	if bench_mode:
		bench_t += delta
		if bench_t > 2.0:
			bench_samples.append(Engine.get_frames_per_second())
		if bench_t > 9.0:
			_finish_bench()

func _update_demo(delta: float) -> void:
	if demo_mode == "" or demo_mode == "walk":
		return
	demo_t += delta
	if demo_mode == "dance":
		if demo_t >= 0.5 and not dance_started:
			dance_started = true
			_set_state("dance")
		# keep looping through the end of the demo clip
	elif demo_mode == "mixed":
		if demo_t >= 1.0 and not dance_started:
			dance_started = true
			_set_state("walk")
			path_mode = true
			for a in actors:
				a["path_index"] = _nearest_path_index(a["node"].position, a["path_offset"])
		if demo_t >= 5.0 and path_mode:
			path_mode = false
			_set_state("dance")
			camera_mode = 2
		if demo_t >= 13.0:
			_set_state("idle")
			camera_mode = 1

func _update_input(delta: float) -> void:
	if test_active:
		for a in actors:
			a["desired"] = test_dir
			a["moving"] = true
		return
	var dir := Vector3.ZERO
	var allow_keyboard := not (demo_mode == "dance" or demo_mode == "walk")
	if demo_mode == "mixed":
		allow_keyboard = false
	if allow_keyboard:
		var iv := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			iv.y += 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			iv.y -= 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			iv.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			iv.x += 1
		if iv.length_squared() > 0.001:
			var cam_fwd := -cam.global_basis.z
			cam_fwd.y = 0
			cam_fwd = cam_fwd.normalized()
			var cam_right := cam.global_basis.x
			cam_right.y = 0
			cam_right = cam_right.normalized()
			dir = (cam_right * iv.x + cam_fwd * iv.y).normalized()
			if path_mode:
				path_mode = false
			if forced_walk:
				forced_walk = false
			for a in actors:
				if a["state"] == "dance":
					_set_state("walk")
	if dir.length_squared() > 0.001:
		for a in actors:
			a["desired"] = dir
			a["moving"] = true
			a["state"] = "walk"
			if a["ap"] and a["ap"].current_animation != _target_anim(a):
				_play_clip(a, a["clip_id"], 0.15)
	elif not path_mode:
		for a in actors:
			a["desired"] = Vector3.ZERO
			a["moving"] = false
			if a["state"] == "dance":
				continue
			if forced_walk:
				a["state"] = "walk"
				if a["ap"] and a["ap"].current_animation != _target_anim(a):
					_play_clip(a, a["clip_id"], 0.15)
			else:
				a["state"] = "idle"
				if a["ap"] and a["ap"].current_animation != "Idle_grafted":
					_set_state("idle")

func _update_actor(actor: Dictionary, delta: float) -> void:
	var node: Node3D = actor["node"]
	var desired: Vector3 = actor["desired"]
	var moving: bool = actor["moving"]
	if actor["state"] == "dance":
		moving = false
		actor["moving"] = false
		desired = Vector3.ZERO
	if path_mode and actor["state"] != "dance":
		var path := _path_points(actor["path_offset"])
		var idx: int = actor["path_index"]
		var target: Vector3 = path[idx]
		var to := Vector3(target.x - node.position.x, 0, target.z - node.position.z)
		if to.length() < 0.10:
			actor["path_index"] = (idx + 1) % path.size()
			target = path[actor["path_index"]]
			to = Vector3(target.x - node.position.x, 0, target.z - node.position.z)
		if to.length() > 0.001:
			desired = to.normalized()
			moving = true
			actor["moving"] = true
			actor["state"] = "walk"
			if actor["ap"] and actor["ap"].current_animation != _target_anim(actor):
				_play_clip(actor, actor["clip_id"], 0.15)
			actor["desired"] = desired
	if moving:
		var target_yaw := atan2(desired.x, desired.z)
		node.rotation.y = lerp_angle(node.rotation.y, target_yaw, minf(1.0, delta * 12.0))
		var step := speed * delta * (1.6 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		node.position += desired * step
		actor["distance"] = float(actor["distance"]) + step
		actor["move_yaw"] = rad_to_deg(target_yaw)
		actor["desired"] = desired
		if actor["ap"]:
			actor["ap"].speed_scale = float(actor["anim_speed"]) * (1.6 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	else:
		if actor["ap"]:
			actor["ap"].speed_scale = 1.0
		actor["move_yaw"] = node.rotation_degrees.y
	# measurement (one-frame lag is fine; smoothing handles it)
	_measure_actor(actor, delta)
	actor["last_pos"] = node.position

func _path_points(offset: Vector3) -> Array:
	var out := []
	for p in PATH_CORNERS:
		out.append(Vector3(p.x + offset.x, 0, p.z + offset.z))
	return out

func _measure_actor(actor: Dictionary, delta: float) -> void:
	var sk: Skeleton3D = actor["sk"]
	if sk == null:
		return
	var il := sk.find_bone("upperleg.l")
	var ir := sk.find_bone("upperleg.r")
	if il >= 0 and ir >= 0:
		var pl := sk.global_transform * sk.get_bone_global_pose(il).origin
		var pr := sk.global_transform * sk.get_bone_global_pose(ir).origin
		var right := Vector3(pr.x - pl.x, 0, pr.z - pl.z)
		if right.length() > 0.001:
			var f := Vector3.UP.cross(right.normalized())
			var body_yaw := rad_to_deg(atan2(f.x, f.z))
			var desired_yaw := float(actor["move_yaw"])
			var err := absf(rad_to_deg(angle_difference(deg_to_rad(desired_yaw), deg_to_rad(body_yaw))))
			actor["body_yaw"] = body_yaw
			actor["body_err"] = err
	var boot := Vector2.ZERO
	var qyaw := Basis(Vector3.UP, (actor["node"] as Node3D).rotation.y)
	var fl := _boot_fwd(sk, "foot.l", (actor["rest_foot_l"] as Quaternion), qyaw)
	var fr := _boot_fwd(sk, "foot.r", (actor["rest_foot_r"] as Quaternion), qyaw)
	if fl.length() > 0.01 and fr.length() > 0.01:
		boot = (fl + fr).normalized()
		var boot_yaw := rad_to_deg(atan2(boot.x, boot.y))
		var err2 := absf(rad_to_deg(angle_difference(deg_to_rad(float(actor["move_yaw"])), deg_to_rad(boot_yaw))))
		actor["boot_err"] = err2
	actor["frame_err"] = lerpf(float(actor["frame_err"]), float(actor["body_err"]), minf(1.0, delta * 10.0))
	actor["frame_boot_err"] = lerpf(float(actor["frame_boot_err"]), float(actor["boot_err"]), minf(1.0, delta * 10.0))

func _boot_fwd(sk: Skeleton3D, bone: String, rest_local: Quaternion, actor_yaw: Basis) -> Vector2:
	var i := sk.find_bone(bone)
	if i < 0:
		return Vector2.ZERO
	var q_pose_local := sk.get_bone_global_pose(i).basis.get_rotation_quaternion()
	var dq := q_pose_local * rest_local.inverse()
	var f := actor_yaw * (Basis(dq) * Vector3(0, 0, 1))
	return Vector2(f.x, f.z).normalized()

func _update_dance_ring(delta: float) -> void:
	var dancing := false
	for a in actors:
		if a["state"] == "dance":
			dancing = true
	dance_ring.visible = dancing
	if dancing:
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 0.5 + 0.5 * sin(t * TAU * 2.0)
		dance_ring.scale = Vector3.ONE * (1.0 + pulse * 0.06)
		ring_mat.emission_energy_multiplier = 1.5 + pulse * 2.5
		ring_outer.scale = Vector3.ONE * (1.0 + (1.0 - pulse) * 0.03)
		for a in actors:
			if a["state"] == "dance":
				var n: Node3D = a["node"]
				dance_ring.global_position = Vector3(n.global_position.x, 0.025, n.global_position.z)
				ring_outer.global_position = Vector3(n.global_position.x, 0.02, n.global_position.z)
				stage_disc.global_position = Vector3(n.global_position.x, -0.035, n.global_position.z)
				break

# ---------------------------------------------------------------- hud / camera

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 120.0
	var cam_dir := DirectionalLight3D.new()
	cam_dir.light_energy = 3.0
	cam_dir.light_color = Color(1.0, 0.95, 0.88)
	cam_dir.shadow_enabled = false
	cam.add_child(cam_dir)
	cam_dir_light = cam_dir
	var cam_fill := SpotLight3D.new()
	cam_fill.light_energy = 8.0
	cam_fill.light_color = Color(1.0, 0.94, 0.86)
	cam_fill.spot_range = 16.0
	cam_fill.spot_angle = 60.0
	cam_fill.spot_attenuation = 0.6
	cam_fill.shadow_enabled = false
	cam.add_child(cam_fill)
	cam_fill.position = Vector3(0, 0.1, 0.2)
	cam_spot = cam_fill
	add_child(cam)
	cam.current = true
	_apply_camera(0.0)

func _update_camera(delta: float) -> void:
	_apply_camera(delta)

func _apply_camera(delta: float) -> void:
	if cam == null:
		return
	var target := Vector3(0, 0.8, 0)
	var pos := Vector3(4.6, 3.4, 5.8)
	match camera_mode:
		0:
			target = Vector3(-0.20, 0.85, 0)
			pos = Vector3(4.7, 3.6, 6.2)
			cam.fov = 46.0
		1:
			var a: Dictionary = actors[0]
			var n: Node3D = a["node"]
			target = n.position + Vector3(0, 0.95, 0)
			pos = n.position + Vector3(0, 2.2, 3.4)
			cam.fov = 38.0
		2:
			target = Vector3(0, 0.95, 0)
			pos = Vector3(1.95, 1.72, 3.75)
			cam.fov = 34.0
		3:
			target = Vector3(0, 0.7, 0)
			pos = Vector3(0.1, 7.5, 0.1)
			cam.fov = 44.0
	if delta <= 0.0:
		cam.look_at_from_position(pos, target, Vector3.UP)
	else:
		var cur := cam.global_position
		var np := cur.lerp(pos, minf(1.0, delta * 4.0))
		var tgt := target
		cam.look_at_from_position(np, tgt, Vector3.UP)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleLayer"
	add_child(title_layer)
	var titlebar := Label.new()
	title_label = titlebar
	titlebar.text = "IDOL FORGE · WALK DIRECTION LAB (T-023)    ·    model forward +Z    ·    RAW vs HIPS-YAW FIXED"
	titlebar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlebar.anchor_left = 0.0
	titlebar.anchor_right = 1.0
	titlebar.offset_top = 10
	titlebar.add_theme_font_size_override("font_size", 18)
	titlebar.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	titlebar.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	titlebar.add_theme_constant_override("outline_size", 4)
	titlebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(titlebar)

	var panel := PanelContainer.new()
	panel.name = "DetailPanel"
	panel.position = Vector2(14, 46)
	panel.custom_minimum_size = Vector2(600, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style())
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "WALK DIRECTION LAB"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	clip_label = Label.new()
	clip_label.add_theme_font_size_override("font_size", 13)
	clip_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	vbox.add_child(clip_label)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size = Vector2(560, 0)
	vbox.add_child(stats_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
	vbox.add_child(status_label)
	legend_label = Label.new()
	legend_label.text = "green arrow = movement direction   ·   red arrow = measured body facing"
	legend_label.add_theme_font_size_override("font_size", 12)
	legend_label.add_theme_color_override("font_color", Color(0.62, 0.70, 0.82))
	vbox.add_child(legend_label)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 12)
	fps_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	vbox.add_child(fps_label)
	help_label = Label.new()
	help_label.text = "WASD 8-dir · Shift run · 1 Idle · 2 Walk · 3 Dance · 4 Clip · 5 RAW/FIXED · P path · C camera · H HUD · R reset"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.custom_minimum_size = Vector2(560, 0)
	vbox.add_child(help_label)

	button_panel = PanelContainer.new()
	button_panel.name = "Buttons"
	button_panel.anchor_left = 1.0
	button_panel.anchor_right = 1.0
	button_panel.offset_left = -196
	button_panel.offset_right = -14
	button_panel.offset_top = 46
	button_panel.add_theme_stylebox_override("panel", _panel_style())
	hud.add_child(button_panel)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	button_panel.add_child(bv)
	var btitle := Label.new()
	btitle.text = "STATES / CALIBRATION"
	btitle.add_theme_font_size_override("font_size", 12)
	btitle.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	bv.add_child(btitle)

func _register_buttons() -> void:
	var bv := button_panel.get_child(0) as VBoxContainer
	_add_button(bv, "1  Idle", func(): _set_state("idle"))
	_add_button(bv, "2  Walk", func(): _set_state("walk"))
	_add_button(bv, "3  Dance", func(): _set_state("dance"))
	_add_button(bv, "4  Clip", func(): _cycle_clip())
	_add_button(bv, "5  RAW / FIXED", func(): _toggle_calib())
	_add_button(bv, "P  Auto path", func(): _toggle_path())
	if demo_mode != "":
		button_panel.visible = false
	_build_demo_bar()
	_update_hud_static()

func _build_demo_bar() -> void:
	if demo_mode == "" or nohud:
		return
	demo_bar = PanelContainer.new()
	demo_bar.anchor_left = 0.5
	demo_bar.anchor_right = 0.5
	demo_bar.anchor_top = 1.0
	demo_bar.anchor_bottom = 1.0
	demo_bar.offset_left = -430
	demo_bar.offset_right = 430
	demo_bar.offset_top = -74
	demo_bar.offset_bottom = -16
	demo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.025, 0.045, 0.86)
	sb.border_color = Color(0.22, 0.78, 0.95, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	demo_bar.add_theme_stylebox_override("panel", sb)
	hud.add_child(demo_bar)
	demo_bar_label = Label.new()
	demo_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_bar_label.add_theme_font_size_override("font_size", 17)
	demo_bar_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	demo_bar.add_child(demo_bar_label)

func _add_button(parent: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	parent.add_child(b)
	buttons[text] = b

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.025, 0.045, 0.84)
	sb.border_color = Color(0.18, 0.72, 0.95, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _update_hud_static() -> void:
	if clip_label:
		if duo:
			clip_label.text = "duo: RAW clip (0°, faces −Z)   vs   FIXED clip (hips +180° bake)"
		else:
			var info: Dictionary = CLIPS.get(clip_mode, CLIPS["michelle_fix"])
			var calib_txt := "FIXED" if calib_fixed else "RAW"
			clip_label.text = "clip: %s   ·   calibration: %s (%s)" % [info["label"], calib_txt, info["offset_note"]]
	if status_label:
		var st := "idle"
		for a in actors:
			st = a["state"]
			break
		status_label.text = "state: %s   ·   speed %.2f m/s   ·   model +Z → controller yaw = atan2(x,z)" % [st.to_upper(), speed]

func _update_live_status() -> void:
	if status_label == null or actors.is_empty():
		return
	var st := String(actors[0]["state"])
	if duo and actors.size() > 1:
		st = "%s / %s" % [actors[0]["state"], actors[1]["state"]]
	status_label.text = "state: %s   ·   speed %.2f m/s   ·   model +Z → controller yaw = atan2(x,z)" % [st.to_upper(), speed]

func _update_hud() -> void:
	if hud == null or not hud_on:
		return
	var hide_at := 1.2 if demo_mode == "dance" else 3.0
	if demo_mode != "" and not fullhud and elapsed > hide_at:
		var dp := hud.get_node_or_null("DetailPanel") as Control
		if dp: dp.visible = false
	if fps_label:
		if shot_path != "":
			fps_label.visible = false
		else:
			fps_label.text = "FPS %d · %s · %dx%d" % [Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name(), get_window().size.x, get_window().size.y]
	var lines: Array[String] = []
	var in_dance := false
	for a in actors:
		if a["state"] == "dance":
			in_dance = true
	if in_dance:
		var a0: Dictionary = actors[0]
		var ap: AnimationPlayer = a0["ap"]
		var len := 8.0
		if ap and dance_clip != "" and ap.has_animation(dance_clip):
			len = ap.get_animation(dance_clip).length
		lines.append("DANCE · %s · %.2f s · LOOP" % [dance_clip, len])
		lines.append("original choreography: wing flap · hip sway · heart hands · 360 spin · knee bounce")
		lines.append("no copyrighted name / likeness / music / choreography · KayKit Rogue CC0")
		stats_label.text = "\n".join(lines)
		if demo_bar_label:
			demo_bar_label.text = "ORIGINAL IDOL-CHICK DANCE  ·  %.2f s loop  ·  no copyrighted music / choreography  ·  KayKit Rogue (CC0)" % len
		for a in actors:
			(a["move_arrow"] as Node3D).visible = false
			(a["face_arrow"] as Node3D).visible = false
			(a["marker_ring"] as Node3D).visible = false
		return
	for a in actors:
		var err := float(a["frame_err"])
		var boot := float(a["frame_boot_err"])
		var tag := "OK"
		if err > 120.0 or boot > 120.0:
			tag = "BACK-WALK"
		elif err > 35.0 or boot > 45.0:
			tag = "SIDE-STEP"
		var arrow := "→" if tag == "OK" else ("↔" if tag == "SIDE-STEP" else "⟲")
		lines.append("%s  %s  ·  body err %5.1f°  ·  boot err %5.1f°  ·  body yaw %+.0f° / move %+.0f°" % [
			arrow, a["label_text"], err, boot, float(a["body_yaw"]), float(a["move_yaw"])])
		var lab: Label3D = a["label"]
		lab.text = "%s\n%s  body err %.0f°" % [a["label_text"], tag, err]
		lab.modulate = a["label_color"] if tag == "OK" else Color(1.0, 0.55, 0.4)
	if not actors.is_empty():
		var a0: Dictionary = actors[0]
		lines.append("root yaw track 0° · Quat root-motion +Z 0.337 m")
		lines.append("clip forward: Quat 0° · Michelle raw −180° · fixed 0° (hips +180° bake)")
		if dance_clip != "":
			var ap: AnimationPlayer = a0["ap"]
			if ap and ap.has_animation(dance_clip):
				var dan := ap.get_animation(dance_clip)
				lines.append("dance %.2f s · loop · original choreography · no copyrighted music" % [dan.length])
	stats_label.text = "\n".join(lines)
	_update_live_status()
	if demo_bar_label:
		if demo_mode == "dance":
			demo_bar_label.text = "ORIGINAL IDOL-CHICK DANCE  ·  8.0 s loop  ·  no copyrighted music / choreography  ·  KayKit Rogue (CC0)"
		elif actors.size() >= 2:
			demo_bar_label.text = "RAW  %.0f° BACK-WALK   ·   FIXED  %.0f° OK   ·   green = movement / red = measured body facing" % [
				float(actors[0]["frame_err"]), float(actors[1]["frame_err"])]
		else:
			demo_bar_label.text = "%s  ·  body err %.0f°  ·  boot err %.0f°  ·  green = movement / red = facing" % [
				actors[0]["label_text"], float(actors[0]["frame_err"]), float(actors[0]["frame_boot_err"])]
	# arrows
	for a in actors:
		var n: Node3D = a["node"]
		var move_arrow: Node3D = a["move_arrow"]
		var face_arrow: Node3D = a["face_arrow"]
		var marker: Node3D = a["marker_ring"]
		marker.visible = duo and a["state"] != "dance"
		if marker.visible:
			marker.global_position = n.global_position + Vector3(0, 0.02, 0)
		var show: bool = a["state"] != "dance" and (bool(a["moving"]) or path_mode)
		move_arrow.visible = show
		face_arrow.visible = show
		if show:
			move_arrow.global_position = n.global_position + Vector3(0, 0, 0)
			move_arrow.rotation.y = deg_to_rad(float(a["move_yaw"]))
			face_arrow.global_position = n.global_position + Vector3(0, 0.015, 0)
			face_arrow.rotation.y = deg_to_rad(float(a["body_yaw"]))

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_set_state("idle")
		KEY_2:
			_set_state("walk")
		KEY_3:
			_set_state("dance")
		KEY_4:
			_cycle_clip()
		KEY_5:
			_toggle_calib()
		KEY_P:
			_toggle_path()
		KEY_H:
			hud_on = not hud_on
			hud.visible = hud_on
			title_layer.visible = hud_on
		KEY_C:
			camera_mode = (camera_mode + 1) % 4
		KEY_R:
			for a in actors:
				(a["node"] as Node3D).position = a["path_offset"] if path_mode else Vector3(0, 0, 1.2)
				(a["node"] as Node3D).rotation.y = 0.0
				a["path_index"] = 0
			_set_state("idle")
		KEY_SPACE:
			paused = not paused

func _capture_shot() -> void:
	if render_size != Vector2i.ZERO:
		var sv := SubViewport.new()
		sv.size = render_size
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.world_3d = get_world_3d()
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

# ---------------------------------------------------------------- helpers

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null

# ---------------------------------------------------------------- test api

func test_set_dir(dir: Vector3) -> void:
	_set_test_direction(dir)

func test_set_state(s: String) -> void:
	_set_state(s)

func test_actor_count() -> int:
	return actors.size()

func test_actor_debug(i := 0) -> Dictionary:
	var a: Dictionary = actors[i]
	var ap: AnimationPlayer = a["ap"]
	return {
		"label": a["label_text"], "clip_id": a["clip_id"], "anim_name": a["anim_name"],
		"current": ap.current_animation if ap else "",
		"clips": ap.get_animation_list() if ap else [],
		"state": a["state"], "path_index": a["path_index"],
		"body_yaw": a["body_yaw"], "move_yaw": a["move_yaw"],
		"body_err": a["body_err"], "boot_err": a["boot_err"],
		"pos": (a["node"] as Node3D).global_position,
		"pending": ap.get_queue() if ap and ap.has_method("get_queue") else [],
	}

func test_metrics(i := 0) -> Dictionary:
	var a: Dictionary = actors[i]
	return {
		"body_err": a["body_err"], "boot_err": a["boot_err"],
		"frame_err": a["frame_err"], "frame_boot_err": a["frame_boot_err"],
		"body_yaw": a["body_yaw"], "move_yaw": a["move_yaw"],
		"pos": (a["node"] as Node3D).global_position,
		"state": a["state"], "clip": a["clip_id"],
	}

func test_dance_info() -> Dictionary:
	var a: Dictionary = actors[0]
	var ap: AnimationPlayer = a["ap"]
	if ap == null or dance_clip == "" or not ap.has_animation(dance_clip):
		return {}
	var an := ap.get_animation(dance_clip)
	return {"name": dance_clip, "length": an.length, "tracks": an.get_track_count()}

func test_dance_loop_delta() -> float:
	var a: Dictionary = actors[0]
	var ap: AnimationPlayer = a["ap"]
	var sk: Skeleton3D = a["sk"]
	if ap == null or dance_clip == "" or not ap.has_animation(dance_clip):
		return 999.0
	var an := ap.get_animation(dance_clip)
	_play_clip(a, a["clip_id"], 0.0)  # ensure current clip is not dance for a moment
	ap.play(dance_clip, 0.0)
	ap.seek(0.0, true)
	await get_tree().process_frame
	var first := _all_bone_rots(sk)
	ap.seek(an.length - 0.0001, true)
	await get_tree().process_frame
	var last := _all_bone_rots(sk)
	var maxd := 0.0
	for i in mini(first.size(), last.size()):
		maxd = maxf(maxd, (first[i] as Quaternion).angle_to(last[i]))
	return maxd

func _all_bone_rots(sk: Skeleton3D) -> Array:
	var out := []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_pose_rotation(i))
	return out

func test_set_calib(fixed: bool) -> void:
	calib_fixed = fixed
	if not duo:
		clip_mode = "michelle_fix"
		for a in actors:
			a["clip_id"] = "michelle_fix"
			if a["state"] == "walk" or a["moving"]:
				_play_clip(a, "michelle_fix", 0.0)

func test_set_path(on: bool) -> void:
	path_mode = on
	if on:
		for a in actors:
			a["path_index"] = _nearest_path_index(a["node"].position, a["path_offset"])

func test_set_clip(id: String) -> void:
	clip_mode = id
	if id == "michelle_raw":
		calib_fixed = false
	elif id == "michelle_fix":
		calib_fixed = true
	for a in actors:
		a["clip_id"] = id
		if a["state"] == "walk" or a["moving"]:
			_play_clip(a, id, 0.0)

func test_get_clip() -> String:
	return clip_mode

func test_scale_dev() -> float:
	var a: Dictionary = actors[0]
	var sk: Skeleton3D = a["sk"]
	var worst := 0.0
	for i in sk.get_bone_count():
		var s := sk.get_bone_pose_scale(i)
		worst = maxf(worst, maxf(absf(s.x - 1.0), maxf(absf(s.y - 1.0), absf(s.z - 1.0))))
	return worst

func test_play_dance() -> void:
	dance_ring.visible = true
	_set_state("dance")

func test_stop_dance() -> void:
	_set_state("idle")
	dance_ring.visible = false
