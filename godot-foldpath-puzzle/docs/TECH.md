# Foldpath · 折径 — 技术说明

T-20261126-016 · 2026-11-26 · Godot 4.6 stable / GL Compatibility
Intel HD Graphics 6000 · OpenGL 4.1 (Compatibility) · macOS

## 0. 交付物与文件

| 路径 | 作用 |
| --- | --- |
| `src/fold_game.gd` | 主控：关卡、屏幕折环、路径 BFS、旋转、撤销、HUD 接线、调试接口 |
| `src/fold_level.gd` | JSON schema、节点世界坐标、折环候选/激活、路径图、BFS |
| `src/fold_world.gd` | 程序化纸建筑、路径带、节点、折环、目标、软阴影、天空/雾、静态合批 |
| `src/fold_camera.gd` | 固定等轴正交相机（不能 orbit，只能 zoom） |
| `src/fold_player.gd` | 原创“小折狐”程序化低模 + 行走/折叠/庆祝 + blob 阴影 |
| `src/fold_hud.gd` | 中文 HUD、屏幕空间折环 overlay、角度盘、提示、胜利卡、调试面板 |
| `src/fold_math.gd` | 正交投影、屏幕不变方向、ray/OBB 拾取、角度吸附 |
| `src/fold_palette.gd` | 原创色板/共享材质/软阴影材质 |
| `levels/level_0*.json` | 3 个数据驱动关卡 |
| `shaders/vignette.gdshader` | 边缘暗角 + 轻颗粒 |
| `shaders/soft_shadow.gdshader` | 径向软阴影贴片（非 shadow map） |
| `shaders/sky_gradient.gdshader` | 无缝天空渐变 |
| `tools/smoke_foldpath.gd` | headless 验收（154 checks） |
| `tools/probe_live.gd` | 实窗真实点击/拖动 + FPS + 实时截图 |
| `tools/capture_shots.gd` | 1920×1080 真实 GPU 截图 |
| `tools/capture_video.gd` | 300 帧 / 30 fps / 10 s 视频源 |

## 1. 固定等轴正交投影

相机 `FoldCamera`：

- `projection = ORTHOGONAL`；
- `Basis.from_euler(Vector3(-35.2643896827546°, 45°, 0), EULER_ORDER_YXZ)`；
- 位置 `focus + BACK * 12`，其中 `BACK = (1,1,1)/√3`；
- 每关 `focus` / `size` 不同（L1 5.9、L2 6.7、L3 7.0），滚轮 zoom 0.82–1.22 只改正交 `size`；
- 屏幕坐标固定以 1280×720 设计像素计算，HUD overlay 也用同一坐标系（1920 截图里被 1.5× 上采样）。

`FoldMath.project`：

```
basis = YXZ(-35.264°, 45°, 0)
right = basis.x, up = basis.y, back = basis.z = (1,1,1)/√3
rel = p - focus
ppw = viewport_h / ortho_size          # 720 / size
screen = (640 + dot(rel,right)*ppw, 360 - dot(rel,up)*ppw)
depth  = dot(rel, back)
```

关键性质：

```
project(p + t*BACK) == project(p)
depth(p + t*BACK) == depth(p) + t
```

所以两段路可以在“屏幕上重合”，但世界坐标沿视线方向相差 `t`，形成不同深度。L1 的 `u = a + 1.6*BACK`；L2 两条缝 `a = i + 1.4*BACK`、`b = o90 - 1.0*BACK`；L3 三段缝分别是 1.3856 / 1.0392 / 1.7320。

- 正交 size 的“垂直 1 世界单位”在屏幕上实际是 `0.816497 * ppw`，因为世界 Y 与相机 up 有夹角；代码/测试以此为准。
- 用真实 `Camera3D.unproject_position` 对照过：L1 的 4 个节点在 1280 下误差 < 0.001 px（`proj_probe` 临时探针，见迭代记录）。因此 overlay 的折环和 3D 几何严格共位。

## 2. 屏幕空间折环（不可能几何核心）

### 2.1 端点与设计缝

`FoldLevel.link_candidates` 从 JSON 的 `fold_pairs` 收集端点；每个端点必须是：

- 路径图中的度数为 1；
- `kind == "path"`（start/goal 不参与）；
- 属于平台，另一端点在不同平台。

