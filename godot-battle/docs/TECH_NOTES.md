# 技术方案与踩坑记录

## 1. 分层与边界

- `core/` 只做战斗结算，禁止 Node/Tween/await/系统时间/全局随机（录像元数据的时间戳除外）。
- `data/` 是内容：单位、技能、状态、道具、遭遇战。`ContentDB` 递归加载 `.tres`，内容 hash 只覆盖这里。
- `battle/` 是表现层的战场、Session、Director、Sequencer、命令、视图、VFX 与调试单例。
- `ui/` 是 HUD、目标选择、日志、对白、气泡、结算和调试 UI；工具脚本在 `tools/`。
- 每回合一次性结算，产生有序 `BattleEvent`；表现层只消费事件和只读快照，不写回战斗数据。
- 表现层不改变随机性：战斗随机只来自 `BattleEngine.rng`，装饰随机使用独立的 `BattleContext.visual_rng`（seed=9001）。因此 VFX 频率/粒子数量不影响录像。

## 2. 确定性内核与回放

### 结算与随机

- `BattleEngine.resolve_round()`：记录回合开始快照/意图 → `BattleResolver` 按速度顺序执行 → 记录完整事件 → 检查不变量 → 战斗结束时定稿录像。
- 速度 = 基础速度 × [0.95, 1.05]；同速按单位 ID 字典序。Dictionary 输出前排序，JSON 摘要用 `sort_keys=true`。
- 所有随机（速度骰、伤害浮动、暴击、AI 选择、状态命中）按固定顺序从注入种子的 `BattleRng` 取数。
- 单位/技能/状态等资源是共享的；测试中只修改 `BattleUnitState`，不要改真实资源。

### 录像格式

- `replay_version` 当前为 1，校验严格比对。
- `meta`：`battle_id`、`content_hash`、`engine`、`seed`、`created_at`、`build`。`engine` 只作元数据，`BattleReplay.verify` 不比对；行为变化靠事件/摘要暴露。
- `rounds[]` 只记录玩家意图；AI 由同种子重建后再次决策。`resolved=false` 表示该回合未结算，回放跳过。
- 逃跑记为 `actor_id="party"` 的 `FLEE` 意图；`kill/set_hp/add_status` 记在 `debug_ops[]`，在对应回合的意图重演前应用。
- `events[]` 是完整有序事件流，`seq` 全局递增；每回合摘要链（上回合摘要 + 规范化事件 JSON）写入 `digests[]`。
- `snapshots[]` 记录每回合开始的 HP/MP/alive/状态/道具使用；参与当前回放校验（见第 7 节）。
- `result`：`outcome`、`rounds`、最后一个摘要；校验时同时比较结局、回合数和摘要。

### JSON 数字与规范化

- Godot 的 JSON 解析把所有数字变成 float，即使录像里写的是整数。内存中的 int 与 JSON float 直接比较/拼接会造成假失败。
- 统一走 `BattleDigest.canonical_json()`：把整值 float 归一化为 int，按 key 排序后再计算 SHA-256 和比较事件。
- 黄金回放文件的字节不稳定（`created_at` 每次生成都会变）；确定性依据是 `digests[]` 与事件重演，不是原始 JSON diff。

### 黄金回放与 fuzz

- `tools/make_golden.gd` 生成三份固定策略/种子的 12 回合过程回放：attack（1001）、aoe（1002）、control（1003）。三份当前 `outcome=0`，是“意图 → 事件链”锁定，不覆盖结局。
- `test_golden.gd` 对三份文件做严格内容 hash + 摘要链 + 逐事件重演校验；CLI 也可单独运行。
- fuzz 在 `test_fuzz.gd`：50 局固定种子（引擎 5000–5049，选择 RNG 9000–9049），每回合查不变量，30 回合上限保证终止；当前 634 个断言。
- 修改 `data/**/*.tres` 必然改变内容 hash，需重建黄金；修改核心规则即使 hash 不变，也可能改变事件流，同样需要重建/验证黄金。

## 3. 表现层架构

### 场景与对象图

`BattleScene` 在 `_ready()` 中构建：

