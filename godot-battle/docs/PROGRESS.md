# 推进日志

## 2026-10-24 · M1–M2 战斗内核

- 目标：完成确定性战斗内核、数据化内容、录像/回放与自动化测试。
- 完成：工程骨架；RNG/事件/意图；7 单位/13 技能/5 状态/2 道具/1 遭遇战；回合调度、速度排序、技能、状态、道具、防御、逃跑、AI、胜负；录像/回放/不变量；黄金回放与 fuzz。
- 技术决策：逻辑与表现双轨；所有随机只来自注入的 `BattleRng`；每回合一次性结算并产出有序事件；录像只记录玩家意图，AI 由同种子重放。
- 问题记录：
  - 测试初期直接在真实遭遇战里验证治疗/封印，敌方先手会干扰断言。解决：用“真实单位 + 慢速木桩敌人”的合成状态做单元测试，真实遭遇战只用于集成/黄金回放。
  - 状态持续时间与中毒 tick 的时序容易错。解决：中毒在回合开始 tick；状态在回合结束递减，且施加回合不递减；封印在跳过行动时消耗；防御在自身下次行动开始解除。对应测试覆盖。
  - `EncounterData` 的脚本字段原名 `script` 与 Godot `Object.script` 冲突，资源序列化异常。解决：更名为 `script_data`，同步内容与测试。
  - 录像中的 JSON 数字经解析后全是 float，与内存中 int 的规范化结果不一致，摘要/事件比对会假失败。解决：统一走 `BattleDigest.canonical_json`，把整值 float 归一化为 int 后再比较与计算 SHA-256。
  - 黄金回放按 12 回合封顶生成，三份录像均未打到胜负（`outcome=0`），属于有意的“过程回放”：用于锁定意图→事件链的确定性，而不是覆盖战斗结局；结局由 `test_flee_ai`、fuzz 与回合上限测试覆盖。
  - 录像元数据写入生成时间，黄金文件每次重生成字节都会变化。解决：以 `digests[]`/事件流作为确定性依据，测试校验回放语义与摘要链，不做文件字节比对；内容变更必须重新生成黄金文件，否则 `--strict-content` 会因内容 hash 不一致而失败。
