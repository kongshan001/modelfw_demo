class_name CoinPickup
extends Node2D

# A coin spinning on the ground. The loop is pickups/coin-spin (PixelFX, MIT);
# collected state is guarded so one coin can only score once per pickup.

var fx: SpriteFX
var collected := false
var respawn_left := 0.0
var respawn_time := 2.6
var index := 0
var phase := 0.0

func setup(def: Dictionary, at: Vector2, coin_index: int) -> void:
	position = at
	index = coin_index
	phase = coin_index * 0.37
	z_index = 8
	fx = SpriteFX.new()
	fx.setup(def, 1, -1.0)
	fx.time = phase
	fx.queue_redraw()
	add_child(fx)
	queue_redraw()

func step(dt: float) -> void:
	if collected:
		respawn_left -= dt
		if respawn_left <= 0.0:
			_respawn()
	else:
		fx.step(dt)

func collect() -> bool:
	if collected:
		return false
	collected = true
	respawn_left = respawn_time
	fx.stop()
	fx.visible = false
	return true

func force_respawn() -> void:
	_respawn()

func clear() -> void:
	collected = false
	respawn_left = 0.0
	if fx:
		fx.visible = true
		fx.restart()

func _respawn() -> void:
	collected = false
	respawn_left = 0.0
	fx.visible = true
	fx.restart()
	fx.time = phase
	fx.queue_redraw()

func is_active() -> bool:
	return not collected
