# 技术说明 · Steering Behavior 实验场

本文记录实现结构、行为公式、力合成、避障探测、性能设计与相对参考视频的差异。
参考视频：B 站 BV1yCqfYuEh1（2026-11-21 取证）。

## 1. 视频取证结论

用 `yt-dlp` 取 720p（1280×720，30fps，4:02），`ffmpeg` 全程 1s/帧、关键段 2–4fps 抽帧，只在 `/tmp` 分析，未复制任何画面进仓库。

观察到的实际内容：

- **0:00–0:20**：游戏实机混剪（RTS/俯视小队），用于说明“单位沿路径/绕障移动”。
- **0:20–1:15**：幻灯片定义 Steering Behavior（Craig Reynolds / Boids）、力→加速度→速度→位置更新、行为清单：Seek、Flee、Arrival、Pursuit、Evade、Wander、Path Following、Collision Avoidance、Leader Following、Cohesion、Separation、Alignment。
- **1:15–1:45**：**实际演示（本 Demo 的主要形态）**：深蓝底、整屏青色箭头（流场）、青绿色 C 形障碍（开口朝右）、粉色圆形单位、右侧青色目标点。单位沿流场绕开 C 形障碍；讲解指出流场直接改速度会在急弯贴墙，引出 Seek“期望速度 − 当前速度 = 转向力”。
- **1:45–2:05**：Separation 图解：碰撞范围内反向斥力，斥力大小与距离成反比，多邻居时求和。
- **2:05–3:05**：Avoidance 图解（矩形 + 圆形）：单位前方三条长射线，与障碍边求交；斥力沿法线、大小与交点距离相关，“动力”沿障碍切向；圆障碍用 P（长，与速度正相关）+ Q（短，垂直于 P）判断即将碰撞。
- **3:05–3:25**：组合演示：流场寻路 + steering 转向行为，大量粉色单位绕过 C 形障碍并在目标处汇合。
- **3:25–4:02**：总结（可配置性、可扩展性、空间划分、参考书籍）。

结论：视频真正演示的是 **流场寻路 + 三须避障 + 分离/聚合/对齐的组合**；其余行为只在清单里出现。本 Demo 以视频最终演示的视觉语言为主，并补齐清单中可交互的行为，便于实验。

## 2. 总体架构

```text
main.tscn
├── Sim (Node2D, steering_sim.gd)
│   ├── 行为/积分/碰撞（固定 1/60 s）
│   ├── 流场（flow_field.gd, RefCounted）
│   ├── 空间哈希（每 8 步重建 / 邻域缓存）
│   ├── _draw：背景、流场箭头、障碍、目标、调试线
│   └── MultiMeshInstance2D ×16：单位本体（3 类角色）+ 主导行为环（12 色）+ 选中环
├── Camera2D（世界 1600×900；1280×720 下 zoom 0.8，1920×1080 截图下 zoom 1.2）
└── UI (CanvasLayer, steering_ui.gd)：程序化中文控制台
```

- 世界：`1600×900`，可行走区 `Rect2(38,38,1524,824)`。
- 固定步长：`_physics_process` 调 `_step(1/60)`；累计器不使用渲染 delta。
- 确定性：固定种子（默认 20261121），自身 `RandomNumberGenerator`，所有容器按插入顺序遍历，无全局 `shuffle`。
- 渲染：GL Compatibility，1280×720，`stretch=canvas_items`，垂直同步关闭。

## 3. 行为公式

记单位位置 `p`、速度 `v`、最大速度 `vmax`、最大转向力 `Fmax`、邻域半径 `R`。
所有行为输出“转向力”（速度量纲），最终再乘权重并限幅。

### 3.1 个体行为

| 行为 | 公式 / 实现 |
| --- | --- |
| **Seek** | `desired = normalize(target − p) · vmax`；`f = desired − v` |
| **Flee** | `d = p − threat`；若 `|d| < R_flee(300)`：`f = (normalize(d)·vmax − v) · (1 − 0.45·|d|/300)` |
| **Arrive** | `dist = |target − p|`；`speed = vmax · clamp(dist/120, 0, 1)`；`f = normalize(target−p)·speed − v`；`dist < 4` 时 `f = −1.5v` |
| **Pursue** | `look = clamp(dist/vmax, 0, 1.2)`；`predicted = target.p + target.v·look`；对 predicted 做 Seek；`dist < 38` 改 Arrive |
| **Evade** | `look = clamp(dist/vmax, 0, 1.0)`；对 `threat.p + threat.v·look` 做 Flee（半径 330） |
| **Wander** | `θ += U(−1,1)·2.6·dt`；`target = p + heading·70 + dir(θ)·42`；对 target 做 Seek |

追逐模式下：
- 猎物只取 `flee / evade / wander / separation / avoidance`；
- 追捕者只取 `pursue / separation / alignment / avoidance`；
- 无猎物时，boid 的 flee/evade 以“最近邻居”为威胁，pursue 以最近邻居为目标（方便单独做行为实验）。

