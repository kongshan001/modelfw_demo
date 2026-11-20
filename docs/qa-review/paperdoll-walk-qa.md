# 纸偶工坊 · 走路脚姿/滑步修复 QA 复验（T-20261121-002）

> 验收对象：`godot-paper-doll/` @ `18537e7`（T-20261121-001 走路脚姿/滑步修复）
> 验收依据：T-20261120-011 QA **BUG-03**（walk 支撑脚 45.26px）+ T-20261120-012 美术复评 **R2-P0-2** + 本任务 T-20261121-002
> 执行：`game-qa-lead`（独立验收；**未修改任何游戏逻辑/美术**；只扩展了 1 个 QA 探针，见 §2.5）
> 日期：2026-11-21 · 证据目录：`docs/qa-review/evidence/walk/`

---

## 0. 结论

**本轮 walk 修复：PASS（可放行，进入 T-003 美术独立复评）。**

| 门 | 结论 | 依据 |
| --- | --- | --- |
| 本轮 walk 修复门 | **PASS** | 8 向支撑脚水平漂移全部 **0.00px**（阈值 2px）；侧向 2s 渲染逐像素锁定；6s GIF 旧版支撑脚扫动 **43.30px** → 新版 **0.00px**；脚掌 −15°→0°→+22°；膝内角最大 **151.3°**（无过伸）；左右镜像 mask IoU **1.0000** |
| 功能/回归门 | **PASS** | 17 槽 / 83 变体 / 8 向 / 4 动作 / 16 预设 / 16 卡 / 存读全过；headless 600 无 SCRIPT ERROR/Parse Error/WARNING；确定性截图 01/02/03/04/07 逐字节一致 |
| 整体 build 放行门 | **不可放行（BLOCKED）** | 阻塞项是上一轮遗留、本轮未修：BUG-01 FPS 未 3/3 签（本轮 2/3）、BUG-02 剪影 IoU 0.412、BUG-04 16 卡键盘不可达、BUG-10 公开外放 P0 未实现。**这些不是 walk 修复造成的回归。** |

**一句话**：走路“原地蹬腿/脚踝拧”的核心问题已修掉，2px 硬门以 0.00px 通过，且用渲染像素和用户可见的 6s GIF 双重独立复核；但当前 build 仍不能整体放行，阻塞项与上一轮相同。

---

## 1. 环境与构建

| 项 | 值（来自 `evidence/walk/logs/environment.txt` 与命令实测） |
| --- | --- |
| 机器 / OS | MacBookAir7,2 · Intel Core i7-5650U @ 2.20GHz · macOS 12.7.6 (21H1320) |
| GPU / 渲染 | Intel HD Graphics 6000 · GL Compatibility |
| Godot | 4.6.stable.official.89cea1439 |
| ffmpeg | 8.0.1 |
| 构建 | `git rev-parse HEAD` = `18537e75bc0ee5d7acad70f45054edfbe9879bfe`；验收开始时 `godot-paper-doll/` 工作区干净 |
| 采样时后台负载 | Lark Helper 26.5% + 21.3%、node 14.4%、WindowServer 12.6%、WebKit 10.8%、claude 8.1% |
| 分辨率 | 试衣镜/截图 1280×720；walk rig 640×360 @30fps；接触帧 1280×720（4× 渲染） |

> 本机没有 `timeout`；所有 GPU 任务前台执行并正常退出（EXIT=0），未出现窗口阻塞，无需 `pkill`。

### 1.1 验收命令（全部实际执行）

