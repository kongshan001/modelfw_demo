# 像素水塘 · 技术拆解

任务：把 B 站《做了水和鱼》（UP：迷茫Mmang_，BV1CDWE6WEmf）的 3D 像素水景
视觉语言，在 Godot 4.6 / GL Compatibility 复刻成可交互 demo。只借鉴视觉/技术方向，
未复制参考视频、原作者或 t3ssel8r 的代码、模型、贴图、音频。

- 参考时长 49s / 1920×1080 / 30fps；抽帧 0/8/16/24/32/40/47s。
- 参考关键特征：俯视浅水池塘、草岛 + 深色土壁 + 白岸线、橙/深色小鱼、乳浊青绿水面、
  强抖动/量化、约 640×360 内部像素感（1080 下约 3×）、水下光柱、雨夜、黄昏暖光。
- 本项目结论：**640×360 内部 RT + 2×/3× 最近邻 + 两段式后期**。

---

## 1. 渲染总览

```text
root Window（逻辑 1280×720；可 1920×1080）
├── Display (Control, ignore mouse)
│   └── TextureRect  ← CompositeViewport.get_texture()，NEAREST，整数倍居中
├── WorldViewport (SubViewport 640×360, UPDATE_ALWAYS, MSAA/AA/TAA 全关)
│   └── Node3D 世界
│       ├── Camera3D（FOV 48° 水上 / 58° 水下）
│       ├── DirectionalLight3D（无实时阴影）
│       ├── WorldEnvironment（纯色天空 + 环境光）
│       ├── 地形 / 草岛 / 岩石 / 草簇 / 水草 / 藻丘
│       ├── WaterSurface（透明，屏幕采样折射）
│       ├── LightShafts（加色四边形）
│       ├── FloatingDecor（花/花瓣/荷叶）
│       ├── Bubbles（CPUParticles3D）
│       └── FishSchool（20 条原创低模鱼）
├── CompositeViewport (SubViewport 640×360, UPDATE_ALWAYS)
│   └── ColorRect + canvas_item 后期（采样 WorldViewport 纹理）
└── HUD (CanvasLayer, root viewport 全分辨率中文 UI)
```

- 内部分辨率可切换 320×180 / 480×270 / 640×360。
- 显示缩放：`scale = max(1, min(floor(win_w / rt_w), floor(win_h / rt_h)))`，
  1280×720 → 2×；1920×1080 → 3×；不匹配时黑边居中，不做小数缩放。
- TextureRect 与 SubViewport 纹理都使用最近邻；UI 不经过 RT。

### 1.1 为什么是两段式 viewport（关键兼容性坑）

最初把全屏后期四边形放在 WorldViewport 的相机下（spatial shader 采样
`hint_screen_texture` / `hint_depth_texture`），同时水面也采样屏幕纹理。在
GL Compatibility + SubViewport 下实测发现：

1. `hint_depth_texture` 在 SubViewport 中采样恒为 0：
   - 深度调试为整屏纯色；
   - 水面“水体厚度 = 场景深度 - 水面深度”恒为 0，于是接触泡沫铺满全池。
2. 后期四边形与水面都读屏幕纹理时，后期复用了一份**早于水面**的 backbuffer 拷贝：
   水面在原始 3D 画面里存在，但进入最终后期后消失（调色板、描边都看不到水）。

解决：

- **WorldViewport** 只渲染 3D（水面可以用屏幕采样做折射）；它的最终纹理包含水。
- **CompositeViewport** 用 `canvas_item` shader 采样 WorldViewport 的纹理
  （不是 `hint_screen_texture`），做描边/调色/抖动/量化。这样水面 100% 进入最终画面。
- 深度/法线调试改为**场景材质覆盖**（`debug_depth.gdshader` /
  `debug_normal.gdshader`）+ 后期直通；不依赖不可用的屏幕深度。
- 描边改为亮度/色度 Sobel + 鱼体 rim，而不是深度 Sobel。
  （“深度/法线描边”在 GL Compatibility 下不可用，属于已记录的引擎限制。）

---

## 2. 低分辨率与像素稳定

### 2.1 顶点像素吸附

