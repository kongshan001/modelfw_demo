# 纸偶工坊 · T-20261120-011 QA 独立验收报告

> 验收对象：`godot-paper-doll/` @ `7b78bc9`（T-20261120-010 发布版）
> 验收依据：T-007《纸偶工坊美术评审》§8 + T-013《纸偶工坊策划设计规格 v1.0》
> 执行：game-qa-lead（独立验收；未修改任何游戏逻辑/美术文件；新增 3 个只读 QA 探针，见 §2.4）
> 日期：2026-11-20 · 证据目录：`docs/qa-review/evidence/`

---

## 0. 结论

**不可放行（本轮美术/技术验收）；同时不可公开外放（设计规格 P0-1/2/3 未实现）。**

| 门 | 结论 | 依据 |
| --- | --- | --- |
| 本轮 T-009/T-010 美术+技术门 | **FAIL（4 个阻塞项）** | ① FPS 门禁 4/4 次实测 `<30`；② 16 人剪影 IoU 均值 **0.412 > 0.30**；③ walk 支撑脚水平漂移 **45.26px > 2px**；④ 16 张阵容卡点击可用但键盘不可达 |
| 公开试玩/外放门（T-013 §7） | **BLOCKED（不在本轮范围）** | P0-1 首玩路径、P0-2 角色卡/命名/3 存档/种子、P0-3 阵容收藏/锁定均未实现；§7.1 T0–T8 无法执行；设计基线仍为 4.6/10，不是 7.3 |
| 功能性系统门 | **PASS** | 17 槽 / 83 变体 / 8 向 / 4 动作 / 16 预设 / JSON 存读 / 16 卡烘焙均通过 smoke |
| 构建干净度 | **PASS** | headless 600 帧、截图、showcase、metric、GIF 全链路无 SCRIPT ERROR / Parse Error / 警告 |

**一句话**：系统与大部分美术指标是真的（墨色 7.02%、ΔL\* 32.0、UI 对比 5.01–7.0、正/背 IoU 0.695、6s GIF 6.000s），但 **性能、剪影区分度、走姿防滑、键盘可达** 四项没到 §8 通过线，必须打回；FPS 实测受本机后台负载影响（同机 T-009 基线也 `<30`），需在洁净环境复测后才能判断是否仅环境问题。

---

## 1. 环境与构建

| 项 | 值（来自 `evidence/logs/environment.txt` 与命令实测） |
| --- | --- |
| 机器 | MacBookAir7,2 · Intel Core i7-5650U @ 2.20GHz |
| GPU | Intel HD Graphics 6000（OpenGL 4.1 INTEL-18.8.16，GL Compatibility） |
| OS | macOS 12.7.6 (21H1320) |
| Godot | 4.6.stable.official.89cea1439 |
| ffmpeg | 8.0.1 |
| 构建 | `git rev-parse HEAD` = `7b78bc9`（T-20261120-010），`godot-paper-doll/` 工作区干净 |
| 采样时后台负载 | Lark Helper 20–33%、WebKit 12–34%、XProtect/CalendarAgent/trustd 12–68%、WindowServer 12–35%；见 `evidence/logs/environment.txt` 与各 perf 日志尾部 |
| 分辨率 | 1280×720 窗口；截图 SubViewport 1280×720；showcase 640×360 帧 |

> 本机没有 `timeout` 命令；所有长任务以后台进程 + 日志轮询执行。未使用估算值，全部数字来自下方命令输出。

### 1.1 验收命令（可复现）

```bash
cd godot-paper-doll

# 一键验收（本次结果：FAIL，唯一失败项是 FPS）
bash tools/verify.sh

# 单独复测 FPS（4 次：verify 内 1 次 + 独立 3 次）
godot --path . --resolution 1280x720 -s tools/perf_paperdoll.gd

# 无头 600 帧
godot --path . --headless --quit-after 600

# 真实 GPU 截图（1280×720，7 张）
godot --path . --resolution 1280x720 -s tools/screenshot_paperdoll.gd

# 美术指标原始渲染 + 6s 物料
godot --path . --resolution 1280x720 -s tools/metric_rig.gd
godot --path . --resolution 1280x720 -s tools/showcase_paperdoll.gd
bash tools/record_showcase.sh

# QA 独立复算（新增探针，不调用实现者 measure_paperdoll.py）
python3 tools/qa_metrics.py

# QA 键盘/焦点探针
godot --headless --path . -s tools/qa_input_probe.gd

# QA walk 支撑脚防滑探针
godot --headless --path . -s tools/qa_motion_probe.gd
```

---

## 2. 测试计划（功能 / 视觉 / 性能 / 回归）

### 2.1 功能

