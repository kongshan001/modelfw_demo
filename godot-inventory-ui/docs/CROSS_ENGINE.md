# CROSS_ENGINE · 云璃背包跨引擎移植指南

> 目标：把这套 Godot 4.6 背包 UI 的**数据、算法、表现、工具链**拆成引擎无关的四层，能在 Unity（UGUI / UI Toolkit）、Unreal（UMG / Slate）、Three.js（CSS/DOM 或 Canvas 2D）上重建，而不依赖 Godot 节点/类型。
>
> **证据边界**：本文的 Godot 数值/性能/F1 是项目实测；Unity/Unreal/Three.js 的 API 映射是公开资料与工程经验层面的**移植建议**，未在目标引擎实机验证。不要把我方的 13–36 FPS 或 F1 偏差当作其他引擎的实测基线。

## 0. 结论先行

- **三个引擎无关文件就够重建**：
  - `../export/ui_layout.json` —— 放在哪里（px + 归一化 rect、锚点、间距、字号、色 token、动效、交互状态）；
  - `../export/asset_manifest.json` —— 用什么（路径、尺寸、九宫格 margin、用途、许可）；
  - `../data/items.json` —— 显示什么（35 物品 / 8 装备 / 5 页 / 6 分类）。
- **坐标契约**：1280×720 逻辑画布、左上原点、+x 向右、+y 向下、单位 design px；整体等比缩放（contain + letterbox），不做流式重排。
- **表现契约**：颜色用 token；品质不画进图标；按钮/格子/页签/血条是运行时渐变，不是状态切图；面板/关闭钮/背景/立绘/20 图标是位图/矢量。
- **交互契约**：数据变更只经 `InventoryState` 等价层；视图层只读数据 + 发动作；键盘优先级固定；动作返回统一 `{ok, message|reason, removed}`。
- **验收契约**：关键几何 ≤3%（实测 2.71%）、交互清单全过、动效时长一致、无参考素材、有 1920×1080 截图/视频。
- 快速导入见 `../export/README.md`；资产细节见 `PORTABLE_ASSETS.md`；开发背景见 `DEVELOPMENT.md`。

---

# A. 数据协议

## A.1 设计原则

| 原则 | 要求 |
| --- | --- |
| 纯数据 | UTF-8 JSON；不出现引擎类型、节点路径、纹理句柄、脚本类名 |
| 版本化 | 顶层 `schema`（当前 1）；破坏性字段变更时递增，并在导入端做迁移 |
| 宽容解析 | 未知字段忽略；缺失字段用默认值；数值字段显式转 int |
| 稳定顺序 | 数组顺序即 UI 顺序；排序只在明确动作（整理）时发生 |
| 坐标无关 | 数据里不存屏幕坐标；坐标只在 `ui_layout.json` |
| 可本地化 | 文本字段不拼接逻辑；数字/货币格式在展示层处理 |

## A.2 文档 schema

```json
{
  "schema": 1,
  "player": {
    "name": "云璃", "title": "青丘灵狐", "level": 68,
    "hp": 2086, "hp_max": 2586, "mp": 1969, "mp_max": 2769,
    "attack": 1730, "spirit": 757, "defense": 1040, "speed": 464,
    "gold": 1972284, "silver": 208548, "capacity": 216
  },
  "equipment_slots": [
    {
      "slot": "weapon", "name": "青锋剑", "icon": "sword",
      "level": 9, "quality": 3, "enchant": "剑心 +3",
      "desc": "…", "stats": {"攻击": 186, "速度": 34}
    }
  ],
  "items": [
    {
      "id": "huichun_pill", "name": "回春丹", "icon": "potion_red",
      "category": "消耗", "quality": 1, "level": 1,
      "stack": 12, "max_stack": 99, "page": 1,
      "desc": "…", "stats": {},
      "use": {"hp": 500, "text": "气血回复 500"},
      "bindable": true, "sellable": true, "price": 120,
      "discardable": true
    }
  ]
}
```

字段语义与约束见 `DEVELOPMENT.md` §5；完整数据见 `../data/items.json`。

## A.3 枚举与 ID

| 枚举 | 取值 | 说明 |
| --- | --- | --- |
| `category` | `装备` / `消耗` / `材料` / `任务` / `杂项` | 筛选与排序；`全部` 只存在于 UI 状态，不在数据里 |
| `quality` | `0..3` | 凡品 / 良品 / 珍品 / 绝品；颜色映射见 §C.5 |
| `page` | `1..5` | 一 / 二 / 三 / 四 / 临时 |
| `slot` | `artifact/boots/armor/helmet/necklace/ring_left/ring_right/weapon` | 8 个固定 key，顺序即环上顺序 |
| `icon` | 小写 snake_case | 解析为 `assets/icons/icon_<icon>.svg`；缺失回退 `pouch` |

**图标解析契约**：`manifest id = "icon_" + icon_key`；如果目标引擎的图标表用路径键，建立 `icon_key → texture` 字典，禁止用显示名（中文）做键。

## A.4 各引擎加载

| 引擎 | 解析 | 类型建议 | 注意 |
| --- | --- | --- | --- |
| Godot 4.6 | `JSON.parse_string(FileAccess.get_as_text())` → `Dictionary` | `InventoryState`（RefCounted） | 当前实现；`_normalize()` 补默认值 |
| Unity UGUI/UI Toolkit | `JsonUtility` 或 Newtonsoft.Json | C# DTO + `Dictionary<string,int>` | `JsonUtility` 不支持字典/联合类型；`stats`（中文 key）与 `use` 建议用 Newtonsoft 或转成数组 |
| Unreal UMG/Slate | `FJsonSerializer::Deserialize` + `FJsonObjectConverter` | `USTRUCT` / `TMap<FString,int32>` | `use` 是可选联合，建议 `TSharedPtr<FJsonObject>` 或 bool+字段；int64 金额 |
| Three.js | `await (await fetch(url)).json()` | 普通 JS 对象 | 金额 < 2^53，可安全用 Number；不要用 `parseInt` 处理缺省值 |

