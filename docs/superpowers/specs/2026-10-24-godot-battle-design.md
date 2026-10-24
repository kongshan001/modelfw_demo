# 《山海试炼》Godot 2D 回合制战斗 Demo — 设计规格

- 日期：2026-10-24
- 状态：已与用户确认
- 落地位置：仓库内新子项目 `godot-battle/`
- 引擎：Godot 4.6 stable（本机已安装）
- 平台：macOS 桌面，1920×1080，键鼠，中文界面
- 美术：原创 Q 版；参考《梦幻西游》的构图、镜头与战斗节奏，不使用其任何原版素材

---

## 1. 目标与非目标

### 1.1 目标

交付一个**可完整游玩、可测试、可录像回放**的单场回合制战斗切片：

- 我方 3 人全员手动操作 vs 敌方 4 人
- 回合制：指令阶段 + 速度排序执行
- 完整表现层：入场、出手、受击、法术特效、飘字、血条缓动、战斗日志、喊招气泡、对白、结算
- 逻辑层可单元测试；战斗可录像、可回放、可定位分歧
- 扩展 BUFF、剧情、对话、弹框、新技能时不需要修改既有模块

### 1.2 非目标

地图探索、养成/装备、多人联机、存档、召唤兽、阵法、任务与剧情分支、视频录制、发布打包、CI 接入。以上均不进入 MVP。

---

## 2. 技术基线

| 项 | 决定 |
|---|---|
| 引擎 | Godot 4.6 stable |
| 语言 | GDScript |
| 渲染 | Forward+，2D |
| 分辨率 | 1920×1080，窗口模式 |
| 输入 | 鼠标为主，键盘快捷键（F1/F3/F6/F7 仅 debug） |
| 平台 | macOS；代码不依赖平台特性 |
| 第三方插件 | 不引入；测试运行器自写 |
| 现有仓库 | 只新增 `godot-battle/` 与本文档，不改动基准测试工程 |

---

## 3. 目录结构

```
godot-battle/
├── project.godot
├── core/                        # 纯逻辑，不依赖场景树
│   ├── battle_rng.gd
│   ├── battle_state.gd
│   ├── battle_unit_state.gd
│   ├── battle_intent.gd
│   ├── battle_event.gd
│   ├── battle_resolver.gd
│   ├── battle_invariants.gd
│   ├── battle_recorder.gd
│   ├── battle_replay.gd
│   ├── content_hash.gd
│   └── data/                    # Resource 类定义
│       ├── unit_data.gd
│       ├── skill_data.gd
│       ├── effect_data.gd
│       ├── status_data.gd
│       ├── item_data.gd
│       ├── encounter_data.gd
│       └── encounter_script.gd
├── battle/                      # 表现层
│   ├── battle_session.gd
│   ├── battle_director.gd
│   ├── battle_sequencer.gd
│   ├── battle_context.gd
│   ├── command_registry.gd
│   ├── commands/
│   └── views/
├── ui/
│   ├── battle_hud.tscn / .gd
│   ├── command_panel.tscn / .gd
│   ├── target_selector.gd
│   ├── turn_order_bar.gd
│   ├── battle_log.gd
│   ├── dialogue_box.tscn / .gd
│   ├── bubble.gd
│   ├── victory_panel.tscn / .gd
│   └── debug/
│       ├── debug_console.tscn / .gd
│       └── debug_overlay.gd
├── data/                        # 内容资源（.tres）
│   ├── units/  skills/  statuses/  items/  encounters/
├── scenes/
│   ├── main.tscn
│   └── battle_scene.tscn
├── assets/
│   ├── placeholder/  art/  audio/  fonts/  vfx/
│   └── CREDITS.md
├── tests/
│   ├── run_tests.gd
│   ├── cases/
│   └── golden/
├── tools/
│   └── replay.gd                # headless 回放/校验入口
└── docs/
    ├── PROGRESS.md              # 迭代推进日志（持续更新）
    ├── TECH_NOTES.md            # 技术方案与踩坑记录（持续更新）
    ├── DEBUGGING.md
    └── EXTENDING.md
```

---

## 4. 架构

### 4.1 分层与硬规矩

```
core/     纯逻辑：不碰 Node / Tween / await，可 headless 单测
battle/   表现：Director / Sequencer / Command / UnitView / VFX
ui/       HUD、指令面板、日志、对话、弹框、调试工具
data/     内容资源，改数值/加技能不碰代码
```

**硬规矩：表现层永远不写战斗数据。** HP、MP、BUFF、死亡只由 `core/` 修改；表现层只根据事件播放“看起来发生的事”。

