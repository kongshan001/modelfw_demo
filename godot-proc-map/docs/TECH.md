# 技术说明 · 边境制图台

> 任务：T-20261121-021（T-20261121-020/T-040 程序化地图调研的 follow-up）
> 引擎：Godot 4.6 `4.6.stable.official.89cea1439` / GDScript / GL Compatibility
> 目标：1280×720 逻辑、1920×1080 截图、Intel HD Graphics 6000 30 FPS+、无第三方运行时依赖

## 1. 定位与结构

调研（[`../../docs/godot-procgen-survey.md`](../../docs/godot-procgen-survey.md)）给出三个候选：A. BSP 地牢 + 自动过渡；B. 噪声生物群系 + Poisson；C. CA 洞穴 + BSP 锚点 + WFC 细节。本轮选择 **A + B**：A 验证“结构 → 连通 → 自动过渡”的工程管线，B 作为视觉 Hero；不重写 WFC（已有 `godot-wfc/`），不做 CA（已有拆解/交互演示），不做 3D 体素（另一个任务）。

```
gen_utils.gd      种子混合 / 坐标 hash / BFS / 连通分量 / FNV 签名（纯函数）
gen_dungeon.gd    BSP 地牢：split → rooms → corridors → connectivity → decor（纯数据）
gen_biome.gd      群岛：elevation → climate → terrain → rivers → vegetation → sites（纯数据）
tile_art.gd       运行时把 32×32 瓦片/道具画进 Image，再烘焙 TileSetAtlasSource
map_view.gd       SubViewport + TileMapLayer + Camera2D + hillshade/水色/调试叠加/chrome
hud.gd            中文控制台、统计、子随机流、阶段进度
main.gd           生成调度、连续/单步/速度、算法切换、工具 API
```

生成器不依赖节点/渲染/UI，可在 headless 直接实例化；`smoke_proc_map.gd` 正是这样测的。

## 2. 地牢：BSP + 最近邻走廊

### 2.1 参数

| 参数 | 值 | 说明 |
| --- | ---: | --- |
| 地图 | 64×48 / 80×60 | 32px/格；边界留 1 格墙 |
| 最小叶 | 10×8 | 小于此不再切 |
| 最大深度 | 6 | 递归上限 |
| 最大叶 | 16 | 防止房间过碎 |
| 最小房间 | 5×4 | 每叶内缩 1–2 格 |
| 房间类型 | stone / moss / wood / gold | 权重约 57% / 20% / 13% / 10% |
| 走廊 | 1 格宽 L 形 | 中心到中心，随机先横或先竖 |
| 生成树 | 最近距离 Kruskal 近似 | 所有房间天然连通 |
| 环路 | `round(rooms × loop_ratio × 2)`，默认 0.12 | 额外跨子树走廊 |
| 火把 | ≤34，墙格相邻地板，Chebyshev 间距 3×2 | 加法光晕 |
| 生成中位 | **17.45ms**（40 seeds，64×48） | 80×60 压力档 42.78ms |

阶段实现：

1. `_split_rect`：按长宽比选方向；不能切就停；深度 >2 时 16% 提前停；切点在中段；父叶弹掉，只留叶子。
2. `_run_rooms`：叶内随机取房间，55% 让房间接近叶大小，16% 做小密室；房间矩形天然不重叠；写入 `grid` 与 `cell_room`。
3. `_run_corridors`：所有房间对按中心距离排序，并查集连成生成树；再随机加环路（距离 ≤28 格）；L 形两段 `_carve_h/_carve_v`，只允许 1..w-2。
4. `_run_connectivity`：BFS 从首房间中心；不可达房间接到最近可达地板（最多 4 轮）；其余不可达地板回填为墙；最终 BFS 全图；用第一次 BFS 的距离找 A，再从 A 找 B（起点/终点为 BFS 最远点对）。
5. `_run_decor`：火把、房间陈设、地毯、起点/终点；签名 FNV-1a 覆盖 seed、grid、房间、装饰、start/exit。

### 2.2 复杂度

设 N = W×H，R = 房间数（≤16），A = 走廊格数。