| ID | 用例 | 命令 | 阈值 | 判定 |
| --- | --- | --- | --- | --- |
| F-01 | headless 启动 600 帧 | `godot --path . --headless --quit-after 600` | 退出码 0；无 SCRIPT ERROR/Parse Error/WARNING | PASS |
| F-02 | 数据/渲染 smoke | `godot --headless --path . -s tools/smoke_paperdoll.gd` | 17 槽/83 变体/8 向/4 动作/16 预设/16 卡全部 baked/存读往返/无缺纹理 | PASS |
| F-03 | 存档往返 | smoke 内 `save_current` → `load_saved` | 17 槽 outfit + direction + action 完全一致 | PASS |
| F-04 | 快捷键 1–4 / R / S / L / F11 / Esc | `qa_input_probe.gd` | 动作/随机/存读/舞台/关闭全部生效 | PASS |
| F-05 | 方向键 ←→ | `qa_input_probe.gd`（无焦点） | 方向循环 ±1 | PASS（有焦点时被焦点导航吃掉，见 BUG-04） |
| F-06 | 键盘可达全部控件 | `qa_input_probe.gd` | 所有可交互控件可聚焦/可操作 | **FAIL**：16 张 LineupCard `focus_mode=0`，Tab 只到 66 个 Button |
| F-07 | 6s GIF 规格 | `ffprobe docs/shots/showcase/paperdoll_6s.gif` | 640×360 / 30fps / 6.0s / 180 帧 | PASS（实测 6.000000s，180 帧） |

### 2.2 视觉（§8 指标 + 人眼项）

| ID | 用例 | 证据/命令 | 阈值 | 判定 |
| --- | --- | --- | --- | --- |
| V-01 | 墨色族占比 | `qa_metrics.py` ← `metric_doll.png` | ≤9% 角色 bbox | **7.02% PASS** |
| V-02 | 量化色数 | 同上 | ≥80 | **85 PASS** |
| V-03 | 角色/舞台 ΔL\* | 同上（`stage_only.png` 中位 L\*） | ≥25 | **31.99 PASS** |
| V-04 | 3 档明度 / 无双层黑边 / 眼≥4px@95px | `01_face_4x_qa.png` 目检 + 组件测量 | 三档可辨；无内层纯黑双线；眼白≥4px | PASS（眼白 15/13px@2.1× → 4.0/3.5px@95px，**临界**，见 BUG-06） |
| V-05 | 缩略图 AA | `cards_200pct_qa.png`（200% NEAREST 裁切） | 无 1px 阶梯；眼/嘴/帽可辨 | PASS（2× 超采样 + Linear，边缘为软 AA，无阶梯） |
| V-06 | 16 人剪影 IoU | `qa_metrics.py` 独立实现（bbox 等比归一，高 96） | 均值 ≤0.30；p90 ≤0.48 | **FAIL：0.412 / 0.590**（未归一 0.470 / 0.597） |
| V-07 | 16 人纯黑剪影 12/16 可辨 | `silhouettes_16_labeled.png` QA 单人目检 | ≥12/16 | **13/16 可辨**（07 夜巡猫、12 露珠药童、15 香菇小贩为临界）——**正式 3 人协议未执行，BLOCKED** |
| V-08 | 每卡 1 个破形件 | 同上 + `poster_16.png` | 16/16 有帽/武器/披风/背饰之一 | PASS（目检 16/16 有至少 1 个破形件） |
| V-09 | 8 向罗盘 7/8 可辨 | `directions_compass_black.png`、`04_directions.png` | ≥7/8 | **7/8 PASS（QA 单人）**；3/4/5 背向组最接近，正式 3 人协议未执行 |
| V-10 | 正/背 IoU | `qa_metrics.py`（dir_00 vs dir_04） | ≤0.70 | **PASS：0.6948（未归一，余量 0.0052）**；归一 0.5679 |
| V-11 | 相邻方向 IoU | 同上（8 对相邻） | ≤0.75 | **PASS：0.6461 均值 / 0.7427 最大（未归一）**；归一最大 **0.7506（超 0.0006，风险）** |
| V-12 | 无滑步（walk 支撑脚） | `qa_motion_probe.gd` | 支撑相水平漂移 ≤2px@2.1× | **FAIL：dir 6 = 45.26px（左右脚），dir 0 = 5.42px** |
| V-13 | 斩击 ≥3:1 | `qa_metrics.py`（slash.png vs 舞台） | 每条斩击主色 ≥3:1 | **PASS：深边 #8f3030 6.85；外圈 #b23c33 5.03**；金色核心 #ffd27a **1.22:1**（见 BUG-05） |
| V-14 | 4×3 动作关键帧 | `03_actions.png` | 4 动作 × 3 时点，不读字可区分 | PASS（待机/行走/挥击/受击 × 3 帧 + 时间标签） |
| V-15 | 6s GIF 4 动作 | `gif_storyboard.png` + GIF | 6s 内可区分 idle/walk/attack/hit | PASS（640×360，30fps，6.000s） |
| V-16 | UI 小字对比度 | `qa_metrics.py`（AtelierTheme 色值） | ≥4.5:1 | **PASS：5.01–7.0**（白/珊瑚 5.76、白/青绿 5.01、白/紫 6.24、MUTED/纸 6.01、珊瑚深/面板 5.34） |
| V-17 | 无 9px / 无 z 40 | 代码字号审计 + `07_layer.png` | 中文 ≥11px；层视不出现 `z 40` | PASS（make_label 最小 11px；层视只显示“17 层 · 选中：帽子”） |
| V-18 | 舞台接触影/轮廓光 | `hero.png`、`01_studio.png` | 两层接触影；2px 轮廓光 | PASS（目检双层影；轮廓光存在，未逐像素测宽） |
| V-19 | 物料（hero/罗盘/海报/GIF） | `showcase/` | 第一张无 UI；角色 ≥160px；陌生人能说出类型 | 客观项 PASS（hero 无 UI、角色约 560px；poster 角色约 178–225px，均 ≥160）；陌生人测试 **BLOCKED** |