```text
BattleScene (Node2D)
├── Background (程序化绘制，可选贴图覆盖)
├── CameraRig
├── World (Node2D)
│   ├── UnitView × 7
│   └── VFXLayer
├── BattleSession
├── BattleSequencer
├── AudioDirector
└── UILayer (CanvasLayer)
    ├── BattleHUD
    ├── Bubble
    ├── DialogueBox
    ├── VictoryPanel
    └── DebugConsole / DebugOverlay（BattleDebug autoload 动态创建）
```

`BattleContext` 是表现层轻量对象，持有 `scene_tree/scene/session/sequencer/camera/vfx_layer/hud/audio/dialogue/bubble/victory_panel/ui_layer/unit_views`，并提供 `wait()`、`is_skipping()`、`apply_snapshot()`、`vfx_factory()`。

### 事件 → 命令 → 播放

1. `BattleSession` 收集意图，调用 `engine.resolve_round(intents)` 得到 `BattleEvent[]`。
2. `BattleDirector.build(events)` 把事件翻译成 `BattleCommand[]`，顺带插入剧情 beat 和技能喊招气泡。
3. `BattleSequencer.enqueue()` 入队，`await sequencer.play_all()` 顺序播放。
4. 播放结束后 `context.apply_snapshot(engine.state)` 让所有视图与真实状态对齐，进入下一回合或结算。

`BattleCommand` 只有 `play(ctx)`/`skip(ctx)`；事件命令由 `CommandRegistry` 映射，未知事件回落到 `SimpleEventCommand`。表现层只能读事件/选择视图节点，不能写 `BattleState`（调试操作是明确例外，且由 recorder 记账）。

### 表现命令

- `RoundBannerCommand`：回合横幅 + 回合开始日志；HUD 存在时顺手刷新出手顺序。
- `ActionStartCommand`：日志、音效、攻击预备→突进、施法蓄力→闪光/法环、镜头轻推；`fire`/`seal`/`heal` 技能先播放 `VFXFactory.projectile()` 弹道（0.24~0.30s，发光球+拖尾）再交给命中命令；技能喊招由 Director 额外插入 `BubbleCommand`。
- `DamageCommand`：扣血前的高光/目标抖动、56px 伤害数字（暴击 76px）、7px 镜头震动（暴击 10px + 更强 punch-zoom）、暴击闪屏、0.12s 真实顿帧；攻击者用 `return_pose()` 收势归位；`status_tick` 使用毒特效与紫色数字。
- `HealCommand` / `StatusCommand` / `DeathCommand`：治疗/状态/死亡各自的视觉反馈。
- `BattleEndCommand`：结局音效、显示结算面板、短等待。
- `DialogueCommand`：经 DialogueBox 播放对白；`skip()` 直接隐藏。

## 4. 播放控制：倍速、跳过、顿帧、单步

### 倍速

- `BattleSequencer.playback_speed` 只改变**播放节奏**；`BattleContext.wait(sec)` 实际等待 `sec / playback_speed`。
- 对白框的 `clock_scale` 在对话期间跟随 `playback_speed`，因此 2x 时自动推进和打字机也加速。
- HUD 的倍速按钮在 `1x`/`2x` 之间切换；F1 `timescale <n>` 设置同一个 `playback_speed`，特意**不**同时改 `Engine.time_scale`，否则会和 `ctx.wait` 形成双重加速。

### 跳过本回合

- `BattleSequencer.skip_all()`：先复位 `Engine.time_scale`，隐藏对白/气泡；若正在播放，`generation += 1` 使旧循环失效，清空队列，设置 `_skip=true`、`playback_speed=1000`。
- 当前命令通过 `await ctx.wait()` 快速返回；循环发现 generation 改变后退出，恢复视图：应用当前引擎快照、存活单位复位姿态、死亡单位停止动画；最后 `_skip=false`、`playback_speed=1.0`、`idle`。
- 如果没有在播放，直接恢复视图。HUD 跳过按钮在指令收集阶段禁用，只有播放中可用。
- 跳过并不“暂停或快进逻辑”：逻辑回合在播放前已经结算完成，跳过只省略演出；因此必须用 `apply_snapshot` 把视图拉到真实状态。

### 真顿帧

- `DamageCommand` 在伤害数字之前把 `Engine.time_scale` 设为 `0.05`，用 `SceneTree.create_timer(HIT_STOP, true, false, true)`（`ignore_time_scale=true`）冻结真实的 0.12 秒，再恢复 `1.0`。
- 跳过中不触发顿帧；`BattleScene._exit_tree()` 和 sequencer 的跳过收尾都会把 `Engine.time_scale` 复位，避免退出后全局时间残留。
- 镜头震动/缩放和闪屏是表现层效果，与逻辑无关；headless 下 VFX 直接跳过。

