# 技术说明 · 池底光网

本文说明 `godot-pool-caustics/` 的 Voronoi 焦散核心、3D 石盆、熔岩复用与性能取舍。实现为 clean-room：参考公开教程的算法思路与画面语言，代码、shader、网格、贴图、UI 全部原创。

## 1. 总览

```text
应用层  main.gd
         ├─ 参数 / 变体 / 调试状态
         ├─ 时间、鼠标聚焦、UI 接线
         └─ 中文 HUD
场景层  pool_world.gd
         ├─ PlaneMesh 河床（程序化贴图）
         ├─ 22 块程序化圆石 + 3 个 mesh 变体
         ├─ 8 槽圆形软阴影
         └─ 可加性水面微光
Shader  caustics.gdshaderinc   ← 所有表面共用
         ├─ pool_floor.gdshader  （河床 + 焦散 + 投影）
         └─ pool_rock.gdshader   （圆石受光 + 焦散 + 湿高光）
后处理  vignette.gdshader       （暗角 + 颗粒，不读 screen texture）
```

关键选择：**直接用世界 XZ 坐标采样**。池底与圆石不需要各自生成一张焦散图，光网在世界空间中连续；圆石只额外沿法线方向做了一个小偏移，让光网从顶部自然包到侧面。

## 2. Voronoi / F1 / F2 核心

文件：`shaders/caustics.gdshaderinc`。

### 2.1 特征点格网

每个整数格一个有轻微不规则的随机特征点：

```glsl
vec2 h = caustic_hash22(cell + g + seedOffset);
vec2 site = cell + g + 0.10 + 0.80 * h;   // 留在格内 10%–90%
```

Hash 使用无三角函数的三次乘加：

```glsl
vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
p3 += dot(p3, p3.yzx + 33.33);
return fract((p3.xx + p3.yz) * p3.zy);
```

### 2.2 3×3 邻域搜索

对当前像素所在格与周围 8 格共 9 个特征点，记录：

- `F1`：最近距离
- `F2`：次近距离
- `F3`：第三近距离（仅用于交点鼓结）

比较时使用距离平方，循环结束后统一开方，减少 9 次平方根。插入逻辑是标准的三路交换：

```glsl
if (d < f1)      { f3 = f2; f2 = f1; f1 = d; nearest = site; }
else if (d < f2) { f3 = f2; f2 = d; }
else if (d < f3) { f3 = d; }
```

3×3 是必要且足够的：在不考虑极端硬直边界的情况下，最近的两个特征点必在相邻 9 格内。Shader 使用固定边界循环，移动端/集显可以常量化展开。

### 2.3 距离差与指数亮纹

```glsl
float gap = max(F2 - F1 - u_gap_threshold, 0.0);
float localWidth = u_width * mix(0.78, 1.46, smoothstep(0.0, 0.9, F1));
float core = exp(-pow(gap / localWidth, 2.0));
```

- 在 Voronoi 边界上，两个最近点等距，`gap = 0`，指数项达到峰值。
- 离边界越远，`gap` 增大，光纹平滑衰减。
- 线宽随 F1 缓变：靠近格心时略宽，避免整张网像等宽线框；这也是参考教程后半段的动态线宽思路。

宽柔光使用更长的指数尾：

```glsl
float halo = exp(-gap / (u_width * u_softness * 7.0));
halo = pow(halo, 1.35) * u_soft_light;
```

### 2.4 交点鼓结（F3）

在三条边界汇聚的 Voronoi 顶点，`F3` 也会接近 `F1`：

```glsl
float junction = exp(-pow((F3 - F1) / (u_width * 2.35), 2.0));
```

这个项只在顶点附近非零，增加节点亮度；显示为光网的“鼓结”而不改变两侧的细线宽度。F3 复用同一轮 9 格循环，没有额外采样。

### 2.5 坐标扭曲 / 漂移 / 流速

```glsl
float anim = time * u_speed;
vec2 flow = vec2(cos(radians(u_flow_angle)), sin(radians(u_flow_angle))) * 0.080 * anim;
vec2 q = world_xz * u_scale + flow;

vec2 w = vec2(
  sin(q.y*0.24 + t*0.13) + 0.46*sin(q.x*0.12 - t*0.08 + 1.7),
  cos(q.x*0.27 - t*0.11) + 0.46*cos(q.y*0.14 + t*0.07 + 4.2)
);
w += 0.24 * vec2(sin(q.y*0.87 - t*0.05), cos(q.x*0.79 + t*0.04));
q += w * u_warp_amount * 0.40;
```

