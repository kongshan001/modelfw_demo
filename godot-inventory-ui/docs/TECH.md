# TECH · 云璃背包 Inventory UI

本文档面向后续工程师 / 美术 / QA：说明布局规格、节点树、数据 schema、交互状态机、动效参数、资产管线、参考差异与验证方法。所有素材均为原创，参考图只用于分析。

> **T-017 更新（2026-11-21）**：新增 [DEVELOPMENT.md](DEVELOPMENT.md)（以源码为准）、[CROSS_ENGINE.md](CROSS_ENGINE.md)、[PORTABLE_ASSETS.md](PORTABLE_ASSETS.md) 和 `../export/` 规格包。本文的 §3 顶层浮层顺序、§6 页签切换 / hover 位移已按源码校正；冲突时以 DEVELOPMENT.md 为准。

## 1. 运行与渲染基线

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.6 stable |
| 渲染器 | GL Compatibility（OpenGL 4.1 / Intel HD 6000 实测） |
| 逻辑分辨率 | 1280×720 |
| 窗口 | 项目默认 1920×1080 override；`canvas_items` 拉伸，可缩放 |
| 截图/视频 | 1920×1080 SubViewport + `size_2d_override=1280×720`，由 `tools/capture_inventory_ui.gd` 渲染 |
| 字体 | `SystemFont`：PingFang SC / Hiragino Sans GB / 黑体回退；标题 KaiTi / 宋体回退。未打包字体。 |
| 输入 | 鼠标 + 键盘；触摸经 `emulate_mouse_from_touch` 映射为点击，操作按钮走详情卡 |
| 测试 | headless GDScript SceneTree smoke，86 项，`INVENTORY_UI_SMOKE_OK` |

启动：

```bash
godot --path .
godot --headless --path . -s tools/smoke_inventory_ui.gd
godot --path . -s tools/capture_inventory_ui.gd -- --shots
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video
```

## 2. 布局规格（1280×720 坐标系）

所有坐标是逻辑像素，最终窗口按 1.5× 缩放到 1920×1080。测量来源与误差表见 `docs/fidelity-1to1.md`。

| 区域 | 矩形 / 参数 |
| --- | --- |
| 全屏面板 | `(17, 47) – (1210, 706)`，1193×659，圆角约 15px（面板图片 2× 生成，细金双层描边） |
| 标题「物品」 | `(160, -3)`，104×46，字号 38，浅色书法 + 深蓝描边；**无绶带**（参考图无） |
| 关闭钮 | `(1198, 6)`，72×72，圆形金环 + 青铜底 |
| 左区内容 | 面板左缘 17 → 左右分界 x=653（49.7% / 50.3%）；纸娃娃容器 `(60,47) 560×470` |
| 纸娃娃环 | 环心相对 `(267,230)`（全局 327,277）；归一化椭圆 rx 262 / ry 218；立绘 `(204,84) 160×204` |
| 装备槽 | 104×90，品质描边 4px，等级胶囊 60×20；位置见 §2.1 |
| 属性栏 | `(60, 505)`，600×178：HP/MP 条 358×30（x=225），4 项属性 2×2（行 y=597/641） |
| 右区页签 | `(653, 59)`，5×103×54，gap 7；活跃页薄荷绿，无金色下划线 |
| 物品网格 | `(653, 121)`，5×5；槽 102×85，步距 110×91；背板 `(647,115) 555×461`；**空位也显示槽框** |
| 滚动条 | 网格右缘内侧 10×445（低透明度，参考图无可见滚动条） |
| 容量/页码辅助条 | `(653, 578)` 340×20，字号 11（新增，参考图无） |
| 分类筛选 | `(1066, 578)`，124×20，下拉「筛选 全部 ▾」（新增，弹层向上） |
| 钱币行 | 铜 `(656, 604)` / 银 `(656, 656)`，300×36；药丸 246×32 / 30 |
| 整理按钮 | `(994, 613)`，182×61，字号 28 |
| 详情卡 | `(898, 132)`，290×440，深色玻璃 + 金边（新增交互浮层，默认不显示） |
| 右侧竖排导航 | `(1198, 87)`，78×129×3，gap 16；物品 / 炼丹 / 九州谱，活跃青色 |
| 空状态 | 网格中央：货袋图标 112px + 标题 + 副文案（空槽框仍显示） |
| F1 对齐检查 | 全屏覆盖层，z=90；`scripts/ui/align_overlay.gd` |

