# TECH · 樱庭日照

本文记录 `godot-sakura-sunlight/` 的实现口径。目标不是复刻 Unity 工程，而是用
Godot 4.6 / GDScript / canvas shader 复现参考视频的**数学闭环与视觉语言**：

> 固定机位 · 08:00–17:00 · 方位角 / 余弦高度角 · 全局 shader 光照 ·
> 影向取反 · 影长 = 树高 / tan(高度角) + 上限 · 树干/树冠两段投影。
> 不用 Light2D、不用 3D 灯光、不逐物传光照参数。

---

## 1. 时间口径（GameTime）

```gdscript
const TICKS_PER_DAY = 6000
const TICKS_PER_HOUR = 250
const HOURS_PER_DAY = 24.0

hour_to_ticks(h) = round(fposmod(h, 24) * 250) % 6000
ticks_to_hour(t) = posmod(t, 6000) / 250
```

| 时刻 | 当天刻数 |
| --- | --- |
| 08:00 | **2000** |
| 12:00 | 3000 |
| 16:00 | 4000 |
| 17:00 | **4250** |
| 24:00 | 6000（回绕到 0） |

- 交互窗口是 08:00–17:00；UI 滑杆范围同此。
- 1× 自动播放：`(17-8)h / 90s = 0.1 h/s`；0.5× / 2× / 4× 对应 180s / 45s / 22.5s 一轮。
- 17:00 → 08:00 回绕；滑杆值由 `sync_from_main()` 用 `set_value_no_signal()` 同步，
  不会触发回调递归。
- 拖动滑杆时 HUD 主动 `set_playing(false)`，松手后保持暂停；需要按「播放」继续。
- 暂停只冻结时间/日照，花瓣继续飘落（交互选择，见 README 的限制说明）。

实现：`scripts/sun_model.gd`、`scripts/main.gd`、`scripts/hud.gd`。

---

## 2. SolarModel / TerrainSunlight

### 2.1 日弧与余弦高度角

```gdscript
arc      = (hour - 12) / 6          # 06:00=-1, 12:00=0, 18:00=+1
elevation = 70° * cos(|arc| * π/2)  # 正午 70°
```

| 时刻 | 高度角 | 参考对照 |
| --- | --- | --- |
| 08:00 | 35.00° | 与 16:00 对称 |
| 09:45 | **58.20°** | 参考视频 09:45 显示 58.2° |
| 12:00 | **70.00°** | 参考「余弦算高度角 · 正午 70°」 |
| 12:03 | 69.95° | 参考 12:03 显示 69.9° |
| 16:00 | 35.00° | |
| 17:00 | 18.12° | 进入影长封顶区 |

### 2.2 方位角与平面光照向量

本项目把方位角定义为**屏幕平面角**，不是地理方位：

```gdscript
azimuth = 90° + arc * 60°          # 08:00=50°, 12:00=90°, 17:00=140°
sun_dir = (cos(az), -sin(az))      # 屏幕坐标 y 向下；0°=右，90°=上
shadow_dir = -sun_dir              # 地面影向 = 太阳向量取反
```

- 08:00：太阳在右上（50°），影子落左下。
- 12:00：太阳在正上（90°），影子落正下。
- 16:00：太阳在左上（130°），影子落右下。
- 17:00：太阳更低（140°），影子更长并封顶。

> 参考视频用 `GroundSunShadows` 的 `-sun.Direction` 求影向；本项目保持同样的
> **取反**语义。屏幕投影约定（尤其是正午/下午的具体角度）是原创的固定机位设定，
> 不逐像素复刻参考。

### 2.3 影长公式与上限

```gdscript
elev_c = clamp(elevation, 1.0, 89.5)
raw    = visual_height / tan(deg_to_rad(elev_c))
cap    = visual_height * maximum_multiple
length = min(raw, cap)
```

| 项目 | 值 |
| --- | --- |
| 树的上限倍数 | **1.8 H** |
| 石头的上限倍数 | 1.6 H |
| 高度角下限/上限 | 1.0° / 89.5°（防止 tan 爆炸） |
| 主角树视觉高度 | ≈131 px（可见树干 33 + 树冠内容高度） |
| 08:00 影长 | ≈187 px（1.43 H） |
| 12:00 影长 | ≈47.7 px（0.364 H） |
| 17:00 原始/封顶 | 401 px → **236 px（1.80 H）** |

参考视频 12:03 显示「未限长时，影长约为树高的 0.36 倍」；本项目正午 70° 的
`1 / tan(70°) = 0.364` 与其一致。参考另一帧的 0.94 倍对应约 46.8° 高度角，
同一公式同样复现：`1 / tan(46.8°) ≈ 0.94`。

