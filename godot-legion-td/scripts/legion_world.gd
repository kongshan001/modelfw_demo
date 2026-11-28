class_name LegionWorld
extends Node3D

# 熔岩荒原竞技场：碎裂高地、三线石道、虚空传送门、余烬核心与固定建造点。
# 地形、道路、岩石、雾与光全部程序化；相机为固定 52° 俯视的 RTS 机位。

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")
const Kit := preload("res://scripts/legion_mesh_kit.gd")

const MAP_MIN := -60.0
const MAP_MAX := 60.0
const GRID := 76
const LAVA_Y := -2.7
const CORE_POS := Vector3(0, 0, 28)
const BARRACKS_POS := Vector3(-9, 0, 31)
const SPAWN_POS := Vector3(-5.5, 0, 27.5)
const RALLY_DEFAULT := Vector3(0, 0, 18)
const PORTAL_POS := [
	Vector3(0, 0, -43),
	Vector3(-36, 0, -28),
	Vector3(36, 0, -28),
]
const LANES := [
	[
		Vector3(0, 0, -43), Vector3(0, 0, -34), Vector3(-3, 0, -24),
		Vector3(2, 0, -14), Vector3(0, 0, -3), Vector3(0, 0, 12),
		Vector3(0, 0, 22), Vector3(0, 0, 27),
	],
	[
		Vector3(-36, 0, -28), Vector3(-32, 0, -18), Vector3(-26, 0, -8),
		Vector3(-18, 0, 3), Vector3(-10, 0, 13), Vector3(-3, 0, 20),
		Vector3(0, 0, 25), Vector3(0, 0, 27),
	],
	[
		Vector3(36, 0, -28), Vector3(32, 0, -18), Vector3(26, 0, -8),
		Vector3(18, 0, 3), Vector3(10, 0, 13), Vector3(3, 0, 20),
		Vector3(0, 0, 25), Vector3(0, 0, 27),
	],
]
const PAD_POS := [
	Vector3(-12, 0, 19), Vector3(12, 0, 19),
	Vector3(-18, 0, 8), Vector3(18, 0, 8),
	Vector3(-9, 0, -2), Vector3(9, 0, -2),
	Vector3(-25, 0, -10), Vector3(25, 0, -10),
]
const ISLANDS := [
	Vector2(0, 0), Vector2(43, 49),
	Vector2(0, -43), Vector2(15, 14),
	Vector2(-36, -28), Vector2(15, 13),
	Vector2(36, -28), Vector2(15, 13),
	Vector2(0, 31), Vector2(18, 17),
]
const PILLARS := [
	Vector3(-28, 0, 9), Vector3(-22, 0, -13), Vector3(26, 0, 2), Vector3(22, 0, 19),
	Vector3(-14, 0, -27), Vector3(14, 0, -28), Vector3(-39, 0, 7), Vector3(39, 0, 6),
]
const TREES := [
	Vector3(-21, 0, 22), Vector3(22, 0, 23), Vector3(-31, 0, -17),
	Vector3(31, 0, -14), Vector3(-8, 0, -32), Vector3(10, 0, -35),
]

var camera: Camera3D
var core_node: Node3D
var core_crystal: MeshInstance3D
var core_material: StandardMaterial3D
var core_crack_node: MeshInstance3D
var portals: Array[Dictionary] = []
var pads: Array[Dictionary] = []
var barracks: Node3D
var rally_flag: Node3D
var lane_paths: Array = []
var env: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var pads_root: Node3D
var props_root: Node3D
var fx_root: Node3D
var mist_nodes: Array[Dictionary] = []
var embers: MultiMeshInstance3D
var mist: MultiMeshInstance3D
var _lava: MeshInstance3D
var _roads_root: Node3D
var _ember_data: Array[Dictionary] = []
var _mist_data: Array[Dictionary] = []
var _flames: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _time := 0.0
var _core_base_y := 3.6
var _core_ratio := 1.0
var _cam_target := Vector3(0, 0, 18)
var _cam_dist := 54.0
var _cam_yaw := 0.0
var _cam_pitch := 52.0
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _terrain: MeshInstance3D


func build() -> void:
	_rng.seed = 20261127
	_noise.seed = 7717
	_noise.frequency = 0.055
	_noise.fractal_octaves = 3
	_noise2.seed = 9124
	_noise2.frequency = 0.16
	_build_environment()
	_build_lights()
	_build_camera()
	_build_terrain()
	_build_lava()
	_build_lanes()
	_build_fissures()
	_build_props()
	_build_portals()
	_build_core()
	_build_pads()
	_build_barracks()
	_build_embers()
	_build_mist()
	set_process(true)


