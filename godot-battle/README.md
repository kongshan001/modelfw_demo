# 山海试炼 · Godot 2D 回合制战斗 Demo

3v4 回合制战斗 MVP：确定性战斗内核 + 可玩的表现层 + 录像回放/调试工具 + 原创程序化 Q 版美术兜底。

## 这是什么

- 我方 3 人（剑客·凌霄、法师·青鸾、医师·白术）对敌方 4 妖（妖兵·甲/乙、妖将·裂山、狐妖·媚娘），一局完整胜负。
- 指令阶段支持普攻、法术、道具、防御、全队逃跑；法术包含单体、AOE、治疗、净化与状态。
- 战斗内核确定性：所有战斗随机来自注入种子的 `BattleRng`；同一内容版本 + 同一意图 + 同一种子可重放出逐事件一致的结果。
- 表现层包括回合横幅、出手顺序、技能特效、飘字、受击顿帧、对白、喊招气泡、战斗日志、胜利/战败/逃跑结算与程序化音效。
- 调试工具包括 F1 控制台、F3 状态浮层、F6/F7 单步、录像 dump/replay、快照校验与黄金回放。
- 美术为项目内原创的程序化 Q 版绘制；没有使用第三方图片、字体或商业素材。AI 美术接入点已留在 `assets/visuals/visual_catalog.json`。

## 环境要求

- Godot **4.6 stable**（实测 `4.6.stable.official.89cea1439`）。
- macOS 或 PC；本项目在 macOS 上完成验收。
- 设计分辨率 **1920×1080**，窗口拉伸模式为 `canvas_items` + `keep`。
- 无第三方运行时依赖；首次运行需要 Godot 导入工程。

## 运行

从仓库根目录：

```bash
godot --path godot-battle
```

也可以直接在 Godot 4.6 中打开 `godot-battle/project.godot` 并按 F5。首次从源码运行若提示 `class_name` 未注册，先导入一次：

```bash
godot --headless --path godot-battle --editor --quit
```

主场景是 `scenes/battle_scene.tscn`，默认遭遇战为 `enc_bamboo_01`。

## 操作

| 操作 | 说明 |
| --- | --- |
| 鼠标 | 点击指令按钮（攻击/法术/道具/防御）、目标单位、返回、倍速、跳过本回合、逃跑。 |
| 数字键 `1`–`4` | 选择目标时，选择敌方第 1–4 个槽位。 |
| `Q` / `W` / `E` | 选择目标时，选择我方第 1–3 个槽位。 |
| `ESC` / 返回按钮 | 目标选择时返回；根指令时回退到上一名我方。 |
| 对白：鼠标点击 / `Space` / `Enter` | 跳过打字或推进下一行；不操作也会自动推进。 |
| 倍速按钮 | 在 `1x` / `2x` 之间切换，影响战斗播放速度。 |
| 跳过本回合 | 仅在事件播放期间可用；跳过当前回合剩余演出并同步到真实状态。 |
| `F1` | 打开/关闭调试控制台（仅 debug 构建）。 |
| `F3` | 打开/关闭调试浮层（仅 debug 构建）。 |
| `F6` | 切换单步模式（仅 debug 构建）。 |
| `F7` | 播放一个命令（未开单步时会自动开启）；回放模式同样可用。 |
| `ESC` | 控制台打开时先关控制台；回放模式下退出回放。 |

指令阶段共用一条 25 秒倒计时（从阶段开始计时，不是每名角色各自计时）；超时会自动为尚未下达指令的我方选择默认意图，已下达的指令保留。逃跑是独立的全队按钮，选择逃跑会丢弃已下达的指令。

## 测试与验收命令

以下命令均从仓库根目录执行，按顺序执行即是一条完整验收清单。

