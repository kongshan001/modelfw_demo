# Cycle 1 · 03 QA 基线（提灯守夜人 → KayKit Rogue）

> 执行：QA 负责人 | 日期：2026-10-31 12:31–12:51（CST） | 阶段：**改动前基线**
> 被测版本：`godot-garden/` 当前工作区。游戏逻辑文件 mtime 仍为 2026-10-30（见 §9），本 QA **未修改任何游戏逻辑代码**；新增 2 个只读 QA 工具（见 §10）。
> 关联：`docs/agency/cycle-1/01-brief.md`、`docs/agency/cycle-1/02-art-review.md`、`docs/迭代记录.md` 轮次 5、`docs/agency/scorecard.md`。

---

## 1. 结论

**基线本身可放行，作为 Cycle 1 的改动前对照；当前唯一硬阻塞是“性能门禁口径”，不是游戏代码。**

- **功能/稳定性基线通过**：无头 600 帧无 `SCRIPT ERROR/ERROR/WARNING`、退出码 0；标准探针 6 次全部 `PROBE_PATROL_OK`（3 次后台 + 3 次前台）；三名 NPC 的位移、与水池/石圈/石像/拱柱的最小间距全部过阈值；`5` 键、`F1`、UI「游人」按钮三条开关链路实测通过。
- **性能存在“基线自身不达 Brief 门禁”的问题**：
  - 按 Brief 原口径（`probe_patrol.gd` 3 次、前台、关闭 vsync），本机 `PATROL_FPS avg` 中位数为 **56.8**，低于 Brief 的 **58.2**；这不是改动造成的回退，而是当前机器/采样口径的可复现实测。
  - 同一版本、同一机器，用本报告新增的**交错稳态探针**（`tools/qa_probe_patrol_perf.gd`，shown/hidden 正反顺序各 4 块）测得 shown **74.5 / 75.3 FPS**、hidden **78.4 / 72.2 FPS**、cost **+3.9 / -3.1 FPS**、巡逻 draw call 增量稳定为 **144.5**。说明 **60 FPS 绝对目标实际可达**，56.8 主要是 `probe_patrol.gd` 12s 采样含启动/顺序偏差。
  - **A/B cost 明确不可靠**：legacy 探针单次“先隐藏后显示”的 cost 在 -7.4～+15.3 FPS 之间摆动（甚至为负），是场景热漂移/采样顺序造成的噪声，不能取一次值当结论；交错探针的 cost 中位 +0.4 FPS，draw call 增量 144.5 才是可用的成本口径。
  - 因此：**沿用 Brief 的 58.2 绝对值，任何实现都会在基线就失败，无法判定本轮是否回退。** 需要在 `04-impl` 前由策划/程序签字改口径，建议“交错稳态探针做绝对门禁 + 标准探针做功能与相对回归”，详见 §8 与 §9。
- **截图基线已更新**：8 张 `patrol_*.png` 全部为本次 12:32–12:33 重新生成，1920×1080；`patrol_fox.png` 被树干完全遮挡（P1 工具问题，非本轮提灯人验收项）。截图中最新文件是并发美术评审生成的 `review_wide_night_rogue.png`（12:42），不是本次 QA 命令产出，已注明来源。
- **实现前需要确认 4 个口径**（不阻塞基线，但直接决定 05 验收）：性能门禁、近景机位、披风去留、提灯灯光参数。见 §9.1。

**放行判定：**

| 项 | 判定 | 说明 |
|---|---|---|
| 作为“改动前基线” | **可放行** | 数据齐全、可复现、功能和稳定性通过 |
| 按 Brief 原性能门禁（58.2） | **BLOCKED** | 基线中位数 56.8 < 58.2；需先改口径/签字 |
| 本轮实现开工 | **可开工，但性能门禁需先签字** | 功能/视觉/回归门禁已明确；不解决性能口径，05 无法判定 |

---

## 2. 环境与命令

### 2.1 环境

| 项 | 值 |
|---|---|
| 机器 | macOS 12.7.6（21H1320），4 核，Intel Iris(TM) Graphics 6000 |
| Godot | 4.6.stable.official.89cea1439 |
| 渲染 | Vulkan 1.2.283，Forward Mobile；项目 `mobile` 渲染方法 |
| 项目 | `废墟花园 · 黄昏`；内部世界 640×360，窗口设置 1920×1080 / `canvas_items` |
| 探针窗口 | 1280×720；截图命令窗口 1440×810，但截图工具用 1920×1080 SubViewport（实测输出 1920×1080，见 §5） |
| 垂直同步 | 探针内 `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`、`Engine.max_fps = 0` |
| 系统负载 | 后台三轮期间 load avg 9.89 / 7.24 / 7.21；前台轮次未逐次采样（12:35 为 4.72、12:36 为 7.21）；常驻 claude / WebKit / Lark / B 站客户端 |
| 干扰 | 12:42 美术评审并发渲染 `review_*.png`，与前台探针 run4 时间重叠（GPU 争用）；见 §6 BUG-2 |

> **测量纪律（本轮新发现）**：Godot 窗口在后台/被遮挡时 macOS 会限速，nohup 启动的三轮 FPS 只有 21.6–49.7，不能作为性能基线；必须让窗口前台（`open -a Godot ...`）并独占运行。A/B 单次“先隐藏后显示”的顺序偏置很大（cost 可为负），必须用交错探针或正反顺序。

### 2.2 可直接复制的命令

```bash
cd /Users/ks_128/Documents/modelfw_demo
```

**A. 无头 600 帧（干净检查）**

```bash
godot --path godot-garden --headless --quit-after 600 2>&1 | grep -E "SCRIPT ERROR|ERROR|WARNING"
# 输出为空、grep 退出码 1 表示无匹配（正常）；完整日志：/tmp/qa_headless_600.log
```

