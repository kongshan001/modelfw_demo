# DEVELOPMENT · 云璃背包 Inventory UI 开发文档

> 任务线程：T-20261121-014（实现）→ T-20261121-015（1:1 校正）→ T-20261121-017（文档/资产沉淀）
> 本文以**当前源码**为准（Godot 4.6），与旧文档有出入的地方见 §14「文档校正记录」。

## 0. 结论先行

- 这是一个**纯 GDScript 自绘、数据驱动**的背包 UI demo：没有引入外部 UI 素材包，面板/按钮/格子/页签/血条都是 shader 渐变绘制，位图只用于背景、面板整图、关闭钮、光晕、星芒、暗角、立绘和 20 个物品图标。
- 逻辑分辨率固定 **1280×720**（`canvas_items` 拉伸，窗口默认 1920×1080，最小 960×540）；截图/视频通过 1920×1080 SubViewport + 1280×720 逻辑覆盖渲染。
- 数据层 `InventoryState` 与视图层 `BackpackUI` 分离；35 件物品 / 8 个装备槽 / 5 页 / 6 分类；使用、丢弃、出售、整理、筛选、翻页、tooltip、详情卡、键盘、触屏链路齐全。
- headless 自测 **86 项 / 0 失败**，末行 `INVENTORY_UI_SMOKE_OK`；其中包含 F1 对齐覆盖层的开/关和「关键几何 ≤3%」断言（实测最大 2.71%）。
- 跨引擎规格已导出：`../export/ui_layout.json`（布局）、`../export/asset_manifest.json`（资产）、`../export/README.md`（导入步骤）；原理与映射见 `CROSS_ENGINE.md`、`PORTABLE_ASSETS.md`。
- 参考图（529×356）只用于数值测量，**不入库、不参与运行时**；所有素材/文案/角色/UI 名均为原创，详见 `../CREDITS.md`。

---

## 1. 运行基线

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.6 stable |
| 渲染器 | GL Compatibility（OpenGL 4.1；Intel HD Graphics 6000 实测） |
| 逻辑分辨率 | 1280×720 |
| 窗口 | `window_width_override=1920` / `height_override=1080`；`stretch/mode=canvas_items`、`aspect=keep`；最小 960×540 |
| 主场景 | `scenes/main.tscn` → `scripts/main.gd` |
| 字体 | `SystemFont`：正文 PingFang SC / Hiragino Sans GB / Heiti SC / Noto Sans CJK SC 回退；标题 STKaiti / Kaiti SC / Songti SC / Noto Serif CJK SC 回退。**未打包字体文件** |
| 输入 | 鼠标 + 键盘；`emulate_mouse_from_touch=true`（触摸映射为鼠标点击） |
| 测试 | headless GDScript SceneTree smoke，86 项 |
| 抗锯齿 | MSAA 2D/3D = 0（UI 由 SDF/纹理边缘自带 AA；避免额外开销） |
| 纹理过滤 | 线性（项目明确规定不使用像素风/NEAREST） |

常用命令（在 `godot-inventory-ui/` 下执行）：

```bash
godot --path .                                             # 运行
godot --headless --path . -s tools/smoke_inventory_ui.gd    # 自测 → INVENTORY_UI_SMOKE_OK
godot --path . -s tools/capture_inventory_ui.gd -- --shots  # 13 张 1920×1080 截图
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video
python3 ../export/validate_export.py                       # 导出规格/资产/链接自检（仅需标准库）
```

> `validate_export.py` 位于上一级的 `export/`；从 `godot-inventory-ui/` 执行时路径如上行。它不依赖 Godot。

---

## 2. 目录与职责

```text
godot-inventory-ui/
├── project.godot              # 1280×720 / 1920×1080 override / GL Compatibility
├── scenes/main.tscn           # Main(Control)
├── scripts/
│   ├── main.gd                # 背景、FPS(F3)、把键盘事件交给 BackpackUI
│   ├── inventory_state.gd     # 数据与纯逻辑：页/分类/使用/丢弃/出售/整理
│   ├── theme_kit.gd           # 调色板、字体、渐变/光晕/标签工厂
│   └── ui/
│       ├── backpack_ui.gd     # 视图编排、状态机、键盘、动作入口
│       ├── inventory_grid.gd  # 5×5 网格、翻页、滚动条、空态
│       ├── item_cell.gd       # 单格：品质边/数量/锁/悬停/选中呼吸/使用闪光
│       ├── paper_doll.gd      # 人物台：光环/椭圆环/立绘/8 槽/图鉴
│       ├── equip_slot.gd      # 装备槽：104×90、品质边、等级胶囊、未附魔芯片
│       ├── player_stats_panel.gd # HP/MP 条 + 四维 + 矢量图标
│       ├── tab_bar_ui.gd      # 5 页签（瞬时换色）
│       ├── side_nav.gd        # 右侧竖排导航（物品/炼丹/九州谱）
│       ├── coin_row.gd        # 铜/银药丸 + “+”占位
│       ├── ui_button.gd       # GOLD/SLATE/DANGER/ICE/GHOST 五种按钮
│       ├── detail_card.gd     # 290×440 详情/操作卡（新增交互层）
│       ├── item_tooltip.gd    # 292×82 悬停说明
│       ├── confirm_dialog.gd  # 丢弃二次确认
│       ├── filter_popup.gd    # 分类下拉（向上弹出）
│       ├── placeholder_overlay.gd # 炼丹/九州谱/图鉴占位
│       ├── toast.gd           # 底部反馈条
│       ├── fx_layer.gd        # 金光粒子（点/星芒/扩散环）
│       ├── gradient_rect.gd   # 圆角渐变+描边+gloss 的 ColorRect 封装
│       └── align_overlay.gd   # F1 1:1 对齐检查（诊断）
├── data/items.json            # 35 items + 8 equipment + player
├── assets/{bg,char,icons,ui}/ # 原创位图/矢量
├── shaders/rounded_gradient.gdshader
├── tools/gen_assets.py        # 背景/面板/关闭钮/光晕/暗角程序化生成
├── tools/smoke_inventory_ui.gd
├── tools/capture_inventory_ui.gd
├── docs/                      # TECH / fidelity / 迭代记录 / 本文 / 跨引擎 / 资产包
├── export/                    # ui_layout.json / asset_manifest.json / README / validator
└── docs/media/                # 截图/视频/GIF/帧率/联系表
```

