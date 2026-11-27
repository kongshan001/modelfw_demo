# 暮色回廊 · 技术说明

Godot 4.6 stable · GL Compatibility · 1280×720（内部 640×360）· 1920×1080 证据合成。

## 1. 目标与边界

- 只复刻参考视频的**视觉语言/技术方向**：3D 低模 + 低分辨率像素 RT、黄昏→深夜、路灯错峰、萤火、水/云影/光束、像素偏移补偿。
- 场景布局、角色、材质、UI、代码全部原创；没有外部模型/贴图/音频。
- 先可运行、再效果：T-20261127-007 残留工程整体可复用，未重建；修复 5 个阻断/配置问题后开始视觉迭代。

## 2. 渲染管线

```
Window (1280×720 / 1920×1080, stretch disabled)
├─ HUD CanvasLayer（全分辨率，独立于像素化；PingFang/Noto 系统字体）
└─ Display (Control, 全屏)
   ├─ Letterbox ColorRect
   └─ PixelScreen TextureRect ← PostViewport 纹理，最近邻，整数倍放大
        └─ PostViewport 640×360（2D，disable_3d）
             └─ PostRect TextureRect
                  ├─ texture = WorldViewport 纹理（最近邻）
                  └─ material = post_pixel.gdshader
        └─ WorldViewport 640×360（own_world_3d，3D）
             ├─ GardenWorld（程序化场景）
             └─ Camera3D
```

- 内部 RT：320×180 / 480×270 / 640×360 可切；默认 640×360。
- 1280×720 → 2×；1920×1080 → 3×；480×270 在 1280 下为 2×（960×540，居中 letterbox 160×90）。
- 关闭 MSAA 3D/2D、screen-space AA、TAA、debanding；材质纹理 `nearest`；显示 `nearest`。
- 1920×1080 截图：`tools/capture_shots.gd` 建一个 1920×1080 SubViewport，把后期纹理最近邻 ×3 放进去，再叠全分辨率 HUD 捕获；仍是真实 GPU 渲染。物理屏 1440×900，无法直接开 1920 窗口。

## 3. 像素偏移补偿（Pixel Offset Compensation）

文件：`scripts/main.gd` `_apply_pixel_snap()`。

低分辨率 + 最近邻 + 整数倍只解决“缩放抖动”，相机亚像素移动仍会让角色边缘 1px 级游走。实现：

1. 相机平滑跟随完成后，把跟随锚点 `_cam_target`（角色胸口高度）投影到内部 RT 像素坐标 `sp = camera.unproject_position(anchor)`。
2. 取最近像素中心，得到亚像素误差 `px = round(sp) - sp`（限制 ±0.5px）。
3. 内部 1px 在该深度对应的世界尺寸：
   `wpp = 2 * depth * tan(fov/2) / internal_height`
4. 沿相机局部 right/up 反向平移相机：
   `camera.position += right * (-px.x * wpp) + up * (px.y * wpp)`
   使锚点落在像素中心。世界随之做 1px 级整体吸附，角色不再抖。
5. `P` 键开关；HUD 统计行显示「像素吸附 开/关」。

限制：这是**跟随锚点**吸附，不是逐深度稳定；远景仍可能有 1px 游走。深度/运动向量稳定化留给 T-20261127-008 做技术复核。

## 4. 场景构建

`scripts/garden_world.gd`（约 1200 行），`build()` 顺序：

1. 环境/主光/天穹
2. 材质（toon/water）
3. 地面石板/碎石
4. 围墙/断柱/柱鼓/苔藓
5. 残拱（11 块楔石缺 2 块 + 塌落石）
6. 水池/池沿/残破喷泉/睡莲/芦苇
7. 主树 4 棵 + 墙外树林剪影（不投影）
8. 草/花/苔藓斑块/落叶
9. 长椅 ×2、石狐雕像
10. 6 盏路灯
11. 3 个光柱
12. 角色 + 萤火
13. 静态 MultiMesh flush + 静态碰撞体

静态几何按类别合并 MultiMesh，降低 draw call：

| MultiMesh | 内容 | 阴影 |
| --- | --- | --- |
| StoneBoxes | ~300 石板 + 墙体 + 拱石 + 台阶 + 池沿 | 开 |
| StoneCylinders | 断柱/柱鼓/喷泉 | 开 |
| Wood | 长椅木条 | 开 |
| TreeTrunks | 4 棵主树 | 开 |
| Foliage | 主树冠/灌木/苔藓/落叶 | 开 |
| OuterFoliage / OuterTrunks | 墙外树林/墙根灌木 | **关**（避免低角度夕阳被外圈树冠切碎） |
| Grass | 草叶 tuft（顶点色渐变 + 风摆） | 关 |
| Flowers | 花茎/花头 | 关 |
| LilyPads | 睡莲 | 关 |
| Fireflies | 160 只 billboard | 关 |

主树/柱/灯/长椅/雕像/水池等有静态碰撞；水池为 layer 4（角色挡住，相机射线不受影响）。相机遮挡射线 mask=1，可被墙/树/柱拉近。

## 5. 时间、天空与光照