**B. 标准巡逻探针（功能 + FPS；建议前台运行）**

```bash
# 后台方式（本次 3 次，窗口可能被限速，FPS 仅参考）
nohup sh -c 'godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd > /tmp/qa_probe_patrol.log 2>&1; echo $? > /tmp/qa_probe_patrol.exit' &

# 前台方式（本次 3 次，推荐用于正式基线）
open -a Godot --args --path "$PWD/godot-garden" --resolution 1280x720 \
  --log-file /tmp/qa_probe_patrol_foreground.log -s res://tools/probe_patrol.gd
```

**C. 截图**

```bash
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd
```

**D. 开关链路（键位 + UI 按钮，无头即可）**

```bash
godot --path godot-garden --headless -s tools/qa_key_toggle.gd
```

**E. 交错稳态性能探针（QA 新增，前台）**

```bash
open -a Godot --args --path "$PWD/godot-garden" --resolution 1280x720 \
  --log-file /tmp/qa_perf.log -s res://tools/qa_probe_patrol_perf.gd
```

**F. 截图目录检查**

```bash
ls -lt "$HOME/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/" | head -20
```

---

## 3. 结果表

> 阈值来自 `tools/probe_patrol.gd` 的判定与 `01-brief.md` / `scorecard.md`。原始输出见 §4，未做估算。

| # | 用例 | 阈值 | 实测（原始摘要） | 判定 |
|---:|---|---|---|---|
| 1 | 无头 600 帧干净 | `SCRIPT ERROR/ERROR/WARNING` = 0；退出码 0 | 无匹配；退出码 0；`real 12.81s` | **PASS** |
| 2 | 提灯人位移（12s） | `travelled > 4.2m` | 后台 9.5 / 8.8 / 8.9；前台 7.7 / 8.5 / 7.4（中位 7.7） | **PASS** |
| 3 | 扫园人位移（12s） | `> 4.2m` | 6.8 / 6.6 / 6.4；前台 5.3 / 6.0 / 6.0 | **PASS** |
| 4 | 小狐侍位移（12s） | `> 4.2m` | 11.2 / 10.3 / 10.1；前台 9.7 / 9.5 / 8.9 | **PASS** |
| 5 | 与水池最小间距 | `> 4.8m` | 全局最小 6.38（提灯人）；扫园人最低 11.78、狐狸最低 12.32 | **PASS** |
| 6 | 与石圈最小间距 | `> 2.6m` | 全局最小 3.29（扫园人）；提灯人最低 6.43、狐狸最低 10.74 | **PASS** |
| 7 | 与石像最小间距 | `> 1.8m` | 全局最小 3.32（提灯人）；扫园人最低 8.95、狐狸最低 8.73 | **PASS** |
| 8 | 与拱柱最小间距 | `> 1.0m` | 全局最小 1.72（狐狸）；提灯人最低 5.90、扫园人最低 10.22 | **PASS** |
| 9 | `5` 键/探针开关链路 | hidden_ok / shown_ok 均 true | 6 次探针全部 `hidden_ok=true shown_ok=true` | **PASS** |
| 10 | 真实键盘 `5` / `F1` / UI「游人」 | 三链路均能隐藏并恢复 | `QA_KEY5 ... true/true/true`；`QA_F1 ... true/true/true`；`QA_UI_BUTTON ... true/true` | **PASS** |
| 11 | 截图 8 张 | 全部生成、1920×1080 | 8/8；12:32:56–12:33:06；`sips` 均 1920×1080；退出码 0 | **PASS（生成）**；fox 内容见 BUG-1 |
| 12 | 日志干净（探针/截图/性能） | 无 `ERROR/WARNING` | headless/probe/screenshot/perf 日志均无匹配 | **PASS** |
| 13 | 标准探针 FPS（后台三轮） | 仅作参考 | avg 27.4 / 36.8 / 33.8；A/B hidden 28.2 / 52.5 / 50.5；shown 21.6 / 49.7 / 43.7；cost 6.6 / 2.8 / 6.8 | **N/A（作废）** 窗口被限速 |
| 14 | 标准探针 FPS（前台三轮） | Brief：3 次中位 avg ≥58.2 | avg 56.8 / 49.8 / 64.8（中位 **56.8**）；min 25 / 40 / 50；hidden 71.0 / 69.3 / 57.3（中位 69.3）；shown 56.6 / 54.0 / 64.8（中位 **56.6**）；cost 14.4 / 15.3 / -7.4（中位 14.4） | **FAIL** 对 Brief；相对基线 −2 可接受 |
| 15 | 交错稳态 FPS（前台两轮） | 绝对 ≥60；回退 ≤2 | shown 74.5 / 75.3（中位 **74.9**）；hidden 78.4 / 72.2；cost +3.9 / -3.1（中位 **+0.4**）；draw call shown 1393.0 / hidden 1248.4（增量 **144.5**） | **PASS**（绝对 + 成本） |
| 16 | 截图目录最新文件 | 记录最新时间与来源 | QA 产出最新：`patrol_fox.png` 12:33:06；目录最新：`review_wide_night_rogue.png` 12:42（并发美术评审，非 QA） | **PASS（已记录）** |

**关键读数（用于 05 对比）：**

- 功能基线（中位/稳定值）：提灯人 `travelled 7.4–9.5m`（前台中位 7.7）、`min_pond 6.38`、`min_circle 6.43`、`min_statue 3.32`、`min_pillar 5.90–5.94`；扫园人 `min_circle 3.29–3.35`；狐狸 `min_pillar 1.72`。
- 性能基线（前台标准探针，3 次中位）：`avg 56.8`、`min 40.0`、`hidden 69.3`、`shown 56.6`、`cost 14.4`（cost 波动极大，见 BUG-2）。
- 性能基线（交错稳态，2 次）：`shown 74.9`、`hidden 75.3`、`cost +0.4`、`draw delta 144.5`。
- 开关：探针 + 真实键位 + UI 按钮均 PASS。

