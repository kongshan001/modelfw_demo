# 静水回廊 · 技术拆解

任务：Godot 4.6 复刻 B 站视频《硬核源码拆解｜拒绝塑料贴纸感！单人手搓 Unity 2D
像素法线受光 + 零额外相机水面夜景反射》中的数学/渲染思路。  
参考：<https://www.bilibili.com/video/BV1ePyizHED1>（UP：小武同学贼下饭）。

只借鉴了这些技术概念：法线正交拆解、沿脚底/水线锚点翻折、单 Mesh 合批、
`round()` 整格水波、暖色像素优先保留。**没有**使用视频帧、Unity 工程、C#/HLSL
代码或任何美术素材。

---

## 1. 渲染总览

```text
root Viewport (1280×720，canvas_items；1920 时 1.5×)
  └── Main (Node2D)
       ├── Camera2D                 ← 全项目唯一的 Camera2D，zoom=4
       ├── World (Node2D)
       │    ├── Sky                 z=-100  程序化夜空/远山/远镇（unlit）
       │    ├── WaterBase           z=-40   320×180 baked 深水 + 月影
       │    ├── Reflections         z=-30   单 Mesh（1 surface / 6 quads）
       │    ├── WaterOverlay        z=-20   additive 波光/月影/暖灯反射碎金
       │    ├── Bank / 2 buildings / 2 trees / 2 lamps / rocks / dock
       │    └── DebugOverlay        z=90    光向量/岸线/四边形/量化刻度
       └── HUD (CanvasLayer)        参数面板/FPS/draw calls
```

- **没有** `SubViewport`、离屏 RenderTarget、第二个 Camera2D、屏幕抓取、SSR
  或后处理。世界所有内容都在 root Viewport 中由同一台 Camera2D 渲染。
- 场景美术为 **320×180** 世界像素。Camera2D `zoom=4`：1280 窗口下 1 美术像素
  = 4 屏像素；1920 下 canvas_items 再线性放大 1.5×，共 6 屏像素，仍为整数。
- 1920 截图 / probe 使用 macOS 的 borderless 根窗口（放在屏幕外）获得真实
  1920×1080 root viewport；不是第二个 Viewport。视频用 Movie Maker 录制
  1280×720 帧，再用 ffmpeg 最近邻放大到 1920×1080。

文件职责：

| 文件 | 说明 |
| --- | --- |
| `scripts/pixel_surface.gd` | 高度/法线 bias/粗糙度/自发光四层；生成 normal/roughness |
| `scripts/pixel_art.gd` | 11 个受光物件的程序化像素画与夜景背景 |
| `scripts/reflection_field.gd` | 图集打包、镜像 quads、单 ArrayMesh、量化位移函数 |
| `shaders/lit_sprite.gdshader` | CanvasItem 手动光照：环境+方向+2 点光+高光+自发光 |
| `shaders/reflection.gdshader` | mask 裁切、暖像素保留、整格 UV 位移、深度变淡 |
| `shaders/water_overlay.gdshader` | additive 波光/月影/暖灯碎金 |
| `scripts/main.gd` | 状态、uniform 同步、输入、截图/验收接口 |
| `scripts/debug_overlay.gd` | 光向量、mask 岸线、倒影线框、水波刻度 |

---

## 2. 程序化像素画与法线图

全部 albedo / normal / roughness / emission 由固定种子 GDScript 绘制，无外部贴图。

### 2.1 四层数据

`PixelSurface` 为每个物件保存四层（分辨率与 albedo 相同）：

1. `image`：RGBA8 albedo（透明背景）。
2. `heights`：每像素高度场，用来生成法线细节。
3. `roughness`：每像素粗糙度（0=光滑 1=粗糙）。
4. `emission`：每像素自发光遮罩。
5. 另有 `normal_bias`：每像素的大形法线偏移（x/y）。

法线图 = R/G/B 编码 normal，**alpha 通道顺便存 emission**，因此每个物件只需
绑定 `albedo + normal/emission + roughness` 三张纹理。

### 2.2 高度场 → 细节法线

对每个 opaque 像素做中心差分：

```text
dx = (h[x+1,y] - h[x-1,y]) * gain
dy = (h[x,y+1] - h[x,y-1]) * gain
n  = normalize(vec3(-dx + bias_x, -dy + bias_y, 1))
```