- 验证：
  - 命令：`bash godot-battle/tools/run_tests.sh`
  - 结果（最终门禁实际输出，`exit=0`；末次墙钟约 13.0s，冷缓存首次约 20.2s）：

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PASS test_battle_basic.gd (9 assertions)
PASS test_content.gd (26 assertions)
PASS test_flee_ai.gd (43 assertions)
PASS test_fuzz.gd (634 assertions)
PASS test_golden.gd (5 assertions)
REPLAY_SAVED: .../test_replay.json
REPLAY_SAVED: .../test_replay_partial.json
REPLAY_SAVED: .../test_replay_debug.json
PASS test_replay.gd (15 assertions)
PASS test_rng.gd (22 assertions)
PASS test_serialization.gd (7 assertions)
PASS test_skills.gd (10 assertions)
PASS test_smoke.gd (2 assertions)
PASS test_status_items.gd (13 assertions)
RESULT: 786 assertions, 0 failures
```

  - 黄金回放：3 个文件位于 `tests/golden/`（`golden_attack`/`golden_aoe`/`golden_control`，种子 1001–1003），`--strict-content` 校验通过（`REPLAY_OK` ×3）；内容 hash 为 `sha256:4381648dff17081e3d1bdd6ace73753fcc0bffc562ee03e4f24e1b6e0ef25975`。
  - fuzz：50 局（引擎种子 5000–5049，选择种子 9000–9049），每回合检查不变量，共 634 个断言，单跑墙钟约 1.4s；借助 30 回合上限保证终止。
- 风险与遗留：表现层、UI、美术与调试浮层属于 Plan 2；当前没有音画表现。已知小项：`snapshots[]` 尚未参与回放校验；快照/事件中的异常 JSON 元素级校验未做（Task 8 记录）。

## 2026-10-24 · Plan 2A 可玩表现层

- 目标：把确定性内核接上可玩的 3v4 战场，完成“指令 → 结算 → 事件演出 → 下一回合”的闭环。
- 完成：
  - 战场场景/背景/相机/7 个 `UnitView`/`BattleSession`；程序化竹林黎明背景与基础角色剪影。
  - `BattleDirector` + `BattleSequencer` + `BattleCommand`/`CommandRegistry`：回合横幅、行动、伤害、治疗、状态、死亡、结算；VFX、飘字、真实顿帧、镜头震动/轻推、回合出手顺序预览。
  - HUD：25 秒指令倒计时、攻击/法术/道具/防御/逃跑、目标选择、1–4/Q/W/E、返回、1x/2x、跳过本回合、战斗日志、顺序条。
  - 剧情：开场/首杀/胜利/失败对白、打字机、点击/空格推进、技能喊招气泡、胜利/战败/逃跑面板、程序化音效。
  - 自动输入探针与真实鼠标 HUD 探针；后续 Plan 2B 已将其保留为最终验收入口。
- 关键决策/实现：
  - 逻辑随机仍只来自 `BattleRng`；表现装饰用独立 `RandomNumberGenerator(seed=9001)`，不影响回放摘要。
  - 表现层只消费有序 `BattleEvent`（再通过 `BattleContext.apply_snapshot` 同步只读状态），不直接改战斗数据。
  - 顿帧用 `Engine.time_scale=0.05` + 忽略时间缩放的 0.06s 计时器；跳过时不顿帧。`playback_speed` 只缩放 `BattleContext.wait`/对白时钟，避免和 `Engine.time_scale` 双重加速。
  - `skip_all()` 用 generation 失效队列、隐藏对白/气泡、恢复快照/姿态；HUD 的跳过按钮只在播放时可用。
- 问题与修正：
  - 状态/MP 变化后的视图目标有误，导致后续演出状态不同步：修正事件目标消费。
  - 首杀对白曾被己方阵亡触发并消耗：改为只接受敌方死亡事件。
  - 真实输入探针早期只验证首个阶段；后来扩展为完整 12 回合真实点击并在 `battle_finished` 后校验真实结算面板。
  - HUD 初始按钮被销毁后再刷新会访问已释放实例：改为有效性检查并回收；单位点击区/附属件与 HUD 面板的重叠成为独立探针。
  - 截图分辨率：窗口被 macOS 显示器限制，统一改用 1920×1080 `SubViewport`；HUD 真实输入探针仍使用逻辑 1920×1080 坐标。
  - 全队普攻策略在同种子下第 12 回合真实战败（outcome=2）；自动技能策略（截图）第 8 回合真实胜利（outcome=1）。两者都保留，用于覆盖不同结局而非写死胜利。
- 验证（当时）：`PRESENTATION_SMOKE_OK`、`HUD_INPUT_OK`、`STORY_PROBE_OK`，核心门禁绿色；最终统一复验见下节。

## 2026-10-25 · Plan 2B 调试、原创美术与最终验收

- 目标：补调试工具/回放模式、原创视觉兜底、文档与最终验收。
- 调试（Task 1）：
  - 新增 `BattleDebug` autoload；F1 控制台（dump/replay/seed/state/step/timescale/kill/set_hp/add_status/validate/skip）、F3 浮层、F6 单步、F7 单步一次。
  - dump 写 `user://replays/*.json`，窗口下附带同目录视口 PNG；游戏内 replay 先校验、设置 pending、重载场景，回放模式隐藏 HUD、复用 Director 播放，F1/F6/F7 可用，ESC 退出。
  - `BattleReplay.verify` 增加回合快照校验：debug_ops 后、意图重演前比较 HP/MP/alive/状态 `id+remaining`/道具使用；不匹配以 `snapshot_mismatch` 失败，未被解析的 partial 轮次跳过。新增 6 个快照/回放断言，最终 792。
  - 问题：`timescale` 若同时改 `Engine.time_scale` 会与 `playback_speed` 双重加速，改为只设 `playback_speed`；headless dump 不截图，打印 `REPLAY_SCREENSHOT_SKIPPED`；强制退出仍会打印既有 ObjectDB/resources 告警。
- 美术（Task 2）：
  - Seedream/方舟生图在本机被 403 + SSO 失效阻断，未生成任何 AI 位图；改用原创程序化 Q 版：7 角色、竹林黎明背景、金边紫檀 UI、状态/指令徽章、对白/气泡/结算视觉。
  - `VisualCatalog` 与空 schema 的 `visual_catalog.json` 提供立绘/背景/状态/指令图标替换；缺失/非法路径自动回退；接入说明和 CREDITS 已落盘。
  - 迭代修正：状态行读取 `status.data.id`；按钮徽章失效引用；狐尾改非对称收拢；小妖信息条下移；法师法球/妖将斧头/妖兵乙毒矛与相邻命中区冲突，最终通过槽位调整（妖将 x=540）、法球/斧头/拳内收、妖兵乙命中区右扩和无类型点探针解决；HUD 探针增加到 6 个附属点，最小命中区间隙 17px。
  - 背景贴图覆盖时，光柱/地面光斑/地面薄雾仍叠加，避免视觉目录替换导致氛围缺失。
  - 视觉验收截图 `plan2b_art_*`、`task3_hud*`、`task4_*`；最终重拍后检查关键画面中的角色一致性、脚底对齐、信息带与按钮无遮挡。