---

## 4. 原始输出（逐字）

### 4.1 无头 600 帧

```text
$ /usr/bin/time -p sh -c 'godot --path godot-garden --headless --quit-after 600 > /tmp/qa_headless_600.log 2>&1'
real 12.81
user 4.78
sys 0.59
exit=0
$ grep -E "SCRIPT ERROR|ERROR|WARNING" /tmp/qa_headless_600.log
（无输出；grep 退出码 1）
$ cat /tmp/qa_headless_600.log
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org
```

### 4.2 标准探针：后台三轮（窗口被限速，FPS 仅作“错误方法”证据）

```text
# run1 12:31:43–12:32:21
PATROL Patrol_lantern role=lantern travelled=9.5 min_pond=6.39 min_circle=6.43 min_statue=3.32 min_pillar=5.91
PATROL Patrol_sweeper role=sweeper travelled=6.8 min_pond=11.78 min_circle=3.30 min_statue=8.95 min_pillar=10.22
PATROL Patrol_fox role=fox travelled=11.2 min_pond=12.32 min_circle=10.75 min_statue=8.73 min_pillar=1.72
PATROL_FPS avg=27.4 min=13.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=28.2 shown=21.6 cost=6.6
PROBE_PATROL_OK

# run2 12:33:40–12:34:14
PATROL Patrol_lantern role=lantern travelled=8.8 min_pond=6.38 min_circle=6.44 min_statue=3.33 min_pillar=5.94
PATROL Patrol_sweeper role=sweeper travelled=6.6 min_pond=11.96 min_circle=3.29 min_statue=9.13 min_pillar=10.37
PATROL Patrol_fox role=fox travelled=10.3 min_pond=13.01 min_circle=10.75 min_statue=9.33 min_pillar=1.72
PATROL_FPS avg=36.8 min=20.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=52.5 shown=49.7 cost=2.8
PROBE_PATROL_OK

# run3 12:35:24–12:36:05
PATROL Patrol_lantern role=lantern travelled=8.9 min_pond=6.39 min_circle=6.44 min_statue=3.33 min_pillar=5.95
PATROL Patrol_sweeper role=sweeper travelled=6.4 min_pond=12.21 min_circle=3.29 min_statue=9.39 min_pillar=10.58
PATROL Patrol_fox role=fox travelled=10.1 min_pond=13.03 min_circle=10.74 min_statue=9.52 min_pillar=1.72
PATROL_FPS avg=33.8 min=14.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=50.5 shown=43.7 cost=6.8
PROBE_PATROL_OK
```

### 4.3 标准探针：前台三轮（正式基线；`open -a Godot` 激活窗口）

```text
# run4 12:40:15–12:42:14（与 12:42 美术评审渲染重叠）
PATROL Patrol_lantern role=lantern travelled=7.7 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.91
PATROL Patrol_sweeper role=sweeper travelled=5.3 min_pond=13.23 min_circle=3.40 min_statue=10.42 min_pillar=11.45
PATROL Patrol_fox role=fox travelled=9.7 min_pond=12.99 min_circle=10.75 min_statue=9.83 min_pillar=1.73
PATROL_FPS avg=56.8 min=25.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=71.0 shown=56.6 cost=14.4
PROBE_PATROL_OK

# run5 12:43:02–12:44:12
PATROL Patrol_lantern role=lantern travelled=8.5 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.90
PATROL Patrol_sweeper role=sweeper travelled=6.0 min_pond=12.63 min_circle=3.35 min_statue=9.81 min_pillar=10.94
PATROL Patrol_fox role=fox travelled=9.5 min_pond=12.98 min_circle=10.74 min_statue=9.98 min_pillar=1.72
PATROL_FPS avg=49.8 min=40.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=69.3 shown=54.0 cost=15.3
PROBE_PATROL_OK

# run6 12:44:28–12:45:25
PATROL Patrol_lantern role=lantern travelled=7.4 min_pond=6.39 min_circle=6.43 min_statue=3.32 min_pillar=5.91
PATROL Patrol_sweeper role=sweeper travelled=6.0 min_pond=12.59 min_circle=3.33 min_statue=9.77 min_pillar=10.90
PATROL Patrol_fox role=fox travelled=8.9 min_pond=12.99 min_circle=10.75 min_statue=10.30 min_pillar=1.73
PATROL_FPS avg=64.8 min=50.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=57.3 shown=64.8 cost=-7.4
PROBE_PATROL_OK
```

### 4.4 交错稳态探针（QA 新增；前台两轮）

```text
# run1 12:48:51–12:49:58
PERF_BLOCK cycle=0 visible=true fps=75.3 draws=1410.1
PERF_BLOCK cycle=0 visible=false fps=80.1 draws=1253.4
PERF_BLOCK cycle=1 visible=false fps=82.1 draws=1243.5
PERF_BLOCK cycle=1 visible=true fps=78.9 draws=1385.5
PERF_BLOCK cycle=2 visible=true fps=72.2 draws=1387.0
PERF_BLOCK cycle=2 visible=false fps=74.0 draws=1248.0
PERF_BLOCK cycle=3 visible=false fps=77.6 draws=1249.0
PERF_BLOCK cycle=3 visible=true fps=71.7 draws=1389.4
PERF_SHOWN fps_avg=74.5 fps_median=73.8 draws=1393.0 blocks=4
PERF_HIDDEN fps_avg=78.4 fps_median=78.8 draws=1248.5 blocks=4
PERF_COST avg=3.9 median=5.1 draw_delta=-144.5
QA_PERF_DONE

# run2 12:50:08–12:51:18
PERF_BLOCK cycle=0 visible=true fps=77.9 draws=1410.0
PERF_BLOCK cycle=0 visible=false fps=77.0 draws=1253.4
PERF_BLOCK cycle=1 visible=false fps=72.2 draws=1243.5
PERF_BLOCK cycle=1 visible=true fps=77.6 draws=1385.4
PERF_BLOCK cycle=2 visible=true fps=73.5 draws=1387.0
PERF_BLOCK cycle=2 visible=false fps=74.5 draws=1248.0
PERF_BLOCK cycle=3 visible=false fps=65.2 draws=1248.9
PERF_BLOCK cycle=3 visible=true fps=72.3 draws=1389.5
PERF_SHOWN fps_avg=75.3 fps_median=75.5 draws=1393.0 blocks=4
PERF_HIDDEN fps_avg=72.2 fps_median=73.3 draws=1248.4 blocks=4
PERF_COST avg=-3.1 median=-2.2 draw_delta=-144.5
QA_PERF_DONE
```

