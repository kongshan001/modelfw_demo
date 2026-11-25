# 静水回廊 · Stillwater

一个 **Godot 4.6 / GL Compatibility / 2D** 的夜景技术 demo：用程序化像素画 +
CanvasItem 法线受光，把路边建筑、枫树、松树、石头照出真实的受光面；水面倒影
**不额外开相机、不开 Viewport、不做抓屏后处理**，而是一次镜像 Mesh 合批 +
一张水面 mask；水波用 `round()` 把 UV 位移量化成整像素，一格一格跳。

本项目只拆解 B 站视频里的数学/渲染思路，没有复制它的 Unity/C# 源码、视频帧、
场景或素材。所有像素图、法线图、粗糙度图、UI 与字幕都由本项目的 GDScript
在启动时原创生成。

参考视频（仅技术拆解）：

- 《硬核源码拆解｜拒绝塑料贴纸感！单人手搓 Unity 2D 像素法线受光 + 零额外相机水面夜景反射》
- UP：小武同学贼下饭
- <https://www.bilibili.com/video/BV1ePyizHED1>

---

## 运行

```bash
godot --path godot-pixel-normal-water
```

- Godot 4.6，GL Compatibility；默认窗口 1280×720。
- 世界只有 **320×180** 美术像素，Camera2D `zoom = 4`：1280 时每颗美术像素 4px，
  1920 时 `canvas_items` 再放大 1.5×，实际 6px（仍为整数）。
- 单张 `Camera2D`，0 个 `SubViewport`。倒影/水面/光照都在主 Viewport 完成。
- Intel HD Graphics 6000 实测：1280×720 世界层 314.9 FPS，带 HUD 246.8 FPS；
  1920×1080 世界层 119.0 FPS，带 HUD 109.7 FPS（关 VSync，详见下方）。
  HUD 里的 FPS 受 VSync 影响时显示 60；测试数据来自独立 probe。

## 操作

左侧参数面板全鼠标可操作，也可用键盘：

| 操作 | 说明 |
| --- | --- |
| 光方向 / 光强度 | 全局冷月光方向（0°=正上，90°=右）与强度 |
| 光色 [C] | 在「冷月 / 暮蓝 / 暖烛」三个预设间循环（同时带环境光/角度） |
| 法线受光 | 开/关 normal map 参与漫反射与高光 |
| 波速 / 波幅 / 量化格 | 水面倒影与波光的整行位移速度、幅度、量化步长 |
| 倒影 / 暖灯 | 单 Mesh 倒影 / 两盏街灯（灯芯、点光、暖色倒影） |
| 时流 | 0–2× 时间流速；Space 或暂停按钮真正冻结 shader 时间 |
| 调试叠加 [F] | 光向量、水面 mask 岸线、倒影四边形线框、量化水波刻度 |
| 法线视图 [V] | 把受光物件的 world normal 直接输出成 RGB |
| 暂停 [Space] | 暂停/继续动画（不影响 UI） |
| 重置 [0] | 恢复默认参数与时间 |
| ← / → | 光方向 −5° / +5° |
| ↑ / ↓ | 光强度 +0.08 / −0.08 |
| `[` / `]` | 波速 −0.1 / +0.1 |
| `-` / `=` | 波幅 −1 / +1 |
| H | 隐藏/显示左侧面板 |

面板实时显示 **FPS、总 draw calls、当前相机数（1）**，以及默认的
**6 个倒影四边形 / 1 个 Mesh surface**。调试模式打开后还显示光角/能量与当前
`round()` 位移。

## 主要参数

| 参数 | 默认 | 范围/固定值 | 说明 |
| --- | --- | --- | --- |
| 世界分辨率 | 320×180 | 固定 | 全部程序化像素图 1× |
| 相机 | 1 个 Camera2D | 1 | `zoom=4`；无 SubViewport |
| 光方向 | 35° | 0–360° | 0°=从正上方来，90°=从右侧来 |
| 光强度 | 1.18× | 0–2.4× | 冷月方向光能量 |
| 光色预设 | 冷月 | 冷月/暮蓝/暖烛 | RGB + 环境光 + 默认角度 |
| 暖灯 | 2 盏 | 点光 | 灯芯世界坐标 (113,78)/(185,78)，能量 2.0，半径 60，光高 22 |
| 波速 | 1.0× | 0–2.5× | 正弦相位速度 |
| 波幅 | 2 px | 0–4 px | 量化前的最大水平位移 |
| 量化格 | 1 px | 1–4 px | `round()` 后的整数步长 |
| 时流 | 1.0× | 0–2× | 暂停时全部 shader 时间冻结 |
| 倒影 Mesh | 1 surface | 6 quads / 36 verts | 共享 512×128 图集 |
| 水面 mask | 320×180 | 1-bit | 倒影与水波叠加共用 |
| 受光物件 | 11 | 固定 | 建筑 2、树 2、街灯 2、石岸/石头/码头/岸墙 |
| 光照材质 | 11 | — | 每个物件一张 normal + roughness + albedo |

## 截图

全部为 **原生 1920×1080** root viewport 截图（borderless 窗口，单 Camera2D，
非离屏 Viewport）：

