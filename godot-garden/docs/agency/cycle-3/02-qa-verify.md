# Cycle 3 · 02 QA 验收（Knight 主角）

> 执行：QA 负责人 | 时间：2026-10-31 17:23–17:32（CST） | 阶段：Cycle 3 验收
> 被测：`godot-garden/` 工作区（`scripts/garden_hero.gd` 17:18、`scripts/garden_patrol.gd` 17:14、`tools/screenshot_patrol.gd` 16:53；`godot-garden/` 在 git 中未跟踪）
> 只读声明：未修改任何游戏逻辑。**新增 1 个只读/驱动型 QA 探针** `tools/qa_cycle3_hero.gd`（读取 Knight 状态、跑真实任务链、驱动 `take_damage` 验证倒地复活、验证 `GARDEN_FORCE_PROCEDURAL`；结束释放场景）。

---

## 1. 结论

**阻塞（不可放行）。**

- 主角外观、动画、攻击、倒地/复活、巡逻、开关、无头稳定性均通过；Knight 已在截图中正常出镜，无 T-pose。
- **P0 阻塞：自动任务链无法完成。** 实测在第 7.6 s 进入 `return`，之后 67.4 s 原地卡在 `(0.69, 0.0, 4.52)`，距任务发布者 `3.202 m`，恰好多出阈值 `3.2 m` 0.002 m；`quest.stage` 永远到不了 `complete`。根因见 BUG-01（A* 同格路径被 0.2 m 到达阈值提前消费）。
- **P1 阻塞：主角没有 `GARDEN_FORCE_PROCEDURAL` 回退。** README 第 50 行声称“程序化小女孩保留为回退”，但环境变量只作用于 `garden_patrol.gd`；主角仍挂 Knight、GardenGirl `visible=false`。
- 性能绝对值受本机负载影响，只做记录、不硬判。

---

## 2. 环境与命令

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6，Intel Core i7-5650U（4 逻辑核），Intel Iris 6000 |
| Godot | 4.6.stable.official.89cea1439 |
| 渲染 | 内部 960×540，MSAA 2×，display LINEAR；截图 SubViewport 1920×1080 |
| 系统负载 | 1 分钟均值 4.93–7.89（`uptime` 实测，逐次记录见结果表） |
| 计时 | 无 `timeout`；长任务用 Shell 超时参数，探针自身带超时/自退出 |

```bash
cd /Users/ks_128/Documents/modelfw_demo

# 1. 无头 600 帧
godot --path godot-garden --headless --quit-after 600 > /tmp/cyc3_headless.log 2>&1
grep -nE "SCRIPT ERROR|ERROR|WARNING" /tmp/cyc3_headless.log

# 2. 巡逻探针 ×3（窗口 1280×720，vsync off）
for i in 1 2 3; do godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd; done

# 3. 主角功能（新增只读/驱动探针）
godot --path godot-garden --headless -s tools/qa_cycle3_hero.gd
GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --headless -s tools/qa_cycle3_hero.gd

# 4. 截图矩阵
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd
```

---

