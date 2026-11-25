# 雨落青苔 · 技术说明

> 目标：在 Godot 4.6 / GL Compatibility / Intel HD 6000 上，用可维护的 2D
> 程序化方案复刻“360 渐变雨丝 + 72 双环涟漪 + 低洼积水 + 树木/暖灯倒影 +
> 1×1 灯柱规则”的雨景。**不用粒子系统**，所有像素素材原创。
>
> 参考视频只用于技术拆解：BV11DyDzjE7c（UP：小武同学贼下饭）。没有复制
> Unity/C#/HLSL 代码、视频帧或任何美术素材。

---

## 1. 渲染管线

```
窗口 1280×720（canvas_items 拉伸，可 1920×1080）
├─ WorldViewport   SubViewport 640×360, UPDATE_ALWAYS, disable_3d
│   └─ World (Node2D)
│       ├─ Ground     Sprite2D  程序化地面（1 call）
│       ├─ WaterLayer ColorRect 湿边/水色/倒影/水际高光（1 call）
│       ├─ Ripples    MultiMeshInstance2D 72 实例（1 call）
│       ├─ Props      红枫/左灯/右灯/松树 4×Sprite2D（4 calls）
│       ├─ LanternGlow MultiMeshInstance2D 2 实例，加法混合（1 call）
│       ├─ Rain       MeshInstance2D 动态 ArrayMesh（1 call）
│       ├─ Foreground 蕨叶剪影（1 call）
│       └─ DebugGrid  Node2D 即时绘制（默认隐藏）
├─ WorldDisplay TextureRect 全屏，最近邻，承载 640×360 世界
└─ HUD CanvasLayer 1280×720（1920 下由拉伸放大 1.5×）
```

- 世界内部固定 640×360：所有雨丝/涟漪/水洼都是在这个像素网格上做的，
  显示时 2×/3× 最近邻放大，得到干净的像素块；UI 保持原生分辨率。
- 项目中 `renderer/rendering_method = gl_compatibility`，无 MSAA，纹理过滤
  Nearest，`WorldViewport` 关闭 3D，`snap_2d_*_to_pixel = true`。

### 实测 draw calls（真实 GPU，非估算）

| 状态 | draw calls | primitives |
| --- | --- | --- |
| 世界层，HUD 隐藏 | **11** | 884 |
| 含 HUD 面板 | **59** | 3132 |
| 含 HUD + 调试网格 | ~121 | — |

世界层 11 的拆分：地面 1 + 水面合成 1 + 涟漪 1 + 4 个道具 + 灯笼辉光 1 +
雨丝 1 + 前景 1 + WorldDisplay blit 1。**雨丝 1 call + 涟漪 1 call**，正对应
参考里“2 个 DrawCall 做雨和涟漪”的部分；水面合成再占 1 call。没有把 11 说成 2，
也没有依赖粒子。

---

## 2. 雨丝：动态 ArrayMesh（1 draw call，无粒子）

`scripts/rain_field.gd`：`MeshInstance2D` + 一张每帧重建表面的 `ArrayMesh`。

- 每条雨丝 = 1 个四边形（4 顶点 / 6 索引），尾窄头宽：
  - 尾 = `head - dir * length`，尾宽 = `width * 0.18`；
  - 头宽 = `width`；
  - 宽度基准 0.8–1.55 px，长度基准 22–52 px，速度基准 650–1010 px/s。
- 顶点颜色：尾部 `Color(0.58, 0.72, 0.92, 0)`，头部
  `Color(0.76, 0.88, 1.0, α)`；α = 单条随机 0.40–0.78 × (0.26 + 0.62 × 雨强)。
  四边形内的顶点色插值 = 渐变拖尾；不需要贴图/粒子。
- 风：`drift = wind × 300 × speed_scale × (0.72 + 0.45 × intensity)` px/s，
  方向 `(wind × 0.9, 1)` 归一化；风速滑杆范围 -0.6–0.6。
- 密度滑杆 60–600（默认 360），池上限 600；`_rebuild()` 只写
  `ARRAY_VERTEX / COLOR / TEX_UV / INDEX`，然后 `add_surface_from_arrays()`；
  一个 surface，一次绘制。
- `rain.gdshader` 只有 `COLOR = COLOR`，不做纹理采样。
- 烟雾测试验证：默认 360 条 / 1440 顶点；密度 120 → 480 顶点；无
  `GPUParticles2D` / `CPUParticles2D` 节点。

