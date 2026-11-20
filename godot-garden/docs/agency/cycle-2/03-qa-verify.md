# Cycle 2 · 03 QA 验收（04 实现后）

> 执行：QA 负责人 | 时间：2026-10-31 16:00–16:12（CST） | 阶段：Cycle 2 验收
> 被测：`godot-garden/` 工作区（`garden_patrol.gd` 15:56:30、`garden_scene.gd` 15:50:07、`screenshot_patrol.gd` 15:59:22；整个 `godot-garden/` 在 git 中未跟踪）
> 只读声明：未修改任何游戏逻辑。新增 1 个只读 QA 探针 `tools/qa_cycle2_verify.gd`（打印视口/挂点/动画/模型尺寸，不改状态，结束释放）。

---

## 1. 结论

**条件放行（Conditional Pass）。不是无条件放行，也不是全量阻塞。**

- 稳定性、巡逻、回退、`5` 键/UI、960×540/LINEAR/MSAA、16°/5.8 机位、脸 p95、小狐比例均通过。
- **P0 条件 1（灯笼右手）**：代码挂在 `handslot_r`、右手确实抬起，但 `LanternRig` 原点距手掌 **0.349 m**（灯心距手 **0.429 m**；杆轴水平距离约 ≥0.286 m），截图中右手为空、灯笼悬在手侧，**视觉上不是“提灯”**。按 brief P0-2“灯笼在右手中”判 **FAIL**；这是 Cycle 1“脱手”债务的复发。
- **P0 条件 2（PAUSE 1.3×）**：`Spellcast_Raise` 正确循环（loop=1），但运行时 `get_playing_speed()=1.00`，brief 要求 1.3×，判 **FAIL（规格偏差，低风险）**。
- P1 条件：修挂点后需重测脸 p95（当前黄昏 216 / 夜间 215，均 <240，但夜间脸颊子 ROI p95=255、>240 占 13.18%，余量已比 Cycle 1 小）；性能绝对值未复现 scorecard 的 63.3/52（见 §3.4），受本机负载主导，只对“巡逻相对成本”判 PASS。

**关闭条件（缺一不可）**

1. 灯笼视觉接在右手：把 `ROGUE_LANTERN_OFFSET` 横向 0.26 m 收到 ≤0.08 m，或加一根手心到灯杆的横向提手；重拍 dusk/night 并复测脸 p95<240。
2. `Spellcast_Raise` 以 1.3× 播放（`play(anim, blend, 1.3)`），或由策划/美术书面把 brief 的 1.3× 改为 1.0×。
3. 性能报告引用本轮 3 连跑中位数，不再引用 scorecard 的 63.3/52（本轮未复现）。

---

## 2. 环境与命令

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6，Intel Core i7-5650U（4 逻辑核），Intel Iris 6000 |
| Godot | 4.6.stable.official.89cea1439，Vulkan 1.2.283，Forward Mobile |
| 渲染 | 内部 960×540，MSAA 2×，display LINEAR；截图外框 1920×1080；探针窗口 1280×720 |
| 系统负载 | 1 分钟均值 **7.59 → 4.65**；`claude` 常驻；4 核本机，任何单次 FPS 都不具判决力 |
| 计时 | 无 `timeout`；探针用 `/usr/bin/time -p`，性能 3 连跑串行执行，期间不做其他负载 |

```bash
cd /Users/ks_128/Documents/modelfw_demo

# 1. 无头 600 帧
godot --path godot-garden --headless --quit-after 600 > /tmp/cyc2_headless.log 2>&1
grep -nE "SCRIPT ERROR|ERROR|WARNING" /tmp/cyc2_headless.log

# 2. legacy 探针 ×3
for i in 1 2 3; do godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd; done

# 3. 程序化回退
GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd

# 4. 受控 A/B 性能 ×3
for i in 1 2 3; do godot --path godot-garden --resolution 1280x720 -s tools/qa_probe_patrol_perf.gd; done

# 5. 5 键 / F1 / UI 按钮
godot --path godot-garden --headless -s tools/qa_key_toggle.gd

# 6. 截图矩阵 + 90 帧序列
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd
godot --path godot-garden --resolution 1280x720 -s tools/capture_patrol_sequence.gd

# 7. 新增只读探针（本报告唯一新增文件）
godot --path godot-garden --headless -s tools/qa_cycle2_verify.gd
```

---

## 3. 结果表（用例 / 阈值 / 实测 / 判定）

