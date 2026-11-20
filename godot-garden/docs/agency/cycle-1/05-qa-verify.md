# Cycle 1 · 05 QA 复验：提灯守夜人 → KayKit Rogue

> 执行：QA 负责人 | 日期：2026-10-31 13:36–13:47（CST） | 阶段：**实现后复验**
> 被测：`godot-garden/` 当前工作区（`scripts/garden_patrol.gd`、`scripts/garden_scene.gd`）
> 关联：`01-brief.md`（v2 门槛）、`02-art-review.md`、`03-qa-baseline.md`、`04-impl.md`
> 只读声明：**未修改任何游戏逻辑**；仅运行现有工具、写本报告与 `/tmp` 分析图。

---

## 1. 结论

**阻塞（不放行）。** 功能、稳定性、程序化回退、开关链路均通过；但 **00:00 脸部 p95=255（门禁 <240）**、**近景机位 12°/5.2m 未签字越权（brief §8.6 Q3 要求本轮不改，16°/5.8m）** 两项 P0 验收未过；**性能门禁因本机噪声不可判**（相对未见一致性回退，draw delta 稳定优于基线，但需受控 3 连跑）；验收截图还混入战斗飘字。

| 项 | 判定 | 依据 |
|---|---|---|
| 无头 600 帧 | **PASS** | 0 匹配、exit 0、7.95s |
| legacy 探针 3 次 | **PASS** | avg 69.7 / 66.1 / 77.8（中位 **69.7** ≥54.8）；3/3 `PROBE_PATROL_OK`；travelled/间距/toggle 全过 |
| 交错稳态探针 | **INCONCLUSIVE（不可判）** | 7 轮 shown avg 56.1–75.5（中位 67.6）；hidden 对照同步摆动 61.0–81.1；draw delta 稳定 113.5–113.8（≤154.5） |
| 程序化回退 | **PASS** | 1 条 WARNING、无刷屏、`PROBE_PATROL_OK`、exit 0 |
| 截图矩阵 | **FAIL（数值+证据）** | 武器/披风隐藏、0.74、脚底、跟手成立；**脸 p95=255**；截图含 `-16/-5` 飘字 |
| 5 键 / UI 开关 | **PASS** | `QA_KEY_TOGGLE_OK` |
| PAUSE = Idle（无举灯） | **不阻塞** | brief v2 §8.6 Q2 / §8.7 明确允许 `Idle + 0.7m 杆`；灯心 0.87m 可读 |
| 相机 12°/5.2m | **阻塞** | brief §8.6 Q3「不改；12°/5.2 仅参考」；无美术+策划签字，且前后对比非同机位 |
| 脸 >240 像素 | **阻塞** | 实测夜脸 p95=255、>240 占 8.0%–13.9%、max=255；02 §8.2 列为「不可妥协」 |

**转条件放行的条件（缺一不可）：**

1. **脸光复测**：在固定 ROI 上达到 02 §5 的 `p95<240、max<250、>240<5%`，重拍 00:00 近景；不得回退光晕/地面池可读性。
2. **机位**：回 **16°/5.8m** 重拍同机位前后对比；若坚持 12°/5.2m，需美术+策划书面签字并写入 `04`/`06`。
3. **性能受控复测**：固定场景状态、前台独占、3 连跑，shown 中位 ≥72.9 且 draw delta ≤154.5；记录 load avg 与 hidden 对照。
4. **截图证据去污染**：隐藏战斗飘字；补 640×360 源画面与 90 帧 WALK→PAUSE→WALK 序列（闪/脚滑/UV 缝）。
5. **美术签字**：角色 ≥6.5 条件、视觉统一 ≥6.0 条件、光照 ≥6.5、构图 ≥6.5、材质 ≥5.5；本轮未提供 `cycle1_mixed_cast` 签字图。

---

## 2. 环境与命令

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6，Intel Core i7-5650U，Intel Iris 6000 |
| Godot | 4.6.stable.official.89cea1439 |
| 渲染 | Vulkan 1.2.283，Forward Mobile |
| 项目 | 内部 640×360；探针窗口 1280×720；截图 SubViewport 1920×1080 |
| 系统负载 | 5.31–9.10（前台 Godot 独占；claude/WebKit 常驻） |
| 计时 | 本机无 `timeout`；后台启动 + `sleep` 轮询日志 |

