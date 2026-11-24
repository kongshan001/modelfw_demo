# 风车原野 · 青岚杯 — 技术说明

更新：2026-11-24  
工程：`godot-ai-3d-game/`，Godot 4.6 stable，GL Compatibility（OpenGL 4.1）。

## 0. 参考视频识别与复刻边界

参考：B 站《用GPT6+Hyper3D，轻松做3D游戏！》，BV1m8eg6wE3V，2:49，UP 主“汤姆喵喵说AI”。  
用 `yt-dlp --proxy http://127.0.0.1:7897` 下载 720p（实际输出 360×640、30fps、168.7s），再用 `ffmpeg fps=1` 抽 169 帧、关键段按 0.5s 复看。分析帧全部保存在 `/tmp/ref_bv1m8/`，没有复制进仓库。

视频里实际做的是 **第三人称卡丁车竞速**，不是射击/塔防：
- 3、2、1、GO 倒计时；追尾镜头；方向盘式转向；单圈 `LAP 1/1`。
- 一辆玩家车 + 两名 AI 对手；路面有红白路肩、方格线、加速带与 `BOOST!` 提示。
- HUD：左上圈数、右上计时、右下速度表（19→81 km/h）、左下小地图、居中倒计时。
- GPT-6/Codex 负责从提示词生成完整游戏代码/结构；Hyper3D Rodin MCP 负责图生 3D 卡丁车、树、风车、拱门等资产。

复刻仅保留抽象玩法与视觉语言。项目名、杯赛名、车手名（阿栗/齿轮仔/泡泡糖）、赛道、车辆、配色、UI 和全部程序化模型均为原创；没有使用视频中的游戏名 `Sunny Toy Valley`、角色、模型、贴图或音频。

## 1. 运行与输入

```bash
godot --path godot-ai-3d-game
# 可选 --resolution 1920x1080
```

输入由 `race_world.gd::_setup_input()` 注册到 `InputMap`：

| 动作 | 键 |
| --- | --- |
| accelerate | W、↑ |
| brake | S、↓ |
| steer_left / steer_right | A / D、← / → |
| pause | ESC、P |
| restart | R |

`R` 在比赛、暂停或结算状态都会重开；重开走 `SceneTree.reload_current_scene()`（工具/子视口内走等价的新实例替换）。HUD 按钮与键盘走同一套 public 方法。

## 2. AI 资产管线还原与降级（重要）

### 2.1 视频中的流程

1. 先让 Codex 生成一张游戏效果参考图与设计方案；
2. 用提示词让代码模型搭起空赛道、UI、车辆控制；
3. 遇到需要 3D 模型的地方，通过 **Hyper3D Rodin MCP** 图生 3D；
4. 生成的 GLB 直接导入游戏，原视频展示过红色卡丁车、蓝/黄卡丁车、树、风车、拱门。

### 2.2 本机实际可用的层

| 层 | 本机情况 | 本实现 |
| --- | --- | --- |
| 代码/场景生成 | Godot 4.6 + GDScript，可用 | 全部代码由本 worker 编写、真实跑通 |
| Hyper3D Rodin | 无 MCP/CLI 访问；会话可见 MCP 只有 Blender | **未使用、未伪造** |
| Tripo 图生 3D | 授权来源 `TRIPO_API_KEY` / teamai secret 为空；本机另有 Tripo CLI 本地配置，但不属于允许的 key 来源，未读取/未使用；脚本 `tools/tripo/tripo_gen.py` 在无 key 时会 `TRIPO_SKIPPED` | **未提交任务，credits=0**，余额保持 225 |
| 3D 资产 | — | 玩家驾驶员用 CC0/CC-BY `Fox.glb`；其余全部 GDScript 程序化几何 |

没有把程序化模型或 CC0 模型标记成 AI 生成资产。没有打印或落盘任何 API key。

### 2.3 与 Hyper3D 流程的差异

