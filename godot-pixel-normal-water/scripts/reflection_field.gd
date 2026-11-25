class_name NormalWaterReflection
extends Node2D

# 单 Mesh 倒影：
#   每个近岸物件沿自己的脚底/水线锚点翻折，UV 垂直翻转；
#   所有物件的四边形打包进同一张 512×128 图集、同一个 Surface、一次 draw call。
#   水面遮罩和整格水波全部在 reflection.gdshader 里完成，
#   不额外开 Camera2D / SubViewport，也不做屏幕抓取或后处理。

const ATLAS_W := 512
const ATLAS_H := 128
const PAD := 6

var mesh_instance: MeshInstance2D
var shader_mat: ShaderMaterial
var atlas_image: Image
var atlas_texture: ImageTexture
var quads: Array = []
var quad_count := 0
var quad_count_hint := 0
var lamp_uv_a := Vector4.ZERO
var lamp_uv_b := Vector4.ZERO
var source_ids: Array[String] = []

var wave_speed := 1.0
var wave_amplitude := 2.0
var wave_step := 1.0
var time_value := 0.0
var waterline := 120.0


func setup(sources: Array, mask_image: Image, waterline_y: float, z: int = -20) -> void:
	waterline = waterline_y
	z_index = z
	_build_atlas(sources)
	_build_mesh(sources)
	_build_material(mask_image)
	quad_count_hint = 1


func _build_atlas(sources: Array) -> void:
	atlas_image = Image.create(ATLAS_W, ATLAS_H, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cursor := PAD
	for i in sources.size():
		var src: Dictionary = sources[i]
		var img: Image = src["image"]
		var rect := Rect2i(cursor, PAD, img.get_width(), img.get_height())
		if rect.end.x > ATLAS_W - PAD:
			push_error("reflection atlas overflow: %s" % String(src["id"]))
			break
		atlas_image.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), rect.position)
		src["atlas_rect"] = rect
		sources[i] = src
		source_ids.append(String(src["id"]))
		var uv_rect := Rect2(
			Vector2(rect.position) / Vector2(ATLAS_W, ATLAS_H),
			Vector2(rect.size) / Vector2(ATLAS_W, ATLAS_H))
		if String(src["id"]) == "lamp_a":
			lamp_uv_a = Vector4(uv_rect.position.x, uv_rect.position.y,
					uv_rect.size.x, uv_rect.size.y)
		elif String(src["id"]) == "lamp_b":
			lamp_uv_b = Vector4(uv_rect.position.x, uv_rect.position.y,
					uv_rect.size.x, uv_rect.size.y)
		cursor += img.get_width() + PAD
	atlas_texture = ImageTexture.create_from_image(atlas_image)


func _build_mesh(sources: Array) -> void:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var atlas_size := Vector2(ATLAS_W, ATLAS_H)
	quads.clear()
	for src in sources:
		var img: Image = src["image"]
		var rect: Rect2i = src["atlas_rect"]
		var pos: Vector2 = Vector2(src["pos"])
		var foot := float(src["foot"])
		var w := float(img.get_width())
		var h := float(img.get_height())
		var x0 := pos.x
		var x1 := pos.x + w
		# 水线以上不可见；四边形从锚点向下镜像，近岸顶点对应原图底部 UV。
		var top := foot
		var bottom := foot + h
		var u0 := float(rect.position.x) / atlas_size.x
		var u1 := float(rect.position.x + rect.size.x) / atlas_size.x
		var v0 := float(rect.position.y) / atlas_size.y
		var v1 := float(rect.position.y + rect.size.y) / atlas_size.y

		verts.append(Vector2(x0, top))
		verts.append(Vector2(x1, top))
		verts.append(Vector2(x1, bottom))
		verts.append(Vector2(x0, top))
		verts.append(Vector2(x1, bottom))
		verts.append(Vector2(x0, bottom))
		uvs.append(Vector2(u0, v1))
		uvs.append(Vector2(u1, v1))
		uvs.append(Vector2(u1, v0))
		uvs.append(Vector2(u0, v1))
		uvs.append(Vector2(u1, v0))
		uvs.append(Vector2(u0, v0))
		quads.append(PackedVector2Array([
			Vector2(x0, top), Vector2(x1, top),
			Vector2(x1, bottom), Vector2(x0, bottom)]))
	quad_count = quads.size()

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance = MeshInstance2D.new()
	mesh_instance.name = "ReflectionMesh"
	mesh_instance.mesh = mesh
	mesh_instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mesh_instance.z_index = 0
	add_child(mesh_instance)


func _build_material(mask_image: Image) -> void:
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/reflection.gdshader")
	shader_mat.set_shader_parameter("u_atlas", atlas_texture)
	var mask_tex := ImageTexture.create_from_image(mask_image)
	shader_mat.set_shader_parameter("u_mask", mask_tex)
	shader_mat.set_shader_parameter("u_atlas_size", Vector2(ATLAS_W, ATLAS_H))
	shader_mat.set_shader_parameter("u_world_size", NormalWaterLayout.WORLD)
	shader_mat.set_shader_parameter("u_waterline", waterline)
	shader_mat.set_shader_parameter("u_lamp_uv_a", lamp_uv_a)
	shader_mat.set_shader_parameter("u_lamp_uv_b", lamp_uv_b)
	mesh_instance.material = shader_mat
	apply_uniforms()


func apply_uniforms() -> void:
	if shader_mat == null:
		return
	shader_mat.set_shader_parameter("u_time", time_value)
	shader_mat.set_shader_parameter("u_wave_speed", wave_speed)
	shader_mat.set_shader_parameter("u_wave_amplitude", wave_amplitude)
	shader_mat.set_shader_parameter("u_wave_step", wave_step)


func set_time(value: float) -> void:
	time_value = value
	if shader_mat != null:
		shader_mat.set_shader_parameter("u_time", time_value)


func set_wave_params(speed: float, amplitude: float, step_px: float) -> void:
	wave_speed = speed
	wave_amplitude = amplitude
	wave_step = maxf(1.0, step_px)
	apply_uniforms()


func set_lamps_on(value: bool) -> void:
	if shader_mat != null:
		shader_mat.set_shader_parameter("u_lamps_on", value)


func set_reflection_enabled(value: bool) -> void:
	if mesh_instance != null:
		mesh_instance.visible = value


func is_reflection_enabled() -> bool:
	return mesh_instance != null and mesh_instance.visible


func get_mesh_instance() -> MeshInstance2D:
	return mesh_instance


func get_surface_count() -> int:
	if mesh_instance == null or mesh_instance.mesh == null:
		return 0
	return mesh_instance.mesh.get_surface_count()


func get_quad_count() -> int:
	return quad_count


func get_quads() -> Array:
	return quads


func get_atlas_image() -> Image:
	return atlas_image


# 与 reflection.gdshader 的整格公式保持同一份数学；调试叠加和 smoke 都用它。
func quantized_shift(row: int, at_time: float) -> int:
	var phase := sin(float(row) * 0.86 + at_time * wave_speed * 1.6) * 0.68 \
			+ sin(float(row) * 0.31 - at_time * wave_speed * 0.90) * 0.32
	var step_px := maxf(1.0, wave_step)
	return int(round(phase * wave_amplitude / step_px)) * int(round(step_px))