### 2.3 性能

| ID | 用例 | 命令 | 阈值 | 实测 |
| --- | --- | --- | --- | --- |
| P-01 | 一键 FPS | `bash tools/verify.sh` | steady_min ≥30 | **24.0 / avg 29.8 → FAIL** |
| P-02 | FPS 复测 1 | `perf_paperdoll.gd` | 同上 | **13.0 / avg 28.3 → FAIL** |
| P-03 | FPS 复测 2 | 同上 | 同上 | **27.0 / avg 30.0 → FAIL** |
| P-04 | FPS 复测 3 | 同上 | 同上 | **26.0 / avg 29.0 → FAIL** |
| P-05 | T-009 基线 A/B | `git worktree` @ `763d25b` + 同机 perf | 用于判断是否 T-010 回退 | **min 20.0 / avg 23.0；min 28.0 / avg 29.4 → 基线同机也 FAIL**，未观察到 T-010 系统性回退 |
| P-06 | 卡片烘焙 p90 | perf 内 | ≤16ms | 采样 1（perf2）9.80ms PASS；采样 2（perf3）16.02ms、采样 3（perf4）19.15ms **FAIL（负载尖峰）** |
| P-07 | 无头 CPU | headless 600 | 退出 0、无错误 | PASS |

> `perf_paperdoll.gd` 口径：7×1s 采样，丢弃首秒暖机；`steady_min` 是 6 个稳态样本最小值。原始样本全部保留在 `evidence/logs/`。
> T-009 基线脚本是 **5 样本旧口径**（不丢弃首秒），A/B 只作量级参考，不与当前 build 的 7 样本数值做严格同口径比较。
> **性能结论**：当前 build 在本次 QA 环境无法复现 ≥30 FPS；同机 T-009 基线也低于 30，因此不能把失败归因于 T-010 回退，但**也不能签发“Intel 30fps+”**。需在关闭 Lark/WebKit/XProtect 等后台负载的洁净机复测；若仍 <30，按 BUG-01 的优化 brief 整改。

### 2.4 回归

| ID | 用例 | 方法 | 结果 |
| --- | --- | --- | --- |
| R-01 | 旧 6 张截图重拍 | `screenshot_paperdoll.gd` 重拍；与 HEAD `7b78bc9` 逐像素 diff | 01/02/03/04/07 **changed_px=0**；05/06 因脚本内 `randomize_lineup()`（无固定种子）不同，属预期，不是回归 |
| R-02 | 构建无脚本错误 | verify/headless/截图/showcase/metric 日志 grep | 全部无 SCRIPT ERROR / Parse Error / ^ERROR / WARNING |
| R-03 | 功能不回归 | smoke | 17/83/8/4/16/存读/烘焙全通过 |
| R-04 | 缺纹理 | smoke | `missing_textures=0` |
| R-05 | 媒体时长 | ffprobe | `docs/paperdoll.mp4` 8.533s、`docs/paperdoll.gif` 8.560s（verify 口径 6–10s）；**新的 6s GIF 是 `docs/shots/showcase/paperdoll_6s.gif`，verify.sh 未覆盖它（BUG-09 工具缺口）** |

### 2.5 新增 QA 探针（仅测试工具，不改游戏逻辑）

| 文件 | 用途 |
| --- | --- |
| `godot-paper-doll/tools/qa_metrics.py` | 独立复算墨色/色数/ΔL\*/斩击/UI 对比/16 人 IoU/8 向 IoU/随机色相；生成 25%、4× 脸、200% 卡、纯黑剪影/罗盘证据 |
| `godot-paper-doll/tools/qa_input_probe.gd` | 66 个 Button 焦点覆盖、焦点环遍历、快捷键实测、LineupCard 可达性 |
| `godot-paper-doll/tools/qa_motion_probe.gd` | walk 支撑相脚底水平漂移（防滑步） |

> 证据目录内有一份副本：`docs/qa-review/evidence/tools/`。

---

## 3. 结果总表（§8 逐项）