> 读数：shown 74.5/75.3、hidden 78.4/72.2；FPS 成本在噪声内（+3.9/-3.1），但 **draw call 增量稳定为 144.5**（3 个程序化 NPC 的网格 + 阴影 pass）。这说明巡逻的主要成本是 draw call，不是不可测的“玄学帧率”。

#### 4.4.1 为什么 perf 工具是 74–75，而 `probe_patrol.gd` 只有 49.8–64.8？

- **不是 UI/战斗状态差异**：两个工具都执行 `scene.set_ui_visible(false)`、`scene.set_autoplay(false)`、`scene.set_time(18.2)`，都不发战斗/移动指令，场景状态一致（主角/妖灵/任务层都在，巡逻都在）。
- **差异在采样口径**：
  1. `probe_patrol.gd` 只等 **1.0s** 就开始 12s 采样，`Engine.get_frames_per_second()` 是平滑值；前几秒的着色器编译/首帧开销会拉低均值（本次前台三次 avg 49.8–64.8，最低 min 25）。
  2. `qa_probe_patrol_perf.gd` 预热 **2.0s**，每块 **4.0s**，用 `Engine.get_process_frames()` 对 wall-clock 计帧，且 shown/hidden **正反顺序交错**，抵消热漂移；取 4 块均值/中位数。
  3. `probe_patrol.gd` 的 A/B 是**单次顺序**（先隐藏 6s、再显示 6s），在 Intel Iris 6000 + 系统负载下会出现 +14.4 或 -7.4 的假成本；交错探针的 cost 中位仅 +0.4。
- **结论**：74–75 是稳态、可重复的数值；49.8–64.8 是“含启动/顺序偏差”的 legacy 数值。两者不矛盾，但**不能混用**：性能门禁看交错稳态，功能/回归看 legacy。

### 4.5 真实键盘 / UI 开关链路

```text
$ /usr/bin/time -p godot --path godot-garden --headless -s tools/qa_key_toggle.gd
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

QA_KEY5 shown_before=true hidden_after=true shown_after=true
QA_F1 ui_before=true ui_hidden=true ui_shown=true
QA_UI_BUTTON hidden_after=true shown_after=true
QA_KEY_TOGGLE_OK
real 4.63
user 2.26
sys 0.61
exit=0
```

### 4.6 截图日志

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org
Vulkan 1.2.283 - Forward Mobile - Using Device #0: Intel - Intel(R) Iris(TM) Graphics 6000

SCREENSHOT: .../patrol_wide_dusk.png
SCREENSHOT: .../patrol_wide_dusk_off.png
SCREENSHOT: .../patrol_compare_on.png
SCREENSHOT: .../patrol_compare_off.png
SCREENSHOT: .../patrol_lantern_dusk.png
SCREENSHOT: .../patrol_lantern_night.png
SCREENSHOT: .../patrol_sweeper.png
SCREENSHOT: .../patrol_fox.png
（退出码 0；12:32:48 启动，12:33:28 结束，约 40s）
```

---

## 5. 截图清单与来源

截图目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`

| 文件 | 时间 | 尺寸 | 来源 | 用途 / 备注 |
|---|---|---|---|---|
| `patrol_wide_dusk.png` | 12:32:56 | 1920×1080 | 本次 `screenshot_patrol.gd` | 默认广角，18.2，巡逻可见 |
| `patrol_wide_dusk_off.png` | 12:32:57 | 1920×1080 | 本次 | 同机位，`5` 键关闭巡逻 |
| `patrol_compare_on.png` | 12:32:58 | 1920×1080 | 本次 | 石圈对侧定点，扫园人 ON |
| `patrol_compare_off.png` | 12:32:58 | 1920×1080 | 本次 | 同机位，巡逻 OFF |
| `patrol_lantern_dusk.png` | 12:33:01 | 1920×1080 | 本次 | 提灯人近景，18.4 |
| `patrol_lantern_night.png` | 12:33:02 | 1920×1080 | 本次 | 提灯人近景，00:00 |
| `patrol_sweeper.png` | 12:33:04 | 1920×1080 | 本次 | 扫园人近景，17.9 |
| `patrol_fox.png` | 12:33:06 | 1920×1080 | 本次 | 小狐侍近景；**树干挡死，见 BUG-1** |
| `preview_a_procedural.png` | 12:21 | 1920×1080 | 早先 `preview_kaykit.gd` 预演，**非本次 QA** | 程序化提灯人 A/B 参考 |
| `preview_b_kaykit_rogue.png` | 12:21 | 1920×1080 | 早先 `preview_kaykit.gd` 预演，**非本次 QA** | Rogue 0.58 预演；不可当集成验收 |
| `review_*.png`（9 张） | 12:42 | 1920×1080 | 并发美术评审的 `/tmp/review_camera.gd`，**非本次 QA** | 见 `02-art-review.md` §6；目录最新为 `review_wide_night_rogue.png` |

