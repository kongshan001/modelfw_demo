# 技术拆解：用 Python/Bpy 生成一段 3D 产品短片

> 参考：B 站《这居然是 Fable5.2 用代码做出来的视频？怎么实现的？》里展示的
> Blender + MCP 工作流。本工程是同一类链路的 **Godot 之外的 Blender 落地**：
> 用 `bpy` 程序化建模、打光、做动画、渲染，再用 ffmpeg 合成。

## 0. 一句话版本

视频里“每个鼠标操作背后都是 Python”是真的：Blender 的整个场景都可以由 `bpy` 构建。
Agent（或人）只需要写一份场景脚本，Blender 负责渲染，ffmpeg 负责封装。

## 1. 为什么是 `bpy`，不是“文生视频”

| 路线 | 本质 | 一致性 | 可控性 |
| --- | --- | --- | --- |
| AI 视频模型 | 像素/潜空间生成 | 容易闪烁、变形 | 镜头/结构难精确控制 |
| **Blender + bpy** | 真 3D 场景 + 渲染器 | 几何/光照/相机全程一致 | 每个参数都能代码控制 |
| Three.js | 实时代码渲染 | 一致 | 交互强，电影级渲染弱 |

本片选择 Blender：需要精确的镜头轨道、材质反射、透明翼、景深和慢动作质感。

## 2. 场景构建（`scripts/build_scene.py`）

### 2.1 程序化几何

- 球/圆柱/圆环/盒子拼装胸腔、头、光学镜头、腹部、尾齿轮、腿；
- 翅膀用 `mesh.from_pydata` 画自定义轮廓，`SOLIDIFY` 加厚，再加 3 根叶脉圆柱；
- 每件零件都挂在 `HB7_Root` 空物体下，方便整体漂浮和相机取景。

**本轮最大的坑：父子关系。**
最初用 `matrix_parent_inverse` 保留世界位置，结果所有身体零件停留在世界原点（地面），
只有翼枢轴是 root 局部坐标——画面表现为“身体在底部、翅膀悬空”。
修复：身体零件按 root 局部坐标建模，`obj.parent = root` 不保留世界矩阵。

### 2.2 材质

Principled BSDF：

- 白陶瓷：低粗糙 + Clearcoat；
- 黑色金属：低 roughness 但高光收敛；
- 光学镜头：**哑光纯黑**（Specular 0.12），避免被面光照成白球；
- 红色珐琅、黄铜、发光环（Emission 3–6）；
- 翅膀：Alpha 0.7 的奶油膜 + `BLEND`，深色叶脉。

### 2.3 灯光

- Key：暖白面光，右前上方；
- Fill：冷蓝面光，左前方；
- Rim：红色面光，后上方，勾出红边；
- Top：大面光，压顶。
- World：近黑暖色，强度 0.45；地面/转盘深色，红环收边。

### 2.4 相机

- `orbit` 空物体在物体中心；
- 相机父级到 orbit，固定局部旋转看向中心；
- 关键帧只转 orbit 的 Z：+58° → -58°，10 秒；
- 相机局部 Y 从 -7.2 推到 -6.55，轻微 dolly；
- 52mm，f/2.8，对焦空物体；EEVEE 景深。

> 不要用 Track To 约束叠在动画父级上——本轮试过，容易在渲染时对不上目标；
> 固定局部朝向 + 旋转父级更稳。

### 2.5 动画

- 机身 Z 漂浮：5 个关键帧，Bezier；
- 4 翼拍动：3.6Hz，每 2 帧烘焙一次，F-Curve 设 `LINEAR`，避免 Bezier 过冲；
- 镜头环 Emission Strength：3 → 6 → 3 脉冲；
- 尘埃：18 个小球绕 Z 慢转。

## 3. 渲染

Blender 3.4.1 / EEVEE Legacy：

- 960×540，24fps，240 帧；
- 8 samples + Bloom + SSR + GTAO + Motion Blur；
- Filmic + Medium High Contrast，exposure 0.05；
- 输出 PNG 序列；ffmpeg 封 MP4。

### 3.1 为什么不用 4.2 的 EEVEE Next

本机 GPU：Intel HD Graphics 6000（Metal GPUFamily macOS 1）。
Blender 4.2.9 的 EEVEE Next 在 `DRW_state_reset` 崩溃；Workbench 同样崩溃。
Cycles CPU 可用，但 640×360/8 samples 约 7.5s/帧，10 秒 720p 不现实。
Blender 3.4.1 的 EEVEE Legacy 在 OpenGL 4.1 上正常，本片最终用它。

### 3.2 性能取舍

| 设置 | 选择 |
| --- | --- |
| 分辨率 | 960×540（原计划 1280×720，后因时间降级） |
| Samples | 8（Bloom 掩盖噪点） |
| 透明 | 仅保留翅膀 Alpha；去掉大玻璃罩 |
| 尘埃 | 46 → 18 |
| 结果 | 240 帧约 15–20 分钟（Intel iGPU） |

## 4. MCP 安装

- 插件：`blender_mcp_addon.py` 复制到 Blender 3.4/4.2 的 `scripts/addons/` 并启用；
- Server：`uv` 创建独立 venv，`pip install mcp-for-blender`；
- Claude Code：`claude mcp add blender -- <venv>/bin/python -m blender_mcp.server`；
- 使用：手动打开 Blender → N 面板 → Start MCP Server（9876）→ 重启 Claude Code。
- 限制：插件在 `blender -b` 后台模式拒绝启动服务器，必须有 GUI 实例。

## 5. 本轮踩坑

| 现象 | 根因 | 修复 |
| --- | --- | --- |
| 身体在地面、翅膀悬空 | `matrix_parent_inverse` 保留世界位置 | 改为 root 局部坐标直接 parent |
| 机位总是对不准 | Track To 约束 + 动画父级叠加 | 固定相机局部朝向，只旋转 orbit |
| 白色身体像白球、看不到黑镜头 | 相机在尾部一侧，白壳遮住镜头；黑材质高光过强 | 反向轨道，从头部开始；镜头改哑光黑 |
| 翅膀像薄片/竖着 | 网格建在 XZ 平面 | 改到 XY 平面，加 14° 上反角与后掠 |
| 红色环被埋进白壳 | torus 主半径 < 壳体截面 | 半径加到 0.63/0.65 |
| 4.2 EEVEE 一渲染就崩 | Intel HD 6000 + Metal GPUFamily 1 | 改用 3.4.1 EEVEE Legacy |
| MCP server 连接失败 | uv console script 的 shebang 依赖 macOS 没有的 `realpath` | 建独立 venv，用 `python -m blender_mcp.server` |
| 渲染太慢 | 16 samples + 720p + 透明罩 + 46 尘埃 | 8 samples / 960×540 / 去玻璃罩 / 18 尘埃 |

## 6. 验证

```bash
# 帧数
ls /tmp/hb7_blender/frame_*.png | wc -l       # 240

# 视频参数
ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration \
  -of default=noprint_wrappers=1 docs/hb7_core.mp4
```

- `docs/poster.png`：头部/镜头一侧的定帧；
- `docs/shots/`：可补的静帧；
- `MCP`：`claude mcp list` 中 `blender` 显示 Connected。