---

## 3. 两段式地面投影（GroundSunShadows）

### 3.1 数学分段

对每个树影：

```text
direction      = -sun_plane_dir(hour)
total_length   = min(H / tan(elev), 1.8H)
trunk_length   = min(T / tan(elev), total_length)
crown_length   = total_length - trunk_length
junction       = base + direction * trunk_length
tip            = base + direction * total_length
```

- `H`：树冠顶到树根的视觉高度（`visual_height`）。
- `T`：树冠底部到树根的高度（`trunk_visible`）。
- 树干影从 `base` 开始，恰好到 `junction`。
- 树冠影的**底边中心**放在 `junction`，沿 `direction` 拉伸 `crown_length`。
- 所以 `trunk_length + crown_length = total_length`，没有悬空、断脚或缝隙。
- 树的 1.8H 封顶作用于总长；树干段先占 `T/tan`，其余给树冠。
- 石头没有树干段：`trunk_height=0`，整块石头剪影从根部沿影向拉伸，上限 1.6H。
- 额外在根部放一个低透明度的接触影（`ContactShadow`），低太阳角时也保持“落地感”。

### 3.2 节点变换

- 树干影：一条 20×64 的程序化锥形条；`centered=false`，原点在顶部中心；
  `rotation = direction.angle() - PI/2`，`scale.y = trunk_length / 64`。
- 树冠影：树冠 alpha 剪影，原点在底边中心；
  `rotation = atan2(direction.x, -direction.y)` 使贴图的“上方”映射到 `direction`；
  `scale.y = crown_length / crown_texture_height`，宽度不变。
- 剪影生成时对边缘做 1–2 px 的 alpha 软化（0.48 / 0.74 / 0.92），再乘全局
  `u_shadow_color.a`，避免像硬纸片；像素仍是最近邻。
- 切换阴影时，即使隐藏也继续更新变换和报告（修复了一个“关闭阴影时拖动时间，
  再打开会冻结在旧时刻”的 bug）。

### 3.3 覆盖对象

- 3 棵樱花树：主树 / 右侧树 / 前景小树，均有树干+树冠两段。
- 3 块石头：单段剪影 + 接触影。
- 每一个影子都可单独取得 `ShadowCaster.get_report()`：`raw_length`、`total_length`、
  `trunk_length`、`crown_length`、`junction`、`tip`、`capped`、方向、可见性。

---

## 4. 全局光照（不逐物传参）

### 4.1 注册与写入

`project.godot` 的 `[shader_globals]` 声明：

| 全局参数 | 类型 | 含义 |
| --- | --- | --- |
| `u_sun_dir` | vec2 | 屏幕平面太阳方向（单位向量） |
| `u_sun_elevation` | float | 太阳高度角（度） |
| `u_sun_color` | color | 当前直射光色温 |
| `u_ambient_color` | color | 冷色环境光 |
| `u_shadow_color` | color | 地面投影色（含 alpha） |
| `u_sun_intensity` | float | 直射光强度（0–1） |
| `u_shadow_strength` | float | 阴影总开关（0/1） |
| `u_time` | float | 全局时间（花瓣/着色器预留） |

`main.gd::_apply_solar()` 是**唯一**写这些值的地方：
`RenderingServer.global_shader_parameter_set(name, value)`。同一函数里也保存一份
`_global_uniforms` 镜像，供 headless 测试与 UI 使用。

> Godot 4.6 GLES3 的 `global_shader_parameter_get()` 是 editor-only API；游戏和
> 工具运行时调用会打印 ERROR 并影响性能。因此运行时**不调用它**。全局写入路径
> 用镜像值 + 工程注册 + shader 声明 + “没有本地覆盖”来验证；真实 GPU 的渲染结果
> 由探针抓 08:00/12:00/16:36/阴影开/关的帧做像素差异检查。

### 4.2 共享材质 / 三个 shader

- `shaders/foliage_light.gdshader`：树冠/树干/草/花/石头/花瓣**共用一个**
  ShaderMaterial 实例。伪法线由 UV 生成：
  `facing = 0.5 + 0.5 * dot(normalize(UV*2-1), normalize(u_sun_dir))`；
  受光面混入 `u_sun_color`，背光面压向冷色，亮部（白色樱花/花瓣）加一点
  自发光式提亮，让阴影侧仍保留白花。
- `shaders/ground_light.gdshader`：地面/远景树篱。大范围方向感 + 色温 +
  高度角亮度；不做 UV 伪法线，避免草地出现塑料球面感。
