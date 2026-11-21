class_name FireballProjectile
extends Node2D

# Fireball projectile: the PixelFX fire/fireball loop is drawn with its head at
# the node origin, so the flame tail trails behind the flight direction.

var fx: SpriteFX
var target_x := 0.0
var travel_speed := 120.0
var base_y := 0.0
var time := 0.0
var arrived := false

func setup(def: Dictionary, from: Vector2, to_x: float, speed_px: float) -> void:
	position = from
	base_y = from.y
	target_x = to_x
	travel_speed = speed_px
	z_index = 18
	fx = SpriteFX.new()
	fx.setup(def, 1, -1.0)
	add_child(fx)
	queue_redraw()

func step(dt: float) -> bool:
	if arrived:
		return false
	time += dt
	fx.step(dt)
	position.x = round(position.x + travel_speed * dt)
	position.y = round(base_y + sin(time * 9.0) * 1.2)
	queue_redraw()
	if position.x >= target_x:
		arrived = true
		return false
	return true
