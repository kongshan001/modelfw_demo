# 晨光农田 · 微缩沙盘（HD-2D）

一个 Godot 4.6 / GL Compatibility / 纯 2D 的可交互技术 demo：把“平面像素纸片 +
实时 2D 光影长影 + 不依赖 3D 深度缓冲的移轴景深”做成一个可调参的晨光农田。

只复刻技术/视觉语言，**没有**复制参考视频的 Unity/C# 源码、视频画面，也没有使用
《八方旅人》/Square Enix 的任何角色、场景、UI、素材或品牌。像素场景、角色、
灯笼、HUD 全部原创并在运行时程序化绘制。

参考：B 站《2d游戏怎么做出像八方旅人一样的质感？我教你！》· 小武同学贼下饭
<https://www.bilibili.com/video/BV1Auy5zzETe>（参考只用于拆解参数，不入库）。

---

## 运行

```bash
# 首次运行/拉取后先导入字体与资源
godot --headless --path godot-hd2d --import

# 交互版（1280×720 窗口；世界按 640×360 美术坐标 ×2 最近邻）
godot --path godot-hd2d

# 1920×1080 窗口（若显示器支持；世界按 ×3 最近邻）
godot --path godot-hd2d --resolution 1920x1080
```

- 渲染器：GL Compatibility；Godot 4.6。
- 逻辑设计：1280×720；`canvas_items` 拉伸。
- 像素：640×360 美术坐标 + Camera2D 整数 zoom + NEAREST + 2D 顶点/变换对齐。
- 无第三方运行时依赖；唯一外部文件是 SIL OFL 的 Noto Sans SC 子集（见 CREDITS）。

## 操作

| 输入 | 作用 |
| --- | --- |
| 右侧滑杆 | 焦点位置 / 焦带宽度 / 过渡羽化 / 模糊强度 / 散景半径 / 光方向 / 光强度 / 暖冷 |
| `B` 或“移轴”按钮 | 前后对比（关掉屏幕后处理，保留 2D 光影） |
| `N` 或“白天/夜晚”按钮 | 昼夜切换（灯笼、窗光、萤火、月光） |
| `Space` 或“暂停”按钮 | 冻结世界动画（角色、作物、水面、萤火、长影时间） |
| `H` | 隐藏/显示 HUD |
| `1` / `2` / `3` | 晨光 / 黄昏 / 夜灯 三组光照预设 |
| `R` | 恢复默认参数 |
| 鼠标拖动 | HUD 滑杆/按钮；HUD 在独立 CanvasLayer，不参与模糊 |

## 关键参数（默认值）

| 参数 | 默认 | 范围/说明 |
| --- | --- | --- |
| 焦点位置 `focus_y` | 0.60 | 屏幕纵向 0–1；0.60 = 屏幕 60% 高度 |
| 焦带半高 `band_half` | 0.14 | 焦内总高度 = 2×0.14 = 屏幕 28% |
| 过渡羽化 `feather` | 0.20 | 焦带边缘到最大模糊的过渡距离（UV） |
| 模糊强度 `strength` | 1.10 | 0–1.5 倍 |
| 散景半径 `radius_px` | 17 px | 0–40 屏幕像素 |
| 光方向 | -38° | -180°…180°；方向光旋转，长影同步转向 |
| 光强度 | 0.75× | 白天方向光；夜间等效月光 = ×0.34 |
| 暖冷 | +0.35 | -1 冷 → +1 暖；同时改变方向光与氛围色 |
| 白天环境色 | `#6b776c` | CanvasModulate；暖 +0.35 后约 `#84755c` |
| 夜晚环境色 | `#3b4661` | CanvasModulate |
| 灯笼点光 | 夜间 1.6 | 2 盏；带暖色 glow / 水面反光 |
| 窗光 | 夜间 0.42 | 2 盏小范围 PointLight2D |
| 萤火虫 | 26 | 夜间显示；暂停时冻结 |
| 世界尺寸 | 640×360 | 自动按视口高度整数放大（×2 / ×3） |
| HUD | 设计 1280×720 | 1920 截图中实际 1.5×，独立 CanvasLayer |

## 场景与技术点

- **世界**：农舍、四棵树、两盏灯笼、三块菜地（73 株独立作物）、灌木、干草、
  稻草人、水塘、木栈桥、前景草叶剪影、26 只萤火虫、往返农夫。
- **2D 光照**：`CanvasModulate` + `DirectionalLight2D` + `PointLight2D`；暖色
  环境光与月光/灯笼光分层；夜晚窗光与水面溢光。
- **长影**：在目标机 GL Compatibility 的 2D 阴影不输出，因此运行时检测渲染器：
  - GL 下使用**沿光向压扁的剪影 sprite**投影（原始像素剪影、实时随光角转向）；
  - Vulkan/Mobile/Forward+ 下自动启用 `DirectionalLight2D`/`PointLight2D` 真实阴影。
  详见 [docs/TECH.md](docs/TECH.md)。
- **移轴**：屏幕后处理 `BackBufferCopy + ColorRect`；纵向焦带；焦内 Point 采样
  早退，焦外 17 点双环散景（中心×4 + 内环 8×2 + 外环 8×1，权重和 28）。
