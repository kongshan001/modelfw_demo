# 技术说明 · 苔井工坊

## 1. 目标与边界

本项目的目标是“可运行的关卡编辑闭环”，不是 LDtk 的功能对等实现。闭环是：

```
网格画结构 → 四邻规则自动铺砖 → 图层/实体属性 → 编辑器 JSON ↔ 运行时 JSON → 预览可走场景
```

刻意不做的：世界地图、外部 tileset 导入、多层任意增删、复杂实体组件系统、完整战斗/寻路。这样能用最小系统验证工作流，同时把规则、数据和验证留在可测试的纯逻辑层。

技术约束：

- Godot 4.6 stable，`GL Compatibility` 渲染后端。
- 逻辑分辨率 1280×720；1920×1080 通过整数拉伸/离屏 SubViewport 截图验证。
- 无第三方运行时库；所有瓦片/图标/玩家精灵均由代码生成。
- 中文 UI 使用 `SystemFont`（PingFang SC / 微软雅黑 / Noto CJK 等系统回退）。
- 命令行在无 `.godot/` 导入缓存时也可运行：脚本之间的类型与静态访问使用本地 `preload` 常量，而不是依赖全局类缓存。

## 2. 架构

| 文件 | 职责 |
| --- | --- |
| `scripts/level_data.gd` | 纯数据模型（RefCounted）：地形/碰撞/实体、自动铺砖、校验、JSON 读写、撤销快照、示例关卡生成 |
| `scripts/tile_art.gd` | 程序化美术：16×16 瓦片（按类型+掩码+变体）、实体图标、玩家四向精灵，带缓存 |
| `scripts/editor_canvas.gd` | 网格画布 Control：局部坐标 ↔ 格子、平移/缩放、五类工具、实体拖动、绘制与预览层 |
| `scripts/editor.gd` | 主控与 UI：主题、工具栏、调色板、图层、属性面板、文件对话框、撤销/重做、预览接线 |
| `scripts/level_preview.gd` | 预览 Control：解析运行时 JSON、静态地图纹理、玩家移动/碰撞、宝箱拾取与 HUD |
| `scenes/editor.tscn` | 单入口场景；其余 UI 由 `editor.gd` 程序化搭建 |
| `levels/demo_level.json` | 36×20 示例关卡（保存格式） |
| `tools/` | smoke、1920 截图、10s 序列、FPS 探针、示例 JSON 生成 |

依赖方向是单向的：`editor.gd` → `editor_canvas.gd` / `level_preview.gd` / `level_data.gd`；`tile_art.gd` 只依赖自身；`level_preview.gd` 不引用编辑器 UI。数据层不依赖任何节点，所以 smoke 可以直接在 headless 里构造和验证。

## 3. 数据模型

```text
LevelData
├── width / height / cell_size / level_name
├── tiles[y][x] : null | { type, variant, mask }
├── collision[y][x] : 0 | 1
├── entities : [ { id, type, x, y, props } ]
├── layers : { terrain/collision/entities: { visible, locked } }
└── next_entity_id
```

- 坐标原点左上，`x` 向右、`y` 向下，实体坐标是格子索引。
- `type` 限 `grass/dirt/wall/water`；`variant` 限 `-1..2`；`mask` 限 `0..15`。
- 实体 props 用默认值合并，数字字段夹紧范围；`kind/loot` 是自由字符串，UI 给预设以减少输入。
- 保存用 `to_dict()`（包含 layers/next_entity_id），导出用 `to_runtime_dict()`（不带编辑器元数据）。
- 载入先解析/校验到临时数组，全部通过后才替换当前状态，避免“加载失败但关卡被改了一半”。
- `snapshot()/restore()` 用于撤销；`from_dict()` 是唯一的结构校验入口。

完整字段见 [schema.md](schema.md)。

## 4. 自动铺砖

### 4.1 四邻掩码

方向位：

```
北=1  东=2  南=4  西=8
```

`compute_mask(x, y, type)` 对上下左右四个邻居调用 `_joins_with`：

- **草/土** 共享“地面组”：邻居是草或土都算连接。
- **石墙** 只有邻居也是石墙才算连接。
- **水面** 只有邻居也是水面才算连接。