```bash
cd /Users/ks_128/Documents/modelfw_demo

# 1. 无头 600 帧
godot --path godot-garden --headless --quit-after 600 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING"

# 2. legacy 探针 ×3（前台；open -a Godot 激活窗口，等价于 --resolution 1280x720）
open -a Godot --args --path "$PWD/godot-garden" --resolution 1280x720 \
  --log-file /tmp/cyc1_legacy_N.log -s res://tools/probe_patrol.gd

# 3. 交错稳态探针（前台）
open -a Godot --args --path "$PWD/godot-garden" --resolution 1280x720 \
  --log-file /tmp/cyc1_perf_N.log -s res://tools/qa_probe_patrol_perf.gd

# 4. 回退
GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd

# 5. 开关链路
godot --path godot-garden --headless -s tools/qa_key_toggle.gd
```

---

## 3. 结果表（阈值 / 实测 / 判定）

### 3.1 稳定性与功能

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 1 | 无头 600 帧 | 0 `SCRIPT ERROR/ERROR/WARNING`，exit 0 | 无匹配；exit 0；real 7.95s | **PASS** |
| 2 | legacy 探针 ×3 | 3/3 `PROBE_PATROL_OK`；avg 中位 ≥54.8 | 69.7 / 66.1 / 77.8（中位 **69.7**）；3/3 OK | **PASS** |
| 3 | 提灯人 travelled | 与基线 7.7 差 ≤5% | 8.0 / 7.9 / 7.9（中位 7.9，+2.6%） | **PASS** |
| 4 | 最小间距 | pond>4.8 / circle>2.6 / statue>1.8 / pillar>1.0 | 6.38 / 6.43 / 3.32 / 5.90–5.92（3 次一致） | **PASS** |
| 5 | 扫园人/小狐侍 | travelled >4.2；无新错误 | sweeper 5.2–5.8；fox 8.4–9.3；日志干净 | **PASS** |
| 6 | 5 键 / UI 开关 | 三链路隐藏并恢复 | `QA_KEY5 true/true/true`；`QA_F1` 全 true；`QA_UI_BUTTON` 全 true；`QA_KEY_TOGGLE_OK` | **PASS** |
| 7 | 程序化回退 | `PROBE_PATROL_OK`；只 1 条警告；不刷屏 | exit 0；`WARNING` 计数 = 1；`SCRIPT ERROR/ERROR` = 0；`PROBE_PATROL_OK` | **PASS** |

**legacy 原始输出（3 次，节选）：**

```text
# run1 13:36:51–13:37:33
PATROL Patrol_lantern role=lantern travelled=8.0 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.90
PATROL_FPS avg=69.7 min=44.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=60.7 shown=58.9 cost=1.8
PROBE_PATROL_OK

# run2 13:37:42–13:38:20
PATROL Patrol_lantern role=lantern travelled=7.9 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.92
PATROL_FPS avg=66.1 min=43.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=67.7 shown=65.0 cost=2.7
PROBE_PATROL_OK

# run3 13:38:30–13:39:05
PATROL Patrol_lantern role=lantern travelled=7.9 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.91
PATROL_FPS avg=77.8 min=68.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=69.3 shown=65.1 cost=4.2
PROBE_PATROL_OK
```

**回退原始输出（节选）：**

```text
WARNING: GardenPatrol: Rogue unavailable (GARDEN_FORCE_PROCEDURAL), using procedural model
PATROL Patrol_lantern role=lantern travelled=8.2 min_pond=6.39 min_circle=6.43 min_statue=3.32 min_pillar=5.92
PATROL_FPS avg=56.4 min=49.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=44.0 shown=64.7 cost=-20.7   # A/B cost 按基线口径作废，不作门禁
PROBE_PATROL_OK
exit=0
```

### 3.2 交错稳态性能

> 用户矩阵要求 ×2；实际因第 1–3 轮出现 **shown/hidden 同步塌陷**（hidden 也降到 52/43 FPS，cost 却从 -6.6 跳到 +23.6，而 draw delta 恒定 113.8），为判断“环境噪声 vs 真实回退”追加到 7 轮。**不硬判 PASS/FAIL。**

