# Godot 回合制战斗 Demo — 战斗内核实施计划（Plan 1 / 2）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付一个可在 headless 下完整运行的 3v4 回合制战斗内核：确定性结算、数据化内容、录像/回放、不变量校验与自动化测试。

**Architecture:** 纯逻辑层 `core/` 只依赖注入的 `BattleRng`，不碰 SceneTree；表现层通过有序 `BattleEvent` 消费结果。所有战斗内容存为 `.tres` 资源，由 `ContentDB` 加载。`BattleEngine` 负责“一回合 = 记录意图 → 结算 → 记录事件与摘要”。

**Tech Stack:** Godot 4.6 stable、GDScript、`godot --headless -s` 自写测试运行器、`HashingContext` SHA-256、JSON 录像。

**Scope note:** 本计划是两份计划中的第 1 份，对应规格 M1–M2（内核、规则、录像回放、测试）。表现层/UI/美术/调试浮层在 Plan 2 中，于本计划全部测试通过后编写；本计划结束时已可通过代码驱动完整战斗并回放。

## Global Constraints

- 引擎固定 Godot 4.6 stable；不引入第三方插件或库。
- `core/` 下任何脚本禁止访问 `Node`、`SceneTree`、`Tween`、`await`、系统时间（录像元数据除外）、全局随机（`randf()` / `randi()`）。
- 所有逻辑随机只允许通过注入的 `BattleRng`；表现层将来使用独立 `VisualRng`。
- 战斗内容必须来自 `.tres` 资源，不得在结算代码里硬编码技能数值。
- 单位/技能/状态/物品 ID 使用稳定字符串：`hero_swordsman`、`hero_mage`、`hero_healer`、`mob_a`、`mob_b`、`boss_brute`、`boss_fox`、`enc_bamboo_01`。
- 事件必须带自增 `seq`（从 1 开始）；同一输入与种子必须产生逐字节一致的事件序列。
- 代码文件编码 UTF-8；GDScript 2.0 语法；类型标注尽量完整。
- 所有命令从仓库根目录 `/Users/ks_128/Documents/modelfw_demo` 执行；Godot 可执行文件为 `godot`。
- 测试命令固定为 `godot --headless --path godot-battle -s tests/run_tests.gd`，退出码 0 才算通过。
- 每个任务结束必须提交，提交信息使用本计划给出的文案。

---

## File Structure (Plan 1)

```
godot-battle/
├── project.godot
├── .gitignore
├── core/
│   ├── battle_types.gd
│   ├── battle_rng.gd
│   ├── battle_event.gd
│   ├── battle_intent.gd
│   ├── status_instance.gd
│   ├── battle_unit_state.gd
│   ├── battle_state.gd
│   ├── battle_factory.gd
│   ├── battle_resolver.gd
│   ├── battle_engine.gd
│   ├── battle_digest.gd
│   ├── battle_invariants.gd
│   ├── battle_recorder.gd
│   ├── battle_replay.gd
│   ├── content_db.gd
│   └── data/
│       ├── battle_effect.gd
│       ├── unit_data.gd
│       ├── skill_data.gd
│       ├── status_data.gd
│       ├── item_data.gd
│       ├── encounter_data.gd
│       └── encounter_script.gd
├── data/
│   ├── units/  skills/  statuses/  items/  encounters/
├── tools/
│   ├── build_content.gd
│   ├── make_golden.gd
│   └── replay.gd
├── tests/
│   ├── test_context.gd
│   ├── run_tests.gd
│   ├── cases/
│   └── golden/
└── docs/
    ├── PROGRESS.md
    └── TECH_NOTES.md
```

---

## Task 1: 工程骨架与 headless 测试运行器

**Files:**
- Create: `godot-battle/project.godot`
- Create: `godot-battle/.gitignore`
- Create: `godot-battle/tests/test_context.gd`
- Create: `godot-battle/tests/run_tests.gd`
- Create: `godot-battle/tests/cases/test_smoke.gd`

**Interfaces:**
- Consumes: 无
- Produces: `TestContext`（`ok` / `eq` / `in_range` / `near`）；`tests/run_tests.gd` 约定所有 `tests/cases/*.gd` 暴露 `func run(t: TestContext) -> void`。

- [ ] **Step 1: 先写冒烟测试**

`godot-battle/tests/cases/test_smoke.gd`:

```gdscript
extends RefCounted

func run(t: TestContext) -> void:
    var probe := TestContext.new()
    probe.ok(false, "intentional failure")
    probe.eq(1, 2, "intentional mismatch")
    t.eq(probe.assertions, 2, "TestContext counts assertions")
    t.eq(probe.failures.size(), 2, "TestContext records failures")
```

- [ ] **Step 2: 运行，确认失败**

Run:

```bash
cd /Users/ks_128/Documents/modelfw_demo
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: 失败或报错（项目或测试运行器尚不存在）。

- [ ] **Step 3: 创建工程与测试运行器**

`godot-battle/project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="山海试炼"
config/features=PackedStringArray("4.6", "GL Compatibility")

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

`godot-battle/.gitignore`:

```gitignore
.godot/
*.tmp
```

`godot-battle/tests/test_context.gd`:

```gdscript
class_name TestContext
extends RefCounted

var failures: Array[String] = []
var assertions: int = 0

func ok(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s — expected=%s actual=%s" % [message, str(expected), str(actual)])

func in_range(value: float, low: float, high: float, message: String) -> void:
	assertions += 1
	if value < low or value > high:
		failures.append("%s — %s not in [%s, %s]" % [message, str(value), str(low), str(high)])

func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > epsilon:
		failures.append("%s — expected≈%s actual=%s" % [message, str(expected), str(actual)])

func has(text: String, needle: String, message: String) -> void:
	assertions += 1
	if not text.contains(needle):
		failures.append("%s — '%s' not found in '%s'" % [message, needle, text])
```

`godot-battle/tests/run_tests.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var total_assertions := 0
	var total_failures := 0
	var cases_dir := DirAccess.open("res://tests/cases")
	if cases_dir == null:
		printerr("Cannot open res://tests/cases")
		quit(1)
		return
	var files := cases_dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		var path := "res://tests/cases/" + file_name
		var script: Script = load(path)
		if script == null:
			printerr("FAILED TO LOAD " + path)
			total_failures += 1
			continue
		var test_case: Object = script.new()
		var ctx := TestContext.new()
		Callable(test_case, "run").call(ctx)
		total_assertions += ctx.assertions
		total_failures += ctx.failures.size()
		if ctx.failures.is_empty():
			print("PASS %s (%d assertions)" % [file_name, ctx.assertions])
		else:
			printerr("FAIL %s (%d assertions)" % [file_name, ctx.assertions])
			for failure in ctx.failures:
				printerr("  - " + failure)
	print("RESULT: %d assertions, %d failures" % [total_assertions, total_failures])
	quit(0 if total_failures == 0 else 1)
```

- [ ] **Step 4: 导入工程并运行测试**

Run:

```bash
cd /Users/ks_128/Documents/modelfw_demo
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected:

```text
PASS test_smoke.gd (2 assertions)
RESULT: 2 assertions, 0 failures
```

- [ ] **Step 5: 提交**

```bash
cd /Users/ks_128/Documents/modelfw_demo
git add godot-battle/project.godot godot-battle/.gitignore godot-battle/tests
git commit -m "build(battle): Godot 工程骨架与 headless 测试运行器"
```

---

## Task 2: 核心基础类型（RNG / 事件 / 意图）

**Files:**
- Create: `godot-battle/core/battle_types.gd`
- Create: `godot-battle/core/battle_rng.gd`
- Create: `godot-battle/core/battle_event.gd`
- Create: `godot-battle/core/battle_intent.gd`
- Create: `godot-battle/tests/cases/test_rng.gd`
- Create: `godot-battle/tests/cases/test_serialization.gd`

**Interfaces:**
- Consumes: `TestContext`
- Produces:
  - `BattleTypes.Side { ALLY, ENEMY }`、`IntentKind { ATTACK, SKILL, ITEM, DEFEND, FLEE }`、`DamageType { PHYSICAL, MAGIC, HEAL, NONE }`、`Outcome { NONE, VICTORY, DEFEAT, ESCAPED }`
  - `BattleRng.new(seed: int)`、`randf_range`、`randi_range`、`chance`、`state()`、`set_state()`
  - `BattleEvent` 字段 `seq/round/type/source_id/target_ids/data`、`to_dict()`、`from_dict()`、`canonical_json()`
  - `BattleIntent` 字段 `actor_id/kind/skill_id/item_id/target_ids`、`make()`、`to_dict()`、`from_dict()`

- [ ] **Step 1: 写失败测试**

`godot-battle/tests/cases/test_rng.gd`:

```gdscript
extends RefCounted

func run(t: TestContext) -> void:
	var a := BattleRng.new(42)
	var b := BattleRng.new(42)
	for i in 20:
		t.eq(a.randi_range(0, 999), b.randi_range(0, 999), "同种子产生相同序列")

	var c := BattleRng.new(7)
	c.randi_range(0, 10)
	c.randi_range(0, 10)
	var saved := c.state()
	var expected := c.randi_range(0, 1000)
	c.set_state(saved)
	t.eq(c.randi_range(0, 1000), expected, "state 可恢复随机流")

	t.ok(BattleRng.new(1).randi_range(0, 100000) != BattleRng.new(2).randi_range(0, 100000), "不同种子产生不同序列")
```

`godot-battle/tests/cases/test_serialization.gd`:

```gdscript
extends RefCounted

func run(t: TestContext) -> void:
	var event := BattleEvent.make(3, 2, &"damage", &"hero_mage", [&"mob_a", &"mob_b"], {"amount": 12, "crit": true})
	var restored := BattleEvent.from_dict(event.to_dict())
	t.eq(restored.canonical_json(), event.canonical_json(), "事件序列化往返一致")
	t.eq(restored.target_ids.size(), 2, "目标数量保留")
	t.eq(String(restored.target_ids[1]), "mob_b", "目标顺序保留")

	var intent := BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.SKILL, [&"boss_fox"], &"sweep")
	var intent2 := BattleIntent.from_dict(intent.to_dict())
	t.eq(String(intent2.actor_id), "hero_swordsman", "意图 actor 往返")
	t.eq(intent2.kind, BattleTypes.IntentKind.SKILL, "意图 kind 往返")
	t.eq(String(intent2.skill_id), "sweep", "意图技能往返")
	t.eq(intent2.target_ids.size(), 1, "意图目标往返")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 解析错误，提示 `BattleRng` / `BattleEvent` / `BattleIntent` 未定义。

- [ ] **Step 3: 实现基础类型**

`godot-battle/core/battle_types.gd`:

```gdscript
class_name BattleTypes
extends RefCounted

enum Side { ALLY, ENEMY }
enum IntentKind { ATTACK, SKILL, ITEM, DEFEND, FLEE }
enum DamageType { PHYSICAL, MAGIC, HEAL, NONE }
enum Outcome { NONE, VICTORY, DEFEAT, ESCAPED }
```

`godot-battle/core/battle_rng.gd`:

```gdscript
class_name BattleRng
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func chance(probability: float) -> bool:
	return _rng.randf() < probability

func state() -> int:
	return _rng.state

func set_state(saved_state: int) -> void:
	_rng.state = saved_state
```

`godot-battle/core/battle_event.gd`:

```gdscript
class_name BattleEvent
extends RefCounted

var seq: int = 0
var round: int = 0
var type: StringName = &""
var source_id: StringName = &""
var target_ids: Array[StringName] = []
var data: Dictionary = {}

static func make(p_seq: int, p_round: int, p_type: StringName, p_source: StringName, p_targets: Array, p_data: Dictionary = {}) -> BattleEvent:
	var event := BattleEvent.new()
	event.seq = p_seq
	event.round = p_round
	event.type = p_type
	event.source_id = p_source
	for target in p_targets:
		event.target_ids.append(StringName(target))
	event.data = p_data.duplicate(true)
	return event

func to_dict() -> Dictionary:
	var targets: Array = []
	for target in target_ids:
		targets.append(String(target))
	return {
		"seq": seq,
		"round": round,
		"type": String(type),
		"source_id": String(source_id),
		"target_ids": targets,
		"data": data,
	}

static func from_dict(source: Dictionary) -> BattleEvent:
	var event := BattleEvent.new()
	event.seq = int(source.get("seq", 0))
	event.round = int(source.get("round", 0))
	event.type = StringName(source.get("type", ""))
	event.source_id = StringName(source.get("source_id", ""))
	for target in source.get("target_ids", []):
		event.target_ids.append(StringName(target))
	event.data = source.get("data", {}).duplicate(true)
	return event

func canonical_json() -> String:
	return JSON.stringify(to_dict(), "", true)
```

`godot-battle/core/battle_intent.gd`:

```gdscript
class_name BattleIntent
extends RefCounted

var actor_id: StringName = &""
var kind: int = BattleTypes.IntentKind.ATTACK
var skill_id: StringName = &""
var item_id: StringName = &""
var target_ids: Array[StringName] = []

static func make(p_actor: StringName, p_kind: int, p_targets: Array = [], p_skill: StringName = &"", p_item: StringName = &"") -> BattleIntent:
	var intent := BattleIntent.new()
	intent.actor_id = p_actor
	intent.kind = p_kind
	intent.skill_id = p_skill
	intent.item_id = p_item
	for target in p_targets:
		intent.target_ids.append(StringName(target))
	return intent

func to_dict() -> Dictionary:
	var targets: Array = []
	for target in target_ids:
		targets.append(String(target))
	return {
		"actor_id": String(actor_id),
		"kind": kind,
		"skill_id": String(skill_id),
		"item_id": String(item_id),
		"target_ids": targets,
	}

static func from_dict(source: Dictionary) -> BattleIntent:
	var intent := BattleIntent.new()
	intent.actor_id = StringName(source.get("actor_id", ""))
	intent.kind = int(source.get("kind", BattleTypes.IntentKind.ATTACK))
	intent.skill_id = StringName(source.get("skill_id", ""))
	intent.item_id = StringName(source.get("item_id", ""))
	for target in source.get("target_ids", []):
		intent.target_ids.append(StringName(target))
	return intent
```