所有 3D shader（地形/岛/岩石/草/水草/鱼/水面/光柱）在 vertex 阶段使用同一函数：

```glsl
vec4 snap_clip(vec4 clip) {
    if (g_pixel_snap > 0.5) {
        vec2 grid = vec2(g_res_x, g_res_y) * 0.5;   // 640×360 → 320×180
        clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
    }
    return clip;
}
```

- 等价于把顶点吸附到虚拟低分辨率像素中心，相机缓慢移动时轮廓不抖成蚂蚁线。
- 全局 uniform `g_pixel_snap` 可在 UI 关闭；默认开。
- 水波纹/泡沫/碎光使用世界坐标量化与低频噪声，避免随相机亚像素抖动。

### 2.2 抗锯齿策略

- SubViewport：`MSAA 3D=off`、`screen_space_aa=off`、`TAA=off`、`debanding=off`。
- 所有世界贴图/视图纹理：最近邻；初始 `project.godot` 也设置默认最近邻。
- 风格上保留像素块与 Bayer/哈希噪声，不做 FXAA/TAA 模糊。

---

## 3. 合成后期（CompositeViewport）

`shaders/post_pixel.gdshader`（canvas_item），采样 `world_tex`。

### 3.1 描边

- 取上下左右 4 个邻居（1 个 640×360 像素宽），计算：
  - `lmax = max(|luma(neighbor) - luma(center)|)`
  - `cmax = max(length(neighbor - center))`
  - `edge_raw = max(lmax, cmax * 0.2)`
  - `de = smoothstep(0.11, 0.34, edge_raw)`
- 正常画面把 `de` 与描边色 `(0.045, 0.09, 0.10)` 混合，强度 × 0.7；阈值经过多轮
  截图调整，避免把抖动/草叶细节描成脏边。
- 调试视图 4 使用更敏感的 `smoothstep(0.04, 0.22, edge_raw)`，便于看边缘覆盖。
- 鱼体自身再用 view-space rim 压暗轮廓（见 §7），补屏幕边缘描边抓不到的鱼身。

### 3.2 调色

```text
c = clamp(c * exposure + lift, 0, 1)       // exposure 来自时段，lift=0.008
c = mix(vec3(luma(c)), c, saturation)      // 1.06–1.12
c = mix(c, c*c*(3-2c), 0.14)               // 柔和高光/对比
轻微暗角：c *= 1 - dot(uv-0.5, uv-0.5) * 0.16
```

### 3.3 抖动与量化

```glsl
float th = bayer4(FRAGCOORD.xy) * dither * 0.7
         + (hash12(FRAGCOORD.xy * 1.37 + time) - 0.5) * dither * 0.65;
```

- Bayer 4×4 提供有序纹理，哈希项打破纯网格，得到类似参考的“手绘噪点”。
- 默认 `levels=12`、`dither=0.20`；可在 UI 调。
- 调色板模式：转亮度/色度，亮度 6 级、色度每轴 5 级（约 36 色），仍带同一抖动。

### 3.4 调试视图与雨天/水下叠加

| 编号 | 视图 | 实现 |
| --- | --- | --- |
| 0 | 关闭 | 正常画面 |
| 1 | 低分辨率 RT | 直接输出 world_tex，绕过所有后期 |
| 2 | 深度 | 场景材质覆盖为 view-depth 热力图，后期直通 |
| 3 | 法线 | 场景材质覆盖为 view-space normal RGB，后期直通 |
| 4 | 描边 | 输出亮度/色度边缘 mask（黑底白/灰线） |
| 5 | 水面 Mask | 水面 shader 输出 field mask（蓝=水、深色=陆），后期直通 |

- 水下时后期额外叠一层屏幕空间光柱（竖向柔性光带），与 3D 光柱共同形成光柱感。
- 雨天：屏幕空间竖线（1–2px 列）+ 水面雨滴环 + 更厚雾/更暗光。
- 深度/法线覆盖会临时隐藏水面、光柱、气泡和花，并替换所有 GeometryInstance3D
  的 material_override；退出时恢复。

---

## 4. 水面

### 4.1 解析池塘场

