# Cycle 3 · 04 QA 终验（delta）

> 执行：QA 负责人 | 时间：2026-10-31 17:40–17:45（CST） | 被测：`godot-garden/` 工作区
> 只读声明：未修改游戏逻辑。新增 1 个只读探针 `tools/qa_cycle3_halo_probe.gd`（核查光晕节点是否真实创建，结束释放场景）。
> 上轮报告：`docs/agency/cycle-3/02-qa-verify.md`（阻塞：任务回交 3.202m、主角回退缺失）。

---

## 1. 结论

**条件放行。**

- 两个历史阻塞均已关闭：任务链 `accept → fight → return → complete` 实测完成；`GARDEN_FORCE_PROCEDURAL=1` 时主角回退为 GardenGirl，Knight 不存在，三名 NPC 同步回退。
- Knight 佩剑/无盾、攻击/倒地复活、巡逻/开关、无头 600 帧、截图矩阵均 PASS；无 T-pose、无 SCRIPT ERROR。
- **唯一条件项（P2，不阻塞玩法）**：本轮声称的“1.4m 宽光晕”在运行时未实例化（`_lantern_halo_wide == null`）。截图中可见的宽暖光来自既有 4.5m `halo_far`，不是新增层；需收口前补创建调用或明确口径。

---

## 2. 环境与命令

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6，Intel Core i7-5650U（4 逻辑核），Intel Iris 6000 |
| Godot | 4.6.stable.official.89cea1439 |
| 渲染 | 内部 960×540、MSAA 2×、display LINEAR（`qa_cycle2_recheck` 实测 `viewport=(960,540) msaa_3d=1 display_filter=2`） |
| 负载 | 1 分钟均值 4.25 → 4.55 → 4.94（`uptime`） |
| 运行方式 | 无头探针用 `--headless`；帧率/截图用窗口；无 `timeout` 命令 |

```bash
cd /Users/ks_128/Documents/modelfw_demo

# 1. 主角探针（窗口 1280×720；另跑 headless 等价口径）
godot --path godot-garden --resolution 1280x720 -s tools/qa_cycle3_hero.gd
godot --path godot-garden --headless -s tools/qa_cycle3_hero.gd

# 2. 回退
GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --headless -s tools/qa_cycle3_hero.gd

# 3. 无头 600 帧 + 巡逻探针
godot --path godot-garden --headless --quit-after 600
godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd

# 4. 截图矩阵
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd

# 5. 回归/补充只读探针
godot --path godot-garden --headless -s tools/qa_key_toggle.gd
godot --path godot-garden --headless -s tools/qa_cycle2_recheck.gd
godot --path godot-garden --headless -s tools/qa_cycle3_halo_probe.gd
```

---

