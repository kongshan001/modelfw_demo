# 算法 Demo 索引：WFC / Steering / Flow Field / 程序化地图

> 2026-11-21 建立，2026-11-22 追加程序化地图 · Godot 4.6 / GL Compatibility · 四个独立可交互算法 Demo 的统一入口
> 原则：每个 Demo 有自己的 seed、场景、阵容与性能口径；**绝对 FPS 不可横向比较**。
> 选型一句话：**WFC 生成世界，Flow Field 给出全局方向，Steering 负责局部不撞。**

## 0. 先看这里

| Demo | 解决什么问题 | 核心原理 | 当前性能结论（各自口径） | 入口 |
| --- | --- | --- | --- | --- |
| **Flow Field**<br>流场寻路 | 大量单位共享一条到最近目标的最短路 | 多源 BFS 积分场 + 最陡下降流场 + 双线性采样 | T-011 默认 1000 体：**26.4 FPS @720 / 16.8 FPS @1080**（高负载；同轮 2.17×） | [README](../godot-flowfield/README.md) · [原理报告](../godot-flowfield/docs/TECHNICAL_PRINCIPLES.md) |
| **Steering**<br>转向行为实验场 | 少量/中等单位的实时转向、避障、成群 | 期望速度 − 当前速度 = 转向力；分离/对齐/聚合；三须避障 | 50/100/200 体 = **73.5 / 45.9 / 33.4 FPS**（本机另一会话） | [README](../godot-steering/README.md) · [TECH](../godot-steering/docs/TECH.md) |
| **WFC**<br>坍缩花园 | 生成满足局部约束的合法地图 | 候选叠加 + Shannon 熵 + 加权坍缩 + 约束传播 + 快照回溯 | 16×10：算法视图 **42.6 FPS** / 成品地图 **73.8 FPS**（本机另一会话） | [README](../godot-wfc/README.md) · [TECH](../godot-wfc/docs/TECH.md) |
| **程序化地图**<br>边境制图台 | 可玩的 BSP 地牢 + 有世界感的生物群系地图 | BSP + 生成树 + BFS/A*；三通道噪声 + 岛屿遮罩 + 河流 + Poisson + Voronoi | 生成中位 **17.5ms（地牢）/63.2ms（群岛）**；**93.7 / 76.7 / 123.3 FPS** @1280×720（群岛/全调试/地牢） | [README](../godot-proc-map/README.md) · [TECH](../godot-proc-map/docs/TECH.md) |

**只看一份**：[Flow Field 技术原理与工程实践](../godot-flowfield/docs/TECHNICAL_PRINCIPLES.md) §0 一页结论 + §2 选型对比；交互版见 [TECHNICAL_PRINCIPLES-交互版.html](../godot-flowfield/docs/TECHNICAL_PRINCIPLES-交互版.html)（单文件无外部依赖）。

---

## 1. Flow Field · 流场寻路（线程 T-20261121-009）

**形态**：36×24 / 48×32 网格，代价场 → 积分场 → 流场三视图；可编辑障碍与目标；200/500/1000 智能体；粉色单位 + 青色箭头 + 拖尾。

### 文档

| 文档 | 内容 |
| --- | --- |
| [README](../godot-flowfield/README.md) | 运行、操作、算法摘要、性能表 |
| [TECH](../godot-flowfield/docs/TECH.md) | 实现结构、数据结构、参数、测试、性能记录（§6.2 为 T-012 审计结论） |
| [迭代记录](../godot-flowfield/docs/迭代记录.md) | T-009 交付、T-011 复测、T-012 文档沉淀 |
| [**技术原理报告**](../godot-flowfield/docs/TECHNICAL_PRINCIPLES.md) | 结论先行 / 三算法对比 / Flow Field 深挖 / 性能因果链 / 工程方法 / 跨引擎移植 |
| [**交互版讲义**](../godot-flowfield/docs/TECHNICAL_PRINCIPLES-交互版.html) | 可编辑三视图 + 消融图表 + 预算计算器 + 移植检查清单（单文件） |