```bash
cd /Users/ks_128/Documents/modelfw_demo/godot-paper-doll

# 1) 原始 QA 探针（0/6 向，BUG-03 同口径）
godot --headless --path . -s tools/qa_motion_probe.gd

# 2) 本轮扩展 8 向 QA 探针（证据副本；项目内 canonical 工具保持 0/6）
godot --headless --path . -s /Users/ks_128/Documents/modelfw_demo/docs/qa-review/evidence/tools/qa_motion_probe_8dir.gd

# 3) 美术自检探针（仅交叉核对，不作为 QA verdict）
godot --headless --path . -s tools/artist_walk_probe.gd

# 4) 功能回归
godot --headless --path . -s tools/smoke_paperdoll.gd
godot --path . --headless --quit-after 600
godot --headless --path . -s tools/qa_input_probe.gd

# 5) 一键 headless 验收
SKIP_GPU=1 bash tools/verify.sh

# 6) 真机截图回归（重拍 7 张）
godot --path . --resolution 1280x720 -s tools/screenshot_paperdoll.gd

# 7) FPS / 烘焙（3 次独立采样）
godot --path . --resolution 1280x720 -s tools/perf_paperdoll.gd

# 8) 重拍 walk：侧向 dir=6 / 正面 dir=0 / 左向 dir=2（60 帧 2s + 8 contact 帧）
godot --path . --resolution 1280x720 -s tools/walk_rig.gd -- \
  --out=res://docs/qa-walk/side  --dir=6 --seconds=2 --scale=2.05
godot --path . --resolution 1280x720 -s tools/walk_rig.gd -- \
  --out=res://docs/qa-walk/front --dir=0 --seconds=2 --scale=2.05
godot --path . --resolution 1280x720 -s tools/walk_rig.gd -- \
  --out=res://docs/qa-walk/left  --dir=2 --seconds=2 --scale=2.05

# 9) GIF / MP4 合成（以 side 为例；front 同）
ffmpeg -y -framerate 30 -start_number 0 -i docs/qa-walk/side/frame_%03d.png \
  -vf "split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 docs/qa-review/evidence/walk/walk_side_2s_qa.gif
ffmpeg -y -framerate 30 -start_number 0 -i docs/qa-walk/side/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart \
  docs/qa-review/evidence/walk/walk_side_2s_qa.mp4

# 10) 媒体规格
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,nb_frames,r_frame_rate \
  -show_entries format=duration -of default=nw=1 <file>
```

---

## 2. 测试计划（功能 / 视觉 / 性能 / 回归）

### 2.1 功能

| ID | 用例 | 命令 | 阈值 | 判定 |
| --- | --- | --- | --- | --- |
| F-01 | headless 启动 600 帧 | `godot --path . --headless --quit-after 600` | 退出 0；无 SCRIPT ERROR/Parse Error/^ERROR/WARNING | **PASS** |
| F-02 | 数据/渲染 smoke | `godot --headless --path . -s tools/smoke_paperdoll.gd` | 17 槽 / 83 变体 / 8 向 / 4 动作 / 16 预设 / 16 卡 baked / 存读往返 / missing_textures=0 | **PASS** |
| F-03 | 存档往返 | smoke 内 `save_current` → `load_saved` | 17 槽 outfit + direction + action 完全一致 | **PASS** |
| F-04 | 键盘可达回归 | `godot --headless --path . -s tools/qa_input_probe.gd` | `QA_INPUT_OK` 0 failures | **FAIL（既有 BUG-04，非本轮引入）**：16 卡 `focus=0`；`arrow_with_focus dir_changed=false focus_moved=true` |
| F-05 | 媒体规格 | `ffprobe` | 见 §3.5 | **PASS** |

### 2.2 视觉

