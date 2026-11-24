# TECH · 雾林微光 / Fogwood

> 任务：T-20261124-002（game-engineer worker）
> 引擎：Godot 4.6 stable / GDScript / **GL Compatibility** / 1280×720 逻辑画布
> 说明：本文以源码为准。场景、材质、贴图、代码均为原创；未复制参考视频或任何 IP 素材。
> 参考：B 站短视频《时之笛重制版雾气效果惊人》 https://www.bilibili.com/video/BV1j44t6kE2C

## 1. 参考视频拆解（先看帧，不凭标题）

用 `yt-dlp` + `ffmpeg` 抽帧（仅存 /tmp，未入库）实际确认：

- 规格：360×640 竖屏 / 30fps / 12.7s；镜头为高角度、略倾斜的缓慢环绕。
- 雾：**贴地、翻涌的乳白雾团**，有细高频丝状结构，随风流动；不是全屏均匀深度雾，也不是明显的 god rays。
- 粒子：大量金色/黄绿浮尘与流萤；近距离有大颗暖色光点。
- 场景：苔藓林地上有草、树根、石块；一个明亮青白色光团（光晕/泛光）。
- 光照：白天柔和阴光，暖灰绿色调；无可见体积光柱、无水面、无神殿。
- 镜头：角色在下方居中，快速跑动带有运动模糊（本 demo 不复刻角色与运动模糊）。

本 demo 的视觉目标因此定为：**低空雾团 + 浮尘 + 柔光 + 高角度环绕**；把参考没有但任务要求的“光束/god rays/水面/昼夜”做成可控的原创变体（夜景月光更戏剧化），而不是照搬画面。

## 2. 架构与文件

```
scripts/main.gd          组装；输入；每帧把大气/水面/后处理参数接线；demo API
├─ world_builder.gd      程序化地形、树、石、遗迹、踏石、草、水面、灯笼、精灵、噪声贴图
├─ atmosphere.gd         WorldEnvironment（深度雾+高度雾）、天空、昼/夜、光、质量
├─ fog_system.gd         20 雾片、2 水平雾层、3 组粒子、4 伪光束、风、质量
├─ camera_rig.gd         环绕相机（拖拽/滚轮/WASD/自动环绕/重置）
├─ hud.gd                标题、FPS、状态、快捷键；Tab 隐藏
└─ post_fx.gd            全屏后处理挂载（CanvasLayer 10，低于 HUD 20）
shaders/
├─ sky.gdshader          昼/夜渐变、太阳辉光、月盘/月晕、星点、地平线雾带
├─ water.gdshader        浅潭波形、菲涅耳、太阳高光、精灵微光、涟漪
├─ grass.gdshader        真实三角草叶、风摆、实例颜色
├─ beam.gdshader         交叉面片伪光束 + 噪声 + 叠加混合
└─ post_fx.gdshader      god rays（屏幕纹理）/ 色调 / 暗角 / 颗粒
tools/                   smoke_fog / screenshot_fog / probe_fps / capture_fog
```

所有内容由代码生成：地形 `SurfaceTool` 网格 72×72；树/石/废墟/草用 `MultiMesh`；灯笼/精灵/睡莲是低模基本体；噪声和 alpha 贴图在启动时用 `FastNoiseLite` + `Image` 生成（不加载外部贴图）。

## 3. 雾模型（不是体积雾）

### 3.1 能力边界（Godot 4.6 GL Compatibility）

- Godot 4.6 渲染器特性表：**Fog (Depth and Height) 在 Compatibility 支持**；**Volumetric Fog 不支持**。
- 实测（Intel HD 6000 / OpenGL 4.1）：
  - `WorldEnvironment` 的指数深度雾、`fog_height`/`fog_height_density` 高度雾、Glow、`hint_screen_texture` 屏幕后处理均可用；
  - 在 custom spatial shader 中写 `FOG` 会被 Compatibility 判为 Unknown identifier；因此**没有**采用自定义 FOG 输出或屏幕深度重建的高度雾。
- 因此本项目是：
  - **引擎侧深度雾 + 高度雾**（真参数、逐像素、按深度/高度衰减）；
  - **半透明雾片/水平雾层/粒子** 补体积感；
  - **伪光束 + 屏幕空间径向 god rays** 补光散射感；
  - **不是** ray-marching 体渲染，也没有体积阴影/散射遮光。TECH 与 README 均不把它称为“真体积雾”。

### 3.2 深度雾 + 高度雾参数

`atmosphere.gd` 使用 `Environment`：

