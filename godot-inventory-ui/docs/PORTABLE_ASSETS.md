# PORTABLE_ASSETS · 云璃背包 UI 资产包

> 面向 Unity / Unreal / Three.js 等引擎的**资产清单 + 切图规格 + 状态配方 + 许可**。
> 机器可读版本：`../export/asset_manifest.json`；布局：`../export/ui_layout.json`；导入步骤：`../export/README.md`。
> 所有素材均为本项目原创；参考游戏截图/图标/Logo/UI 切图**未进入仓库**。详见 `../CREDITS.md`。

## 0. 结论先行

- **29 个资产文件**：1 张背景、1 个立绘 SVG、20 个物品图标 SVG、7 个 UI 纹理 PNG（其中 `ribbon.png`、`rune_ring.png` 为 T-014 legacy，当前未使用）。另有 1 份数据 JSON；**0 个打包字体**。
- **没有按钮/页签/格子/血条的“状态切图”**：这些全部由运行时渐变 shader 绘制（5 种按钮 kind、页签 3 态、格子正常/hover/选中/空格、装备槽品质边）。移植时要么复刻渐变配方，要么按 §2 烘焙 9-slice。
- **没有为九宫格切图**：面板是整图 2× 拉伸；关闭钮是圆形贴图；图标/立绘是矢量；光晕/星芒/暗角/背景是整图缩放。若目标引擎必须用 9-slice，建议值见 §2。
- **品质不画进图标**：凡/良/珍/绝由格子/槽位/详情卡的边框色表达；同一图标可跨品质复用。
- **许可**：原创或程序化生成；无第三方美术；字体是系统字体、未随包分发；仓库未附独立 LICENSE，对外分发前需确定授权条款。

---

## 1. 资产包总览

| 组 | 数量 | 路径 | 类型 | 用途 |
| --- | ---: | --- | --- | --- |
| 背景 | 1 | `assets/bg/night_palace.png` | PNG 2560×1440 | 全屏夜景；面板关闭时可见 |
| 立绘 | 1 | `assets/char/cloud_fox.svg` | SVG 720×900 | 原创「青丘灵狐·云璃」 |
| 物品图标 | 20 | `assets/icons/icon_*.svg` | SVG 256×256（viewBox 128） | 背包/装备/详情/空态/占位/确认 |
| UI 纹理 | 7 | `assets/ui/*.png` | PNG | 面板、关闭钮、光晕、星芒、暗角 + 2 个 legacy |
| 数据 | 1 | `data/items.json` | JSON | 35 物品 / 8 装备 / 玩家 |
| 字体 | 0 | — | 系统字体 | 未打包；见 §7 |

### 1.1 UI 纹理细表

| id | 文件 | 源尺寸 | 显示尺寸 | 九宫格 margin | 用途 | 许可 |
| --- | --- | ---: | ---: | --- | --- | --- |
| `ui_panel` | `assets/ui/panel.png` | 2386×1318 | 1193×659 | 无（整图）；可选 120 源 px | 冰蓝面板 + 细金边 + 角饰 | 原创 |
| `ui_close` | `assets/ui/close.png` | 232×232 | 72×72 | 无（圆形） | 右上关闭钮 | 原创 |
| `ui_glow` | `assets/ui/glow.png` | 512×512 | 96–520 动态 | 无（径向） | 标题/人物/按钮/槽位/卡片光晕 | 原创 |
| `ui_sparkle` | `assets/ui/sparkle.png` | 256×256 | 34–56 | 无（粒子） | 使用物品星芒 | 原创 |
| `ui_vignette` | `assets/ui/vignette.png` | 1280×720 | 1280×720 | 无（全屏） | 暗角 | 原创 |
| `ui_ribbon` | `assets/ui/ribbon.png` | 520×180 | 260×90（设计） | 无 | **legacy 未使用**（T-015 移除绶带） | 原创 |
| `ui_rune_ring` | `assets/ui/rune_ring.png` | 1280×1280 | 1280×1280 | 无 | **legacy 未使用**（改为运行时椭圆） | 原创 |

### 1.2 物品图标细表