### 2.1 装备槽位置与顺序（相对纸娃娃容器 `(60,47)`）

| 槽位 | 位置 | 数据 |
| --- | --- | --- |
| artifact（法宝） | `(212, 3)` | 九霄玄典 · 8 级 · 绝品 |
| boots（鞋履） | `(47, 48)` | 踏云靴 · 8 级 · 珍品 · 未附魔 |
| armor（衣甲） | `(383, 49)` | 玄冰甲 · 8 级 · 珍品 · 未附魔 |
| helmet（头冠） | `(-2, 186)` | 流云冠 · 8 级 · 良品 |
| necklace（项链） | `(430, 186)` | 璎珞佩 · 8 级 · 珍品 |
| ring_left（戒指） | `(47, 319)` | 碧玉戒 · 9 级 · 珍品 |
| ring_right（戒指） | `(382, 319)` | 赤金戒 · 9 级 · 良品 |
| weapon（武器） | `(218, 367)` | 青锋剑 · 9 级 · 绝品 |

人物立绘 `(204, 84)`，160×204（原始 SVG 720×900），底部阴影/光环/椭圆符文环；`(322,117) 40×40`「图鉴」蓝色按钮。

### 2.2 色板（核心，按参考图区域中位数重新采样）

| Token | Hex / 值 |
| --- | --- |
| 面板冰蓝 | `#9EC4EC → #69A1D2`，细金边 `#44300F / #A87C3A / #F0D696` |
| 格子 | `#5F8FBD → #4F7CAB`；hover `#79A7CF → #6090BB`；背板 `#517DAB → #406B9B` |
| 页签 idle | `#96C0DF → #5A96C6`，边 `#D8EFFF`；active `#83DFE0 → #4FD8C6`，边 `#EAFFFF` |
| 侧导航 idle | `#3F6B98 → #2A5075`；active `#5BCDF5 → #2FB4E6` |
| 品质 0/1/2/3 | `#D9ECFB` / `#7FC7FF` / `#BD88F0` / `#FFB35F`（网格内与 `#CFE6F8` 混合 42%） |
| HP/MP | `#FF9A9A→#EC6A6A` / `#8FD2FF→#58AAF2` |
| 属性文字 | `#2F5C86` + 浅色描边；血蓝条数值白色 |
| 详情卡 | `rgba(14,38,55,.965) → rgba(6,19,31,.975)` + 金边 |
| 金色按钮 | `#FFE27A → #E8B92A`，边 `#9C6A1C`，文字 `#5A3410` |
| 钱币药丸 | `#A6CDF0 → #79AEE2`，数字白 + 深蓝描边 |
| 危险按钮 | `#FFB8AE → #D94A40` |

## 3. 节点树