### 3.1 稳定性、功能、回退

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 1 | 无头 600 帧 | 0 `SCRIPT ERROR/ERROR/WARNING`，exit 0 | grep 0 匹配；exit **0**；日志仅 Godot banner | **PASS** |
| 2 | legacy 探针（第 1 次，load 7.59） | `PROBE_PATROL_OK`；三 NPC 在走、不穿模 | travelled **7.9 / 6.1 / 10.5**；最小距离 6.38/6.43/3.32/5.91（lantern）、12.43/3.32/9.62/10.77（sweeper）、12.88/10.73/9.22/1.71（fox）；`PROBE_PATROL_OK`；exit 0；real 36.30s | **PASS** |
| 3 | legacy 探针 ×3（avg/min） | 见 §3.4 | avg **31.6 / 46.3 / 53.6**，min **20 / 38 / 50**；中位 **46.3 / 38.0** | **PASS（功能性）/ INCONCLUSIVE（绝对值）** |
| 4 | 程序化回退 | `PROBE_PATROL_OK`；不刷屏 | exit 0；WARNING **3** 条（三个角色各一条一次性日志）；travelled 8.4/5.6/10.4；avg 41.4 min 23.0；toggle true/true；`PROBE_PATROL_OK` | **PASS** |
| 5 | `5` / F1 / UI 按钮 | 三条链路隐藏并恢复 | `QA_KEY5 true/true/true`；`QA_F1 true/true/true`；`QA_UI_BUTTON true/true`；`QA_KEY_TOGGLE_OK`；exit **0**；0 ERROR/WARNING | **PASS** |
| 6 | 巡逻最小间距 | pond>4.8 / circle>2.6 / statue>1.8 / pillar>1.0 | lantern 6.38 / 6.43 / 3.32 / 5.91；sweeper 12.43 / 3.32 / 9.62 / 10.77；fox 12.88 / 10.73 / 9.22 / 1.71 | **PASS** |
| 7 | toggle 链路（探针内） | hidden_ok=true, shown_ok=true | 三次 legacy 与回退均 `PATROL_TOGGLE hidden_ok=true shown_ok=true` | **PASS** |

**关键原始输出**

```text
PATROL Patrol_lantern role=lantern travelled=7.9 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.91
PATROL Patrol_sweeper role=sweeper travelled=6.1 min_pond=12.43 min_circle=3.32 min_statue=9.62 min_pillar=10.77
PATROL Patrol_fox role=fox travelled=10.5 min_pond=12.88 min_circle=10.73 min_statue=9.22 min_pillar=1.71
PATROL_FPS avg=31.6 min=20.0 samples=12
PATROL_FPS_AB hidden=36.2 shown=37.1 cost=-0.9
PATROL_TOGGLE hidden_ok=true shown_ok=true
PROBE_PATROL_OK
```

回退：

```text
WARNING: GardenPatrol: Rogue unavailable (GARDEN_FORCE_PROCEDURAL), using procedural model   ×3
PATROL_FPS avg=41.4 min=23.0 samples=12
PATROL_FPS_AB hidden=59.2 shown=49.3 cost=9.8
PATROL_TOGGLE hidden_ok=true shown_ok=true
PROBE_PATROL_OK
```

> Cycle 1 门禁写“回退只 1 条 WARNING”；Cycle 2 三个角色都走模型管线，回退时每个实例各警告一次，共 3 条，不重复刷屏，属于预期变化。

### 3.2 960×540 / LINEAR / MSAA 与相机

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 8 | 内部分辨率 | 960×540 | `_scene._viewport.size = (960, 540)`；`cycle2_960x540.png` = **960×540**；`u_texel = (0.001042, 0.001852)` = 1/960, 1/540 | **PASS** |
| 9 | 外部分辨率 | 1920×1080 | 近景/广角/扫园人/狐/混合阵营均 **1920×1080** | **PASS** |
| 10 | MSAA / 线性过滤 | MSAA 2×、LINEAR、无 SSAA/TAA | `msaa_3d=1`（MSAA_2X）、`ssaa=0`、`taa=false`、`display_filter=2`（LINEAR）；目检 1920×1080 无像素块/硬锯齿，960×540 源图边缘柔和 | **PASS** |
| 11 | 提灯人机位 | 16° / 5.8 m | 运行时 `distance=5.80 pitch=16.0`；位置 (-3.58, 2.60, 2.95)，目标 (2.00, 1.00, 3.00) | **PASS** |
| 12 | 截图时效 | 图晚于代码 | 代码 15:56:30 / 15:50:07；截图 **16:08:22–16:09:41**；新 `cycle2_960x540.png` / `cycle2_mixed_cast.png` 哈希与 15:56 旧图不同 | **PASS** |

