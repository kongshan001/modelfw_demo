# 技术说明 · Flow Field 流场寻路

> 任务：T-20261121-009（续 T-20261121-008）
> 引擎：Godot 4.6 / GDScript / GL Compatibility
> 参考：B 站 BV12bzZY2EfA（仅算法与视觉研究，不含素材复用）

## 1. 分层

```
输入 / UI      main.gd ── flow_ui.gd
                    │
                    ▼
模拟           flow_sim.gd（固定 30Hz）── 空间哈希 / 分离 / 碰撞 / 重生
                    │
                    ▼
场数据         flow_field_grid.gd（纯 RefCounted）
               cost[] → integration[] → flow[]
                    │
                    ▼
渲染           flow_view.gd（三视图、箭头、MultiMesh、拖尾、目标脉冲）
```

- `flow_field_grid.gd` 不依赖节点，可被 headless 工具直接实例化。
- `flow_sim.gd` 继承 `Node`，`_physics_process` 以 30Hz 调用 `step_fixed(FIXED_DT)`；渲染帧用 `render_alpha()` 在上一逻辑位置与当前位置之间插值。
- `flow_view.gd` 的父节点画网格/数值/箭头；三个子层依次为拖尾、智能体光晕、智能体核心；最上层 `Overlay` 画目标脉冲与悬停框。

## 2. 代价场与积分场

### 2.1 数据结构

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `cost[i]` | PackedInt32Array | `0` 障碍，`1` 可走 |
| `integration[i]` | PackedInt32Array | 到最近目标的 BFS 步数，`INF = 1<<30` |
| `flow[i]` | PackedVector2Array | 指向积分值更小邻格的单位向量 |
| `goals` | Array[Vector2i] | 多目标（≤8） |

固定邻域顺序（同时用于 BFS 与流场平局裁决）：

```
k:    0     1     2     3     4      5      6      7
dx:  +1     0     0    -1   +1     +1     -1     -1
dy:   0    -1    +1     0   -1     +1     -1     +1
```

### 2.2 多源 BFS

目标格先入队，`integration = 0`；逐层弹出，8 邻接 `+1`。对角移动（`k >= 4`）要求 `(x+dx, y)` 与 `(x, y+dy)` 两个正交格都可走，否则跳过——这条规则就是“禁斜穿墙角”。

伪代码：

```
queue = goals
while queue not empty:
    p = pop_front()
    for k in 0..7:
        n = p + offset[k]
        if n out of bounds or blocked or visited: continue
        if diagonal(k) and (blocked(p.x+n.x, p.y) or blocked(p.x, p.y+n.y)): continue
        integration[n] = integration[p] + 1
        push_back(n)
```

可达格数 `reachable_cells = queue.size()`，与独立 BFS 的可达集合严格一致（见 smoke 测试）。

### 2.3 流场

对每个可达非目标格，遍历 8 邻域，选出积分值最小的可走邻格；同样应用斜穿墙角规则。若最小邻格值严格小于当前格，写入该方向的单位向量；目标格、障碍格、不可达格保持零向量。

性质：均匀步长 BFS 下，每个可达非目标格必有一个“父格”满足 `integration[parent] = integration[self] - 1`，因此流场在格级别严格单调递减。smoke 测试逐格验证了这一点。

### 2.4 双线性采样

单位位置通常落在格内而不是格心。取所在格四角的流向量，按面积权重混合：

```
w00 = (1-fx)(1-fy)   w10 = fx(1-fy)
w01 = (1-fx)fy       w11 = fx·fy
dir = normalize(Σ flow[corner] * w)
```

四角都不可用时退回单位所在格流向量。这样单位转弯不会在格边界突然折向。

## 3. 群体模拟（30Hz）

### 3.1 积分

每个逻辑步：

```
desired = sampled_flow * speed * speed_scale[i]
accel   = (desired - velocity) * 5.0
accel  += separation * speed * 2.8
accel  += wall_soft_push * speed * 3.2
clamp(accel, max_force = speed * 8)
velocity += accel * dt
clamp(velocity, own_speed)
position += velocity * dt
```

