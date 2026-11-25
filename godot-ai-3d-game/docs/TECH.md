# 风车原野 · 青岚杯 — 技术说明

更新：2026-11-25（T-20261125-001 Tripo 资产接入）  
工程：`godot-ai-3d-game/`，Godot 4.6 stable，GL Compatibility（OpenGL 4.1）。

## 0. 参考视频识别与复刻边界

参考：B 站《用GPT6+Hyper3D，轻松做3D游戏！》，BV1m8eg6wE3V，2:49，UP 主“汤姆喵喵说AI”。  
用 `yt-dlp --proxy http://127.0.0.1:7897` 下载 720p（实际输出 360×640、30fps、168.7s），再用 `ffmpeg fps=1` 抽 169 帧、关键段按 0.5s 复看。分析帧全部保存在 `/tmp/ref_bv1m8/`，没有复制进仓库。

视频里实际做的是 **第三人称卡丁车竞速**，不是射击/塔防：
- 3、2、1、GO 倒计时；追尾镜头；方向盘式转向；单圈 `LAP 1/1`。
- 一辆玩家车 + 两名 AI 对手；路面有红白路肩、方格线、加速带与 `BOOST!` 提示。
- HUD：左上圈数、右上计时、右下速度表（19→81 km/h）、左下小地图、居中倒计时。
- GPT-6/Codex 负责从提示词生成完整游戏代码/结构；Hyper3D Rodin MCP 负责图生 3D 卡丁车、树、风车、拱门等资产。

复刻仅保留抽象玩法与视觉语言。项目名、杯赛名、车手名（阿栗/齿轮仔/泡泡糖）、赛道、车辆、配色、UI 与其余程序化模型均为原创；2026-11-25 的 Tripo 车体/风车由本项目原创参考图生成（见第 2 节）；没有使用视频中的游戏名 `Sunny Toy Valley`、角色、模型、贴图或音频。

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

## 2. Tripo 图生 3D 资产管线（2026-11-25）

### 2.1 视频中的流程

1. 先让 Codex 生成一张游戏效果参考图与设计方案；
2. 用提示词让代码模型搭起空赛道、UI、车辆控制；
3. 遇到需要 3D 模型的地方，通过 **Hyper3D Rodin MCP** 图生 3D；
4. 生成的 GLB 直接导入游戏，原视频展示过红色卡丁车、蓝/黄卡丁车、树、风车、拱门。

### 2.2 本机实际执行（Tripo CLI，`profile=cn`）

| 项 | 卡丁车 | 风车 |
| --- | --- | --- |
| 用途 | 替换 `KartVisual` 程序化车体 | 替换 `RaceWorld` 程序化塔身 |
| 参考图 | `assets/ai/tripo/refs/kart_3q.png` | `assets/ai/tripo/refs/windmill_3q.png` |
| Tripo task | `f7ef8737-d179-451a-b858-8ad024d14183` | `cbdc4d8b-e6e1-43f9-9838-932b78f5c26d` |
| 模型 | P2-20260801 | v3.1-20260211（H3.1） |
| 参数 | face_limit=18000，texture=detailed，pbr=false，quad=false | face_limit=20000，texture=detailed，pbr=false，quad=false |
| 三角面 | 18,857 | 18,758 |
| credits | **120** | **40** |
| 输出 | `kart.glb` 3.6MB + 抽出贴图 | `windmill.glb` 1.7MB + 抽出贴图 |

- 生成前用 `tripo make ... --dry-run --json` 核对：120 + 40 = **160 credits**，低于 180 预算；实际消耗与预估一致。
- 余额 **225 → 65**；没有失败、退款、重试或额外 convert 任务。两个 GLB 均直接交付。
- 所有命令经 `HTTPS_PROXY/HTTP_PROXY=http://127.0.0.1:7897`、显式 `--profile cn`；key 由已登录的 Tripo CLI `cn` profile 自行读取，**项目/文档/仓库中没有 key，未输出明文 key**。
- 参考图由 `tools/tripo_refs.gd` 在 1024²、浅灰底、真实 GPU 下渲染：卡丁车隐藏车轮/驾驶员/围巾/尾旗/尾灯/尾焰/方向盘，只保留车体；风车隐藏旋转叶片/土台/干草，只保留塔身。这样车轮仍可滚动/转向、叶片仍可旋转。
- 输入素材原创：参考图来自本项目的程序化模型，不含参考视频帧、Hyper3D 资产或原作素材。