透明邻居的高度取 `EDGE_HEIGHT = -0.34`，使轮廓边缘自然出现倒角法线，而不是
贴纸式全平面。不同物件使用不同 gain（1.9–2.35）。

### 2.3 大形 normal bias（关键）

只靠高度场时，大块的墙/屋顶/树冠仍接近平面，方向光改变时整体变化很小，
容易回到“塑料贴纸”。因此额外写了一层低分辨率的大形法线：

- **屋顶**：以屋脊为分界，左右两坡的 normal x 分别朝外，y 略朝上；
  光从左侧/右侧来时两坡明暗翻转。
- **墙面**：轻微凸面 bias（中心平、边缘向外 ≤0.26），左右受光有细微衰减。
- **树冠**：以树冠中心为原点，normal xy 指向外；叶片高度场提供细碎起伏。
- **松树 / 石头**：圆柱/圆顶 bias，让针叶层和石块有明确朝向。
- 细节高度场仍保留窗框/木梁/砖缝/叶簇的 1px 凹凸。

这就是本项目对“法线正交拆解”的落地：法线先表示成 `(x, y, z)`，进入 shader
后用正交基重组，并让大形 bias 与细部高度场叠加。

### 2.4 粗糙度与自发光

- 窗玻璃/灯芯 roughness≈0.14–0.2；木/石/叶 ≈0.8–0.95；金属灯柱 ≈0.3–0.5。
- 自发光只标在窗芯、灯笼玻璃等像素上（大多数为 0），避免整面暖墙发光。
- 暖窗的 emission 遮罩约 0.48–0.68；街灯玻璃约 0.68–1.0。
- `PixelSurface.finish()` 把 emission 写进 normal map 的 alpha。

---

## 3. 2D 法线受光 shader

`shaders/lit_sprite.gdshader`，`canvas_item`，`render_mode blend_mix, unshaded`
（手动光照，不使用全局 Light2D）。每个受光物件一个 ShaderMaterial，共 11 个。

### 3.1 正交重组

```glsl
vec3 ortho_detail_normal(vec3 detail, float strength) {
    detail.xy *= strength;
    detail.z = max(detail.z, 0.055);
    vec3 basis = normalize(vec3(0.0, 0.0, 1.0)); // 面向屏幕外
    vec3 helper = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(helper, basis)); // (1,0,0)
    vec3 up = cross(basis, right);                // (0,1,0)
    return normalize(right * detail.x + up * detail.y + basis * detail.z);
}
```

`detail.xy` 是法线贴图的切向分量，`basis` 是贴片基础法线。当前项目的基础
法线是屏幕外 (0,0,1)，但屋顶/树冠/石头等大形方向已经烘进 normal bias；
重组步骤保证它们是正交归一化的，不会因 x/y 缩放而出现“拉丝高光”。

### 3.2 参数

| Uniform | 默认 | 作用 |
| --- | --- | --- |
| `u_light_dir` | (0.574, -0.819) | 屏幕 2D 光向，指向光源 |
| `u_light_color` | (0.64,0.78,1.0) | 冷月光颜色 |
| `u_light_energy` | 1.18 | 方向光能量 |
| `u_ambient_color` | (0.125,0.18,0.29) | 环境光 |
| `u_normal_strength` | 1.0/1.15 | 法线 xy 强度（枫树 1.15） |
| `u_specular_strength` | 0.26 | 高光强度 |
| `u_lamp_a/b` | (113,78)/(185,78) | 两盏暖灯的 2D 点光位置 |
| `u_lamp_energy/radius/height` | 2.0 / 60 / 22 | 点光能量、半径、离面高度 |
| `u_normals_on` | true | 关掉后法线压平，用于对比 |
| `u_debug_mode` | 0 | 1=输出 world normal RGB；2=roughness |

### 3.3 光照公式

```text
L = normalize(vec3(light_xy, 0.82))          // 2D 光向 + 固定仰角
diffuse = max(dot(N,L),0) 与 smoothstep 的混合
ambient = albedo * ambient_color * (0.72 + 0.28*max(-N.y,0))
direct  = albedo * light_color * light_energy * diffuse
spec    = pow(max(dot(N,H),0), mix(96,8,rough)) * (1-rough) * 0.26 * diffuse
lamp_i  = albedo * lamp_color * max(dot(N,normalize(vec3(lamp_pos-world,22))),0)
          * (1-smoothstep(5,60,dist)) * 2.0 * flicker
emission= albedo * normal.a * u_emission_strength
color   = ambient + direct + spec + lamp_a + lamp_b + emission
```