- `shaders/cast_shadow.gdshader`：只读取剪影 alpha，乘 `u_shadow_color` 和
  `u_shadow_strength`；方向/长度/分段都在 GDScript 节点变换里解决。
- `shaders/vignette.gdshader`：轻微暗角，只做构图，不影响太阳模型。

“不逐物传参”的检查：
`world.foliage_material.get_shader_parameter("u_sun_dir") == null`，且所有精灵/草/花/
石头/花瓣引用同一个 `foliage_material`；太阳方向只存在于 global uniform。

### 4.3 色温 / 阴影冷色关键帧

| 时刻 | sun color | ambient | shadow color | intensity |
| --- | --- | --- | --- | --- |
| 08:00 | (1.00, 0.81, 0.58) | (0.80, 0.83, 0.94) | (0.13, 0.19, 0.23) α0.60 | 0.90 |
| 10:30 | (1.00, 0.92, 0.78) | (0.87, 0.90, 0.95) | (0.10, 0.19, 0.17) α0.58 | 0.97 |
| 12:00 | (1.00, 0.98, 0.90) | (0.92, 0.94, 0.97) | (0.08, 0.18, 0.15) α0.58 | 1.00 |
| 14:30 | (1.00, 0.91, 0.75) | (0.88, 0.87, 0.94) | (0.11, 0.18, 0.22) α0.59 | 0.96 |
| 16:00 | (1.00, 0.80, 0.58) | (0.80, 0.78, 0.92) | (0.14, 0.17, 0.26) α0.61 | 0.90 |
| 17:00 | (1.00, 0.63, 0.44) | (0.74, 0.72, 0.90) | (0.17, 0.16, 0.29) α0.64 | 0.78 |

时间维度用 `Color.lerp` + smoothstep 混合；`u_sun_intensity` 与 `u_sun_color`
共同决定直射光。阴影色始终偏冷（青绿/蓝紫），直射光在低太阳角偏暖。

---

## 5. 像素渲染 / 画布

```text
世界：SubViewport 640×360，snap_2d_transforms_to_pixel=true
显示：TextureRect 拉伸到窗口，TEXTURE_FILTER_NEAREST
1280×720 = 2×，1920×1080 = 3× 整数放大
UI：设计坐标 1280×720；窗口 1280 时 1×，1920 时 CanvasLayer 1.5×
```

- 世界内所有节点位置/纹理都是整数像素或由整数像素纹理变换得到。
- 阴影的旋转/缩放是亚像素变换；它们的剪影纹理和最近邻采样保持像素边缘。
- UI 使用 SystemFont 回退 PingFang SC / Hiragino Sans GB / STHeiti /
  Noto Sans CJK SC；没有随项目分发字体文件。
- `1920×1080` 的截图由离屏 SubViewport 生成，避免 macOS 对 1920 窗口的裁切。
- UI 的 1.5× 缩放是为了可读性；像素世界的 3× 仍是严格的最近邻整数倍。

---

## 6. 场景与程序化素材

`scripts/sakura_art.gd` 固定种子生成：

- 草地：FastNoiseLite 双层 + 6200 根短草叶 + 落瓣 + 野花；低对比，不让色块伪装成影子。
- 三棵樱花树：每棵用 **29 / 27 / 13 个小叶簇**（rx 9–20）叠出蓬松树冠；
  每簇局部上亮下暗 + 白花团（20 个大白花团 + 84 个单像素白花 + 边缘 dither）。
  树冠和树干是分开的图，剪影另存给影子系统。
- 树篱：三层灌木团 + 远景粉花树，使用 ground 材质，退到背景。
- 石头：不规则椭圆 + 高光/裂纹/苔藓，剪影给单段影子。
- 草/花/花瓣：程序化小图；草与花使用 MultiMesh 实例色；花瓣使用一个 MultiMesh。
- 前景草：沿画面下缘/左右边缘的 38 个实例，z=28，增加景深；暗角 z=45。
- 无外部 PNG/模型/音频/字体文件；所有素材在启动时约 1–2s 生成（Intel HD 实测）。

## 7. 花瓣

- 66 片，`MultiMesh` + 一个 6×5 像素花瓣贴图 → 1 draw call。
- 每片有独立位置、速度、摆动相位/幅度、旋转、缩放和粉色实例色。
- 从三棵树冠的包围盒里生成；飘出画面后回到树冠附近再落下。
- 花瓣使用同一个 `foliage_light` 材质，因此全局太阳色/方向也会改变它们。

## 8. 交互 / UI / 调试

- 左侧中文面板：时间、刻数、时段、滑杆、播放/暂停、重置、0.5/1/2/4×、
  高度角、方位角、影长（H 与 px、封顶提示）、光照向量、影向、FPS/DRAW、
  阴影/调试/花瓣开关、快捷键提示。