**硬规矩：逻辑层无外部随机源。** 所有随机必须来自注入的 `BattleRng` 实例；表现层的装饰性随机使用独立的 `VisualRng`，两者绝不共用。

### 4.2 核心类型

```gdscript
# 随机数：包装 RandomNumberGenerator，只暴露受限接口
class_name BattleRng
var _rng: RandomNumberGenerator
func _init(seed: int) -> void
func randf_range(a: float, b: float) -> float
func randi_range(a: int, b: int) -> int
func chance(p: float) -> bool
func state() -> int
func set_state(s: int) -> void

# 指令意图：只描述“想做什么”，合法性由逻辑层校验
class_name BattleIntent
var actor_id: StringName
var kind: IntentKind          # ATTACK / SKILL / ITEM / DEFEND / FLEE
var skill_id: StringName
var item_id: StringName
var target_ids: Array[StringName]

# 战斗事件：表现层唯一的信息来源
class_name BattleEvent
var seq: int                  # 自增序号，从 1 开始
var round: int
var type: StringName
var source_id: StringName
var target_ids: Array[StringName]
var data: Dictionary          # 事件参数，如 amount / crit / hp_before / hp_after
```

`BattleEvent.type` 的 MVP 取值：`round_start`、`round_end`、`status_tick`、`status_apply`、`status_refresh`、`status_expire`、`status_resist`、`action_start`、`action_skipped`、`defend`、`damage`、`heal`、`mp_change`、`death`、`item_used`、`flee_attempt`、`flee_result`、`intent_rejected`、`battle_end`。

### 4.3 回合数据流

1. 指令阶段：玩家为 3 名存活角色下指令，得到 `Array[BattleIntent]`；超时自动生成“普攻随机敌人”的意图。
2. `BattleResolver.resolve_round(state, player_intents, rng)`：
   - 校验意图：目标已死、MP 不足、物品用尽 → 降级为防御，并产生 `intent_rejected` 事件
   - 生成敌方 AI 意图（同一 RNG）
   - 结算回合开始的持续伤害/治疗
   - 按有效速度排序，逐个执行
   - 修改权威状态 `BattleState`，产出有序 `Array[BattleEvent]`
3. `BattleDirector`：把事件翻译成表现命令入队；在钩子位置插入 `EncounterScript` 提供的命令（开场对白、喊招、胜利弹框）。
4. `BattleSequencer`：FIFO 播放命令；支持串行、并行、等待、条件、倍速、跳过。
5. 播放完成后判定胜负，进入下一回合或结束。

**权威状态与视图状态分离**：逻辑层在产出事件时已提交最终状态；表现层维护自己的显示值（血条当前值、状态图标等），按事件增量更新。因此“跳过本回合”只需把视图拉到快照，不需要重算或倒放。

### 4.4 表现层命令与队列

```gdscript
class_name BattleCommand
func play(ctx: BattleContext) -> void: pass   # 可 await
func skip(ctx: BattleContext) -> void: pass   # 跳过时立即完成
func is_skippable() -> bool: return true

class_name BattleSequencer
func enqueue(cmd: BattleCommand) -> void
func enqueue_batch(cmds: Array) -> void
func prepend(cmd: BattleCommand) -> void      # 仅逻辑事件顺序允许时使用
func play_all() -> void
func skip_all() -> void
var time_scale: float = 1.0
var step_mode: bool = false
```

组合命令：`SequenceCommand`、`ParallelCommand`、`WaitCommand`、`CallbackCommand`。

`BattleContext` 提供：单位视图、镜头装置、VFX 生成器、HUD、音频、**只读**状态快照（仅用于跳过时拉齐视图）。命令只能通过 Context 操作表现层，不得访问或修改逻辑层状态对象。

命令注册表：按事件类型 / 剧情类型登记工厂回调。未知事件在 debug 下打印 warning 并跳过，不中断播放。

### 4.5 场景节点结构

```
BattleScene (Node2D)
├── CameraRig (Camera2D)
├── Background (ParallaxBackground)
│   ├── Sky
│   ├── Mid
│   └── Ground
├── World (Node2D)
│   ├── EnemySlots (Marker2D ×4)
│   ├── AllySlots (Marker2D ×3)
│   ├── Units (Node2D)              # UnitView 实例
│   ├── VFXLayer (Node2D)
│   └── ForegroundFog (GPUParticles2D)
├── UILayer (CanvasLayer)
│   ├── BattleHUD
│   ├── DialogueBox
│   ├── VictoryPanel
│   └── DebugOverlay                # 仅 debug 构建
└── BattleSession (Node)
    ├── BattleDirector
    └── BattleSequencer
```