### 单步

- `F6` 切换 `sequencer.set_step_mode`；`F7` 调用 `request_step()`，未开单步会自动开启。
- `play_all()` 在每个命令前等待 `_step_requested`；关闭单步并调用 `request_step()` 可以释放等待。回放模式同样可用，方便逐事件看快照/浮层。

## 5. HUD 指令流

- `BattleHUD.collect_intents()` 为每个存活我方依次显示根菜单，返回 `Array[BattleIntent]`；根菜单包含攻击、法术、道具、防御，另有独立的全队“逃跑”按钮。
- 攻击/单体法术进入 `TARGET` 模式；敌方目标用鼠标或 `1`–`4`，我方目标用鼠标或 `Q/W/E`；`ESC`/返回退回上一菜单，根菜单可回退到上一名角色。
- 防御立即提交；逃跑清空已下达的意图，只保留 `actor_id="party"` 的 FLEE 意图。
- 每名角色有 25 秒倒计时；超时后当前及剩余我方使用 `_auto_intent()`（攻击随机存活敌方），不会再等输入。
- 只有 `BattleIntent` 会被交给 Session/Engine；HUD 不改 HP/MP。事件播放时 HUD 从 `BattleEvent` 写日志、刷新顺序条，播放结束再由 `apply_snapshot` 同步 HP/MP/状态。
- 点击拾取依赖 `get_viewport().physics_object_picking = true`，单位用 `Area2D`。真实输入探针会检查命中矩形不重叠、不压 HUD/信息带，并检查法师法球、妖将拳头/斧头、狐妖尾尖、妖兵乙毒矛等附属件。
- `F1` 调试控制台/`F3` 浮层由 `BattleDebug` 在 debug 构建创建，层级高于 HUD；控制台打开时会拿到输入焦点。

## 6. 剧情与音频

### 剧情

- `EncounterData.script_data` 指向 `EncounterScript`；后者有 `intro_lines`、`first_kill_lines`、`victory_lines`、`defeat_lines` 以及 `reset()`。
- 开场 beat 在 `BattleSession._run_battle()` 的战斗循环前播放；`BattleDirector` 在 `battle_end` 事件前插入结局 beat，在敌方 `death` 事件后插入首杀 beat（只在首次且由敌方死亡触发，己方阵亡不会消耗首杀）。
- `BattleHUD.play_beat()` 负责把对白写入日志并调用 `DialogueBox.play_lines()`；无 HUD 或无对白框时退化为日志 + 等待。
- `DialogueBox`：电影黑边、逐字显示（30 cps）、点击/空格/Enter 跳过打字并推进、自动推进（默认 1.25s）；全屏控制层本身不吞输入，只有对白面板接收点击，避免挡住播放控件。
- `skip_story` 在工具/回放/自动冒烟中跳过全部剧情；`BattleSession` 和 `BattleDirector` 使用同一个标志。

### 音频

- `AudioDirector` 用程序化合成生成 9 个短音效流（hit/slash/cast/heal/status/death/victory/defeat/click），不依赖外部音频。
- headless 下完全静音但仍生成流，探针可检查 `stream_names()`；BGM 仅在 `encounter.bgm_path` 可加载时播放，当前遭遇战未配置。
- 没有全局静音 UI；音频属于表现层，不影响战斗与回放。

## 7. 调试、回放与快照校验

### BattleDebug

- `project.godot` 注册 autoload `BattleDebug="*res://battle/debug/battle_debug.gd"`；`BattleSession._prepare()` 注册当前 session。
- 仅 `OS.is_debug_build()` 启用；无 session 时惰性，不创建 UI，因此核心测试不受影响。
- `dump_replay()` 调用 engine dump；非 headless 会把当前窗口视口截图保存到录像同目录（实际窗口尺寸可能小于 1920×1080），headless 打印跳过。
- `replay(path)` 先 `BattleReplay.verify(..., false)`，失败打印 `REPLAY_FAIL` 和首个分歧 JSON；成功后设置 `pending_replay_path` 并 `reload_current_scene()`。release 禁用。
- F1 控制台的 `kill/set_hp/add_status` 统一走 `BattleEngine.apply_debug_op`，会自动记入录像；`state`/`validate` 只读检查。