石墙的连接掩码决定外露边：例如中段 `东|西 = 10` 两侧不画描边，转角 `南|西 = 12` 只在北、东两侧描边，端点只有一个方向连接。水面的非连接方向生成泡沫岸线；草/土的非连接方向压暗并生成草叶。

### 4.2 实时更新与手动覆盖

- `paint_terrain(..., auto_update=true)`：写入当前格后，计算本格并重算 `3×3` 邻域内的自动格。
- `erase_terrain(..., auto_update=true)`：擦除后同样重算邻域。
- 自动铺砖关闭时，画布只计算当前格掩码，不刷新邻居；数据层因此能保留“冻结”的旧边，点“重算铺砖”再统一刷新。
- `variant >= 0` 的格子是手动变体，`recalculate_autotiles(false)` 会跳过它们；`clear_manual_overrides()` 才会把变体恢复为 `-1` 并重算。
- 矩形/直线批量落笔时先逐格写入且 `auto_update=false`，最后对包围盒扩张 1 格做一次 `autotile_area()`，避免每格重复扫描。
- 掩码烘焙进 JSON（`mask` 字段），外部游戏可直接按掩码取图；若外部改了地形，需要按同一规则重算。

### 4.3 为什么这样选

- 只用四邻而不是 8 邻：规则容易解释、规则与 tile 生成一一对应、转角效果已能覆盖 MVP；避免为了 47-tile 模板引入 tileset 编辑器。
- 规则在数据层而不是绘制层：可以在 headless smoke 中验证，不受渲染影响；也保证保存的 mask 与画面一致。
- 手动变体是“视觉覆盖”而非改变地形类型：保持碰撞/预览语义稳定。

## 5. 画布与工具

### 5.1 坐标与像素对齐

- `cell_size ∈ {16,32,48}`，`zoom ∈ {1,2,3,4}`，全部整数；格子屏幕像素 `px = cell_size * zoom`。
- 地图原点：`base = (canvas_size - map_size)/2 + pan`，最终 `round()`。
- 画布 `texture_filter = NEAREST`，tile 纹理按 16px 基准整数倍绘制；平移/缩放后起点仍取整，避免半像素采样。
- 滚轮缩放以鼠标为中心：先记录鼠标下的格坐标，改变 zoom 后反算 pan，使该格保持在鼠标下。
- 中键/空格+左键拖拽平移；平移限制保留至少 72px 地图可见，避免地图拖丢。

### 5.2 工具状态机

`tool ∈ {select, brush, eraser, rect, line, picker}`，`layer_id ∈ {terrain, collision, entities}`：

- **select**：点选格子；实体层可选中并拖动实体（第一次移动时才开始撤销动作），Delete 删除。
- **brush**：地形/碰撞按格连续绘制；实体层变为“放置”，点击空格创建实体并自动选中。
- **eraser**：按格/按拖拽擦除地形/碰撞；实体层删除经过的实体。
- **rect/line**：只在按下时记录 anchor，拖拽期间仅显示预览；松开才一次性写入并生成单条撤销记录。实体层会提示改用放置/选择。
- **picker**：地形层拾取类型和变体并切回画笔；实体层拾取实体类型；碰撞层显示状态。
- 隐藏/锁定图层时禁止编辑，并在 Toast 中说明原因。
- 鼠标移出画布会安全地结束当前笔画/取消范围预览，避免丢失 release 事件导致撤销动作悬挂。

### 5.3 绘制顺序

```
背景点阵 → 地图阴影/边框 → 地形 → 碰撞层（激活高对比，非激活淡提示）
→ 网格 → 实体 → 范围预览 → 选中 → 悬停 → 坐标/HUD
```

可见区域裁剪：只遍历当前画布范围内的格子。坐标标签在 `px >= 24` 时绘制，并在鼠标不在网格内时显示“选中 x,y”。

## 6. 图层与实体属性