调试控制台 `DebugConsole` 由 debug 构建自动挂载为 Autoload。

### 4.6 扩展点（“加东西不改旧代码”的保证）

| 要加的东西 | 做法 | 是否改核心 |
|---|---|---|
| 新技能（使用已有效果原语） | 新建 `SkillData` .tres，在 `UnitData.skills` 里引用 | 否 |
| 新 BUFF/DEBUFF（标准属性修正/持续伤害） | 新建 `StatusData` .tres + 图标；必要时加 `StatusVisualProfile`。全新的结算机制才需要新增一个效果原语 | 否（新机制除外） |
| 新特效表现 | 新建/替换 VFX 场景，改技能或状态的表现配置 | 否 |
| 新流程节点（黑屏/运镜/剧情动画） | 新增 `BattleCommand` 子类并注册 | 否 |
| 对白/气泡/弹框 | 使用内置 `DialogueCommand` / `BubbleCommand` / `PopupCommand`，或在 `EncounterScript` 中配置 | 否 |
| 新触发时机 | 在 `EncounterScript` 加钩子实现 | 否 |
| 新事件类型 | 逻辑层发出事件 + 注册新的表现工厂；旧命令忽略未知事件 | 仅新增 |

**顺序保证**：AOE 多目标、反击（未来）、死亡跳过行动等时序全部由逻辑层事件顺序定死；表现层不得自行插队。

---

## 5. 战斗规则

### 5.1 回合流程

1. **回合开始**：展示轮次横幅；结算持续伤害/治疗（中毒等）。
2. **指令阶段**：25 秒倒计时；3 名存活角色依次下指令，可回退重选；超时自动“普攻随机敌人”。
3. **执行阶段**：全体按有效速度从高到低行动；死亡、被封印的单位跳过并飘字提示。
4. **回合结束**：BUFF 持续回合 −1、到期移除；判定胜负；进入下一回合。

有效速度 = `SPD × uniform(0.95, 1.05)`（乱敏）；同速按单位 ID 字典序稳定排序。

### 5.2 属性与公式

属性：HP、MP、物攻、物防、法攻、法防、速度、暴击率。

- 物理伤害 = `max(1, round((物攻 × 技能倍率 − 物防 × 0.6) × uniform(0.9, 1.1)))`
- 法术伤害 = `max(1, round((法攻 × 技能倍率 − 法防 × 0.5) × uniform(0.9, 1.1)))`
- 治疗量 = `round(法攻 × 技能倍率 × uniform(0.95, 1.05))`
- 暴击：先乘随机波动，再乘暴击倍率，最后取整；物理 ×1.6，法术 ×1.5
- 防御姿态：最终伤害 ×0.5，受封印命中率 ×0.7
- 所有结果受上限约束：HP ≤ 最大 HP，MP ≤ 最大 MP

### 5.3 我方角色

| 角色（ID） | HP | MP | 物攻 | 物防 | 法攻 | 法防 | 速度 | 暴击 |
|---|---|---|---|---|---|---|---|---|
| 剑客·凌霄 `hero_swordsman` | 620 | 80 | 118 | 72 | 20 | 50 | 92 | 18% |
| 法师·青鸾 `hero_mage` | 460 | 220 | 40 | 45 | 135 | 85 | 85 | 10% |
| 医师·白术 `hero_healer` | 540 | 180 | 52 | 58 | 105 | 78 | 78 | 8% |

| 技能（ID） | 归属 | MP | 目标 | 倍率/效果 |
|---|---|---|---|---|
| 横扫千军 `sweep` | 剑客 | 30 | 敌方最多 3 人 | 物理 0.85 |
| 破甲击 `armor_break` | 剑客 | 20 | 单体敌方 | 物理 1.25 + 破甲 2 回合（100%） |
| 烈火咒 `fire_spell` | 法师 | 25 | 单体敌方 | 法术 1.5 |
| 雷霆万钧 `thunder_storm` | 法师 | 45 | 全体敌方 | 法术 0.9 |
| 定身符 `seal_talisman` | 法师 | 30 | 单体敌方 | 封印，65% 命中 |
| 回春术 `heal_single` | 医师 | 30 | 单体友方 | 治疗 1.6 |
| 清心咒 `cleanse` | 医师 | 25 | 单体友方 | 解除 1 个负面状态 + 治疗 0.5（无负面状态时只治疗） |
| 灵雨 `heal_all` | 医师 | 50 | 全体友方 | 治疗 0.8 |

