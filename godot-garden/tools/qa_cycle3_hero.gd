extends SceneTree

# QA Cycle 3 主角（KayKit Knight）只读验收探针。
# 1) 打印 Knight 挂载/缩放/朝向/动画/隐藏网格；2) 真实跑自动任务链；
# 3) 采样攻击动画与攻击后回到 Idle/Walk；4) 强制倒地并验证复活可见性。
# 5) 设置 GARDEN_FORCE_PROCEDURAL=1 时只验证回退（期望 GardenGirl 可见、无 Knight）。
# 不修改游戏逻辑；仅驱动公开/运行时接口（take_damage）。结束释放场景。

const TIMEOUT := 75.0
const ATTACK_ANIM := "1H_Melee_Attack_Chop"

var _scene
var _hero
var _player
var _model
var _knight
var _seen_anims: Array[String] = []
var _post_attack_anims: Array[String] = []
var _attack_starts := 0
var _attack_speeds: Array[float] = []
var _last_anim := ""
var _stage_transitions: Array[String] = []
var _quest_ok := false
var _attack_ok := false
var _downed_ok := false

func _initialize() -> void:
	var force_proc := OS.has_environment("GARDEN_FORCE_PROCEDURAL")
	_scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	_scene.set_autoplay(false)
	_scene.set_ui_visible(false)
	await create_timer(0.3).timeout

	_hero = _scene._world.hero
	_model = _hero._model
	_knight = _hero._knight
	_player = _hero._knight_player
	var mode := "knight" if _knight != null else "procedural"
	print("HERO_BUILD force_proc=%s mode=%s model_is_girl=%s model_visible=%s knight=%s player=%s" % [
		str(force_proc), mode, str(_model is GardenGirl), str(_model != null and _model.visible),
		str(_knight != null), str(_player != null)])

	if force_proc:
		var fallback_ok: bool = _knight == null and _model != null and _model.visible
		print("HERO_FALLBACK expected=procedural actual=%s model_visible=%s knight=%s" % [
			mode, str(_model != null and _model.visible), str(_knight != null)])
		if _model != null:
			print("HERO_FALLBACK girl_walking=%s scale=%s" % [
				str(_model.walking), str(_model.scale)])
		print("QA_CYCLE3_FALLBACK_%s" % ("PASS" if fallback_ok else "FAIL"))
		_scene.queue_free()
		await process_frame
		quit(0 if fallback_ok else 1)
		return

	if _knight == null or _player == null:
		print("HERO_KNIGHT_MISSING")
		print("QA_CYCLE3_HERO_FAIL")
		_scene.queue_free()
		await process_frame
		quit(1)
		return

	_print_knight_meta()
	await _run_quest_chain()
	await _test_attack_anim_return()
	await _test_downed_respawn()

	print("HERO_QUEST stage=%s kills=%d transitions=%s quest_ok=%s elapsed=%.1fs" % [
		_hero.quest.stage, _hero.quest.current, str(_stage_transitions), str(_quest_ok), _quest_elapsed])
	print("HERO_ANIM seen=%s attack_starts=%d attack_speeds=%s post_attack=%s attack_ok=%s" % [
		str(_seen_anims), _attack_starts, str(_attack_speeds), str(_post_attack_anims), str(_attack_ok)])

	var pass_all := _quest_ok and _attack_ok and _downed_ok
	print("QA_CYCLE3_HERO_%s" % ("PASS" if pass_all else "FAIL"))
	_scene.queue_free()
	await process_frame
	quit(0 if pass_all else 1)

var _quest_elapsed := 0.0

