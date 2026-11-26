extends Node

# 主控：程序化像素场景 → 水面数据管线 → 单个全屏水面 shader。
# 水面不是网格：世界层只有一张 1280×720 的 ColorRect（WaterLayer）。
# 相机负责海 / 河 / 湖的观察机位；HUD 只改参数与调试视图。

const WORLD := Vector2(1280.0, 720.0)
const CELL := 16

var pipeline: WaterPipeline
var controller: WaterController

var _art: Dictionary = {}
var _textures: Dictionary = {}
var _water_mat: ShaderMaterial
var _water_layer: ColorRect
var _ground: Sprite2D
var _foreground: Sprite2D
var _camera: Camera2D
var _hud
var _cam_pos := WORLD * 0.5
var _cam_zoom := 1.0
var _cam_target_pos := WORLD * 0.5
var _cam_target_zoom := 1.0
var _hud_accum := 0.0
var _last_rebuild_same := true


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_art = PixelArt.build()
	var t_art := Time.get_ticks_msec()
	pipeline = WaterPipeline.new()
	pipeline.build(_art["mask"], CELL, _art["bridge_rect"])
	var t_pipe := Time.get_ticks_msec()
	controller = WaterController.new()
	_camera = $WorldViewport/World/Camera
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(WORLD.x)
	_camera.limit_bottom = int(WORLD.y)
	_camera.limit_smoothed = false
	_hud = $HUD
	var display: TextureRect = $WorldDisplay
	display.texture = $WorldViewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_world()
	_save_pipeline()
	controller.apply_to(_water_mat)
	_hud.setup(self)
	snap_camera()
	print("WATER_SHADER_READY art_ms=%d pipe_ms=%d total_ms=%d grid=%dx%d bridge_cells=%d" % [
		t_art - t0, t_pipe - t_art, Time.get_ticks_msec() - t0,
		pipeline.cols, pipeline.rows, pipeline.bridge_cells])


func _build_world() -> void:
	var world: Node2D = $WorldViewport/World
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.centered = false
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.z_index = -10
	_ground.texture = _make_texture(_art["ground"])
	world.add_child(_ground)

	# 唯一的水面绘制节点。没有 MeshInstance2D / Polygon2D 水面。
	_water_layer = ColorRect.new()
	_water_layer.name = "WaterLayer"
	_water_layer.position = Vector2.ZERO
	_water_layer.size = WORLD
	_water_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water_surface.gdshader")
	_water_layer.material = _water_mat
	_water_layer.z_index = 0
	world.add_child(_water_layer)

	_foreground = Sprite2D.new()
	_foreground.name = "Foreground"
	_foreground.centered = false
	_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foreground.z_index = 10
	_foreground.texture = _make_texture(_art["foreground"])
	world.add_child(_foreground)

	_bind_field_textures()
	_water_mat.set_shader_parameter("u_ground", _make_texture(_art["ground"]))
	_water_mat.set_shader_parameter("u_world", WORLD)
	_water_mat.set_shader_parameter("u_cell", float(CELL))


func _bind_field_textures() -> void:
	_textures.clear()
	for key in pipeline.images.keys():
		_textures[key] = _make_texture(pipeline.images[key])
	_water_mat.set_shader_parameter("u_mask", _textures["mask"])
	_water_mat.set_shader_parameter("u_depth", _textures["depth"])
	_water_mat.set_shader_parameter("u_category", _textures["category"])
	_water_mat.set_shader_parameter("u_flow", _textures["flow"])
	_water_mat.set_shader_parameter("u_puddle_mask", _textures["puddle_mask"])
	_water_mat.set_shader_parameter("u_puddle_depth", _textures["puddle_depth"])