`PondField`（GDScript）同时驱动地形高度、水面 mask/深度、岸线泡沫、假岛影、
鱼群边界和 smoke 断言。

- 世界 30×22 m，水面 y=0；池塘超椭圆半径 12.6×8.5，带 3/5/8 次角向扰动。
- 4 个草岛（2 大 2 小），近似椭圆 SDF；7 块岩石。
- 深度：

```text
shore_df = clamp(shore_distance / 3.1, 0, 1)
island_factor = smoothstep(0.12, 1.7, min_island_distance)
depth = clamp(shore_df * (0.34 + 0.66 * island_factor), 0, 1)
```

  这样岛可以靠得较近，池心仍然足够深；近岛则压成浅滩。

- 场贴图 384×288 RGBA8：
  - **R**：水深 0..1（用于水色、水底色）
  - **G**：离岸/离岛距离（米/4，用于岸线泡沫与浅水区）
  - **B**：陆地 mask（用于假岛影）
  - **A**：水面 mask（discard 陆地）
- 地形顶点高度：`floor_y = -0.15 - 1.65*depth + 0.05*sin(...)`；
  岸高 `0.05 + 0.42*smoothstep(0.15, 2.6, 岸外距离) + ...`。
- 岛体为独立的草帽顶 + 四圈土壁（顶/上/水线/底），岛壁 shader 根据世界 y 在水线
  附近生成白色虚线泡沫带。

### 4.2 水色与透明

- 水色：`shallow(0.6, 0.93, 0.89) → deep(0.2, 0.58, 0.7)`，按 depth 与浅水 factor 混合；
  加低频 value noise 与焦散光网，避免大片纯色。
- 屏幕折射：

```text
uv = SCREEN_UV + rip * refraction * 0.0042 * (0.55 + depth01)
behind = texture(screen_tex, uv)
tint = mix(0.34, 0.62, depth01) * mix(1.05, 0.84, clarity)
col = mix(behind, water_col, tint)
```

  - 鱼在水下会被屏幕采样轻微扭曲，满足“可见且轻微扭曲”。
  - 鱼附近额外降低水色占比（≤40%），形成风格化“通透水窗”，让橙/青更可读。
- 菲涅尔天空色、假岛影（陆地 mask 沿太阳反方向偏移 ×0.15 压暗）、白色碎光。
- 水下仰视：用视角与法线夹角形成明亮“顶棚”与 Snell 窗式渐变；后期再叠水下光带。

### 4.3 泡沫 / 溅光 / 焦散

- 岸线：`shore_ring = 1 - smoothstep(0, 0.16, field.g)`，与水线附近的岛壁白带叠加。
- 岩石：shader 内 8 个 rock_pos/radius uniform，环宽约 0.16 m。
- 鱼/雨：8 个 ripple slot（位置、出生时间、幅度）；鱼近水面每 2–4 s 生成环；
  雨夜由 FishManager 以 0.08–0.18 s 间隔生成随机雨滴环。
- 泡沫做虚线 + 2 级量化（Bayer），避免成为塑料白圈。
- 白色碎光：稀疏短划线（9×15 世界格、阈值 0.985），强度 0.3。
- 焦散：两套互相干涉的正弦网取幂，量化 3 级；用于水底、岩石、鱼和水面。
- 没有使用深度缓冲计算水体厚度（兼容性限制，见 §1.1）。

---

## 5. 地形 / 草岛 / 岩石 / 植物

全部由 SurfaceTool 程序化生成，无外部模型/贴图。

- **地形**：121×89 共享顶点网格，顶点色区分浅水沙、深水藻、岸边沙、岸上草；
  法线由高度场中心差分解析计算；shader 加世界空间 grain、焦散、雾、rim。
- **草岛**：44 点轮廓（角向扰动）× 内圈/中心草帽 + 四圈土壁；顶点色；
  顶面颜色统一（防止扇形顶点色条纹），grain 在 shader 里补纹理。
- **草簇**：MultiMesh，5 片短宽三角叶/簇，岛顶 + 岛缘下垂 + 外圈岸草；
  受 `sway` 顶点风摆；颜色从浅绿到高光黄绿。