func _print_knight_meta() -> void:
	print("KNIGHT root_scale=%s root_yaw=%.4f knight_nodes=%d" % [
		str(_knight.scale), _knight.rotation.y, _hero._all_nodes(_knight).size()])
	print("KNIGHT anims=%s" % str(_player.get_animation_list()))
	for anim_name in ["Idle", "Running_A", ATTACK_ANIM]:
		var anim: Animation = _player.get_animation(anim_name)
		if anim == null:
			print("KNIGHT anim_missing=%s" % anim_name)
			continue
		print("KNIGHT anim=%s len=%.3f loop=%d speed=%.2f" % [
			anim_name, anim.length, anim.loop_mode, _player.get_playing_speed()])
	print("KNIGHT current=%s playing=%s" % [
		_player.current_animation, str(_player.is_playing())])

	var hidden_expected: Array = GardenHero.KNIGHT_HIDDEN
	var hidden_found: Array[String] = []
	var hidden_visible: Array[String] = []
	var visible_meshes: Array[String] = []
	var mesh_count := 0
	for node in _hero._all_nodes(_knight):
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			mesh_count += 1
			var mesh_name := String(mi.name)
			if hidden_expected.has(mesh_name):
				hidden_found.append(mesh_name)
				if mi.visible:
					hidden_visible.append(mesh_name)
			elif mi.is_visible_in_tree():
				visible_meshes.append(mesh_name)
	print("KNIGHT meshes=%d hidden_found=%s hidden_visible=%s visible=%s" % [
		mesh_count, str(hidden_found), str(hidden_visible), str(visible_meshes)])
	var aabb := _model_aabb(_knight)
	print("KNIGHT visible_aabb size=%s min_y=%.3f max_y=%.3f" % [
		str(aabb.size.snapped(Vector3.ONE * 0.001)), aabb.position.y, aabb.position.y + aabb.size.y])

func _run_quest_chain() -> void:
	var start: String = _hero.quest.stage
	_stage_transitions.append(start)
	_last_anim = _player.current_animation
	_seen_anims.append(_last_anim)
	var elapsed := 0.0
	var last_stage := start
	var next_report := 5.0
	while elapsed < TIMEOUT and _hero.quest.stage != GardenQuest.STAGE_COMPLETE:
		await create_timer(0.1).timeout
		elapsed += 0.1
		_feed_anim(elapsed)
		if _hero.quest.stage != last_stage:
			last_stage = _hero.quest.stage
			_stage_transitions.append(last_stage)
			print("HERO_STAGE t=%.1f stage=%s kills=%d hero=%s hp=%d/%d" % [
				elapsed, last_stage, _hero.quest.current,
				str(_hero.global_position.snapped(Vector3.ONE * 0.01)), _hero.hp, _hero.max_hp])
		if elapsed >= next_report:
			next_report += 5.0
			print("HERO_TICK t=%.1f stage=%s kills=%d hero=%s anim=%s hp=%d" % [
				elapsed, _hero.quest.stage, _hero.quest.current,
				str(_hero.global_position.snapped(Vector3.ONE * 0.01)),
				_player.current_animation, _hero.hp])
	_quest_elapsed = elapsed
	_quest_ok = _hero.quest.stage == GardenQuest.STAGE_COMPLETE and _hero.quest.current == _hero.quest.total
	if not _quest_ok:
		print("HERO_QUEST_TIMEOUT t=%.1f stage=%s kills=%d hero=%s" % [
			elapsed, _hero.quest.stage, _hero.quest.current,
			str(_hero.global_position.snapped(Vector3.ONE * 0.01))])
	await create_timer(0.5).timeout
	_feed_anim(_quest_elapsed)
	print("HERO_QUEST_END t=%.1f stage=%s kills=%d hero=%s anim=%s" % [
		_quest_elapsed, _hero.quest.stage, _hero.quest.current,
		str(_hero.global_position.snapped(Vector3.ONE * 0.01)), _player.current_animation])

