class_name DollThumbnail
extends Control

# 阵容/对照用的烘焙纸偶：把 17 层程序化绘制放进 SubViewport 只渲染一次，
# 外层只画一张纹理。这样 16 张卡同时在场也不会因为上千条绘制指令拖慢主界面。
# 试衣镜仍然使用实时 PaperDollRenderer；本节点只负责静态快照。

var doll: PaperDollRenderer
var viewport: SubViewport

var _texture_rect: TextureRect
var _params: Dictionary = {}
var _bottom_pad := 2.0
var _pending_frames := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_ensure_built()


func _ready() -> void:
	_texture_rect.texture = viewport.get_texture()
	resized.connect(_sync_layout)
	_sync_layout()


func _ensure_built() -> void:
	if viewport != null:
		return
	viewport = SubViewport.new()
	viewport.name = "DollViewport"
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.size = Vector2i(120, 120)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	doll = PaperDollRenderer.new()
	doll.name = "Doll"
	doll.animate = false
	doll.mini = true
	doll.set_display_scale(0.56)
	viewport.add_child(doll)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "BakedTexture"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)


func set_doll(
		outfit_now: Dictionary,
		direction_now: int,
		action_now: String,
		display_scale: float,
		time_offset_now := 0.0,
		bottom_pad := 2.0,
		shadow := true) -> void:
	_params = {
		"outfit": outfit_now,
		"direction": direction_now,
		"action": action_now,
		"scale": display_scale,
		"offset": time_offset_now,
		"pad": bottom_pad,
		"shadow": shadow,
	}
	_bottom_pad = bottom_pad
	doll.set_doll(outfit_now, direction_now, action_now)
	doll.set_display_scale(display_scale)
	doll.time_offset = time_offset_now
	doll.show_shadow = shadow
	doll.set_clock(0.0)
	_sync_layout()


func set_clock(value: float) -> void:
	doll.set_clock(value)
	refresh()


func refresh() -> void:
	if viewport == null:
		return
	# UPDATE_ONCE 在 4.6 的 Compatibility 下会保持每帧刷新；渲染两帧后主动关闭，
	# 否则 16 张卡会一直重画各自的木偶。
	_pending_frames = 2
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	set_process(true)


func _process(_delta: float) -> void:
	if _pending_frames <= 0:
		set_process(false)
		return
	_pending_frames -= 1
	if _pending_frames == 0:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)


func is_baked() -> bool:
	return viewport != null and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED


func _sync_layout() -> void:
	if viewport == null:
		return
	var target := Vector2i(maxi(int(round(size.x)), 4), maxi(int(round(size.y)), 4))
	if viewport.size != target:
		viewport.size = target
	doll.position = Vector2(size.x * 0.5, size.y - _bottom_pad)
	refresh()