- 右侧下角太阳罗盘：屏幕平面 08:00–17:00 弧，太阳点按方位角移动、
  离地平线的高度按高度角变化；显示方位角和高度角。
- F3 调试叠加：40px 网格、太阳/影向箭头、每棵树/石头影子的分段线、
  树干/树冠接点、H 标尺、L 长度标签、az/elev 读数。
- 截图/媒体工具隐藏 FPS 行，避免把截图过程的低帧率写进画面。

## 9. 性能与验收

环境：Godot 4.6 stable，GL Compatibility，Intel HD Graphics 6000，
macOS，关闭 VSync，1280×720 / 1920×1080 离屏。

| 场景 | 平均 FPS | 最低 FPS | Draw calls |
| --- | --- | --- | --- |
| 1280×720，隔离运行，含 HUD/66 花瓣/全部阴影 | 159.2 | 154.0 | 79 |
| 1920×1080 离屏，隔离运行，含 HUD | 129.8 | 128.6 | 79 |
| 1280×720，完整 verify 并发负载 | 91.7 | 71.0 | 79 |
| 1920×1080 离屏，完整 verify 并发负载 | 51.3 | 36.2 | 79 |

- `tools/verify.sh` 全流程通过，最后一行 `SAKURA_SUNLIGHT_VERIFY_OK`。
- `smoke_sakura_sunlight.gd`：136 项检查通过，最后一行
  `SAKURA_SUNLIGHT_SMOKE_OK checks=136`。
- 真实 GPU 600 帧启动：日志无 `SCRIPT ERROR` / `ERROR`。
- headless 600 帧启动：同样无错误。
- 1920 截图 10 张，均 1920×1080。
- 探针像素差异：08→12 0.333，12→16.6 0.458，阴影开/关 0.035；
  说明 global shader 参数和阴影开关确实改变了世界渲染。

## 10. 文件地图

```text
project.godot                  全局 shader_globals、GL Compatibility、1280×720
scenes/main.tscn               640×360 WorldViewport + TextureRect + HUD
scripts/main.gd                时间/太阳/全局 uniform/键盘/UI 接线
scripts/sun_model.gd           纯数学：刻数/高度角/方位角/影长/色温
scripts/sakura_art.gd          程序化像素素材 + 树冠/石头剪影
scripts/sakura_world.gd        地面/树/石头/草/花/花瓣/暗角/调试
scripts/shadow_caster.gd       树干+树冠两段影，石头单段影
scripts/petal_field.gd         66 片 MultiMesh 花瓣
scripts/hud.gd                 中文面板/滑杆/速度/开关
scripts/sun_dial.gd            太阳罗盘
scripts/debug_overlay.gd       F3 网格/向量/分段/H/L
shaders/foliage_light.gdshader 树木/草/花/石头/花瓣共享
shaders/ground_light.gdshader  地面/树篱
shaders/cast_shadow.gdshader   剪影 α + 全局阴影色
shaders/vignette.gdshader      暗角
tools/smoke_sakura_sunlight.gd    headless 验收
tools/probe_sakura_sunlight.gd    1280 GPU FPS + 像素差异
tools/probe_sakura_sunlight_1080.gd  1920 离屏 FPS
tools/screenshot_sakura_sunlight.gd  1920 截图矩阵
tools/capture_sakura_sunlight.gd     300 帧媒体抓取
tools/build_media.sh                 MP4/GIF
tools/verify.sh                      一条龙验收
```

## 11. 限制与边界

1. **屏幕方位角**不是地理方位；见 §2.2。核心取反/长度闭环是参考一致的。
2. 阴影是剪影近似，不做逐像素几何遮挡；树冠影子的宽度随树冠轮廓保留，
   不做真实的光线投影体积。
3. 参考视频里 14:30 的屏幕影向显示为“右上”；本项目的固定机位映射是
   “下午右下”。这是相机/投影约定差异，不是公式差异；README 已注明。
4. 1.8H 的上限是美术选择；可在 `SunModel.DEFAULT_MAX_SHADOW_MULTIPLE` 和
   `TREE_SPECS["cap"]` 调整。17:00 会显示“封顶”。
5. UI 在 1920 下以 1.5× 缩放；像素世界仍为 3×。若要求 UI 也严格整数，
   需要另一套 640×360 UI 设计。
6. 暂停只暂停时间/日照，花瓣继续飘；若希望冻结花瓣，在 `main._process`
   的花瓣 step 前面加 `if _playing` 即可。
7. 无音频；无第三方运行时依赖；无外部字体/贴图。
