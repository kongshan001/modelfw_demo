# Godot 回合制战斗 Demo — 调试、美术与验收实施计划（Plan 2B）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** 在可玩的表现层之上补齐调试工具体验、原创 Q 版美术与项目文档，完成 MVP 验收。

**Architecture:** 调试控制台/浮层通过 `BattleDebug` 单例访问当前 `BattleSession`；录像回放走「重建引擎 + 按录像意图重演 + 同一 Director 播放」路径；美术通过独立 `VisualCatalog`（`assets/`，不写入 `res://data`）覆盖立绘/背景/图标，避免改变内容 hash 与黄金回放。

**Tech Stack:** Godot 4.6、GDScript、现有 `core/` 录像/回放/不变量、Seedream/org-game-art（原创 Q 版，失败则 CC0/程序化兜底）。

## Global Constraints

- 不修改 `core/` 战斗规则与 `res://data/**`；调试/表现只能读事件与状态，回放重建引擎重演。
- 黄金回放严格校验保持绿色（`bash godot-battle/tools/run_tests.sh`）。
- 表现层冒烟、HUD 输入冒烟、故事探针保持绿色。
- 美术必须原创；不得使用网易《梦幻西游》素材；`assets/CREDITS.md` 记录来源。
- 截图 1920×1080；调试工具仅 debug 构建可用。

---

## Task 1: 调试控制台、浮层、单步、录像回放与快照校验

**Files:**
- Create: `battle/debug/battle_debug.gd`（Autoload）
- Create: `ui/debug/debug_console.gd`, `ui/debug/debug_overlay.gd`
- Modify: `project.godot`（autoload `BattleDebug`）
- Modify: `battle/battle_scene.gd`, `battle/battle_session.gd`
- Modify: `core/battle_replay.gd`（快照校验；core 只读增强，不改战斗规则）
- Create: `tools/smoke_debug.gd`
- Modify: `tests/cases/test_replay.gd`（快照篡改/通过用例）

**Requirements:**
1. `BattleDebug` 单例：保存当前 session；`dump_replay()`（调用 engine.dump_replay，debug 构建同时保存视口截图到 user://replays/，打印绝对路径）；`replay(path)`（先 `BattleReplay.verify`，失败打印分歧并返回；成功设置 pending replay path 并 `reload_current_scene()`）；`pending_replay_path`/`consume_pending_replay()`；`fuzz(count)` 可调用核心 fuzz 逻辑或打印说明。
2. `DebugConsole`（F1）：CanvasLayer + 半透明面板 + LineEdit + RichTextLabel；命令：`dump`、`replay <path>`、`seed`、`state`、`step on|off`、`step`、`timescale <n>`、`kill <id>`、`set_hp <id> <n>`、`add_status <id> <status>`、`validate`；回显；仅 `OS.is_debug_build()`。
3. `DebugOverlay`（F3）：seed、round、当前事件 seq/type、队列长度、播放速度、双方 HP/MP/状态、RNG 名称；每帧刷新；仅 debug。
4. 单步：F6 切换 `sequencer.set_step_mode`，F7 `request_step`；命令 `step` 等价。
5. 回放模式：`BattleSession.start` 检测 pending replay；加载 replay 的 encounter/seed，构建 engine/views（复用 `_build_units`），隐藏 HUD，`skip_story=true`；按 `rounds` 顺序应用 debug_ops、player intents，`engine.resolve_round`，Director 播放事件，`apply_snapshot` 同步；`resolved=false` 的轮次跳过；结束后显示结果面板。回放过程可倍速/跳过；控制台打印 `REPLAY_OK` 或分歧。
6. 快照校验：`BattleReplay.verify` 在每个已重演轮次后，把记录中下一轮开始的 snapshot（HP/MP/alive/statuses/item_uses）与 engine.state 对比；不一致记为 first divergence（类型 `snapshot_mismatch`）并失败；对 partial dump 的未解析轮次不比较。测试增加「篡改 snapshot 失败」与「正常回放通过」。
7. `tools/smoke_debug.gd`：headless 加载战斗场景 → auto 一局 → dump → CLI/直接 verify → 篡改 snapshot 验证失败 → 用 pending replay 启动回放模式跑 2 轮 → 输出 `DEBUG_SMOKE_OK`，退出 0；不修改 core/content/goldens。

**Verification:**
- `bash godot-battle/tools/run_tests.sh` 0 failures（含新增快照测试）。
- `godot --headless --path godot-battle -s tools/smoke_debug.gd` → `DEBUG_SMOKE_OK`。
- 非 headless：F1 console/F3 overlay 截图（`tools/screenshot_debug.gd` 或手动窗口截屏），确认命令/状态可读；回放模式播放一段录像。
- 提交 `feat(debug): 控制台/浮层/单步/录像回放与快照校验`。