### 游戏内回放

- `BattleSession.start()` 优先消费 `BattleDebug.pending_replay_path`；从录像 `meta` 读取 battle_id/seed，重建引擎（`record=false`）、`UnitView`，`skip_story=true`，隐藏 HUD，显示“回放模式”标签。
- 按 round 顺序：应用该轮 `debug_ops` → 跳过 `resolved=false` → 重演玩家意图 → `resolve_round` → Director 播放 → `apply_snapshot`。结束时显示结果面板并打印 `REPLAY_OK ... rounds=N outcome=M`。
- 回放中可 F1/F3/F6/F7、`timescale`、`skip`；ESC 重新加载场景退出回放。

### 快照校验

- `BattleRecorder` 在每回合开始记录快照（`hp/mp/alive/statuses[id+remaining]/item_uses/unit set`）。
- `BattleReplay.verify` 按回合重演：先应用 debug_ops，再把 engine 当前状态与该回合录像快照比较；比较通过才重演意图并逐事件比对。
- 不一致时 `first_divergence.reason = "snapshot_mismatch"`，含 `round/unit_id/field/expected/produced`；`resolved=false` 的轮次不比较；没有 `snapshots[]` 的旧录像保持兼容。
- 事件不一致使用 `event_mismatch`/`event_count`；摘要链错误单独报告。CLI 把首个分歧以 `REPLAY_DIVERGENCE` JSON 打印。

### 内容 hash 与严格校验

- `ContentDB.content_hash()` 递归收集 `res://data/**/*.tres`，按完整路径排序，对路径和文件全文做 SHA-256。美术 `assets/`、脚本和文档不参与。
- 当前黄金 hash：`sha256:4381648dff17081e3d1bdd6ace73753fcc0bffc562ee03e4f24e1b6e0ef25975`（28 个 `.tres`）。
- `--strict-content` 把 content hash 不一致当 error；非严格模式只给 warning。改数据后要重建黄金，否则严格校验失败。
- 仅改核心脚本不会改变 content hash，但事件流可能变化，仍可能让黄金回放失败；修复规则后必须重建/验证黄金。
- `res://` 只在源码运行时可写；导出 PCK 只读，黄金生成/调试写盘工具仅用于开发期。

## 8. 视觉目录与程序化美术

- 所有角色、背景、HUD、对白、结算和徽章均可用 GDScript 绘制原语实时生成；程序化美术是默认路径和兜底。
- `VisualCatalog` 读取 `res://assets/visuals/visual_catalog.json`（缺失/非法 JSON 时返回空字典），支持：
  - `units[id].sprite/scale/offset`：角色立绘，底边对齐脚底；
  - `background.path/scale/modulate`：1920×1080 背景；
  - `status_icons[id]`、`command_icons[id]`：状态/指令图标。
- 纹理加载先走 `ResourceLoader`，未导入但文件存在时用 `Image.load_from_file`；静态缓存纹理。路径缺失/损坏时 `UnitView`/`BackgroundView` 自动回退程序化绘制。
- 角色立绘推荐目标高度 300px，`scale = 300 / 图片像素高度`；`offset` 以脚底为原点，向上为负 y。背景覆盖时仍绘制光柱、地面光斑、地面薄雾、暗角、雾带与飘叶，避免替换后氛围消失。
- 程序化角色使用 `UnitView` 内的 `draw_set_transform` 做 `_art_scale` 缩放；UI、信息条和 130×(320 或 173×320) 点击区不受绘制缩放影响。`appendage_points()` 暴露附属件局部坐标，HUD 探针会做“自身命中区内 + 邻居命中区外”的检查。
- `VisualCatalog` 资源放在 `assets/`，不改变内容 hash；若改 `UnitData.sprite_path` 等数据字段，则会改变 hash。
- Seedream/方舟通道在本机 403 + SSO 失效，因此没有 AI 位图；AI 接入步骤和 CREDITS 在 `assets/art/`。

## 9. Godot 踩坑

