# T-20261125-002 · H3.1 真实感跑车替换 P2 卡丁车

- 线程：T-20261125-001（父）/ T-20261124-004（根）
- 角色：Game Engineer
- 日期：2026-11-25
- 目标：用 Tripo H3.1 生成原创无品牌真实感跑车，替换 P2 卡丁车车体；保留玩法/相机/状态机/加速带/AI/HUD 与程序化轮组动画；Tripo 预算 65，不超支。

## 相对父任务新增

- 新增 H3.1 跑车资产：task `856e0f6e-f6aa-49ff-bdd5-c056c3d662ff`，40 credits，源 94,256 tris → 集成 30,000 tris。
- 新增原创跑车参考图与 Blender 生成脚本：`tools/blender/realistic_car_refs.py`、`assets/ai/tripo/refs/realistic_car/`。
- 新增 PBR 车队色 shader：`shaders/tripo_car.gdshader`（亮度 + 饱和度蒙版，保留 ORM/法线/红尾灯/蓝玻璃）。
- 升级程序化轮组：20 边形轮胎 + 深色轮辋 + 银色轮圈/5 辐条 + 车队色轮心；轮距/轴距/半径按跑车轮拱重排。
- 新增本地降面脚本 `tools/blender/decimate_car.py`；smoke 66→**68** 项；截图 8→**9** 张；10s 视频重录。
- P2 卡丁车资产与 `shaders/tripo_kart.gdshader` 归档，不再运行时加载；程序化车身仍为缺图 fallback。

## Tripo 预算与方案

| 方案 | face_limit | texture | pbr | 交付 | dry-run credits |
| --- | ---: | --- | --- | --- | ---: |
| `--for game-pc` | 20,000 | detailed | false | FBX（含 convert） | 40 |
| `--for game-pc` | 50,000 | detailed | false | FBX（含 convert） | 40 |
| `--for game-pc` | 100,000 | detailed | false | FBX（含 convert） | 40 |
| 显式 PBR | 20,000 | detailed | true | GLB | 40 |
| 显式 PBR | 50,000 | detailed | true | GLB | 40 |
| 显式 PBR | 100,000 | detailed | true | GLB | 40 |
| 显式 PBR | 50,000 | standard | true | GLB | 30 |

- 余额 **65**；选择 **显式 100k + detailed + pbr=true = 40**（同价但比 game-pc 多了 PBR、且直接 GLB 不需要 FBX convert），结束余额 **25**。
- 实际消耗 40，无失败/退款/重试/额外 convert。
- 所有命令：`--profile cn`，`HTTPS_PROXY/HTTP_PROXY=http://127.0.0.1:7897`；key 只由已登录 CLI profile 读取，未入库/未打印。

## 参考图（原创）

- `tools/blender/realistic_car_refs.py`（Blender 3.4.1，Cycles CPU）从零建模：loft 车身、boolean 轮拱/座舱、扫掠风挡框、灯/镜/扩散器/排气/尾翼；无品牌、无真实车照片/车标。
- 输出：`assets/ai/tripo/refs/realistic_car/realistic_car_{3q,side,front,rear3q}.png` + `realistic_car_sheet.png`（2×2 多视图）。
- 刻意不画车轮（轮拱留空），游戏用程序化轮组。Tripo 只输入 `realistic_car_3q.png`。

## 关键参数

| 项 | 值 |
| --- | --- |
| 源 AABB | 1.0000 × 0.2749 × 0.5178m（长×高×宽，车头 +X） |
| 目标尺寸 | 3.25m 长 / 0.95m 高 / 1.80m 宽 |
| 缩放 | `(3.25, 3.4557, 3.4762)` |
| 朝向/偏移 | `rotation.y=+90°`（车头→游戏 -Z），offset `(0, 0.595, 0)`，车底离地 0.12m |
| 车轮 | r=0.345m，宽 0.24m；轮距 ±0.735m；轴距 ±0.95m；前轮 pivot 转向、spinner 滚动 |
| 驾驶员 | Fox 缩放 0.0078，`Run`，位置 `(0,0.80,0.42)`；围巾 `(0,1.10,0.64)`；方向盘 `(0,0.86,0.10)` |
| 车队色 | `shaders/tripo_car.gdshader`，亮度/饱和度蒙版；玩家奶油/青绿、AI 珊瑚/奶油、金/藏蓝 |
| 贴图 | Color/ORM/NormalGL 2048²（源 4096²），normal map 导入 |
| 降面 | Blender Decimate COLLAPSE ratio 0.3182，94,256 → 30,000 tris |