### 性能与原始数据

| 文件 | 内容 |
| --- | --- |
| [审计报告](../godot-flowfield/docs/perf/REPORT.md) | T-011：8 配置 × 5 轮 × 2 分辨率、P50/P95/P99、hitch、引擎计数、方法/局限 |
| [1280×720 CSV](../godot-flowfield/docs/perf/ablation_1280x720.csv) | 72 行：40 消融 + 20 五百对照 + 12 图层 |
| [1920×1080 CSV](../godot-flowfield/docs/perf/ablation_1920x1080.csv) | 40 行：8 配置 × 5 轮（离屏 SubViewport） |
| [runs_raw.json](../godot-flowfield/docs/perf/runs_raw.json) | 每轮统计 + 每帧帧时间（约 530 KB） |
| [ablation_chart.png](../godot-flowfield/docs/perf/ablation_chart.png) | FPS / P95 双面板，柱=中位、须=min–max |
| [环境日志](../godot-flowfield/docs/perf/env_log.txt) | load1 / thermal / OS / CPU |

### 可移植包（引擎无关）

| 文件 | 内容 |
| --- | --- |
| [flowfield_params.json](../godot-flowfield/docs/portable/flowfield_params.json) | 坐标/邻域/BFS/流场/模拟/渲染/审计参数 |
| [flowfield_sample_medium.json](../godot-flowfield/docs/portable/flowfield_sample_medium.json) | 36×24 C 形样例的 cost/integration/flow；835 可达、最大积分 31、单调坏格 0 |
| [manifest.json](../godot-flowfield/docs/portable/manifest.json) | sha256、坐标/单位/深度/时间/确定性契约、验收清单 |

### 媒体

| 文件 | 内容 |
| --- | --- |
| [01_flow_500.png](../godot-flowfield/docs/screenshots/01_flow_500.png) | 流场总览（C 形回廊 + 500 体 + 拖尾） |
| [02_integration_500.png](../godot-flowfield/docs/screenshots/02_integration_500.png) | 积分场热力色 + BFS 数值 |
| [03_cost_edit.png](../godot-flowfield/docs/screenshots/03_cost_edit.png) | 代价场 + 手绘障碍 |
| [04_flow_1000_large.png](../godot-flowfield/docs/screenshots/04_flow_1000_large.png) | 48×32 大地图 + 1000 体 |
| [05_random_goal_switch.png](../godot-flowfield/docs/screenshots/05_random_goal_switch.png) | 随机地图 + 目标切换 |
| [flowfield_demo.mp4](../godot-flowfield/docs/video/flowfield_demo.mp4) | 10 秒 / 30fps / 1920×1080 演示 |
| [flowfield-principles-flow.png](shots/flowfield-principles-flow.png) | 交互版三视图截图 |
| [flowfield-principles-ablation.png](shots/flowfield-principles-ablation.png) | 交互版消融图表截图 |

### 复现

```bash
cd godot-flowfield
godot --path . --headless -s tools/smoke_flowfield.gd     # FLOWFIELD_SMOKE_OK
godot --path . --headless --quit-after 600                # 0 ERROR
godot --path . --resolution 1280x720 -s tools/bench_flowfield.gd
bash tools/run_ablation.sh                                # T-011 审计级复测
```

---

## 2. Steering · 转向行为实验场（T-20261121-006）

**形态**：1600×900 世界，Seek/Flee/Arrive/Pursue/Evade/Wander + Separation/Alignment/Cohesion/Leader；三须射线避障；追逐/走廊/羊群预设；力/邻居/射线可视化。

### 文档与媒体

