# 山海试炼 · Godot 2D 回合制战斗 Demo

3v4 回合制战斗 MVP：确定性战斗内核 + 可玩的表现层 + 录像回放/调试工具 + 原创程序化 Q 版美术兜底。入口是 6 名主角的选择界面，确认后进入战斗。

## 这是什么

- 我方 3 人（剑客·凌霄、法师·青鸾、医师·白术）对敌方 4 妖（妖兵·甲/乙、妖将·裂山、狐妖·媚娘），一局完整胜负。
- 指令阶段支持普攻、法术、道具、防御、全队逃跑；法术包含单体、AOE、治疗、净化与状态。
- 战斗内核确定性：所有战斗随机来自注入种子的 `BattleRng`；同一内容版本 + 同一意图 + 同一种子可重放出逐事件一致的结果。
- 表现层包括回合横幅、出手顺序、技能特效、飘字、攻击预备/收势、远程弹道、受击顿帧、对白、喊招气泡、战斗日志、胜利/战败/逃跑结算与程序化音效。
- 调试工具包括 F1 控制台、F3 状态浮层、F6/F7 单步、录像 dump/replay、快照校验与黄金回放。
- 角色、战场背景与面板为项目内原创的程序化 Q 版绘制；指令/状态图标来自 game-icons.net（CC BY 3.0）。来源见 `assets/art/CREDITS.md`；AI 角色立绘接入点留在 `assets/visuals/visual_catalog.json`。

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

主场景是 `scenes/character_select.tscn`：6 名主角选 1 名，确认后进入 `scenes/battle_scene.tscn`；默认遭遇战为 `enc_bamboo_01`。

## 操作

### 主角选择

| 操作 | 说明 |
| --- | --- |
| 鼠标 | 点击底部角色卡、左右箭头或「踏入试炼」 |
| `←` / `→` 或 `A` / `D` | 切换主角 |
| `1`–`6` | 直接选择对应角色 |
| `Enter` | 确认并进入战斗 |

### 战斗

| 操作 | 说明 |
| --- | --- |
| 鼠标 | 点击指令按钮（攻击/法术/道具/防御）、目标单位/尖端、返回、倍速、跳过本回合、逃跑。目标箭头默认落在前排尖端，并跟随悬停目标移动。 |
| 数字键 `1`–`4` | 选择目标时，按 HUD「目标键位」映射选择敌方第 1–4 个槽位（阵型重叠时最稳定）。 |
| `Q` / `W` / `E` | 选择目标时，按 HUD「目标键位」映射选择我方第 1–3 个槽位（道具/治疗）。 |
| `ESC` / 返回按钮 | 目标选择时返回；根指令时回退到上一名我方。 |
| 对白：鼠标点击 / `Space` / `Enter` | 跳过打字或推进下一行；不操作也会自动推进。 |
| 倍速按钮 | 在 `1x` / `2x` 之间切换，影响战斗播放速度。 |
| 跳过本回合 | 仅在事件播放期间可用；跳过当前回合剩余演出并同步到真实状态。 |
| `F2` | 切换画风：原画 → 卡通渲染 → 水墨（屏幕后处理，仅作用于战场，HUD 保持清晰）。 |
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

# 8. 主角选择冒烟、切战斗与截图（1920×1080）
bash godot-battle/tools/smoke_gate.sh smoke_character_select.gd --headless; echo "exit=$?"
bash godot-battle/tools/smoke_gate.sh smoke_character_enter_battle.gd --headless; echo "exit=$?"
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_character_select.gd; echo "exit=$?"

