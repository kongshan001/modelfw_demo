class_name VFX
extends Node3D
## Lightweight one-shot 3D effects: particle bursts, ground rings, floating text.
## Separate scene for the T-030 art pass (scenes/vfx.tscn).

const MK = preload("res://scripts/mesh_kit.gd")
const Mat = preload("res://scripts/material_lib.gd")
const Fonts = preload("res://scripts/font_lib.gd")


func play_burst(colors: Array, count: int = 10, speed: float = 2.2, life: float = 0.5,
		size: float = 0.11, gravity: float = 4.0) -> void:
	var per := maxi(1, int(count / maxi(1, colors.size())))
	for color in colors:
		var p := CPUParticles3D.new()
		p.amount = per
		p.lifetime = life * 1.4
		p.one_shot = true
		p.explosiveness = 0.92
		p.emitting = true
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = speed * 0.25
		p.initial_velocity_max = speed
		p.gravity = Vector3(0, -gravity, 0)
		p.damping_min = 0.4
		p.damping_max = 1.4
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.4
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		q.material = Mat.unshaded(color, 2.2, 0.9)
		p.mesh = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
	_finish_after(life * 1.6 + 0.25)


func play_ring(color: Color, radius: float = 2.0, duration: float = 0.42, width: float = 0.08) -> void:
	var st := MK.new_st()
	MK.add_ring(st, Vector3.ZERO, radius - width, radius, 28, Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = MK.finish(st)
	var mat := Mat.unshaded(color, 1.6, 0.8)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.07
	mi.scale = Vector3(0.15, 1, 0.15)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	_finish_after(duration + 0.1)


func play_text(text: String, color: Color, size: float = 0.55, life: float = 0.95) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Fonts.bold()
	label.font_size = 72
	label.pixel_size = 0.0045 * size
	label.modulate = color
	label.outline_size = 18
	label.outline_modulate = Color(0.04, 0.03, 0.06, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.position.y = 1.2
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.6, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	_finish_after(life + 0.1)


func play_skill(field_size: Vector2) -> void:
	var p := CPUParticles3D.new()
	p.amount = 64
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.55
	p.emitting = true
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(field_size.x * 0.5, 0.4, field_size.y * 0.5)
	p.position.y = 3.2
	p.direction = Vector3.DOWN
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -5.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.42)
	q.material = Mat.unshaded(Color(1.0, 0.55, 0.18), 2.4, 0.9)
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	var st := MK.new_st()
	MK.add_ring(st, Vector3.ZERO, 27.0, 28.0, 40, Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = MK.finish(st)
	var mat := Mat.unshaded(Color(1.0, 0.7, 0.3), 1.6, 0.45)
	mi.material_override = mat
	mi.position.y = 0.09
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	_finish_after(1.7)


func _finish_after(seconds: float) -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(queue_free)