- **最新文件**：目录整体最新是 `review_wide_night_rogue.png`（12:42，美术评审）；**本次 QA 命令产出的最新是 `patrol_fox.png`（12:33:06）**。两者来源不同，05 对比不要混用。
- **分辨率说明**：截图命令传 `--resolution 1440x810`，但 `screenshot_patrol.gd` 创建的是 1920×1080 SubViewport，`sips` 实测输出 1920×1080；窗口分辨率不决定截图尺寸。
- 截图均隐藏 UI（`set_ui_visible(false)`）、关闭 autoplay；`patrol_fox.png` 不含战斗飘字；`review_ab_*.png` 含飘字，仅美术参考。

---

## 6. 问题列表（含复现）

### BUG-1（P1，工具）：`patrol_fox.png` 被树干遮挡

- **复现**：
  1. `godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd`
  2. 查看输出 `patrol_fox.png`（12:33:06）。
- **期望**：小狐侍在画面中央可辨。
- **实际**：画面中央被一根深色树干占满，狐狸不可见；`focus_patrol(2)` 的固定方位（azimuth 100°/5.8m）穿树。
- **影响**：小狐侍视觉验收/截图矩阵缺一项；**不影响本轮提灯人**（提灯人近景 `patrol_lantern_*` 正常）。
- **建议**：按 `02-art-review.md` §4.8 给 `focus_patrol` 加“相机→胸口射线检测，遇挡按 ±15° 步进”，或给 fox 加 anchor。只改工具，不改游戏逻辑。

### BUG-2（P1，测量方法）：`probe_patrol.gd` 的 FPS/A-B 在当前机器不稳定

- **复现**：
  1. 用 nohup 后台跑 3 次 `probe_patrol.gd`：avg 27.4 / 36.8 / 33.8；A/B cost 6.6 / 2.8 / 6.8。
  2. 用 `open -a Godot` 前台跑 3 次：avg 56.8 / 49.8 / 64.8；A/B cost 14.4 / 15.3 / **-7.4**。
  3. 用交错探针前台跑 2 次：shown 74.5 / 75.3，cost +3.9 / -3.1。
- **期望**：同一版本、同一机器，FPS 和 A/B cost 可重复，cost 符号稳定。
- **实际**：窗口前后台、单次隐藏/显示顺序、并发 GPU 负载都会改变结果；成本甚至出现负值。
- **影响**：**不能**用单次 `PATROL_FPS_AB` 判定性能回退；Brief 的 “cost ≤2.3 作为诊断” 在 legacy 方法下基线中位就是 14.4，无法执行。
- **建议**：正式性能门禁用 `qa_probe_patrol_perf.gd`（交错、正反顺序、draw call）；legacy 探针保留功能/回归用途。05 必须独占运行，不与美术评审/其他 Godot 并发。

### BUG-3（P1，门禁口径）：Brief 的 58.2 绝对值在基线即不成立

- **复现**：按 Brief 口径前台跑 3 次 `probe_patrol.gd`，`PATROL_FPS avg` = 56.8 / 49.8 / 64.8，中位 **56.8** < **58.2**。
- **期望**：基线应满足门槛，或门槛应低于基线。
- **实际**：基线自身低于门槛 1.4 FPS；同时交错稳态探针显示同一版本可达 74.9 FPS，证明不是引擎上限。
- **影响**：若不改口径，任何实现都会被判 FAIL，无法区分“改动回退”和“采样偏差”。
- **建议**：见 §8.3 的 A/B/C 方案；需策划/程序签字。

### BUG-4（P2，文档/工具）：截图命令分辨率与输出分辨率不一致

- **复现**：`godot ... --resolution 1440x810 -s tools/screenshot_patrol.gd`；`sips -g pixelWidth -g pixelHeight patrol_*.png` 均返回 1920/1080。
- **期望**：文档若写“1440×810 截图”应说明实际输出。
- **实际**：窗口是 1440×810，截图 SubViewport 固定 1920×1080。
- **影响**：容易误判“截图不是 1440”；不影响验收。建议在工具注释/README 写明。

### BUG-5（P2，预演风险）：`preview_kaykit.gd` 的挂灯偏移与 0.58 比例不能直接进运行时

- **复现**：读 `tools/preview_kaykit.gd`：灯笼位置用 `toward_camera * 0.16` 世界偏移、`scale 0.58`；读 `01-brief.md` P0-3 风险。
- **期望**：运行时挂 `handslot_l`、本地偏移、比例 0.74（美术签字）。
- **实际**：预演图是相机朝向相关的世界偏移，角色一转就会漂移；0.58 只有 1.268m，比旧提灯人矮约 24%。
- **影响**：若程序照抄预演，会出现“灯随相机漂”“角色变矮”。属于实现风险，不是当前 bug。
- **建议**：04-impl 严格按 `02-art-review.md` §4.2/§4.5 的 0.74 + 本地偏移 + 0.7m 短杆执行。

---

## 7. 本轮回归清单（改动前后必测）

| 回归项 | 命令 | 通过标准 | 本轮基线 |
|---|---|---|---|
| 巡逻路线/位移 | `probe_patrol.gd` | 三名 NPC `travelled > 4.2m/12s`；提灯人与基线差 ≤5% | 提灯人 7.4–9.5m |
| 最小间距（水池/石圈/石像/拱柱） | `probe_patrol.gd` | 分别 >4.8 / >2.6 / >1.8 / >1.0m | 6.38 / 3.29 / 3.32 / 1.72 |
| 夜间提灯 | `screenshot_patrol.gd`；18:24 与 00:00 近景 | 暖光、光晕、灯芯可见；脸/地面光池可读；无过曝；不新增阴影灯 | `patrol_lantern_night.png` 已拍 |
| 相机 | `focus_patrol(0)` 16°/5.8m；默认 48°/27.5m；zoom 0.65–1.7 | 不改默认机位；近景如需改 ≤4° 且签字 | 基线截图已覆盖默认/近景 |
| UI/键位开关 | `qa_key_toggle.gd`；`5`/`F1`/UI「游人」 | 模型、灯、光晕一起隐藏；恢复后无残留；UI 状态同步 | PASS |
| 无头干净 | `--headless --quit-after 600` | 0 匹配；退出码 0 | PASS（12.81s） |
| FPS 不回退 >2 | 交错探针 3 次；legacy 3 次 | 见 §8.3 | 交错 shown 74.9；legacy shown 56.6 |
| 程序化回退 | 实现提供的调试开关/模拟加载失败 | 回退后 `PROBE_PATROL_OK`，画面仍是原程序化提灯人，不刷错误 | 改前不存在，改后必测 |
| 其他 NPC/场景 | `probe_patrol.gd` + 截图 | 扫园人/狐狸/小女孩/章鱼/任务链不回退 | 基线正常 |