| §8 # | 验收项 | 通过线 | 实测 | 判定 |
| --- | --- | --- | --- | --- |
| 1 | 苔藓骑士 1280 + 4× 裁切 | 墨色族 ≤9%；3 档明度；无双层黑边；眼≥4px@95px | 墨色 **7.02%**；85 色；目检 3 档/无双层黑边；眼白 4.0/3.5px@95px | **PASS（眼临界）** |
| 2 | 缩略图 AA + 200% 裁切 | 无 1px 阶梯；眼/嘴/帽可辨；6 卡剪影不同 | 无阶梯；眼/嘴/帽可辨；16 卡有 ≥6 种轮廓 | PASS（AA）/ 剪影见 #3 |
| 3 | 16 人纯黑剪影 | 12/16 可辨；IoU 均值 ≤0.30；每卡 1 破形件 | QA 单人 **13/16**；IoU **0.412**（p90 0.590）；16/16 有破形件 | **FAIL（IoU）**；12/16 正式协议未执行（BLOCKED） |
| 4 | 8 向罗盘 + 4×3 + 6s GIF | 7/8 方向；正/背 IoU ≤0.70；无滑步；斩击 3:1 | QA 单人 7/8；正/背 **0.6948**；滑步 **45.26px**；斩击 6.85/5.03（金核 1.22） | **FAIL（滑步）**；方向 PASS（临界）、斩击 PASS（金核风险） |
| 5 | 舞台灰度/彩色 | ΔL\* ≥25；接触影两层；2px 轮廓光 | ΔL\* **31.99**；目检双层影；轮廓光存在 | PASS |
| 6 | UI 1280 + 对比度 | 小字 ≥4.5:1；无 9px；键盘可达；无 z 40 | 5.01–7.0；最小 11px；**16 卡键盘不可达**；无 z 40 | **FAIL（键盘）**；其余 PASS |
| 7 | hero/罗盘/16 海报/6s GIF | 第一张无 UI；角色 ≥160px；陌生人能说出类型 | hero 无 UI、约 560px；poster 约 178–225px；GIF 6.000s | PASS（客观；poster 部分 >200 上限）/ 陌生人测试 BLOCKED |
| 8 | 旧 6 张重拍 | 无回归；35 FPS 下限保持 | 确定性视图 diff=0；**FPS min 13–27（4 次）** | **FAIL（FPS）**；截图无回归 |

### 3.1 功能/系统实测输出（原文）

```text
PASS 无 SCRIPT ERROR / Parse Error

PAPERDOLL_SMOKE_OK slots=17 variants=83 dirs=8 actions=4 presets=16 cards=16 baked_cards=16 combos=≈ 9.0×10²⁶ 种外观 procedural_art=true missing_textures=0

PASS PAPERDOLL_SHOTS_OK · 7 张 PNG

PAPERDOLL_FPS samples=[33.0, 37.0, 31.0, 28.0, 24.0, 28.0, 31.0] steady_min=24.0 steady_avg=29.8 gpu=Intel(R) HD Graphics 6000
PAPERDOLL_FPS_LOW min=24.0 avg=29.8

PAPERDOLL_VERIFY_FAILED
```

```text
QA_INPUT buttons=66 focusable_buttons=66 all_controls=247 lineup_cards=16
QA_INPUT focus_cycle=66 ...
QA_INPUT arrow_with_focus dir_changed=false focus_moved=true
QA_INPUT FAIL: lineup cards are clickable but not keyboard-focusable
QA_INPUT_FAILED failures=1
```

```text
QA_WALK dir=0 left_px=5.42 right_px=5.42
QA_WALK dir=6 left_px=45.26 right_px=45.26
QA_WALK_SLIDE max_left_px=45.26 max_right_px=45.26 threshold_px=2.0 worst=dir=6 foot=right
QA_MOTION_FAIL
```

```text
GIF: 640x360, r_frame_rate=30/1, nb_frames=180, duration=6.000000
PAPERDOLL_SHOWCASE_GIF_OK
```

### 3.2 关键指标原文（`evidence/metrics-qa.json`，与实现者 `summary.json` 独立复算一致）

```json
{
  "doll": {
    "ink_ratio_bbox": 0.07018313849100268,
    "quantized_colors_24bin": 85,
    "delta_Lstar": 31.98854165933308
  },
  "lineup_silhouette": {
    "aligned_mean": 0.46993152290586954,
    "normalized_mean": 0.4121689629909638,
    "normalized_p90": 0.5903583764838606,
    "normalized_max": 0.7227443609022557
  },
  "direction_silhouette": {
    "front_back_iou_aligned": 0.6948498574064754,
    "front_back_iou_normalized": 0.5678901820352134,
    "adjacent_iou_max_aligned": 0.7426545086119554,
    "adjacent_iou_max_normalized": 0.7506339814032121
  },
  "slash": {
    "#8f3030": {"contrast_vs_stage": 6.85},
    "#b23c33": {"contrast_vs_stage": 5.03},
    "#ffd27a": {"contrast_vs_stage": 1.22}
  },
  "ui_contrast": {
    "white_on_coral_deep": 5.76, "white_on_teal_deep": 5.01,
    "white_on_plum_deep": 6.24, "muted_on_panel": 6.01, "muted_on_cream": 7.0
  },
  "random_color_discipline": {
    "all_10_hue_clusters_le3": true,
    "all_10_hue_clusters_le2": false
  }
}
```

