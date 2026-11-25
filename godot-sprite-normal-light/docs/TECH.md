# 灯影工坊 · 技术拆解

任务：按 B 站翻译教程《Godot 法线贴图：实现精灵光照效果》复刻一个可交互的
2D 精灵法线贴图光照 demo。  
参考：<https://www.bilibili.com/video/BV1TJsc61Ewe>（短链 <https://b23.tv/3eSeHcH>，
4:16，UP 寓学堂，原作者 Coding Quests）。

只复刻**技术/视觉语言**：高度图生成法线、Sprite + 法线图、可移动点光、
法线开/关对比、光高/颜色调参。没有复制教程的工程、代码、角色素材或画面；
所有像素画、高度图、法线图与场景均为本项目原创。

---

## 0. 参考视频的实际做法（抽帧确认）

用 `yt-dlp` 拉 720p + `ffmpeg` 每 4s 抽帧，确认教程的关键路径：

1. 在 Aseprite 里用 normal-map 插件，从高度/明暗图导出角色 spritesheet 的
   **normal map**；原 sprite 与 normal map 都是像素级 PNG。
2. Godot 里在 Sprite2D 上创建/指定 **CanvasTexture**，Inspector 中填写
   `Diffuse`、`NormalMap`（`Specular` 留空，`Shininess = 1.0`）。
3. 场景用 **PointLight2D**（带一张径向 light.png）+ 灰色 `ColorRect` 背景；
   同一角色上下两份：`With Normal Map` / `Without Normal Map`。
4. 把点光拖到角色附近，法线版出现体积/明暗；平面版只有一块均匀亮斑。
5. 再调 PointLight2D 的 **Height**、颜色/能量，展示法线方向对光照的响应。

结论：教程的 Godot 端走的是**原生 2D 光照路径**（CanvasTexture + Light2D），
不是自定义 shader。本项目原样实现了这条路径作为对照模式（`M`），
主路径则用自定义 CanvasItem shader，把教程里的 height/颜色/能量等调参做得更可控。

---

## 1. 工程与渲染结构

```text
root Viewport (1280×720 逻辑，canvas_items；1920 时内容 1.5×)
  └── Main (Node, main.gd)
       ├── World (Node2D, lit_room.gd)
       │    ├── RoomWall  (320×116, z=-20)
       │    ├── RoomFloor (320×64,  z=-19)
       │    ├── Guardian  (64×88,   z=0)
       │    ├── Barrel    (44×54,   z=1)
       │    ├── Golem     (36×48,   z=2)
       │    ├── 3 baked contact shadows (unshaded, z=-2)
       │    └── Camera2D (position 160,90, zoom 4)
       ├── LightRig (Node2D) + EmberGlow + NativePointLight + NativeDirectionalLight
       ├── NativeFillLight (DirectionalLight2D)
       ├── CanvasModulate
       ├── DebugOverlay (Node2D, 世界矢量化调试)
       └── HUD (CanvasLayer, 中文面板)
```

- 世界是 **320×180 美术像素**。`Camera2D.zoom = 4`，在 1280×720 逻辑下
  1 美术像素 = 4 屏幕像素；1920 时 root 的 `canvas_items` 再 ×1.5，即 6 屏幕像素。
- 五张受光 Sprite 均 `centered=false`、整数坐标、nearest 过滤；没有旋转/非整数缩放。
- 没有 SubViewport、没有第二相机、没有后处理；运行时 9 个世界 draw call
  （含 glow/阴影），HUD 再加约 78 个。
- 像素完美设置：
  - `textures/canvas_textures/default_texture_filter=0`（Nearest）
  - `2d/snap/snap_2d_transforms_to_pixel=true`
  - `2d/snap/snap_2d_vertices_to_pixel=true`
  - Camera zoom 固定整数 4（截图 1920 时由窗口 stretch 得到 6）。
- 唯一的非 nearest 元素是 **EmberGlow**（软光晕，linear）——它表示光源本体，
  不是贴图像素；其位置按世界浮点移动，避免 8px/帧的跳格。

---

## 2. 原创资产管线（高度图 → Sobel 法线）

`tools/gen_assets.py`（Pillow，仅在开发期使用，无运行时依赖）。固定种子，完全可复现：

```bash
python3 tools/gen_assets.py
```

### 2.1 五张受光图