L1：`u–a`。L2：`a–i`、`o–b`。L3：`l–r1`、`r2–t1`、`t2–c`。

JSON 里显式声明候选缝而不是自动配对所有端点，原因：程序化测试发现 L3 在 15° 网格上会出现 `r1–t2` 等 10–17 px 的偶然近平行投影，若开放所有端点会产生额外捷径。显式缝仍然**完全由屏幕投影决定是否打开**：旋转到非对齐角时缝关闭，UI 上的折环消失。这不是预烘焙连接。

每条缝每帧重新计算：

```
sa = project(node_a_world)
sb = project(node_b_world)
dist = |sa - sb|
depth_delta = |depth_a - depth_b|
open = dist <= link_px(18) && depth_delta >= link_depth(0.35)
```

通过后按 `dist` 贪心去重（一个端点最多一条活动缝），排序输出。`FoldGame._refresh_links()` 在旋转拖动、Q/E tween、zoom、关卡加载和每帧 `_process` 中调用；角色的可行图始终只使用**当前**活动缝。

### 2.2 路径图与折叠行走

- 基础图：JSON `edges`（强制同平台，避免跨平台弯折）。
- 运行时在基础图上加活动缝作为临时边。
- 点击节点 → BFS 得到 `[a, b, ...]`；若没有路径，提示“先旋转纸桥”。
- 每一步是世界空间直线（同平台的边是刚体，随平台旋转；角色只能在旋转停止后行走）。
- 缝步使用 0.58 s 的“折纸”动画：世界位置沿视线方向插值（屏幕位置不变），角色 Y 压缩到 0.28、绕 Y 翻转 360°、轻微抬起，并在缝的屏幕位置播发扩散环；`hud.pulse_fold`。
- 目标节点到达 → 胜利卡；移动记录为一条 undo action。

### 2.3 屏幕拾取

- 节点：投影距离 27 px 内；对 open 端点额外接受“折环高度”的位置（节点上方 0.36 世界单位，约 36 px），因此点击视觉上的折环也能选中节点；普通节点用 pad 位置。
- 平台：屏幕 ray → 平台局部 OBB（`FoldMath.ray_yaw_box`），取最近命中；拖动只在可旋转件上开始。
- “折环高度”在 overlay 与 3D halo 上都使用；overlay 通过同一 `fold_lift = 0.36 * 0.816497 * 720/ortho` 上移，避免出现两枚错位圆环。

## 3. 旋转构件

平台 JSON：

```json
{
  "id": "bridge", "name": "旋桥", "pivot": [0, 1.1, 0],
  "initial": 0, "rotatable": true, "step": 15,
  "shape": "bridge", "size": [3.5, 0.36, 0.8]
}
```

节点局部坐标 `pos`，世界坐标：

```
world = pivot + R_y(angle) * local
```

- 初始角来自 `initial`；每关启动时 `FoldLevel.initial_angles`。
- Q/E 每次 ±`step`（15°），tween 0.20 s；拖动灵敏度 0.55°/px，松手吸附到 15°。
- 构件旋转时角色若站在该构件的节点上，随平台“乘坐”（`_process` 每帧按当前显示角重算节点位置，`player.idle`）。行走中禁止旋转；旋转 tween 中禁止行走。
- 旋转是 undo action（记录拖动起始角 / Q/E 起始角）。拖动可以转多圈；HUD 角度盘显示 `fposmod(angle, 360)`。
- L2 桥 0°→90°；L3 环桥 0°→90°、折塔 0°→90°。L3 的环桥视觉是一个窄梁而不是圆盘，减少与上层高冠的遮挡；环桥上的路径节点随梁旋转。

## 4. 关卡数据

```json
{
  "id": "L2", "order": 2, "name": "旋桥庭",
  "objective": "...", "camera": {"focus": [0.4, 1.08, 0.28], "size": 6.7,
                                "zoom_min": 0.82, "zoom_max": 1.22},
  "link_px": 18.0, "link_depth": 0.35,
  "start": "s", "goal": "g",
  "platforms": [{"id":"bridge","pivot":[0,1.1,0],"initial":0,"rotatable":true,
                 "step":15,"shape":"bridge","size":[3.5,0.36,0.8],
                 "addons":[...],"ribbons":[...]}],
  "nodes": [{"id":"i","platform":"bridge","pos":[1.55,0,0],"kind":"path"}],
  "edges": [["i","m"],["m","o"]],
  "fold_pairs": [["a","i"],["o","b"]],
  "hints": [{"text":"...","focus":"a"}],
  "soft_shadows": [{"pos":[0.15,0.535,1.0],"size":[2.3,1.2],"rot":18,"alpha":0.15}]
}
```