- 光角 UI：0°=正上，90°=右；`light_xy = (sin(a), -cos(a))`。
- 点光衰减在 5–60 世界像素内，灯高 22 参与 3D 方向，让灯附近的墙面/树冠出现
  暖色方向光，而远离灯的物体不受影响。
- 半兰伯特混合系数 0.42，让背光面保留冷环境色，同时不洗掉受光面。
- 每个方向的光并非固定烘焙；拖光角或换预设会立刻重新计算 11 个材质。

---

## 4. 单相机水面倒影

### 4.1 为什么不开第二相机

传统 2D 反射常用第二 Camera2D + SubViewport 抓屏，再在 shader 中采样。
本实现不再渲染一遍场景：

1. 启动时把 6 个近岸物件的 albedo 打包进一张 **512×128** 图集；
2. 每个物件按几何关系沿水线翻折，生成 2 个三角形（6 顶点）；
3. 6 个物件共 36 顶点，放进 **一个 ArrayMesh 的单个 surface**；
4. 用 `reflection.gdshader` 采样图集，并按共享水面 mask 裁切。

结果是：**1 个 MeshInstance2D、1 个 surface、1 个 draw call**，没有第二台
相机、没有 RenderTarget、没有后处理。

### 4.2 镜像映射

物件的世界矩形 `x0..x1, y0..y1`，水线/脚底锚点为 `waterline=120`：

```text
反射四边形：
  (x0, waterline)   -- UV 取源图左下 (u0,v1)
  (x1, waterline)   -- UV 取源图右下 (u1,v1)
  (x1, waterline+h) -- UV 取源图右上 (u1,v0)
  (x0, waterline+h) -- UV 取源图左上 (u0,v0)
```

近水边对应原图底部（脚底），远端对应原图顶部；因此建筑灯窗、树冠、街灯都在
水线下方以正确的上下关系出现。当前近岸物件的美术脚底在 y=112，水线/倒影锚点
取 y=120 的石岸外缘；这是 2D 平面倒影的刻意 cheat，掩藏在岸沿阴影/压顶石后。

图集每边留 6px 透明 padding，防止 `round()` 水平位移采样到相邻物件的像素。
水面 mask 为 320×180 的 1-bit alpha；`reflection.gdshader` 对 mask 采样后
`discard`，所以倒影不会出现在石岸、天空或码头遮挡区。

### 4.3 保留暖色像素

```glsl
float lum  = max(src.r, max(src.g, src.b));
float warm = clamp((src.r - src.b) * 2.2, 0.0, 1.0)
           * smoothstep(0.22, 0.82, lum);
vec3  cool = src.rgb * vec3(0.45, 0.64, 0.78);
vec3  hot  = src.rgb * vec3(1.05, 0.78, 0.50);
float alpha= src.a * mix(0.38, 0.68, warm) * (1.0 - 0.30 * depth);
```

树影/暗墙压成冷蓝色，低不透明度；暖窗和灯芯保留更强的 alpha 与暖色。再叠加
水面深色底和 additive 波光后，倒影读起来像夜景水面，而不是镜面贴纸。

灯关掉时，不仅点光和 glow 关闭，reflection shader 也会按两盏灯的图集 UV 矩形
丢弃灯本体倒影；水面 overlay 的暖色碎金同步关闭。

### 4.4 整格水波

`reflection.gdshader` 以世界像素行（先 `floor`）计算相位：

```glsl
float row = floor(v_world.y);
float phase = sin(row * 0.86 + u_time * u_wave_speed * 1.6) * 0.68
            + sin(row * 0.31 - u_time * u_wave_speed * 0.90) * 0.32;
float step_px = max(u_wave_step, 1.0);
float shift_px = round(phase * u_wave_amplitude / step_px) * step_px;
vec2 uv = UV + vec2(shift_px / u_atlas_size.x, 0.0);
```

