# Knotline · 线屿 — 技术说明

> 版本：2026-11-26 · Godot 4.6 stable · GL Compatibility · 1280×720 逻辑分辨率
>
> 本文只描述实现。**本项目不声称实现完整 knot theory**；“结”是明确写出的玩法近似，边界见最后两节。

## 1. 范围

| 项 | 实现 |
| --- | --- |
| 3D 一笔画 | 鼠标射线 → 表面点 / 面向镜头平面上的空中点，锚定起点、不可断笔 |
| 轨道相机 | yaw/pitch/distance/focus，平滑插值；WASD 平移、滚轮缩放、右键拖动旋转 |
| 绳网格 | 控制点 → Catmull-Rom → 平行传输 TubeMesh + 条纹 shader + 阴影 |
| 绕柱 | 柱体避让（弧线插入）+ 柱周 winding 累计 |
| 结条件 | 绕柱圈数 + XZ 自交的高度差 over/under + 绳头到结台 |
| 关卡 | 2 个 JSON 手工关卡；目标“套住 X + 结条件 + 终点” |
| Undo | 撤销最后一个用户控制点，0.20 s 平滑收绳动画 |
| UI | 中文 HUD、目标进度、情境提示、F1 调试、过关卡片 |
| 媒体 | 7 张 1920×1080 截图 + 1280×720 10 s MP4/GIF（真实 GPU） |

所有几何、材质、UI、音效均为运行时程序化生成；无第三方模型/贴图/音频。唯一外部资产是项目用字子集字体（OFL，见 CREDITS）。

## 2. 3D 画线输入

### 2.1 相机

`src/knot_orbit_camera.gd`

- 相机 rig 的 focus = 焦点；yaw/pitch 决定机位；子 `Camera3D` 位于 `(0,0,distance)`，`fov=46°`。
- pitch 12°–74°、distance 4.2–14.0、focus 在半径 3.5 m 内（y 0.25–1.8）。
- 每帧以 `1 - exp(-10·dt)` 平滑 current → target，避免生硬跳变。
- WASD/方向键按 target yaw 的前/右方向平移焦点；鼠标滚轮按距离缩放；右键拖动 `-0.28°/px`，`-0.22°/px`。

### 2.2 指针 → 3D 点

`KnotGame._pointer_draw_point()`

1. `camera.project_ray_origin/normal(mouse)` 得到射线；
2. `PhysicsRayQueryParameters3D` 在 collision layer 1 上查询 80 m：只把岛面和柱体设为可画表面（装饰物无碰撞，不挡笔）；
3. 命中表面：取 `hit.position + normal·0.018`；若射线没命中（天空/岛外）：
   - 以“上一个线点”（或起点）为参照，构造**过该点、面向镜头**的平面（normal = camera forward）；
   - 求射线与平面交点；若平面在镜头后方则退回参照点；
   - 交点距参照点 > 3.1 m 时截断，再夹到岛半径 4.25 m 与 y 0.09–3.75；
4. 若按住 `Shift`，给点加 0.30 m 的抬笔高度（`_pen_lift` 以 2.6 m/s 平滑升降）；
5. 交给 `KnotRope._sanitize`：夹边界、抬离地面、把落在柱体碰撞半径内的点推到 `r + rope_radius + clearance` 外。

### 2.3 一笔与续笔

- 线锚点固定在起点（发光圈中心 y≈0.13）；起点由屏幕距离 ≤58 px 的“开始点击”判定。
- 按住左键时每帧采样；两点移动 < `min_step=0.075 m` 时忽略。
- 松开左键 = 暂停但**不断笔**；在绳头白球 58 px 内按下才可继续，避免瞬移产生断点。
- `Tab` 在绘制/镜头模式间切换；右键拖动在两种模式下都可旋转；右键单击（位移 <5 px）或 `Space` 收笔；`Esc` 收回整笔；`R` 重建本关。

## 3. 绳的表示与 TubeMesh

### 3.1 数据

`src/knot_rope.gd`

```text
points: PackedVector3Array   // 第 0 个 = 锚点；后续 = 用户点 + 自动弧点
_user:  PackedByteArray      // 1=用户控制点，0=柱体避让自动弧点
```

- `min_step=0.075`、`max_points=520`、`max_jump=2.8`（单次输入超过时沿方向截断）。
- `step_count = 用户点数 - 1`（锚点不算一步）。
- `length()` 用原始折线长度；鼠标密集采样下典型 2 关路径约 10–21 m。