```bash
# 1. 核心门禁：自动导入 + 全量单元/集成/黄金/fuzz 测试
bash godot-battle/tools/run_tests.sh; echo "exit=$?"

# 2. 表现层自动战斗冒烟（headless；门禁同时校验引擎/脚本错误）
bash godot-battle/tools/smoke_gate.sh smoke_presentation.gd --headless; echo "exit=$?"

# 3. HUD 真实鼠标输入，完整 3v4 战斗到结算面板（需要窗口）
bash godot-battle/tools/smoke_gate.sh smoke_hud_input.gd --resolution 1920x1080; echo "exit=$?"

# 4. 对白与胜利面板剧情探针（headless）
bash godot-battle/tools/smoke_gate.sh probe_story.gd --headless; echo "exit=$?"

# 5. 调试工具冒烟：dump/verify/篡改快照/回放模式（headless）
bash godot-battle/tools/smoke_gate.sh smoke_debug.gd --headless; echo "exit=$?"

# 6. 黄金回放 CLI 严格校验
godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_attack.json --strict-content; echo "exit=$?"

# 7. 截图工具（需要窗口；输出 1920×1080）
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_art.gd; echo "exit=$?"
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_hud.gd; echo "exit=$?"
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_story.gd; echo "exit=$?"
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_debug.gd; echo "exit=$?"
```

聚焦调试单个探针时，可绕过门禁直接运行（不会因 `ERROR:` 行失败）：

```bash
godot --headless --path godot-battle -s tools/smoke_presentation.gd
godot --path godot-battle --resolution 1920x1080 -s tools/smoke_hud_input.gd
godot --headless --path godot-battle -s tools/probe_story.gd
godot --headless --path godot-battle -s tools/smoke_debug.gd
```

预期关键输出：

- `RESULT: 792 assertions, 0 failures`
- `PRESENTATION_SMOKE_OK`
- `HUD_INPUT_OK`
- `STORY_PROBE_OK`
- `DEBUG_SMOKE_OK`
- 四个烟测/探针各输出一行 `SMOKE_OK <script>` 且 `exit=0`
- `REPLAY_OK`
- 四个截图工具 exit 0，输出 `SCREENSHOT: <绝对路径>`。

截图写入 Godot 用户目录：

- macOS：`~/Library/Application Support/Godot/app_userdata/山海试炼/screenshots/`
- 程序内路径：`user://screenshots/`
- 调试 dump 的录像与视口截图写入 `user://replays/`。

当前验收的实际结果见 `docs/PROGRESS.md`。黄金回放位于 `tests/golden/`，内容变更后的重新生成命令见 `docs/EXTENDING.md`。

## 项目结构

```text
godot-battle/
├── project.godot              # Godot 4.6 配置、主场景、BattleDebug autoload
├── scenes/
│   └── battle_scene.tscn      # 主战斗场景入口
├── core/                      # 确定性战斗内核（无 Node/Tween/表现依赖）
│   ├── battle_engine.gd       # 记录意图 → 结算 → 事件 → 录像
│   ├── battle_resolver.gd     # 速度排序、技能/状态/道具/逃跑/AI
│   ├── battle_replay.gd       # 回放校验、摘要链、快照校验
│   ├── battle_recorder.gd     # 录像格式与落盘
│   └── data/                  # 数据资源脚本
├── data/                      # .tres 内容：7 单位、技能、状态、道具、遭遇战
├── battle/                    # 表现层
│   ├── battle_session.gd      # 指令循环 / 自动战斗 / 回放模式
│   ├── battle_director.gd     # BattleEvent → BattleCommand
│   ├── battle_sequencer.gd    # 命令队列、倍速、跳过、单步
│   ├── commands/              # 各事件的表现命令
│   ├── views/                 # UnitView / BackgroundView / CameraRig
│   ├── debug/                 # BattleDebug autoload
│   ├── vfx_factory.gd         # 程序化 2D 特效
│   └── visual_catalog.gd      # 可选美术覆盖目录
├── ui/                        # HUD、目标选择、日志、对白、气泡、结算、调试 UI
├── assets/
│   ├── visuals/visual_catalog.json  # AI/外部美术 drop-in schema（当前为空）
│   └── art/                   # 素材说明与 CREDITS
├── tools/                     # 冒烟、探针、回放 CLI、截图、黄金生成
├── tests/
│   ├── cases/                 # 核心测试用例（自动发现）
│   └── golden/                # 3 个黄金回放
└── docs/                      # README、调试、扩展、过程、技术文档
```

## 美术与素材状态

