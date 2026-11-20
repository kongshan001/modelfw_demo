class_name DollThumbnail
extends Control

# 阵容/对照用的烘焙纸偶：把 17 层程序化绘制放进 SubViewport 只渲染一次，
# 外层只画一张纹理。这样 16 张卡同时在场也不会因为上千条绘制指令拖慢主界面。
# 试衣镜仍然使用实时 PaperDollRenderer；本节点只负责静态快照。
#
# T-010 AA：GL Compatibility 不支持 2D MSAA（T-006 实测），因此缩略图用
# 2× SubViewport 超采样 + Linear 下采样；纸偶按 display_scale×2 绘制，
# 视口尺寸也×2，外层显示尺寸不变。只在签名/时钟变化时重烘焙一次。

const SUPERSAMPLE := 2
const BUDGET_USEC := 16000

var doll: PaperDollRenderer
var viewport: SubViewport
# 观测值：烘焙请求计数、上次烘焙的 CPU draw 耗时（微秒）、窗口耗时（含等待帧）。
var bake_count := 0
var last_bake_usec := 0
var last_draw_usec := 0

var _texture_rect: TextureRect
var _params: Dictionary = {}
var _bottom_pad := 2.0
var _display_scale := 0.56
var _pending_frames := 0
var _bake_started_usec := 0
var _signature := ""
var _clock_value := 0.0
var _clock_set := false
var _configured := false


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
	viewport.size = Vector2i(120 * SUPERSAMPLE, 120 * SUPERSAMPLE)
	# 首个 set_doll 之前不渲染默认纸偶；refresh() 再开 UPDATE_ONCE。
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

	doll = PaperDollRenderer.new()
	doll.name = "Doll"
	doll.animate = false
	doll.mini = true
	doll.shadow_scale_y = 0.72
	doll.set_display_scale(0.56 * SUPERSAMPLE)
	viewport.add_child(doll)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "BakedTexture"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	# 签名不变就不重烘焙（评审 P0-2：一次性烘焙）。尺寸变化由 _sync_layout 负责。
	var signature := "%s|%d|%s|%.4f|%.4f|%.4f|%s" % [
		DollData.outfit_signature(outfit_now), direction_now, action_now,
		display_scale, time_offset_now, bottom_pad, str(shadow),
	]
	if signature == _signature:
		return
	_signature = signature
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
	_display_scale = display_scale
	doll.set_doll(outfit_now, direction_now, action_now)
	doll.set_display_scale(_display_scale * SUPERSAMPLE)
	doll.time_offset = time_offset_now
	doll.show_shadow = shadow
	doll.set_clock(0.0)
	_clock_value = 0.0
	_clock_set = true
	_configured = true
	_sync_layout()


func set_clock(value: float) -> void:
	if _clock_set and is_equal_approx(value, _clock_value) and is_baked():
		return
	_clock_value = value
	_clock_set = true
	doll.set_clock(value)
	if _configured:
		refresh()


func refresh() -> void:
	if viewport == null:
		return
	if _pending_frames <= 0:
		_bake_started_usec = Time.get_ticks_usec()
		bake_count += 1
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
		last_bake_usec = Time.get_ticks_usec() - _bake_started_usec
		last_draw_usec = doll.last_draw_usec
		set_process(false)


func is_baked() -> bool:
	return viewport != null and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED


func is_supersampled() -> bool:
	if viewport == null or size.x < 1.0 or size.y < 1.0:
		return false
	var want := Vector2i(int(round(size.x)) * SUPERSAMPLE, int(round(size.y)) * SUPERSAMPLE)
	return viewport.size == want


func uses_linear_filter() -> bool:
	return _texture_rect != null and _texture_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR


func bake_stats() -> Dictionary:
	return {
		"viewport": viewport.size if viewport != null else Vector2i.ZERO,
		"control": size,
		"supersample": SUPERSAMPLE,
		"display_scale": _display_scale,
		"mini": doll.mini if doll != null else false,
		"linear": uses_linear_filter(),
		"baked": is_baked(),
		"bake_count": bake_count,
		"last_bake_usec": last_bake_usec,
		"last_draw_usec": last_draw_usec if last_draw_usec > 0 else (doll.last_draw_usec if doll != null else 0),
	}


func _sync_layout() -> void:
	if viewport == null or not _configured or size.x < 8.0 or size.y < 8.0:
		return
	var target := Vector2i(
			maxi(int(round(size.x)), 8) * SUPERSAMPLE,
			maxi(int(round(size.y)), 8) * SUPERSAMPLE)
	if viewport.size != target:
		viewport.size = target
	doll.set_display_scale(_display_scale * SUPERSAMPLE)
	doll.position = Vector2(size.x * 0.5, size.y - _bottom_pad) * SUPERSAMPLE
	refresh()
