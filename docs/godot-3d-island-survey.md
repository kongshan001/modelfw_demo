# Godot 4.6 生成 3D 海岛：从高度场、海岸线到水面的可落地方案

> 任务：**T-20261121-022**（T-20261121-020 的 follow-up / 3D 海岛子题）
> 调研与实测环境：**Godot `4.6.stable.official.89cea1439`**、macOS、Intel HD Graphics 6000、目标 **GL Compatibility / 1280×720 / 30 FPS+**。
> 所有 URL 访问日期：**2026-11-21**（另注明的除外）。
> 交互版：[godot-3d-island-survey-交互版.html](godot-3d-island-survey-交互版.html)（单文件、无外部依赖；可调噪声/岛屿遮罩/海岸线的 Canvas 演示）。
> 父报告：[godot-procgen-survey.md](godot-procgen-survey.md)（2D/通用程序化地图总览）。本文只展开 3D 海岛，不重复 WFC / CA / BSP / 醉汉漫步的对比。
> 本文只做调研、文档与交互演示，不改任何游戏代码；不复制任何商业游戏画面、地形数据或素材。

---

## 0. 结论先行

### 0.1 两套推荐路线（按项目阶段选）

| 路线 | 一句话 | 适用场景 | 视觉上限 | 实现/性能成本 | GL Compatibility | 建议 |
| --- | --- | --- | --- | --- | --- | --- |
| **A. 高度场 + 岛屿遮罩 + 分块 LOD** | 用 2D 高度场（FBM + 岛屿 mask + 海岸塑形）生成一张 `ArrayMesh` 地形，海面单独一层 | 可走、可远眺的主岛；沙滩/草地/山脊/悬崖；开放世界小岛 | 中–高（靠美术分层、光照、雾、植被拉满） | 中；本机 257² 高度场 + 64 块 131k 三角约 1–1.6 s 单线程生成 | ✅ 支持（CPU 生成 + 普通材质） | **默认推荐；MVP 先做这条** |
| **B. 低多边形 Stylized** | 粗网格 + 平面着色（flat shading）+ 强色块 + 手工感轮廓；可选 icosphere / 非均匀网格 | 小岛、浮空岛、卡通/棋盘战棋地图；需要强美术识别度 | 高（风格化上限高，但不适合写实） | 低–中；三角数可压到 5–50k，生成 <0.5 s | ✅ 完全支持 | **视觉 demo / 小体量项目的首选** |
| C. 体素 / Marching Cubes / Transvoxel | 3D 密度场 → 网格，可挖洞/悬垂/破坏 | 可破坏地形、洞穴、沙盒建造 | 高（但材质/UV/LOD 成本高） | 高；GDScript 逐体素不可行，必须 GDExtension/C++；块重建 + 碰撞同步复杂 | ⚠️ CPU 路径可，GPU 特性需 Forward+；本机 Intel HD 不推荐 | **只作为后续扩展，不进 MVP** |

**一句话选型：**
- 想要“像游戏里的海岛”，且要在 Intel HD / Compatibility 上稳：**A（高度场）**，自写 `ArrayMesh` + `HeightMapShape3D` + 预生成岸线深度图水面。
- 想要“有辨识度的卡通岛”，且体量小：**B（低多边形）**，用共享高度场但平面着色/去索引。
- 想要“可挖洞的岛”：再上 **C（Voxel Tools）**；不要为了“技术先进”让 MVP 背体素成本。

### 0.2 本报告给出的具体方案（可直接照做）

```text
世界 1024×1024 m，海平面 y=0，岛屿半径约 420 m
高度场 257×257（4 m 网格），最大高度约 70 m
FastNoiseLite：SIMPLEX_SMOOTH + FBM(5 octaves) 作基底；
                SIMPLEX + RIDGED(4 octaves) 作山脊；
                独立 SIMPLEX 作 domain warp 打破圆形岛
岛屿遮罩：椭圆径向 falloff + 噪声波纹 + smoothstep/pow
网格：8×8 chunks，每块 32×32 quads；共 131,072 tris（66,049 高度场采样，分块后 69,696 顶点）
碰撞：HeightMapShape3D（257×257），不逐树碰撞
水面：1 张 2048×2048 平面 + Gerstner 顶点波 + 预生成 R8 岸线深度图
植被：2–4 个 MultiMesh，1,500–3,000 实例，Poisson Disk + 高度/坡度/湿度筛选
验收：1280×720、Compatibility、平均 ≥30 FPS、P95 ≤33.3 ms；
     同种子高度场 hash 一致；生成 ≤2 s（或预烘焙 <200 ms 加载）
```

### 0.3 最容易踩的五个坑

| 坑 | 后果 | 规避 |
| --- | --- | --- |
| 每个 chunk 各自采样噪声/各自算法线 | 接缝处高度/法线不一致，出现裂缝或亮线 | **所有 chunk 共享同一张高度场与同一张法线表**；边缘顶点坐标必须完全一致 |
| 依赖 `SurfaceTool.generate_normals()` 逐块算 | 块边缘法线只看到本块三角形，出现硬边 | 从高度场中心差分算全局法线；flat shading 则**故意**去索引并每面独立法线 |
| LOD 直接换网格，不做缝合 | T 形接缝/裂缝，镜头移动时闪烁 | 加裙边（skirt）或做 LOD 缝合；`visibility_range` 加滞后，禁止逐帧重建 |
| 水面用 `DEPTH_TEXTURE` 算浅水色，却没做 Compatibility 分支 | 颜色/深度错误，或顶点阶段编译失败 | MVP 改用**预生成岸线深度图**；要用深度纹理时只在 fragment 用，并按 `CURRENT_RENDERER` 做 NDC 重映射 |
| 用 GDScript 在加载时做几十万次噪声 + 侵蚀 | 数秒卡顿，Intel HD 上更像“死机” | 预烘焙高度图/EXR 或 WorkerThreadPool 分块；侵蚀离线做 |

### 0.4 实测基线（本机，Godot 4.6 headless）

> 目的：给 MVP 一个可复现的量级，不是跨机承诺。GDScript 单线程、`--headless`、同机仍有其他任务并发；数值取两次运行的区间/量级。

| 项目 | 规模 | 实测 |
| --- | --- | ---: |
| 高度场（warp + FBM + ridged + 岛屿 mask） | 257×257 = 66,049 采样 | **0.34–0.72 s** |
| 高度场法线（中心差分，GDScript 逐顶点） | 257×257 | **0.24 s** |
| `ArrayMesh` 分块构建 | 8×8 chunks / 131,072 tris | **0.30 s** |
| `HeightMapShape3D` 构建 | 257×257 | **0.015 s** |
| 热力侵蚀 3 次迭代（GDScript 逐格找最低邻居） | 257×257 | **2.72 s**（明确不建议运行时做） |
| 513×513 高度场（同噪声链） | 263,169 采样 | **3.60 s** |

**结论：** MVP 用 257²，总生成约 **1.0–1.6 s**（不含侵蚀）可接受；若目标“秒开”，把高度场预烘焙成 16-bit PNG/EXR 或 `.res`，加载只需几十毫秒。侵蚀放离线工具链。

---

## 1. 海岛到底由什么组成

把“3D 海岛”拆成六个可独立验收的层，避免一上来就写一个巨大的 `generate_island()`：

| 层 | 作用 | 主要数据 | Godot 落地 |
| --- | --- | --- | --- |
| **1. 形状（岛屿遮罩）** | 决定陆地/海洋轮廓，保证四周是海 | 2D mask（float 或 8-bit） | `FastNoiseLite` + 自写 falloff，存 `PackedFloat32Array` / `Image` |
| **2. 高度细节** | 山脊、丘陵、谷地、台地 | 高度场 `H(x,z)` | `FastNoiseLite`（FBM/Ridged/域扭曲）+ 可选侵蚀 |
| **3. 海岸线** | 沙滩、浅滩、悬崖、泡沫线 | 海平面、到岸距离/深度 | 高度阈值 + 距离场（BFS/采样）+ 水面 shader |
| **4. 网格与碰撞** | 可渲染、可走、可射线检测 | 顶点/法线/索引、碰撞形状 | `ArrayMesh` / `SurfaceTool`；`HeightMapShape3D` |
| **5. 水** | 海平面、深浅色、波、泡沫、反光 | 水面网格 + 深度图/深度纹理 | `PlaneMesh` + `ShaderMaterial`（Gerstner） |
| **6. 覆盖物与生态** | 树、草、岩石、生物群系色带 | 散布点、坡度/高度/湿度 | `MultiMeshInstance3D` + Poisson Disk + 顶点色 |

