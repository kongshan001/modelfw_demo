# Flow Field 技术原理与工程实践

> 报告：T-20261121-012（线程 T-20261121-009，性能数据依赖 T-20261121-011）
> 日期：2026-11-21 · 引擎：Godot 4.6 / GDScript / GL Compatibility
> 范围：WFC、Steering、Flow Field 三套算法 Demo 的原理、选型、性能与跨引擎移植
> 约束：本轮只读代码与文档，不改游戏代码/资产；性能数字除特别标注外均来自 T-011 的 5 轮审计数据

**证据标记**：`[公开]` 官方文档或公开算法资料；`[实测]` 本项目 CSV/日志/冒烟测试；`[推断]` 由实现与计数推导，未直接测量。

---

## 0. 结论先行（一页）

### 0.1 一句话

**WFC 负责“生成世界”，Flow Field 负责“给一大群单位一条共同的路”，Steering 负责“让每个单位在路上不撞人、不撞墙、转弯自然”。** 三者不是互相替代，而是一条流水线：**生成地图 → 全局路径场 → 局部避让**。

### 0.2 三算法一张表

| 维度 | WFC（坍缩花园） | Steering（转向行为实验场） | Flow Field（流场寻路） |
| --- | --- | --- | --- |
| 解决什么问题 | 生成满足局部约束的合法地图/内容 | 让单个或少量单位实时转向、避障、成群 | 让大量单位共享一条到最近目标的最短路 |
| 核心原理 | 候选叠加 + Shannon 熵 + 加权坍缩 + 约束传播 + 快照回溯 | 期望速度 − 当前速度 = 转向力；分离/对齐/聚合；三须局部避障 | 目标多源 BFS 积分场 + 最陡下降流场 + 双线性采样 |
| 计算粒度 | 每步扫描全图格子的候选与熵 | 每个单位每步累加行为力 | 建场每格 O(8)；之后每个单位每步 O(1) 采样 |
| 复杂度 | 每步 O(N·T)；快照 O(S·N)；最坏指数回溯（有预算） | O(N·C + N·3·K)；C 为邻居上限，K 为宽相位候选 | 建场 O(V + E)，E ≤ 8V；更新 O(N)；渲染 O(N) |
| 适用场景 | 关卡片段、庭院、程序化地图、离线内容 | 少到中等单位、动态目标、追逐、群体感、局部避让 | RTS/塔防/大规模同目标寻路、迷宫绕行 |
| 动态障碍 | 不适用；改约束后重新生成 | 支持，局部感知与避让 | 支持，但当前实现为整场重建 |
| 可复现性 | 固定种子，含回溯与重开路径 | 固定种子 + 固定遍历顺序 | 积分场/流场逐位相同；同种子位置偏差 0.000000 px |
| 主要失败模式 | 矛盾、回溯预算耗尽、重开上限 | 局部极小、振荡、参数敏感、拥挤死锁 | 目标不可达、重建卡顿、瓶颈拥堵、斜穿墙角规则写错 |
| 当前性能结论 | 算法视图 42.6 FPS / 成品地图 73.8 FPS（16×10，本机另一会话） | 200 体 33.4 FPS；200 体单步 15.2 ms（本机另一会话） | T-011 默认 1000 体：26.4 FPS @720 / 16.8 FPS @1080（高负载环境） |

> WFC 与 Steering 的绝对 FPS 来自各自任务会话，**不能与 Flow Field 的 T-011 数值横向比较**；这里只用来回答“当前是否可跑、瓶颈在哪”。Flow Field 的因果结论一律以 T-011 的同轮归一与引擎计数为准。

### 0.3 Flow Field 五个关键结论

1. **反向建场是扩展性的根源**：BFS 从所有目标出发，一次 $O(V)$ 得到全图到最近目标的距离；$N$ 个单位共享同一张场，而不是每个单位各跑一次 A*。这是 1000 单位仍能跑起来的前提。`[实测+推断]`
2. **单调性可证明**：均匀步长 BFS 下，每个可达非目标格都存在一个积分值恰好小 1 的父格；流场指向积分更小的邻格，因此不会成环，沿场最多走 `integration` 步到达目标。smoke 逐格验证坏格为 0。`[实测]`
3. **8 邻接必须禁斜穿墙角**：对角移动要求两侧正交格都可走，否则单位会从两个障碍的角缝“切”过去。这条规则同时用于 BFS 和流场选择。`[实测]`
4. **动态编辑是整场重建**：中图 36×24 重建约 6–14 ms（T-011 高负载下中位 11.6–18.1 ms，含近墙表与重生格重建）。当前地图规模全量重建足够；大图或高频改动才需要增量 BFS。`[实测]`
5. **瓶颈不在寻路，而在渲染**：T-011 默认配置下，隐藏箭头层 +27.5 FPS（26.9→54.4），箭头约 45,036 primitives；拖尾三项优化同轮 2.17×，优化后拖尾层已接近免费。`[实测]`

### 0.4 性能结论（T-011，1000 智能体）

| 分辨率 | 初版 B：AA on / 15Hz / 全拖尾 | 默认 ALL：AA off / 10Hz / 半采样 | 同轮归一 | P95 帧时间 |
| --- | ---: | ---: | ---: | ---: |
| 1280×720 | 11.0 FPS [9.5–12.7] | **26.4 FPS** [17.0–32.2] | **2.17×** [1.37–3.02] | 145.4 → **57.9 ms** |
| 1920×1080 | 8.6 FPS [4.7–10.2] | **16.8 FPS** [13.7–23.4] | **2.17×** [1.55–2.93] | 181.1 → **129.2 ms** |

- **单因排序**：关拖尾 AA（同轮 1.65×/1.46×）> 拖尾半采样（1.25×/1.35×）> 大群 10Hz（1.13×/1.22×）。
- **10Hz 买的是 CPU 余量**：逻辑步长中位 18.28→16.17 ms（720）、22.84→16.92 ms（1080），预算 55%→48% / 68%→51%；逻辑预算下降，但帧渲染受限时 FPS 只小幅提升。
- **平均 FPS 不等于流畅**：1280 ALL 合并 1500 帧仍有 56% 的帧 >33.3 ms、26% >50 ms；1080 为 74% / 48%。worst frame 达 218.1 / 428.7 ms，其中包含 OS 级 0.5–1.5 s 停顿。
- **绝对数不可跨环境比较**：T-011 复测期间 load1 5.23–24.68（中位 9.34），swap 已用约 4.3–4.5 GB。T-009 的 47.0 FPS 是较空机器上的单次采样，不能与 26.4 直接对比；同轮归一与引擎计数才是可复现证据。

### 0.5 怎么读这份报告

- 只想选型：读 §2.4–§2.6。
- 想理解 Flow Field：读 §3.2–§3.7。
- 想复现性能结论：读 §4 与 §5，再跑 §7.3 的命令。
- 想移植到 Unity/Unreal/Three.js：直接读 §6，并取走 `docs/portable/flowfield_params.json`、`flowfield_sample_medium.json`、`manifest.json`。

---

## 1. 范围、口径与证据

### 1.1 本报告回答什么

1. 三套算法各自解决什么问题、核心原理、复杂度、适用场景与当前性能。
2. Flow Field 从代价场到积分场、流场、采样、移动、渲染的完整链路，对应到实际代码位置。
3. 用 T-011 的消融矩阵解释“为什么某项优化有效”，把机制、成本与验收串成因果链。
4. 一套可复用的性能审计方法与回归门禁。
5. 一套跨引擎的数据协议、算法契约、渲染映射与工具链映射。

**不回答**：GPU 硬件时间戳分解（本机 GL Compatibility 不可得）、其他地图/阵容的绝对 FPS、商业项目容量规划。

### 1.2 证据分级与数据来源

| 级别 | 含义 | 本报告中的例子 |
| --- | --- | --- |
| `[公开]` | 官方文档、论文、公开算法资料 | BFS/Dijkstra 定义、Godot MultiMesh 文档、Reynolds 转向行为 |
| `[实测]` | 本仓库工具输出或已归档 CSV/日志 | T-011 的 FPS/P95/hitch/objects/primitives；smoke 的 835 可达格；WFC/Steering 的 FPS |
| `[推断]` | 由实现与计数推导，未直接测量 | “AA 把线段展开为屏空间图元”的机制解释；500→1000 变平的构成分析 |

### 1.3 性能口径（重要）

- **Flow Field 主性能数据只来自 T-011**：`godot-flowfield/docs/perf/ablation_1280x720.csv`、`ablation_1920x1080.csv`、`runs_raw.json`、`REPORT.md`。
- **WFC/Steering 数据来自各自 TECH/迭代记录**，标注“本机另一会话”，只用于说明可运行性与瓶颈，不与 Flow Field 混表。
- 所有绝对 FPS 都带有环境条件（分辨率、vsync、load1、swap、窗口焦点）。**跨会话、跨机器、跨负载的绝对 FPS 不可直接相除或排名。**
- 本报告不编造数字；表中每个数都能在对应 CSV/REPORT/文档中找到。无法从 T-011 得到的量（如 GPU ms）明确写“不可得”。

---

## 2. 总览与选型

### 2.1 WFC：约束满足的地图生成

**问题**：给定一套瓦片与边接口规则，生成一张处处合法的地图。它不是“找路”，而是“在组合空间里找一个满足所有局部约束的解”。

**核心原理**（`godot-wfc/docs/TECH.md`）：

1. 每个格子保存一个候选位掩码 `mask`，第 `t` 位表示瓦片 `t` 仍可能。
2. 用 Shannon 熵衡量不确定性：