| 名称 | albedo 尺寸 | 内容 | 说明 |
| --- | --- | --- | --- |
| `room_wall` | 320×116 | 灰泥墙、木梁、砖带、窗、搁板罐子、工具板 | 环境背板 |
| `room_floor` | 320×64 | 木踢脚、三层错缝石板、排水格栅、钉子 | 光池载面 |
| `guardian` | 64×88 | 石狐守卫：尖耳、胸像、卷尾、苔藓、石座 | 体积/倒角最明显 |
| `barrel` | 44×54 | 橡木桶：竖板、铁箍、铆钉、桶盖 | 金属高光 |
| `golem` | 36×48 | 苔灵：圆身、大眼、叶芽、蘑菇、苔藓 | 球形法线/角色 |

每张输出：

- `<name>.png`：RGBA albedo；
- `<name>_height.png`：高度场灰度（仅调试/文档）；
- `<name>_normal.png`：切线空间法线，**A 通道 = 逐像素粗糙度**
  （0 smooth / 255 rough；这是本项目自定义约定，原生 Godot 2D 路径忽略该 alpha）。

辅助图：`glow.png`（加色光晕）、`light_radial.png`（原生 PointLight2D 的 128px
径向光纹理，RGB 与 alpha 同时衰减）、三张 `shadow_*.png`（石狐/木桶/苔灵的
烘焙接触阴影）。

### 2.2 高度场与大形法线

每个像素维护 `height`、`rough` 和二维 `bias`（大形法线偏移）。绘制时：

- 圆球/椭球（头、胸、苔灵身体）：`bias = ((x-cx)/rx, (y-cy)/ry) * strength`；
  桶身用水平圆柱 bias；叶芽用朝外 bias。
- 透明邻居高度取 `edge_height = 0.02`，因此每个轮廓都有 1px 倒角法线，
  不是“整块平面 + 贴纸轮廓”。
- 细节高度：砖缝、木纹、铁箍、铆钉、石座台阶、眼睛凹陷、裂缝。
- 大面积灰泥**不做逐像素高度噪声**（早期版本做过，点光下出现满墙静电闪烁；
  见迭代记录），只保留 albedo 的脏点。

### 2.3 Sobel / 中心差分

对每个不透明像素（屏幕坐标 x 右、y 下）：

```text
dx = (hR - hL) * gain
dy = (hD - hU) * gain
nx = -dx + bias_x
ny = -dy + bias_y       // 屏幕 y 向下
n  = normalize(vec3(nx, ny, 1))
```

编码为 OpenGL / Godot 常用的**绿色 = +Y 向上**：

```text
R = nx * 0.5 + 0.5
G = -ny * 0.5 + 0.5
B = nz * 0.5 + 0.5
A = roughness * 255
```

各图 gain：墙/地板 3.8，石狐 4.0，木桶 4.2，苔灵 4.0。砖块/铁箍/铆钉的
高度差在这里变成明确的方向法线；粗糙度 alpha 让铁箍/眼睛/铆钉比石头/木头
更容易出高光。

### 2.4 导入设置（关键）

所有 `*_normal.png` 的 `.import` 都显式固定：

```ini
compress/mode=0                    ; lossless（保留 alpha 粗糙度）
compress/normal_map=2              ; Enabled：按 normal map 处理，不做 sRGB→linear 误读
mipmaps/generate=false
process/normal_map_invert_y=false  ; 保持 +Y 绿（OpenGL / Godot 2D）
detect_3d/compress_to=0
```

- 法线贴图是**向量数据**，不能按普通 sRGB 颜色贴图解释；`compress/normal_map=2`
  是这里的色彩空间/压缩语义保证。
- 不用 mipmap：相机是整数 zoom，2D 像素风不需要 mip；同时避免远处法线变糊。
- 自定义 shader 里采样器声明 `uniform sampler2D normal_tex : hint_normal;`。
- `process/normal_map_invert_y=false`：DirectX 绿向下的贴图需要改为 `true`；
  本项目的原生 Light2D 对照也使用同一张绿色朝上的图，两者方向一致。

---

## 3. 自定义 CanvasItem 光照 Shader

文件：`shaders/sprite_normal_light.gdshader`，`render_mode unshaded, blend_mix`。
每个受光 Sprite 一个 `ShaderMaterial`，共享下列 `[shader_globals]`；每个材质只绑定
自己的 `normal_tex` 和 `flip_x`。