| 参数 | 说明 | 本项目值（昼 / 夜） |
| --- | --- | --- |
| `fog_mode` | 指数雾 | `FOG_MODE_EXPONENTIAL` |
| `fog_density` | 深度消光密度（F 键四档） | 0.0004 / 0.0020 / 0.0044 / 0.0085 |
| `fog_height` | 高度雾基准高度（G 键四档） | 0.4 / 1.2 / 2.4 / 3.6 m |
| `fog_height_density` | 高度雾附加密度 | 0.026 / 0.050 |
| `fog_light_color` | 雾色（C 键四色） | 见下表 |
| `fog_light_energy` | 雾亮度 | 0.78 / 0.45 |
| `fog_sun_scatter` | 朝光方向散射 | 0.22 / 0.12 |
| `fog_sky_affect` | 对天空的影响 | 0.22 / 0.12 |
| `fog_aerial_perspective` | 不使用 | 0 |

**等效模型（用于理解与调参，不是我们手写的积分）**

- 深度雾透过率：`T_d = exp(-ρ_d · d)`，雾量 `1 - T_d`；`ρ_d = fog_density`，`d` 为视距。
- 高度雾等效密度：`ρ_h(y) = ρ_h0 · exp(-max(y - y0, 0) / H)`；引擎按高度与视线做逐片元混合，`fog_height`/`fog_height_density` 控制低空密度与过渡高度。
- 雾色 = `mix(fog_color, horizon/sky tint)`；太阳散射由 `fog_sun_scatter` 控制。
- 高度雾让树根、石柱底部、林地凹处首先淹没，树冠与拱门顶部保持更清晰；深度雾负责远景整体空气感。

雾色预设：

| 名称 | RGB |
| --- | --- |
| 晨白 | (0.86, 0.83, 0.73) |
| 冷蓝 | (0.55, 0.66, 0.80) |
| 暖金 | (0.88, 0.78, 0.58) |
| 苔绿 | (0.60, 0.72, 0.56) |

夜晚会把雾色向 (0.26, 0.36, 0.50) 混 58%，压暗雾亮度，避免白雾在月光下过曝。

### 3.3 雾片与水平雾层（体积观感）

- **20 片 billboard 雾片**（高质量）：
  - 8000 个顶点以内；`QuadMesh(1×1)` + 程序化 256² 噪声 alpha 贴图（径向边缘 × FBM）。
  - 每片尺寸 7.5–19m，贴地 0.35–1.65m，基础 alpha 0.42；`MultiMesh` 一次 draw call，逐实例色调略有变化。
  - 每帧按相机 yaw 手写 Y-轴 billboard；随风漂移，越界后在 ±38m 内环绕；UV 以 `0.012 / 0.005 × wind` 滚动。
  - 材质 `unshaded + alpha + cull_disabled`，透明不写深度，保留深度测试（被树干遮挡）。
- **2 层水平贴地雾层**：62×62m `PlaneMesh`，y=0.75/1.60m，alpha 0.15/0.08；使用**可平铺 patch 噪声**（四角混合 FBM，256²），以 2.4× 平铺；UV 缓慢漂移。低质量只保留 1 层。
- 雾片/雾层的 alpha 乘 F 键档位因子 [0.25, 0.65, 1.0, 1.30]，因此“浓/淡”不仅改变环境密度，也改变可见雾团厚薄。
- 透明排序按对象/材质距离进行，MultiMesh 内部不排序；因为 alpha 低、雾片相互重叠柔化，无明显排序瑕疵。近距离雾片不做逐片裁剪（数量小，预算可控）。

### 3.4 粒子（浮尘 / 流萤 / 落叶）

| 系统 | 高质量数量 | 低质量 | 生命周期 | 形态 | 材质 |
| --- | ---: | ---: | ---: | --- | --- |
| 浮尘 Pollen | 190 | 80 | 12s | Box (60×6×60m) | 径向 alpha + ADD，暖金/夜色转冷 |
| 流萤 Fireflies | 34 | 15 | 7s | Box (44×5.2×44m) | ADD，黄绿 α 闪烁 |
| 落叶 Leaves | 24 | 9 | 14s | Box (52×13×52m) | MIX + 程序化叶形 alpha |

- 使用 `CPUParticles3D`（避免 Compatibility 下 GPU 粒子差异），三系统合计 1–3 draw calls。
- 每帧不做粒子节点增删；质量档只改 `amount` + `restart()`，切换 3 次后节点数不变（smoke 覆盖）。
- 场景释放时粒子节点随树释放；smoke 用 WeakRef 验证无泄漏。

### 3.5 伪光束

- 4 组，各由 2 个交叉 `QuadMesh` 组成；14–18m 高、2.0–3.0m 宽；放置于遗迹/潭边/林地。
- `beam.gdshader`：`ALPHA = edge(UV.x) × vertical(UV.y) × (0.3 + 0.7·noise(uv, TIME)) × intensity`；`unshaded + blend_add + depth_draw_never + cull_disabled`。
- 不是体积光：没有光源方向一致性/遮挡/散射积分，只是视觉上对齐月光的软光柱；白天 intensity≈0.04，夜晚≈0.42，低质量只保留 2 组。
- 优点：极低 draw 成本、能快速营造“月穿过树冠”的氛围；缺点：从某些角度薄、没有真实树冠投影。