### 2.3 接入与整理

**卡丁车**（`scripts/kart_visual.gd`）：

- 程序化车身移入 `Body/ProceduralBody`；Tripo 车身挂到 `Body/TripoKartBody`，可用时隐藏 `ProceduralBody`。
- 源 AABB：长×高×宽 = **0.9995 × 0.2778 × 0.6753m**，长沿 X、车头朝 **+X**，以原点为中心。
- 目标尺寸 **3.25m 长 / 0.95m 高 / 1.80m 宽**；缩放 `(3.2516, 3.4193, 2.6655)`，`rotation.y = +90°` 让车头对准游戏内 `-Z`，偏移 `(0, 0.645, -0.03)`。
- 首轮接入使用 `-90°`，截图发现车是倒着开的（尾翼朝前）；改为 `+90°` 后方向正确。
- 车轮/前轮转向 pivot/boost 尾焰/尾灯/尾旗保留；Fox 驾驶员、围巾、方向盘随 Tripo 座舱后移上移；缺图回退时恢复原程序化位置。
- 同一张 Tripo 贴图通过 `shaders/tripo_kart.gdshader` 的色块蒙版分成奶油/青色/深海军蓝三区，分别替换为每辆车的 `body/accent/dark` 色；玩家奶油/青绿、AI 珊瑚/奶油、金/藏蓝，保留贴图明暗与 GLB 几何。

**风车**（`scripts/race_world.gd`）：

- 程序化塔身/屋顶/门窗/阳台放入 `Windmill/ProceduralBody`；Tripo 塔身挂到 `Windmill/TripoWindmill`。
- 源高 1.0m、目标高 **10.7m**（scale=10.7），底部 y=0.20，`rotation.y=0`：Tripo 输出的 +Z 是轮毂侧/正面，与程序化风车一致。
- 土台、干草、`Windmill/Rotor` 四叶转子保留；转子仍在 `(0, 7.9, 3.18)` 旋转，Tripo 塔身提供塔体/门/窗/阳台/轮毂底座。

**回退**：

- 加载链为 `ResourceLoader.exists` → `load` → `instantiate`；缺图/失败保持原程序化车身/塔身，不空白、不 SCRIPT ERROR。
- smoke 新增 Tripo GLB 加载、节点挂载、程序化节点隐藏、4 轮仍存在、叶片仍存在、AABB 尺寸在预期范围等检查（53 → **66 checks**）。

### 2.4 credits 与许可

| 项 | credits |
| --- | ---: |
| 起始余额 | 225 |
| 卡丁车 P2 | 120 |
| 风车 H3.1 | 40 |
| **合计** | **160** |
| 结束余额 | 65 |

Tripo 输出用于本原创项目；输入是项目自有程序化渲染，不含第三方角色/Logo/游戏素材；Tripo 服务条款适用。驾驶员仍使用 CC0/CC-BY Fox，发布时保留 CC-BY 4.0 署名。

### 2.5 与 Hyper3D 流程的差异

- 视频使用 Hyper3D Rodin；本机无 Hyper3D 访问，改用 Tripo P2/H3.1。输入仍是项目原创图，不复制视频/原作素材。
- P2 输出是单个网格，车轮不能独立旋转；因此参考图隐藏车轮，游戏保留程序化轮组。
- P2 车体有少量 AI 拓扑瑕疵（侧裙长条、尾翼支撑略碎），H3.1 风车屋顶有烘焙明暗；未做二次重拓扑。两者合计 37.6k tris，Intel HD 目标仍达标。
- GLB 的纹理在 Godot 导入时抽成同目录 `*_Color_*.jpg`；移动/发布时必须与 GLB 一起保留。