### 3.2 群体行为

| 行为 | 公式 / 实现 |
| --- | --- |
| **Separation** | 取缓存邻居前 6 个：`push = Σ (p−p_j)/max(d²,0.01)`；`desired = normalize(push)·vmax`；`f = desired − v`。1/d² 权重，近邻更强；每 2 步重算一次。 |
| **Alignment** | 最多 8 个邻居：`avg_v = Σv_j`；`f = normalize(avg_v)·vmax − v` |
| **Cohesion** | 最多 8 个邻居：`c = mean(p_j)`；对 c 做 Seek |
| **Leader（队列）** | i>0：`target = p_{i−1} − heading_{i−1}·46`；对 target 做 Arrive。0 号按主行为行动。 |

### 3.3 流场跟随

1. `flow_field.gd` 以目标格为源做 **8 邻域 BFS**，记录距离场与“指向父格”的单位方向。
2. 对角扩展要求两侧正交格均可通行，避免贴角穿墙。
3. 单位每步在格点采样方向 `d`；若所在格被占（极少），向外找最近可通行格。
4. `Flow` 力：
   - `dist = |goal − p|`
   - `speed = vmax · clamp(dist/120, 0.12, 1)`（近目标减速）
   - `f = d · speed − v`
   - `dist < 26`：`f = −1.5v`（制动）

流场在预设切换、双击设目标时重建；静态障碍不会移动。

### 3.4 边界

可行走区边界内侧 90px 施加朝内的期望速度；最终位置做硬夹取。边界不属于“静态障碍穿透”统计，但保证永不越界。

## 4. 力合成与积分

```text
for each agent:
    F = Σ_i w_i · f_i                       # 行为权重
    if avoidance imminent:
        F += 0.7 · Fmax · normalize(f_avoid)   # 避障优先级
    F = clamp_length(F, Fmax)               # 限力
    v += F · dt
    v = clamp_length(v, vmax)               # 限速
    p += v · dt
    resolve_static_collisions(p, v)         # 硬矫正 + 去除法向速度
```

- 权重 0–3，默认见 README；权重为 0 或行为关闭则不参与。
- 记录每个行为的加权分力（仅选中单位），用最大分力确定“主导行为”颜色。
- 避障“临近”定义为任一射线命中且 `t < 0.45`，或近场排斥强度超过阈值；此时叠加额外 0.7·Fmax 的避障力，确保避障压过路径吸引。
- 积分在固定 1/60 s 下进行；速度/位置都检查有限性，异常时重置到场地中心并计数。

## 5. 三须局部避障

### 5.1 探测

- 三根胡须：航向 ±0.55 rad（±31.5°）与正前；长度 `look = clamp(30 + 0.7·|v|, 56, 110)`，与速度正相关。
- **宽相位**：每步只把“最近点距离 ≤ look”的矩形/圆加入候选，之后三根射线只测试候选集。
- **矩形**：slab 法求线段与 AABB 的首个交点，得到 t 与入射面法线；起点在矩形内时取最近面的外法线。
- **圆**：解 `|o + d·t|² = r²` 的二次方程，取最近正根；法线为圆心指向交点。
- 取三根中最近交点（t 最小）。

### 5.2 避障力

对每根命中的胡须：

```text
proximity = 1 − t
weight    = 0.55（侧须） / 0.95（中须）
tangent   = 法线逆时针 90°，若与射线方向点乘 < 0 则取反（沿墙滑行的“动力”）
repel     = normal · (1.2 + 2.0·proximity)      # 斥力
drive     = tangent · (0.55 + 0.8·proximity)    # 动力
F_avoid  += (repel + drive) · weight · (0.4 + proximity)
```

另外有近场排斥（`margin = radius + 26`），对矩形/圆做朝外推力；它同时用于“即将碰撞”的判定。
与视频一致：斥力随交点靠近而增大；动力方向沿障碍切向，保证单位不“撞停”而是沿墙滑行。

### 5.3 性能策略

- 避障每 2 步重算一次；上一帧有命中的“热”单位每步都算，避免贴墙时迟钝。
- 选中单位的射线记录保留供可视化；非选中单位不建射线记录，减少分配。
- 硬碰撞矫正独立于转向力：任何一帧结束后都保证圆心到静态障碍的距离 ≥ 半径。

## 6. 空间哈希与邻域

- 网格边长 = 邻域半径（默认 56px），3×3 桶查询。
- 邻域每 8 步刷新一次；单位 8 步内最大位移约 20px，远小于半径，视觉无差。
- 扫描上限 24 个候选、最多保留 10 个邻居；Separation 只用前 6 个，Alignment/Cohesion 最多 8 个。
- 只在刷新步重建哈希，其余步复用邻域缓存；避免每帧对稠密人群做全量邻域扫描。
- 所有列表按插入顺序使用，保证同种子同结果。