所有图标：SVG、`width/height=256`、`viewBox="0 0 128 128"`、直通 alpha；主显示 78×78（网格/装备槽），详情 72×72，空态 112×112，占位 146×146，确认框 70×70。

| key | 文件 | 典型用途 |
| --- | --- | --- |
| `sword` | `assets/icons/icon_sword.svg` | 青锋剑 / 星陨剑 / 武器槽 |
| `armor` | `assets/icons/icon_armor.svg` | 玄冰甲 / 御风袍 / 衣甲槽 |
| `helmet` | `assets/icons/icon_helmet.svg` | 流云冠 / 头冠槽 |
| `necklace` | `assets/icons/icon_necklace.svg` | 璎珞佩 / 项链槽 |
| `ring` | `assets/icons/icon_ring.svg` | 碧玉戒 / 赤金戒 / 戒指槽 |
| `boots` | `assets/icons/icon_boots.svg` | 踏云靴 / 鞋履槽 |
| `bell` | `assets/icons/icon_bell.svg` | 紫电符 / 清心铃 / 山神信物 |
| `tome` | `assets/icons/icon_tome.svg` | 九霄玄典 / 天书残卷 / 法宝槽 |
| `feather` | `assets/icons/icon_feather.svg` | 凤羽 / 龙鳞 |
| `potion_red` | `assets/icons/icon_potion_red.svg` | 回春丹 / 九转还魂丹 |
| `potion_blue` | `assets/icons/icon_potion_blue.svg` | 凝神露 |
| `potion_green` | `assets/icons/icon_potion_green.svg` | 百草露 / 醉仙酿 / 百花蜜 |
| `herb` | `assets/icons/icon_herb.svg` | 千年灵芝 / 幽兰草 |
| `ore` | `assets/icons/icon_ore.svg` | 玄铁矿石 |
| `scroll` | `assets/icons/icon_scroll.svg` | 古卷残页 / 藏宝图 / 上古符箓 / 试炼凭证 |
| `fish` | `assets/icons/icon_fish.svg` | 锦鲤 |
| `gem` | `assets/icons/icon_gem.svg` | 寒晶石 / 月光石 |
| `pouch` | `assets/icons/icon_pouch.svg` | 锦囊；空态大图标；图标缺失回退 |
| `chest` | `assets/icons/icon_chest.svg` | 鎏金宝箱 |
| `peach` | `assets/icons/icon_peach.svg` | 瑶池蟠桃 / 灵兽口粮 |

显示尺寸建议：

| 场景 | 尺寸 | 说明 |
| --- | ---: | --- |
| 物品网格 / 装备槽 | 78×78 | 102×85 格内 `(12,3)`；104×90 槽内 `(13,3)` |
| 详情卡 | 72×72 | 88×88 品质框内 `(8,8)` |
| 空态 | 112×112 | 网格中央 |
| 占位卡 | 146×146 | 170×170 品质框内 |
| 丢弃确认 | 70×70 | 卡片左侧 |
| 图标源 | 256×256 | 2×+ 余量；4K 下仍可 |

### 1.3 背景/立绘

| id | 文件 | 源尺寸 | 显示 | 适配 | 说明 |
| --- | --- | ---: | ---: | --- | --- |
| `bg_night_palace` | `assets/bg/night_palace.png` | 2560×1440 | 1280×720 | cover | 原创夜景：青蓝天空、月亮、山峦、云海、楼阁、灯笼、月桥、前景栏杆、暗角 |
| `char_cloud_fox` | `assets/char/cloud_fox.svg` | 720×900 | 160×204 | keep-aspect | 原创狐耳少女；底部阴影/光环/符文环由运行时绘制 |

---

## 2. 九宫格 margin

### 2.1 现状

**当前资产包中没有任何 9-slice**。这是有意为之：

- 面板是完整插画式面板（云纹/角饰/高光分布在全图），整图拉伸到 1193×659；源图 2×，在 1920×1080（1.5×）下仍有富余。
- 按钮/页签/侧导航/格子/血条/钱币药丸/详情卡/弹层都是 `rounded_gradient.gdshader` 运行时绘制，天然支持任意尺寸，不需要切图。
- 关闭钮是圆形贴图；图标/立绘是矢量；光晕/星芒是径向；背景/暗角是整图。