### 3.6 屏幕空间 god rays

`post_fx.gdshader`（CanvasLayer 10，低于 HUD 20）：

- 采样 `hint_screen_texture`；围绕光源屏幕 UV 做 8 taps 径向采样，步长 `(SCREEN_UV - light_uv) × 0.125`，权重 0.86 递减。
- 亮度阈值 `smoothstep(0.42, 0.95, luminance)`，累加后叠加；夜晚强度 0.75（天空锚点）/0.38（精灵/灯笼锚点），白天 0.28/0.14。
- 锚点优先级：月亮/太阳在画面内 → 月盘/日盘远景；否则雾精灵/最近灯笼。这样在夜景月光镜头能看到从月盘/光柱拉出的放射状光晕；在俯视日景则以精灵/灯笼做低调径向光。
- 同 pass 内做：暖高光/冷暗部轻微分级、暗角 0.30、0.010 细颗粒抖动。
- 限制：没有深度/遮挡，不能做到真实光束穿过树叶的遮蔽；低质量关闭 rays。

### 3.7 天空、光照与昼夜

- 天空 `sky.gdshader`：`mix(horizon_color, zenith_color, pow(up, 0.55))`；太阳辉光 `pow(sd,7)/pow(sd,150)`；月盘 `smoothstep(moon_size±0.0003)` + 两级 halo；稀疏星点（方向哈希 + 闪烁）；地平线雾带。
- 昼夜过渡 1.25s，逐帧对以下参数插值：
  - 太阳色 (1.0,0.90,0.72) → 月光色 (0.62,0.74,1.0)；能量 1.18 → 0.30；旋转 (-42,-30) → (-30,-58)。
  - 环境色 (0.58,0.585,0.47) → (0.22,0.29,0.42)；环境能量 0.74 → 0.26。
  - 天空顶 (0.40,0.53,0.62) → (0.035,0.065,0.13)；地平线 (0.82,0.80,0.70) → (0.14,0.21,0.32)。
  - 星空 0 → 0.8；月盘 0 → 1；Glow 强度 0.55 → 1.1。
  - 灯笼球自发光/光晕/地面光池、雾精灵、水面微光同步增强。
- 高质量：Glow + 单级方向光阴影（2048、48m，soft filter quality 1）。低质量关闭阴影与 rays，保留 Glow（性能允许，观感优先）。
- 水 `water.gdshader`：4 个正弦波叠加 → 有限差分法线；菲涅耳混天空渐变；太阳高光 `pow(...,140)`；精灵距离衰减微光 + 涟漪；环境雾自动叠加。无真实反射/折射。
- 草 `grass.gdshader`：每个 tuft 7 个真实三角叶片（非 alpha billboard），1200 实例，风摆按世界位置相位；实例颜色混合。

## 4. 交互 / 参数

| 输入 | 功能 |
| --- | --- |
| 左键拖拽 / 滚轮 / WASD | 环绕 / 缩放 / 平移焦点 |
| 空格 | 自动环绕 |
| F | 雾浓度 4 档（环境密度 + 雾片 alpha 因子） |
| G | 高度雾层 4 档（fog_height） |
| C | 雾色 4 预置 |
| B | 风速 4 档（雾片漂移/UV 滚动、草摆、粒子 speed_scale、光束噪声流速） |
| N | 昼/夜平滑切换 |
| 1 / 2 | 质量高 / 低 |
| R | 全量重置 |
| Tab | HUD |

主控提供的 demo API：`demo_set_view / demo_set_auto_orbit / demo_set_quality / demo_set_phase / demo_set_fog / demo_set_fog_color / demo_cycle_fog_color / demo_set_wind_level / demo_set_wind_speed / demo_set_hud_visible / demo_set_fps_visible / demo_set_ray_override / demo_get_counts / demo_get_fog_state / demo_get_wind / demo_get_camera / demo_reset`。仅供截图/录帧/冒烟，不改变正常键鼠路径。

## 5. 质量档与预算

| 项 | 高 | 低 |
| --- | --- | --- |
| 世界 3D 渲染分辨率 | 1280×720（逻辑），窗口可 1920×1080 | 同左 |
| 雾片 / 水平层 | 20 / 2 | 9 / 1 |
| 粒子（浮尘+流萤+落叶） | 248 | 104 |
| 伪光束（组） | 4 | 2 |
| 草叶实例 | up to 1200 | 540 |
| 灯笼/精灵/睡莲 | 3 / 1 / 9 | 同左（材质持续） |
| 方向光阴影 | 单级 2048 / 48m | 关 |
| Glow | 开 | 开 |
| 屏幕 god rays | 8 taps | 关 |
| 实测 draw calls | 72（昼）/ 67（夜） | 47 |