---

## 8. 测试计划：程序化模型 → glTF 模型（Cycle 1）

> 所有用例只针对**提灯守夜人**；扫园人、小狐侍、小女孩、章鱼、任务、相机默认值不动。新增测试脚本均为只读，不改游戏逻辑。数值阈值优先来自 `01-brief.md` / `02-art-review.md`；与基线冲突处已标注。
>
> **待复测声明**：本表是改动后的测试计划。基线本次实际执行的只有：无头 600 帧、标准探针（位移/间距/toggle/FPS）、真实键位/UI 开关、8 张截图、交错性能探针。F-05/F-06、V-01–V-08、P-01–P-07、R-07 等涉及 Rogue 接入后的数值/画面，凡本文未给出实测值的，均标为**待复测**，不得在 05 用估计值代替。

### 8.1 功能（F）

| ID | 用例 | 命令/方法 | 判定阈值 | 优先级 |
|---|---|---|---|---|
| F-01 | Rogue 加载与实例化 | 启动场景；检查 `patrols[0]` 下存在 Rogue 实例、`AnimationPlayer`、`handslot_l` | 加载成功；无 `SCRIPT ERROR`；灯/模型同属提灯人节点 | P0 |
| F-02 | 程序化回退 | 模拟 GLB 缺失 / `AnimationPlayer` 为空（调试开关或临时改名资源） | 场景不崩；走原 `_build()`；`PROBE_PATROL_OK`；只警告一次；无刷屏 | P0 |
| F-03 | 巡逻 FSM 不变 | `probe_patrol.gd` 3 次 | `PROBE_PATROL_OK`；提灯人 `travelled` 与基线差 ≤5%（基线 7.4–9.5m）；WALK→PAUSE→WALK 至少各一次；PAUSE 1.6–3.4s | P0 |
| F-04 | 路线/间距不变 | `probe_patrol.gd` 3 次 | `min_pond>4.8`、`min_circle>2.6`、`min_statue>1.8`、`min_pillar>1.0`；中位数不低于基线 −0.2m | P0 |
| F-05 | 朝向/脚底 | 同机位截图 + 节点检查 | 模型正面 +Z，子节点 `yaw=π`；Idle 脚底 y=0 ±0.02m；无倒走 | P0 |
| F-06 | 动画三态 | `capture_patrol_sequence.gd`（目标切到 `patrols[0]`，只改工具）90 帧 | T-pose 帧 = 0；Idle/Walk/PAUSE 各 ≥1；过渡 ≤0.25s；无 root motion；无明显滑步 | P0 |
| F-07 | 提灯挂手 | 行走/驻足截图 + 节点检查 | 挂 `handslot_l`；本地偏移；无脱手/漂移/穿模；灯随臂摆、PAUSE 举起 | P0 |
| F-08 | 夜间灯光曲线 | `set_night` 数值检查 + 18:24/00:00 截图 | `glow=max(night, dusk*0.55)` 不变；灯/光晕/玻璃随 glow；无新增阴影灯；无过曝 | P0 |
| F-09 | 开关链路 | `qa_key_toggle.gd`；UI 按钮 | `5`/F1/UI 三条链路均隐藏并恢复；模型/灯/光晕/地面池一起消失；无残留光源 | P0 |
| F-10 | 其他 NPC 不受影响 | `probe_patrol.gd` + 截图 | 扫园人/狐狸 `travelled` 与基线差 ≤5%；无新错误 | P1 |

### 8.2 视觉（V）

| ID | 用例 | 命令/方法 | 判定阈值 | 优先级 |
|---|---|---|---|---|
| V-01 | 比例/身高 | A/B 固定机位 `(5.7,1.55,6.2)→(2,1.0,3.0)`，18:12；0.74 与旧提灯人同裁剪 | 总高 95–105%（0.74 → 1.618m vs 旧 1.66m = 97.5%）；头顶差 ≤±4%；脚底贴地 | P0 |
| V-02 | 武器/披风 | 节点可见性检查 + 近景 | 5 件武器可见数 = 0（`Knife_Offhand`/`1H_Crossbow`/`2H_Crossbow`/`Knife`/`Throwable`）；披风按 §9.1 Q3 签字结果执行；无 magenta/UV 大缝 | P0 |
| V-03 | 提灯可读性 | `focus_patrol(0)` 近景（16°/5.8m 或签字的 12°/5.2m），18:24/00:00 | 灯杆/灯框/灯芯同时在画面；灯心约 0.88m（±0.03m）；不被草/手完全遮住；1080 下光晕 ≥70px | P0 |
| V-04 | 脸部曝光 | 近景脸+胸裁切，00:00 | 脸 p95 <240、max <250、>240 像素 <5%；眼睛/鼻梁/脸颊三段可辨；无纯白过曝 | P0 |
| V-05 | 广角剪影 | 默认 48°/27.5m，18:24 + 00:00，两个行走方向 | 角色 1080 下 ≥100px；暖光点可辨；与女孩红白、扫园人棕帽可区分；不黑成一团 | P1 |
| V-06 | 同屏统一性 | `cycle1_mixed_cast.jpg`（Rogue + 女孩 + 旧扫园人） | 美术签字 ≥6.5/10；否则触发长袍/调色方案（P1，不做默认实现） | P1 |
| V-07 | 640×360 源画面 | 截 640×360 源视口或 1920 图 NEAREST 缩到 640×360 | 无糊/闪/UV 缝/双影/脱手；Nearest 或 NEAREST_WITH_MIPMAPS 按 §9.1 Q4 签字 | P0 |
| V-08 | 截图矩阵完整 | `screenshot_patrol.gd` + 补拍 | 黄昏/夜/默认广角/近景/A-B/同屏各至少 1 张；无 UI/战斗飘字；同机位同裁剪 | P0 |