# ---------------------------------------------------------------- 环境 / 相机

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#16131C")
	sky_mat.sky_horizon_color = Color("#5A3426")
	sky_mat.sky_curve = 0.28
	sky_mat.ground_bottom_color = Color("#121016")
	sky_mat.ground_horizon_color = Color("#3A211C")
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.10
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#A08C7A")
	env.ambient_light_energy = 1.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color("#3A241C")
	env.fog_light_energy = 0.55
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.6
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = Color("#FFD9B0")
	sun.light_energy = 2.8
	sun.rotation_degrees = Vector3(-48, -135, 0)
	sun.shadow_enabled = false
	add_child(sun)
	rim = DirectionalLight3D.new()
	rim.light_color = Color("#B9DDE4")
	rim.light_energy = 0.22
	rim.rotation_degrees = Vector3(-30, 55, 0)
	rim.shadow_enabled = false
	add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#FFE8D0")
	fill.light_energy = 0.32
	fill.rotation_degrees = Vector3(-38, 25, 0)
	fill.shadow_enabled = false
	add_child(fill)

	var core_light := OmniLight3D.new()
	core_light.light_color = D.C_TEAL
	core_light.light_energy = 1.2
	core_light.omni_range = 12.0
	core_light.omni_attenuation = 1.4
	core_light.position = CORE_POS + Vector3(0, 5.0, 0)
	add_child(core_light)
	for i in 3:
		var pl := OmniLight3D.new()
		pl.light_color = Color("#9B6BC0")
		pl.light_energy = 1.9
		pl.omni_range = 18.0
		pl.omni_attenuation = 1.6
		pl.position = PORTAL_POS[i] + Vector3(0, 4.0, 0)
		add_child(pl)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "RTSCamera"
	camera.fov = 42.0
	camera.near = 0.5
	camera.far = 260.0
	add_child(camera)
	camera.current = true
	apply_camera()


func apply_camera() -> void:
	if camera == null:
		return
	var pitch := deg_to_rad(_cam_pitch)
	var yaw := deg_to_rad(_cam_yaw)
	var offset := Vector3(
		sin(yaw) * cos(pitch) * _cam_dist,
		sin(pitch) * _cam_dist,
		cos(yaw) * cos(pitch) * _cam_dist
	)
	camera.position = _cam_target + offset
	camera.look_at(_cam_target, Vector3.UP)


func set_camera(target: Vector3, dist: float = -1.0) -> void:
	_cam_target = Vector3(clampf(target.x, -30, 30), 0, clampf(target.z, -33, 34))
	if dist > 0.0:
		_cam_dist = clampf(dist, 34.0, 96.0)
	apply_camera()


func pan_camera(delta: Vector3) -> void:
	_cam_target += Vector3(delta.x, 0, delta.z)
	_cam_target.x = clampf(_cam_target.x, -30, 30)
	_cam_target.z = clampf(_cam_target.z, -33, 34)
	apply_camera()


func zoom_camera(amount: float) -> void:
	_cam_dist = clampf(_cam_dist + amount, 34.0, 96.0)
	apply_camera()


func get_cam_target() -> Vector3:
	return _cam_target


func get_cam_dist() -> float:
	return _cam_dist