职责边界：

| 层 | 文件 | 允许做什么 | 不允许做什么 |
| --- | --- | --- | --- |
| 数据/逻辑 | `inventory_state.gd` | 读 JSON、过滤、排序、扣减、出售、丢弃、返回结果字典 | 访问节点/纹理/动画 |
| 主题/工厂 | `theme_kit.gd` | 颜色 token、字体、渐变/光晕/标签/按钮样式 | 持有业务状态 |
| 视图编排 | `backpack_ui.gd` | 建树、信号连线、选中/切页/动效、键盘分发 | 直接改数据（必须经 `InventoryState`） |
| 组件 | `scripts/ui/*.gd` | 绘制自身、发信号、局部 hover/动效 | 跨组件直接改数据 |
| 工具 | `tools/*.gd` | 自测、截图/视频、F1 报告 | 作为运行时依赖 |

---

## 3. 节点树与渲染顺序

`Main` 负责背景和 FPS；`BackpackUI` 是一个 1280×720 的 Control，内部再分 `panel_root` 和若干顶层浮层。**实际 `add_child` 顺序**如下（同 z 时后加的覆盖先加的）：

```text
Main (Control, scripts/main.gd)
├── Background TextureRect            # assets/bg/night_palace.png, STRETCH_KEEP_ASPECT_COVERED
├── bg_glow_a / bg_glow_b TextureRect # 呼吸辉光，IGNORE
├── Vignette TextureRect              # assets/ui/vignette.png, 全屏
├── BackpackUI (Control, scripts/ui/backpack_ui.gd)   # mouse_filter = IGNORE
│   ├── panel_root (Control, pivot 630,379, 1280×720)
│   │   ├── Dim ColorRect                        # 全屏 rgba(2,10,15,0.22)
│   │   ├── PanelArt TextureRect                 # panel.png @ (17,47) 1193×659
│   │   ├── PaperDoll (560×470 @ 60,47)
│   │   │   ├── Aura glow / Character SVG / 椭圆环+光点(_draw)
│   │   │   ├── EquipSlot ×8 (104×90)
│   │   │   └── UIButton「图鉴」ICE 40×40
│   │   ├── PlayerStatsPanel (600×178 @ 60,505)
│   │   ├── TabBarUI (543×54 @ 653,59)
│   │   ├── capacity label (340×20 @ 653,578)    # 新增辅助条
│   │   ├── filter UIButton (124×20 @ 1066,578)  # 新增辅助条
│   │   ├── InventoryGrid (551×455 @ 653,121)
│   │   │   ├── Grid backing (555×461 @ -6,-6)
│   │   │   ├── ItemCell ×25（全部可见，空格也无图标）
│   │   │   ├── Empty state（pouch + 文案）
│   │   │   └── PageScroll (10×445 @ 535,2)
│   │   ├── CoinRow gold (300×36 @ 656,604)
│   │   ├── CoinRow silver (300×36 @ 656,656)
│   │   ├── sort UIButton (182×61 @ 994,613)
│   │   ├── title glow + Label「物品」 (104×46 @ 160,-3)
│   │   ├── close glow + TextureButton (72×72 @ 1198,6)
│   │   ├── SideNav (78×419 @ 1198,87)
│   │   ├── DetailCard (290×440 @ 898,132)
│   │   └── AlignOverlay (全屏, z_index=90, 默认隐藏)
│   ├── reopen_root (全屏，关闭态；默认隐藏)
│   ├── ItemTooltip (292×82，动态)
│   ├── FxLayer (全屏，IGNORE)
│   ├── Toast (底部反馈)
│   ├── FilterPopup (全屏拦截，默认隐藏)
│   ├── PlaceholderOverlay (全屏拦截，默认隐藏)
│   └── ConfirmDialog (全屏拦截，默认隐藏)
└── FPS Label (F3，z_index=100)
```

**层序事实（重要）**：

1. 除 `AlignOverlay` 外，上述节点都没有显式 `z_index`；绘制顺序 = `add_child` 顺序。因此实际是：`tooltip` 在 `fx/toast` 之下，`toast` 在 `filter_popup` 之下，`confirm_dialog` 最后加入 → 永远最上（同为 z=0 时）。
2. `AlignOverlay.z_index=90` 相对于 `panel_root`，会排在同 canvas layer 的所有普通层（z=0）之后，包括确认框；因此 F1 覆盖层是**诊断专用**，正式截图/交付不应开启。
3. 旧版 `TECH.md` §3 写的「reopen → filter → placeholder → FX → toast → tooltip → confirm」与源码不一致；T-017 已按源码核对，本文为准。

`panel_root` 内的次级顺序（从下到上）：Dim → PanelArt → PaperDoll → Stats → Tabs → capacity/filter → Grid（含 backing/cells/empty/scroll）→ 钱币 → 整理 → 标题 → 关闭 → 侧导航 → 详情 → F1。

---

## 4. UI 状态机

### 4.1 面板与浮层