- **水草**：MultiMesh 3 条带状叶片，9 个簇中心 × 7 株；按水深放置；
  `sway` + 水下焦散；颜色偏中绿。
- **藻丘**：8 个压扁低模半球，合并成 1 个 mesh，浅绿顶点色 + 焦散，读作水下软植物。
- **岩石**：UV 球扰动 + 平面法线（faceted 低模），顶部苔藓色，底部压暗；
  大部分在岛上，3 块半浸水中。
- **漂浮装饰**：白花、花瓣、荷叶合并为 1 个 mesh；unshaded 顶点色。

---

## 6. 光照与氛围

- DirectionalLight3D（默认无阴影），自定义 `light()`：

```glsl
float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
float steps = max(g_light_steps, 2.0);        // 默认 3
float band = floor(clamp(ndl,0,1) * steps) / (steps - 1.0);
DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band;
```

- 环境光使用 WorldEnvironment ambient；雾在 scene shader 内按视图距离混合
  （水上淡青、雾密度约 0.005；水下 `g_underwater` 时密度 ~0.17）。
- 时段关键帧（0..1）：太阳高度/方位、光色、能量、天空色、环境光、雾色/密度、曝光；
  雨会再压暗/加雾；水下把天空/雾混向青绿并加后期光带。
- 水下光柱：8 个十字交叉加色四边形 + 后期屏幕光带；水上只保留 30%，水下增强。
- 无实时阴影/SSR/SSAO；岛影为解析假投影，焦散为程序化光网。

---

## 7. 鱼

### 7.1 三种原创鱼

| 种类 | 长度 | 宽度/高度半径 | 主色 | 深度带 |
| --- | --- | --- | --- | --- |
| 赤锦（锦鲤） | 0.76 m | 0.155 / 0.16 | 橙红 + 乳白斑 | -0.30 m |
| 青鳞 | 0.46 m | 0.085 / 0.095 | 深青 + 浅腹/暗纹 | -0.80 m |
| 银灯 | 0.34 m | 0.06 / 0.07 | 银蓝 + 蓝背 | -0.60 m |

- 网格：7 环×8 段鱼身 + 头封口 + 水平/竖直尾鳍 + 胸鳍 + 背鳍；顶点色花纹；
  头部两侧暗色眼斑。
- 尾摆：shader 内 `instance uniform`（相位/速度/弯曲/体长）：
  `lateral = sin(time*speed - t*3.4 + phase) * bend * (0.04 + t²) * body_len`；
  同时做轻微 yaw 与胸鳍抖动。
- 轮廓：view-space rim 压暗 + 屏幕亮度/色度描边；**不加外扩壳**（早期外扩壳在
  Godot 的 cull 方向下会整条鱼变黑，已移除）。

### 7.2 群游

- 每帧 O(n²) 简易 boids（n≤36，开销可忽略）：
  - 分离：0.95 m 内，权重 2.5；
  - 同种聚合/对齐：2.4 m 内，权重 0.2 / 0.5；
  - 群体锚点：0.16；
  - 目标深度 + 正弦起伏；
  - 前方 0.9 m 边界/草岛避让；池底、水面高度限制；
  - 速度按种限制 0.5–1.05 m/s；水平方向 + 垂直限速。
- 方向用 `Basis.looking_at` + 四元数 slerp；身体轻微 roll。
- 近水面鱼生成涟漪事件；深度不足/越界兜底到安全水域。

### 7.3 渲染顺序与水面

鱼是 opaque，先于水面绘制；水面的屏幕采样会包含鱼，因此产生折射。鱼附近的
“通透水窗”由水面 shader 的 fish_pos/fish_count uniform 完成（最多 12 条）。

---

## 8. 相机与输入

- 轨道相机：yaw/pitch/dist/target 平滑插值（时间常数 ~0.2 s）。
- 水上：FOV 48°，pitch 18°–82°，dist 5–24 m；自动环绕 2.2°/s。
- 水下：FOV 58°，pitch -30°–-0.5°，dist 5–14 m；相机 xz 夹在安全水域内，
  y 夹在池底 +0.32 与水面下 -0.18 之间；避免穿地/穿岛。
