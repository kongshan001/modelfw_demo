# 扩展指南

本项目的边界是：`core/` 决定战斗结果，`data/` 提供数据，`battle/` 和 `ui/` 只消费事件/状态。扩展时优先改数据和表现层，不要在表现层直接改 HP/状态/回合。

> 重要：所有 `res://data/**/*.tres` 会参与内容 hash。修改内容后必须重建黄金回放并跑严格校验；只改 `assets/` 美术不会改变内容 hash，但改核心脚本可能改变事件流，同样可能需要重建黄金，详见文末。

## 1. 新增技能

1. 在 `data/skills/` 新建 `<skill_id>.tres`，可复制 `fire_spell.tres` 后改字段。
2. 字段：

| 字段 | 说明 |
| --- | --- |
| `id` | 唯一 `StringName`，与文件名/引用一致。 |
| `display_name` | HUD 与日志显示名。 |
| `mp_cost` | MP 不足时 HUD 禁用该技能。 |
| `target_type` | `0` 单体敌人、`1` 全体敌人、`2` 单体我方、`3` 全体我方、`4` 自身。 |
| `max_targets` | 多目标上限；AOE 由目标类型/解析器处理。 |
| `effects` | `BattleEffect` 数组，决定伤害/治疗/上状态/净化/回 MP。 |
| `visual_id` | 对应 `VFXFactory` 的特效 id；未知值回退 `generic`。 |
| `shout_text` | 非空时，技能行动开始会在施法者头顶显示喊招气泡。 |

3. 若需要战斗效果，给 `effects[]` 添加子资源。常用构造类型：

   - `BattleEffect.Kind.DAMAGE`：`damage_type`（`0` 物理、`1` 魔法）、`power`；
   - `Kind.HEAL`：`power`、`flat_amount`；
   - `Kind.APPLY_STATUS`：`status_id`、`status_chance`；
   - `Kind.CLEANSE`：`cleanse_count`；
   - `Kind.RESTORE_MP`：`flat_amount`。

4. 把技能 id 加进相应单位的 `data/units/<unit>.tres` 的 `skills` 数组。HUD 按角色 `skills` 列表自动生成菜单；AI 的通用策略从列表里选择可施放技能，专用 AI 见第 5 节。
5. 若技能需要新的特效形状/音效，在 `battle/vfx_factory.gd`/`battle/audio_director.gd` 增加 id 分支；否则用现有视觉 id。
6. 写/扩展 `tests/cases/test_skills.gd`（数值、目标、MP、状态等），然后按文末流程重建黄金。

## 2. 新增状态

1. 在 `data/statuses/` 新建 `<status_id>.tres`，参考 `poison.tres`。
2. 字段语义：

| 字段 | 说明 |
| --- | --- |
| `id` / `display_name` | 唯一 id 与日志显示名。 |
| `kind` | `0` BUFF、`1` DEBUFF；AI 净化/统计会使用。 |
| `duration` | 持续回合数；施加当回合不递减。 |
| `expires_on_owner_action` | 在拥有者下次行动开始时解除（如防御）。 |
| `skips_action` | 拥有者行动被跳过（如封印）。 |
| `damage_taken_mult` | 受到伤害倍率。 |
| `seal_resist_bonus` | 封印抗性加成。 |
| `atk_mult` / `defense_mult` | 攻击/防御倍率。 |
| `poison_max_hp_ratio` | 每回合开始按最大 HP 比例的毒伤；为 0 表示无。 |
| `icon_path` | 数据层的可选图标路径；HUD/UnitView 优先走 `VisualCatalog.status_icons`。 |
| `display_color` | 文字徽章/特效颜色。 |

3. 通过技能的 `APPLY_STATUS` 效果或调试命令 `add_status` 施加。状态持续时间、tick、封印跳过、防御解除的时序由 `core/battle_resolver.gd` 统一处理；不要在表现层计时。
4. 状态徽章：`UnitView` 对 `poison/armor_down/war_cry/defending/sealed` 有内置单字映射，未知状态取 `display_name` 首字。要显示自定义图标，在 `assets/visuals/visual_catalog.json` 的 `status_icons` 配置。
5. 扩展 `tests/cases/test_status_items.gd`（持续时间、抵抗、解除、毒伤等），再按文末流程重建黄金。

