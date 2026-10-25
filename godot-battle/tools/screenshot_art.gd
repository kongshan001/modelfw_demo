extends SceneTree

# Plan 2B 美术截图：1920x1080 静态全场、无 HUD 角色陈列、技能特效、胜利面板。
# 用法：godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_art.gd
# 输出：user://screenshots/plan2b_art_full.png / _scene.png / _skill.png / _victory.png

const WARMUP := 0.7
const CAPTURE_DIR := "user://screenshots"

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.skip_story = true
	_viewport.add_child(scene)
	await process_frame

	var hud: BattleHUD = scene.get_node("UILayer/BattleHUD")
	var session: BattleSession = scene.get_node("BattleSession")
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 8.0):
		_fail("command phase did not start")
		return
	await create_timer(WARMUP).timeout
	await _capture("plan2b_art_full.png")

	# 无 HUD 的角色 / 背景纯美术图
	hud.visible = false
	await create_timer(0.35).timeout
	await _capture("plan2b_art_scene.png")

	# 技能特效：火球 + 剑气叠在妖将身上
	var enemies := session.engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		_fail("no living enemies for effect capture")
		return
	var target: BattleUnitState = enemies[min(2, enemies.size() - 1)]
	var view: UnitView = session.context.unit_view(target.id)
	if view == null:
		_fail("missing unit view for effect capture")
		return
	var impact := view.global_position + Vector2(0, -150)
	var vfx := session.context.vfx_factory()
	vfx.fire(impact)
	vfx.slash(impact + Vector2(-10, 10))
	var fox_view: UnitView = session.context.unit_view(enemies[enemies.size() - 1].id)
	if fox_view != null:
		vfx.thunder(fox_view.global_position + Vector2(0, -120))
	await create_timer(0.12).timeout
	await _capture("plan2b_art_skill.png")
	await create_timer(0.28).timeout
	await _capture("plan2b_art_skill_late.png")

	# 远程弹道：法师到妖将的发光弹丸 + 拖尾（截取飞行中段）
	await create_timer(0.6).timeout
	var caster: UnitView = session.context.unit_view(&"hero_mage")
	if caster != null:
		vfx.projectile(caster.global_position + Vector2(0, -140), impact, &"fire")
		await create_timer(0.08).timeout
		await _capture("plan2b_art_projectile.png")
		await create_timer(0.3).timeout

	# 攻击预备：剑客后拉蓄力（截取预备帧）
	var swordsman: UnitView = session.context.unit_view(&"hero_swordsman")
	if swordsman != null:
		swordsman.lunge_to(view.global_position)
		await create_timer(0.045).timeout
		await _capture("plan2b_art_lunge.png")
		swordsman.reset_pose()

	# 飘字可读性：普通伤害 + 暴击
	FloatText.spawn(session.context, view.global_position + Vector2(-70, -250), "128", Color(1, 1, 1, 0.96), 56)
	if fox_view != null:
		FloatText.spawn(session.context, fox_view.global_position + Vector2(36, -244), "246", Color(1.0, 0.86, 0.25), 76, true)
	await create_timer(0.12).timeout
	await _capture("plan2b_art_float.png")
	await create_timer(0.8).timeout

	# 胜利面板（与真实战斗共用同一 VictoryPanel）
	await create_timer(1.0).timeout
	var victory: VictoryPanel = scene.get_node("UILayer/VictoryPanel")
	victory.show_panel(BattleTypes.Outcome.VICTORY, 1200, 350)
	await create_timer(1.4).timeout
	await _capture("plan2b_art_victory.png")

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
	var path := CAPTURE_DIR + "/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	printerr("SCREENSHOT_ART_FAIL: " + message)
	quit(1)