| run | shown avg / median | hidden avg / median | cost avg / median | draw delta（绝对值） |
|---:|---|---|---|---|
| 1 | 64.2 / 64.2 | 65.4 / 67.3 | 1.1 / 3.1 | 113.5 |
| 2 | 67.6 / 66.2 | 61.0 / 62.4 | -6.6 / -3.8 | 113.7 |
| 3 | 56.1 / 54.6 | 79.7 / 82.1 | 23.6 / 27.5 | 113.8 |
| 4 | 75.5 / 75.3 | 81.1 / 80.3 | 5.7 / 4.9 | 113.8 |
| 5 | 74.1 / 73.9 | 76.4 / 73.3 | 2.3 / -0.7 | 113.6 |
| 6 | 67.3 / 69.2 | 74.1 / 71.8 | 6.8 / 2.6 | 113.7 |
| 7 | 73.9 / 74.0 | 79.3 / 81.8 | 5.4 / 7.8 | 113.6 |

**读数：**
- shown avg 中位（7 轮）= **67.6** < 72.9；但 hidden 对照组同步在 **61.0–81.1** 间摆动，cost 在 **-6.6～+23.6** 间摆动；干净轮次（4/5/7）shown 73.9–75.5，与基线 74.5/75.3 一致。**结论：本机噪声导致交错门槛不可判，不能据此判 FPS 回退。**
- **draw delta 7/7 稳定在 113.5–113.8**，优于基线 144.5（少约 31 个 draw call）且远低于门槛 154.5 → **draw 项 PASS**，是当前唯一稳定的性能证据。
- cost 中位（7 轮）5.1 > 2.4 诊断线；因 shown/hidden 同步漂移，不作为成本结论。

### 3.3 视觉与截图

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 8 | 武器/披风 | 5 武器 + `Rogue_Cape` 可见数 = 0 | 代码隐藏 6 个网格（`garden_patrol.gd:21-23`）；截图中无武器/披风 | **PASS** |
| 9 | 比例 | ModelRoot 0.74（0.72–0.759） | 代码 `ROGUE_MODEL_SCALE := 0.74`；`ModelRoot.position.y=0`；截图脚底贴地、未见悬浮 | **PASS（静态）** |
| 10 | 灯笼跟手 | 挂 `handslot_l`，跟手、不脱手 | 每帧 `LanternRig.global_position = handslot_l + basis*offset`；近景灯在左手侧、杆/框/玻璃可见 | **PASS（静态）** |
| 11 | 夜间脸部曝光 | 脸 p95<240、max<250、>240<5% | **p95=255、max=255、>240=8.0%**（ROI1）；内脸 p95=253/7.1%；受光颊 p95=255/13.9% | **FAIL** |
| 12 | 黄昏脸部曝光 | p95<245 | ROI1 241 / 内脸 234 / 受光颊 247 | **PASS（临界）** |
| 13 | 640×360 源画面 | 不糊、无 UV 缝、无闪、无脱手 | 1920→640 NEAREST：可辨、无 UV 缝/脱手；**静态图无法验证“闪”** | **PASS（静态）/ 闪未测** |
| 14 | 截图无 UI/飘字 | UI 隐藏、无战斗飘字 | UI 已隐藏；**画面仍有 `-16/-16/-5` 战斗飘字** | **FAIL（证据）** |
| 15 | 机位 | 本轮 16°/5.8m（12° 仅参考/签字） | `PATROL_CAMERAS["lantern"]` = **12°/5.2m**；无签字记录 | **FAIL（越权）** |
| 16 | 构图/统一性签字 | 角色 ≥6.5 条件、视觉 ≥6.0 条件 | 无美术签字；目录无 `cycle1_mixed_cast.jpg` | **BLOCKED（证据缺失）** |

**脸部 p95 测量口径（PIL，逐像素 max(R,G,B)）：**

```text
patrol_lantern_night.png
ROI1 全脸 (865,440)-(1050,600): p95=255.0 max=255 >240=8.0%  >=250=6.60%
ROI2 内脸 (880,455)-(1030,595): p95=253.0 max=255 >240=7.1%  >=250=5.57%
ROI3 受光颊 (950,475)-(1040,600): p95=255.0 max=255 >240=13.9% >=250=11.17%

patrol_lantern_dusk.png
ROI1 p95=241 / ROI2 p95=234 / ROI3 p95=247
```

