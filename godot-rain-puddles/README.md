# 雨落青苔 · Rain Puddles

一个 Godot 4.6 / GL Compatibility / 2D 的**像素雨天积水**技术 demo，复刻
B 站教程《unity中怎么做出雨天积水？我教你！》里的*技术与视觉语言*，不是复制原作：

- 360 条渐变雨丝，**不用粒子系统**，用一张动态 `ArrayMesh` 合批（雨丝 1 draw call）。
- 72 组双环扩散涟漪，`MultiMesh` 合批（涟漪 1 draw call）。
- 低洼盆地噪声生成水洼；大雨约 **22s 积满**，雨停约 **75s 渗干**（默认速度）。
- 红枫 / 松树 / 暖灯倒影进入水洼，被**同一份 puddle mask** 裁切；水面有像素级扰动。
- 灯柱 **1×1 格放行积水**规则：细灯柱脚下不产生方形干边；大石头/石岸才会挡水。
- 画布 1280×720；世界 640×360 最近邻放大；1920×1080 截图与实测（见下）。
- 所有像素素材由 GDScript 在启动时程序化绘制，无外部贴图、无第三方运行库。

参考视频（仅技术拆解，未复制任何素材/代码）：
<https://www.bilibili.com/video/BV11DyDzjE7c>（UP：小武同学贼下饭，3:16）

---

## 运行

```bash
godot --path godot-rain-puddles
```

- 默认 1280×720，垂直同步；内部世界 640×360，2× 最近邻放大。
- 期望环境：Godot 4.6，GL Compatibility，Intel HD 6000 级别核显。
- 窗口拉伸/全屏到 1920×1080 也可（canvas_items 拉伸，UI 跟随放大）。

## 操作

| 操作 | 说明 |
| --- | --- |
| 左侧面板 | 雨强 / 雨丝密度 / 风 / 雨速 / 雨长 / 积水速度 / 渗干速度 |
| 涟漪 / 倒影 / 网格 | 开关双环涟漪、倒影层、灯柱-遮挡格调试叠加 |
| 暂停 / 重置 | 暂停动画（rain/涟漪/积水）；恢复默认参数并从干地开始 |
| Space | 暂停 / 继续 |
| R | 重置 |
| H | 隐藏 / 显示 UI |
| F3 | 灯柱规则网格 |

面板里同时显示 FPS、总 draw calls、当前雨丝数、涟漪数、水位与状态
（积水中 / 满水 / 渗干中 / 干燥）。

## 关键参数

| 参数 | 默认 | 范围 | 说明 |
| --- | --- | --- | --- |
| 雨丝密度 | 360 | 60–600 | 动态 mesh 的条带数量 |
| 雨强 | 85% | 0–100% | 影响雨丝透明度/速度/涟漪频率；0 即雨停 |
| 风 | 0.26 | -0.6–0.6 | 横向漂移 = wind × 300 px/s（世界坐标） |
| 雨速 | 1.0× | 0.4–2.0× | 650–1010 px/s 基准速度的倍率 |
| 雨丝长度 | 1.0× | 0.5–1.8× | 22–52 px 基准长度的倍率 |
| 积水速度 | 1.0× | 0.25–4.0× | 雨强 100% 时 22s 满水；默认 85% 约 26s |
| 渗干速度 | 1.0× | 0.25–12.0× | 无雨时 75s 从满到空 |
| 涟漪池 | 72 | 固定 | 目标数量 = 72 × 雨强 |
| 水洼场 | 320×180 | 固定 | 每 texel = 2 世界像素 |
| 灯柱格 | 1×1（16×16 px） | 固定 | 放行积水；见 `TECH.md` |

积水模型：`intensity > 0.01` 时 `wet += dt × intensity × fill / 22`，否则
`wet -= dt × drain / 75`；`wet` 经 `pow(wet, 0.40)` 映射到水线，让前段先漫过
深盆、后段慢慢啃浅边，整段过程都可读。**时间口径仍然是 22s / 75s。**

## 自动验收

```bash
# 无头 smoke：雨丝数量/无粒子/22s+75s/灯柱规则/72 双环/倒影开关/重置/HUD
godot --headless --path godot-rain-puddles -s tools/smoke_rain_puddles.gd

# 1920×1080 截图（9 张，写到 docs/shots/）
godot --path godot-rain-puddles -s tools/screenshot_rain_puddles.gd

# 720p 原生窗口 / 1080p 离屏 FPS + draw calls
godot --path godot-rain-puddles --resolution 1280x720 -s tools/probe_rain_puddles.gd
godot --path godot-rain-puddles -s tools/probe_rain_puddles_1080.gd

# 一条龙：导入 + smoke + headless/GPU 600 帧 + 截图 + 两个探针
godot-rain-puddles/tools/verify.sh

# 重新生成 10s 演示 MP4 / GIF
godot-rain-puddles/tools/build_media.sh
```