- 三个固定图层各自有 `visible/locked`；点击图层名切换活动层，眼睛/锁按钮即时生效并写入编辑器 JSON。
- 画布与数据层都做锁/隐藏保护，避免只靠 UI 禁用。
- 属性面板是程序化重建的：选中实体时显示类型图标、id、位置 SpinBox、类型相关字段、JSON 路径提示和删除按钮；选中格子时显示地形/变体/掩码/外露边、恢复自动按钮、碰撞切换。
- 位置编辑会检查地图边界和实体占用；非法目标会回滚字段并 Toast，不产生撤销记录。
- 属性修改以“修改前快照 → 修改 → 比较 JSON → 记录撤销”的方式落地。

## 7. 撤销 / 重做

采用整图快照而不是命令模式：

- 画笔拖动在按下时 `begin_action()` 保存快照，松开时比较前后 JSON，有变化才入栈；一次拖拽只算一步。
- 矩形/直线、属性编辑、地图尺寸/格子大小、重算、清空/重置通过 `_record_history()`/`_mutate_with_undo()` 记一步。
- 栈上限 80。撤销把当前快照推入 redo 栈，恢复 before；重做反向。
- 快照包含 tiles/collision/entities/next_entity_id/尺寸/名字；图层显隐/锁定、画笔变体选择属于会话 UI，不进入撤销。
- 快照是 JSON 结构深拷贝并通过字符串化比较，简单可靠；代价是大地图大笔画的内存/时间，当前 96×96 上限仍可接受。

## 8. 保存 / 加载 / 导出 / 预览

### 文件

- 保存：编辑器 JSON；当前路径为空时弹 `FileDialog`，之后 Ctrl/Cmd+S 直接覆盖。
- 加载：读取 → 新 `LevelData.from_json` → 成功后才替换当前关卡并清空撤销/重做。
- 导出：运行时 JSON → `user://exports/`；同时打开只读 JSON 检视面板（可复制到剪贴板）。
- 路径默认 `user://levels` / `user://exports`；内置示例从 `res://levels/demo_level.json` 读取。

### 预览

- 点击运行预览时，将当前 `LevelData` 序列化为**运行时 JSON**，再由 `LevelPreview.load_json()` 从零解析；不是把编辑器对象直接传给预览。
- 静态地图在载入时**一次性合成为 ImageTexture**（每格 16px 基准），每帧只画一张地图 + 动态实体/玩家/水面闪光，避免几百个 tile 每帧重绘。
- 移动：WASD/方向键，按轴分离 + 子步进，防止大 delta 穿透；采样玩家 AABB 四角所在的格。
- 阻挡：碰撞格、石墙、水面、地图外。
- 宝箱：距离格中心 ≤ 0.62 格时拾取，HUD 显示 `loot × amount`、宝箱计数。
- 校验结果（可走格数、实体数、警告）显示在预览顶栏；无出生点时从第一个可走格开始。
- 预览期间隐藏主编辑器 UI，避免它继续参与绘制；返回时恢复。

## 9. 程序化美术

`TileArt` 直接生成 `Image`（RGBA8）并缓存 `ImageTexture`：

- 草地：多色噪点 + 随机草叶；自动外露边压暗并在上缘长草。
- 泥土：暖褐噪点 + 小石子；外露边压暗；手动变体可长蘑菇。
- 石墙：交错砖块、灰缝、苔点；四邻掩码决定外露描边与顶部高光，连接处不画边，因此整段墙连续。
- 水面：蓝色渐变 + 波光带；非水侧生成泡沫虚线岸线；手动变体有睡莲/涟漪。
- 实体图标：旗帜（出生点）、苔团小妖（敌人）、木箱金扣（宝箱）；玩家是 16×20 的小园丁（草帽/外套/四向脸）。
- 所有颜色、形状、命名均为本项目原创；未使用外部图集。

UI 主题（深青面板、苔绿主色、暖金强调）也是代码构建的 `Theme`/`StyleBoxFlat`，不依赖预制资源。

## 10. 性能