- [ ] **Step 4: 运行，确认通过**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `RESULT: ... 0 failures`，且包含 `PASS test_rng.gd`、`PASS test_serialization.gd`。

- [ ] **Step 5: 提交**

```bash
git add godot-battle/core godot-battle/tests/cases
git commit -m "feat(battle): 核心类型、确定性 RNG 与事件序列化"
```

---

## Task 3: 内容资源、内容生成器与 ContentDB

**Files:**
- Create: `godot-battle/core/data/battle_effect.gd`
- Create: `godot-battle/core/data/unit_data.gd`
- Create: `godot-battle/core/data/skill_data.gd`
- Create: `godot-battle/core/data/status_data.gd`
- Create: `godot-battle/core/data/item_data.gd`
- Create: `godot-battle/core/data/encounter_data.gd`
- Create: `godot-battle/core/data/encounter_script.gd`
- Create: `godot-battle/core/battle_digest.gd`
- Create: `godot-battle/core/content_db.gd`
- Create: `godot-battle/tools/build_content.gd`
- Create: `godot-battle/tests/cases/test_content.gd`
- Generated: `godot-battle/data/**/*.tres`

**Interfaces:**
- Consumes: `BattleTypes`, `BattleEvent`, `TestContext`
- Produces:
  - `BattleEffect`（`Kind { DAMAGE, HEAL, APPLY_STATUS, CLEANSE, RESTORE_MP }`，字段 `kind/damage_type/power/status_id/status_chance/cleanse_count/flat_amount`）
  - `UnitData`（`id/display_name/max_hp/max_mp/atk/defense/magic/resistance/speed/crit_rate/skills/ai_profile/sprite_path/visual_scale`）
  - `SkillData`（`id/display_name/mp_cost/target_type/max_targets/effects/visual_id/shout_text`）
  - `StatusData`（`id/display_name/kind/duration/expires_on_owner_action/skips_action/damage_taken_mult/seal_resist_bonus/atk_mult/defense_mult/poison_max_hp_ratio/icon_path/display_color`）
  - `ItemData`（`id/display_name/effects/max_uses/icon_path`）
  - `EncounterData`（`id/ally_unit_ids/enemy_unit_ids/item_counts/reward_exp/reward_gold/max_rounds/background_path/bgm_path/script`）
  - `EncounterScript`（`intro_lines/first_kill_lines/victory_lines/defeat_lines`、`beats_for_start()`、`beats_for_event(ev)`、`beats_for_end(outcome)`）
  - `BattleDigest.sha256(text) -> String`
  - `ContentDB.load_all(base_dir) -> ContentDB`、`get_unit/get_skill/get_status/get_item/get_encounter`、`content_hash()`

- [ ] **Step 1: 写内容加载失败测试**

`godot-battle/tests/cases/test_content.gd`:

```gdscript
extends RefCounted

func run(t: TestContext) -> void:
	var db := ContentDB.load_all()
	t.eq(db.units.size(), 7, "7 个单位")
	t.eq(db.skills.size(), 13, "13 个技能")
	t.eq(db.statuses.size(), 5, "5 个状态")
	t.eq(db.items.size(), 2, "2 个道具")
	t.eq(db.encounters.size(), 1, "1 个遭遇战")

	var encounter: EncounterData = db.get_encounter(&"enc_bamboo_01")
	t.ok(encounter != null, "遭遇战存在")
	t.eq(encounter.ally_unit_ids.size(), 3, "我方 3 人")
	t.eq(encounter.enemy_unit_ids.size(), 4, "敌方 4 人")
	for unit_id in encounter.ally_unit_ids + encounter.enemy_unit_ids:
		t.ok(db.get_unit(unit_id) != null, "单位资源存在: " + String(unit_id))

	for skill_id in [&"sweep", &"seal_talisman", &"heal_all", &"poison_strike", &"charm_seal"]:
		var skill: SkillData = db.get_skill(skill_id)
		t.ok(skill != null, "技能存在: " + String(skill_id))
		for effect in skill.effects:
			if effect.kind == BattleEffect.Kind.APPLY_STATUS:
				t.ok(db.get_status(effect.status_id) != null, "状态引用有效: " + String(effect.status_id))

	var hash_a := db.content_hash()
	var hash_b := ContentDB.load_all().content_hash()
	t.eq(hash_b, hash_a, "内容 hash 稳定")
	t.has(hash_a, "sha256:", "内容 hash 格式")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 解析错误，提示资源类或 `ContentDB` 未定义。

- [ ] **Step 3: 实现资源类、摘要与 ContentDB**

`godot-battle/core/data/battle_effect.gd`:

```gdscript
class_name BattleEffect
extends Resource

enum Kind { DAMAGE, HEAL, APPLY_STATUS, CLEANSE, RESTORE_MP }

@export var kind: Kind = Kind.DAMAGE
@export var damage_type: int = BattleTypes.DamageType.PHYSICAL
@export var power: float = 1.0
@export var status_id: StringName = &""
@export var status_chance: float = 1.0
@export var cleanse_count: int = 1
@export var flat_amount: int = 0

static func damage(p_type: int, p_power: float) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.DAMAGE
	effect.damage_type = p_type
	effect.power = p_power
	return effect

static func heal(p_power: float, p_flat: int = 0) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.HEAL
	effect.damage_type = BattleTypes.DamageType.HEAL
	effect.power = p_power
	effect.flat_amount = p_flat
	return effect

static func apply_status(p_status_id: StringName, p_chance: float = 1.0) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.APPLY_STATUS
	effect.status_id = p_status_id
	effect.status_chance = p_chance
	return effect

static func cleanse(p_count: int = 1) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.CLEANSE
	effect.cleanse_count = p_count
	return effect

static func restore_mp(p_amount: int) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.kind = Kind.RESTORE_MP
	effect.flat_amount = p_amount
	return effect
```

`godot-battle/core/data/unit_data.gd`:

```gdscript
class_name UnitData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 1
@export var max_mp: int = 0
@export var atk: int = 0
@export var defense: int = 0
@export var magic: int = 0
@export var resistance: int = 0
@export var speed: int = 0
@export var crit_rate: float = 0.0
@export var skills: Array[StringName] = []
@export var ai_profile: StringName = &"none"
@export var sprite_path: String = ""
@export var visual_scale: float = 1.0
```

`godot-battle/core/data/skill_data.gd`:

```gdscript
class_name SkillData
extends Resource

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var mp_cost: int = 0
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var max_targets: int = 1
@export var effects: Array[BattleEffect] = []
@export var visual_id: StringName = &"generic"
@export var shout_text: String = ""
```

`godot-battle/core/data/status_data.gd`:

```gdscript
class_name StatusData
extends Resource

enum Kind { BUFF, DEBUFF }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.BUFF
@export var duration: int = 1
@export var expires_on_owner_action: bool = false
@export var skips_action: bool = false
@export var damage_taken_mult: float = 1.0
@export var seal_resist_bonus: float = 0.0
@export var atk_mult: float = 1.0
@export var defense_mult: float = 1.0
@export var poison_max_hp_ratio: float = 0.0
@export var icon_path: String = ""
@export var display_color: Color = Color.WHITE
```

`godot-battle/core/data/item_data.gd`:

```gdscript
class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var effects: Array[BattleEffect] = []
@export var max_uses: int = 3
@export var icon_path: String = ""
```

`godot-battle/core/data/encounter_script.gd`:

```gdscript
class_name EncounterScript
extends Resource

@export var intro_lines: Array[String] = []
@export var first_kill_lines: Array[String] = []
@export var victory_lines: Array[String] = []
@export var defeat_lines: Array[String] = []

var _first_kill_done: bool = false

func reset() -> void:
	_first_kill_done = false

func beats_for_start() -> Array[Dictionary]:
	if intro_lines.is_empty():
		return []
	return [{"kind": "dialogue", "lines": intro_lines}]

func beats_for_event(event: BattleEvent) -> Array[Dictionary]:
	if event.type == &"death" and not _first_kill_done:
		_first_kill_done = true
		if not first_kill_lines.is_empty():
			return [{"kind": "dialogue", "lines": first_kill_lines}]
	return []

func beats_for_end(outcome: int) -> Array[Dictionary]:
	if outcome == BattleTypes.Outcome.VICTORY and not victory_lines.is_empty():
		return [{"kind": "dialogue", "lines": victory_lines}]
	if outcome == BattleTypes.Outcome.DEFEAT and not defeat_lines.is_empty():
		return [{"kind": "dialogue", "lines": defeat_lines}]
	return []
```

`godot-battle/core/data/encounter_data.gd`:

```gdscript
class_name EncounterData
extends Resource

@export var id: StringName = &""
@export var ally_unit_ids: Array[StringName] = []
@export var enemy_unit_ids: Array[StringName] = []
@export var item_counts: Dictionary = {}
@export var reward_exp: int = 0
@export var reward_gold: int = 0
@export var max_rounds: int = 30
@export var background_path: String = ""
@export var bgm_path: String = ""
@export var script: EncounterScript
```

`godot-battle/core/battle_digest.gd`:

```gdscript
class_name BattleDigest
extends RefCounted

static func sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return "sha256:" + context.finish().hex_encode()
```

`godot-battle/core/content_db.gd`:

```gdscript
class_name ContentDB
extends RefCounted

var units: Dictionary = {}
var skills: Dictionary = {}
var statuses: Dictionary = {}
var items: Dictionary = {}
var encounters: Dictionary = {}
var _hash_cache: String = ""

static func load_all(base_dir: String = "res://data") -> ContentDB:
	var db := ContentDB.new()
	db._load_dir(base_dir + "/units", db.units)
	db._load_dir(base_dir + "/skills", db.skills)
	db._load_dir(base_dir + "/statuses", db.statuses)
	db._load_dir(base_dir + "/items", db.items)
	db._load_dir(base_dir + "/encounters", db.encounters)
	return db