- 参考视频的车辆/场景是图生 3D 网格 + 纹理/PBR，形体细节和表面丰富度更高。
- 本项目车辆由 30 余个 Box/Cylinder/Torus 拼成，赛道/路肩/护栏/拱门/风车/树/云/山用 ArrayMesh、PrimitiveMesh、MultiMesh 生成，视觉是刻意的低模玩具风；没有 UV 手绘纹理，也不存在 AI 网格拓扑修复问题。
- 相同点是“资产→引擎”的落地链路：`Fox.glb` 走真实 glTF 导入、骨骼动画与运行时材质调优，说明如果之后接入 Hyper3D/Tripo，产物进入 `assets/ai/generated/` 后可以沿用同一套导入/验收流程。
- 预算：Tripo 预算上限 100 credits；本次实际 0。接入步骤与 key 策略见 `assets/ai/README.md`。

### 2.4 如果之后要补齐真正 AI 资产

- 先做原创三视图（正面/侧面/背面），不得使用视频截图；
- Hyper3D 可用时优先 Hyper3D Rodin；否则 Tripo（`profile=cn`，代理 `http://127.0.0.1:7897`）；
- 单任务后记录 `task_id`、模型版本、credit 消耗、输入图 hash/许可；
- 总预算不超过 100 credits，资产落 `assets/ai/generated/`，在 `CREDITS.md` 增补来源；
- 加载失败时继续保留程序化车/回退小狐狸，不允许空白车或 SCRIPT ERROR。

## 3. 场景与渲染

```
Main scene
└── RaceWorld (Node3D, race_world.gd)
    ├── SkyEnvironment / Sun
    ├── Track (Node3D, track.gd)
    ├── Grass (340m PlaneMesh + ground.gdshader)
    ├── Hills / MountainRing / SnowCaps / CloudBanks (MultiMesh)
    ├── TreeTrunks / TreeCanopies / Bushes / Wildflowers / Rocks (MultiMesh)
    ├── Windmill (tower/roof/blades/hay)
    ├── 3 BoostPads
    ├── PlayerKart / 2 RivalKarts (Node3D + KartVisual)
    ├── ChaseCamera
    └── HUD (CanvasLayer)
```

- 渲染：GL Compatibility，MSAA 关闭，屏幕 AA 关闭，无 TAA；1920×1080 由 SubViewport 真实 GPU 渲染截图。
- 灯光：一盏暖色 DirectionalLight3D，默认阴影贴图、投射范围 85m；环境使用彩色环境光，避免纯天空蓝把路面染成高饱和蓝。
- 天空：`ProceduralSkyMaterial`（顶部蓝、地平线浅青、地面浅色）；没有依赖引擎雾/体积雾，GL 兼容更稳。
- 草地：`shaders/ground.gdshader` 用世界坐标的低频斑块 + 极淡割草条纹，无贴图。
- 树/花/山/云全部 MultiMesh，主场景 draw call 规模随实例数增长很小；阴影仅车、拱门、风车等关键动态/地标投射。
- 草地/路面/路肩/护栏/方格线均为运行时或静态程序化网格。弯道使用 12 个控制点的闭合 Catmull-Rom 曲线，16 段/控制点，共 192 个采样点。

## 4. 赛道数学

`RaceTrack`（`track.gd`）：

- 12 个控制点（闭环），Catmull-Rom；总长度 **328.5m**，路宽 14m（`HALF_WIDTH=7`）。
- 采样点缓存：`samples[]`、`tangents[]`、`rights[]`、`dists[]`，支持 `point_at`、`tangent_at`、`right_at`、`nearest`、`curvature_at`。
- `nearest()` 先找最近采样点，再沿切线投影，返回 `{progress, lateral, center, tangent, right}`；玩家与道具触发都用它保证道路坐标一致。
- 路面/线/护栏/方格起跑线用统一三角形 ribbon 生成；发现并修复过绕序导致的双面法线翻转（早期路面/方格线发黑）。
- 起跑线位于 progress 0；起跑格在终点线后 **6m**。完赛目标 `race_goal = 328.5 + 6 = 334.5m`，玩家必须从起跑格出发，跨过终点线后再完整跑一圈，倒数时看到的是拱门前方而不是拱门底下。