### 2.2 若目标引擎必须用 9-slice

| 资产 | 是否建议 9-slice | 源图 margin（px） | 设计 px | 说明 |
| --- | --- | ---: | ---: | --- |
| `panel.png` | 可选项；不是原始设计 | 120（左/上/右/下） | 60 | 角饰约 102 源 px；120 能包住角饰；中段是平滑渐变+云纹，拉伸可接受；需目视复核 |
| 烘焙按钮（可选） | 建议 | 24 | 12 | 按钮圆角 9 设计 px；24 源 px 能包住圆角+描边；按钮高 38/40/42/56/61 时中段可拉伸 |
| `close.png` | 否 | — | — | 圆形；直接缩放 |
| 图标 / 立绘 | 否 | — | — | 矢量或精灵；直接缩放 |
| `glow` / `sparkle` | 否 | — | — | 径向/粒子；整图缩放 |
| `vignette` / `bg` | 否 | — | — | 全屏拉伸/cover |

换算：

| 引擎 | 9-slice 单位 | panel | 按钮 |
| --- | --- | --- | --- |
| Godot `NinePatchRect` | 源像素 | `patch_margin_left/top/right/bottom = 120` | 24 |
| Unity UGUI `Image` | Sprite Border（源像素） | 在 Sprite Editor 设 Border 120 | 24 |
| Unity UI Toolkit | `-unity-slice-left/top/right/bottom` | 120 | 24 |
| Unreal UMG | `Brush.Margin`（Slate 纹理空间，按纹理尺寸归一化） | `120/2386`, `120/1318` | `24/48` |
| Three.js CSS | `border-image-slice`（源像素）+ `border-image-width`（设计 px） | `slice 120` + `width 60px` | `slice 24` + `width 12px` |

> 注意：UE 的 margin 语义在不同版本/导入设置下可能按纹理像素或归一化 UV 解释；以导入后实际九宫格效果为准，用 1×/2× 两种尺寸验证。

### 2.3 不做 9-slice 时的替代

- Godot：`GradientRect` + shader（当前实现）。
- Unity UGUI：自定义 UI 材质/SDF 圆角；或生成 1×N 渐变纹理 + `Image` 九宫格。
- Unity UI Toolkit：生成的渐变纹理/Shader；`border-radius` + `background-image`。
- Unreal：Material（SDF/渐变）+ `UBorder`/`UImage`；或烘焙。
- Three.js：CSS `linear-gradient` + `border-radius` + `inset box-shadow`；Canvas 2D 路径 + `createLinearGradient`。

---

## 3. 色板（hex）

### 3.1 面板 / 金 / 文本

| Token | 值 | 用途 |
| --- | --- | --- |
| `panel_top` | `#9EC4EC` | 面板渐变顶 |
| `panel_bottom` | `#69A1D2` | 面板渐变底 |
| `panel_ice` | `#7FA9D3` | 面板中间/冰蓝 |
| `panel_deep` | `#6CA0D2` | 面板深部 |
| `gold_frame_dark` | `#44300F` | 面板外描边 |
| `gold_frame` | `#A87C3A` | 金边主色 |
| `gold_frame_light` | `#F0D696` | 金边高光 |
| `title_text` | `#EAF8FF` | 标题「物品」 |
| `title_outline` | `#123A5A` | 标题描边 |
| `text_light` | `#F2FBFF` | 浅色正文/数量 |
| `text_ink` | `#123B56` | 深色文字 |
| `text_ink_soft` | `#3F6B84` | 次级深色 |
| `text_muted` | `#7F9FB2` | 弱化文字 |
| `gold` | `#E8C778` | 金色装饰 |
| `gold_bright` | `#FFF0BD` | 金色高光/按钮文字 |
| `gold_deep` | `#A87527` | 金色阴影 |
| `gold_dark` | `#6F4A16` | 金色深阴影 |
| `mint` | `#5FDFC9` | 活跃页签（辅） |
| `mint_bright` | `#B5F5E9` | 活跃页签（高光） |
| `navy_glass_top` | `rgba(14,38,55,0.965)` | 详情/弹层/占位玻璃顶 |
| `navy_glass_bottom` | `rgba(6,19,31,0.975)` | 玻璃底 |