func _load_dir(dir_path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Content directory missing: " + dir_path)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var resource: Resource = load(dir_path + "/" + file_name)
		if resource == null:
			push_error("Cannot load content: " + dir_path + "/" + file_name)
			continue
		target[resource.get("id")] = resource

func get_unit(id: StringName) -> UnitData:
	return units.get(id)
func get_skill(id: StringName) -> SkillData:
	return skills.get(id)
func get_status(id: StringName) -> StatusData:
	return statuses.get(id)
func get_item(id: StringName) -> ItemData:
	return items.get(id)
func get_encounter(id: StringName) -> EncounterData:
	return encounters.get(id)

func content_hash() -> String:
	if not _hash_cache.is_empty():
		return _hash_cache
	var files := _collect_tres("res://data")
	files.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		context.update(path.to_utf8_buffer())
		context.update(text.to_utf8_buffer())
	_hash_cache = "sha256:" + context.finish().hex_encode()
	return _hash_cache

func _collect_tres(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			result.append(dir_path + "/" + file_name)
	for sub_dir in dir.get_directories():
		result.append_array(_collect_tres(dir_path + "/" + sub_dir))
	return result
```

- [ ] **Step 4: 实现内容生成器**

`godot-battle/tools/build_content.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	for dir_path in ["res://data/units", "res://data/skills", "res://data/statuses", "res://data/items", "res://data/encounters"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var statuses := _build_statuses()
	for status in statuses.values():
		_save(status, "res://data/statuses/%s.tres" % String(status.id))

	var skills := _build_skills(statuses)
	for skill in skills.values():
		_save(skill, "res://data/skills/%s.tres" % String(skill.id))

	var items := _build_items()
	for item in items.values():
		_save(item, "res://data/items/%s.tres" % String(item.id))

	var units := _build_units()
	for unit in units.values():
		_save(unit, "res://data/units/%s.tres" % String(unit.id))

	var encounter := _build_encounter()
	_save(encounter, "res://data/encounters/enc_bamboo_01.tres")

	print("CONTENT_BUILT units=%d skills=%d statuses=%d items=%d" % [units.size(), skills.size(), statuses.size(), items.size()])
	quit(0)

func _save(resource: Resource, path: String) -> void:
	resource.resource_path = path
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		printerr("SAVE FAILED %s error=%d" % [path, error])
		quit(1)

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

func _build_skills(statuses: Dictionary) -> Dictionary:
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
	encounter.script = script
	return encounter
```

- [ ] **Step 5: 生成内容并运行测试**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tools/build_content.gd
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `CONTENT_BUILT units=7 skills=13 statuses=5 items=2`，随后测试 `RESULT: ... 0 failures`，包含 `PASS test_content.gd`。

- [ ] **Step 6: 提交**

```bash
git add godot-battle/core godot-battle/data godot-battle/tools/build_content.gd godot-battle/tests/cases/test_content.gd
git commit -m "feat(battle): 数据化战斗内容与 ContentDB"
```

## Task 4: 战斗状态、回合调度与普攻结算

**Files:**
- Create: `godot-battle/core/status_instance.gd`
- Create: `godot-battle/core/battle_unit_state.gd`
- Create: `godot-battle/core/battle_state.gd`
- Create: `godot-battle/core/battle_factory.gd`
- Create: `godot-battle/core/battle_resolver.gd`
- Create: `godot-battle/core/battle_engine.gd`
- Create: `godot-battle/tests/cases/test_battle_basic.gd`

**Interfaces:**
- Consumes: `ContentDB`、`UnitData`、`StatusData`、`BattleRng`、`BattleEvent`、`BattleIntent`
- Produces:
  - `StatusInstance.new(data: StatusData, round: int)`
  - `BattleUnitState`（`id/data/side/slot/hp/mp/statuses/alive`；`is_alive/find_status/has_status/add_status/remove_status/atk_value/defense_value/magic_value/resistance_value/damage_taken_mult/seal_resist_bonus`）
  - `BattleState`（`round/outcome/units/item_uses/encounter/max_rounds`；`get_unit/living/is_over/item_remaining/consume_item`）
  - `BattleFactory.create(encounter, content) -> BattleState`
  - `BattleEngine.new(encounter, content, seed)`；`resolve_round(intents) -> Array[BattleEvent]`；`is_over()`；`outcome()`
  - `BattleResolver.new(state, rng, content)`；`resolve_round(intents) -> Array[BattleEvent]`

- [ ] **Step 1: 写失败测试**

`godot-battle/tests/cases/test_battle_basic.gd`:

```gdscript
extends RefCounted

func _unit(id: String, hp: int, atk: int, defense: int, speed: int, crit: float) -> UnitData:
	var data := UnitData.new()
	data.id = StringName(id)
	data.display_name = id
	data.max_hp = hp
	data.max_mp = 0
	data.atk = atk
	data.defense = defense
	data.magic = 0
	data.resistance = 0
	data.speed = speed
	data.crit_rate = crit
	data.ai_profile = &"melee"
	return data

func _state(entries: Array) -> BattleState:
	var state := BattleState.new()
	for entry in entries:
		state.units.append(BattleUnitState.new(entry["data"], entry["side"], entry["slot"]))
	state.max_rounds = 30
	return state

func _defend_intents(state: BattleState) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	for unit in state.living(BattleTypes.Side.ALLY):
		intents.append(BattleIntent.make(unit.id, BattleTypes.IntentKind.DEFEND))
	return intents

func _find_damage(events: Array[BattleEvent], source: String) -> BattleEvent:
	for event in events:
		if event.type == &"damage" and String(event.source_id) == source:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()

	var ally := _unit("ally", 100, 100, 0, 100, 0.0)
	var enemy := _unit("enemy", 1000, 10, 0, 10, 0.0)
	var state := _state([
		{"data": ally, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": enemy, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var resolver := BattleResolver.new(state, BattleRng.new(42), content)
	var events := resolver.resolve_round([BattleIntent.make(&"ally", BattleTypes.IntentKind.ATTACK, [&"enemy"])])
	var damage := _find_damage(events, "ally")
	t.ok(damage != null, "产生伤害事件")
	t.in_range(float(damage.data["amount"]), 90.0, 110.0, "伤害在公式范围内")
	t.eq(int(damage.data["hp_before"]) - int(damage.data["hp_after"]), int(damage.data["amount"]), "HP 变化等于伤害")

	var s1 := _unit("s1", 100, 10, 0, 100, 0.0)
	var s2 := _unit("s2", 100, 10, 0, 60, 0.0)
	var s3 := _unit("s3", 100, 10, 0, 20, 0.0)
	var e1 := _unit("e1", 100, 5, 0, 1, 0.0)
	var order_state := _state([
		{"data": s1, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": s2, "side": BattleTypes.Side.ALLY, "slot": 1},
		{"data": s3, "side": BattleTypes.Side.ALLY, "slot": 2},
		{"data": e1, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var order_events := BattleResolver.new(order_state, BattleRng.new(7), content).resolve_round(_defend_intents(order_state))
	var actors: Array[String] = []
	for event in order_events:
		if event.type == &"action_start":
			actors.append(String(event.source_id))
	t.eq(actors, ["s1", "s2", "s3", "e1"], "按速度降序行动")

	var killer := _unit("killer", 100, 1000, 0, 100, 0.0)
	var victim := _unit("victim", 10, 0, 0, 1, 0.0)
	var win_state := _state([
		{"data": killer, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": victim, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var win_events := BattleResolver.new(win_state, BattleRng.new(1), content).resolve_round([
		BattleIntent.make(&"killer", BattleTypes.IntentKind.ATTACK, [&"victim"]),
	])
	t.eq(win_state.outcome, BattleTypes.Outcome.VICTORY, "敌方全灭判胜")
	t.eq(String(win_events[win_events.size() - 1].type), "battle_end", "battle_end 是最后一个事件")

	var defender := _unit("defender", 1000, 10, 0, 10, 0.0)
	var attacker := _unit("attacker", 100, 100, 0, 100, 0.0)
	var def_state := _state([
		{"data": attacker, "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": defender, "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var defending_status := content.get_status(&"defending")
	def_state.get_unit(&"defender").add_status(defending_status, 0)
	var def_events := BattleResolver.new(def_state, BattleRng.new(3), content).resolve_round([
		BattleIntent.make(&"attacker", BattleTypes.IntentKind.ATTACK, [&"defender"]),
	])
	var def_damage := _find_damage(def_events, "attacker")
	t.in_range(float(def_damage.data["amount"]), 45.0, 55.0, "防御后伤害减半")

	var encounter := content.get_encounter(&"enc_bamboo_01")
	var engine := BattleEngine.new(encounter, content, 123)
	t.eq(engine.state.living(BattleTypes.Side.ALLY).size(), 3, "引擎生成 3 名我方")
	t.eq(engine.state.living(BattleTypes.Side.ENEMY).size(), 4, "引擎生成 4 名敌方")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 解析错误，提示 `BattleState` / `BattleUnitState` / `BattleResolver` / `BattleEngine` 未定义。

- [ ] **Step 3: 实现状态对象**

`godot-battle/core/status_instance.gd`:

```gdscript
class_name StatusInstance
extends RefCounted

var data: StatusData
var remaining: int
var applied_round: int

func _init(p_data: StatusData, p_round: int) -> void:
	data = p_data
	remaining = p_data.duration
	applied_round = p_round
```

`godot-battle/core/battle_unit_state.gd`:

```gdscript
class_name BattleUnitState
extends RefCounted

var id: StringName = &""
var data: UnitData
var side: int = BattleTypes.Side.ALLY
var slot: int = 0
var hp: int = 0
var mp: int = 0
var statuses: Array[StatusInstance] = []
var alive: bool = true

func _init(p_data: UnitData, p_side: int, p_slot: int) -> void:
	id = p_data.id
	data = p_data
	side = p_side
	slot = p_slot
	hp = p_data.max_hp
	mp = p_data.max_mp

func is_alive() -> bool:
	return alive and hp > 0

func find_status(status_id: StringName) -> StatusInstance:
	for status in statuses:
		if status.data.id == status_id:
			return status
	return null

func has_status(status_id: StringName) -> bool:
	return find_status(status_id) != null

func add_status(status_data: StatusData, round_number: int) -> bool:
	var existing := find_status(status_data.id)
	if existing != null:
		existing.remaining = maxi(existing.remaining, status_data.duration)
		existing.applied_round = round_number
		return false
	statuses.append(StatusInstance.new(status_data, round_number))
	return true

func remove_status(status_id: StringName) -> bool:
	for index in range(statuses.size()):
		if statuses[index].data.id == status_id:
			statuses.remove_at(index)
			return true
	return false

func atk_value() -> float:
	var multiplier := 1.0
	for status in statuses:
		multiplier *= status.data.atk_mult
	return float(data.atk) * multiplier

func defense_value() -> float:
	var multiplier := 1.0
	for status in statuses:
		multiplier *= status.data.defense_mult
	return float(data.defense) * multiplier

func magic_value() -> float:
	return float(data.magic)

func resistance_value() -> float:
	return float(data.resistance)

func damage_taken_mult() -> float:
	var multiplier := 1.0
	for status in statuses:
		multiplier *= status.data.damage_taken_mult
	return multiplier

func seal_resist_bonus() -> float:
	var bonus := 0.0
	for status in statuses:
		bonus += status.data.seal_resist_bonus
	return bonus
```

`godot-battle/core/battle_state.gd`:

```gdscript
class_name BattleState
extends RefCounted

var round: int = 0
var outcome: int = BattleTypes.Outcome.NONE
var units: Array[BattleUnitState] = []
var item_uses: Dictionary = {}
var encounter: EncounterData
var max_rounds: int = 30

func get_unit(unit_id: StringName) -> BattleUnitState:
	for unit in units:
		if unit.id == unit_id:
			return unit
	return null

func living(side: int) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for unit in units:
		if unit.side == side and unit.is_alive():
			result.append(unit)
	return result

func living_enemies_of(unit: BattleUnitState) -> Array[BattleUnitState]:
	return living(1 - unit.side)

func living_allies_of(unit: BattleUnitState) -> Array[BattleUnitState]:
	return living(unit.side)

func is_over() -> bool:
	return outcome != BattleTypes.Outcome.NONE

func item_remaining(item_id: StringName) -> int:
	return int(item_uses.get(item_id, 0))

func consume_item(item_id: StringName) -> bool:
	var remaining := item_remaining(item_id)
	if remaining <= 0:
		return false
	item_uses[item_id] = remaining - 1
	return true
```

`godot-battle/core/battle_factory.gd`:

```gdscript
class_name BattleFactory
extends RefCounted

static func create(encounter: EncounterData, content: ContentDB) -> BattleState:
	var state := BattleState.new()
	state.encounter = encounter
	state.max_rounds = encounter.max_rounds
	var slot := 0
	for unit_id in encounter.ally_unit_ids:
		var data := content.get_unit(unit_id)
		if data == null:
			push_error("Missing ally unit: " + String(unit_id))
			continue
		state.units.append(BattleUnitState.new(data, BattleTypes.Side.ALLY, slot))
		slot += 1
	slot = 0
	for unit_id in encounter.enemy_unit_ids:
		var data := content.get_unit(unit_id)
		if data == null:
			push_error("Missing enemy unit: " + String(unit_id))
			continue
		state.units.append(BattleUnitState.new(data, BattleTypes.Side.ENEMY, slot))
		slot += 1
	for item_id in encounter.item_counts:
		state.item_uses[StringName(item_id)] = int(encounter.item_counts[item_id])
	return state
```

- [ ] **Step 4: 实现基础 Resolver 与 Engine**

`godot-battle/core/battle_resolver.gd`:

```gdscript
class_name BattleResolver
extends RefCounted

var state: BattleState
var rng: BattleRng
var content: ContentDB
var events: Array[BattleEvent] = []

var _seq: int = 0
var _speed_rolls: Dictionary = {}

func _init(p_state: BattleState, p_rng: BattleRng, p_content: ContentDB) -> void:
	state = p_state
	rng = p_rng
	content = p_content

func resolve_round(player_intents: Array[BattleIntent]) -> Array[BattleEvent]:
	events = []
	_speed_rolls.clear()
	if state.is_over():
		return events
	state.round += 1
	_roll_speeds()
	var order := _ordered_living()
	var order_ids: Array[String] = []
	for unit in order:
		order_ids.append(String(unit.id))
	_emit(&"round_start", &"", order_ids, {"order": order_ids})
	var intents := _validate_player_intents(player_intents)
	for enemy in state.living(BattleTypes.Side.ENEMY):
		intents[enemy.id] = _decide_ai(enemy)
	var actions := _collect_actions(intents)
	actions.sort_custom(_compare_actions)
	for intent in actions:
		if state.is_over():
			break
		_execute_intent(intent)
		_check_end()
	if not state.is_over():
		_finish_round()
	return events

func _roll_speeds() -> void:
	for unit in state.units:
		if unit.is_alive():
			_speed_rolls[unit.id] = float(unit.data.speed) * rng.randf_range(0.95, 1.05)

func _ordered_living() -> Array[BattleUnitState]:
	var living: Array[BattleUnitState] = []
	for unit in state.living(BattleTypes.Side.ALLY):
		living.append(unit)
	for unit in state.living(BattleTypes.Side.ENEMY):
		living.append(unit)
	living.sort_custom(func(a, b):
		var sa := float(_speed_rolls.get(a.id, 0.0))
		var sb := float(_speed_rolls.get(b.id, 0.0))
		if is_equal_approx(sa, sb):
			return String(a.id) < String(b.id)
		return sa > sb)
	return living

func _validate_player_intents(player_intents: Array[BattleIntent]) -> Dictionary:
	var result := {}
	for intent in player_intents:
		var actor := state.get_unit(intent.actor_id)
		if actor == null or actor.side != BattleTypes.Side.ALLY or not actor.is_alive():
			continue
		if _is_valid_intent(actor, intent):
			result[actor.id] = intent
		else:
			_emit(&"intent_rejected", actor.id, intent.target_ids, {"reason": "invalid"})
			result[actor.id] = BattleIntent.make(actor.id, BattleTypes.IntentKind.DEFEND)
	for ally in state.living(BattleTypes.Side.ALLY):
		if not result.has(ally.id):
			_emit(&"intent_rejected", ally.id, [], {"reason": "missing"})
			result[ally.id] = BattleIntent.make(ally.id, BattleTypes.IntentKind.DEFEND)
	return result

func _is_valid_intent(actor: BattleUnitState, intent: BattleIntent) -> bool:
	match intent.kind:
		BattleTypes.IntentKind.ATTACK:
			if intent.target_ids.size() != 1:
				return false
			var attack_target := state.get_unit(intent.target_ids[0])
			return attack_target != null and attack_target.is_alive() and attack_target.side != actor.side
		BattleTypes.IntentKind.DEFEND:
			return true
		_:
			return false

func _collect_actions(intents: Dictionary) -> Array[BattleIntent]:
	var actions: Array[BattleIntent] = []
	for unit in state.units:
		if unit.is_alive() and intents.has(unit.id):
			actions.append(intents[unit.id])
	return actions

func _compare_actions(a: BattleIntent, b: BattleIntent) -> bool:
	var sa := float(_speed_rolls.get(a.actor_id, 0.0))
	var sb := float(_speed_rolls.get(b.actor_id, 0.0))
	if is_equal_approx(sa, sb):
		return String(a.actor_id) < String(b.actor_id)
	return sa > sb

func _execute_intent(intent: BattleIntent) -> void:
	var actor := state.get_unit(intent.actor_id)
	if actor == null or not actor.is_alive():
		if actor != null:
			_emit(&"action_skipped", actor.id, [], {"reason": "dead"})
		return
	if actor.has_status(&"defending"):
		actor.remove_status(&"defending")
		_emit(&"status_expire", actor.id, [actor.id], {"status_id": "defending", "reason": "owner_action"})
	match intent.kind:
		BattleTypes.IntentKind.ATTACK:
			_execute_attack(actor, intent)
		BattleTypes.IntentKind.DEFEND:
			_execute_defend(actor)
		_:
			_emit(&"intent_rejected", actor.id, [], {"reason": "unsupported"})
			_execute_defend(actor)

func _execute_attack(actor: BattleUnitState, intent: BattleIntent) -> void:
	var target := _resolve_attack_target(actor, intent)
	if target == null:
		_emit(&"action_skipped", actor.id, [], {"reason": "no_target"})
		return
	_emit(&"action_start", actor.id, [target.id], {"kind": "attack"})
	var damage := _compute_damage(actor, target, BattleTypes.DamageType.PHYSICAL, 1.0)
	_apply_damage(actor.id, target, int(damage["amount"]), bool(damage["crit"]), &"attack")

func _resolve_attack_target(actor: BattleUnitState, intent: BattleIntent) -> BattleUnitState:
	if not intent.target_ids.is_empty():
		var target := state.get_unit(intent.target_ids[0])
		if target != null and target.is_alive() and target.side != actor.side:
			return target
	var enemies := state.living_enemies_of(actor)
	if enemies.is_empty():
		return null
	return enemies[rng.randi_range(0, enemies.size() - 1)]

func _compute_damage(source: BattleUnitState, target: BattleUnitState, damage_type: int, power: float) -> Dictionary:
	var base := 0.0
	if damage_type == BattleTypes.DamageType.PHYSICAL:
		base = source.atk_value() * power - target.defense_value() * 0.6
	else:
		base = source.magic_value() * power - target.resistance_value() * 0.5
	base = maxf(1.0, base)
	var variance := rng.randf_range(0.9, 1.1)
	var crit := false
	if source.data.crit_rate > 0.0:
		crit = rng.chance(source.data.crit_rate)
	var crit_multiplier := 1.0
	if crit:
		crit_multiplier = 1.6 if damage_type == BattleTypes.DamageType.PHYSICAL else 1.5
	var amount := maxi(1, roundi(base * variance * crit_multiplier * target.damage_taken_mult()))
	return {"amount": amount, "crit": crit}

func _apply_damage(source_id: StringName, target: BattleUnitState, amount: int, crit: bool, source_type: StringName) -> void:
	var hp_before := target.hp
	target.hp = maxi(0, target.hp - amount)
	_emit(&"damage", source_id, [target.id], {
		"amount": amount,
		"crit": crit,
		"hp_before": hp_before,
		"hp_after": target.hp,
		"source_type": String(source_type),
	})
	if target.hp <= 0 and target.alive:
		target.alive = false
		target.statuses.clear()
		_emit(&"death", source_id, [target.id], {})

func _execute_defend(actor: BattleUnitState) -> void:
	_emit(&"action_start", actor.id, [], {"kind": "defend"})
	var status := content.get_status(&"defending")
	if status == null:
		push_error("Missing status: defending")
		return
	var applied := actor.add_status(status, state.round)
	_emit(&"defend", actor.id, [actor.id], {})
	_emit(&"status_apply" if applied else &"status_refresh", actor.id, [actor.id], {"status_id": "defending"})

func _decide_ai(actor: BattleUnitState) -> BattleIntent:
	var targets := state.living_enemies_of(actor)
	if targets.is_empty():
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.DEFEND)
	var target := _pick_ai_target(targets)
	return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [target.id])

func _pick_ai_target(candidates: Array[BattleUnitState]) -> BattleUnitState:
	if candidates.size() == 1:
		return candidates[0]
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	if rng.chance(0.2):
		return sorted[rng.randi_range(0, sorted.size() - 1)]
	return sorted[0]

func _check_end() -> void:
	if state.is_over():
		return
	if state.living(BattleTypes.Side.ENEMY).is_empty():
		state.outcome = BattleTypes.Outcome.VICTORY
		_emit(&"battle_end", &"", [], {"outcome": state.outcome})
	elif state.living(BattleTypes.Side.ALLY).is_empty():
		state.outcome = BattleTypes.Outcome.DEFEAT
		_emit(&"battle_end", &"", [], {"outcome": state.outcome})

func _finish_round() -> void:
	_emit(&"round_end", &"", [], {"round": state.round})
	if state.round >= state.max_rounds and not state.is_over():
		state.outcome = BattleTypes.Outcome.DEFEAT
		_emit(&"battle_end", &"", [], {"outcome": state.outcome, "reason": "round_limit"})

func _emit(event_type: StringName, source_id: StringName, target_ids: Array, data: Dictionary = {}) -> void:
	_seq += 1
	events.append(BattleEvent.make(_seq, state.round, event_type, source_id, target_ids, data))
```

`godot-battle/core/battle_engine.gd`:

```gdscript
class_name BattleEngine
extends RefCounted

var content: ContentDB
var encounter: EncounterData
var state: BattleState
var rng: BattleRng
var resolver: BattleResolver
var seed_value: int

func _init(p_encounter: EncounterData, p_content: ContentDB, p_seed: int) -> void:
	encounter = p_encounter
	content = p_content
	seed_value = p_seed
	rng = BattleRng.new(p_seed)
	state = BattleFactory.create(p_encounter, p_content)
	resolver = BattleResolver.new(state, rng, p_content)

func resolve_round(intents: Array[BattleIntent]) -> Array[BattleEvent]:
	if state.is_over():
		return []
	return resolver.resolve_round(intents)

func is_over() -> bool:
	return state.is_over()

func outcome() -> int:
	return state.outcome
```

- [ ] **Step 5: 运行，确认通过**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `PASS test_battle_basic.gd`，`RESULT: ... 0 failures`。

- [ ] **Step 6: 提交**

```bash
git add godot-battle/core godot-battle/tests/cases/test_battle_basic.gd
git commit -m "feat(battle): 战斗状态、速度排序与普攻结算"
```

---

## Task 5: 技能、AOE 与治疗

**Files:**
- Modify: `godot-battle/core/battle_resolver.gd`
- Create: `godot-battle/tests/cases/test_skills.gd`

**Interfaces:**
- Consumes: `SkillData`、`BattleEffect`、Task 4 的 Resolver
- Produces: `_execute_skill`、`_resolve_targets`、`_nearest_targets`、`_apply_effect`、`_apply_heal`

- [ ] **Step 1: 写失败测试**

`godot-battle/tests/cases/test_skills.gd`:

```gdscript
extends RefCounted

func _dummy(slot: int) -> UnitData:
	var data := UnitData.new()
	data.id = StringName("dummy_%d" % slot)
	data.display_name = "木桩%d" % slot
	data.max_hp = 9999
	data.max_mp = 0
	data.atk = 1
	data.defense = 999
	data.magic = 0
	data.resistance = 999
	data.speed = 1
	data.crit_rate = 0.0
	data.ai_profile = &"melee"
	return data

func _state(entries: Array) -> BattleState:
	var state := BattleState.new()
	for entry in entries:
		state.units.append(BattleUnitState.new(entry["data"], entry["side"], entry["slot"]))
	state.max_rounds = 30
	return state

func _count_events(events: Array[BattleEvent], type: StringName, source: String) -> int:
	var count := 0
	for event in events:
		if event.type == type and String(event.source_id) == source:
			count += 1
	return count

func _event_by_type(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()

	var sweep_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
		{"data": _dummy(1), "side": BattleTypes.Side.ENEMY, "slot": 1},
		{"data": _dummy(2), "side": BattleTypes.Side.ENEMY, "slot": 2},
		{"data": _dummy(3), "side": BattleTypes.Side.ENEMY, "slot": 3},
	])
	var sweep_events := BattleResolver.new(sweep_state, BattleRng.new(101), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"sweep"),
	])
	t.eq(_count_events(sweep_events, &"damage", "hero_swordsman"), 3, "横扫千军命中 3 个目标")
	var sweep_mp := _event_by_type(sweep_events, &"mp_change", "hero_swordsman")
	t.ok(sweep_mp != null, "技能消耗 MP")
	t.eq(int(sweep_mp.data["amount"]), 30, "横扫千军消耗 30 MP")

	var fire_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var fire_events := BattleResolver.new(fire_state, BattleRng.new(202), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"fire_spell"),
	])
	t.eq(_count_events(fire_events, &"damage", "hero_mage"), 1, "烈火咒单体命中")

	var thunder_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
		{"data": _dummy(1), "side": BattleTypes.Side.ENEMY, "slot": 1},
		{"data": _dummy(2), "side": BattleTypes.Side.ENEMY, "slot": 2},
		{"data": _dummy(3), "side": BattleTypes.Side.ENEMY, "slot": 3},
	])
	var thunder_events := BattleResolver.new(thunder_state, BattleRng.new(303), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"thunder_storm"),
	])
	t.eq(_count_events(thunder_events, &"damage", "hero_mage"), 4, "雷霆万钧命中全体")

	var heal_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": content.get_unit(&"hero_healer"), "side": BattleTypes.Side.ALLY, "slot": 1},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	heal_state.get_unit(&"hero_swordsman").hp = 300
	var heal_events := BattleResolver.new(heal_state, BattleRng.new(404), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.SKILL, [&"hero_swordsman"], &"heal_single"),
	])
	var heal := _event_by_type(heal_events, &"heal", "hero_healer")
	t.ok(heal != null, "回春术产生治疗事件")
	t.ok(int(heal.data["amount"]) > 0, "治疗量为正")
	t.ok(int(heal.data["hp_after"]) > int(heal.data["hp_before"]), "目标 HP 增加")

	var mp_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(0), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	mp_state.get_unit(&"hero_mage").mp = 0
	var mp_events := BattleResolver.new(mp_state, BattleRng.new(505), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy_0"], &"fire_spell"),
	])
	var rejected := _event_by_type(mp_events, &"intent_rejected", "hero_mage")
	t.ok(rejected != null, "MP 不足被拒绝")
	t.eq(String(rejected.data["reason"]), "invalid", "拒绝原因 invalid")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 测试失败，横扫千军的伤害事件数为 0（技能尚未实现）。

- [ ] **Step 3: 扩展 Resolver**

在 `_is_valid_intent` 的 `match` 中，`DEFEND` 分支之前加入：

```gdscript
		BattleTypes.IntentKind.SKILL:
			var skill := content.get_skill(intent.skill_id)
			if skill == null or not actor.data.skills.has(skill.id):
				return false
			if actor.mp < skill.mp_cost:
				return false
			if skill.target_type == SkillData.TargetType.SELF:
				return true
			if intent.target_ids.size() != 1:
				return false
			var skill_target := state.get_unit(intent.target_ids[0])
			if skill_target == null or not skill_target.is_alive():
				return false
			if skill.target_type == SkillData.TargetType.SINGLE_ALLY or skill.target_type == SkillData.TargetType.ALL_ALLIES:
				return skill_target.side == actor.side
			return skill_target.side != actor.side
```

在 `_execute_intent` 的 `match` 中加入：

```gdscript
		BattleTypes.IntentKind.SKILL:
			_execute_skill(actor, intent)
```

在文件末尾追加：

```gdscript
func _execute_skill(actor: BattleUnitState, intent: BattleIntent) -> void:
	var skill := content.get_skill(intent.skill_id)
	if skill == null or actor.mp < skill.mp_cost:
		_emit(&"intent_rejected", actor.id, [], {"reason": "mp"})
		_execute_defend(actor)
		return
	var targets := _resolve_targets(actor, intent, skill)
	if targets.is_empty():
		_emit(&"action_skipped", actor.id, [], {"reason": "no_target"})
		return
	var target_ids: Array[StringName] = []
	for target in targets:
		target_ids.append(target.id)
	_emit(&"action_start", actor.id, target_ids, {"kind": "skill", "skill_id": String(skill.id)})
	if skill.mp_cost > 0:
		var mp_before := actor.mp
		actor.mp = maxi(0, actor.mp - skill.mp_cost)
		_emit(&"mp_change", actor.id, [actor.id], {
			"amount": mp_before - actor.mp,
			"mp_before": mp_before,
			"mp_after": actor.mp,
			"reason": "skill",
			"skill_id": String(skill.id),
		})
	for effect in skill.effects:
		for target in targets:
			_apply_effect(actor, target, effect, skill.id)

func _resolve_targets(actor: BattleUnitState, intent: BattleIntent, skill: SkillData) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	if skill.target_type == SkillData.TargetType.SELF:
		result.append(actor)
		return result
	var candidates: Array[BattleUnitState]
	if skill.target_type == SkillData.TargetType.SINGLE_ENEMY or skill.target_type == SkillData.TargetType.ALL_ENEMIES:
		candidates = state.living_enemies_of(actor)
	else:
		candidates = state.living_allies_of(actor)
	if candidates.is_empty():
		return result
	var primary: BattleUnitState = null
	if not intent.target_ids.is_empty():
		var candidate := state.get_unit(intent.target_ids[0])
		if candidate != null and candidate.is_alive() and candidates.has(candidate):
			primary = candidate
	if primary == null:
		primary = _lowest_hp(candidates)
	if skill.target_type == SkillData.TargetType.SINGLE_ENEMY or skill.target_type == SkillData.TargetType.SINGLE_ALLY:
		result.append(primary)
		return result
	return _nearest_targets(primary, candidates, skill.max_targets)

func _lowest_hp(candidates: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	return sorted[0]

func _nearest_targets(primary: BattleUnitState, candidates: Array[BattleUnitState], max_targets: int) -> Array[BattleUnitState]:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var da := absi(a.slot - primary.slot)
		var db := absi(b.slot - primary.slot)
		if da == db:
			return String(a.id) < String(b.id)
		return da < db)
	var result: Array[BattleUnitState] = []
	for index in mini(max_targets, sorted.size()):
		result.append(sorted[index])
	return result

func _apply_effect(source: BattleUnitState, target: BattleUnitState, effect: BattleEffect, source_type: StringName) -> void:
	match effect.kind:
		BattleEffect.Kind.DAMAGE:
			if not target.is_alive():
				return
			var damage := _compute_damage(source, target, effect.damage_type, effect.power)
			_apply_damage(source.id, target, int(damage["amount"]), bool(damage["crit"]), source_type)
		BattleEffect.Kind.HEAL:
			if not target.is_alive():
				return
			_apply_heal(source, target, effect)

func _apply_heal(source: BattleUnitState, target: BattleUnitState, effect: BattleEffect) -> void:
	var amount := 0
	if effect.flat_amount > 0:
		amount = effect.flat_amount
	else:
		amount = roundi(source.magic_value() * effect.power * rng.randf_range(0.95, 1.05))
	var hp_before := target.hp
	target.hp = mini(target.data.max_hp, target.hp + amount)
	_emit(&"heal", source.id, [target.id], {
		"amount": target.hp - hp_before,
		"hp_before": hp_before,
		"hp_after": target.hp,
	})
```

- [ ] **Step 4: 运行，确认通过**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `PASS test_skills.gd`，全部测试 0 failures。

- [ ] **Step 5: 提交**

```bash
git add godot-battle/core/battle_resolver.gd godot-battle/tests/cases/test_skills.gd
git commit -m "feat(battle): 技能、AOE 选目标与治疗结算"
```

---

## Task 6: 状态、道具与防御

**Files:**
- Modify: `godot-battle/core/battle_resolver.gd`
- Create: `godot-battle/tests/cases/test_status_items.gd`

**Interfaces:**
- Consumes: `StatusData`、`ItemData`、`BattleEffect.Kind.APPLY_STATUS/CLEANSE/RESTORE_MP`
- Produces: `compute_status_chance(target, base)`、`_tick_round_start_statuses`、`_apply_status_effect`、`_apply_cleanse`、`_restore_mp`、`_execute_item`

- [ ] **Step 1: 写失败测试**

`godot-battle/tests/cases/test_status_items.gd`:

```gdscript
extends RefCounted

func _dummy() -> UnitData:
	var data := UnitData.new()
	data.id = &"dummy"
	data.display_name = "木桩"
	data.max_hp = 9999
	data.max_mp = 0
	data.atk = 1
	data.defense = 999
	data.magic = 0
	data.resistance = 999
	data.speed = 1
	data.crit_rate = 0.0
	data.ai_profile = &"melee"
	return data

func _state(entries: Array, items: Dictionary = {}) -> BattleState:
	var state := BattleState.new()
	for entry in entries:
		state.units.append(BattleUnitState.new(entry["data"], entry["side"], entry["slot"]))
	state.item_uses = items
	state.max_rounds = 30
	return state

func _count(events: Array[BattleEvent], type: StringName, source: String) -> int:
	var total := 0
	for event in events:
		if event.type == type and String(event.source_id) == source:
			total += 1
	return total

func _first(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()

	# 中毒：回合开始 tick，施加回合不递减，结束后 remaining 3 -> 2
	var poison_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var poisoned := poison_state.get_unit(&"hero_swordsman")
	poisoned.add_status(content.get_status(&"poison"), 0)
	var poison_events := BattleResolver.new(poison_state, BattleRng.new(11), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
	])
	var tick := _first(poison_events, &"status_tick", "hero_swordsman")
	t.ok(tick != null, "中毒在回合开始结算")
	t.eq(int(tick.data["amount"]), roundi(float(poisoned.data.max_hp) * 0.08), "中毒伤害为最大 HP 的 8%")
	t.eq(poisoned.find_status(&"poison").remaining, 2, "中毒剩余回合减少")

	# 封印：只结算一次（命中或抵抗）
	var seal_state := _state([
		{"data": content.get_unit(&"hero_mage"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var seal_events := BattleResolver.new(seal_state, BattleRng.new(22), content).resolve_round([
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.SKILL, [&"dummy"], &"seal_talisman"),
	])
	var seal_count := _count(seal_events, &"status_apply", "hero_mage") + _count(seal_events, &"status_resist", "hero_mage")
	t.eq(seal_count, 1, "封印要么命中要么抵抗，且只结算一次")

	# 防御对封印命中的修正
	var def_target := BattleUnitState.new(content.get_unit(&"boss_fox"), BattleTypes.Side.ENEMY, 0)
	def_target.add_status(content.get_status(&"defending"), 0)
	t.near(BattleResolver.new(BattleState.new(), BattleRng.new(1), content).compute_status_chance(def_target, 0.65), 0.455, 0.0001, "防御使封印命中率 ×0.7")

	# 道具：金疮药回复 220，共享池 3 -> 2
	var item_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	], {&"potion_hp": 3})
	item_state.get_unit(&"hero_swordsman").hp = 100
	var item_events := BattleResolver.new(item_state, BattleRng.new(33), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.ITEM, [&"hero_swordsman"], &"", &"potion_hp"),
	])
	var item_use := _first(item_events, &"item_used", "hero_swordsman")
	t.ok(item_use != null, "使用金疮药")
	t.eq(int(item_use.data["remaining"]), 2, "金疮药剩余 2 次")
	var item_heal := _first(item_events, &"heal", "hero_swordsman")
	t.eq(int(item_heal.data["hp_after"]), 320, "金疮药回复 220 HP")

	# 清心咒：解除一个负面状态
	var cleanse_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": content.get_unit(&"hero_healer"), "side": BattleTypes.Side.ALLY, "slot": 1},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var cleanse_target := cleanse_state.get_unit(&"hero_swordsman")
	cleanse_target.add_status(content.get_status(&"poison"), 0)
	cleanse_target.add_status(content.get_status(&"armor_down"), 0)
	var cleanse_events := BattleResolver.new(cleanse_state, BattleRng.new(44), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.SKILL, [&"hero_swordsman"], &"cleanse"),
	])
	var cleanse_expire := _first(cleanse_events, &"status_expire", "hero_healer")
	t.ok(cleanse_expire != null, "清心咒解除一个负面状态")
	t.eq(String(cleanse_expire.data["reason"]), "cleanse", "解除原因正确")
	t.eq(cleanse_target.statuses.size(), 1, "只解除一个负面状态")

	# 防御：状态保留到自身下次行动
	var defend_state := _state([
		{"data": content.get_unit(&"hero_swordsman"), "side": BattleTypes.Side.ALLY, "slot": 0},
		{"data": _dummy(), "side": BattleTypes.Side.ENEMY, "slot": 0},
	])
	var defend_events := BattleResolver.new(defend_state, BattleRng.new(55), content).resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
	])
	t.ok(_first(defend_events, &"defend", "hero_swordsman") != null, "防御指令产生事件")
	t.ok(defend_state.get_unit(&"hero_swordsman").has_status(&"defending"), "防御状态保留到自身下次行动")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 失败（无 `status_tick` / `item_used` / `_apply_status_effect`）。

- [ ] **Step 3: 扩展 Resolver**

在 `resolve_round` 中 `_emit(&"round_start"...)` 之后插入：

```gdscript
	_tick_round_start_statuses(order)
	_check_end()
	if state.is_over():
		return events
```

在 `_is_valid_intent` 的 `DEFEND` 分支之前加入：

```gdscript
		BattleTypes.IntentKind.ITEM:
			if intent.target_ids.size() != 1:
				return false
			var item := content.get_item(intent.item_id)
			if item == null or state.item_remaining(item.id) <= 0:
				return false
			var item_target := state.get_unit(intent.target_ids[0])
			return item_target != null and item_target.is_alive() and item_target.side == actor.side
```

在 `_execute_intent` 中，防御状态移除之后、`match` 之前加入封印处理：

```gdscript
	if actor.has_status(&"sealed"):
		actor.remove_status(&"sealed")
		_emit(&"action_skipped", actor.id, [actor.id], {"reason": "sealed"})
		_emit(&"status_expire", actor.id, [actor.id], {"status_id": "sealed", "reason": "sealed"})
		return
```

在 `_execute_intent` 的 `match` 中加入：

```gdscript
		BattleTypes.IntentKind.ITEM:
			_execute_item(actor, intent)
```

在 `_apply_effect` 的 `match` 中加入：

```gdscript
		BattleEffect.Kind.APPLY_STATUS:
			if not target.is_alive():
				return
			_apply_status_effect(source.id, target, effect)
		BattleEffect.Kind.CLEANSE:
			_apply_cleanse(source.id, target, effect)
		BattleEffect.Kind.RESTORE_MP:
			if not target.is_alive():
				return
			_restore_mp(source, target, effect)
```

在文件末尾追加：

```gdscript
func compute_status_chance(target: BattleUnitState, base_chance: float) -> float:
	return clampf(base_chance * (1.0 - target.seal_resist_bonus()), 0.0, 1.0)

func _tick_round_start_statuses(order: Array[BattleUnitState]) -> void:
	for unit in order:
		if not unit.is_alive():
			continue
		for status in unit.statuses.duplicate():
			if not unit.is_alive():
				break
			if status.data.poison_max_hp_ratio > 0.0:
				var amount := maxi(1, roundi(float(unit.data.max_hp) * status.data.poison_max_hp_ratio))
				var hp_before := unit.hp
				unit.hp = maxi(0, unit.hp - amount)
				_emit(&"status_tick", unit.id, [unit.id], {
					"status_id": String(status.data.id),
					"amount": amount,
					"hp_before": hp_before,
					"hp_after": unit.hp,
				})
				if unit.hp <= 0 and unit.alive:
					unit.alive = false
					unit.statuses.clear()
					_emit(&"death", unit.id, [unit.id], {})

func _apply_status_effect(source_id: StringName, target: BattleUnitState, effect: BattleEffect) -> void:
	var status := content.get_status(effect.status_id)
	if status == null:
		push_error("Missing status: " + String(effect.status_id))
		return
	var chance := effect.status_chance
	if status.skips_action:
		chance = compute_status_chance(target, chance)
	if chance <= 0.0:
		_emit(&"status_resist", source_id, [target.id], {"status_id": String(status.id)})
		return
	if chance < 1.0 and not rng.chance(chance):
		_emit(&"status_resist", source_id, [target.id], {"status_id": String(status.id)})
		return
	var applied := target.add_status(status, state.round)
	_emit(&"status_apply" if applied else &"status_refresh", source_id, [target.id], {
		"status_id": String(status.id),
		"duration": status.duration,
	})

func _apply_cleanse(source_id: StringName, target: BattleUnitState, effect: BattleEffect) -> void:
	var removed := 0
	for status in target.statuses.duplicate():
		if removed >= effect.cleanse_count:
			break
		if status.data.kind == StatusData.Kind.DEBUFF:
			target.remove_status(status.data.id)
			removed += 1
			_emit(&"status_expire", source_id, [target.id], {
				"status_id": String(status.data.id),
				"reason": "cleanse",
			})

func _restore_mp(source: BattleUnitState, target: BattleUnitState, effect: BattleEffect) -> void:
	var mp_before := target.mp
	target.mp = mini(target.data.max_mp, target.mp + effect.flat_amount)
	_emit(&"mp_change", source.id, [target.id], {
		"amount": target.mp - mp_before,
		"mp_before": mp_before,
		"mp_after": target.mp,
		"reason": "item",
	})

func _execute_item(actor: BattleUnitState, intent: BattleIntent) -> void:
	var item := content.get_item(intent.item_id)
	if item == null or state.item_remaining(item.id) <= 0:
		_emit(&"intent_rejected", actor.id, [], {"reason": "item"})
		_execute_defend(actor)
		return
	var target := actor
	if not intent.target_ids.is_empty():
		var candidate := state.get_unit(intent.target_ids[0])
		if candidate != null and candidate.is_alive() and candidate.side == actor.side:
			target = candidate
	_emit(&"action_start", actor.id, [target.id], {"kind": "item", "item_id": String(item.id)})
	state.consume_item(item.id)
	_emit(&"item_used", actor.id, [target.id], {"item_id": String(item.id), "remaining": state.item_remaining(item.id)})
	for effect in item.effects:
		_apply_effect(actor, target, effect, item.id)
```

在 `_finish_round` 的 `_emit(&"round_end"...)` 之前插入状态时长结算：

```gdscript
	for unit in state.units:
		if not unit.is_alive():
			continue
		for status in unit.statuses.duplicate():
			if status.data.expires_on_owner_action:
				continue
			if status.applied_round >= state.round:
				continue
			status.remaining -= 1
			if status.remaining <= 0:
				unit.remove_status(status.data.id)
				_emit(&"status_expire", &"", [unit.id], {
					"status_id": String(status.data.id),
					"reason": "duration",
				})
```

- [ ] **Step 4: 运行，确认通过**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `PASS test_status_items.gd`，全部 0 failures。

- [ ] **Step 5: 提交**

```bash
git add godot-battle/core/battle_resolver.gd godot-battle/tests/cases/test_status_items.gd
git commit -m "feat(battle): 状态、道具、封印与防御结算"
```

---

## Task 7: 逃跑、敌方 AI 与回合上限

**Files:**
- Modify: `godot-battle/core/battle_resolver.gd`
- Create: `godot-battle/tests/cases/test_flee_ai.gd`

**Interfaces:**
- Consumes: Task 6 的 Resolver
- Produces: `compute_flee_chance()`、`_resolve_flee()`、扩展后的 `_decide_ai()`

- [ ] **Step 1: 写失败测试**

`godot-battle/tests/cases/test_flee_ai.gd`:

```gdscript
extends RefCounted

func _find(events: Array[BattleEvent], type: StringName, source: String) -> BattleEvent:
	for event in events:
		if event.type == type and String(event.source_id) == source:
			return event
	return null

func _has_skill_event(events: Array[BattleEvent], source: String, skill_id: String) -> bool:
	for event in events:
		if String(event.source_id) != source:
			continue
		if event.type == &"action_start" and String(event.data.get("skill_id", "")) == skill_id:
			return true
	return false

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")

	var slow_state := BattleState.new()
	var fast_data := UnitData.new()
	fast_data.id = &"fast"; fast_data.max_hp = 100; fast_data.max_mp = 0; fast_data.speed = 200
	var slow_data := UnitData.new()
	slow_data.id = &"slow"; slow_data.max_hp = 100; slow_data.max_mp = 0; slow_data.speed = 100
	slow_state.units.append(BattleUnitState.new(fast_data, BattleTypes.Side.ALLY, 0))
	slow_state.units.append(BattleUnitState.new(slow_data, BattleTypes.Side.ENEMY, 0))
	var chance_resolver := BattleResolver.new(slow_state, BattleRng.new(1), content)
	chance_resolver._roll_speeds()
	t.in_range(chance_resolver.compute_flee_chance(), 0.5, 0.9, "逃跑概率被限制在 50%~90%")

	var success_found := false
	var failure_found := false
	for seed_value in range(1, 201):
		var engine := BattleEngine.new(encounter, content, seed_value)
		var events := engine.resolve_round([BattleIntent.make(&"party", BattleTypes.IntentKind.FLEE)])
		var flee_result := _find(events, &"flee_result", "party")
		if flee_result == null:
			continue
		if bool(flee_result.data["success"]):
			success_found = true
			t.eq(engine.outcome(), BattleTypes.Outcome.ESCAPED, "逃跑成功结束战斗")
			t.eq(String(events[events.size() - 1].type), "battle_end", "逃跑成功以 battle_end 收尾")
		else:
			failure_found = true
			var ally_actions := 0
			for event in events:
				if event.type == &"action_start" and engine.state.get_unit(event.source_id) != null and engine.state.get_unit(event.source_id).side == BattleTypes.Side.ALLY:
					ally_actions += 1
			t.eq(ally_actions, 0, "逃跑失败我方不行动")
		if success_found and failure_found:
			break
	t.ok(success_found, "在 200 个种子内找到逃跑成功")
	t.ok(failure_found, "在 200 个种子内找到逃跑失败")

	var brute_engine := BattleEngine.new(encounter, content, 9)
	var brute_events := brute_engine.resolve_round([
		BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
		BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
	])
	t.ok(_has_skill_event(brute_events, "boss_brute", "war_cry"), "妖将首回合使用战吼")
	t.ok(bool(_find(brute_events, &"status_apply", "boss_brute") != null), "战吼状态施加")

	var fox_seal_seen := false
	var fox_fire_seen := false
	for seed_value in range(1, 31):
		var fox_engine := BattleEngine.new(encounter, content, seed_value)
		var fox_events := fox_engine.resolve_round([
			BattleIntent.make(&"hero_swordsman", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_mage", BattleTypes.IntentKind.DEFEND),
			BattleIntent.make(&"hero_healer", BattleTypes.IntentKind.DEFEND),
		])
		if _find(fox_events, &"status_apply", "boss_fox") != null or _find(fox_events, &"status_resist", "boss_fox") != null:
			fox_seal_seen = true
		if _has_skill_event(fox_events, "boss_fox", "fox_fire"):
			fox_fire_seen = true
	t.ok(fox_seal_seen or fox_fire_seen, "狐妖至少使用一种技能")

	var limit_state := BattleState.new()
	limit_state.max_rounds = 1
	var hero_data := UnitData.new()
	hero_data.id = &"hero"; hero_data.max_hp = 1000; hero_data.max_mp = 0; hero_data.atk = 1; hero_data.speed = 10
	var enemy_data := UnitData.new()
	enemy_data.id = &"enemy"; enemy_data.max_hp = 1000; enemy_data.max_mp = 0; enemy_data.atk = 1; enemy_data.speed = 10
	limit_state.units.append(BattleUnitState.new(hero_data, BattleTypes.Side.ALLY, 0))
	limit_state.units.append(BattleUnitState.new(enemy_data, BattleTypes.Side.ENEMY, 0))
	var limit_events := BattleResolver.new(limit_state, BattleRng.new(5), content).resolve_round([
		BattleIntent.make(&"hero", BattleTypes.IntentKind.DEFEND),
	])
	t.eq(limit_state.outcome, BattleTypes.Outcome.DEFEAT, "达到回合上限判负")
	var limit_end := _find(limit_events, &"battle_end", "")
	t.eq(String(limit_end.data["reason"]), "round_limit", "回合上限原因正确")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 失败（逃跑意图被当成 unsupported，AI 不会使用技能）。

- [ ] **Step 3: 扩展 Resolver**

在 `resolve_round` 中，把 `var intents := _validate_player_intents(player_intents)` 到 `actions.sort_custom(_compare_actions)` 的整段替换为：

```gdscript
	var flee_requested := _has_flee_intent(player_intents)
	var intents := _validate_player_intents(player_intents, flee_requested)
	for enemy in state.living(BattleTypes.Side.ENEMY):
		intents[enemy.id] = _decide_ai(enemy)
	var actions: Array[BattleIntent] = []
	if flee_requested:
		var chance := compute_flee_chance()
		_emit(&"flee_attempt", &"party", [], {"chance": chance})
		if rng.chance(chance):
			state.outcome = BattleTypes.Outcome.ESCAPED
			_emit(&"flee_result", &"party", [], {"success": true})
			_emit(&"battle_end", &"", [], {"outcome": state.outcome})
			return events
		_emit(&"flee_result", &"party", [], {"success": false})
		for enemy in state.living(BattleTypes.Side.ENEMY):
			if intents.has(enemy.id):
				actions.append(intents[enemy.id])
	else:
		actions = _collect_actions(intents)
	actions.sort_custom(_compare_actions)
```

把 `_validate_player_intents` 签名改为：

```gdscript
func _validate_player_intents(player_intents: Array[BattleIntent], flee_requested: bool) -> Dictionary:
```

并把其中“补齐缺失意图”的循环包起来：

```gdscript
	if not flee_requested:
		for ally in state.living(BattleTypes.Side.ALLY):
			if not result.has(ally.id):
				_emit(&"intent_rejected", ally.id, [], {"reason": "missing"})
				result[ally.id] = BattleIntent.make(ally.id, BattleTypes.IntentKind.DEFEND)
```

在文件末尾追加：

```gdscript
func _has_flee_intent(player_intents: Array[BattleIntent]) -> bool:
	for intent in player_intents:
		if intent.kind == BattleTypes.IntentKind.FLEE:
			return true
	return false

func compute_flee_chance() -> float:
	var ally_average := _average_speed(state.living(BattleTypes.Side.ALLY))
	var enemy_average := _average_speed(state.living(BattleTypes.Side.ENEMY))
	return clampf(0.5 + (ally_average - enemy_average) / 10.0 * 0.08, 0.5, 0.9)

func _average_speed(units: Array[BattleUnitState]) -> float:
	if units.is_empty():
		return 0.0
	var total := 0.0
	for unit in units:
		total += float(_speed_rolls.get(unit.id, unit.data.speed))
	return total / float(units.size())
```

把 `_decide_ai` 整体替换为：

```gdscript
func _decide_ai(actor: BattleUnitState) -> BattleIntent:
	var targets := state.living_enemies_of(actor)
	if targets.is_empty():
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.DEFEND)
	var profile := actor.data.ai_profile
	if profile == &"brute":
		if not actor.has_status(&"war_cry") and actor.mp >= 15:
			return _skill_intent(actor, &"war_cry", [actor.id])
		if targets.size() >= 2 and actor.mp >= 20 and rng.chance(0.6):
			return _skill_intent(actor, &"ground_split", [_pick_ai_target(targets).id])
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])
	if profile == &"fox":
		var priority := _priority_allies(targets)
		var seal_target := _first_unsealed(priority)
		if seal_target != null and actor.mp >= 25 and rng.chance(0.7):
			return _skill_intent(actor, &"charm_seal", [seal_target.id])
		if actor.mp >= 20:
			return _skill_intent(actor, &"fox_fire", [_pick_ai_target(targets).id])
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])
	if profile == &"poison_melee" and actor.mp >= 0 and rng.chance(0.6):
		return _skill_intent(actor, &"poison_strike", [_pick_ai_target(targets).id])
	if not actor.data.skills.is_empty() and actor.mp >= 0 and rng.chance(0.6):
		var first_skill := StringName(actor.data.skills[0])
		var skill := content.get_skill(first_skill)
		if skill != null and actor.mp >= skill.mp_cost:
			var target_id := actor.id if skill.target_type == SkillData.TargetType.SELF else _pick_ai_target(targets).id
			return _skill_intent(actor, first_skill, [target_id])
	return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])

func _skill_intent(actor: BattleUnitState, skill_id: StringName, target_ids: Array) -> BattleIntent:
	return BattleIntent.make(actor.id, BattleTypes.IntentKind.SKILL, target_ids, skill_id)

func _priority_allies(candidates: Array[BattleUnitState]) -> Array[BattleUnitState]:
	var priority: Array[BattleUnitState] = []
	for wanted in [&"hero_healer", &"hero_mage"]:
		for candidate in candidates:
			if candidate.id == wanted:
				priority.append(candidate)
	if priority.is_empty():
		priority.append(_lowest_hp(candidates))
	return priority

func _first_unsealed(candidates: Array[BattleUnitState]) -> BattleUnitState:
	for candidate in candidates:
		if not candidate.has_status(&"sealed"):
			return candidate
	return null
```

- [ ] **Step 4: 运行，确认通过**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `PASS test_flee_ai.gd`，全部 0 failures。

- [ ] **Step 5: 提交**

```bash
git add godot-battle/core/battle_resolver.gd godot-battle/tests/cases/test_flee_ai.gd
git commit -m "feat(battle): 逃跑、敌方 AI 与回合上限"
```

## Task 8: 录像、回放、不变量与 headless 校验工具

**Files:**
- Create: `godot-battle/core/battle_invariants.gd`
- Create: `godot-battle/core/battle_recorder.gd`
- Create: `godot-battle/core/battle_replay.gd`
- Modify: `godot-battle/core/battle_engine.gd`
- Create: `godot-battle/tools/replay.gd`
- Create: `godot-battle/tests/cases/test_replay.gd`

**Interfaces:**
- Consumes: Task 4–7 的 `BattleEngine`、`BattleResolver`
- Produces:
  - `BattleInvariants.check(state) -> Array[String]`
  - `BattleRecorder.begin/record_intents/record_debug_op/record_snapshot/record_round_events/finish/save/to_dict`
  - `BattleReplay.load_file(path) -> Dictionary`、`verify(replay, content, strict_content) -> Dictionary { ok, errors, warnings, first_divergence }`
  - `BattleEngine.new(encounter, content, seed, record := true)`、`apply_debug_op(op)`、`dump_replay(path := "") -> String`
  - CLI：`godot --headless --path godot-battle -s tools/replay.gd -- --file <path> [--strict-content]`

- [ ] **Step 1: 写失败测试**

`godot-battle/tests/cases/test_replay.gd`:

```gdscript
extends RefCounted

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	return sorted[0]

func _policy(engine: BattleEngine) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		if ally.id == &"hero_healer":
			var target := _lowest_ally(allies)
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [target.id], &"heal_single"))
		elif ally.id == &"hero_mage":
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"fire_spell"))
		else:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
	return intents