AOE 目标规则：玩家选一个主目标，命中主目标 + 同阵营中与其槽位距离最近的其余目标，数量不超过技能上限。

### 5.4 敌方

| 敌人（ID） | HP | MP | 物攻 | 物防 | 法攻 | 法防 | 速度 | 暴击 | 技能 |
|---|---|---|---|---|---|---|---|---|---|
| 妖兵·甲 `mob_a` | 380 | 0 | 82 | 40 | 10 | 30 | 70 | 5% | 无（普攻） |
| 妖兵·乙 `mob_b` | 380 | 0 | 78 | 40 | 10 | 30 | 70 | 5% | 淬毒击 `poison_strike`（物理 0.9 + 中毒） |
| 妖将·裂山 `boss_brute` | 720 | 60 | 105 | 65 | 20 | 45 | 62 | 10% | 裂地斩 `ground_split`（物理 1.0，最多 2 人，MP 20）、战吼 `war_cry`（自身 ATK +20%，2 回合，MP 15） |
| 狐妖·媚娘 `boss_fox` | 420 | 120 | 30 | 38 | 110 | 70 | 88 | 8% | 妖火 `fox_fire`（法术 1.3，MP 20）、魅惑封印 `charm_seal`（封印，60%，MP 25） |

### 5.5 状态

| 状态（ID） | 类型 | 效果 | 持续 |
|---|---|---|---|
| 中毒 `poison` | 负面 | 回合开始损失 8% 最大 HP | 3 回合 |
| 破甲 `armor_down` | 负面 | 物防 −25% | 2 回合 |
| 战吼 `war_cry` | 正面 | 物攻 +20% | 2 回合 |
| 防御姿态 `defending` | 正面 | 受伤 ×0.5，封印命中率 ×0.7 | 直到自身下次行动开始 |
| 封印 `sealed` | 负面 | 跳过行动 | 消耗一次行动后解除 |

规则细节：

- 中毒/持续效果在**回合开始**结算；状态持续时间在**回合结束**递减，但施加状态的那一回合不递减；持续伤害的最后一跳发生在剩余回合为 1 的回合开始。
- 同名状态重复施加 = 刷新持续时间，不叠加。
- 封印在目标行动时消耗：跳过该次行动并立即解除；封印命中失败产生 `status_resist` 事件，MP 照常消耗。

### 5.6 道具、防御、逃跑

- 道具为全队共享池：金疮药 `potion_hp`（回复 220 HP）×3，凝神散 `potion_mp`（回复 80 MP）×3；使用消耗该角色本回合行动。
- 防御：该角色本回合行动变为防御，获得“防御姿态”，持续到其下次行动开始。
- 逃跑为**全队指令**（指令面板单独按钮）：立即放弃其余指令。执行阶段开始时判定，基础 50%，我方存活角色平均速度每高于敌方 10 点 +8%，上限 90%。成功直接结束战斗；失败则本回合我方不行动，敌方正常行动。

### 5.7 AI

- 通用：MP 足够时有 60% 概率使用技能，否则普攻；优先攻击血量百分比最低的目标，20% 概率随机选择目标。
- 妖将：未带战吼时优先战吼；裂地斩仅在可命中 ≥2 人时使用。
- 狐妖：优先封印医师/法师（权重 70%），否则使用妖火。
- 妖兵·乙：淬毒击与普攻按 60% 概率选择。
- AI 与玩家共用同一 `BattleRng`，固定种子可完整复现。

### 5.8 边界规则

- 一方全灭：立即产生 `battle_end` 事件，中断本回合剩余行动。
- 已死单位不可被选中、不可被治疗；MVP 无复活。
- 指令阶段校验失败（目标已死 / MP 不足 / 物品用尽）：意图降级为防御，产生 `intent_rejected`。
- 执行到某个单位时其单体目标已死亡：自动改选同阵营中随机存活目标；若无可选目标则跳过该次行动（产生 `action_skipped`）。
- 逃跑失败不产生额外惩罚，除本回合不行动外。
- 逃跑意图以 `actor_id = "party"` 记录，每回合最多一条，且排在所有角色意图之前。
- 奖励固定写在遭遇战资源：经验 1200、金币 350；逃跑成功无奖励。
- 战斗最长回合数 30；超过即判失败（防止测试/异常时死循环）。

---

## 6. 表现层

### 6.1 构图与背景