**金额/堆叠**：用 64 位整数（Godot int / C# long / Unreal int64 / JS Number 安全区）。当前最大金币 1,972,284，远低于 2^53。

## A.5 数据变更与返回契约

目标引擎应保留一个 `InventoryState` 等价类，视图层不得直接改数组。动作返回：

```json
{"ok": true,  "message": "气血回复 500", "removed": false, "name": "回春丹"}
{"ok": false, "reason": "任务物品不可丢弃"}
```

规则：

- `use`：HP/MP 先加后裁剪到上限；满值时改写文案；`stack-1`；0 时移除；`silver` 直接加。
- `discard`：`discardable=false` 拒绝；成功整组移除。
- `sell`：`sellable=false` 或 `price<=0` 拒绝；成功 `silver += price*stack` 并整组移除。
- 所有成功动作后重算容量（= 数组长度）、页码、货币、条值、选中状态。

## A.6 确定性

- 数组顺序是唯一的 UI 顺序来源；不依赖哈希表遍历顺序。
- 整理比较器：`quality ↓ → category_order ↑ → level ↓ → name ↑`；**移植建议追加 `id ↑` 作为最终 tie-break**（当前 Godot 版没有，但同名物品在跨语言排序下可能不稳定）。
- 浮点只用于动画/布局比例；货币/堆叠/等级/价格用整数。
- 数字展示：当前实现无千分位；若目标 UI 要逗号，放在格式化层，并预留宽度（布局不依赖分隔符）。
- 文本换行：详情描述在固定 258×72 盒内自动换行；跨字体时行数可能变化，验收以「不溢出盒子」为准，不要求逐字断行一致。

---

# B. 算法与交互

## B.1 状态机（引擎无关）

```text
Panel: closed ⇄ open
  closed --B/I/Enter/Space/open-button--> open
  open   --Esc/close-button/B/I---------> closed

Page: 1 ↺ 2 ↺ 3 ↺ 4 ↺ 5  (Tab / Shift+Tab / 1–5 / wheel / scrollbar)
  switch → clear selection + close detail + close tooltip

Category: 全部 / 装备 / 消耗 / 材料 / 任务 / 杂项
  change → refresh grid + clear selection + close detail

Selection/Detail:
  none --click cell--> bag-selected + detail(bag)
  none --click equip--> equipped-selected + detail(equipped)
  bag --Space/✕/page/category/remove--> none (detail hidden)
  bag --click cell--> update detail(bag)

Overlays (priority):
  confirm > placeholder > filter-popup > panel
  Esc closes the highest-priority open overlay; otherwise closes panel.
```

## B.2 页 / 分类过滤

```text
page_items(page, category):
  out = []
  for item in items:                      # 保持原始顺序
    if item.page != page: continue
    if category != "全部" and item.category != category: continue
    out.append(item)
  return out

page_all_items(page): same without category filter
```

第 1 页基线：全部 25；装备 9；消耗 5；材料 6；任务 3；杂项 2。
第 2 页 7；第 3 页 2；第 4 页 0；第 5 页 1。

## B.3 选中与键盘移动

```text
move_selection(dx, dy):
  n = visible_count
  if n == 0: return
  if selected < 0: select(0); return
  if dx != 0: next = clamp(selected + dx, 0, n - 1)
  if dy != 0: next = clamp(selected + dy * 5, 0, n - 1)
  select(next)
```

- 网格固定 5 列；上下移动按 +5/-5，不做「同列」几何计算。
- 选中变化发 `selection_changed(index, item)`；详情若已打开则刷新。
- 点击格子也会选中并打开详情；装备槽清空网格选中。

## B.4 使用 / 丢弃 / 出售

```text
can_use(item)      = item has dict "use"
can_discard(item)  = discardable != false
can_sell(item)     = sellable == true AND price > 0

use(item):
  if not can_use: fail "该物品不可直接使用"
  if use.hp:  hp  = min(hp_max,  hp  + use.hp);  if gain<=0: text="气血已满…"
  if use.mp:  mp  = min(mp_max,  mp  + use.mp);  if gain<=0: text="魔法已满…"
  if use.silver: silver += use.silver; text = "…（+N 银两）"
  stack -= 1
  if stack <= 0: remove item
  return {ok:true, message:text, removed}

discard(item):
  if not can_discard: fail "任务物品不可丢弃"
  remove entire stack

sell(item):
  if not can_sell:
    if category == "装备": fail "已认主的装备不可出售"
    else: fail "任务物品不可出售"
  silver += price * stack
  remove entire stack
```

边界：

- HP/MP 条与数字使用「当前/上限」；满值使用仍消耗数量（当前实现如此），只是文案改变。
- 同一物品若同时有 hp+mp，后写入的满值文案覆盖前者（当前实现的边角行为）；移植可按「逐条追加」改善。
- 装备槽物品永远不可使用/丢弃/出售（`mode=equipped` 强制三按钮置灰）。

## B.5 整理排序

```text
order(category) = {装备:0, 消耗:1, 材料:2, 任务:3, 杂项:4}
compare(a, b):
  if a.quality != b.quality: return b.quality - a.quality      # 高→低
  if order(a.cat) != order(b.cat): return order(a.cat)-order(b.cat)
  if a.level != b.level: return b.level - a.level              # 高→低
  if a.name != b.name: return a.name < b.name                  # 升序
  return a.id < b.id                                            # 移植建议
```

