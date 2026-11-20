# Pixel Ocean 技术说明

> 目标：在 Godot 4.6 / GL Compatibility / Intel HD 6000 上，用可维护的程序化方案复刻
> “像素海面 + 五点浮沉木筏 + 晚霞倒影 + 碎金 + 白沫 + 透明”的完整效果。

## 1. 渲染管线

```
窗口 1280×720（canvas_items）
├─ WorldViewport  SubViewport 640×360, UPDATE_ALWAYS, MSAA off
│   └─ World (Node3D)：天穹 / 太阳 / 补光 / 海床 / 海面 / 木筏 / 相机
├─ WorldDisplay  TextureRect 全屏, stretch_mode=scale, texture_filter=nearest
└─ HUD           CanvasLayer 1280×720（SystemFont 中文）
```

- 3D 画面固定 640×360，2× 最近邻放大，得到干净的大像素；UI 不跟着像素化。
- 倒影视口 `ReflectionViewport` 320×180，共享 `WorldViewport.world_3d`，
  自带镜像 `Camera3D`，`cull_mask = 1`（只拍天空/木筏/角色）。
- 海面 `layers = 1 << 1`、海床与水下石头 `layers = 1 << 2`，因此不会进入倒影。
- 主相机 FOV 46°，near 0.05，far 700；天穹是半径 320 的大球（从内部看）。

## 2. 海面网格

`scripts/ocean.gd`：`PlaneMesh`，尺寸 140×140，细分 219（220×220 四边形，
48,841 顶点，约 9.7 万三角形）。节点位于原点、无旋转，顶点 shader 直接输出世界坐标，
所以 `VERTEX`、`v_world` 与 CPU 采样使用同一坐标系。

海面边缘：`max(|x|,|z|)` 从 52→66 把波幅平滑收回 0，颜色在 32→58 融入天际色。
这样远处海面边缘是平的、与天空同色，不会露出锯齿状“小岛”。

## 3. 波形（vertex shader + CPU 同构）

`shaders/water.gdshader` 的 `vertex()` 与 `ocean.gd:height_at()` 必须保持一致。

### 3.1 三道 Gerstner 式波

每道波：

```
k = 2π / λ
ω = sqrt(9.81 * k) * wave_speed_i * u_wave_speed
f = k * dot(D, p) - ω * t
height += A * sin(f)
horiz  += D * (chop * A * cos(f))          // 水平位移，挤压浪尖
dP/dx, dP/dz 按 sin/cos 解析累加
```

| 波 | 相对方向 | 波长 λ | 振幅 A | 速度倍率 | chop 倍率 |
| --- | --- | --- | --- | --- | --- |
| 0 | -0.38 rad | 15.0 | 0.62 | 1.00 | 0.90 |
| 1 | +0.72 rad | 7.0 | 0.30 | 1.25 | 0.80 |
| 2 | +1.90 rad | 4.6 | 0.16 | 1.50 | 0.70 |

全局 `wave_angle` 加到三道波的方向上（HUD “浪向”）。

法线：`N = normalize(cross(dP/dz, dP/dx))`，在顶点里解析求出，逐像素插值。

### 3.2 拉长 / 拧弯 / 浪群

- 拉长：采样坐标 `p.x *= lerp(1.0, 0.55, stretch)`，使 x 方向波长变长。
- 拧弯：`p.y += sin(p.x * 0.055 + t * 0.18) * 2.0 * stretch`，让浪脊线弯曲。
- 浪群：`env = 0.5 + 0.5*sin(dot(p, vec2(0.055, 0.031)) - t*0.24)`，
  `gmul = lerp(1.0, 0.62 + 0.72*env, grouping)`，大浪一拨一拨地来。

### 3.3 浪尖挤尖与泡沫判据

水平位移的 Jacobian：

```
J = (1 + ∂Px/∂x)(1 + ∂Pz/∂z) - (∂Px/∂z)²
v_crest = clamp((1 - J) * 3.0, 0, 1)
```

`J` 越小表示水平方向挤得越紧，浪尖越尖，同时泡沫的“孕育”值越高。

## 4. 五点浮力

`scripts/raft.gd`：

```
采样点：中心 (0,0)，前 (0,-1.55)，后 (0,+1.55)，左 (-1.15,0)，右 (+1.15,0)
y_target   = average(五个高度) + 0.10
pitch      = atan2(front - back, 3.10)
roll       = atan2(right - left, 2.30)
k          = 1 - exp(-7 * dt)
position.y = lerp(position.y, y_target, k)
rotation.x = lerp(rotation.x, pitch, k)
rotation.z = lerp(rotation.z, roll, k)
```

- 木筏节点原点在水线附近，甲板、道具、水手都在节点内，随俯仰/横滚整体倾侧。
- CPU 采样与 shader 使用同一套时间、波高、波向、stretch/grouping 参数，避免“漂在水上”。
- `O` 键显示 5 个无深度测试的球体标记（中心青色、四角黄色），方便验收。

## 5. 像素水纹与色阶

片元阶段（**不依赖 UV 贴图**）：

1. 两层世界空间“短横线”网格：
   - 第一层：`world.xz * 5.0`，随时间漂移，横向短划线；
   - 第二层：`world.xz * 2.3`，另一方向，更稀疏；
   - 由于使用顶点的 `v_world`，纹理会跟着浪的位移/挤压一起动。
2. 4 档受光色：`deep → mid → light → crest`，由法线受光 + 高度 + 抖动决定；
3. 小幅度 band dither（`hash(world*7.4)` ±0.035）打破平滑大片；
4. 短划线在亮部混入 `deep`、暗部混入 `light`，形成水纹；
5. 最终颜色 `floor(col * 20 + 0.5) / 20` 收成受限色阶。