func _make_texture(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _save_pipeline() -> void:
	var dir := "res://docs/pipeline"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_art["mask"].save_png(dir.path_join("source_mask_1280.png"))
	var saved := pipeline.save_to(dir)
	print("PIPELINE_SAVED dir=%s hashes=%s" % [saved["dir"], str(saved["hashes"])])


func _process(delta: float) -> void:
	controller.advance(delta)
	controller.apply_to(_water_mat)
	_update_camera(delta)
	_hud_accum += delta
	if _hud_accum >= 0.20:
		_hud_accum = 0.0
		if _hud != null:
			_hud.tick()


func _update_camera(delta: float) -> void:
	var k := 1.0 - pow(0.0025, maxf(delta, 0.001))
	var p := _camera.position.lerp(_cam_target_pos, k)
	_cam_zoom = lerpf(_cam_zoom, _cam_target_zoom, k)
	_camera.position = _clamp_camera(p, _cam_zoom)
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)


func _clamp_camera(p: Vector2, z: float) -> Vector2:
	# 直接对机位做边界夹取，避免近景越出 1280×720 世界出现黑边。
	var half := WORLD / (2.0 * maxf(z, 1.0))
	return Vector2(
		clampf(p.x, half.x, WORLD.x - half.x),
		clampf(p.y, half.y, WORLD.y - half.y))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	match key:
		KEY_SPACE:
			toggle_pause()
		KEY_R:
			toggle_rain()
		KEY_1:
			set_focus(WaterController.CAT_SEA)
		KEY_2:
			set_focus(WaterController.CAT_RIVER)
		KEY_3:
			set_focus(WaterController.CAT_LAKE)
		KEY_0, KEY_ESCAPE:
			set_focus(WaterController.CAT_ALL)
		KEY_F:
			cycle_debug()
		KEY_B:
			rebuild_pipeline()
		KEY_N:
			reset()
		KEY_H:
			if _hud != null:
				_hud.toggle_ui()
		KEY_T:
			if _hud != null:
				var cur: float = controller.tide
				set_param("tide", 1.0 if cur < 0.5 else 0.0)


# ── 对外参数接口（HUD / smoke 共用） ─────────────────────────────────────
func set_param(name: String, value: float) -> void:
	controller.set_param(name, value)
	controller.apply_to(_water_mat)
	if _hud != null:
		_hud.sync_from_main()


func set_focus(cat: int) -> void:
	controller.set_focus(cat)
	controller.apply_to(_water_mat)
	var lm: Dictionary = _art["landmarks"]
	var key := "full"
	match cat:
		WaterController.CAT_SEA:
			key = "sea"
		WaterController.CAT_RIVER:
			key = "river"
		WaterController.CAT_LAKE:
			key = "lake"
	_cam_target_pos = lm[key]["pos"]
	_cam_target_zoom = lm[key]["zoom"]
	if _hud != null:
		_hud.sync_from_main()


func set_camera_view(pos: Vector2, zoom: float, instant: bool = false) -> void:
	_cam_target_pos = pos
	_cam_target_zoom = zoom
	if instant:
		_cam_zoom = zoom
		_camera.position = _clamp_camera(pos, zoom)
		_camera.zoom = Vector2(zoom, zoom)


func snap_camera() -> void:
	_cam_zoom = _cam_target_zoom
	_camera.position = _clamp_camera(_cam_target_pos, _cam_zoom)
	_camera.zoom = Vector2(_cam_zoom, _cam_zoom)


func set_rain(value: float) -> void:
	controller.set_param("rain", value)
	controller.apply_to(_water_mat)
	if _hud != null:
		_hud.sync_from_main()


func toggle_rain() -> bool:
	var on := controller.toggle_rain()
	controller.apply_to(_water_mat)
	if _hud != null:
		_hud.sync_from_main()
	return on


func set_paused(value: bool) -> void:
	controller.set_paused(value)
	controller.apply_to(_water_mat)
	if _hud != null:
		_hud.sync_from_main()


func toggle_pause() -> void:
	set_paused(not controller.paused)


func set_debug_view(view: int) -> void:
	controller.set_debug_view(view)
	controller.apply_to(_water_mat)
	_sync_debug_visibility()
	if _hud != null:
		_hud.sync_from_main()