func _run(engine: BattleEngine, max_rounds: int) -> Array[Dictionary]:
	var all_events: Array[Dictionary] = []
	for i in max_rounds:
		if engine.is_over():
			break
		for event in engine.resolve_round(_policy(engine)):
			all_events.append(event.to_dict())
	return all_events

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")

	var engine := BattleEngine.new(encounter, content, 777)
	_run(engine, 12)
	var path := engine.dump_replay("user://test_replay.json")
	t.ok(not path.is_empty(), "录像写入成功")
	t.ok(FileAccess.file_exists(path), "录像文件存在")

	var replay := BattleReplay.load_file(path)
	t.ok(not replay.is_empty(), "录像可加载")
	var verification := BattleReplay.verify(replay, content, true)
	t.ok(bool(verification["ok"]), "录像校验通过: " + str(verification["errors"]))
	var replay_snapshots: Array = replay.get("snapshots", [])
	var replay_events: Array = replay.get("events", [])
	t.ok(replay_snapshots.size() >= 1, "包含状态快照")
	t.ok(replay_events.size() > 0, "包含事件流")

	var engine_a := BattleEngine.new(encounter, content, 888, false)
	var engine_b := BattleEngine.new(encounter, content, 888, false)
	var events_a := _run(engine_a, 12)
	var events_b := _run(engine_b, 12)
	t.eq(JSON.stringify(events_b, "", true), JSON.stringify(events_a, "", true), "同种子同指令事件流一致")
	t.eq(engine_b.state.outcome, engine_a.state.outcome, "同种子结果一致")

	var tampered := replay.duplicate(true)
	for event in tampered["events"]:
		if event["type"] == "damage":
			event["data"]["amount"] = int(event["data"]["amount"]) + 1
			break
	var tampered_result := BattleReplay.verify(tampered, content, true)
	t.ok(not bool(tampered_result["ok"]), "篡改后的录像校验失败")

	var debug_engine := BattleEngine.new(encounter, content, 999)
	debug_engine.apply_debug_op({"op": "kill", "unit_id": "mob_a"})
	debug_engine.resolve_round(_policy(debug_engine))
	var debug_path := debug_engine.dump_replay("user://test_replay_debug.json")
	var debug_replay := BattleReplay.load_file(debug_path)
	var debug_result := BattleReplay.verify(debug_replay, content, true)
	t.ok(bool(debug_result["ok"]), "调试操作可随录像重放: " + str(debug_result["errors"]))

	var broken_state := BattleState.new()
	var broken_unit := BattleUnitState.new(content.get_unit(&"hero_swordsman"), BattleTypes.Side.ALLY, 0)
	broken_unit.hp = -1
	broken_state.units.append(broken_unit)
	t.ok(BattleInvariants.check(broken_state).size() > 0, "不变量能发现非法 HP")
