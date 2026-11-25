# TECH · 晨光农田 / HD-2D 质感复刻

本文记录 `godot-hd2d` 的实现方式、关键公式、GL Compatibility 下的取舍和性能数据。
参考视频只提供技术拆解；所有场景/角色/UI/贴图均为原创程序化绘制，不包含
Unity/C# 源码或视频素材。

## 1. 总体渲染顺序

```
Main (Node2D)
├─ Camera2D                     整数 zoom：视口高 / 360
├─ World (HD2DWorld)            640×360 美术坐标
│   ├─ CanvasModulate           环境色（日/夜/暖冷）
│   ├─ Ground / Water / Props   NEAREST sprite；独立 z 排序
│   ├─ 长影剪影 / 接触影         unshaded，z=-450 / -449
│   ├─ DirectionalLight2D       太阳/月亮
│   ├─ PointLight2D ×2          灯笼
│   ├─ PointLight2D ×2          窗光
│   ├─ 农夫 + 动画 + 手提灯
│   └─ 萤火虫 / 作物摆动
├─ CanvasLayer 2  Atmosphere    屏幕暖晕 + 暗角
├─ CanvasLayer 10 TiltShift     BackBufferCopy + ColorRect
└─ CanvasLayer 20 HUD           中文控件，位于后处理之上
```

- 世界为纯 2D；**没有使用 3D 深度缓冲或任何 3D 相机**。
- `CanvasModulate`、天光、灯笼都作用于世界 canvas；HUD 在独立 CanvasLayer，不参与
  灯光/后处理。
- 视角固定；没有摄像机移动，保证微缩模型的稳定构图。

## 2. 像素完美与分辨率

| 项 | 值 |
| --- | --- |
| 美术坐标系 | 640×360 |
| 相机位置 | (320, 180)，无平滑 |
| 相机 zoom | `viewport_height / 360`：720p=2×，1080p=3× |
| 纹理过滤 | 世界 sprite = NEAREST；灯光/glow = LINEAR |
| 对齐 | `snap_2d_transforms_to_pixel` + `snap_2d_vertices_to_pixel` |
| 后处理采样 | `hint_screen_texture, filter_nearest` |
| 2D MSAA | GL Compatibility 不支持，关闭；用硬边像素风 |

常规窗口使用 `canvas_items` 拉伸；1280×720 下世界实际为 2×，1920×1080 截图使用
离屏 SubViewport，世界为 3×。HUD 在 1080 截图场景中以 1.5× 字号重新排版，
不是把 1280 的整张 UI 放大，因此截图文字仍清晰。

## 3. 2D 实时光照

### 3.1 环境色（CanvasModulate）

| 状态 | 颜色 |
| --- | --- |
| 白天中性 | `#6b776c` |
| 白天暖 +1 | 向 `#84755c` 插值 |
| 白天冷 -1 | 向 `#7d9099` 插值 |
| 夜晚 | `#3b4661` |

方向光颜色在 `#fff0d2`（中性）、`#ffc46e`（暖）、`#b9d4ff`（冷）之间按
暖冷参数插值；夜晚再向 `#9db4e8` 插值 78%。

### 3.2 方向光与点光

- 方向光旋转角 `θ`（度）；Godot `DirectionalLight2D` 沿 +Y 发光，屏幕方向：
  `d = (-sin θ, cos θ)`。默认 θ=-38°，光从左上射向右下，长影朝右下。
- 白天方向光能量 = UI 光强度；夜晚 ×0.34（月光）。
- 灯笼：`PointLight2D`，128×128 径向衰减纹理，夜晚能量 1.6，颜色 `#ffb45f`；
  附一个加色 glow sprite。
- 窗光：小范围 `PointLight2D` ×2，夜晚 0.42，颜色 `#ffbc64`。
- 农夫夜间携带一盏小手提灯（无阴影的 PointLight2D）。
- 灯光纹理做了 1/40 的 alpha 台阶，避免平滑渐变完全失去像素感；sprite 本体仍是硬像素。

### 3.3 长影：真实 Light2D 阴影 + GL 兼容回退

参考视频使用 URP 2D 的实时阴影。本项目先按 Godot 标准实现：

- `LightOccluder2D` + `OccluderPolygon2D`（房/树冠/树干/灯笼/稻草人/农夫，世界内 14 个，
  另有农夫自带 1 个）；
- `DirectionalLight2D.shadow_enabled` / `PointLight2D.shadow_enabled`。