$$H(\text{mask}) = \ln W - \frac{\sum_t w_t \ln w_t}{W}, \quad W = \sum_t w_t$$

3. 每次选择候选数 >1 且熵最小的格，按权重抽一个瓦片坍缩。
4. 用栈把邻接约束传播出去；某个邻格候选被削到 0 即矛盾。
5. 矛盾时弹出最近快照，剔除该次选择，继续尝试；超过预算则用同一基础种子确定性重开。

**复杂度**：设格子数 $N$、瓦片数 $T$、坍缩/回溯步数 $S$。初始化 $O(NT)$；每步选最低熵格 $O(NT)$；传播通常远小于 $O(NT)$；快照最坏 $O(SN)$ 内存。最坏情况仍可能指数回溯，工程上用 `BACKTRACK_BUDGET = 48` + `MAX_RESTARTS = 48` 把病态种子变成有限时间的确定性重试。

**当前性能** `[实测，godot-wfc 会话]`：默认 16×10 / 20 步每秒，算法视图 avg 42.6 / min 38 FPS，成品地图 avg 73.8 / min 46 FPS；第一版把候选几何直接画在 CanvasItem 上时只有 8–9 FPS，改为 1024×1024 图集 + 掩码拼贴缓存后初始静态画面提升到 62+ FPS。瓶颈是**候选的绘制提交量**，不是求解器本身。

**失败模式**：约束本身无解（再怎么回溯也失败）、回溯预算耗尽、重开上限耗尽；边约束 WFC 不保证道路连通性或可玩性，需要后处理。

### 2.2 Steering：局部力场与群体行为

**问题**：单位没有全局路径时，如何根据当前位置、速度、邻居和前方障碍，实时算出“下一秒往哪走、走多快”。

**核心原理**（`godot-steering/docs/TECH.md`）：

```text
desired = normalize(target - p) * vmax        # Seek 的期望速度
force   = desired - v                          # 转向力 = 期望速度 − 当前速度
F       = Σ w_i · f_i                          # 多行为加权
F      += 0.7 · Fmax · normalize(F_avoid)      # 避障优先
F       = clamp_length(F, Fmax)                # 限力
v      += F · dt; v = clamp_length(v, vmax)    # 积分/限速
p      += v · dt; resolve_collisions(p, v)     # 位置与硬碰撞
```

- 个体行为：Seek、Flee、Arrive、Pursue、Evade、Wander。
- 群体行为：Separation（1/d² 权重）、Alignment、Cohesion、Leader Following。
- 局部避障：三根前向“胡须”射线（±31.5° 与正前），矩形用 slab 法、圆用二次方程求最近交点；斥力沿法线，动力沿切向，避免“撞停”。
- 性能策略：宽相位候选过滤、邻域每 8 步刷新、避障非热单位每 2 步重算、3 个 MultiMesh 按角色批量绘制。

**复杂度**：O(N·C + N·3·K)；C 为邻居上限（10），K 为宽相位候选（通常 0–2）。实测 100 体单步 7.3 ms、200 体 15.2 ms（headless）；真实 GPU 50/100/200 体 = 73.5/45.9/33.4 FPS `[实测，godot-steering 会话]`。

**失败模式**：**没有全局路径**，遇到 C 形回廊这类局部极小会贴着障碍打转；大量单位互相挤压时分离力与目标吸引力可能抵消，出现振荡或“拥堵死锁”；行为权重对场景敏感，换一张地图就要重调。这正是它需要与 Flow Field 组合的原因。

### 2.3 Flow Field：共享的全局向量场

**问题**：大量单位要去同一个（或同一组）目标，如何避免为每个单位单独寻路，又能让它们自然绕开静态障碍。

**核心原理**：

1. 从**所有目标**出发做多源 BFS，得到每个可走格到最近目标的步数（积分场）。
2. 每个非目标格选择积分值最小的邻格，写入单位方向（流场）。
3. 单位在任意位置对四角流向量做双线性插值，得到平滑的期望方向。
4. 期望速度与当前速度之差产生加速度；叠加分离力、障碍软斥力；限力、限速、积分位置；硬碰撞兜底。

**复杂度**：建场 O(V + E)，V = cols×rows，E ≤ 8V；之后每单位每步 O(1) 采样 + O(1) 邻居查询（分离用空间哈希，均摊 O(1)）。1000 体不需要 1000 次寻路。

### 2.4 三者对比

| 维度 | WFC | Steering | Flow Field |
| --- | --- | --- | --- |
| **输入** | 瓦片集、边接口、权重、尺寸、种子 | 单位位置/速度、邻居、障碍、目标/威胁 | 可走格、目标格、单位位置 |
| **输出** | 完整瓦片地图 | 每单位速度/加速度/位置 | 每格方向向量 + 单位运动 |
| **计算时机** | 生成期一次；交互版可按步推进 | 每逻辑 tick（本 Demo 60Hz） | 地图/目标变化时重建；每 tick 采样与移动（本 Demo 30Hz） |
| **群体规模** | 不适用（网格 N） | 本机 200 体 33.4 FPS；300 体上限 | 本机 1000 体（上限 1200） |
| **动态障碍** | 不适用；可重新生成 | 支持局部避让，无需全局重建 | 支持，但当前为整场重建；小改动可批处理/节流 |
| **全局最优性** | 约束满足，不追求“最优” | 无全局路径，易局部极小 | 到最近目标的 BFS 最短路（均匀代价）；加权需 Dijkstra |
| **可复现性** | 固定种子，含回溯/重开序列 | 固定种子 + 固定遍历 | 场逐位相同；同种子位置偏差 0.000000 px |
| **失败模式** | 矛盾无解、预算耗尽、重开上限 | 局部极小、振荡、参数敏感、拥堵死锁 | 目标不可达、重建卡顿、瓶颈拥堵、斜穿墙角 |
| **主要成本** | 候选绘制提交量（已用图集/拼贴缓存解决） | GDScript 每单位力计算与射线 | 拖尾 AA 填充、箭头图元、逻辑缓存刷新 |
| **本仓库证据** | `godot-wfc/docs/TECH.md` §7–§9 | `godot-steering/docs/TECH.md` §5–§9 | 本报告 §3–§4；`docs/perf/REPORT.md` |

### 2.5 何时用哪个

**选 WFC**：

- 需要“生成”而不是“移动”：关卡布局、庭院、地牢房间、程序化装饰。
- 约束是局部的、可枚举的（边接口、邻接规则）。
- 可以接受回溯/重开，或内容在加载期生成。

**选 Steering**：

- 单位数量少到中等（几十到几百），目标会移动，或需要追逐/逃离/编队/群体感。
- 障碍是局部的、动态的，且不需要全局最优路径。
- 需要平滑转弯、避让、到达减速、单位间挤压感。

**选 Flow Field**：

- 大量单位共享一个或少数几个目标（RTS 集团移动、塔防、撤离、人群）。
- 地图以静态障碍为主，或允许在编辑后重建。
- 需要确定性的全局绕行，不想让每个单位各跑 A*。

**一个粗略的规模判据**（`[推断]`，不是实测）：若地图重建不频繁、单位数 $N$ 与格数 $V$ 同量级或更大、且目标高度一致，Flow Field 的“一次建场、多次复用”更划算；若 $N$ 很小且目标各自不同，逐单位 A* + Steering 更简单。

### 2.6 组合：Flow Field 全局 + Steering 局部

推荐的分层：

```text
┌─────────────────────────────────────────────┐
│ 全局层：Flow Field                           │
│  - 目标多源 BFS 积分场                        │
│  - 每格最陡下降方向                           │
│  - 地图编辑时重建 / 增量更新                  │
└──────────────────┬──────────────────────────┘
                   │ 位置 → 双线性采样 → 期望方向
┌──────────────────▼──────────────────────────┐
│ 局部层：Steering                             │
│  - 到达减速（Arrive）                         │
│  - 单位间分离（Separation）                   │
│  - 障碍软斥力 / 三须避障                      │
│  - 限力、限速、硬碰撞兜底                     │
└─────────────────────────────────────────────┘
```

- **Flow Field 负责“往哪走”**：绕过静态墙、选择最近目标、保证全局可达。
- **Steering 负责“怎么走”**：避免互相重叠、贴墙滑行、目标附近减速、动态单位避让。
- 本项目的 `flow_sim.gd` 已经实现了这个组合的“轻量版”：流场采样 + 分离 + 障碍软斥力 + 圆形硬碰撞；`godot-steering` 则实现了完整行为集，并在其 §3.3 用流场作为路径跟随。
- 若障碍会移动（单位、可破坏墙、临时路障），有两种做法：
  1. **不重建场**，把动态障碍交给局部 Steering 避让（便宜，但不保证全局最优）。
  2. **重建/增量更新代价场**，让流场绕开（全局正确，但有重建成本）。

### 2.7 为什么拆成三个独立 Demo

- **公平归因**：WFC 的瓶颈是候选绘制，Steering 的瓶颈是每单位力计算，Flow Field 的瓶颈是拖尾/箭头填充；混在一个场景里无法分离成本。
- **可复现验收**：每个 Demo 有自己的 seed、地图、阵容、smoke 与性能口径。
- **可复用**：数据协议、算法、渲染、工具链可以分别搬到其他引擎；§6 的映射表就是按这个拆分写的。

---

## 3. Flow Field 深挖

### 3.1 数据管线总览