`FoldLevel.validate` 检查：必填键、平台 pivot/size、节点平台引用、kind、start/goal、边同平台且无重复、fold_pairs 跨平台且只接路径端点、相机参数。任一关卡无效会被 `FoldGame` 过滤并 `push_error`（当前 3 个都通过）。

## 5. 渲染与性能

### 5.1 程序化视觉

- 全部几何由 `BoxMesh / CylinderMesh / TorusMesh / PlaneMesh / SphereMesh` 组合；无纹理、无外部模型、无第三方运行库。
- 色板：奶油纸、苔绿/深松、陶土、黄铜、芥末、梅；角色为折纸狐狸。
- 天空：`sky_gradient.gdshader`（`EYEDIR.y` 平滑混合 horizon/top/bottom），无硬地平线。
- 雾：`Environment` 雾密度 0.0032，配合远景漂浮纸片/环/纸鸟。
- 软阴影：见 5.3。

### 5.2 静态合批

`FoldWorld._batch_platforms()` 在每个平台本地空间内，将所有静态 MeshInstance 按 `(material, cast_shadow)` 分组，用 `SurfaceTool.append_from(mesh, 0, transform)` 烘焙成少量 ArrayMesh；动态节点用 meta `fold_dynamic` 排除：

- 飘带、折环/目标宝石、起点旗杆；
- 角色、折环 overlay、UI 不参与。

这样平台主体、路径带、节点 pad、黄铜刻线、addon、Contact shadow 都合并；draw calls 从首版 251–369 降到 **144–184**（普通场景），调试/胜利 UI 叠加到约 261。MSAA 关闭、shadow map 关闭以适配 Intel。

### 5.3 柔和阴影的近似边界

在目标机器（Intel HD 6000 / macOS OpenGL 4.1 Compatibility）上：

- 测试了 `DirectionalLight3D.shadow_enabled=true`，`SHADOW_ORTHOGONAL` 与 `SHADOW_PARALLEL_4_SPLITS`、shadow map 1024/2048、多个光角度、相机距离 12/30；
- 最小 shadow probe 场景（地台 + 立方体 + 方向光）也未见可见投影；判定该驱动/GL Compatibility 路径上方向光 shadow map 不产出可用结果。
- 因此最终视觉采用：
  - `soft_shadow.gdshader` 径向 alpha 贴片（平台 addon 根部、角色脚底、手放的“大影子”）；
  - 深色底面（`stone_dark`/`pine`）、黄铜刻线、雾与天空渐变；
  - 方向光保留为塑形光（无 shadow map），另有一盏冷色补光。

**这是艺术化近似，不是物理投射阴影。** 它稳定、便宜，且与纸艺风格一致；在支持 shadow map 的机器上也不会出现双重影子（shadow map 关闭）。

### 5.4 实测

实窗 1280×720，VSync off，Intel HD 6000，前台。正常玩法（无调试叠加）的聚焦基准：

```
NORMAL L1 idle fps=101.1 draws=147 meshes=86
NORMAL L2 idle fps=82.9 draws=169 meshes=104
NORMAL L3 idle fps=87.8 draws=180 meshes=111
NORMAL L2 rotating fps=93.2 draws=165
L3 debug fps=55.9 draws=261
```

`tools/probe_live.gd`（真实点击/拖动输入路径；本机同时有其它 worker 负载，故数值更低）：

```
LIVE_IDLE fps=64.7 draws=147
LIVE_CLICK node=u walked=true at=u
LIVE_DRAG bridge_angle=90.0 rotating=false
LIVE_UNDO angle=0.0 ok=true
LIVE_WIN reached=true node=g
LIVE_ACTIVE fps=34.7 draws=261 links=1
LIVE_1920 window=(1920, 762) viewport=(1280.0, 720.0)
LIVE_1920 fps=31.8 draws=261
FOLDPATH_LIVE_OK fps=34.7 draws=261
```