func _test_attack_anim_return() -> void:
	# 任务完成后主角停在石像旁 Idle。找一个仍存活的妖灵（若已全灭则跳过，
	# 任务链过程中已采样到攻击后动画）。
	var target: GardenMonster = null
	for monster in _hero.monsters:
		if monster != null and is_instance_valid(monster) and monster.is_alive():
			target = monster
			break
	if target == null:
		print("HERO_ATTACK_PROBE skipped=no_live_monster quest_combat_samples=%s" % str(_post_attack_anims))
		_attack_ok = _post_attack_anims.size() > 0
		return
	_hero.command_attack(target)
	var elapsed := 0.0
	var saw := false
	while elapsed < 8.0 and not saw:
		await create_timer(0.05).timeout
		elapsed += 0.05
		_feed_anim(elapsed)
		saw = _player.current_animation == ATTACK_ANIM
	await create_timer(1.0).timeout
	_feed_anim(8.0 + elapsed)
	print("HERO_ATTACK_PROBE saw_chop=%s after_1s=%s playing=%s" % [
		str(saw), _player.current_animation, str(_player.is_playing())])
	_attack_ok = saw and _post_attack_anims.size() > 0

func _test_downed_respawn() -> void:
	var before := {
		"hp": _hero.hp, "downed": _hero.is_downed(), "model": _model.visible,
		"knight": _knight.visible, "ring": _hero._ring.visible if _hero._ring != null else false,
	}
	_hero.take_damage(9999)
	await process_frame
	await process_frame
	print("HERO_DOWN before_hp=%d hp=%d downed=%s model_visible=%s knight_visible=%s ring_visible=%s anim=%s" % [
		before["hp"], _hero.hp, str(_hero.is_downed()), str(_model.visible),
		str(_knight.visible), str(_hero._ring.visible if _hero._ring != null else false), _player.current_animation])
	var down_ok: bool = _hero.is_downed() and not _model.visible and not _knight.visible \
		and (_hero._ring == null or not _hero._ring.visible)
	await create_timer(3.2).timeout
	await process_frame
	var respawn_dist: float = _hero.global_position.distance_to(_hero.respawn_position)
	var up_ok: bool = not _hero.is_downed() and _hero.hp == _hero.max_hp \
		and not _model.visible and _knight.visible \
		and (_hero._ring == null or _hero._ring.visible) and respawn_dist < 0.01
	print("HERO_RESPAWN hp=%d/%d downed=%s model_visible=%s knight_visible=%s ring_visible=%s anim=%s playing=%s pos=%s dist_spawn=%.3f" % [
		_hero.hp, _hero.max_hp, str(_hero.is_downed()), str(_model.visible),
		str(_knight.visible), str(_hero._ring.visible if _hero._ring != null else false),
		_player.current_animation, str(_player.is_playing()),
		str(_hero.global_position.snapped(Vector3.ONE * 0.01)), respawn_dist])
	_downed_ok = down_ok and up_ok

func _feed_anim(elapsed: float) -> void:
	var anim: String = _player.current_animation
	if anim != _last_anim:
		if anim != "" and not _seen_anims.has(anim):
			_seen_anims.append(anim)
		if anim == ATTACK_ANIM:
			_attack_starts += 1
			_attack_speeds.append(_player.get_playing_speed())
			if _hero._knight_anim != "attack":
				print("HERO_ANIM_STATE_WARN anim=%s _knight_anim=%s" % [anim, _hero._knight_anim])
		if _last_anim == ATTACK_ANIM:
			if not _post_attack_anims.has(anim):
				_post_attack_anims.append(anim)
			print("HERO_ANIM_AFTER_ATTACK t=%.2f anim=%s playing=%s" % [
				elapsed, anim, str(_player.is_playing())])
		_last_anim = anim

func _model_aabb(root: Node3D) -> AABB:
	var first := true
	var out := AABB()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var local: AABB = mi.get_aabb()
		var xf: Transform3D = mi.global_transform
		for i in 8:
			var point: Vector3 = xf * local.get_endpoint(i)
			if first:
				out = AABB(point, Vector3.ZERO)
				first = false
			else:
				out = out.expand(point)
	return out