```

- [ ] **Step 2: 运行，确认失败**

Run: `godot --headless --path godot-battle -s tests/run_tests.gd`

Expected: 解析错误，提示 `BattleInvariants` / `BattleRecorder` / `BattleReplay` 未定义。

- [ ] **Step 3: 实现不变量与录像**

`godot-battle/core/battle_invariants.gd`:

```gdscript
class_name BattleInvariants
extends RefCounted

static func check(state: BattleState) -> Array[String]:
	var issues: Array[String] = []
	if state.round < 0:
		issues.append("round is negative")
	if state.round > state.max_rounds:
		issues.append("round exceeds max_rounds")
	for unit in state.units:
		if unit.hp < 0 or unit.hp > unit.data.max_hp:
			issues.append("%s hp out of range: %d" % [String(unit.id), unit.hp])
		if unit.mp < 0 or unit.mp > unit.data.max_mp:
			issues.append("%s mp out of range: %d" % [String(unit.id), unit.mp])
		if unit.hp <= 0 and unit.alive:
			issues.append("%s has zero hp but still alive" % String(unit.id))
		if unit.hp > 0 and not unit.alive:
			issues.append("%s is dead with positive hp" % String(unit.id))
		var seen := {}
		for status in unit.statuses:
			if seen.has(status.data.id):
				issues.append("%s duplicate status %s" % [String(unit.id), String(status.data.id)])
			seen[status.data.id] = true
			if status.remaining < 0:
				issues.append("%s status %s has negative remaining" % [String(unit.id), String(status.data.id)])
	for item_id in state.item_uses:
		if int(state.item_uses[item_id]) < 0:
			issues.append("item %s has negative uses" % String(item_id))
	return issues