```text
cost[]           0 = 障碍，1 = 可走
  │
  ▼ 多源 BFS（8 邻接，禁斜穿墙角）
integration[]    到最近目标的步数；INF = 不可达
  │
  ▼ 每格选积分最小的邻格
flow[]           单位方向向量；目标/障碍/不可达 = 零向量
  │
  ▼ 双线性采样（四角按面积加权）
单位期望方向
  │
  ▼ 期望速度 − 当前速度 + 分离 + 障碍软斥力
加速度 → 速度 → 位置 → 硬碰撞 → 到达/重生
  │
  ▼
MultiMesh 光晕/核心 + 拖尾 + 箭头 + 热力底色
```

实现分层（`godot-flowfield/docs/TECH.md` §1）：

| 层 | 文件 | 职责 |
| --- | --- | --- |
| 场数据 | `scripts/flow_field_grid.gd` | 纯 `RefCounted`，不依赖节点；cost/integration/flow/BFS/采样 |
| 模拟 | `scripts/flow_sim.gd` | 固定 30Hz；空间哈希、分离、碰撞、重生、拖尾历史 |
| 渲染 | `scripts/flow_view.gd` | 三视图、箭头、MultiMesh、拖尾、目标脉冲 |
| 入口/UI | `scripts/main.gd` / `scripts/flow_ui.gd` | 输入、画笔、目标、地图/群数、FPS/统计 |

### 3.2 代价场

当前实现是**二元代价**：`cost[i] = 0` 障碍，`1` 可走（`flow_field_grid.gd:31`、`set_cost()` `:107`）。这是参考视频的模型，也是 BFS 能直接用的前提。若要做加权地形（沼泽、道路、斜坡），把 `cost` 扩展为 `1..255` 的通行代价，积分场改用 Dijkstra，**流场输出格式不变**。

### 3.3 积分场：多源 BFS

#### 数据结构

| 字段 | 类型 | 含义 | 代码 |
| --- | --- | --- | --- |
| `cost` | `PackedInt32Array` | 0 障碍 / 1 可走 | `flow_field_grid.gd:31` |
| `integration` | `PackedInt32Array` | 到最近目标的 BFS 步数，`INF = 1<<30` | `:32`, `:18` |
| `flow` | `PackedVector2Array` | 指向积分更小邻格的单位向量 | `:33` |
| `goals` | `Array[Vector2i]` | 多目标，最多 8 个 | `:34`, `:14` |
| `_goal_mask` | `PackedByteArray` | 目标格标记，流场选择时跳过 | `:43` |
| `_queue` | `PackedInt32Array` | BFS FIFO 队列（存格索引） | `:42` |

#### 固定邻域顺序

```text
k:    0     1     2     3     4      5      6      7
dx:  +1     0     0    -1   +1     +1     -1     -1
dy:   0    -1    +1     0   -1     +1     -1     +1
```

（`flow_field_grid.gd:21-24`）

顺序不是随手写的：它同时决定 BFS 的入队顺序、流场平局裁决顺序，以及最终可复现性。**移植时必须保留这张表**。

#### 伪代码

```text
integration.fill(INF); flow.fill(0); goal_mask.fill(0)
queue.clear()
for goal in goals:                    # 多源：所有目标都是 0
    if open(goal):
        integration[goal] = 0
        goal_mask[goal] = 1
        queue.push_back(goal)

head = 0
while head < queue.size():
    p = queue[head]; head += 1
    for k in 0..7:
        n = p + offset[k]
        if out_of_bounds(n) or blocked(n) or integration[n] != INF: continue
        if k >= 4 and (blocked(p.x + dx[k], p.y) or blocked(p.x, p.y + dy[k])):
            continue                  # 禁斜穿墙角
        integration[n] = integration[p] + 1
        queue.push_back(n)
```

实际实现见 `flow_field_grid.gd:191-226`。`reachable_cells = queue.size()`（`:226`）。

> **度量约定**：本实现与参考视频一致，正交和对角都记 1 步（8 邻接的 Chebyshev 度量），所以路径会偏向对角。若需要更接近欧氏距离，可在 Dijkstra 中给对角 √2、正交 1；流场输出格式不变，但积分值和路径形状会变。移植时把这条写进数据协议，避免“看起来更近但走得更远”的争议。

#### 不变量与证明要点

1. **目标值为 0**：所有可走目标格入队时 `integration = 0`。
2. **最短路性质**：BFS 按 FIFO 扩展，均匀步长 +1；一个格第一次被访问时就是最短步数。对角规则只是把“允许的邻接”限制为不穿墙角的邻接，不破坏 BFS 的正确性。
3. **存在父格**：对每个可达非目标格 $c$，由 BFS 的赋值方式，存在邻格 $p$ 使 `integration[c] = integration[p] + 1`。
4. **严格单调**：流场选择 `integration` 最小的邻格（严格 `<` 当前格才写入），因此 `flow[c]` 指向的格满足 `integration < integration[c]`。
5. **无环/可达**：每走一步积分值严格下降，整数且下界为 0，因此不会成环，至多 `integration[c]` 步到达某个目标。
6. **不可达**：保持 `INF`，流场为零向量。
7. **确定性**：固定队列顺序 + 固定邻域顺序 + 严格 `<` 平局裁决；同地图同目标逐位相同。

smoke 对 C 形样例（36×24）的验证：开放格 835、可达格 835、最大积分 31、流场单调坏格 0、斜穿墙角坏格 0、目标格零向量（`tools/smoke_flowfield.gd`；T-009/T-011 回归均通过）。本报告导出的引擎无关样例也复现了同样的 835/31/0/0（`docs/portable/flowfield_sample_medium.json`）。

#### 加权地形：BFS → Dijkstra

把 FIFO 队列换成二叉堆（或桶队列），把 `+1` 换成 `+ terrain_cost[n]`：

```text
dist[start] = 0
while heap not empty:
    (d, p) = pop_min(heap)
    if d != dist[p]: continue
    for k in 0..7:
        n = p + offset[k]
        if blocked(n) or corner_blocked(p, n): continue
        nd = d + cost[n]
        if nd < dist[n]:
            dist[n] = nd
            push(heap, (nd, n))
```

流场的选择逻辑完全不变（仍选积分最小的邻格），只是“步数”变成“代价”。流场的严格单调性仍然成立（代价为正时）。注意：目标格代价应为 0，否则会在目标处多计一次。

### 3.4 流场：最陡下降

```text
for each cell c:
    if blocked(c) or unreachable(c) or goal(c): continue
    best = INF; best_k = -1
    for k in 0..7:
        n = c + offset[k]
        if blocked(n): continue
        if k >= 4 and corner_blocked(c, n): continue
        if integration[n] < best:
            best = integration[n]; best_k = k
    if best_k >= 0 and best < integration[c]:
        flow[c] = unit_direction[best_k]
```

实际实现 `flow_field_grid.gd:229-252`。目标格、障碍格、不可达格保持 `Vector2.ZERO`。

**平局**：多个邻格积分相同，保留第一个 `k`（严格 `<` 才替换）。这保证同一张图每次生成相同方向。

**多目标**：BFS 把所有目标作为源，所以每个格自动流向“最近的目标”；不需要为每个目标单独建场。目标增删会触发整场重建。

### 3.5 采样：双线性插值

单位位置通常落在格内而不是格心。取所在格四角的流向量，按面积权重混合：

```text
local = (world - origin) / cell_size - 0.5
x0 = floor(local.x); y0 = floor(local.y)
fx = local.x - x0; fy = local.y - y0
w00 = (1-fx)(1-fy); w10 = fx(1-fy)
w01 = (1-fx)fy;     w11 = fx·fy

dir = normalize( Σ flow[corner] * w[corner] )
```

- 只有“可走且可达”的角参与；四角都不可用时退回单位所在格流向量。
- 归一化防止斜向混合导致速度变快。
- 作用：格边界处方向连续过渡，单位不会在格子边缘突然折向。

实现：`flow_field_grid.gd:262-320`；模拟热路径内联版本在 `flow_sim.gd:475-532`（每 2/3 拍刷新一次，见 §3.7）。

**注意**：双线性混合的是“方向”，不是“路径”；在急弯处混合向量可能短暂指向墙角，靠障碍软斥力与硬碰撞兜底。本项目 smoke 验证了 500 体 180 步无穿墙。

### 3.6 动态重建与增量更新

当前 `_rebuild_field()`（`flow_sim.gd:370-400`）做的是：

1. `field.rebuild()`：清空、重算 BFS、重算流场。
2. 重建 `_spawn_cells`（可达且可走）。
3. 重建 `_goal_centers` 与到达半径。
4. 重建 `_near_wall` 邻墙表（每个障碍格周围一圈）。
5. 把卡在墙里的单位推出（`_nudge_agents_out_of_walls()`）。
6. 发 `field_changed` 信号。

**成本**（`[实测]`）：

- T-009 记录中图 6–14 ms；T-011 高负载下 `build_ms` 中位 11.63–18.07 ms（B/ALL、720/1080 不同配置）。
- 这个成本包含近墙表与重生格，纯 BFS 只是一部分。
- 拖拽画笔时每个鼠标事件都重建会明显掉帧；当前 Demo 每次 `apply_brush_line`（一段笔划）后重建一次，而不是每个像素重建。

**策略取舍**：

| 策略 | 成本 | 正确性 | 适用 |
| --- | --- | --- | --- |
| 整场重建 | O(V + E) | 简单、严格正确 | 当前地图（≤48×32）、低频编辑 |
| 笔划批处理/节流 | 同上，但次数少 | 正确 | 拖拽绘制、连续编辑 |
| 增量 BFS | 正比于受影响区域 | 需要小心维护不变量 | 大图、局部开门/关门 |
| 多分辨率/分层场 | 粗层全局 + 细层局部 | 近似，需处理边界 | 超大世界 |
| 局部避让替代 | O(N) | 不保证全局最优 | 少量动态障碍 |

