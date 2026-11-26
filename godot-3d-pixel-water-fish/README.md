# 像素水塘 · Pixel Pond

一个 **Godot 4.6 / GL Compatibility / 3D** 的像素水景技术 demo：640×360 低分辨率
3D RT、最近邻整数放大、亮度/色度描边、色阶量化 + Bayer/噪声抖动、风格化水面
（深浅色阶 / 透明 / 屏幕折射 / 岸线泡沫 / 焦散 / 碎光 / 涟漪）、原创低多边形
鱼群与水下光柱。

参考了 B 站《做了水和鱼》（UP：迷茫Mmang_，BV1CDWE6WEmf）的**视觉语言与渲染思路**，
并致敬 t3ssel8r 的 3D 像素化方向。**没有**复制参考视频、作者或 t3ssel8r 的代码、
模型、贴图、音频。本项目的全部几何、shader、UI、程序化贴图均为原创。

参考：<https://www.bilibili.com/video/BV1CDWE6WEmf>（仅技术分析，未入库）

---

## 运行

```bash
godot --path godot-3d-pixel-water-fish
```

- Godot **4.6.stable**，**GL Compatibility**（Intel HD Graphics 6000 实测）。
- 默认窗口 1280×720；内部 3D RT **640×360**，整数 2× 最近邻放大。
- 窗口到 1920×1080 时为整数 3×；UI 在 root viewport 的 CanvasLayer 上，全分辨率、
  不经过像素化 RT。
- 无第三方运行时依赖；glTF 未使用，全部程序化生成。

### 自测与工具

```bash
# headless 冒烟（末行 WATER_FISH_SMOKE_OK）
godot --path godot-3d-pixel-water-fish --headless -s tools/smoke_water_fish.gd

# 真实 GPU 性能（关垂直同步；1280 + 1920 合成）
godot --path godot-3d-pixel-water-fish --position 50,50 -s tools/probe_fps.gd

# 真实 GPU 1920×1080 截图（写入 docs/shots）
godot --path godot-3d-pixel-water-fish --position 40,40 -s tools/capture_shots.gd
```

> 开发机屏幕为 1440×900，系统会限制 1920 窗口的渲染；截图工具用 1920×1080
> CaptureViewport 真实 GPU 合成（640 世界 3× + 1920 原生 HUD），不是事后放大。
> 10 秒视频由 Movie Maker 在 1280×720 录制后用最近邻放大到 1920×1080。

---

## 操作

| 操作 | 说明 |
| --- | --- |
| 鼠标左键拖动 | 轨道旋转（自动环绕会关闭） |
| 滚轮 | 拉近/拉远 |
| **V** | 水上 / 水下视角切换（相机 FOV 48°↔58°、水下雾/光柱渐显） |
| **Space** | 暂停/继续（时间、鱼群、水波、雨滴涟漪全冻结） |
| **F1** | 调试视图循环：低分辨率 RT / 深度 / 法线 / 描边 / 水面 Mask |
| **1 / 2 / 3** | 内部 320×180 / 480×270 / 640×360 |
| **T** | 时段预设循环：晨光 → 正午 → 黄昏 → 雨夜 |
| **P** | 调色板量化（亮度/色度 36 色）开关 |
| **G** | 自动环绕开关 |
| **R** | 复位视角与水上模式 |
| **H** | 隐藏/显示中文 HUD |

左侧面板可鼠标调节全部参数；面板实时显示 **FPS、draw calls、RT、鱼数量**。

---

## 主要参数（默认值）

| 参数 | 默认 | 范围 | 说明 |
| --- | --- | --- | --- |
| 内部分辨率 | 640×360 | 320×180 / 480×270 / 640×360 | 3D RT，整数倍最近邻放大 |
| 色阶 | 12 | 2–16 | 每通道量化级数 |
| 抖动 | 0.20 | 0–1.5 | Bayer + 哈希噪声的抖动强度 |
| 描边 | 1.0 | 0–2.5 | 亮度/色度 Sobel 边缘压暗 |
| 调色板 | 关 | 开/关 | 亮度 6 级 + 色度 5 级的 36 色量化 |
| 像素吸附 | 开 | 开/关 | 顶点 clip-space 网格吸附，移动相机不闪烁 |
| 透明度（清澈度） | 45% | 0–100% | 越高越能看见水底/鱼 |
| 深水色 | 30% | 0–100% | 深水暗度 |
| 折射 | 0.40 | 0–1.5 | 屏幕 UV 折射量 |
| 泡沫 | 0.45 | 0–2.0 | 岸线/岩石/涟漪泡沫 |
| 焦散 | 1.0× | 0–2.0 | 水底/鱼/水面的焦散光网 |
| 波纹 | 0.60 | 0–1.5 | 水面波纹与涟漪速度 |
| 鱼数量 | 20 | 6–36 | 3 种鱼，按 46% / 30% / 24% 分配（各至少 1） |
| 时段 | 0.42 | 0–1 | 太阳高度/方位/光色/雾/曝光关键帧 |
| 天气 | 晴 | 晴/雨 | 雨：雨丝、水面雨滴环、更厚雾、暗光 |
| 视角 | 水上 | 水上/水下 | 水下：FOV 58°，雾密度 0.17，光柱增强 |