使用解析式双频正弦而非 fBm：每像素只需少量 sin/cos，足以把直边 Voronoi 弯成水中的有机边界。`u_flow_angle` 控制整体漂移方向，`u_speed` 统一控制时间。

### 2.6 明暗聚散

```glsl
float n  = noise(q*0.16 + animDirA);
float n2 = noise(q*0.39 + animDirB);
float m  = clamp(0.66*n + 0.34*n2, 0.0, 1.0);
float gather = mix(1.0, 0.10 + 1.92*pow(m, 1.70), u_gather);
```

两个低频 value noise 相乘/混合后作为整张光网的照明包络；它同时乘核心与柔光，让部分区域“聚光”、部分区域“散开”。这也给静态截图带来非均匀的空间节奏。

### 2.7 鼠标聚焦

```glsl
float focus = 1.0 + u_focus.w * exp(-dot(world_xz - u_focus.xy, world_xz - u_focus.xy) * 0.22);
```

左键射到池底后，将命中点写入 `u_focus`；聚焦值随时间衰减。它只调节局部亮度，不改变 Voronoi 图案。

### 2.8 单格对照

`u_search_3x3 = 0` 时只查询本格的一个特征点：

- `F1` 是本格距离，`F2` 无效（HUD 显示“无有效 F2”）。
- 最终对照图用本格 F1 的等距环（半径 0.43 格）叠加深色格缝；这正是“单格测距”会出现的不连续。
- 3×3 模式则用邻近 8 格找到真正的次近点，光网跨格连续。

这不是实际玩法，而是教学对照；UI 与截图都明确标注。

### 2.9 最终颜色

池底：

```glsl
vec3 col = glowColor * halo * 1.00;
col += lineColor * core;
col += mix(lineColor, vec3(1.0), 0.42) * clamp(junction, 0.0, 1.0) * 0.66;
```

光网与表面底色相加。底色和圆石自身受光由各自的 surface shader 计算；焦散只负责发光部分。

## 3. 池底 / 圆石表面

### 3.1 河床

- `PlaneMesh` 40×31，36×28 细分，顶点按椭圆半径轻微下凹（`smoothstep(0.42, 1.0, r) * 0.72`）。
- 640×640 程序化贴图在 `riverbed_texture.gd` 生成：`FastNoiseLite` 淤泥、34 个软苔斑、118 颗带烘焙明暗/湿边的卵石、2200 粒砂。生成 mipmap。
- Shader 侧再加一次世界噪声与 8 个圆形软阴影，遮住大石底部；没有真实阴影贴图。
- 池边 `u_deep_tint` 混合，藏住平面边界并控制视觉焦点。

### 3.2 圆石

- 3 个自建 UV 球变体（20 环 × 30 段），径向四频正弦扰动 + 底部压平 + 少量横向漂移；`SurfaceTool.generate_normals()` 平滑法线。
- 22 个实例：6 个主景石、14 个岸边石、2 个前景剪影；总 26,400 三角形。
- 自定义受光：上表面天空环境光 + 左上主光 + 底部接触暗 + 湿面 Blinn 高光 + 边缘光；苔藓只长在朝上的法线区域。
- 焦散投影：

```glsl
vec2 p = v_world.xz + N.xz * 0.56 + vec2(v_world.y * 0.09, 0.0);
```

法线偏移让光纹在石侧面有连续感，同时不完全等同于池底图案，避免“贴纸”感。

### 3.3 水面微光

一个位于水面上方、可加性的透明大平面，使用很慢的 3 组正弦波产生稀疏高光与宽纹理，最高 alpha 0.30。它只暗示水面，不参与焦散距离场，也没有屏幕空间折射（避免额外的全屏拷贝与性能损耗）。模式切换为调试图或熔岩时自动隐藏。

### 3.4 暗角

CanvasItem shader 只画暗角、冷色边缘与颗粒，不采样屏幕纹理。这样在 GL Compatibility 的 Intel 集显上没有额外全屏 backbuffer 读取。

## 4. 相机与交互

- 透视相机 FOV 44°，默认 target `(0.55, -0.25, 0)`、yaw 4°、pitch 48°、距离 17.2。
- 自动环视只是在 yaw 上叠加 `sin(t * 0.075) * ±3.2°`，不影响采样。
- 右键拖拽改变 yaw ±12°、pitch 48–60°；滚轮距离 12.8–17.2。限制范围是为了始终留在程序化石盆内，不露出平面边界。
- 左键通过 `project_ray_origin/normal` 与 `y=0` 平面求交，更新 `u_focus`。

## 5. 熔岩变体

同一份 `caustics.gdshaderinc` 在 `u_style = 1` 时：