- 只重排当前页；其他页保持原顺序。
- 排序后保留当前选中 id（若仍存在），并刷新详情。
- 动画：每格从旧位置 tween 到新位置，180ms + 12ms×index stagger；不要瞬间跳变（视觉验收项）。

## B.6 tooltip 夹取

```text
show_tooltip(anchor, tip=(292,82), screen=(1280,720), margin=12):
  x = clamp(anchor.x, margin, screen.x - tip.x - margin)
  y = clamp(anchor.y, margin, screen.y - tip.y - margin)
```

格子锚点 `(cell.right-4, cell.top+6)`；装备槽锚点 `(slot.right+8, slot.top)`。
tooltip 本身 `mouse_filter=IGNORE`（CSS `pointer-events:none`），不能挡点击。

## B.7 滚动条 → 页

```text
thumb_h = max(52, track_h / pages)          # 10×445, pages=5
usable  = track_h - thumb_h
t       = clamp((mouse_y - thumb_h/2) / usable, 0, 1)
page    = round(t * (pages-1)) + 1
```

- 滚轮：在网格/滚动条上滚 ±1 页。
- 参考图没有可见滚动条；这是新增交互层，低透明度，不要做成高对比原生滚动条。

## B.8 F1 偏差公式（验收工具，不是运行时 UI）

```text
位置误差 = max(|Δx| / 1280, |Δy| / 720)
尺寸误差 = max(|Δw| / w_target, |Δh| / h_target)
偏差%    = max(位置, 尺寸) × 100
```

- 标题/关闭钮按**中心点**比较（参考图边缘被裁切）。
- 新增控件（容量、筛选、详情、滚动条）标记为 added/counted=false，不进最大偏差。
- 当前实测最大 2.71%（整理按钮高 61 vs 62.7），目标 ≤3%。

## B.9 输入优先级

```text
F1 → confirm → placeholder → filter → panel_closed → panel_open
```

- 目标引擎不要把 Esc 同时绑给多个系统；按上表只让最高优先级消费。
- 面板打开时方向键/Enter/Space/Tab/数字键都归背包；面板关闭时 B/I/Enter/Space 重新打开。
- 触屏：把点击映射为鼠标/指针事件；不要依赖双击作为唯一使用路径，详情卡按钮是稳妥路径。

## B.10 确定性

- 不把动画中间值写回数据；`stack/hp/silver` 只在动作完成时变更。
- 随机只用于 FX；布局/排序/选择无随机。
- 帧率无关：动画以「已过时间 / 时长」驱动；不要按帧计数。
- 像素对比时固定 30fps、关闭/固定粒子随机。

---

# C. 渲染表现

## C.1 坐标与布局模型

- 设计画布 1280×720；左上角原点；+x 右、+y 下；单位 design px。
- 整体等比缩放（contain）：`scale = min(viewportW/1280, viewportH/720)`；剩余区域留黑（letterbox）；不改变元素相对位置。
- 最小窗口 960×540；`ui_layout.json` 同时给出 `rect_px` 与 `rect_norm`（= px / 1280, px / 720），两种都可用于建树。
- 所有节点默认左上锚定（`anchors.min=max=[0,0]`）；标题/关闭钮为中心锚点；详情卡为左中 pivot（便于右侧滑入）；全屏浮层为 stretch（min 0,0 / max 1,1）。

## C.2 结构与布局映射

| 概念 | Godot 4.6 | Unity UGUI | Unity UI Toolkit | Unreal UMG / Slate | Three.js CSS/DOM | Three.js Canvas 2D |
| --- | --- | --- | --- | --- | --- | --- |
| 根画布 | `Control` + `stretch/mode=canvas_items`, `aspect=keep` | `Canvas` + `CanvasScaler`（Scale With Screen Size, 1280×720） | `UIDocument` + 根 `VisualElement`（absolute） | `UCanvasPanel` + DPI Scaling | `div` 1280×720 + `transform: scale()` | `canvas` 1280×720，`ctx.scale(s,s)` |
| 矩形定位 | `position` / `size` / `pivot_offset` | `RectTransform.anchorMin/anchorMax/pivot/anchoredPosition/sizeDelta` | `style.left/top/width/height`（px 或 %） | `CanvasPanelSlot` 的 anchors/offsets/alignment | `position:absolute; left/top/width/height` | 显式 rect 绘制 |
| 贴图 | `TextureRect`（`EXPAND_IGNORE_SIZE` + `STRETCH_KEEP_ASPECT_CENTERED`） | `Image`（`preserveAspect`） | `VisualElement.style.backgroundImage` + `unityBackgroundScaleMode` | `UImage` | `<img>` / `background-image` | `ctx.drawImage` |
| 九宫格 | `NinePatchRect` | `Image.type=Sliced` + Sprite Editor Border | `-unity-slice-*` / `unitySliceLeft…` | `UImage` Draw As Box + `Brush.Margin`（按 Slate 归一化语义换算） | `border-image` | 九宫格手工三/九段绘制 |
| 圆角/渐变/描边 | 自定义 shader（SDF 圆角 + 渐变 + gloss + 内侧描边） | 自定义 UI 材质/ShaderGraph，或烘焙 9-slice PNG | 生成渐变纹理或 Shader；`border-radius` 支持圆角 | Material + `UBorder` / 渐变贴图 | `linear-gradient` + `border-radius` + `inset box-shadow` | `createLinearGradient` + `roundRect` + `stroke` |
| 纯色/压暗 | `ColorRect` | `Image` + color | `style.backgroundColor` | `UBorder`/`UImage` tint | `background-color` / `opacity` | `fillRect` |
| 文本 | `Label` + `LabelSettings`（outline） | TextMeshPro（Outline 材质） | `Label`（`-unity-text-outline-*`） | `UTextBlock` + Outline/Shadow | CSS `font` + `text-shadow` / `-webkit-text-stroke` | `fillText` + `strokeText` |
| 点击命中 | `mouse_filter=STOP` + `_gui_input`/signals | `GraphicRaycaster` + `Button`/`EventTrigger` | `PointerDownEvent`/`ClickEvent` + `picking-mode` | `UButton`/`OnMouseButtonDown`（UMG 默认命中测试） | DOM 事件 + `pointer-events` | 手写 rect 命中 |
| 裁剪 | `clip_contents` / `Rect` clip | `RectMask2D` / `Mask` | `overflow:hidden` | `RetainerBox` / clipping | `overflow:hidden` | `ctx.save/clip/restore` |