| 文件 | 内容 |
| --- | --- |
| [README](../godot-steering/README.md) | 运行、行为清单、操作、性能 |
| [TECH](../godot-steering/docs/TECH.md) | 视频取证、行为公式、力合成、三须避障、空间哈希、复杂度、与视频差异 |
| [迭代记录](../godot-steering/docs/迭代记录.md) | 从 20 步/秒到 33.4 FPS 的优化过程与真实缺陷 |
| [agency/T-20261121-006.md](../godot-steering/docs/agency/T-20261121-006.md) | 任务分派/验收记录 |
| [01_video_flow_1080p.png](../godot-steering/docs/screenshots/01_video_flow_1080p.png) | 参考视频同形态的流场 + 群体 |
| [02_ui_1080p.png](../godot-steering/docs/screenshots/02_ui_1080p.png) | 控制台 |
| [03_chase_1080p.png](../godot-steering/docs/screenshots/03_chase_1080p.png) | 追逐 |
| [04_corridor_1080p.png](../godot-steering/docs/screenshots/04_corridor_1080p.png) | 走廊拥堵 |
| [05_flock_1080p.png](../godot-steering/docs/screenshots/05_flock_1080p.png) | 羊群 |
| [06_closeup_1080p.png](../godot-steering/docs/screenshots/06_closeup_1080p.png) | 单位/力向量近景 |
| [steering_tour_10s.mp4](../godot-steering/docs/media/steering_tour_10s.mp4) / [GIF](../godot-steering/docs/media/steering_tour_10s.gif) | 10 秒演示 |

**性能** `[实测，2026-11-21 另一会话]`：50/100/200 体 = 73.5/45.9/33.4 FPS（1280×720，vsync off）；200 体单步 15.2 ms（headless）；200 体约 53 draw calls / 5,900 primitives。

**关键结论**：Steering 没有全局路径，C 形回廊会局部极小；它的价值在局部避让、到达减速、群体感与动态目标，和 Flow Field 组合时负责“怎么走”。

---

## 3. WFC · 坍缩花园（T-20261121-005）

**形态**：12×8 / 16×10 / 18×10 庭院地图；14 种原创瓦片；候选叠加、熵热力、波前、回溯红框、事件流；暂停/单步/调速/种子/视图；固定种子可复现。

### 文档与媒体

| 文件 | 内容 |
| --- | --- |
| [README](../godot-wfc/README.md) | 运行、操作、算法摘要、性能 |
| [TECH](../godot-wfc/docs/TECH.md) | 视频取证、瓦片/边接口、熵、传播、快照回溯、复杂度、渲染优化、与视频差异 |
| [迭代记录](../godot-wfc/docs/迭代记录.md) | 无断头石径设计、回溯预算、图集/掩码拼贴缓存、性能诊断 |
| [01_superposition_1920.png](../godot-wfc/docs/shots/01_superposition_1920.png) | 初始叠加态 |
| [02_wavefront_1920.png](../godot-wfc/docs/shots/02_wavefront_1920.png) | 约束传播波前 |
| [03_backtrack_1920.png](../godot-wfc/docs/shots/03_backtrack_1920.png) | 回溯 |
| [04_complete_algorithm_1920.png](../godot-wfc/docs/shots/04_complete_algorithm_1920.png) | 算法视图完成 |
| [05_finished_map_1920.png](../godot-wfc/docs/shots/05_finished_map_1920.png) | 成品地图 |
| [06_large_map_1920.png](../godot-wfc/docs/shots/06_large_map_1920.png) | 大图 |
| [wfc_garden.mp4](../godot-wfc/docs/wfc_garden.mp4) / [GIF](../godot-wfc/docs/wfc_garden.gif) | 10 秒演示 |

**性能** `[实测，2026-11-21 另一会话]`：16×10 / 20 步每秒，算法视图 avg 42.6 / min 38 FPS，成品地图 avg 73.8 / min 46 FPS；第一版候选直画仅 8–9 FPS，图集 + 掩码拼贴缓存后 62+ FPS。

**关键结论**：WFC 不是寻路，是约束满足生成；最坏仍可能指数回溯，工程上用回溯预算 + 确定性重开把病态种子变成有限时间重试。

---

## 4. 选型速查

