extends RefCounted

# 主角选择数据层：6 名预设主角、3 职业 × 2 性别、3 种族、描述/语录/四维/技能完整，
# 以及 user://character_select.cfg 的读写与无效 id 回退。

func run(t: TestContext) -> void:
	var profiles := HeroRoster.load_all()
	t.eq(profiles.size(), 6, "hero count")
	t.eq(HeroRoster.validate(profiles).size(), 0, "roster validation")

	var ids: Dictionary = {}
	var classes: Dictionary = {}
	var races: Dictionary = {}
	for profile in profiles:
		t.ok(not ids.has(profile.id), "unique id: " + String(profile.id))
		ids[profile.id] = true
		t.ok(not profile.display_name.is_empty(), "display name: " + String(profile.id))
		t.ok(not profile.title.is_empty(), "title: " + String(profile.id))
		t.ok(profile.description.length() >= 20, "description length: " + String(profile.id))
		t.ok(not profile.quote.is_empty(), "quote: " + String(profile.id))
		t.eq(profile.skills.size(), 3, "skill count: " + String(profile.id))
		for value in [profile.hp_bar, profile.atk_bar, profile.mag_bar, profile.spd_bar]:
			t.in_range(float(value), 0.0, 100.0, "stat range: " + String(profile.id))
		if not profile.portrait_path.is_empty():
			t.ok(FileAccess.file_exists(profile.portrait_path), "portrait exists: " + String(profile.id))
		races[profile.race] = true
		if not classes.has(profile.hero_class):
			classes[profile.hero_class] = {}
		classes[profile.hero_class][profile.gender] = true

	t.eq(classes.size(), 3, "three classes")
	for hero_class in HeroRoster.CLASSES:
		t.ok(classes.has(hero_class), "class present: " + hero_class)
		if classes.has(hero_class):
			var genders: Dictionary = classes[hero_class]
			t.ok(genders.has("男") and genders.has("女"), "both genders: " + hero_class)
	t.eq(races.size(), 3, "three races")
	for race in HeroRoster.RACES:
		t.ok(races.has(race), "race present: " + race)

	var first := HeroRoster.find(profiles, &"swordsman_lingxiao")
	t.ok(first != null, "find returns profile")
	t.ok(HeroRoster.find(profiles, &"missing") == null, "find missing returns null")

	var previous := HeroRoster.load_saved_id()
	var had_previous := not previous.is_empty()
	t.eq(HeroRoster.save_id(&"mage_qingluan"), OK, "save valid id")
	t.eq(HeroRoster.load_saved_id(), &"mage_qingluan", "load saved id")
	t.eq(HeroRoster.save_id(&"does_not_exist"), OK, "save invalid id file")
	t.eq(HeroRoster.load_saved_id(), &"", "invalid saved id falls back to empty")

	if had_previous:
		HeroRoster.save_id(previous)
	else:
		HeroRoster.clear_saved_id()