## 5. 状态机与核心规则

`RaceWorld`：

| 状态 | 行为 |
| --- | --- |
| COUNTDOWN | 3.35s；玩家/AI 不可动；红起跑灯；冻结计时 |
| RACING | 计时开始，玩家输入 + AI 寻线，检测加速带和完赛 |
| PAUSED | 时间、物理、计时全部冻结；遮罩；`active=false` |
| FINISHED | 玩家冲线后定格；算名次；镜头绕车；胜负结算；R 重开 |

- 玩家冲线时 `finish_place = 1 + 已完赛的 AI 数`；第 1 名胜利，2/3 失败。
- AI 若先冲线会 `mark_finished(place)` 并停在终点区；玩家仍必须自己冲线才能结束。
- 暂停/恢复不改变计时；`pause_game()` 在暂停时冻结 `elapsed` 与所有 AI/玩家状态。
- 结果面板使用同一套 `finish_time`、`best_speed`、`boost_count`，不是硬编码文案。

## 6. 车辆与 AI

### 6.1 玩家

`RaceKart.step_player()`：

- 最高速 `24 m/s`（86.4 km/h），加速 `14.5 m/s²`，制动 `27 m/s²`，倒车 `6.5 m/s`，滑行减速 `6 m/s²`。
- 转向速率随速度从 `2.35 rad/s` 降到 `1.12 rad/s`；速度为零时不能原地打方向。
- 横向护栏限制 `±6.55m`；撞墙降速到 70%，相机轻震、HUD 红边闪烁。
- 加速带：`apply_boost(1.45)`，最高速 `31 m/s`（111.6 km/h），当前速度立即抬高；3 个加速带 cooldown 3.4s。
- 玩家车模型：低模程序化车身 + 车轮胎/轮毂/挡泥板/尾翼/尾灯；玩家驾驶员为 `Fox.glb`（缩放约 0.0078，播放 `Run`，朝向 `+Z=head → rotation.y=π`）。缺图时 `KartVisual._build_fallback_fox()` 用球/圆锥生成小狐狸，保证不空白。

### 6.2 AI

- 2 名 AI，基础速度 22.4 / 23.2 m/s，加速度 8.5 m/s²。
- 弯道按 `curvature_at()` 从 1.0 降到 0.82 倍速；车道基准 ±2.35m，加正弦摆动 ±0.8m。
- 橡皮筋：`clamp(1 + (player_distance - ai_distance) * 0.003, 0.95, 1.20)`；落后时最多 +20% 速度，领先时略收油。
- AI 用 `start_progress + race_distance` 在闭环上取点，`race_distance` 与玩家同名同量纲，排名和冲线用同一阈值。
- AI 不参与 boost 道具触发；它们的目标是提供可读的对手与名次压力，不做硬碰撞。

## 7. 视觉与 HUD

- 设计坐标 1280×720；`RaceHud._fit_ui()` 按视口取最小缩放，在 1920×1080 为 1.5×，所以截图/窗口都是同一构图。
- 相机：追尾支架不直接对世界坐标做弹簧插值；`_cam_yaw` 平滑追随车头，距离/高度固定阻尼。倒计时 8.2m / 3.15m，比赛 7.2m / 2.65m。这样转向时相机绕车摆动，不会抄内线穿过车身或把车甩出画面。FOV 67° 起，随速度与 boost 增高。
- HUD 元素：LAP 1/1、名次、TIME、FPS、MINIMAP、速度表（130 km/h 满刻度）、倒计时、加速提示、暂停面板、胜负结算 + 彩纸。
- 字体：`SystemFont`（PingFang SC / Hiragino / Noto CJK / Microsoft YaHei），无字体文件入库。
- 加速带：箱体底座 + 4 边发光框 + 三组人字形箭头；可用时脉冲，冷却时降亮。
- 起跑拱门：方格横幅、三盏红→绿起跑灯、气球、`Label3D` 青岚杯字牌、旗子。
- 场景元素全部为原创低模配色；没有从参考视频截取贴图。