### 3.2 格子 / 页签 / 侧栏

| Token | 值 | 用途 |
| --- | --- | --- |
| `cell_top` | `#5F8FBD` | 格子顶 |
| `cell_bottom` | `#4F7CAB` | 格子底 |
| `cell_top_hover` | `#79A7CF` | 格子 hover 顶 |
| `cell_bottom_hover` | `#6090BB` | 格子 hover 底 |
| `grid_back_top` | `#517DAB` | 网格背板顶 |
| `grid_back_bottom` | `#406B9B` | 网格背板底 |
| `grid_border_mix` | `#CFE6F8` | 品质边混合目标 |
| `selection_border` | `#FFEFC8` | 选中金边 |
| `selection_glow` | `rgba(255,209,255,1)` | 选中呼吸光（洋红） |
| `hover_glow` | `rgba(255,235,173,0.45)` | 格子 hover 金光 |
| `tab_idle_top/bottom/border` | `#96C0DF` / `#5A96C6` / `#D8EFFF` | 页签 idle |
| `tab_hover_top/bottom/border` | `#A9CFE9` / `#6DA6D3` / `#E6F6FF` | 页签 hover |
| `tab_active_top/bottom/border` | `#83DFE0` / `#4FD8C6` / `#EAFFFF` | 页签 active |
| `tab_idle_text` / `tab_active_text` | `#E8F7FF` / `#FFFFFF` | 页签文字 |
| `nav_idle_top/bottom/border` | `#3F6B98` / `#2A5075` / `#7595B5` | 侧栏 idle |
| `nav_hover_top/bottom/border` | `#4C7BA9` / `#33597F` / `#A9C4DC` | 侧栏 hover |
| `nav_active_top/bottom/border` | `#5BCDF5` / `#2FB4E6` / `#E8FCFF` | 侧栏 active |
| `nav_idle_text` / `nav_active_text` | `#E6F4FF` / `#12506E` | 侧栏文字 |

### 3.3 条 / 货币 / 按钮 / 品质 / 禁用

| Token | 值 | 用途 |
| --- | --- | --- |
| `hp_top` / `hp_bottom` / `hp_border` | `#FF9A9A` / `#EC6A6A` / `#B84848` | 气血条 |
| `mp_top` / `mp_bottom` / `mp_border` | `#8FD2FF` / `#58AAF2` / `#2F6FAE` | 魔法条 |
| `bar_track_top/bottom/border` | `rgba(36,71,102,0.32)` / `rgba(26,56,84,0.40)` / `rgba(230,250,255,0.42)` | 条底槽 |
| `bar_ink` | `#23486B` | 条内数字描边 |
| `coin_pill_top/bottom/border` | `#A6CDF0` / `#79AEE2` / `#DFF2FF` | 钱币药丸 |
| `coin_plus_top/bottom/border` | `#9BD8FF` / `#4F9CD8` / `#2A6C9A` | “+”按钮 |
| `gold_button_top/bottom/border` | `#FFE27A` / `#E8B92A` / `#9C6A1C` | GOLD 按钮 |
| `slate_button_top/bottom/border` | `#CFE9FB` / `#8FB9DA` / `#5F8FB0` | SLATE 按钮 |
| `danger_button_top/bottom/border` | `#FFB8AE` / `#D94A40` / `#84231F` | DANGER 按钮 |
| `ice_button_top/bottom/border` | `#8FD4FF` / `#3D9FDD` / `#2A6F9E` | ICE 按钮 |
| `button_text` | `#5A3410` | GOLD 文字 |
| `slate_button_text` | `#113B58` | SLATE 文字 |
| `danger_button_text` | `#4C120F` | DANGER 文字 |
| `ice_button_text` | `#0D3F5C` | ICE 文字 |
| `quality_0` | `#D9ECFB` | 凡品 |
| `quality_1` | `#7FC7FF` | 良品 |
| `quality_2` | `#BD88F0` | 珍品 |
| `quality_3` | `#FFB35F` | 绝品 |
| `quality_0_dark` | `#8AA6BB` | 凡品暗 |
| `quality_1_dark` | `#3F7FB8` | 良品暗 |
| `quality_2_dark` | `#7A4AB8` | 珍品暗 |
| `quality_3_dark` | `#B87320` | 绝品暗 |
| `disabled_top/bottom/border/text` | `#B9C6CF` / `#94A5B1` / `#768B98` / `#E7EEF3` | 禁用按钮 |
| `stat_text` / `stat_outline` | `#2F5C86` / `rgba(255,255,255,0.45)` | 属性文字/描边 |
| `empty_title` / `empty_sub` | `#F2FBFF` / `#D9ECF8` | 空态文字 |
| `detail_note` / `danger_text` | `#FFB3A6` / `rgba(247,181,166,0.90)` | 详情原因/红色提示 |