### 3.2 Catmull-Rom 采样

`src/knot_tube.gd`

- 先去除相邻重复点；端点用镜像控制点扩展（`p0 = p1 + (p1-p2)`）。
- 均匀 Catmull-Rom，tension 0.5，默认每段 3 个细分；总采样数上限 1100。
- 采样既用于 TubeMesh，也用于 winding / 自交度量（度量前再抽稀到 420 个样本，见 §8）。

### 3.3 管状网格

`KnotTube.build_tube(sampled, radius, radial=10)`：

1. 每个采样点求切线（中心差分，端点单边差分）；
2. **平行传输**框架：用 `Quaternion(prev_tangent, tangent)` 旋转上一法线，再投影到切线垂直面并归一化，避免沿绳扭转/翻面；
3. 每个环 10 个顶点，沿周向 `cos/sin` 生成法线；三角形 `(a,b,c)` 与 `(b,d,c)` 保证朝外；
4. UV：`u` = 沿绳 0..1，`v` = 周向 0..1；无端盖（两端由起点桩/白球点/目标桩覆盖）。

半径 `ROPE_RADIUS=0.068 m`；柱体避让净空 `clearance=0.055 m`。

### 3.4 绳材质与阴影

`shaders/rope.gdshader`

```glsl
float s = UV.x * bands + UV.y * 1.35;
float stripe = smoothstep(0.245-aa, 0.245+aa, abs(fract(s)-0.5));
ALBEDO = mix(cream, coral, stripe);  // aa 由 fwidth 抗锯齿
EMISSION = ALBEDO * 0.055;
RIM = 0.55; RIM_TINT = 0.18;          // 暗色 Fresnel 边缘，接近玩具描边
```

- `bands = clamp(length / 0.24, 6, 110)`，条纹间距约 0.24 m，并由 UV.y 加 1.35 的扭转。
- `MeshInstance3D.cast_shadow = ON`，方向光阴影开启（2048 贴图、max_distance 14 m、blur 0.6）。
- 由于 Intel GL 驱动上的实际投影阴影很淡，另外生成**压扁的绳影**：同一份 TubeMesh 再交给一个 y 缩放到 0.001、y=0.014 的 `MeshInstance3D`，用深色半透明 unshaded 材质；它和真实阴影一起保证“绳子悬空/跨过自己”的可读性。
- 立柱/道具/建筑使用贴地的**接触阴影**（见 §8），并用 MultiMesh 合并为一次 draw。

## 4. 绕柱：避让 + winding

### 4.1 柱体

关卡 JSON 中的柱体归一化为：

```gdscript
{ id, name, center: Vector2(x,z), radius, height, turns, required,
  color, top_color, pos3 }
```

岛面 + 柱体是唯一的物理碰撞层；柱体视觉由柱身、柱础、顶部球、两道环、目标提示环（torus）与未完成时绕环旋转的小珠组成。

### 4.2 不允许穿柱

`_sanitize` 与 `_arc_around`：

- 每一步先把落入柱体圆柱 `r + rope_radius + clearance` 的点沿径向推出；
- 对上一段 A→B 与圆柱的 XZ 截面做线段/圆求交，若弦会穿过柱体：
  - 取进入/离开角，按**短弧**方向以 ≤15° 插值圆弧点；
  - 圆弧半径固定为 `r + rope_radius + clearance`，高度按 A/B 插值；
  - 若整段在柱顶以上（`min(h) > height + 0.05`）则跳过，不插弧；
- 自动弧点 `_user=0`，不计步数，撤销用户点时随该段一起回退。

这是**玩法辅助**而非物理模拟：它保证绳在视觉和 winding 上确实绕过柱子，但不模拟绳子张力、自碰撞或接触形变。

### 4.3 Winding 度量

`KnotRope.compute_winding()`

对每根柱体，扫描采样点：

1. 只考虑满足 `|xz - center| <= radius + wrap_band`（`wrap_band=0.58 m`）且 `0 <= y <= height + 0.16` 的点；
2. 连续满足的点构成一个 run；run 内用 `wrapf(angle_now - angle_prev, -π, π)` 累加有符号角（跳变 ≥1.1 rad 的采样点跳过）；
3. 记录每个 run 的有符号总角度，取**绝对值最大**的 run；
4. `turns = best_run / 2π`；UI 显示 `abs(turns)*360°`，判定也用 `abs(turns)`（顺时针/逆时针都有效）。