## 3. 新增道具

1. 在 `data/items/` 新建 `<item_id>.tres`，参考 `potion_hp.tres`。
2. 字段：`id`、`display_name`、`effects[]`、`max_uses`、可选 `icon_path`。道具效果类型与技能共用 `BattleEffect`。
3. 在 `data/encounters/<encounter>.tres` 的 `item_counts` 中配置本场可用次数，例如：

   ```text
   item_counts = {
   "potion_hp": 3,
   "potion_mp": 3
   }
   ```

4. HUD 的“道具”菜单会列出当前 `ContentDB` 内所有道具，并按本场 `item_remaining()` 禁用/显示次数；目标固定为我方单体。若要做敌方道具或特殊目标，需要同时扩展 HUD 与解析器。
5. 补 `tests/cases/test_status_items.gd` 后重建黄金。

## 4. 新增表现命令（BattleCommand）

先区分两种“命令”：

- **玩家指令（BattleIntent）**：攻击/技能/道具/防御/逃跑，属于核心规则。新增一种需要改 `BattleTypes.IntentKind`、解析器、HUD、录像与测试，成本较高；现有玩法优先用技能+效果表达。
- **表现命令（BattleCommand）**：把 `BattleEvent` 演出来，属于本层，可独立扩展。

新增表现命令的步骤：

1. 在 `battle/commands/` 新建 `my_event_command.gd`：

   ```gdscript
   class_name MyEventCommand
   extends BattleCommand

   var event: BattleEvent

   func _init(p_event: BattleEvent) -> void:
       event = p_event

   func play(ctx: BattleContext) -> void:
       # 只读 event/ctx；需要等待时用 await ctx.wait(...)
       pass

   func skip(ctx: BattleContext) -> void:
       # 清理临时节点/提示；不要修改战斗状态
       pass
   ```

2. 在 `battle/command_registry.gd` 的 `create()` 里把对应 `event.type` 映射到新命令；未映射事件会回落到 `SimpleEventCommand`。
3. 播放逻辑必须尊重 `ctx.is_skipping()` 和 `ctx.wait()`，headless 下不能依赖可视节点（或像 `VFXFactory` 一样在 headless 跳过）。
4. 运行表现冒烟/截图检查，必要时在 `smoke_presentation.gd` 或 `screenshot_*.gd` 中覆盖；如果只是纯视觉命令，不需要改黄金回放。

## 5. 新增单位/角色

1. 在 `data/units/` 新建 `<unit_id>.tres`，字段见 `core/data/unit_data.gd`：基础属性、`skills[]`、`ai_profile`、可选 `sprite_path`/`visual_scale`。
2. 现有 `ai_profile`：

   - `melee`：优先施放第一个可施放技能（60% 概率），否则普攻；
   - `brute`：先 `war_cry`，敌方 ≥2 时 60% 用 `ground_split`；
   - `fox`：优先对治疗/法师/最残血目标用 `charm_seal`（70%），否则 `fox_fire`；
   - `poison_melee`：60% 用 `poison_strike`，否则普攻。

   新的专用 AI 分支要改 `battle_resolver.gd`；否则可用通用行为。
3. 把单位 id 加入 `data/encounters/enc_bamboo_01.tres` 的 `ally_unit_ids` 或 `enemy_unit_ids`。当前场景/`BattleSession._build_units()` 固定提供 3 个我方槽位和 4 个敌方槽位；超过这个数量需要增加坐标、HUD/命中区适配和战斗 UI 验证。
4. 外观：

   - 最简单：保留未知 id 的 `UnitView` 通用剪影；
   - 或在 `UnitView._draw()` 增加 id 分支，复用现有绘制原语；
   - 或走视觉目录：在 `assets/visuals/units/` 放透明 PNG，在 `visual_catalog.json` 配置 `sprite`、`scale`、`offset`。推荐以 300px 为目标高度，`scale = 300 / 图片像素高度`，图片底边对齐脚底。
