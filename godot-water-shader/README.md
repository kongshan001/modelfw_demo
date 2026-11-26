# 潮汐花园 · Tidal Garden

一个 **Godot 4.6 / GL Compatibility / 2D 像素** 水面 Demo：海、河、内陆湖共用 **1 个全屏水面 Shader**，没有额外水面网格，也不建全图高清 RT。

岸线来自手绘像素 mask；运行时按 **16px 格**降采样抠图，用 **2-Pass 8 邻域倒角距离**求连续水深，再用 **预分配队列 BFS** 自动分成海 / 河 / 内陆湖。内陆湖（不贴地图边界）自动关闭海浪与焦散。同一套水面逻辑还复用在雨天低洼积水与雨点涟漪上。

![全景](docs/shots/01_wide.png)

![浅滩](docs/shots/06_shallow_foam.png)

![双波前特写](docs/shots/14_wavefront_islet.png)

![雨积水](docs/shots/08_rain_closeup.png)

## 快速运行

```bash
# 在仓库根目录
godot --path godot-water-shader

# 1920×1080 窗口（世界仍按 1280×720 逻辑渲染后放大）
godot --path godot-water-shader --resolution 1920x1080
```

- Godot **4.6**，渲染后端 **GL Compatibility**，无第三方运行时依赖。
- 默认窗口 1280×720，逻辑世界 1280×720；屏幕比例保持 16:9。
- 首次启动会程序化生成像素场景并烘焙水面数据，空载约 2–4 秒（并行负载下 5–8 秒）；随后启动很快。

## 操作

| 操作 | 功能 |
| --- | --- |
| 空格 | 暂停 / 继续水面时间 |
| 1 / 2 / 3 | 观察 海域 / 河流 / 内陆湖（相机推近，并高亮该类水体） |
| 0 / Esc | 回到全部水体 |
| R | 开 / 关降雨 |
| F | 循环调试视图：关闭 / 水体掩码 / 水深场 / 水体类别 / 岸线 |
| B | 重建数据管线（输出可复现） |
| N | 重置所有参数与时间 |
| H | 收起 / 展开面板 |
| T | 潮汐在 0% / 100% 之间切换（快捷演示） |

面板滑杆：

- **潮汐**：移动岸线切分阈值，并改变波前推进距离。
- **流速 / 浪幅 / 泡沫 / 焦散**：全局倍率，叠加在海 / 河 / 湖各自的基础预设上。
- **雨量**：雨丝、雨点涟漪和低洼积水的强度。

面板实时显示 **FPS、draw calls、水体数量与各自覆盖率、时间、雨量、观察目标、调试视图**。

![面板](docs/shots/02_panel.png)

## 三水体参数预设

| 水体 | 浪幅 | 流速 | 泡沫 | 焦散 | 说明 |
| --- | --- | --- | --- | --- | --- |
| 海域 | 1.00 | 0.55 | 1.00 | 1.00 | 双波前、Voronoi 焦散、向岸流动 |
| 河流 | 0.32 | 1.35 | 0.50 | 0.60 | 单向主轴流动，桥下连通 |
| 内陆湖 | 0.05 | 0.00 | 0.07 | 0.00 | BFS 判定不贴边 → 关海浪 / 关焦散 |
| 积水 | 0.02 | 0.00 | 雨控 | 0.00 | 复用同一水面 shader 的薄水膜 + 雨点涟漪 |

滑杆是全局倍率；切换海 / 河 / 湖只改变观察机位与高亮，不改变 BFS 分类。

![海](docs/shots/03_sea_caustics.png)

![河与桥](docs/shots/04_river_bridge.png)

![湖](docs/shots/05_lake_calm.png)

## 数据管线（3 步）

1. **16px 抠图**：手绘 mask 为 1280×720；每个 16px 格做 8×8 子采样，得到覆盖率和硬水格。桥面格从绘制 mask 中挖掉，但保留“桥下水体”标志用于连通。
2. **2-Pass 8 邻域水深**：直向 ×1、斜向 ×1.414 的倒角距离变换；输出 `R = 1-exp(-d/3.2)` 的展示水深，`G = d/16` 的距岸格数（供双波前使用）。
3. **零分配 BFS 分类**：一次性分配的队列 / 访问表 / 统计数组；按“是否贴图边 + 平均宽度”分类：不贴边 → 内陆湖；贴边且平均宽度 < 9.5 格 → 河流；否则 → 海域。

管线输出可直接查看与重建：

- `docs/pipeline/mask.png`（R 硬水 / G 覆盖率 / B 桥面 / A 桥下水体）
- `docs/pipeline/depth.png`（R 显示水深 / G 距岸格数）
- `docs/pipeline/category.png`（R = 类别 × 0.25）
- `docs/pipeline/flow.png`（RG 方向）
- `docs/pipeline/puddle_mask.png`、`docs/pipeline/puddle_depth.png`
- `docs/pipeline/meta.json`（类别统计、哈希、单元尺寸）
- `docs/pipeline/source_mask_1280.png`（手绘源 mask）

实测：水体 3 个；海 888 格（68% 水体）、河 210 格（16%）、湖 216 格（16%）；低洼 88 格；桥面裁切 57 格。