## 3. 结果表

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 1 | 主角任务链（窗口 1280×720） | 75s 内 complete，kills=3 | `t=7.5s stage=complete kills=3`；transitions=`[accept, fight, return, complete]`；exit 0；总墙钟 **19.1s** | **PASS** |
| 2 | 主角任务链（headless 等价） | 同上 | `t=9.2s stage=complete kills=3`；exit 0；总墙钟 **16.3s** | **PASS** |
| 3 | 回交位置 | 距发布者 ≤3.45m 触发 | 完成时 `(1.13, 0, 4.5)`，距发布者 `(-1,0,1.8)` 水平 **3.41m**（上轮 3.202m） | **PASS** |
| 4 | Knight 挂载/缩放/隐藏 | 0.74、yaw π；7 项隐藏；保留 1H_Sword | `root_scale=(0.74,0.74,0.74) root_yaw=3.1416`；`hidden_found` 7/7 含 `Round_Shield`，`hidden_visible=[]`；可见含 `1H_Sword` | **PASS** |
| 5 | 攻击/倒地/复活 | Chop 出现并回 Idle/Run；倒地双模型隐藏；复活 Knight 可见、HP 满、回出生点 | 9 次 Chop（speed 1.2），post=`[Idle, Running_A]`；down `hp=0 model=false knight=false ring=false`；respawn `hp=220/220 knight=true ring=true dist_spawn=0.000` | **PASS** |
| 6 | `GARDEN_FORCE_PROCEDURAL=1` 主角回退 | Knight 不存在、GardenGirl 可见 | `mode=procedural model_is_girl=true model_visible=true knight=false player=false`；`QA_CYCLE3_FALLBACK_PASS`；exit 0；墙钟 **2.77s** | **PASS** |
| 7 | 回退时 NPC | 三名 NPC 均回退 | 3 条 `GardenPatrol: Rogue unavailable (GARDEN_FORCE_PROCEDURAL)` WARNING（lantern/sweeper/fox 各 1） | **PASS** |
| 8 | 无头 600 帧 | 0 条 SCRIPT ERROR/ERROR/WARNING，exit 0 | exit **0**；墙钟 **9.17s**；日志仅 banner；grep 0 匹配 | **PASS** |
| 9 | 巡逻探针（单次） | `PROBE_PATROL_OK`、间距阈值、toggle 双向 | exit 0；墙钟 **33.47s**；travelled **8.1 / 6.2 / 10.2**；toggle `hidden_ok=true shown_ok=true` | **PASS** |
| 10 | 巡逻最小间距 | pond>4.8 / circle>2.6 / statue>1.8 / pillar>1.0 | lantern 6.38/6.43/3.32/5.92；sweeper 12.38/3.31/9.56/10.73；fox 12.99/10.73/9.41/1.71 | **PASS** |
| 11 | 截图矩阵 | exit 0、0 ERROR/WARNING、无 T-pose | exit 0；墙钟 **32.03s**；12 张；日志 0 错误；目检见 §5 | **PASS** |
| 12 | 键盘/UI 开关回归 | 5 键、F1、UI 按钮双向 | `QA_KEY5 true/true/true`；`QA_F1 true/true/true`；`QA_UI_BUTTON true/true`；`QA_KEY_TOGGLE_OK` | **PASS** |
| 13 | 相机/渲染回归 | 5.80m / 16.0°、960×540/MSAA/LINEAR | `camera distance=5.80 pitch=16.0`；`viewport=(960,540) msaa_3d=1 display_filter=2` | **PASS** |
| 14 | 新增宽光晕 | 运行时存在 1.4m wide 层（α=glow×0.45、z+0.28） | `HALO wide=NULL`；rig 仅 3 个 Sprite3D（core 0.80 / outer 2.20 / far 4.50）；far α=0.044 | **FAIL（P2）** |
| 15 | 性能 | 仅记录，不硬判 | `PATROL_FPS avg=39.0 min=34.0 samples=12`；A/B `hidden=31.2 shown=33.5 cost=-2.3`（噪声）；load 4.25–4.94 | **记录 / INCONCLUSIVE** |

**关键原始输出**

```text
HERO_STAGE t=7.5 stage=complete kills=3 hero=(1.13, 0.0, 4.5) hp=195/220
HERO_QUEST stage=complete kills=3 transitions=["accept", "fight", "return", "complete"] quest_ok=true elapsed=7.5s
HERO_ANIM seen=["Running_A", "1H_Melee_Attack_Chop", "Idle"] attack_starts=9 post_attack=["Idle", "Running_A"] attack_ok=true
HERO_DOWN hp=0 downed=true model_visible=false knight_visible=false ring_visible=false
HERO_RESPAWN hp=220/220 downed=false model_visible=false knight_visible=true ring_visible=true dist_spawn=0.000
QA_CYCLE3_HERO_PASS
```

```text
HERO_BUILD force_proc=true mode=procedural model_is_girl=true model_visible=true knight=false player=false
HERO_FALLBACK expected=procedural actual=procedural model_visible=true knight=false
QA_CYCLE3_FALLBACK_PASS
WARNING: GardenPatrol: Rogue unavailable (GARDEN_FORCE_PROCEDURAL), using procedural model  ×3
```

```text
PATROL Patrol_lantern role=lantern travelled=8.1 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.92
PATROL Patrol_sweeper role=sweeper travelled=6.2 min_pond=12.38 min_circle=3.31 min_statue=9.56 min_pillar=10.73
PATROL Patrol_fox role=fox travelled=10.2 min_pond=12.99 min_circle=10.73 min_statue=9.41 min_pillar=1.71
PATROL_FPS avg=39.0 min=34.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=31.2 shown=33.5 cost=-2.3
PROBE_PATROL_OK
```

```text
HALO core visible=true alpha=0.177 world_m=0.800
HALO outer visible=true alpha=0.141 world_m=2.200
HALO far visible=true alpha=0.044 world_m=4.500
HALO wide=NULL
HALO rig_sprite_count=3 names=["@Sprite3D@892", "@Sprite3D@893", "@Sprite3D@894"]
```

---

## 4. Bug 列表

### BUG-01（P2，不阻塞玩法）新增宽光晕未实例化