- 编辑器画布只在数据/交互变化时 `queue_redraw`；绘制按视口裁剪。
- 预览地图合批为单张纹理后，实测预览在 Intel HD Graphics 6000 上反而高于编辑器（预览隐藏了编辑器 UI）。
- JSON 导出只在用户操作时执行；FPS 显示每 0.3s 更新一次；JSON 检视时隐藏 FPS 表（避免大 TextEdit 布局的瞬时值误导），退出后恢复。
- 截图/序列工具使用 SubViewport 离屏渲染，不受本机窗口最大尺寸限制；截图 1920×1080 的 2D 内容覆盖为 1280×720 逻辑再拉伸，保持 UI 比例。
- 最终实测（vsync 关闭，1280×720，Intel HD 6000，GL Compatibility）：

```
PROBE editor  avg=89.8  p5=62.5  min=50.0  frames=342
PROBE preview avg=105.6 p5=66.7  min=43.5  frames=297
LEVEL_EDITOR_FPS avg=97.7 min=43.5 target_avg=30 OK
```

逐帧最低值仍受 OS 调度/首次着色器影响；平均帧率与 5% 分位都远高于 30 FPS 目标。截图工具因每帧写 PNG，会拉低当时的瞬时 FPS 标签，因此演示视频隐藏了 FPS 表；正式 FPS 证据使用独立探针。

## 11. 测试与工具

- `tools/smoke_level_editor.gd`：134 项检查，覆盖纯数据、自动铺砖、矩形/直线、实体属性、撤销/重做、保存/加载 roundtrip、schema 拒绝、预览移动/碰撞/拾取，以及**真实画布 `_gui_input` 路径**的画/擦/矩形/取色/实体放置与属性写回。
- `tools/screenshot_level_editor.gd`：1920×1080 SubViewport，6 张状态截图。
- `tools/capture_level_editor_sequence.gd`：20fps × 200 帧 = 10s，1280×720；驱动真实输入事件绘制、切层、属性编辑、保存/导出和预览行走。
- `tools/probe_level_editor.gd`：关闭 vsync，编辑器/预览分别预热后采样，输出 avg/p5/min。
- `tools/make_demo_level.gd`：生成内置示例 JSON，便于 diff 与回归。

详细结果见 [VERIFY.md](VERIFY.md)。

## 12. 已知风险与后续

1. **系统字体依赖**：CJK 字体来自 OS。若目标机器没有任何中文系统字体，文字会退化；后续可内置经过许可的子集字体。
2. **快照撤销**：极端大图和超长笔画会造成复制开销；后续可改为 tile 差异/命令模式。
3. **规则表达力**：只有四邻 + 三种地形组，没有边角组合、随机权重、跨层规则；这是刻意的 MVP 边界。
4. **schema/UI 范围不完全一致**：schema 接受 1..256 格与 8..64 px，UI 只给 8..96 格与 16/32/48 px；外部文件可能在 UI 中显示为最近的可选项，直到用户主动改尺寸。
5. **预览碰撞**：玩家 AABB 四角采样，窄缝/高速位移用子步进缓解，但不是完整物理引擎。
6. **图层/名称不进撤销**：可见性、锁定、关卡名属于编辑会话设置，按当前设计会保存但不进入历史。
7. **离屏截图缩放**：1920×1080 截图是由 1280×720 逻辑覆盖拉伸到 1920 输出，文字边缘可能有轻微插值；游戏画布内的像素对齐在 1280 逻辑下仍为整数缩放。
8. **输入模拟测试**：smoke 直接调用 `_gui_input` 并构造 `InputEventMouseButton/Motion`，能验证工具路径，但不经过 OS 窗口事件队列；真实窗口路径由真实 GPU 运行/截图/序列覆盖。

## 13. 扩展点

- 新增地形：在 `TILE_TYPES/TILE_NAMES/TILE_SHORT`、`TileArt` 基色/边规则/变体、UI 调色板循环处添加；自动规则在 `_joins_with` 决定分组。
- 新增实体：在 `ENTITY_TYPES/ENTITY_NAMES/DEFAULT_PROPS` 添加类型与默认 props，属性面板加一个 `match` 分支，`TileArt` 增加图标。
- 新规则：把掩码从 4 位扩成 8 位时，需要同时更新 `compute_mask`、TileArt 掩码判断与 schema 文档；预览使用保存的 mask，无需额外代码。
- 导入外部 tileset：可在 `TileArt.tile_texture` 外挂 atlas 映射，保持 LevelData 的 `type/variant/mask` 不变。