CPU 成本：每帧 600 条 × 4 顶点 = 2400 顶点重建；在 Intel HD 6000 上
600 雨丝世界层仍达 207.9 FPS（1280×720，VSync 关闭）。

---

## 3. 低洼盆地场（320×180）+ 22s / 75s 水位

### 3.1 数据布局

`scripts/puddle_field.gd` 生成 320×180 RGBA8 贴图（每 texel = 2 世界像素）：

| 通道 | 含义 |
| --- | --- |
| R | 高度（0 低 / 1 高），由 FBM 噪声 + 6 个椭圆盆地 + 轻坡度组成 |
| G | 大占地遮挡（石头/石岸 = 1；水面 shader 用 `1-G` 掩掉） |
| B | 灯柱 1×1 格标记（调试/规则可读性） |
| A | 高频边缘噪声，用来打碎水线 |

高度：

```
h = 0.50 + low_noise*0.26 + fine_noise*0.03 + (x/W - 0.5)*0.03
for basin:
    q = ((x-cx)/rx)^2 + ((y-cy)/ry)^2 + warp*0.11
    h -= depth * (1 - smoothstep(0.05, 1.0, q))
```

- 6 个设计过的盆地（左灯、红枫下、右灯、松树前、右上、左下），
  再叠加噪声/边缘噪声，水洼不会呈正圆。
- 全满水位取高度分布的 **19 百分位**：满水时约 **17.2%** 的格子有水；
  半湿时约 6.8%，1/4 湿时约 3.5%，增长过程可见。

### 3.2 水线与时间

```
waterline_dry  = min(height) - 0.014
waterline_full = 19th percentile(height)
t              = pow(clamp(wet, 0, 1), 0.40)
waterline      = lerp(waterline_dry, waterline_full, t)
水面 mask     = smoothstep(0, 0.010, waterline - h + (edge-0.5)*0.010) * (1 - block)
```

- `0.40` 次幂是刻意选的填充曲线：如果线性映射，盆地侧壁很陡，前 11s 只有
  约 2.5% 面积有水，最后几秒突然铺开；0.40 让前段先漫过深盆、后段慢慢扩张，
  同时**时间口径不变**。
- 湿度：
  - 雨强 > 0.01：`wet += dt * intensity * fill_speed / 22`，默认满雨 22s 满；
  - 雨停：`wet -= dt * drain_speed / 75`，默认 75s 干；
  - `fill_speed` 0.25–4、`drain_speed` 0.25–12，只改速度，不改时间语义。
- 水洼边缘的可读性：
  - 水面 alpha 从浅处 0.74 到深处 0.94；
  - 水线内 1–2 texel 的浅青高光 `rim`；
  - 水线外的湿边（damp band）压暗草色 + 轻微透明，避免硬方块；
  - 边缘噪声让水线呈不规则像素边。

### 3.3 灯柱 1×1 规则

占位网格是 16×16 世界像素（40×23 格）：

1. 大石头（2 组）和左下石岸先写 `block = 1`，共 28 个遮挡格；
2. 两根灯柱各占 **1×1 格**，先记录为灯柱格；
3. 应用规则：`EmitsLight && Width == 1 && !RoomBoundary → 放行积水`，
   清掉该格的遮挡位。

结果：**两根灯柱脚下的 1×1 格都可积水**（满水时 mask = 1.0），
不会出现方形干边；大石头/石岸仍然挡水。调试叠加（F3）用红色画遮挡格、
绿色画灯柱格。实际代码不依赖 TileMap，是一条简化后的规则函数
`_apply_thin_lamp_rule()`。

> 与视频的差异：原教程是 Unity Tilemap 工程里的规则；这里是 16px 规则格 +
> 1×1 灯柱标记，规则语义一致，实体系统更轻。

### 3.4 CPU / GPU 同构

`shaders/water_mask.gdshaderinc` 的 `rp_depth / rp_water_mask / rp_damp_mask`
与 `PuddleField.mask_from_texel()` 共用同一组常数（0.010 软边、0.010 边缘抖动）。
水面 shader、涟漪 shader、CPU 测试查询结果一致。项目的“同源”做法从原教程的
C#/HLSL 同源噪声，移植为 **GDScript 低洼场 + GLSL include**；没有复制源码。

---

## 4. 72 组双环涟漪（MultiMesh，1 draw call）