| ID | 用例 | 方法/证据 | 阈值 | 判定 |
| --- | --- | --- | --- | --- |
| V-01 | 8 向支撑脚漂移 | 扩展 QA 探针 240 采样/向 | 每向 max ≤2px @2.1× | **PASS：8/8 向 0.00px** |
| V-02 | 重点 dir6/dir0 | 同上 | ≤2px | **PASS：0.00 / 0.00** |
| V-03 | 支撑相 x 锁定 | 相位 <0.58 的脚 x 极差 | ≤2px | **PASS：0.00px** |
| V-04 | 脚掌滚动区间 | `foot_angle_l/r` 全周期 | [−15°, +22°]，且 8 keys 可见 heel→flat→toe | **PASS：精确 [−15.0°, +22.0°]** |
| V-05 | 膝过伸 | 膝内角（hip-knee-foot） | <179° | **PASS：最大 151.3°** |
| V-06 | 左右镜像 | dir0 同相位左右曲线；dir2 vs dir6 翻转 | 误差 ≤0.01 local；mask IoU ≥0.99 | **PASS：mirror_err 0.0000；IoU 1.0000** |
| V-07 | 侧向 2s 可见无滑步 | 640×360 逐帧渲染 + 底部靴像素跟踪 | 支撑窗口 x 扫动 ≤2px（目检+GIF） | **PASS：支撑窗口 0.00px** |
| V-08 | 用户可见 6s GIF | 旧/新 6s GIF walk 段逐帧跟踪（f042–f078） | 旧滑步应消失 | **PASS：旧 43.30px → 新 0.00px** |
| V-09 | 接触表/脚姿 | 8 keys × 4× 渲染，侧/正面 | 无断踝、无单侧外翻、脚掌滚动可读 | **PASS（侧向）；正/背面 2.5D 倾斜见 P2-W01** |
| V-10 | 截图无回归 | 重拍 7 张并与 HEAD 逐字节比较 | 确定性视图 diff=0 | **PASS：01/02/03/04/07 字节一致；05/06 随机属预期** |

### 2.3 性能

| ID | 用例 | 命令 | 阈值 | 实测 |
| --- | --- | --- | --- | --- |
| P-01 | FPS 3 次 | `perf_paperdoll.gd` ×3 | 3/3 `steady_min ≥30` | **2/3 PASS：33 / 31 / 21**（第 3 次受负载尖峰） |
| P-02 | 卡片烘焙 p90 | perf 内 | ≤16ms | **PASS：11.00 / 11.11 / 11.05ms** |
| P-03 | walk 修复对性能影响 | 对比上一轮 | 不引入新回退 | **未观察到新回退**（只改 `doll_pose.gd`，渲染管线未动） |

### 2.4 回归

| ID | 用例 | 方法 | 结果 |
| --- | --- | --- | --- |
| R-01 | 17 槽 / 83 变体 / 8 向 / 4 动作 / 16 预设 / 16 卡 | smoke | **PASS** |
| R-02 | 存读 | smoke | **PASS** |
| R-03 | 无解析/脚本错误 | headless 600 + verify + 全部工具日志 grep | **PASS：无 SCRIPT ERROR / Parse Error / ^ERROR / WARNING** |
| R-04 | 确定性截图 | 重拍并与 HEAD 逐字节 diff | **PASS：01/02/03/04/07 一致；05/06 无固定 seed，预期不同** |
| R-05 | 改动面 | `git diff --name-only 71e011e 18537e7` | **游戏代码仅 `scripts/doll/doll_pose.gd`**；新增 `tools/artist_walk_probe.gd`、`tools/walk_rig.gd`；其余为文档/证据图 |

### 2.5 QA 探针变更（仅测试工具，已在报告注明）

- 原 `tools/qa_motion_probe.gd` 只覆盖 dir 0/6（BUG-03 同口径）。本轮为满足“8 向逐项记录”，QA 在**证据副本**中扩展为 8 向 + 支撑相 x 锁定 + 鞋底高度 + 膝内角 + 脚掌区间 + 左右对称：
  `docs/qa-review/evidence/tools/qa_motion_probe_8dir.gd`
- 项目内 canonical `godot-paper-doll/tools/qa_motion_probe.gd` 已还原为 HEAD 的 0/6 版本，保证 BUG-03 数值可直接对比。
- 扩展探针保留原输出标记 `QA_WALK dir=...` / `QA_WALK_SLIDE` / `QA_MOTION_OK`，新增 `QA_WALK_POSE` 行；不修改任何游戏逻辑/美术。

---

## 3. 执行结果（实际输出）

### 3.1 8 向支撑脚漂移（扩展 QA 探针原文）