## 8. 验收

### 8.1 无头 smoke

```bash
godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd
```

最后一行：`AI_3D_GAME_SMOKE_OK checks=53`

覆盖：Fox 资源加载 + AnimationPlayer；3 车/2 AI/3 加速带；倒计时→RACING；真实输入加速/转向；玩家/AI 位移；护栏夹回；加速带触发、计数与冷却；暂停计时冻结与恢复；玩家第 1 冲线 → 胜利 + HUD 结算；重开回到 COUNTDOWN 且清空状态；两名 AI 先完赛 → 玩家第 3 → 失败遮罩。

### 8.2 自动驾驶整圈

```bash
godot --headless --path godot-ai-3d-game -s tools/playtest_autopilot.gd
```

本项目交付时使用允许复现的 `tools/playtest_autopilot.gd` 验证：完赛 **13.46s**，3 次加速带，第 1 名，最终两人距离约 275/282m（玩家 334.6m）。自动寻线仅用于验收/录制，正常游戏默认 `auto_drive=false`。

### 8.3 截图

```bash
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/screenshot_race.gd
```

输出 `docs/shots/01_start_grid.png` … `06_finish_win.png`，全部 1920×1080。  
本次运行 `RACE_SHOTS_OK count=6 fps=60`；截图线程中的 PNG 编码会拉低 HUD FPS 读数，不作为性能结论，性能以 `perf_ai_3d_game.gd` 为准。六张图均为 **1920×1080**。

### 8.4 性能

```bash
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd -- --vp=1280x720
```

Intel HD Graphics 6000、vsync 关、自动驾驶、3 车 + HUD + 全场景：

| 视口 | 帧数/采样 | 平均 FPS | 中位 FPS | P95 | 最差帧 | 瞬时最低 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1920×1080 | 393 / 6.00s | **65.49** | 64.00 | 101.54 | 21.34ms | **46.87** |
| 1280×720 | 450 / 6.01s | **74.91** | 73.83 | 131.58 | 23.64ms | **42.31** |

均高于 Intel HD 30fps+ 目标。所有场景在报告中均为真实 GPU 运行；没有用 headless 数据冒充渲染性能。

### 8.5 真实 GPU 控制台

```bash
godot --path godot-ai-3d-game --resolution 1280x720 --quit-after 600
```

实测无 `SCRIPT ERROR`（`--headless --quit-after 600` 与真实 GPU `--quit-after 600` 均通过）。

### 8.6 10s 媒体

`tools/capture_race_video.gd` 用真实 1920×1080 GPU 帧录完整一圈（含倒计时/加速/冲线/结算），按 20fps 采样到 `/tmp/race_video_frames`；ffmpeg 加速/编码成 10s MP4：

- 源帧：380 帧 / 19.00s（20fps），冲线在第 334 帧；冲线后固定保留 46 帧结算。
- 成片：`docs/media/qinglan_cup_10s.mp4`，1920×1080、30fps、10.000s、5.2MB、H.264。
- 录制时隐藏 FPS 标签：PNG 回读会让 `Engine` 瞬时 FPS 掉到个位数，不代表游戏性能；正常游玩与截图仍显示真实 FPS。
- 加速倍率约 1.9×，因此成片 HUD 时间会跑得比真实时间快；完赛计时本身仍是真实模拟结果（13.40s）。

## 9. 已知风险 / 未做

- 玩家与 AI 之间没有硬物理碰撞；并排时可能视觉重叠。
- 没有音效/音乐、手柄、触屏、设置菜单、回放。
- 场景低模风格，远山/云/树是低多边形海量实例，不是高精度 AI 资产；这是无 Hyper3D/Tripo 权限的显式取舍。
- 完全使用系统 CJK 字体，跨机器字形可能不同。
- 自动驾驶是验收/录制辅助，不暴露在 HUD；正常输入仍由 smoke 与人工试玩覆盖。
- 参考视频只放 `/tmp`，仓库不含其画面/音频；如做对外发布，需保留 Fox 的 CC-BY 4.0 署名。