---

## Task 2: 原创 Q 版美术与视觉集成

**Art generation:** 使用 `org-game-art`（Seedream）生成原创 Q 版：
- 3 我方立绘：剑客·凌霄（蓝白剑客）、法师·青鸾（青蓝法袍）、医师·白术（白绿医师）。
- 4 敌方：妖兵·甲/乙（红黑小妖）、妖将·裂山（魁梧山妖）、狐妖·媚娘（紫衣狐妖）。
- 1 张 1920×1080 战斗背景：竹林山谷，左右留出站位，柔和雾气/光斑，Q 版手绘风。
- 图标：攻击/法术/道具/防御/逃跑、中毒/破甲/战吼/防御/封印。
- 规格：透明 PNG、1024×1024、3/4 正面、脚底对齐、统一色板；避免任何受版权保护的角色/logo；生成 2–3 个候选后选一致的一套。

**Files:**
- Create: `assets/art/units/*.png`, `assets/art/backgrounds/bamboo_battle.png`, `assets/art/icons/*.png`
- Create: `assets/visuals/visual_catalog.json`（unit id → sprite/scale；background；status/command icons）
- Create: `battle/visual_catalog.gd`（加载 JSON，缺失/加载失败回退占位）
- Modify: `battle/views/unit_view.gd`（有贴图时显示 Sprite2D，脚底对齐、按高度缩放，隐藏程序化绘制；保留血蓝条/名字/状态/点击区）
- Modify: `battle/views/background_view.gd`（有背景贴图时显示 TextureRect/Sprite2D，保留雾/光斑；缺失回退程序化）
- Modify: `ui/battle_hud.gd`（命令/状态图标、面板配色微调；可选）
- Create/modify: `assets/CREDITS.md`（注明 AI 生成/CC0 来源与许可证）
- 视觉验收截图：全景、指令面板、技能特效、胜利面板。

**Constraints:** 不写 `res://data`；不改 core；贴图缺失时游戏仍可玩；资源文件控制在合理体积（单图 ≤ ~3MB，必要时压缩）。

**Verification:** gate/smoke/HUD input/story probes green；4 张 1920×1080 截图检查立绘一致、背景构图、UI 可读；`visual_catalog` 缺失回退测试（临时改名目录/文件，游戏不崩）。

**Art fallback:** 若 Seedream/网络不可用，采用 CC0（Kenney/OpenGameArt）或保留程序化占位并统一调色/雾气/描边；在 CREDITS 与报告中记录实际来源与限制。

---

## Task 3: 文档、最终验收与交付报告

**Files:**
- Create: `godot-battle/README.md`（运行、操作、测试/冒烟/截图命令、项目结构）
- Create: `godot-battle/docs/DEBUGGING.md`（dump → replay → 分歧 → 修复 → golden 流程；F1/F3/F6/F7；快照校验）
- Create: `godot-battle/docs/EXTENDING.md`（新增技能/BUFF/道具/Command/剧情/视觉目录的步骤）
- Update: `godot-battle/docs/PROGRESS.md`（Plan 2A/2B 迭代、问题、验证证据）
- Update: `godot-battle/docs/TECH_NOTES.md`（表现层/回放/调试/美术目录决策与坑）
- 最终验收：`run_tests`、`smoke_presentation`、`smoke_hud_input`、`probe_story`、`smoke_debug`、CLI replay、4 张截图；运行一次真实窗口手动检查清单（用户可复核）。
- 最终 whole-branch review（opus）覆盖 Plan 1+2；修复 Critical/Important；输出交付报告（功能、验证证据、已知限制、运行方式）。

**Verification:** 一条命令清单全部通过；文档可从零运行；截图/录像路径可复现；最终审查 Ready。

---

## Acceptance (MVP)

1. 真实窗口可完成 3v4：指令、技能、道具、防御、逃跑、胜负、对白、气泡、日志、倍速/跳过。
2. 核心测试 785+ / 0；3 黄金回放严格校验；50 局 fuzz；快照校验。
3. 表现层 smoke、HUD 真实输入 12 回合、故事探针、调试 smoke 全绿。
4. 原创 Q 版视觉（或明确记录的兜底）与 1920×1080 截图；无侵权素材。
5. F1/F3/F6/F7 + dump/replay 可用；录像可复现并定位分歧。
6. README/DEBUGGING/EXTENDING/PROGRESS/TECH_NOTES 完整。
7. 最终 whole-branch review Ready（或所有 Critical/Important 已修复）。