| 文件 | 内容 |
| --- | --- |
| `docs/shots/01_night_wide.png` | 夜景全景 |
| `docs/shots/02_tavern_normal_light.png` | 酒馆法线受光特写（月光从右上） |
| `docs/shots/03_tavern_light_flip.png` | 同机位、光从左上，方向响应对比 |
| `docs/shots/04_reflection_closeup.png` | 暖窗/树/街灯倒影与水面裁切 |
| `docs/shots/05_quantized_wave_steps.png` | 4px 波幅 / 2px 量化的整格跳变 |
| `docs/shots/06_debug_normals_mesh.png` | 法线 RGB + 光向量 + 倒影四边形 + 量化刻度 |
| `docs/shots/07_reflection_mesh_wire.png` | 倒影 Mesh 线框特写 |
| `docs/shots/08_hud_panel.png` | 中文参数面板、FPS/draw calls/1 CAMERA |

10 秒带原创字幕的演示视频：

- `docs/normal_water.mp4`（1920×1080 / 30fps / 10.0s，H.264）
- `docs/normal_water.gif`（960×540 / 15fps / 10.0s）
- 源帧由 Godot Movie Maker 在 1280×720 录制；mp4 用 ffmpeg 最近邻放大到
  1920×1080。截图仍是原生 1920。HUD 在视频里隐藏，字幕来自 capture 工具。

## 自测 / 验收

```bash
# 无头 smoke（单相机/法线/倒影/round 量化/开关/暂停/重置/HUD）
godot --headless --path godot-pixel-normal-water -s tools/smoke_normal_water.gd

# 真实 GPU：原生 1920×1080 截图（8 张）
godot --path godot-pixel-normal-water -s tools/screenshot_normal_water.gd

# FPS / draw calls
godot --path godot-pixel-normal-water --resolution 1280x720 -s tools/probe_normal_water.gd
godot --path godot-pixel-normal-water -s tools/probe_normal_water_1080.gd

# 重新生成 10s MP4/GIF
godot-pixel-normal-water/tools/build_media.sh

# 一条龙：导入 + smoke + headless/GPU 600 帧 + 截图 + 两个 probe
godot-pixel-normal-water/tools/verify.sh
```

**已通过（2026-11-25，Godot 4.6，Intel HD Graphics 6000）**

- `NORMAL_WATER_SMOKE_OK checks=160`（末行）
- headless 600 帧启动：0 `SCRIPT ERROR` / `ERROR`
- 真实 GPU 600 帧启动：0 `SCRIPT ERROR` / `ERROR`
- 8 张 1920×1080 原生截图
- 10.0s MP4/GIF：1920×1080、960×540
- 1280×720：世界层 avg 314.9 FPS；含 HUD avg 246.8 FPS
- 1920×1080：世界层 avg 119.0 FPS；含 HUD avg 109.7 FPS
- Draw calls：世界层 17；含 HUD 81；`1 CAMERA`，`6 quads / 1 surface`

> 上面的 probe 在多个任务并行、系统负载较高时测量，读数会随运行环境波动；
> 即便在这种条件下也远高于 30 FPS 目标。

## 实现结构

```text
scenes/main.tscn            一个 Camera2D + World + HUD
scripts/main.gd             主控、状态、光照 uniform、调试/截图接口
scripts/pixel_art.gd        固定种子程序化像素画 + 法线/粗糙度/自发光
scripts/pixel_surface.gd    高度场→法线、宽形 normal bias、roughness/emission
scripts/reflection_field.gd 512×128 图集、6 quads、单 ArrayMesh surface
scripts/debug_overlay.gd    光向量/倒影线框/水波量化刻度
scripts/hud.gd              中文参数面板与 FPS/draw calls
shaders/lit_sprite.gdshader 法线正交拆解、方向光、点光、粗糙度高光
shaders/reflection.gdshader 镜像 UV、mask 裁切、round() 整格水波
shaders/water_overlay.gdshader 波光/月影/暖灯倒影的加法叠加层
tools/                      smoke / probe / screenshot / Movie Maker / verify
docs/TECH.md                公式、限制、性能
```

## 已知限制

- 这是 2D 平面水倒影：不是 SSR、不是真实反射；只镜像 6 个近岸物件，码头、
  前景石块、远景城镇不入倒影。
- 单 Mesh 透明表面的绘制顺序固定；当前布局刻意避免互相穿插。若移动物件，
  需要重新考虑前后顺序；项目没有实现按像素深度排序。
- 法线图是程序化生成（高度场 + 大形 normal bias），不是手绘/DCC 烘焙；
  方向受光可读，但不等同于美术逐像素绘制的法线。
- 水面 mask 是 1-bit 硬裁切，没有柔边或浑浊深度吸收。
- 运行时没有相机滚动；`focus_camera()` 只用于截图/视频工具取景。
- 1920 截图/probe 在 macOS 上用 borderless 根窗口完成，因为普通窗口会被桌面
  裁切；没有使用第二个 Viewport。视频源是 1280×720，再用最近邻放大到 1080p。
- UI 使用系统中文字体回退，未随项目分发字体。
- 无音频；演示素材只为了验证渲染与交互。