### 3.1 顶点：世界位置 + 法线矩阵

```glsl
v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
mat2 basis = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy);
v_nmat = transpose(inverse(basis));   // 逆转置：旋转 + 非均匀缩放下法线正确
```

`MODEL_MATRIX` 在 CanvasItem fragment 不可用，所以放到 vertex 里算成 varying。

### 3.2 片元：解码 + 方向 + 高光

```glsl
vec3 nd = texture(normal_tex, UV).rgb * 2.0 - 1.0;
nd.xy = vec2(nd.x * flip_x, -nd.y);   // 绿向上 → 屏幕 y 向下；flip_h 镜像 x
nd.xy *= u_normal_strength;
if (!u_normals_on) nd = vec3(0.0, 0.0, 1.0);

vec2 n_world = v_nmat * nd.xy;
float n_len = length(n_world);
n_world = n_len > 0.0001 ? n_world / n_len : vec2(0.0);
vec3 N = normalize(vec3(n_world, max(nd.z, 0.035)));

// 点光
vec3 to_light = vec3(u_light_pos - v_world, u_light_height);
vec3 L = normalize(to_light);
float planar = length(u_light_pos - v_world);
float atten = pow(clamp(1.0 - planar / u_light_radius, 0.0, 1.0), 1.2);

// 方向光：0° 从上方，90° 从右侧
// L = normalize(vec3(sin(a), -cos(a), height / 80));

float diffuse = max(dot(N, L), 0.0);
vec3 V = vec3(0.0, 0.0, 1.0);
vec3 H = normalize(L + V);

float rough = clamp(ntex.a + (u_roughness - 0.5), 0.02, 1.0);
float shininess = mix(120.0, 6.0, rough);
float specular = pow(max(dot(N, H), 0.0), shininess)
               * u_spec_strength * (1.0 - rough * 0.72)
               * atten * smoothstep(-0.05, 0.25, dot(N, L));

float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0)
          * u_rim_strength * atten * (0.25 + 0.75 * diffuse);

vec3 light = u_light_color.rgb * u_light_energy * atten;
vec3 col = base.rgb * (u_ambient_color.rgb + light * diffuse);
col += light * specular;
col += u_light_color.rgb * rim;
COLOR = vec4(min(col, vec3(1.0)), base.a);
```

- **环境光**是加色项（`albedo * ambient`），不与点光相乘；点光近处能压过环境光。
- **粗糙度** = 全局滑杆 + 法线图 alpha 逐像素；金属箍/眼睛 alpha 低，出窄高光；
  石头/苔藓 alpha 高，几乎只有漫反射。
- **高光**用 Blinn–Phong，`smoothstep` 抑制背光面针尖高光；强度默认 0.6，避免塑料感。
- **Rim** 只在边缘法线偏离视线时出现，做出石像/苔灵轮廓。
- 输出 `min(col, 1.0)` 做过曝保护；默认能量/颜色经截图校准，亮部集中在小面积高光。
- **零向量保护**：`u_normals_on=false` 时 `nd.xy = (0,0)`；若直接 `normalize(0)`
  在部分 GL 驱动上得到 NaN，会把平面模式渲染成黑色。本项目显式判断长度后
  取 `(0,0)`，这是最终版本的关键修复（见迭代记录）。

### 3.3 调试模式

`u_debug_mode`：

| 值 | 内容 |
| ---: | --- |
| 0 | 正常光照 |
| 1 | 输出切线空间法线贴图 RGB（检查导入/朝向） |
| 2 | 输出逐像素 L（`L*0.5+0.5`，检查光照向量/点光位置） |
| 3 | 输出漫反射灰度（检查衰减） |
| 4 | 正常光照 + 世界箭头标注（由 DebugOverlay 绘制，最易读） |

`DebugOverlay` 始终画：点光半径环、巡游椭圆、每个样本点的 L 箭头、
光源高度竖杆；仅在 debug 模式 ≠ 0 时显示。HUD 另有法线图缩略图和
`az / h` 光照向量表盘。

### 3.4 翻转/缩放

- **flip_h**：Sprite2D 的 UV 镜像；材质通过 `flip_x = -1` 同步镜像法线 x，
  光仍在世界空间。`X` 键翻转石狐，`08_flip_scale.png` 可对照。
- **缩放**：逆转置模型基矩阵处理旋转与非均匀缩放；苔灵 2× 时保持脚底锚点，
  法线方向不被拉伸破坏。uniform scale 对方向无影响，数学上应保持不变。
