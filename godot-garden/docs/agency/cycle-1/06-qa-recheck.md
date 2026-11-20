# Cycle 1 · 06 QA 条件复审（delta）

> 执行：QA 负责人 | 时间：2026-10-31 14:15–14:23（CST） | 阶段：05 阻塞项复验
> 被测：`godot-garden/` 当前工作区（`garden_patrol.gd` mtime **14:00:18**、`garden_scene.gd` **13:50:19**、`screenshot_patrol.gd` **14:00:23**、`capture_patrol_sequence.gd` **14:10:40**）
> 关联：`05-qa-verify.md`、`05-art-signoff.md`、`01-brief.md` §8 v2
> 只读声明：**未修改任何游戏逻辑/测试脚本**。仅清理了一个 14:05 遗留的挂起截图进程（PID 28242，`capture_patrol_sequence.gd` 在 `waypoints` 赋值报错后未退出，占用 78.9% CPU、运行约 12 分钟）；该进程是工具进程，不是游戏代码。

---

## 1. 结论

**条件放行。** 05 的两项 P0 阻塞中，**相机已回退 16°/5.8（关闭）**；**夜间脸 p95 主门禁已过**（用户指定 ROI p95=185<240、>240=1.0%<5%），但 `max=255`（225 px 脸颊高光）仍不满足 02/brief 的 `max<250`，且脸颊子 ROI p95=250，需美术确认或微调高光后才能完全关闭 P0-3。性能因本机噪声与遗留进程不硬判，需受控复测。截图证据（无飘字、640×360、混合阵营、90 帧）与 5 键/UI、程序化回退均通过。

**放行条件（缺一不可）：**

1. **脸光 max**：夜间指定 ROI `max=255`、`>=250` 225 px（0.67%）落在脸颊高光；脸颊子 ROI `(950,475)-(1040,600)` p95=250。需美术在 05/06 明确接受该局部高光，或把高光/灯位再压到 `max<250`。
2. **性能**：前台独占、低负载下 legacy 3 连跑，中位 `avg ≥54.8`（01 v2 相对门槛）；本轮只有 1 次干净样本 47.5，不足以判 PASS/FAIL。
3. **灯光参数签字**：当前实现偏离 02 §4.5 签字版（见 §5.3），需美术追签或把新参数写入 04/06，避免“已签参数”与“实际参数”不一致。
4. **动画**：90 帧序列已补，6 帧抽检无 T-pose；脚滑 ≤5%、移动闪烁仍为抽检，未逐帧量化。

---

## 2. 环境与命令

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6，Intel Core i7-5650U（4 逻辑核），Intel Iris 6000 |
| Godot | 4.6.stable.official.89cea1439 |
| 渲染 | Vulkan，Forward Mobile；内部 640×360；探针窗口 1280×720；截图 SubViewport 1920×1080 |
| 系统负载 | **7.43–10.57**（1 分钟均值；`claude` 常驻约 57% CPU；清理遗留 Godot 前 8.98） |
| 计时 | 无 `timeout`；同步运行 + `/usr/bin/time` |

```bash
cd /Users/ks_128/Documents/modelfw_demo

# 1. 无头 600 帧
godot --path godot-garden --headless --quit-after 600 > /tmp/cyc1_recheck_headless.log 2>&1
grep -nE "SCRIPT ERROR|ERROR|WARNING" /tmp/cyc1_recheck_headless.log

# 2. legacy 探针（清理遗留进程后重跑 1 次；另记录清理前 1 次受污染结果）
godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd \
  --log-file /tmp/cyc1_recheck_probe2.log

# 3. 程序化回退
env GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --resolution 1280x720 \
  -s tools/probe_patrol.gd --log-file /tmp/cyc1_recheck_fallback.log

# 4. 5 键 / UI
godot --path godot-garden --headless -s tools/qa_key_toggle.gd
```

---

## 3. 结果表（用例 / 阈值 / 实测 / 判定）

