# TECH · 云璃背包 Inventory UI

本文档面向后续工程师 / 美术 / QA：说明布局规格、节点树、数据 schema、交互状态机、动效参数、资产管线、参考差异与验证方法。所有素材均为原创，参考图只用于分析。

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
| 测试 | headless GDScript SceneTree smoke，`INVENTORY_UI_SMOKE_OK` |

启动：

```bash
godot --path .
godot --headless --path . -s tools/smoke_inventory_ui.gd
godot --path . -s tools/capture_inventory_ui.gd -- --shots
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video
```

## 2. 布局规格（1280×720 坐标系）

所有坐标是逻辑像素，最终窗口按 1.5× 缩放到 1920×1080。

| 区域 | 矩形 / 参数 |
| --- | --- |
| 全屏面板 | `(44, 52) – (1216, 706)`，1172×654，圆角约 22px（面板图片 2× 生成） |
| 红色绶带标题 | `(120, 2)`，260×90；标题「物品」36px，副题「背包」12px |
| 关闭钮 | `(1178, 4)`，62×62，圆形金环 + X |
| 左区 | x 60–620 内容区（约 45% 屏宽） |
| 纸娃娃容器 | `(60, 82)`，560×410；光环中心 `(270, 206)` |
| 装备槽 | 96×96，品质描边 3px，等级胶囊 42×18；位置见 §2.1 |
| 属性栏 | `(60, 500)`，560×178：HP/MP 条 300×22，4 项属性 2×2 |
| 右区页签 | `(636, 74)`，552×40；5 个 104×40，gap 8；金色下划线 84×4 滑动 |
| 容量/页码 | `(636, 118)`：`背包容量 35 / 216 · 第 1 / 5 页` |
| 分类筛选 | `(1134, 116)`，68×26，下拉按钮「全部 ▾」 |
| 物品网格 | `(636, 150)`，5×5，格子 104×84，列 gap 8 / 行 gap 7 |
| 滚动条 | 网格右侧，13×448；5 页分段 + 可拖拽金色描边滑块 |
| 钱币行 | `(636, 616)` / `(636, 650)`，372×28；金色铜钱 / 银锭 + 数量 + 「+」 |
| 整理按钮 | `(1024, 612)`，164×80 |
| 详情卡 | `(908, 146)`，282×446，深色玻璃 + 金边 |
| 右侧竖排导航 | `(1218, 140)`，54×376；物品 / 炼丹 / 九州谱，active mint，文字竖排 |
| 空状态 | 网格中央：货袋图标 112px + 标题 + 副文案 |
| 操作提示 | `(894, 118)`：`Tab 切页 · 滚轮翻页 · Enter 使用` |

### 2.1 装备槽位置与顺序（相对纸娃娃容器）

| 槽位 | 位置 | 数据 |
| --- | --- | --- |
| artifact（法宝） | `(222, 0)` | 九霄玄典 · 8 级 · 绝品 |
| boots（鞋履） | `(26, 54)` | 踏云靴 · 8 级 · 珍品 · 未附魔 |
| armor（衣甲） | `(432, 54)` | 玄冰甲 · 8 级 · 珍品 · 未附魔 |
| helmet（头冠） | `(0, 186)` | 流云冠 · 8 级 · 良品 |
| necklace（项链） | `(456, 186)` | 璎珞佩 · 8 级 · 珍品 |
| ring_left（戒指） | `(58, 292)` | 碧玉戒 · 9 级 · 珍品 |
| ring_right（戒指） | `(398, 292)` | 赤金戒 · 9 级 · 良品 |
| weapon（武器） | `(222, 316)` | 青锋剑 · 9 级 · 绝品 |

人物立绘 `(174, 62)`，192×240（原始 SVG 720×900），底部阴影/光环/旋转符文环；右上方 46×46「图鉴」按钮。

### 2.2 色板（核心）