- 切分 O(R)；房间 O(N)（写格）；所有房间对排序 O(R² log R)；走廊 O(A)。
- BFS/连通验证 O(N)，最多 4–5 次 BFS；总体系数很小。
- 装饰 O(N + R)；签名 O(N + 装饰数) 字节级。
- 本机 smoke：median 17.45ms、p95 24.67ms（40 seeds）；80×60 stress median 42.78ms。

### 2.3 校验

- 独立 BFS 复核：所有地板格可达、连通块 =1、起点/终点可达。
- `AStarGrid2D` 独立验证起点→终点路径（前 10 个 seed）。
- 房间矩形不重叠、不出界、中心是地板。
- 同种子逐阶段生成与一次性生成的 `grid`/签名/start/exit 完全一致。
- 30% 环路参数 vs 12% 必须产生不同签名。

## 3. 群岛：三通道噪声 + 河流 + Poisson + Voronoi

### 3.1 噪声参数（`FastNoiseLite`）

| 场 | 类型 | frequency | 分形 | 角色 |
| --- | --- | ---: | --- | --- |
| 海拔 | Simplex Smooth | 0.0125 | FBM 3 octaves，gain 0.5，lacunarity 2 | 大陆/山脉 |
| 海岸扰动 | Simplex | 0.018 | FBM 2 | 打散圆形轮廓，形成海湾/半岛 |
| 细节 | Simplex | 0.075 | 1 octave | 海岸细节、山谷纹理 |
| 湿度 | Simplex Smooth | 0.022 | FBM 2 | 森林/岩地 |
| 温度 | Perlin | 0.028 | FBM 2 | 雪线、纬度 |

岛屿遮罩（96×64，x/y 归一化到 [−1,1]）：

```text
d = sqrt(nx² + 1.12·ny²)
d += 0.245·coast(x,y) + 0.06·detail(x,y)
island = smoothstep(1.06, 0.28, d)
base   = elevation_noise(x,y)·0.5 + 0.5
e      = island · (0.8 + 0.36·base + 0.05·detail) − 0.265
```

湿度/温度：

```text
lat = 0.5 − y/H
m = clamp(0.82·(0.5 + 0.5·moist(x,y)) + 0.09 + 0.06·lat, 0, 1)
t = clamp(0.72·(0.5 + 0.5·temp(x,y)) + 0.16 + 0.20·lat, 0, 1)
```

### 3.2 生物群系分类与海滩

`sea_level` 默认 0（UI 可调 ±0.08）：

| 条件 | 分类 |
| --- | --- |
| e ≤ sea − 0.22 | 深水 |
| e ≤ sea − 0.075 | 浅滩 |
| e ≤ sea | 海岸（浅水） |
| e < sea + 0.055 | 沙滩 |
| e > `0.69 + (0.5−t)·0.05 ± 0.025`（hash 抖动） | 雪原 |
| e > 0.55 或 m < 0.24 | 岩地 |
| m > 0.535 且 e < 0.46 | 森林 |
| 其它 | 草地 |

之后对临水草地/森林（4 邻）且 e < sea+0.20 的格强制沙滩。小岛清理：计算陆地连通块；若除最大块外的面积 > 9.5%，把它们全部转成中/浅水；否则保留为小岛。最大陆块在本轮 100 seeds 中最低 95.9%。

### 3.3 河流

1. 候选河源：每个陆地格检查是否 4 邻域局部最高、e ≥ 0.26；按高度选 7 个，间距 ≥9 格。
2. 追踪：8 邻域选最低 e；若对角移动，同时补一个正交桥格，保证 4 连通；最多 140 步。
3. 抵达水体 → 入海；撞到已有河流 → 支流；两者都不是 → 丢弃，避免断头河。
4. 若所有河都没入海：用全图水体 BFS 距离场，从最高源强制走到水体（保证 ≥1 条入海）。
5. 河口：最后 4 个格向两侧加宽一格（仅陆地），形成喇叭口。

统计：`rivers / river_cells / rivers_to_sea / longest_river`；独立 smoke 逐河检查不落在水面、至少一条邻接海。