为什么取“最强 run”而不是全部求和：玩家绕完一圈后把线尾甩出柱周时，尾巴在柱周带内的反向角变化会把累计值抵消，导致明显的“已经绕满却没有判定”。按连续区间取最大绝对值可避免这个反直觉 bug。演示/鼠标密集路径的测试也验证了这一点。

**边界**：
- 大于柱高的 loop 不计；离柱超过 band 的 loop 不计；
- 两柱重叠时分别计算，不合并成联合绕数；
- 绕多圈在一个 run 内可累计（≥1 圈由 `turns` 判定，当前关卡只要求 1 圈）；
- 自动弧和用户点都在带内，视觉上的圈与判定一致。

## 5. 自交与 over/under

`KnotRope.find_crossings()`

1. 在 **XZ 平面**上对所有采样段两两求交（AABB 粗筛）；
2. 跳过沿绳弧长距离 < 0.45 m 的段对，跳过交点参数 t/u 在端部 3% 内的退化情况；
3. 在交点处线性插值两段的高度 `y_a`、`y_b`，`delta = |y_a - y_b|`；
4. `delta >= 0.12 m` → resolved（有上有下）；否则 → flat（平交）；
5. 以 XZ 距离 0.16 m 聚类去重，保留 delta 最大的代表；
6. 调试视图显示所有（可显示）交点；`F1` 面板显示 resolved / flat 数量。

**这是刻意近似的“打结条件”**：
- 只检测水平投影交叉，竖直平面中交叉的绳段不会算；
- over/under 由 3D 高度决定，不是根据镜头视角；
- 近顶点相交可能被 t/u 安全边距跳过（测试里特意用奇数段来避免采样点正好落在交点上）；
- “平交”记录但不阻止玩家；它不是物理自碰撞；
- 没有 knot invariant、没有 Reidemeister moves、没有三叶结分类。第 2 关的“8 字/上下”是本项目自洽的**伪结条件**，不是数学结。

## 6. 关卡 schema 与胜利判定

示例（简化自 `levels/level_02.json`）：

```json
{
  "id": "double_loop",
  "name": "双环庭",
  "subtitle": "第二结 · 双柱上下",
  "blurb": "青柱与珊瑚柱各绕一圈，并让绳子……",
  "palette": { "sky_top": "#9EC6E3", "island_top": "#D5E1B2", "accent": "#3E8E8A", "...": "..." },
  "start": [-2.80, 0.12, 1.45],
  "goal": [2.75, 0.06, 1.45],
  "goal_radius": 0.62,
  "start_radius": 0.62,
  "pillars": [
    { "id": "qing", "name": "青柱", "pos": [-1.35, 0.25], "radius": 0.28,
      "height": 1.80, "turns": 1, "required": true,
      "color": "#3E8E8A", "top_color": "#F2CC8F" }
  ],
  "crossings_required": 1,
  "camera": { "yaw": -36, "pitch": 40, "distance": 10.8, "focus": [0, 0.55, 0] },
  "hints": ["...", "..."]
}
```

判定（`KnotLevel.evaluate()`）：

| 检查 | 条件 |
| --- | --- |
| 每根必须柱 | `abs(winding.turns) >= required_turns - 0.035` |
| 可选柱 | 只显示进度，不参与胜利 |
| 自交 | `resolved_crossings >= crossings_required` |
| 结台 | 线尾 XZ 距结台中心 ≤ `goal_radius`，且 y ≤ 1.05 m |
| 胜利 | 所有 required 检查通过；仅在玩家按 `Space`/右键单击“收笔”时触发 |

HUD 的目标行实时显示角度/圈数、自交数与“还差 x m”；`H` 显示数据里的关卡提示；底部情境提示按优先级自动变化（先必须绕柱 → 自交上下 → 结台 → 可收笔）。

**第 1 结**：青柱 1 圈（必须），铃柱 1 圈（可选，完成时触发铃音/粒子），终点。
**第 2 结**：青柱 + 珊瑚柱各 1 圈，额外 1 次 over/under；苔柱可选。第 2 关的演示/测试路径使用抬高的第二股绳，高度差 ≥0.12 m。

## 7. Undo / Reset / 取消