func screen_to_ground(screen_pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -origin.y / dir.y
	if t <= 0.0 or t > 400.0:
		return Vector3.INF
	return origin + dir * t


func world_to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


# ---------------------------------------------------------------- 地形

func island_mask(x: float, z: float) -> float:
	var best := -2.0
	var i := 0
	while i < ISLANDS.size():
		var c: Vector2 = ISLANDS[i]
		var r: Vector2 = ISLANDS[i + 1]
		var dx := (x - c.x) / r.x
		var dz := (z - c.y) / r.y
		best = maxf(best, 1.0 - sqrt(dx * dx + dz * dz))
		i += 2
	best += _noise2.get_noise_2d(x, z) * 0.055
	return best


func height_at(x: float, z: float) -> float:
	var m := island_mask(x, z)
	var land := smoothstep(-0.10, 0.34, m)
	if m > 0.30:
		return _noise2.get_noise_2d(x * 1.6, z * 1.6) * 0.045
	return lerpf(-4.8, 0.0, land)


func lane_distance(x: float, z: float) -> float:
	var best := 999.0
	var p := Vector2(x, z)
	for lane in LANES:
		for i in range(lane.size() - 1):
			var a: Vector3 = lane[i]
			var b: Vector3 = lane[i + 1]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ap := p - Vector2(a.x, a.z)
			var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var q := Vector2(a.x, a.z) + ab * t
			best = minf(best, p.distance_to(q))
	return best


func _terrain_color(x: float, z: float, h: float) -> Color:
	var n := _noise.get_noise_2d(x * 2.4, z * 2.4) * 0.5 + 0.5
	var n2 := _noise2.get_noise_2d(x * 5.0, z * 5.0) * 0.5 + 0.5
	if h < -1.1:
		var low := Color("#2A211C").lerp(Color("#3A2A22"), n)
		return low.lerp(Color("#5A2E1E"), clampf(-h / 6.0, 0.0, 0.30))
	if h < -0.20:
		var cliff := Color("#3A312A").lerp(Color("#4A3F32"), n)
		return cliff.lerp(Color("#5A4A3A"), n2 * 0.20)
	var d := lane_distance(x, z)
	if d < 3.2:
		return Color("#332C26").lerp(Color("#40382E"), n)
	var ash := Color("#4C4234").lerp(Color("#584C3C"), n)
	if n2 > 0.62:
		ash = ash.lerp(Color("#2A2620"), clampf((n2 - 0.62) * 2.8, 0.0, 0.55))
	elif n2 < 0.30:
		ash = ash.lerp(Color("#6A5A46"), clampf((0.30 - n2) * 1.6, 0.0, 0.30))
	if d < 5.0:
		ash = ash.lerp(Color("#3A342E"), 0.5)
	return ash


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := (MAP_MAX - MAP_MIN) / GRID
	for iz in GRID:
		for ix in GRID:
			var x0 := MAP_MIN + ix * step
			var z0 := MAP_MIN + iz * step
			var x1 := x0 + step
			var z1 := z0 + step
			var h00 := height_at(x0, z0)
			var h10 := height_at(x1, z0)
			var h01 := height_at(x0, z1)
			var h11 := height_at(x1, z1)
			_add_tri(st,
				Vector3(x0, h00, z0), Vector3(x1, h10, z0), Vector3(x0, h01, z1))
			_add_tri(st,
				Vector3(x1, h10, z0), Vector3(x1, h11, z1), Vector3(x0, h01, z1))
	_terrain = MeshInstance3D.new()
	_terrain.name = "Terrain"
	_terrain.mesh = st.commit()
	_terrain.material_override = Art.vcol_mat(1.0, true)
	_terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_terrain)


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_color(_terrain_color(v.x, v.z, v.y))
		st.add_vertex(v)


const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 col_deep : source_color = vec3(0.045, 0.012, 0.010);
uniform vec3 col_mid : source_color = vec3(0.42, 0.10, 0.020);
uniform vec3 col_hot : source_color = vec3(1.0, 0.47, 0.13);
varying vec3 wpos;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i); float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float amp = 0.55;
	for (int i = 0; i < 4; i++){ v += vnoise(p) * amp; p = p * 2.03 + 17.1; amp *= 0.48; }
	return v;
}
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wpos.xz * 0.045;
	float t = TIME * 0.018;
	float n = fbm(p + vec2(t * 1.8, -t));
	float n2 = fbm(p * 2.15 + vec2(-t * 2.1, t * 1.4) + n * 1.7);
	float crack = smoothstep(0.50, 0.79, n2);
	float heat = smoothstep(0.22, 0.90, n);
	vec3 c = mix(col_deep, col_mid, heat);
	c = mix(c, col_hot, crack * 0.85);
	c += col_hot * crack * 0.55;
	ALBEDO = c;
}
"""

const ROAD_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec3 base_col : source_color = vec3(0.44, 0.41, 0.36);
uniform vec3 crack_col : source_color = vec3(1.0, 0.36, 0.10);
varying vec3 wpos;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i); float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p){
	float v = 0.0; float amp = 0.5;
	for (int i = 0; i < 4; i++){ v += vnoise(p) * amp; p = p * 2.05 + 9.1; amp *= 0.5; }
	return v;
}
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float n = fbm(wpos.xz * 0.22);
	float n2 = fbm(wpos.xz * 0.85 + vec2(4.2, 7.7));
	float crack = smoothstep(0.60, 0.72, n2) * smoothstep(0.35, 0.6, n);
	vec3 c = base_col * (0.72 + 0.42 * n);
	ALBEDO = c;
	ROUGHNESS = 0.94;
	EMISSION = crack_col * crack * 0.42;
}
"""


func _build_lava() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	var mi := MeshInstance3D.new()
	mi.name = "LavaSea"
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LAVA_SHADER
	sm.shader = sh
	mi.material_override = sm
	mi.position.y = LAVA_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lava = mi
	add_child(mi)