### 8.3 性能（P）

> **前置决定（需签字）**：legacy `probe_patrol.gd` 的 58.2 绝对值在本机基线即不成立（56.8），且 A/B 顺序敏感（-7.4…15.3）。建议采用下列 **A+B 双轨**：

| ID | 用例 | 命令/方法 | 判定阈值 | 优先级 |
|---|---|---|---|---|
| P-01 | 交错稳态绝对帧率 | `qa_probe_patrol_perf.gd` 前台 3 次，独占运行 | 3 次 `PERF_SHOWN fps_avg` 中位 ≥**60**（基线 74.9）；至少 2/3 次 ≥60 | P0 |
| P-02 | 交错稳态相对回退 | 同上 | shown 中位 ≥基线 74.9 − 2 = **72.9**；hidden 中位 ≥基线 75.3 − 2 = 73.3 | P0 |
| P-03 | 巡逻 FPS 成本（诊断） | 同上 | `PERF_COST` 中位 ≤基线 **+0.4 + 2 = 2.4 FPS**；若超标先定位模型 `cast_shadow`/材质/灯，不单独阻塞（按 Brief 的“诊断”口径） | P1 |
| P-04 | 巡逻 draw call | 同上 | shown−hidden draw 增量 ≤基线 **144.5 + 10 = 154.5**；目标 ≤144.5（越低越好） | P0 |
| P-05 | legacy 功能+相对回归 | `probe_patrol.gd` 前台 3 次 | `PROBE_PATROL_OK`；`PATROL_FPS avg` 中位 ≥基线 56.8 − 2 = **54.8**；shown 中位 ≥56.6 − 2 = **54.6**；avg/min/hidden/shown/cost 全部记录 | P1 |
| P-06 | 三次连跑稳定性 | 上述 3 次连续 | 无崩溃/无新错误；3 次均 `PROBE_PATROL_OK` | P0 |
| P-07 | 无新增光源/阴影灯 | 代码检查 + 截图 | 提灯人仍只有 1 盏无阴影 OmniLight（或按 §9.1 Q4 签字的根灯方案）；不新增阴影灯 | P0 |

**若团队坚持只用 legacy `probe_patrol.gd` 58.2：**

- 先在 04-impl 前把 `probe_patrol.gd` 的 FPS 采样改为“预热 ≥3s + 采样 ≥20s”，再重跑基线；否则命中率取决于窗口/顺序，不能作为门禁。
- 或把阈值改为基线中位 −2（56.8−2=54.8），并在 `05-qa-verify.md` 记录“绝对 60 由交错探针 P-01 证明”。
- 不允许用“历史 60.2”直接当本机门槛；Brief 已明确要求本机重跑基线。

### 8.4 回归（R）

| ID | 用例 | 命令 | 判定 |
|---|---|---|---|
| R-01 | 无头干净 | `--headless --quit-after 600` | 0 `SCRIPT ERROR/ERROR/WARNING`；退出码 0 |
| R-02 | 巡逻路线/间距 | `probe_patrol.gd` | 同 §7；提灯人 travelled 差 ≤5% |
| R-03 | 夜间提灯 | 18:24/00:00 截图 | 暖光/光晕/地面池可见；无过曝/新增阴影 |
| R-04 | 相机 | 默认 48°/27.5m；近景 16°/5.8m（或签字机位） | 默认机位不变；近景改动 ≤4° 且签字 |
| R-05 | UI/键位 | `qa_key_toggle.gd` | 5/F1/UI 按钮 PASS；模型+灯+光晕一起隐藏；无残留 |
| R-06 | 其他 NPC/场景 | probe + 截图 | 扫园人/狐狸/女孩/章鱼/任务链不回退 |
| R-07 | 程序化回退 | 模拟加载失败 | `PROBE_PATROL_OK`；原程序化提灯人可见；不刷错误 |
| R-08 | 截图矩阵 | `screenshot_patrol.gd` + 补拍 | 8 张基线图 + Cycle 1 验收图；`patrol_fox` 遮挡按 BUG-1 处理 |

---

## 9. 风险与建议

### 9.1 需要签字的口径（实现前）