- 1920×1080 横版侧视；敌方 4 人在画面左侧，后排略缩小（scale 0.92），我方 3 人在右侧前排，朝向相对。
- 背景三层视差：远景山水/天空、中景竹林/岩石、地面；叠加雾粒子、光斑、轻微镜头漂移（±6px，8 秒周期）。
- 单位脚底软阴影，屏幕高度约 260–340px。

### 6.2 单位动画（程序化，不依赖逐帧）

| 动作 | 表现 |
|---|---|
| 待机 | 上下浮动 4px + 轻微挤压，1.8 秒循环 |
| 选中 | 脚下高亮圈 + 小幅弹跳 |
| 攻击 | 前冲到目标前（0.18s）→ 挤压挥击（0.12s）→ 回位（0.2s） |
| 施法 | 上浮 + 发光 + 脚下法阵，0.5s 蓄力后出招 |
| 受击 | 白闪 shader + 后仰 + 击退 12px |
| 死亡 | 变灰 + 下落淡出 + 粒子消散 |

最终 AI 美术只需提供**单张立绘**，不需要逐帧动画；立绘规格：透明 PNG、1024×1024、3/4 正面、脚底对齐、统一色板。

### 6.3 打击感与特效

- 顿帧：命中瞬间 60–90ms（`Engine.time_scale` 短暂降低后恢复，计时器忽略时间缩放）
- 屏震：受击 3–5px / 0.12s；暴击 6px
- 镜头：施法与暴击轻微推近至 1.04，0.15s 后复位
- 飘字：伤害（白/黄）、暴击（金色、1.4 倍）、治疗（绿色）、状态（紫/蓝）；0.8 秒上浮淡出
- 血条：0.35 秒缓动，延迟白条残影
- AOE：每个目标间隔 80–120ms 依次命中
- 特效清单：火（橙红粒子 + 火星 + 暖色闪光）、雷（折线闪电 + 白闪 + 震屏）、风/水（旋涡弧线 + 水花）、治疗（上升光点 + 地面光环）、封印（符文环 + 符纸/锁链）
- 实现：`GPUParticles2D` + 着色器 + `AnimatedSprite2D`/贴图；占位贴图可替换

### 6.4 HUD

- 右下：指令面板（攻击 / 法术 / 道具 / 防御），梦幻风圆角木质按钮；**逃跑**为面板外的全队按钮，点击后放弃剩余指令并进入执行阶段
- 目标选择：黄色箭头在目标头顶跳动；AOE 显示影响范围
- 左上：出手顺序条（头像 + 序号，高亮当前行动者）
- 左下：战斗日志（`RichTextLabel`，自动滚动，颜色区分伤害/治疗/状态）
- 顶部中央：回合横幅（“第 N 回合”滑入滑出）
- 头顶：血条/蓝条 + BUFF 图标行；鼠标悬停显示单位名称与状态
- 喊招气泡：出手时角色头顶显示技能台词
- 结算面板：胜利/失败/逃脱；经验、金币数字跳动；按钮“再战一场”

### 6.5 对白与剧情

- 开场对白 1 段（电影黑边 + 打字机效果），首次击杀触发 1 段，胜利结算。
- 全部通过 `DialogueCommand` / `PopupCommand` / `EncounterScript` 钩子实现，不硬编码进战斗流程。

### 6.6 音频

- 免费 CC0 音效：挥砍、命中、暴击、火焰、雷击、治疗、封印、按钮、胜利/失败
- BGM 1 首占位；提供总音量与静音按钮；素材缺失时静默降级

### 6.7 播放控制

- 1x / 2x 倍速切换
- “跳过本回合”：清空当前队列，视图直接应用逻辑快照
- debug 构建支持单步模式（F6 暂停 / F7 单步）

**推荐节奏**：普攻 0.6–0.8s，单体法术 1.0–1.3s，AOE 1.5–2.0s，单回合总时长 15–25s。

---

## 7. 测试与调试框架

### 7.1 确定性铁律

1. 逻辑层所有随机只来自注入的 `BattleRng`；表现层装饰随机使用独立 `VisualRng`
2. 逻辑层不读系统时间、帧率、节点遍历顺序；Dictionary/Set 输出前排序
3. 逻辑层禁止 `await` / Tween / Node 访问
4. 单位、技能、状态使用稳定字符串 ID；事件带自增 `seq`
5. 录像记录引擎版本 + 内容 hash + 种子；跨版本回放给出明确告警

### 7.2 录像格式（JSON，人可读）

