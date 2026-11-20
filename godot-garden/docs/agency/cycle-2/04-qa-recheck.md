# Cycle 2 · 04 QA 复审（Delta）

> 执行：QA 负责人 | 时间：2026-10-31 16:36–16:47（CST） | 阶段：Cycle 2 两个未关 P0 复审
> 被测：`godot-garden/`；`garden_patrol.gd` 16:32:40、`garden_scene.gd` 15:50:07、`screenshot_patrol.gd` 16:28:11。
> 只读声明：未修改任何游戏逻辑。新增 1 个只读探针 `tools/qa_cycle2_recheck.gd`（打印挂点/倍速/狐狸 AABB/骨骼朝向/扫帚触地/光晕，结束释放）；重跑截图工具覆盖了 16:33 旧图（新图 16:40）。

---

## 1. 结论

**条件放行（Conditional Pass）。**

- **03-qa-verify 的两个未关 P0 均已关闭**：灯笼到手距离 **0.0353 m**（阈值 <0.08）、`Spellcast_Raise` 实测 **1.300×**（1 s 实际推进 1.318），截图目检灯笼在右手中。
- **狐狸 / 扫帚 / 无头 / 巡逻 / 开关 / 机位 / 分辨率均 PASS**。
- **不能无条件放行的原因**：程序声称的“夜灯远光晕 4 m”**未实现为光晕精灵**——`_lantern_halo_far` 声明并在 `set_night()` 里被驱动，但从未创建（探针输出 `halo_far=null`）；当前只有 1.55 m 外圈光晕 + 4.0 m 的 OmniLight range。广角夜景手持灯暖光区实测仍约 **20×26 px**，低于 brief P0-3 的 **70 px** 线。若本轮门禁含 P0-3，则 P0-3 仍未关闭。
- 性能受控 A/B 3 连跑 cost 中位 **6.5 / 8.7 / -1.7 FPS**，本机 load 4.6–5.4，噪声 > 巡逻成本，判 **INCONCLUSIVE**，不作为 PASS。

**放行条件（按优先级）**

1. 若要关闭 P0-3：创建 `_lantern_halo_far`（4 m）或书面撤回“4 m 远光晕”口径；重测默认 48°/27.5 m、00:00 手持灯暖光区 ≥70 px。
2. 性能需在低负载（load <3）下复跑 3 连跑中位；本机当前数据不可判。
3. P2（不阻塞）：驻足扫帚摆动幅度过大（最低 -0.121 m、最高 +0.196 m，相对地面）。

---

## 2. 环境与命令

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6，Intel Core i7-5650U（4 逻辑核），Intel Iris 6000 |
| Godot | 4.6.stable.official.89cea1439，Vulkan 1.2.283，Forward Mobile |
| 渲染 | 内部 960×540、MSAA 2×、display LINEAR；截图外框 1920×1080；探针窗口 1280×720 |
| 系统负载 | 巡逻探针 3 连跑 **5.61–7.05**；受控性能 3 连跑 **4.62–5.44**（4 核本机，单次 FPS 无判决力） |
| 截图时效 | 代码 16:32:40；新截图 **16:40:40–16:40:54**（晚于代码） |

```bash
cd /Users/ks_128/Documents/modelfw_demo

# 1. 无头 600 帧
godot --path godot-garden --headless --quit-after 600 > /tmp/cyc2_recheck_headless.log 2>&1

# 2. legacy 巡逻探针 ×3
for i in 1 2 3; do /usr/bin/time -p godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd; done

# 3. 本轮新增只读探针
godot --path godot-garden --headless -s tools/qa_cycle2_recheck.gd

# 4. 截图矩阵重拍
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd

# 5. 受控 A/B 性能 ×3
for i in 1 2 3; do godot --path godot-garden --resolution 1280x720 -s tools/qa_probe_patrol_perf.gd; done
```

---

## 3. 结果表