- **JSON 数字全变 float**：任何事件/摘要比较都要先过 `BattleDigest.canonical_json`，否则整值 int/float 会造成假失败。
- **`script` 字段冲突**：`EncounterData` 不能把导出字段命名为 `script`（与 `Object.script` 冲突），当前为 `script_data`。改名时同步 `.tres` 和所有读取代码。
- **autoload 与 debug 构建**：`BattleDebug` autoload 在所有运行中存在，但 UI/热键用 `OS.is_debug_build()` 禁用；核心测试没有 session 时必须保持惰性。
- **强制退出告警**：冒烟/截图工具在 tween、静态字体和资源缓存仍存活时 `quit(0)`，会打印 `ObjectDB instances leaked at exit` / `resources still in use at exit`；退出码仍为 0，当前不视为断言失败，但不是干净退出。
- **headless VFX**：`DisplayServer.get_name() == "headless"` 时 `VFXFactory` 跳过节点创建，但逻辑/等待仍正常；headless dump 不截图，避免无渲染后端报错。
- **截图窗口与 SubViewport**：macOS 实际窗口会被限制到 1440×762/1354×762；`--resolution 1920x1080` 不能保证真实窗口大小。截图工具使用独立 1920×1080 `SubViewport`；HUD 真实输入探针按逻辑画布坐标点击，并验证物理拾取。
- **点击区与附属件**：只比较单位点击矩形会漏掉法球、尾巴、斧头、长矛等视觉外溢；当前通过收拢附属件、调整槽位（妖将 x=540、妖兵乙命中区右扩）和点探针解决，最小命中区间隙 17px。
- **`Array[自定义类型].duplicate()`**：可能丢失类型；需要返回类型数组时用循环 append，或只在动态数组上下文使用 duplicate 结果。
- **资源是共享的**：测试不要修改真实 `UnitData`/`SkillData`；只改 `BattleUnitState`。状态/数据修改需要重建黄金。
- **首次导入**：`godot -s` 之前若没有 `.godot/global_script_class_cache.cfg`，`class_name` 可能未注册；`run_tests.sh` 已内置一次 `--editor --quit` 导入，手动跑工具前同样要注意。
- **门禁拒绝 `ERROR:`**：不变量违规用 `push_error` 上报，`run_tests.sh` 会因 `ERROR:` 失败；测试门禁还会拒绝 `SCRIPT ERROR`、解析失败、超时和缺失 `RESULT` 行。
- **中文字体**：使用系统字体回退（PingFang SC、Hiragino Sans GB、Noto Sans CJK SC、Microsoft YaHei、Arial Unicode MS），不随项目分发字体；跨平台验收要确认 CJK 字体存在。
- **物理拾取**：UnitView 点击用 `Area2D`，必须在场景中启用 `get_viewport().physics_object_picking = true`；否则真实鼠标 HUD 探针会出现“点了没反应”。
- **窗口关闭与场景重载**：F1 replay 成功后通过 `reload_current_scene()` 进入回放；当前 scene 不存在时保留 pending 路径，等待下一次 `BattleSession.start()` 消费。
- **AI 生图被阻断**：Seedream 403 AccessDenied、模型未开放、SSO 刷新失败；没有生成图，也没有版权素材。恢复流程是重新 SSO → 创建可用接入点 → 生成透明 PNG → 更新 `visual_catalog.json` → 用 1920×1080 截图复核。

## 10. 工作流与验收原则

1. 先写失败测试/最小复现，再改实现。
2. headless 核心门禁全绿，再补表现层冒烟、真实 HUD 输入、故事/调试探针。
3. 出问题：dump → CLI replay 看首个分歧 → 修复 → 摘要/快照一致 → 视内容/行为变化重建黄金 → 重投影截图。
4. 表现层改动必须尊重跳过/倍速/单步/headless 路径，且不得改变内容 hash；数据/核心行为变化必须重新生成黄金。
5. 每个里程碑同步 `PROGRESS.md` 和本文件；最终验收的手动清单由用户执行并签字，自动探针不冒充真人验收。

## 11. 2.5D 俯视阵型

