# 池底光网 · Pool Caustics

Godot 4.6 / GL Compatibility 的可交互 Voronoi 焦散实验。用 **特征点格网 + 3×3 邻域 F1/F2** 的距离差生成池底青白光网，并把同一套核心应用到程序化圆石和熔岩变体。

所有代码、网格、材质、贴图、UI 都是本任务原创；公开教程只用于理解算法与视觉语言，没有复制作者场景、素材或代码。参考说明见 [CREDITS.md](CREDITS.md) 与 [docs/迭代记录.md](docs/迭代记录.md)。

## 快速运行

```bash
godot --path godot-pool-caustics
# 或指定窗口：
godot --path godot-pool-caustics --resolution 1280x720
```

- 逻辑分辨率 1280×720；截图工具用 1920×1080 SubViewport + HUD ×1.5。
- 启动时程序化生成河床贴图、22 块圆石和三个 shader material，约 0.7–1.0 s。
- 无需第三方运行时依赖；字体使用系统字体回退。

## 操作

| 操作 | 效果 |
| --- | --- |
| 左键点池底 | 光网在点击处局部聚光（约 3 秒内衰减） |
| 右键拖拽 | 受限环视（yaw ±12° / pitch 48–60°） |
| 滚轮 | 缩放（距离 12.8–17.2） |
| `1` / `2` | 池底光网 / 熔岩裂缝 |
| `K` | 单格测距 ↔ 3×3 邻域 |
| `D` | 循环 7 个调试视图 |
| `G` | 格网 + 特征点 |
| `W` | 坐标扭曲 |
| `B` | 交点鼓结 |
| `J` | 明暗聚散 |
| `L` | 宽柔光 |
| `U` | 水面微光 |
| `O` | 自动环视 |
| `Space` | 暂停 shader 时间 |
| `R` | 重置相机与全部参数 |
| `H` | 隐藏 UI |
| `Tab` | 收起 / 展开右侧面板 |

右侧中文面板可完成全部变体、调试、开关、连续参数和颜色操作。`FPS / DC` 在右上角实时显示。

## 参数

| 标签 | uniform | 默认 | 范围 | 说明 |
| --- | --- | --- | --- | --- |
| 密度 | `u_scale` | 0.72 | 0.35–2.50 | 世界单位 → 格子数，越大越密 |
| 线宽 | `u_width` | 0.050 | 0.008–0.110 | 亮纹宽度（格单位） |
| 软度 | `u_softness` | 0.95 | 0.10–1.40 | 宽柔光的扩散长度 |
| 亮度 | `u_brightness` | 1.00 | 0.30–2.20 | 光纹总亮度 |
| 流速 | `u_speed` | 0.46 | 0.00–1.60 | 漂移与噪声动画速度 |
| 流向 | `u_flow_angle` | -31° | -180–180° | 光网整体漂移方向 |
| 光纹色 | `u_line_color` | `#94FAF7` | 任意 | 点击色块选色，同时派生柔光色 |

变体预设会切换为该变体的推荐连续参数；四个构成开关的 on/off 状态保留。
(`#94FAF7` 对应 shader 内的 `(0.58, 0.98, 0.97)`。)

## 调试视图

| 按钮 | 内容 |
| --- | --- |
| 成片 | 最终光网 |
| F1 | 最近特征点距离（特征点处亮、边界暗） |
| F2 | 次近特征点距离 |
| F2−F1 | 距离差；边界归零，用指数映射显示为亮线 |
| 亮纹 | 只显示核心 beam mask |
| 格网 | 3×3 特征格网、特征点、最终光网的暗底叠层 |
| 扭曲 | 红/绿通道编码域扭曲的 X/Y 偏移量 |

单格模式是一个教学对照：每个像素只查询自己格子的一个特征点，因此看到等距圆环和硬格缝；此时没有有效 F2。HUD 会显示黄色提示。

## 场景

- 3D 世界空间石盆：程序化河床 PlaneMesh（40×31，2146 三角形），微微下凹。
- 640×640 河床贴图：`FastNoiseLite` 底色 + 软苔斑 + 118 颗手绘式卵石 + 砂粒，运行时生成并生成 mipmap。
- 22 块圆石（26,400 三角形）：3 个自建 UV 球变体，径向正弦扰动、平底、平滑法线；6 块主景石 + 岸边/前景石。
- 8 个世界空间圆形软阴影槽，避免真实阴影贴图开销。
- 很淡的可加性水面微光层（可关）和 2D 暗角/颗粒层；不做屏幕空间折射，以保证 Intel 集显性能。
- 池底 `pool_floor.gdshader` 与圆石 `pool_rock.gdshader` 共用 `caustics.gdshaderinc`。焦散在世界 XZ 上连续，圆石表面另加法线方向偏移，让光网自然包住石面。