**增量更新的难点**：目标移动或多目标变化会影响全图距离；障碍变化只影响局部，但如果该局部是唯一通道，远处所有格的距离都要更新。实现上需要“脏区 + 重新扩散”，并保证流场在新旧积分场交替时仍然单调。当前项目选择整场重建，是规模与复杂度的合理折中。

### 3.7 智能体积分

每个逻辑步（`flow_sim.gd:411-649`）：

```text
desired = sampled_flow * own_speed
accel   = (desired - velocity) * 5.0
accel  += separation * own_speed * 2.8
accel  += wall_soft_push * own_speed * 3.2   # 仅邻墙格
clamp(accel, max_force = own_speed * 8)
velocity += accel * dt
clamp(velocity, own_speed)
position += velocity * dt
resolve_collisions(position)
```

参数：

| 参数 | 值 | 代码 |
| --- | --- | --- |
| 固定步长 | 1/30 s | `flow_sim.gd:13` |
| 单位半径 | `clamp(cell*0.17, 2.6, 7.0)` | `:138` |
| 速度 | `cell*2.9` | `:139` |
| 个体速度系数 | 0.86–1.14（固定种子） | `:239` |
| 分离半径 | `radius*2.3` | `:459` |
| 分离哈希格 | `radius*2.3`（最小 4） | `:140` |
| 障碍软斥力半径 | `radius*2.1` | `:461` |
| 最大力 | `speed*8` | `:468` |
| 到达半径 | `0.8*cell` | `:380` |
| 重生最小积分 | 12 步 | `:17`, `:787` |
| 上限 | 1200 单位 / 8 目标 | `:15-16` |

**分离力**：空间哈希每 2 拍（大群 3 拍）重建；每对只累加一次（自身格 + 右/右上/右下/下五个偏移，`flow_sim.gd:663-712`）。零距离时用 `float(i*37 + j*17) * 0.618` 的确定性角度散开（`:699-703`），避免随机数与除零。

**碰撞**：非邻墙格只做边界夹紧；邻墙格才做圆 vs 矩形精确推出，最多 3 次迭代（`_resolve_walls` `:715-762`）。中心落入障碍内部时按最近边推出，避免 `d=0`。

**到达与重生**：到达半径内重生到积分 ≥12 的格，带 0.18 s 淡入，避免目标附近无限堆积（`:765-799`）。

**可复现性**：

- 所有随机数来自 `RandomNumberGenerator`，种子 `seed*7919+17`（`:218`）。
- 哈希桶、邻域、目标列表、BFS 队列全部按固定顺序遍历。
- 逻辑不使用 wall-clock；`Time.get_ticks_usec()` 只用于统计，不参与决策。
- smoke：同地图同目标两次重建逐位相同；同种子 300 体 90 步位置最大偏差 0.000000 px。

### 3.8 渲染

#### 三视图

| 视图 | 底色 | 数值 | 箭头 |
| --- | --- | --- | --- |
| 代价场 | 深青平地 + 棋盘微差 | 可走格显示 `1` | 关 |
| 积分场 | 青→蓝→紫→粉热力色 | BFS 步数，不可达 `×` | 默认关（可手动开） |
| 流场 | 低饱和热力色 | 关 | 青色 8 方向箭头 |

热力色 `_heat_color()` 在 `flow_view.gd:292-302`；箭头在 `:329-365`，每支 3 段（`draw_multiline_colors`，抗锯齿开启），835 个可达格 ×3 ≈ 2,505 段，T-011 测得箭头层约 45,036 primitives。

#### 智能体批量绘制

`MultiMeshInstance2D` + `MultiMesh.TRANSFORM_2D`，两个实例层：

- **Glow**：加色混合，`QuadMesh(64×64)`，`glow_scale = radius*4.6/64`，alpha 0.42。
- **Core**：普通混合，`core_scale = radius*1.9/64`，alpha 0.92。

每帧更新 2N 个变换与颜色（`flow_view.gd:195-227`），渲染位置在 `agent_prev` 与 `agent_pos` 之间按 `render_alpha()` 插值。1000 体 = 2,000 个 MultiMesh 实例，T-011 图层归因显示智能体层约 4,000 primitives（隐藏 agents+trails +6.8 FPS）。**必须给 MultiMesh 设置 mesh**（`QuadMesh`），否则 GLES3 报 `mesh.is_null()` 且不绘制——T-009 修复的关键问题。

#### 拖尾

- 每个单位保留 6 个历史点，5 段线（`TRAIL_LEN = 6`）。
- `draw_multiline`，线宽 1.1 px，固定粉色 alpha 0.115。
- 默认关闭抗锯齿；群数 >700 时隔一个单位画一条（半采样），线段数 5000 → 2500。
- 刷新频率：普通 15Hz（每 2 拍），大群 10Hz（每 3 拍）。
- 单段跳变超过 2.4 格时跳过，避免重生拉出长线（`flow_view.gd:435`）。

T-011 的引擎计数直接量化了拖尾成本：AA 开→关，objects 138,088→58,087、primitives 151,438→71,436；半采样再减 45k（AA 开时）/5k（AA 关时）。详见 §4。

#### 绘制层顺序

```text
父节点 _draw：底色 → 格子 → 网格线 → 数值 → 箭头 → HUD 角标
子节点 TrailLayer：拖尾
子节点 AgentGlow：加色光晕
子节点 AgentCore：核心
子节点 Overlay：目标脉冲、悬停框
```

绘制必须在**对应节点自己的 `_draw()`** 里调用；T-008 在父节点上调用子节点的绘制，触发 “Drawing is only allowed inside this node's `_draw()`” 并刷屏。T-009 改为 `draw` 信号 bind 子节点（`flow_view.gd:60`, `:80`）。

### 3.9 复杂度

设 V = cols×rows，N = 单位数，C = 每单位邻居上限，L = 拖尾点数（6），S = 哈希表大小。

| 阶段 | 复杂度 | 说明 |
| --- | --- | --- |
| 代价场编辑 | O(1)/格 | `set_cost` |
| BFS 积分场 | O(V + E)，E ≤ 8V | 每格入队一次；对角检查常数 |
| 流场 | O(8V) | 每格扫描 8 邻域 |
| 重建附加 | O(V + N) | 近墙表、重生格、推出卡墙单位 |
| 双线性采样 | O(1)/单位 | 热路径内联；每 2/3 拍刷新 |
| 空间哈希重建 | O(N + S) | 每 2/3 拍 |
| 分离 | O(N·C) 均摊 | 每对只算一次 |
| 碰撞 | O(N)（多数只夹边界） | 邻墙单位才做 3 次精确推出 |
| 到达/重生 | O(N·G)，G ≤ 8 | 目标距离检查 |
| 拖尾历史 | O(N·L) 每 2/3 拍 | 移位 |
| 渲染 | O(N) 实例更新 + O(N·L/stride) 线段 | MultiMesh + draw_multiline |

### 3.10 参数与代码位置

| 主题 | 参数/函数 | 位置 |
| --- | --- | --- |
| 邻居顺序 | `OFF_X/OFF_Y/DIR_X/DIR_Y` | `flow_field_grid.gd:21-24` |
| 多源 BFS | `rebuild()` | `:180-257` |
| 禁斜穿墙角 | `k >= 4` 检查 | `:218-221`（BFS）、`:244-246`（流场） |
| 流场选择 | 最陡下降 | `:229-252` |
| 双线性采样 | `sample_direction()` | `:262-320` |
| 固定步长 | `FIXED_DT` | `flow_sim.gd:13` |
| 大群 10Hz | `large_group_10hz` / `_refresh_every` | `:56`, `:104-110`, `:442` |
| 分离哈希 | `_compute_separation()` | `:652-712` |
| 碰撞推出 | `_resolve_walls()` | `:715-762` |
| 重生 | `_respawn_agent()` / `_spawn_position()` | `:765-799` |
| 拖尾 | `_shift_trails()` / `_draw_trails()` | `:844-850` / `flow_view.gd:431-453` |
| 智能体 MultiMesh | `_ensure_agent_multimesh()` / `_update_agents()` | `flow_view.gd:169-227` |
| 箭头 | `_draw_arrows()` | `flow_view.gd:329-365` |
| 审计 bench | 8 配置 × 5 轮 × 2 分辨率 | `tools/bench_ablation.gd:17-55`, `:269` |
| 一键复测 | `run_ablation.sh` | `tools/run_ablation.sh` |

### 3.11 已知限制

- BFS 均匀代价；加权地形需 Dijkstra（流场接口不变）。
- 整场重建，编辑大图有 6–20 ms 峰值；未做增量。
- 动态障碍只能通过重建或局部 Steering 处理，没有“移动障碍专用场”。
- 拖尾没有时间衰减颜色，只是固定透明度。
- UI 为 1280×720 逻辑布局，窗口更窄时依赖 `keep` 拉伸。
- 智能体上限 1200；1000 档为保集显帧率牺牲拖尾密度与刷新频率。

---

## 4. 性能原理：机制 → 成本 → 验收

### 4.1 指标定义与预算

| 指标 | 定义 | 回答什么问题 |
| --- | --- | --- |
| avg FPS | 300 帧间隔之和 → `300 / elapsed_s` | 整段吞吐 |
| P50/P95/P99 | 300 个帧间隔的最近秩百分位 | 典型/尾部体验 |
| worst | 300 帧中的最大帧间隔 | 最坏瞬间 |
| hitch >33.3 / >50 | 严格大于 33.3 ms / 50 ms 的帧数（每轮 /300） | 卡顿频率 |
| 逻辑步长 | `step_fixed()` 的精确 `step_total_usec / step_count` | CPU 逻辑预算 |
| 逻辑预算 | 逻辑步长 / 33.33 ms（30Hz 固定步长） | 逻辑是否吃满一帧 |
| 引擎计数 | draw calls / objects / primitives | 渲染提交量 |
| 建场时间 | `sim.build_ms()` | 地图编辑的峰值成本 |