**验收顺序也按这个来**：先有“形状正确的灰模”，再谈水/植被/光照。不要在高度场接缝没解决时加 1 万棵树。

---

## 2. 高度场：从圆形岛到可信海岸

### 2.1 推荐管线（每一步都可单独开关）

```text
(u,v) 世界坐标
  → ① domain warp（用低频噪声扰动坐标，打破完美圆形）
  → ② 椭圆径向遮罩 mask = 1 - smoothstep(inner, 1, d)   （可 pow 调整海岸硬度）
  → ③ 基底高度 base = FBM(Simplex) ∈ 约[-1,1]
  → ④ 山脊 ridge = Ridged(Simplex)，只在中部/高处加权
  → ⑤ h = mask * (base*A + ridge*B*mask²) - seaFloor*(1-mask)
  → ⑥ 海岸塑形：沙滩压平、悬崖坡度限制、海岸噪声
  → ⑦ 可选： terrace（台地） / thermal & hydraulic erosion（离线）
  → ⑧ 高度 LUT：归一化 → 生物群系色带/材质权重
```

### 2.2 FastNoiseLite 参数表（Godot 4.6 原生）

Godot 4.6 的 `FastNoiseLite` 属性已在本机用 `ClassDB` 核对；属性名、枚举如下（官方文档见 §9）。

| 参数 | 推荐值（1024 m 岛） | 作用/直觉 | 备注 |
| --- | --- | --- | --- |
| `noise_type` | `TYPE_SIMPLEX_SMOOTH` | 基底；比 SIMPLEX 更平滑，适合大陆 | 慢一点，可接受 |
| `frequency` | **0.0025** | 主波长 ≈ 400 m | 数值越小，地形越大块 |
| `fractal_type` | `FRACTAL_FBM` | 分形叠加 | — |
| `fractal_octaves` | **5**（3–5 可用） | 细节层数 | 每加一层成本约 +20–30% |
| `fractal_lacunarity` | **2.0** | 每层频率倍数 | 常用 1.9–2.1 |
| `fractal_gain` | **0.5** | 每层振幅衰减 | >0.55 更粗糙；<0.45 更圆润 |
| `fractal_weighted_strength` | 0（可 0.1–0.3） | 抑制低层太强时的高层细节 | 需要“大地形压小细节”时开 |
| 山脊噪声 `noise_type` | `TYPE_SIMPLEX` | 山脊/山脉 | 也可 `TYPE_SIMPLEX_SMOOTH` |
| 山脊 `frequency` | **0.006** | 波长 ≈ 167 m | 山脊比基底更细 |
| 山脊 `fractal_type` | `FRACTAL_RIDGED` | 尖锐山脊 | 与 FBM 混合，不要全图 ridged |
| 山脊 `fractal_octaves` | **4** | — | — |
| 域扭曲 | 独立噪声实例 frequency **0.004**，FBM 3 octaves | 用采样偏移 `wx/wz` 打破圆形 | 也可用 `domain_warp_enabled`；见下 |
| `domain_warp_amplitude` | 30（官方默认） | 最大扭曲距离 | 直接用于高度噪声时，30 在米制坐标下可能偏大；先用独立 warp 实例更可控 |
| `domain_warp_frequency` | 0.05（官方默认） | 扭曲噪声频率 | 与振幅一起调 |
| `seed` | 固定整数 | 复现 | 每个噪声实例可同 seed；不同用途建议 seed+偏移 |

> **不要把 `get_noise_2d()` 的返回值当严格 `[-1,1]`。** 本机 20,000 个采样点的 FBM 实测范围约 `[-0.67, 0.64]`；不同分形/域扭曲会变。始终用 `clamp` 或按实测 min/max 归一化。

**岛屿遮罩公式（推荐直接用）：**

```gdscript
# p: 世界 XZ（米）；center: 岛中心；radius: 椭圆半径（米）
var q := p - center
var wx := warp_a.get_noise_2d(p.x, p.z) * warp_strength
var wz := warp_b.get_noise_2d(p.x + 71.3, p.z + 19.7) * warp_strength
q += Vector2(wx, wz)
var d := sqrt(pow(q.x / rx, 2.0) + pow(q.y / rz, 2.0))
var mask := 1.0 - smoothstep(inner, 1.0, d)   # inner≈0.62–0.78
mask = pow(clamp(mask, 0.0, 1.0), coast_power) # 1.2–2.0：越大岸线越陡
```

- `inner = 0.72–0.82`：越大，陆地越靠中心、海岸带越宽。
- `coast_power = 1.2–2.0`：控制从浅滩到陆地的过渡硬度；太小会像“圆形饼”，太大像“高台”。
- 椭圆 `rx/rz = 1.0–1.4`：避免正圆；再叠 domain warp 就足够自然。
- **保证四周是海**：不要让 mask 在地图边缘仍 >0；在最后强制 `if |x|>0.48W or |z|>0.48H: mask=0` 或加边界 falloff。

### 2.3 海岸线塑形（比“噪声阈值”更重要的是这 4 步）

1. **设海平面为 y=0**，所有高度以米为单位；水下地形也保留（浅滩/礁石）。
2. **沙滩带**：`0 < h < 2.5 m` 的坡度压到 `normal.y > 0.82`，避免沙滩像刀片。
3. **海岸噪声**：在 `d` 上加一层低频噪声（波长 80–150 m，幅度 0.03–0.08），让岸线有海湾/岬角；不要用高频噪声，否则岸线像毛刺。
4. **悬崖带**：`h > 12 m` 且坡度阈值以下时，允许更陡；用 `clamp` 或 terrace 形成“岩层”感；但不要整圈悬崖，保留 1–2 段沙滩登陆点。

**高度 LUT 建议（归一化高度 `t = (h - h_min)/(h_max - h_min)`）：**

| 区间 | 视觉 | 顶点色/材质 |
| --- | --- | --- |
| `h < -8` | 深水海床 | 深沙/暗礁（可省略，水下不可见） |
| `-8..0` | 浅滩 | 浅沙 `#C9B98A`，可加少量海草 |
| `0..2.5` | 沙滩 | 亮沙 `#E8D8A6` |
| `2.5..25` | 草地 | 草绿 `#6F9E4E`；湿度高处偏深 `#4F7A3A` |
| `25..50` | 岩石/灌木 | 岩灰 `#7C7468`；坡度大处强制岩石 |
| `>50` 或 `normal.y < 0.55` | 高峰/陡壁 | 浅岩/雪 `#EDF2F4`（风格化项目可只到岩石） |

> 顶点色在 3D 光照里按线性值参与；如果直接用 sRGB 十六进制颜色觉得偏暗/偏灰，用 `Color.srgb_to_linear()` 转换后再写入 `ARRAY_COLOR`，或改用贴图 + sRGB 导入。以截图调色为准。

### 2.4 Terrace（台地）与侵蚀

**Terrace（风格化，成本低）：**

```gdscript
func terrace(h: float, step: float, blend: float) -> float:
    var stepped := floor(h / step) * step
    return lerp(h, stepped, blend)
```

- `step = 6–10 m`，`blend = 0.15–0.3`；只对 `h > 3 m` 生效，避免沙滩出现台阶。
- 适合低多边形/卡通海岛；写实路线慎用，容易像梯田。

**热力侵蚀（thermal，近似崩塌）：**