```text
QA_WALK dir=0 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=151.3 pitch_deg=[-15.0, 22.0]
QA_WALK dir=1 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=150.4 pitch_deg=[-15.0, 22.0]
QA_WALK dir=2 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=149.7 pitch_deg=[-15.0, 22.0]
QA_WALK dir=3 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=150.4 pitch_deg=[-15.0, 22.0]
QA_WALK dir=4 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=151.3 pitch_deg=[-15.0, 22.0]
QA_WALK dir=5 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=150.4 pitch_deg=[-15.0, 22.0]
QA_WALK dir=6 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=149.7 pitch_deg=[-15.0, 22.0]
QA_WALK dir=7 left_px=0.00 right_px=0.00 stance_px=0.00/0.00 sole_dy=0.000 knee_max_deg=150.4 pitch_deg=[-15.0, 22.0]
QA_WALK_SLIDE max_left_px=0.00 max_right_px=0.00 threshold_px=2.0 worst=
QA_WALK_POSE stance_max_px=0.00 sole_dy_max=0.000 knee_max_deg=151.3 knee_limit_deg=179.0 pitch_deg=[-15.0, 22.0] mirror_err=0.0000 local
QA_MOTION_OK
```

原 0/6 探针（BUG-03 直接对照）：

```text
QA_WALK dir=0 left_px=0.00 right_px=0.00
QA_WALK dir=6 left_px=0.00 right_px=0.00
QA_WALK_SLIDE max_left_px=0.00 max_right_px=0.00 threshold_px=2.0 worst=
QA_MOTION_OK
```

**BUG-03 对照**：旧版 dir6 = **45.26px**、dir0 = **5.42px**；新版 8 向 = **0.00px**。硬门余量 2.00px。

### 3.2 脚姿 / 脚掌滚动 / 膝 / 镜像

8-key 接触表（侧向 dir6）实测脚掌俯仰：

| key | 相位 | 左脚 | 右脚 | 读法 |
| ---: | ---: | ---: | ---: | --- |
| 0 | 0.000 | −15.0° | +15.4° | 左脚脚跟触地 / 右脚脚尖离地 |
| 1 | 0.125 | 0.0° | +18.9° | 左脚全掌 / 右脚摆动 |
| 2 | 0.250 | 0.0° | +3.2° | 左脚全掌 / 右脚抬起 |
| 3 | 0.375 | +0.3° | −11.7° | 左脚全掌 / 右脚下落 |
| 4 | 0.500 | +15.4° | −15.0° | 左右互换（镜像） |
| 5 | 0.625 | +18.9° | 0.0° | 右脚全掌 / 左脚摆动 |
| 6 | 0.750 | +3.2° | 0.0° | 右脚全掌 / 左脚抬起 |
| 7 | 0.875 | −11.7° | +0.3° | 右脚全掌 / 左脚下落 |

- 脚掌滚动区间精确为 **[−15.0°, +22.0°]**（探针 `pitch_deg=[-15.0, 22.0]`），无旧版“shin 角度叠加导致的断踝”。
- 膝内角最大 **151.3°**（<179°），侧向 4× 接触表目检：支撑腿膝朝前弯、摆动腿膝弯曲，无反向/过伸。
- 左右对称：dir0 同相位曲线误差 **0.0000 local**；dir2（左向）与 dir6（右向翻转）6 个抽样帧 mask **IoU=1.0000**，字符像素数完全相同（如 frame015：34660/34660）。字符区域 RGB 平均差 2.96/765（仅 3 个 >30 的像素位于舞台顶部边框），判定为**逐像素镜像一致**。

### 3.3 渲染像素 / 用户可见 6s GIF 复核

**侧向 2s 重拍**：60 帧中的支撑窗口，靴底最低像素 x 恒定：

```text
side dir=6 (1280×720 contact frames, 4× render):
p=0.125–0.375  bottom_x=[617,649]（不变）
p=0.625–0.875  bottom_x=[635,666]（不变）
```

**6s GIF（用户看到的正面 walk 段）**：用底部靴像素质心跟踪 `f042–f078`，旧/新对比：