### 3.1 两个未关 P0 与已改动项

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 1 | 灯笼原点 → `handslot_r`（PAUSE） | <0.08 m | **0.0353 m**（rig 1.604,1.061,3.283；手 1.623,1.090,3.290）；灯心距手 0.3115 m；`ROGUE_LANTERN_OFFSET=(0.02,-0.03,0)` | **PASS** |
| 2 | 灯笼原点 → 手（WALK） | <0.08 m | **0.0453 m**；灯心距手 0.3232 m；`Walking_A` speed 1.29 | **PASS** |
| 3 | 灯笼在右手（目检） | 手持可读 | `patrol_lantern_dusk/night.png` 右手腕/拳贴住灯杆底部，灯笼随手臂抬起；`cycle2_mixed_cast.png` 同 | **PASS** |
| 4 | `Spellcast_Raise` 倍速 | 1.3× 循环 | `anim=Spellcast_Raise len=2.100 loop=1 playing=true get_playing_speed=**1.300** speed_scale=1.000`；1 s 实际推进 **1.318**（+1.4%） | **PASS** |
| 5 | 狐狸 AABB 长度 | 约 1.7 m | **1.723×0.869×0.486 m**（length 1.723，height 0.869）；scale 0.011 | **PASS** |
| 6 | 狐狸朝向 = 根 -Z | 角度 ≈0° | `model_root_yaw=3.142(π)`；model +Z=(0.992,0,-0.124) vs root -Z=(0.992,0,-0.124)，夹角 **0.00°**；`dot(hip→head, model+Z)=1.0000`、`dot(neck→head, model+Z)=1.0000` | **PASS** |
| 7 | 狐狸目检 | 面朝前 | `patrol_fox.png` 可见白色口鼻/黑鼻、双耳内侧白，正面朝机位；无尾巴入镜（正对镜头透视） | **PASS** |
| 8 | 扫帚斜握/触地 | 行走触地 | walk `tilt=-0.55`，扫帚最低点 **-0.004 m**（贴地）；手→BroomRig **0.0458 m**；`patrol_sweeper.png` 刷头压在地面 | **PASS** |
| 9 | 扫帚驻足摆动 | 始终贴地（参考） | 摆动 1.2 s：最低 **-0.121 m**、最高 **+0.196 m**（地面=0） | **P2 观察项** |
| 10 | 夜灯远光晕 4 m | 4 m 光晕 | `halo_core=0.50 m`、`halo_outer=1.55 m`、**`halo_far=null`**；仅 `light_range=**4.00**`、`light_energy=0.120`；广角手持灯暖光区 **约 20×26 px**（连通域 7×26 + 12×8），低于 70 px | **FAIL（远光晕未实现）/ 4 m OmniLight 存在** |
| 11 | 脸 p95 夜（框 850,380–1010,590） | <240 | 16:33 旧图 **216**（max 255，>240 2.26%）；16:40 新图 **185**（max 255，>240 0.80%） | **PASS** |
| 12 | 脸 p95 黄昏（同 ROI） | <240 | 16:33 旧图 **233**（max 255，>240 4.26%）；16:40 新图 **197**（max 255，>240 1.76%） | **PASS** |
| 13 | 脸颊子 ROI（框 950,475–1040,600） | 参考 <240 | 16:33：dusk p95 207 / night 238；16:40：dusk 186 / night 199（>240 均为 0%） | **PASS（余量小）** |

**关键原始输出**

```text
RECHECK viewport=(960, 540) msaa_3d=1 ssaa=0 display_filter=2
RECHECK lantern anim=Spellcast_Raise len=2.100 loop=1 is_playing=true get_playing_speed=1.300 speed_scale=1.000
RECHECK lantern hand_r_y=1.090 hand_l_y=0.429 raised=true
RECHECK lantern rig=(1.604, 1.061, 3.283) hand_r=(1.623, 1.09, 3.29) gap_hand_rig=0.0353 gap_hand_lamp=0.3115 offset=(0.02, -0.03, 0.0)
RECHECK lantern anim_advance_1s=1.318 expected_1.3x=1.300 speed=1.300 anim_now=Spellcast_Raise
RECHECK lantern halo_core=scale=0.78 a=0.06 vis=true halo_outer=scale=2.42 a=0.06 vis=true halo_far=null light_range=4.00 light_energy=0.120
RECHECK lantern halo_outer_world_m=1.550 core_world_m=0.500 tex_w=64.0 pixel_size=0.010
RECHECK lantern walking gap_hand_rig=0.0453 gap_hand_lamp=0.3232 anim=Walking_A speed=1.29
RECHECK sweeper hand_y=0.502 broom_rig=(10.618, 0.474, 6.923) gap_hand_broom=0.0458 anim=Interact speed=1.30
RECHECK sweeper broom_bottom_pause min_y=-0.121 max_y=0.196 (ground=0)
RECHECK sweeper broom_bottom_walk min_y=-0.004 tilt=-0.55
RECHECK fox aabb_size=(1.723, 0.869, 0.486) length=1.723 height=0.869 yaw_root=-1.446 model_root_yaw=3.142 scale=(0.011, 0.011, 0.011)
RECHECK fox dirs model_plusZ=(0.992, 0.0, -0.124) root_minusZ=(0.992, 0.0, -0.124) angle_model_vs_root=0.00 deg
RECHECK fox dirs dot(hip->head,model+Z)=1.0000 dot(hip->head,root-Z)=1.0000 dot(neck->head,model+Z)=1.0000
RECHECK camera distance=5.80 pitch=16.0 pos=(-3.65, 2.6, 2.89) target=(1.92, 1.0, 3.2)
```