- 不按顶点平滑插值，也不做透视拉伸；每个世界像素行整体平移整数个图集像素。
- 1 美术像素 = 1280 下 4 屏像素 / 1920 下 6 屏像素，所以跳变肉眼可见。
- `u_wave_amp` 0–4、`u_wave_step` 1–4，HUD 可实时调；GDScript 的
  `NormalWaterReflection.quantized_shift()` 与 shader 公式完全一致，用于
  smoke 验收和调试刻度。
- 时间使用 GDScript 注入的 `u_time`，而不是 shader 内 `TIME`；暂停/时流 0
  时水波、灯光闪烁、glow 都真正冻结。

### 4.5 水面叠加层

`water_overlay.gdshader` 是 additive 透明层，不复制倒影本体：

- 2px 网格稀疏碎光；整行 `round()` 位移后的横向波纹亮带；
- 月亮 (x=252) 下方的短横条月影；
- 两盏街灯 x 位置的破碎暖色倒影；
- 水线 1px 浪花。
- 所有 pattern 都落在世界像素格上，且用统一 mask 限定在水面。

水底色由 `PixelArt.build_water_base()` 离屏生成：靠近岸边的浅水和深水渐变、
少量水平色带、很淡的月影与漂浮叶；它不参与光照 shader。

---

## 5. 场景、材质与像素完美

- 受光物件共 11 个：河岸、酒馆、杂货铺、枫树、松树、2 盏街灯、2 处岸边石头、
  前景大石、木码头。每个物件独立 ShaderMaterial，各自绑定 normal/roughness。
- 所有 Sprite 的 `centered=false`，位置和尺寸为整数；`texture_filter=nearest`。
- 项目设置：
  - `renderer/rendering_method="gl_compatibility"`
  - `window/size/viewport_width/height=1280×720`
  - `window/stretch/mode="canvas_items"`
  - `textures/canvas_textures/default_texture_filter=0`
  - `2d/snap/snap_2d_transforms_to_pixel=true`
  - `2d/snap/snap_2d_vertices_to_pixel=true`
- 夜景色板、星点/月盘/远山/雾带、酒馆/杂货铺/枫树/松树/街灯/石岸/码头/
  浮叶全部由 `pixel_art.gd` 固定种子绘制；没有加载图片文件。
- UI 用系统字体（PingFang SC 等），深墨+黄铜色栏板；只有 `HUD` 一个 CanvasLayer。

---

## 6. 交互与调试

- HUD：光方向/强度/光色预设、法线受光、波速/波幅/量化格、倒影、暖灯、
  时流、调试叠加、法线视图、暂停、重置。
- 键盘：见 README。
- 调试叠加（F）绘制：
  - 顶部中央金色光向量箭头（世界坐标）；
  - 黄色 mask 上缘岸线；
  - 每个倒影四边形的青色线框；
  - 水面左侧的 14 条 `round()` 量化取样刻度；
  - 法线视图打开时顶部 "NORMAL rgb" 标签。
- 法线视图（V）把受光 Sprite 的 world normal 直接输出为 RGB；用于检查
  法线贴图方向/正交重组是否正确。
- HUD 每 0.22s 刷新 FPS、draw calls、倒影 quads、水波步长、法线状态。
- 暂停只冻结 `_process` 的时间累加；UI、相机和调试叠加仍可操作。

---

## 7. 性能

测试机：Intel HD Graphics 6000（OpenGL 4.1，GL Compatibility），关 VSync。
系统有其他 worker 并行运行时测得：

| 场景 | avg FPS | min FPS | Draw calls |
| --- | ---: | ---: | ---: |
| 1280×720 世界层（默认倒影/暖灯/11 受光物） | 314.9 | 313.1 | 17 |
| 1280×720 含 HUD | 246.8 | 247.2* | 81 |
| 1920×1080 世界层（borderless 根窗口） | 119.0 | 114.4 | 17 |
| 1920×1080 含 HUD | 109.7 | 107.5 | 81 |

- 世界层 17 个 draw call：11 受光物件 + 天空 + 水底 + 倒影 Mesh + 水 overlay +
  2 个灯 glow。
- 倒影只有 1 个 surface，不存在 6 个独立倒影 Sprite；避免了 6 个额外 draw call。
- 没有后处理 pass；没有第二相机多渲染一遍场景。
- 1920 的 81 draw call 主要来自 HUD 的 Label/Panel/Button/Slider。
- 采样窗口只有 1s，`*` 处 HUD 的 1s 最低值略高于 4s 均值属于采样噪声；以均值
  和独立运行结果为准。两者均远高于 30 FPS 目标；读数随系统负载波动。