> 完整 token 列表在 `../export/ui_layout.json.palette`；每个 token 的用途也在该文件里。

---

## 4. 命名规范

| 类型 | 规则 | 例子 | 备注 |
| --- | --- | --- | --- |
| 物品图标 | `assets/icons/icon_<key>.svg` | `icon_sword.svg` | `<key>` 小写 snake_case；数据 `icon` 字段 = `<key>` |
| UI 纹理 | `assets/ui/<name>.png` | `panel.png`、`close.png` | 文件名 `<name>`；manifest id = `ui_<name>` |
| 背景 | `assets/bg/<name>.png` | `night_palace.png` | manifest id = `bg_<name>` |
| 立绘 | `assets/char/<name>.svg` | `cloud_fox.svg` | manifest id = `char_<name>` |
| 数据 | `data/items.json` | — | schema 1 |
| 导出 | `export/ui_layout.json` / `export/asset_manifest.json` | — | id 与文件名解耦，改文件需同步 manifest |
| 通用 | 全小写、下划线、ASCII，不用空格/中文文件名 | — | 便于 CI/跨平台 |

**不要重命名现有文件**：`asset_manifest.json`、`theme_kit.gd`（`icon(name)` / `ui_tex(name)`）、`items.json` 的 `icon` 字段都按名字解析。若要重命名，全局搜索并同步更新 manifest/数据/文档。

新增一个图标的最小步骤：

1. 画 `assets/icons/icon_<key>.svg`（256×256、viewBox 128、统一 3–4px 描边）。
2. 在 `data/items.json` 的物品/装备里填 `"icon": "<key>"`。
3. 在 `export/asset_manifest.json` 增加一条（可参照现有 20 条），或重新生成 manifest。
4. 跑 `godot --headless --path . -s tools/smoke_inventory_ui.gd` 和 `python3 ../export/validate_export.py`。

---

## 5. 各状态：normal / hover / pressed / disabled / selected

> 本资产包**没有状态切图**；下表是「状态由什么表达」。实现配方见 `CROSS_ENGINE.md` §C.5/§C.8 与 `shaders/rounded_gradient.gdshader`。

### 5.1 物品格子 `ItemCell`

| 状态 | 视觉 | 实现 |
| --- | --- | --- |
| normal | 冰蓝渐变底 + 品质边（2.4px；品质≥2 为 2.8px）+ 图标 + 数量（stack>1）+ 锁（bindable=false） | 运行时 shader + 图标/文字 |
| hover | 底提亮（`#79A7CF→#6090BB`）、边框品质提亮 20%、内容上抬 -3px、金色柔光 0.45 | 120ms Sine/EaseOut |
| pressed | **无**（单击立即选中） | 不实现 |
| disabled | 仅空格子：保留槽框、无图标/数量、鼠标穿透 | `set_empty()` |
| selected | 金色边框 `#FFEFC8` 3.2px + 洋红呼吸光（α 0.24–0.40，周期 1.57s） | `set_selected()` + `_process` |
| carried/bound | 右上银锁 11×9 + 弧线（不改变底/边） | `Decor._draw` |

### 5.2 按钮 `UIButton`