```text
Main (Control, scripts/main.gd)
├── Background TextureRect (assets/bg/night_palace.png)
├── bg_glow_a / bg_glow_b TextureRect（呼吸）
├── Vignette TextureRect
├── BackpackUI (Control, scripts/ui/backpack_ui.gd)  [全屏；mouse_filter=IGNORE]
│   ├── panel_root (pivot 630,379)
│   │   ├── Dim ColorRect (.22)
│   │   ├── PanelArt TextureRect (panel.png)
│   │   ├── PaperDoll (560×470)
│   │   │   ├── aura / character SVG / 椭圆符文环（_draw）
│   │   │   ├── EquipSlot ×8（104×90）
│   │   │   └── UIButton「图鉴」
│   │   ├── PlayerStatsPanel（HP/MP 条、4 属性、图标 _draw）
│   │   ├── TabBarUI ×5（渐变底 + 薄荷活跃页 + hover）
│   │   ├── InventoryGrid（551×455）
│   │   │   ├── 背板 + ItemCell ×25（品质边框/锁/数量；空槽也显示）
│   │   │   ├── 空状态（pouch + 文案）
│   │   │   └── PageScroll（低对比拖拽/滚轮 → 页）
│   │   ├── capacity label + UIButton filter（新增辅助条 y=578）
│   │   ├── CoinRow ×2 / UIButton 整理
│   │   ├── 标题 Label「物品」/ close TextureButton
│   │   ├── SideNav（物品/炼丹/九州谱）
│   │   ├── DetailCard（290×440，新增浮层）
│   │   └── AlignOverlay（F1 对齐检查，z=90）
│   ├── reopen_root（关闭态「打开背包」按钮 + 标题）
│   ├── FxLayer（金光粒子；屏幕坐标）
│   ├── Toast
│   ├── ItemTooltip
│   ├── FilterPopup
│   ├── PlaceholderOverlay（炼丹/九州谱/图鉴）
│   └── ConfirmDialog（丢弃确认，置顶）
└── FPS label（F3）；F1 切换对齐检查
```

渲染顺序：panel_root 内先面板/格子再标题/关闭/侧导航/详情；顶层 `add_child` 顺序为 **reopen_root → tooltip → FxLayer → toast → filter_popup → placeholder → confirm**。同 z 时后者覆盖前者，所以确认框永远置顶；toast 会盖住 tooltip（可接受）。F1 覆盖层 `z_index=90`，仅诊断用。完整说明见 [DEVELOPMENT.md](DEVELOPMENT.md) §3。