---

## 4. Bug 列表（含复现）

### BUG-01 · FPS 门禁未过（P0，阻塞） — 当前 build 不能签“Intel ≥30”

- **复现**：`cd godot-paper-doll && godot --path . --resolution 1280x720 -s tools/perf_paperdoll.gd`（重复 3 次）
- **期望**：`PAPERDOLL_FPS_OK`，`steady_min ≥30`
- **实际**：3 次独立 + verify 内 1 次全部 `PAPERDOLL_FPS_LOW`：
  - `samples=[33,37,31,28,24,28,31] min=24.0 avg=29.8`
  - `samples=[33,29,13,29,33,33,33] min=13.0 avg=28.3`
  - `samples=[28,29,32,31,31,27,30] min=27.0 avg=30.0`
  - `samples=[29,31,31,28,26,29,29] min=26.0 avg=29.0`
- **环境证据**：采样时 Lark/WebKit/XProtect/CalendarAgent 持续占 20–68% CPU；`perf4` 日志含 `IMKClient Stall detected ... 1.33 secs`。
- **A/B 结论**：同机 T-009 基线（`763d25b` worktree）两次为 `min=20.0/avg=23.0`、`min=28.0/avg=29.4`，也 `<30`；**未发现 T-010 回退**，但当前 build 同样未达标。`§8 #8` 写的是“35 FPS 下限保持”，当前 4 次 min 13/24/26/27 也低于 35；任务/设计门是 ≥30，两个口径都未过。
- **下一步**：洁净环境（关闭浏览器/Lark Helper/XProtect 后）复测；仍低则按 §6 性能 brief 优化，不允许以“环境问题”直接放行。

### BUG-02 · 16 人剪影 IoU 0.412 > 0.30（P0，阻塞；T-012 决策项）

- **复现**：`godot --path . --resolution 1280x720 -s tools/metric_rig.gd` → `python3 tools/qa_metrics.py`
- **期望**：均值 ≤0.30、p90 ≤0.48（§8 #3 / T-013 D3）
- **实际**：归一均值 **0.4122**、p90 **0.5904**、最大 **0.7227**；未归一均值 0.4699、p90 0.5970。
- **人眼**：`silhouettes_16_labeled.png` QA 单人 13/16 可辨（07/12/15 临界）；正式 3 人测试未执行。
- **性质**：16 人共享同一躯干/头/腿骨架，单靠帽/道具不足以把 IoU 压到 0.30；T-009 报告已承认结构性，本任务仍按 §8 判 FAIL。**不要求本任务修**，交 T-012 决策是否要求二次体型/专属剪影资产。
- **证据**：`evidence/silhouettes_16_black.png`、`silhouettes_16_labeled.png`、`metrics-qa.json`。

### BUG-03 · walk 支撑脚滑步 45.26px（P1，阻塞 §8 #4 “无滑步”）

- **复现**：`godot --headless --path . -s tools/qa_motion_probe.gd`
- **期望**：支撑相（脚底距最低点 ≤1 local）水平漂移 ×2.1 ≤2px
- **实际**：`dir=6 left_px=45.26 right_px=45.26`；`dir=0 left_px=5.42 right_px=5.42`。
- **视觉**：`walk_contact_strip.png`（showcase 帧 42–78）可见角色原地走、脚随步幅向后扫；舞台无横向位移，读作滑步。
- **修复方向（下一轮）**：脚部 IK/脚锁定 + 根位移/地面滚动，或改成原地踏步式 gait；保留 8 keys 与脚掌滚动。验收命令同 BUG-03，目标 ≤2px。

### BUG-04 · 16 张阵容卡键盘不可达 + 方向键与焦点导航冲突（P1，§8 #6 “键盘可达” FAIL）

- **复现**：`godot --headless --path . -s tools/qa_input_probe.gd`
- **实际**：
  - 66 个 Button 全部 `FOCUS_ALL` 且焦点环遍历 66 个；**16 张 LineupCard 是 `PanelContainer focus=0`**，点击可载入，但 Tab 永远到不了，键盘无替代载入方式。
  - 有焦点按钮时按 →：`dir_changed=false focus_moved=true`（方向键被 UI 焦点导航吃掉）；无焦点时方向键正常。
- **期望**：全部可交互控件可键盘操作；←→ 按设计与 UI 提示“←→ 方向”应切方向。
- **修复方向**：LineupCard 设 `FOCUS_ALL` + 2px 焦点环 + Enter/Space 载入；方向键在卡片/按钮聚焦时的行为二选一（改为仅 Tab 导航，或提供 Ctrl+←→ 备用），并在 UI 文案中写清。