- 最终验收（2026-10-25，实际输出，未伪造）：
  - 核心门禁：`bash godot-battle/tools/run_tests.sh; echo "exit=$?"` → `RESULT: 792 assertions, 0 failures`，`exit=0`。含 3 个黄金回放、50 局 fuzz（634 断言）、22 个回放断言（含快照篡改）。
  - 表现层：`PRESENTATION_SMOKE_OK`，`exit=0`；退出期有 `ObjectDB instances leaked at exit` 告警。
  - HUD 真实输入：`HUD_INPUT_OK`，`exit=0`；窗口 `1440×762`（逻辑 1920×1080）；最小命中区间隙 17.0px、6 个附属点通过、7 个单位真实点击通过、边界点击通过、倍速实测 2.0x；完整 12 回合真实输入，`battle finished outcome=2 rounds=12 panel=战败…`（全普攻策略）。
  - 故事探针：`STORY_PROBE_OK`，`exit=0`；两行对白推进/自动完成、胜利面板奖励 1200/350 且单次展示。
  - 调试冒烟：`DEBUG_SMOKE_OK`，`exit=0`；auto 战斗 `outcome=1 rounds=8`，dump verify OK，篡改快照被拒（round=2 field=hp），回放模式播放 3 回合并验证 F1/F3/F6/F7；退出期有 ObjectDB/resources 告警。
  - 黄金回放 CLI：`REPLAY_OK tests/golden/golden_attack.json`，`exit=0`（`--strict-content`）；核心测试同时严格校验 attack/aoe/control 三份。
  - 截图工具：`screenshot_art`、`screenshot_hud`、`screenshot_story`、`screenshot_debug` 均 exit 0；生成的 `plan2b_art_*`、`task3_hud*`、`task4_*`、`plan2b_debug_*` 关键图均为 1920×1080。已检查最新无 HUD 全景、HUD 全景、胜利面板、对白/喊招、F1+F3 与回放模式截图。
  - 产物目录：`~/Library/Application Support/Godot/app_userdata/山海试炼/screenshots/`、`~/Library/Application Support/Godot/app_userdata/山海试炼/replays/`。
- 已知限制/遗留：手动真人全流程待用户签字；BGM 未配置、无静音开关；调试工具仅 debug 构建；headless dump 无截图；退出期对象/资源告警；程序化美术细节低于成品 AI 立绘；AI 美术需修复通道后按 VisualCatalog 接入。

## 手动验收清单（待用户执行并签字）

自动探针不能替代真人手感检查。请打开游戏后逐项确认：

- [ ] 双击/打开 `project.godot` 或运行 `godot --path godot-battle`，能进入开场对白；点击对白框、`Space`/`Enter` 可推进并结束对白。
- [ ] 完成一局 3v4，实际使用过：普攻、至少一个法术、至少一个道具、防御；另开一局尝试“逃跑”，确认逃跑成功/失败有明确结果。
- [ ] 鼠标点击 `1`–`4`（敌方目标）和 `Q`/`W`/`E`（我方目标）均能选中；`ESC`/“返回”能退回上一层指令。
- [ ] 指令倒计时正常；`倍速` 在 1x/2x 间切换；播放中的“跳过本回合”能直接到真实结算后的状态。
- [ ] 战斗日志、出手顺序、状态徽章、技能喊招气泡可读；对白期间 HUD 不产生重影。
- [ ] 按实际战局确认真实结算面板（胜利/战败/逃跑至少一种；条件允许时三种都走一遍），确认“再战一场”和“退出”可用。
- [ ] F1 打开控制台，执行 `state`、`validate`、`dump`、`replay <path>`；F3 浮层数据正确；F6 开单步、F7 逐步推进；回放模式 ESC 能退出。
- [ ] 退出游戏后确认无本次验收新增的崩溃；如有 ObjectDB/resources 告警，记录但不视为功能失败。
- [ ] 用户签字/日期：____________________

## 2026-10-25 · 2.5D 俯视阵型