```json
{
  "replay_version": 1,
  "meta": {
    "battle_id": "enc_bamboo_01",
    "content_hash": "sha256:...",
    "engine": "4.6.stable",
    "seed": 123456789,
    "created_at": "2026-10-24T20:00:00+08:00",
    "build": "debug"
  },
  "rounds": [
    {
      "round": 1,
      "intents": [
        {"actor_id": "hero_swordsman", "kind": "skill", "skill_id": "sweep", "target_ids": ["mob_a"]},
        {"actor_id": "hero_mage", "kind": "attack", "target_ids": ["boss_fox"]},
        {"actor_id": "hero_healer", "kind": "defend", "target_ids": []}
      ],
      "debug_ops": []
    }
  ],
  "events": [
    {"seq": 1, "round": 1, "type": "damage", "source_id": "hero_swordsman", "target_ids": ["mob_a"], "data": {"amount": 96, "crit": false, "hp_before": 380, "hp_after": 284}}
  ],
  "digests": [{"round": 1, "sha256": "..."}],
  "snapshots": [{"round": 1, "units": [{"id": "hero_swordsman", "hp": 620, "mp": 80, "statuses": []}]}],
  "result": {"outcome": "victory", "rounds": 4, "digest": "sha256:..."}
}
```

关键规则：

- `rounds[].intents` **只记录玩家指令**；敌方 AI 指令不录，重放时由同一种子重新生成，确保 AI 的 bug 可复现。
- `debug_ops` 记录 `kill` / `set_hp` / `add_status` 等调试操作，仅允许发生在指令阶段，重放时按相同回合重放。
- 摘要 = 对该回合事件数组做规范化 JSON（键排序）后取 SHA-256，并与上一回合摘要一起哈希成链；摘要计算不依赖平台换行与字典顺序。
- `content_hash` = 遭遇战引用到的单位/技能/状态/物品/遭遇战资源按 ID 排序后的规范化序列化哈希；内容变更会被检测到。
- `snapshots` 默认在 debug 构建开启，便于直接查看异常现场与交叉验证重放。
- 录像文件写入 `user://replays/`，文件名含遭遇战 ID 与自增序号；不自动上传。控制台同时打印宿主机绝对路径。

### 7.3 调试接口

| 能力 | 接口 / 快捷键 |
|---|---|
| 随时 dump 录像 | `BattleDebug.dump_replay()`；debug 构建同时保存当前截图 |
| 回放 | `BattleDebug.replay(path, {verify=true, speed=1.0, step=false})` |
| 校验回放 | `godot --headless --path godot-battle -s tools/replay.gd -- --file <path> --verify` |
| 分歧定位 | 逐事件对比摘要，报告第一个不一致点（round/seq/源/目标/期望/实际）+ 前后 5 条事件 |
| 不变量检查 | 每次事件后校验 HP/MP 范围、死者不可行动、状态重复、行动次数等；违反即自动 dump 并停止战斗 |
| 随机 fuzz | `BattleDebug.fuzz(count)`：随机种子 + 随机指令，断言失败自动存录像 |
| 控制台 | F1：`dump` / `replay` / `seed` / `state` / `step` / `timescale` / `kill` / `set_hp` / `add_status` / `validate` |
| 调试浮层 | F3：当前事件、命令队列、双方状态、RNG 调用次数、回合/种子 |
| 单步播放 | F6 暂停 / F7 单步执行下一条命令 |

调试能力只在 `OS.is_debug_build()` 为真时启用；release 构建不挂载控制台、不接受调试指令。

### 7.4 测试套件

运行方式（不依赖第三方插件）：

```
godot --headless --path godot-battle -s tests/run_tests.gd
```

| 类型 | 内容 |
|---|---|
| 逻辑单测 | 速度排序与抖动范围、物理/法术/治疗公式、暴击、防御减伤、死亡跳过、封印命中/抵抗/消耗、中毒跳数与到期、AOE 选目标、MP 不足降级、逃跑概率边界、全灭判胜负、30 回合上限 |
| 确定性测试 | 同种子 + 同指令跑两次，事件流与最终摘要必须完全一致 |
| 黄金回放 | `tests/golden/` 存放录像 + 期望摘要；重放后摘要不一致即失败 |
| 表现冒烟 | headless 加载战斗场景，以 skip 模式跑完整局，断言零报错 |
| Fuzz | 随机跑 50 局，任意不变量违反即失败并保留录像 |

测试运行器自写：`tests/run_tests.gd` 继承 `SceneTree`，自动发现 `tests/cases/*.gd`，提供 `TestContext` 断言方法，失败以非零退出码结束。