> 狐狸尾骨名 `b_Tail_01` 未找到（返回 inf），不影响朝向结论；`b_Head_05 / b_Neck_04 / b_Hip_01` 存在。

### 3.2 稳定性、巡逻、开关、回归

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 14 | 无头 600 帧 | 0 SCRIPT ERROR/ERROR/WARNING，exit 0 | grep **0 匹配**；exit **0**；日志仅 2 行 banner | **PASS** |
| 15 | 巡逻位移 | travelled >4.2 | lantern **9.3/9.7/8.8**；sweeper **6.4/6.8/6.2**；fox **9.7/10.8/11.1** | **PASS** |
| 16 | 最小间距 | pond>4.8 / circle>2.6 / statue>1.8 / pillar>1.0 | lantern 6.39 / 6.43–6.44 / 3.32 / 5.90–5.93；sweeper 11.84–12.35 / 3.29–3.32 / 9.01–9.53 / 10.27–10.70；fox 12.41–12.98 / 10.66–10.73 / 8.80–9.80 / 1.64–1.71 | **PASS** |
| 17 | toggle 链路（探针内） | hidden_ok=true, shown_ok=true | 3/3 次 `PATROL_TOGGLE hidden_ok=true shown_ok=true` | **PASS** |
| 18 | 探针整体 | `PROBE_PATROL_OK`、exit 0 | 3/3 次 `PROBE_PATROL_OK`；real 38.86 / 38.04 / 37.73 s | **PASS** |
| 19 | 近景机位 | 16°/5.8 m | **distance=5.80 pitch=16.0** | **PASS** |
| 20 | 960×540 / MSAA / LINEAR | 960×540、MSAA 2×、LINEAR | `viewport=(960,540) msaa_3d=1 ssaa=0 display_filter=2`；`cycle2_960x540.png` **960×540** | **PASS** |
| 21 | 截图尺寸/时效 | 1920×1080、晚于代码 | 6 张核心图均 1920×1080，**16:40:40–16:40:54**；代码 16:32:40 | **PASS** |

**巡逻原始输出（3 连跑）**

```text
PATROL Patrol_lantern role=lantern travelled=9.3 min_pond=6.39 min_circle=6.43 min_statue=3.32 min_pillar=5.90
PATROL Patrol_sweeper role=sweeper travelled=6.4 min_pond=12.16 min_circle=3.29 min_statue=9.33 min_pillar=10.53
PATROL Patrol_fox role=fox travelled=9.7 min_pond=12.98 min_circle=10.73 min_statue=9.80 min_pillar=1.71
PATROL_FPS avg=24.0 min=13.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=55.8 shown=49.3 cost=6.5
PROBE_PATROL_OK
（run2 avg=25.4 min=15.0；run3 avg=24.9 min=10.0；三次均 PROBE_PATROL_OK）
```

> FPS 24.0/25.4/24.9、min 13/15/10，load 5.61–7.05；单次 A/B cost 6.5/15.7/-12.8 说明顺序采样被负载主导。**绝对值不判回退**。

### 3.3 受控 A/B 性能（3 连跑）

| 运行 | shown 中位 | hidden 中位 | cost 中位 | shown draws | hidden draws | draw delta |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 38.9 | 45.4 | **6.5** | 1296.8 | 1247.0 | -49.8 |
| 2 | 41.3 | 50.0 | **8.7** | 1296.0 | 1247.0 | -49.0 |
| 3 | 46.2 | 44.6 | **-1.7** | 1296.8 | 1247.2 | -49.6 |
| **跨轮中位** | **41.3** | **45.4** | **6.5** | — | — | **~49.5** |

- 门槛：cost ≤2.4 FPS（或 ≤2 FPS）；draw delta ≤155。**draw delta 稳定 ~49.5，与 Cycle 2 的 49.5 一致，未新增 draw 成本**。
- FPS cost 2/3 轮超线、1 轮为负；load 4.62–5.44、单 block 波动 29.8–54.4。**绝对/相对 FPS 均判 INCONCLUSIVE，不硬判 PASS/FAIL**。

---

## 4. Bug 列表

### BUG-05（P1，若 P0-3 在门禁内则阻塞）夜灯 4 m 远光晕未实现

- **复现**：`godot --path godot-garden --headless -s tools/qa_cycle2_recheck.gd` → `RECHECK ... halo_far=null light_range=4.00`；代码 `garden_patrol.gd:69` 声明 `_lantern_halo_far`、`garden_patrol.gd:121-123` 在 `set_night()` 驱动，但 `_build_model_lantern()`（486–489）只创建 0.50 m core 与 1.55 m outer，从未实例化 far。
- **期望**：4 m 远光晕精灵（或 brief 明确改为 OmniLight range 4 m）。
- **实际**：`halo_far=null`；仅 4.0 m OmniLight 与 1.55 m 外圈光晕。默认广角 00:00 手持灯暖光区 **约 20×26 px**（阈值 70 px），旁边路灯光晕更大。
- **建议**（未改代码）：在 `_build_model_lantern()` 增加 `_lantern_halo_far = _make_lantern_halo(4.0)`，alpha 沿用 `glow*0.05`；重拍 `cycle1_wide_night.png` 并做暖光区连通域统计。

