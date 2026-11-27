class_name LegionWorld
extends Node3D

# 熔岩荒原竞技场：碎裂高地、三线石道、虚空传送门、余烬核心与固定建造点。
# 地形、道路、岩石、雾与光全部程序化；相机为固定 52° 俯视的 RTS 机位。

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")

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
var _ember_data: Array[Dictionary] = []
var _flames: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _time := 0.0
var _cam_target := Vector3(0, 0, 23)
var _cam_dist := 56.0
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
	sky_mat.sky_top_color = Color("#2b2742")
	sky_mat.sky_horizon_color = Color("#a45f4e")
	sky_mat.sky_curve = 0.22
	sky_mat.ground_bottom_color = Color("#21172a")
	sky_mat.ground_horizon_color = Color("#6b3a3a")
	sky_mat.sun_angle_max = 26.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b3aaa0")
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.18
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color("#65433d")
	env.fog_light_energy = 0.62
	env.fog_density = 0.0019
	env.fog_sky_affect = 0.55
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
	sun.light_color = Color("#ffe0bb")
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-56, -34, 0)
	sun.shadow_enabled = false
	add_child(sun)
	rim = DirectionalLight3D.new()
	rim.light_color = Color("#ff8d60")
	rim.light_energy = 0.78
	rim.rotation_degrees = Vector3(-28, 148, 0)
	rim.shadow_enabled = false
	add_child(rim)

	var core_light := OmniLight3D.new()
	core_light.light_color = D.C_TEAL
	core_light.light_energy = 3.4
	core_light.omni_range = 22.0
	core_light.omni_attenuation = 1.3
	core_light.position = CORE_POS + Vector3(0, 4.5, 0)
	add_child(core_light)
	for i in 3:
		var pl := OmniLight3D.new()
		pl.light_color = Color("#c07bff") if i == 0 else Color("#ff8a55")
		pl.light_color = Color("#b36bff")
		pl.light_energy = 2.2
		pl.omni_range = 17.0
		pl.omni_attenuation = 1.5
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
		var low := Color("#241b2b").lerp(Color("#3b2430"), n)
		return low.lerp(Color("#6a3328"), clampf(-h / 4.0, 0.0, 0.35))
	if h < -0.20:
		var cliff := Color("#3a3145").lerp(Color("#544357"), n)
		return cliff.lerp(Color("#73515b"), n2 * 0.25)
	var d := lane_distance(x, z)
	if d < 3.0:
		return Color("#4d444f").lerp(Color("#5c5151"), n)
	var ash := Color("#71816a").lerp(Color("#8b9077"), n)
	ash = ash.lerp(Color("#5c6d64"), n2 * 0.55)
	if d < 5.0:
		ash = ash.lerp(Color("#6a6a5f"), 0.45)
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
uniform vec3 col_deep : source_color = vec3(0.10, 0.025, 0.035);
uniform vec3 col_mid : source_color = vec3(0.62, 0.16, 0.05);
uniform vec3 col_hot : source_color = vec3(1.0, 0.58, 0.18);
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
	c = mix(c, col_hot, crack * 0.95);
	c += col_hot * crack * 1.25;
	ALBEDO = c;
}
"""

const ROAD_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec3 base_col : source_color = vec3(0.115, 0.100, 0.125);
uniform vec3 crack_col : source_color = vec3(1.0, 0.38, 0.12);
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
	vec3 c = base_col * (0.72 + 0.55 * n);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	EMISSION = crack_col * crack * 0.75;
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
	add_child(mi)


func _build_lanes() -> void:
	lane_paths.clear()
	var road_mat := ShaderMaterial.new()
	var road_sh := Shader.new()
	road_sh.code = ROAD_SHADER
	road_mat.shader = road_sh
	for lane in LANES:
		lane_paths.append(_densify(lane, 1.4))
	for i in lane_paths.size():
		_build_ribbon(lane_paths[i], 5.2, 0.065, road_mat)
		# 两侧碎石 / 余烬
		_build_lane_edges(lane_paths[i])


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
		_ribbon_tri(st, a0, b0, b1)
		_ribbon_tri(st, a0, b1, a1)
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
		items.append({
			"p": Vector3(x, height_at(x, z) + 0.15 * s, z),
			"rot": _rng.randf_range(0, TAU),
			"s": Vector3(s * _rng.randf_range(0.8, 1.25), s, s * _rng.randf_range(0.8, 1.25)),
			"tilt": _rng.randf_range(-0.16, 0.16),
			"c": Color("#25222d").lerp(Color("#4b4642"), _rng.randf() * 0.7),
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
	for i in PILLARS.size():
		var p: Vector3 = PILLARS[i]
		var root := Node3D.new()
		root.position = p + Vector3(0, height_at(p.x, p.z), 0)
		root.rotation.y = _rng.randf_range(0, TAU)
		props_root.add_child(root)
		var h := _rng.randf_range(2.0, 4.8)
		var tilt := _rng.randf_range(-0.16, 0.16)
		var pillar := Node3D.new()
		pillar.rotation.x = tilt
		root.add_child(pillar)
		Art.add_cyl(pillar, 0.55, 0.72, h, Vector3(0, h * 0.5, 0), Color("#3b3542"), 6)
		Art.add_box(pillar, Vector3(1.0, 0.25, 1.0), Vector3(0, 0.15, 0), Color("#2b2733"))
		Art.add_box(pillar, Vector3(0.9, 0.16, 0.9), Vector3(0, h, 0), Color("#4a4048"),
			Vector3(0, 12, 6))
		Art.add_box(pillar, Vector3(0.35, 0.16, 0.7), Vector3(0.35, h - 0.12, 0.1), Color("#4a4048"),
			Vector3(0, -20, 14))
		Art.add_torus(pillar, 0.58, 0.66, Vector3(0, h * 0.62, 0), D.C_TEAL, Vector3(90, 0, 0),
			Art.glow_mat(Color(D.C_TEAL.r, D.C_TEAL.g, D.C_TEAL.b, 0.22)))
	# 两座残拱
	var arch_pos := [Vector3(-4, 0, -30), Vector3(6, 0, 10)]
	for i in arch_pos.size():
		var p: Vector3 = arch_pos[i]
		var root := Node3D.new()
		root.position = p + Vector3(0, height_at(p.x, p.z), 0)
		root.rotation.y = 0.35 if i == 0 else -0.9
		props_root.add_child(root)
		Art.add_box(root, Vector3(0.8, 4.2, 0.9), Vector3(-2.1, 2.1, 0), Color("#332e3a"))
		Art.add_box(root, Vector3(0.8, 3.4, 0.9), Vector3(2.1, 1.7, 0), Color("#332e3a"))
		Art.add_box(root, Vector3(4.6, 0.6, 1.0), Vector3(0, 3.9, 0), Color("#3c3542"),
			Vector3(0, 0, 4))
		Art.add_sphere(root, 0.15, Vector3(0, 4.2, 0), D.C_TEAL, Vector3.ONE,
			Art.glow_mat(D.C_TEAL), 5, 3)
	# 枯树
	for i in TREES.size():
		var p: Vector3 = TREES[i]
		var root := Node3D.new()
		root.position = p + Vector3(0, height_at(p.x, p.z), 0)
		root.rotation.y = _rng.randf_range(0, TAU)
		props_root.add_child(root)
		var h := _rng.randf_range(2.2, 3.7)
		Art.add_cyl(root, 0.10, 0.28, h, Vector3(0, h * 0.5, 0), Color("#3a2f2c"), 5,
			Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)))
		for b in 4:
			var a := _rng.randf_range(0, TAU)
			var bh := h * _rng.randf_range(0.55, 0.9)
			var br := Node3D.new()
			br.position = Vector3(0, bh, 0)
			br.rotation = Vector3(_rng.randf_range(-0.9, -0.4), a, 0)
			root.add_child(br)
			Art.add_cyl(br, 0.03, 0.08, _rng.randf_range(1.0, 1.8), Vector3(0, 0.6, 0),
				Color("#352b29"), 4)
			Art.add_sphere(br, 0.09, Vector3(0, 1.3, 0), Color("#ff8a4f"), Vector3.ONE,
				Art.glow_mat(Color("#ff8a4f")), 4, 3)
	# 火盆
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		var p := CORE_POS + Vector3(cos(a) * 7.6, 0, sin(a) * 7.6)
		var root := Node3D.new()
		root.position = p + Vector3(0, height_at(p.x, p.z), 0)
		props_root.add_child(root)
		Art.add_cyl(root, 0.42, 0.24, 0.7, Vector3(0, 0.35, 0), Color("#3a333d"), 6)
		Art.add_cyl(root, 0.55, 0.42, 0.28, Vector3(0, 0.82, 0), Color("#2b2630"), 6)
		var flame := Art.add_sphere(root, 0.35, Vector3(0, 1.12, 0), Color("#ff9a4f"),
			Vector3(1.0, 1.7, 1.0), Art.glow_mat(Color(1.0, 0.45, 0.15, 0.85)), 6, 3)
		_flames.append({"node": flame, "phase": _rng.randf_range(0, TAU)})
		Art.add_billboard(root, 2.4, Vector3(0, 1.2, 0), Color(1.0, 0.42, 0.14, 0.35))


func _build_floating_rocks() -> void:
	var positions := [
		Vector3(-55, 4.0, -8), Vector3(53, 5.5, -16), Vector3(-49, 3.0, 32),
		Vector3(49, 4.2, 30), Vector3(-6, 6.0, -61), Vector3(-24, 2.5, -58),
	]
	for i in positions.size():
		var p: Vector3 = positions[i]
		var root := Node3D.new()
		root.position = p
		root.rotation.y = _rng.randf_range(0, TAU)
		props_root.add_child(root)
		Art.add_cyl(root, 1.6, 2.4, 1.4, Vector3.ZERO, Color("#292430"), 5)
		Art.add_cyl(root, 0.0, 1.7, 1.6, Vector3(0, -1.5, 0), Color("#211c27"), 5,
			Vector3(180, 0, 0))
		Art.add_sphere(root, 0.5, Vector3(0.6, 0.9, 0.3), D.C_EMBER, Vector3.ONE,
			Art.glow_mat(Color(1.0, 0.4, 0.12, 0.55)), 5, 3)


func _build_distant_spires() -> void:
	var positions := [
		Vector3(-72, 0, -30), Vector3(-66, 0, 18), Vector3(70, 0, -34),
		Vector3(66, 0, 14), Vector3(-20, 0, -78), Vector3(26, 0, -76), Vector3(0, 0, 66),
	]
	for i in positions.size():
		var p: Vector3 = positions[i]
		var h := _rng.randf_range(12, 26)
		var root := Node3D.new()
		root.position = Vector3(p.x, -4.0, p.z)
		root.rotation.y = _rng.randf_range(0, TAU)
		props_root.add_child(root)
		Art.add_cyl(root, _rng.randf_range(1.0, 2.2), _rng.randf_range(3.0, 5.0), h,
			Vector3(0, h * 0.5, 0), Color("#1f1a26"), 5,
			Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)))
		Art.add_box(root, Vector3(1.2, 0.6, 1.2), Vector3(0.8, h * 0.7, 0.2), Color("#2a2430"),
			Vector3(0, 12, 8))
		if i % 2 == 0:
			Art.add_sphere(root, 0.22, Vector3(0, h * 0.55, 0), Color("#c47bff"), Vector3.ONE,
				Art.glow_mat(Color("#c47bff")), 5, 3)


# ---------------------------------------------------------------- 建筑

func _build_portals() -> void:
	portals.clear()
	for i in 3:
		var tint := Color("#b36bff") if i == 0 else Color("#c46bff")
		var built := Art.build_portal(tint)
		var node: Node3D = built.root
		node.position = PORTAL_POS[i]
		var to_center: Vector3 = (CORE_POS - PORTAL_POS[i]).normalized()
		node.rotation.y = atan2(to_center.x, to_center.z)
		add_child(node)
		portals.append({
			"node": node, "veil": built.veil, "shards": built.shards,
			"pos": PORTAL_POS[i], "index": i, "tint": tint,
		})


func _build_core() -> void:
	var built := Art.build_core()
	core_node = built.root
	core_node.position = CORE_POS
	add_child(core_node)
	core_crystal = built.crystal
	core_material = built.material
	# 地面符文环
	var ring := Art.build_range_ring(8.5, D.C_TEAL, 0.38)
	ring.position = CORE_POS + Vector3(0, 0.02, 0)
	add_child(ring)
	# 来路石阶
	for i in 3:
		var p := CORE_POS + Vector3(0, 0.12 + i * 0.12, -4.5 - i * 0.9)
		Art.add_box(self, Vector3(4.6 - i * 0.5, 0.24, 1.0), p, Color("#2c2832"))


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
	for i in 150:
		var x := _rng.randf_range(-56, 56)
		var z := _rng.randf_range(-58, 54)
		_ember_data.append({
			"p": Vector3(x, _rng.randf_range(LAVA_Y + 0.5, 6.0), z),
			"v": _rng.randf_range(0.35, 1.4),
			"ph": _rng.randf_range(0, TAU),
			"sway": _rng.randf_range(0.15, 0.55),
			"size": _rng.randf_range(0.5, 1.7),
			"c": Color("#ff8a3d").lerp(Color("#ffd36a"), _rng.randf()),
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
	for i in 5:
		var plane := PlaneMesh.new()
		plane.size = Vector2(_rng.randf_range(26, 44), _rng.randf_range(18, 32))
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = Art.smoke_texture()
		m.albedo_color = Color(0.55, 0.45, 0.62, 0.10)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mi.material_override = m
		mi.position = Vector3(_rng.randf_range(-42, 42), LAVA_Y + 0.45, _rng.randf_range(-48, 40))
		mi.rotation.y = _rng.randf_range(0, TAU)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mist_nodes.append({
			"node": mi, "base": mi.position, "phase": _rng.randf_range(0, TAU),
			"speed": _rng.randf_range(0.15, 0.45),
		})


# ---------------------------------------------------------------- 每帧动画

func _process(delta: float) -> void:
	_time += delta
	if core_crystal != null:
		core_crystal.position.y = 3.2 + sin(_time * 1.1) * 0.16
		core_crystal.rotation.y += delta * 0.45
	if core_material != null:
		var pulse := 0.72 + 0.18 * sin(_time * 2.0)
		core_material.emission_energy_multiplier = pulse
	for p in portals:
		var shards: Array = p.shards
		for i in shards.size():
			var sh: Node3D = shards[i]
			var a := _time * 0.7 + i * TAU / 3.0
			sh.position = Vector3(cos(a) * 1.9, 2.9 + sin(_time * 1.3 + i) * 0.35, sin(a) * 1.9)
			sh.rotation.y += delta * 1.4
		var veil: MeshInstance3D = p.veil
		if veil != null:
			veil.scale = Vector3.ONE * (0.94 + 0.06 * sin(_time * 1.7 + p.index))
	for f in _flames:
		var node: MeshInstance3D = f.node
		var s := 0.9 + 0.18 * sin(_time * 7.0 + f.phase) + 0.08 * sin(_time * 13.0 + f.phase)
		node.scale = Vector3(1.0, 1.7 * s, 1.0)
	for m in mist_nodes:
		var node: MeshInstance3D = m.node
		node.position.x = m.base.x + sin(_time * m.speed + m.phase) * 3.2
		node.position.z = m.base.z + cos(_time * m.speed * 0.8 + m.phase) * 2.4
		node.rotation.y += delta * m.speed * 0.05
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


func set_pad_available(index: int, available: bool) -> void:
	if index < 0 or index >= pads.size():
		return
	var plus: Node3D = pads[index].plus
	plus.visible = available