**30Hz 逻辑预算 = 33.33 ms；60Hz 渲染预算 = 16.67 ms；30 FPS 渲染预算 = 33.33 ms。** 逻辑与渲染是两条预算线，不能用一个“FPS”混在一起。

### 4.2 因果链一：关闭拖尾 AA（最大单因）

| 环节 | 内容 |
| --- | --- |
| **机制** | `draw_multiline(..., antialiased=true)` 把每条线段展开成带边缘的屏幕空间图元，而不是 1 条普通线；5,000 条拖尾线段被放大成大量几何与填充。`[推断，有计数支持]` |
| **成本** | 1000 体、1280×720：objects 138,088→58,087（−58%），primitives 151,438→71,436（−53%）；draw calls 仅 166→161，说明不是提交次数问题，而是图元/填充。`[实测]` |
| **收益** | 同轮归一 1.65× [0.84–2.33] @720；1.46× [1.35–2.08] @1080；P95 145.4→98.7 ms（720）、181.1→109.0 ms（1080）。`[实测]` |
| **为什么 1080 的 P95 改善更大** | 同样内容下 1080 像素填充更多，去掉 AA 后减少的填充与带宽收益更大；720/1080 的 objects/primitives 完全相同，差异只在像素。`[实测+推断]` |
| **验收** | 默认 `trail_antialias=false`；视觉回归确认 1.1 px 线宽下差异可接受；引擎计数 objects/primitives 应显著下降；同轮 FPS 增益 ≥1.4×。`[项目决策]` |

**结论**：在 Intel HD 这类填充受限的集显上，**拖尾 AA 是 T-008 初版的最大瓶颈**；关掉它不是“降画质到不可看”，而是去掉每条线段的屏空间展开成本。

### 4.3 因果链二：拖尾半采样

| 环节 | 内容 |
| --- | --- |
| **机制** | 群数 >700 时每 2 个单位只画 1 条拖尾；线段数 5,000→2,500。`[实测]` |
| **成本** | AA 开时 objects/primitives 减约 45k/45k（151,438→106,438）；AA 关时只减 5k/5k（71,436→66,436）。`[实测]` |
| **收益** | 仅半采样同轮 1.25× [0.74–1.62] @720、1.35× [1.00–2.42] @1080；**先关 AA 再开半采样**，1280 中位 15.7→26.9 FPS（+71%）。`[实测]` |
| **为什么单独开收益小** | AA 的巨型图元掩盖了线段数本身；先削掉更贵的那层（AA），半采样才成为主要矛盾。两者是**正交互**：都在削拖尾几何。`[推断，由计数支持]` |
| **验收** | 大群视觉密度可接受；500 档不生效（阈值 >700）；AA 关时 primitives 再降约 5k。`[实测]` |

### 4.4 因果链三：大群 10Hz 刷新

| 环节 | 内容 |
| --- | --- |
| **机制** | 群数 >700 时，方向/分离/拖尾从每 2 拍（15Hz）降到每 3 拍（10Hz）；移动仍 30Hz。`[实测]` |
| **成本** | 图元数不变（objects/primitives 与 B 相同）；逻辑步长中位 18.28→16.17 ms（720）、22.84→16.92 ms（1080）；逻辑预算 55%→48% / 68%→51%。`[实测]` |
| **收益** | 同轮 1.13× [0.66–1.40] @720、1.22× [1.06–1.53] @1080；FPS 增幅小于 AA/半采样，因为它主要降低 CPU 压力。`[实测]` |
| **为什么帧率提升有限** | 复测时场景是渲染受限（拖尾/箭头填充），逻辑不是唯一瓶颈；10Hz 买的是**逻辑余量与 worst frame 空间**，不是直接帧率。`[推断，由逻辑预算与图层归因支持]` |
| **验收** | 逻辑预算显著下降；移动仍 30Hz、视觉不卡顿；500 档阈值不生效。`[实测]` |

### 4.5 因果链四：500→1000 为什么变平

这是最容易被误读的一条。先给结论：**“变平”不是流场算法免费，而是 >700 的降采样策略把 1000 档的绘制/刷新量拉回到了 500 档的水平；在关闭这些策略的初版配置下，T-011 实测 500→1000 是明显变慢的。**

证据链（全部来自 T-011 与代码）：

1. **拖尾段数被拉平**：500 档阈值不生效，`stride=1`，500×5 = **2,500 段**；1000 档半采样生效，`stride=2`，500×5 = **2,500 段**。两者相同。
2. **引擎计数几乎相同**：
   - 500 档 `-AA`（AA 关、半采样不生效）：objects 53,086 / primitives 64,434。
   - 1000 档 `ALL`（AA 关、半采样生效）：objects 53,087 / primitives 66,436。
   - 差值只有 2,002 primitives，正好对应智能体从 500→1000 多出的约 2,000 个实例图元。`[实测，CSV]`
3. **500 档半采样确实不生效**：500 的 `baseline` 与 `half` 计数完全相同（93,086/104,434），`aa_off` 与 `aa_off_half` 也完全相同（53,086/64,434）。这直接验证了 >700 阈值。`[实测，CSV]`
4. **刷新频率也被拉平**：500 档方向/分离 15Hz；1000 档 10Hz。按“单位·刷新次数”粗算，1000 的每 tick 刷新量是 1000/3 ≈ 333 单位，500 是 500/2 = 250 单位，只多 33%，不是 2×（未计邻居密度带来的成对成本）。移动积分仍是 30Hz，1000 是 500 的 2×。`[推断，由代码与参数]`
5. **初版配置下并不平**：T-011 的 baseline（AA 开、15Hz、全拖尾）500→1000 中位 FPS 为 **26.0→11.0**（1280×720），约 2.4× 下降；此时拖尾段数 2,500→5,000、AA 展开量翻倍。`[实测]`

**所以正确的表述是**：在默认优化配置下，500→1000 的 FPS 接近，是因为 **绘制几何被半采样拉平、逻辑刷新被 10Hz 拉平、MultiMesh 保持 draw calls 恒定**；在关闭这些策略时，成本仍随群体线性/超线性增长。不要把“调参后的平台”误当成“算法复杂度平台”。

### 4.6 平均 FPS、worst frame、P95/P99 与 hitch

| 口径 | T-011 1280 B | T-011 1280 ALL | T-011 1080 ALL | 说明 |
| --- | ---: | ---: | ---: | --- |
| avg FPS | 11.0 | 26.4 | 16.8 | 整段吞吐 |
| 每轮 P95 中位 | 145.4 ms | 57.9 ms | 129.2 ms | 稳定态尾部 |
| 合并 P50 | 81.3 ms | 37.9 ms | 48.7 ms | 5×300 帧池化 |
| 合并 P95 | 153.6 ms | 77.6 ms | 129.2 ms | 池化尾部，含负载尖峰 |
| 合并 P99 | 221.7 ms | 103.7 ms | 204.0 ms | 更尾部 |
| 合并 worst | 355.5 ms | 218.1 ms | 428.7 ms | 单帧最大 |
| hitch >33.3 | 100% | 56% | 74% | 每轮帧数占比 |
| hitch >50 | 100% | 26% | 48% | 每轮帧数占比 |

**区别**：

- **平均 FPS 会把长尾“摊平”**：300 帧里出现 1–2 个 1 秒级停顿，平均 FPS 只下降几个点，但玩家会明确感到卡顿。
- **P95/P99 描述尾部**：P95 = 95% 的帧不慢于该值；P99 更接近“最差体验”。
- **worst 是单点极值**，容易被 OS 调度、换页、窗口失焦放大；本项目 worst 218–428 ms 中包含 0.5–1.5 s 的 OS 级停顿，不全是游戏逻辑。
- **hitch 计数回答“卡顿频率”**：30 FPS 目标下 >33.3 ms 的帧占比，比平均 FPS 更接近验收口径。

**验收建议**：平均 FPS 只作吞吐参考；主指标用 **P95 + hitch 占比**，worst 用来定位异常；三者同时报告。

### 4.7 图层归因：剩余成本排序

T-011 在默认全优化配置下依次隐藏图层（1280×720，1000 体，3 轮）：

| 变体 | FPS 中位 | P95 中位 | primitives | objects |
| --- | ---: | ---: | ---: | ---: |
| all layers | 26.9 [25.1–30.2] | 61.5 | 66,436 | 53,087 |
| trails off | 26.2 [23.2–27.8] | 65.7 | 61,436 | 48,087 |
| agents+trails off | 33.7 [20.7–34.9] | 50.6 | 57,436 | 48,085 |
| arrows off | **54.4** [48.6–63.5] | **40.0** | **21,400** | **8,051** |

- **箭头层是默认配置下最大渲染项**：隐藏 +27.5 FPS，primitives −45,036；draw calls 只 −3。835 格 ×3 段、AA 的 `draw_multiline_colors`，不是 draw call 问题，而是图元/填充。
- **智能体层有 CPU 成本**：隐藏 agents+trails +6.8 FPS，但 primitives 只 −4,000；同时省掉每帧 2×1000 次 MultiMesh 更新，所以不能全归因于 GPU。
- **拖尾层接近免费**：隐藏 −0.7 FPS（噪声内），primitives −5,000；三项优化后它已不是瓶颈。