| 窗口 | 旧版（HEAD^） | 新版（HEAD 18537e7） |
| --- | ---: | ---: |
| 第一支撑窗口 | f043–f053：321.1 → 364.4，扫动 **43.30px** | f046–f052：**308.3 恒定，0.00px** |
| 第二支撑窗口 | f058–f066：318.5 → 331.2，扫动 **12.70px** | f058–f064：**339.0 恒定，0.00px** |
| 第三支撑窗口 | — | f070–f076：**308.3 恒定，0.00px** |

> 旧版渲染 43.30px 与 BUG-03 探针 45.26px 同量级（差异来自质心/栅格化）；新版在用户可见的 6s GIF 中支撑脚 x 被锁定到像素，肉眼滑步消失。原始逐帧数据见 `evidence/walk/logs/qa_6s_gif_pixel_tracking.txt`。

**证据可复现性**：美术已提交的 `docs/shots/walk/walk_side_2s_after.gif` 与 QA 同机位重拍帧逐帧比较，mean abs diff **0.89**（p99=3，GIF 调色板量化误差），确认美术证据与当前 build 一致。

**正/背面 2.5D 观察项**：dir0 摆动脚在屏幕平面内整靴倾斜最大 **18.9°**（侧向是矢状面滚动，正面则表现为平面内滚转）；左右对称、只发生在离地摆动脚，承重脚始终 0° 全掌。见 P2-W01，交 T-003 美术复判定性。

### 3.4 功能回归原文

```text
PAPERDOLL_SMOKE_OK slots=17 variants=83 dirs=8 actions=4 presets=16 cards=16 baked_cards=16 combos=≈ 9.0×10²⁶ 种外观 procedural_art=true missing_textures=0
```

```text
headless 600：EXIT=0
grep SCRIPT ERROR|Parse Error|^ERROR:|WARNING → 无
SKIP_GPU=1 bash tools/verify.sh → PAPERDOLL_VERIFY_OK
```

```text
QA_INPUT buttons=66 focusable_buttons=66 all_controls=247 lineup_cards=16
QA_INPUT lineup_card_focus=[... 16 × "focus=0"]
QA_INPUT arrow_with_focus dir_changed=false focus_moved=true
QA_INPUT FAIL: lineup cards are clickable but not keyboard-focusable
QA_INPUT_FAILED failures=1
```

> 键盘项是上一轮 BUG-04，**未由本轮 walk 修复引入**；本轮未修，整体放行仍被它阻塞。

**截图回归**（重拍后与 HEAD 逐字节比较）：

| 截图 | 结果 |
| --- | --- |
| `01_studio.png` / `02_wardrobe.png` / `03_actions.png` / `04_directions.png` / `07_layer.png` | **逐字节一致（diff=0）** |
| `05_lineup.png` / `06_saved.png` | 不同——脚本内 `randomize_lineup()` 无固定 seed，属预期；已还原仓库版本，重拍图存 `evidence/walk/shots/` |

### 3.5 性能与媒体

```text
PAPERDOLL_FPS run1 samples=[42,42,41,45,43,39,33] steady_min=33.0 steady_avg=40.5 → PAPERDOLL_FPS_OK
PAPERDOLL_FPS run2 samples=[33,31,33,33,32,32,34] steady_min=31.0 steady_avg=32.5 → PAPERDOLL_FPS_OK
PAPERDOLL_FPS run3 samples=[32,31,22,21,27,33,33] steady_min=21.0 steady_avg=27.8 → PAPERDOLL_FPS_LOW
BAKE p90: 11.00 / 11.11 / 11.05ms（预算 16ms，PASS）
```

| 媒体 | 规格（ffprobe 实测） |
| --- | --- |
| QA `walk_side_2s_qa.gif` | 640×360 · 60 帧 · **2.000s** · r_frame_rate **30/1** |
| QA `walk_front_2s_qa.gif` | 640×360 · 60 帧 · **2.000s** · r_frame_rate **30/1** |
| QA `walk_side_2s_qa.mp4` | 640×360 · 60 帧 · **2.000s** · **30/1** |
| 美术 `docs/shots/walk/walk_side_2s_after.gif` | 640×360 · 60 帧 · **2.000s** · **30/1** |
| 产品 `docs/shots/showcase/paperdoll_6s.gif` | 640×360 · 180 帧 · **6.000s** · **30/1** |