- `speed_scale` 在 `[0.86, 1.14]` 内由固定种子生成，避免整齐划一。
- 分离力：`radius * 2.3` 内的邻居成对累加，每对只算一次；零距离时用确定性的角度散开。
- 障碍软斥力：只对邻墙格（`near_wall` 标记）计算，按最近点距离线性衰减。

### 3.2 空间哈希

分离哈希格边长 `agent_radius * 2.3`，每个单位插入单链表。遍历时只检查“自身 + 右三格 + 下格”五种偏移，保证每对只处理一次。1000 智能体时约 3.0 ms/步。

### 3.3 碰撞

- 单位视为圆，半径 `cell * 0.17`（夹在 2.6–7 px）。
- 非邻墙格只做边界夹紧；邻墙格才做“圆 vs 矩形”精确推出，最多迭代 3 次。
- 中心落入障碍内部时，按最近边推出，避免 `d = 0` 除零。

### 3.4 到达与重生

到达半径 `0.8 * cell`。到达后从距目标积分值 ≥12 的格中随机重生，带 0.18 秒淡入，避免目标附近无限堆积。

### 3.5 可复现性

- 所有随机性来自 `RandomNumberGenerator`，种子固定。
- 哈希桶、邻域、目标列表遍历顺序固定。
- 逻辑不使用 wall-clock；`Time.get_ticks_usec()` 只用于统计，不参与决策。
- smoke：同地图同目标两次重建的 `integration`/`flow` 逐位相等；两套 300 智能体模拟 90 步位置偏差 0。

## 4. 渲染

### 4.1 三视图

| 视图 | 底色 | 数值 | 箭头 |
| --- | --- | --- | --- |
| 代价场 | 深青平地 + 棋盘微差 | 可走格显示 `1` | 关 |
| 积分场 | 青→蓝→紫→粉热力色 | 显示 BFS 步数，不可达 `×` | 关（可手动开） |
| 流场 | 低饱和热力色 | 关 | 青色 8 方向箭头 |

障碍为深青色 + 斜线纹理；目标为青色脉冲圈；智能体为粉色光晕 + 暖白核心；拖尾为半透明粉色折线。

### 4.2 智能体批量绘制

`MultiMeshInstance2D` + `MultiMesh.TRANSFORM_2D`，每个单位更新一次变换和颜色。必须在 MultiMesh 上设置 `mesh = QuadMesh(64×64)`，否则 GLES3 会报 `mesh.is_null()` 且不绘制——这是 T-009 修复的关键问题之一。

### 4.3 拖尾性能

拖尾用 `draw_multiline` 批量画线段。1000 智能体 × 5 段 = 5000 段，开启抗锯齿时在 Intel HD 上会把帧率压到约 20 fps。最终策略：

- 关闭抗锯齿（1.1 px 线宽下视觉差异很小）。
- 群数 >700 时每 2 个智能体只画 1 条拖尾，拖尾刷新降到 10Hz。
- 方向/分离缓存同样在 >700 时降到 10Hz，移动仍 30Hz。

### 4.4 绘制层修正

`_draw_trails` / `_draw_overlay` 由子节点的 `draw` 信号触发，必须在**子节点**的 CanvasItem 上调用 `draw_*`。T-008 版本在 `FlowFieldView` 上调用，触发 “Drawing is only allowed inside this node's `_draw()`” 并刷屏。T-009 改为：

```gdscript
_trail_layer.draw.connect(_draw_trails.bind(_trail_layer))
_overlay_layer.draw.connect(_draw_overlay.bind(_overlay_layer))
```

绘制函数接收 `CanvasItem` 参数并在其上绘制；同时删除了未被使用、且引用不存在方法的两个旧层脚本。

## 5. 测试与工具

### 5.1 `tools/smoke_flowfield.gd`

headless 运行，覆盖：

1. 样例地图积分场有限值 vs 独立 BFS 可达性（835 格）。
2. 随机大地图可达性一致。
3. 斜穿墙角禁止（构造只有对角通道的 3×3 地图）。
4. 流场单调 + 流向无斜穿墙角 + 目标格零向量。
5. 画笔 / 擦除 / 清障 / 放置目标 / 多目标增删。
6. 500 智能体 180 步：无 NaN、无穿墙、群体位移、到达重生、逻辑步长 <33.3 ms。
7. 可复现性：积分场/流场逐位相同，300 智能体 90 步位置偏差 <0.001 px。