- 输入：拖动旋转并关闭自动环绕；滚轮缩放；V/Space/F1/H/R/1/2/3/T/P/G 快捷键。
- HUD 是 root viewport CanvasLayer；字体 SystemFont；面板 338px 固定宽，1280 与
  1920 下都保持全分辨率清晰（1920 下相对更小）。

---

## 9. 性能

实测（Intel HD Graphics 6000，OpenGL 4.1，VSync 关闭，4 s 采样）：

| 场景 | 平均 FPS | draw calls | 说明 |
| --- | --- | --- | --- |
| 1280×720，内部 640×360，HUD 开 | 64.3 | 137 | 世界 ~48 draw + HUD |
| 1920×1080 合成（3× + 1920 HUD） | 44.4 | 232 | 真实 GPU SubViewport（开发屏 1440×900） |

- 世界 draw 约 48–60：地形 1、岛 4、岩 7、草 1 MultiMesh、水草 1、藻丘 1、水 1、
  光柱 1、装饰 1、气泡 3、鱼 20、鱼无外扩壳、后期 1。
- 内部 640×360 只有 ~230k 像素；主要成本是 2D HUD 控件与 3D 低模绘制，不是填充率。
- 无实时阴影/SSR/后处理链；两段式 viewport 各 640×360，额外成本很小。
- 偶发最低瞬时帧（10.6 / 7.7）来自系统调度/窗口/测量毛刺，平均值高于 30 FPS。

---

## 10. 已知限制与后续

1. GL Compatibility 的 SubViewport 无可用屏幕深度纹理 → 无深度/法线屏幕描边；
   如换 Forward+/Mobile 可加 MRT normal-roughness 与深度 Sobel。
2. 无实时阴影、SSR、SSAO；岛影与焦散均为风格化近似。
3. 水面是解析模型，不是物理模拟；鱼附近的水窗是艺术处理。
4. 1920 截图用 1920 CaptureViewport（屏幕只有 1440×900）；视频为 1280 录制后
   最近邻放大到 1920，世界内部始终 640×360。
5. HUD 为固定像素尺寸，1920 下相对较小；可加 DPI 缩放开关。
6. 鱼网格是低模管子 + 鳍，近看仍偏简；可加脊线/眼睛几何/更细的尾鳍。
7. 调色板模式是程序化亮度/色度 36 色，不是手工调色板；可按参考帧再精修。

---

## 11. 文件职责

| 文件 | 说明 |
| --- | --- |
| `scripts/main.gd` | 两段式 viewport、缩放/布局、相机、时段/天气、调试、电影时间线、参数 API |
| `scripts/pond_field.gd` | 池塘/岛/岩解析场、深度/岸距、场贴图、鱼边界 |
| `scripts/world_builder.gd` | 地形/岛/岩/草/水草/藻丘/水/光柱/花/气泡 |
| `scripts/fish_manager.gd` | 3 种鱼网格、boids、涟漪、鱼群查询 |
| `scripts/hud.gd` | 中文全分辨率参数面板与统计 |
| `shaders/common.gdshaderinc` | 全局 uniform、噪声、焦散、像素吸附、Bayer、雾 |
| `shaders/scene_toon.gdshader` | 量化受光 + grain + 焦散 + 岸线白带 + 水下雾 |
| `shaders/water_surface.gdshader` | 屏幕折射、色阶、泡沫、碎光、涟漪、水下顶棚 |
| `shaders/post_pixel.gdshader` | 合成后期：描边/调色/抖动/量化/调试 |
| `shaders/fish.gdshader` | 鱼摆尾、顶点色、rim、焦散 |
| `shaders/debug_depth.gdshader` / `debug_normal.gdshader` | 调试材质覆盖 |
| `shaders/light_shaft.gdshader` | 水下光柱 |
| `tools/smoke_water_fish.gd` | headless 自测 |
| `tools/capture_shots.gd` | 1920 CaptureViewport 截图 |
| `tools/probe_fps.gd` | 无回读干扰的 FPS 探针 |
| `tools/build_media.sh` | Movie Maker + ffmpeg 媒体重建命令 |