func _build_lanes() -> void:
	lane_paths.clear()
	_roads_root = Node3D.new()
	_roads_root.name = "Roads"
	add_child(_roads_root)
	var road_mat: Material = Art.mat(Color("#7E7668"), Color(0, 0, 0, 0), 0.95)
	for lane in LANES:
		lane_paths.append(_densify(lane, 1.4))
	var bed := Kit.new()
	var ember := Kit.new()
	for i in lane_paths.size():
		_build_ribbon(lane_paths[i], 6.0, 0.145, road_mat)
		_build_lane_bed(lane_paths[i], bed)
		_build_lane_embers(lane_paths[i], ember)
		_build_lane_edges(lane_paths[i])
	var bed_mi := MeshInstance3D.new()
	bed_mi.mesh = bed.commit(Art.vcol_mat(1.0, false))
	bed_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_roads_root.add_child(bed_mi)
	var em_mi := MeshInstance3D.new()
	em_mi.mesh = ember.commit(Art.vcol_alpha_material())
	em_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_roads_root.add_child(em_mi)


func _densify(points: Array, step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var d := a.distance_to(b)
		var n := maxi(1, int(ceil(d / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	out.append(points[points.size() - 1])
	return out


func _build_ribbon(points: Array, width: float, y: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var a0 := a + side * half
		var a1 := a - side * half
		var b0 := b + side * half
		var b1 := b - side * half
		a0.y = y
		a1.y = y
		b0.y = y
		b1.y = y
		# winding fixed for Godot front-face culling (T-020): was culled from above
		_ribbon_tri(st, a0, b1, b0)
		_ribbon_tri(st, a0, a1, b1)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ribbon_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


func _build_lane_bed(points: Array, kit: LegionMeshKit) -> void:
	# dark stone bevel under the light road: 0.4m on each side, L*15
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var mid := (a + b) * 0.5
		mid.y = 0.105
		var yaw := rad_to_deg(atan2(dir.x, dir.z))
		kit.box(Vector3(6.5, 0.035, a.distance_to(b) + 0.35), mid,
			Color("#2E2A25"), Vector3(0, yaw, 0))
		# worn wheel grooves + cross seams on the road surface
		for gs in [-2.15, 2.15]:
			kit.box(Vector3(0.16, 0.012, a.distance_to(b) + 0.2), mid + side * float(gs) + Vector3(0, 0.056, 0),
				Color("#3A342E"), Vector3(0, yaw, 0))
		if i % 8 == 0:
			kit.box(Vector3(5.9, 0.012, 0.22), mid + Vector3(0, 0.058, 0),
				Color("#433B32"), Vector3(0, yaw, 0))


func _build_lane_embers(points: Array, kit: LegionMeshKit) -> void:
	# thin ember seams every 8m along both road edges (alpha material)
	for i in range(points.size() - 1):
		if i % 6 != 0:
			continue
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var mid := (a + b) * 0.5
		for sv in [-1.0, 1.0]:
			var p: Vector3 = mid + side * (3.12 * float(sv))
			p.y = 0.168
			kit.box(Vector3(0.09, 0.016, 2.2), p, Color(1.0, 0.42, 0.12, 0.42),
				Vector3(0, rad_to_deg(atan2(dir.x, dir.z)), 0))


func _build_lane_edges(points: Array) -> void:
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	var stone := BoxMesh.new()
	stone.size = Vector3(0.28, 0.20, 0.34)
	m.mesh = stone
	var items: Array[Dictionary] = []
	for i in range(2, points.size() - 2, 3):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		for s in [-1.0, 1.0]:
			var p: Vector3 = a + side * (2.85 * s) + side * _rng.randf_range(-0.25, 0.25)
			if lane_distance(p.x, p.z) < 2.4:
				continue
			items.append({"p": p, "rot": _rng.randf_range(0, TAU), "s": _rng.randf_range(0.6, 1.2)})
	m.instance_count = items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var basis := Basis(Vector3.UP, it.rot)
		m.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * it.s), it.p + Vector3(0, 0.03, 0)))
		m.set_instance_color(i, Color("#2e2a35").lerp(Color("#4a3a38"), _rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = m
	mmi.material_override = Art.vcol_mat(1.0, true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_fissures() -> void:
	var fissures := [
		[Vector3(-30, 0, 20), Vector3(-26, 0, 12), Vector3(-30, 0, 3), Vector3(-27, 0, -5)],
		[Vector3(26, 0, 23), Vector3(30, 0, 14), Vector3(27, 0, 5), Vector3(31, 0, -4)],
		[Vector3(-16, 0, -6), Vector3(-8, 0, -3), Vector3(-2, 0, -5), Vector3(5, 0, -2)],
	]
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LAVA_SHADER
	mat.shader = sh
	mat.set_shader_parameter("col_hot", Color(1.0, 0.62, 0.22))
	for f in fissures:
		var pts := _densify(f, 1.2)
		_build_ribbon(pts, 1.25, 0.075, mat)


# ---------------------------------------------------------------- 场景物件

func _build_props() -> void:
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	_build_rocks()
	_build_reeds()
	_build_bones()
	_build_ruins()
	_build_floating_rocks()
	_build_distant_spires()


func _build_rocks() -> void:
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.92
	cm.height = 1.3
	cm.radial_segments = 5
	cm.rings = 1
	m.mesh = cm
	var items: Array[Dictionary] = []
	var tries := 0
	while items.size() < 130 and tries < 3000:
		tries += 1
		var x := _rng.randf_range(-48, 48)
		var z := _rng.randf_range(-52, 48)
		var mask := island_mask(x, z)
		if mask < 0.10 or mask > 0.82:
			continue
		if lane_distance(x, z) < 3.4:
			continue
		if Vector2(x, z).distance_to(Vector2(CORE_POS.x, CORE_POS.z)) < 8.0:
			continue
		var near_pad := false
		for pp in PAD_POS:
			if Vector2(x, z).distance_to(Vector2(pp.x, pp.z)) < 3.0:
				near_pad = true
		if near_pad:
			continue
		var s := _rng.randf_range(0.35, 1.15)
		var roll := _rng.randf()
		if roll > 0.86:
			s = _rng.randf_range(1.9, 2.6)
		elif roll > 0.62:
			s = _rng.randf_range(1.1, 1.7)
		items.append({
			"p": Vector3(x, height_at(x, z) + 0.15 * s, z),
			"rot": _rng.randf_range(0, TAU),
			"s": Vector3(s * _rng.randf_range(0.8, 1.25), s, s * _rng.randf_range(0.8, 1.25)),
			"tilt": _rng.randf_range(-0.16, 0.16),
			"c": Color("#35302A").lerp(Color("#4A4238"), _rng.randf() * 0.75),
		})
	m.instance_count = items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var basis := Basis(Vector3.UP, it.rot).rotated(Vector3.RIGHT, it.tilt)
		m.set_instance_transform(i, Transform3D(basis.scaled(it.s), it.p))
		m.set_instance_color(i, it.c)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rocks"
	mmi.multimesh = m
	mmi.material_override = Art.vcol_mat(1.0, true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mmi)


func _build_reeds() -> void:
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 1.1
	cone.radial_segments = 3
	cone.rings = 1
	m.mesh = cone
	var items: Array[Dictionary] = []
	var tries := 0
	while items.size() < 210 and tries < 4000:
		tries += 1
		var x := _rng.randf_range(-46, 46)
		var z := _rng.randf_range(-50, 46)
		var mask := island_mask(x, z)
		if mask < 0.25 or mask > 0.80:
			continue
		if lane_distance(x, z) < 2.9:
			continue
		items.append({
			"p": Vector3(x, height_at(x, z) + 0.55, z),
			"rot": _rng.randf_range(0, TAU),
			"tilt": _rng.randf_range(-0.22, 0.22),
			"s": _rng.randf_range(0.5, 1.3),
			"c": Color("#5b5a48").lerp(Color("#7a6046"), _rng.randf() * 0.6),
		})
	m.instance_count = items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var basis := Basis(Vector3.UP, it.rot).rotated(Vector3.RIGHT, it.tilt).scaled(Vector3.ONE * it.s)
		m.set_instance_transform(i, Transform3D(basis, it.p))
		m.set_instance_color(i, it.c)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Reeds"
	mmi.multimesh = m
	mmi.material_override = Art.vcol_mat(1.0, true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mmi)


func _build_bones() -> void:
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = true
	var bone := BoxMesh.new()
	bone.size = Vector3(0.09, 0.09, 0.62)
	m.mesh = bone
	var items: Array[Dictionary] = []
	for i in 36:
		var x := _rng.randf_range(-24, 24)
		var z := _rng.randf_range(-30, 20)
		if island_mask(x, z) < 0.4 or lane_distance(x, z) < 2.6:
			continue
		items.append({
			"p": Vector3(x, height_at(x, z) + 0.05, z),
			"rot": _rng.randf_range(0, TAU), "s": _rng.randf_range(0.6, 1.3),
			"c": Color("#8d8276").lerp(Color("#b6a98f"), _rng.randf() * 0.5),
		})
	m.instance_count = items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var basis := Basis(Vector3.UP, it.rot).scaled(Vector3.ONE * it.s)
		m.set_instance_transform(i, Transform3D(basis, it.p))
		m.set_instance_color(i, it.c)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bones"
	mmi.multimesh = m
	mmi.material_override = Art.vcol_mat(0.9, true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mmi)


func _build_ruins() -> void:
	# Every static ruin / dead tree / floating rock is merged into ONE mesh.
	var kit := Kit.new()
	var glow := Kit.new()
	for i in PILLARS.size():
		var p: Vector3 = PILLARS[i]
		var base := p + Vector3(0, height_at(p.x, p.z), 0)
		var h := _rng.randf_range(2.2, 4.8)
		var tilt := _rng.randf_range(-0.14, 0.14)
		var rot := _rng.randf_range(0, TAU)
		var b := Basis(Vector3.UP, rot).rotated(Vector3.RIGHT, tilt)
		kit.add_mesh(_cyl_mesh(0.50, 0.68, h), Transform3D(b, base + Vector3(0, h * 0.42, 0)),
			Color("#332C26"))
		kit.box(Vector3(1.02, 0.26, 1.02), base + Vector3(0, 0.13, 0), Color("#241F1C"))
		kit.box(Vector3(0.92, 0.16, 0.92), base + Vector3(0, h * 0.88, 0), Color("#4A443C"),
			Vector3(0, 12, 6))
		glow.torus(0.52, 0.58, base + Vector3(0, h * 0.55, 0),
			Color(0.37, 0.88, 0.75, 0.20), Vector3(90, 0, 0))
	# two broken arches (kept away from lanes)
	for pv in [Vector3(-6.5, 0, -24), Vector3(8.0, 0, 16)]:
		var p: Vector3 = pv
		var base: Vector3 = p + Vector3(0, height_at(p.x, p.z), 0)
		kit.box(Vector3(0.86, 4.6, 0.94), base + Vector3(-2.2, 2.3, 0), Color("#2E2A25"), Vector3(0, 0, 3))
		kit.box(Vector3(0.86, 3.4, 0.94), base + Vector3(2.2, 1.7, 0), Color("#2E2A25"), Vector3(0, 0, -2))
		kit.box(Vector3(4.9, 0.65, 1.05), base + Vector3(0, 4.15, 0), Color("#3A342E"), Vector3(0, 0, 5))
		glow.sphere(0.16, base + Vector3(0, 4.5, 0), Color(0.37, 0.88, 0.75, 0.55), Vector3.ONE, 5, 3)
	# portal-framing ruins (3 unique clusters)
	var portal_ruins := [
		[Vector3(-7.5, 0, -36), Vector3(7.5, 0, -36), Vector3(-3.0, 0, -47)],
		[Vector3(-41.0, 0, -24), Vector3(-33.0, 0, -34), Vector3(-40.0, 0, -32)],
		[Vector3(41.0, 0, -24), Vector3(33.0, 0, -34), Vector3(40.0, 0, -32)],
	]
	for cluster in portal_ruins:
		for pv in cluster:
			var p: Vector3 = pv
			var base: Vector3 = p + Vector3(0, height_at(p.x, p.z), 0)
			var h := _rng.randf_range(1.6, 3.6)
			kit.box(Vector3(0.70, h, 0.80), base + Vector3(0, h * 0.5, 0), Color("#332C26"),
				Vector3(_rng.randf_range(-8, 8), _rng.randf_range(0, 360), _rng.randf_range(-8, 8)))
			kit.box(Vector3(1.1, 0.28, 1.2), base + Vector3(0, 0.14, 0), Color("#241F1C"))
	# dead trees with ember knots
	for i in TREES.size():
		var p: Vector3 = TREES[i]
		var base := p + Vector3(0, height_at(p.x, p.z), 0)
		var h := _rng.randf_range(2.4, 3.9)
		var rot := _rng.randf_range(0, TAU)
		kit.cyl(0.10, 0.30, h, base + Vector3(0, h * 0.5, 0), Color("#2E2724"), 5,
			Vector3(_rng.randf_range(-8, 8), rad_to_deg(rot), _rng.randf_range(-8, 8)))
		for b in 4:
			var a := rot + b * TAU / 4.0 + 0.3
			var bh := h * _rng.randf_range(0.55, 0.88)
			var br := base + Vector3(cos(a) * 0.42, bh, sin(a) * 0.42)
			kit.cyl(0.03, 0.08, 1.5, br + Vector3(0, 0.55, 0), Color("#28211F"), 4,
				Vector3(-40, rad_to_deg(a), 0))
			glow.sphere(0.09, br + Vector3(0, 1.25, 0), Color("#FF8A3C"), Vector3.ONE, 4, 3)
	# floating rocks
	for p in [Vector3(-55, 4.0, -8), Vector3(53, 5.5, -16), Vector3(-49, 3.0, 32),
			Vector3(49, 4.2, 30), Vector3(-6, 6.0, -61), Vector3(-24, 2.5, -58)]:
		var rot := _rng.randf_range(0, TAU)
		kit.cyl(1.6, 2.4, 1.4, p, Color("#1E1B19"), 5, Vector3(0, rad_to_deg(rot), 0))
		kit.cyl(0.0, 1.7, 1.6, p + Vector3(0, -1.5, 0), Color("#141210"), 5, Vector3(180, 0, 0))
		glow.sphere(0.40, p + Vector3(0.6, 0.9, 0.3), Color("#FF6B35"), Vector3.ONE, 5, 3)
	# distant spires (silhouette skyline)
	for i in 7:
		var p: Vector3 = [Vector3(-72, 0, -30), Vector3(-66, 0, 18), Vector3(70, 0, -34),
			Vector3(66, 0, 14), Vector3(-20, 0, -78), Vector3(26, 0, -76), Vector3(0, 0, 66)][i]
		var h := _rng.randf_range(12, 26)
		kit.cyl(_rng.randf_range(1.0, 2.2), _rng.randf_range(3.0, 5.0), h, Vector3(p.x, -4.0 + h * 0.5, p.z),
			Color("#141118"), 5, Vector3(_rng.randf_range(-4, 4), _rng.randf_range(0, 360), _rng.randf_range(-4, 4)))
		if i % 2 == 0:
			glow.sphere(0.18, Vector3(p.x, -4.0 + h * 0.55, p.z), Color("#9B6BC0"), Vector3.ONE, 5, 3)
	var mi := MeshInstance3D.new()
	mi.name = "RuinsMerged"
	mi.mesh = kit.commit(Art.vcol_mat(1.0, true))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mi)
	var gi := MeshInstance3D.new()
	gi.name = "RuinsGlow"
	gi.mesh = glow.commit(Art.vcol_alpha_material())
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(gi)


func _cyl_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 5
	m.rings = 1
	return m


func _build_floating_rocks() -> void:
	pass


func _build_distant_spires() -> void:
	pass


# ---------------------------------------------------------------- 建筑

func _build_portals() -> void:
	portals.clear()
	var tints := [Color("#9B6BC0"), Color("#8E5BC0"), Color("#7F55B8")]
	for i in 3:
		var tint: Color = tints[i]
		var built := Art.build_portal(tint, i)
		var node: Node3D = built.root
		node.position = PORTAL_POS[i]
		var to_center: Vector3 = (CORE_POS - PORTAL_POS[i]).normalized()
		node.rotation.y = atan2(to_center.x, to_center.z)
		add_child(node)
		portals.append({
			"node": node, "veil": built.veil, "veil_inner": built.veil_inner,
			"shards": built.shards, "pos": PORTAL_POS[i], "index": i,
			"tint": tint, "pulse_t": 0.0,
		})


func _build_core() -> void:
	var built := Art.build_core()
	core_node = built.root
	core_node.position = CORE_POS
	add_child(core_node)
	core_crystal = built.crystal
	core_material = built.material
	# 地面符文环
	core_crack_node = built.get("cracks", null)
	var ring := Art.build_range_ring(9.0, D.C_TEAL, 0.35)
	ring.position = CORE_POS + Vector3(0, 0.02, 0)
	add_child(ring)
	# 来路石阶
	for i in 3:
		var p := CORE_POS + Vector3(0, 0.12 + i * 0.12, -5.2 - i * 1.0)
		Art.add_box(self, Vector3(5.2 - i * 0.5, 0.24, 1.1), p, Color("#241F1C"))
	set_core_ratio(1.0)


func _build_pads() -> void:
	pads_root = Node3D.new()
	pads_root.name = "BuildPads"
	add_child(pads_root)
	pads.clear()
	for i in PAD_POS.size():
		var built := Art.build_pad(i)
		var node: Node3D = built.root
		node.position = PAD_POS[i] + Vector3(0, height_at(PAD_POS[i].x, PAD_POS[i].z) + 0.02, 0)
		pads_root.add_child(node)
		pads.append({
			"index": i, "node": node, "pos": PAD_POS[i], "rune": built.rune,
			"plus": built.plus, "tower": null,
		})


func _build_barracks() -> void:
	var built := Art.build_barracks()
	barracks = built.root
	barracks.position = BARRACKS_POS + Vector3(0, height_at(BARRACKS_POS.x, BARRACKS_POS.z), 0)
	barracks.rotation.y = 0.3
	add_child(barracks)
	rally_flag = Art.build_rally_flag()
	rally_flag.position = RALLY_DEFAULT
	rally_flag.visible = false
	add_child(rally_flag)


# ---------------------------------------------------------------- 氛围粒子

func _build_embers() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.20, 0.20)
	mm.mesh = q
	_ember_data.clear()
	for i in 110:
		var x := _rng.randf_range(-56, 56)
		var z := _rng.randf_range(-58, 54)
		_ember_data.append({
			"p": Vector3(x, _rng.randf_range(LAVA_Y + 0.5, 6.0), z),
			"v": _rng.randf_range(0.35, 1.4),
			"ph": _rng.randf_range(0, TAU),
			"sway": _rng.randf_range(0.15, 0.55),
			"size": _rng.randf_range(0.5, 1.7),
			"c": Color("#FF8A3C").lerp(Color("#FFC48A"), _rng.randf()),
		})
	mm.instance_count = _ember_data.size()
	for i in _ember_data.size():
		var e: Dictionary = _ember_data[i]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * e.size), e.p))
		mm.set_instance_color(i, e.c)
	embers = MultiMeshInstance3D.new()
	embers.name = "Embers"
	embers.multimesh = mm
	var m := Art.billboard_material(Color.WHITE, Art.radial_texture(32, 0.1), true)
	m.vertex_color_use_as_albedo = true
	embers.material_override = m
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(embers)