### 7.1 截图/视频工具

- `tools/screenshot_normal_water.gd`：普通窗口会被 macOS 桌面裁切，因此把
  borderless 根窗口设为 1920×1080 并移到屏幕外；仍使用唯一 Camera2D + root
  Viewport，不创建 SubViewport。输出 8 张 1920×1080 PNG。
- `tools/probe_normal_water_1080.gd`：同样的根窗口方式测量真实 1080p 性能。
- `tools/capture_normal_water.gd`：Movie Maker 模式录制 300 帧（30fps）到
  `/tmp/normal_water_frames`；HUD 隐藏，原创字幕由工具自己的 CanvasLayer 提供。
  `tools/build_media.sh` 用 ffmpeg 生成 1920×1080 MP4 与 960×540 GIF。
  之所以不用逐帧 `get_image()+save_png()`，是因为在 1920 下主线程截图开销极大，
  Movie Maker 的离屏编码路径快一个数量级。

---

## 8. 验收

```bash
godot --headless --path godot-pixel-normal-water -s tools/smoke_normal_water.gd
godot --path godot-pixel-normal-water -s tools/screenshot_normal_water.gd
godot --path godot-pixel-normal-water --resolution 1280x720 -s tools/probe_normal_water.gd
godot --path godot-pixel-normal-water -s tools/probe_normal_water_1080.gd
godot-pixel-normal-water/tools/verify.sh
```

smoke 共 160 项，末行：

```text
NORMAL_WATER_SMOKE_OK checks=160
```

覆盖：

- demo 场景恰好 1 个 Camera2D，无 SubViewport / 嵌套 Viewport；
- 11 个受光物件都有同尺寸 albedo/normal/roughness，法线非平面、粗糙度有变化，
  只有灯窗/灯芯有 emission；
- 倒影 Mesh 1 个 surface、6 个 quads、36 顶点、512×128 图集、mask 绑定；
- reflection shader 含 `round()`、`u_wave_step`、mask discard、暖灯 UV 剔除；
- 量化步长整除、随时间变化、幅度 0 时归零；
- 光方向/强度/光色 uniform 更新；
- 暖灯/倒影/法线/调试/法线视图切换、暂停冻结、时流 0 冻结、重置；
- HUD 标题、FPS/DRAW、1 CAMERA、倒影/法线读数，至少 6 个 slider。

真实 GPU 600 帧与 headless 600 帧启动均为 0 ERROR。  
详细日志与截图/视频规格见 `docs/verification.txt` 与 README。

---

## 9. 限制与已知风险

1. **平面水反射不是真实反射**：只有 6 个近岸物件进入图集，码头/前景大石/
   远景城镇不反射；没有菲涅耳、折射或 SSR。
2. **没有逐像素深度排序**：单 Mesh 里的透明四边形按固定顺序画；若挪动物件产生
   重叠，可能出现前后错误。当前布局已避开。
3. **法线是程序化近似**：大形 bias + 高度场 Sobel，视觉可读但不等于美术逐像素
   手绘法线；极端光角下窗框/叶片的法线可能出现硬边。
4. **水面 mask 是 1-bit**：岸线/倒影裁切是硬像素边，没有柔边；这是像素风选择，
   但不是物理正确的水陆边界。
5. **视频与截图分辨率来源不同**：截图是 1920 root 原生；视频源是 1280 Movie
   Maker 再最近邻放大到 1920，因为 Movie Maker 在项目 1280 逻辑分辨率下录制。
6. **截图/1080 probe 的窗口技巧**：macOS 上普通窗口被裁切，所以用 borderless
   根窗口放到屏幕外。它不改变 demo 的运行时单相机/零额外 Viewport 约束；但
   如果换平台/显示环境，截图工具可能需要调整窗口策略。
7. **系统字体**：中文 UI 依赖 PingFang SC / Noto Sans CJK 等系统回退字体；
   项目不打包字体文件，不同机器字形可能略有差异。
8. **无音频**：演示视频没有音轨；本技术任务不需要。
9. 参考视频里更高保真的手绘法线/美术构图没有被逐像素复制；本项目是独立原创
   场景与程序化素材。