# 9. 画风后处理冒烟与三风格截图（1920×1080）
bash godot-battle/tools/smoke_gate.sh smoke_style.gd --headless; echo "exit=$?"
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_style.gd; echo "exit=$?"
```

聚焦调试单个探针时，可绕过门禁直接运行（不会因 `ERROR:` 行失败）：

```bash
godot --headless --path godot-battle -s tools/smoke_presentation.gd
godot --path godot-battle --resolution 1920x1080 -s tools/smoke_hud_input.gd
godot --headless --path godot-battle -s tools/probe_story.gd
godot --headless --path godot-battle -s tools/smoke_debug.gd
```

预期关键输出：

- `RESULT: 1070 assertions, 0 failures`
- `PRESENTATION_SMOKE_OK`
- `HUD_INPUT_OK`
- `STORY_PROBE_OK`
- `DEBUG_SMOKE_OK`
- 四个烟测/探针各输出一行 `SMOKE_OK <script>` 且 `exit=0`
- `CHARACTER_SELECT_SMOKE_OK`
- `ENTER_BATTLE_OK`
- `REPLAY_OK`
- `STYLE_SMOKE_OK`
- 截图工具 exit 0，输出 `SCREENSHOT: <绝对路径>`；`screenshot_art.gd` 额外输出 `plan2b_art_projectile.png`、`plan2b_art_lunge.png`、`plan2b_art_float.png` 三张打击感验收图（弹道/预备/飘字）。
- `screenshot_character_select.gd` 额外输出 `charselect_lingxiao.png`、`charselect_qingluan.png`、`charselect_confirm.png`。
- `screenshot_style.gd` 额外输出 `style_0_original.png`、`style_1_toon.png`、`style_2_ink.png` 三张同帧画风对比图。

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
│   ├── character_select.tscn  # 主场景：主角选择入口
│   └── battle_scene.tscn      # 战斗场景
├── roster/                    # 主角档案与存盘（不进 data/，避免内容哈希）
│   ├── hero_profile.gd
│   ├── hero_roster.gd
│   └── heroes/*.tres          # 6 名主角
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
│   └── character_select/      # 主角选择控制器/背景/立绘/详情/卡片
├── assets/
│   ├── visuals/visual_catalog.json  # AI/外部美术 drop-in schema
│   ├── visuals/heroes/        # 主角透明立绘（缺图自动回退程序化）
│   └── art/                   # 素材说明与 CREDITS
├── tools/                     # 冒烟、探针、回放 CLI、截图、黄金生成
├── tests/
│   ├── cases/                 # 核心测试用例（自动发现）
│   └── golden/                # 3 个黄金回放
└── docs/                      # README、调试、扩展、过程、技术文档
```

## 美术与素材状态

- 当前全部可视内容由 `battle/views/unit_view.gd`、`battle/views/background_view.gd`、`ui/*.gd` 使用 Godot 绘制原语实时生成：Q 版角色、竹林黎明背景、HUD/对白/结算样式、状态与指令徽章。
- 主角选择立绘：凌霄、霜岚已用 Seedream 5.0 Flash 生成、绿幕抠像并接入 `assets/visuals/heroes/`；青鸾、玄烛、白术、紫苏暂用程序化兜底，账号充值后补齐。
- 生图通道：方舟端点 `ep-20261027232001-j8hg2`（Seedream 5.0 Flash，按量计费）。2026-10-27 因账号欠费暂停，充值后继续。
- `assets/visuals/visual_catalog.json` 已接入指令/状态图标，并预留角色立绘与背景的 drop-in 接口；缺失或损坏时自动回退到程序化绘制。
- 指令/状态图标：game-icons.net，CC BY 3.0；战斗背景仍为程序化竹林晨光。字体走系统字体回退。完整来源见 `assets/art/CREDITS.md`。
- 后续接入 AI 美术的规格、缩放换算和回退验证步骤见 `assets/art/README.md`。

## 战场站位（2.5D 俯视）

