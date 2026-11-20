# B 站《Rogue 类游戏是如何自动生成关卡的？》拆解：四种算法、一个原则与可复刻清单

> 对象：B 站 **BV14Un16fEvz**《Rogue类游戏是如何自动生成关卡的？程序化生成算法原理解析 | 程序化生成 / 地牢设计 / 随机地图》
> UP 主：赛博门外憨 · 时长 7:31 · 上传 2026-10-23 · [视频链接](https://www.bilibili.com/video/BV14Un16fEvz)
> 原片：Rogue's Den《How Do Roguelikes Actually Generate Their Levels?》(YouTube, 7:34)，B 站版画面与英文硬字幕与原片内容一致，并叠加了中文字幕（据简介链接与逐帧核对）。本文以 **B 站版时间点** 为准（±2s），原片章节时间会早约 5–22s。
>
> 交互版：[procedural-generation-teardown-交互版.html](procedural-generation-teardown-交互版.html)（本地 http server 打开；含四个可交互演示）。
>
> 采集方式：`yt-dlp 2026.08.19` 拉取 720p 视频与元数据；B 站未提供 CC 字幕（`x/player/v2` 的 `subtitle.subtitles=[]`），因此用 **ffmpeg 抽帧（全程 1/3s，关键段 1s）+ 画面硬字幕** 理解内容，并用原片自动字幕交叉核对。没有用标题猜算法。
>
> 版权：本文只做技术转述，不复制视频画面、音频或字幕原文；HTML 中的时间轴、BSP/CA 图、房间路径图均为原创 SVG/Canvas。demo 代码是按视频描述的算法独立重写。

---

## 0. 结论先行

| 问题 | 结论 |
| --- | --- |
| 视频实际讲了哪几种生成算法？ | **元胞自动机（4-5 规则）**、**Spelunky 式“先保证路径，再填房间模板”**、**BSP 二叉空间分割**、**醉汉漫步（Drunkard's Walk）**。Gungeon 的手工房间池是第二种的工业版。 |
| 只是被提到、没有展开的？ | **WFC**（Caves of Qud 一句带过）、Dwarf Fortress 的历史模拟；结尾一闪而过的 Poisson Disk / Delaunay / L-System / Perlin / Marching Squares / Simplex 等。视频**没有**讲锁钥/图结构生成。 |
| 最值钱的一句设计原则？ | **先保证可玩路径/连通性，再随机装饰。**（Spelunky 段 3:45–3:57）随机只负责变化，不负责保证。 |
| 最值钱的警告？ | **Procedural Oatmeal**：一千碗技术上不同、体验上一样的燕麦粥。堆算法不等于好玩（6:25–7:07）。 |
| 视频没讲、落地必须补的？ | 连通性 BFS 验证、种子策略、难度曲线、模板连接口校验。本文放在“落地扩展”，不冒充视频内容。 |
| 最小落地顺序？ | 先做一种拓扑（CA 洞穴或 Spelunky 路径）→ BFS 验证/修复 → 再谈模板与装饰 → 最后加难度预算与种子回放。 |

---

## 1. 视频结构（B 站版时间轴）

| 时间 | 段落 | 视频里实际出现的内容 |
| --- | --- | --- |
| 0:00–0:42 | 开场问题 | 程序化洞穴不是美术摆的；一个简单规则就能生成。片头用 `SEED: 2137` 演示同种子两次生成 100% 相同的图（0:27–0:36）。种子机制本身属于前作，本片没有展开。 |
| 0:43–2:48 | 元胞自动机 | 随机填充 45% 墙 / 55% 地板（1:00）；数 8 邻域（1:12–1:24）；墙 ≥4 邻域保持墙，地板 ≥5 邻域变墙；重复迭代后出现洞穴（1:30–1:42）；“4-5 规则”（1:48）；把阈值改成单一 4 后变成散落小块，再用走廊连接（2:00–2:21）；Brogue 实机（2:36–2:48）。 |
| 2:49–4:38 | 房间 / 走廊 / 模板 | 想要“像人设计”的房间（2:49）；Spelunky：4×4 房间网格、入口在上、出口在下（3:12–3:20），先走一条只允许左/右/下的黄金路径（3:20–3:38），路径确定后才从房间模板库填房间（3:39–3:45）；“先保证路径，再随机装饰”（3:45–3:57）；Enter the Gungeon：手工房间 + 少量随机，按战斗/陷阱/隐藏/Boss 分类，生成器只决定选哪些、放哪里（3:57–4:29）。 |
| 4:39–5:28 | BSP | 一个大矩形代表整层；随机横/竖切半，递归切到房间大小（4:42–5:00）；每个叶节点放一个房间（5:00–5:08）；相邻房间用走廊连接（5:08–5:12）；视频总结：房间不会重叠、布局整洁易连接（5:12–5:22）。 |
| 5:29–5:41 | 醉汉漫步 | 一个挖掘者在网格上随机跌撞，边走边挖出蜿蜒的有机隧道；“这真的就是它的名字”。 |
| 5:42–6:11 | 更复杂的例子 | Dwarf Fortress 模拟地质/文明/数千年历史（5:42–5:53）；Caves of Qud 除了地图还用 WFC 等复杂算法，并生成历史、冲突、传记、派系恩怨（5:54–6:11）。 |
| 6:12–6:24 | 工具箱观点 | 程序化生成不是“一个秘密算法”，每个开发者按想要的手感挑工具（多个游戏实机混剪）。 |
| 6:25–7:07 | Procedural Oatmeal | Kate Compton 的“程序化燕麦粥”：一千碗燕麦粥，技术上各不相同，体验上仍是燕麦粥（6:35–6:58）；堆复杂系统不等于更好玩，关键是少量聪明的选择 + 开发者的手（7:00–7:07）。 |
| 7:08–7:31 | 结尾 | 频道订阅、系列视频、下期预告。 |

> 说明：B 站版与原片内容一致，但剪辑导致章节点整体后移。比如原片 BSP 章节从 4:17 开始，B 站版实际在 **4:39** 才出现 BSP 标题；本文一律用 B 站版时间。

---

## 2. 四种算法：视频讲了什么、怎么实现、怎么调

### 2.1 元胞自动机：4-5 规则（0:43–2:48）

**视频的核心叙述**

1. 建一个网格，每格按 45% 概率放墙、55% 放地板（1:00）。
2. 对每个格子数它周围有多少个墙邻居（视频用 8 邻域，1:12）。
3. 墙格子：邻居墙数 **≥4** 就继续当墙，否则变地板。
   地板格子：邻居墙数 **≥5** 才变墙，否则继续当地板（1:12–1:24）。
4. 迭代一次几乎没变化；迭代几次后，随机噪声“坍缩”成洞穴、蜿蜒隧道和开阔洞厅（1:30–1:42）。
5. 这个规则在经典 Roguelike 里太常见，通常直接叫 **4-5 规则**；Brogue 的洞穴就是这一族算法（1:48–2:48）。

**伪代码（与视频画面一致，1:09 / 1:21）**

```text
# 初始化：45% 墙，55% 地板
for y in height:
    for x in width:
        grid[y][x] = WALL if random_percent() <= 45 else FLOOR

# 一次规则更新（同时更新到 new_grid）
for y in height:
    for x in width:
        n = count_wall_neighbors_8(grid, x, y)   # 越界按墙算
        if grid[y][x] == WALL:
            new_grid[y][x] = WALL if n >= 4 else FLOOR
        else:
            new_grid[y][x] = WALL if n >= 5 else FLOOR
grid = new_grid
# 重复 4–6 次，直到洞穴形态稳定
```

**参数与调参直觉**

| 参数 | 视频取值 | 直觉 |
| --- | --- | --- |
| 初始墙比例 | 45% | 低于 40% 容易变成大空地；高于 50% 容易全是墙/碎洞。45–48% 是常用起点。 |
| 墙保留阈值 | 4 | 越小，墙越容易被保留 → 洞穴更封闭、更碎。 |
| 地板变墙阈值 | 5 | 比墙阈值更保守，避免地板被大量吞掉；这是 4-5 规则名字的由来。 |
| 迭代次数 | 4–6 次 | 1–2 次噪声还在；太多会过度平滑、洞穴变大变圆。以“形态稳定”为准，不要死记次数。 |
| 邻域 | 8 邻域（Moore） | 斜角邻居也计入；换成 4 邻域会更“正交/方正”。 |
| 边界 | 越界算墙 | 让洞穴保持封闭；越界算地板会把地图边缘吃掉。 |

**视频里最关键的调参实验：把规则改成“单一阈值 4”**

在 2:00–2:21，视频把原规则的 4/5 两个阈值换成一个 4：结果不再是一整片连通洞穴，而是很多散落的小块；再用几条走廊把它们连起来，就得到“洞穴 + 通道”的可玩地图。这个实验说明：

- **阈值不是装饰参数，直接决定拓扑**：4/5 偏向连通大洞穴，4/4 偏向碎洞。
- **碎洞不是废图**：可以用走廊连接成“洞室群”，但必须做连通性验证（见 §4）。
- 这也是“生成 + 后处理”思想的早期版本：先生成形态，再做连通修复。

**常见坑**

- 只迭代一次就说“算法没效果”；实际要重复到稳定。
- 邻域/边界规则与碰撞检测不一致：生成用 8 邻域、可行走判定用 4 邻域，导致视觉上连着的洞走不过去。
- 不清理小碎洞：大量 1–7 格的小地板会让地图看起来像噪点。
- 不验证连通性：4-5 规则通常不错，但不保证 100% 连通；必须 BFS。

**适合的 Rogue 玩法**：洞穴探索、生存、Brogue 式传统 Roguelike；不适合需要严格房间/门/锁结构的战术关卡。

**本仓库 demo 实测（seed 2137）**：45% 初始墙、5 次迭代，得到 52.7% 地板、一个连通洞穴；把规则改成 4/4 后，修复前有 8 个连通块，用 2 条走廊连成 1 块（15.5% 地板）。见 §5 的验证输出。

---

### 2.2 房间 + 走廊 + 模板：Spelunky / Gungeon 的“手工感”（2:49–4:38）

**视频的核心叙述**

- 洞穴适合“有机、混乱”的感觉；如果你要的是**清晰的房间、合理的平台跳跃**，那是另一套算法（2:49–2:57）。
- Spelunky 的创作者 Derek Yu 记录过完整流程（3:00–3:06）：
  1. 先铺一个 **4×4 的房间网格**，入口放在顶部，出口放在底部某处（3:12–3:20）。
  2. 从入口开始，**只允许向左、向右、向下**，一个房间一个房间地走，刻出一条保证存在的路径（3:20–3:38）。
  3. **只有路径确定之后**，才从房间模板库里选房间填充；每个模板根据它需要的连接方向提供门/通道（3:39–3:45）。
  4. 模板内部再撒一点随机（敌人、障碍、道具）。
- 视频把原则总结成一句：**先保证路径，再随机装饰**（3:45–3:57）。所以 Spelunky 的关卡不会像“无意义噪声”，因为房间看起来像人设计的（3:57–4:06）。
- Enter the Gungeon 是同一思路的工业版：每个房间都是手工设计 + 少量随机，按**战斗、陷阱、隐藏、Boss** 分类；生成器只决定这一局选哪些房间、放在楼层哪里（3:57–4:29）。

**伪代码（黄金路径 + 模板填充）**

```text
rooms = 4
grid  = 4x4 empty room slots

entrance_col = random(0..rooms-1)
exit_col     = random(0..rooms-1)
path = [(0, entrance_col)]

row = 0
while row < rooms-1:
    # 只在当前行左右移动，然后向下；不允许向上
    target = clamp(col + random(-k..k), 0, rooms-1)
    move horizontally to target, marking each slot
    row += 1
    mark (row, col)
    path.append((row, col))

# 此时 path 已经保证从顶到底连通
for each slot in path:
    template = pick_template(
        room_type    = weighted_by_depth(row),
        connectors   = [direction to prev/next path slot] + optional side doors
    )
    place(template, slot, rng)

# 可选：挂接支线房间
for each non-path slot adjacent to a path room:
    if random() < side_branch_chance:
        place(side_room_template, slot)
        carve_door_between(slot, path_room)
```

> 视频只讲了“黄金路径 + 模板库 + 连接方向 + 模板内随机”。上面的 `room_type` 权重、连接口元数据、支线概率是实现细节，属于**落地扩展**，不是视频原话。

**参数与调参直觉**

| 参数 | 建议起点 | 直觉 |
| --- | --- | --- |
| 房间网格 | 4×4（视频） | 太小没变化，太大路径太长；4×4–6×6 适合单层关卡。 |
| 黄金路径 | 每行 1–3 个房间，只左/右/下 | 保证入口到出口可达；不要允许“上”，否则可能绕回/死循环。 |
| 路径宽度 | 1 个房间 | 主路径必须唯一、清晰；支线可以多。 |
| 模板池 | 12–30 个/类型 | 太少重复，太多质量难控；按房间类型和深度分组。 |
| 连接口 | 每个模板声明 N/E/S/W | 生成器只选连接口匹配的模板；不匹配就换模板或旋转。 |
| 支线概率 | 20–40% | 提供探索感；支线必须能回到主路径或形成环路。 |
| 模板内随机 | 0–3 个障碍 + 1–2 组敌人 | 保持“手工感”；不要把门/唯一通道堵死。 |

**常见坑**

- **模板门位不匹配**：路径要求“左进右出”，模板只有左门，生成出死胡同。
- **装饰堵路**：石头/箱子随机放在唯一通道上；模板必须声明“不可占用的连接格”。
- **路径太直**：每行都直下，虽然连通但像电梯；需要左右移动和支线。
- **出口不可达**：如果先填房间再找路，后填的模板可能把路堵了；视频的顺序正好相反。
- **重复感**：同一模板连续出现；用“最近 N 个不重复”或权重衰减。
- **难度尖峰**：Boss 房旁边直接接高难战斗房；用深度预算和“安全房”缓冲。

**适合的 Rogue 玩法**：平台跳跃 Roguelike（Spelunky）、房间制地牢（Gungeon、Isaac）、需要手工关卡质感的游戏；不适合强调连续有机地形的洞穴探索。

**本仓库 demo**：`generate_golden_path()` 实现 4×4 槽位、入口顶行、出口底行、只左/右/下的路径、路径房间模板和中心十字保通；BFS 验证入口到出口可达。

---

### 2.3 BSP 二叉空间分割（4:39–5:28）

**视频的核心叙述**

1. 用一个矩形代表整层地牢（4:42）。
2. 随机选择横切或竖切，把它切成两半（4:45）。
3. 对每一半继续切，直到每块大约是一个房间的大小（4:48–5:00）。
4. 停止切割后，在每个最终叶节点里放一个房间（5:00–5:08）。
5. 用走廊连接相邻房间（5:08–5:12）。
6. 视频总结 BSP 自动保证两件事：**房间不会重叠**、**布局整洁、容易用走廊连接**（5:12–5:22）。

**伪代码**

```text
function split(node, depth):
    if depth >= max_depth or node is small enough:
        leaves.append(node)
        return
    axis = choose_axis(node, rng)       # 横 / 竖
    cut  = random_between(min_ratio, max_ratio) * node.size(axis)
    left, right = node.cut(axis, cut)
    split(left, depth+1)
    split(right, depth+1)

split(Rect(0, 0, W, H), 0)

for leaf in leaves:
    room = random_rect_inside(leaf, padding=1, min_size=3)
    carve(room)

for each pair of neighbouring rooms (or a spanning tree over rooms):
    carve_L_corridor(center(a), center(b))
```

**视频没有展开、但落地必须处理的点**

- “相邻房间”怎么定义？可以按 BSP 树兄弟节点连接，也可以对所有房间做最近邻生成树。后者更简单，且天然连通。
- 走廊穿过其他房间怎么办？允许穿过通常没问题，甚至更自然；但要做“门/墙”视觉处理。
- 视频说“房间不重叠、易连接”，**没有说自动保证全图可达**；工程上仍要 BFS 验证。

**参数与调参直觉**

| 参数 | 建议起点 | 直觉 |
| --- | --- | --- |
| 最小叶节点 | 8–12 格 | 太小会切出细条；太大房间少、重复感强。 |
| 最大深度 | 4–6 | 控制房间数量；深度越大房间越多。 |
| 切分比例 | 0.35–0.65 | 避免切出极薄的长条；太居中则布局太规整。 |
| 房间内边距 | 1–2 格 | 留墙，避免房间贴边。 |
| 房间最小尺寸 | 3×3 | 小于 3×3 基本不可玩。 |
| 走廊宽度 | 1–2 格 | 1 格适合紧凑迷宫，2 格更适合战斗/寻路。 |
| 连接方式 | 最近邻生成树 / BSP 兄弟 | 最近邻简单且连通；兄弟连接更有层次感。 |

**常见坑**

- 切出 1 格宽的长条房间；用最小叶节点和切分比例限制。
- 只连接 BSP 兄弟，漏掉跨子树连接；BFS 一验就发现多个连通块。
- 走廊从房间中心直穿，破坏房间形状；可以在房间边缘开门，或让走廊沿墙走。
- 地图太规整、每局都像同一张图；加入随机切分、房间尺寸变化、非矩形房间/圆角。
- 房间数太多导致敌人/道具预算失控；把房间数和深度预算绑定。

**适合的 Rogue 玩法**：结构化地牢、战术/回合制 Roguelike、需要明确房间边界的游戏；不适合追求有机洞穴的游戏。

**本仓库 demo**：`generate_bsp()` 递归切分 64×32 地图，叶节点放房间，最近邻生成树 + L 形走廊连接；验证 21 个种子全部连通、房间零重叠。

---

### 2.4 醉汉漫步 Drunkard's Walk（5:29–5:41）

**视频的核心叙述**

- 一个“喝醉的挖掘者”在网格上随机跌撞，每走一步就挖开脚下的格子，最后形成蜿蜒的有机隧道（5:29–5:41）。
- 视频只给了概念和两段可视化，没有展开终止条件、刷子大小、多个挖掘者等细节。
- 紧接着的 Dwarf Fortress / Caves of Qud 是“更复杂的程序化系统”的例子，**视频没有说它们用的是醉汉漫步**；不要混淆。

**伪代码**

```text
grid = all WALL
x, y = center
carve(x, y)                       # 可选用 3×3 刷子
while carved_floor < target and steps < max_steps:
    dx, dy = random cardinal direction
    # 可选：靠近边界时向中心偏置，避免贴边
    x, y = clamp(x+dx, 1..W-2), clamp(y+dy, 1..H-2)
    carve_brush(x, y, radius=1)
    steps += 1
```

**参数与调参直觉**

| 参数 | 建议起点 | 直觉 |
| --- | --- | --- |
| 目标地板比例 | 35–45% | 太低洞穴太小；太高变成大空洞。 |
| 最大步数 | 1000–3000 | 防止死循环；按目标比例提前停。 |
| 刷子大小 | 1×1 或 3×3 | 1×1 隧道细、3×3 更像洞穴；3×3 更容易连通。 |
| 边界偏置 | 靠近边缘时向中心 | 否则挖掘者容易贴着地图边挖，形状难看。 |
| 多挖掘者 | 2–4 个 + 后期连接 | 增加洞室；但每个挖掘者各自连通，必须再做连通修复。 |

**常见坑**

- 多个挖掘者各挖各的，最后是多个孤岛；必须 BFS + 连走廊。
- 没有目标比例，随机游走可能一直在一个小区域打转。
- 贴边、贴角；加边界偏置或限制活动范围。
- 只挖 1 格宽，战斗/寻路很挤；用 3×3 刷子或后期拓宽。
- 每局形状都差不多；改变步数、刷子、偏置、多个起点。

**适合的 Rogue 玩法**：洞穴、地下城、Metroidvania 式连通洞室；适合快速原型，正式关卡通常要加验证与装饰。

**本仓库 demo**：`generate_drunkard()` 单挖掘者、3×3 刷子、40% 目标地板；起点/终点用 BFS 最远点对自动选择；21 个种子全部连通。

---

### 2.5 视频只“点名”但没有展开的内容（不要假装它讲了）

| 内容 | 视频里的位置 | 实际程度 | 本文处理 |
| --- | --- | --- | --- |
| WFC（Wave Function Collapse） | 5:54–6:00，Caves of Qud 一句带过 | 只提名字，没讲原理 | 只标注“何时考虑”；不展开成教程。 |
| Dwarf Fortress 世界模拟 | 5:42–5:53 | 举例，未拆算法 | 作为“程序化不止地图”的例子。 |
| Poisson Disk / Delaunay / L-System / Perlin / Marching Squares / Simplex | 7:00–7:02 的掉落标签 | 一闪而过 | 只列名字，说明它们属于更大的工具箱。 |
| 锁钥 / 图结构 / 任务依赖 | 全片没有 | 未出现 | 明确标注为**视频外扩展**，见 §4.4。 |
| 连通性验证 / BFS | 全片没有 | 未出现 | 落地扩展，§4.1。 |
| 难度曲线 | 全片没有 | 未出现 | 落地扩展，§4.3。 |

> 这一节是本文的“防幻觉”边界：视频讲的是**CA、房间/模板、BSP、醉汉漫步**四个核心算法 + 一个设计理念；WFC 只是一个名字，锁钥/图结构根本不在视频里。

---

## 3. 从“随机噪声”到“可玩地牢”：三条工程底线

### 3.1 连通性 / 可玩性验证（视频未讲，落地必需）

生成完地图后，至少做以下检查：

```text
1. 4 邻域 BFS/flood fill 所有地板，得到连通块集合
2. 断言：连通块数量 == 1（或者：最大连通块占比 >= 95%）
3. 断言：起点和出口在同一个连通块
4. 断言：所有可交互物（钥匙、宝箱、NPC、Boss 门）可达
5. 统计：可达地板比例、死胡同数量、平均走廊宽度、起点到出口距离
6. 如果不通过：修复（连接最近连通块）或换种子重试
```

**修复策略（按成本从低到高）**

| 策略 | 做法 | 代价 |
| --- | --- | --- |
| 丢弃小碎块 | 把 <8 格的地板填回墙 | 损失一点内容，最快 |
| 连走廊 | 找最大连通块与其它块的最近点对，挖 L 形走廊 | 可能破坏美术/房间边界 |
| 重试 | 换种子重新生成 | 简单，但不可控；需要重试上限 |
| 设计保证 | BSP 用生成树连接、Spelunky 先保路径 | 最稳，但算法约束更强 |

**可玩性指标（不只是“连通”）**

- 起点→出口的最短路径长度（太短=无聊，太长=疲劳）。
- 死胡同比例（探索感 vs 迷路感）。
- 房间/洞室数量与面积分布（避免全是小碎洞或一个大空洞）。
- 关键资源可达性（钥匙、补给、Boss 房）。
- 战斗空间宽度（1 格走廊不适合大型敌人）。

### 3.2 种子与可复现性

片头用 `SEED: 2137` 演示同一 seed 两次生成完全相同的图（0:27–0:36）。落地时建议：

- **所有随机都走注入的 RNG**：布局、敌人、掉落、装饰各用独立流（`layout_rng`、`enemy_rng`、`loot_rng`），避免“多放一个敌人导致地图全变”。
- **记录 seed + 算法版本 + 参数**：存档/回放/QA 都靠它复现。
- **黄金种子测试**：固定一批 seed，断言地图 hash、连通性、起点/出口距离不漂移。
- **不要用全局随机**：`random.random()` / `Math.random()` / 未播种的引擎 RNG 都会让复现失败。
- **跨语言/跨引擎注意**：浮点噪声、取整、哈希遍历顺序都可能不同；演示 demo 用整数 xorshift32，同 seed 的序列在 Python/JS 中一致；Godot 用 `RandomNumberGenerator` 时建议锁引擎版本并跑黄金样本。

**本仓库 demo 的做法**：`XorShift32(seed)` 是唯一随机源；`verify.py` 验证“同 seed 两次生成签名相同、相邻 seed 签名不同、21 个 seed 全部连通”。

### 3.3 难度曲线（视频未讲，落地必需）

不要“随机撒怪”，而是给每个深度一个**预算**：

| 深度 | 房间数 | 敌人预算 | 模板权重 | 特殊房 |
| --- | --- | --- | --- | --- |
| 1 | 6–8 | 4–6 | 基础战斗 80% / 陷阱 10% / 商店 10% | 教学房、第一把钥匙 |
| 2 | 7–9 | 6–9 | 基础 65% / 陷阱 20% / 隐藏 15% | 商店、精英 |
| 3 | 8–10 | 9–13 | 基础 50% / 陷阱 25% / 隐藏 25% | 锁钥门、分支路线 |
| 4 | 8–12 | 12–17 | 基础 40% / 陷阱 30% / 隐藏 30% | 精英、Boss 前安全房 |
| 5 | 9–12 | 16–22 | 基础 30% / 陷阱 35% / 隐藏 35% | Boss、奖励房 |

原则：

- **预算曲线**比单点随机更能控制体验；每层有“上限”和“下限”。
- **安全房/商店**放在高难段之间，形成呼吸节奏。
- **路径长度**和敌人预算挂钩：路径越长，补给越多。
- 用种子回放做难度回归：同一 seed 的敌人数、资源数、Boss 位置应可复现。

---

## 4. 视频外扩展：锁钥/图结构（视频完全没讲）

> 视频没有讲锁钥、任务依赖或图生成。下面只作为“如果你要做 Isaac/Gungeon 式关卡”的补充，**不计入视频内容**。

如果要在房间图上加锁钥：

1. 先生成房间连通图（BSP 最近邻树、Spelunky 路径 + 支线、Gungeon 房间图）。
2. 选一棵生成树作为主路径；把钥匙放在锁的**祖先区域**，保证“先拿钥匙再开门”。
3. 用 BFS/拓扑排序验证：从起点出发，在拿到每把钥匙后，锁门后的区域可达。
4. 避免“钥匙在锁后面”的循环依赖；多把钥匙时用 key-door 二部图/拓扑顺序检查。
5. 隐藏房/商店不参与主路径，但要保证有入口。

这类玩法更像 Gungeon/Isaac 的“房间图 + 门 + 钥匙”，而不是视频里的地形生成；两者可以叠加，但不要把地形算法当成关卡节奏算法。

---

## 5. 可复刻清单：在 Godot / 代码里怎么落地

### 5.1 最小实现顺序（建议按这个顺序做，不要一上来做 WFC）

| 阶段 | 做什么 | 验收 |
| --- | --- | --- |
| 1 | 网格 + 瓦片枚举 + 种子 RNG 封装 | 同 seed 两次生成一致 |
| 2 | 先实现一种拓扑：CA 洞穴（最快出效果）或 Spelunky 黄金路径（最像“手工关”） | 能看到一张可走地图 |
| 3 | BFS/flood fill 验证 + 连通修复 + 起点/出口 | 所有可玩种子 100% 连通 |
| 4 | 加房间模板/装饰/敌人（模板声明连接口与不可占用格） | 装饰不堵路 |
| 5 | 加难度预算、房间类型权重、特殊房 | 3 层难度曲线可复现 |
| 6 | 加调试叠层：连通块着色、路径、房间编号、seed 显示 | 出问题能定位 |
| 7 | 再考虑 BSP / 醉汉漫步 / 多算法组合 | 每种都有黄金种子测试 |

### 5.2 Godot 4.6 关键点

- **地图**：`TileMapLayer` + `TileSet`；墙/地板/门/装饰分图层。Godot 4.3+ 用 `TileMapLayer.set_cell(coords, source_id, atlas_coords, alternative_tile)`。
- **随机**：`RandomNumberGenerator.new()`，显式 `rng.seed = level_seed`；不要用 `randi()` 全局函数。
- **验证**：`AStarGrid2D` 可做寻路，但连通性验证用简单 BFS 更直接；也可用 `AStarGrid2D.is_point_solid` + 自定义队列。
- **模板**：`PackedScene` 或 `Resource` 存房间模板；每个模板导出 `connectors: Array[String]`（N/E/S/W）、`blocked_cells`、`room_type`、`weight`。
- **黄金路径**：先算出 4×4 槽位路径，再实例化模板；模板连接口必须与路径方向匹配，不匹配就旋转/换模板。
- **测试**：`godot --headless -s tests/test_dungeon.gd`；固定 seed 列表，断言连通、出口可达、房间不重叠、同 seed hash 一致。

**最小 CA 片段（GDScript 伪代码）**

```gdscript
const WALL := 1
const FLOOR := 0
@export var level_seed: int = 2137
@export var width := 60
@export var height := 30

func generate() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = level_seed
    var grid := []
    for y in height:
        var row := []
        for x in width:
            row.append(WALL if rng.randf() < 0.45 else FLOOR)
        grid.append(row)

    for iteration in 5:
        var next := grid.duplicate(true)
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                var n := count_wall_neighbors_8(grid, x, y)
                if grid[y][x] == WALL:
                    next[y][x] = WALL if n >= 4 else FLOOR
                else:
                    next[y][x] = WALL if n >= 5 else FLOOR
        grid = next
    return grid

func count_wall_neighbors_8(grid: Array, x: int, y: int) -> int:
    var n := 0
    for dy in [-1, 0, 1]:
        for dx in [-1, 0, 1]:
            if dx == 0 and dy == 0:
                continue
            var xx: int = x + dx
            var yy: int = y + dy
            if xx < 0 or yy < 0 or xx >= width or yy >= height or grid[yy][xx] == WALL:
                n += 1
    return n
```

**最小 BFS 验证（GDScript 伪代码）**

```gdscript
func reachable(grid: Array, start: Vector2i) -> Dictionary:
    var seen := {start: true}
    var queue: Array[Vector2i] = [start]
    while not queue.is_empty():
        var p: Vector2i = queue.pop_front()
        for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
            var q: Vector2i = p + d
            if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
                continue
            if grid[q.y][q.x] == FLOOR and not seen.has(q):
                seen[q] = true
                queue.append(q)
    return seen
```

### 5.3 参数速查（按玩法选算法）

| 你想要的体验 | 首选 | 次选 | 关键参数 |
| --- | --- | --- | --- |
| 有机洞穴、探索感 | CA 4-5 规则 | 醉汉漫步 | 墙比例 45%；阈值 4/5；迭代 4–6 |
| 手工房间、平台跳跃 | Spelunky 黄金路径 + 模板 | BSP + 模板 | 4×4 网格；只左/右/下；连接口匹配 |
| 整洁地牢、战术战斗 | BSP | 房间图 + 生成树 | 最小叶 8–12；切分比例 0.35–0.65 |
| 快速原型、蜿蜒隧道 | 醉汉漫步 | CA | 目标地板 35–45%；3×3 刷子 |
| 房间图 + 锁钥 | 房间图（Gungeon 式） | BSP + 锁钥 | 拓扑排序验证；钥匙在锁的祖先区 |

---

## 6. 最小 demo 与验证

目录：`docs/procedural-generation-demos/`

| 文件 | 内容 |
| --- | --- |
| `generators.py` | 四个生成器 + XorShift32 + BFS/连通修复 + ASCII 渲染 |
| `verify.py` | 复现性、连通性、BSP 不重叠、黄金路径单调性、21 个种子扫描 |

**运行**

```bash
cd docs/procedural-generation-demos
python3 verify.py
python3 verify.py --maps     # 额外打印 seed 2137 的 ASCII 地图
```

**实测输出（seed 2137）**

```text
PASS ca          60x30  components 1->1, corridors +0, floor 52.7% sig=52cde5ffc1d3
PASS golden_path 29x29  4x4 rooms, path 6, floor 18.1%             sig=f7268076b52b
PASS bsp         64x32  16 rooms, corridor tiles 78, floor 36.0%   sig=d63a886e1e80
PASS drunkard    60x30  1785 steps, floor 40.1%                    sig=6325ec6c4028
CA VARIANT  single-threshold 4: components 8->1, corridors +2, floor 15.5% (video 2:00-2:21)

SEEDS OK ca          21/21 seeds connected
SEEDS OK golden_path 21/21 seeds connected
SEEDS OK bsp         21/21 seeds connected
SEEDS OK drunkard    21/21 seeds connected
REPRODUCIBLE same seed -> same signature; adjacent seed -> different signature
ALL_GENERATORS_OK
```

**黄金路径的 4×4 槽位（seed 2137）**

```text
. # # #
. . . #
# # . #
# # . #
```

`.` = 黄金路径经过的房间；`#` = 未使用槽位。路径从顶行入口开始，只左/右/下移动，最后落在底行出口。

**一个实现差异**：Python 的 CA demo 会先把小于 8 格的孤立地板填回墙，再连接剩余洞室（所以 seed 2137 的 4/4 变体是 8→1、+2 条走廊）；HTML 交互版不丢弃碎块，直接连接所有连通块（8→1、+7 条走廊）。两者都通过 BFS，差异来自“清理策略”，不是算法分歧。

**demo 的边界**

- 这是教学级最小实现：ASCII 地图、单层、无美术、无敌人、无锁钥。
- 不是生产级生成器：没有房间模板资源、没有性能优化、没有多算法混合、没有跨引擎一致性测试。
- 真实项目建议把生成器拆成“纯函数 + 数据契约”，Godot 只负责把网格/房间数据实例化成场景（与本仓库 `portable-core` 的思路一致）。

---

## 7. 来源与边界

### 7.1 视频与时间点

- B 站版：<https://www.bilibili.com/video/BV14Un16fEvz>（赛博门外憨，2026-10-23，7:31）
- 原片：Rogue's Den, *How Do Roguelikes Actually Generate Their Levels?*（YouTube, 2026-09-14, 7:34）<https://www.youtube.com/watch?v=4iBibkgpGeQ>
- 视频简介给出的章节（原片时间）：0:00 Intro / 0:44 Cellular Automata / 2:41 Levels that feel hand-designed / 4:17 BSP / 5:07 Drunkard's Walk & examples / 6:05 Procedural Oatmeal / 7:04 Outro。B 站版因剪辑整体后移，引用时以本文的 B 站时间为准。
- 视频提到的作品/人物：Brogue、Spelunky（Derek Yu）、Enter the Gungeon（Dave Crooks）、Dwarf Fortress、Caves of Qud、Kate Compton（procedural oatmeal）。
- 视频画面中的代码/伪代码只用于理解规则；本文 demo 为独立重写，没有复制视频代码或素材。

### 7.2 本文的确定性边界

- **确认是视频内容**：CA 的 45% 填充与 4-5 规则、阈值 4 的碎洞实验、Brogue 例子；Spelunky 的 4×4 / 入口顶 / 出口底 / 左-右-下黄金路径 / 后填模板 / “先路径后装饰”；Gungeon 的手工房间分类；BSP 的递归切分/叶节点房间/走廊/不重叠；醉汉漫步的随机挖掘；WFC 只在 Caves of Qud 被点名；procedural oatmeal 的 1000 碗燕麦粥。
- **属于本文扩展**：BFS 连通性验证、种子流拆分、难度预算、锁钥拓扑、模板连接口元数据、具体参数表、Godot 代码。文中均标注“落地扩展”或“视频没有展开”。
- **不确定点**：B 站版无 CC 字幕，本文依赖硬字幕 + 原片自动字幕；个别语气/数字（例如 45% 的具体写法）以画面为准。时间点 ±2s。若需要逐字稿，应使用人工校对，而不是本文。

---

## 8. 一页速查

```text
CA 4-5：随机 45% 墙 → (墙≥4留，地≥5变墙) × 4–6 → 碎洞/洞穴 → 连走廊 → BFS
Spelunky：4×4 槽位 → 入口顶/出口底 → 只左/右/下的黄金路径 → 再填模板/装饰
BSP：大矩形 → 随机横/竖切 → 叶节点放房间 → 最近邻/兄弟连走廊 → BFS
Drunkard：随机游走 + 刷子挖洞 → 目标地板比例 → 最远点对做起点/出口
通用：先保证连通与进度，再随机装饰；seed 可复现；难度按预算曲线
反例：一千碗燕麦粥 —— 变化不等于体验
```