节点数约 71；无可变子节点每帧产生。阴影用单级，避免 Compatibility 下多级 split 的重复 shadow pass。物理/CPU 逻辑每帧仅雾片矩阵更新（20×）、材质 uniform 少量写入。

## 6. 性能实测

环境：Intel Core i7-5650U / Intel HD Graphics 6000 / 1280×720 内部渲染 / vsync off / 共享 macOS 主机。

| 场景 | avg | median | min | best 2s |
| --- | ---: | ---: | ---: | ---: |
| 高质量 昼 720p | 44.2 | 44.0 | 40.0 | 48.0 |
| 高质量 夜 720p | 37.4 | 38.0 | 36.0 | 38.0 |
| 低质量 昼 720p | 45.1 | 46.0 | 23.0* | 49.0 |
| 高质量 昼 1080p 窗口 | 34.5 | 35.0 | 34.0 | 34.6 |
| 低质量 昼 1080p 窗口 | 36.2 | 38.0 | 32.0 | 38.0 |

\* 首帧含 shader/测量预热。1080p 窗口在本机被系统夹为 1920×762（1440×900 屏幕），内部仍按 720p 渲染；本轮阴影优化+8 taps 后 1080p 高质量稳定 ≥34fps。多轮运行受共享主机负载影响，720p 高质昼曾出现 33–48fps，均 ≥30。完整样本见 `docs/fps.txt`。

## 7. 与参考视频的差异

- 参考是第三人称高角度林地短镜头，角色跑动 + 运动模糊；本 demo 是无角色的原创雾林环视，只有环绕相机。
- 参考的雾以贴地雾团/流丝为主；本 demo 用引擎深度/高度雾打底 + 雾片补团块，远景更均匀（引擎雾），近景仍有滚动 billboard。
- 参考没有可见 god rays/水面/石柱/灯笼；这些是任务要求下的原创扩展，夜景模式尤其戏剧化。
- 本 demo 是低模程序化美术，非扫描/贴图写实；没有真体积散射、软阴影级联、运动模糊、景深。
- 没有复制任何角色、场景布局、素材、Logo、音乐或视频帧。

## 8. 自测与证据

- `tools/smoke_fog.gd`（headless）：59 项检查全过，末行 `FOG_SMOKE_OK`。覆盖场景加载、程序化材质/贴图、环境雾/高度雾、天空、Glow/阴影、雾片/水平层/粒子/光束预算、质量档（含节点数不增长）、昼夜、雾浓度/高度/颜色、风、相机重置、HUD、粒子释放与 WeakRef 泄漏检查。
- `tools/screenshot_fog.gd`：8 张 1920×1080 PNG（浓/淡雾、暖色、潭边、月夜光束、夜灯笼、高/低质量），末行 `FOG_SHOTS_OK`。
- `tools/probe_fps.gd`：真实窗口采样，写入 `docs/fps.txt`；末行 `FOG_FPS_OK`。
- `tools/capture_fog.gd`：`--fixed-fps 30` 300 帧 → `/tmp/fog_atmosphere_frames`；末行 `FOG_VIDEO_FRAMES_OK frames=300`；MP4/GIF 为 10.0s / 1280×720 / 30fps 与 900 宽 12fps。
- `godot --headless --quit-after 600`：退出码 0，无 ERROR/SCRIPT ERROR。

## 9. 已知风险 / 限制

- **不是体积雾**：没有 ray-marching、体积阴影、真实光散射；雾片是 2D billboard；从极端低角度/贴近观察能看出片状。
- **god rays 是屏幕空间 2D 效果**：无深度遮挡，光源锚点离开画面时关闭；低质量关闭。
- **透明排序**：MultiMesh 内雾片不参与逐实例排序；低 alpha 掩盖了大部分问题，但在特别密集的浓雾+近距离仍可能有轻微叠层感。
- **阴影**：单级方向光阴影，只有高质量开启；无点光阴影；树木/废墟的阴影与雾交互是引擎默认，不做体积阴影。
- **性能**：共享主机负载尖峰明显；低质量首帧有预热；1080p 窗口高度被系统夹到 762；1080p 真窗口 30fps 余量不大。
- **视觉简化**：水面为解析着色（无反射/折射）；草是低模三角，不做 LOD；灯笼用 billboard 光晕而非真实点光；无音频、无移动端触控。
- **HUD 字体**：SystemFont 依赖操作系统 CJK 字体；无中文字体的平台会回退。
- **可移植**：项目刻意使用 Compatibility 支持的子集；若切 Forward+ 可进一步加真体积雾/SDFGI/更真实的 god rays。