## 4. 数据 schema（data/items.json）

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
      "desc": "寒铁为骨，青霜为锋。剑鸣如风过松梢。",
      "stats": {"攻击": 186, "速度": 34}
    }
  ],
  "items": [
    {
      "id": "huichun_pill", "name": "回春丹", "icon": "potion_red",
      "category": "消耗", "quality": 1, "level": 1,
      "stack": 12, "max_stack": 99, "page": 1,
      "desc": "千年灵芝配晨露炼成。服用后回复 500 气血。",
      "stats": {},
      "use": {"hp": 500, "text": "气血回复 500"},
      "bindable": true, "sellable": true, "price": 120,
      "discardable": true
    }
  ]
}
```

字段说明：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | string | 唯一；交互、选择、测试用 |
| name/desc | string | 原创中文文案 |
| icon | string | → `assets/icons/icon_<icon>.svg` |
| category | 装备/消耗/材料/任务/杂项 | 分类筛选；排序次序 |
| quality | 0–3 | 凡品/良品/珍品/绝品 → 4 档边框色 + 角标 |
| level | int | 装备等级；非装备显示页签等替代信息 |
| stack/max_stack | int | 当前/最大堆叠；使用 -1，归零移除 |
| page | 1–5 | 一/二/三/四/临时 |
| stats | map | 装备加成，如 `{"攻击":120}` |
| use | object? | `hp` / `mp` / `silver` / `text`；没有 use → 使用按钮置灰 |
| bindable | bool | 展示「未绑定·可交易」/「已绑定」 |
| sellable | bool | 出售可用性；出售价 `price × stack` |
| price | int | 单件银两 |
| discardable | bool | 任务物品设为 false，丢弃按钮置灰 |

内置数据：35 个物品堆叠 = 第 1 页 25、第 2 页 7、第 3 页 2、第 4 页 0（刻意的空页）、第 5 页 1；容量 `35/216`。8 件装备槽数据独立。

## 5. 状态与交互

`InventoryState` 负责数据，`BackpackUI` 负责视图与交互。

- 页签：`TabBarUI` 点击或 `Tab/Shift+Tab`、`1–5`；`switch_page()` 刷新网格、清空选中与详情、更新页码。
- 分类：`set_category(cat)`，作用于当前页；6 个分类；组合为空时显示空状态。
- 选中：`InventoryGrid.set_selected_index()` → `ItemCell` 金色描边 + 呼吸光；`BackpackUI` 打开 `DetailCard`。键盘方向键计算 5 列索引移动。
- tooltip：`ItemCell` mouse_entered / `demo_hover` → `ItemTooltip.show_for(item, pos)`，fade-in 140ms；装备槽同理。
- 使用：`use_item(id)` → HP/MP 上限裁剪、银两增加；stack-1；归零从 `items` 移除；刷新容量/页码/HP 条/详情；`FxLayer.burst` 金光 + `ItemCell.play_use_flash`。
- 丢弃：`request_discard_current()` → `ConfirmDialog` 二次确认；任务物品/不可丢弃物品直接 toast 拒绝；确认后整组移除。
- 出售：`sell_item(id)` → 增加银两，移除组；不可出售/已绑定装备拒绝。
- 整理：`sort_page(page)` 按品质↓ → 分类次序（装备/消耗/材料/任务/杂项）→ 等级↓ → 名称↑；`InventoryGrid.refresh(..., animate_map)` 让每个格子从旧位置 tween 到新位置。
- 键盘：方向键选择；Enter 使用；Space 开关详情；Tab 切页；Esc 关面板（先关闭确认/占位/筛选，再关面板）；面板关闭时 B/I 打开；F1 对齐检查；F3 显示 FPS。
- 对齐检查：`set_align_overlay_visible()` / `is_align_overlay_visible()` / `get_align_report()`；报告含每个元素 target/actual/dev_pct，最大偏差进入 smoke 断言（≤3%）。
- 鼠标：单击选中并打开详情；双击使用；滚轮/拖拽滚动条翻页；点击页签/筛选/侧导航；触摸映射点击。

不可用状态的优先级：任务物品（不可使用/丢弃/出售）> 已装备（只读）> 消耗品无 use > 装备/杂项不可使用 > 已绑定不可出售。详情卡会把每个禁用按钮变灰，并显示一句原因。

## 6. 动效参数

| 动效 | 实现 | 时长 / 曲线 |
| --- | --- | --- |
| 开面板 | panel_root scale .965→1 + alpha 0→1 | 200ms，Cubic/EaseOut |
| 关面板 | scale 1→.94 + alpha 1→0，然后显示 reopen | 180ms，Sine/EaseOut |
| 页签切换 | 颜色瞬时切换（T-015 已移除金色下划线） | 无补间 |
| 页签/网格刷新 | 网格 alpha 0→1 | 140ms |
| 物品 hover | 内容上抬 -3px + 光晕 + 描边提亮 | 120ms，Sine/EaseOut |
| 选中呼吸 | `sin(time*4)` 驱动紫色柔光 alpha | 持续，周期 ~1.6s |
| tooltip | alpha 0→1 / 1→0 | 140ms / 100ms |
| 详情卡 | 右侧滑入 26px + alpha + scale .985→1 | 160ms |
| 使用闪光 | icon 1→1.18→1 + 金晕衰减；FxLayer 26 粒 + 3 星芒 + 1 扩散环 | 100–380ms，粒子 ~0.4–0.7s |
| 整理 | 每个格子从旧位置 tween 到新排序位置 | 180ms + 12ms/项 stagger |
| 确认框 | 卡片 scale .94→1 + 全屏 dim fade | 150ms |
| toast | 淡入/上浮 + 1.35s 停留 + 淡出 | 120 / 200ms |

绘制的渐变/圆角统一由 `shaders/rounded_gradient.gdshader` 完成；图标/面板/立绘使用纹理。

## 7. 图标与美术资产管线

- **物品图标**：20 个手绘 SVG（`assets/icons/icon_*.svg`），128×128 viewBox、256×256 光栅导入；统一 3–4px 深梅色描边、金/青/紫/红高光、柔和投影；不用参考游戏图标。
  - 列表：sword / armor / helmet / necklace / ring / boots / bell / tome / feather / potion_red / potion_blue / potion_green / herb / ore / scroll / fish / gem / pouch / chest / peach。
  - 品质不是画进图标的，而是由 ItemCell / EquipSlot / DetailCard 的 4 档边框色 + 角标 + 品质文字表达，可复用。
- **纸娃娃**：`assets/char/cloud_fox.svg` 原创「青丘灵狐·云璃」，720×900，狐耳/银紫长发/白色紫内衬汉服/青玉杖/大尾巴；显示 160×204，底部椭圆阴影 + 呼吸浮动。
- **面板/关闭钮/暗角/光晕**：`tools/gen_assets.py` 用 PIL + numpy 程序化生成（1193×659 冰蓝渐变、细金双层描边、小角饰、柔光纹理），输出 2× 尺寸给 1280 逻辑和 1.5× 截图使用。红绶带与符文环纹理仍保留在 `assets/ui/`，但 1:1 校正后不再使用。无参考图像素。
- **背景**：同脚本生成 2560×1440 夜景：青蓝天空、月亮、山脉、云海、左右楼阁剪影、暖灯笼、月桥、前景栏杆、暗角；背面在面板关闭时可见。
- **质量策略**：图标/立绘 SVG 矢量；面板 2× 纹理；UI 矢量用 shader 绘制，避免像素化。项目默认线性过滤，没有启用像素风。

## 8. 参考与差异（T-015 1:1 校正）

参考（仅分析，未入库）：`/tmp/htz_imgs/19.png`（实际 529×356，约 1.49:1）。完整测量表、归一化坐标、误差、颜色采样与例外见 **`docs/fidelity-1to1.md`**。

借鉴点（只借布局/比例/配色/信息层级/交互语言）：

- 浅青/冰蓝半透明面板 + 细金描边 + 右上圆形关闭钮；标题为场景上的浅色书法（参考图没有绶带）；
- 左侧纸娃娃 + 8 个环形装备槽 + 气血/魔法条 + 4 属性 + 货币/整理；
- 右侧顶部 5 页签（活跃薄荷绿）+ 5×5 网格 + 右下货币 + 右侧竖排导航；
- 品质色描边、堆叠数、槽位等级/「未附魔」小标签。

1:1 校正结果（归一化映射到 1280×720，实测最大偏差 2.71%）：

| 区域 | 参考（529×356） | 目标（1280×720） | 实现 |
| --- | --- | --- | --- |
| 面板 | x 7–500, y 23–349 | (16.9,46.5) 1192.9×659.3 | (17,47) 1193×659 |
| 左右分界 | x=270 | 653.3 | 653 |
| 页签 | 5 × 42.5×27，gap 3 | 103×54.6，gap 7.3 | 103×54，gap 7 |
| 网格 | 5×5，42×42，pitch 45.4×44.8 | 101.6×84.9，pitch 109.9×90.6 | 102×85，pitch 110×91 |
| 装备槽 | 44×44 | 106.5×89.0 | 104×90 |
| 侧导航 | 33×64，gap 8 | 79.8×129.4，gap 16 | 78×129，gap 16 |
| 整理按钮 | 75×31 | 181.5×62.7 | 182×61 |

原创 / 例外：

- 所有素材、图标、立绘、背景、名称、描述均为本项目原创；不复制截图/Logo/UI 切图/文案；不使用「幻唐志」作为产品名（demo 名：云璃背包）。
- 16:9 适配：参考 1.486:1 → 1280×720；归一化映射后方形槽理论 106.5×89，实现取 104×90 保持方形观感，两轴误差 ≤2.32%。
- 参考图没有容量条/分类筛选：保留为网格与钱币行之间空白带的低对比辅助控件（容量 x=653、筛选 x=1066、y=578，高 20），F1 中品红标记且不计入最大误差。
- 参考图没有详情浮层：保留 290×440 右侧详情卡（`(898,132)`，使用/丢弃/出售），默认总览不显示。
- 参考图没有可见滚动条：保留 10px 低透明度拖拽条，嵌在网格背板右缘。
- 红绶带已移除；标题改为浅色书法「物品」+ 深蓝描边。页签不再使用金色下划线，改为参考的薄荷绿活跃页。
- 品质色按参考“紫 / 橙红”语言重映射：凡品 `#D9ECFB`、良品 `#7FC7FF`、珍品 `#BD88F0`、绝品 `#FFB35F`；网格边框向 `#CFE6F8` 混合 42% 以贴近参考的浅冰蓝主调。
- 竖排导航「炼丹/九州谱」与图鉴按钮为原创占位面板；页 4 刻意为空；临时页 1 件。
- 背景为原创夜景；参考户外场景不复制。