### 3.1 稳定性、功能、回退

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 1 | 无头 600 帧 | 0 `SCRIPT ERROR/ERROR/WARNING`，exit 0 | 0 匹配；exit 0；real **10.8s** | **PASS** |
| 2 | legacy 探针（干净 1 次） | `PROBE_PATROL_OK`；avg 中位 ≥54.8（3 次口径） | `PROBE_PATROL_OK`；avg **47.5** min 27.0；hidden 64.8 / shown 60.5 / cost 4.3；exit 0；real 36.8s | **INCONCLUSIVE（仅 1 次，负载 9.19→9.76）** |
| 3 | legacy 探针（清理前，受污染） | 同上 | avg **28.8** min 16.0；hidden 35.8 / shown 32.0；`PROBE_PATROL_OK` | **作废（遗留进程 78.9% CPU）** |
| 4 | 提灯人 travelled | >4.2；与基线 7.4–9.5 差 ≤5% | 干净跑 **7.3**（距中位 7.7 −5.2%，距基线区间下沿 −0.1）；受污染跑 9.0；回退 7.5 | **PASS（基线波动内）/ 备注 −5.2%** |
| 5 | 最小间距 | pond>4.8 / circle>2.6 / statue>1.8 / pillar>1.0 | 6.39 / 6.43 / 3.32 / 5.91（三次一致） | **PASS** |
| 6 | 扫园人 / 小狐 | travelled >4.2；无新错误 | sweeper 5.4 / 6.6；fox 9.0 / 10.2；日志干净 | **PASS** |
| 7 | toggle | hidden_ok=true, shown_ok=true | `PATROL_TOGGLE hidden_ok=true shown_ok=true` | **PASS** |
| 8 | 程序化回退 | `PROBE_PATROL_OK`；只 1 条 WARNING；不刷屏 | exit 0；WARNING **1** 条；`SCRIPT ERROR/ERROR` **0**；travelled 7.5；avg 55.3 min 46.0；toggle true/true；`PROBE_PATROL_OK` | **PASS** |
| 9 | 5 键 / UI 开关 | 三链路隐藏并恢复 | `QA_KEY5 true/true/true`；`QA_F1` 全 true；`QA_UI_BUTTON` 全 true；`QA_KEY_TOGGLE_OK`；exit 0 | **PASS** |

**legacy 干净跑原始输出：**

```text
PATROL Patrol_fox role=fox travelled=9.0 min_pond=12.99 min_circle=10.75 min_statue=10.30 min_pillar=1.73
PATROL Patrol_lantern role=lantern travelled=7.3 min_pond=6.39 min_circle=6.43 min_statue=3.32 min_pillar=5.91
PATROL Patrol_sweeper role=sweeper travelled=5.4 min_pond=13.15 min_circle=3.40 min_statue=10.35 min_pillar=11.39
PATROL_FPS avg=47.5 min=27.0 samples=12
PATROL_FPS_AB hidden=64.8 shown=60.5 cost=4.3
PATROL_TOGGLE hidden_ok=true shown_ok=true
PROBE_PATROL_OK
```

### 3.2 性能口径（01 v2 相对门槛，不硬判）

- 01 v2 硬门槛：legacy **3 次** avg 中位 **≥54.8** + `PROBE_PATROL_OK`；交错稳态 3 次 shown 中位 ≥72.9、draw delta ≤154.5。本轮按要求 **legacy ×1**（因遗留进程污染补跑 1 次），**没有 3 次合法样本，也没有跑交错稳态**。
- 干净跑 avg 47.5 < 54.8，但同一次 A/B 的 shown=60.5 ≥54.8，hidden=64.8，cost=4.3；受污染跑 avg 28.8（hidden 35.8 / shown 32.0）证明低值是环境/进程导致，不是一致回退。
- **本机噪声**：4 逻辑核上 load 7.43–10.57，`claude` 约 57% CPU；清理遗留 Godot 后 avg 从 28.8 回升到 47.5。按 01 v2“本机噪声不可判”口径，本轮记 **INCONCLUSIVE**，不据此判性能回退。
- 参考证据：05 的 3 次 legacy 中位 **69.7**、交错 draw delta **113.5–113.8**（≤154.5）; 14:00 的改动只改灯能量/光晕 alpha/玻璃 emission，节点数与 draw call 不变，draw 结论可沿用，但仍建议受控 3 连跑。

### 3.3 截图与视觉（14:00–14:11 新图）