5. 若新单位/技能进入遭遇战，内容 hash 变化，必须重建黄金并补测试；AI 行为变化即使内容 hash 不变，也要重建/验证黄金。

## 6. 新增剧情 beat

### 只改对白文本

`data/encounters/enc_bamboo_01.tres` 里的 `script_data` 是 `EncounterScript` 子资源，编辑以下数组即可：

- `intro_lines`：开场对白；
- `first_kill_lines`：首次击杀敌方时的对白（只触发一次，且只由敌方死亡触发）；
- `victory_lines` / `defeat_lines`：结局对白。

对白框支持点击、`Space`/`Enter`、自动推进；剧情期间 HUD 日志隐藏，播放控件保留。改文本会改变内容 hash，需要重建黄金。

### 新增一种 beat 类型

当前 `BattleDirector._append_beats()` 只把 `kind == "dialogue"` 的 beat 转成 `DialogueCommand`，`BattleHUD.play_beat()` 也只处理 dialogue 并等待。新增例如 `banner`：

1. 在 `core/data/encounter_script.gd` 的 `beats_for_*()` 返回 `{"kind": "banner", ...}`；
2. 新建 `BattleCommand` 子类并在 `BattleDirector._append_beats()` 中实例化；
3. 开场 beat 走 `BattleSession._play_beat()` → `BattleHUD.play_beat()`，需要同步添加分支；
4. 若该 beat 影响战斗规则，改到 core；纯演出保持在表现层；
5. 同步更新 `tools/probe_story.gd` 或截图工具以覆盖新路径。

## 7. 新增/替换视觉资源（VisualCatalog）

当前所有美术为空路径，程序化绘制兜底。替换步骤：

1. 建立目录（可选）：`assets/visuals/units/`、`assets/visuals/background/`、`assets/visuals/status/`、`assets/visuals/commands/`。
2. 编辑 `assets/visuals/visual_catalog.json`：

   ```json
   {
     "units": {
       "hero_swordsman": {
         "sprite": "res://assets/visuals/units/hero_swordsman.png",
         "scale": 0.293,
         "offset": [0, 0]
       }
     },
     "background": {
       "path": "res://assets/visuals/background/bamboo_dawn.png",
       "scale": 1.0,
       "modulate": [1.0, 0.98, 0.94, 1.0]
     },
     "status_icons": {
       "poison": {"path": "res://assets/visuals/status/poison.png"}
     },
     "command_icons": {
       "attack": {"path": "res://assets/visuals/commands/attack.png"}
     }
   }
   ```

3. 推荐规格：角色透明 PNG，底边贴脚底，目标高度 300px；背景 1920×1080；状态/指令图标 24–28px。脚底对齐通过 `offset`（相对脚底，向上为负 y）微调。
4. 导入资源：

   ```bash
   godot --headless --path godot-battle --editor --quit
   ```

5. 如果没有导入但文件存在，`VisualCatalog` 会尝试 `Image.load_from_file`；正式发布请走 Godot 导入管线。路径为空、文件缺失或损坏时自动回退程序化美术。
6. 背景覆盖时，光柱、地面光斑、地面薄雾、暗角、雾带和飘叶层仍叠加；背景图的细微风格不匹配可能需要在 `visual_catalog.json` 里用 `modulate` 调色。
7. 只改 `assets/` 不改变内容 hash；但如果同时修改 `UnitData.sprite_path`（数据字段），就会改变 hash 并需要重建黄金。素材来源与许可证必须登记在 `assets/art/CREDITS.md`（`assets/CREDITS.md` 为兼容入口）。

## 8. 新增遭遇战

1. 在 `data/encounters/` 新建 `<encounter_id>.tres`，设置 `ally_unit_ids`、`enemy_unit_ids`、`item_counts`、奖励、`max_rounds`、可选 `background_path`/`bgm_path`、`script_data`。
2. 当前 `BattleSession.start()` 固定读取 `enc_bamboo_01`；场景启动种子固定为 `20261024`（截图/工具可覆盖）。要切换默认遭遇战，需要在 `battle_session.gd`/`battle_scene.gd` 提供选择参数或改读取逻辑。
3. 当前 HUD/站位按 3 我方/4 敌方布局，换阵容时重点验证 `_build_units()` 槽位、`smoke_hud_input.gd` 的点击区/信息带断言和截图。
4. 新增 `.tres` 会改变内容 hash；重建黄金并跑严格回放。