## 9. 验证与性能

自测（headless，86 项）覆盖：启动/容量/页码、5 页计数、6 分类筛选、空状态、选中、tooltip 淡入淡出、方向键、整理排序、使用扣减/移除/回血、丢弃取消/确认、出售加银两、绑定装备拒绝出售、任务物品拒绝丢弃、筛选 popup、单元格单击/双击、Tab/Shift+Tab/数字键/ESC/B 键、关闭按钮与重新打开，以及 F1 对齐覆盖层开/关与几何 ≤3% 断言。

命令与结果：

```text
$ godot --headless --path . -s tools/smoke_inventory_ui.gd
...
checks=86 failures=0
INVENTORY_UI_SMOKE_OK

$ python3 export/validate_export.py
...
EXPORT_LAYOUT_OK / EXPORT_MANIFEST_OK / EXPORT_LINKS_OK
```

真实 GPU 截图/视频（1920×1080）：

- 截图 13 张：总览、**F1 对齐检查**、tooltip、选中详情、装备详情、第 2 页、分类筛选、使用反馈、空页、丢弃确认、整理、炼丹占位、关闭态。
- 视频：10s / 30fps / 1920×1080 MP4，展示 hover、选中、切页、筛选、使用金光/粒子、整理重排、空页、关闭/打开；GIF 960 宽 12fps。
- console：截图/视频运行均无 ERROR/WARNING（见 docs/media/fps.txt、tools 日志）。