**当前成本排序（默认配置，1280×720，1000 体）**：箭头层 ≫ 智能体层（含 CPU 更新）> 拖尾层 ≈ 背景网格/UI。下一步若还要提帧率，应评审箭头层的 AA/密度/缓存策略（属视觉变更，T-011 未做）。

### 4.8 测量局限

必须与数字一起读：

1. **机器负载是最大方差源**：T-011 期间飞书、WebKit、Godot 编辑器、另外两个 worker 同时运行；load1 5.23–24.68（中位 9.34），swap 已用约 4.3–4.5 GB（总 5 GB）。绝对 FPS 被压低。
2. **720 与 1080 不是同一负载窗口**：1080 各轮 load1 中位 10.2–15.9，720 为 7.5–14.3；不要用 1080/720 的绝对 FPS 比值推断分辨率成本。相同的是 objects/primitives；差异在填充/带宽。
3. **1080 是离屏 SubViewport**：本机屏幕 1440×900，macOS 会把 1920×1080 窗口夹到 1440×762；因此用 1920×1080 离屏渲染，present/blit 成本不计。真实 1080p 显示器上的绝对值可能不同。
4. **窗口未获得焦点**：`window_is_focused()=false`（前台是飞书）；macOS 可能对后台/遮挡窗口节流。影响绝对值，不影响同轮相对比较。
5. **无 GPU 计时器**：GL Compatibility 不暴露 GPU time；RenderDoc 不支持 macOS 宿主；Xcode GPU Capture 只支持 Metal。归因是“引擎计数 + 图层隔离 + 同轮归一”的间接推断，不能给出 GPU ms 分解。
6. **5 轮不足以消除长时尖峰**：轮次漂移表显示 load1 可在一轮内到 21+；中位稳健，但范围保留尖峰。不要只引用最好一轮。
7. **单场景/单地图**：medium/421，1000 与 500 两档；未扫 small/large、随机地图、多目标、暂停/重置、录制模式。
8. **UI 包含在负载内**：场景默认带右侧 UI 与 HUD 文本；这与玩家真实运行一致，但不是纯模拟微基准。
9. **热状态**：`CPU_Speed_Limit=100`，无 thermal warning；但 2015 款 15W i7 + 核显在长时间负载下可能降频，未取得逐轮频率。
10. **绝对 FPS 不可跨会话比较**：T-009 的 47.0 是较空机器单次；T-011 ALL 中位 26.4（范围 17.0–32.2）。旧 bench 本次复跑 1000 档 32.2、500 档 43.3，落在范围内，说明代码路径一致，差异来自环境。

### 4.9 验收口径建议

- **干净机器**：30 FPS 目标 → P95 ≤33.3 ms、hitch >33.3 ms ≤5%、无持续 NaN/错误。
- **共享/高负载机器**：不要用绝对 FPS 门禁；用同轮归一 **ALL/baseline FPS ≥1.8×**、**P95/baseline ≤0.7**，并要求引擎计数方向正确（AA off 后 objects/primitives 显著下降）。
- **任何环境**：正确性 smoke 必须先过；性能优化不能以破坏确定性或穿墙为代价。

---

## 5. 工程方法

### 5.1 性能预算

先写预算，再写优化：

| 预算项 | 30 FPS 目标 | 60 FPS 目标 | 本项目现状 |
| --- | ---: | ---: | --- |
| 渲染帧预算 | 33.33 ms | 16.67 ms | ALL 1280 P95 57.9 ms（高负载，未达标） |
| 逻辑固定步预算 | 33.33 ms | 33.33 ms | ALL 1280 14.40 ms（43%） |
| 逻辑余量 | ≥50% | ≥50% | 57% |
| hitch >33.3 ms | ≤5% | ≤5% | 56%（1280 ALL，高负载） |
| 建场峰值 | ≤16 ms | ≤16 ms | 11.6–18.1 ms（T-011 负载下） |

**注意**：T-011 的高负载环境没有达到 30 FPS 的 P95 门禁；这是诚实结论，不应藏起来。干净机器需要用同一 `run_ablation.sh` 复跑补一列。

### 5.2 先测量后优化

T-011 的顺序值得复用：

1. **先做正确性回归**：smoke 28 条 PASS、同种子 0 偏差、headless 0 ERROR。
2. **先建立可比的基线**：同一场景、同一地图、同一种子、同一采样窗口。
3. **再拆因子**：把“关 AA / 10Hz / 半采样”做成独立开关，而不是一次改三个。
4. **看引擎计数**：objects/primitives 解释“贵在几何还是提交”；draw calls 只有 161–166，说明不是提交瓶颈。
5. **做图层隔离**：隐藏 trails / agents+trails / arrows，分离 GPU 与 CPU 成本。
6. **最后才改默认值**：本轮只加 bench 开关，默认视觉不动；箭头优化留给美术/策划评审。

### 5.3 消融矩阵与同轮归一

- **8 配置因子矩阵**：B、-AA、10Hz、1/2、-AA+10Hz、-AA+1/2、10Hz+1/2、ALL。
- **5 轮独立运行**，轮次主序，每轮配置顺序循环左移，避免同一配置总在同一负载位置。
- **同轮归一**：每轮内 `config FPS / 同轮 baseline FPS`，再取 5 轮中位；这是抵消机器负载漂移的主要证据。
- **主效应**：每个因子两个水平各汇总 4 组合 ×5 轮 = 20 次运行的中位。
- **池化分布**：5×300 帧合并算 P50/P95/P99/hitch，展示真实尾部；与“每轮 P95 中位”并列，二者回答不同问题。

### 5.4 可复现审计场景

```text
地图：medium 36×24，C 形回廊，seed 421
阵容：1000（主档）+ 500（对照，验证 >700 阈值）
视图：flow；网格/箭头/拖尾/智能体开，数值关
预热：60 帧；采样：300 帧；轮间 settle：15 帧
轮次：5 轮独立运行，配置顺序循环左移
垂直同步：关闭；Engine.max_fps = 0
分辨率：1280×720 真实窗口；1920×1080 离屏 SubViewport
记录：每轮 load1/load5、CPU_Speed_Limit、引擎计数、逻辑步长、建场
产物：CSV + JSON（每帧）+ Markdown 汇总 + 对比图
```

### 5.5 报告模板

```markdown
# <场景> 性能报告
## 0. 结论（先看这里）
- 场景/配置/轮次/分辨率/环境
- 中位 FPS + 范围；P95；hitch；同轮归一
## 1. 测试对象与改动
## 2. 方法（采样、指标、消融矩阵、负载）
## 3. 结果（每轮 + 池化）
## 4. 归因（机制 → 计数 → 同轮归一）
## 5. 局限（负载、离屏、焦点、无 GPU 计时）
## 6. 回归（smoke、确定性、视觉）
## 7. 复现命令与原始数据
## 8. 后续建议
```

### 5.6 检查清单

**测量前**

- [ ] 正确性 smoke 通过，0 ERROR。
- [ ] 固定 seed/地图/阵容/轮次；写进报告。
- [ ] vsync 关闭，分辨率与拉伸模式明确。
- [ ] 记录机器负载、swap、热状态、窗口焦点。
- [ ] 原始数据落 CSV/JSON，不只留汇总。

**测量中**

- [ ] 至少 3–5 轮，轮次轮转配置顺序。
- [ ] 同时记录 avg、P50/P95/P99、worst、hitch。
- [ ] 记录逻辑步长与逻辑预算。
- [ ] 记录 draw calls/objects/primitives。
- [ ] 不在采样窗口内写大文件。

**测量后**

- [ ] 同轮归一与主效应都算。
- [ ] 不用最好一轮；给中位与范围。
- [ ] 机制解释与计数一致；区分实测与推断。
- [ ] 写清不能外推的边界。
- [ ] 视觉回归与确定性回归通过。

### 5.7 回归门禁

| 检查 | 命令 | 通过标准 |
| --- | --- | --- |
| 正确性 | `godot --path godot-flowfield --headless -s tools/smoke_flowfield.gd` | 末行 `FLOWFIELD_SMOKE_OK`，0 ERROR |
| 启动 | `godot --path godot-flowfield --headless --quit-after 600` | 0 ERROR / SCRIPT ERROR |
| 确定性 | smoke 内同种子 300 体 90 步 | 最大偏差 <0.001 px（参考实现 0.000000） |
| 性能相对门禁 | `bash tools/run_ablation.sh` | ALL/baseline ≥1.8×，P95/baseline ≤0.7 |
| 视觉 | 默认 1920×1080 截图对照 | 构图/图层/颜色一致，仅统计标签可不同 |

---

## 6. 跨引擎可移植

### 6.1 四层拆分

| 层 | 内容 | 哪些可跨引擎 | 哪些必须重写 |
| --- | --- | --- | --- |
| **A 数据协议** | cost/integration/flow 数组、索引、目标、参数、manifest | 全部；用 JSON/二进制 + 明确坐标与 INF | 文件读取/序列化 API |
| **B 算法** | 多源 BFS/Dijkstra、8 邻接、禁斜穿墙角、最陡下降、双线性采样、积分/分离/碰撞 | 全部；伪代码与不变量 | 容器类型、堆、随机数、浮点细节 |
| **C 渲染表现** | 三视图、热力色、箭头、MultiMesh/实例化、拖尾、图层顺序 | 视觉规则与参数 | 具体绘制 API（Godot/Unity/Unreal/Three.js） |
| **D 工具链** | smoke、bench、CSV/JSON、同轮归一、回归门禁 | 场景定义、指标、报告格式 | 引擎测试框架、Profiler、截图工具 |