```text
panel_open = false
└─ reopen_root 可见
   └─ B / I / Enter / Space / 「打开背包」 → panel_open = true（200ms 缩放淡入）

panel_open = true
├─ confirm_open = true      → Esc 取消；Enter 确认；其余按键被吞掉
├─ placeholder_open = true  → Esc 关闭占位层；回到物品页；其余按键被吞掉
├─ filter_open = true       → Esc 关闭筛选；其余按键被吞掉
└─ 无浮层
   ├─ Esc → 关闭面板（180ms；然后显示 reopen）
   ├─ B / I → 关闭面板
   ├─ Tab / Shift+Tab / 1..5 / 滚轮 / 拖滚动条 → 切页
   ├─ 方向键 → 移动选中
   ├─ Enter → 使用当前选中
   └─ Space → 开/关详情卡
```

优先级由 `BackpackUI.handle_key()` 的检查顺序决定（`F1` 最先处理）：

```text
F1  →  确认框  →  占位层  →  筛选弹层  →  面板关闭  →  面板打开
```

- 所有 Control 的 `focus_mode = FOCUS_NONE`；没有引擎原生焦点遍历，键盘由 `BackpackUI` 集中处理。
- `_unhandled_input` 在 `main.gd`：先处理 `F3`，否则把 `InputEventKey` 交给 `ui.handle_key()`；被处理时标记 `set_input_as_handled()`。
- 键盘重复（`ev.echo`）被忽略；一次按下只处理一次。

### 4.2 页 / 分类 / 选中 / 详情

| 状态 | 取值 | 初始 | 转移 |
| --- | --- | --- | --- |
| `current_page` | 1..5 | 1 | 页签点击、Tab/Shift+Tab、数字键、滚轮、拖滚动条；切页时清空选中/详情 |
| `current_category` | 全部/装备/消耗/材料/任务/杂项 | 全部 | 筛选弹层选择；同样清空选中/详情 |
| `selected_mode` | `bag` / `equip` | `bag` | 点格子 → bag；点装备槽 → equip |
| `selected_item` | 物品字典 | `{}` | 选中/使用后刷新；切页/筛选/移除时清空 |
| `detail` | hidden / bag / equipped | hidden | 单击/空格打开；关闭钮/空格/切页/筛选/移除关闭 |

- 方向键移动公式（5 列网格）：`next = clamp(index + dx, 0, n-1)`；`next = clamp(index + dy*5, 0, n-1)`。
- 第一次按方向键时若无选中，选中索引 0。
- 详情卡已打开时，方向键切换选中会实时刷新详情内容；切页/筛选会先关闭详情。
- 点装备槽会清空网格选中，并打开只读装备详情。

### 4.3 数据不变量

- `items.size()` 就是已用容量（`used_capacity()`）；容量上限来自 `player.capacity`（216）。
- 存储的物品 `stack >= 1`；使用到 0 时立即从 `items` 移除。
- `page ∈ 1..5`；`category ∈ 6 类`；`quality ∈ 0..3`。
- `equipment_slots` 恰好 8 个 key：`artifact/boots/armor/helmet/necklace/ring_left/ring_right/weapon`。
- `hp/mp` 永远被裁剪到 `hp_max/mp_max`。
- 出售价 = `price × stack`；`price` 为单件价格。
- `bindable` 只影响展示（未绑定·可交易/已绑定）；能否出售由 `sellable && price > 0` 决定。
- `discardable=false` 的物品（任务物品）不可丢弃。
- `use` 字段存在即可使用（`can_use` 只看 `use` 是否为字典），与 `category` 无关。

---

## 5. 数据 schema（`data/items.json`）

### 5.1 顶层

```json
{
  "schema": 1,
  "player": { "...": "..." },
  "equipment_slots": [ { "slot": "weapon", "...": "..." } ],
  "items": [ { "id": "huichun_pill", "...": "..." } ]
}
```

### 5.2 `player`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` / `title` / `level` | string/string/int | 展示用；demo 中角色为原创「云璃 / 青丘灵狐 / 68」 |
| `hp` / `hp_max` | int | 气血当前/上限；使用回血会被上限裁剪 |
| `mp` / `mp_max` | int | 魔法当前/上限 |
| `attack` / `spirit` / `defense` / `speed` | int | 四维，显示在属性栏 |
| `gold` / `silver` | int | 铜币/银两；银两会因出售/使用宝箱增加 |
| `capacity` | int | 背包总容量 216；已用 = `items.size()` |

### 5.3 `items[]`

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 唯一；选择/测试/动作定位 |
| `name` | string | ✅ | 原创中文名 |
| `icon` | string | ✅ | → `assets/icons/icon_<icon>.svg` |
| `category` | enum | ✅ | 装备/消耗/材料/任务/杂项 |
| `quality` | 0..3 | ✅ | 凡品/良品/珍品/绝品 |
| `level` | int | ✅ | 装备等级；非装备用于详情展示（页签信息另算） |
| `stack` / `max_stack` | int | ✅ | 当前/最大堆叠 |
| `page` | 1..5 | ✅ | 一/二/三/四/临时 |
| `desc` | string | ✅ | 原创描述 |
| `stats` | object | ✅（可空） | 属性加成，如 `{"攻击":120}` |
| `use` | object? | — | `hp`/`mp`/`silver`/`text`；无 → 使用按钮置灰 |
| `bindable` | bool | — | 默认 true；false 显示绑定锁与「已绑定」 |
| `sellable` | bool | — | 默认 false；出售按钮可用性 |
| `price` | int | — | 单件银两；默认 0 |
| `discardable` | bool | — | 默认 true；任务物品设 false |

加载时会做一次 `_normalize()`：缺失的 int/bool 补默认值，`stats` 为 null 补 `{}`，`use` 里的 `hp/mp/silver` 转 int。

