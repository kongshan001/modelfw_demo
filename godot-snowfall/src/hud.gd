extends CanvasLayer

# Compact HUD: snow amount, ground coverage, wind, night time; F keys for the
# individual layers.

var world
var snow_slider: HSlider
var cover_slider: HSlider
var wind_slider: HSlider
var night_slider: HSlider
var snow_label: Label
var cover_label: Label
var wind_label: Label
var night_label: Label
var status: Label

const GOLD := Color(1.0, 0.87, 0.66)
const ICE := Color(0.72, 0.90, 1.0)
const DIM := Color(0.80, 0.86, 0.92)


func setup(w) -> void:
	world = w
	_build()
	snow_slider.set_value_no_signal(world.snow_amount)
	cover_slider.set_value_no_signal(world.coverage)
	wind_slider.set_value_no_signal(world.wind)
	night_slider.set_value_no_signal(world.night)
	snow_slider.value_changed.connect(_on_snow)
	cover_slider.value_changed.connect(_on_cover)
	wind_slider.value_changed.connect(_on_wind)
	night_slider.value_changed.connect(_on_night)
	_on_snow(snow_slider.value)
	_on_cover(cover_slider.value)
	_on_wind(wind_slider.value)
	_on_night(night_slider.value)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var title_panel := PanelContainer.new()
	title_panel.position = Vector2(24.0, 18.0)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_theme_stylebox_override("panel",
		_style(Color(0.035, 0.05, 0.08, 0.74), Color(0.72, 0.90, 1.0, 0.22)))
	root.add_child(title_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	title_panel.add_child(tv)
	tv.add_child(_label("雪夜墓园", 24, GOLD))
	tv.add_child(_label("SNOWFALL · 2D snow study · particles + mask", 11, ICE))

	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 24.0
	bar.offset_right = -24.0
	bar.offset_top = -112.0
	bar.offset_bottom = -18.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_stylebox_override("panel",
		_style(Color(0.035, 0.05, 0.08, 0.84), Color(0.72, 0.90, 1.0, 0.20)))
	root.add_child(bar)

	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 4)
	bar.add_child(vv)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	row1.add_child(_label("雪量", 13, DIM))
	snow_slider = _slider(0.0, 1.0, 0.02, 0.85)
	snow_label = _label("85%", 13, ICE)
	row1.add_child(snow_slider)
	row1.add_child(snow_label)
	row1.add_child(_label("   积雪", 13, DIM))
	cover_slider = _slider(0.0, 1.0, 0.01, 0.74)
	cover_label = _label("74%", 13, ICE)
	row1.add_child(cover_slider)
	row1.add_child(cover_label)
	row1.add_child(_label("   风", 13, DIM))
	wind_slider = _slider(-1.0, 1.0, 0.05, 0.25)
	wind_label = _label("0.25", 13, ICE)
	row1.add_child(wind_slider)
	row1.add_child(wind_label)
	row1.add_child(_label("   夜晚", 13, DIM))
	night_slider = _slider(18.0, 24.0, 0.25, 21.0)
	night_label = _label("21:00", 13, ICE)
	row1.add_child(night_slider)
	row1.add_child(night_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp)
	status = _label("", 12, Color(0.68, 0.86, 0.96))
	row1.add_child(status)
	vv.add_child(row1)

	vv.add_child(_label(
		"WASD / 方向键 移动（留下脚印）   ·   F1 地面积雪   F2 雪粒子   F3 树面积雪   F4 脚印   F5 蒙版   R 清脚印",
		12, DIM))


func _slider(lo: float, hi: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(130.0, 16.0)
	return s


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _on_snow(v: float) -> void:
	world.set_snow_amount(v)
	snow_label.text = "%d%%" % int(round(v * 100.0))


func _on_cover(v: float) -> void:
	world.set_coverage(v)
	cover_label.text = "%d%%" % int(round(v * 100.0))


func _on_wind(v: float) -> void:
	world.set_wind(v)
	wind_label.text = "%.2f" % v


func _on_night(v: float) -> void:
	world.set_night(v)
	var h := int(floor(v))
	var m := int(round((v - h) * 60.0)) % 60
	night_label.text = "%02d:%02d" % [h, m]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			world.set_ground_snow(not world.ground_snow_on)
		KEY_F2:
			world.set_snow_enabled(not world.snow_on)
		KEY_F3:
			world.set_caps(not world.caps_on)
		KEY_F4:
			world.set_footprints(not world.footprints_on)
		KEY_F5:
			world.toggle_mask_debug()
		KEY_R:
			world.clear_footprints()
		_:
			return
	_update_status()


func _update_status() -> void:
	status.text = "GROUND %s · SNOW %s · CAPS %s · FEET %s" % [
		"ON" if world.ground_snow_on else "OFF",
		"ON" if world.snow_on else "OFF",
		"ON" if world.caps_on else "OFF",
		"ON" if world.footprints_on else "OFF",
	]