![掩码](docs/shots/09_debug_mask.png)

![水深](docs/shots/10_debug_depth.png)

![类别](docs/shots/11_debug_category.png)

![岸线](docs/shots/12_debug_shoreline.png)

![桥面裁切](docs/shots/13_debug_bridge_cutout.png)

## 单水面 Shader

场景里只有：

- 地面 `Sprite2D`（静态像素图）
- **一个** 1280×720 的 `ColorRect`（唯一水面绘制节点，挂 `water_surface.gdshader`）
- 前景 `Sprite2D`（桥、栈桥、芦苇、睡莲、小船，位于水面之上）
- HUD `CanvasLayer`

没有 `MeshInstance2D` / `Polygon2D` 水面，也没有 `screen_texture`。浅滩沙底、鹅卵石、焦散、白沫、雨积水全部在同一个 fragment shader 里合成。smoke 会断言水面材质只被一个节点使用。

## 自测

```bash
# 无头规则验收（末行 WATER_SHADER_SMOKE_OK）
godot --headless --path godot-water-shader -s tools/smoke_water_shader.gd

# 无头 / 真实 GPU 启动 600 帧，扫描 ERROR
godot --headless --path godot-water-shader --quit-after 600
godot --path godot-water-shader --resolution 1280x720 --quit-after 600

# 1920×1080 截图（14 张）
godot --path godot-water-shader -s tools/screenshot_water_shader.gd

# 性能探针
godot --path godot-water-shader --resolution 1280x720 -s tools/probe_water_shader.gd
godot --path godot-water-shader -s tools/probe_water_shader_1080.gd

# 一键
godot-water-shader/tools/verify.sh

# 10 秒 GIF / MP4（较慢，单独跑）
godot-water-shader/tools/build_media.sh
```

当前结果：

- smoke：`WATER_SHADER_SMOKE_OK checks=119`，包含斜向 1.414 合成用例、桥下连通、三预设、雨积水复用、重置、重建可复现。
- 无头 / 真实 GPU 600 帧启动：`SCRIPT ERROR / ERROR:` 均为 0。
- 截图：14 张 **1920×1080**，位于 `docs/shots/`（含双波前礁石特写）。
- 视频：`docs/water_shader.mp4`（10s，1920×1080，30fps，7.5MB）、`docs/water_shader.gif`（10s，960×540，15fps，13MB）。

## 性能（Intel HD 6000 / GL Compatibility / VSync off）

| 场景 | 平均 FPS | 1s 采样区间 | draw calls |
| --- | ---: | ---: | ---: |
| 1280×720 世界 + 满雨 | 172.7 | 168–178 | 4 |
| 1280×720 世界 + 满雨 + HUD | 158.1 | 157–160 | 67 |
| 1920×1080 离屏 + 满雨 | 142.6 | 141–147 | 4 |
| 1920×1080 离屏 + 满雨 + HUD | 113.9 | 117–124 | 67 |

以上为最终 verify 在并行任务负载下的实测；较轻负载时曾测到 194 / 170（720p）与 151 / 133（1080p）。所有场景平均 FPS 最低 113.9，仍远高于 30fps。水面绘制节点始终为 **1**。1280×720 逻辑在世界层渲染，1920×1080 通过显示放大（像素风）。

## 目录

```
godot-water-shader/
├─ project.godot
├─ scenes/main.tscn
├─ scripts/
│  ├─ main.gd               主控 / 相机 / HUD 接线
│  ├─ water_pipeline.gd     mask→覆盖率→8 邻域 depth→BFS 分类→数据纹理
│  ├─ water_controller.gd   三预设 / 全局倍率 / uniform
│  ├─ pixel_art.gd          原创程序化像素场景 + 手绘式 mask
│  └─ hud.gd                中文面板 / 调试视图 / 字幕
├─ shaders/water_surface.gdshader   唯一水面 shader
├─ tools/                   smoke / 截图 / 视频 / 性能 / 一键验收
├─ docs/
│  ├─ TECH.md               算法、shader 公式、桥面裁切、雨积水、性能
│  ├─ 迭代记录.md           参考帧观察、实现迭代、修复与调参
│  ├─ agency/T-20261126-001.md  程序实现报告
│  ├─ pipeline/             80×45 数据纹理 + meta（可重建比对）
│  ├─ shots/                14 张 1920×1080 截图
│  └─ water_shader.mp4/.gif
├─ README.md
└─ CREDITS.md
```

## 许可与参考

- 代码与全部像素素材均为本任务原创；场景由 `pixel_art.gd` 以固定种子程序化绘制。
- 技术参考：B 站《2D游戏海河湖共用1个水面Shader？零额外网格源码拆解》（UP：小武同学贼下饭，https://b23.tv/KYEA6ng）。仅用于理解算法与视觉语言；未复制 Unity/C# 源码、视频画面或素材。参考视频只下载到 `/tmp` 做抽帧分析。
- 中文字体使用 `SystemFont`（PingFang SC / Noto Sans CJK 等系统回退），不随项目分发字体文件。
- 无第三方运行时库。

详细公式与验证见 [docs/TECH.md](docs/TECH.md)，迭代过程见 [docs/迭代记录.md](docs/迭代记录.md)。