> Unity 的 9-slice Border 单位是 Sprite 像素；Unreal 的 `Brush.Margin` 采用 Slate 的纹理空间语义（按纹理尺寸归一化），导入后务必用 1×/2× 两种尺寸复核；CSS `border-image-slice` 用源图像素，需配 `border-image-width`。

## C.3 锚点与 pivot

| 节点 | 锚点（相对父） | pivot | 说明 |
| --- | --- | --- | --- |
| 面板 | top-left `(0,0)` | `(0,0)` | 固定 1193×659；缩放动画 pivot 为 `(630,379)` |
| 标题 | center `(0.5,0.5)` | `(0.5,0.5)` | F1 用中心点比较 |
| 关闭钮 | center `(0.5,0.5)` | `(0.5,0.5)` | hover 以中心缩放 |
| 人物台/属性/页签/网格/侧栏/详情 | top-left | `(0,0)` | 固定 rect |
| 详情卡 | left-center `(0,0.5)` | `(0,0.5)` | 从右侧 26px 滑入 |
| 全屏浮层 | stretch `(0,0)-(1,1)` | `(0,0)` | dim/模态/调试 |

**移植原则**：如果目标引擎支持固定设计尺寸 + 整体缩放，直接用绝对 rect 最稳；锚点只用于父级尺寸变化时的保持关系。不要用「百分比布局」重算这些 rect，否则 1:1 会漂移。

## C.4 层级 / z

`ui_layout.json.z_stack` 给出建议层序：

```text
0 backdrop → 5 vignette → 10 dim → 20 panel → 24 character →
26 attributes → 27 grid backing → 28 grid → 29 aux/currency/sort/scroll →
30 tabs → 31 side nav → 32 title → 33 close → 40 detail → 45 reopen →
60 tooltip → 65 fx → 70 toast → 80 filter → 85 placeholder → 90 confirm →
95 debug → 100 fps
```

- Godot 实际实现主要靠 `add_child` 顺序（同 z）；F1 显式 `z=90`。目标引擎建议显式设 z/兄弟顺序，避免「后加的覆盖先加的」隐式规则不可移植。
- 详情卡在面板之上、tooltip 之下；确认框必须最上；toast 在 FX 之上、弹层之下。

## C.5 颜色

### C.5.1 核心色板（hex）

| 组 | Token | 值 |
| --- | --- | --- |
| 面板 | `panel_top` / `panel_bottom` | `#9EC4EC` → `#69A1D2` |
| 金边 | `gold_frame_dark` / `gold_frame` / `gold_frame_light` | `#44300F` / `#A87C3A` / `#F0D696` |
| 文本 | `text_light` / `text_ink` / `text_ink_soft` / `text_muted` | `#F2FBFF` / `#123B56` / `#3F6B84` / `#7F9FB2` |
| 金 | `gold` / `gold_bright` / `gold_deep` / `gold_dark` | `#E8C778` / `#FFF0BD` / `#A87527` / `#6F4A16` |
| 格子 | `cell_top` / `cell_bottom` | `#5F8FBD` → `#4F7CAB` |
| 格子 hover | `cell_top_hover` / `cell_bottom_hover` | `#79A7CF` → `#6090BB` |
| 网格背板 | `grid_back_top` / `grid_back_bottom` | `#517DAB` → `#406B9B` |
| 页签 idle | `tab_idle_top` / `tab_idle_bottom` / `tab_idle_border` | `#96C0DF` → `#5A96C6` / `#D8EFFF` |
| 页签 active | `tab_active_top` / `tab_active_bottom` / `tab_active_border` | `#83DFE0` → `#4FD8C6` / `#EAFFFF` |
| 侧导航 idle | `nav_idle_top` / `nav_idle_bottom` / `nav_idle_border` | `#3F6B98` → `#2A5075` / `#7595B5` |
| 侧导航 active | `nav_active_top` / `nav_active_bottom` / `nav_active_border` | `#5BCDF5` → `#2FB4E6` / `#E8FCFF` |
| 气血 | `hp_top` / `hp_bottom` / `hp_border` | `#FF9A9A` → `#EC6A6A` / `#B84848` |
| 魔法 | `mp_top` / `mp_bottom` / `mp_border` | `#8FD2FF` → `#58AAF2` / `#2F6FAE` |
| 钱币药丸 | `coin_pill_top` / `coin_pill_bottom` / `coin_pill_border` | `#A6CDF0` → `#79AEE2` / `#DFF2FF` |
| 品质 0/1/2/3 | `quality_0..3` | `#D9ECFB` / `#7FC7FF` / `#BD88F0` / `#FFB35F` |
| 品质暗色 | `quality_0_dark..3_dark` | `#8AA6BB` / `#3F7FB8` / `#7A4AB8` / `#B87320` |
| 禁用 | `disabled_top` / `disabled_bottom` / `disabled_border` / `disabled_text` | `#B9C6CF` / `#94A5B1` / `#768B98` / `#E7EEF3` |
| 深玻璃 | `navy_glass_top` / `navy_glass_bottom` | `rgba(14,38,55,0.965)` / `rgba(6,19,31,0.975)` |

