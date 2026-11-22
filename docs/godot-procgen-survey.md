# Godot 程序化地图生成：技术方案、案例与复刻 Brief

> 调研对象：**Godot 4.6**（本机实测 `4.6.stable.official.89cea1439`），目标平台 **GL Compatibility / 1280×720 / Intel HD Graphics 6000 30 FPS+**。
> 调研日期与原始 URL 访问日期：**2026-11-21**；**T-040 复核日期：2026-11-22**（复核结论见 §7.4，修正处已在正文标注）。
> 交互版：[godot-procgen-survey-交互版.html](godot-procgen-survey-交互版.html)（单文件、无外部依赖，含 CA / BSP / 噪声生物群系 3 个可交互演示）。
> 截图：[CA 洞穴](shots/godot-procgen-survey-ca.png) · [BSP 房间](shots/godot-procgen-survey-bsp.png) · [噪声生物群系](shots/godot-procgen-survey-biomes.png)（Chrome 150 headless 实测，2026-11-22）。
> 本文只做技术调研与实现 brief，不改任何游戏代码；案例只引用公开链接与文字结论，**不复制任何商业游戏画面、素材或关卡布局**。

---

## 0. 结论先行（一页）

| 问题 | 结论 |
| --- | --- |
| Godot 里做程序化地图有哪些主流方案？ | 可归为 4 族：**约束求解**（WFC / 图语法）、**空间划分**（BSP / 房间模板 / 黄金路径）、**随机生长**（CA / 醉汉漫步）、**场与采样**（Perlin/Simplex/FastNoiseLite / Voronoi / Poisson / L-System / Marching Squares/Cubes）。没有“唯一正确算法”，商业项目几乎都是**多种算法串联 + 后处理**。 |
| 哪些效果最好？ | **2D 瓦片地图**：`噪声生物群系 + TileSet Terrain 自动过渡 + 手工瓦片美术` 的视觉上限最高；`WFC` 适合做局部约束细节，但必须配全局连通/地标 pass。**3D**：`WFC 岛屿/城镇`（Bad North/Townscaper 路线）和 `体素 + Marching Cubes/Transvoxel`（godot_voxel）最强，但 3D 成本远高于 2D。 |
| 我们该复刻哪 2–3 个？ | **A. BSP 地牢 + TileSet Terrain 自动过渡**（最低风险，先做）；**B. FastNoiseLite + Poisson + Voronoi 生物群系地图**（视觉最好，第二做）；**C. CA 洞穴 + BSP 房间锚点 + WFC 细节层**（可选，复用已有 WFC demo，不建议重写 WFC）。 |
| 最容易被高估的方案？ | **纯 WFC**。WFC 只保证局部邻接，不保证全局连通、路径、锁钥或可玩性；大图回溯可能爆炸。Godot 社区插件多为 2D，3D 需自研。 |
| 最低成本的“看起来像商业游戏”做法？ | **把生成算法的钱花在美术与过渡上**：原创瓦片 + TileSet Terrain 的角/边/内角变体 + 统一的受限色板 + 装饰层。算法复杂度不是视觉上限，**瓦片接口和美术一致性**才是。 |
| 本轮绝对不要重复什么？ | 不再做纯 WFC 演示（已有 `godot-wfc/`）；不再做 CA/BSP/醉汉漫步的纯算法拆解（已有 `docs/procedural-generation-teardown.md` + `generators.py` + 交互 HTML）；不把 3D 海岛作为本任务主目标（T-20261121-022 已单独立项）。 |
| Godot 4.6 有什么“新”的程序化能力？ | 4.6 是**打磨/工作流版本**，没有新的 WFC/地形生成 API。程序化地图依赖的是 4.x 稳定栈：`TileMapLayer`（4.4 起替代废弃的 `TileMap`）、`TileSet` Terrains、`FastNoiseLite`、`AStarGrid2D`、`NavigationRegion2D`、`MultiMesh`、`SurfaceTool/ArrayMesh`、`Geometry2D`、`WorkerThreadPool`。4.6 的实用增量是**可旋转场景瓦片**（装饰/建筑朝向）和 GridMap 的 Bresenham 画线（编辑器效率）。 |
| GL Compatibility 能不能做？ | **2D 可以，且是低端机首选**；核心 3D 也可以。但 Compatibility **不支持 MSAA 2D、2D HDR、Compute Shader、RenderingDevice、SDFGI、SSR、体积雾、CompositorEffects**。所以：不要在 Compatibility 下走 GPU compute 的体素路线；CPU 生成 + TileMapLayer/ArrayMesh/MultiMesh 是主路径。 |

**三句话选型**

1. **要稳、要快、要可玩**：BSP/房间模板 + TileSet Terrain 自动过渡 + BFS 连通验证。
2. **要视觉、要“世界感”**：FastNoiseLite 多通道场 + 岛屿遮罩 + Poisson 植被/地标 + Voronoi 区域 + 河流。
3. **要约束美感/城镇细节**：WFC 只做“局部细节层”，全局结构、连通、锁钥用 BSP/图语法先定；不要指望 WFC 自己保证可玩。

**推荐执行顺序**

```text
A（1–2 天可出可玩 slice） → B（3–5 天出视觉 hero） → C（可选，复用 godot-wfc，避免重写）
```

---

## 1. 技术方案对比

> 成本是“工程复杂度 + 目标机上的生成耗时”的合称；实际耗时见 §2.4 的 Godot 4.6 本机微基准。
> “连通性”指算法是否**天然保证**可玩连通；大多数算法都需要 BFS/并查集验证或后处理。

| 方案 | 输入 → 输出 | 可控性 | 连通性 | 动态修改 | 典型成本 | 2D/3D | Godot 落地 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **WFC（tile / overlap）** | 瓦片集 + 邻接规则，或一张示例图 → 满足局部约束的瓦片网格 | 局部高、全局低；可用固定格/权重/负样本引导 | **不保证**；需 BFS、A* 连接、后处理 | 中；局部重解可能引发波前扩散/回溯 | 高；传播 O(N·候选)，最坏回溯指数级；16×10 可交互，大图要预算/重开 | 2D 强；3D 可但需自研/3D 瓦片 | 插件：AlexeyBond WFC（MIT）、Fast WFC（MIT，C++）；原生无 WFC 节点 |
| **元胞自动机洞穴（CA）** | 随机墙/地板 + 邻域规则 → 洞穴掩码 | 中；墙比例、阈值、迭代次数、边界规则 | **不保证**；4-5 规则通常较好，4-4 会碎；需 BFS + 走廊修复 | 易；局部改格后重跑几轮即可 | 低；O(W·H·I·8)；本机 128×96×5 约 96 ms（GDScript） | 2D/3D 都可 | 原生无节点；`PackedByteArray`/`Image` 自写；WorkerThreadPool 后台跑 |
| **BSP 房间 + 走廊** | 一个矩形 + 递归切分规则 → 房间矩形 + 走廊 | **高**；切分方向/最小叶/房间内缩/走廊宽度都可控 | **天然好**；房间由走廊图连接；仍需 BFS 验证 | 中；增删房间要重建局部走廊 | 低；O(R log R + 走廊)；本机 80×60 约 3.5 ms（含 BFS） | 2D 强；3D 可做分层 BSP | 原生无节点；`Rect2i` + 自写；TileMapLayer 绘制 |
| **醉汉漫步（Drunkard's Walk）** | 起点 + 步数/偏向 → 蜿蜒隧道/洞穴 | 低–中；步数、挖掘半径、偏向、边界回弹 | 通常连通，但可能困在小区域；需验证 | 易；继续走即可扩展 | 低；O(steps) | 2D/3D 都可 | 原生无节点；自写；适合做“支洞/连接”而非主结构 |
| **Voronoi 生物群系/多边形地图** | 种子点（Poisson/随机）+ 距离度量 → 多边形区域 | 中–高；点分布、权重、Lloyd 松弛、噪声扰动边界 | 区域邻接图天然连通；具体通行需图/路网 | 中；加点/删点要重建局部 | 中；Delaunay O(n log n)，暴力 O(n²) | 2D 强；3D 可用 3D Voronoi（少用） | 原生无 Delaunay；`Geometry2D` 做裁剪/合并；自写或第三方 |
| **Perlin/Simplex/FastNoiseLite 地形** | 种子 + 频率/分形/域扭曲 → 高度/湿度/温度场 | 中–高；频率、octave、lacunarity、gain、域扭曲、遮罩 | N/A（场本身）；陆地连通需阈值/遮罩/后处理 | 易；换种子/参数即变 | 低–中；O(W·H·通道)；本机 128×96×3 约 60 ms（逐像素 GDScript） | 2D/3D 都强 | **原生**：`FastNoiseLite`、`NoiseTexture2D`、`Noise.get_image()` |
| **Poisson Disk 采样** | 最小距离 r、边界、尝试次数 k → 均匀但不过密的点集 | 高；r 控制密度，k 控制质量 | N/A；用于植被/POI/出生点，不负责连通 | 易；增量加点 | 低；Bridson O(n) | 2D/3D 都可 | 原生无节点；自写 Bridson；`RandomNumberGenerator` |
| **L-System 河流/道路/植被** | 公理 + 重写规则 + 角度/步长 → 折线/分支结构 | 中–高；规则、角度、长度、随机扰动 | 河流需保证入海；道路需 A*/图连接 | 中；规则变则整体变 | 低–中；O(步数×符号数) | 2D/3D 都可 | 原生无节点；自写；`Line2D`/`Curve2D`/ArrayMesh |
| **Marching Squares 2D 轮廓** | 标量场/布尔网格 → 等值线/多边形轮廓 | 中；阈值、平滑、闭合处理 | N/A；适合洞穴/海岸/水域轮廓 | 易；改场后重算局部 | 中；O(W·H)；GDScript 需注意每格 16 case | 2D | 原生无节点；`Geometry2D` 做多边形清理/三角化 |
| **3D Marching Cubes/体素** | 3D 密度场 → 三角网格（+ 法线/UV） | 中–高；密度函数、阈值、LOD、材质 | 体素连通需额外验证；洞穴可能断开 | 中–难；改地形要重建 chunk | 高；GDScript 逐体素很慢；C++/GDExtension 才实用 | 3D | 插件 `godot_voxel`（MIT，4.6 有 v1.6）；原生 `SurfaceTool`/`ArrayMesh` 自写；Compatibility 无 compute |
| **图语法/任务图（graph grammar / mission graph）** | 房间/任务节点 + 重写规则 → 锁钥/循环/分支图 | **很高**；规则即设计意图 | **由构造保证**；可强制锁钥、环路、Boss 路径 | 中；改图后重映射空间 | 中；O(规则×图节点) | 2D/3D 抽象层 | 原生无节点；自写；可驱动 BSP/房间模板/场景拼接 |
| **房间模板/黄金路径（Spelunky / Gungeon 路线）** | 房间模板库 + 路径/连接口约束 → 可玩关卡 | **很高**；模板、连接口、难度预算 | **由路径先验保证**；模板必须匹配门 | 中；换模板/重排即可 | 中；O(房间数×模板数) | 2D/3D 都可 | 原生：`TileMapLayer` + 场景实例 + `set_pattern`；自写选择器 |