- 对每个格找最低邻居，若高差 > `talus`，按比例搬运。
- 本机 GDScript 257² × 3 次 = **2.72 s**；只适合离线或极低分辨率预览。
- 参数：`talus = 1.5–3 m`，`rate = 0.1–0.2`，2–5 次；次数过多会把山脊磨平。

**水力侵蚀（hydraulic，droplet）：**

- 推荐离线：Sebastian Lague 的 MIT 实现/视频（§9）或 Python 工具，跑 50k–100k droplets，输出高度图。
- 在线只读取烘焙结果；不要在每个 chunk 加载时跑。
- 若必须在 Godot 内跑，使用 WorkerThreadPool + 预计算坡度/流量，且把预算限制在 <500 ms；Intel HD 机器上 GDScript 很容易超。

**推荐的“够用”组合：** 基底 FBM + ridged 山脊 + mask + 海岸压平 + 轻度 terrace（可选）+ **离线** 1 次水力侵蚀。不要同时上热力 + 水力 + 高分辨率，收益递减。

---

## 3. 网格、分块、LOD 与碰撞

### 3.1 `ArrayMesh` vs `SurfaceTool`

| | `ArrayMesh`（数组接口） | `SurfaceTool` |
| --- | --- | --- |
| 适合 | 运行时批量生成、多线程、分块 | 原型、少量网格、需要 `generate_normals/tangents` |
| 写法 | 组装 `PackedVector3Array` / `PackedInt32Array` 等，`add_surface_from_arrays()` | `begin()` → `set_*` → `add_vertex()` → `commit()` |
| 性能 | 更快，少一次中间层 | 方便但逐顶点调用开销大 |
| 法线 | 自己算（推荐从高度场中心差分） | `generate_normals()`；注意跨块接缝 |
| 切线 | 自己算或不需要（无 normal map 时跳过） | `generate_tangents()`，需要 UV + 法线 |
| 本机 131k tris | **0.30 s**（8×8 chunks） | 未测；预计更慢 |

**结论：** MVP 用 `ArrayMesh` 直接数组；`SurfaceTool` 只用于小道具/教学。官方教程：`Using the ArrayMesh`、`Using the SurfaceTool`（§9）。

### 3.2 网格规格与分块

| 参数 | 推荐值 | 说明 |
| --- | --- | --- |
| 世界尺寸 | **1024×1024 m** | 小岛可走完；再大用 Terrain3D/流式 |
| 高度场 | **257×257**（4 m 间距） | 66,049 采样；够表现 10–30 m 级地形 |
| 岛屿半径 | 380–440 m | 四周留 80–120 m 海 |
| 网格块 | **8×8 = 64 块**，每块 32×32 quads | 每块 1,089 verts / 2,048 tris |
| 总三角 | **131,072** | 单材质、64 draw calls |
| 顶点属性 | `VERTEX / NORMAL / COLOR / INDEX` | 无 UV 时不需要切线；要贴图再加 UV/TANGENT |
| 索引类型 | `PackedInt32Array` | 每块 <65k verts，也可用 16-bit，但 32-bit 更省心 |

**绕序（winding）：** Godot 以**顺时针**为正面（从正面看）。网格如果从上方看不见、从下方能看见，就把每个三角形索引顺序反过来。不同坐标轴/视角容易搞混，**先做一个 2×2 的测试块确认**，再批量生成。

**共享高度场是防接缝的关键：**

```gdscript
# 全局只生成一次
var H := PackedFloat32Array(); H.resize(N * N)
var N := 257
var NORMALS := PackedVector3Array(); NORMALS.resize(N * N)

func height_at(ix: int, iz: int) -> float:
    return H[iz * N + ix]

# 中心差分法线（米制：dx = dz = 4.0）
func normal_at(ix: int, iz: int) -> Vector3:
    var hl := height_at(maxi(ix - 1, 0), iz)
    var hr := height_at(mini(ix + 1, N - 1), iz)
    var hd := height_at(ix, maxi(iz - 1, 0))
    var hu := height_at(ix, mini(iz + 1, N - 1))
    return Vector3(hl - hr, 2.0 * SPACING, hd - hu).normalized()
```

- 每个 chunk 的顶点位置必须是 `Vector3(ix * 4.0, H[iz*N+ix], iz * 4.0)`；不要用“块内局部坐标 + 不同噪声偏移”。
- 相邻块的共享边顶点由同一 `ix/iz` 采样，天然一致。
- 法线也用同一张 `NORMALS` 表，避免块边缘硬边。

**低多边形版本：** 同样高度场，但每个 quad 拆成两个三角形后**去索引**（`SurfaceTool.deindex()` 或直接每个三角形写 3 个独立顶点），法线用面法线；再用受限色板（4–6 色）+ 少量顶点色抖动。三角数可降到 5–20k。

### 3.3 LOD

- **Godot 的自动 Mesh LOD 主要面向导入的网格**；运行时 `ArrayMesh` 不会自动帮你生成 LOD。你要自己生成 LOD 网格或做距离剔除。
- **两级 LOD 足够 MVP：**
  - LOD0：4 m 间距（近处，≤180 m）
  - LOD1：8 m 间距（远处，180–420 m）
  - 更远：直接用低分辨率整体网格/雾遮住。
- 每级 LOD 用同一高度场按步长采样；块边界要**对齐到偶数格**，否则接缝对不上。
- **裙边（skirt）**：每块四周向下拉 2–4 m 的垂直裙边，能遮住 90% 的 LOD 裂缝；比实现完整 Transvoxel 缝合便宜得多。
- **`GeometryInstance3D`：**
  - `visibility_range_begin/end`（米）+ `visibility_range_fade_mode` 做 HLOD/距离切换；
  - `lod_bias` 调整自动 LOD 偏置（对导入网格有效）；
  - 距离阈值加 5–10% 滞后，避免相机在边界抖动导致闪烁。
- **不要逐帧重建**：LOD 切换只换 `Mesh` 资源或可见性；高度场不变就不重建数组。

**低多边形的三种轮廓（路线 B 细项）：**

| 方案 | 做法 | 优点 | 缺点 | 适用 |
| --- | --- | --- | --- | --- |
| **Grid（高度场粗网格）** | 复用本文高度场，步长 8–16 m；每个 quad 去索引、每面独立法线；受限色板 | 最简单；与 `HeightMapShape3D` 碰撞天然一致；可复现 | 轮廓仍受高度场限制；近看面片大 | 卡通主岛、战棋地图 |
| **Icosphere（细分二十面体）** | 二十面体细分 3–6 次，沿法线用 3D FBM + 岛屿 mask 位移；flat shading | 轮廓圆润、适合浮空岛/星球；无极点问题 | 半径位移会自交；UV 接缝/碰撞要额外处理；难做沙滩/海岸带 | 浮空岛、小型幻想岛 |
| **Irregular / 手工轮廓** | 手绘多边形轮廓 + 挤出 + 噪声细节；或非均匀网格 | 美术可控性最高；剪影有设计感 | 碰撞/UV/生成管线更手工；不适合大规模 | 主菜单展示岛、关卡地标 |

- Grid 版的关键是**去索引**：`SurfaceTool.deindex()` 后每个三角形拥有独立顶点，再 `generate_normals()` 得到平面法线；否则会得到平滑着色。
- Icosphere 版的海岸线语义弱：更适合“浮空岛/岩石岛”，而不是有沙滩和浅滩的主岛。
- 三种方案都能用 `Color` 顶点色 + 受限色板；低多边形的视觉上限主要取决于**色板、轮廓和光照方向**，不是三角数。

### 3.4 碰撞

**首选：`HeightMapShape3D`（原生）**