- 两种测量都高于 30 FPS；正常玩法/旋转明显高于调试叠加。调试叠加多出投影点、图线、阈值圆、文字。
- 1920×1080 实窗受本机显示器高度限制被 macOS 限制为 1920×762；游戏逻辑 viewport 仍为 1280×720（stretch `canvas_items`）。
- 1920 截图的调试卡片 FPS 是 offscreen SubViewport 的采样，不是实窗基准。
- 1920×1080 验收截图通过 SubViewport（1920×1080，`size_2d_override` 1280×720，真实 GPU，MSAA 2×）输出，7 张 PNG 均为 1920×1080。
- 视频：1280×720、30 fps、300 帧、10.00 s；MP4 1.2 MB / GIF 7.5 MB。

## 6. 交互 / HUD

- 点击节点 → BFS 行走；`←↑→↓` / `WASD` 朝屏幕方向走一个路径图相邻节点（含当前活动折缝）；点击折环高度也可选 open 端点；点击不可达节点给出提示。
- 拖动可旋转件；`Q/E` 微调；角度盘实时显示；选中平台信息在右下卡片。
- 顶部：标题、关卡 chips（可点击切关）、目标、提示行；底部左：操作条；右下：构件/撤销/重置/提示；`F1` 右上调试面板。
- 屏幕 overlay（`FoldHud._draw_overlay`）：活动折环脉冲、未连接端点微标、悬停环、提示脉冲、折纸飞散粒子、胜利彩纸、调试投影点/阈值圆/路径图/角度/FPS/draw calls。
- 中文字体使用 `SystemFont`（PingFang SC / Hiragino Sans GB / Noto Sans CJK / Microsoft YaHei 等），不随仓库分发字体；缺失时回退系统默认字体。
- UI 按钮 `focus_mode=NONE`，避免键盘 Q/E 被按钮焦点吞掉；CanvasLayer 的卡片的命中区域会阻止世界点击。

## 7. 调试 / 验收

- `F1` 显示：所有节点屏幕投影与 id/depth、open 端点 18 px 阈值圆、活动折环与像素距离、基础路径图、平台角度/旋转标记、玩家投影点、FPS、draw calls、ortho/zoom、动作统计。
- `tools/smoke_foldpath.gd`（headless）154 checks：
  - 3 个关卡 schema；跨平台 fold_pairs；度数 1；
  - 正交投影屏幕不变性/深度、ray/OBB、角度吸附；
  - L1 预对齐；L2 初始/45°/90°/180° 连通性；L3 环桥/折塔阶段与所有缩放下的精确缝；
  - 实景实例化、真实点击行走、undo、L1 折环过关、L2 旋转/undo/reset、L3 全流程/真实旋转乘坐/胜利、调试快照；
  - 末行 `FOLDPATH_SMOKE_OK checks=154 levels=3`。
- `godot --headless --path . --quit-after 600` 无 SCRIPT ERROR。
- `tools/probe_live.gd` 真实窗口：点击、拖动、undo、reset、胜利、调试、1280/1920 尺寸/FPS；保存 `docs/shots/08_live_1280.png`。
- 所有近期脚本/截图/视频日志均无 SCRIPT ERROR。

## 8. 已知边界 / 可继续做

- 屏幕拾取没有前景遮挡测试：透过后景重叠的前景构件也可能点到节点（当前布局里仅在意图重叠的开放端点上发生，且两端都会进入同一连通图）。
- 关卡只支持 Y 轴旋转；没有沿其他轴的翻转/折叠；屏幕对齐只对声明的 `fold_pairs` 生效。
- 对齐阈值是固定设计像素；滚轮 zoom 会改变像素距离（设计解仍为 0 px）。最大 zoom 1.22 时测试过不会把非设计缝打开。
- 固定等轴、无 orbit；角色为点行走/直线段，没有曲线插值或跳跃。
- 无音频、无存档、无触屏手势（仅鼠标模拟）；HUD 依赖系统 CJK 字体。
- 软阴影为贴片近似（见 5.3）；若未来在支持 shadow map 的设备上需要物理阴影，可加质量开关并重新调光，不要直接叠加。