| 参数 | 池底 | 熔岩 |
| --- | --- | --- |
| `u_gap_threshold` | 0 | 0.0035 |
| `u_width` | 0.050 | 0.060 |
| `u_brightness` | 1.00 | 1.55 |
| `u_speed` | 0.46 | 0.33 |
| 线色 | 青白 `#94FAF7` | 暖黄 `#FFC261` |
| 柔光色 | 深青 | 橙红 |
| 水面微光 | 开 | 关 |
| 底面 / 岩石 | 苔绿河床 | 暗色玄武岩 |
| 环境 | 深青 | 暗红棕 |

`caustic_light` 在熔岩分支使用不同的色阶组合和更强节点光，但输入仍是同一组 `F1/F2/F3` 与 `gap`。切换仅更新 material uniforms 与场景颜色，无需重新加载 shader 或生成纹理。

## 6. HUD

- 1280×720 设计尺寸；截图工具设置 HUD `scale=1.5` 得到 1920×1080 的清晰文字。
- 右侧参数面板包含：
  - 池底 / 熔岩变体
  - 7 个分析视图
  - 单格 / 3×3 搜索
  - 坐标扭曲 / 交点鼓结 / 明暗聚散 / 宽柔光 / 水面微光 / 自动环视
  - 6 个连续参数 + 光纹色
- 顶部显示实时 `FPS` 与 draw calls；调试视图下右上角统计可被截图工具隐藏，避免截图写入拖慢引擎造成假低值。
- 调试/单格模式下有黄色说明条；顶部与底部使用程序化渐变，改善亮背景上的文字可读性。
- 字体使用 `SystemFont`（PingFang SC / Songti SC / Menlo），无打包字体资产。

## 7. 性能

实测环境：macOS，Godot 4.6.stable，GL Compatibility，Intel HD Graphics 6000，关闭 VSync，UI 全开。多次运行在 1280×720 为 94.6–105.9 fps、1920×1080 离屏为 53.5–58.2 fps；下表取最后一轮。

| 场景 | 平均 FPS | 平均帧时间 | Draw calls |
| --- | ---: | ---: | ---: |
| 1280×720 真实窗口，240 帧采样 | **105.9** | 9.45 ms | 143 |
| 1920×1080 离屏 SubViewport，120 帧采样 | **58.2** | 17.19 ms | 143 |

优化点：

- 9 格搜索只做一次，F3 免费复用；无纹理采样循环、无屏幕纹理。
- 底面是单张程序化贴图 + 一个 shader material；22 块圆石共享 2 个 material，几何总量约 2.9 万三角形。
- 无真实阴影贴图，使用 8 个圆形软阴影。
- 不依赖 3D 灯光、雾、Glow 后处理；所有颜色在手写着色中完成。
- HUD 在 1280×720 设计，1920 截图根据缩放因子放大；不增加 3D 分辨率以外的 UI 复杂度。

Draw calls 包含 HUD 的 Control 绘制批次。场景本体没有第三方模型/贴图资源。

## 8. 验收

命令见 `tools/verify.sh`，最近一次结果：

```text
import: clean
POOL_CAUSTICS_SMOKE checks=93
POOL_CAUSTICS_SMOKE_OK
headless 600-frame boot: clean
real-GPU 600-frame boot: clean
POOL_CAUSTICS_PROBE resolution=1280x720 fps=105.9 ms=9.45 engine_fps=99 dc=143 samples=240
POOL_CAUSTICS_PROBE_1080 resolution=1920x1080 fps=58.2 ms=17.19 engine_fps=59 dc=143 samples=120
11 screenshots 1920×1080
POOL_CAUSTICS_VERIFY_OK
```

`smoke_pool_caustics.gd` 覆盖 93 项：节点/贴图/材质、6 个参数、7 个调试视图、单格/3×3、四个构成开关、水面微光、聚焦射线、熔岩切换、暂停、重置、HUD 状态。

## 9. 已知差异与限制

- 参考视频是 2D shader 投射到 3D 池底；本实现直接把世界空间场投影到 3D 池底和圆石，因此近景石面的光纹包裹感更强，但也更容易显得像“网”。
- 参考视频的最后一种变体是闪电/光带；本任务按规格做成熔岩裂缝，复用同一距离差核心。
- 水面只是低强度可加性微光，没有做真实折射；这是性能取舍。
- 单格模式显示的是教学用的 F1 等距环，不是完整的光网。
- 因匿名 B 站接口只返回 852×480，参考帧分辨率低于任务描述的 2560×1440；视觉判断基于 480p 帧，未逐像素比对。
- 当前 1920 媒体帧很大，仓库中的 10s GIF 为 16 MB；MP4 为 5.1 MB。
