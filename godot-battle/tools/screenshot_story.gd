extends SceneTree

# Task 4 剧情截图：开场对白（电影黑边+打字机）、技能喊招气泡、胜利结算面板。
# 用法：godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_story.gd

const INTRO_WARMUP := 0.35
const BUBBLE_TIMEOUT := 60.0
const PANEL_WARMUP := 1.4

var _viewport: SubViewport
var _dialogue: DialogueBox
var _bubble: Bubble
var _victory: VictoryPanel
var _session: BattleSession

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.start_auto_mode = true
	scene.skip_story = false
	_viewport.add_child(scene)
	await process_frame

	_dialogue = scene.get_node("UILayer/DialogueBox")
	_bubble = scene.get_node("UILayer/Bubble")
	_victory = scene.get_node("UILayer/VictoryPanel")
	_session = scene.get_node("BattleSession")
	var audio: AudioDirector = scene.get_node("AudioDirector")
	_dialogue.auto_advance_seconds = 3.0
	_bubble.hold_seconds = 4.0
	print("SCREENSHOT_STORY: audio_streams=%d silent=%s" % [audio.stream_names().size(), str(audio.is_silent())])

	if not await _wait_until(func() -> bool: return _dialogue.visible, 5.0):
		_fail("intro dialogue did not appear")
		return
	await create_timer(INTRO_WARMUP).timeout
	await _capture("task4_intro_dialogue.png")

	# 提前结束开场对白，进入自动战斗以捕捉技能喊招。
	_dialogue.hide_now()

	if not await _wait_until(func() -> bool: return _bubble.visible, BUBBLE_TIMEOUT):
		_fail("skill shout bubble did not appear")
		return
	await create_timer(0.3).timeout
	await _capture("task4_skill_bubble.png")

	# 停掉自动战斗，避免结算面板期间再冒出新的喊招气泡。
	await _session.sequencer.skip_all()
	await create_timer(0.2).timeout
	_bubble.hide_now()
	_session.show_result(BattleTypes.Outcome.VICTORY)
	if not await _wait_until(func() -> bool: return _victory.visible, 5.0):
		_fail("victory panel did not show")
		return
	await create_timer(PANEL_WARMUP).timeout
	await _capture("task4_victory_panel.png")

	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return false

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := "user://screenshots/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	printerr("SCREENSHOT_STORY_FAIL: " + message)
	quit(1)