**原则**：A 和 B 尽量做成引擎无关的“参考实现 + 数据”；C 只做“同一视觉规则的引擎适配”；D 保持同一套场景与指标，否则数字不可比。

### 6.2 Godot / Unity / Unreal / Three.js 映射表

| 概念 | Godot 4.6（参考实现） | Unity 2022+ | Unreal 5.x | Three.js |
| --- | --- | --- | --- | --- |
| 网格坐标 | `Vector2i` | `Vector2Int` | `FIntPoint` | `{x,y}` 或 `Int32Array` |
| 代价/积分数组 | `PackedInt32Array` | `NativeArray<int>` / `int[]` | `TArray<int32>` | `Int32Array` |
| 流方向 | `PackedVector2Array`（或 u8 索引） | `NativeArray<float2>` / `byte[]` | `TArray<FVector2D>` / `uint8` | `Float32Array` / `Uint8Array` |
| 邻域表 | `const OFF_X/OFF_Y` | `static readonly int[]` | `static const int32[]` | `const` 数组 |
| BFS 队列 | `PackedInt32Array` + head | `Queue<int>` / 环形缓冲 | `TQueue<int32>` | `Int32Array` + head/tail |
| 加权最短路 | 二叉堆（自写） | `NativeMinHeap` / 自写 | `TArray` + `Heapify` / 自写 | 自写二叉堆 |
| 固定步长 | `_physics_process` + `FIXED_DT` | `FixedUpdate` + `Time.fixedDeltaTime=1/30` | `FTickFunction` / Timer | 累加器 + `fixedDt` |
| 随机数 | `RandomNumberGenerator`（seed） | `Unity.Mathematics.Random` / 自写 PCG | `FRandomStream` | mulberry32/xorshift |
| 2D 画布 | `Node2D._draw()` / `draw_*` | `MonoBehaviour` + `Graphics` / `CommandBuffer` | `UCanvas` / `HUD` / Slate | `CanvasTexture` / `ShaderMaterial` |
| 实例化单位 | `MultiMeshInstance2D` | `Graphics.DrawMeshInstanced`（≤1023/批） | `UInstancedStaticMeshComponent` | `InstancedMesh` |
| 拖尾线 | `draw_multiline` | 自定义 Mesh / `LineRenderer` | `UStaticMeshComponent` / Spline Mesh | `LineSegments`（线宽受限）或四边形条带 |
| 文本/HUD | `Label` / `draw_string` | UI Toolkit / TextMeshPro | UMG / Slate | DOM / Canvas 2D |
| 计时 | `Time.get_ticks_usec()` | `Time.realtimeSinceStartupAsDouble` | `FPlatformTime::Seconds()` | `performance.now()` |
| 无头测试 | `godot --headless -s script.gd` | EditMode/PlayMode Test Runner | Automation / `-nullrhi` | Node + Playwright |
| 性能计数 | `RenderingServer.get_rendering_info()` | Profiler / Frame Debugger / `ProfilerRecorder` | `stat unit`, Insights | `renderer.info.render` |
| 截图 | `SubViewport` + `save_png` | `ScreenCapture.CaptureScreenshot` | `FScreenshotRequest` | Playwright screenshot |

### 6.3 移植契约

| 契约 | 规定 | 验收 |
| --- | --- | --- |
| **坐标** | 标准网格：原点左上、+x 右、+y 下；格心 `(x+0.5, y+0.5)*cell`；索引 `y*cols+x` | 用 3 个已知格心做坐标往返测试 |
| **单位** | 所有参数相对 `cell_size`；半径 0.17 cell、速度 2.9 cell/s、分离半径 0.391 cell（半径 ×2.3） | 缩放后所有长度比例不变；单位换算表写进 manifest |
| **锚点** | 单位/箭头/目标都以格心为锚；拖尾点是单位中心；镜头平移不改变网格原点 | 截图叠网格，锚点误差 <0.5 px（或 <0.01 cell） |
| **深度/顺序** | 背景 → 格子 → 网格线 → 箭头 → 拖尾 → 光晕 → 核心 → 目标/悬停 | 逐层隐藏截图，顺序与参考一致 |
| **图集/过滤** | 箭头可烘焙 8 方向图集；线性过滤；不使用像素风 NEAREST；拖尾颜色/透明度固定 | 视觉对照；无接缝/黑边 |
| **时间** | 逻辑固定 30Hz；渲染插值；降采样按 tick 计数，不用 wall-clock | 同 seed/同输入 90 步位置一致 |
| **确定性** | 邻域表、FIFO、严格 `<`、RNG seed、整数 INF、固定遍历 | 同 seed 两次积分/流场逐位相同 |
| **manifest** | 版本、坐标/单位/时间契约、文件 sha256、场景、验收结果 | sha256 重算一致；缺文件/版本不匹配拒绝加载 |

### 6.4 数据协议与导出包

本轮导出了三个引擎无关文件（`godot-flowfield/docs/portable/`）：

1. **`flowfield_params.json`**：坐标、邻域、BFS/流场规则、模拟参数、渲染参数、审计场景、移植规则。
2. **`flowfield_sample_medium.json`**：36×24 C 形样例的 cost/integration/flow 完整导出（864 格）。校验结果与 Godot smoke 一致：**835 可达、最大积分 31、单调坏格 0、斜穿墙角坏格 0、可达非目标零流向 0**。
3. **`manifest.json`**：坐标/深度/时间契约、文件 sha256、样例校验、验收清单，以及“绝对 FPS 不可跨会话混用”的警告。

数据格式建议：

```json
{
  "grid": {"cols": 36, "rows": 24, "cell_size": 24.0, "origin": [0, 0], "y_axis": "down"},
  "cost": {"encoding": "u8[]", "blocked": 0, "walkable": 1, "data": []},
  "integration": {"encoding": "i32[]", "goal": 0, "unreachable": 1073741824, "data": []},
  "flow": {"encoding": "u8[]", "none": 255, "directions": [[1,0],[0,-1],[0,1],[-1,0],[1,-1],[1,1],[-1,-1],[-1,1]], "data": []},
  "goals": [[5, 12]]
}
```

- **紧凑传输**：flow 用 1 字节方向索引（0–7，255 = 无），比每格 2 个 float 更省；渲染时再查方向表。
- **不可达哨兵**：统一 `1<<30`；不要用 `-1`（与“未初始化”混淆）。
- **版本化**：任何邻域顺序或坐标变化都必须升 `schema` 版本，否则旧数据不可复用。
- **校验**：加载时检查数组长度、目标合法性、INF 一致性；可选重算 BFS 对比抽样格。

### 6.5 移植验收清单

**数据**

- [ ] `cost/integration/flow` 长度均为 `cols*rows`，索引 `y*cols+x`。
- [ ] 目标格 `integration=0`、`flow=none`。
- [ ] 不可达格 `integration=INF`、`flow=none`。
- [ ] 同一份 JSON 在目标引擎加载后 sha256/抽样值一致。

**算法**

- [ ] 随机 20 张地图，积分场与参考 BFS 逐格一致。
- [ ] 所有可达非目标格流场严格指向积分更小的邻格（坏格 0）。
- [ ] 对角移动两侧正交格都被检查（坏格 0）。
- [ ] 多目标时所有目标为源，单位为最近目标。
- [ ] 同 seed/同编辑序列两次重建逐位相同。

**模拟**

- [ ] 600 步无 NaN；500 体 180 步无穿墙。
- [ ] 同 seed 300 体 90 步位置偏差 ≤ 本引擎浮点容差（参考实现为 0）。
- [ ] 到达后重生；目标附近不无限堆积。
- [ ] 逻辑 30Hz、渲染插值；降采样不改变移动频率。

**性能**

- [ ] 记录引擎、版本、CPU/GPU、分辨率、vsync、负载。
- [ ] 1000 体场景可运行；报告 avg + P95 + hitch + 逻辑步长 + 建场。
- [ ] 相对门禁：优化/基线 FPS ≥1.8、P95 比 ≤0.7（共享机器）。
- [ ] 不把不同引擎/不同会话的绝对 FPS 混表。

**视觉**

- [ ] 三视图底色/热力色/箭头/障碍/目标/拖尾颜色一致。
- [ ] 图层顺序一致；光晕为加色混合。
- [ ] 锚点、网格、单位半径、拖尾宽度比例一致。
- [ ] 截图对照（参考 vs 实现），标注差异。

### 6.6 常见移植坑

1. **Y 轴方向**：Godot 2D 是 Y-down，Unity/Three.js 是 Y-up；只在渲染适配层取反，不要把算法里的 y 也改掉，否则 BFS 的“上/下”与美术的“上/下”不一致。
2. **单位尺度**：Unreal 用厘米，Unity/Three.js 用米；`cell_size` 与速度、半径、分离半径必须一起缩放，不能只改一个。
3. **锚点**：Godot 的 `Node2D` 位置是节点原点；Unity Sprite 默认中心；Unreal 的 pivot 可能在脚底。统一到“格心/单位中心”，否则拖尾和箭头会错位。
4. **实例化批量上限**：Unity `DrawMeshInstanced` 每批最多 1023 个实例；1000 体刚好需要分两批。Godot MultiMesh 没有这个限制，不能直接照搬 draw call 数。
5. **线宽**：Three.js `LineBasicMaterial.linewidth` 在多数平台被忽略（通常只有 1 px）；要 1.1 px 或更粗的拖尾，用四边形条带/自定义 shader，不要假设 `linewidth` 生效。`[公开]`
6. **AA 语义**：不同引擎的“抗锯齿线”成本差异巨大；把“拖尾 AA 开关”作为独立参数，不要假设默认等价。
7. **时间**：Unity `FixedUpdate` 默认 50Hz；必须显式设 `Time.fixedDeltaTime = 1/30`。Unreal 的 tick 组与固定步长也要单独配置。
8. **随机数**：不要用全局 `Random`；用可序列化的 RNG 状态，否则同 seed 不可复现。
9. **浮点确定性**：跨引擎不保证逐位相同的浮点结果；用整数网格 + 固定顺序保证算法层确定性，浮点位置验收用容差（参考引擎为 0）。
10. **文本/HUD**：中文字体在各引擎的默认字体不同；要么打包字体，要么接受系统字体差异（本项目使用系统 CJK 字体，不打包）。