**已通过（2026-11-25，Intel HD 6000）**

- `RAIN_PUDDLES_SMOKE_OK checks=73`
- headless 600 帧、真实 GPU 600 帧：日志 0 个 `SCRIPT ERROR` / `ERROR`
- 9 张 1920×1080 截图（`docs/shots/`）
- 10s MP4 + GIF（`docs/rain_puddles.mp4` / `.gif`）
- `RAIN_PUDDLES_VERIFY_OK`

### 性能实测（关闭 VSync，GL Compatibility）

| 场景 | 平均 FPS | 最低 FPS | Draw calls |
| --- | --- | --- | --- |
| 1280×720，世界层，360 雨丝 | 217.9 | 211.4 | 11 |
| 1280×720，世界层，600 雨丝 | 207.9 | 207.9 | 11 |
| 1280×720，含 HUD | 180.8 | 178.8 | 59 |
| 1920×1080，离屏世界层 | 153.8 | 134.7 | 11 |
| 1920×1080，离屏含 HUD | 141.0 | 140.6 | 59 |

> 说明：macOS 会把超过桌面尺寸的窗口裁到 1440×762，因此 1080p 用
> 1920×1080 的 SubViewport 离屏渲染测量。世界 draw calls 11 = 地面 1 +
> 水面合成 1 + 涟漪 1 + 4 个道具 + 灯笼辉光 1 + 雨丝 1 + 前景 1 + 世界显示 blit 1。
> 雨丝 + 涟漪正是参考里常说的“2 个 DrawCall”；HUD 元素较多，总计 59。
> 调试网格全开时 draw calls 约 121。数字来自
> `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`，不是估算。

## 文件结构

```
godot-rain-puddles/
├─ project.godot
├─ scenes/main.tscn
├─ scripts/
│  ├─ main.gd           主控：世界、水位、UI 接线、测试入口
│  ├─ puddle_field.gd   低洼场 + 占位/灯柱规则 + CPU mask
│  ├─ pixel_art.gd      原创像素地面/红枫/松树/灯柱/倒影图集/前景
│  ├─ rain_field.gd     动态 ArrayMesh 雨丝（1 call）
│  ├─ ripple_field.gd   MultiMesh 双环涟漪（1 call）
│  ├─ debug_grid.gd     挡水格 / 灯柱 1×1 放行格的调试叠加
│  ├─ hud.gd            中文参数面板 / FPS / draw calls / 状态
│  └─ rain_layout.gd    场景布局与盆地/灯柱/石头数据
├─ shaders/
│  ├─ water_mask.gdshaderinc  水面/涟漪共用的统一裁切函数
│  ├─ water_surface.gdshader  湿边/水色/倒影/水际高光
│  ├─ ripple.gdshader         涟漪裁切
│  └─ rain.gdshader           雨丝顶点色直出
├─ tools/
│  ├─ smoke_rain_puddles.gd
│  ├─ screenshot_rain_puddles.gd
│  ├─ capture_rain_puddles.gd
│  ├─ probe_rain_puddles.gd
│  ├─ probe_rain_puddles_1080.gd
│  ├─ verify.sh
│  └─ build_media.sh
├─ docs/
│  ├─ TECH.md
│  ├─ 迭代记录.md
│  ├─ agency/T-20261125-004.md
│  ├─ shots/*.png（1920×1080）
│  ├─ rain_puddles.mp4 / .gif
├─ README.md
└─ CREDITS.md
```

## 已知限制

- 倒影是**启动时烘焙的镜像图集**，不是实时平面反射 / SSR：静态场景足够漂亮且
  在 GL Compatibility 上很便宜，但动态角色不会自动入水；需要重烘或换实时方案。
- 低洼场是固定 seed 生成的静态 mask；运行时改变地形/摆放道具不会重算水洼。
- 1×1 灯柱规则是简化 tile 规则，不是完整的 TileMap 占用系统。
- 世界内部固定 640×360；1080p 是 3× 最近邻放大（像素风，不追求高清细节）。
- 录制 MP4/GIF 时逐帧存 PNG 会拉低实时帧率，所以演示视频隐藏了实时 FPS 数字；
  截图和真实运行仍显示 FPS/draw calls。
- 参考视频只用于技术拆解；没有复制 Unity 工程、C#/HLSL 代码、视频帧或素材。

更细的公式、draw call 拆分、GL Compatibility 取舍见 [docs/TECH.md](docs/TECH.md)。
