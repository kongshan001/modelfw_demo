class_name SproutStyle
extends RefCounted

## 共享配色 / 字体 / 低模资源工厂。所有视觉资源程序化生成，无外部贴图。

const PAPER := Color(0.96, 0.91, 0.78)
const INK := Color(0.14, 0.20, 0.15)
const MINT := Color(0.55, 0.86, 0.62)
const AMBER := Color(1.0, 0.73, 0.35)
const CORAL := Color(0.86, 0.40, 0.32)
const TEAL := Color(0.32, 0.62, 0.56)
const PANEL := Color(0.075, 0.14, 0.105, 0.82)
const PANEL_SOFT := Color(0.09, 0.16, 0.12, 0.55)

const GRASS_A := Color(0.29, 0.49, 0.16)
const GRASS_B := Color(0.39, 0.59, 0.21)
const GRASS_DARK := Color(0.19, 0.35, 0.11)
const PATH := Color(0.68, 0.55, 0.33)
const TRUNK := Color(0.38, 0.26, 0.16)
const LEAF_A := Color(0.28, 0.50, 0.22)
const LEAF_B := Color(0.20, 0.40, 0.17)
const STONE := Color(0.55, 0.53, 0.44)
const STONE_DARK := Color(0.40, 0.40, 0.33)
const SKY_TOP := Color(0.25, 0.52, 0.85)
const SKY_HORIZON := Color(0.82, 0.89, 0.80)

static var _cjk_font: SystemFont


static func cjk() -> SystemFont:
	if _cjk_font == null:
		_cjk_font = SystemFont.new()
		_cjk_font.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
			"Microsoft YaHei", "Arial Unicode MS", "sans-serif",
		])
		_cjk_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_cjk_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return _cjk_font


static func mat(color: Color, roughness: float = 0.92,
		emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic_specular = 0.0
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission if emission != Color.BLACK else color
		m.emission_energy_multiplier = energy
	return m


static func unshaded(color: Color, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func low_sphere(radius: float, radial: int = 7, rings: int = 4) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = radial
	s.rings = rings
	return s


static func low_cylinder(top: float, bottom: float, height: float,
		radial: int = 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = radial
	c.rings = 1
	return c