> 04 §7 记录的“左脸 p95≈229、脸颊 >240 约 24%”未复现；本次按全脸 ROI 测得 p95=253–255、>240=7.1%–13.9%。无论取哪个 ROI，**夜间 p95 均 >240**，与 02 §8.2「不可妥协」冲突。绿色 >240 像素可视化确认落在额头/受光灯颊（非灯玻璃/耳饰）。

---

## 4. Bug 列表

### BUG-A（P0，视觉）：00:00 脸部过曝，p95=255 超门禁

- **复现**：`godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd` → 用 PIL 读取 `patrol_lantern_night.png`，ROI (865,440)-(1050,600) 计算 max-channel。
- **期望**：p95<240、max<250、>240<5%（02 §5 / brief §8.7）。
- **实际**：p95=255、max=255、>240=8.0%（内脸 253/7.1%；受光颊 255/13.9%）。眼/鼻/嘴仍可读，但数值门禁未过。
- **原因线索**：根灯 `(-1.30,0.80,-0.90)`、能量 `0.18+glow*0.22`、光晕核心 alpha `glow*0.40` 仍有近场叠加；灯与脸距离/角度在 12°/5.2m 机位下更近。
- **建议**：按 02 备选（规格位置 + attenuation 0.5，实测左脸 p95≈186）或再降光晕核心 alpha/灯能量，用同一 ROI 复测；勿改全局曝光。

### BUG-B（P0，流程/构图）：近景机位改为 12°/5.2m，未签字

- **复现**：读 `scripts/garden_scene.gd:15`；`PATROL_CAMERAS["lantern"] = {pitch: 12.0, distance: 5.2}`；截图 `focus_patrol(0)`。
- **期望**：brief §8.6 Q3——本轮不改机位，16°/5.8m 做前后对比；12°/5.2m 仅参考（02 §4.8 同）。
- **实际**：已改为 12°/5.2m；04 §6 以「按 02 §4.8」为由，但 02 §4.8 原文是“保持 16°/5.8m，12°/5.2 是早期草稿未采纳”。无美术+策划签字。
- **影响**：验收图与 03 基线（16°/5.8m）不同机位，无法做同机位前后对比；构图/遮挡结论不可比。**按门槛判阻塞**，回 16°/5.8m 或补签字。

### BUG-C（P1，证据）：验收截图含战斗飘字

- **复现**：查看 `patrol_lantern_dusk.png` / `patrol_lantern_night.png` / `patrol_wide_dusk.png`，可见 `-16`、`-5` 飘字。
- **期望**：02 §4.8/§5——验收图隐藏 UI、autoplay=false、无战斗飘字。
- **实际**：`screenshot_patrol.gd` 只 `set_ui_visible(false)`，未关闭战斗/妖灵伤害数字。
- **影响**：图片不能直接作为美术签字/发布图；不影响游戏逻辑。

### BUG-D（P1，测量方法）：交错性能探针本机不可重复

- **复现**：7 次前台独占运行 `qa_probe_patrol_perf.gd`：shown avg 56.1–75.5，hidden avg 61.0–81.1，cost -6.6～+23.6，draw delta 恒 113.5–113.8。
- **期望**：3 次 shown 中位 ≥72.9、draw delta ≤154.5；成本中位 ≤2.4（诊断）。
- **实际**：FPS 与成本随系统负载大幅摆动，hidden 对照同步塌陷（如 run3 hidden 82→shown 54）；draw delta 稳定。**判 INCONCLUSIVE，不判回退，也不能据此放行。**
- **建议**：固定场景状态（关闭其它 app/渲染）、独占、3 连跑；记录 load avg、窗口前后台、hidden 对照；必要时用 GPU 计时替代墙钟 FPS。

### BUG-E（P2，工具）：640×360 “闪”与 90 帧序列未验证

- 现状：只有静态 1920 图 NEAREST 缩到 640×360；无源 640×360 抓帧，无 `capture_patrol_sequence` 90 帧（工具当前拍扫园人，未切提灯人）。
- 影响：T-pose、过渡、脚滑、移动闪烁未在本轮留下证据；列为残留风险。

---