性能（Intel HD 6000，GL Compatibility，共享主机）：

- 1920×1080 SubViewport：共享主机波动明显，多次采样 **13–36 FPS**（最新 pass [35,16,13,17,18,18] avg 19.5/min 13；早先 pass [28,32,32,36,36,34] avg 33/min 28）。
- 344 draw calls，主要来自 25 个格子（图标/数量/锁）与页签/按钮渐变。
- 优化：空格子光晕隐藏、装备光晕按品质/悬停显示、纸娃娃自定义绘制节流 30Hz；视频逐帧 JPEG 回读会造成额外 CPU 开销，需与交互帧率区分。
- F3 可在 demo 内查看实时 FPS 与 draw calls。

## 10. 媒体生成

```bash
# 10s 300 帧，逐帧 JPEG 到 /tmp/inv_ui_frames
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video

ffmpeg -y -framerate 30 -i /tmp/inv_ui_frames/frame_%04d.jpg \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/media/inventory_ui_demo.mp4

ffmpeg -y -i docs/media/inventory_ui_demo.mp4 \
  -vf "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=160[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
  docs/media/inventory_ui_demo.gif
```

## 11. 已知限制 / 后续可做

- 分类为下拉而非常驻分类栏（参考图也没有常驻分类栏；控件放在网格下方空白带）。
- 参考图为 4:3 类比例，16:9 适配细节与例外见 `docs/fidelity-1to1.md` §7。
- 装备槽只读，无换装/附魔/属性联动；货币「+」为占位。
- 炼丹/九州谱/图鉴为占位面板。
- 字体依赖系统 CJK 回退；发布跨平台版本时应自带 OFL 字体（如 Noto Sans SC / Noto Serif SC）。
- 触摸双击不保证被识别为双击；触屏用户通过详情卡操作按钮使用/丢弃/出售。
- 可进一步做 Sprite 批处理/图集以减少 draw calls，或把重复的角标/锁改成共享纹理。
- 本 demo 不含存档、联网、经济与音效。