### 5.4 `equipment_slots[]`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `slot` | enum | 8 个固定 key，与 `PaperDoll.SLOT_KEYS` 一致 |
| `name` / `icon` | string | 展示与图标 |
| `level` | int | 等级胶囊「N级」 |
| `quality` | 0..3 | 槽位品质边框 |
| `enchant` | string/null | 仅当等于「未附魔」时显示芯片和 “+”；其他字符串不显示芯片 |
| `desc` / `stats` | string / object | 装备详情 |

### 5.5 内置数据分布（实测）

| 页 | 物品堆叠数 | 说明 |
| --- | ---: | --- |
| 1（一） | 25 | 满页；网格仍显示 25 个槽位框 |
| 2（二） | 7 | |
| 3（三） | 2 | |
| 4（四） | 0 | 刻意的空页，用于验证空状态 |
| 5（临时） | 1 | |
| **合计** | **35** | 容量 35/216 |

第 1 页分类：装备 9 / 消耗 5 / 材料 6 / 任务 3 / 杂项 2。
全库分类：装备 12 / 消耗 7 / 材料 9 / 任务 5 / 杂项 2。
其中 8 件可用（带 `use`）、5 件任务物品（`discardable=false`）、17 件可出售。

### 5.6 动作返回契约

`InventoryState` 的 `use_item` / `discard_item` / `sell_item` 返回字典：

```json
{"ok": true,  "message": "…", "removed": false, "name": "回春丹", "item": {…}}
{"ok": false, "reason": "该物品不可直接使用"}
```

调用方（`BackpackUI`）只用 `ok`、`message`/`reason`、`removed`；移植时应保持同一契约，便于 UI 层复用。

---

## 6. 交互流程

### 6.1 切页

1. 触发：页签点击 / `Tab` / `Shift+Tab` / `1..5` / 网格滚轮 / 拖右侧滚动条。
2. `_switch_page_internal(page)`：页号循环到 1..5 → `tabs.set_active` → `grid.refresh`（140ms 淡入）→ 关闭详情 / tooltip → 清空选中 → 更新容量/页码文本。
3. 空页（第 4 页）仍显示 25 个槽位框，并叠加空状态图标与文案。

### 6.2 分类筛选

1. 点「筛选 全部 ▾」→ 打开 `FilterPopup`（向上弹出，y 从 `-8` 归位，120ms）。
2. 选中分类 → `set_category(cat)`：更新按钮文字、刷新网格、关闭详情/tooltip、清空选中；toast「已筛选：<分类>」。
3. 当前页 + 分类为空 → 空状态文案切换为「此分类在本页暂无物品」。
4. `Esc` 或点击弹层外部关闭；筛选弹层打开时会先关闭详情卡。

### 6.3 选中 / 悬停 / tooltip

- 单击格子：`InventoryGrid` 设置选中（金边 3.2px + 洋红呼吸光）并打开详情卡。
- 悬停格子：内容上抬 -3px、金色柔光 0.45、边框提亮 20%；tooltip 140ms 淡入，锚点为格子右上角 `(right-4, top+6)`。
- 悬停装备槽：缩放 1.045、金色柔光 0.45；tooltip 显示「已装备 · N级 · 品质」。
- tooltip 位置 = 锚点 + 12px，夹取在 12..(屏幕-尺寸-12) 内；移出 100ms 淡出。
- 品质 3 的空闲装备槽会有 0.10–0.16 的呼吸光（周期 2.856s）。

### 6.4 使用

1. 触发：双击格子 / `Enter` / 详情卡「使用」。
2. `state.use_item(id)`：
   - HP/MP 增加后裁剪到上限；若已满，文案改为「气血已满，药力化入经脉」/「魔法已满，灵气散入丹田」。
   - `silver` 直接增加并改写文案。
   - `stack -= 1`；为 0 时从 `items` 移除。
3. 视图：`FxLayer.burst(center, 金色, 28)` + 格子图标 1→1.18→1 + 金晕 + HP/MP 条 220ms 动画 + 容量/页码刷新 + toast。
4. 移除时关闭详情、清空选中、刷新网格；未移除时刷新数量与详情。
5. 不可使用时 toast「该物品不可直接使用」；未选中时 toast「请先在背包中选中物品」。

### 6.5 整理

1. 点「整 理」→ 记录当前选中 id 和旧位置 map → `state.sort_page(page)`。
2. 排序键：`quality ↓` → `category_order ↑`（装备/消耗/材料/任务/杂项）→ `level ↓` → `name ↑`。
3. `grid.refresh(..., preserve_id, old_map)`：每格从旧位置 180ms Cubic/EaseOut 到新位置，按索引 12ms stagger；保留原选中。
4. toast「已按品质与类型整理」；详情若打开则刷新。
5. 排序只重排当前页；其他页保持原顺序。

### 6.6 丢弃二次确认

1. 详情卡「丢弃」→ 若 `discardable=false`，直接 toast「任务物品不可丢弃」；否则打开 `ConfirmDialog`。
2. 确认框显示物品图标、「确定丢弃「X」×N 吗？」、红色警示；全屏 dim 拦截底层点击。
3. `Esc`/取消 → 不扣物品；`Enter`/「确定丢弃」→ `discard_item(id)` 整组移除，刷新容量/网格，关闭详情，toast「已丢弃…」。
4. 确认框打开时 F1 仍可切换（诊断优先）；其余按键被吞掉。

### 6.7 出售

1. 详情卡「出售」→ `sell_item(id)`：仅在 `sellable && price>0` 时成功。
2. 银两 += `price × stack`；整组移除；再点「+」只显示占位 toast。
3. 已装备/已认主装备：`sellable=false` → 拒绝，提示「已认主的装备不可出售」。
4. 出售同样会刷新容量/页码/网格并关闭详情。

### 6.8 键盘