### BUG-05 · 斩击金色核心 1.22:1（P2，非主判定）

- **复现**：`qa_metrics.py` 的 `slash` 段
- **期望**：§8 #4 “斩击 3:1”
- **实际**：深边 `#8f3030` **6.85**、外圈 `#b23c33` **5.03** 均过；金色核心 `#ffd27a` **1.22**（对舞台 `#f5edde`）。若“每条斩击色”都算，金色核心 FAIL；若只要求主斩击边可见，则 PASS。
- **建议**：给金色核心加 0.8px 深墨描边，或改为 ≥3:1 的暖金；由 T-012 独立判定口径。

### BUG-06 · 眼白 4.0/3.5px @95px，贴 §8 “眼≥4px”下限（P2）

- **复现**：`metric_doll.png` 组件测量：眼白 bbox 15×15 与 13×12 @2.1×；按角色高 353px→95px 缩放系数 0.269，得 **4.0×4.0px / 3.5×3.2px**；虹膜约 10–11px @2.1× → 2.8px @95px。
- **判定**：按“眼形（眼白+虹膜）”口径一只眼刚好 4px、另一只 3.5px，属于临界 PASS；按虹膜口径 <4px。缩略图 200% 裁切目检可辨，但建议下一轮把 mini 眼白再放大 1px 或加粗虹膜，留出余量。

### BUG-07 · 3 人用户测试协议未执行（BLOCKED 证据，不是构建 bug）

- §8 #3 的 **12/16**、§8 #4 的 **7/8**、§8 #7 的“陌生人能说出产品类型”、T-013 §7.1 的 **T0–T8** 都要求 3 名未见过项目的测试者；本轮无外部测试者，只有 QA 单人目检（13/16、7/8）。
- **不得**把单人目检当成正式通过；T-012 复评/下一轮外放前必须补 3 人测试与录屏。

### BUG-08 · §8 回归线“35 FPS 下限”与任务/设计门“≥30”不一致（P2，口径）

- §8 #8 写“35 FPS 下限保持”，任务/设计 D8 写“Intel min ≥30”。T-010 的 README 宣称 30–45，T-009 实测 31–48。本轮 min 13/24/26/27（负载下），两个口径都未过；即使洁净机回到 31–33，也无法满足 §8 的 35。
- **建议**：T-012 / 策划明确以 30 还是 35 为门；若坚持 35，当前美术/性能预算需要再降负载（24Hz 试衣镜→20Hz、卡片预烘焙、减少实时层）。

### BUG-09 · verify.sh 未覆盖 6s 展示 GIF（P2，QA 工具缺口）

- `verify.sh` 第 5 步只校验 `docs/paperdoll.mp4` / `docs/paperdoll.gif`（8.53/8.56s，T-006 旧演示）；§8 要求的 6s GIF 是 `docs/shots/showcase/paperdoll_6s.gif`，不在 verify 覆盖内。本轮由 QA 单独 ffprobe 验证为 6.000s/180 帧。
- 下一轮建议把 `verify.sh` 增加该文件与 `record_showcase.sh` 的时长/帧数校验（测试工具改动，不影响游戏）。

### BUG-10 · 设计规格 P0-1/2/3 未实现（公开外放门 BLOCKED）

- 当前 build 仍是 T-006/T-009 的工具界面：17 槽平铺未分组；三个随机入口仍叫“本槽随机/随机纸偶/随机阵容”；头部仍显示 `≈9.0×10²⁶ 种外观`；无 3 步引导；无命名/3 存档/1080×1350 角色卡/6 位种子；4×4 阵容不能“写入当前/保存/读回/锁定”；本槽随机仍是全色板裸随机（设计 D5 要求从当前 scheme 选）。
- 因此 T-013 §7.1 的 T0–T8 无法执行，设计加权分仍是基线 4.6（不是 7.3）。**这不属于 T-009/T-010 的整改范围**，但意味着本 build 只能内部 demo/devlog，不能公开试玩/外放。
- 证据：`evidence/shots/01_studio.png`、`05_lineup.png`、`07_layer.png`；代码审计 `main.gd` 头部文案与保存函数。

---