## 3. 结果表（用例 / 阈值 / 实测 / 判定）

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 1 | 无头 600 帧 | 0 条 `SCRIPT ERROR/ERROR/WARNING`，exit 0 | exit **0**；grep 0 匹配；日志 5 行仅 banner | **PASS** |
| 2 | 巡逻探针（3 连跑） | `PROBE_PATROL_OK`、三 NPC 行走、间距达标、toggle 双向 | 3/3 exit 0；travelled **7.7–8.0 / 5.4–6.2 / 10.3–10.5**；最小距离见下；toggle 3/3 `true/true` | **PASS** |
| 3 | 巡逻最小间距 | pond>4.8 / circle>2.6 / statue>1.8 / pillar>1.0 | lantern 6.38/6.43/3.32/5.91；sweeper 12.38/3.31/9.56/10.72；fox 12.87/10.74/9.21/1.71（取最小值） | **PASS** |
| 4 | Knight 挂载/缩放/朝向 | Knight 存在、scale 0.74、yaw π | `root_scale=(0.74,0.74,0.74)`、`root_yaw=3.1416`；GardenGirl `model_visible=false` | **PASS** |
| 5 | 隐藏多余武器/披风 | KNIGHT_HIDDEN 全部不可见 | 7/7 命中且不可见：`1H_Sword/1H_Sword_Offhand/2H_Sword/Badge_Shield/Rectangle_Shield/Spike_Shield/Knight_Cape`；`hidden_visible=[]`；保留 `Round_Shield` | **PASS** |
| 6 | Knight 动画资源 | Idle/Running_A/Chop 存在，Idle+Run 循环 | `Idle` len 1.067 loop=1；`Running_A` len 0.800 loop=1；`1H_Melee_Attack_Chop` len 1.067 loop=0 | **PASS** |
| 7 | 攻击动画触发/回 Idle-Walk | Chop 出现且播放后回 Idle/Running_A | 战斗期 9 次进入 Chop，`get_playing_speed=1.2`；离开后采样到 `Idle` 与 `Running_A`（`HERO_ANIM seen=[Running_A, 1H_Melee_Attack_Chop, Idle]`） | **PASS** |
| 8 | **自动任务链** | 75 s 内 accept→fight→return→complete，kills=3 | accept t=0.6 → fight → return t=7.6（kills=3）→ **75 s 超时仍 return**；主角停 `(0.69,0,4.52)`，距发布者 **3.202 m**（阈值 3.2） | **FAIL（P0）** |
| 9 | 倒地/复活可见性 | down: 双模型/光环隐藏；respawn: Knight 可见、GardenGirl 隐藏、HP 满 | down: `hp=0 downed=true model=false knight=false ring=false`；respawn: `hp=220/220 downed=false model=false knight=true ring=true`；anim 立即回 `Running_A` | **PASS** |
| 10 | 复活位置 | `dist_spawn≈0` | 探针在复活后 0.7 s 采样，因 stage=return 已在走回路，`dist_spawn=1.157 m`；代码 `_respawn()` 先 `global_position = respawn_position`，此为采样时机问题，非位置错误 | **PASS（代码审查）/ 采样 INCONCLUSIVE** |
| 11 | `GARDEN_FORCE_PROCEDURAL=1` 回退 | Knight 不存在、GardenGirl 可见 | `HERO_BUILD mode=knight model_visible=false knight=true`；仅 3 条 NPC 回退 WARNING；`QA_CYCLE3_FALLBACK_FAIL`，exit 1 | **FAIL（P1）** |
| 12 | 截图（mixed/wide/lantern dusk+night） | 3 名 KayKit、无 T-pose、无脚本错误 | 工具 exit 0、0 ERROR/WARNING；mixed 为 左绿兜帽 Rogue + 中红发 Rogue 提灯 + 右 Knight；wide 中 Knight 处于攻击前倾姿态（非倒地/T-pose）；lantern dusk/night 背景 Knight 持盾站立，无 T-pose | **PASS** |
| 13 | 截图分辨率/时效 | 本轮新图 | `cycle2_mixed_cast.png`、`patrol_lantern_dusk/night.png`、`patrol_wide_dusk.png` 时间 17:30–17:31；实际 **1920×1080**（工具内 SubViewport），非命令行 1440×810 | **PASS（内容）/ P3 命名与口径残留** |
| 14 | 性能（legacy 探针） | 仅记录，不硬判 | avg **37.8 / 37.8 / 36.8**，min **27 / 25 / 31**；load **5.78 → 6.11 → 6.63 → 7.89**；A/B 成本 -2.1 / +0.2 / +0.4 FPS | **功能性 PASS / 绝对值 INCONCLUSIVE** |

**关键原始输出**