- 网格点 **1 m 间距**、以 `CollisionShape3D` 原点为中心；内部每格拆两个三角形。
- 属性：`map_width`、`map_depth`、`map_data`（`PackedFloat32Array`，长度 = width × depth）。
- 地形 4 m 间距时，两种做法：
  1. `CollisionShape3D.scale = Vector3(4, 1, 4)`（最简单；确认 Jolt/Godot Physics 下缩放行为符合预期）；
  2. 单独生成 1 m 间距的碰撞高度场（1025×1025 ≈ 4.2 MB float），彻底避免缩放歧义。**推荐 2**，尤其项目用 Jolt（4.6 新 3D 项目默认）。
- 性能：官方明确 `HeightMapShape3D` 比 `ConcavePolygonShape3D` 快，但比 Box 等图元慢；本机 257² 构建仅 **15 ms**。
- 洞：把 `map_data` 对应顶点设为 `NAN` 可打洞（GodotPhysics3D 与 Jolt 都支持），再给洞穴单独碰撞。
- **不要**用 `Mesh.create_trimesh_shape()` 给 131k 三角地形做碰撞：构建慢、内存大、角色贴地查询也更贵。它只适合小道具。

**角色贴地：**

- 玩家用 `CharacterBody3D` + `move_and_slide()`；
- 敌人/NPC 距离远时可直接 `terrain_height(x,z)` 采样贴地，别给每个敌人开复杂碰撞（Terrain3D 文档也给了同样建议）；
- 射线检测只用于“不知道 XZ”的场合（例如鼠标拾取）。

### 3.5 生成耗时与线程

| 策略 | 适用 | 说明 |
| --- | --- | --- |
| 加载时单线程生成 | 原型/MVP | 1.0–1.6 s；加加载画面/淡入，不要卡在首帧 |
| `WorkerThreadPool` 分块 | 正式版 | 高度场按行/块并行；每线程用自己的噪声实例（避免共享状态） |
| 预烘焙高度图 | 最稳 | 16-bit PNG/EXR 或 `.res`；加载 + 建网格 <300 ms；美术可手工修 |
| 运行时增量 | 沙盒/编辑器 | 改一块重算一块 + 局部碰撞更新；预算 50 ms/帧以内 |

**注意：** FastNoiseLite 的线程安全性未在本文做压力验证；并行时**每线程创建独立实例**（同 seed），不要在多个线程共享同一个实例。`ArrayMesh.add_surface_from_arrays()` 应在主线程提交，线程只准备数组。

---

## 4. 水面、海岸与 GL Compatibility

### 4.1 MVP 推荐：预生成“岸线深度图”，不依赖深度纹理

本仓库 `godot-sea-water/` 的经验可直接复用：**用 BFS 距离场预生成深度图**，同时驱动水色、泡沫、角色水线；这比实时深度纹理稳定，且 Compatibility 完全可用。

**做法：**

1. 从高度场生成一张 `512×512` 的 R8 纹理：
   ```text
   depth = clamp((sea_level - h(x,z)) / 12.0, 0, 1)
   ```
   陆地（h≥0）为 0，深水为 1。
2. 水面 shader 用世界 XZ 映射 UV 采样这张图：
   - 浅水色 `#2FB7B0` → 深水色 `#0B3C5D`；
   - 泡沫 = `smoothstep(0.08, 0.0, depth)` × 噪声 × 时间；
   - 透明度随深度增加（0.35→0.75）。
3. 优点：无 `DEPTH_TEXTURE`、无 NDC/Y 翻转差异、无透明排序问题；缺点：动态物体（船）不会自动产生“遮挡变浅”的效果——MVP 不需要。

### 4.2 Gerstner 波（顶点着色器）

- 3–4 个波就够；每个波给方向、振幅、波长、陡度、速度。
- 顶点位移用 Gerstner：

```glsl
vec3 gerstner(vec2 p, vec2 dir, float amp, float wavelength, float steepness, float speed, float t, inout vec3 tangent, inout vec3 binormal) {
    float k = TAU / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(dir);
    float f = k * (dot(d, p) - c * speed * t);
    float a = steepness / k;
    tangent  += vec3(-d.x * d.x * steepness * sin(f), d.x * steepness * cos(f), -d.x * d.y * steepness * sin(f));
    binormal += vec3(-d.x * d.y * steepness * sin(f), d.y * steepness * cos(f), -d.y * d.y * steepness * sin(f));
    return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}
```

- 法线 = `normalize(cross(binormal, tangent))`；在顶点里算，片元里可再叠一层细节法线/噪声。
- 参数起点（1024 m 海域）：

| 波 | 方向角 | 振幅 | 波长 | 陡度 | 速度 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0° | 0.18 m | 18 m | 0.60 | 1.0 |
| 2 | 35° | 0.12 m | 31 m | 0.50 | 1.2 |
| 3 | 70° | 0.07 m | 57 m | 0.40 | 1.5 |
| 4 | 110° | 0.04 m | 96 m | 0.30 | 1.8 |

- 水面网格：`PlaneMesh` 2048×2048，64×64 细分（约 8k tris）；近处可再加一张 128×128 的细节平面，或直接用 128 细分（32k tris）看预算。
- 风格化项目可把振幅减半、波长加大，得到“平静海岛”而不是“怒海”。

### 4.3 如果一定要用深度纹理（浅水/折射）

- `hint_depth_texture` 在 **spatial fragment shader** 中可用；兼容渲染器也能采样，但：
  - **Compatibility 用 OpenGL NDC**：深度采样后通常要 `depth = depth * 2.0 - 1.0`，再乘 `INV_PROJECTION_MATRIX`；Forward+/Mobile 用 `[0,1]`，不要混用。
  - `hint_depth_texture` / `hint_screen_texture` 在 **vertex shader** 中不支持（Godot issue #124537，Compatibility 下实测编译失败）；只在 fragment 用。
  - **透明材质不会出现在深度/屏幕纹理里**，所以水面看不到其他半透明物；船/角色如果是透明材质也不会贡献深度。
- 推荐用一个 uniform 或 `CURRENT_RENDERER` 分支：

```glsl
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    depth = depth * 2.0 - 1.0;
#endif
```

`CURRENT_RENDERER` / `RENDERER_COMPATIBILITY` 是 Godot 4.4+ 的内置 shader 预定义（§9）。

### 4.4 GL Compatibility 的硬限制（与水面/海岛直接相关）

| 特性 | Compatibility | 影响 |
| --- | --- | --- |
| Compute Shader / RenderingDevice | ❌ | 不能做 GPU 噪声、GPU 体素、GPU 侵蚀；CPU 生成 |
| Screen-Space Reflections (SSR) | ❌ | 水面不能用 SSR 反射；用天空/ReflectionProbe/Fresnel 近似 |
| Volumetric Fog | ❌ | 用 Depth/Height Fog（支持）+ 天空渐变做空气透视 |
| SDFGI / VoxelGI / SSIL | ❌ | 用烘焙 LightmapGI（可渲染已烘焙）+ 方向光 + SSAO（支持） |
| SSAO | ✅ | 可用来增强山脊/岩石接触阴影 |
| Depth/Height Fog、Glow、Tonemap | ✅ | 海岛氛围的主力 |
| 透明材质深度/屏幕纹理 | ⚠️ | 透明物体不写入；排序问题要自己控制 |
| 新渲染特性 | ⚠️ 最晚 | 不要按 Forward+ 的特性表做设计 |

---

## 5. 植被、岩石与生物群系

### 5.1 MultiMesh 散布

| 项 | 推荐 | 说明 |
| --- | --- | --- |
| 批次数 | 2–4 个 `MultiMeshInstance3D`（树/岩石/草） | 一个 MultiMesh 一次 draw call；但**单个实例不单独视锥剔除** |
| 树木 | 1,200–2,000 | 每棵 80–200 tris；远 LOD 用 20–40 tris 或 billboard |
| 岩石 | 400–800 | 40–80 tris；大岩石单独碰撞 |
| 草 | 300–800 簇（可选） | 用交叉面片/短草网格；Intel HD 上不要做逐草动画 |
| 总三角 | 100k–200k | 加上地形 131k，总控制在 300k 左右 |
| 实例颜色 | `use_colors = true` | 同一种树做色相/明度变化，避免复制感 |
| 自定义 AABB | `custom_aabb` | 实例散布范围大时，避免整体被错误剔除 |
| 可见数量 | `visible_instance_count` | 流式/近处优先时可动态调 |
| 分桶 | 按 8×8 区块或距离环拆多个 MultiMesh | 弥补“单实例不剔除”的缺陷 |