- **UI 防糊**：氛围层 layer 2 → 后处理层 layer 10 → HUD layer 20；HUD 不被屏幕
  纹理采样，夜晚也不被 CanvasModulate 压暗。
- **像素完美**：所有世界 sprite 用 NEAREST，倍率为 2×/3×；HUD 文字在 1920 截图中
  按 1.5× 字号重新排版（不随世界放大而模糊）。

## 截图 / 媒体（`docs/`）

| 文件 | 内容 |
| --- | --- |
| `docs/shots/01_before.png` | 1920×1080，移轴关（原始像素） |
| `docs/shots/02_after.png` | 1920×1080，移轴开（同一机位/参数） |
| `docs/shots/03_focus_high.png` | 焦点上移 0.38，焦带 0.10 |
| `docs/shots/04_focus_low.png` | 焦点下移 0.76，焦带 0.09 |
| `docs/shots/05_light_angle.png` | 光方向 +38°（长影反向） |
| `docs/shots/06_night.png` | 夜灯/萤火/月光 |
| `docs/shots/07_dusk.png` | 黄昏暖色 |
| `docs/shots/08_ui.png` | 完整中文 HUD（独立层，不受模糊影响） |
| `docs/shots/09_ui_night.png` | 夜间 HUD（不被夜色/移轴压暗或模糊） |
| `docs/shots/10_before_after_compare.png` | 1920×1080 前后对比拼图（同一机位/状态） |
| `docs/hd2d_demo.mp4` | 10s / 1280×720 / 30fps |
| `docs/hd2d_demo.gif` | 10s / 800px / 15fps |

> 1920×1080 截图使用离屏 SubViewport 渲染（macOS 会将超出屏幕的窗口裁切）；
> 实际交互窗口默认 1280×720。

## 自测 / 验收

```bash
# 导入
godot --headless --path godot-hd2d --import

# headless 600 帧：无脚本错误
godot --headless --path godot-hd2d --quit-after 600

# smoke：75 项检查，末行 HD2D_SMOKE_OK
godot --headless --path godot-hd2d -s tools/smoke_hd2d.gd

# 真实 GPU 1280×720 性能（移轴开/关）
godot --path godot-hd2d --resolution 1280x720 -s tools/probe_hd2d.gd

# 1920×1080 离屏性能
godot --path godot-hd2d -s tools/probe_hd2d_1080.gd

# 重新生成 1920 截图与 10s 媒体
godot --path godot-hd2d -s tools/screenshot_hd2d.gd
godot-hd2d/tools/build_media.sh
```

### 已通过（2026-11-25）

- `godot --headless --quit-after 600`：0 `SCRIPT ERROR`。
- 真实 GPU（Intel HD 6000，OpenGL 4.1 / GL Compatibility）600 帧：0 错误。
- `HD2D_SMOKE_OK checks=75`。
- 9 张 1920×1080 截图 + 1 张前后对比拼图、10s MP4 + GIF。
- 1280×720（VSync off）：
  - 移轴开：平均 **195.1 FPS**，最低 74.6 FPS，153 draw calls；
  - 移轴关：平均 225.4 FPS，最低 104.8 FPS，151 draw calls。
- 1920×1080 离屏（同一 2.5s 探针）：
  - 移轴开：平均 **85.8–91.2 FPS**，瞬时最低 14.4–25.7 FPS，153 draw calls；
  - 移轴关：平均 94.7–116.2 FPS，瞬时最低 21.3–27.0 FPS，151 draw calls。
  - 离屏最低值对系统调度/读回很敏感；1280×720 交互档稳定远高于 30 FPS。
    详见 docs/TECH.md。

> 本机为 1440×900 屏幕，1920 截图/性能走离屏 SubViewport，因此 1920 的“最低帧”
> 包含系统调度/离屏读回抖动，不代表窗口交互档。

## 已知限制

- 目标机 GL Compatibility **不渲染 Light2D 阴影**（同一场景在 Vulkan Mobile 下
  阴影正常）；因此 GL 下改用剪影投影长影，保留 LightOccluder2D 与真实阴影代码路径。
- 剪影长影是屏幕平面的艺术近似：它不遮挡灯笼点光，也不会在作物/道具上继续二次投影。
- 只有 1 个完整场景（晨光农田）+ 白天/黄昏/夜灯三组状态；未做第二个森林湖场景。
- 字体为 Noto Sans SC 的 UI 字符子集；改 HUD 文案后需重新生成子集，否则缺字。
- 无音频、无外部图片（字体除外）、无第三方运行时插件。
- 参考视频的焦带/散景参数是从 360×640 压缩画面里读到的近似值；本 demo 按自己的
  构图重新标定（焦点 0.60、焦带半高 0.14、半径 17px），并非逐参数照搬。

## 文档 / 许可

- [docs/TECH.md](docs/TECH.md) — 光照、长影公式、移轴公式、17 点散景、UI 分层、
  GL Compatibility 限制、像素对齐、性能。
- [docs/迭代记录.md](docs/迭代记录.md) — 参考抽帧、GL 阴影失败实验、三轮视觉调整、
  验收数据与已知问题。
- [CREDITS.md](CREDITS.md) — 参考来源、原创声明、字体 OFL。
- `assets/fonts/OFL-NotoSansSC.txt` — Noto Sans SC 的 OFL 1.1 许可。