**实测限制**：在本任务目标机（Godot 4.6 stable，macOS，Intel Iris/HD 6000，
OpenGL 4.1，GL Compatibility）下，即使最小隔离场景也**不输出任何 2D Light2D 阴影**；
同一隔离场景切到 `--rendering-method mobile --rendering-driver vulkan` 时阴影正常
（长条平行影）。这是渲染器/驱动路径的问题，不是 occlusion 配置错误。

因此运行时判断：

```gdscript
_real_shadows = RenderingServer.get_rendering_device() != null
_custom_shadows = not _real_shadows
```

- Vulkan/Forward+/Mobile：启用真实 Light2D 阴影，隐藏剪影长影。
- GL Compatibility（目标机）：关闭 Light2D 阴影，启用“剪影投影”长影。
- `LightOccluder2D` 始终保留（SDF 和真实阴影路径都可用）。

### 3.4 剪影投影长影（GL 回退）

对每个投影体使用其原始像素 texture 作为 silhouette，沿光照方向做剪切投影。设：

- caster 底边中心 `B`；
- texture 尺寸 `w×h`；
- 影子沿光方向长度 `L`；
- 光方向单位向量 `d = (-sinθ, cosθ)`；
- 水平翻转 `flip ∈ {-1, +1}`。

Sprite2D 的变换设为：

```
x_axis = (flip, 0)
y_axis = -d * (L / h)
origin = B + d * L - (flip * w / 2, 0)
```

这样 texture 的底边（y=h）映射到 `B`，顶边（y=0）映射到 `B + d·L`；整体沿
光方向被压扁拉长，并保留原像素剪影的树冠/屋顶/人物外形。
`modulate` 用深冷色 + alpha（白天约 0.38，夜晚约 0.30），材质
`CanvasItemMaterial.LIGHT_MODE_UNSHADED`，z=-450，位于地面/水面之上、道具和作物之下。

长度（世界像素）：房 128、大树 104、小树 82、灯笼 72、稻草人 68、农夫 56。

**限制**：这是屏幕平面的艺术近似。它不会遮挡灯笼点光，也不会让影子落在作物/道具上
形成二次投影；接触影用独立的软椭圆 sprite（z=-449）补足贴地感。

### 3.5 昼夜与暂停

- 一天状态由 `night` 布尔 + 暖冷参数驱动；切换立即应用（截图工具可精确复现）。
- 暂停通过自建 `paused` 标志传递给：
  - 农夫（停步/停帧）；
  - 作物摆动、萤火虫漂移；
  - 水面 `flow` 自定义 uniform（shader 不再随时间推进）；
  - 影子变换只在参数改变时更新。
- `Engine.time_scale` 不参与，避免 UI/后处理被意外冻结。

## 4. 移轴景深（无深度缓冲）

### 4.1 渲染结构

`CanvasLayer 10`：

1. `BackBufferCopy`（COPY_MODE_VIEWPORT）先复制世界 + 氛围层；
2. 全屏 `ColorRect`（unshaded canvas shader）用 `hint_screen_texture` 读取；
3. 之后才绘制 HUD（layer 20），因此 HUD 天然不在 screen texture 里。

这等价于参考视频的 URP RendererFeature：只处理世界，不糊 UI。

### 4.2 焦带公式

屏幕 UV 纵向 `y`，焦点位置 `f`，焦带半高 `b`，羽化 `fth`：

```
dist   = max(|y - f| - b, 0)
weight = smoothstep(0, fth, dist)
radius = weight * strength * radius_px
```

- `dist <= 0`（焦带内）时直接输出中心像素，**Point 采样、1:1 像素**；
- `radius < 0.5px` 时同样早退，避免无意义的模糊；
- 因此没有“高斯式”全屏软化，焦内保持像素刀切感。

### 4.3 17 点双环散景

焦外做单 pass 17 taps：

| 组 | 采样数 | 半径 | 权重 |
| --- | --- | --- | --- |
| 中心 | 1 | 0 | 4 |
| 内环 | 8 | 0.5 × r | 2 |
| 外环 | 8 | 1.0 × r | 1 |
| 总权重 | 17 taps |  | 28 |

内/外环方向为 `i·π/4 + 0.1963495`（8 个方向，加小偏移避免正十字），
采样坐标偏移为 `(1/screen_size) * radius`。除权重和 28 得到中心点颜色。
由于 `filter_nearest`，采样点是硬像素，呈双环散景而不是平滑高斯。

### 4.4 与参考参数的关系

从参考视频代码浮层读到的（近似值，压缩画面）：