### 7.5 缺陷修复工作流

1. 出现异常 → F1 执行 `dump`（不变量违反时自动 dump）
2. `godot --headless ... -s tools/replay.gd -- --file <path> --verify` 复现
3. 工具报告第一个分歧事件与上下文 → 定位根因
4. 修复代码
5. 重放同一录像 → 摘要一致（或差异符合预期）即确认修复
6. 将该录像加入 `tests/golden/`，转正为回归用例

---

## 8. 素材策略

- **占位阶段**：Kenney UI Pack、OpenGameArt 的 CC0 背景/音效；网络不可用时自动降级为程序化渐变背景 + 剪影 + 内置几何 UI，保证开发不被阻塞。
- **MVP 成品**：使用 `org-game-art`（Seedream）生成原创 Q 版素材：3 名我方 + 4 名敌方立绘、1 张战斗背景、BUFF 图标、UI 皮肤纹理。统一规格：透明 PNG、1024×1024、3/4 正面、脚底对齐、同一色板。
- **替换方式**：只改 `UnitData` / 场景中的贴图路径，逻辑与表现命令不变。
- **降级方案**：若 AI 出图不可用，使用免费素材 + 统一调色/描边后处理 + 雾气光效，保证观感不拉胯。
- **版权**：不使用网易《梦幻西游》任何原版素材；`assets/CREDITS.md` 登记所有素材来源与许可证。

---

## 9. 错误处理与降级

| 场景 | 处理 |
|---|---|
| 意图非法（目标死亡/MP 不足/物品用尽） | 降级为防御，产生 `intent_rejected` 事件并写日志 |
| 某方全灭 | 中断剩余行动，产生 `battle_end` |
| 超过 30 回合 | 判负，产生 `battle_end` |
| 未知事件类型 | debug 下 warning，跳过播放，流程继续 |
| 命令缺少对应表现 | 使用通用命令（飘字 + 等待），写 warning |
| 素材缺失 | 使用纯色占位/剪影 + 屏幕上可见的 warning，不崩溃 |
| 音频缺失 | 静默，不报错 |
| 录像损坏/版本不符 | 回放工具给出明确错误并退出，不进入战斗 |
| 内容 hash 不一致 | 默认告警继续；`--strict-content` 时终止 |
| 不变量违反 | debug：自动 dump + 停止战斗并显示错误浮层；release：记录日志并尝试恢复到安全状态 |

---

## 10. 里程碑

| 里程碑 | 交付物 | 验收 |
|---|---|---|
| M1 骨架与确定性核心 | 工程、战斗场景、单位视图、基础指令 UI、纯逻辑普攻、事件流、Sequencer、录像/回放骨架、headless 测试运行器 | 3v4 可普攻打完一局；dump 后 headless 重放摘要一致 |
| M2 完整规则 | 技能、BUFF、道具、防御、逃跑、AI、胜负、`.tres` 内容 | 13 个技能与 5 个状态生效；逻辑单测通过；黄金回放 ≥3 个 |
| M3 表现与调试打磨 | VFX、镜头、飘字、血条缓动、日志、顺序条、气泡、对白、结算、音频、倍速/跳过、控制台/浮层/单步 | 手动清单通过；表现冒烟测试零报错；单回合 15–25s |
| M4 美术替换 | AI 原创 Q 版立绘、背景、图标、UI 皮肤 | 占位到成品的替换只改资源路径；1080p 可读性检查 |
| M5 验收与文档 | 全量测试、fuzz 50 局、`README.md`、`docs/DEBUGGING.md`、`docs/EXTENDING.md`、`docs/PROGRESS.md`、`docs/TECH_NOTES.md` | 一条命令跑通全部测试；文档可让新人复现录像并定位问题；过程文档完整可复盘 |

---

## 11. 验收标准

1. 在 Godot 4.6 中可启动，完成一场 3v4 战斗，支持胜利、失败、逃跑三种结局。
2. 指令阶段、速度排序、技能/BUFF/道具/防御/逃跑全部可用；数值与本文一致。
3. `BattleDebug.dump_replay()` 可在任意时刻生成录像；headless 重放可复现相同事件摘要；debug 构建内可在游戏内以无 UI 模式播放录像。
4. 回放校验能报告第一个分歧事件及上下文；不变量违反自动 dump。
5. `godot --headless --path godot-battle -s tests/run_tests.gd` 退出码为 0；逻辑单测、确定性测试、≥3 个黄金回放、表现冒烟、50 局 fuzz 全部通过。
6. 1080p 下 UI 可读，特效不遮挡指令面板；1x/2x/跳过本回合均正确。
7. 素材不包含侵权内容；`CREDITS.md` 完整登记来源与许可证。
8. `README.md` 说明运行方式；`DEBUGGING.md` 覆盖录像→复现→修复→回归流程；`EXTENDING.md` 覆盖加技能/BUFF/命令/剧情钩子的步骤。
9. `PROGRESS.md` 每个里程碑至少一条记录，所有缺陷记录包含现象、根因、解决方案与验证证据；`TECH_NOTES.md` 覆盖架构、确定性、回放格式与 Godot 实践要点；M5 结束时产出一份复盘总结。