> GIF 的时间轴按 10ms 量化，部分工具会把 avg_frame_rate 显示为 100/3；r_frame_rate 与 `nb_frames/duration` 均为 30fps。MP4 为精确 30/1。

### 3.6 结果总表

| 类别 | 用例 | 阈值 | 实测 | 判定 |
| --- | --- | --- | --- | --- |
| 视觉 | 8 向支撑脚漂移 | ≤2.0px | 8/8 向 **0.00px** | **PASS** |
| 视觉 | dir6 / dir0 | ≤2.0px | **0.00 / 0.00** | **PASS** |
| 视觉 | 支撑相 x 锁定 | ≤2.0px | **0.00px** | **PASS** |
| 视觉 | 脚掌滚动 | [−15°,+22°] | **精确 [−15.0°,+22.0°]** | **PASS** |
| 视觉 | 膝过伸 | <179° | **151.3°** | **PASS** |
| 视觉 | 左右镜像 | ≤0.01 local / IoU≥0.99 | **0.0000 / 1.0000** | **PASS** |
| 视觉 | 侧向 2s 无滑步 | ≤2px | **0.00px（支撑窗口）** | **PASS** |
| 视觉 | 6s GIF 旧→新 | 滑步消失 | **43.30px → 0.00px** | **PASS** |
| 功能 | headless 600 | 无错误 | 无 SCRIPT/PARSE/ERROR/WARNING | **PASS** |
| 功能 | smoke 17/83/8/4/16/存读 | 全过 | 全过，missing_textures=0 | **PASS** |
| 回归 | 确定性截图 | diff=0 | 01/02/03/04/07 一致 | **PASS** |
| 性能 | FPS 3 次 | 3/3 ≥30 | 33 / 31 / 21 → **2/3** | **FAIL（既有环境问题，非 walk 回归）** |
| 性能 | 烘焙 p90 | ≤16ms | 11.00 / 11.11 / 11.05ms | **PASS** |
| 回归 | 16 卡键盘 | QA_INPUT_OK | 16 卡 focus=0；方向键冲突 | **FAIL（既有 BUG-04，非本任务范围）** |

---

## 4. Bug / 观察项列表（含复现）

### 4.1 本轮 walk 修复：无新增 P0/P1 阻塞

2px 硬门、脚掌区间、膝内角、左右镜像、用户可见 6s GIF 全部通过。以下为 **P2 观察/工具项**，不改变 walk 修复 PASS 的判定。

#### P2-W01 · 正/背面摆动脚俯仰在屏幕平面内表现为整靴倾斜（2.5D 表现取舍）

- **复现**：`godot --path . --resolution 1280x720 -s tools/walk_rig.gd -- --out=res://docs/qa-walk/front --dir=0 --seconds=2 --scale=2.05`；看 `evidence/walk/walk_contact_strip_front_qa.png` 的 key 1/2/3、5/6/7。
- **期望**：脚掌俯仰在矢状面（侧向）滚动；正/背面不应读成脚踝侧翻。
- **实际**：侧向完全正确；正/背面因 2.5D 只在屏幕平面旋转脚掌，摆动脚最大 **18.9°** 整靴倾斜（承重脚 0° 全掌）。左右对称、非单侧、非承重脚，不构成 2px 硬门失败。
- **建议（交 T-003 美术复评）**：yaw<0.20 时把脚掌俯仰压到 ±8°，或用纵向压扁/遮挡表现跖屈，避免正面读成侧翻；侧向保持现参数。

#### P2-W02 · 脚跟/脚尖接触帧鞋底比全掌帧高约 3px @4×（约 1.6–2px @2.1×）