按钮色：

| Kind | top → bottom | border | text |
| --- | --- | --- | --- |
| GOLD | `#FFE27A → #E8B92A` | `#9C6A1C` | `#5A3410` |
| SLATE | `#CFE9FB → #8FB9DA` | `#5F8FB0` | `#113B58` |
| DANGER | `#FFB8AE → #D94A40` | `#84231F` | `#4C120F` |
| ICE | `#8FD4FF → #3D9FDD` | `#2A6F9E` | `#0D3F5C` |
| GHOST | `rgba(31,71,97,0.35) → rgba(13,41,61,0.55)` | `rgba(232,199,120,0.70)` | `#FFF0BD` |

### C.5.2 品质边框公式

```text
grid cell border = lerp(quality_color(q), #CFE6F8, 0.42)
grid cell width   = 2.4px (q<2) / 2.8px (q>=2); selected 3.2px #FFEFC8
hover border      = quality_color(q).lightened(20%)
equip slot border = quality_color(q) 4px; hover lightened(12%)
```

颜色空间：sRGB；纹理直通 alpha（straight alpha），不要预乘。目标引擎导入时确认 `sRGB` 与 `Alpha Is Transparency`/`straight alpha` 一致；Godot 使用 `premult_alpha=false`。

## C.6 文本

| 项 | 契约 |
| --- | --- |
| 字体栈 | 正文 PingFang SC / Hiragino Sans GB / Heiti SC / Noto Sans CJK SC / Source Han Sans SC / Microsoft YaHei；标题 STKaiti / Kaiti SC / Songti SC / Noto Serif CJK SC |
| 未打包 | 当前仓库不含字体；发布前必须自带 OFL 字体（Noto Sans/Serif SC），随包附许可 |
| 字号 | 9–38px；逐项见 `ui_layout.json.fonts.sizes`；不要开启 Auto Size/Fit，否则行高/QT 会漂移 |
| 对齐 | 绝大多数垂直居中；详情描述/原因、占位正文为顶部对齐 + 自动换行 |
| 描边 | 标题 5px `#123A5A`；页签 3px；条内数值 3px；属性 2px 白色 45%；详情/提示 1–3px 深色 |
| 竖排 | 侧导航「物\n品」「炼\n丹」「九\n州\n谱」用逐字换行实现，不依赖引擎竖排布局（跨字体最稳） |
| 数字 | 无千分位；若加分隔符，在格式化层，并保持右对齐/居中框不变 |
| 缺失字形 | 启动时检测 CJK 字形；缺失则回退到打包字体，并记录 warning（不要静默豆腐块） |

## C.7 渲染顺序：先面板后格子

- 面板整图 → 人物台（光环/环/立绘/槽）→ 属性 → 网格背板 → 25 格 → 辅助条/钱币/整理/滚动条 → 页签 → 侧导航 → 标题/关闭 → 详情 → 浮层。
- 格子内部：背景/品质边 → 图标 → 数量 → 锁角标 → 选中光/悬停光。光晕在图标之下、背景之上；选中光在格框外侧（-18px 扩张）。
- 面板外发光（标题/关闭/侧导航）可以超出 rect；裁剪只用于网格/卡片内部，不要裁剪整层。

## C.8 动画与缓动

### C.8.1 公式（t ∈ [0,1]）

| 名称 | 公式 |
| --- | --- |
| `linear` | `f(t)=t` |
| `sine-out` | `f(t)=sin(t·π/2)` |
| `sine-in` | `f(t)=1-cos(t·π/2)` |
| `sine-in-out` | `f(t)=-(cos(πt)-1)/2` |
| `cubic-out` | `f(t)=1-(1-t)^3` |
| `cubic-in-out` | `t<0.5 ? 4t³ : 1-(-2t+2)³/2` |
| `back-out` | `c1=1.70158; c3=c1+1; f(t)=1+c3(t-1)³+c1(t-1)²` |
| `sine-loop` | `f(t)=0.5-0.5·cos(2πt)`（用于呼吸/浮动，周期见条目） |
| `step` | `t>=0 → 1`（瞬时） |

### C.8.2 引擎映射

| 动效 | Godot | Unity | Unreal | Three.js |
| --- | --- | --- | --- | --- |
| 开面板 200ms cubic-out | `TRANS_CUBIC/EASE_OUT` | DOTween `Ease.OutCubic` / AnimationCurve | UMG Animation 曲线或 `1-pow(1-t,3)` | `1-Math.pow(1-t,3)` |
| 关面板 180ms sine-out | `TRANS_SINE/EASE_OUT` | `Ease.OutSine` | `FMath::Sin(t*PI/2)` | `Math.sin(t*Math.PI/2)` |
| 详情滑入 160ms cubic-out | Tween position/alpha/scale | Tween `anchoredPosition`/CanvasGroup.alpha/scale | UMG Animation + Translation | CSS transition/JS tween |
| 图标闪光 100ms back-out | `TRANS_BACK/EASE_OUT` | `Ease.OutBack` | 曲线或 back 公式 | back 公式 |
| 呼吸/浮动（循环） | `_process` 里 sin | Update/coroutine 里 sin | Tick 里 sin | rAF 里 sin |
| 整理重排 180ms + 12ms stagger | Tween 每格 + delay | DOTween sequence/stagger | UMG 多个动画或 Tick 插值 | 每个元素独立 delay |
| 页签切换 | 瞬时 set colors | 直接设色 | 直接设色 | 直接设色 |

**时长必须按毫秒/秒**，不要按帧；目标 60/120fps 下视觉应一致。允许 ±20ms 的实现误差，不允许改缓动族（例如把 cubic-out 换成 linear）。