**读表要点**

- **“可控性”和“视觉惊喜”通常反向**：BSP/模板可控但容易“整齐”；CA/噪声惊喜但难保证可玩；WFC 在两者之间，但全局约束弱。
- **商业项目几乎不只用一种算法**：Caves of Qud 是“高层分段 + WFC 填充 + A* 连接 + 后处理”；Bad North 是“先保证路径/房屋可达，再 WFC 填岛”；Townscaper 是“3D WFC + 二次 WFC 生成庭院”。
- **连通性不是算法赠品**：除 BSP/图语法/模板外，CA、噪声、WFC、醉汉漫步都必须做 BFS/并查集验证，失败时修复或重开。
- **动态修改成本**：CA/噪声/醉汉漫步最便宜；BSP/Voronoi/WFC 中等；Marching Cubes 最贵（chunk 重建 + 碰撞/导航同步）。

---

## 2. Godot 4.6 落地细节

### 2.1 原生能力速查

| 能力 | API / 节点 | 程序化地图里的用法 | 必须注意 |
| --- | --- | --- | --- |
| **瓦片地图** | `TileMapLayer`（4.4+，替代废弃的 `TileMap`） | 每层一个节点；`set_cell(coords, source_id, atlas_coords, alternative_tile)` 批量写格 | 所有更新在帧末批量处理；需要立即读取/碰撞时调用 `update_internals()`；序列化坐标限 **16-bit signed（-32768..32767）**，超大世界要分块/偏移 |
| **自动过渡** | `TileSet` **Terrains**（Godot 4 的 autotile 替代品） | 给瓦片分配 terrain set/terrain，使用 `set_cells_terrain_connect(cells, terrain_set, terrain)` 或 `set_cells_terrain_path(path, ...)` 自动选角/边/内角 | 三种匹配模式：**Match Corners and Sides / Match Corners / Match Sides**；TileSet 必须准备所有需要的组合，否则结果不可预期；支持概率变体 |
| **噪声** | `FastNoiseLite`（Cellular/Perlin/Value/Simplex 等） | 高度、湿度、温度、洞穴密度、岛屿遮罩；`get_noise_2d/3d`、`get_image()`、`get_seamless_image()` | 值大多在 `[-1,1]`（部分 Cellular 可能 >1）；用固定 `seed`；批量生成优先 `get_image()` / `NoiseTexture2D`，逐像素 GDScript 调用有开销 |
| **噪声纹理** | `NoiseTexture2D` | 快速得到可平铺/法线/颜色渐变纹理；`color_ramp` 可直接做生物群系/高度色带 | 内部用 `Thread` 生成；`get_image()` 在完成前可能返回 `null`，要 `await texture.changed` |
| **确定性随机** | `RandomNumberGenerator`（PCG32） | 固定种子、独立随机流（布局/装饰/掉落）、`seed` + `state` 存档/回放 | `randomize()` 只用于“新一局”；同一 seed + 同一调用顺序才可复现；不要用全局 `randi()` 混入 |
| **网格寻路/连通验证** | `AStarGrid2D` | `region` + `update()`；`set_point_solid`/`fill_solid_region` 设障碍；`get_id_path` 验证房间/POI 可达；支持方形/六边形、对角线模式、JPS（`jumping_enabled`） | 改 region/cell/障碍后要重新 `update()`；随机墙太多时 `path_len` 可能为 0（正常，说明不连通）；适合验证，不适合每帧全量重建 |
| **导航** | `NavigationRegion2D` + `NavigationServer2D` | 由可行走多边形/瓦片生成导航区；`bake_navigation_polygon(true)` 默认在线程烘焙 | 导航不等于生成；生成后要重建/更新导航；动态障碍用 NavigationServer 局部更新，避免整图重烘 |
| **大量装饰** | `MultiMesh` / `MultiMeshInstance2D/3D` | 草、树、石头、粒子替身；一次 draw call 画数千实例 | 单个 MultiMesh 的实例不单独视锥剔除；自定义 AABB；每对象光源数量受限；Blend Shapes 不支持 |
| **程序化网格** | `SurfaceTool` / `ArrayMesh` | Marching Squares/Cubes、Voronoi 多边形、道路/河流带状网格 | `SurfaceTool` 书写方便；大批量/多线程构建优先 `ArrayMesh` 的数组接口；注意顺时针绕序；顶点属性格式在第一个顶点前确定 |
| **2D 几何** | `Geometry2D` | `merge_polygons`、`clip_polygons`、`intersect_polygons`、`offset_polygon`、`triangulate_polygon`、`is_point_in_polygon` | 用于 Voronoi 单元裁剪、岛屿轮廓、房间多边形、道路缓冲；复杂多边形先清理自交 |
| **后台生成** | `WorkerThreadPool` | `add_task` / `add_group_task` 跑 CA、噪声、WFC、BSP；完成后主线程应用 | **场景树不是线程安全的**；不要在 worker 里 `add_child`/改节点；用 `call_deferred` 回主线程；每个线程用独立 RNG/噪声实例 |
| **生成纹理** | `Image` + `ImageTexture` | 生成高度图、生物群系图、mask、调试热力图 | `Image.create` 后 `set_pixel` 逐像素较慢；大图用 `PackedByteArray` + `Image.create_from_data` 更快 |

**4.6 版本说明**

- `TileMapLayer` 不是 4.6 新加的，而是 **4.4** 引入、`TileMap` 废弃后的现行 API；4.6 继续沿用。
- 4.6 与程序化地图直接相关的增量：**可旋转的场景瓦片**（90° 步进，适合建筑/装饰朝向）、**GridMap 的 Bresenham 画线**（编辑器画格子更顺）、Jolt 成为新 3D 项目默认物理、SSR/IK 等渲染/动画改进。它们改善工作流，不改变“地图生成算法”本身。
- 不要为了“4.6 新特性”去重写 `TileMapLayer` 流程；把精力放在瓦片接口、连通验证和美术一致性上。

### 2.2 原生 / 插件 / 非 Godot 可移植

| 需求 | Godot 原生 | 推荐插件（许可） | 非 Godot 可移植参考 |
| --- | --- | --- | --- |
| WFC 2D | 无 | **AlexeyBond/godot-constraint-solving**（MIT；TileMapLayer/GridMap；回溯、多线程、从示例学规则；无 3D/全局路径约束）；**Fast WFC**（MIT；C++ 版 mxgmn WFC；tiling + overlapping）；**Rayogenesis WFC**（MIT；overlap；Godot 4.3；体量小） | **mxgmn/WaveFunctionCollapse**（MIT 代码；示例图片/瓦片不随软件授权） |
| 体素/3D 地形 | `SurfaceTool`/`ArrayMesh` 可自写；无内置 MC | **Zylann/godot_voxel**（MIT；C++ module/GDExtension；v1.6 对应 Godot 4.6；blocky + Transvoxel LOD；无限分页）；**Terrain3D**（MIT；高度场，不是体素；Godot 4.5–4.8+；适合程序化高度图渲染） | SebLague/Godot-Marching-Cubes（MIT；**compute shader**，Compatibility 不可用，只适合 Forward+/Mobile 学习） |
| 地牢 | 无 | **GenMap Lite**（MIT；Godot 4.3；48×48；TileMapLayer + TileSet；房间可达；worker thread + 批量绘制） | TinyKeep 风格 BSP/房间分离；Unexplored 的 cyclic graph |
| 噪声/CA/BSP/Voronoi/Poisson | 全部可用 GDScript/C# 自写；`FastNoiseLite`、`Geometry2D`、`RandomNumberGenerator` 原生 | 一般不需要插件；用 WorkerThreadPool + PackedByteArray | 算法本身可移植；不要复制无权代码 |
| 寻路/导航 | `AStarGrid2D`、`NavigationRegion2D`、`NavigationServer2D` | 无 | A*/JPS/流场可移植；Godot 已原生 |