- 翻转/缩放都在顶点阶段进入 `v_nmat` 或通过常量 `flip_x`，不需要逐帧重建法线图。

---

## 4. 原生 Godot 路径（CanvasTexture + Light2D）

`M` 切到原生路径时，`lit_room.gd` 把每个 Sprite：

```gdscript
sprite.material = null
sprite.texture = canvas_texture   # CanvasTexture
canvas_texture.diffuse_texture = albedo
canvas_texture.normal_texture = normal
canvas_texture.specular_color = Color(0.36, 0.33, 0.28)
canvas_texture.specular_shininess = 0.28
```

光源：

- `PointLight2D`：`light_radial.png`（128px，RGB+alpha 径向衰减），
  `texture_scale=6`，`height` 跟随 UI 光高，`energy = UI 强度 × 2.2`。
- `DirectionalLight2D`：方向光模式使用，`rotation = deg(方位角)`，`height` 同上。
- `NativeFillLight`（冷色 DirectionalLight2D）+ `CanvasModulate`：原生环境底色。
- 阴影精灵/glow 保持 unshaded；HUD 的 CanvasLayer 不受世界光影响。

### 为什么有补光（重要）

原生 2D 光照里，`CanvasModulate` 会把**最终光照结果**一起乘色。若把环境色
直接设为 `(0.27, 0.31, 0.43)`，点光的贡献也会被压暗，角色几乎全黑。
实测对比后改为：

```text
CanvasModulate = (0.22,0.24,0.30) + (0.38,0.40,0.46) * ambient_strength
NativeFillLight.energy = ambient_strength * 0.7   // 冷色、height 54
```

这样墙/地板保留夜色底，点光仍有明显暖色光池，角色可读。它不是教程里的
“纯 CanvasModulate”方案，而是本项目为了让原生路径在夜景里可读做的补充；
TECH 如实记录，不把它当作物理正确的环境光。

### 原生 vs 自定义的差异

| 项 | 自定义 Shader | 原生 Light2D |
| --- | --- | --- |
| 光源数 | 1 个点光或 1 个方向光 | PointLight2D / DirectionalLight2D，可加补光 |
| 环境光 | 加色 `albedo * ambient` | CanvasModulate（乘色）+ 冷色补光 |
| 法线强度 | 0–2 连续调 | 无（固定贴图强度） |
| 高光/粗糙度 | Blinn–Phong + 逐像素 alpha 粗糙度 | CanvasTexture specular，近似、全局 |
| 边缘光 | 有 | 无 |
| 调试视图 | 法线/光向量/漫反射/标注 | 无（HUD 会强制切回 Shader） |
| 观感 | 对比强、体积明显 | 平、整体均匀，用于“引擎原生行为”对照 |

原生路径忠实对应教程的 CanvasTexture + PointLight2D 做法；但要公平地说，
它的最终观感与自定义路径不同，且本项目没有为原生路径制作 specular map，
所以金属/石头的高光区分不如 shader 路径。

---

## 5. 像素完美、场景与 UI

- 美术 320×180；相机 zoom 4；1280 逻辑窗口下 1 art px = 4 screen px；
  1920 时 root stretch 1.5 → 6 screen px，仍为整数倍。
- 所有精灵位置为整数；`centered=false`；nearest；snap 2D transforms/vertices。
- `EmberGlow` 使用 linear 的软光晕（例外，见上）；其余贴图 nearest。
- HUD 逻辑尺寸 1280×720；root 窗口在 1920 时由 `canvas_items` 统一放大 1.5×
  （实测面板 366 逻辑 px → 549 物理 px）；截图工具的 borderless 1920 根窗口
  得到的是真实 1920×1080，不是离屏放大。
- HUD 包含：标题/副标题、FPS/DRAW/路径、点光/方向光、光色、巡游、法线、
  调试、暂停、重置、8 个滑杆、原生提示、石狐法线缩略图、光照向量表盘、
  快捷键提示。系统字体回退（PingFang SC 等），不打包字体。
- 交互：拖拽/方向键移动光源；滑杆调整参数；按钮/快捷键切换路径与视图。

---

## 6. 性能

测试机：**Intel HD Graphics 6000（OpenGL 4.1，GL Compatibility）**，关闭 VSync，
`Engine.max_fps=0`；测试时系统还有其他 worker/Godot 进程并行，数字偏保守。