`scripts/ripple_field.gd`：

- 固定池 **72**，`MultiMesh` + 1 张 32×32 双环贴图；`transform_format=2D`，
  `use_colors=true`。
- 目标数量 = `72 × intensity`；生成节奏
  `spawn_accum += dt × target / 1.55`，每帧最多补 5 个；
  雨强 0 时不再生成，已有涟漪自然结束。
- 生命周期 1.1–2.1s（随机），尺寸 12–30 px，横向/纵向按随位置变化的
  1.16–1.50 比例拉成椭圆。
- 半径 `1 - (1-t)^2.3` 扩散；透明度 `sin(πt)^0.65 × 0.52 × amp`，双环贴图
  本身有两个半径（约 9px / 13.5px），扩散时保持双环。
- shader 用 `SCREEN_UV` 采样同一份 puddle field，并调用 `rp_water_mask`；
  只在积水内可见，水面边缘自动裁剪。
- 位置从 `PuddleField.spawn_points` 中挑选并实时检查当前水线；水还没漫到的
  格子不会生成涟漪。
- 烟雾测试：72 池；0.9 雨强 2.5s 后活跃 > 30；寿命范围、相位散布；
  雨停 3.2s 后归零；关闭开关后不生成；重新打开后恢复；0.3 雨强的活跃数量
  明显少于 0.9（频率随雨强）。

---

## 5. 倒影：离线镜像图集 + 统一 mask 裁切

### 5.1 烘焙

`PixelArt.build_reflection()` 在启动时生成 640×360 RGBA 图集：

1. 把红枫、松树、两盏灯柱按各自**脚底 y 垂直翻转**；
2. 乘冷色 tint（红枫偏暗红、松树偏青、灯柱偏暖灰），再按行渐隐；
3. 叠加两层**平滑的暖光**（灯笼在水下的拉长光晕）；
4. 整张图集交给水面 shader。

不是实时平面反射/SSR；好处是零额外 render target、GL Compatibility 安全、
所有道具的倒影共享同一张纹理。原教程用实时反射 + `clip(surface-.001)`；
这里把“统一裁切”落在水面 shader 的同一次 mask 计算上。

### 5.2 运行时

```glsl
// water_surface.gdshader
float water = rp_water_mask(f, u_waterline);
if (u_reflection_on > 0.5 && water > 0.001) {
    vec2 ruv = UV;
    ruv.x += sin(UV.y*92 + u_time*2.3) * 0.0030 * (0.30+0.70*d01);
    ruv.y += sin(UV.x*61 + u_time*1.45) * 0.0016;
    ruv = floor(ruv * vec2(640,360)) / vec2(640,360);  // 像素吸附
    vec3 refl = texture(u_reflection, ruv).rgb;
    refl = mix(vec3(lum), refl, 0.56) * vec3(0.88, 0.98, 1.0);
    water_col = mix(water_col, refl*0.92 + water_col*0.42, refl_amt);
}
```

- 倒影只在 `water > 0` 的分支里采样，因此**必然被 puddle mask 裁切**；
- 涟漪 shader 用同一 `rp_water_mask`，水面/涟漪/倒影的裁切是同一套；
- UV 吸附到 640×360 像素网格，保留像素风；
- 深浅影响倒影强度（0.18 浅 → 0.64 深），并受倒影开关 uniform 控制。

### 5.3 GL Compatibility 限制

- **没有用 BackBufferCopy / screen_texture / SSR**：移动端 GL Compatibility
  对屏幕纹理有额外限制，这里直接采样离线图集，避免跨平台问题。
- 倒影是静态烘焙；移动的雨丝/涟漪不进入倒影（它们在 shader 里单独叠层）。
- 倒影图集在启动时占 640×360 RGBA（约 0.9MB 显存），运行时只多一次采样。
- 水面 shader 只做有限的 sin/hash，无循环；GLSL ES 3.0 下可编译运行。
- 像素吸附 + 最近邻过滤意味着倒影边缘会有意保留硬像素块。

---

## 6. 画面层与湿气氛

- 地面：底色在 320×180 上程序化生成再 2× 最近邻放大；上面再叠 640×360
  的草叶、花、落叶、蕨丛、石头、灯下柔光、树影。启动阶段打印
  `PIXEL_ART_MS ground/props/reflection/extra`。