## 5. 截图 / 证据清单

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `evidence/shots/01_studio.png` | 1280×720 试衣镜默认苔藓骑士 | 主视觉/UI |
| `evidence/shots/02_wardrobe.png` | 衣柜换装（尖帽/长发/配色/行走朝右） | 换装反馈 |
| `evidence/shots/03_actions.png` | 4 动作 × 3 关键帧 | §8 #4 |
| `evidence/shots/04_directions.png` | 8 向罗盘 | §8 #4 |
| `evidence/shots/05_lineup.png` | 随机 16 人阵容（脚本无固定 seed） | 阵容/随机 |
| `evidence/shots/06_saved.png` | 存档状态 | 存读 |
| `evidence/shots/07_layer.png` | 层视 17 层展开、选中帽子 | §8 #6/层视 |
| `evidence/01_studio_25pct.png` | 320×180 25% 缩略 | 25% 可读性 |
| `evidence/05_lineup_25pct.png` | 320×180 阵容 25% | 25% 可读性 |
| `evidence/01_face_4x_qa.png` | 4× 脸部裁切 | 线宽/明度/眼 |
| `evidence/cards_200pct_qa.png` | 200% 阵容卡裁切 | 缩略图 AA |
| `evidence/silhouettes_16_black.png` | 16 人纯黑剪影 4×4 白底 | §8 #3 |
| `evidence/silhouettes_16_labeled.png` | 带 00–15 编号的同图 | §8 #3 人眼计数 |
| `evidence/directions_compass_black.png` | 8 向纯黑剪影 3×3 环 | §8 #4 |
| `evidence/walk_contact_strip.png` | showcase walk 帧 42–78 接触表 | 滑步证据 |
| `evidence/gif_storyboard.png` | idle/walk/attack/hit 代表帧 | 6s GIF 动作可辨 |
| `evidence/showcase/hero.png` | 无 UI 舞台 hero | §8 #7 |
| `evidence/showcase/compass.png` | 彩色 8 向罗盘 | §8 #7 |
| `evidence/showcase/poster_16.png` | 16 人海报（角色约 178–225px） | §8 #7 |
| `evidence/showcase/paperdoll_6s.gif` | 640×360 / 30fps / 6.000s | §8 #4/#7 |
| `evidence/metrics-qa.json` | QA 独立指标 JSON | 全部数值 |
| `evidence/logs/qa_verify_plain.log` | verify.sh 原始输出（去 ANSI） | 门禁 |
| `evidence/logs/qa_perf2.log` / `qa_perf3.log` / `qa_perf4.log` | FPS 复测原始输出 | 性能 |
| `evidence/logs/qa_perf_t009b.log` / `qa_perf_t009c.log` | T-009 基线 A/B | 回退判断 |
| `evidence/logs/qa_input2.log` | 键盘探针输出 | BUG-04 |
| `evidence/logs/qa_motion.log` | 滑步探针输出 | BUG-03 |
| `evidence/logs/environment.txt` | 机器/GPU/后台负载 | 采样条件 |
| `evidence/tools/` | 3 个 QA 探针副本 | 复现 |

---

## 6. 整改 Brief（给下一轮；QA 不执行实现）

> 按角色拆分；每条给出可复现验收命令。顺序建议：P0 性能/剪影 → P1 滑步/键盘 → P2 金核/眼白 → 设计 P0-1/2/3。

### 6.1 Game Engineer（性能 / 键盘可达 / verify 工具）

1. **FPS 洁净复测**：关闭 Lark Helper/WebKit/XProtect 后重跑 `tools/perf_paperdoll.gd` 3 次；目标 `steady_min ≥30`（若 T-012 确认 35，则 ≥35）。若仍低：
   - 试衣镜 24Hz → 20Hz（保留定格风格）；
   - 卡片/罗盘/动作弹层保持一次性烘焙，避免同帧 16 张重烘焙（`PAPERDOLL_BAKE` p90 在负载下曾 19.15ms）；
   - 预烘焙气场/披风/背饰等大层；检查 `_process` 是否有每帧 `queue_redraw`。
2. **LineupCard 键盘可达**：`focus_mode = FOCUS_ALL`、焦点环复用 `AtelierTheme.focus_style()`、Enter/Space 触发 `pressed`；解决 `←→` 与焦点导航冲突（建议方向键仅在没有焦点时切方向，或焦点环改用 Tab/上下键）。
3. **verify.sh 覆盖 6s GIF**：增加 `docs/shots/showcase/paperdoll_6s.gif` 的存在性 + ffprobe 6.0s/180 帧校验；保留原 mp4/gif 检查。
4. **验收**：`bash tools/verify.sh` 输出 `PAPERDOLL_VERIFY_OK`；`qa_input_probe.gd` 0 failures。

### 6.2 Game Artist（剪影 / 滑步 / 金核 / 眼白）

1. **16 人剪影**：目标 IoU 均值 ≤0.30、p90 ≤0.48，同时 12/16 可辨。方向：每预设独立体型比例/专属剪影资产（宽肩/矮胖/长袍/翅膀/盾），不是只加帽子；给 07 夜巡猫、12 露珠药童、15 香菇小贩补更明显的破形件。
2. **walk 防滑**：脚锁定/根位移/地面滚动或原地踏步 gait；`qa_motion_probe.gd` 目标 `max_px ≤2.0`。
3. **斩击金色核心**：提高至 ≥3:1 或加深色描边；主斩击边保持 6.85/5.03。
4. **mini 眼**：眼白从 15/13px @2.1× 提升到 ≥16px，保证 95px 下 ≥4.3px；虹膜同步加粗。
5. **验收**：`metric_rig.gd` + `qa_metrics.py` 全部指标；`walk_contact_strip.png` 重拍；`paperdoll_6s.gif` 重录。