- 目标：把横排战场升级为梦幻西游式前后两排、透视地面、按排深度缩放、面向翻转的 2.5D 阵型，同时保持 HUD/点击/测试可用。
- 完成：`BattleFieldLayout` 槽位系统；`world.y_sort_enabled`；`UnitView` 只对美术层做深度缩放与面向翻转；透视石台/网格平台；前后排 x 命中区间隔 ≥10px；阵型单测 82 条；HUD 真实输入完整战斗。
- 问题与解决：
  - 前后排 + 大型附属件（法球/尾巴/斧/矛）容易落进相邻命中区。解决：按排/列错位，敌方统一面向右、我方面向左；把附属件收进间隙或允许它在自由区；探针改为“不得进入邻居命中区”，而不是“必须在自身矩形内”。
  - 3D 式前后排天然会视觉重叠；用 Y 排序保证前排绘制在上，点击区用 x 间隔避免抢点，前后排中心点击/数字键均可选。
  - `mob_a` 耳尖在 10px 最小间隙处约有 1.8px 擦边，未进入探针点集；属于已知视觉微差。
- 验证：核心 874 断言 / 0 失败（含 test_formation 82）；`PRESENTATION_SMOKE_OK`；`HUD_INPUT_OK`（12 回合真实输入、前后排、最小命中间隙 10px）；`STORY_PROBE_OK`；`DEBUG_SMOKE_OK`；1920×1080 截图与 20 秒阵型 GIF。
- 提交：`bf2bbac`（2.5D 阵型/透视战场）、`40feddc`（敌方统一面向与间隙）。

## 2026-10-25 · 方向造型与缩放

- 目标：按梦幻参考，我方背影、敌方正面；角色缩小，增加环境占比。
- 参考分析：经典 45° 左上右下；镜头在我方背后；角色约占屏高 1/6；两排错位；HUD 靠边（52PK/搜狐/官网截图，仅内部参考）。
- 完成：`slot.view=back/front` + `facing`；三英雄程序化背影（发束/长发/发髻、袍背、背带/武器侧面）；敌方保持正面；VisualCatalog 预留 `sprites.front/back`；全局美术缩放约 0.75，信息条/命中区同步收拢。
- 问题与解决：背影遮住脸/正面衣领；法师长发/医师发髻/剑客发带分别处理；法杖/药囊/剑在侧后方保留；缩小时血条/命中区不再悬空；探针更新尺寸与前后排。
- 验证：核心 895 断言 / 0 失败（formation 103）；HUD 真实输入 12 回合；表现/故事/调试冒烟全绿；1920×1080 截图与 12.7 秒 GIF。
- 遗留：程序化背影是正视/背视，不是真正 45° 3/4；未来 AI 的前/背立绘可无缝替换；法师法球光晕与血条边缘略近。
- 提交：`72d098a`（背影/正面与缩放）。

## 2026-10-25 · 镜头纵深（敌方远/我方近）

- 目标：强化“镜头在我方背后”的空间感；我方靠近镜头、更大更低，敌方远离、更小更高。
- 完成：我方 slots depth `1.12/0.98/0.96`、脚底 y `880/790`；敌方 depth `0.84/0.74`、脚底 y `720/630`；同侧前后排关系保留；PartyFleeButton 右移避开法师信息条；HUD 探针改为按侧断言前后排/纵深。
- 验证：核心 898 断言 / 0 失败（formation 103）；HUD 真实输入 12 回合 `HUD_INPUT_OK`；表现/故事/调试冒烟全绿；1920×1080 截图与 GIF。
- 遗留：纵深比例可继续按镜头 FOV 微调；当前是数据表驱动，改 `BattleFieldLayout` 即可。
- 提交：`2be0f19`。

## 2026-10-25 · 竹林林间空地战场与去网格背景

- 目标：按用户反馈与独立美术评审，移除矩形石台/描金边/均匀方格，把地面改成与竹林、山雾、晨光连成一体的自然林间空地；提亮提饱和、给敌侧补光，同时保留阵型、HUD、点击与剧情。
- 完成：
  - `BackgroundView` 地面重写：确定性程序纹理空地（远侧雾草 → 中央受光泥地/苔藓 → 近景深草）+ 不规则远缘（插值曲线/噪声/草须/薄雾）+ 踩踏土径/踏脚石 + 半埋石环中心锚点 + 石块/竹根/竹桩/落叶/小花/竹影 + 左上敌侧暖光斑。
  - 近景框景竹改画在空地之上，竹脚用草簇/根瘤接地；光柱、地面光斑、薄雾、暗角保留。
  - 曝光/色彩：天空、山体、竹丛提亮提饱和；暗角最大 alpha 0.4→0.08。