### 1280×720

| 项 | avg FPS | min FPS | draw calls |
| --- | ---: | ---: | ---: |
| Shader + HUD | 274.9 | 249.2 | 87 |
| Shader 仅世界 | 395.5 | 393.5 | 9 |
| 原生仅世界 | 289.6 | 287.5 | — |
| 法线图 debug + HUD | 194.0 | 188.1 | — |

`*` 1920 世界层的 min 略高于同段 avg，是 1s 采样窗口重叠造成的噪声；以 avg 为准。
系统负载会显著影响帧率；同一机器两次复测可能在 120–400 FPS 区间波动，均远高于 30 FPS 目标。

### 1920×1080

| 项 | avg FPS | min FPS | draw calls |
| --- | ---: | ---: | ---: |
| Shader + HUD | 150.2 | 144.5 | 87 |
| Shader 仅世界 | 154.3 | 154.9* | — |
| 原生仅世界 | 121.7 | 120.2 | — |

- 世界 9 draw calls：墙/地板/3 物体/3 阴影/glow；HUD 约 78。
- 法线光只有一次 fragment 光照，没有额外 light pass、没有后处理。
- 远超 30 FPS 目标；截图工具显示的瞬时 FPS 受逐帧 PNG 抓图影响，不作为性能结论。
- 性能探针：`tools/probe_sprite_normal_light.gd`、`tools/probe_sprite_normal_light_1080.gd`。

---

## 7. 验收与产物

```bash
godot --headless --path godot-sprite-normal-light -s tools/smoke_sprite_normal_light.gd
godot --path godot-sprite-normal-light --resolution 1280x720 -s tools/probe_sprite_normal_light.gd
godot --path godot-sprite-normal-light -s tools/probe_sprite_normal_light_1080.gd
godot --path godot-sprite-normal-light -s tools/screenshot_sprite_normal_light.gd
godot --path godot-sprite-normal-light --fixed-fps 30 -s tools/capture_sprite_normal_light.gd
```

- smoke：**181 checks / 0 failures**，末行 `SPRITE_NORMAL_LIGHT_SMOKE_OK`（上一行 `SMOKE_SUMMARY checks=181 failures=0`）。
- 600 帧 headless 与真实 GPU 启动均 0 ERROR/WARNING（详见 `docs/verification.txt`）。
- 截图：`docs/shots/01..09` 共 9 张，真实 1920×1080。
- 视频：`docs/sprite_normal_light.mp4` 10.0s / 1920×1080 / 30fps（源 1280×720
  固定 30fps 抓帧后最近邻放大），`docs/sprite_normal_light.gif` 10.0s / 960×540 / 15fps。
- 视频内容：法线 ON/OFF 对比、点光巡游、法线图/光照向量调试、金属高光、
  原生 CanvasTexture+Light2D、翻转+2× 缩放、回到主画面。

---

## 8. 与教程的差异（如实说明）

1. **原创素材**：教程里的角色/贴图/工程没有任何一份被复制；我们用 Python
   画了石狐/木桶/苔灵/房间，法线由高度图 Sobel 生成。
2. **主路径是自定义 shader**：教程用原生 CanvasTexture + PointLight2D；
   我们把原生路径完整保留为 `M` 对照，同时用自定义 shader 做连续法线强度/
   高光/粗糙度/rim/调试视图。两者都在 HUD 里可切换。
3. **原生路径环境光的处理**：教程用灰色背景和较亮场景；我们的夜景需要
   CanvasModulate + 冷色补光，且观感更平。这个差异在 HUD/文档中明示。
4. **没有制作原生 specular map**：教程的 Specular 留空、Shininess=1.0；
   我们设置了较低 specular color/shininess，但没有逐像素原生高光贴图。
5. **没有实时投影阴影**：物体下方是烘焙接触阴影；光源/物体移动时阴影不变。
6. **Aseprite → Python**：教程用 Aseprite 插件生成法线；本项目用
   `tools/gen_assets.py`（Pillow）从程序化高度场生成，便于复现和版本管理。
7. **Godot 4.6 vs 4.4.2**：教程画面是 4.4.2；本项目运行在 4.6 GL Compatibility，
   原生 2D 光照路径行为一致（已实测）。