| 状态 | GOLD | SLATE / DANGER / ICE | GHOST |
| --- | --- | --- | --- |
| normal | `#FFE27A→#E8B92A`，边 `#9C6A1C`，文字 `#5A3410` | 见 §3.3 | 深玻璃底 + 金边 + `#FFF0BD` 文字；无光晕 |
| hover | 顶/底提亮 12%/16%，金色光晕 α 0.30，scale 1.035 | 提亮 12%/16%，光晕 α 0.18（ICE 0.30），scale 1.035 | scale 1.035 |
| pressed | scale 0.97（60ms）；松开回 1.035（100ms） | 同左 | 同左 |
| disabled | 底 `#B9C6CF→#94A5B1`、边 `#768B98`、文字 `#E7EEF3`，光标箭头，无 hover/press | 同左 | 同左 |
| selected | **不适用**（按钮无持续选中态） | — | — |

### 5.3 页签 `TabBarUI`

| 状态 | 视觉 |
| --- | --- |
| idle | `#96C0DF→#5A96C6`、边 `#D8EFFF`、文字 `#E8F7FF`、2px 边 |
| hover | `#A9CFE9→#6DA6D3`、边 `#E6F6FF` |
| pressed | **无**（点击即切换，无按下态） |
| disabled | **无**（5 页始终可用） |
| selected (active) | `#83DFE0→#4FD8C6`、边 `#EAFFFF`、文字 `#FFFFFF`、3px 深色描边；**瞬时换色，无下划线补间** |

### 5.4 侧导航 `SideNav`

| 状态 | 视觉 |
| --- | --- |
| idle | `#3F6B98→#2A5075`、边 `#7595B5` 1.6px、文字 `#E6F4FF` |
| hover | `#4C7BA9→#33597F`、边 `#A9C4DC` 1.6px |
| pressed | **无** |
| disabled | **无** |
| selected (active) | `#5BCDF5→#2FB4E6`、边 `#E8FCFF` 2px、文字 `#12506E`、x-8、青色光晕 α 0.28、140ms |

### 5.5 装备槽 `EquipSlot`

| 状态 | 视觉 |
| --- | --- |
| normal | `#8FB8DA→#6F9CC7`、品质边 4px、图标、等级胶囊、「未附魔」芯片（仅该文案） |
| hover | `#A4C9E8→#82ABD2`、品质边提亮 12%、scale 1.045、金光 0.45、120ms |
| pressed | **无**（点击直接打开详情） |
| disabled | **无**（始终可查看） |
| selected | **无持续选中框**；点击后由详情卡表达选中 |
| quality 3 idle | 呼吸金光 α 0.10–0.16，周期 2.856s |

### 5.6 钱币行 / 关闭钮 / 面板

| 组件 | 状态 |
| --- | --- |
| 钱币药丸 | normal `#A6CDF0→#79AEE2`、边 `#DFF2FF`、数字白色 + 深蓝描边；只有 “+” 可点（hover 无整行变化）；pressed/disabled 无 |
| 关闭钮 | normal 金环+青铜面+X；hover scale 1.08 + 光晕 α 0.22→0.42（120ms）；pressed/disabled/selected 无 |
| 面板 | normal 整图；开/关是整体 scale/alpha 动效，不是状态贴图 |

### 5.7 详情卡 / 确认框 / 弹层

| 组件 | 状态 | 说明 |
| --- | --- | --- |
| 详情卡 | closed / bag / equipped | closed alpha 0；bag 显示持有数、交易状态、三按钮可用性；equipped 只读、三按钮禁用、原因「已装备 · 请在装备栏中查看」 |
| 详情按钮 | enabled / disabled | disabled 用 §3.3 禁用色；原因行按数据状态给文案 |
| 确认框 | closed / open / cancelled / confirmed | open 时全屏 dim；cancelled 不改数据；confirmed 整组移除 |
| 筛选弹层 | closed / open / row idle / row hover / row active | active 品红/金色 `◆` 前缀 + `#FFE9B3`；hover `#F3FBFF` |
| 占位层 | closed / alchemy / codex / compendium | 同一卡片换图标/标题/正文/标签 |
| tooltip | hidden / bag / equipped | bag：品质·分类×堆叠 + 操作提示；equipped：已装备·等级·品质 + 查看提示 |
| toast | hidden / showing / cooling | 120ms 入 + 1350ms 停留 + 200ms 出 |
| 空态 | all / filtered | 两种文案；25 个槽框仍显示 |

---

## 6. 资产导出给其他引擎