- **复现**：`evidence/walk/walk_contact_strip_side_qa.png` 的洋红基准线；或量测 `docs/qa-walk/side/contact_000.png` 与 `contact_001.png` 的棕色靴底最低像素 y：**664 vs 667**（4× 渲染）。
- **期望**：支撑相鞋底最低点恒定。
- **实际**：全掌帧贴线；脚跟/脚尖端点高 3px @4×。探针的“尖角矩形”模型给出 sole_dy=0.000，但实际绘制的鞋是圆角矩形（r=3.6），旋转后最低点比尖角模型高约 0.9 local。6s GIF 中对应底部像素 y=331→333（约 2px @2.05×）。
- **影响**：轻微“端点悬浮”，4× 才明显；不是水平滑步，不影响 2px 硬门。**建议**：`ankle_lift` 用圆角有效半宽（≈5.0 而非 8.5）补偿，或在鞋底下加 1px 接触影；目标 ≤1px @2.1×。

#### P2-W03 · README / verify 工具链与文档不一致

- **复现**：
  - `test -f godot-paper-doll/tools/record_walk.sh` → **不存在**；`tools/walk_rig.gd` 头注释却引用它合成 GIF。
  - `grep -n 'qa_motion\|artist_walk' godot-paper-doll/tools/verify.sh` → **无匹配**；README 的“预期关键标记”块列出 `QA_MOTION_OK` / `ARTIST_WALK_OK`，但 `verify.sh` 只跑 5 步、不会输出这两个标记（需单独跑探针）。
- **影响**：文档可复现性；不影响游戏运行。**建议**：补 `record_walk.sh`，把 2s/6s GIF 与 motion/artist 探针纳入 `verify.sh`。

#### P2-W04 · `qa_input_probe.gd` 打印失败但退出码为 0

- **复现**：`godot --headless --path . -s tools/qa_input_probe.gd; echo $?` → 打印 `QA_INPUT_FAILED failures=1`，但 **EXIT=0**。
- **影响**：CI/verify 若只看退出码会漏掉键盘失败。**建议**：失败分支 `quit(1)`（属 QA 工具修正，不改游戏）。

### 4.2 上一轮遗留阻塞项（本轮未修，整体放行仍被阻塞）

| ID | 状态 | 本轮实测/说明 |
| --- | --- | --- |
| BUG-01 · FPS | **仍阻塞** | 3 次 `steady_min` = 33 / 31 / **21**，2/3 过；未达到 3/3 ≥30。与后台 Lark/WebKit/node 负载相关；walk 修复未改渲染管线，无新回退证据。 |
| BUG-02 · 16 人剪影 IoU | **仍阻塞** | 上一轮 0.412 > 0.30；本轮未改角色体型/剪影，未重跑（不在 walk 范围）。 |
| BUG-04 · 16 卡键盘不可达 | **仍阻塞** | 本轮 `qa_input_probe` 仍 16 卡 `focus=0`、`arrow_with_focus` 冲突。 |
| BUG-10 · T-013 公开外放 P0 | **仍阻塞** | 首玩路径/角色卡/阵容收藏未实现；不影响本轮 walk 验收。 |

---

