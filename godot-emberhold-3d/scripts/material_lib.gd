class_name MaterialLib
extends RefCounted
## Material entry points for the T-030 art pass.
## Replace files in res://materials/ or override get_mat()/unshaded() here.

const NAMES := ["stone", "stone_dark", "ember", "frost", "gold", "bone", "char_vertex",
	"ground_ashen", "ground_frost", "path_ashen", "path_frost", "water_frost"]

static var _cache: Dictionary = {}


static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var path := "res://materials/%s.tres" % name
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	if res == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.8, 0.2, 0.2)
		res = fallback
	_cache[name] = res
	return res


static func unshaded(color: Color, energy: float = 1.0, alpha: float = 1.0, cull_disabled: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if cull_disabled:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 1.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	return m


static func emissive(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	return m