**Poisson Disk（Bridson）参数：**

- 树：最小间距 6–12 m，`k = 30`；岩石 3–6 m。
- 采样范围限制在岛屿 mask 内；先拒绝水下/陡坡/沙滩，再按密度接受。
- 确定性：使用 `RandomNumberGenerator.seed`；点集顺序固定；同 seed 同结果。
- 坡度筛选：`normal.y > 0.72`（树）、`> 0.6`（岩石）；高度带：树 2–45 m，岩石 0–60 m。
- 湿度：额外一层低频噪声，森林处 `moisture > 0.45`；沙滩/岩石不种树。
- 海岸线留 2–4 m 缓冲，避免树长在水里。

### 5.2 碰撞与 LOD

- 只有玩家附近的大型岩石/树干给碰撞；每棵树都给碰撞会让物理服务器在密林里爆掉。
- 远景树用 billboard（2 个交叉面片）或低模；`visibility_range_begin/end` 切换。
- 草不参与碰撞、不投影；岩石可投影但限制阴影距离。

### 5.3 生物群系/气候

单岛不需要完整纬度为王，**高度 + 坡度 + 湿度** 就够：

| 条件 | 群系 | 颜色/植被 |
| --- | --- | --- |
| `h < 0` | 水下 | 沙/礁石；不散布树 |
| `0–2.5 m`，坡度缓 | 沙滩 | 亮沙；少量棕榈/浮木 |
| `2.5–25 m`，`moisture > 0.45` | 森林 | 深草 + 密树 |
| `2.5–30 m`，`moisture ≤ 0.45` | 草地 | 草绿 + 稀疏树/岩石 |
| `>25 m` 或 `normal.y < 0.62` | 岩石/山地 | 岩灰；少量针叶/灌木 |
| `>55 m` 且坡度缓 | 高山/雪 | 雪白；无树 |

- 可选纬度：`moisture = fbm(freq 0.0015, seed+101)`、`temperature = 1 - |z|/half_depth`（北冷南暖）；单岛用湿度噪声即可。
- 群系边界用 `smoothstep` 混色，不要硬切；岩石/草地交界可用坡度噪声打散。

---

## 6. Godot 4.6 原生 API、插件与“必须自己写”

### 6.1 原生能力（无需插件）

| 需求 | API / 节点 | 备注 |
| --- | --- | --- |
| 噪声/分形/域扭曲 | `FastNoiseLite` | 属性已核对 4.6；`get_noise_2d/3d`、`get_image()` |
| 噪声纹理 | `NoiseTexture2D` | 可做 mask/法线/色带；异步生成，注意 `changed` |
| 程序化网格 | `ArrayMesh`、`SurfaceTool` | 分块/批量优先 ArrayMesh |
| 碰撞 | `HeightMapShape3D` | 高度场专用；1 m 网格、居中 |
| 散布 | `MultiMesh` / `MultiMeshInstance3D` | 一次 draw call；单实例不剔除 |
| LOD/HLOD | `GeometryInstance3D.visibility_range_*`、`lod_bias` | 运行时 ArrayMesh 需自己出 LOD |
| 多线程 | `WorkerThreadPool` | 高度场/网格数组准备；主线程提交 |
| 图像/纹理 | `Image`、`ImageTexture` | 高度图/深度图/岸线 mask |
| 水体 | `PlaneMesh` + `ShaderMaterial` | Gerstner 在 vertex；无内置海洋系统 |
| 雾/环境 | `Environment`（Depth/Height Fog、Glow、Tonemap） | 体积雾不可用 |
| 物理 | 4.6 新 3D 项目默认 Jolt | HeightMapShape3D 支持 Jolt；洞用 NAN |

**Godot 没有内置 3D 地形系统/海洋系统。** 高度场地形、水面、侵蚀、Poisson 散布都要自己写或上插件。

### 6.2 插件/开源项目核实表（截至 2026-11-21）