### 3.3 角色与视觉

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 13 | 黄昏脸 p95（ROI 850,380–1010,590） | p95<240 | **p95=216**、max=255、>240 **1.65%**、>=250 1.17% | **PASS** |
| 14 | 夜间脸 p95（同 ROI） | p95<240 | **p95=215**、max=255、>240 **2.78%**、>=250 2.25% | **PASS** |
| 15 | 夜间脸颊子 ROI (950,475–1040,600) | 参考 p95<240 | p95=**255**、>240 **13.18%**；亮像素为粉肤色高光 `(255,170,161)`，x 931–1009 / y 451–493 | **FAIL（局部残留，非主门禁）** |
| 16 | 灯笼在右手 | 右手 `handslot_r`、视觉手持 | 代码使用 `handslot_r`；右手 y=1.102 > 左手 0.426（明确抬起）；但 `LanternRig` 原点距手掌 **0.349 m**、灯心距手 **0.429 m**（杆轴水平距约 ≥0.286 m），`ROGUE_LANTERN_OFFSET=(0.26,-0.20,-0.12)`；截图中右手为空、灯笼悬浮 | **FAIL（视觉手持）/ PASS（挂点名）** |
| 17 | PAUSE 动画 | `Spellcast_Raise`、1.3×、循环 | 当前动画 `Spellcast_Raise`，length 2.10 s，loop=1（LOOP_LINEAR）；`get_playing_speed()=1.00` | **FAIL（速度 1.0 vs 1.3×）** |
| 18 | 扫园人 | Rogue_Hooded + 扫帚 | 模型 AABB 高 **1.666 m**；6 件武器/披风隐藏（`Knife_Offhand/1H_Crossbow/2H_Crossbow/Knife/Throwable/Rogue_Cape`）；`BroomRig` 存在，杆距手 0.438 m；`patrol_sweeper.png` 目检为绿兜帽 + 扫帚 | **PASS（证据为背面，扫帚头偏小）** |
| 19 | 小狐 | glTF Fox，约 1.3 m 长，朝向合理 | AABB 长 **1.332 m**、高 0.672 m；当前动画 `Survey`；`patrol_fox.png` 目检为橙白狐狸、朝向机位 | **PASS（草丛遮挡后半身）** |
| 20 | 混合阵营 | 同框 | `cycle2_mixed_cast.png` 1920×1080：左 Rogue_Hooded + 右 Rogue + 右缘程序化女孩，另有小狐与红章鱼 | **PASS（女孩被右缘裁切、章鱼入镜、灯笼同样悬浮）** |
| 21 | 提灯人比例 | 1.618 m | 模型 AABB 高 **1.618 m** | **PASS** |
| 22 | 90 帧序列 | 90 帧、可读 | 重新生成 `PATROL_SEQUENCE_OK frames=90`，1280×720，16:08:58–16:09:41 | **PASS（生成）/ 未逐帧判定** |

**夜间脸 ROI 亮像素明细（PIL，ROI 内逐像素 max(R,G,B)）**

```text
patrol_lantern_dusk.png  ROI(850,380)-(1010,590): p95=216 max=255 >240=1.65% >=250=1.17%
  脸颊子 ROI(950,475)-(1040,600):               p95=241 max=255 >240=5.06%
  05 ROI1 (865,440)-(1050,600):                 p95=248 max=255 >240=6.72%
patrol_lantern_night.png ROI(850,380)-(1010,590): p95=215 max=255 >240=2.78% >=250=2.25%
  脸颊子 ROI(950,475)-(1040,600):               p95=255 max=255 >240=13.18%
  05 ROI1 (865,440)-(1050,600):                 p95=255 max=255 >240=10.58%
```

> 主门禁（用户 ROI p95<240）通过，但夜间 p95 从 Cycle 1 的 185 升到 215，脸颊子 ROI 从 p95=250 / >240 7.28% 升到 255 / 13.18%。亮像素坐标在脸颊/鼻梁，不在灯玻璃；仍是暖高光，但余量变小。修灯笼挂点后必须重拍复测。

### 3.4 性能（960×540 vs Cycle 1 640×360）

**受控 A/B（`qa_probe_patrol_perf.gd`，shown/hidden 交错，4 blocks × 4 s，3 连跑）**