---

## 7. 证据索引

### 7.1 本仓库文件

| 文件 | 内容 |
| --- | --- |
| `godot-flowfield/README.md` | 运行、操作、算法摘要、性能表 |
| `godot-flowfield/docs/TECH.md` | 实现结构、参数、测试、性能记录 |
| `godot-flowfield/docs/迭代记录.md` | T-009/T-011/T-012 迭代与决策 |
| `godot-flowfield/docs/TECHNICAL_PRINCIPLES.md` | 本报告 |
| `godot-flowfield/docs/TECHNICAL_PRINCIPLES-交互版.html` | 单文件交互版（三视图/消融/预算计算器） |
| `godot-flowfield/docs/perf/REPORT.md` | T-011 审计报告 |
| `godot-flowfield/docs/perf/ablation_1280x720.csv` | 72 行原始数据（消融/500 对照/图层） |
| `godot-flowfield/docs/perf/ablation_1920x1080.csv` | 40 行原始数据 |
| `godot-flowfield/docs/perf/runs_raw.json` | 每轮统计 + 每帧帧时间 |
| `godot-flowfield/docs/perf/ablation_chart.png` | FPS/P95 对比图 |
| `godot-flowfield/docs/screenshots/01–05_*.png` | 1920×1080 截图 |
| `godot-flowfield/docs/video/flowfield_demo.mp4` | 10 秒 30fps 演示 |
| `godot-flowfield/docs/portable/flowfield_params.json` | 引擎无关参数 |
| `godot-flowfield/docs/portable/flowfield_sample_medium.json` | 校验过的样例场 |
| `godot-flowfield/docs/portable/manifest.json` | 契约、sha256、验收 |
| `godot-steering/README.md` / `docs/TECH.md` | Steering 实现与性能 |
| `godot-wfc/README.md` / `docs/TECH.md` | WFC 实现与性能 |
| `docs/algorithm-demos-index.md` | 三个 Demo 的总索引 |

### 7.2 关键代码位置

- 场数据：`godot-flowfield/scripts/flow_field_grid.gd:180-320`
- 模拟：`godot-flowfield/scripts/flow_sim.gd:411-850`
- 渲染：`godot-flowfield/scripts/flow_view.gd:195-453`
- 审计：`godot-flowfield/tools/bench_ablation.gd:17-55`, `:269-420`
- 回归：`godot-flowfield/tools/smoke_flowfield.gd`
- 一键复测：`godot-flowfield/tools/run_ablation.sh`

### 7.3 复现命令

```bash
cd godot-flowfield

# 正确性
godot --path . --headless -s tools/smoke_flowfield.gd
godot --path . --headless --quit-after 600

# 基准（旧，快速）
godot --path . --resolution 1280x720 -s tools/bench_flowfield.gd

# 审计级消融（T-011；macOS）
bash tools/run_ablation.sh
python3 tools/summarize_ablation.py
godot --path . --resolution 640x360 -s tools/plot_ablation.gd
```

### 7.4 来源表

| 来源 | 类型 | 用于 | 访问日期 |
| --- | --- | --- | --- |
| [B 站 BV12bzZY2EfA](https://www.bilibili.com/video/BV12bzZY2EfA) | 视频（仅研究，无素材复制） | Flow Field 视觉语言与算法演示 | 2026-11-21 |
| [B 站 BV1yCqfYuEh1](https://www.bilibili.com/video/BV1yCqfYuEh1) | 视频（仅研究） | Steering 行为与三须避障 | 2026-11-21 |
| [B 站 BV1Br421M7Vm](https://www.bilibili.com/video/BV1Br421M7Vm) | 视频（仅研究） | WFC 熵/传播/回溯 | 2026-11-21 |
| [Breadth-first search — Wikipedia](https://en.wikipedia.org/wiki/Breadth-first_search) | 公开资料 | BFS 定义、最短路性质 | 2026-11-21 |
| [Dijkstra's algorithm — Wikipedia](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm) | 公开资料 | 加权地形扩展 | 2026-11-21 |
| [Craig Reynolds, Steering Behaviors For Autonomous Characters](https://www.red3d.com/cwr/steer/gdc99/) | 公开论文 | Seek/Arrive/Separation 等行为模型 | 2026-11-21 |
| [WaveFunctionCollapse — GitHub (mxgmn)](https://github.com/mxgmn/WaveFunctionCollapse) | 公开实现 | WFC 原始算法与简单瓦片模型 | 2026-11-21 |
| [Shannon entropy — Wikipedia](https://en.wikipedia.org/wiki/Entropy_(information_theory)) | 公开资料 | WFC 熵定义 | 2026-11-21 |
| [Godot MultiMeshInstance2D](https://docs.godotengine.org/en/stable/classes/class_multimeshinstance2d.html) | 官方文档 | MultiMesh 实例化 | 2026-11-21 |
| [Godot CanvasItem.draw_multiline](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html) | 官方文档 | 拖尾/箭头批量线 | 2026-11-21 |
| [Godot RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html) | 官方文档 | 确定性随机 | 2026-11-21 |
| [Godot Time](https://docs.godotengine.org/en/stable/classes/class_time.html) | 官方文档 | 微秒计时/固定步 | 2026-11-21 |
| [Unity Graphics.DrawMeshInstanced](https://docs.unity3d.com/ScriptReference/Graphics.DrawMeshInstanced.html) | 官方文档 | Unity 实例化上限 | 2026-11-21 |
| [Unreal Instanced Static Mesh Component](https://dev.epicgames.com/documentation/en-us/unreal-engine/instanced-static-mesh-component-in-unreal-engine) | 官方文档 | Unreal 实例化 | 2026-11-21 |
| [Three.js InstancedMesh](https://threejs.org/docs/#api/en/objects/InstancedMesh) | 官方文档 | Three.js 实例化 | 2026-11-21 |
| [Three.js LineBasicMaterial](https://threejs.org/docs/#api/en/materials/LineBasicMaterial) | 官方文档 | 线宽限制 | 2026-11-21 |
| `godot-flowfield/docs/perf/REPORT.md` + CSV/JSON | 项目实测 | 本报告 §4 全部性能数字 | 2026-11-21 |
| `godot-wfc/docs/TECH.md` + `迭代记录.md` | 项目实测 | WFC 复杂度/性能 | 2026-11-21 |
| `godot-steering/docs/TECH.md` + `迭代记录.md` | 项目实测 | Steering 公式/性能 | 2026-11-21 |

### 7.5 相对父任务（T-009）与 T-011 新增了什么

- **新增**：本报告（原理/选型/性能因果/工程方法/跨引擎移植）与交互 HTML。
- **新增**：`docs/portable/` 三个引擎无关文件，其中样例场 835 可达与 smoke 一致，可作为移植 golden data。
- **新增**：`docs/algorithm-demos-index.md` 总索引，把 WFC/Steering/Flow Field 的 README、TECH、迭代记录、perf、视频与本报告串起来。
- **更新**：`TECH.md` §6 增加审计级结论与链接；`迭代记录.md` 追加 T-012 文档沉淀记录；README 增加原理报告入口。
- **不改**：游戏代码、资产、默认视觉、默认性能行为（T-011 的开关仍只由 bench 使用）。
- **相对 T-011**：T-011 给出“是什么/多少”，本报告补充“为什么/怎么选/怎么移植/怎么验收”，并把 500→1000 变平、平均 FPS vs hitch、测量局限讲清楚。

---

## 附录 A：一页速查

```text
流场三步：
  cost[] --多源BFS--> integration[] --最陡下降--> flow[]

四条不变量：
  目标=0；可达格有父格；流场严格单调；不可达=INF+零向量

五个参数：
  30Hz 逻辑；半径 0.17 cell；速度 2.9 cell/s；分离半径 0.391 cell（半径×2.3）；拖尾 6 点/5 段

三条性能结论（T-011）：
  AA 关是最大单因（1.65×/1.46×）
  半采样在 AA 关后显现（+71%）
  10Hz 买 CPU 余量（逻辑预算 55%→48% / 68%→51%）

三条验收：
  P95 + hitch，不只看 avg FPS
  同轮归一，不跨环境比绝对 FPS
  smoke/确定性先过，再谈优化
```

## 附录 B：术语

| 术语 | 含义 |
| --- | --- |
| 代价场（cost field） | 每格是否可走/通行代价 |
| 积分场（integration field） | 每格到最近目标的累计代价（本实现为 BFS 步数） |
| 流场（flow field） | 每格指向积分更小邻格的单位向量 |
| 多源 BFS | 所有目标同时作为起点，天然得到“最近目标” |
| 最陡下降 | 每格选择积分最小的邻格 |
| 禁斜穿墙角 | 对角移动要求两侧正交格都可走 |
| 双线性采样 | 四角按面积权重混合方向，平滑转弯 |
| 空间哈希 | 将单位按网格分桶，近邻查询均摊 O(1) |
| hitch | 帧间隔超过阈值（33.3/50 ms）的帧 |
| 同轮归一 | 每轮内配置相对同轮 baseline 的比值，抵消负载漂移 |