| 项目 | 类型 | 许可 | Godot 4.6 / Compatibility | 能提供什么 | 风险/限制 | 维护状态 |
| --- | --- | --- | --- | --- | --- | --- |
| **Terrain3D**（TokisanGames） | C++ GDExtension | **MIT** | 1.x 支持 Godot 4.4+，**Compatibility 自 1.0 起支持**；v1.1.0 目标 4.5–4.8+ | Clipmap/几何 LOD（Witcher 3 式）、区域、纹理数组、碰撞、植被实例化、运行时雕刻 | **2.0 计划不再支持 Compatibility**（要求 compute/GL4.3+）；需按平台装 GDExtension 二进制；macOS 可能要去 quarantine | 活跃：4,782★，v1.1.0 2026-10-30，最近 push 2026-11-10 |
| **HTerrain**（Zylann/godot_heightmap_plugin） | GDScript 编辑器插件 | **MIT**（LICENSE.md） | README 标注 **Godot 4.6+**；GDScript，理论兼容 Compatibility | 高度图雕刻、纹理/颜色绘制、洞、LOD、草；商店条目称最高 4096×4096 | 仅 bug-fix，不再加功能；无 GDExtension；大图性能一般 | 低活跃但稳定：2,297★，最近 push 2026-11-13；Asset Store 条目 v1.8（2026-07） |
| **Voxel Tools**（Zylann/godot_voxel） | C++ module / GDExtension | **MIT** | GDExtension 文档要求 **Godot 4.4.1+**；**v1.6 对应 4.6**（父报告核对）；GPU 特性需 Forward+ compute | 体素/Transvoxel、无限分页、LOD、物理、植被实例化、图生成器 | GPU 生成/图需 compute（Forward+）；Compatibility 只能走 CPU 路径；块破坏/碰撞同步复杂；Intel HD 不适合 | 活跃：v1.7 2026-08-20（4.7.2 定制版） |
| **Gaea** | GDScript 插件（节点图） | **MIT** | 2.0 目标 **Godot 4.4**；GDScript，Compatibility 可用 | 节点图生成高度/地形/洞穴；可输出高度图给 Terrain3D/自写网格 | 2.0 早期开发，未针对大项目优化；不是运行时地形系统 | 活跃：1,666★，最近 push 2026-10-18 |
| **Terrainy** | GDScript 插件 | **MIT** | Godot 4；小体量，需实测 4.6 | 节点式地形编辑器：山/火山/陨石坑/**岛屿**、噪声、平滑/台地/散布 | 社区小（31★）；生产前要验证维护与性能 | 最近 push 2026-10-24 |
| **LesusX/Water-Shader** | Godot 4 demo | **MIT** | 最后测试 **4.5**；Compatibility 未声明，需实测 | Gerstner 波 + 焦散 + 泡沫 + 深度着色 + 海岛 demo | 体量小（8★）；不是生产水系统；深度着色依赖深度纹理 | 2025-09 后无更新 |
| **SebLague/Godot-Marching-Cubes** | 学习项目 | **MIT** | **compute shader**，需 Forward+/Mobile | GPU Marching Cubes 参考 | **Compatibility 不可用**；2023 后未更新 | 142★ |

**怎么选：**

- **MVP/教学/完全可控**：不装插件，用本文的自写高度场管线。代码量约 500–800 行 GDScript，足够 1024 m 岛。
- **要大型可编辑世界（4 km+）、纹理绘制、植被**：上 **Terrain3D 1.x**（固定 1.x，别升 2.0）。
- **要编辑器手工雕刻 + 小团队**：HTerrain（GDScript，易改）或 Terrainy（岛屿预设）。
- **要洞穴/可破坏**：Voxel Tools；接受 Forward+ 或 CPU 路径的性能折衷。

### 6.3 必须自己写的部分

1. 岛屿遮罩/海岸塑形（插件通常只提供通用高度场，不给“海岛”语义）。
2. 高度 LUT/生物群系色带（Terrain3D 有纹理绘制，但程序化规则要自己接）。
3. 分块/流式/LOD 策略（Terrain3D 自带 clipmap；自写路线要自己做）。
4. 岸线深度图/泡沫（预生成 R8 图或深度纹理方案）。
5. Poisson 散布与过滤。
6. 种子/版本/黄金样本的确定性测试。
7. 性能预算与调试叠层。

### 6.4 性能预算（1280×720 / Intel HD 6000 / Compatibility）

| 项 | 预算 | 说明 |
| --- | ---: | --- |
| 地形三角 | ≤150k | MVP 131k |
| 地形 draw calls | ≤64 | 8×8 分块，单材质 |
| 水面 | ≤20k tris / 1–2 calls | 64×64 细分约 8k tris |
| 植被 | 1,500–3,000 实例 / 4 calls | 100k–200k tris；远 LOD |
| 岩石 | ≤800 | 40–80 tris |
| 总三角 | ≤300k | 超过就降植被或地形 LOD |
| 总 draw calls | ≤80 | 分块 + MultiMesh |
| 阴影 | 只开近处树/岩石 + 方向光 | 地形自身投射阴影关掉，改用 SSAO/法线 |
| 碰撞 | 1 个 HeightMapShape3D | 不给每棵树碰撞 |
| VRAM | ≤256 MB | 纹理压缩 + mipmap；不要 4k 地形贴图满天飞 |
| 生成 | ≤2 s 或预烘焙 | 单线程实测 1.0–1.6 s（不含侵蚀） |
| 帧率验收 | 平均 ≥30 FPS，P95 ≤33.3 ms | 关闭垂直同步测；记录 P95 而非只看平均 |

---

## 7. 推荐 MVP：照着做的 9 步

### 7.1 目标与验收口径

**目标：** 1280×720（可选 1920×1080 离屏）、Godot 4.6、**GL Compatibility**、Intel HD 6000，生成一座 1024 m 的可走海岛；固定种子可复现；有海面、沙滩、草地、山脊、树/岩石；30 FPS+。

**验收清单：**

- [ ] 同 seed 两次生成的高度场 hash 完全一致；相邻 seed 明显不同。
- [ ] 陆地比例 20–45%；主岛占陆地 ≥90%；地图四周 50 m 内无陆地。
- [ ] 地形块之间**无可见裂缝/亮线**；相机贴地移动无闪烁。
- [ ] 碰撞贴合视觉：沙滩可走、悬崖挡住、海平面以下不可走（或游泳）。
- [ ] 水面：浅水→深水颜色过渡；岸线有泡沫；无 z-fighting；无大面积排序错误。
- [ ] 植被不悬空、不进水、不在陡壁；同 seed 分布一致。
- [ ] 1280×720 平均 ≥30 FPS，P95 ≤33.3 ms；生成 ≤2 s（或预烘焙加载 <300 ms）。
- [ ] 调试叠层：seed、FPS、三角数、draw calls、高度/坡度/岸线视图。

### 7.2 步骤（每步都有验证）

| 步 | 做什么 | 验证 |
| --- | --- | --- |
| 0 | 新建 4.6 项目：1280×720、GL Compatibility、Jolt（默认） | 能跑空场景 |
| 1 | 写 `heightfield.gd`：FastNoiseLite 基底 + warp + 岛屿 mask + 高度 LUT；输出 257² `PackedFloat32Array` | 控制台打印 land%、min/max、hash；二维预览正确 |
| 2 | 写 `mesh_builder.gd`：8×8 chunks、ArrayMesh、共享 NORMALS、可选裙边 | 灰模无裂缝；从上方可见（绕序正确） |
| 3 | 加材质：顶点色 + 简单光照；水下地形暗色 | 沙滩/草地/岩石可辨 |
| 4 | `HeightMapShape3D` 碰撞 + `CharacterBody3D` 玩家 | 走遍全岛不穿地、不卡缝 |
| 5 | 水面：PlaneMesh + Gerstner + 预生成 R8 深度图 + 泡沫 | 浅深色/岸线泡沫正确；无闪烁 |
| 6 | 植被/岩石：Poisson + 高度/坡度/湿度筛选 + MultiMesh | 不悬空/不进水；实例数达标 |
| 7 | 天空/方向光/Depth Fog/SSAO（可选）/Tonemap | 有空气透视；远景不糊成一片 |
| 8 | LOD/距离剔除 + 调试叠层 + 固定 seed 回归 | 30 FPS+；同 seed hash 一致 |
| 9 | 预烘焙（可选）+ 加载流程 + 性能采样 | 加载 <300 ms（预烘焙）或 <2 s（运行时） |

### 7.3 参数起点（可直接抄）

```ini
# 世界/高度场
world_size = 1024 m
height_samples = 257
sample_spacing = 4 m
sea_level = 0 m
island_radius_x = 420 m
island_radius_z = 380 m
mask_inner = 0.74
coast_power = 1.6
warp_strength = 55 m
base_amp = 46 m
ridge_amp = 28 m
sea_floor = -12 m
terrace_step = 0 (0–8 m 可选)
terrace_blend = 0.2

# 噪声
base_freq = 0.0025, octaves=5, lacunarity=2.0, gain=0.5
ridge_freq = 0.006, octaves=4
warp_freq = 0.004, octaves=3

# 网格
chunks = 8×8, quads_per_chunk = 32×32
triangles = 131,072
normals = central difference, spacing 4 m

# 水面
water_plane = 2048×2048 m, subdivisions 64×64
waves = 4 (见 §4.2)
depth_map = 512×512 R8, depth_range = 12 m
shore_foam_band = 0.08 (normalized depth)
water_shallow = #2FB7B0, water_deep = #0B3C5D

# 植被
tree_count = 1,500–2,000, min_spacing = 8 m, max_slope = 0.72
rock_count = 500–800, min_spacing = 4 m
moisture_freq = 0.0015, threshold = 0.45
```

### 7.4 种子与复现

- 所有噪声实例用固定 `seed`；布局/植被/岩石各用独立流（`seed+1/2/3`），避免“多一棵树导致全岛变”。
- 不用全局 `randi()`/`randf()`；只用 `RandomNumberGenerator`（显式 seed）。
- 记录：`seed + 参数 JSON + Godot 版本 + 算法版本`；存 `height_hash`（例如对 `PackedFloat32Array` 逐字节哈希）。
- 黄金样本：至少 20 个 seed，断言 land% 在 20–45%、主岛连通、高度 hash 不漂移。
- 跨引擎注意：FastNoiseLite 的浮点实现可能随版本/平台变化；不要拿 Unity/Three.js 的噪声结果做逐位比对，只做同引擎同版本回归。

### 7.5 主要坑清单（按出现概率排序）

1. **接缝**：块边缘顶点/法线不一致。→ 共享高度场与法线表，不用 `generate_normals()` 逐块。
2. **法线方向/绕序**：地形从上方不可见。→ 在 2×2 测试块确认顺时针；或先 `cull_disabled` 调试。
3. **LOD 裂缝**：裙边/缝合 + 距离滞后；不要用不同步长的块直接相接。
4. **碰撞缩放**：`HeightMapShape3D` 格点 1 m；用 scale 时先在 Jolt 下测试；更稳的是单独 1 m 碰撞场。
5. **GL Compatibility shader**：不要用 compute、SSR、体积雾；深度/屏幕纹理只在 fragment；要做 NDC 分支。
6. **透明排序**：水面 `depth_draw_never`、设置 render priority；不要把水放在透明物体堆里。
7. **顶点色偏暗**：sRGB→linear 转换；以截图为准。
8. **GDScript 生成慢**：257² 已是单线程 1 s 量级；侵蚀离线；并行时每线程独立噪声实例。
9. **MultiMesh 剔除**：单实例不剔除；按区块拆 MultiMesh 或接受整体 AABB。
10. **插件升级**：Terrain3D 2.0 不再支持 Compatibility；项目锁定 1.x。Voxel GPU 特性需 Forward+；v1.6 对应 4.6。

### 7.6 什么时候升级到 Terrain3D / Voxel

- **Terrain3D 1.x**：地图 >2 km、需要纹理绘制/植被实例化/区域流式、团队接受 GDExtension。目标机仍是 Compatibility 时**锁 1.x**。
- **Voxel Tools**：需要洞穴、悬垂、可挖掘。切 Forward+ 或接受 CPU 体素路径；v1.6 对应 Godot 4.6，v1.7 对应 4.7。
- **Gaea/Terrainy**：作为“高度图作者工具”，把结果导入自写网格或 Terrain3D，不必在运行时集成。

---

## 8. 案例与可移植参考

> 只记录公开可查证的项目/文档；许可以仓库 LICENSE 为准。不复制案例画面/素材进仓库。

### 8.1 Godot 生态（可直接看实现）

| 案例 | 类型 | 许可 | 效果亮点 | 对本文的用法 | 来源/访问日期 |
| --- | --- | --- | --- | --- | --- |
| **Terrain3D** | Godot 4 GDExtension | MIT | Witcher 3 式 clipmap 几何 LOD、区域、纹理数组、植被、碰撞；官方 demo 有大地形 | 生产级高度场路线；Compatibility 自 1.0 起支持；2.0 不再支持 Compatibility | [GitHub](https://github.com/TokisanGames/Terrain3D) · [Platforms](https://terrain3d.readthedocs.io/en/latest/docs/platforms.html) · 2026-11-21 |
| **HTerrain** | Godot 4 GDScript 插件 | MIT | 编辑器内雕刻/绘制、洞、LOD、草；4096×4096 | 小团队手工修地形；维护模式 | [GitHub](https://github.com/Zylann/godot_heightmap_plugin) · 2026-11-21 |
| **Voxel Tools** | Godot 4 C++/GDExtension | MIT | blocky + smooth Transvoxel、无限分页、物理、植被实例化 | 可破坏/洞穴路线；GPU 特性需 Forward+ | [GitHub](https://github.com/Zylann/godot_voxel) · [Docs](https://voxel-tools.readthedocs.io/en/latest/getting_the_module/) · 2026-11-21 |
| **LesusX/Water-Shader** | Godot 4 demo | MIT | 海岛场景 + Gerstner 波 + 焦散 + 泡沫 + 深度着色 | 水面 shader 的直接参考；4.5 测试，需在 4.6 复核 | [GitHub](https://github.com/LesusX/Water-Shader) · 2026-11-21 |
| **Gaea** | Godot 4 GDScript 节点图 | MIT | 节点图生成地形/洞穴，2D/3D | 高度图作者工具；2.0 早期 | [GitHub](https://github.com/gaea-godot/gaea) · 2026-11-21 |
| **Terrainy** | Godot 4 GDScript 插件 | MIT | 节点式地形，内置岛屿/火山/陨石坑、散布 | 快速做岛屿灰模；小社区 | [GitHub](https://github.com/fabian-becker/Terrainy) · 2026-11-21 |
| **SebLague/Godot-Marching-Cubes** | Godot 4 学习项目 | MIT | compute shader Marching Cubes | 只适合 Forward+ 学习，不可用于 Compatibility | [GitHub](https://github.com/SebLague/Godot-Marching-Cubes) · 2026-11-21 |

**仓库内可复用资产：**

- `godot-sea-water/`：预生成深度图驱动水色/泡沫/角色水线的思路（2D，但方法与本文 §4.1 一致）。
- `craft-island/`：Three.js 海岛视觉参考（非 Godot、非本任务代码来源）；其迭代记录里“先稳定高度场/泡沫阈值，再谈美术”的教训同样适用。
- 父报告 `docs/godot-procgen-survey.md`：FastNoiseLite、Poisson、MultiMesh、Compatibility 限制的通用结论。

### 8.2 非 Godot、可移植的经典方案

| 方案 | 引擎/出处 | 许可/状态 | 可移植点 | 来源/访问日期 |
| --- | --- | --- | --- | --- |
| **Procedural Landmass Generation** | Unity，Sebastian Lague | **MIT**（仓库） | 高度场 + 岛屿 falloff + LOD 分块 + 法线/接缝处理；算法与引擎无关 | [GitHub](https://github.com/SebLague/Procedural-Landmass-Generation) · 2026-11-21 |
| **Hydraulic Erosion** | Unity，Sebastian Lague | **MIT** | Droplet 水力侵蚀，可离线烘焙高度图 | [GitHub](https://github.com/SebLague/Hydraulic-Erosion) · 2026-11-21 |
| **Gerstner 水面** | GPU Gems 1, Ch.1 | 免费在线章节 | 多波 Gerstner、法线解析式；本文 §4.2 的公式来源 | [NVIDIA GPU Gems](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models) · 2026-11-21 |
| **Poisson Disk Sampling** | Bridson, SIGGRAPH 2007 | 论文/算法可自由实现 | O(n) 均匀点集；植被/岩石散布 | [论文 PDF](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf) · 2026-11-21 |
| **Transvoxel** | Eric Lengyel | 算法**无专利**；原始数据表有版权/署名要求 | 体素 LOD 缝合的经典方案；用表需在源码致谢 | [transvoxel.org](https://transvoxel.org/) · 2026-11-21 |
| **Marching Cubes** | Lorensen & Cline 1987 | 原始专利已过期；实现自由 | 体素等值面提取；注意 15 个拓扑 case/表版权 | 经典论文；实现参考公开教程 |
| **Three.js Water Pro 海岛（视觉参考）** | Three.js，Dan Greenheck | 商业扩展，**不复制** | 只作为“大海岛 + 船 + 浪”的视觉目标；仓库 `craft-island/` 为净室复刻 | 仓库 `craft-island/README.md` |

---

## 9. 来源表（URL + 访问日期）

> 全部访问日期：**2026-11-21**，除非另注。官方文档以 Godot **4.6** 分支为准。

### 9.1 Godot 官方

| # | 来源 | 用途 |
| --- | --- | --- |
| 1 | [Godot 4.6 Release](https://godotengine.org/releases/4.6/) | 4.6 版本页（社区报道发布日期 2026-01-26；Jolt 为新 3D 项目默认） |
| 2 | [FastNoiseLite (4.6)](https://docs.godotengine.org/en/4.6/classes/class_fastnoiselite.html) | 噪声类型/分形/域扭曲属性与默认值 |
| 3 | [Noise (4.6)](https://docs.godotengine.org/en/4.6/classes/class_noise.html) | `get_noise_2d/3d`、`get_image()` |
| 4 | [HeightMapShape3D (4.6)](https://docs.godotengine.org/en/4.6/classes/class_heightmapshape3d.html) | 1 m 格点、居中、NAN 洞、性能定位 |
| 5 | [ArrayMesh (4.6)](https://docs.godotengine.org/en/4.6/classes/class_arraymesh.html) | `add_surface_from_arrays()`、`create_trimesh_shape()` |
| 6 | [SurfaceTool (4.6)](https://docs.godotengine.org/en/4.6/classes/class_surfacetool.html) | `generate_normals/tangents`、`deindex` |
| 7 | [Using the ArrayMesh](https://docs.godotengine.org/en/4.6/tutorials/3d/procedural_geometry/arraymesh.html) | 数组布局/属性顺序 |
| 8 | [Using the SurfaceTool](https://docs.godotengine.org/en/4.6/tutorials/3d/procedural_geometry/surfacetool.html) | 逐顶点 API、法线/切线 |
| 9 | [MultiMesh optimization (4.6)](https://docs.godotengine.org/en/4.6/tutorials/performance/using_multimesh.html) | 一次 draw call、单实例不剔除、`visible_instance_count` |
| 10 | [Visibility ranges / HLOD (4.6)](https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html) | `visibility_range_begin/end`、距离 LOD |
| 11 | [Mesh LOD (4.6)](https://docs.godotengine.org/en/4.6/tutorials/3d/mesh_lod.html) | 导入网格 LOD；运行时网格需自行处理 |
| 12 | [Renderers / Compatibility limitations (4.6)](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html) | SSR/体积雾/SDFGI/VoxelGI/SSIL 不支持；SSAO/雾/Glow 支持 |
| 13 | [Shader preprocessor (4.6)](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/shader_preprocessor.html) | `CURRENT_RENDERER`、`RENDERER_COMPATIBILITY`（4.4+） |
| 14 | [Spatial shaders (4.6)](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html) | `hint_depth_texture` / `hint_screen_texture`；透明材质不写入 |
| 15 | [Godot issue #124537](https://github.com/godotengine/godot/issues/124537) | Compatibility 下 depth/screen texture 在 vertex 阶段不可用 |
| 16 | [GeometryInstance3D (4.6)](https://docs.godotengine.org/en/4.6/classes/class_geometryinstance3d.html) | `lod_bias`、`visibility_range_*` |
| 17 | [WorkerThreadPool (4.6)](https://docs.godotengine.org/en/4.6/classes/class_workerthreadpool.html) | 后台生成 |
| 18 | [Environment (4.6)](https://docs.godotengine.org/en/4.6/classes/class_environment.html) | Depth/Height Fog、Glow、Tonemap |
| 19 | [Image (4.6)](https://docs.godotengine.org/en/4.6/classes/class_image.html) | 高度图/岸线深度图 |
| 20 | [Color (4.6)](https://docs.godotengine.org/en/4.6/classes/class_color.html) | `srgb_to_linear()`（顶点色/材质颜色） |

### 9.2 插件、案例与非 Godot

| # | 来源 | 用途/核实 |
| --- | --- | --- |
| 21 | [Terrain3D GitHub](https://github.com/TokisanGames/Terrain3D) | MIT、4,782★、v1.1.0 2026-10-30、最近 push 2026-11-10 |
| 22 | [Terrain3D Platforms](https://terrain3d.readthedocs.io/en/latest/docs/platforms.html) | Compatibility 自 1.0/Godot 4.4 起支持；2.0 不再支持 |
| 23 | [Terrain3D Introduction](https://terrain3d.readthedocs.io/en/latest/docs/introduction.html) | Clipmap/几何 LOD、256 m 默认区域、1024 regions 上限 |
| 24 | [Terrain3D Collision](https://terrain3d.readthedocs.io/en/latest/docs/collision.html) | 动态/全量碰撞、射线/`get_height()`、敌人碰撞建议 |
| 25 | [Terrain3D Performance](https://terrain3d.readthedocs.io/en/latest/docs/performance.html) | 纹理 mipmap/压缩、区域、植被开销 |
| 26 | [Tokisan: GPU-driven workflow](https://tokisan.com/terrain3d-gpu-driven-workflow/) | 2.0 需要 compute（GL4.3+/D3D11/Vulkan），1.x 维护 Compatibility |
| 27 | [HTerrain GitHub](https://github.com/Zylann/godot_heightmap_plugin) | MIT、2,297★、Godot 4.6+、维护模式 |
| 28 | [HTerrain Asset Store](https://store.godotengine.org/asset/zylann/hterrain/) | Asset Store 版本（v1.8，2026-07 条目） |
| 29 | [Voxel Tools GitHub](https://github.com/Zylann/godot_voxel) | MIT、GDExtension 4.4.1+、v1.7 2026-08-20 |
| 30 | [Voxel Tools: Getting the module](https://voxel-tools.readthedocs.io/en/latest/getting_the_module/) | Module vs GDExtension；GPU 特性需 Forward+ compute |
| 31 | [Gaea GitHub](https://github.com/gaea-godot/gaea) | MIT、2.0 目标 Godot 4.4、早期开发 |
| 32 | [Terrainy GitHub](https://github.com/fabian-becker/Terrainy) | MIT、岛屿/火山/陨石坑节点、散布 |
| 33 | [LesusX/Water-Shader](https://github.com/LesusX/Water-Shader) | MIT、Gerstner/焦散/泡沫/深度着色、4.5 测试 |
| 34 | [SebLague/Godot-Marching-Cubes](https://github.com/SebLague/Godot-Marching-Cubes) | MIT、compute shader、Forward+ 限定 |
| 35 | [SebLague/Procedural-Landmass-Generation](https://github.com/SebLague/Procedural-Landmass-Generation) | Unity、MIT、高度场/LOD/岛屿 falloff 可移植 |
| 36 | [SebLague/Hydraulic-Erosion](https://github.com/SebLague/Hydraulic-Erosion) | Unity、MIT、droplet 侵蚀 |
| 37 | [GPU Gems 1 Ch.1](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models) | Gerstner 水面公式 |
| 38 | [Bridson Poisson Disk 2007](https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf) | O(n) Poisson Disk |
| 39 | [transvoxel.org](https://transvoxel.org/) | 算法无专利；数据表版权/署名要求 |
| 40 | [父报告 godot-procgen-survey.md](godot-procgen-survey.md) | Godot 4.6 通用程序化地图结论、Compatibility 限制、v1.6 对应 4.6 |

### 9.3 本文的确定性边界

- **已核实**：本地 Godot 4.6 `ClassDB` 属性/枚举/方法；FastNoiseLite 采样范围；高度场/法线/网格/碰撞/侵蚀的实测耗时；插件版本/许可/维护状态（GitHub API 与官方文档）；Compatibility 功能表；`CURRENT_RENDERER` 预定义。
- **推断/经验值**：具体噪声参数、岛屿尺寸、植被数量、Gerstner 参数、FPS 预算；这些是起点，不是跨机器保证。Intel HD 6000 的实际帧率必须用本文的验收脚本实测。
- **未做**：没有在本机跑完整 3D 海岛场景的 GPU 帧率；没有验证 Terrain3D/Voxel 在 Godot 4.6 + Compatibility + Intel HD 上的完整项目（只核实官方声明与版本）。落地前按 §7.1 做一次 30 分钟 spike。
- **版权**：本文不复制任何商业游戏画面、地形数据、贴图或代码；插件代码按其 LICENSE 使用；Transvoxel 表若使用需署名；案例只引用公开 URL 与文字结论。
- **交互版验证**：Chromium（Playwright）在 1920×1080 / 1280×720 / 390×844 三档打开，无 console error、无横向溢出；Canvas 同种子可复现；截图 2 张（`docs/shots/godot-3d-island-*.png`）。

---

## 10. 一页速查

```text
形状：1024m 岛 / 257² 高度场 / 椭圆 mask + 噪声 warp + smoothstep/pow
高度：SIMPLEX_SMOOTH FBM(0.0025, 5 oct) + RIDGED(0.006, 4 oct)*mask²
海岸：海平面 0 / 沙滩 0–2.5m 压平 / 岸线低频噪声 / 悬崖坡度限制
网格：8×8 chunks × 32×32 quads = 131k tris；共享高度场/法线；裙边防 LOD 裂缝
碰撞：HeightMapShape3D（1m 格点，必要时独立 1025² 碰撞场）；不要 trimesh 地形
水：Plane + 4 Gerstner + 预生成 512² R8 岸线深度图 + 泡沫；不要 SSR/体积雾
植被：2–4 MultiMesh / 1500–3000 实例 / Poisson + 高度/坡度/湿度；单实例不剔除
插件：Terrain3D 1.x（MIT，Compatibility，2.0 不支持）；HTerrain（维护）；Voxel v1.6 for 4.6（GPU 需 Forward+）
验收：同 seed hash 一致 / 无接缝 / 30 FPS+ P95≤33.3ms / 生成≤2s 或预烘焙
```

---

*本文为 T-20261121-022 的调研产出；相对父任务 T-20261121-020 新增了 3D 海岛的高度场/海岸/网格/碰撞/水面/植被/插件与 MVP 实测，不重复父报告的 2D 算法对比。*