```

`godot-battle/core/battle_recorder.gd`:

```gdscript
class_name BattleRecorder
extends RefCounted

const REPLAY_VERSION := 1

var meta: Dictionary = {}
var rounds: Array[Dictionary] = []
var events: Array[Dictionary] = []
var digests: Array[Dictionary] = []
var snapshots: Array[Dictionary] = []
var result: Dictionary = {}
var _previous_digest: String = ""

func begin(encounter: EncounterData, seed_value: int, content_hash: String, state: BattleState) -> void:
	meta = {
		"battle_id": String(encounter.id),
		"content_hash": content_hash,
		"engine": String(Engine.get_version_info().get("string", "unknown")),
		"seed": seed_value,
		"created_at": Time.get_datetime_string_from_system(true),
		"build": "debug" if OS.is_debug_build() else "release",
	}
	snapshots.append(_snapshot(1, state))

func _ensure_round(round_number: int) -> Dictionary:
	for entry in rounds:
		if int(entry["round"]) == round_number:
			return entry
	var entry := {"round": round_number, "intents": [], "debug_ops": []}
	rounds.append(entry)
	return entry

func record_intents(round_number: int, intents: Array[BattleIntent]) -> void:
	var entry := _ensure_round(round_number)
	var list: Array = entry["intents"]
	for intent in intents:
		list.append(intent.to_dict())
	entry["intents"] = list