## 9. 测试、内容 hash 与黄金回归

### 测试用例

核心测试自动发现 `tests/cases/*.gd`。每个文件是一个用例，`run(t)` 必须正好接收一个 `TestContext` 参数并至少产生一个断言：

```gdscript
extends RefCounted

func run(t: TestContext) -> void:
    t.ok(true, "示例断言")
    t.eq(2 + 2, 4, "示例相等")
```

`TestContext` 提供 `ok/eq/in_range/near/has`；测试失败信息会聚合到门禁末尾。运行：

```bash
bash godot-battle/tools/run_tests.sh; echo "exit=$?"
```

### 内容 hash

`ContentDB.content_hash()` 的算法是：递归收集 `res://data/**/*.tres`，按完整路径排序，依次对“路径 UTF-8 + 文件全文 UTF-8”做 SHA-256。因此：

- 新增/删除/改任何数据 `.tres` 都会改变内容 hash；
- `assets/` 美术、脚本和 `.md` 文档不会改变内容 hash；
- 当前黄金记录的内容 hash 为 `sha256:4381648d...ef25975`（完整值见 `docs/DEBUGGING.md`）。

> 注意：内容 hash 只覆盖 `.tres` 中实际序列化的字段。取自脚本默认值的字段（例如 `ItemData.max_uses = 3`、`EncounterData.max_rounds = 30`）如果没有在 `.tres` 里显式写出，修改脚本默认值不会改变内容 hash，但行为可能变化，严格黄金校验也不会因此提示。修改这类默认值后，必须重建内容/黄金，或在变更说明中记录并重新验证黄金；需要让 hash 覆盖该字段时，在对应 `.tres` 中显式序列化它。

### 黄金回放

内容变化后重建：

```bash
godot --headless --path godot-battle -s tools/make_golden.gd
```

然后严格校验：

```bash
godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_attack.json --strict-content
godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_aoe.json --strict-content
godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_control.json --strict-content
bash godot-battle/tools/run_tests.sh; echo "exit=$?"
```

注意：

- 黄金文件不是“胜利演示”，三份当前均为 12 回合、outcome=0 的过程回放；
- 生成时 `meta.created_at` 变化，**不要用原始文件 diff** 判断回归；以事件/摘要/严格回放校验为准；
- 改核心脚本（比如结算顺序）但不改 `.tres` 时，内容 hash 不变，黄金可能仍会因事件流变化失败——这类行为变化同样要重建黄金；
- 黄金只能通过生成工具和人工审查来更新，不要手改 JSON 绕过失败。

### 完整自检

```bash
bash godot-battle/tools/run_tests.sh; echo "exit=$?"
godot --headless --path godot-battle -s tools/smoke_presentation.gd; echo "exit=$?"
godot --headless --path godot-battle -s tools/probe_story.gd; echo "exit=$?"
godot --headless --path godot-battle -s tools/smoke_debug.gd; echo "exit=$?"
godot --path godot-battle --resolution 1920x1080 -s tools/smoke_hud_input.gd; echo "exit=$?"
```

## 10. 调试扩展点

- 新增 `BattleEngine.apply_debug_op` 的操作类型：同时更新 `BattleRecorder.record_debug_op` 的调用路径和 F1 控制台命令，确保操作被录像；回放会按回合重放 `debug_ops[]`。
- 新增 F1 命令：在 `ui/debug/debug_console.gd` 的 `_run()` 增加分支和帮助文本；调试状态修改优先通过 engine API，不要直接改 `BattleState`。
- 新增 F3 字段：在 `ui/debug/debug_overlay.gd` 的 `_refresh()` 添加只读展示，保持每帧刷新成本低。
- 新工具脚本放在 `tools/`，命名清晰，并在 README/DEBUGGING 中补命令与预期输出；工具不应依赖 release 构建或强制写 `res://data`。
- 调试 UI 仅 `OS.is_debug_build()` 生效；所有调试操作仍要服从确定性录像/回放规则。