- 当前全部可视内容由 `battle/views/unit_view.gd`、`battle/views/background_view.gd`、`ui/*.gd` 使用 Godot 绘制原语实时生成：Q 版角色、竹林黎明背景、HUD/对白/结算样式、状态与指令徽章。
- Seedream / 方舟生图通道在本机被 **403 / SSO 失效**阻断，本版本没有生成或引入任何 AI 位图。
- `assets/visuals/visual_catalog.json` 已预留角色立绘、背景、状态图标、指令图标的 drop-in 接口；缺失或损坏时自动回退到程序化绘制。
- 未使用任何受版权保护的图片、字体或角色造型；字体走系统字体回退。来源说明见 `assets/art/CREDITS.md` 与 `assets/CREDITS.md`。
- 后续接入 AI 美术的规格、缩放换算和回退验证步骤见 `assets/art/README.md`。

## 战场站位（2.5D 俯视）

- 两排站位由 `battle/battle_field_layout.gd` 管理：后排约 0.90–0.92 倍、前排 1.05 倍，角色按脚底 Y 排序；只翻转美术层面向对方，名字/血条/命中区不翻转。
- 透视石台/地面网格由 `battle/views/background_view.gd` 绘制；前后排命中区在 x 方向留 ≥10px 间隔，避免抢点击；点击与数字键对前后排均可用。
- 默认 3v4 阵型可按遭遇战替换；新增单位/阵型时改 `BattleFieldLayout`，跑 `tests/cases/test_formation.gd`、HUD 真实输入探针并重截 1920×1080 截图。
- **方向造型**：我方显示背影（后脑发束、袍背、背带/武器侧面），敌方显示正面；`slot.view = back/front` 数据驱动，`VisualCatalog` 支持 `sprites.front/back`，未来 AI 立绘可直接替换，缺失回退程序化。
- **缩放**：全局美术缩放约 0.75（后排再 ×0.9）；名字/血条/状态/气泡锚点与命中区已随造型收拢，HUD 不变。

## 已知限制

1. **手动验收待用户签字**：自动探针已覆盖完整输入链路，但“真人从打开游戏到打完一局并检查对白/倍速/跳过/F1/F3/F6/F7”的清单尚未由用户亲自执行；见 `docs/PROGRESS.md` 末尾。
2. **退出期引擎告警**：部分 headless/强制退出工具会打印 `ObjectDB instances leaked at exit` 和 `resources still in use at exit`；退出码为 0，无 `SCRIPT ERROR`，不影响门禁，但不是“完全干净退出”。这是既有已知现象。`tools/smoke_gate.sh` 只豁免这条退出期 `ERROR: N resources still in use at exit` 诊断，其他 `ERROR:`（含 `push_error`）仍按失败处理。
3. **音频**：当前遭遇战没有配置 BGM（`bgm_path` 为空），只有程序化短音效；没有全局静音开关。
4. **AI 美术未接入**：程序化 Q 版细节密度低于成品立绘；后续按 `assets/art/README.md` 接入 AI 图并复核脚底对齐/信息条遮挡即可回退。
5. **窗口与截图分辨率**：本机窗口受显示器限制可能只有 1440×762 或 1354×762；截图工具使用 1920×1080 的 `SubViewport` 保证输出规格。HUD 输入冒烟按 1920×1080 逻辑坐标进行真实点击映射。
6. **HUD 全流程冒烟采用全队普攻策略**：在同一种子下第 12 回合战败，最终面板为“战败…”。这是真实的完整战斗结果，不是被强制写死；自动技能策略的剧情截图在同一种子下第 8 回合胜利。两种结局都由真实结算产生。
7. **调试工具仅 debug 构建**：F1/F3/F6/F7、游戏内回放模式在 release/导出构建中不可用；headless dump 只保存 JSON，不保存 PNG。

## 文档

- `docs/DEBUGGING.md`：dump/replay、分歧定位、快照、黄金回放、fuzz、F3/F6/F7、截图与修复流程。
- `docs/EXTENDING.md`：新增技能、状态、道具、单位、表现命令、剧情 beat、视觉目录与内容变更后的黄金回归。
- `docs/PROGRESS.md`：Plan 1 内核、Plan 2A 表现层、Plan 2B 调试/美术/验收、2.5D 阵型的真实过程、决策和证据。
- `docs/TECH_NOTES.md`：双轨架构、确定性/回放、表现层、HUD、剧情、调试、美术、2.5D 阵型与 Godot 踩坑。