## C.9 性能

项目实测（Godot/Intel HD 6000/共享主机）：344 draw calls，1920×1080 下 13–36 FPS（最新 pass avg 19.5/min 13；早先 avg 33）。这是**本项目基线**，不是目标引擎基线。

移植建议（工程建议，未在目标引擎实测）：

- 25 个格子最容易产生大量 draw calls：把图标 + 品质边 + 数量 + 锁按材质/图集合批；UI 用一张 1024/2048 图集。
- 文本 outline 是 overdraw 大户：标题/页签/数值尽量用同一字体材质或 SDF。
- 渐变/圆角若用逐控件材质，尽量共享同参数材质；或烘焙 9-slice。
- 目标：目标设备 1920×1080 下 60fps；draw calls 尽量 <150；以目标机 Profile 为准。
- 参考图无动态模糊/景深/后处理；不要为了「高级感」加后处理，会破坏 1:1 与性能。

## C.10 与参考的差异（移植时保留）

- 参考 529×356 → 1280×720：16:9 适配；方形槽理论 106.5×89，实现 104×90。
- 参考图没有容量条、分类筛选、详情卡、可见滚动条；这些是新增交互层，F1 中品红标记且不计入 3% 误差。移植时保留，但不要把它们当作参考图元素。
- 参考图无绶带；标题是场景上的浅色书法「物品」。
- 参考图户外背景不复制；使用原创夜景（或目标项目自己的背景）。
- 品质色按参考「紫/橙金」语言重映射；具体 hex 见 §C.5。

---

# D. 工具链

## D.1 真源与派生

| 类型 | 真源 | 派生 |
| --- | --- | --- |
| 布局 | `scripts/ui/*.gd` 的常量 + `docs/fidelity-1to1.md` | `export/ui_layout.json` |
| 数据 | `data/items.json` | 运行时状态（内存） |
| 资产 | `assets/` + `tools/gen_assets.py` + 手绘 SVG | `export/asset_manifest.json` |
| 证据 | Godot 渲染 | `docs/media/*` |

任何改布局/资产/数据的提交，都应同步更新对应 export 文件并跑 `validate_export.py`。

## D.2 校验命令

```bash
# Godot 功能/几何回归（86 项）
godot --headless --path . -s tools/smoke_inventory_ui.gd
# → checks=86 failures=0 / INVENTORY_UI_SMOKE_OK

# 导出 JSON + manifest + 文档链接（仅 Python 标准库）
python3 ../export/validate_export.py
# → EXPORT_LAYOUT_OK / EXPORT_MANIFEST_OK / EXPORT_LINKS_OK

# 截图/视频（真实 GPU）
godot --path . -s tools/capture_inventory_ui.gd -- --shots
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video
```

## D.3 目标引擎导入要点

### Unity（UGUI）

1. **纹理**：把 `assets/` 拷入 `Assets/InventoryUI/`；PNG → Texture Type Sprite (2D and UI)、Sprite Mode Single、Filter Bilinear、Compression None/High Quality、sRGB 开、Alpha Is Transparency（面板/关闭/光晕）；图标 SVG 用 Vector Graphics 包或先批量导出 256 PNG。
2. **画布**：Canvas Screen Space Overlay；CanvasScaler = Scale With Screen Size，Reference 1280×720；为 16:9 外套一个 AspectRatioFitter（Fit In Parent）或只允许 16:9 视口，确保 letterbox 而不是重排。
3. **建树**：用 Editor 脚本读 `ui_layout.json`：`anchorMin/anchorMax/pivot` 取 `node.anchors`，`anchoredPosition/sizeDelta` 取 `rect_px`（父级为画布时直接用 px）；全屏节点用 stretch。
4. **绘制**：面板/关闭/光晕用 Image；按钮/页签/格子用自定义 UI 材质（SDF 圆角+渐变）或烘焙 9-slice；文字用 TextMeshPro（复制字体资产并设置 Outline）。
5. **逻辑**：C# 版 InventoryState；JsonUtility 处理不了中文 key 字典，用 Newtonsoft 或把 `stats`/`use` 转数组；动作返回保持契约。
6. **动效**：DOTween/AnimationCurve；时长/缓动按 §C.8；排序动画用 stagger。
7. **验收**：按本文「移植验收清单」+ 1920×1080 截图。

### Unity（UI Toolkit）

- 根 `UIDocument` + `VisualElement`，panel 设为 absolute、1280×720；`style.left/top/width/height` 用 px；`transform: scale()` 或 `PanelSettings` 的 Scale With Screen Size。
- 背景/图标用 `background-image` + `unityBackgroundScaleMode`；九宫格用 `-unity-slice-*`；渐变用生成的渐变纹理/Shader（UI Toolkit 不支持完整 CSS 渐变）。
- 文本用 `Label`，`-unity-text-outline-width/color`；字体通过 `-unity-font-definition` 指定打包 CJK 字体。
- 事件用 `PointerDownEvent`/`ClickEvent`；命中测试用 `picking-mode`；tooltip 设 `picking-mode=Ignore`。
- 动画用 USS transition（仅限部分属性）或 C# 定时器；复杂的 stagger/呼吸用 C# 驱动。

### Unreal（UMG / Slate）