### 6.3 Game Designer（设计 P0 / 口径）

1. 明确 FPS 门是 30 还是 35（§8 与 T-013 冲突）；明确斩击“金核是否计入 3:1”。
2. 推进 P0-1/P0-2/P0-3 的实现排期；当前 build 不具备公开试玩条件（T0–T8 不可执行）。
3. 确认 12/16、7/8 的正式 3 人测试脚本与录屏模板。

### 6.4 Game QA Lead（下一轮）

1. 3 人用户测试（T0–T8、12/16、7/8、陌生人物料）与录屏。
2. 洁净机 FPS 3 次 + 烘焙 p90；保留原始 samples。
3. 重跑本报告 §1.1 全命令；更新 `docs/qa-review/paperdoll-qa.md`。
4. 回归清单见 §7。

---

## 7. 回归清单（改动前后必须复测）

- [ ] `bash tools/verify.sh` → `PAPERDOLL_VERIFY_OK`（FPS min ≥30；6s GIF 已纳入）
- [ ] `PAPERDOLL_SMOKE_OK slots=17 variants=83 dirs=8 actions=4 presets=16 cards=16 baked_cards=16 ... missing_textures=0`
- [ ] headless 600：无 SCRIPT ERROR / Parse Error / WARNING
- [ ] `qa_metrics.py`：墨色 ≤9%、色数 ≥80、ΔL* ≥25、剪影均值 ≤0.30/p90 ≤0.48、正/背 ≤0.70、相邻 ≤0.75、UI ≥4.5、斩击主色 ≥3:1
- [ ] `qa_motion_probe.gd`：`QA_MOTION_OK`（≤2px）
- [ ] `qa_input_probe.gd`：`QA_INPUT_OK`（16 卡可聚焦 + 快捷键全过）
- [ ] 6s GIF：640×360 / 30fps / 6.000s / 180 帧
- [ ] 7 张 1280×720 截图；确定性视图与批准基线逐像素 diff=0（05/06 随机视图另存）
- [ ] 25% / 4× 脸 / 200% 卡 / 16 剪影 / 8 向罗盘重拍
- [ ] 旧 6 张截图重拍无 UI/布局回归

---

## 8. 残留风险

1. **FPS 判定的环境敏感性**：本机后台 Lark/WebKit/XProtect 常驻 20–68% CPU，4 次实测 min 24/13/27/26；同机 T-009 基线也 20/28。未发现 T-010 回退，但当前 build 不能签发 ≥30；洁净机复测前应视为**未验证通过**。
2. **8 向是 2.5D 近似**：正/背 IoU 0.6948 只比 0.70 低 0.0052；相邻归一最大 0.7506 略超 0.75。T-012 若采用更严口径，可能直接打回。
3. **剪影是结构性问题**：0.412 距 0.30 差 0.112；不是调帽檐/换色能解决，需二次体型/专属剪影资产；本轮没有修改。
4. **走姿**：45px 滑步在 640×360 GIF 中肉眼可见；修复可能牵动 DollPose/渲染层，需回归 8 向/4 动作。
5. **随机色彩口径冲突**：T-007 P1-4 用“≤3 色相簇”，T-013 §6.3 写“≤2 有彩色相”；本轮 10/10 ≤3、仅 6/10 ≤2。需要策划/美术统一口径。
6. **缩略图 AA**：2× 超采样 + Linear 在 4× 裁切下是软边而非阶梯，符合评审意图；但不是原生 4×/MSAA，极小字/眼睛仍接近 4px 下限。
7. **展示物料陌生人测试未做**：hero/poster/GIF 客观规格过，但“第一眼能说出产品类型”没有 3 人证据。
8. **公开外放未具备**：P0-1/2/3 未实现；即使本轮美术/性能修完，仍需设计门的 T0–T8。
9. **截图随机性**：05/06 由 `randomize_lineup()` 生成且无固定 seed，与 HEAD 逐像素不同；回归比较只对 01/02/03/04/07 有意义。
10. **媒体范围**：只验证桌面 1280×720；移动/Web、音频、本地化未测（设计明确 P1/P2）。

---

## 9. 验收签署

| 角色 | 结论 | 备注 |
| --- | --- | --- |
| QA Lead（本报告） | **不可放行** | 阻塞项：BUG-01 FPS、BUG-02 剪影 IoU、BUG-03 滑步、BUG-04 键盘；公开外放另有 BUG-10 |
| 待 T-012 美术复评 | — | 用同一 build/证据独立复评；重点裁决 BUG-02（0.412 是否接受）与 BUG-05（金核口径） |
| 待下一轮 Engineer/Artist | — | 按 §6 brief 整改后，按 §7 回归清单复测 |

> 本报告所有数值均来自当前 build 的实际命令输出与 `docs/qa-review/evidence/` 原始文件；未使用估算值。QA 未修改游戏逻辑/美术；新增的 3 个只读探针已在 §2.5 注明，并随本报告提交。
