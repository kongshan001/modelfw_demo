class_name BattleSequencer
extends Node

signal idle

var ctx: BattleContext
var playback_speed := 1.0
var _queue: Array[BattleCommand] = []
var _playing := false
var _skip := false
var _generation := 0
var _step_mode := false
var _step_requested := false
var _step_signal: Signal

func _ready() -> void:
	_step_signal = get_tree().create_timer(0.0).timeout

func enqueue(cmd: BattleCommand) -> void:
	_queue.append(cmd)

func enqueue_batch(commands: Array) -> void:
	for cmd in commands:
		_queue.append(cmd)

func play_all() -> void:
	if _playing:
		return
	_playing = true
	var generation := _generation
	while not _queue.is_empty():
		if _step_mode:
			while not _step_requested and not _skip:
				await get_tree().process_frame
			_step_requested = false
		if generation != _generation:
			break
		var cmd: BattleCommand = _queue.pop_front()
		if _skip:
			cmd.skip(ctx)
			continue
		await cmd.play(ctx)
		if generation != _generation:
			break
	if generation != _generation:
		if ctx != null and ctx.session != null:
			ctx.apply_snapshot(ctx.session.engine.state)
		if ctx != null:
			for view in ctx.unit_views.values():
				view.stop_animations()
		_skip = false
		playback_speed = 1.0
	_playing = false
	idle.emit()

func skip_all() -> void:
	if not _playing:
		if ctx != null and ctx.session != null:
			ctx.apply_snapshot(ctx.session.engine.state)
		if ctx != null:
			for view in ctx.unit_views.values():
				view.stop_animations()
		return
	_generation += 1
	_queue.clear()
	_skip = true
	playback_speed = 1000.0

func is_skipping() -> bool:
	return _skip

func set_step_mode(enabled: bool) -> void:
	_step_mode = enabled

func request_step() -> void:
	_step_requested = true