- 纹理导入 Content/UI；Texture Group = UI，Compression = UserInterface2D，sRGB 开，Filter = Bilinear，Mip Gen Settings = NoMipmaps。
- 根 `UCanvasPanel`（1280×720）+ `UScaleBox`（16:9，Fit）；每个节点用 `CanvasPanelSlot` 设置 anchors/offsets/alignment（绝对 rect 从 JSON 读取）。
- `UImage` 显示面板/图标；9-slice 用 Draw As Box + `Brush.Margin`（按纹理空间归一化换算，导入后目视复核）；渐变/圆角用 Material 或 UBorder。
- 文本 `UTextBlock`：设置打包 CJK 字体、字号、Outline/Shadow；不要开 Auto Wrap 的自动缩放。
- 数据用 `FJsonSerializer` + `USTRUCT`；`stats` 用 `TMap<FString,int32>`；`use` 用可选字段。
- 交互：`UButton`/`OnMouseButtonDown`；键盘在 Widget 的 `OnKeyDown` 中按 §B.9 优先级处理；Esc 的消费方只能是最高优先级。
- 动效：UMG Animation 或 Tick 插值；时长/曲线按 §C.8。

### Three.js（CSS/DOM）

1. `fetch('export/ui_layout.json')`、`fetch('export/asset_manifest.json')`、`fetch('data/items.json')`。
2. 建一个 1280×720 的 `div#stage`；`scale = Math.min(innerWidth/1280, innerHeight/720)`；`transform-origin: top left`；用 flex/absolute 居中实现 letterbox。
3. 按 `nodes` 建绝对定位元素：`left/top/width/height` = `rect_px`；`z-index` 按 §C.4；`<img>` 或 `background-image` 放贴图。
4. 渐变/圆角/描边：`background: linear-gradient(...)` + `border-radius` + `box-shadow: inset 0 0 0 Npx color`；光晕用径向渐变或 `<img src=glow.png>` + `filter: brightness()/opacity`；文字用 CJK 字体 + `text-shadow`。
5. 交互：DOM 事件（click/dblclick/pointerenter/mouseleave）；tooltip `pointer-events:none`；网格滚轮 `wheel`；滚动条 pointerdown/move。
6. 动效：rAF 驱动，按 §C.8 公式；或轻量 tween 库。粒子用独立 canvas 层。
7. 验收：1280×720 与 1920×1080 截图各一张；对照 rect/字号/状态。

### Three.js（Canvas 2D）

- 单 canvas 1280×720（按 devicePixelRatio 放大）；`ctx.scale(scale, scale)`。
- 每个节点一个绘制函数：圆角矩形路径 + `createLinearGradient` + `stroke`；图标 `drawImage`；文字 `fillText`/`strokeText`。
- 命中测试用同一 rect 表（指针坐标除以 scale、减去 letterbox 偏移）；z 按绘制顺序。
- 动效 rAF；粒子在同一 canvas 上层绘制。
- 适合完全自绘/像素级对照；文本换行与字体度量要显式实现。

## D.4 九宫格与图集

| 资产 | 当前是否 9-slice | 源尺寸 | 建议 margin（源 px） | 换算 |
| --- | --- | --- | --- | --- |
| panel | 否（整图） | 2386×1318 | 120（四边） | design 60px；Unity Border=120；Unreal Margin=120/2386、120/1318；CSS slice=120 |
| 按钮（烘焙时） | 否（运行时渐变） | 建议 48×48 @2× | 24（四边） | design 12px；Unity Border=24；Unreal 24/48；CSS slice=24 |
| close | 否（圆形） | 232×232 | 不适用 | 直接缩放 |
| icons/char | 否（矢量/精灵） | 256×256 / 720×900 | 不适用 | 直接缩放/矢量 |
| glow/sparkle/vignette/bg | 否（径向/全屏） | 512/256/1280×720/2560×1440 | 不适用 | 整图拉伸/cover |

图集建议：

- 图标：20 × 256×256；4 列 × 5 行 = 1024×1280（或缩到 128×128 → 512×640）；padding 4px；无 mipmap；sRGB；straight alpha。
- 不要把发光纹理打进图标图集（需要不同采样/尺寸）；光晕单独一张 512。
- 面板不放进图集（大且整图）。

## D.5 媒体/证据

- 截图：1920×1080；总览、F1、tooltip、详情、装备详情、第 2 页、筛选、使用、空页、丢弃确认、整理、占位、关闭（13 张）。
- 视频：10s/30fps/1920×1080 MP4；GIF 960 宽/12fps。
- 跨引擎联系表：`docs/media/export/portable_layout_assets.png`（布局矩形 + 资产缩略图 + 色板 + 数量）。
- 每次改布局/资产，重新出图并替换；不要用旧截图证明新版本。

## D.6 CI 思路

```text
1. godot --headless ... smoke → 必须 INVENTORY_UI_SMOKE_OK
2. python3 export/validate_export.py → 三个 OK
3. 检查 docs/ 内相对链接（validator 已含）
4. 渲染 1920×1080 截图，量 F1/关键 rect，阈值 ≤3%
5. 检查包内无参考图/参考素材（仅原创/CC0）
6. 目标引擎：用同一 layout JSON 生成截图，按验收清单逐项对比
```

---

# 移植契约（必须满足）