- `focusHeight ≈ 0.46`
- `SharpHalfHeight ≈ 0.10`
- `Falloff ≈ 2.8`
- `Radius ≈ 2.8`
- 17 taps：中心 ×4 + 内环 8×2 + 外环 8×1 = 28。

本 demo 按自己的 640×360 构图重新标定默认值：`focus_y=0.60`、`band_half=0.14`、
`feather=0.20`、`radius=17px`（半径单位改为屏幕像素）。公式结构一致，参数不是照搬。

## 5. UI 防糊 / 图层

| CanvasLayer | 内容 | 是否被后处理 |
| --- | --- | --- |
| 世界 canvas（layer 0） | 地面/道具/光照/长影 | 是 |
| 2 | 氛围暖晕/暗角 | 是（但只做颜色叠加） |
| 10 | BackBufferCopy + 移轴 ColorRect | 后处理本身 |
| 20 | HUD / 中文滑杆 / 日志 | **否** |

自动化 smoke 会检查：
- `hud.layer > post_layer.layer`；
- HUD 不是后处理层的子节点；
- BackBufferCopy 在 ColorRect 之前；
- 8 个滑杆、中文标签、字体资源存在；
- 开关/暂停/显隐真实改变状态。

## 6. GL Compatibility 限制与差异

| 项 | 本 demo | 参考/说明 |
| --- | --- | --- |
| 渲染器 | GL Compatibility | 目标机 Intel HD 6000；避免 Vulkan 依赖 |
| 2D Light2D 阴影 | 目标机不输出，自动回退剪影投影 | Vulkan 下使用真实阴影；参考 URP 支持 |
| 2D HDR/MSAA | GL Compatibility 不支持；不用 | 与最终像素风一致 |
| 深度缓冲 | 不使用 | 与参考视频的技术前提一致 |
| 后处理载体 | CanvasLayer + BackBufferCopy + ColorRect | URP RendererFeature + Blit |
| 场景数量 | 1 个完整晨光农田 + 3 种光照状态 | 参考 4 个场景；按本任务“先前后对比成立”要求取舍 |
| UI | 原创中文 HUD / Noto Sans SC 子集 | 不复制参考/SE UI |
| 执行 | 自定义暂停、运行时程序化美术 | 无第三方运行时依赖 |

## 7. 性能

测试环境：macOS，Godot 4.6 stable，GL Compatibility，Intel HD Graphics 6000，
关闭 VSync，`Engine.max_fps=0`。

| 场景 | 移轴 | 平均 FPS | 最低 FPS | draw calls |
| --- | --- | --- | --- | --- |
| 1280×720 窗口 | 开 | 195.1 | 74.6 | 153 |
| 1280×720 窗口 | 关 | 225.4 | 104.8 | 151 |
| 1920×1080 离屏 SubViewport | 开 | 85.8–91.2（多次） | 14.4–25.7 | 153 |
| 1920×1080 离屏 SubViewport | 关 | 94.7–116.2（多次） | 21.3–27.0 | 151 |

- 1280×720 的交互档远高于 30 FPS（最低 74.6）。
- 1920 离屏平均 85.8–91.2 FPS（移轴开）；最低瞬时值受系统调度/离屏回读影响
  会掉到 14–26，本机屏幕为 1440×900，1920 窗口会被裁切，所以用离屏测量渲染成本。
  因此 1920 数据只作为渲染成本参考，不当成窗口交互帧率。
- 主要的 draw call 来源：73 株独立作物、26 只萤火虫、9 个长影剪影、15 个接触影、
  灯/glow、HUD。17 taps 在 GL 下不是主要瓶颈（1280 开/关约差 30 FPS 平均）。
- 没有发现脚本错误/泄漏；headless 与真实 GPU 各跑 600 帧验证。

## 8. 复现实验命令

```bash
godot --headless --path godot-hd2d --import
godot --headless --path godot-hd2d --quit-after 600
godot --headless --path godot-hd2d -s tools/smoke_hd2d.gd
godot --path godot-hd2d --resolution 1280x720 -s tools/probe_hd2d.gd
godot --path godot-hd2d -s tools/probe_hd2d_1080.gd
godot --path godot-hd2d -s tools/screenshot_hd2d.gd
godot-hd2d/tools/build_media.sh
```

隔离阴影实验（开发期，未入库）：同一相机/遮挡体在 Vulkan Mobile 下可见真实长影，
GL Compatibility 下不可见；据此选择了双路径。