## 6. 泡沫

- **浪尖泡沫**：`smoothstep(0.78, 1.0, v_crest)`，再乘坡度门限、低频 0.55/1.9 两格斑块、
  高频 6/13 格噪声。低频斑块把大片泡沫切成不规则碎块，避免“白冰盖”。
- **木筏边缘泡沫**：圆角矩形 SDF（半尺寸 1.22×1.62），`sd ∈ [0, ~0.2]` 的窄环，
  乘哈希噪声，强度 `u_foam * 0.45`；环随水面顶点位移一起扭动。
- **逆光**：泡沫颜色按 `pow(max(dot(-V, sun_dir),0),3)` 混入太阳色。
- 泡沫颜色再混一点 `light` 色和细颗粒 hash，避免纯白。

## 7. 平面倒影（镜像相机）

`scripts/main.gd:_build_reflection / _update_reflection_camera`：

- `ReflectionViewport` 320×180，`world_3d` 指向主 3D 视口的世界。
- 镜像相机位置：`(x, -y, z)`（水面 y=0）。
- 朝向：forward 和 up 都做 y 取反，用 `Transform3D(...).looking_at()` 构造；
  - 这相当于一个“从上往下看”的相机被翻到水下，朝向也翻过来；
  - 得到的图像相对真实反射在水平方向是镜像的，因此水面 shader 用
    `vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)` 采样。
- 采样时加入 `normal.xz * 0.012` 和少量正弦抖动；`filter_linear` 让 320×180 的
  倒影在 640×360 水面上自然过渡。
- 反射权重：`clamp(fres * 1.15 + 0.24, 0, 1) * reflection_strength`。
  - 基础 0.24 保证低机位也能看到木筏/帆的倒影；
  - Fresnel 项 `pow(1 - N·V, 3)` 在掠射角增强，海平线附近能看到整片晚霞。
- 颜色乘以 `mix(1, sun_color, 0.22) * 0.70`，让晚霞反射偏金、夜里偏冷。
- 关闭倒影时把视口设为 `UPDATE_DISABLED`，shader 的 `u_reflection_on = 0`。

## 8. 碎金 sparkle

```
R = reflect(-V, N)
sun_path = pow(max(dot(R, sun_dir), 0), 64)
col += sun_color * sun_path * 0.16
cell = floor(world.xz * 20 + time * (2.3, -1.7))
sparkle = step(0.975, hash(cell)) * smoothstep(0.28, 0.75, sun_path + fres*0.2) * amount
```

- 低强度的窄太阳高光带提供“水面碎金”的底色；
- 稀疏的世界网格闪光只出现在太阳反射路径附近；
- 夜间同一套逻辑会变成月光的冷色碎光。

## 9. 透明

- 水材质：`render_mode unshaded, blend_mix, depth_draw_never`。
- `ALPHA = clamp(mix(0.68, 1.0, fres) * u_opacity, 0.25, 1.0)`。
- HUD “透明” 0–1 → `u_opacity = lerp(1.0, 0.48, transparency)`。
- 海床（70×70，y=-3.4）与 5 块小石头提供透水参照；海床 shader 用低对比像素焦散，
  透明度高时可以看到水下的暗色/焦散纹理。

## 10. 昼夜调色

`scripts/main.gd:SKY_KEYS`：0h / 6.5h / 9h / 16h / 18.4h / 21.5h / 24h 关键帧，
插值这些字段：

- 天穹：`zenith / horizon / sun_color / sun_energy / sun_elev / stars / clouds / cloud_color`
- 环境光：`ambient / ambient_energy`
- 水色：`deep / mid / light / crest / foam / gold`
- 太阳方位固定 222°，高度随时间变化；晚霞时太阳在镜头正前方偏左，形成逆光。

天穹是一个从内部观看的大球（`shaders/sky.gdshader`）：渐变 + 太阳盘/光晕 +
条纹云带 + 星点，最后做 28 级色阶量化。阳光使用无阴影 `DirectionalLight3D`；
另有一盏从镜头方向照向木筏的无阴影弱补光，避免逆光时木筏全黑。
木筏灯笼在夜间点亮（`OmniLight3D` + 自发光球 + 轻微闪烁）。

## 11. 性能

目标机器：Intel HD Graphics 6000（2015 MacBook Air），1280×720，vsync off。

实测（2026-11-20，`tools/probe_pixel_ocean.gd`）：

| 配置 | 平均 FPS | 最低采样 |
| --- | --- | --- |
| 默认 640×360 + 倒影 320×180 | **92.2** | 58 |
| 关闭倒影 | 128.8 | 107 |
| 倒影 + 512×288 内部 | 89.9 | 77 |

约 104,604 图元 / 88 draw calls。达到 Intel 集显 30 FPS+ 的要求，余量充足。

主要成本：水面的 48,841 顶点 × 3 波三角函数、640×360 水片元、以及额外一次 320×180
倒影渲染。没有使用阴影、SSR、泛光或后处理。

## 12. 验收点

- `smoke_pixel_ocean.gd`：网格顶点数、三道波配置、shader uniform 链路、五点高度差、
  木筏反应、昼夜调色、倒影视口/相机、图层、HUD 开关、暂停。
- `screenshot_pixel_ocean.gd`：9 张定格（晚霞、低机位倒影、正午、夜、浪尖泡沫、
  五点标记、面板、镜面、透明）。
- `probe_pixel_ocean.gd`：三组 FPS 配置 + 图元/draw call。
- `verify.sh`：导入 → smoke → 600 帧启动扫描 ERROR → 截图 →（可选）FPS 探针。