| 键 | 面板打开 | 面板关闭 | 备注 |
| --- | --- | --- | --- |
| `Esc` | 依优先级关浮层/面板 | — | 确认框 → 占位层 → 筛选 → 面板 |
| `Tab` / `Shift+Tab` | 下一页/上一页 | — | 页号循环 |
| `1`–`5` | 跳到对应页 | — | |
| 方向键 | 移动选中 | — | 5 列网格公式 |
| `Enter` | 使用选中；无选中则选第 0 项 | 打开面板 | |
| `Space` | 开/关详情 | 打开面板 | |
| `B` / `I` | 关闭面板 | 打开面板 | |
| `F1` | 切换 F1 对齐检查 | 同上（但覆盖层只在面板打开时可见） | 诊断 |
| `F3` | FPS/绘制数 | 同左 | 由 `main.gd` 处理 |

### 6.9 鼠标 / 触屏

- 鼠标：格子单击选中、双击使用；滚轮/拖滚动条翻页；页签/侧导航/筛选/详情按钮点击；关闭钮 hover 1.08。
- 触屏：项目开启 `emulate_mouse_from_touch`，触摸 = 点击；**双击在部分系统/浏览器不可靠**，触屏稳妥路径是详情卡的「使用 / 丢弃 / 出售」按钮。
- 所有面板/卡片的 dim 层 `MOUSE_FILTER_STOP`，打开时拦截底层；关闭后不拦截。

---

## 7. 布局规格（1280×720）

完整、可机器读取的版本（含归一化 rect、锚点、字号、色 token、动效、状态）在 **`../export/ui_layout.json`**。下面是人工速查表：

| 区域 | 位置 / 尺寸（px） | 备注 |
| --- | --- | --- |
| 全屏面板 | `(17,47) 1193×659` | 圆角 15；细金多层描边；2× 纹理 |
| 左右分界 | `x = 653` | 左区 636px / 右区 557px（占面板 53.31% / 46.69%） |
| 标题「物品」 | 原始控件框 `(160,-3) 104×46`，中心 `(212,20)`；导出取文本块 `(160,0) 104×40` | 38px 书法 + 5px 深蓝描边；无绶带；原框记录在 `control_box_px` |
| 关闭钮 | `(1198,6) 72×72` | 中心 `(1234,42)`；圆形贴图 |
| 人物台 | `(60,47) 560×470` | 椭圆环心 `(327,277)`，rx/ry = 262/218 |
| 立绘 | `(264,131) 160×204` | 原始 SVG 720×900；上下浮动 ±2px |
| 装备槽 | `104×90`，8 个；位置见下 | 品质边框 4px；等级胶囊 60×20 |
| 属性栏 | `(60,505) 600×178` | HP 条 `(225,513) 358×30`；MP `(225,551) 358×30` |
| 四维 | 行 1 `y=597`，行 2 `y=641` | 标签 24px / 数值 28px |
| 页签 | `(653,59) 543×54` | 5 × 103×54，gap 7，pitch 110 |
| 物品网格 | `(653,121) 542×449` | 5×5；槽 102×85，pitch 110×91；gap 8×6 |
| 网格背板 | `(647,115) 555×461` | 四边外扩 6px |
| 滚动条 | `(1188,123) 10×445` | 低对比；参考图无 |
| 容量/页码 | `(653,578) 340×20` | 新增控件，11px |
| 筛选按钮 | `(1066,578) 124×20` | 新增控件，弹层 `(1054,418) 128×180` |
| 铜币/银两药丸 | `(706,606) 246×32` / `(706,659) 246×30` | 行容器 300×36，y=604/656；+ 44×30 |
| 整理按钮 | `(994,613) 182×61` | 金色，28px |
| 侧导航 | `(1198,87) 78×419` | 3 × 78×129，gap 16，pitch 145；活跃页 x-8 |
| 详情卡 | `(898,132) 290×440` | 新增浮层；默认隐藏；三个操作按钮 76/76/82×38 |
| 空状态 | 网格内 `(653,121) 543×449` | 112px 钱袋 + 22px 标题 + 15px 副文案 |

装备槽（相对人物台 `(60,47)` → 全局）：

| 槽 | local | 全局 | 参考中心 → 实现中心 |
| --- | --- | --- | --- |
| 法宝 artifact | `(212,3)` | `(272,50) 104×90` | (324,95) → (324,95) |
| 鞋履 boots | `(47,48)` | `(107,95)` | (158,140) → (159,140) |
| 衣甲 armor | `(383,49)` | `(443,96)` | (495,141) → (495,141) |
| 头冠 helmet | `(-2,186)` | `(58,233)` | (110,278) → (110,278) |
| 项链 necklace | `(430,186)` | `(490,233)` | (542,278) → (542,278) |
| 戒指 ring_left | `(47,319)` | `(107,366)` | (159,411) → (159,411) |
| 戒指 ring_right | `(382,319)` | `(442,366)` | (494,411) → (494,411) |
| 武器 weapon | `(218,367)` | `(278,414)` | (330,459) → (330,459) |

1:1 测量背景、误差表与例外（16:9 适配、新增控件、无绶带、无可见滚动条）见 `fidelity-1to1.md`。要点：

- 参考 529×356（1.486:1）→ 1280×720（1.778:1）；按归一化坐标分别映射。
- 关键几何最大偏差 2.71%（整理按钮高度 61 vs 62.7），全部 ≤3%。
- 装备槽理论 106.5×89；实现 104×90 保持方形观感，两轴偏差 ≤2.32%。
- 参考图没有的容量/筛选/详情卡/滚动条，均标注为新增项，不计入 1:1 误差。

---

## 8. 动效参数（按源码）

