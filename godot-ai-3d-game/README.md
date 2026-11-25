# 风车原野 · 青岚杯

原创低模卡丁车竞速 vertical slice。Godot 4.6 / GL Compatibility / 1280×720 逻辑 / 可 1920×1080。

参考视频实际做的是 **第三人称卡丁车竞速**：倒计时 → 油门/转向 → 加速带 → 一名玩家与两名 AI 抢线 → 冲线。  
本项目复刻这个核心 loop，使用原创场景、车手、车辆、赛道和 UI；没有复制参考视频或原游戏素材。

![追尾竞速](docs/shots/02_chase_corner.png)

## 运行

```bash
godot --path godot-ai-3d-game
# 或
cd godot-ai-3d-game && godot
```

默认窗口 1280×720；也可 `--resolution 1920x1080`。首次启动会自动导入 `assets/ai/cc0/fox/Fox.glb`、`assets/ai/tripo/kart/kart.glb` 与 `assets/ai/tripo/windmill/windmill.glb`。

## 操作

| 按键 | 功能 |
| --- | --- |
| `W` / `↑` | 油门 |
| `S` / `↓` | 刹车 / 倒车 |
| `A D` / `← →` | 转向 |
| `ESC` / `P` | 暂停 / 继续 |
| `R` | 重开（比赛中、暂停或结算均可） |

目标：从起跑格出发，跑完 1 圈并第一个冲过青岚杯拱门。经过**发光箭头加速带**会获得 1.45s 冲刺；共 3 个加速带。冲线时第 1 名获胜，第 2/3 名失败，结算面板会给出用时、最高时速与冲刺次数。

## 画面与 HUD

- 第三人称追尾镜头，随速度拉 FOV，撞护栏/加速带会有轻微镜头反馈。
- 中文 HUD：圈数、名次、计时、FPS、小地图、圆形速度表、倒计时、暂停菜单、胜负结算。
- 低模玩具风：Tripo P2 卡丁车车体（玩家奶油/青绿、AI 珊瑚/奶油、金/藏蓝），程序化轮组/尾焰/旗子，Tripo H3.1 风车塔身 + 程序化旋转叶片，红白路肩、方格起跑线、青岚杯拱门、果树、雪山与气球。
- 1920×1080 截图（`docs/shots/`）：

| 起跑 | 追尾 | 加速带 |
| --- | --- | --- |
| ![](docs/shots/01_start_grid.png) | ![](docs/shots/02_chase_corner.png) | ![](docs/shots/03_boost_pad.png) |

| 暂停 | 航拍 | 冠军 |
| --- | --- | --- |
| ![](docs/shots/04_pause.png) | ![](docs/shots/05_circuit_aerial.png) | ![](docs/shots/06_finish_win.png) |

| 车辆特写 | 风车特写 |
| --- | --- |
| ![](docs/shots/07_kart_closeup.png) | ![](docs/shots/08_windmill_closeup.png) |

10 秒演示（1920×1080 / 30fps / H.264，4.6MB；真实 GPU 整圈录制后压缩到 10s）：  
[`docs/media/qinglan_cup_10s.mp4`](docs/media/qinglan_cup_10s.mp4)

> 录制时 HUD 的 FPS 标签被隐藏：逐帧 PNG 回读会让 `Engine` FPS 掉到个位数，那是采集开销，不是游戏性能。真实 1080p/720p 数据见下方性能项；正常游玩时 FPS 标签可见。

## 验收结果

环境：macOS + Intel HD Graphics 6000，OpenGL 4.1 Compatibility。