---

## 12. 过程沉淀与复盘

每轮迭代（至少每个里程碑）必须更新文档并随代码提交，作为验收的一部分。

### 12.1 `PROGRESS.md` — 迭代推进日志

每个条目固定结构：

- 日期 / 里程碑 / 本轮目标
- 完成内容（对应 commit）
- 技术决策：背景、备选方案、选择理由、影响面
- 问题记录：现象 → 根因 → 解决方案 → 验证证据（测试命令、录像文件、golden 用例）
- 测试与验证：执行的命令、通过数量、耗时
- 风险与遗留：未解决项、下一步

### 12.2 `TECH_NOTES.md` — 技术方案说明

- 架构图（Mermaid）、事件流与命令队列原理
- 确定性设计、录像/回放格式、摘要链、内容 hash
- Godot 4.6 实践要点与坑（headless 脚本、async 命令、`time_scale`、资源加载、视口截图）
- 性能与体积数据、手感调参记录（顿帧、屏震、动画时长）
- 新增方案的模板：背景 / 备选方案 / 取舍 / 结论 / 验证方式

### 12.3 记录纪律

- 每个缺陷修复至少一条问题记录；有复现录像的附路径，并转正为 `tests/golden/`
- 每次提交前确认 `PROGRESS.md` 已更新（里程碑推进或缺陷修复）
- 只写事实与证据，不写“应该没问题”；测试失败必须原样保留输出
- 不复述代码，重点记录“为什么这样做”和踩过的坑

---

## 13. 风险与对策

| 风险 | 对策 |
|---|---|
| 免费素材风格不统一，观感差 | 占位仅内测；MVP 用统一 AI 画风替换；降级方案保证最低观感 |
| AI 立绘一致性不足 | 固定色板、统一提示词与参考图；单张立绘 + 程序化动画降低一致性要求 |
| 弱网导致素材下载失败 | 程序化占位兜底；素材生成与开发并行，不阻塞核心 |
| Godot headless 脚本行为差异 | M1 第一天验证 `-s` 运行方式与退出码 |
| 浮点/引擎版本造成回放漂移 | 记录引擎版本与内容 hash；逻辑层不使用物理与系统时间；同平台回归 |
| 扩展导致表现层膨胀 | 命令注册表 + Context 隔离；新功能仅新增命令/资源 |
| 范围蔓延 | 非目标清单 + 里程碑卡点 |

---

## 14. 附录：扩展操作清单

**新增一个技能**

1. 在 `data/skills/` 新建 `SkillData` .tres（ID、名称、MP、目标类型、倍率、效果数组、表现配置、喊招台词）
2. 在对应 `UnitData.skills` 中追加
3. 若使用已有特效/飘字/动作，无需改代码；新表现则新增 VFX 场景并配置

**新增一个 BUFF**

1. 新建 `StatusData` .tres（持续时间、面板修正、回合开始效果、图标、视觉配置）
2. 若效果是新的结算方式，在 `BattleResolver` 中新增一个结算分支与事件类型
3. 注册该事件的表现工厂（或走通用状态飘字/图标）

**新增一段剧情/对话/弹框**

1. 在遭遇战的 `EncounterScript` 中配置触发点（`battle_start` / `round_start` / `after_event` / `unit_died` / `battle_end`）
2. 填写台词/气泡/弹框内容；需要特殊运镜时新增一个 `BattleCommand`
3. 不需要改动战斗流程代码

**新增一种流程节点**

1. 继承 `BattleCommand`，实现 `play(ctx)` / `skip(ctx)`
2. 在 `command_registry.gd` 注册类型
3. 由 Director 或 EncounterScript 插入队列

**新增回归用例**

1. 用调试控制台或测试构造一次战斗，dump 录像
2. 放入 `tests/golden/` 并记录期望摘要
3. 测试运行器自动纳入