| 动效 | 时长 / 缓动 | 参数 |
| --- | --- | --- |
| 开面板 | 200ms Cubic/EaseOut | `panel_root` scale 0.965→1，alpha 0→1，pivot (630,379) |
| 关面板 | 180ms Sine/EaseOut | scale 1→0.94，alpha 1→0；结束显示 reopen |
| reopen 淡入 | 160ms Sine/EaseOut | alpha 0→1 |
| 网格刷新 | 140ms Sine/EaseOut | 网格 alpha 0→1 |
| 格子 hover | 120ms Sine/EaseOut | 内容 y 0→-3；金光 alpha→0.45；边框提亮 20% |
| 格子移出 | 120ms Sine/EaseOut | 内容归位；金光 120ms 淡出后隐藏 |
| 选中呼吸 | 周期 ≈1570.8ms，正弦循环 | `α = 0.24 + 0.16*(0.5+0.5*sin(t*4))` |
| 使用闪光 | 100ms Back/EaseOut + 160ms 线性 + 380ms 金晕 | 图标 1→1.18→1；金晕 0.95→0 |
| 金色粒子 | 寿命 380–720ms（点）/280–420ms（星芒）/300ms（环） | 26 点 + 3 星芒 + 1 扩散环；重力 260px/s²、阻尼 1.4/s |
| tooltip 入/出 | 140ms / 100ms Sine/EaseOut | alpha |
| 详情卡入 | 160ms Cubic/EaseOut | x +26→0，alpha 0→1，scale 0.985→1；pivot (898,352) |
| 详情卡出 | 120ms Sine/EaseOut | x 0→+20，alpha→0 |
| 整理重排 | 180ms Cubic/EaseOut + 12ms/项 stagger | 每格旧位置→新位置 |
| 确认框入/出 | 150ms Cubic/EaseOut / 120ms Sine/EaseOut | 卡片 scale 0.94→1 / 1→0.96；alpha |
| toast | 120ms 淡入 + 160ms 上浮（628→618）+ 停留 1350ms + 200ms 淡出 | Sine/EaseOut |
| 占位层入/出 | 160ms Cubic/EaseOut / 130ms Sine/EaseOut | 卡片 scale 0.97→1 / 1→0.97 |
| 筛选弹层 | 120ms Cubic/EaseOut | y -8→0；alpha 0→1 |
| HP/MP 条 | 220ms Cubic/EaseOut | 宽度→比例×358 |
| 侧导航活跃 | 140ms Sine/EaseOut | 活跃页 x 0→-8 |
| 按钮 hover/press/release | 120 / 60 / 100ms Sine/EaseOut | scale 1→1.035 / 1.035→0.97 / 0.97→1.035 |
| 关闭钮 hover | 120ms Sine/EaseOut | scale 1→1.08；光晕 alpha 0.22→0.42 |
| 装备槽 hover | 120ms Sine/EaseOut | scale 1→1.045；光晕 0.45 |
| 绝品槽呼吸 | 周期 2856ms | `α = 0.10 + 0.06*(0.5+0.5*sin(t*2.2))` |
| 立绘浮动 | 周期 4189ms | `y = 131 + 2*sin(t*1.5)` |
| 人物光环 | 周期 5236ms | `α = 0.22 + 0.045*sin(t*1.2)` |
| 页签切换 | **瞬时** | 颜色即时切换；T-015 已移除金色下划线补间 |

> 缓动命名与跨引擎映射（sine-out/cubic-out/back-out 的公式）见 `CROSS_ENGINE.md` §C.8。所有时长以 ms 计，不依赖帧率。

---

## 9. 图标与资产管线

### 9.1 生成方式

| 资产 | 来源 | 尺寸（源） | 运行时显示 |
| --- | --- | --- | --- |
| 背景 `assets/bg/night_palace.png` | `tools/gen_assets.py`（PIL+numpy） | 2560×1440 | 1280×720 cover |
| 面板 `assets/ui/panel.png` | 同上；3× 绘制 → 2× 降采样 | 2386×1318 | 1193×659 |
| 关闭钮 `assets/ui/close.png` | 同上 | 232×232 | 72×72 |
| 光晕 `assets/ui/glow.png` | 径向渐变 | 512×512 | 96–520，按需缩放/着色 |
| 星芒 `assets/ui/sparkle.png` | 径向+十字 | 256×256 | 34–56 粒子 |
| 暗角 `assets/ui/vignette.png` | 程序化 | 1280×720 | 全屏 |
| 绶带 `assets/ui/ribbon.png` | 程序化 | 520×180 | **未使用**（T-015 移除） |
| 符文环 `assets/ui/rune_ring.png` | 程序化 | 1280×1280 | **未使用**（改为运行时椭圆） |
| 立绘 `assets/char/cloud_fox.svg` | 手绘 SVG | 720×900 | 160×204 |
| 物品图标 ×20 | 手绘 SVG | 256×256（viewBox 128） | 78×78（主）/72/112/146/70 |

### 9.2 物品图标

- 列表：`sword / armor / helmet / necklace / ring / boots / bell / tome / feather / potion_red / potion_blue / potion_green / herb / ore / scroll / fish / gem / pouch / chest / peach`。
- 统一风格：3–4px 深梅色描边、金/青/紫/红高光、柔和椭圆投影；256×256 导入。
- **品质不画进图标**：4 档品质由格子/槽位/详情卡的边框色 + 文字表达，图标可跨品质复用。

### 9.3 面板/按钮/渐变

- `shaders/rounded_gradient.gdshader`：SDF 圆角掩码 + 上下渐变 + 顶部 gloss + 对角 sheen + 内侧描边 + 1px 内高光。
- 按钮/页签/侧导航/格子/血条/钱币药丸/详情卡/弹层全部复用该 shader；因此**没有按钮状态切图**，状态是运行时参数。
- 面板是唯一的大型整图 UI 纹理：2× 源图，细金三层描边 + 四角云纹；不是九宫格。九宫格建议见 `PORTABLE_ASSETS.md` §2。

### 9.4 字体

