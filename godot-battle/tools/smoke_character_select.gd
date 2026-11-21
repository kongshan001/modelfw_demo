extends SceneTree

# Headless 冒烟：实例化主角选择场景，验证 6 张卡、6 人切换、确认落盘与信号；
# auto_enter_battle=false，避免真的切进战斗。测试结束恢复用户原选择。

var _failures: Array[String] = []
var _confirmed_id: StringName = &""

func _initialize() -> void:
	var previous := HeroRoster.load_saved_id()
	var scene: CharacterSelect = load("res://scenes/character_select.tscn").instantiate()
	scene.auto_enter_battle = false
	root.add_child(scene)
	await process_frame
	await process_frame

	_check(scene.profiles.size() == 6, "profiles: expected 6, got %d" % scene.profiles.size())
	_check(scene.card_count() == 6, "cards: expected 6, got %d" % scene.card_count())
	_check(scene.selected_id() != &"", "initial selection is empty")

	for profile in scene.profiles:
		var selected: bool = scene.select_hero(profile.id, false)
		_check(selected, "select_hero failed: " + String(profile.id))
		_check(scene.selected_id() == profile.id, "selected id mismatch: " + String(profile.id))

	scene.confirmed.connect(func(profile: HeroProfile) -> void: _confirmed_id = profile.id)
	var expected := scene.selected_id()
	scene.confirm()
	await create_timer(0.55).timeout
	_check(_confirmed_id == expected, "confirmed signal id mismatch")
	_check(HeroRoster.load_saved_id() == expected, "saved id mismatch")

	if previous.is_empty():
		HeroRoster.clear_saved_id()
	else:
		HeroRoster.save_id(previous)

	scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CHARACTER_SELECT_SMOKE_OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("SMOKE_FAIL: " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
