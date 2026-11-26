class_name FoldPalette
extends RefCounted

## Original paper-diorama palette: cream card, sage stone, terracotta seams,
## deep pine and brass. No textures; all materials are flat-shaded colors.

const COLORS := {
	"stone": Color("#DFCFB4"),
	"stone_2": Color("#CBB794"),
	"stone_dark": Color("#7E6D53"),
	"cream": Color("#F3E8D3"),
	"paper": Color("#FFF4DF"),
	"teal": Color("#1F4B47"),
	"teal_light": Color("#5E8A7F"),
	"pine": Color("#182E2B"),
	"coral": Color("#B95538"),
	"coral_dark": Color("#8A3E2D"),
	"brass": Color("#C99A4C"),
	"brass_dark": Color("#967034"),
	"mustard": Color("#D7A33F"),
	"plum": Color("#644E63"),
	"mint": Color("#8FD0B2"),
	"amber": Color("#F4B24A"),
	"ink": Color("#1F2E2A"),
	"white": Color("#FFF9EC")
}

static var _cache: Dictionary = {}
static var _shadow_shader: Shader


static func color(key: String) -> Color:
	return COLORS.get(key, Color.MAGENTA)


static func mat(key: String, metallic := 0.0, roughness := 0.94) -> StandardMaterial3D:
	var cache_key := "%s|%.2f|%.2f" % [key, metallic, roughness]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color(key)
	m.metallic = metallic
	m.roughness = roughness
	m.metallic_specular = 0.28
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_cache[cache_key] = m
	return m


static func glow(key: String, energy := 1.2) -> StandardMaterial3D:
	var cache_key := "glow|%s|%.2f" % [key, energy]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color(key)
	m.emission_enabled = true
	m.emission = color(key)
	m.emission_energy_multiplier = energy
	_cache[cache_key] = m
	return m


static func soft_shadow(alpha := 0.24) -> ShaderMaterial:
	var cache_key := "blob|%.2f" % alpha
	if _cache.has(cache_key):
		return _cache[cache_key]
	if _shadow_shader == null:
		_shadow_shader = load("res://shaders/soft_shadow.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shadow_shader
	m.set_shader_parameter("shadow_color", Color(0.035, 0.070, 0.060, alpha))
	m.set_shader_parameter("softness", 0.55)
	m.render_priority = 1
	_cache[cache_key] = m
	return m


static func translucent(key: String, alpha: float) -> StandardMaterial3D:
	var cache_key := "soft|%s|%.2f" % [key, alpha]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color(key), alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	_cache[cache_key] = m
	return m