## 媒体

- 10 秒 1920×1080 / 30 fps 演示：`docs/pool_caustics_10s.mp4`
- 10 秒 GIF（800 px / 12 fps）：`docs/pool_caustics_10s.gif`
- 11 张 1920×1080 截图：`docs/screenshots/`

| 截图 | 内容 |
| --- | --- |
| [01_pool_caustics](docs/screenshots/01_pool_caustics.png) | 池底光网总览 |
| [02_boulder_detail](docs/screenshots/02_boulder_detail.png) | 圆石特写 |
| [03_single_cell](docs/screenshots/03_single_cell.png) | 单格测距 / 格缝 |
| [04_f1_distance](docs/screenshots/04_f1_distance.png) | F1 最近距离 |
| [05_f2_distance](docs/screenshots/05_f2_distance.png) | F2 次近距离 |
| [06_f2_minus_f1](docs/screenshots/06_f2_minus_f1.png) | F2−F1 距离差 |
| [07_beam_mask](docs/screenshots/07_beam_mask.png) | 核心亮纹 mask |
| [08_grid_3x3](docs/screenshots/08_grid_3x3.png) | 3×3 格网 + 特征点 |
| [09_warp_field](docs/screenshots/09_warp_field.png) | 扭曲场 RGB 调试 |
| [10_lava_cracks](docs/screenshots/10_lava_cracks.png) | 熔岩裂缝变体 |
| [11_control_panel](docs/screenshots/11_control_panel.png) | 中文参数面板 / FPS / DC |

## 自测

```bash
cd godot-pool-caustics

# 无头 smoke（末行 POOL_CAUSTICS_SMOKE_OK）
godot --headless --path . -s tools/smoke_pool_caustics.gd

# 720p 实窗性能
godot --path . --resolution 1280x720 -s tools/probe_pool_caustics.gd

# 1080p 离屏性能
godot --path . -s tools/probe_pool_caustics_1080.gd

# 全量验收（导入 / smoke / 600 帧 / 截图 / 性能）
./tools/verify.sh

# 重新生成视频与 GIF
./tools/build_media.sh
```

本机 Intel HD Graphics 6000 实测（Godot 4.6 Compatibility）：

| 分辨率 | 平均 FPS | 帧时间 | Draw calls |
| --- | ---: | ---: | ---: |
| 1280×720，真实窗口 | 105.9 | 9.45 ms | 143（含 UI） |
| 1920×1080，离屏 | 58.2 | 17.19 ms | 143（含 UI） |

多次运行有系统负载波动：1280×720 为 94.6–105.9 fps，1920×1080 为 53.5–58.2 fps，均高于 30 fps。

`verify.sh` 末行：`POOL_CAUSTICS_VERIFY_OK`。详细数据、参考帧分析和已知差异见 [docs/TECH.md](docs/TECH.md) 与 [docs/迭代记录.md](docs/迭代记录.md)。

## 文件

```text
project.godot
scenes/main.tscn
scripts/main.gd              # 统一状态、变体、参数、输入
scripts/pool_world.gd        # 程序化石盆 / 圆石 / 水面微光
scripts/pool_camera.gd       # 受限环视 + 屏幕射线
scripts/riverbed_texture.gd  # 640² 程序化河床贴图
scripts/hud.gd               # 中文 HUD、参数、调试视图
shaders/caustics.gdshaderinc # Voronoi + F1/F2/F3 + beam 核心
shaders/pool_floor.gdshader
shaders/pool_rock.gdshader
shaders/water_veil.gdshader
shaders/vignette.gdshader
tools/smoke_pool_caustics.gd
tools/probe_pool_caustics.gd
tools/probe_pool_caustics_1080.gd
tools/screenshot_pool_caustics.gd
tools/capture_pool_caustics.gd
tools/verify.sh
tools/build_media.sh
```

## 已知差异

- 参考视频的场景、相机、石块布局与调色未复刻；这里是原创石盆构图。
- 参考教程最后 `510 s` 展示的是同思路的闪电/光带变体；本任务按规格改为熔岩裂缝，不复刻其闪电形态。
- 水面的处理是低强度可加性微光，不是物理正确的屏幕空间折射。
- 为了保持单次 9 格采样的性能，光网比参考视频略规整；可通过“扭曲”和“密度”参数进一步接近。