| 运行 | shown 中位 | hidden 中位 | cost 中位 | show 均 draw | hidden 均 draw | draw delta |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 48.4 | 47.7 | -0.7 | 1296.4 | 1246.5 | 49.9 |
| 2 | 50.6 | 51.4 | +0.8 | 1296.5 | 1247.0 | 49.5 |
| 3 | 46.3 | 45.0 | -1.4 | 1296.9 | 1247.8 | 49.1 |
| **中位** | **48.4** | **47.7** | **-0.7** | — | — | **49.5** |

- 门槛：shown 相对 hidden 回退 **≤2 FPS 或 cost ≤2.4**；draw delta **≤155**。实测 cost 中位 **-0.7**（范围 -1.4~+0.8），draw delta 约 **49.5**（巡逻三个角色新增约 50 个 draw call）→ **PASS**。
- 单次运行内部 block 波动 16.5–56.8 FPS，负载噪声远大于巡逻成本；只认 3 连跑中位。

**legacy 探针（960×540，窗口 1280×720，vsync off）**

| 运行 | avg | min | 负载（1 min） |
|---|---:|---:|---|
| 1 | 31.6 | 20.0 | 7.59 |
| 2 | 46.3 | 38.0 | 6.79→6.09 |
| 3 | 53.6 | 50.0 | 4.65 |
| **中位** | **46.3** | **38.0** | — |

- Cycle 1 对照（640×360）：复审干净单次 **47.5 / 27.0**（当时 load 9.19→9.76）；05 的 3 次 legacy 中位 **69.7**。
- 本轮中位 avg 46.3 对比 47.5 为 **-2.5%**，在负载噪声内；对比 69.7 为 **-33.6%**，但分辨率变为 2.25× 像素且开 MSAA 2×，不是同口径。
- **绝对性能判 INCONCLUSIVE**：首跑 load 7.59 时只有 31.6/20，后两跑 46.3–53.6；单次值不可判回退。**相对成本（受控 A/B）判 PASS**。
- scorecard 写的“960×540：63.3 avg/52 min”本轮**未复现**（3 连跑中位 46.3/38.0）；请勿继续引用该数，除非补同口径证据。

---

## 4. Bug 列表（复现 / 期望 / 实际）

### BUG-01（P0）灯笼视觉脱手（右手为空）

- **复现**：跑截图工具 → 打开 `patrol_lantern_dusk.png` / `patrol_lantern_night.png`；或跑 `tools/qa_cycle2_verify.gd` 看 `gap_hand_rig` / `gap_hand_lamp`。
- **期望**：`Spellcast_Raise` 抬右手时灯笼与手掌接触/由提手连接，读作“提灯查看”。
- **实际**：右手抬起（y 1.102 vs 左手 0.426），但 `LanternRig` 原点距手掌 0.349 m、灯心距手 0.429 m（杆轴水平距离约 ≥0.286 m）；灯笼悬在手侧，右手是空拳头。`ROGUE_LANTERN_OFFSET=(0.26,-0.20,-0.12)`，灯杆为竖直 0.7 m，无横向提手连接到手心。
- **建议**（未改代码）：横向偏移收到 ≤0.08 m，或在 rig 内加一根从手心到灯杆的短横杆；改后重拍两张近景并复测脸 p95。
- **证据**：`patrol_lantern_dusk.png`、`patrol_lantern_night.png`、`VERIFY ... gap_hand_rig=0.349 gap_hand_lamp=0.429`。

### BUG-02（P1）PAUSE 动画未按 1.3× 播放

- **复现**：`garden_patrol.gd:577` `_model_player.play(anim_name, 0.25)`（无 speed 参数）；QA 探针 `playing_speed=1.00`。
- **期望**：brief P0-2 `Spellcast_Raise` 1.3× 循环。
- **实际**：1.0× 循环（loop=1），length 2.10 s。
- **建议**：`play(anim_name, 0.25, 1.3)`，或策划/美术书面改 brief。

### BUG-03（P2）历史截图命名残留/复制，证据易误导

- `cycle1_640x360.png` 实际 **960×540**，且与 15:59 旧 `cycle2_960x540.png` 同哈希 `b5354f8a…`；本轮新图哈希已变为 `76d67fda…`。
- `cycle1_mixed_cast.png` 与旧 `cycle2_mixed_cast.png` 同哈希 `21f4c36f…`。
- **影响**：只影响证据卫生，不影响游戏；建议下一轮清理或改名，文件名与分辨率/时间必须一致。

### BUG-04（P3）注释/配置与实现不一致