### BUG-06（P2）驻足扫帚摆动离地/入地

- **复现**：探针 `RECHECK sweeper broom_bottom_pause min_y=-0.121 max_y=0.196`；`_update_broom_rig()` 驻足 `tilt=-0.72+sin(_time*3.2)*0.22`。
- **期望**：刷头始终贴地（|y| ≤0.03 m）。
- **实际**：摆动周期内在 **-0.121 m（入地 12 cm）** 与 **+0.196 m（离地 20 cm）** 之间；行走态 -0.004 m 正常。截图恰好落在贴地相位。
- **影响**：驻足特写穿帮；不阻塞本轮两个 P0。

### BUG-07（P3，风险）脸 ROI 与随机 PAUSE 相位耦合

- **复现**：`seek(randf()*len)`（`garden_patrol.gd:587`）导致抬灯相位随机；同一 ROI 两次捕获 dusk/night：16:33 = **233/216**（恰好匹配程序声称值），16:40 = **197/185**。
- **影响**：p95 波动 185–233，两次均 <240，但最小余量仅 7；ROI 会包含灯框/灯芯时数值升高。
- **建议**：截图探针固定 `seek()` 相位，或把灯笼像素从 ROI 剔除后再统计。

---

## 5. 截图清单（本轮 16:40 重拍）

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 时间 | 尺寸 | 内容/结论 |
|---|---|---|---|
| `patrol_lantern_dusk.png` | 16:40:40 | 1920×1080 | 右手提灯，拳贴灯杆；脸 p95=197 |
| `patrol_lantern_night.png` | 16:40:43 | 1920×1080 | 00:00 同机位；脸 p95=185 |
| `patrol_sweeper.png` | 16:40:50 | 1920×1080 | 斜握扫帚，刷头压地；背面视角 |
| `patrol_fox.png` | 16:40:52 | 1920×1080 | 正面朝机位（白口鼻/黑鼻可见）；AABB 长 1.723 m |
| `cycle2_mixed_cast.png` | 16:40:54 | 1920×1080 | 灯笼在右手、遮住部分脸；女孩右缘、章鱼入镜 |
| `cycle1_wide_night.png` | 16:40:48 | 1920×1080 | 广角手持灯暖光约 20×26 px；路灯光晕更大 |
| `cycle2_960x540.png` | 16:40:40 | **960×540** | 内部源画面，LINEAR/MSAA 生效 |

> 说明：16:33 旧图已被本次重拍覆盖；§3.1 的 233/216 为覆盖前实测，16:40 新图 197/185，两组均记录。

---

## 6. 残留风险

1. **P0-3 广角剪影仍未关闭**：4 m 远光晕无实现（BUG-05），暖光区 ~20×26 px <70 px；若本轮门禁含 P0-3，不可无条件放行。
2. **性能不可判**：load 4.6–7.05；受控 A/B cost 中位 6.5/8.7/-1.7，draw delta 稳定 ~49.5。只有 draw 成本可判“未回退”，FPS 不作为 PASS。
3. **脸 p95 相位耦合**：185–233 波动，最小余量 7；建议固定 PAUSE 相位或剔除灯光像素后复测。
4. **灯笼自照明/构图**：OmniLight 仍在角色局部 `(0.62,0.76,-0.34)`（根灯），不在灯芯；近景/mixed_cast 中灯框会遮住部分脸。本轮只验证“手持”，未改光位。
5. **扫帚驻足摆动**：-0.121/+0.196 m（BUG-06），特写相位依赖。
6. **本轮未复测项**（时间盒）：`GARDEN_FORCE_PROCEDURAL` 回退、`5`/F1/UI 按钮链路、90 帧序列逐帧脚滑。沿用 Cycle 2 的 PASS 结论；本轮改动只触及模型姿态/挂点，回归风险低但未重测。
7. **截图工具随机相位**：每次重拍灯笼相对脸的位置不同，跨轮对比 p95 时需固定相位。

---

## 7. 一句话

**两个 QA P0 已关闭（手→灯杆 0.0353 m、Spellcast 实播 1.318×），狐狸 1.723 m/朝向 0.00°、扫帚行走贴地、无头/巡逻/开关/机位全部 PASS；但“4 m 远光晕”未实现（`halo_far=null`，广角暖光 ~20×26 px <70 px），性能受 load 4.6–7.05 主导不可判，故整体判条件放行。**