- `undo_info()` 找到最后一个用户控制点与上一个用户控制点，返回 `keep_count`、起止点；
- 撤销动画 0.20 s：临时绘制“保留到上一用户点 + 从末点线性回收到上一点”的可视 polyline，用 `ease(t, 0.45)`；结束后真正 `undo_last_control()` 截断数据与自动弧点，重算 metrics；
- 若撤销到只剩锚点，则 `started=false`、计时归零；
- `Esc` 清空回到起点；`R` 重建整关（相机/目标/HUD/计时）；
- 调试探针验证：屏幕射线连画 9 步 → `Z` 后 8 步，耗时 0.4 s 内完成。

## 8. 性能与渲染

### 8.1 设置

| 项 | 值 | 理由 |
| --- | --- | --- |
| Renderer | GL Compatibility | 任务要求；Intel HD 6000 |
| 游戏 MSAA | 关闭 | 帧率；截图单独开 2× |
| 方向光阴影 | 2048、max distance 14 m、blur 0.6 | 控制带宽/填充 |
| 接触阴影 | 1 个 MultiMesh | 替代大量小透明面 |
| 踏脚石/石子 | 2 个 MultiMesh | 15+ 个单体 → 2 draw |
| 云 | 1 个 MultiMesh | 9 个球 → 1 draw |
| 花草 | 单花头 + 少量球 | 控制 draw |
| 逻辑采样 | Catmull 采样后抽稀到 420 点 | 交叉检测 O(n²) 有界 |
| 自交更新 | 绘制时 0.18 s 节流；收笔时全量 | 避免逐点 O(n²) 卡顿 |
| HUD 更新 | 0.12 s 节流 | 减少 2D 重建 |
| 字体 | Noto Sans SC 子集 95 KB，`FontFile.load_dynamic_font` 运行时读取 | 中文 UI、无导入依赖、无外部网络 |

### 8.2 本次实测（真实 GPU，1280×720 live 窗口，VSync 关）

```
LIVE_IDLE fps=56.0 draws=172
LIVE_ROPE fps=113.7 draws=173
LIVE_DEBUG fps=108.7 draws=182
HUD 截图显示 FPS 109 · Draw 182
```

- 多次测量因 macOS 窗口遮挡/省电策略有波动（本任务观察到的范围为 idle/rope 55–152 FPS；最终带绳 113.7、debug 108.7、截图 HUD 109）；所有测量都高于 30 FPS 目标。正式运行开启 VSync，上限 60 FPS。
- 1920×1080 截图在 1920×1080 的 SubViewport 中渲染（2× MSAA、UI 以 1280×720 布局后 1.5× 拉伸），通过 `get_texture().get_image()` 回读；回读和保存会拖慢 wall-clock 帧率，截图日志中的 capture FPS（1–20）**不是游戏性能**，HUD 在 capture 模式隐藏实时 FPS 卡。
- 画面主要 draw call 来源：岛体、柱体、装饰、目标环/珠、绳（主+压扁影）、HUD 面板、调试标记；无后处理链，无第三方资源。

## 9. 自测覆盖与证据

`tools/smoke_knotline.gd`（headless，98 checks）：

- 关卡 schema / 目标 / 相机默认值；两关均加载；
- Catmull 采样端点、有限值、Tube 顶点/索引/UV/法线、索引范围；
- 一笔连续性（锚点不动、重复点拒绝、步数、夹边界、长度）；
- 柱体避让（所有原始点不进入净空圆柱、自动弧插点、用户步数不变）；
- winding（整圆 1、半圆 0.5、反向 -1、高于柱顶 0、远离柱 0）；
- 自交（有高度差 → resolved，同高 → flat、不 resolved）；
- 目标判定（全满足、远离结台、未套柱、可选柱不阻塞、顺时针负 winding、第 2 关缺自交）；
- Undo/Reset（逐点回退到锚点、重置长度/步数）；
- 演示路径（稀疏 + 鼠标密度抽稀）两关必胜，且第 2 关保有 over/under；
- 场景 wiring（实例化主场景、加载第 2 关、路径判定、收笔后 won=true）。

输出：

```
$ godot --headless --path godot-knotline-puzzle -s tools/smoke_knotline.gd
KNOTLINE_SMOKE_OK checks=98 levels=2
```

实机：

```
$ godot --path godot-knotline-puzzle --resolution 1280x720 -s tools/probe_live.gd
LIVE_SCREEN_DRAW started=true points=17 steps=9
LIVE_UNDO before=9 after=8 ok=true
LIVE_SHADOW enabled=true
KNOTLINE_LIVE_OK fps=113.7 draws=173

$ godot --path godot-knotline-puzzle --resolution 1280x720 --quit-after 600
（10 秒，无 ERROR / SCRIPT ERROR）
```