- `garden_scene.gd:3` 仍写“640×360 内部渲染 → NEAREST”；实际 960×540 LINEAR。
- `shaders/post_process.gdshader:4` 写“内部 1280×720”；实际 960×540（运行时 u_texel 正确）。
- `shaders/flower.gdshader:5` 写“640×360”。
- `project.godot` `config/features` 仍含 `GL Compatibility`，实际 Vulkan Forward Mobile。
- **影响**：仅可维护性/文档，不影响运行。按“只记录不改”原则未动。

---

## 5. 截图清单（本轮 16:08–16:09 重拍）

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 时间 | 尺寸 | 内容/结论 |
|---|---|---|---|
| `patrol_lantern_dusk.png` | 16:08:29 | 1920×1080 | 16°/5.8；右手抬起但灯笼悬浮；脸 p95=216 |
| `patrol_lantern_night.png` | 16:08:31 | 1920×1080 | 00:00 同机位；脸 p95=215；脸颊 p95=255 |
| `cycle2_960x540.png` | 16:08:29 | **960×540** | 内部源画面；LINEAR/MSAA 生效，无像素块 |
| `cycle2_mixed_cast.png` | 16:08:43 | 1920×1080 | Rogue_Hooded + Rogue + 程序化女孩 + 狐 + 章鱼同框；女孩右缘裁切 |
| `patrol_sweeper.png` | 16:08:38 | 1920×1080 | Rogue_Hooded + 扫帚（背面视角，扫帚头偏小） |
| `patrol_fox.png` | 16:08:40 | 1920×1080 | glTF Fox，AABB 长 1.332 m；草丛遮挡后半身，背景有红章鱼 |
| `cycle1_noon.png` | 16:08:34 | 1920×1080 | 正午广角；非像素观感 |
| `cycle1_wide_night.png` | 16:08:36 | 1920×1080 | 夜间 48°/27.5 m；街灯暖池清楚，提灯人灯点偏小 |
| `patrol_wide_dusk.png` / `_off.png` | 16:08:22 / 16:08:24 | 1920×1080 | 巡逻有/无对比 |
| `patrol_compare_on.png` / `_off.png` | 16:08:25 / 16:08:26 | 1920×1080 | 扫园人定点有/无对比 |
| `patrol_seq/frame_000..089.png` | 16:08:58–16:09:41 | 1280×720 | 90 帧重新生成；`PATROL_SEQUENCE_OK` |

---

## 6. 残留风险

1. **灯笼修挂点会移动光源/玻璃位置**：当前 p95 余量（216/215 vs 240）比 Cycle 1 小，灯靠近脸可能再次推高 p95；修复后必须重拍 dusk/night 并复测 ROI 与脸颊子 ROI。
2. **性能绝对值不可判**：4 核 + load 4.65–7.59，单次 31.6–53.6；只有相对成本（cost≤2.4、draw delta 49.5）可判。scorecard 的 63.3/52 未复现，需删改或补证据。
3. **90 帧只生成未逐帧量化**：T-pose、脚滑≤5%、WALK→PAUSE→WALK 过渡本轮未逐帧判定（时间盒）。
4. **小狐截图取景差**：草丛挡住后半身、红章鱼入镜；长 1.332 m 由 AABB 证明，但“朝向合理”仅目检。`_stage_mixed_cast` 只隐藏 `world.monsters`，章鱼不在列表（工具层旧问题）。
5. **扫园人截图背面**：能证明 Rogue_Hooded+扫帚，但面部/扫帚细节证据弱；扫帚杆距手 0.438 m，视觉上靠杆身穿过手心，仍有“非实体握持”风险。
6. **混合阵营构图**：程序化女孩被右缘裁切，章鱼在背景；同框成立，但美术 7.0 评分前建议重拍干净构图。
7. **回退警告从 1 条变 3 条**：三角色各一条一次性 WARNING，可接受；若门禁仍按“1 条”字面，需要更新门禁措辞。
8. **历史证据文件命名混乱**（BUG-03）：`cycle1_640x360.png` 实为 960×540；引用旧报告时注意。

---

## 7. 一句话

**无头、巡逻、回退、`5`/UI、960×540/LINEAR/MSAA、16°/5.8、脸 p95（216/215<240）、小狐 1.332 m 全部 PASS；但灯笼距右手 0.349–0.429 m、右手为空，`Spellcast_Raise` 实播 1.0× 而非 1.3×，两项 P0 条件未关闭，故为条件放行；性能仅相对成本 PASS（cost -0.7、draw delta 49.5），绝对值受 load 4.65–7.59 噪声主导、scorecard 63.3/52 未复现。**