| 你的问题 | 选择 | 原因 |
| --- | --- | --- |
| 生成一张合法地图/庭院/关卡 | **WFC** | 局部约束 + 熵坍缩 + 回溯 |
| 少量单位追逃、编队、群体感 | **Steering** | 力合成、邻域行为、三须避障 |
| 一大群单位绕静态迷宫去同一目标 | **Flow Field** | 一次建场，N 单位共享；全局单调 |
| 大群 + 自然避让 | **Flow Field + Steering** | 全局方向 + 局部分离/碰撞 |
| 加权地形（沼泽/道路） | Flow Field + **Dijkstra** | 流场输出不变，积分场换最短路算法 |
| 动态障碍很多 | Steering 局部避让，或增量更新流场 | 全量重建有峰值成本 |
| 超大世界 | 分层/多分辨率流场或 coarse-to-fine | 单层 BFS 的 V 太大 |

---

## 5. 怎么读（按目标）

- **5 分钟了解全貌**：本页 §0 + [原理报告 §0](../godot-flowfield/docs/TECHNICAL_PRINCIPLES.md#0-结论先行一页)。
- **理解 Flow Field 实现**：[TECH §2–§4](../godot-flowfield/docs/TECH.md) → `godot-flowfield/scripts/flow_field_grid.gd` → `flow_sim.gd` → `flow_view.gd`。
- **复现性能结论**：[perf/REPORT.md](../godot-flowfield/docs/perf/REPORT.md) + [原理报告 §4–§5](../godot-flowfield/docs/TECHNICAL_PRINCIPLES.md) + `tools/run_ablation.sh`。
- **移植到 Unity/Unreal/Three.js**：[原理报告 §6](../godot-flowfield/docs/TECHNICAL_PRINCIPLES.md) + [portable/](../godot-flowfield/docs/portable/)。
- **看视觉/演示**：各 Demo 的 screenshots 与 mp4；Flow Field 另有交互版 HTML。
- **做技术评审**：本页 §6 数据口径 + 原理报告 §4.8 测量局限。

---

## 6. 数据口径与限制

- **Flow Field**：T-011 的 5 轮审计是主证据；复测期间 load1 5.23–24.68、swap ≈4.3–4.5 GB，绝对 FPS 被压低。T-009 的 47.0 是较空机器单次，不可与 T-011 的 26.4 直接比较；WFC/Steering 的 FPS 来自各自另一会话，也不能与 Flow Field 混表。
- **同轮归一**：每轮内配置 FPS / 同轮 baseline FPS，抵消机器负载漂移；T-011 全开 2.17×（两档一致）。
- **指标**：平均 FPS 只作吞吐参考；主指标是 P50/P95/P99、hitch >33.3/50 ms、逻辑步长与逻辑预算、引擎 objects/primitives。
- **确定性**：三个 Demo 都用固定种子与固定遍历顺序；Flow Field smoke 验证同地图同目标积分/流场逐位相同、300 体 90 步偏差 0.000000 px。
- **可复现**：所有性能数字都能由各 Demo 的 `tools/` 脚本与固定 seed 复跑；不要只引用最好一轮。

---

## 7. 参考视频（仅研究引用，无素材复制）

| Demo | 参考 | 用途 | 访问日期 |
| --- | --- | --- | --- |
| Flow Field | [B 站 BV12bzZY2EfA](https://www.bilibili.com/video/BV12bzZY2EfA) | 流场视觉语言与 BFS/双线性讲解 | 2026-11-21 |
| Steering | [B 站 BV1yCqfYuEh1](https://www.bilibili.com/video/BV1yCqfYuEh1) | 转向行为清单、分离、三须避障 | 2026-11-21 |
| WFC | [B 站 BV1Br421M7Vm](https://www.bilibili.com/video/BV1Br421M7Vm) | 候选叠加、熵、约束传播、回溯 | 2026-11-21 |

三个工程的代码、场景、UI、瓦片、角色与特效均为原创；参考视频只用于算法与视觉语言研究，未复制画面或素材。详见各项目 `CREDITS.md`。

---

## 8. 任务线程

| 线程 | 任务 | 产物 |
| --- | --- | --- |
| WFC | T-20261121-005 | `godot-wfc/` |
| Steering | T-20261121-006 | `godot-steering/` |
| Flow Field | T-20261121-008（failed）→ T-20261121-009（交付）→ T-20261121-011（审计）→ T-20261121-012（原理/文档） | `godot-flowfield/` + `docs/perf/` + `docs/portable/` + 本索引 |
| 程序化地图 | T-20261121-020/T-040（调研）→ T-20261121-021（交付） | `godot-proc-map/` + `docs/godot-procgen-survey.md` |

> 本索引由 T-20261121-012 建立；新增算法 demo 时请在同一页追加，不复刻一套平行索引。


---

## 9. 程序化地图 · 边境制图台（T-20261121-021）

**形态**：同一种子/同一界面切换两条完整管线。**地牢 · BSP**：递归切分 → 房间 → 最近邻生成树 + 环路 → BFS 连通修复 → 最远点对起点/终点 → 火把/陈设；**群岛 · 噪声（Hero）**：海拔/湿度/温度 → 岛屿遮罩 → 8 类群系 → 陡降河流 → Bridson Poisson 植被 → 6 个 POI + Voronoi 区域。五个调试叠加（连通/房间·区域/群系/噪声/边界），阶段单步/连续/速度，种子/签名/子随机流，中文 HUD。

### 文档与媒体

| 文件 | 内容 |
| --- | --- |
| [README](../godot-proc-map/README.md) | 运行、操作、算法摘要、实测 |
| [TECH](../godot-proc-map/docs/TECH.md) | 参数、复杂度、网络/噪声/河流/Poisson 细节、自定义 16 向 terrain、跨引擎、差异与风险 |
| [迭代记录](../godot-proc-map/docs/迭代记录.md) | 视觉三轮、性能 160→62ms、1280 HUD 修复 |
| [01_biome_hero_1920.png](../godot-proc-map/docs/shots/01_biome_hero_1920.png) | 群岛 Hero |
| [02_biome_elevation_stage_1920.png](../godot-proc-map/docs/shots/02_biome_elevation_stage_1920.png) | 海拔阶段（单步） |
| [03_biome_debug_1920.png](../godot-proc-map/docs/shots/03_biome_debug_1920.png) | 群系 + 区域 + 连通 + 边界 |
| [04_biome_moisture_1920.png](../godot-proc-map/docs/shots/04_biome_moisture_1920.png) | 湿度场 |
| [05_dungeon_hero_1920.png](../godot-proc-map/docs/shots/05_dungeon_hero_1920.png) | 地牢 Hero |
| [06_dungeon_debug_1920.png](../godot-proc-map/docs/shots/06_dungeon_debug_1920.png) | BSP / 房间 / 连通 |
| [07_biome_closeup_1920.png](../godot-proc-map/docs/shots/07_biome_closeup_1920.png) | 群岛近景 |
| [proc_map_demo.mp4](../godot-proc-map/docs/proc_map_demo.mp4) / [GIF](../godot-proc-map/docs/proc_map_demo.gif) | 10 秒：Hero → BSP 调试 → 六阶段生成 → 同种子复现 → 近景 |

**性能** `[本机实测，2026-11-22，1280×720，vsync off]`：最终轮：群岛完成态 93.7 avg / 67 min，全调试 76.7 / 75，地牢完成态 123.3 / 78，群岛生成中 130.0 / 130 FPS；另一轮 97.3 / 94.0 / 131.3 / 122.5。生成中位（算法本体）：地牢 17.45ms、群岛 63.22ms；p95 24.67 / 74.21ms（100 群岛 + 40 地牢 seeds）。

**关键结论**：地图视觉上限主要来自**地形过渡、光照与标签层**，不是再加一种算法；自定义 16 向 terrain 解析器可以在运行时烘焙 TileSet 上实现与 Terrain 等价的边过渡，并支持多层 alpha；生成耗时必须把算法预算与 TileMapLayer 应用成本分开统计。

**许可**：全部代码/瓦片/UI 原创；未使用商业游戏截图、素材或品牌。见 [CREDITS](../godot-proc-map/CREDITS.md)。