`scripts/main.gd` 5 个关键帧（t = 0 → 1，时钟 18:30 → 22:30，`分钟 = 18:30 + t*240`）：

| t | 时钟 | 阶段 | 日/月 | 路灯光 | 萤火 | 曝光 |
| --- | --- | --- | --- | --- | --- | --- |
| 0.00 | 18:30 | 黄昏 | 太阳 elev 13°, energy 1.35 | 0 | 0 | 1.06 |
| 0.22 | 19:23 | 日落 | 太阳 elev 4°, energy 0.80 | 2 | 0.12 | 1.08 |
| 0.45 | 20:18 | 蓝调 | 太阳落下；月 0.13 | 4 | 0.52 | 1.10 |
| 0.70 | 21:18 | 蓝调深 | 月 0.30 | 5 | 0.82 | 1.14 |
| 1.00 | 22:30 | 深夜 | 月 0.40 | 6 | 1.00 | 1.16 |

- 关键帧之间 smoothstep 插值 Color/float；方向向量由 elev/azim 重算。
- `sun_light` 自动在太阳/月亮间切换方向、颜色与能量；阴影只在能量 >0.08 时开。
- 天空：`sky_dusk.gdshader` 半径 92m 翻转球，渐变 + 低空暖霾 + 太阳光晕/日盘 + 月盘/环形光 + 球面哈希星点 + 两层 fbm 流动云。
  - 地平线带修复：云 UV 分母 `0.16 → 0.30`，云带起始 `0.015 → 0.055`，地面渐变 `-0.14..0.045 → -0.22..0.06`，减少 640×360 下的横向条纹。
- 云影：`garden_toon.gdshader` 的 `light()` 用世界 XZ 的两层 fbm 计算 patch，`g_cloud_shadow` 从 0.30（黄昏）降到 0.10（深夜），云随时间流动（`g_cloud_x/z`）。
- 雾：手写距离雾 `1-exp(-dist*g_fog_density)`，不依赖 GL Compatibility 的体积雾；每帧把雾色/密度写 global uniform。

## 6. 路灯 / 萤火 / 水 / 光柱

### 路灯（6 盏）

| # | 位置 | 阈值 |
| --- | --- | --- |
| 0 | (-2.1, 0, 5.7) | 0.17 |
| 1 | (3.2, 0, 3.3) | 0.26 |
| 2 | (-6.7, 0, -0.2) | 0.35 |
| 3 | (3.5, 0, -2.7) | 0.45 |
| 4 | (-1.9, 0, -7.7) | 0.55 |
| 5 | (7.1, 0, 1.2) | 0.65 |

`t >= threshold` 后 0.045 的 smoothstep 渐亮；过渡区间叠加 19Hz/7.3Hz 双正弦闪烁，最低 18%。每盏包含：

- OmniLight（能量 1.55×level，范围 5.4，无阴影）
- 玻璃自发光（暗棕 → 暖白黄）
- billboard 加色辉光（0.95m，随 level 缩放/增亮）
- 地面加色光池（5.8m，径向衰减 power 1.9，alpha 0.34×level）
- 离池最近的 3 盏向水面喂**虚拟反射点**（池内 0.72R 靠灯一侧），避免“灯在池外所以水面没有倒影”。

### 萤火（160 只）

- 单个 MultiMesh（1 draw call），每只独立轨道/高度/摆动/闪烁相位/尺寸/色温；CPU 每帧更新变换和实例色。
- 9 个区域（池边、大树、西侧、拱门、起点、路径中心、入口、外圈 ×2），权重 0.05–0.26；`min_y 0.3–0.5`，避免入地。
- 活动度 `smoothstep(0.30, 0.72, t)`；尺寸 0.09–0.16m；紧致 spark 纹理（power 3.0），加色 billboard。
- 开关 `G`；暂停时空冻结。

### 水池

`water_pool.gdshader`（unshaded，半透明 0.93）：

- 深度：中心 `deep_color` → 边缘 `shallow_color`；`shallow_t = smoothstep(0.34, 0.95, r)`。
- 天空：`sky_ref` 混合菲涅尔 `0.12 + fres*0.58`，并随 ripple 在 horizon/mid 之间偏移。
- 日/月倒影：`reflect(-view_dir, n)` 与 `sun_dir`/`moon_dir` 的窄高光（pow 110/150），由 `sun_sky`/`moon_sky` 驱动。
- 水面灯倒影：3 个虚拟点（见上），双频 `sin` 断裂 + 指数衰减。
- 量化双频涟漪 + 稀疏像素 glint；池沿内圈压深、外圈湿石高光。

### 光柱 + 丁达尔

- 3 个锥体（`light_shaft.gdshader`）：底半径 1.7/1.1/0.9，高 16m，加法混合、无深度写入；视向柔边 × 纵向衰减 × 缓慢条带。
- 强度随时间：0.30 / 0.22 / 0.08 / 0.02 / 0.0 × 每柱 1.0/0.5/0.35；深夜关闭。
- `post_pixel.gdshader` 屏幕空间丁达尔：朝日/月屏幕位置 14 次径向采样，只取 luma>0.60，decay 0.93，强度 0.7×日/月强度；在 640×360 下自然颗粒化。
  - 当年太阳/月亮在屏幕外/背后时自动关闭。
  - 相机每帧投影 `camera.position + dir*120` 得到 `godray_pos`。