- **复现**：`godot --path godot-garden --headless -s tools/qa_cycle3_halo_probe.gd`；或 `grep -n "_lantern_halo_wide" scripts/garden_patrol.gd`。
- **期望**（`docs/迭代记录.md:191`）：提灯新增 **1.4m 宽光晕**，α=glow×0.45，z 后移 0.28。
- **实际**：运行时 `wide=NULL`，灯笼 rig 只有 3 个 Sprite3D（0.80/2.20/4.50m）；`scripts/garden_patrol.gd:70` 声明、`:125-127` 更新，但构造函数 `:490-493` 只创建 core/outer/far，**没有任何 `_lantern_halo_wide = _make_lantern_halo(...)`**。
- **影响**：截图中广角夜灯的宽暖光来自既有 `halo_far`（4.5m，α≈0.04），不是本轮新增层；迭代记录的 1.4m/α0.45 声明与代码不一致。玩法/任务不受影响。
- **建议**（未改代码）：在 `:493` 后补 `_lantern_halo_wide = _make_lantern_halo(1.4)`，并让 `_make_lantern_halo()` 支持 1.4m 的 z=0.28；或删除该变量并在文档中明确“宽光晕=far 4.5m”。

### BUG-02（P3，证据卫生）截图为 1920×1080 且沿用 cycle2 命名

- `screenshot_patrol.gd` 内 SubViewport 固定 1920×1080，命令行 `--resolution 1440x810` 不会改变输出；`cycle2_mixed_cast.png` 仍用 Cycle 2 名称。内容正确，只影响检索/口径。未改工具。

---

## 5. 截图清单（本轮 17:41:43–17:42:05 重拍）

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 时间 | 尺寸 | 目检结论 |
|---|---|---|---|
| `cycle2_mixed_cast.png` | 17:42:05 | 1920×1080 | 左绿兜帽 Rogue、中红发 Rogue 提灯、右 Knight；**Knight 右手佩剑、无盾**；无 T-pose |
| `patrol_lantern_dusk.png` | 17:41:50 | 1920×1080 | 前景提灯人右手提灯；背景 Knight 背身持剑，无盾、无 T-pose |
| `patrol_lantern_night.png` | 17:41:53 | 1920×1080 | 夜景同机位；Knight 背身，银色剑刃可见，无盾、无 T-pose |
| `cycle1_wide_night.png` | 17:41:58 | 1920×1080 | 广角夜：街灯/提灯宽暖区可见；Knight 行走姿态；无 T-pose。**宽暖光来源为 `halo_far`，wide 层 null（BUG-01）** |
| `patrol_wide_dusk.png` | 17:41:43 | 1920×1080 | 石圈/池塘全景；Knight 与巡逻在位，无 T-pose |
| `cycle1_noon.png` | 17:41:56 | 1920×1080 | 正午广角，构图/角色正常 |
| `patrol_sweeper.png` / `patrol_fox.png` | 17:42:00 / 17:42:02 | 1920×1080 | 扫园人/狐正常出镜（扫帚触地为既有 P2 观察项） |
| `cycle2_960x540.png` | 17:41:51 | 960×540 | 内部源画面，MSAA/LINEAR 生效 |

截图工具日志 0 ERROR/WARNING；`SCREENSHOT:` 12 条全部落盘。

---

## 6. 残留风险 / 回归清单

- **条件项**：BUG-01 宽光晕未实例化；修后必须重跑 `qa_cycle3_halo_probe.gd` + `screenshot_patrol.gd` 的 `cycle1_wide_night.png`，并核对迭代记录数值口径。
- **性能**：avg 39.0 / min 34.0，load 4.25–4.94；A/B hidden 31.2 vs shown 33.5（cost -2.3）为噪声，不能判定 NPC 渲染成本。绝对值受本机负载主导，只记录不硬判。
- **既有 P2（非本轮引入）**：驻足扫帚摆动实测 min_y=-0.147、max_y=+0.048（上轮 -0.121/+0.196，相位相关），仍超出 |y|≤0.03 的美术目标。
- **攻击探针口径**：任务链内已采样 9 次 Chop 与攻击后 Idle/Running_A；完成时怪物全灭，`HERO_ATTACK_PROBE skipped=no_live_monster` 属预期，不影响 PASS。
- **截图口径**：1920×1080 + `cycle2_` 命名（BUG-02），仅证据卫生。
- **下次回归必测**：任务链 complete、`GARDEN_FORCE_PROCEDURAL=1` 主角+三 NPC 回退、无头 600 帧干净、`probe_patrol.gd`（avg/min、travelled、min 距离、toggle）、相机 5.80/16.0、5 键/F1/UI 按钮、mixed/lantern/wide 截图、Knight 佩剑无盾、倒地复活。