### 3.4 植被与地标（Bridson Poisson）

| 图层 | 最小间距（格） | k | limit | 接受条件 |
| --- | ---: | ---: | ---: | --- |
| 森林树 | 1.62 | 10 | 480 | biome=forest，非河 |
| 草地树/灌木 | 3.2 | 8 | 130 | biome=grass，非河 |
| 岩/雪巨石/雪松 | 3.9 | 8 | 80 | rock/snow，非河 |
| 花丛/草簇 | 2.2 | 6 | 100 | grass，非河 |
| POI | 12.5 | 18 | 6 | 陆地、非河、非高峰 |
| 区域种子 | 8.5 | 12 | 5 | 陆地、非河 |

- Bridson 在某个斑块耗尽 active 后会重新播种（最多 20 个额外起点），覆盖碎片化森林/草地；否则初始点落在哪个斑块就只填那一块。
- 树/岩石/花以“脚底”为锚点绘制，带烘焙阴影；POI 清空周围 2.6 格的树。
- POI 类型：近海（水体距离 ≤4）偏灯塔；高地偏哨塔；其余按随机分成遗迹/营地/村庄。名称从 10 个原创中文名中无重复抽取。
- 区域：POI 格子 + 5 个额外 Poisson 种子，最近点划分给每个陆地格；用于调试叠加和草地 5 个色相变体。

### 3.5 复杂度与耗时

设 N=96×64=6144，P=地表点数，R=区域种子（≤9）。

- 海拔/气候：O(5N) 次噪声 + O(N) 分类；河流 O(N + 源×步×8)；Poisson 近似 O(P·k + N)；区域 O(N·R)。
- 本机 smoke 100 seeds：median **63.22ms**、p95 **74.21ms**（含全部六阶段、含 6 个 POI、241 树量级、4 条河流）。
- 之前版本 median 160–250ms，优化点见 §8 与迭代记录：去掉不必要的全图 BFS、减少噪声 octaves、合并陆地清理/统计、河流按需距离场、河流层增量写入、纹理缓存。

### 3.6 签名与子流

- 子流：`海拔 / 气候 / 河流 / 植被 / 地标 / 区域`，由 `mix32(base_seed, salt)` 派生；HUD 显示十六进制值。
- 签名 FNV-1a 32-bit：base seed + sea 参数 + biome 字节 + river 字节 + 每个装饰（kind / 位置量化 / scale / variant）+ POI（名称/类型/格）+ 区域种子。
- 同 seed+尺寸+海平面生成两次，biome/river/region 数组与签名逐字节一致；smoke 对 5 个 seed 做逐阶段 vs 一次性对比。

## 4. 渲染：TileMapLayer + 自定义 16 向地形

### 4.1 图集