func _build_mist() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	_mist_data.clear()
	for i in 5:
		_mist_data.append({
			"p": Vector3(_rng.randf_range(-42, 42), LAVA_Y + 0.45, _rng.randf_range(-48, 40)),
			"size": Vector2(_rng.randf_range(26, 44), _rng.randf_range(18, 32)),
			"phase": _rng.randf_range(0, TAU),
			"speed": _rng.randf_range(0.15, 0.45),
		})
	mm.instance_count = _mist_data.size()
	for i in _mist_data.size():
		var d: Dictionary = _mist_data[i]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(d.size.x, 1, d.size.y)), d.p))
	mist = MultiMeshInstance3D.new()
	mist.name = "Mist"
	mist.multimesh = mm
	var m := Art.billboard_material(Color(0.55, 0.45, 0.55, 0.09), Art.smoke_texture(), false)
	mist.material_override = m
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mist)


# ---------------------------------------------------------------- 每帧动画

func _process(delta: float) -> void:
	_time += delta
	if core_crystal != null:
		core_crystal.position.y = _core_base_y + sin(_time * 1.1) * 0.18
		core_crystal.rotation.y += delta * 0.35
	if core_material != null:
		var pulse := 0.70 + 0.16 * sin(_time * 2.0)
		if _core_ratio <= 0.33:
			pulse *= 1.0 + 0.25 * sin(_time * 9.0)
		core_material.emission_energy_multiplier = (0.35 + 0.45 * _core_ratio) * pulse
	for p in portals:
		var shards: Node3D = p.shards
		if shards != null:
			shards.rotation.y += delta * 0.9
			var pulse_t: float = float(p.get("pulse_t", 0.0))
			var s := 1.0 + 0.28 * maxf(0.0, pulse_t)
			shards.scale = Vector3.ONE * s
			p.pulse_t = maxf(0.0, pulse_t - delta)
		var veil: MeshInstance3D = p.veil
		if veil != null:
			var k: float = float(p.get("pulse_t", 0.0))
			veil.scale = Vector3.ONE * (0.96 + 0.05 * sin(_time * 1.7 + p.index) + 0.18 * k)
		var inner: MeshInstance3D = p.get("veil_inner", null)
		if inner != null:
			inner.rotation.z += delta * 0.6
	for f in _flames:
		var node: MeshInstance3D = f.node
		var s := 0.9 + 0.18 * sin(_time * 7.0 + f.phase) + 0.08 * sin(_time * 13.0 + f.phase)
		node.scale = Vector3(1.0, 1.7 * s, 1.0)
	if mist != null:
		var mm2 := mist.multimesh
		for i in _mist_data.size():
			var d: Dictionary = _mist_data[i]
			var base: Vector3 = d.p
			var pos := base + Vector3(sin(_time * d.speed + d.phase) * 3.2, 0,
				cos(_time * d.speed * 0.8 + d.phase) * 2.4)
			mm2.set_instance_transform(i, Transform3D(
				Basis().scaled(Vector3(d.size.x, 1, d.size.y)), pos))
	if embers != null:
		var mm := embers.multimesh
		for i in _ember_data.size():
			var e: Dictionary = _ember_data[i]
			var p: Vector3 = e.p
			p.y += e.v * delta
			p.x += sin(_time * e.sway + e.ph) * delta * 0.7
			if p.y > 7.0:
				p.y = LAVA_Y + 0.3
			e.p = p
			var s: float = e.size * (0.8 + 0.2 * sin(_time * 3.0 + e.ph))
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))


func portal_pulse(index: int) -> void:
	if index < 0 or index >= portals.size():
		return
	portals[index]["pulse_t"] = 0.65


func set_core_ratio(ratio: float) -> void:
	_core_ratio = clampf(ratio, 0.0, 1.0)
	if core_crack_node != null:
		core_crack_node.visible = _core_ratio <= 0.66
	if core_material != null:
		var c := Color("#2FB9AE").lerp(Color("#14413D"), 1.0 - _core_ratio)
		core_material.albedo_color = c


func set_pad_available(index: int, available: bool) -> void:
	if index < 0 or index >= pads.size():
		return
	var plus: Node3D = pads[index].plus
	plus.visible = available