成功最后一行：`FLOWFIELD_SMOKE_OK`。

### 5.2 `tools/bench_flowfield.gd` / `tools/bench_ablation.gd`

- `bench_flowfield.gd`：加载主场景，关闭垂直同步，分别设置 200/500/1000 智能体；每档 60 帧预热 + 180 帧采样，输出平均 FPS、最差帧、逻辑步长、逻辑预算占比。
- `bench_ablation.gd`（T-011）：把三项优化拆成独立开关，做 8 配置 × 5 轮消融；1000 为主、500 对照；1280 真实窗口 + 1920 离屏 SubViewport；输出 CSV/JSON、P50/P95/P99、worst、hitch、引擎计数、负载/热日志。汇总与对比图见 `docs/perf/REPORT.md`、`docs/perf/ablation_chart.png`；一键复测入口 `tools/run_ablation.sh`，Markdown 汇总 `tools/summarize_ablation.py`。

### 5.3 `tools/capture_flowfield.gd`

- 使用 1920×1080 的 `SubViewport`，`size_2d_override = 1280×720`，等价于项目的 `canvas_items` 拉伸，输出真正的 1920×1080 图。
- 手动步进（`manual_step`），保证截图/视频逐帧确定。
- 输出 5 张 `docs/screenshots/*.png` 与 300 张 `capture_frames/frame_*.png`；后者被 `.gitignore` 排除，由 ffmpeg 编码为 10 秒 30fps MP4。

## 6. 性能记录

环境：macOS，Godot 4.6 GL Compatibility，Intel HD 集显，1280×720 逻辑分辨率，垂直同步关闭。

| 智能体 | 平均 FPS | 最差帧 | 逻辑步长 | 逻辑预算 |
| --- | ---: | ---: | ---: | ---: |
| 200 | 65.0 | 25.2 ms | 2.85 ms | 9% |
| 500 | 49.0 | 34.4 ms | 7.15 ms | 21% |
| 1000 | 47.0 | 45.1 ms | 7.89 ms | 24% |

> 帧率存在 ±5 fps 的机器负载波动；验收要求为平均值 ≥30。优化前 1000 智能体基线约 19.7 fps（拖尾抗锯齿为主要瓶颈）。

### 6.1 审计级复测（T-20261121-011）

详见 [`docs/perf/REPORT.md`](perf/REPORT.md)。同机 5 轮 × 300 帧、seed 421 / medium / 1000 智能体；复测期间外部负载 load1 5.2–24.7（中位 9.3）、swap 约 4.5 GB，因此绝对值低于上表，**不要与 T-009 的单次 47.0 直接对比**：

| 配置（1000） | 1280×720 中位 FPS [范围] | P95 中位 | 1920×1080 中位 FPS [范围] |
| --- | ---: | ---: | ---: |
| 初版（AA on / 15Hz / 全拖尾） | 11.0 [9.5–12.7] | 145.4 ms | 8.6 [4.7–10.2] |
| 默认（AA off / 10Hz / 半采样） | 26.4 [17.0–32.2] | 57.9 ms | 16.8 [13.7–23.4] |

同轮归一（抵消跨轮负载漂移）：关 AA 1.65×、半采样 1.25×、10Hz 1.13×（1080：1.46× / 1.35× / 1.22×）；全开 2.17×（两档一致）。500 档验证半采样/10Hz 的 >700 阈值不生效。图层归因显示默认配置下箭头层是最大渲染项（隐藏 +27.5 FPS），优化后的拖尾层已接近免费；箭头优化属视觉变更，本轮未做。

## 7. 已知限制 / 后续

- BFS 为均匀代价；加权地形需改 Dijkstra（需优先队列），流场输出接口不变。
- 重建是整场 O(N)，编辑大图时有 6–14 ms 峰值；可做增量 BFS。
- 拖尾没有做时间衰减颜色，只是固定透明度。
- UI 为 1280×720 逻辑布局，窗口更窄时依赖 `keep` 拉伸；未做 4:3 自适应重排。