视频：

```
$ godot --path godot-knotline-puzzle --resolution 1280x720 --fixed-fps 30 -s tools/capture_video.gd
KNOTLINE_VIDEO_FRAMES_OK frames=300 video_seconds=10.00 wall=20.9s
KNOTLINE_VIDEO_PATH points=254 steps=254
```

`docs/shots/knotline_demo_10s.mp4`：1280×720、30 fps、300 帧、10.000 s；GIF：800×450、12 fps、120 帧。

## 10. 目录 / 入口

| 文件 | 职责 |
| --- | --- |
| `src/knot_game.gd` | 输入、模式、射线条、Undo 动画、调试钩子、HUD 接线 |
| `src/knot_rope.gd` | 一笔数据、柱体避让、winding、自交、指标 |
| `src/knot_tube.gd` | Catmull-Rom、TubeMesh |
| `src/knot_level.gd` | JSON 读取/校验、归一化、目标判定 |
| `src/knot_world.gd` | 岛/柱/目标/装饰/环境/粒子/接触阴影 |
| `src/knot_orbit_camera.gd` | 轨道相机 |
| `src/knot_hud.gd` | 中文 HUD、目标行、提示、过关卡、调试面板 |
| `src/knot_sfx.gd` | 程序化 sine 合成音效 |
| `levels/*.json` | 关卡数据 |
| `tools/smoke_knotline.gd` | headless 验收 |
| `tools/probe_live.gd` | live FPS / 屏幕射线 / undo 探针 |
| `tools/probe_knotline.gd` | 早期性能分解探针（保留） |
| `tools/probe_paths.gd` | 演示路径 metrics 打印 |
| `tools/capture_shots.gd` | 1920 截图 |
| `tools/capture_video.gd` | 固定 30 fps 视频帧源 |
| `tools/demo_paths.gd` | 无头/截图/视频共用的演示控制点 |

## 11. 近似边界（重要）

本项目满足“3D 一笔画 + 绕柱 + 自交上下 + 目标判定 + undo”的可玩闭环，但**不是**物理绳模拟，也不是数学结判别：

1. **绕柱避让**是规则性的：线段切柱时自动插入圆弧，而非求解碰撞；玩家不能把绳“压进”柱体，但可借此获得比手绘更规整的绕柱。
2. **Winding** 在水平柱周带内计算；高于柱子的环不计；离柱超过 0.58 m 的环不计；多柱重叠不合并。
3. **自交**只在 XZ 平面检测；竖直方向的交叉、端点处交叉、平行贴合都不计；高度差 <0.12 m 记为平交；没有三叶结/8 字结的拓扑分类，也没有 knot invariant。
4. **绳自身不自碰撞**：平交在视觉上可穿过，游戏只提示“未分上下”，不阻止。
5. **自动弧+采样**会略微改变几何；视觉网格与度量都用同一条采样链路的近似。
6. **物理**：只有一层 raycast（岛/柱），没有绳索动力学、摩擦、重力悬挂。
7. **Undo** 冒一个用户点，不是任意段/半段；平滑动画是视觉插值，数据在动画结束时才裁剪。
8. **输入**只支持鼠标/触摸模拟；相机操作与绘制共用右键拖动。
9. **方向光投影阴影**在当前 Intel GL 驱动上偏淡；接触阴影与压扁绳影是补偿手段，不是真实光照模拟。
10. **1920 截图 FPS** 与 **1280 游戏 FPS** 不能混为一谈：截图是离屏回读，游戏内 HUD 隐藏 capture FPS。

## 12. 已知问题 / 后续

- cast shadow 在 Intel GL 上存在但很淡（已用接触阴影/绳影增强）；如需更强，可改用烘焙 blob shadow 或提高 shadow 分辨率换性能。
- 自交检测仍有近顶点漏检；可加入“顶点附近 epsilon 扰动”或段-段最近距离补充。
- 演示路径为了同时适配稀疏控制点与鼠标密度，绕柱用了 400° 而非恰好 360°；HUD 对完成态显示 360°。真实玩家 360°+ 即可。
- 音频是简单合成音，未做专业混音；视频为无声演示。
- 字体是子集；增加新 UI 文案时需重新运行 pyftsubset。
- 触摸仅通过 emulate_mouse_from_touch，对多点触控未优化。
