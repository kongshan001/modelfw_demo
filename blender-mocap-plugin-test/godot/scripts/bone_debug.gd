extends Node3D
class_name BoneDebug

## Draws a line per bone (parent -> child) plus a small joint cross.
## Must be added as a child of the Skeleton3D so skeleton-space poses map directly.

var skeleton: Skeleton3D
var enabled := false:
	set(v):
		enabled = v
		if mi:
			mi.visible = v
var mi: MeshInstance3D
var mesh := ImmediateMesh.new()
var mat := ShaderMaterial.new()
var shader := Shader.new()

func setup(sk: Skeleton3D) -> void:
	skeleton = sk
	mi = MeshInstance3D.new()
	mi.name = "BoneDebugMesh"
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, blend_mix;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""
	mat.shader = shader
	mat.render_priority = 2
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 8.0
	mi.visible = enabled
	add_child(mi)

func _process(_delta: float) -> void:
	if not enabled or skeleton == null or skeleton.get_bone_count() == 0:
		return
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in skeleton.get_bone_count():
		var p: Vector3 = skeleton.get_bone_global_pose(i).origin
		var parent := skeleton.get_bone_parent(i)
		if parent >= 0:
			var pp: Vector3 = skeleton.get_bone_global_pose(parent).origin
			_line(pp, p, _bone_color(skeleton.get_bone_name(i)))
		var s := 0.018
		var c := Color(1.0, 1.0, 1.0, 0.85)
		_line(p - Vector3(s, 0, 0), p + Vector3(s, 0, 0), c)
		_line(p - Vector3(0, s, 0), p + Vector3(0, s, 0), c)
		_line(p - Vector3(0, 0, s), p + Vector3(0, 0, s), c)
	mesh.surface_end()

func _bone_color(bone_name: String) -> Color:
	var n := bone_name.to_lower()
	if n.contains("hand") or n.contains("arm") or n.contains("elbow"):
		return Color(0.2, 0.85, 1.0, 0.95)
	if n.contains("leg") or n.contains("foot") or n.contains("toe") or n.contains("knee"):
		return Color(1.0, 0.55, 0.2, 0.95)
	if n.contains("spine") or n.contains("chest") or n.contains("hip") or n.contains("pelvis") or n.contains("root"):
		return Color(1.0, 0.85, 0.2, 0.95)
	return Color(0.75, 0.8, 0.9, 0.85)

func _line(a: Vector3, b: Vector3, c: Color) -> void:
	mesh.surface_set_color(c)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(c)
	mesh.surface_add_vertex(b)
