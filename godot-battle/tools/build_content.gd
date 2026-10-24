extends SceneTree

func _initialize() -> void:
	for dir_path in ["res://data/units", "res://data/skills", "res://data/statuses", "res://data/items", "res://data/encounters"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var statuses := _build_statuses()
	for status in statuses.values():
		if _save(status, "res://data/statuses/%s.tres" % String(status.id)) != OK:
			quit(1)
			return

	var skills := _build_skills()
	for skill in skills.values():
		if _save(skill, "res://data/skills/%s.tres" % String(skill.id)) != OK:
			quit(1)
			return

	var items := _build_items()
	for item in items.values():
		if _save(item, "res://data/items/%s.tres" % String(item.id)) != OK:
			quit(1)
			return

	var units := _build_units()
	for unit in units.values():
		if _save(unit, "res://data/units/%s.tres" % String(unit.id)) != OK:
			quit(1)
			return

	var encounter := _build_encounter()
	if _save(encounter, "res://data/encounters/enc_bamboo_01.tres") != OK:
		quit(1)
		return

	print("CONTENT_BUILT units=%d skills=%d statuses=%d items=%d" % [units.size(), skills.size(), statuses.size(), items.size()])
	quit(0)

func _save(resource: Resource, path: String) -> Error:
	resource.resource_path = path
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		printerr("SAVE FAILED %s error=%d" % [path, error])
	return error

func _unit(id: String, name: String, hp: int, mp: int, atk: int, defense: int, magic: int, resistance: int, speed: int, crit: float, skills: Array, ai_profile: String) -> UnitData:
	var unit := UnitData.new()
	unit.id = StringName(id)
	unit.display_name = name
	unit.max_hp = hp
	unit.max_mp = mp
	unit.atk = atk
	unit.defense = defense
	unit.magic = magic
	unit.resistance = resistance
	unit.speed = speed
	unit.crit_rate = crit
	for skill_id in skills:
		unit.skills.append(StringName(skill_id))
	unit.ai_profile = StringName(ai_profile)
	return unit

func _skill(id: String, name: String, mp_cost: int, target_type: int, max_targets: int, effects: Array, visual_id: String, shout: String) -> SkillData:
	var skill := SkillData.new()
	skill.id = StringName(id)
	skill.display_name = name
	skill.mp_cost = mp_cost
	skill.target_type = target_type
	skill.max_targets = max_targets
	for effect in effects:
		skill.effects.append(effect)
	skill.visual_id = StringName(visual_id)
	skill.shout_text = shout
	return skill

func _build_statuses() -> Dictionary:
	var result := {}

	var poison := StatusData.new()
	poison.id = &"poison"
	poison.display_name = "中毒"
	poison.kind = StatusData.Kind.DEBUFF
	poison.duration = 3
	poison.poison_max_hp_ratio = 0.08
	poison.display_color = Color(0.6, 0.9, 0.3)
	result[poison.id] = poison

	var armor_down := StatusData.new()
	armor_down.id = &"armor_down"
	armor_down.display_name = "破甲"
	armor_down.kind = StatusData.Kind.DEBUFF
	armor_down.duration = 2
	armor_down.defense_mult = 0.75
	armor_down.display_color = Color(1.0, 0.6, 0.2)
	result[armor_down.id] = armor_down

	var war_cry := StatusData.new()
	war_cry.id = &"war_cry"
	war_cry.display_name = "战吼"
	war_cry.kind = StatusData.Kind.BUFF
	war_cry.duration = 2
	war_cry.atk_mult = 1.2
	war_cry.display_color = Color(1.0, 0.35, 0.25)
	result[war_cry.id] = war_cry

	var defending := StatusData.new()
	defending.id = &"defending"
	defending.display_name = "防御"
	defending.kind = StatusData.Kind.BUFF
	defending.duration = 99
	defending.expires_on_owner_action = true
	defending.damage_taken_mult = 0.5
	defending.seal_resist_bonus = 0.3
	defending.display_color = Color(0.4, 0.7, 1.0)
	result[defending.id] = defending

	var sealed := StatusData.new()
	sealed.id = &"sealed"
	sealed.display_name = "封印"
	sealed.kind = StatusData.Kind.DEBUFF
	sealed.duration = 1
	sealed.skips_action = true
	sealed.display_color = Color(0.7, 0.4, 1.0)
	result[sealed.id] = sealed

	return result

func _build_skills() -> Dictionary:
	var result := {}

	result[&"sweep"] = _skill("sweep", "横扫千军", 30, SkillData.TargetType.ALL_ENEMIES, 3,
		[BattleEffect.damage(BattleTypes.DamageType.PHYSICAL, 0.85)], "slash", "看我的横扫千军！")
	result[&"armor_break"] = _skill("armor_break", "破甲击", 20, SkillData.TargetType.SINGLE_ENEMY, 1,
		[BattleEffect.damage(BattleTypes.DamageType.PHYSICAL, 1.25), BattleEffect.apply_status(&"armor_down", 1.0)], "slash", "破甲！")
	result[&"fire_spell"] = _skill("fire_spell", "烈火咒", 25, SkillData.TargetType.SINGLE_ENEMY, 1,
		[BattleEffect.damage(BattleTypes.DamageType.MAGIC, 1.5)], "fire", "烈火焚身！")
	result[&"thunder_storm"] = _skill("thunder_storm", "雷霆万钧", 45, SkillData.TargetType.ALL_ENEMIES, 99,
		[BattleEffect.damage(BattleTypes.DamageType.MAGIC, 0.9)], "thunder", "雷霆万钧！")
	result[&"seal_talisman"] = _skill("seal_talisman", "定身符", 30, SkillData.TargetType.SINGLE_ENEMY, 1,
		[BattleEffect.apply_status(&"sealed", 0.65)], "seal", "定！")
	result[&"heal_single"] = _skill("heal_single", "回春术", 30, SkillData.TargetType.SINGLE_ALLY, 1,
		[BattleEffect.heal(1.6)], "heal", "回春术！")
	result[&"cleanse"] = _skill("cleanse", "清心咒", 25, SkillData.TargetType.SINGLE_ALLY, 1,
		[BattleEffect.cleanse(1), BattleEffect.heal(0.5)], "heal", "清心！")
	result[&"heal_all"] = _skill("heal_all", "灵雨", 50, SkillData.TargetType.ALL_ALLIES, 99,
		[BattleEffect.heal(0.8)], "heal", "灵雨术！")
	result[&"poison_strike"] = _skill("poison_strike", "淬毒击", 0, SkillData.TargetType.SINGLE_ENEMY, 1,
		[BattleEffect.damage(BattleTypes.DamageType.PHYSICAL, 0.9), BattleEffect.apply_status(&"poison", 1.0)], "poison", "尝尝这个！")
	result[&"ground_split"] = _skill("ground_split", "裂地斩", 20, SkillData.TargetType.ALL_ENEMIES, 2,
		[BattleEffect.damage(BattleTypes.DamageType.PHYSICAL, 1.0)], "aoe", "大地裂开吧！")
	result[&"war_cry"] = _skill("war_cry", "战吼", 15, SkillData.TargetType.SELF, 1,
		[BattleEffect.apply_status(&"war_cry", 1.0)], "buff", "吼！")
	result[&"fox_fire"] = _skill("fox_fire", "妖火", 20, SkillData.TargetType.SINGLE_ENEMY, 1,
		[BattleEffect.damage(BattleTypes.DamageType.MAGIC, 1.3)], "fire", "妖火！")
	result[&"charm_seal"] = _skill("charm_seal", "魅惑封印", 25, SkillData.TargetType.SINGLE_ENEMY, 1,
		[BattleEffect.apply_status(&"sealed", 0.6)], "seal", "别动哦～")

	return result

func _build_items() -> Dictionary:
	var result := {}

	var potion_hp := ItemData.new()
	potion_hp.id = &"potion_hp"
	potion_hp.display_name = "金疮药"
	potion_hp.max_uses = 3
	potion_hp.effects.append(BattleEffect.heal(0.0, 220))
	result[potion_hp.id] = potion_hp

	var potion_mp := ItemData.new()
	potion_mp.id = &"potion_mp"
	potion_mp.display_name = "凝神散"
	potion_mp.max_uses = 3
	potion_mp.effects.append(BattleEffect.restore_mp(80))
	result[potion_mp.id] = potion_mp

	return result

func _build_units() -> Dictionary:
	var result := {}

	result[&"hero_swordsman"] = _unit("hero_swordsman", "剑客·凌霄", 620, 80, 118, 72, 20, 50, 92, 0.18, ["sweep", "armor_break"], "none")
	result[&"hero_mage"] = _unit("hero_mage", "法师·青鸾", 460, 220, 40, 45, 135, 85, 85, 0.10, ["fire_spell", "thunder_storm", "seal_talisman"], "none")
	result[&"hero_healer"] = _unit("hero_healer", "医师·白术", 540, 180, 52, 58, 105, 78, 78, 0.08, ["heal_single", "cleanse", "heal_all"], "none")
	result[&"mob_a"] = _unit("mob_a", "妖兵·甲", 380, 0, 82, 40, 10, 30, 70, 0.05, [], "melee")
	result[&"mob_b"] = _unit("mob_b", "妖兵·乙", 380, 0, 78, 40, 10, 30, 70, 0.05, ["poison_strike"], "poison_melee")
	result[&"boss_brute"] = _unit("boss_brute", "妖将·裂山", 720, 60, 105, 65, 20, 45, 62, 0.10, ["ground_split", "war_cry"], "brute")
	result[&"boss_fox"] = _unit("boss_fox", "狐妖·媚娘", 420, 120, 30, 38, 110, 70, 88, 0.08, ["fox_fire", "charm_seal"], "fox")

	return result

func _build_encounter() -> EncounterData:
	var script := EncounterScript.new()
	script.intro_lines = [
		"狐妖·媚娘：擅闯竹林的凡人，留下买路财！",
		"剑客·凌霄：正好试试新练的招式。",
	]
	script.first_kill_lines = ["医师·白术：别恋战，稳住阵型！"]
	script.victory_lines = ["剑客·凌霄：不过如此。"]
	script.defeat_lines = ["狐妖·媚娘：这点本事也敢闯山？"]

	var encounter := EncounterData.new()
	encounter.id = &"enc_bamboo_01"
	encounter.ally_unit_ids = [&"hero_swordsman", &"hero_mage", &"hero_healer"]
	encounter.enemy_unit_ids = [&"mob_a", &"mob_b", &"boss_brute", &"boss_fox"]
	encounter.item_counts = {"potion_hp": 3, "potion_mp": 3}
	encounter.reward_exp = 1200
	encounter.reward_gold = 350
	encounter.max_rounds = 30
	encounter.script_data = script
	return encounter