- **槽位**：`battle/battle_field_layout.gd` 以 `side + slot` 返回 `row/pos/depth/art_flip/view`；默认 3v4 为 FWJ 式紧凑菱形/箭头：每侧唯一 `row=1` 尖端（我方剑客 (1000,800)、敌方妖将 (850,700)），其余 `row=0` 在后方展开。换阵型只改表。
- **深度**：`world.y_sort_enabled = true` 让前排绘制在后排之上；`UnitView.apply_formation(depth, facing, view)` 只把 `depth`/`facing`/`view` 应用到美术层，名字/血条/命中区保持屏幕尺寸与正向。
- **点击**：命中区为 96×208 的身体框。紧凑阵型下命中区/信息带**允许重叠**（参考作亦然），不再要求 x 区间间隔；目标选择由三层保证：① HUD「目标键位」+ `1`–`4` / `Q`/`W`/`E`；② 单一金色目标箭头，默认落在尖端并跟随鼠标悬停；③ 点击可见尖端。`test_formation` 断言尖端中心点击点不被其他命中区抢走，`HUD_INPUT` 逐一验证每个键位与尖端点击。
- **附属件**：法球/尾巴/斧/矛可能伸出自身命中区；`appendage_points()` 仍保留为美术信息，但紧凑阵型中不再做“不得进入邻居命中区”的断言（邻居本身允许重叠）。改阵型/美术先跑 `test_formation` + `HUD_INPUT`。
- **地面**：`BackgroundView` 用确定性程序纹理 + 绘制原语生成竹林林间空地：远缘由插值曲线/噪声扰动/草须与薄雾软收，自敌侧 y≈480 铺到近景；远侧雾草 → 中央受光泥地/苔藓 → 近景深草，叠加踩踏土径、竹桩/竹根、落石、落叶、小花、竹影与半埋石环。中央石环圆心 (925,750)，正好是双方尖端连线中点；用两条很淡的椭圆线 + 44 颗断续石块保证在两尖端之间可读。没有矩形石台、描金边或均匀网格；单位脚底与空地透视一致。
- **背景光照**：左上敌侧后方暖光斑 + 中央暖阳 + 右上光柱；暗角最大 alpha 0.08；程序纹理的 sky/ground 色板以无 HUD 全场景平均亮度 ≥135、饱和度 ≥35% 校准（对应独立美术评审 P0-1）。换背景贴图时仍保留光柱/地面光斑/薄雾/暗角叠加。
- **坑**：仅翻转美术层，不要 scale 整个 Node（会镜像文字/血条并把点击区缩放）；Y 排序只影响绘制，不改变 Area2D 拾取优先级；紧凑阵型的视觉/命中区重叠是有意设计，稳定选择必须靠单一箭头 + 数字键，不能再把“命中区互不相交”当验收条件。

### 11.1 方向造型（我方背影/敌方正面）

- `slot.view`：我方 `back`、敌方 `front`；`facing` 控制左右。只作用于美术层，名字/血条/状态/命中区保持正向。
- 程序化背影：在正面绘制后叠加后脑发团/后发/发髻、袍背面板、背带/背结，遮住脸和正面交领；武器保持在侧后方；剑客发带、法师长发、医师发髻分别处理。
- `VisualCatalog.unit_entry` 支持 `sprites.front/back`；有贴图优先用当前 view，缺失回退程序化。未来 AI 立绘只需补两方向图。
- 缩放：`BASE_ART_SCALE≈0.75` 叠加 formation depth（敌方 0.86–0.94 / 我方 0.98–1.10）；美术变换缩放，UI/命中区保持屏幕常量；改缩放必须重跑 HUD 输入探针并检查血条不悬空。
- 当前限制：程序化背影是正视/背视，不是真正 45° 3/4；如果要更贴近梦幻，需要 AI 或手绘的 3/4 背面立绘，并沿 VisualCatalog 替换。
- **中心线**：只把两军分成左右两簇、中心同高，会退化成“横排排队”。正确做法是敌方中心左上、我方中心右下，中心连线约 20–45°；尖端沿轴相向，后排法系在后方。当前中心 (1057,857)/(750,635)，约 36°；`test_formation` 会断言中心线与尖端关系。
- **地面范围**：敌方后排（狐妖 y≈580）必须落在空地远缘以内；`test_formation` 用 `BackgroundView._clearing_edge_y()` 校验所有敌方脚底仍有 8px 以上余量。
- **整队纵深**：我方 depth `0.98/1.10/1.06`、脚底 y `800/860/910`；敌方 depth `0.94/0.90/0.88/0.86`、y `700/640/620/580`。这样“镜头在我方背后”成立：我方更大更低、敌方更小更高；我方最小 depth 仍大于敌方最大。改深度要同步检查 HUD/信息条遮挡与 HUD 探针。