func record_debug_op(round_number: int, op: Dictionary) -> void:
	var entry := _ensure_round(round_number)
	var ops: Array = entry["debug_ops"]
	ops.append(op.duplicate(true))
	entry["debug_ops"] = ops

func record_snapshot(round_number: int, state: BattleState) -> void:
	for index in range(snapshots.size()):
		if int(snapshots[index]["round"]) == round_number:
			snapshots[index] = _snapshot(round_number, state)
			return
	snapshots.append(_snapshot(round_number, state))

func record_round_events(round_events: Array[BattleEvent]) -> void:
	if round_events.is_empty():
		return
	var round_number := round_events[0].round
	var parts: Array[String] = []
	for event in round_events:
		events.append(event.to_dict())
		parts.append(event.canonical_json())
	var digest := BattleDigest.sha256(_previous_digest + "\n" + "\n".join(parts))
	_previous_digest = digest
	digests.append({"round": round_number, "sha256": digest})

func finish(state: BattleState) -> void:
	result = {"outcome": state.outcome, "rounds": state.round, "digest": _previous_digest}

func _snapshot(round_number: int, state: BattleState) -> Dictionary:
	var unit_list: Array = []
	for unit in state.units:
		var status_list: Array = []
		for status in unit.statuses:
			status_list.append({"id": String(status.data.id), "remaining": status.remaining})
		unit_list.append({
			"id": String(unit.id),
			"hp": unit.hp,
			"mp": unit.mp,
			"alive": unit.is_alive(),
			"statuses": status_list,
		})
	var items := {}
	for item_id in state.item_uses:
		items[String(item_id)] = int(state.item_uses[item_id])
	return {"round": round_number, "units": unit_list, "item_uses": items}

func to_dict() -> Dictionary:
	return {
		"replay_version": REPLAY_VERSION,
		"meta": meta,
		"rounds": rounds,
		"events": events,
		"digests": digests,
		"snapshots": snapshots,
		"result": result,
	}

func save(path: String = "") -> String:
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://replays"))
		var battle_id := String(meta.get("battle_id", "battle"))
		var stamp := int(Time.get_unix_time_from_system())
		path = "user://replays/%s_%d.json" % [battle_id, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write replay: " + path)
		return ""
	file.store_string(JSON.stringify(to_dict(), "  ", true))
	file.close()
	print("REPLAY_SAVED: " + ProjectSettings.globalize_path(path))
	return path
```

- [ ] **Step 4: 集成录制并实现回放校验**

把 `godot-battle/core/battle_engine.gd` 整体替换为：

```gdscript
class_name BattleEngine
extends RefCounted

var content: ContentDB
var encounter: EncounterData
var state: BattleState
var rng: BattleRng
var resolver: BattleResolver
var recorder: BattleRecorder
var seed_value: int
var check_invariants: bool = true

func _init(p_encounter: EncounterData, p_content: ContentDB, p_seed: int, p_record: bool = true) -> void:
	encounter = p_encounter
	content = p_content
	seed_value = p_seed
	rng = BattleRng.new(p_seed)
	state = BattleFactory.create(p_encounter, p_content)
	resolver = BattleResolver.new(state, rng, p_content)
	recorder = BattleRecorder.new() if p_record else null
	if recorder != null:
		recorder.begin(p_encounter, p_seed, p_content.content_hash(), state)

func resolve_round(intents: Array[BattleIntent]) -> Array[BattleEvent]:
	if state.is_over():
		return []
	if recorder != null:
		recorder.record_snapshot(state.round + 1, state)
		recorder.record_intents(state.round + 1, intents)
	var events := resolver.resolve_round(intents)
	if recorder != null:
		recorder.record_round_events(events)
	if check_invariants:
		var issues := BattleInvariants.check(state)
		for issue in issues:
			push_error("INVARIANT: " + issue)
		if not issues.is_empty() and recorder != null:
			dump_replay()
	if state.is_over() and recorder != null:
		recorder.finish(state)
	return events

func apply_debug_op(op: Dictionary) -> void:
	if recorder != null:
		recorder.record_debug_op(state.round + 1, op)
	match String(op.get("op", "")):
		"kill":
			var kill_unit := state.get_unit(StringName(op.get("unit_id", "")))
			if kill_unit != null and kill_unit.is_alive():
				kill_unit.hp = 0
				kill_unit.alive = false
				kill_unit.statuses.clear()
		"set_hp":
			var hp_unit := state.get_unit(StringName(op.get("unit_id", "")))
			if hp_unit != null:
				hp_unit.hp = clampi(int(op.get("hp", hp_unit.hp)), 0, hp_unit.data.max_hp)
				hp_unit.alive = hp_unit.hp > 0
		"add_status":
			var status_unit := state.get_unit(StringName(op.get("unit_id", "")))
			var status_data := content.get_status(StringName(op.get("status_id", "")))
			if status_unit != null and status_data != null:
				status_unit.add_status(status_data, state.round)
		_:
			push_warning("Unknown debug op: " + String(op.get("op", "")))

func is_over() -> bool:
	return state.is_over()

func outcome() -> int:
	return state.outcome

func dump_replay(path: String = "") -> String:
	if recorder == null:
		return ""
	recorder.finish(state)
	return recorder.save(path)
```

`godot-battle/core/battle_replay.gd`:

```gdscript
class_name BattleReplay
extends RefCounted

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed := JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

static func verify(replay: Dictionary, content: ContentDB, strict_content: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if int(replay.get("replay_version", 0)) != 1:
		errors.append("unsupported replay_version")
		return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}
	var meta: Dictionary = replay.get("meta", {})
	var encounter := content.get_encounter(StringName(meta.get("battle_id", "")))
	if encounter == null:
		errors.append("unknown encounter: " + String(meta.get("battle_id", "")))
		return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}
	if String(meta.get("content_hash", "")) != content.content_hash():
		if strict_content:
			errors.append("content hash mismatch")
		else:
			warnings.append("content hash mismatch")
	errors.append_array(_verify_digest_chain(replay))
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings, "first_divergence": {}}

	var engine := BattleEngine.new(encounter, content, int(meta.get("seed", 0)), false)
	var recorded_by_round := {}
	for event_dict in replay.get("events", []):
		var event_round := int(event_dict.get("round", 0))
		if not recorded_by_round.has(event_round):
			recorded_by_round[event_round] = []
		recorded_by_round[event_round].append(event_dict)

	var rounds: Array = replay.get("rounds", [])
	rounds.sort_custom(func(a, b): return int(a["round"]) < int(b["round"]))
	var first_divergence := {}
	for entry in rounds:
		var entry_round := int(entry["round"])
		for op in entry.get("debug_ops", []):
			engine.apply_debug_op(op)
		var intents: Array[BattleIntent] = []
		for intent_dict in entry.get("intents", []):
			intents.append(BattleIntent.from_dict(intent_dict))
		var produced := engine.resolve_round(intents)
		var expected: Array = recorded_by_round.get(entry_round, [])
		first_divergence = _compare_events(produced, expected)
		if not first_divergence.is_empty():
			break
	if not first_divergence.is_empty():
		errors.append("event divergence: " + String(first_divergence.get("reason", "unknown")))
	else:
		var result: Dictionary = replay.get("result", {})
		if int(result.get("outcome", BattleTypes.Outcome.NONE)) != engine.state.outcome:
			errors.append("outcome mismatch")
		elif int(result.get("rounds", engine.state.round)) != engine.state.round:
			errors.append("round count mismatch")
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "first_divergence": first_divergence}

static func _compare_events(produced: Array[BattleEvent], expected: Array) -> Dictionary:
	if produced.size() != expected.size():
		return {"reason": "event_count", "expected": expected.size(), "produced": produced.size()}
	for index in produced.size():
		var produced_json := JSON.stringify(produced[index].to_dict(), "", true)
		var expected_json := JSON.stringify(expected[index], "", true)
		if produced_json != expected_json:
			return {
				"reason": "event_mismatch",
				"index": index,
				"round": produced[index].round,
				"seq": produced[index].seq,
				"expected": expected[index],
				"produced": produced[index].to_dict(),
				"context_before": expected.slice(maxi(0, index - 5), index),
				"context_after": expected.slice(index + 1, mini(expected.size(), index + 6)),
			}
	return {}