| # | 契约 | 值 / 要求 |
| --- | --- | --- |
| 1 | 逻辑画布 | 1280×720，16:9，contain + letterbox；最小 960×540 |
| 2 | 坐标 | 左上原点、+y 向下；rect 同时提供 px 与归一化；静态节点 ±1px / ±0.1% |
| 3 | 面板 | `(17,47) 1193×659`；圆角 15；细金三层描边 |
| 4 | 分界 | `x=653`；左 636 / 右 557 |
| 5 | 页签 | 5 × 103×54，gap 7，pitch 110，原点 `(653,59)` |
| 6 | 网格 | 5×5，槽 102×85，pitch 110×91，原点 `(653,121)`；25 个槽框始终显示 |
| 7 | 装备槽 | 8 × 104×90；中心/本地坐标见 `DEVELOPMENT.md` §7 表；品质边 4px |
| 8 | 属性 | HP/MP 358×30 @ (225,513)/(225,551)；四维在 y=597/641 |
| 9 | 货币/整理 | 药丸 246×32 / 246×30；整理 182×61 @ (994,613) |
| 10 | 侧栏 | 3 × 78×129，gap 16，原点 (1198,87)；活跃 x-8 |
| 11 | 详情 | 290×440 @ (898,132)；三个按钮 76/76/82×38；默认隐藏 |
| 12 | 九宫格 | 面板若切片：源图 margin 120；按钮若烘焙：设计 12px（源 24）；否则用 shader/渐变 |
| 13 | 层级 | 按 §C.4；确认框最上；tooltip 不拦截点击 |
| 14 | 字体 | CJK 字体随包；字号 9–38px；outline 见 `ui_layout.json`；禁止自动缩放 |
| 15 | 动效 | 时长/缓动按 §C.8；±20ms；呼吸/浮动公式一致 |
| 16 | 颜色 | sRGB、straight alpha；品质边框公式一致 |
| 17 | 交互 | §B.1–§B.9 全实现；动作返回契约一致 |
| 18 | 数据 | `items.json` 35/5/6/8；排序 comparator 一致（建议 id tie-break） |
| 19 | 确定性 | 无哈希序/无随机布局；像素对比时固定 FX 随机 |
| 20 | 合规 | 包内无参考截图/图标/Logo/文案；保留 CREDITS/原创声明；字体许可随包 |
| 21 | 例外 | 容量条/筛选/详情/滚动条为新增控件，不计入 1:1 误差 |
| 22 | 证据 | 1920×1080 截图 + 交互录屏 + 验收清单勾选 |

---

# 移植验收清单

> 每项都要有证据（截图/数值/日志），不要只写「看起来一致」。

1. [ ] 画布 1280×720，16:9 contain + letterbox；1280×720 与 1920×1080 截图各一张。
2. [ ] 面板 `(17,47) 1193×659`（±1px）；左右分界 `x=653`（±1px）。
3. [ ] 5 个页签 `103×54`、gap 7、原点 `(653,59)`；活跃页薄荷绿；无金色下划线补间。
4. [ ] 网格 5×5、槽 `102×85`、pitch `110×91`、25 个槽框全部可见；空隙不出现大片空背板。
5. [ ] 8 个装备槽 `104×90`，中心与 `DEVELOPMENT.md` §7 表一致（±2px）；品质边 4px；等级胶囊/未附魔芯片。
6. [ ] HP/MP 条 `358×30` @ (225,513)/(225,551)；四维行 y=597/641；数值随数据变化。
7. [ ] 铜/银药丸 `246×32` / `246×30`；整理 `182×61`；侧栏 3×78×129 gap16；活跃 x-8。
8. [ ] 详情卡 `290×440` @ (898,132)，滑入 26px/160ms，三个按钮状态正确；默认不显示。
9. [ ] 25 格状态：normal/hover/selected/empty/bound；品质边框混合 42%；选中呼吸周期 ≈1.57s。
10. [ ] 按钮 5 种 kind 的 normal/hover/pressed/disabled；hover 1.035、press 0.97；禁用光标正确。
11. [ ] 页签/侧栏的 idle/hover/active 颜色与参考色板一致；侧栏竖排逐字换行。
12. [ ] 开/关面板、reopen、grid 刷新、tooltip、详情、整理、确认、toast、占位、筛选的时长/缓动与 §C.8 一致（±20ms）。
13. [ ] 切页/筛选/选中/tooltip/双击使用/Enter/Space/丢弃确认/出售/整理/空页/关闭重开全部可操作。
14. [ ] 键盘优先级：F1 → confirm → placeholder → filter → panel；Esc 不会同时关闭两层。
15. [ ] 数据：35 件、5 页（25/7/2/0/1）、6 分类（第 1 页 9/5/6/3/2）、8 装备；整理排序一致。
16. [ ] 使用扣减/归零移除/回血裁剪；丢弃整组移除；出售 `price×stack`；任务/绑定限制。
17. [ ] 字体：无豆腐块；标题/正文/数值字号与 `ui_layout.json` 一致；不自动缩放；竖排换行正确。
18. [ ] 颜色：sRGB/straight alpha；品质/禁用/选中/页签/侧栏 hex 与 §C.5 一致。
19. [ ] 层级：详情在面板上、tooltip 不挡点击、确认框最上、toast 在弹层下。
20. [ ] 确定性：连续两次运行布局/排序/选中一致；固定 30fps 截图可复现（FX 关闭/固定种子）。
21. [ ] 性能：目标设备 1920×1080 下达到项目约定帧率；记录 draw calls/CPU/GPU（不要套用 Godot 数字）。
22. [ ] 合规：包内无参考图/参考素材/品牌名；CREDITS/原创声明/字体许可齐全。
23. [ ] 证据：截图/录屏/日志/验收表归档；README 写清运行与测试命令。

---

## 附：最小可移植文件集

```text
godot-inventory-ui/
├── export/ui_layout.json          # 必须
├── export/asset_manifest.json     # 必须
├── export/README.md               # 导入步骤
├── data/items.json                # 必须
├── assets/
│   ├── bg/night_palace.png
│   ├── char/cloud_fox.svg
│   ├── icons/icon_*.svg ×20
│   └── ui/{panel,close,glow,sparkle,vignette}.png
├── docs/CROSS_ENGINE.md           # 本文
├── docs/PORTABLE_ASSETS.md        # 资产细节
├── docs/DEVELOPMENT.md            # 逻辑/状态机
└── CREDITS.md                     # 许可/原创声明
```

`ribbon.png` / `rune_ring.png` 是 legacy，可不带；其余可按目标引擎需要转成 PNG/图集。