```bash
# 1) 无头核心逻辑 + Tripo 资产/回退节点检查
godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd
# 最后一行：AI_3D_GAME_SMOKE_OK checks=66

# 2) 整圈自动驾驶回放（验收用，不是默认玩法）
godot --headless --path godot-ai-3d-game -s tools/playtest_autopilot.gd
# AUTOPILOT_PLAYTEST_OK / 13.45s / 第 1 名

# 3) 1920×1080 真 GPU 截图（8 张）
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/screenshot_race.gd
# RACE_SHOTS_OK count=8

# 4) 1080p 性能（vsync 关，自动驾驶加压）
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd
# avg_fps=66.47 / p95=94.97 / 最低瞬时 39.39

# 5) 视频帧源 + 10s 成片
godot --path godot-ai-3d-game --resolution 1280x720 -s tools/capture_race_video.gd

# 6) Tripo GLB 结构/AABB 检查
godot --headless --path godot-ai-3d-game -s tools/inspect_tripo_assets.gd
```

实测完整单圈：自动驾驶（仅用于验收/录制，正常运行默认关闭）**13.45s** 完赛、3 次加速带、第 1 名；人类操作路径由 smoke 的输入测试覆盖。Tripo 资产替换前后完赛时间/距离/AI 名次一致（父任务 13.46s）。

## 玩法结构

```
RaceWorld (Node3D)
├── Track (328.5m 闭合 Catmull-Rom 环道 + 路面/路肩/护栏/拱门)
├── Player + 2 Rivals
├── 3 Boost Pads
├── Chase Camera
└── HUD (CanvasLayer)
```

状态机：`COUNTDOWN → RACING ⇄ PAUSED → FINISHED`。起跑格在终点线后 6m，比赛距离目标 = 328.5 + 6 = 334.5m。  
技术细节（赛道生成、AI、加速带、状态机、性能数据、Hyper3D/Tripo 差异）见 [`docs/TECH.md`](docs/TECH.md)。  
迭代过程见 [`docs/迭代记录.md`](docs/迭代记录.md)，许可与 AI 资产说明见 [`CREDITS.md`](CREDITS.md)。

## AI 资产管线说明（重要）

- 视频中 GPT-6/Codex 负责代码生成，Hyper3D Rodin MCP 负责图生 3D 车/场景资产。
- 本机没有 Hyper3D 访问；本任务沿用已登录的 Tripo CLI（`--profile cn`，经本地代理）完成图生 3D：
  - 卡丁车车体：P2-20260801，task `f7ef8737-d179-451a-b858-8ad024d14183`，18,857 tris，120 credits；
  - 风车塔身：H3.1 (v3.1-20260211)，task `cbdc4d8b-e6e1-43f9-9838-932b78f5c26d`，18,758 tris，40 credits。
- 合计 160 credits（余额 225 → 65）；参考图是当前 demo 程序化模型在真实 GPU 上的原创渲染，不是参考视频/原作素材。
- 卡丁车的车轮、转向、boost 尾焰、尾旗与 CC0 Fox 驾驶员仍由代码/资产驱动；风车叶片仍程序化旋转。GLB 缺失或加载失败时自动回退程序化几何。
- 同一张卡丁车贴图通过 `shaders/tripo_kart.gdshader` 的色块蒙版重新着成三套车队色，保留 3 车可读性。
- 任务 id、参数、credits、许可与已知 mesh 瑕疵见 `assets/ai/README.md`、`assets/ai/tripo/README.md` 与 `docs/TECH.md` 第 2 节。

## 已知限制

- 没有音效/音乐、手柄/触屏和设置菜单。
- AI 与玩家没有硬碰撞体；追尾或并排时可能视觉重叠。
- Tripo P2 车体是单个网格，车轮无法独立旋转，因此游戏内使用程序化轮组；车体有侧裙长条、尾翼支撑略碎等 AI 拓扑瑕疵。
- H3.1 风车屋顶纹理带烘焙明暗渐变；未做二次重拓扑。
- 未生成第三个 Tripo 道具/驾驶员：预算优先两个核心资产；驾驶员保留 CC0/CC-BY Fox + `Run` 动画。
- GLB 内嵌纹理在 Godot 导入时抽成同目录 `*_Color_*.jpg`，移动/发布资产时需与 GLB 一起保留。
- 中文依赖系统 CJK 字体；无 CJK 字体的机器上字形会回退。