## 7. 静态碰撞

- 宽相位：矩形按 `grow(radius + 4)` 判断，圆按 `radius + r + 4` 判断；不靠近则只做边界夹取。
- 窄相位：对每个矩形求最近点；若距离 < 半径，沿最近点法线推到半径位置；若圆心进入矩形内部，沿最近的面推出。圆同理。
- 最多 2 轮，第一轮无位移则提前结束。
- 去除朝障碍内部的速度分量（`v -= n·min(0, v·n)`），避免下一帧继续“顶墙”。
- 冒烟测试逐帧检查 `distance < radius − 0.6` 即记穿墙；最终 6300 帧全部为 0。

## 8. 渲染与性能

- 单位本体：**3 个 MultiMeshInstance2D**（boid 粉 / 猎物橙 / 追捕者蓝），每实例一张 64×64 程序化贴图（圆体 + 深色描边 + 航向箭头）。每个单位每帧只更新一个 2D 变换。
- 主导行为环：12 个 MultiMeshInstance2D（每个主导行为一色），环形贴图；每帧只更新 visible_instance_count 与实例变换。
- 选中环：单独一个 MultiMesh，白色。
- 流场箭头：一个 `draw_multiline`（约 180 支箭头，每 4 格一支）。
- 其它：背景网格一个 multiline、障碍 8–10 个多边形/圆、目标区约 10 个图元、选中单位的调试线约 10–20 条。
- 实测 200 体约 **53 draw calls / 5900 primitives**；MultiMesh 批处理把渲染从“每单位 6 次 draw”降为“每角色 1 次”。
- 物理螺旋防护：`physics/common/max_physics_steps_per_frame=1`，当单步超过 16.6ms 时不再叠加多个物理步；主场景 200 体仍保持 33.4fps（模拟时间可能略慢于实时）。电影巡演临时设为 2 步以保证 60Hz 录制。

## 9. 复杂度

设单位数 N、静态障碍数 S（本 Demo ≤ 8）、每步候选障碍数 K（通常 0–2）、邻域上限 C=10。

| 阶段 | 复杂度 | 说明 |
| --- | --- | --- |
| 邻域刷新（每 8 步） | O(N·24) | 哈希 3×3 桶 + 距离判断；均摊 O(3N) |
| Separation | O(6N) | 每 2 步重算 |
| Alignment/Cohesion | O(8N) | 仅启用时 |
| Avoidance | O(N·3·K)（热单位每步，其余每 2 步） | K 由宽相位限制 |
| 碰撞矫正 | O(N·S) | 宽相位后通常只做边界夹取 |
| 绘制 | O(N) 实例更新 + 固定条带 | MultiMesh |

实测 100 体单步 7.3ms、200 体 15.2ms（headless，含全部渲染无关逻辑；本机 Intel HD 6000）。
当 N 增大时开销近似线性；主要常数来自 GDScript 的对象属性访问与射线数学。

## 10. 与参考视频的差异

1. **形态**：视频 1:15 后的实际演示是 2D 俯视 + 流场箭头 + C 形障碍 + 粉色圆单位；本 Demo 采用同一视觉语言，但场景/UI/贴图/代码全部原创。
2. **行为范围**：视频实际动画演示 Seek、Separation、Avoidance 与组合流场；其余行为只出现在清单。本 Demo 也实现并开放了 Flee/Arrive/Pursue/Evade/Wander/Alignment/Cohesion/Leader，便于做行为实验；并用“追逐 / 走廊拥堵 / 羊群”预置展示。
3. **寻路**：视频用流场 + steering；本 Demo 的流场用 BFS（非 Dijkstra 代价场），并将“路径跟随”实现为流场跟随（视频未给出显式 waypoint 路径）。
4. **避障**：视频以三射线图解矩形/圆障碍；本 Demo 用宽相位 + 精确 slab/二次方程求交，且为性能采用分步重算与近场硬矫正。
5. **完成判定**：视频演示中单位在目标点附近聚成一团；本 Demo 用 160px 目标区统计“到达”，否则分离力会让大群无法全部进入 30px 内。目标区在画面中以细环标出。
6. **性能取舍**：视频为少量单位；本 Demo 支持 300 体，并为 200 体设置了物理追赶上限与邻域/避障分步缓存。
7. **UI**：视频是幻灯片 + 少量演示；本 Demo 的中文控制台为原创，用于实时调参与可视化。

## 11. 验收证据

- `STEERING_SMOKE_OK`：0 穿墙帧、0 NaN、限速通过、同种子一致；详见 README。
- 真实 GPU：50/100/200 体 = 73.5 / 45.9 / 33.4 FPS（1280×720，vsync off）。
- 截图：`docs/screenshots/01–06`（1920×1080）。
- 视频：`docs/media/steering_tour_10s.mp4`（10.000s，1280×720，30fps）与 GIF。
- 全部命令与日志见 README 与 `docs/迭代记录.md`。