```text
PATROL Patrol_lantern role=lantern travelled=8.0 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.92
PATROL Patrol_sweeper role=sweeper travelled=5.4 min_pond=13.12 min_circle=3.40 min_statue=10.32 min_pillar=11.36
PATROL Patrol_fox role=fox travelled=10.4 min_pond=12.97 min_circle=10.74 min_statue=9.29 min_pillar=1.71
PATROL_FPS avg=37.8 min=27.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PROBE_PATROL_OK
```

```text
HERO_BUILD force_proc=false mode=knight model_is_girl=true model_visible=false knight=true player=true
KNIGHT root_scale=(0.74, 0.74, 0.74) root_yaw=3.1416 knight_nodes=25
KNIGHT hidden_found=["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "1H_Sword", "2H_Sword", "Knight_Cape"] hidden_visible=[]
HERO_STAGE t=0.6 stage=fight kills=0 hero=(0.82, 0.0, 4.5) hp=220/220
HERO_STAGE t=7.6 stage=return kills=3 hero=(6.31, 0.0, 5.48) hp=200/220
HERO_TICK t=10.1 stage=return kills=3 hero=(0.69, 0.0, 4.52) anim=Idle hp=200
...
HERO_TICK t=75.0 stage=return kills=3 hero=(0.69, 0.0, 4.52) anim=Idle hp=200
HERO_QUEST_TIMEOUT t=75.0 stage=return kills=3 hero=(0.69, 0.0, 4.52)
HERO_ANIM seen=["Running_A", "1H_Melee_Attack_Chop", "Idle"] attack_starts=9 attack_speeds=[1.2 ×9] post_attack=["Idle", "Running_A"]
HERO_DOWN before_hp=200 hp=0 downed=true model_visible=false knight_visible=false ring_visible=false
HERO_RESPAWN hp=220/220 downed=false model_visible=false knight_visible=true ring_visible=true anim=Running_A
QA_CYCLE3_HERO_FAIL
```

```text
HERO_BUILD force_proc=true mode=knight model_is_girl=true model_visible=false knight=true player=true
HERO_FALLBACK expected=procedural actual=knight model_visible=false knight=true
WARNING: GardenPatrol: Rogue unavailable (GARDEN_FORCE_PROCEDURAL), using procedural model  ×3
QA_CYCLE3_FALLBACK_FAIL
```

---

## 4. Bug 列表（复现 / 期望 / 实际 / 根因）

### BUG-01（P0）自动任务链卡在“回交”，永远无法完成

- **复现**：`cd /Users/ks_128/Documents/modelfw_demo && godot --path godot-garden --headless -s tools/qa_cycle3_hero.gd`。也可窗口运行游戏后放置 40–60 s 观察：任务计数到 3/3 后主角回到石像旁站住，不再触发完成。
- **期望**：`accept → fight → return → complete`，75 s 内完成。
- **实际**：t=0.6 fight，t=7.6 return（kills=3），随后 67.4 s 原地 Idle；`quest.stage=return`，`quest_ok=false`，exit 1。
- **根因（代码 + 实测坐标）**：主角停在 `(0.69, 0, 4.52)`，与发布者 `(-1, 0, 1.8)` 水平距离 **3.202 m**，`garden_hero.gd:203` 的判断是 `<= 3.2`，差 0.002 m 不触发 `turn_in()`。
  交付点 `turn_in_position=(0.9,0,4.2)` 与主角在同一个 1 m A* 网格 `(18,22)`，格心 `(0.5,4.5)`；`find_path()` 返回该格心，距主角 0.191 m，小于 `_follow_path()` 的 0.2 m 到达阈值，被立即消费并 `_path.clear()`；下一帧 `_path.is_empty()` 重新规划同一格，形成原地循环。
- **建议**（未改代码）：交付判定放宽到 ≥3.5 m，或让 `turn_in_position` 与主角不同格/给最终路径点加“进入阈值即交付”，并补一条任务链自动回归测试（本次 `tools/qa_cycle3_hero.gd` 可复用）。