**许可风险提醒**

- `loothammer/godot_2D_procedural_dungeon_gen` **没有 LICENSE 文件，但 README 声明 MIT**（GitHub license API 返回 404）；`Peatral/Godot-Map-Generator` **没有许可证文件**（README 也无声明）。保守处理：只读思路，不复制代码/资产；如确需复用 loothammer，先记录 README 声明并自行做合规判断。
- mxgmn WFC 的 **代码是 MIT，但示例图片和瓦片“不属于软件授权范围”**；不能把 `samples/*.png` 直接放进仓库。
- Kenney 资产通常是 CC0，但仍应在 `CREDITS.md` 记录来源；商业游戏截图/瓦片一律不能用。

### 2.3 GL Compatibility 的限制（对程序化地图意味着什么）

官方 Renderers 功能表（4.6）关键结论：

| 能力 | Compatibility | 对生成方案的影响 |
| --- | --- | --- |
| 2D 渲染 | ✅ 支持 | 2D TileMapLayer/CanvasItem 路线可行 |
| 核心 3D | ✅ 支持 | ArrayMesh/MultiMesh/基础材质可行 |
| 高级渲染 | ❌ 不支持 | 不要依赖 SDFGI/SSR/体积雾等做“效果” |
| **MSAA 2D** | ❌ 不支持 | 2D 边缘锯齿用 SSAA/纹理/像素对齐解决，别配 MSAA |
| **2D HDR Viewport** | ❌ 不支持 | 2D 泛光/HDR 调色要另想办法或降低预期 |
| **Compute Shader / RenderingDevice** | ❌ 不支持 | **GPU Marching Cubes / GPU 噪声 / GPU WFC 不可用**；CPU 生成 + 上传网格 |
| SDFGI / SSR / SSIL / Volumetric Fog | ❌ 不支持 | 3D 场景靠烘焙/简单光照/雾效近似 |
| SSAO | ✅ 支持 | 可用，但低端机要测 |
| SSAA | ✅ 支持 | 2D 抗锯齿的可行替代 |
| CompositorEffects | ❌ 不支持 | 自定义后处理用全屏 quad，不能用 Compositor |
| 渲染成本 | 低基础成本、高扩展成本 | 控制 draw call/材质切换/过度绘制；瓦片图集、MultiMesh、分块 |

**目标机预算（1280×720 / 30 FPS = 33.3 ms/帧）**

- 生成阶段：交互式“步进演示”每帧只做**一个阶段/一小批格**，单帧逻辑 ≤ 8–16 ms；完整生成放 WorkerThreadPool，主线程只做应用。
- 渲染阶段：TileMapLayer 批量绘制；装饰用 MultiMesh；一张图集/少量材质；避免每格一个 Node2D/Sprite。
- 本机微基准：4800 格 `set_cell` 中位约 **4.5 ms**；AStarGrid2D 96×72 约 **3.5 ms**；BSP 约 **3.5 ms**；CA 128×96×5 约 **96 ms**（必须后台/降尺寸）；噪声 128×96×3 通道约 **60 ms**（后台/降尺寸/用纹理）。

### 2.4 本机 Godot 4.6 微基准（可复现口径）

**环境**：MacBook Air 2015 · Intel HD Graphics 6000 · macOS · Godot `4.6.stable.official.89cea1439` · `--headless` · GL Compatibility 项目设置。20 次采样，去掉 3 次预热，取中位数；单位为毫秒。脚本为临时 GDScript 基准（不进入游戏代码）。

| 基准 | 规模/参数 | 中位 | 最小 | 最大 | 说明 |
| --- | --- | ---: | ---: | ---: | --- |
| CA 洞穴 | 128×96，45% 初始墙，4-5 规则，5 次迭代 + BFS | **96.1 ms** | 64.6 | 260.3 | 纯 GDScript 逐格；64×48 约 1/4 体量，约 20–30 ms |
| BSP 房间+走廊 | 80×60，最大深度 5，最小叶 8，L 走廊 + BFS | **3.5 ms** | 2.0 | 22.8 | 生成本体 <1 ms；BFS 验证占大头但仍很快 |
| 噪声三通道 | 128×96，Simplex/Simplex/Perlin + 岛屿遮罩 + 分类 | **60.4 ms** | 30.6 | 158.9 | 逐像素 `get_noise_2d`；后台线程或降分辨率更稳 |
| 噪声纹理路径 | 同上，`Noise.get_image()` 三次 + 字节分类 | 129.3 ms | 38.9 | 210.3 | 中位反而更慢（分配/归一化/GC 波动）；**优势是异步/不占主线程** |
| TileMapLayer 写格 | 80×60 = 4800 格，`set_cell` + `update_internals()` | **4.5 ms** | 2.9 | 108.0 | 帧末批量；首次/GC 峰值明显 |
| AStarGrid2D | 96×72，约 23% 实心，1 次路径查询 | **3.5 ms** | 2.0 | 48.7 | 首次较慢；随机墙过多时无路径（`path_len=0`） |

**结论**

- **BSP/模板**可以在一帧内生成并立即绘制；**CA/噪声**应放后台或降低分辨率；**TileMapLayer 写入**很便宜，真正的成本在算法与验证。
- 这些是 **CPU/GDScript** 数据，不是 GPU 帧率；GL Compatibility 的 2D 渲染在 1280×720 下通常远快于生成本身。验收时要分别测**生成耗时**与**播放 FPS**。
- 机器负载、GC、首次调用会显著影响 max；报告用中位数 + P95，不要只报最好一轮。

---

## 3. 优秀效果案例（可查证）

> 证据等级：**官方** = 开发者/引擎官方页面；**媒体** = 可信媒体报道/开发者访谈；**推断** = 没有公开算法细节，只根据画面/玩法做的技术推断，不可当事实引用。
> 所有商业游戏的许可均为**版权保留**，只能研究思路，**不能复制素材/画面/关卡**。

### 3.1 Godot 已发布游戏