## 3. 场景与渲染

```
Main scene
└── RaceWorld (Node3D, race_world.gd)
    ├── SkyEnvironment / Sun
    ├── Track (Node3D, track.gd)
    ├── Grass (340m PlaneMesh + ground.gdshader)
    ├── Hills / MountainRing / SnowCaps / CloudBanks (MultiMesh)
    ├── TreeTrunks / TreeCanopies / Bushes / Wildflowers / Rocks (MultiMesh)
    ├── Windmill (TripoWindmill + 程序化 Rotor/土台/干草; ProceduralBody 隐藏)
    ├── 3 BoostPads
    ├── PlayerKart / 2 RivalKarts (Node3D + KartVisual; Body/TripoKartBody + 程序化 Wheels/尾焰/旗子)
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
- 玩家车模型：Tripo P2 车体（`Body/TripoKartBody`，18,857 tris，3.25×0.95×1.80m，`rotation.y=+90°`）+ 程序化车轮胎/轮毂/转向 pivot/尾翼/尾灯/尾焰/旗子；三辆车共用 GLB，通过 `shaders/tripo_kart.gdshader` 重新着成各自车队色。玩家驾驶员为 `Fox.glb`（缩放约 0.0078，播放 `Run`，朝向 `+Z=head → rotation.y=π`，Tripo 座舱下位置 `(0,0.78,0.40)`）。缺 Tripo 图时隐藏 `TripoKartBody`、恢复 `ProceduralBody` 和原驾驶员位置；缺 Fox 时 `KartVisual._build_fallback_fox()` 用球/圆锥生成小狐狸，保证不空白。

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
- 起跑拱门、路肩、护栏、树/花/山/云仍是原创程序化几何；Tripo 只替换车体与风车塔身，场景元素没有从参考视频截取贴图。
- 车队色：Tripo 卡丁车贴图的奶油/青色/深海军蓝由 `shaders/tripo_kart.gdshader` 映射成 body/accent/dark 三色；玩家奶油+青绿、AI A 珊瑚+奶油、AI B 金+藏蓝。色块蒙版同时保留贴图明暗，避免三辆车完全相同。
- 风车：Tripo H3.1 塔身（10.7m，18,758 tris）+ 程序化四叶转子；土台、干草、旋转动画保留。

## 8. 验收

### 8.1 无头 smoke

```bash
godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd
```

最后一行：`AI_3D_GAME_SMOKE_OK checks=66`

覆盖：Fox 资源加载 + AnimationPlayer；Tripo kart/windmill GLB 加载、节点挂载、程序化回退节点隐藏、4 轮仍存在、风车叶片仍存在、AABB 尺寸；3 车/2 AI/3 加速带；倒计时→RACING；真实输入加速/转向；玩家/AI 位移；护栏夹回；加速带触发、计数与冷却；暂停计时冻结与恢复；玩家第 1 冲线 → 胜利 + HUD 结算；重开回到 COUNTDOWN 且清空状态；两名 AI 先完赛 → 玩家第 3 → 失败遮罩。

### 8.2 自动驾驶整圈

```bash
godot --headless --path godot-ai-3d-game -s tools/playtest_autopilot.gd
```

本项目交付时使用允许复现的 `tools/playtest_autopilot.gd` 验证：完赛 **13.45s**，3 次加速带，第 1 名，最终两人距离 275.2 / 281.9m（玩家 334.6m）。Tripo 资产接入前后完赛时间/AI 距离一致（父任务 13.46s）。自动寻线仅用于验收/录制，正常游戏默认 `auto_drive=false`。

### 8.3 截图

```bash
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/screenshot_race.gd
```

输出 `docs/shots/01_start_grid.png` … `08_windmill_closeup.png`，全部 1920×1080。  
本次运行 `RACE_SHOTS_OK count=8 fps=43`；截图线程中的 PNG 编码会拉低 HUD FPS 读数，不作为性能结论，性能以 `perf_ai_3d_game.gd` 为准。八张图均为 **1920×1080**。新增 `07_kart_closeup` 展示 Tripo 车体/程序化轮组/Fox，`08_windmill_closeup` 展示 Tripo 塔身/旋转叶片。

### 8.4 性能

```bash
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd -- --vp=1280x720
```

Intel HD Graphics 6000、vsync 关、自动驾驶、3 车 + HUD + 全场景：

| 视口 | 帧数/采样 | 平均 FPS | 中位 FPS | P95 | 最差帧 | 瞬时最低 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1920×1080 | 399 / 6.00s | **66.47** | 67.39 | 94.97 | 25.39ms | **39.39** |
| 1280×720 | 433 / 6.01s | **72.09** | 73.58 | 106.30 | 27.64ms | **36.18** |

接入 Tripo 后平均 FPS 相比父任务基本持平（1080p 65.49→66.47，720p 74.91→72.09），瞬时最低从 46.9/42.3 降到 39.4/36.2，仍高于 Intel HD 30fps+ 目标。所有场景在报告中均为真实 GPU 运行；没有用 headless 数据冒充渲染性能。

### 8.5 真实 GPU 控制台

```bash
godot --path godot-ai-3d-game --resolution 1280x720 --quit-after 600
```

实测无 `SCRIPT ERROR`（`--headless --quit-after 600` 与真实 GPU `--quit-after 600` 均通过）。

### 8.6 10s 媒体

`tools/capture_race_video.gd` 用真实 1920×1080 GPU 帧录完整一圈（含倒计时/加速/冲线/结算），按 20fps 采样到 `/tmp/race_video_frames`；ffmpeg 加速/编码成 10s MP4：

- 源帧：380 帧 / 19.00s（20fps），冲线在第 334 帧；冲线后固定保留 46 帧结算。
- 成片：`docs/media/qinglan_cup_10s.mp4`，1920×1080、30fps、10.000s（300 帧）、4.6MB、H.264。
- 录制时隐藏 FPS 标签：PNG 回读会让 `Engine` 瞬时 FPS 掉到个位数，不代表游戏性能；正常游玩与截图仍显示真实 FPS。
- 加速倍率约 1.9×，因此成片 HUD 时间会跑得比真实时间快；完赛计时本身仍是真实模拟结果（13.40s）。

### 8.7 Tripo 资产检查

```bash
godot --headless --path godot-ai-3d-game -s tools/inspect_tripo_assets.gd
```

- `kart.glb`：1 个 mesh、18,857 tris、1 个带贴图 surface，AABB 0.9995 × 0.2778 × 0.6753m，中心在原点。
- `windmill.glb`：1 个 mesh、18,758 tris、1 个带贴图 surface，AABB 0.5858 × 1.0 × 0.6218m，中心在原点。
- 两个文件都被导入为 `PackedScene`；纹理在 Godot 导入时抽出为同目录 `*_Color_*.jpg`。smoke 与 `tools/tripo_turntable.gd` 都基于真实导入结果，不只看任务状态。

## 9. 已知风险 / 未做

- 玩家与 AI 之间没有硬物理碰撞；并排时可能视觉重叠。
- 没有音效/音乐、手柄、触屏、设置菜单、回放。
- Tripo P2 车体是单网格，车轮不能独立旋转；游戏内保留程序化轮组解决滚动/转向。车体有侧裙长条、尾翼支撑略碎等 AI 拓扑瑕疵；H3.1 风车屋顶有烘焙明暗。未做二次重拓扑。
- 未生成第三个 Tripo 道具/驾驶员：预算优先核心车+风车；驾驶员仍是 CC0/CC-BY Fox + `Run`。
- 完全使用系统 CJK 字体，跨机器字形可能不同。
- 自动驾驶是验收/录制辅助，不暴露在 HUD；正常输入仍由 smoke 与人工试玩覆盖。
- 参考视频只放 `/tmp`，仓库不含其画面/音频；如做对外发布，需保留 Fox 的 CC-BY 4.0 署名。
- Tripo 资产参考图/输出只用于本项目；没有把 Tripo key 或账号配置写入仓库。