### 6.1 导出尺寸策略

| 资产 | 建议导出 | 理由 |
| --- | --- | --- |
| panel | 保留 2386×1318（2×），或导出 1193×659（1×） | 1920×1080 下 1.5× 显示，2× 有富余；1× 在 4K 会糊 |
| close | 232×232 | 72 显示，3× 余量 |
| icons | 256×256 PNG（从 SVG 栅格化）或保留 SVG | 78 显示，3× 余量；支持 SVG 的引擎优先矢量 |
| char | 720×900 PNG 或 SVG | 160×204 显示；4K 也够 |
| glow | 512×512 | 最大 520 显示，接近 1:1 |
| sparkle | 256×256 | 34–56 显示 |
| vignette | 1280×720 | 全屏 1×；4K 下可放大 |
| bg | 2560×1440 | 1280×720 的 2×；cover |

### 6.2 SVG → PNG（批量）

```bash
# 任选其一；输出 256×256
mkdir -p /tmp/icons_png
for f in assets/icons/*.svg; do
  rsvg-convert -w 256 -h 256 "$f" -o "/tmp/icons_png/$(basename "$f" .svg).png"
done

# 或 Inkscape
# for f in assets/icons/*.svg; do inkscape "$f" --export-type=png --export-width=256 \
#   --export-filename="/tmp/icons_png/$(basename "$f" .svg).png"; done

# 或 ImageMagick（需 delegate）
# for f in assets/icons/*.svg; do convert -background none -density 288 "$f" \
#   -resize 256x256 "/tmp/icons_png/$(basename "$f" .svg).png"; done
```

立绘：

```bash
rsvg-convert -w 720 -h 900 assets/char/cloud_fox.svg -o /tmp/char_cloud_fox.png
```

> 本机 macOS 也可用 `qlmanage -t -s 256 -o <outdir> <file.svg>` 快速预览；注意 qlmanage 会铺白底，不适合直接当透明贴图。

### 6.3 导入设置

| 项 | Unity | Unreal | Three.js |
| --- | --- | --- | --- |
| 类型 | Sprite (2D and UI) | Texture2D / UI Texture | Texture |
| 过滤 | Bilinear | Bilinear | `THREE.LinearFilter` |
| Mipmap | 关（UI） | NoMipmaps | `generateMipmaps=false` |
| sRGB | 开 | sRGB 开 | `texture.colorSpace = SRGBColorSpace` |
| Alpha | Straight / Alpha Is Transparency（面板/关闭/光晕） | 直通 alpha | `premultiplyAlpha=false` |
| 压缩 | None / High Quality | UserInterface2D | 不压缩 PNG/WebP |
| 图集 | Sprite Atlas（可选） | Paper2D/UI 图集（可选） | 手工图集或独立贴图 |

### 6.4 图集

- 20 个图标 256×256：建议 4 列 × 5 行 = 1024×1280，padding 4px；或降到 128×128 后 512×640。
- 不要把 512 的光晕/星芒打进图标图集（采样需求不同）。
- 面板/背景不进图集。
- 记录每格 UV 到目标引擎的 icon key 映射；`asset_manifest.json` 的 `icon_key` 可直接作为映射键。

### 6.5 状态烘焙（可选）

如果目标 UI 系统完全不支持运行时渐变：

1. 按 §3 颜色 + §5 状态，用 shader/脚本生成每种按钮 kind × 状态、页签 3 态、侧栏 3 态、格子 4 种品质 × 3 态的 9-slice PNG。
2. 尺寸建议：按钮 48×48 @2×（9-slice margin 24）；格子 204×170 @2×（margin 12）；页签 206×108 @2×（margin 18）。
3. 命名：`ui_btn_<kind>_<state>.png`、`ui_tab_<state>.png`、`ui_cell_q<q>_<state>.png`。
4. 保持颜色/圆角/描边与 §3/§5 一致，验收用像素采样对比（允许 ±2/255）。

> 这是可选的移植手段，不是本资产包的一部分；当前交付不包含任何状态切图。

---

## 7. 许可与原创声明