- 雨强度也影响全屏色调：`_update_wet_tint()` 把地面/道具 modulate 向
  `(0.84,0.92,0.95)` 混合，最多 30%，让湿草更冷、更暗。
- 灯笼：地面暖光池 + MultiMesh 加法辉光（2 实例，1 draw call），亮度随
  `sin(_time*2.2 + i*2.4)` 轻微闪烁。
- 前景：四角蕨叶剪影 + 底边极轻压暗，只用来做景深，不遮挡主要水洼。
- 所有像素素材由 `scripts/pixel_art.gd` 以固定种子生成，无外部图片。

---

## 7. 交互与 UI

- `scripts/hud.gd`：SystemFont + 系统 CJK fallback（PingFang SC /
  Hiragino Sans GB / Noto Sans CJK SC）。
- 滑杆：雨强、密度、风、雨速、雨长、积水、渗干；复选框：涟漪、倒影、
  网格；按钮：暂停/继续、重置；FPS/draw calls/涟漪数/水位/状态实时显示。
- HUD 的滑杆/按钮/复选框 `focus_mode = NONE`，避免抢走 Space/R/H/F3 快捷键。
- 录制演示时隐藏实时 FPS 统计（逐帧 PNG 会拉低实时帧率），截图和真实运行
  仍显示；这是为了不在视频里展示误导性的低 FPS。

---

## 8. 验收与证据

| 项目 | 结果 |
| --- | --- |
| headless smoke | `RAIN_PUDDLES_SMOKE_OK checks=73` |
| headless 600 帧 | 0 `SCRIPT ERROR` / 0 `ERROR` |
| 真实 GPU 600 帧 | 0 `SCRIPT ERROR` / 0 `ERROR`（OpenGL API 4.1, Intel HD 6000） |
| 截图 | 9 张 1920×1080（`docs/shots/01…09`） |
| 视频 | 10.0s MP4 1280×720@30 / GIF 800×450@15 |
| 720p 世界层 | 217.9 avg / 211.4 min FPS, 11 draw calls |
| 720p 含 HUD | 180.8 avg / 178.8 min FPS, 59 draw calls |
| 1080p 离屏世界层 | 153.8 avg / 134.7 min FPS, 11 draw calls |
| 1080p 离屏含 HUD | 141.0 avg / 140.6 min FPS, 59 draw calls |

证据日志：`/tmp/rain_verify.log`、`/tmp/rain_headless_boot.log`、
`/tmp/rain_gpu_boot.log`（本机；重启后 `/tmp` 会清理，命令可重跑）。

### 复现命令

```bash
godot --headless --path godot-rain-puddles --editor --quit
godot --headless --path godot-rain-puddles -s tools/smoke_rain_puddles.gd
godot --headless --path godot-rain-puddles --quit-after 600
godot --path godot-rain-puddles --resolution 1280x720 --quit-after 600
godot --path godot-rain-puddles -s tools/screenshot_rain_puddles.gd
godot --path godot-rain-puddles --resolution 1280x720 -s tools/probe_rain_puddles.gd
godot --path godot-rain-puddles -s tools/probe_rain_puddles_1080.gd
```

---

## 9. 已知限制 / 风险

1. **倒影不是实时的**：静态离线图集，移动角色/可破坏物不会自动入水；
   若后续要加动态角色，需要每帧重烘图集或做一次镜像 SubViewport + mask。
2. **水洼是静态 mask**：低洼场 seed 固定；运行时改地形需要重新生成
   `PuddleField` 和 shader 贴图。
3. **1×1 灯柱规则是简化实现**：不是完整 TileMap 占用；只覆盖本 demo 的
   2 盏灯、2 组石头、1 段石岸。
4. **1080p 测量是离屏**：macOS 限制窗口尺寸（实测被裁到 1440×762），
   所以用 1920×1080 的 SubViewport 强制 1080p GPU 渲染；数值比全屏显示略保守。
5. **HUD draw calls 高**：59 总调用里约 48 来自 UI 控件；世界层只有 11。
   如果后续要严格压总调用，需要合并 UI 或使用自绘面板。
6. **录制统计隐藏**：视频里不显示实时 FPS/draw calls，原因是逐帧抓图本身
   会把实时 FPS 拉低；运行态与截图仍显示。
7. **像素尺度**：世界内部 640×360，1080p 是 3× 最近邻放大；不追求高清纹理。
8. **音频**：无音频；素材/依赖为零，符合“无第三方运行库”约束。