| # | 用例 | 阈值 | 实测 | 判定 |
|---:|---|---|---|---|
| 10 | 相机回退 | `PATROL_CAMERAS["lantern"]` = 16°/5.8 | `garden_scene.gd:15`: `pitch 16.0, distance 5.8`；截图工具注释“16°/5.8”；近景取景已按 16°/5.8 | **PASS** |
| 11 | 夜间脸 p95（用户 ROI `(850,380)-(1010,590)`） | p95<240、max<250、>240<5% | **p95=185、max=255、>240=1.00%（>=250 0.67%，225/33600 px）** | **p95 PASS / >240 PASS / max FAIL** |
| 12 | 夜间脸 05 ROI1 `(865,440)-(1050,600)` | p95<240 | p95=**235**、max=255、>240=4.35% | **PASS（p95）/ max FAIL** |
| 13 | 夜间脸颊子 ROI `(950,475)-(1040,600)` | p95<240 | p95=**250**、>240=7.28% | **FAIL（局部高光）** |
| 14 | 黄昏脸（用户 ROI） | p95<245 | **p95=199**、>240=0.76%；>=250 的 51 px 在 ROI 左缘、颜色为橙色灯玻璃，不在脸 | **PASS** |
| 15 | 飘字 | 无 `-16/-5` 战斗漂字 | `_hide_floaters()` 已隐藏全部 `Label3D`；dusk/night/wide/noon/mixed/640/序列目检 **无飘字** | **PASS** |
| 16 | 640×360 源画面 | 640×360、不糊、无 UV 缝 | `cycle1_640x360.png` = **640×360**（来自 `_scene._viewport`）；NEAREST 放大目检清晰、无 UV 缝、无脱手 | **PASS（静态）** |
| 17 | 混合阵营 | 同框可见 | `cycle1_mixed_cast.png` = 1920×1080；可见 KayKit Rogue（提灯人）+ 程序化扫园人 + 程序化女孩；无武器/披风；无飘字；背景另有章鱼/妖灵 | **PASS（证据补齐）** |
| 18 | 90 帧序列 | 90 帧、无 T-pose、无飘字 | 90 张 `frame_000..089.png`，1280×720，14:10:55–14:11:25；抽检 0/15/30/45/60/89 六帧：无 T-pose、无飘字、WALK 前后折返可读 | **PASS（抽检）** |
| 19 | 截图时效 | 图晚于代码 | 代码 14:00:18 / 工具 14:00:23；截图 **14:00:48–14:01:00**；序列工具 14:10:40、帧 **14:10:55–14:11:25** | **PASS** |
| 20 | 地面光池 | 不得回退可读性 | 近景夜间灯下地面有暖色池（3.2× 亮度下清晰；正常曝光下偏弱）；广角夜景街灯池清楚，提灯人脚下暖池较淡 | **PASS（弱）/ 残留** |

**夜间脸 ROI 明细（PIL，逐像素 max(R,G,B)）：**

```text
patrol_lantern_night.png
用户 ROI (850,380)-(1010,590): p95=185 max=255 >240=1.00% >=250=0.67%
05 ROI1 (865,440)-(1050,600):  p95=235 max=255 >240=4.35%
05 ROI2 内脸 (880,455)-(1030,595): p95=230 max=255 >240=3.76%
05 ROI3 脸颊 (950,475)-(1040,600): p95=250 max=255 >240=7.28%

patrol_lantern_dusk.png
用户 ROI: p95=199 max=255 >240=0.76%（max 像素在左缘灯玻璃，不在脸）
```

> `max=255` 的 225 px 位于 x 915–1009、y 504–542，颜色约 `(255,153,147)`，是脸颊高光；不是眼睛/牙齿/灯玻璃。相对 05 的 p95=255，本轮 p95 已降到 185/235，主过曝已消除，但局部高光仍裁切。

---

## 4. 05 阻塞项逐条关闭情况

| 05 阻塞项 | 本轮证据 | 状态 |
|---|---|---|
| 脸光 p95=255（<240） | 用户 ROI p95=185、05 ROI1 p95=235、>240 1.0%/4.35% | **主项关闭**；max=255/脸颊 p95=250 为残留条件 |
| 相机 12°/5.2 未签字 | `garden_scene.gd:15` 已回 16°/5.8；截图工具按 16°/5.8 重拍 | **关闭** |
| 截图含 `-16/-5` 飘字 | 工具 `_hide_floaters()`；新图目检无飘字 | **关闭** |
| 640×360 / 混合阵营 / 90 帧缺失 | 三件证据均已生成并可读取 | **关闭** |
| 性能不可判 | 仍只有 1 次干净 legacy；load 7.4–10.6 | **未关闭（条件：受控 3 连跑）** |
| 美术签字 | 05-art-signoff 13:45 签“条件通过”，但基于 13:29/13:40 旧图与旧参数；14:00 新参数/新图未追签 | **未关闭（条件：追签）** |

---

## 5. 残留风险