### 草叶

`_build_tuft_mesh()`：5 片三角叶，顶点色根部暗/尖端亮，双面；风吹顶点偏移（`sway_amount 0.060`，`sway_ref 0.38`，世界位置相位）；MultiMesh 一次绘制。苔藓斑块与落叶使用同一 Foliage MultiMesh（压扁球体）。

## 7. 角色「苔灯」

`scripts/keeper.gd`（CharacterBody3D，程序化图元）：

- 宽檐草帽（前檐上翘 6°）、墨绿披风、锈橙围巾、斜挎包、背卷、铜灯笼手杖。
- 行走 2.15 m/s / 跑 3.85 m/s，加速度 13；`move_and_slide` + 地面碰撞。
- 步行相位驱动腿/臂摆动、身体侧倾、头部微转；idle 呼吸/转头；灯笼钟摆（行走更明显）。
- 提灯：玻璃自发光（`GLASS_WARM × clamp(0.60+e*0.35, 0.60, 0.98)`，暖色；点光压低避免杖身爆白）、billboard 辉光 0.42m、OmniLight（0.30 基础，目标 0.18+night*0.25，范围 2.8）、贴地加色光池 2.6m。
  - 迭代中曾出现点光近场把手杖/手照爆成白色十字；通过降低 OmniLight、收紧玻璃/辉光、加地面光池解决。
- 接触阴影：1.05m 暗色径向 quad。
- 脸：肤色球 + 头发/鬓角 + 黑眼 + 小嘴；帽子整体前檐上翘避免压住眼睛。

## 8. HUD

`scripts/hud.gd`（CanvasLayer，全分辨率）：

- 标题/副标题；时钟 + 时段 + 夜色百分比；时间滑杆（步进 0.001）。
- 自动时间开关 + 速度 0.2–4.0；预设 1/2/3；路灯/萤火/暂停开关；内部 RT 320/480/640；相机复位。
- 统计：FPS、draw calls、内部 RT × 放大倍数、像素吸附、路灯 n/6、萤火 n/160、实时/暂停。
- 操作提示；所有中文走系统字体回退链。
- 截图工具用 `hud_scale_override = 3`，保证 1920 合成里的「×N」显示 3×。

## 9. 性能

真实 GPU：Intel HD Graphics 6000，OpenGL 4.1 Compatibility，1440×900 面板。

```
PERF_1280 avg=98.9 min=27.9 max=238.5 frames=495 draw=187 rt=640x360 fps_engine=92
PERF_1920_SUBPORT avg=63.6 min=26.0 max=161.4 frames=319 draw=239
```

- 关键手段：MultiMesh 合批；外圈植被不投影；萤火单 draw call；无平面反射/体积雾；丁达尔只在 640×360 后期做 14 tap；无 MSAA/TAA；方向光阴影 2048、正交 48m；阴影只在日月能量 >0.08 时开。
- `min` 是 5s 窗口内瞬时时延（启动/OS 调度尖峰）；平均满足 30fps+。HUD 截图里的 FPS 包含 1920 合成 + PNG 回读，不代表 1280 目标。
- Draw calls 187（1280）/239（1920 合成）。

## 10. 自测与复现

```bash
# smoke（headless，70 checks，末行 DUSK_GARDEN_SMOKE_OK）
godot --headless --path . --script tools/smoke_dusk_garden.gd

# 真实 GPU 控制台
godot --path . --resolution 1280x720 --quit-after 300

# 1920×1080 真实 GPU 截图（12 张，docs/shots）
godot --path . --script tools/capture_shots.gd

# 纯黑剪影
godot --path . --script tools/capture_silhouette.gd

# FPS
godot --path . --script tools/probe_fps.gd

# 10.4s Movie Maker
godot --path . --resolution 1280x720 --write-movie docs/media/dusk_cloister.avi \
  --fixed-fps 30 --disable-vsync -- --movie
```

最近一次：

- `CHECKS 70` / `DUSK_GARDEN_SMOKE_OK`
- 真实 GPU 启动/运行：0 ERROR / 0 WARNING
- 12 张 1920×1080 截图 + 25%/4×/剪影自检
- 10.43s MP4（H.264）+ GIF（480×270，12fps）

## 11. 已知问题 / 交接

- 1920×1080 截图是 SubViewport 合成，不是 1920 原生窗口；物理屏为 1440×900。
- 像素吸附只对齐跟随锚点，不是逐深度稳定；快速环绕或远景物仍可能有 1px 游走（T-008 技术复核）。
- 天空/云在极低视角仍有轻微横向采样纹理；已通过 UV 分母/云带/地平线渐变缓解。
- 截图/剪影工具退出会打印 `ObjectDB instances leaked at exit`（工具清理不彻底）；游戏本体无此警告。
- 无音频；HUD 字体依赖系统；无 32:9/超宽自适应（整数缩放会 letterbox）。
- 外圈树林是视觉剪影、无碰撞；相机不会碰到它们。