static func _verify_digest_chain(replay: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var events_by_round := {}
	for event_dict in replay.get("events", []):
		var event_round := int(event_dict.get("round", 0))
		if not events_by_round.has(event_round):
			events_by_round[event_round] = []
		events_by_round[event_round].append(event_dict)
	var previous := ""
	for digest_entry in replay.get("digests", []):
		var digest_round := int(digest_entry.get("round", 0))
		var parts: Array[String] = []
		for event_dict in events_by_round.get(digest_round, []):
			parts.append(JSON.stringify(event_dict, "", true))
		var expected := BattleDigest.sha256(previous + "\n" + "\n".join(parts))
		if expected != String(digest_entry.get("sha256", "")):
			errors.append("digest mismatch at round %d" % digest_round)
		previous = expected
	return errors
```

`godot-battle/tools/replay.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var file := ""
	var strict := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--strict-content":
			strict = true
		elif argument.begins_with("--file="):
			file = argument.substr("--file=".length())
		elif not argument.begins_with("--"):
			file = argument
	if file.is_empty():
		printerr("usage: godot --headless --path godot-battle -s tools/replay.gd -- --file <path> [--strict-content]")
		quit(2)
		return
	var replay := BattleReplay.load_file(file)
	if replay.is_empty():
		printerr("REPLAY_FAIL cannot load " + file)
		quit(2)
		return
	var content := ContentDB.load_all()
	var result := BattleReplay.verify(replay, content, strict)
	for warning in result["warnings"]:
		print("REPLAY_WARN " + warning)
	if bool(result["ok"]):
		print("REPLAY_OK " + file)
		quit(0)
	else:
		for error in result["errors"]:
			printerr("REPLAY_FAIL " + error)
		var divergence: Dictionary = result["first_divergence"]
		if not divergence.is_empty():
			printerr("REPLAY_DIVERGENCE " + JSON.stringify(divergence, "  ", true))
		quit(1)
```

- [ ] **Step 5: 运行，确认通过**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected: `PASS test_replay.gd`，全部 0 failures。

再验证 CLI（使用测试生成的录像）：

```bash
godot --headless --path godot-battle -s tools/replay.gd -- --file user://test_replay.json --strict-content
```

Expected: `REPLAY_OK ...`，退出码 0。若 `user://` 路径在宿主机解析失败，改用 `$(godot --headless --path godot-battle -s ... )` 打印的 `REPLAY_SAVED` 绝对路径。

- [ ] **Step 6: 提交**

```bash
git add godot-battle/core godot-battle/tools/replay.gd godot-battle/tests/cases/test_replay.gd
git commit -m "feat(battle): 确定性录像、回放校验与不变量检查"
```

---

## Task 9: 黄金回放、fuzz、过程文档与收尾

**Files:**
- Create: `godot-battle/tools/make_golden.gd`
- Create: `godot-battle/tests/golden/*.json`（工具生成）
- Create: `godot-battle/tests/cases/test_golden.gd`
- Create: `godot-battle/tests/cases/test_fuzz.gd`
- Create: `godot-battle/docs/PROGRESS.md`
- Create: `godot-battle/docs/TECH_NOTES.md`

**Interfaces:**
- Consumes: Task 8 的 `BattleEngine` / `BattleReplay`
- Produces: 3 个黄金回放、50 局 fuzz、M1–M2 过程记录

- [ ] **Step 1: 写黄金回放生成工具**

`godot-battle/tools/make_golden.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/golden"))
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")
	var configs := [
		{"name": "golden_attack", "seed": 1001, "policy": "attack"},
		{"name": "golden_aoe", "seed": 1002, "policy": "aoe"},
		{"name": "golden_control", "seed": 1003, "policy": "control"},
	]
	for config in configs:
		var engine := BattleEngine.new(encounter, content, int(config["seed"]), true)
		for i in 12:
			if engine.is_over():
				break
			engine.resolve_round(_build_intents(engine, String(config["policy"]), content))
		var path := engine.dump_replay("res://tests/golden/%s.json" % String(config["name"]))
		print("GOLDEN: " + path)
	quit(0)

func _build_intents(engine: BattleEngine, policy: String, content: ContentDB) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	var lowest := _lowest_ally(allies)
	for ally in allies:
		match policy:
			"attack":
				intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
			"aoe":
				if ally.id == &"hero_swordsman":
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"sweep"))
				elif ally.id == &"hero_mage":
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"thunder_storm"))
				else:
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [lowest.id], &"heal_all"))
			"control":
				if ally.id == &"hero_swordsman":
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"armor_break"))
				elif ally.id == &"hero_mage":
					var seal_target := enemies[0]
					for enemy in enemies:
						if enemy.id == &"boss_fox":
							seal_target = enemy
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [seal_target.id], &"seal_talisman"))
				else:
					var has_debuff := false
					for ally2 in allies:
						for status in ally2.statuses:
							if status.data.kind == StatusData.Kind.DEBUFF:
								has_debuff = true
					if has_debuff:
						intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [lowest.id], &"cleanse"))
					else:
						intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [lowest.id], &"heal_single"))
	return intents

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	return sorted[0]
```

- [ ] **Step 2: 写黄金回放与 fuzz 测试**

`godot-battle/tests/cases/test_golden.gd`:

```gdscript
extends RefCounted

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var dir := DirAccess.open("res://tests/golden")
	t.ok(dir != null, "golden 目录存在")
	if dir == null:
		return
	var count := 0
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		count += 1
		var replay := BattleReplay.load_file("res://tests/golden/" + file_name)
		var result := BattleReplay.verify(replay, content, true)
		t.ok(bool(result["ok"]), "黄金回放通过: %s %s" % [file_name, str(result["errors"])])
	t.eq(count, 3, "存在 3 个黄金回放")
```

`godot-battle/tests/cases/test_fuzz.gd`:

```gdscript
extends RefCounted

func _random_intents(engine: BattleEngine, choice_rng: RandomNumberGenerator, content: ContentDB) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		var options: Array[int] = [BattleTypes.IntentKind.ATTACK, BattleTypes.IntentKind.DEFEND]
		if not ally.data.skills.is_empty():
			options.append(BattleTypes.IntentKind.SKILL)
		if engine.state.item_remaining(&"potion_hp") > 0 or engine.state.item_remaining(&"potion_mp") > 0:
			options.append(BattleTypes.IntentKind.ITEM)
		var kind: int = options[choice_rng.randi_range(0, options.size() - 1)]
		match kind:
			BattleTypes.IntentKind.ATTACK:
				intents.append(BattleIntent.make(ally.id, kind, [enemies[choice_rng.randi_range(0, enemies.size() - 1)].id]))
			BattleTypes.IntentKind.DEFEND:
				intents.append(BattleIntent.make(ally.id, kind))
			BattleTypes.IntentKind.SKILL:
				var skill := content.get_skill(StringName(ally.data.skills[choice_rng.randi_range(0, ally.data.skills.size() - 1)]))
				if skill == null:
					intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
					continue
				var target := ally.id
				if skill.target_type == SkillData.TargetType.SINGLE_ENEMY or skill.target_type == SkillData.TargetType.ALL_ENEMIES:
					target = enemies[choice_rng.randi_range(0, enemies.size() - 1)].id
				elif skill.target_type == SkillData.TargetType.SINGLE_ALLY or skill.target_type == SkillData.TargetType.ALL_ALLIES:
					target = allies[choice_rng.randi_range(0, allies.size() - 1)].id
				intents.append(BattleIntent.make(ally.id, kind, [target], skill.id))
			BattleTypes.IntentKind.ITEM:
				var item_id := &"potion_hp"
				if engine.state.item_remaining(&"potion_hp") <= 0:
					item_id = &"potion_mp"
				var target := allies[choice_rng.randi_range(0, allies.size() - 1)].id
				intents.append(BattleIntent.make(ally.id, kind, [target], &"", item_id))
	return intents

func run(t: TestContext) -> void:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")
	for battle_index in 50:
		var engine := BattleEngine.new(encounter, content, 5000 + battle_index, false)
		var choice_rng := RandomNumberGenerator.new()
		choice_rng.seed = 9000 + battle_index
		var rounds := 0
		while not engine.is_over() and rounds < 35:
			rounds += 1
			var intents := _random_intents(engine, choice_rng, content)
			engine.resolve_round(intents)
			var issues := BattleInvariants.check(engine.state)
			t.ok(issues.is_empty(), "fuzz #%d round %d: %s" % [battle_index, rounds, str(issues)])
			if not issues.is_empty():
				break
		t.ok(engine.is_over(), "fuzz #%d 在 30 回合内结束" % battle_index)
```

- [ ] **Step 3: 生成黄金回放并运行测试**

Run:

```bash
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tools/make_golden.gd
godot --headless --path godot-battle --editor --quit
godot --headless --path godot-battle -s tests/run_tests.gd
```

Expected:

```text
GOLDEN: res://tests/golden/golden_attack.json
GOLDEN: res://tests/golden/golden_aoe.json
GOLDEN: res://tests/golden/golden_control.json
...
PASS test_golden.gd
PASS test_fuzz.gd
RESULT: ... 0 failures
```

- [ ] **Step 4: 写过程文档**

`godot-battle/docs/PROGRESS.md`:

```markdown
# 推进日志

## 2026-10-24 · M1–M2 战斗内核

- 目标：完成确定性战斗内核、数据化内容、录像/回放与自动化测试。
- 完成：工程骨架；RNG/事件/意图；7 单位/13 技能/5 状态/2 道具/1 遭遇战；回合调度、速度排序、技能、状态、道具、防御、逃跑、AI、胜负；录像/回放/不变量；黄金回放与 fuzz。
- 技术决策：逻辑与表现双轨；所有随机只来自注入的 `BattleRng`；每回合一次性结算并产出有序事件；录像只记录玩家意图，AI 由同种子重放。
- 问题记录：
  - 测试初期直接在真实遭遇战里验证治疗/封印，敌方先手会干扰断言。解决：用“真实单位 + 慢速木桩敌人”的合成状态做单元测试，真实遭遇战只用于集成/黄金回放。
  - 状态持续时间与中毒 tick 的时序容易错。解决：中毒在回合开始 tick；状态在回合结束递减，且施加回合不递减；封印在跳过行动时消耗；防御在自身下次行动开始解除。对应测试覆盖。
- 验证：
  - 命令：`godot --headless --path godot-battle -s tests/run_tests.gd`
  - 结果：把实际输出的 `RESULT: ... 0 failures` 原样粘贴到此处。
  - 黄金回放：3 个文件位于 `tests/golden/`，`--strict-content` 校验通过。
- 风险与遗留：表现层、UI、美术与调试浮层属于 Plan 2；当前没有音画表现。
```

`godot-battle/docs/TECH_NOTES.md`:

```markdown
# 技术方案与踩坑记录

## 1. 双轨制架构

- `core/` 只做战斗结算，禁止 Node/Tween/await/系统时间/全局随机。
- 每回合一次性结算，产出有序 `BattleEvent`；表现层只消费事件，不写战斗数据。
- 好处：可单测、可回放、可跳过/倍速；表现层扩展不影响结算正确性。

## 2. 确定性设计

- 随机源：`BattleRng` 包装 `RandomNumberGenerator`，构造时注入固定种子。
- 顺序：速度 = 基础速度 × [0.95, 1.05]，同速按单位 ID 字典序；Dictionary 输出前排序。
- 记录：引擎版本、内容 hash、种子；跨版本/内容变更会告警或 `--strict-content` 失败。
- 注意：Godot 版本升级可能改变 RNG 实现，回放前先确认引擎版本一致。

## 3. 录像格式

- `rounds[]` 只记录玩家意图（逃跑记为 `actor_id="party"`）；AI 指令由同种子重放。
- `events[]` 为完整事件流；每回合 SHA-256 摘要链，规范化 JSON（键排序）。
- `snapshots[]` 记录每回合开始状态，便于查看异常现场。
- `debug_ops[]` 记录 `kill` / `set_hp` / `add_status`，重放时按相同回合应用。

## 4. 工作流

1. 失败测试 → 2. 最小实现 → 3. headless 全绿 → 4. 提交。
2. 出现异常：dump 录像 → `tools/replay.gd --verify` 复现 → 看第一个分歧事件 → 修复 → 重放摘要一致 → 转正 golden。
3. 每个里程碑更新本文件与 `PROGRESS.md`。

## 5. 坑

- `godot -s` 首次运行前需要 `--editor --quit` 导入工程，否则 `class_name` 可能未注册。
- `Array[自定义类型].duplicate()` 可能丢失类型；需要返回类型数组时用循环 append。
- `JSON.stringify(data, "", true)` 的第三个参数是 `sort_keys`，用于摘要稳定性。
- 真实资源是共享的：测试里不要修改 `UnitData` / `SkillData`，只修改 `BattleUnitState`。
```

- [ ] **Step 5: 全量验证并提交**

Run:

```bash
godot --headless --path godot-battle -s tests/run_tests.gd
echo "exit=$?"
```

Expected: `RESULT: ... 0 failures` 且 `exit=0`。

```bash
git add godot-battle/tools/make_golden.gd godot-battle/tests godot-battle/docs
git commit -m "test(battle): 黄金回放、fuzz 与过程文档"
```

---

## Self-Review

- Spec coverage（本计划范围 M1–M2）：确定性、数据化内容、回合流程、13 技能、5 状态、道具、防御、逃跑、AI、胜负、录像/回放、不变量、fuzz、过程文档均有对应任务。表现层、UI、美术、调试浮层、README/DEBUGGING/EXTENDING 留给 Plan 2。
- Placeholder scan：无 TBD/TODO；所有代码步骤均给出可运行代码；错误信息与命令均具体。
- Type consistency：`BattleEvent`/`BattleIntent`/`BattleRecorder`/`BattleReplay`/`BattleEngine` 的签名在任务间保持一致；`ContentDB` 的 getter 名称固定为 `get_unit/get_skill/get_status/get_item/get_encounter`。

<!-- END -->