## 自测输出（真实运行）

```text
godot --headless --path godot-ai-3d-game --quit-after 600
  → EXIT=0；仅 TRACK_READY / AI_3D_GAME_READY / RACE_GO，无 SCRIPT ERROR

godot --path godot-ai-3d-game --resolution 1280x720 --quit-after 600
  → EXIT=0；无 SCRIPT ERROR

godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd
  → AI_3D_GAME_SMOKE_OK checks=68

godot --headless --path godot-ai-3d-game -s tools/playtest_autopilot.gd
  → AUTOPILOT_PLAYTEST_OK；13.45s；第 1 名；3 boost；
     player=334.5m；rivalA=275.2m；rivalB=281.9m

godot --path godot-ai-3d-game --resolution 1280x720 -s tools/screenshot_race.gd
  → RACE_SHOTS_OK count=9（1920×1080）

godot --path godot-ai-3d-game --resolution 1280x720 -s tools/perf_ai_3d_game.gd
  → run1 avg 62.34 / median 64.76 / p95 99.90 / min 3.26
  → run2 avg 57.11 / median 62.48 / p95 86.74 / min 1.94
  → 720p avg 65.11 / median 71.11 / min 1.92
  → PERF_WORST at≈1.3–1.5s, dist≈200m, worst 306–516ms

video：380 源帧 / 19.00s → docs/media/qinglan_cup_10s.mp4
  1920×1080 / 30fps / 10.000s / 300 帧 / 4.5MB
  capture finish 13.40s, 3 boost, 第 1 名

tripo balance --profile cn → {"balance":25,"frozen":0}
```

## 改动文件

- 代码：`scripts/kart_visual.gd`（H3.1 挂载、轮组、驾驶员/尾灯/尾焰位置、PBR 车队色）
- Shader：`shaders/tripo_car.gdshader`（新）；`shaders/tripo_kart.gdshader`（归档保留）
- 工具：`tools/blender/realistic_car_refs.py`、`tools/blender/decimate_car.py`（新）；`tools/inspect_tripo_assets.gd`、`tools/tripo_turntable.gd`、`tools/perf_ai_3d_game.gd`、`tools/screenshot_race.gd`、`tools/smoke_ai_3d_game.gd`
- 资产：`assets/ai/tripo/car/car.glb`、Color/ORM/NormalGL 贴图、`source.json`、`tripo_preview.png`；`assets/ai/tripo/refs/realistic_car/`
- 文档：`README.md`、`docs/TECH.md`、`docs/迭代记录.md`、`CREDITS.md`、`assets/ai/README.md`、`assets/ai/tripo/README.md`
- 媒体：`docs/shots/01–09`（07/09 新增）、`docs/media/qinglan_cup_10s.mp4`、`docs/shots/tripo_car_preview.png`

## 已知风险 / 未做

- 跑车源模型是单网格，车轮无法拆出独立旋转；参考图隐藏车轮，游戏用程序化轮组填补轮拱。车体轮拱边缘/后翼子板折线有轻微 AI 拓扑瑕疵。
- 30k decimate 后细节依赖 2048 PBR 贴图；未做手工重拓扑。
- 1080p 平均 57–62 FPS、720p 约 65 FPS，仍 >30；6 秒采样在 ~200m 有一次性 0.3–0.5s hitch，禁用 Tripo 车体后仍复现，判断为既有场景/引擎事件，但父任务未记录，保留为风险。
- 截图 HUD FPS 是 PNG 编码期间的瞬时值，不作为性能结论。
- P2 卡丁车归档保留，占仓库空间；如要清理需另立任务。
- Tripo 余额 25，不足以再做一次同档生成（40）；后续新增资产需充值或降档。