| 项 | 说明 |
| --- | --- |
| 图像/矢量/数据 | 本项目原创或由 `tools/gen_assets.py` 程序化生成；无第三方图库/游戏美术 |
| 参考素材 | `/tmp/htz_imgs/19.png` 仅用于数值测量；**未入库**、未随包分发；未复制截图/图标/Logo/UI 切图/文案 |
| 品牌 | 不使用《幻唐志》名称/Logo 作为产品名；demo 名「云璃背包」，角色「青丘灵狐·云璃」 |
| 字体 | 运行时使用系统 CJK 字体；**未打包/未再分发**。对外发布请替换为 OFL 字体（Noto Sans SC / Noto Serif SC）并随包附许可 |
| 引擎 | Godot Engine 4.6（MIT）；仅引擎层面使用，不随仓库分发引擎 |
| 项目授权 | 仓库未附独立 LICENSE 文件；`CREDITS.md` 提供原创声明与来源。对外分发/商用前需由项目所有者确定授权条款 |
| 第三方工具 | Python/Pillow/numpy（gen_assets）、ffmpeg（媒体）、Godot（运行/测试） |

**再分发检查**：

- [ ] 包内没有 `/tmp/htz_imgs` 或任何参考游戏截图/图标/Logo。
- [ ] 保留 `CREDITS.md`（或等价原创声明）。
- [ ] 若打包字体，附带字体 OFL 许可与版权声明。
- [ ] 若使用 CC0/第三方资产，单独记录来源/许可（本包当前没有）。

---

## 8. 资产验收清单

1. [ ] `export/asset_manifest.json` 中 29 条路径全部存在；PNG/SVG 尺寸与文件头一致。
2. [ ] 20 个 `icon_*.svg` 均为 256×256、viewBox 0 0 128 128；主显示 78×78 清晰无锯齿。
3. [ ] 8 个装备槽图标 key（sword/armor/helmet/necklace/ring/boots/bell/tome）都在；缺失时回退 `pouch`。
4. [ ] `panel.png` 为 2386×1318；显示 1193×659；圆角/金边/角饰完整，无拉伸撕裂。
5. [ ] `close.png` 232×232、72×72 显示；圆形不变形。
6. [ ] `glow.png` / `sparkle.png` 透明背景；着色后无黑边/白边。
7. [ ] `vignette.png` 1280×720 全屏；`bg` 2560×1440 cover 无接缝。
8. [ ] `ribbon.png` / `rune_ring.png` 标记为 legacy，不进入目标 UI 引用。
9. [ ] 色板 hex 与 §3 一致；品质 0–3 与格子/槽位/详情一致。
10. [ ] 状态：按钮 5 kind × normal/hover/pressed/disabled；页签/侧栏 idle/hover/active；格子 normal/hover/selected/empty/bound；装备槽 normal/hover + 品质 3 呼吸。
11. [ ] 九宫格（若使用）：panel margin 120 源 px、按钮 24 源 px；拉伸后角饰/圆角不变形。
12. [ ] 字体：无豆腐块；字号/描边/竖排符合 `ui_layout.json`；未打包字体时有明确替代方案。
13. [ ] 许可：包内无参考素材；CREDITS 存在；字体/第三方资产许可齐全。
14. [ ] 联系表：`docs/media/export/portable_layout_assets.png` 与当前资产一致。

---

## 9. 相关链接

| 文档/文件 | 内容 |
| --- | --- |
| [`../export/asset_manifest.json`](../export/asset_manifest.json) | 机器可读资产清单（路径/尺寸/九宫格/用途/许可） |
| [`../export/ui_layout.json`](../export/ui_layout.json) | 布局/色板/状态/动效 |
| [`../export/README.md`](../export/README.md) | 导入 Unity/Unreal/Three.js 最小步骤 |
| [`CROSS_ENGINE.md`](CROSS_ENGINE.md) | 四层拆分 / 映射表 / 移植契约 / 验收清单 |
| [`DEVELOPMENT.md`](DEVELOPMENT.md) | 节点树 / 状态机 / 数据 / 交互 / 动效 / 性能 |
| [`../CREDITS.md`](../CREDITS.md) | 原创声明与参考来源 |
| [`media/export/portable_layout_assets.png`](media/export/portable_layout_assets.png) | 布局规格 + 资产联系表 |