- 正文：PingFang SC / Hiragino Sans GB / Heiti SC / Noto Sans CJK SC / Source Han Sans SC / Microsoft YaHei / sans-serif，weight 500。
- 标题：STKaiti / Kaiti SC / Songti SC / STSong / Noto Serif CJK SC / Source Han Serif SC / serif，weight 700。
- 未打包字体；跨平台发布前必须自带 OFL 字体（Noto Sans SC / Noto Serif SC），否则非 macOS 设备可能缺字。
- 字号范围 9–38px；具体 token 见 `../export/ui_layout.json` 的 `fonts.sizes`。

### 9.5 截图/视频管线

```bash
# 13 张 1920×1080 PNG（SubViewport 1920×1080，逻辑 1280×720 覆盖）
godot --path . -s tools/capture_inventory_ui.gd -- --shots

# 10s / 30fps 逐帧 JPEG → mp4
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video
ffmpeg -y -framerate 30 -i /tmp/inv_ui_frames/frame_%04d.jpg \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/media/inventory_ui_demo.mp4

# GIF（960 宽 / 12fps / 160 色）
ffmpeg -y -i docs/media/inventory_ui_demo.mp4 \
  -vf "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=160[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
  docs/media/inventory_ui_demo.gif
```

### 9.6 重新生成

```bash
python3 tools/gen_assets.py    # 只重新生成 bg/ui 下的程序化 PNG；不会生成图标/立绘
```

图标与立绘是手绘 SVG，**不要**用脚本覆盖；修改后用 Godot 重新导入并跑 smoke。

---

## 10. 性能

项目实测（同一台 Intel Core i7-5650U / Intel HD Graphics 6000，GL Compatibility，共享主机）：

| 指标 | 值 |
| --- | --- |
| 1920×1080 SubViewport 绘制调用 | 344 |
| 最新 pass 采样 | `[35,16,13,17,18,18]`，avg 19.5 / min 13 |
| 早先 pass | `[28,32,32,36,36,34]`，avg 33 / min 28 |
| 结论 | 共享主机波动大；**13–36 FPS**，不是稳定 60 |
| 原始数据 | `docs/media/fps.txt` |

优化现状：

- 闲置格子双层光晕 `visible=false`；装备槽光晕只在品质 3 或 hover 时显示。
- 纸娃娃的 `_draw` 节流到约 30Hz；背景辉光只改 alpha。
- 标题/关闭钮/格子的光晕是纹理，不额外绘制形状。
- `F3` 显示实时 FPS/绘制调用，便于回归。

已知瓶颈与建议（**建议，不是本机实测**）：

- 25 个格子 ×（图标/数量/锁/边框）是主要 draw calls 来源；移植/优化可把角标、锁、品质小框打进图集或共享材质。
- 大量文字带 outline（标题 5px、页签 3px、详情/数值 2–3px）会增加 overdraw；可合并到同一材质或使用 SDF 字体。
- 按钮/页签/格子都是逐控件 shader 材质；目标引擎应尽量合批或使用图集。
- 移植性能目标建议：目标设备 1920×1080 下 60fps、draw calls <150（需在目标机实测，勿把 Godot 数字当跨引擎基线）。

---

## 11. 验证与证据

### 11.1 headless smoke（86 项）

```bash
godot --headless --path . -s tools/smoke_inventory_ui.gd
# checks=86 failures=0
# INVENTORY_UI_SMOKE_OK
```

覆盖：启动/容量/页码、5 页计数、6 分类筛选、空状态、选中、tooltip 淡入淡出、方向键、整理排序、使用扣减/移除/回血、丢弃取消/确认、出售加银两、绑定装备拒绝出售、任务物品拒绝丢弃、筛选弹层、单击/双击、Tab/Shift+Tab/数字键/Esc/B、关闭钮/重新打开、F1 覆盖层开/关与关键几何 ≤3%。

### 11.2 真实 GPU 证据

| 类型 | 路径 |
| --- | --- |
| 总览 | `media/screenshots/01_overview_1920x1080.png` |
| F1 对齐检查 | `media/screenshots/13_alignment_overlay_1920x1080.png` |
| tooltip / 详情 / 装备详情 / 第 2 页 / 筛选 / 使用 / 空页 / 丢弃确认 / 整理 / 占位 / 关闭 | `media/screenshots/02…12_*.png` |
| 10s 视频 | `media/inventory_ui_demo.mp4`（1920×1080 / 30fps） |
| GIF | `media/inventory_ui_demo.gif`（960 宽 / 12fps） |
| 帧率 | `media/fps.txt` |
| 跨引擎联系表 | `media/export/portable_layout_assets.png` |

### 11.3 导出规格自检

```bash
python3 ../export/validate_export.py
# EXPORT_LAYOUT_OK
# EXPORT_MANIFEST_OK
# EXPORT_LINKS_OK
```

校验内容：rect 不越界、归一化值与 px 一致、`within` 包含关系、5×5 网格与 25 槽、8 装备槽、5 页签、3 侧导航、字体范围、动效字段、manifest 路径/尺寸/九宫格字段/许可、文档相对链接。仅需 Python 3 标准库。

---

## 12. 已知限制

- 1:1 口径是**布局/比例/配色/信息层级/交互**；参考图为 529×356，16:9 适配与例外见 `fidelity-1to1.md` §7。
- 参考图没有容量条、分类筛选、详情卡、可见滚动条；这些是新增交互层，已在 F1 中以品红标记、不计入最大误差。
- 详情卡默认不显示；选中时覆盖右侧网格 2 列。
- 装备槽为展示/查看态；不实现换装/附魔/属性联动。
- 炼丹/九州谱/图鉴为占位界面；货币「+」为占位提示。
- 字体依赖系统 CJK 回退；发布前需打包 OFL 字体。
- 触屏双击不保证被识别；稳妥路径是详情卡按钮。
- 未实现：存档、联网、经济、音效、拖拽物品、右键菜单、多选、批量操作。
- 背包内非任务装备的「出售」按钮会置灰，但原因行可能为空（`bindable=false` 分支未覆盖）；这是既有行为，T-017 未改 UI 行为。
- 实现数字不带千分位（参考图有逗号）；布局/验收不依赖分隔符。
- 共享主机 FPS 波动大；不要用本机 13–36 FPS 推断目标设备性能。