func cycle_debug() -> int:
	var v := controller.cycle_debug()
	controller.apply_to(_water_mat)
	_sync_debug_visibility()
	if _hud != null:
		_hud.sync_from_main()
	return v


func _sync_debug_visibility() -> void:
	# 调试视图看数据本身：把桥/芦苇等前景移开，桥面裁切以蓝色格显示。
	if _foreground != null:
		_foreground.visible = controller.debug_view == 0


func set_time_seconds(seconds: float) -> void:
	controller.set_time_seconds(seconds)
	controller.apply_to(_water_mat)


func rebuild_pipeline() -> bool:
	var before := pipeline.images_hash()
	var t0 := Time.get_ticks_msec()
	_art = PixelArt.build()
	var fresh := WaterPipeline.new()
	fresh.build(_art["mask"], CELL, _art["bridge_rect"])
	var after := fresh.images_hash()
	pipeline = fresh
	_ground.texture = _make_texture(_art["ground"])
	_foreground.texture = _make_texture(_art["foreground"])
	_bind_field_textures()
	_water_mat.set_shader_parameter("u_ground", _ground.texture)
	_save_pipeline()
	controller.apply_to(_water_mat)
	_sync_debug_visibility()
	_last_rebuild_same = before == after
	if _hud != null:
		_hud.sync_from_main()
	print("PIPELINE_REBUILD cell=%d grid=%dx%d ms=%d reproducible=%s" % [
		CELL, pipeline.cols, pipeline.rows, Time.get_ticks_msec() - t0, str(_last_rebuild_same)])
	return _last_rebuild_same


func reset() -> void:
	controller.reset()
	controller.apply_to(_water_mat)
	_sync_debug_visibility()
	_cam_target_pos = WORLD * 0.5
	_cam_target_zoom = 1.0
	snap_camera()
	if _hud != null:
		_hud.sync_from_main()


func set_ui_visible(value: bool) -> void:
	if _hud != null:
		_hud.set_ui_visible(value)


func show_caption(text: String) -> void:
	if _hud != null:
		_hud.show_caption(text)


# ── 查询接口（HUD / smoke） ──────────────────────────────────────────────
func get_pipeline() -> WaterPipeline:
	return pipeline


func get_controller() -> WaterController:
	return controller


func get_water_material() -> ShaderMaterial:
	return _water_mat


func get_water_layer() -> ColorRect:
	return _water_layer


func get_ground_sprite() -> Sprite2D:
	return _ground


func get_foreground_sprite() -> Sprite2D:
	return _foreground


func get_hud() -> CanvasLayer:
	return _hud


func get_fps() -> int:
	return Engine.get_frames_per_second()


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func get_time() -> float:
	return controller.time_seconds


func get_stats() -> Dictionary:
	return pipeline.stats


func get_bodies() -> Array:
	return pipeline.bodies.duplicate(true)


func get_body_by_type(type_name: String) -> Dictionary:
	return pipeline.body_of_type(type_name)


func get_landmarks() -> Dictionary:
	return _art["landmarks"]


func get_params() -> Dictionary:
	return controller.get_params()


func get_last_rebuild_same() -> bool:
	return _last_rebuild_same


func is_raining() -> bool:
	return controller.rain > 0.01


func get_rain() -> float:
	return controller.rain


func get_focus() -> int:
	return controller.focus


func get_debug_view() -> int:
	return controller.debug_view


func count_water_surfaces() -> int:
	var count := 0
	for n in find_children("*", "CanvasItem", true, false):
		if n.material is ShaderMaterial:
			var mat: ShaderMaterial = n.material
			if mat == _water_mat:
				count += 1
	return count


func pipeline_summary() -> String:
	var pct := {"sea": 0.0, "river": 0.0, "lake": 0.0}
	for b in pipeline.bodies:
		pct[b["type"]] += float(b["coverage"]) * 100.0
	return "水体 %d · 海 %.0f%% 河 %.0f%% 湖 %.0f%%" % [
		pipeline.bodies.size(), pct["sea"], pct["river"], pct["lake"]]