## 5. 截图清单与时间

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 文件时间 | 尺寸 | 内容/结论 |
|---|---|---|---|
| `patrol_lantern_dusk.png` | 2026-10-31 13:29:05 | 1920×1080 | 18:24 近景（12°/5.2m）；灯/杆/玻璃/光晕可见、左手、无武器/披风；含飘字；黄昏 p95 234–247 |
| `patrol_lantern_night.png` | 2026-10-31 13:29:07 | 1920×1080 | 00:00 同机位；**脸 p95=255 FAIL**；地面暖光池可见；含飘字 |
| `patrol_wide_dusk.png` | 2026-10-31 13:29:02 | 1920×1080 | 默认 48°/27.5m；人形+暖光可辨性未单独量化；含飘字 |
| `patrol_compare_on.png` | 2026-10-31 13:29:03 | 1920×1080 | 石圈对侧定点，巡逻 ON |
| `patrol_compare_off.png` | 2026-10-31 13:29:03 | 1920×1080 | 同机位巡逻 OFF（开关对比） |

- 以上为目录内**最新** `patrol_*` 图；13:23–13:27 的 `att_*`/`con_*`/`fine_*`/`far_*` 为并发调参图，非本次验收依据。
- `screenshot_patrol.gd` 在提灯近景前会转向 NPC（`_face_patrol_to_camera`），属验收工具姿态，不代表玩家实际朝向（04 §7 已声明）。

---

## 6. 已知偏差判断

| 偏差 | 判定 | 理由 |
|---|---|---|
| PAUSE 仍是 Idle，无举灯动作 | **不阻塞** | brief v2 §8.6 Q2 / §8.7 已把 P0-2 从“第三条 PAUSE 动画”改为 `Idle + 0.7m 杆`；灯心 0.87m 在近景可读。仍需在 06 记为债务（02 P1-4 的举灯未交付）。 |
| 相机 12°/5.2m（美术建议 16°/5.8m） | **阻塞** | 本轮 brief 明确“不改机位”，12°/5.2 仅参考；无签字，且破坏同机位对比。需回退或补美术+策划签字。 |
| 脸 >240 像素约 24%（04 记录） | **阻塞** | 本次实测夜间全脸 p95=255、>240=8.0%–13.9%、max=255；02 §8.2 将“脸 p95<240”列为不可妥协。数值门禁未过。 |

---

## 7. 残留风险

1. **性能不可判**：7 轮 shown 中位 67.6 <72.9，但 hidden 同步波动；无受控 3 连跑，不能证明或证伪回退。draw delta 稳定 113.5–113.8 是唯一可信正证据。
2. **美术签字缺失**：`cycle1_mixed_cast.jpg` 不存在；角色/统一性/光照/构图/材质 0–10 分未签；本轮不能给“条件放行”的视觉维度签字。
3. **动画证据缺失**：无 90 帧 WALK→PAUSE→WALK 序列；T-pose=0、过渡 ≤0.25s、脚滑 ≤5%、Nearest 移动闪烁均未测。代码只接 Idle/Walking_A，风险中等。
4. **640×360**：仅静态缩图检查；无源视口帧、无 1.2s 行走序列，“闪/双影”未验证。
5. **双影**：身体实时阴影 + 0.45 贴地阴影并存；截图未逐帧检查，不能排除近景双影。
6. **灯遮挡**：正常游玩时灯在左手，某些朝向会被身体挡住；验收图是工具转向后的姿态，玩家实际可见性未量化。
7. **既有 BUG-1（`patrol_fox.png` 树干遮挡）** 未在本轮复验，仍为工具问题。
8. **回退 FPS 低**（56.4）且 A/B cost -20.7 为噪声；回退只按“可用/单警告/探针 OK”验收，未做性能对比。
9. **`04-impl` 与 brief 的机位叙述冲突**（04 称按 02 §4.8 用 12°/5.2，02 §4.8 实为保持 16°/5.8）；需策划在 06 统一口径，避免后续引用混乱。

---

## 8. 一句话

**功能/稳定性/回退/开关全过；性能因本机噪声不可判但无一致性回退、draw delta 稳定优于基线；阻塞项是 00:00 脸 p95=255（>240）与未签字的 12°/5.2m 机位，另需去飘字重拍、补受控性能 3 连跑与美术签字；PAUSE=Idle 按 brief v2 不阻塞。**