## 5. 截图 / 证据清单

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `evidence/walk/walk_contact_strip_side_qa.png` | 侧向 dir6 · 8 keys · 4× 渲染/2× 裁切 · 相位+脚掌角度+洋红鞋底基准线 | V-04/V-07/V-09 |
| `evidence/walk/walk_contact_strip_front_qa.png` | 正面 dir0 · 同规格 | 左右镜像/正背面观察 |
| `evidence/walk/walk_cycle_side_qa.png` | 侧向 2s 全周期 16 帧（每 4 帧） | 动作可读性 |
| `evidence/walk/walk_cycle_front_qa.png` | 正面 2s 全周期 16 帧 | 正面步态/镜像 |
| `evidence/walk/walk_side_2s_qa.gif` | 640×360 / 60 帧 / 2.000s / 30fps | 侧向验收 GIF |
| `evidence/walk/walk_side_2s_qa.mp4` | 同上，H.264 30/1 | 飞书视频附件 |
| `evidence/walk/walk_front_2s_qa.gif` | 640×360 / 60 帧 / 2.000s | 正面复核 |
| `evidence/walk/walk_front_2s_qa.mp4` | 同上 | 备用 |
| `evidence/walk/walk_mirror_lr_qa.png` | dir2 vs dir6 翻转对照（frame015） | 左右镜像 |
| `evidence/walk/walk_6s_old_walkseg_qa.png` | 旧 6s GIF walk 段 f042–f075 | 旧滑步证据 |
| `evidence/walk/walk_6s_new_walkseg_qa.png` | 新 6s GIF 同帧段 | 修复对照 |
| `evidence/walk/shots/01..07_*.png` | QA 重拍的 7 张 1280×720 | 截图回归 |
| `evidence/walk/logs/` | 探针/回归/perf/媒体/像素跟踪全部原始日志 | 可复现 |
| `evidence/walk/logs/qa_walk_summary.json` | 关键指标 JSON | 汇总 |
| `evidence/walk/logs/qa_6s_gif_pixel_tracking.txt` | 6s GIF 逐帧靴底 x/y + 支撑窗口扫动 | V-08 |
| `evidence/walk/logs/qa_mirror_iou.txt` | dir2/dir6 翻转 IoU | V-06 |
| `evidence/tools/qa_motion_probe_8dir.gd` | 本轮扩展 QA 探针（证据副本） | 8 向复现 |
| `docs/shots/walk/walk_side_2s_after.gif`（仓库内，美术提交） | 640×360/60/2s | 与 QA 重拍 mean abs 0.89 一致 |
| `docs/shots/showcase/paperdoll_6s.gif`（仓库内） | 640×360/180/6s | 用户可见回归复核 |

---

## 6. 残留风险

1. **正/背面 2.5D 脚掌俯仰**：摆动脚最大 18.9° 平面内倾斜，可能被部分观众读成“脚踝侧翻”；侧向不受影响。需 T-003 美术复评按目标尺寸/GIF 判定是否接受。
2. **端点鞋底 3px @4× 轻微悬浮**：全掌贴地正确，脚跟/脚尖接触端点略高；2.1× 下约 1.6–2px，非水平滑步，但 4× 物料可见。
3. **FPS 环境敏感性**：2/3 过、1/3 低；未达到 3/3 签核，不能据此宣称“Intel 稳定 ≥30”。
4. **键盘/剪影/产品 P0**：本轮未动，整体放行仍 BLOCKED；不要把本报告的 walk PASS 误读为整体放行。
5. **视觉覆盖面**：8 向漂移为数值全测；肉眼仅重拍 dir 0/2/6（正面/左向/右向）+ 6s 正面 GIF；对角/背面仅数值与 4× 接触帧逻辑，未单独出人眼物料。
6. **单人评审**：脚姿“好看”仍是 QA/美术导演单人判断，无 3 人测试；T-003 是独立复评，不是用户测试。
7. **GIF 计时量化**：GIF 的 10ms 时间轴使 avg_frame_rate 字段可能显示 100/3；按 r_frame_rate/nb_frames/duration 判定为 30fps、2.000s。

---

## 7. 验收签署

| 角色 | 结论 | 备注 |
| --- | --- | --- |
| QA Lead（本报告） | **walk 修复 PASS；整体 build 不可放行** | walk 硬门全部通过；整体阻塞项为 BUG-01/02/04/10（遗留） |
| 待 T-20261121-003 美术复评 | — | 独立看侧向 walk/脚姿/接触，重点裁决 P2-W01（正/背面平面内脚掌倾斜）与 P2-W02（端点鞋底悬浮） |
| 下一轮 Engineer/Artist | — | 若 T-003 要求，按 P2-W01/W02 打磨；BUG-01/02/04/10 另行排期 |

> 本报告所有数值均来自当前 build 的实际命令输出与 `docs/qa-review/evidence/walk/` 原始文件；未使用估算值。QA 未修改游戏逻辑/美术；唯一的测试工具扩展为 8 向 QA 探针，已以证据副本提交，项目内 canonical 探针保持原样。