| 案例 | 引擎 / 世代 | 是否程序化地图 | 技术证据（等级） | 视觉亮点 | 性能 / 规模 | 许可 | URL（访问 2026-11-21） |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Dome Keeper**（Bippinbits / Raw Fury） | **Godot 3 → Godot 4**（2024 “A Keeper's Duty”；RPS 原文 “moving from godot 3 to 4”；具体 3.x 小版本/GodotSteam 分支本次未核实） | **是**：RPS 报道升级后 “better map generation”，地图形状/尺寸更多、出现新结构；具体算法未公开 | RPS 报道（**媒体**，直接引述引擎升级与地图生成改进）+ Steam 更新公告（**官方**，本次未取到正文）；**推断**：多 pass 形状生成 + 规则/噪声 + 手工调参 | 可破坏矿井 + 穹顶防守；挖掘/资源/怪物波次的强反馈；像素风统一 | 地图规模/算法未公开；商业 2D，低端机友好 | 商业，版权保留 | [Godot Showcase](https://godotengine.org/showcase/dome-keeper/) · [RPS](https://www.rockpapershotgun.com/dome-keeper-just-got-a-massive-update-that-ups-replayability-and-helps-generate-better-worlds) · [Steam 公告](https://steamcommunity.com/games/1637320/announcements/detail/4396159337027279925) |
| **Lumencraft**（2Dynamic Games） | **Godot 3**（开发者访谈时；访谈称未来会考虑 Godot 4，本次未核实现状） | **是**：程序化生成地图（Steam 商店页明确 “procedurally generated maps/levels”）+ 全可破坏地形 | Godot 开发者访谈（**官方**）：Godot 3、完全可破坏地形、流体模拟、动态光照；Steam 商店页（**官方**）：procedurally generated maps/levels；具体生成算法未公开（**推断**：CA/噪声 + 自定义可破坏地形） | 黑暗中的挖掘/照明/塔防；像素级破坏与光照；地下洞穴氛围 | 大规模可破坏地下地图；商业 2D | 商业，版权保留 | [Godot Showcase](https://godotengine.org/showcase/lumencraft/) · [开发者访谈](https://godotengine.org/article/godot-showcase-2dynamic-games-lumencraft/) · [Steam](https://store.steampowered.com/app/1713810/) |
| **Cassette Beasts**（Bytten Studio） | **Godot**（技术博客确认；3.5 为社区常见版本说法，本次未逐条核实） | **否（主世界手工）**：16×8 个 32×32 瓦片 chunk 的 GridMap 手工世界（**官方技术博客**） | 开发者技术博客 “Technical Look: The Park”（**官方**，原文现 404，经 Wayback 存档核实）：GridMap + chunk 流式加载；无自动瓦片，角/过渡手工摆 | 2.5D 像素开放世界；固定相机 + 网格地形；手工节奏 | 16×8×32×32 = **131,072 瓦片**；chunk 加载降低内存/CPU | 商业，版权保留 | [Godot Showcase](https://godotengine.org/showcase/cassette-beasts/) · [技术博客（Wayback 存档）](https://web.archive.org/web/20210809140543/https://www.cassettebeasts.com/2021/08/09/technical-look-the-park/) |
| **Brotato**（Blobfish） | **Godot 3.5**（teemo.dev 系统拆解确认） | **否**：固定竞技场；随机的是敌人波次、商店、掉落 | Godot Showcase（**官方**）+ teemo.dev 系统拆解（**媒体**，明确 “twenty-wave arena roguelite on constants that never move”）；无程序化地图证据 | 固定竞技场让战斗/走位可控；武器/道具组合是视觉与玩法主角 | 20 波、场上敌人上限约 100；商业 2D | 商业，版权保留 | [Godot Showcase](https://godotengine.org/showcase/brotato/) · [系统拆解](https://teemo.dev/game-design/brotato/design/overview-notes/) |
| **Road to Vostok**（Antti Leinonen） | **Godot**（2023 从 Unity 迁移，Wikipedia 确认；具体 4.x 版本未公开确认） | **未证实（推断非程序化）**：Wikipedia 确认 EA 有 **9 张地图 / 3 个区域**；是否手工未在本次来源明确；动态事件/巡逻/天气为推断 | Wikipedia（**媒体**）：9 maps、3 regions、引擎迁移；Steam 更新（**官方**）：EA 信息；没有程序化地图证据 | 硬核生存 FPS；真实芬兰/俄罗斯边境氛围；分区推进 + permadeath | 分区地图；EA 2026-04-07 | 商业，版权保留 | [Wikipedia](https://en.wikipedia.org/wiki/Road_to_Vostok) · [Steam 更新](https://store.steampowered.com/news/app/1963610) |
| **ΔV: Rings of Saturn**（Kodera Software） | **Godot**（世代未在本次来源中确认） | **未证实**：Showcase/Steam 均未说明小行星带是否程序化生成；没有“程序化地图”公开证据（**推断**：岩体/矿点可能程序化） | Godot Showcase（**官方**）确认引擎；Steam 商店页（**官方**）确认玩法；生成方式未公开 | 硬科幻小行星采矿；真实物理/碰撞 | 商业 2D；规模/性能未公开 | 商业，版权保留 | [Godot Showcase](https://godotengine.org/showcase/delta-v-rings-of-saturn/) · [Steam](https://store.steampowered.com/app/846030/) |

**核实结论（很重要）**

- **Dome Keeper、Lumencraft** 是少数可确认“Godot + 程序化地图”的商业案例（RPS / Steam 商店页）；但两者都**没有公开算法**，只能作为视觉/产品参考，不能把“它们用了 WFC/CA”当事实。
- **Cassette Beasts、Brotato** 常被误认为“Godot 程序化地图案例”；本次核实分别是 **手工 GridMap 世界**（官方技术博客，Wayback 存档）与 **固定竞技场**（teemo.dev 拆解，明确 “constants that never move”）。**Road to Vostok** 只有 Wikipedia 的“9 张地图 / 3 区域”记录，是否手工/程序化**未获公开证据**（推断：非程序化）；**ΔV** 的 Showcase/Steam 页面也没有生成方式说明（推断，不计入“程序化地图案例”）。
- **Godot 官方 Showcase 能证明“引擎”**，不能证明“程序化”；技术判断必须另找开发者访谈、技术博客或更新公告。本次复核把无直接证据的细节改为“未证实/推断”。

### 3.2 Godot 开源项目 / 插件

| 项目 | 类型 | 技术 / 规模 | Godot 版本 | 许可 | 适合复刻？ | URL（访问 2026-11-21） |
| --- | --- | --- | --- | --- | --- | --- |
| **Zylann/godot_voxel** | C++ module / GDExtension | 3D 体素：blocky + smooth（Transvoxel LOD）、无限分页、物理、植被实例化、自定义生成器 | Godot 4；**v1.6 明确对应 4.6**（v1.7 对应 4.7） | **MIT** | ✅ 3D 体素首选；但需要编译/扩展，不是纯 GDScript | [GitHub](https://github.com/Zylann/godot_voxel) · [v1.6 Release](https://github.com/Zylann/godot_voxel/releases/tag/v1.6) |
| **TokisanGames/Terrain3D** | C++ GDExtension | 高度场地形：64×64 m–65.5×65.5 km、32 纹理、10 LOD、植被、孔洞/雕刻 | Godot 4.5–4.8+（v1.1.0） | **MIT** | ✅ 程序化高度图渲染；不是体素，不适合悬垂洞穴 | [GitHub](https://github.com/TokisanGames/Terrain3D) · [Release](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.1.0-stable) |
| **AlexeyBond/godot-constraint-solving** | GDScript 插件 | 2D WFC/通用 CSP：回溯、多线程、从示例学规则、TileMapLayer/TileMap/GridMap、概率；无 3D/全局路径约束 | Godot 4（Asset 1.7 标注 4.3；4.6 未显式声明） | **MIT** | ✅ 2D WFC 首选之一；适合做“细节层” | [GitHub](https://github.com/AlexeyBond/godot-constraint-solving) · [Asset 1951](https://godotengine.org/asset-library/asset/1951) |
| **AliasFactory/Godot_Fast_WFC** | C++ 插件（GDExtension） | mxgmn WFC 的 C++ 移植；tiling + overlapping；自带 demo | Asset 标注 **4.4**（4.6 未显式声明） | **MIT** | ✅ 追求速度的 2D WFC；需实测 4.6 | [GitHub](https://github.com/AliasFactory/Godot_Fast_WFC) · [Asset 4149](https://godotengine.org/asset-library/asset/4149) |
| **Rayogenesis/WaveFunctionCollapse-GodotAddon** | GDScript 插件 | 忠实 overlap WFC；`WFCGenerator2D`；TileMapLayer；旋转/反射；回溯 | Godot **4.3** | **MIT** | ⚠️ 学习/小项目；体量小，长期维护未知 | [GitHub](https://github.com/Rayogenesis/WaveFunctionCollapse-GodotAddon) |
| **GenMap Lite** | GDScript 插件 | 一键地牢：TileMapLayer + TileSet、碰撞/导航、房间 Area2D、可达性、worker thread + 批量绘制；上限 48×48 | Asset 标注 **4.3** | **MIT** | ✅ 快速原型/对照实现；Lite 有尺寸限制 | [Asset 5546](https://godotengine.org/asset-library/asset/5546) |
| **loothammer/godot_2D_procedural_dungeon_gen** | GDScript 示例 | 80×80、最多 10 房间、L 走廊、TileMapLayer | Godot 4 | **README 声明 MIT（无 LICENSE 文件）** | ⚠️ 可参考；复用前自行确认合规，保守只读 | [GitHub](https://github.com/loothammer/godot_2D_procedural_dungeon_gen) |
| **Peatral/Godot-Map-Generator** | GDScript + C++ GDExtension | Voronoi 区域、岛屿、海拔、河流、湿度、生物群系；Poisson + Delaunator | Godot 4（2023 项目） | **无许可证** | ⚠️ 只读思路，不能复制代码 | [GitHub](https://github.com/Peatral/Godot-Map-Generator) |
| **SebLague/Godot-Marching-Cubes** | 学习项目 | Godot 4 **compute shader** Marching Cubes | Godot 4 | **MIT** | ❌ 不适合 GL Compatibility（无 compute）；可看算法 | [GitHub](https://github.com/SebLague/Godot-Marching-Cubes) |
| **Godot 官方 Demo** | 官方示例 | AStarGrid2D（Asset 2723，Compatibility）、Dynamic TileMap Layers（2713）、Hex（2717） | 4.2 标注，4.x 可迁移 | **MIT** | ✅ 原生 API 学习/验收 | [AStarGrid2D Demo](https://godotengine.org/asset-library/asset/2723) · [Dynamic TileMap Layers](https://godotengine.org/asset-library/asset/2713) |

### 3.3 非 Godot 但可移植的案例（单独标注）

| 案例 | 引擎 | 技术（证据等级） | 可移植教训 | 许可 | URL（访问 2026-11-21） |
| --- | --- | --- | --- | --- | --- |
| **Noita**（Nolla Games） | **自研 Falling Everything**（C++） | 每个像素都是物理模拟材质；复杂元胞自动机（**官方/媒体**） | “像素级 CA + 材质反应”是视觉奇观，但性能/设计成本极高；2D 我们只建议用**粗网格 CA** 做洞穴，不做全像素模拟 | 商业 | [官网](https://noitagame.com/) · [Press Kit](https://noitagame.com/press/) |
| **Caves of Qud**（Freehold Games） | **Unity**（Unity 官方案例 + Steam FAQ 可证） | 多 pass：高层结构 → **WFC（texture mode，3×3 图案，8×8/16×16 训练图）** → A* 连接 → 门/家具/怪物后处理；大图分段 WFC（**GDC 2019 演讲**） | **不要把 WFC 当全局生成器**：分段、先结构后细节、A* 修连通；这是最值得抄的工程流程（不是代码） | 商业 | [Unity 案例](https://unity.com/resources/systems-driven-design-in-caves-of-qud) · [GDC 演讲条目](https://gdcvault.com/browse/gdc-19/play/1026263) |
| **Bad North**（Plausible Concept / Raw Fury） | 非 Godot（Unity 为社区常见说法，本次未逐条核实） | 3D 岛屿 WFC，手工瓦片模块；**先保证房屋/路径可达，再 WFC 填充**；离线生成，失败可整局重开（**Oskar Stålberg 2018 演讲**） | “路径优先 + WFC 细节 + 失败重开”非常适合离线生成；Godot 里用 A*Grid/BFS 先验 + WFC 插件填充 | 商业 | [演讲视频](https://www.youtube.com/watch?v=0bcZb-SsnrA) · [80.lv 介绍](https://80.lv/articles/using-wave-function-collapse-algorithm-for-dioramas) |
| **Townscaper**（Oskar Stålberg） | 非 Godot（引擎未在本次来源核实） | 3D/不规则网格约束求解（常被描述为 WFC 思路）；二次 WFC 生成庭院；六边形/变形网格（**SGC21 “Beyond Townscapers”**） | “不规则网格 + 约束求解 + 二次 pass”能消除方块感；Godot 2D 可用变形六边形/噪声扰动边界借鉴 | 商业 | [演讲](https://www.youtube.com/watch?v=Uxeo9c-PX-w) · [可玩网页版](https://oskarstalberg.com/Townscaper/) |
| **Unexplored**（Ludomicro / Joris Dormans） | 非 Godot（自研/Ludoscope 工具链） | **Cyclic dungeon generation**：图重写规则生成环路/锁钥，而非树状分支；关卡用 tilemap 表示（**论文/演讲**） | 图语法先定“任务/锁钥/环路”，再把节点映射到空间；Godot 可用自定义 Resource/Graph 实现 | 商业 | [Cyclic Generation 章节](https://www.taylorfrancis.com/chapters/edit/10.1201/9781315156378-11/cyclic-generation-joris-dormans) · [演讲](https://www.youtube.com/watch?v=mA6PacEZX9M) |
| **Spelunky / Enter the Gungeon** | 非 Godot（GameMaker / Unity） | Spelunky：4×4 房间网格 + 只允许左/右/下的黄金路径 + 房间模板；Gungeon：手工房间池 + 分类选房（**开发者演讲/书籍**；本仓库已有视频拆解） | “先保证路径，再填内容”是最稳的可玩性策略；Godot 用场景模板 + 连接口匹配即可 | 商业 | 见仓库 [procedural-generation-teardown.md](procedural-generation-teardown.md) 与其中引用的原始视频/书籍 |

### 3.4 案例给我们的 6 条结论

1. **商业上的“程序化地图”几乎都是混合管线**：结构（BSP/图/模板）→ 细节（WFC/噪声）→ 连通修复（A*/BFS）→ 装饰/POI。单一算法只存在于教学 demo。
2. **视觉记忆点来自美术与反馈，不来自算法名字**：Dome Keeper 的挖掘反馈、Lumencraft 的黑暗与破坏、Cassette Beasts 的手工像素世界，都比“用了什么算法”更重要。
3. **WFC 的正确位置是“局部细节层”**：Caves of Qud 分段 WFC + A* 连接；Bad North 先路径后 WFC；Townscaper 二次 WFC。不要用它保证全局可玩性。
4. **Godot 商业案例的算法细节普遍不公开**：把“推断”标出来，避免把社区猜测写成事实。
5. **低端机/GL Compatibility 下，2D 是绝对优势区**；3D 体素必须用 C++/GDExtension，且不能依赖 compute。
6. **许可边界要前置**：商业游戏只研究；无许可证/无 LICENSE 文件的仓库只读；WFC 示例图不能直接入库；原创/CC0 资产要写 `CREDITS.md`。

---

## 4. 与仓库现状对照

| 现有资产 | 已经覆盖 | 可复用 | 本轮应避免 |
| --- | --- | --- | --- |
| `godot-wfc/` | 2D WFC 完整交互：候选叠加、Shannon 熵、加权坍缩、约束传播、快照回溯、确定性重开；14 种原创庭院瓦片；算法视图/成品地图；16×10 默认档实测算法视图 avg 42.6 / min 38 FPS，成品地图 avg 73.8 / min 46 FPS | `scripts/wfc_solver.gd` 的掩码/熵/传播/回溯；`wfc_tileset.gd` 的边接口/权重；`tile_baker.gd` 的图集烘焙；`board_view.gd` 的波前/热力/调试表达；`hud.gd` 的中文控制台模式 | **不要重写一个纯 WFC demo**；不要重复“候选叠加/熵/回溯”的教学演示；不要把 14 种庭院瓦片直接当新项目美术 |
| `docs/procedural-generation-teardown.md` + `docs/procedural-generation-demos/generators.py` | CA 4-5 规则、Spelunky 黄金路径、BSP、醉汉漫步；确定性 XorShift32；21 seeds 连通性验证；参数/坑/修复 | CA 参数（45% 墙、keep 4、become 5、4–6 次迭代；4/4 变体 + 走廊修复）；BSP 递归切分/房间内缩/L 走廊；BFS/最远点；种子签名思路 | **不要重复四种算法的纯拆解**；不要再做“算法视频复刻”；把参数迁移到“带美术/自动瓦片/性能预算”的可玩 slice |
| `godot-flowfield/` | 流场寻路完整 demo：代价场 → 积分场（8 邻接 BFS）→ 流场方向；24×16/36×24/48×32 地图、200/500/1000 智能体、三视图、可编辑地图、固定种子可复现；1000 智能体实测平均 47 FPS | 多源 BFS/积分场/双线性流场采样、固定邻域顺序的确定性、空间哈希分离力、批量绘制、`tools/smoke_flowfield.gd` 冒烟模式 | **不要重做流场/避障 demo**；不要把“寻路”当“地图生成”；T-021 的 A/B brief 只需 AStarGrid2D/BFS 做连通验证，不需要整套流场；若后续同屏敌人很多，再复用流场移动层 |
| `docs/procedural-generation-teardown-交互版.html` | 既有讲义设计系统：深/浅色 token、卡片、表格、demo 面板、控件、FAB、进度条、复制按钮 | 直接复用 CSS 变量与组件类名（`--paper/--ink/--gold/--teal`、`.card`、`.tablewrap`、`.demo`、`.controls`、`.metrics` 等） | 不要复制旧页面的正文/图表；新页面只复用设计系统，内容全部重写 |
| `docs/shots/` | 既有截图命名与尺寸习惯 | 新截图放 `docs/shots/godot-procgen-survey-*.png` | 不要覆盖旧截图；不要放商业游戏画面 |
| T-20261121-022（3D 海岛调研） | 已单独立项，聚焦高度场/岛屿遮罩/噪声/侵蚀/网格/水面/植被/LOD | 本报告的 FastNoiseLite、岛屿遮罩、Poisson、LOD/分块结论可被 T-022 复用 | **本任务不做 3D 海岛实现**；不要把 3D 体素作为本轮主目标 |

**本轮定位**

> 不是“再做一个算法 demo”，而是**把已有算法资产变成可落地的地图生产管线**：BSP/噪声负责结构，TileSet Terrain 负责视觉过渡，BFS/A* 负责可玩性，WorkerThreadPool 负责预算，调试叠加负责可验证。

---

## 5. 推荐复刻目标与实现 Brief

### 5.1 评分（1–5，分数越高越好）

> “实现成本（5=低）”“许可风险（5=低）”“30fps 信心（5=高）”均已反向计分，便于直接相加。

| 目标 | 视觉效果 | 实现成本（5=低） | 许可风险（5=低） | Godot 适配度 | 30fps 信心 | 总分 /25 | 结论 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| **A. BSP 地牢 + TileSet Terrain 自动过渡** | 4.0 | 5.0 | 5.0 | 5.0 | 5.0 | **24.0** | **先做**；1–2 天可出可玩 slice |
| **B. FastNoiseLite + Poisson + Voronoi 生物群系** | 5.0 | 3.5 | 5.0 | 4.5 | 4.5 | **22.5** | **第二做**；视觉 hero，3–5 天 |
| **C. CA 洞穴 + BSP 锚点 + WFC 细节（可选）** | 4.5 | 2.5 | 5.0 | 4.0 | 4.0 | **20.0** | 只在需要“洞穴据点/混合关卡”时做；复用 `godot-wfc` |
| （对照）纯 WFC 新 demo | 3.5 | 2.0 | 5.0 | 4.0 | 3.5 | 18.0 | **不做**：已有 `godot-wfc/` |

**执行建议**

- **先 A**：验证工程管线（确定性、连通、TileSet Terrain、调试叠加、30fps），产出可玩的 2D 地牢 slice。
- **再 B**：复用 A 的 TileMapLayer/预算/验收框架，换成噪声+Poisson+Voronoi，做出“世界地图”视觉 hero；2D 版本可直接为 T-022 的 3D 海岛提供高度/湿度/遮罩参数。
- **C 暂缓**：只有 T-021 明确需要“洞穴 + 房间 + 约束细节”时才做；否则容易与已有 WFC/CA demo 重复。

### 5.2 Brief A：BSP 地牢 + TileSet Terrain 自动过渡

**目标**：1280×720 / GL Compatibility / Intel HD 30 FPS+ 的可玩 2D 地牢 slice；固定种子可复现；有步进演示与调试叠加。

| 项 | 规格 |
| --- | --- |
| 地图尺寸 | **64×48 格**（32 px/格，世界 2048×1536，相机滚动）；可选 80×60 压力档 |
| 瓦片/材质 | 3 层：地板、墙体、装饰；TileSet Atlas 32×32；地板 6–8 变体、墙 3 变体、门 2 变体；**原创程序化瓦片**或 CC0（Kenney）并在 `CREDITS.md` 记录 |
| 自动过渡 | TileSet Terrain：`wall` 地形，模式 **Match Corners and Sides**；`set_cells_terrain_connect` 批量刷墙/地面过渡；地板/墙体各保留概率变体 |
| 算法 | BSP 递归切分（最小叶 10×8，最大深度 6，最小房间 5×4，内缩 1–2）→ 每叶放房间 → 房间中心按“最近未连接房间”连 L 走廊（等价 MST 近似）→ 可选额外 10–15% 环路 → BFS 从起点验证 → 未达房间连最近可达点 → 死胡同剪枝 → 起点/终点取 BFS 最远点对 |
| 种子 | `RandomNumberGenerator` 固定 seed（如 `hash("T-021-dungeon")`）；独立流：`split_rng` / `room_rng` / `corridor_rng` / `decor_rng` / `loot_rng`；记录 `seed + size + signature` |
| 步进可视化 | 阶段：`split → rooms → corridors → connectivity → decor`；暂停/单步/速度 1–20 阶段/秒；当前阶段高亮；完成后可切“成品/调试” |
| 调试叠加 | BSP 切分线、叶节点矩形、房间 ID、走廊图、BFS 连通分量、未达房间红框、起点/终点、种子/签名、生成耗时 ms |
| 验收 | 100 seeds：**房间可达 100%**、房间不重叠、走廊不出界；同 seed 两次签名一致；64×48 生成 ≤ 50 ms（后台/加载）；步进播放 ≥ 30 FPS @1280×720；draw call ≤ 10；600 帧 headless 无 ERROR |
| 版权 | 不复制任何商业地牢的布局/瓦片/UI；瓦片原创或 CC0；参考算法但不复制无权代码 |

**伪代码**

```text
seed = hash("T-021-dungeon")
rng_split, rng_room, rng_corr, rng_decor = split_streams(seed)
leaves = bsp_split(Rect2i(1,1,62,46), depth=0, max_depth=6, min_leaf=10x8)
rooms = for leaf in leaves: inset_random_room(leaf, min=5x4, rng_room)
grid = wall_grid(64,48)
carve_rooms(grid, rooms)
connect_rooms_nearest(grid, rooms, rng_corr)   # L 走廊
add_loops(grid, rooms, rng_corr, ratio=0.12)
start = rooms[0].center
reachable = bfs(grid, start)
for room in rooms where not reachable: connect_to_nearest_reachable(room)
start, exit = farthest_pair(grid, start)
decorate(grid, rng_decor, poisson_min_dist=2)
```

**Godot 落地**

- `TileMapLayer.set_cell` 批量写地板/墙；墙体用 `set_cells_terrain_connect` 让角/边自动过渡。
- 生成放 `WorkerThreadPool`（纯数据），完成后 `call_deferred` 到主线程写 TileMapLayer；步进演示可在主线程一次写一个阶段。
- `AStarGrid2D` 只做验证/最远点，不参与每帧生成；不要在每帧重建。
- 装饰用 `MultiMeshInstance2D` 或少量 Sprite2D；不要每格一个节点。
- 调试叠加用 `_draw()` 画线/矩形，不生成额外节点。

### 5.3 Brief B：FastNoiseLite + Poisson + Voronoi 生物群系地图

**目标**：一张“世界地图”级的 2D 生物群系地图，视觉优先；1280×720 / GL Compatibility / Intel HD 30 FPS+；固定种子可复现；可切通道/生物群系/河流/植被视图。

| 项 | 规格 |
| --- | --- |
| 地图尺寸 | **96×64 格**（32 px，世界 3072×2048）或 128×96 压力档；TileMapLayer 分块（32×32）加载 |
| 瓦片/材质 | 6 生物群系：深水、浅水、沙、草、森林、岩石/雪；每类 4–6 变体；水/岸/草/林/岩/雪自动过渡；原创调色板 |
| 场 | `FastNoiseLite` ×3：海拔（FBM/Simplex，frequency 0.012，octaves 4）、湿度（Simplex，0.02）、温度（Perlin，0.03）；岛屿遮罩 = 径向衰减 + 域扭曲；可选第二层细节噪声 |
| 分类 | 海拔阈值 → 水/岸/陆地；陆地按湿度分草/森林；高海拔/低温度 → 岩石/雪；所有阈值暴露为导出参数 |
| 河流 | 从高海拔格出发，沿最陡下降走到水/边界；合并相邻河流；限制 3–6 条；避免 1 格断头 |
| 植被/POI | Poisson Disk（Bridson，r=2.5–4 格，k=30）撒树/石头/遗迹；POI 3–8 个；用 `RandomNumberGenerator` 独立流 |
| 区域（可选） | Voronoi（Poisson 种子 + 最近点距离场）做王国/生态区边界；边界用噪声扰动，避免直线；`Geometry2D` 裁剪/合并 |
| 种子 | 海拔/湿度/温度/植被/POI/河流各自 seed offset；记录 `seed + 参数 + signature`；同 seed 逐格一致 |
| 步进可视化 | 视图切换：`海拔 → 湿度 → 温度 → 生物群系 → 河流 → 植被/POI`；生成一次，切换视图只重绘，不重算 |
| 调试叠加 | 噪声通道热力、阈值线、生物群系直方图、最大陆块占比、河流长度/入海、Poisson 最小距离、生成 ms |
| 验收 | 100 seeds：最大陆块 ≥ 90% 陆地面积；至少 1 条河流入海；3–8 个 POI；同 seed 签名一致；96×64 生成 ≤ 100 ms（后台/加载）；播放 ≥ 30 FPS；draw call ≤ 12；无每格节点 |
| 版权 | 噪声/算法无版权问题；瓦片/色板原创或 CC0；不复制商业地图纹理/画面 |

**伪代码**

```text
seed = hash("T-021-biomes")
elev = FastNoiseLite(seed+1, SIMPLEX, freq=0.012, octaves=4)
moist = FastNoiseLite(seed+2, SIMPLEX, freq=0.02)
temp  = FastNoiseLite(seed+3, PERLIN,  freq=0.03)
for y,x:
    e = elev.get_noise_2d(x,y)*0.7 + island_mask(x,y)*0.5 - 0.15
    m = moist.get_noise_2d(x,y)
    t = temp.get_noise_2d(x,y)
    biome = classify(e,m,t)
rivers = steepest_descent_from_high_points(elev, water_mask, max=6)
trees  = poisson_disk(r=3.0, k=30, seed=seed+4, only=land)
pois   = poisson_disk(r=10.0, k=30, seed=seed+5, only=walkable)
```

**Godot 落地**

- 先用 `FastNoiseLite.get_image()` 或 `NoiseTexture2D` 生成高度/湿度/温度图，再在 `PackedByteArray` 上分类；避免每帧逐像素调用。
- 96×64 一次生成约 6k 格 ×3 通道；本机逐像素约 60 ms，放 `WorkerThreadPool` 或加载界面。
- 用 `TileMapLayer` + TileSet Terrain 自动过渡；水/岸/草/林/岩/雪各一套 terrain 或 tile 变体。
- 河流/道路可用 `Line2D`/`Curve2D` 叠加，或直接写入 TileMapLayer；不要为每段生成节点。
- Voronoi 只在需要区域边界时加；优先用最近点距离场（简单、可控），Delaunay 不是必需。
- 验收时把“视觉 hero 截图”和“调试视图截图”都保存，证明不是贴图。

### 5.4 Brief C（可选）：CA 洞穴 + BSP 锚点 + WFC 细节层

**目标**：在 A 的 BSP 结构上，用 CA 挖出自然洞穴，再用已有 WFC 做局部装饰/道路/建筑细节；只在需要“洞穴据点/混合关卡”时做。

| 项 | 规格 |
| --- | --- |
| 地图 | 80×60 格；BSP 房间作为“锚点/安全区”，房间之间用 CA 洞穴连接；边界墙 |
| 算法 | BSP 房间 → 房间外区域 CA（45% 墙、4-5 规则、5 次）→ BFS 验证 → 用 L 走廊连接孤立房间/洞穴 → WFC 只在房间边缘/道路节点做局部填充（固定格/预条件） |
| 复用 | `godot-wfc/scripts/wfc_solver.gd`、`wfc_tileset.gd`、`tile_baker.gd`；CA 参数来自 `procedural-generation-teardown.md`；BSP 来自 `generators.py` |
| 种子 | BSP/CA/WFC 三段独立 seed；WFC 重开预算 ≤ 48 次回溯；总生成预算 ≤ 100 ms（后台） |
| 验收 | 100 seeds：BSP 房间 100% 可达；CA 洞穴最大连通块 ≥ 95%；WFC 无未坍缩格/矛盾；同 seed 一致；30 FPS 播放；无不可达 POI |
| 风险 | WFC 与 CA 的边界/预条件最容易出矛盾；先固定房间边缘为 WFC 的“allowed set”，再做局部块；不要全图 WFC |
| 版权 | 复用自家 `godot-wfc` 代码；不引入 WFC 示例图片/商业瓦片 |

**结论**：C 的视觉上限高，但工程/调试成本也最高；如果 T-021 只要求“一个能打的复刻”，**A + B 足够**，C 留作后续。

### 5.5 必须避免的版权边界

- ❌ 不复制 Dome Keeper / Lumencraft / Cassette Beasts / Brotato / Road to Vostok / Noita / Caves of Qud / Bad North / Townscaper 的**截图、瓦片、UI、音乐、关卡布局**。
- ❌ 不反编译、不 rip 商业游戏资产；不在仓库放“参考图/截图”作为素材。
- ❌ 不直接使用 mxgmn WFC 仓库的 `samples/*.png`（代码 MIT，示例图片/瓦片不随软件授权）。
- ❌ 不复制 Peatral（无许可证）的代码/资产；loothammer 虽在 README 声明 MIT 但无 LICENSE 文件，保守只读思路。
- ❌ 不把 Kenney/CC0 资产说成原创；在 `CREDITS.md` 写清来源、许可证、URL、修改。
- ✅ 所有 demo 图形用 Canvas/程序化绘制；所有游戏瓦片原创或 CC0；所有外部引用只写链接与文字结论。

---

## 6. 来源表

> 原始访问日期：**2026-11-21**；T-040 复核新增/更正来源为 **2026-11-22**（见 §6.5）。官方文档优先；媒体/社区来源用于案例核实，推断处已在正文标注。

### 6.1 Godot 官方

| # | 来源 | 用途 | URL |
| --- | --- | --- | --- |
| 1 | Godot 4.6 Release | 4.6 版本定位、可旋转场景瓦片、GridMap、Jolt 等 | https://godotengine.org/releases/4.6/ |
| 2 | Renderers（4.6） | Compatibility 功能对比与限制 | https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html |
| 3 | TileMapLayer（4.6） | 单层 API、批量更新、16-bit 坐标、terrain connect | https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html |
| 4 | Using TileSets（4.6） | Terrains/autotile 模式与配置 | https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html |
| 5 | FastNoiseLite（4.6） | 噪声类型、分形、种子、域扭曲 | https://docs.godotengine.org/en/4.6/classes/class_fastnoiselite.html |
| 6 | Noise（4.6） | `get_noise_2d`、`get_image`、`get_seamless_image` | https://docs.godotengine.org/en/4.6/classes/class_noise.html |
| 7 | NoiseTexture2D（4.6） | 异步线程生成、`changed` 信号 | https://docs.godotengine.org/en/4.6/classes/class_noisetexture2d.html |
| 8 | RandomNumberGenerator（4.6） | PCG32、seed/state、确定性 | https://docs.godotengine.org/en/4.6/classes/class_randomnumbergenerator.html |
| 9 | AStarGrid2D（4.6） | region/update、solid、diagonal、get_id_path | https://docs.godotengine.org/en/4.6/classes/class_astargrid2d.html |
| 10 | NavigationRegion2D（4.6） | 导航烘焙（on_thread） | https://docs.godotengine.org/en/4.6/classes/class_navigationregion2d.html |
| 11 | MultiMesh（4.6） | 单 draw call、实例数、无逐实例剔除 | https://docs.godotengine.org/en/4.6/classes/class_multimesh.html |
| 12 | SurfaceTool（4.6） | 程序化网格、绕序、ArrayMesh 替代 | https://docs.godotengine.org/en/4.6/classes/class_surfacetool.html |
| 13 | Geometry2D（4.6） | 多边形裁剪/合并/偏移/三角化 | https://docs.godotengine.org/en/4.6/classes/class_geometry2d.html |
| 14 | WorkerThreadPool（4.6） | 任务/组任务、场景树线程限制 | https://docs.godotengine.org/en/4.6/classes/class_workerthreadpool.html |
| 15 | Thread-safe APIs（4.6） | 场景树非线程安全、`call_deferred` | https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html |
| 16 | AStarGrid2D Demo | 官方 2D 网格寻路示例（MIT，Compatibility） | https://godotengine.org/asset-library/asset/2723 |
| 17 | Dynamic TileMap Layers Demo | 官方 TileMap 运行时更新示例 | https://godotengine.org/asset-library/asset/2713 |

### 6.2 插件 / 开源项目

| # | 来源 | 用途 | URL |
| --- | --- | --- | --- |
| 18 | Zylann/godot_voxel | 3D 体素、Transvoxel LOD、4.6 支持 | https://github.com/Zylann/godot_voxel |
| 19 | godot_voxel v1.6 | 明确对应 Godot 4.6 | https://github.com/Zylann/godot_voxel/releases/tag/v1.6 |
| 20 | Terrain3D | 高度场地形、Godot 4.5–4.8+ | https://github.com/TokisanGames/Terrain3D |
| 21 | AlexeyBond/godot-constraint-solving | 2D WFC/CSP、回溯、多线程 | https://github.com/AlexeyBond/godot-constraint-solving |
| 22 | Fast WFC | C++ WFC、tiling+overlap | https://github.com/AliasFactory/Godot_Fast_WFC |
| 23 | Rayogenesis WFC | overlap WFC、TileMapLayer | https://github.com/Rayogenesis/WaveFunctionCollapse-GodotAddon |
| 24 | GenMap Lite | 一键地牢、TileMapLayer、worker thread | https://godotengine.org/asset-library/asset/5546 |
| 25 | loothammer dungeon | TileMapLayer BSP 示例（无许可证） | https://github.com/loothammer/godot_2D_procedural_dungeon_gen |
| 26 | Peatral Map Generator | Voronoi/岛屿/河流（无许可证） | https://github.com/Peatral/Godot-Map-Generator |
| 27 | SebLague Marching Cubes | compute shader MC（Compatibility 不适用） | https://github.com/SebLague/Godot-Marching-Cubes |
| 28 | mxgmn WFC | 原始 WFC 算法/代码（MIT；示例图不随授权） | https://github.com/mxgmn/WaveFunctionCollapse |

### 6.3 案例 / 媒体（Godot 与非 Godot）

| # | 来源 | 用途 | URL |
| --- | --- | --- | --- |
| 29 | Godot Showcase · Dome Keeper | 引擎确认 | https://godotengine.org/showcase/dome-keeper/ |
| 30 | RPS · Dome Keeper 世界生成更新 | 程序化地图与 Godot 4 升级 | https://www.rockpapershotgun.com/dome-keeper-just-got-a-massive-update-that-ups-replayability-and-helps-generate-better-worlds |
| 31 | Steam · Dome Keeper A Keeper's Duty | 官方更新说明 | https://steamcommunity.com/games/1637320/announcements/detail/4396159337027279925 |
| 32 | Godot Showcase · Lumencraft | 引擎确认 | https://godotengine.org/showcase/lumencraft/ |
| 33 | Godot 开发者访谈 · Lumencraft | 全破坏像素地形、Godot 3 | https://godotengine.org/article/godot-showcase-2dynamic-games-lumencraft/ |
| 34 | Godot Showcase · Cassette Beasts | 引擎确认 | https://godotengine.org/showcase/cassette-beasts/ |
| 35 | Cassette Beasts 技术博客（Wayback 存档） | GridMap/16×8 chunks/手工世界（原文 404，存档可读） | https://web.archive.org/web/20210809140543/https://www.cassettebeasts.com/2021/08/09/technical-look-the-park/ |
| 36 | Godot Showcase · Brotato | 引擎确认 | https://godotengine.org/showcase/brotato/ |
| 37 | Brotato 系统拆解 | 固定竞技场/波次 | https://teemo.dev/game-design/brotato/design/overview-notes/ |
| 38 | Road to Vostok · Wikipedia | Godot 迁移、分区地图 | https://en.wikipedia.org/wiki/Road_to_Vostok |
| 39 | Road to Vostok · Steam 更新 | EA/地图/动态事件 | https://store.steampowered.com/news/app/1963610 |
| 40 | Godot Showcase · ΔV: Rings of Saturn | 引擎确认/程序化小行星 | https://godotengine.org/showcase/delta-v-rings-of-saturn/ |
| 41 | Noita 官网 | 自研引擎、全像素模拟 | https://noitagame.com/ |
| 42 | Noita Press Kit | Falling Everything 引擎 | https://noitagame.com/press/ |
| 43 | Unity · Caves of Qud 案例 | Unity 引擎确认、系统设计 | https://unity.com/resources/systems-driven-design-in-caves-of-qud |
| 44 | GDC Vault · Caves of Qud WFC 演讲 | WFC 多 pass 流程 | https://gdcvault.com/browse/gdc-19/play/1026263 |
| 45 | Oskar Stålberg · Bad North WFC 演讲 | 岛屿 WFC/路径优先 | https://www.youtube.com/watch?v=0bcZb-SsnrA |
| 46 | Oskar Stålberg · Beyond Townscapers | 3D/不规则网格/二次 WFC | https://www.youtube.com/watch?v=Uxeo9c-PX-w |
| 47 | Unexplored · Cyclic Generation | 图语法/环状地牢 | https://www.taylorfrancis.com/chapters/edit/10.1201/9781315156378-11/cyclic-generation-joris-dormans |
| 48 | Unexplored 演讲 | 环状生成实践 | https://www.youtube.com/watch?v=mA6PacEZX9M |

### 6.4 仓库内部参考

| # | 来源 | 用途 | 路径 |
| --- | --- | --- | --- |
| 49 | WFC demo | 已有 WFC 求解器/瓦片/性能 | `godot-wfc/` |
| 50 | WFC TECH | 取证、约束、复杂度、性能 | `godot-wfc/docs/TECH.md` |
| 51 | 程序化生成拆解 | CA/BSP/醉汉漫步/黄金路径参数 | `docs/procedural-generation-teardown.md` |
| 52 | 算法 demo | 确定性生成器/BFS 验证 | `docs/procedural-generation-demos/generators.py` |
| 53 | 既有交互讲义 | 设计系统复用 | `docs/procedural-generation-teardown-交互版.html` |
| 54 | 算法 demo 索引 | WFC/Steering/Flow Field 统一入口 | `docs/algorithm-demos-index.md` |

### 6.5 T-040 复核新增/更正来源（访问 2026-11-22）

| # | 来源 | 用途 | URL |
| --- | --- | --- | --- |
| 55 | Lumencraft · Steam 商店页 | 确认 “procedurally generated maps/levels” 与全破坏地形 | https://store.steampowered.com/app/1713810/ |
| 56 | Cassette Beasts · Technical Look: The Park（Wayback 存档） | 确认 16×8×32×32 chunks、GridMap、手工过渡、chunk 流式加载 | https://web.archive.org/web/20210809140543/https://www.cassettebeasts.com/2021/08/09/technical-look-the-park/ |
| 57 | ΔV: Rings of Saturn · Steam 商店页 | 确认玩法；页面未见程序化生成说明 | https://store.steampowered.com/app/846030/ |
| 58 | loothammer README（MIT 声明，无 LICENSE 文件） | 许可复核 | https://github.com/loothammer/godot_2D_procedural_dungeon_gen |
| 59 | Godot Asset 2723 · AStarGrid2D Demo | 官方示例/Compatibility | https://godotengine.org/asset-library/asset/2723 |
| 60 | Godot Asset 2713 · Dynamic TileMap Layers | 官方 TileMap 运行时更新示例 | https://godotengine.org/asset-library/asset/2713 |

---

## 7. T-021 执行清单（可直接照做）

### 7.1 工程

- [ ] `project.godot`：`renderer/rendering_method="gl_compatibility"`，1280×720，vsync 按测试需要关闭。
- [ ] 场景结构：`Main` → `TileMapLayer`（地板/墙/装饰）+ `Camera2D` + `CanvasLayer`（HUD/调试）；不要每格 Node2D。
- [ ] 生成逻辑：纯数据（`PackedByteArray`/`Array`），与渲染解耦；WorkerThreadPool 后台跑，主线程应用。
- [ ] 种子：所有随机来自 `RandomNumberGenerator`；独立流；记录 seed/signature；禁止无种子全局 `randi()`。
- [ ] 自动过渡：TileSet Terrains 配置完整；用 `set_cells_terrain_connect` 批量刷；边界/断头路检查。
- [ ] 连通：BFS/并查集验证房间/POI；失败修复或确定性重开；`AStarGrid2D` 做路径抽检。
- [ ] 调试：BSP 线/房间 ID/连通分量/噪声通道/耗时/seed 叠层；可开关。
- [ ] 性能：生成 ≤ 50–100 ms（后台）；播放 30 FPS+ @1280×720；draw call 目标 ≤ 10–12；无每帧重建。
- [ ] 视觉：原创瓦片/受限色板/TileSet Terrain 过渡/装饰层；1280×720 截图与 10 s 录屏。
- [ ] 许可：`CREDITS.md` 记录所有外部资产/工具/参考；不复制商业素材。

### 7.2 文档/交付

- [x] 更新 `docs/task-plans/research-docs.md` 的 T-20261121-020/T-20261121-040 状态与产出（2026-11-22）。
- [x] `docs/godot-procgen-survey.md`（本文件）。
- [x] `docs/godot-procgen-survey-交互版.html`（CA/BSP/噪声 3 个 demo；Chrome 150 headless 实测无 console error）。
- [x] `docs/shots/godot-procgen-survey-ca.png`、`-bsp.png`、`-biomes.png`（另 `-hero.png`）。
- [x] `cc-connect send --image` 发送 2 张截图（2026-11-22）。
- [x] `tools/git_publisher.py` 按 `commit_paths` 提交并 push 到 `origin/feat/ai-slice`（2026-11-22，发布器执行）。

### 7.3 验收口径（建议写进 QA）

| 指标 | 门槛 | 测量方式 |
| --- | --- | --- |
| 连通性 | 100 seeds 房间/POI 可达 100% | BFS/并查集 + 固定 seed 列表 |
| 确定性 | 同 seed 两次 tile signature 完全一致 | 哈希 tile 网格 + 两次运行 |
| 生成耗时 | A：64×48 ≤ 50 ms；B：96×64 ≤ 100 ms | `Time.get_ticks_usec()`，后台线程口径 |
| 播放帧率 | 1280×720 ≥ 30 FPS，P95 帧时间 ≤ 33.3 ms | 引擎 FPS + 帧时间采样 |
| 绘制开销 | draw call ≤ 10–12；无每格节点 | 引擎 monitor / 场景树审计 |
| 视觉 | 1280×720 截图可读；自动过渡无断角/断边 | 人工评审 + 截图 |
| 许可 | 无商业素材；CREDITS 完整 | 文件审计 |

### 7.4 T-040 复核记录（2026-11-22）

**交互演示实测（Chrome 150 headless，`file://` 单文件，无外部请求）**

- 3 个 Canvas demo 全部自动生成，**0 个 console error / pageerror**。
- CA（seed 2137）：地板 52.7%，连通块 1，最大块 100%；点“修复连通”后仍 1 块。
- BSP（seed 4242）：21 房间 / 22 走廊 / 可达 21/21，耗时约 14 ms（JS 口径）。
- 噪声（seed 9001）：陆地 43.1%，最大陆块 92.3%，河流 5，POI 7，树 173。
- 截图：`docs/shots/godot-procgen-survey-{ca,bsp,biomes}.png`（另 `-hero.png`）。

**案例复核与修正**

| 项 | 复核结果 | 处理 |
| --- | --- | --- |
| Cassette Beasts 技术博客 | 原链接 `cassettebeasts.com/tag/godot/` 现 404；Wayback 存档可读，确认 16×8×32×32、GridMap、chunk 流式加载、无自动瓦片 | 链接改为 Wayback；删除未证实的 “map randomizer” |
| Dome Keeper | RPS 确认 Godot 3→4、“better map generation”、更多形状/尺寸/新结构；未提“迷宫图/天然洞穴”与 3.5.1/GodotSteam | 删除未证实细节；保留“是/程序化”与推断标记 |
| Lumencraft | Steam 商店页明确 “procedurally generated maps/levels”；访谈确认 Godot 3、全破坏地形/流体/动态光照 | 证据补 Steam；引擎世代保留“访谈时”限定 |
| Brotato | teemo.dev 拆解确认 Godot 3.5、20 波固定竞技场 “constants that never move” | 补强证据 |
| Road to Vostok | Wikipedia 确认 Godot 迁移、EA 9 张地图/3 区域；未见“手工/真实地点”的直接表述 | 改为“未证实（推断非程序化）” |
| ΔV | Showcase/Steam 均未说明程序化生成 | 从“是”改为“未证实”，不计入程序化案例 |
| loothammer 许可证 | 无 LICENSE 文件，README 声明 MIT；GitHub license API 404 | 从“无许可证”改为“README 声明 MIT（无 LICENSE 文件）” |

**链接复核（HTTP 200 / 内容可读）**：Godot 4.6 Release、Renderers 4.6、TileMapLayer 4.6、godot_voxel v1.6、Terrain3D v1.1.0-stable、GenMap Lite asset 5546、AlexeyBond WFC、Godot Asset 2723、RPS、Lumencraft Steam、Brotato teemo、Wikipedia。未取到正文的链接已在正文标“本次未取到/未核实”。

**微基准口径**：§2.4 的中位数是 T-020 在 2026-11-21 用本机 Godot `4.6.stable.official.89cea1439` 跑的 20 次采样；T-040 只复核了二进制版本一致，**未重跑全部基准**。验收时应按同一脚本在本机复测，报告 median + P95。

---

## 8. 一句话总结

> **Godot 4.6 的程序化地图，不缺算法，缺的是“结构 → 连通 → 自动过渡 → 美术 → 预算”的管线。**
> 先做 **BSP + TileSet Terrain** 证明管线，再做 **噪声生物群系 + Poisson** 出视觉，WFC/CA 只做细节层；
> 所有案例只研究思路，不复制素材；所有推荐都能在 GL Compatibility / 1280×720 / Intel HD 30 FPS+ 下落地的范围内收敛。