| Token | Hex / 值 |
| --- | --- |
| 面板冰蓝 | `#ecf9ff → #a7c8e0`，95% 不透明 |
| 金边 | 深金 `#6f4a16` / 金 `#b47a2e` / 亮金 `#e8c778` / 高光 `#fff0bd` |
| 红绶带 | `#8f1d29 → #a92c35`，金色描边 |
| 格子 | `#c8e1f2 → #9fc0db`；hover `#e2f4ff → #b6d8ea` |
| 页签 idle | `#d9eefb → #a4c9e2`；active `#c9fbf1 → #58cdbd` |
| 品质 0/1/2/3 | `#e8f0f5` / `#74d99e` / `#68adff` / `#c48bff` |
| HP/MP | `#ff9c8d→#e85049` / `#8bd8ff→#2f8fe0` |
| 详情卡 | `rgba(14,38,55,.965) → rgba(6,19,31,.975)` + 金边 |
| 金色按钮 | `#ffefae → #ffc531`，边 `#a86f19`，文字 `#5a3410` |
| 危险按钮 | `#ffb8ae → #d94a40` |

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
│   │   ├── PaperDoll (560×410)
│   │   │   ├── glow / rune_ring / character SVG
│   │   │   ├── EquipSlot ×8
│   │   │   └── UIButton「图鉴」
│   │   ├── PlayerStatsPanel（HP/MP 条、4 属性、图标 _draw）
│   │   ├── TabBarUI ×5（渐变底 + 金色滑动下划线 + hover）
│   │   ├── capacity label / 操作提示 label
│   │   ├── UIButton filter（全部 ▾）
│   │   ├── InventoryGrid（566×448）
│   │   │   ├── ItemCell ×25（品质边框/角标/锁/数量/选中呼吸/粒子闪）
│   │   │   ├── 空状态（pouch + 文案）
│   │   │   └── PageScroll（拖拽/滚轮 → 页）
│   │   ├── CoinRow ×2 / UIButton 整理
│   │   ├── 绶带 TextureRect / 标题 labels / close TextureButton
│   │   ├── SideNav（物品/炼丹/九州谱）
│   │   └── DetailCard（282×446）
│   ├── reopen_root（关闭态「打开背包」按钮 + 标题）
│   ├── FxLayer（金光粒子；屏幕坐标）
│   ├── Toast
│   ├── ItemTooltip
│   ├── FilterPopup
│   ├── PlaceholderOverlay（炼丹/九州谱/图鉴）
│   └── ConfirmDialog（丢弃确认，置顶）
└── FPS label（F3）
```

渲染顺序：panel_root 内先面板/格子再标题/关闭/侧导航/详情；上层依次 reopen → filter popup → placeholder → FX → toast → tooltip → confirm。这样确认框永远置顶，tooltip 不会被 toast 盖住。

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
- 键盘：方向键选择；Enter 使用；Space 开关详情；Tab 切页；Esc 关面板（先关闭确认/占位/筛选，再关面板）；面板关闭时 B/I 打开；F3 显示 FPS。
- 鼠标：单击选中并打开详情；双击使用；滚轮/拖拽滚动条翻页；点击页签/筛选/侧导航；触摸映射点击。

不可用状态的优先级：任务物品（不可使用/丢弃/出售）> 已装备（只读）> 消耗品无 use > 装备/杂项不可使用 > 已绑定不可出售。详情卡会把每个禁用按钮变灰，并显示一句原因。

## 6. 动效参数

| 动效 | 实现 | 时长 / 曲线 |
| --- | --- | --- |
| 开面板 | panel_root scale .965→1 + alpha 0→1 | 200ms，Cubic/EaseOut |
| 关面板 | scale 1→.94 + alpha 1→0，然后显示 reopen | 180ms，Sine/EaseOut |
| 页签下划线 | GradientRect x tween | 160ms，Cubic/EaseOut |
| 页签/网格刷新 | 网格 alpha 0→1 | 140ms |
| 物品 hover | 内容上抬 -4px + 光晕 + 描边提亮 | 120ms |
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
- **纸娃娃**：`assets/char/cloud_fox.svg` 原创「青丘灵狐·云璃」，720×900，狐耳/银紫长发/白色紫内衬汉服/青玉杖/大尾巴；显示 192×240，底部椭圆阴影 + 呼吸浮动。
- **面板/绶带/关闭钮/符文环/暗角/光晕**：`tools/gen_assets.py` 用 PIL + numpy 程序化生成（渐变、贝塞尔金色藤蔓、云纹、圆角描金边框、柔光纹理），输出 2× 尺寸给 1280 逻辑和 1.5× 截图使用。无参考图像素。
- **背景**：同脚本生成 2560×1440 夜景：青蓝天空、月亮、山脉、云海、左右楼阁剪影、暖灯笼、月桥、前景栏杆、暗角；背面在面板关闭时可见。
- **质量策略**：图标/立绘 SVG 矢量；面板 2× 纹理；UI 矢量用 shader 绘制，避免像素化。项目默认线性过滤，没有启用像素风。

## 8. 参考与差异

参考（仅分析，未入库）：`/tmp/htz_imgs/19.png`、`14.png`、`15.png`，来源 https://htzsy.bbs.duoyi.com/posts/28525681 （幻唐志官方论坛·新手攻略之操作界面篇）。借鉴点：

- 浅青/冰蓝半透明面板 + 金色描边 + 红色绶带标题 + 右上圆形关闭钮；
- 左侧纸娃娃 + 8 个环形装备槽 + 气血/魔法条 + 4 属性 + 货币/整理；
- 右侧顶部页签 + 5×5 网格 + 右下货币 + 右侧竖排导航；
- 品质色描边、堆叠数、槽位等级/未附魔小标签。

原创 / 差异：

- 所有素材、图标、立绘、背景、名称、描述均为本项目原创；不复制截图/Logo/UI 切图/文案；不使用「幻唐志」作为产品名（demo 名：云璃背包）。
- 参考图约 529×356（≈1.49:1），本 demo 为 16:9：格子改为 104×84 的 5×5，左侧槽位与属性按 1280×720 重新标定；保留相对分区（左约 45% / 右约 55%）。
- 参考图没有常驻分类栏；本 demo 用右上「全部 ▾」下拉满足分类筛选且不挤占网格。
- 参考图没有详情浮层；本 demo 增加右侧详情卡 + 操作按钮，以满足可交互验收。
- 竖排导航的「炼丹/九州谱」与图鉴按钮用原创占位面板实现可点击切换，不实现玩法。
- 页 4 刻意为空，用于演示空页状态；临时页展示 1 件试炼凭证。
- 背景、面板角饰与红色绶带比例做了 16:9 适配；面板角饰缩小避免压住信息。
- 参考数值（攻击 1730 等）仅用于布局演示；货币/道具文案为原创。

## 9. 验证与性能

自测（headless，79 项）覆盖：启动/容量/页码、5 页计数、6 分类筛选、空状态、选中、tooltip 淡入淡出、方向键、整理排序、使用扣减/移除/回血、丢弃取消/确认、出售加银两、绑定装备拒绝出售、任务物品拒绝丢弃、筛选 popup、单元格单击/双击、Tab/Shift+Tab/数字键/ESC/B 键、关闭按钮与重新打开。

命令与结果：

```text
$ godot --headless --path . -s tools/smoke_inventory_ui.gd
...
checks=79 failures=0
INVENTORY_UI_SMOKE_OK
```

真实 GPU 截图/视频（1920×1080）：

- 截图 12 张：总览、tooltip、选中详情、装备详情、第 2 页、分类筛选、使用反馈、空页、丢弃确认、整理、炼丹占位、关闭态。
- 视频：12s / 30fps / 1920×1080 MP4，展示 hover、选中、切页、筛选、使用金光/粒子、整理重排、空页、关闭/打开；GIF 960 宽 12fps。
- console：截图/视频运行均无 ERROR/WARNING（见 docs/media/fps.txt、tools 日志）。

性能（Intel HD 6000，GL Compatibility，共享主机）：

- 空闲 1920×1080 SubViewport：多次采样 36–45 FPS（一次 [47,47,45,45,43,43] avg 45/min 43；稍后一次 avg 36/min 27，主机有其他 worker 负载）。
- 401 draw calls，主要来自 25 个格子（图标/数量/品质角标/锁）与页签/按钮渐变。
- 优化：空格子光晕隐藏、装备光晕按品质/悬停显示、纸娃娃自定义绘制节流 30Hz；视频逐帧 JPEG 回读会造成额外 CPU 开销，需与交互帧率区分。
- F3 可在 demo 内查看实时 FPS 与 draw calls。

## 10. 媒体生成

```bash
# 12s 360 帧，逐帧 JPEG 到 /tmp/inv_ui_frames
godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video

ffmpeg -y -framerate 30 -i /tmp/inv_ui_frames/frame_%04d.jpg \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/media/inventory_ui_demo.mp4

ffmpeg -y -i docs/media/inventory_ui_demo.mp4 \
  -vf "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=160[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
  docs/media/inventory_ui_demo.gif
```

## 11. 已知限制 / 后续可做

- 分类为下拉而非常驻分类栏（为保留 5×5 布局与参考观感）。
- 装备槽只读，无换装/附魔/属性联动；货币「+」为占位。
- 炼丹/九州谱/图鉴为占位面板。
- 字体依赖系统 CJK 回退；发布跨平台版本时应自带 OFL 字体（如 Noto Sans SC / Noto Serif SC）。
- 触摸双击不保证被识别为双击；触屏用户通过详情卡操作按钮使用/丢弃/出售。
- 可进一步做 Sprite 批处理/图集以减少 draw calls，或把重复的角标/锁改成共享纹理。
- 本 demo 不含存档、联网、经济与音效。