- 单尖端 + 扇形后排阵型由 `battle/battle_field_layout.gd` 管理：每侧只有一个 `row=1` 尖端（我方剑客、敌方妖将），法系/辅助作为 `row=0` 沿尖端后方**向两侧扇形展开**（不是堆在正后方）；角色按脚底 Y 排序，只翻转美术层，名字/血条/命中区不翻转。
- **尖端与中心**：我方剑客 (1100,830)、敌方妖将 (660,560) 是双方最近的一对（约 516px），连线中点 (880,695) 落在中央石环；两侧中心约 (1185,900) / (565,479)，中心距约 750px（≈4.4 个角色高），中心线约 34°。
- **同侧间距**：我方法师 (1265,870)、医师 (1190,1000)，同侧两两约 150–192px；敌方妖兵甲 (520,520)、妖兵乙 (470,400)、狐妖 (610,415) 与妖将组成 2×2 交错块，相邻对约 130–153px（0.76–0.90 个角色高）。参考梦幻实测的同侧相邻 0.7–1.0 个角色高。
- **角色比例**：`UnitView.BASE_ART_SCALE = 0.66`，角色美术高约 170px（屏高 15%），对齐梦幻实机 10–14% 的量级；阵型 depth 再叠加。
- **镜头纵深**：我方整队靠近镜头（depth 0.98/1.06/1.10），敌方整队远离（depth 0.94/0.90/0.88/0.86）；我方更大/更低，敌方更小/更高，我方最小 depth 仍大于敌方最大。
- **方向造型**：我方显示背影（后脑发束、袍背、背带/武器侧面），敌方显示正面；`slot.view = back/front` 数据驱动，`VisualCatalog` 支持 `sprites.front/back`，未来 AI 立绘可直接替换，缺失回退程序化。
- **林间空地**：`battle/views/background_view.gd` 绘制不规则草坡（远缘 y≈340–460，整体抬高约 140px 让构图更竖），远侧雾草 → 中央受光泥地/苔藓 → 近景深草，配踩踏土径、竹根/竹桩、石块、落花、竹影与中央半埋石环；没有矩形平台、描金边或均匀方格。石环放大到 320×105、两军尖端都在环外，环内空置。敌方后排（狐妖 y≈415）仍站在空地内。
- **目标选择**：单尖端+扇形阵型下命中区/信息带允许在屏幕空间重叠（参考作亦然），不再要求 x 区间互不相交。选择目标时只显示一个目标箭头（默认落在尖端，鼠标悬停/点击会移动），并用 HUD 的「目标键位」映射 + `1`–`4` / `Q`/`W`/`E` 直接确认；鼠标点尖端作为补充。后排被遮挡时优先用数字键。
- 默认 3v4 阵型可按遭遇战替换；新增单位/阵型时改 `BattleFieldLayout`，跑 `tests/cases/test_formation.gd`、HUD 真实输入探针并重截 1920×1080 截图。

## 已知限制

1. **手动验收待用户签字**：自动探针已覆盖完整输入链路，但“真人从打开游戏到打完一局并检查对白/倍速/跳过/F1/F3/F6/F7”的清单尚未由用户亲自执行；见 `docs/PROGRESS.md` 末尾。
2. **退出期引擎告警**：部分 headless/强制退出工具会打印 `ObjectDB instances leaked at exit` 和 `resources still in use at exit`；退出码为 0，无 `SCRIPT ERROR`，不影响门禁，但不是“完全干净退出”。这是既有已知现象。`tools/smoke_gate.sh` 只豁免这条退出期 `ERROR: N resources still in use at exit` 诊断，其他 `ERROR:`（含 `push_error`）仍按失败处理。
3. **音频**：当前遭遇战没有配置 BGM（`bgm_path` 为空），只有程序化短音效；没有全局静音开关。
4. **AI 角色立绘未接入**：程序化 Q 版细节密度低于成品立绘；指令/状态图标已先接入免费素材，背景保持程序化以避免与角色风格架空。后续按 `assets/art/README.md` 接入 AI 图并复核脚底对齐/信息条遮挡即可回退。
5. **窗口与截图分辨率**：本机窗口受显示器限制可能只有 1440×762 或 1354×762；截图工具使用 1920×1080 的 `SubViewport` 保证输出规格。HUD 输入冒烟按 1920×1080 逻辑坐标进行真实点击映射。
6. **HUD 全流程冒烟采用全队普攻策略**：在同一种子下第 12 回合战败，最终面板为“战败…”。这是真实的完整战斗结果，不是被强制写死；自动技能策略的剧情截图在同一种子下第 8 回合胜利。两种结局都由真实结算产生。
7. **调试工具仅 debug 构建**：F1/F3/F6/F7、游戏内回放模式在 release/导出构建中不可用；headless dump 只保存 JSON，不保存 PNG。
8. **主角选择立绘待补齐**：4 名主角暂用程序化兜底；确认主角后进入现有战斗，本期不替换战斗阵容/数值。

## 文档

- `docs/DEBUGGING.md`：dump/replay、分歧定位、快照、黄金回放、fuzz、F3/F6/F7、截图与修复流程。
- `docs/EXTENDING.md`：新增技能、状态、道具、单位、表现命令、剧情 beat、视觉目录与内容变更后的黄金回归。
- `docs/PROGRESS.md`：Plan 1 内核、Plan 2A 表现层、Plan 2B 调试/美术/验收、2.5D 阵型的真实过程、决策和证据。
- `docs/TECH_NOTES.md`：双轨架构、确定性/回放、表现层、HUD、剧情、调试、美术、2.5D 阵型与 Godot 踩坑。