### 时段预设

| 预设 | 时间 | 天气 |
| --- | --- | --- |
| 晨光 | 0.06 | 晴 |
| 正午 | 0.46 | 晴 |
| 黄昏 | 0.80 | 晴 |
| 雨夜 | 0.95 | 雨 |

---

## 渲染管线（简）

```text
root Window 1280×720 / 1920×1080
  ├── WorldViewport 640×360（3D：岛/水/鱼/光柱/气泡，水面内做屏幕折射）
  ├── CompositeViewport 640×360（canvas_item 后期：描边→调色→Bayer/噪声抖动→量化）
  ├── TextureRect（CompositeViewport 纹理，整数倍最近邻显示）
  └── HUD CanvasLayer（root viewport 全分辨率，中文 UI）
```

两段式 viewport 是 GL Compatibility 的兼容性选择：如果后期四边形也读
`hint_screen_texture`，水面（同样读屏幕纹理）会因 backbuffer 拷贝时机而不进入
后期；拆成 World → Composite 两段后，水面与鱼群才能完整进最终画面。

详细公式与踩坑记录见 [docs/TECH.md](docs/TECH.md)。

---

## 截图（全部原生 1920×1080，真实 GPU）

| 文件 | 内容 |
| --- | --- |
| `docs/shots/01_surface_wide.png` | 水上全景：青绿水面、草岛、白岸线、鱼群 |
| `docs/shots/02_fish_school.png` | 鱼群近景（锦鲤/青鳞/银灯） |
| `docs/shots/03_underwater.png` | 水下视角：光柱、水面顶棚、鱼与藻丘 |
| `docs/shots/04_caustics_foam.png` | 岛缘泡沫、岩石、焦散与浅水色阶 |
| `docs/shots/05_debug_lowres_rt.png` | 低分辨率 RT 原始像素 |
| `docs/shots/06_debug_depth.png` | 深度调试（材质覆盖热力图） |
| `docs/shots/07_debug_normals.png` | 法线调试（view-space RGB） |
| `docs/shots/08_debug_outline.png` | 描边 mask（亮度/色度边缘） |
| `docs/shots/09_golden_hour.png` | 黄昏暖光 |
| `docs/shots/10_night_rain.png` | 雨夜与水面雨滴环 |
| `docs/shots/11_hud_panel.png` | 中文 HUD：FPS / DRAW / RT / 鱼数量 |

10 秒演示：

- `docs/water_fish.mp4`（1920×1080 / 30fps / 10.03s / H.264，约 10 MB）
- `docs/water_fish.gif`（640×360 / 12fps / 10s，约 9 MB）

---

## 性能（Intel HD Graphics 6000，OpenGL 4.1，VSync 关）

| 场景 | 平均 FPS | 最低瞬时 FPS | Draw calls | 备注 |
| --- | --- | --- | --- | --- |
| 1280×720，640×360 RT，HUD 开 | **64.3** | 10.6 | 137 | 4 秒采样，含 HUD |
| 1920×1080 合成（640 3× + 1920 HUD） | **44.4** | 7.7 | 232 | 真实 GPU 1920 SubViewport；两个 HUD 的保守测量 |

- 平均帧率高于 30 FPS 目标；偶发最低瞬时帧来自 tiling GPU 的调度/测量毛刺，
  不是持续掉帧。
- 世界层 draw calls 约 **48–60**；HUD 控件约 90 个 draw call。
- 详细方法见 `docs/verification.txt`。

---

## 已知限制

- GL Compatibility 的 SubViewport 中 `hint_depth_texture` 实测恒为 0，所以**没有**
  屏幕空间深度/法线描边；描边用亮度/色度 Sobel + 鱼体 rim，深度/法线调试用材质覆盖。
- 没有实时阴影、SSR、SSAO；岛影为解析场偏移的假投影。
- 水面是解析风格化模型（场贴图 + 屏幕折射 + 泡沫/焦散/碎光），不是物理水体。
- 鱼群“通透水窗”是风格化处理：鱼附近降低水色占比，让橙/青更可读。
- 1920 截图使用 1920 CaptureViewport（开发屏 1440×900 限制）；视频由 1280 Movie
  Maker 录制后最近邻放大到 1920，世界内部仍是 640×360。
- 中文 UI 使用系统字体（PingFang SC 等），不同机器字形略有差异。

---

## 文档与致谢

- [docs/TECH.md](docs/TECH.md)：低分辨率 RT、像素稳定、量化/抖动、描边、水面公式、
  鱼动画/群游、两段式 viewport 的兼容性原因。
- [docs/迭代记录.md](docs/迭代记录.md)：参考帧分析、迭代过程、与参考的差异。
- [docs/agency/T-20261126-008.md](docs/agency/T-20261126-008.md)：实现说明、参数、
  文件清单、自测输出与风险。
- [docs/verification.txt](docs/verification.txt)：实际命令输出。
- [CREDITS.md](CREDITS.md)：原创声明、参考视频与 t3ssel8r 概念致敬、字体/引擎许可。