| # | 冲突/问题 | 当前证据 | 建议 |
|---|---|---|---|
| Q1 | **性能门禁 58.2**：Brief 用历史 60.2−2；本机基线中位 56.8，直接失败 | §4.3 / §4.4 | 采用 §8.3 的 A+B 双轨：交错探针 P-01 绝对值 + legacy P-05 相对值；把 58.2 改为 54.8 或删除，并在 05 说明。**这是硬阻塞，需策划/程序签字** |
| Q2 | **近景机位**：Brief 允许 ≤4° 微调；`02-art-review` 提议 16°→12°、5.8m→5.2m、target y 1.0 | `02-art-review.md` §4.8 | 先确认距离 5.8→5.2 是否在 Brief 授权内；未签字前，QA 用 16°/5.8m 做前后同机位对比，另拍 12°/5.2m 作参考 |
| Q3 | **披风**：Brief 默认保留（穿模可签字隐藏）；`02-art-review` 要求隐藏 `Rogue_Cape`（未蒙皮、最低 y=-1.122，会钻地） | `01-brief.md` L135；`02-art-review.md` §4.2 | 以美术签字“隐藏”为准；若保留，必须拍斜坡/石阶穿模证据，否则 05 视觉 FAIL |
| Q4 | **灯光参数**：Brief 要求保留 `glow*1.35`/range 6.0；`02-art-review` 建议 `0.20+glow*0.25`、range 4.0、色 (1.0,0.78,0.52) | `01-brief.md` P0-3；`02-art-review.md` §4.5 | 允许美术签字改参；QA 按“无过曝（p95<240）、脸/地面可读、无新增阴影灯”验收；若改参，记录最终值 |
| Q5 | **贴图过滤**：Brief 写 Nearest；`02-art-review` 建议 NEAREST_WITH_MIPMAPS（防移动闪烁） | 两份文档 | 以 1.2s 行走序列验证：裸 Nearest 若闪烁，改 NEAREST_WITH_MIPMAPS；在 05 记录选择 |

### 9.2 其他风险

- **R1 版本控制**：`godot-garden/` 在当前仓库中是未跟踪目录（`git status` 显示 `?? godot-garden/`），没有可回滚的历史。改动前必须备份或提交（建议至少 `tar` 一份 `scripts/garden_patrol.gd` / `garden_world.gd`），否则回退只能靠人工。
- **R2 并发测量污染**：12:42 美术评审与前台探针 run4 同时渲染，GPU 争用会拉低 FPS。05 验证必须独占运行，并在报告记录 load avg、窗口前后台状态、是否有其他 Godot 进程。
- **R3 采样方法**：`probe_patrol.gd` 的 12s 平均含启动/着色器预热；A/B 单次顺序会被热漂移放大。正式性能结论以交错探针为准；legacy 数据只做功能/相对回归。
- **R4 Q 版比例**：Rogue 头身比 46.7%，与女孩 23.9%、旧提灯人约 18.7% 差异大；美术已判定视觉统一性本轮最多 6.0，不达 7.5。QA 的 V-05/V-06 只按“主镜头可辨 + 美术签字”验收，不把整体风格 8 分作为本轮门槛。
- **R5 灯笼挂点**：`handslot_l` 在 Idle 只有 0.471m 高，需要 0.7m 短杆把灯心抬到 0.88m；若照抄预演的相机偏移，会随相机漂移。F-07 必须检查行走/驻足两种状态。
- **R6 回退路径**：Rogue 加载失败/动画缺失时必须回退到原 `_build()`；如果程序只隐藏模型不重建程序化身体，F-02 判 FAIL。
- **R7 截图工具**：`patrol_fox.png` 被树挡是工具问题；`screenshot_patrol.gd` 的 `focus_patrol(1)` 机位也偏小。Cycle 1 提灯人截图不受影响，但 05 的“小狐侍不回退”需要另拍或修工具。
- **R8 资产导入**：Rogue.glb 3.4MB / 1024 图集 / 76 动画；只接 2–3 条动画，不要全接；材质实例共享，避免每个 NPC 新建材质。性能看 draw call 和蒙皮成本，不看“面数更少”的理论值。

---

## 10. QA 新增脚本与限制

本次只新增/修改 QA 工具，**未触碰任何游戏逻辑**：

| 文件 | 性质 | 作用 | 基线结果 |
|---|---|---|---|
| `tools/qa_key_toggle.gd` | 新增，只读 | 经 `Window.push_input` 发送真实 `KEY_5`/`KEY_F1`，并触发 UI「游人」按钮的 `toggled` 信号；验证三条开关链路 | `QA_KEY_TOGGLE_OK`（§4.5） |
| `tools/qa_probe_patrol_perf.gd` | 新增，只读 | shown/hidden 正反顺序交错、4 块 ×4s、按 wall-clock 数帧、记录 draw call；给出稳定 A/B | shown 74.5/75.3，cost +3.9/-3.1，draw delta 144.5（§4.4） |

- 两个脚本都只实例化 `garden.tscn`、读节点状态/切 `set_patrol_visible`，结束后 `queue_free`；不写游戏状态、不改场景/资源。
- `qa_probe_patrol_perf.gd` 首版曾有 `Array[bool]` 类型错误（仅 QA 脚本，已修复）；最终版本运行干净，日志无 `ERROR/WARNING`。
- 未新增 `.uid` 文件（CLI 运行未生成）；若编辑器打开项目，Godot 会自动生成，不影响运行。

**改动范围证据**：`find godot-garden -newermt '2026-10-31 12:25'` 在 QA 窗口内只列出 `docs/agency/*`、`tools/qa_*.gd`、`tools/_inspect_rogue.gd`（并发评审，非本 QA）与截图；`scripts/garden_patrol.gd`/`garden_world.gd`/`garden_scene.gd`/`garden_ui.gd` mtime 仍为 2026-10-30，确认基线未被改动。

---

## 11. 签字建议

- **QA 基线**：接受为 Cycle 1 对照；功能/稳定性/截图/开关链路通过。
- **性能门禁**：不接受按 Brief 58.2 直接判定；请策划/程序在 04-impl 前签字确认 §8.3 的双轨口径。若坚持 58.2，05 将在基线阶段即判 BLOCKED，无法区分实现回退。
- **视觉门禁**：按 `02-art-review.md` 的 6.5（角色/统一性）与 §8.2 的数值阈值执行；Q2–Q5 需美术/策划签字后写入 05。
- **下一步**：04-impl 先做 P0-1（0.74、脚底、朝向、武器隐藏、回退），保留程序化回退；QA 在实现后按 §8 执行，并用 `qa_probe_patrol_perf.gd` 独占跑 3 次。
