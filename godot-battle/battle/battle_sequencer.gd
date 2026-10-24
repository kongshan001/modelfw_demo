class_name BattleSequencer
extends Node

signal idle

var ctx: BattleContext
var playback_speed := 1.0
# 调试浮层用：当前正在播放的命令（含 event 的命令可用于显示事件 seq/type）。
var current_command: BattleCommand = null
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
		current_command = cmd
		if _skip:
			cmd.skip(ctx)
			continue
		await cmd.play(ctx)
		if generation != _generation:
			break
	if generation != _generation:
		Engine.time_scale = 1.0
		_restore_views()
		_skip = false
		playback_speed = 1.0
	_playing = false
	idle.emit()

func skip_all() -> void:
	Engine.time_scale = 1.0
	if ctx != null:
		if ctx.dialogue != null:
			ctx.dialogue.hide_now()
		if ctx.bubble != null:
			ctx.bubble.hide_now()
	if not _playing:
		_restore_views()
		return
	_generation += 1
	_queue.clear()
	_skip = true
	playback_speed = 1000.0

func _restore_views() -> void:
	if ctx == null:
		return
	if ctx.session != null:
		ctx.apply_snapshot(ctx.session.engine.state)
	for view in ctx.unit_views.values():
		if view.unit_state != null and view.unit_state.is_alive():
			view.reset_pose()
		else:
			view.stop_animations()

func is_skipping() -> bool:
	return _skip

func is_playing() -> bool:
	return _playing

func set_step_mode(enabled: bool) -> void:
	_step_mode = enabled

func is_step_mode() -> bool:
	return _step_mode

func queue_size() -> int:
	return _queue.size()

func request_step() -> void:
	_step_requested = true