8. **视频不是逐帧 1920 渲染**：截图是真 1920 根窗口；视频源为 1280 SubViewport，
   MP4 最近邻放大到 1920。原因见限制。

---

## 9. 已知限制与风险

1. **单光源**：自定义 shader 只有一个点光或一个方向光；没有多光源叠加。
2. **无实时阴影**：没有 LightOccluder2D 或手写 shadow map；只有 3 个烘焙接触阴影。
3. **法线采样是 nearest**：法线图 1 art px/texel，4×/6× 显示时每个法线 texel 是
   4×4/6×6 屏幕块，光照过渡有像素块感；这是像素风选择，不是 bug。若要更平滑，
   需要单独提高法线图分辨率（与 albedo 不同步）或改成线性采样法线。
4. **逐像素粗糙度存在 normal map 的 alpha 里**：原生 Godot 2D 光照忽略 alpha，
   所以原生路径没有逐像素粗糙度；如果用户替换法线图，alpha 约定可能被破坏
   （不影响原生路径，会影响自定义高光）。
5. **CanvasModulate 会乘最终光照**：原生路径用补光而不是纯 CanvasModulate，
   因此原生环境光不是单一物理量；HUD 的环境滑杆在两条路径上的含义略有不同。
6. **原生路径观感更平**：无法线强度/rim/逐像素粗糙度；点光纹理/高度是近似。
7. **调试色不是色彩管理后的颜色**：法线/光向量 debug 直接输出编码值，用于检查
   数据，不适合作为最终画面。
8. **接触阴影不随 2× 苔灵缩放**：`Z` 的 2× 是光照/法线正确性验证，阴影仍是
   原始尺寸。
9. **系统字体**：中文依赖 PingFang SC / Noto Sans CJK 等回退；不同机器字形略异。
10. **视频放大**：MP4 源帧 1280×720，最近邻 1.5× 到 1920；像素在视频里不是
    等宽 6px，截图才是真实 1920 的 6px。
11. **无音频**；演示不需要。
12. **`--import` 偶尔打印 `p_name.is_empty()`**：在此环境空测试工程也能复现，
    运行/截图/探针均 0 ERROR；作为工具链噪声记录，不影响 demo。
13. **单场景无存档**：参数/灯光状态不写盘；“重置”回到默认。演示目的足够。
14. **反作弊/内容安全**：没有用户输入/网络，无相关风险。

---

## 10. 常见坑清单（复刻时最容易踩）

- 法线贴图当 sRGB 颜色图导入：法线 XY 会偏向一侧，正面变暗；用 normal map import
  或 `hint_normal`，并固定 `process/normal_map_invert_y`。
- 绿色通道方向：Godot/OpenGL 用 +Y 向上；DirectX 贴图需要翻转 G。混合来源时
  先用调试模式 1 看法线图，再用顶光检查“上表面亮”。
- 对零向量 `normalize()`：平面模式（法线关闭/纯平图）会产生 NaN；必须加长度保护。
- 把环境光做成“乘色”：会连直接光一起压暗；2D 原生路径尤其明显。
- 点光半径太小/衰减平方太陡：角色在光池外，看起来像没开灯；先用大半径 + 柔和
  衰减定位，再收紧。本项目最终 `radius=240`、`pow(...,1.2)`。
- 逐像素高度噪声：近距离点光下会变成“静电雪花”；大面积材质应保持高度平滑，
  细节放在结构边缘（砖缝/箍/倒角）。
- 只在大形上加法线，不做轮廓倒角：物体像贴纸；透明邻域取低高度可自动出 1px 倒角。
- 翻转精灵时只翻 UV 不翻法线 x：光照会“反着来”；用 `flip_x` 配套。
- 缩放精灵时用普通矩阵变换法线：非均匀缩放会把高光拉丝；用逆转置。
- `MODEL_MATRIX` 不在 CanvasItem fragment 可用：放到 vertex 里算 varying。
- 用 HUD 滑杆直接改 uniform 但不 `queue_redraw`/全局更新：调试层/表盘可能滞后；
  本项目在 `_apply_lighting`/`sync_from_main` 里统一刷新。
- 截图时普通窗口被桌面裁切：使用 borderless + 负坐标根窗口，或 SubViewport。
- 视频逐帧 `get_image()` 与 `frame_post_draw` 的顺序/错误：脚本错误会让
  SceneTree 永不退出；自动化运行时必须保证每条路径都能到 `quit()`。