### BUG-02（P1）主角不响应 `GARDEN_FORCE_PROCEDURAL`

- **复现**：`GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --headless -s tools/qa_cycle3_hero.gd`。
- **期望**（README:50）：Knight 回退到 GardenGirl，小女孩可见。
- **实际**：`mode=knight`、`model_visible=false`、`knight=true`；环境变量只让 3 名巡逻 NPC 回退并打印 3 条 WARNING，主角无回退日志。
- **根因**：`scripts/garden_hero.gd` 的 `_build()` / `_build_knight()` 没有环境变量判断；该判断只存在于 `scripts/garden_patrol.gd:325/376`。
- **建议**：在 `_build()` 前检查 `OS.has_environment("GARDEN_FORCE_PROCEDURAL")`，命中则跳过 `_build_knight()` 并保留 `_model.visible=true`，打印一次回退 WARNING。

### BUG-03（P3，证据卫生）截图命名与尺寸口径不一致

- 本轮截图实际 1920×1080（`screenshot_patrol.gd` 内 `SubViewport.size=1920×1080`），不是调用方口径的 1440×810；且新图仍沿用 `cycle2_` 文件名。只影响证据检索，不影响游戏。未改工具。

---

## 5. 截图清单（本轮 17:30–17:31 重拍）

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 时间 | 尺寸 | 目检结论 |
|---|---|---|---|
| `cycle2_mixed_cast.png` | 17:31 | 1920×1080 | 三名 KayKit 同框：左绿兜帽 Rogue、中红发 Rogue（提灯）、右 Knight；无 T-pose |
| `patrol_wide_dusk.png` | 17:30 | 1920×1080 | Knight 在石圈战斗中（前倾挥砍姿态），非倒地/T-pose；三巡逻在位 |
| `patrol_lantern_dusk.png` | 17:31 | 1920×1080 | 前景提灯人右手提灯；背景 Knight 持盾站立，无 T-pose |
| `patrol_lantern_night.png` | 17:31 | 1920×1080 | 同机位夜景；背景 Knight 侧身持盾，无 T-pose |
| `cycle2_960x540.png` | 17:31 | 960×540 | 内部源画面，LINEAR/MSAA 生效 |
| `patrol_sweeper.png` / `patrol_fox.png` | 17:31 | 1920×1080 | 扫园人/狐正常，无脚本错误 |

---

## 6. 残留风险 / 回归清单

- **P0 未清**：任务链回交卡死（BUG-01）；**P1 未清**：主角回退缺失（BUG-02）。修复后必须重跑：无头 600 帧、`tools/qa_cycle3_hero.gd`（正常 + `GARDEN_FORCE_PROCEDURAL=1`）、截图 mixed/wide/lantern。
- **性能**：本轮 avg 36.8–37.8 / min 25–31（load 4.93–7.89），未做 Knight 显示/隐藏受控 A/B，不能据此判定 Knight 渲染成本；建议下一轮在低负载下用交错 A/B 复测，勿引用历史 63/52 数值。
- **比例**：Knight 可见 AABB 高 **1.869 m**，NPC Rogue 约 1.618 m；混合阵营截图中 Knight 比 NPC 略高。符合“0.74 缩放”实现，但是否为美术期望需 signoff。
- **攻击观感**：`1H_Sword` 等武器全部隐藏，Chop 动画手中无剑（保留 Round_Shield）；截图中读作持盾劈砍/空手，建议美术确认是否保留一把主手剑。
- **回归清单（改动前后均需复测）**：巡逻路线最小间距（pond/circle/statue/pillar）、5 键/UI 游人开关、相机 16°/5.8 与广角、无头 0 ERROR/WARNING、任务链 complete、倒地/复活双模型可见性、Knight 动画 Idle/Running_A/Chop、`GARDEN_FORCE_PROCEDURAL=1` 主角与三 NPC 回退。