- 视觉验收（1920×1080，无 HUD 纯场景，与评审同口径）：平均亮度 104.2→154.9，平均饱和度 24.4%→38.0%；HUD 全景 97.3→134.4 亮度、26.2%→35.4% 饱和度（HUD 深色面板未改，全景均值略低于场景口径）。无矩形平台/网格/描金边；敌群落在受光地面；单位脚底阴影、HUD、日志与前后排可读。
- 验证：核心 `RESULT: 901 assertions, 0 failures`；`PRESENTATION_SMOKE_OK` / `SMOKE_OK`；`HUD_INPUT_OK`（12 回合真实输入）/`SMOKE_OK`；`screenshot_art.gd` 全场景/HUD/技能/胜利均 1920×1080；GIF 15s/720×405/10fps/96 色 5.4MB（`.superpowers/sdd/bamboo-clearing.gif`，未入库）。
- 遗留：胜利面板仍按原 0.7 压暗（评审 P1-4，未在本次范围）；HUD 深色面板拉低全景均值；程序化空地仍是兜底美术，未来可经 VisualCatalog 换手绘背景。

## 2026-10-25 · 打击感增强与敌方比例/光照 P0

- 目标：落实独立美术评审剩余 P0（P0-2 战斗 juice、P0-3 敌方尺度/打光）；保留 P0-1 的自然竹林空地曝光，不放大 `BASE_ART_SCALE`。
- 完成：
  - 攻击 `lunge_to()` 增加 0.08s 预备（后拉 12px + 压扁）；新增 `return_pose()` 收势归位（越过家门 16px 再收住）；`cast_pose()` 增加 0.08s 蓄力后再闪光。
  - 顿帧 0.06→0.12s；普通命中震屏 5→7px，暴击 10px + 1.06 punch-zoom，普通命中补 1.02 punch。
  - 飘字：普通伤害 42→56px、暴击 58→76px、治疗 44→56px、状态 40→52px；描边/阴影加强。
  - `VFXFactory` 粒子改用 `BLEND_MODE_ADD` 叠加混合且数量×2；新增 `projectile()` 发光球+彗尾拖尾（0.24~0.30s），`fire`/`seal`/`heal` 由 `ActionStartCommand` 等弹道到达后再播放命中；雷击保留落雷，不改为弹道。
  - 敌方 depth 0.74–0.86→0.88–0.96；我方 0.98/1.12/1.08→1.0/1.08/1.06；位置、斜向中心线、前后排关系、朝向与视图不变，我方最小 depth 仍大于敌方最大。
  - `BackgroundView` 在 (500,560) 增加敌侧暖光地斑，左上竹林/冠层提亮减暗；`UnitView` 信息带锚点下移 4px，避开左上出手顺序条。
- 视觉验收：无 HUD 场景平均亮度 152.6 / 饱和度 38.2%（目标 ≥135/≥35）；含 HUD 全景 133.2 / 35.5%。敌方主体增大到约 18–20% 屏高（妖将 20.1%、狐妖 17.8%），我方仍更近更大；林间空地、雾/光柱与 HUD 可读性保持。新增 `plan2b_art_projectile.png` / `plan2b_art_lunge.png` / `plan2b_art_float.png` 验收图。
- 验证：核心 `RESULT: 901 assertions, 0 failures`；`PRESENTATION_SMOKE_OK` / `SMOKE_OK`；`HUD_INPUT_OK`（12 回合真实输入完整战斗）/`SMOKE_OK`；`STORY_PROBE_OK` / `SMOKE_OK`；`DEBUG_SMOKE_OK` / `SMOKE_OK`；临时跳过探针 `SKIP_OK`（time_scale=1.0、存活单位复位）。
- 产物：8 张 1920×1080 截图（`plan2b_art_full/scene/skill/skill_late/projectile/lunge/float/victory.png`）；GIF 18s/720×405/10fps/96 色 5.6MB（`.superpowers/sdd/p0-combat.gif`，未入库）。
- 遗留：胜利面板仍按原 0.7 压暗（评审 P1-4；不在 P0 范围，未改 UI）；GIF 10fps 下 0.08s 预备动作只有约 1 帧，需看静帧/实时确认；程序化美术本体未变。
- 提交：`feat(presentation): 打击感增强与敌方比例/光照 P0`。