1. **夜间局部高光**：用户指定脸框 `max=255`、>=250 共 225 px（0.67%），集中在脸颊；脸颊子 ROI p95=250。p95/占比门禁已过，但 `max<250` 字面未过；若美术以“无纯白”为口径，仍应微调高光或接受签字。
2. **性能样本不足**：本轮仅 1 次干净 legacy（avg 47.5），低于 54.8 门槛；同次 A/B shown=60.5、hidden=64.8，且清理遗留进程后明显回升，属负载噪声。**不能据此判回退，也不能据此判 PASS**；需受控 3 连跑。交错稳态（shown 中位/draw delta）本轮未跑。
3. **灯光参数与签字版不一致**：02 §4.5 / 01 §8.5 签字值为 `energy=0.20+glow*0.25`、灯位 `(-0.38,0.90,-0.22)`、核心光晕 `glow*0.55`、外圈 `glow*0.15`；当前代码为 `0.14+glow*0.18`、灯位 `(-1.30,0.70,-0.90)`、核心 `glow*0.22`、外圈 `glow*0.06`。这是为压脸光做的进一步调暗，**效果达标但流程上未追签**；同时灯位离灯笼约 1.3 m，近景地面暖池偏弱，需美术确认“光池可读”仍成立。
4. **90 帧只抽检 6 帧**：无 T-pose、无飘字；脚滑 ≤5%、过渡 ≤0.25s、Nearest 移动闪烁未逐帧量化。序列为 1280×720（非 1920），符合“90 帧”证据要求，但不是 1920 母版。
5. **`patrol_fox.png` 树干遮挡仍在**：14:00:59 新图仍被树干挡住狐侍，属既有工具取景 BUG（03/05 已记），本轮未修，非游戏逻辑阻塞。
6. **混合阵营图含章鱼/妖灵**：`cycle1_mixed_cast.png` 背景仍有红色章鱼，虽然主体是 Rogue + 扫园人 + 女孩；若发布图要求“干净同框”，需隐藏该生物。另 `_stage_mixed_cast` 隐藏的是 `world.monsters`，章鱼未被隐藏，说明它不在该列表（工具层问题）。
7. **基准帧率环境**：本机 4 逻辑核、load 最高 10.57，任何单次 FPS 都不具判决力；01 v2 的“本机噪声”说明继续适用。

---

## 6. 截图清单与时间

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 文件时间 | 尺寸 | 内容/结论 |
|---|---|---|---|
| `patrol_lantern_dusk.png` | 2026-10-31 14:00:51 | 1920×1080 | 16°/5.8 近景；无飘字；黄昏脸 p95=199；灯/杆/玻璃可见 |
| `patrol_lantern_night.png` | 2026-10-31 14:00:53 | 1920×1080 | 同机位 00:00；无飘字；脸 p95=185（用户 ROI）；脸颊局部 max=255 |
| `cycle1_640x360.png` | 2026-10-31 14:00:51 | **640×360** | 内部视口源画面；清晰、无 UV 缝、无飘字 |
| `cycle1_noon.png` | 2026-10-31 14:00:55 | 1920×1080 | 正午广角；无飘字；可读 |
| `cycle1_wide_night.png` | 2026-10-31 14:00:56 | 1920×1080 | 夜间广角；街灯暖池清楚；提灯人脚下暖池偏淡 |
| `cycle1_mixed_cast.png` | 2026-10-31 14:01:00 | 1920×1080 | Rogue + 扫园人 + 女孩同框；无飘字；背景含章鱼 |
| `patrol_wide_dusk.png` | 2026-10-31 14:00:48 | 1920×1080 | 默认广角黄昏；无飘字 |
| `patrol_sweeper.png` | 2026-10-31 14:00:57 | 1920×1080 | 扫园人近景；无飘字 |
| `patrol_fox.png` | 2026-10-31 14:00:59 | 1920×1080 | **树干遮挡仍在**（既有工具 BUG） |
| `patrol_compare_on/off.png` | 2026-10-31 14:00:50 | 1920×1080 | 开关对比；无飘字；on 有扫园人，off 无 |
| `patrol_seq/frame_000..089.png` | 2026-10-31 14:10:55–14:11:25 | 1280×720 | 90 帧；抽检无 T-pose、无飘字；WALK 折返可读 |

---

## 7. 一句话

**相机已回 16°/5.8、夜间脸主门禁 p95=185 已过、截图矩阵/无飘字/640×360/混合阵营/90 帧/5 键/回退全过；结论条件放行，余项是脸颊 max=255 局部高光需美术接受或微调、灯光参数偏离 02 §4.5 签字版需追签、性能需受控 3 连跑（本轮 1 次 avg 47.5 受 load 7.4–10.6 与遗留进程影响，不硬判）。**