`tile_art.gd` 在启动/首次切换时把全部瓦片画进一张 `Image`，`ImageTexture` + `TileSetAtlasSource`，32×32 区域，16 列，生成 mipmaps；图层使用 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`。所有图形来自 `set_pixel` + 自写 disc/ellipse/triangle/line/noise 工具，没有外部贴图。

地牢瓦片：4 种地板 ×6 变体、墙 16 向 ×2 变体、地板阴影 16 向；道具（火把、木箱、桶、宝箱、桌、骸骨、蘑菇、柱、地毯、起点/终点）是独立 ImageTexture。

群岛瓦片：水面 3 深度 ×3 变体；草地 5 变体；沙/森林各 16×2；岩/雪各 16×1；海岸泡沫 16；河流 16；树 6+4+2、灌木、巨石、花、POI 5 类。

### 4.2 方向 mask 约定

| 位 | 方向 |
| ---: | --- |
| 1 | N |
| 2 | E |
| 4 | S |
| 8 | W |

- 墙：mask=相邻墙；无墙的边画亮顶/亮左/暗底/暗右，并在外凸角做 4px 圆角。
- 地板阴影：mask=相邻墙，四边 4px 渐变黑。
- 沙/森林/岩/雪 overlay：mask=同 terrain 的 4 邻，非同类边做 9–10px 抖动 alpha 渐隐。
- 海岸泡沫：陆地格 mask=水方向；水格 mask=陆地方向（双面泡沫）。
- 河流：mask=河/水方向；中心到各接口画 17px 宽水带，边缘抗锯齿。
- 河流/海岸/墙面全部 16 种 mask 预烘焙，不需要运行时几何。

### 4.3 图层顺序

群岛：`ocean(0) → water tint(0, 后添加) → ground(1) → sand(2) → coast(3) → forest(4) → rock(5) → snow(6) → river(7) → hillshade(9) → decor(10) → glow(11) → field/debug(15/21–24) → overlay(30)`。
地牢：`floor(2) → shadow(3) → wall(4) → decor(10) → glow(11) → overlay(30)`。

- **hillshade**：以海拔梯度（1 格 + 3 格）计算西北光照，输出 RGBA 白/暗叠层，LINEAR 放大，给山谷/山脊体积感。
- **水色**：所有水格使用同一组 mid 瓦片做纹理，再用地图分辨率连续深度色（deep→mid→shallow）覆盖 alpha 0.64，消除 32px 深度硬边；再叠加两层平滑 value noise 的明暗。
- **POI 标签**：不是 world 字体，而是在 chrome 屏幕空间绘制；固定 10.5×ui_scale 字体，自动避开图例/标题框，缩放/平移时始终可读。
- **chrome**：罗盘、比例尺（自动选 4/8/10/16/20 格）、种子/签名面板、群系/地牢图例、字段图例、边界角标。
- **vignette**：320×180 RGBA 径向暗角，群岛 0.82 强度、地牢 1.0。

### 4.4 为什么不用 `set_cells_terrain_connect`

调研建议 `TileSet` Terrains，但本项目的资产是**运行时烘焙**的，并且同一格需要多套互相叠加的 alpha 地形（草底 → 沙 → 森林/岩/雪 → 河），还有双面海岸泡沫与自定义河流带。Godot Terrain 只支持每格一个 terrain tile；要实现同等效果需要把 alpha 过渡组合进瓦片并准备 8 邻域组合，仍无法覆盖水面/陆地双向泡沫。

因此这里使用 **TileSetAtlasSource + 16 向 mask 解析器**：语义上等价于 Match Corners/Sides 的边过渡（边对边、角对角），但组合由代码控制，便于 alpha 多层与自定义接口。若移植到 Unity，可直接映射为 Rule Tile 的 16 种边规则；Unreal/Three.js 用同样的 mask 选择即可。

## 5. 查看器、阶段与调试

- 地图在 `SubViewport` 中由 `Camera2D` 渲染，HUD/chrome 在外面，截图可把整个场景放进 1920×1080 SubViewport 无损放大。
- 相机 fit 使用**内容裁剪框**：群岛按陆地包围盒 +5 格，地牢按地板包围盒 +6 格，因此不会把整张海面/空墙缩得很小；用户可以拖动/滚轮/双击复位。
- 阶段：主控每帧累积 `speed`，到点调用生成器的一个阶段；`暂停` 只停自动推进，`单步` 手动一阶段，`完成` 执行剩余阶段。阶段标签/进度条/统计同步刷新。
- 调试叠加各占一个 Sprite2D（z=21–24）或 overlay `_draw`：
  - 连通性 → BFS 分量/距离纹理；
  - 群系 → 分类纯色纹理；
  - 区域 → 最近点区域色 + 边界；
  - 噪声 → 96×64 场热力 + 等值线（海拔/湿度/温度）；
  - BSP → 叶/房间色块；overlay 画切分线/房间矩形/ID/起点终点；
  - 边界 → 地图矩形 + 每 8 格网格。
  - 所有纹理在需要时生成，缓存按 seed/stage/签名区分；不会每帧重建。
- HUD 显示 FPS；截图/录屏时 `api_set_capture_mode(true)` 把 FPS 标签换成 `FPS · 录制`，避免把 PNG 落盘的停顿误读成实际性能。

## 6. 实测

### 6.1 无头 smoke（`tools/smoke_proc_map.gd`）

```text
UI_CONTRACT_OK
DUNGEON seeds=40 rooms_avg=15.5 median_ms=17.45 p95_ms=24.67 stress_median_ms=42.78
BIOME seeds=100 largest_min=95.9% rivers_min=1 poi_range=6..6 median_ms=63.22 p95_ms=74.21
PROC_MAP_SMOKE_OK
```

覆盖项：

- 地牢 40 seeds：生成成功、房间 ≥5、房间不重叠/不出界/中心地板、BFS 100% 可达、连通块 1、start/exit 可达、A* 起终点路径、同 seed 逐步一致、参数影响签名、签名多样性、median ≤50ms；80×60 压力档 5 seeds。
- 群岛 100 seeds：陆地 15–72%、最大陆块 ≥90%、≥1 条河入海、河流 ≥1、POI 3–8、树 ≥50、POI 不在水/河、POI 有区域、河不画在水面、独立检查邻海、同 seed 逐步逐字节一致、海平面参数改变陆地/签名、median ≤100ms、p95 ≤250ms（防病态重试）。
- 主场景：初始 6 阶段、单步推进、完成签名、5 个调试开关的置位/清零、切到地牢 5 阶段、同 seed 重开签名一致。

### 6.2 真实 GPU（`tools/probe_proc_map.gd`，1280×720，vsync off）

| 场景 | avg FPS | 最低采样 |
| --- | ---: | ---: |
| 群岛完成态 | 93.7 | 67 |
| 群岛全调试 | 76.7 | 75 |
| 地牢完成态 | 123.3 | 78 |
| 群岛连续生成（2 阶段/秒） | 130.0 | 130 |

> 机器同时有其他 worker 负载，采样 6×0.5s；这是最终构建的一轮记录。另一轮为 97.3 / 94.0 / 131.3 / 122.5 FPS（同为 1280×720、vsync off）。两轮均远高于 30 FPS 门槛；截图/视频中的 FPS 标签不参与验收。

### 6.3 启动与媒体

- `--headless --quit-after 600`：0 ERROR / 0 SCRIPT ERROR。
- GPU 截图 7 张 1920×1080；视频 300 帧 @30fps = 10.000s，MP4 2.8MB / GIF 9.8MB。
- 生成耗时与应用耗时分开记录：算法本体 median 17.45/63.22ms；应用耗时是 TileMapLayer 批量写格 + 调试纹理 + 装饰重绘，属于阶段切换的一次性成本，本机高负载下总和约 100–200ms。

## 7. 跨引擎注意

| 能力 | Godot | Unity | Unreal | Three.js |
| --- | --- | --- | --- | --- |
| 网格地图 | `TileMapLayer` + `TileSetAtlasSource` | `Tilemap` + `RuleTile`（2D Extras） | Paper2D TileMap 或 InstancedMesh 网格 | InstancedMesh + 平面/纹理图集 |
| 16 向地形 | 自写 mask 解析器 | RuleTile 16 种边规则 | 自写 mask → tile index | 自写 mask → UV 区域 |
| 噪声 | `FastNoiseLite` | FastNoiseLite 移植 / `Mathf.PerlinNoise` | `UNoise` / 自定义 FBM | `simplex-noise`（需固定版本/参数） |
| 随机流 | `RandomNumberGenerator`（PCG32） | `System.Random`/自写 PCG | `FRandomStream` | 自写 PCG/mulberry32 |
| 连通 | 自写 BFS + `AStarGrid2D` | BFS + NavMesh/A* | BFS + NavMesh | 自写 BFS/A* |
| 多层 alpha 地形 | 多个 TileMapLayer/CanvasItem | 多个 Tilemap + Sorting Layer | 多层 Translucent | 多层平面 + 透明材质 |
| 调试叠加 | Sprite2D/`_draw` | Tilemap/Debug 材质 | Canvas/Slate/Decal | 覆盖 Mesh/Canvas |
| 无 GPU compute | GL Compatibility 约束 | 低端机同样避免 compute | 移动端可能无 compute | WebGL2 无 compute |

**移植契约**（与引擎无关的数据）：

- `biome: uint8[N]`（0–7）+ `river: uint8[N]` + `region: int32[N]`（水为 −1）；
- `grid: uint8[N]`（地牢 0/1）+ `cell_room: int32[N]` + 房间矩形/类型；
- `seed_streams: 6×uint32` / `4×uint32`；
- `signature = FNV-1a32(有序字节流)`；两边必须使用同样的字节顺序和量化（位置×100）。
- 参数表见 §2.1 与 §3.1/§3.4；噪声实现差异会改变地图，但同一实现 + 同 seed 必须逐格一致。
- 验收口径：连通阈值、最大陆块 ≥90%、≥1 条入海河、POI 3–8、同 seed 签名一致、median 生成耗时。

## 8. 与调研 brief/案例的差异

| 维度 | 调研建议/案例 | 本工程 |
| --- | --- | --- |
| 地图 A | BSP 64×48，TileSet Terrain 自动过渡 | 实现 64×48/80×60，自定义 16 向 terrain 叠加；连通/BFS/A* 与 50ms 预算一致 |
| 地图 B | 96×64，FastNoiseLite + Poisson + Voronoi，视觉 Hero | 实现 96×64/112×72，3 通道 + 岛屿遮罩 + 河流 + Poisson + POI/Voronoi；加 hillshade/水色/双面泡沫/屏幕空间 POI 标签 |
| 算法 C | CA + BSP 锚点 + WFC 细节 | 未做（避免与 `godot-wfc/` 重复） |
| 纯 WFC | 调研明确不建议重写 | 未用；本工程不依赖 WFC |
| 案例素材 | Dome Keeper / Lumencraft 等只研究思路 | 未复制截图/瓦片/UI/关卡/品牌；全部程序化原创 |
| 3D 体素 | 另一个任务 T-022 | 未做；本工程纯 2D |
| 线程 | 建议 WorkerThreadPool | 当前 62ms 中位、分阶段可交互，主线程完成；扩大到 128×96 时再迁移 |
| 截图 FPS | — | capture mode 明确标注 `FPS · 录制`，真实 FPS 由 probe 给出 |

## 9. 已知风险与限制

1. **自定义 autotile**：没有走 `set_cells_terrain_connect`；视觉与语义已覆盖，但评审如果强制检查 Godot Terrain API 会不满足。替换成本评估：需要把多层 alpha 过渡烘焙进瓦片并重做海岸双面泡沫，约 1–2 天。
2. **主线程生成**：当前 96×64 median 63.22ms、p95 74.21ms，已低于 100ms；但算法与应用都在主线程，阶段切换时仍有 100–200ms 的批量写格停顿（高负载）。建议未来把纯数据阶段移到 WorkerThreadPool，在主线程仅做 `TileMapLayer` 应用。
3. **Bridson 的碎片覆盖**：多起点只覆盖有足够空间的斑块；极小的森林/草地碎块可能没有树。视觉上可接受，但“每片森林都有树”不是硬保证。
4. **河流 4 连通**：对角步会补正交桥格，所以河流看起来像像素阶梯；这是格子地图的取舍，不是连续曲线。
5. **生成参数敏感性**：海平面 ±0.08 会明显改变陆地比例；极端参数下仍通过“最大陆块”与保底河流，但 POI 可能集中在少数陆地。
6. **视觉上限**：32px 瓦片 + 1 格轮廓，近景可见方格；hillshade/水色/装饰缓解，但不是手绘资产。
7. **FPS 标签**：正常模式显示真实 Engine FPS；截图/视频 capture mode 显示 `FPS · 录制`，不要把截图里的数字当性能。
8. **字体**：系统 CJK 字体，Linux 需安装；不打包字体文件。
9. **无玩法层**：没有角色、战斗、导航烘焙或存档；连通/A* 只是生成验证。

## 10. 复现命令

```bash
cd godot-proc-map
godot --headless --path . -s tools/smoke_proc_map.gd
godot --headless --path . --quit-after 600
godot --path . --resolution 1280x720 -s tools/probe_proc_map.gd
godot --path . --resolution 1280x720 -s tools/screenshot_proc_map.gd
./tools/build_media.sh
```