---

## 13. 维护指南

### 13.1 加一件物品

1. 在 `data/items.json` 的 `items` 增加对象；`id` 唯一，`page`/`category`/`quality` 合法，`icon` 对应已有 `assets/icons/icon_<key>.svg`。
2. 若新增图标，按 `icon_<key>.svg` 命名，256×256、viewBox 128、统一描边；重新导入。
3. 跑 smoke。注意 smoke 对页 1 数量（25）、分类数量（9/5/6/3/2）、总容量（35/216）有硬断言；新增物品需同步更新断言与文档计数。
4. 更新 `../export/asset_manifest.json`（若新增图标）与 `../export/ui_layout.json` 的 `self_check`/文档计数（如适用）。

### 13.2 改布局

1. 改 `backpack_ui.gd` 的 `PANEL_POS/PANEL_SIZE/GRID_POS/SPLIT_X` 或组件常量（`TabBarUI.TAB_W/TAB_H/GAP`、`InventoryGrid.COL_W/ROW_H/CELL`、`EquipSlot.SLOT_SIZE`、`PaperDoll.SLOT_POS` 等）。
2. **不要**随意改 `AlignOverlay.REF_RECTS`：它是参考图测量值，不是实现值；只有重新测量参考图时才改。
3. 同步更新 `../export/ui_layout.json`（rect_px/rect_norm/self_check），运行 `validate_export.py`。
4. 跑 smoke（F1 会因布局变化报偏差；若 >3% 需重新校正或说明例外）；重新截图/视频。
5. 更新 `TECH.md` §2 与 `fidelity-1to1.md`（如测量口径变化）。

### 13.3 改数据/交互

- 纯数据逻辑改 `inventory_state.gd`；保持动作返回契约与排序键。
- 视图状态改 `backpack_ui.gd`；新增浮层时明确 `add_child` 顺序（或设置显式 z），并更新本文 §3。
- 新增键盘键时放在 `handle_key()` 的正确优先级；注意 `ev.echo` 与返回 `true` 的吞键语义。
- 任何行为变化都要补 smoke 断言；视觉变化要重新出图/视频。

### 13.4 打包给其他引擎

1. 读 `../export/README.md` 的最小步骤。
2. 用 `../export/ui_layout.json` 建 RectTransform/Widget/绝对定位节点；用 `../export/asset_manifest.json` 导入/映射贴图。
3. 按 `CROSS_ENGINE.md` §B/§C 实现状态机、排序、动效与渲染映射。
4. 按 `CROSS_ENGINE.md` 的「移植验收清单」逐项验收；不要用 Godot 的 F1 偏差数字代替目标引擎的实测。

---

## 14. 文档校正记录（T-017）

相对 T-015 的 `TECH.md`，本文按源码核对并修正：

| 项 | 旧文档 | 实际源码 |
| --- | --- | --- |
| 顶层浮层顺序 | `reopen → filter → placeholder → FX → toast → tooltip → confirm` | `reopen_root → tooltip → fx → toast → filter_popup → placeholder → confirm`（同 z 时按 add_child 顺序） |
| F1 覆盖层层级 | 未说明 | `z_index=90` 相对 panel_root；排序高于普通层（含确认框），仅诊断用 |
| 页签动效 | 「金色下划线 160ms Cubic/EaseOut」 | T-015 已移除金色下划线；页签为瞬时换色，无补间 |
| 格子 hover 位移 | 「上抬 -4px」 | `-3px`，120ms Sine/EaseOut |
| 背面「tooltip 不会被 toast 盖住」 | 意图描述 | 实际 tooltip 先加入，toast 后加入；toast 会盖住 tooltip（可接受，但文档需如实） |
| smoke 项数 | 79（v3）→ 86（T-015） | 当前 86；包含 F1 断言 |

另外，本文新增：完整键盘优先级、动作返回契约、数据分布、导出规格/校验入口、跨引擎链接。

---

## 15. 相关文档

| 文档 | 内容 |
| --- | --- |
| [`TECH.md`](TECH.md) | T-014/T-015 视角的布局/色板/状态/动效/性能说明（部分条目以本文为准） |
| [`fidelity-1to1.md`](fidelity-1to1.md) | 参考测量表、误差、颜色采样、例外、回归清单、证据 |
| [`迭代记录.md`](迭代记录.md) | v0–v5 迭代过程与问题修复 |
| [`CROSS_ENGINE.md`](CROSS_ENGINE.md) | A 数据 / B 算法交互 / C 渲染 / D 工具链 + 四引擎映射 + 移植契约与验收 |
| [`PORTABLE_ASSETS.md`](PORTABLE_ASSETS.md) | 资产包清单、九宫格、色板、命名、状态、许可、导出 |
| [`../export/README.md`](../export/README.md) | 导入 Unity/Unreal/Three.js 的最小步骤 + 伪节点树 |
| [`../export/ui_layout.json`](../export/ui_layout.json) | 机器可读布局规格（含归一化 rect/锚点/字号/动效/状态） |
| [`../export/asset_manifest.json`](../export/asset_manifest.json) | 机器可读资产清单（路径/尺寸/九宫格/用途/许可） |
| [`../README.md`](../README.md) | 项目总览、运行、操作、性能、已知限制 |
| [`../CREDITS.md`](../CREDITS.md) | 原创声明、参考来源（未入库）、许可说明 |
