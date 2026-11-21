# export · 引擎无关导入包

> 一句话：**`ui_layout.json` 决定“放在哪里”，`asset_manifest.json` 决定“用什么”，`data/items.json` 决定“显示什么”。**
> 三份文件 + 原创素材，即可在 Unity / Unreal / Three.js 重建当前 UI；不需要 Godot 工程。
> 原理与验收标准：`../docs/CROSS_ENGINE.md`；资产细节：`../docs/PORTABLE_ASSETS.md`；逻辑/状态机：`../docs/DEVELOPMENT.md`。

## 0. 文件

| 文件 | 作用 | 关键内容 |
| --- | --- | --- |
| `ui_layout.json` | 布局 + 表现规格 | 139 个节点、归一化 rect、锚点/pivot、8 装备槽、5×5 网格、字号、色板、交互状态、34 条动效、自检块 |
| `asset_manifest.json` | 资产清单 | 29 个资产（1 背景 / 1 立绘 / 20 图标 / 7 UI 纹理）、源尺寸/显示尺寸、九宫格、用途、许可、字体/数据、运行时配方 |
| `../data/items.json` | 内容数据 | 玩家、8 件装备、35 件物品（5 页 / 6 分类） |
| `validate_export.py` | 自检脚本 | 仅标准库；校验 rect/归一化/包含关系/网格/槽位/manifest 路径尺寸/文档链接 |
| `README.md` | 本文 | 最小导入步骤 + 伪节点树 |

运行自检：

```bash
python3 export/validate_export.py
# EXPORT_LAYOUT_OK
# EXPORT_MANIFEST_OK
# EXPORT_LINKS_OK
```

## 1. 坐标契约（先读）

- 设计画布 **1280×720**，左上原点，+x 向右、+y 向下，单位 design px。
- 整体 **contain** 缩放：`s = min(viewportW/1280, viewportH/720)`；居中留黑边；不重排。
- 每个节点同时有 `rect_px`（绝对设计坐标）和 `rect_norm`（`[x/1280, y/720, w/1280, h/720]`）。
- `parent` 字段指向父节点（`null` = 画布）；**子节点的 rect 仍然是画布绝对坐标**，不是父级局部坐标。
- `within` 字段表示该节点必须落在某个父节点的矩形内（validator 会检查）；`rect_px` 可越过父级表示绘制层（如侧导航超出面板），以 `within` 为准。
- 所有导出 rect 都在 1280×720 内；标题的 Godot 原始 Label 框 `(160,-3) 104×46` 有 3px 上边距，导出规格取画布内文本块 `(160,0) 104×40`，原框记录在 `control_box_px`（中心均为 212,20）。
- 层级：`z_stack` 是建议层序；Godot 实现主要靠兄弟顺序（见 `DEVELOPMENT.md` §3）。

## 2. 引擎无关伪节点树

```text
Stage (1280×720 design, contain scale, letterbox)
├─ Backdrop (cover)                                       z=0
├─ Vignette (stretch)                                     z=5
├─ Dim (full, rgba(2,10,15,0.22), ignore pointer)         z=10
├─ Panel (1193×659 @ 17,47)                               z=20
│  ├─ CharacterStage (560×470 @ 60,47)                    z=24
│  │  ├─ Aura, Character (160×204), RingDecor, CodexButton (40×40)
│  │  └─ EquipmentSlot ×8 (104×90)  # artifact..weapon
│  ├─ Attributes (600×178 @ 60,505)                       z=26
│  │  ├─ HpBar (358×30 @ 225,513) + HpText
│  │  ├─ MpBar (358×30 @ 225,551) + MpText
│  │  └─ StatRow ×4 (attack/spirit/defense/speed)
│  ├─ Tabs (543×54 @ 653,59)                              z=30
│  │  └─ Tab ×5 (103×54, gap 7; 一/二/三/四/临时)
│  ├─ ItemGrid (542×449 @ 653,121)                        z=28
│  │  ├─ GridBacking (555×461 @ 647,115)                  z=27
│  │  ├─ ItemCell ×25 (102×85, pitch 110×91)              # 空格也保留槽框
│  │  ├─ EmptyState (pouch 112 + title 22 + sub 15)
│  │  └─ Scrollbar (10×445 @ 1188,123)                    z=29
│  ├─ AuxStrip: CapacityLabel (340×20 @ 653,578) + FilterButton (124×20 @ 1066,578)
│  ├─ Currency: GoldRow @656,604 / SilverRow @656,656 + SortButton (182×61 @ 994,613)
│  ├─ Title (center 212,20; 38px) + CloseButton (72×72 @ 1198,6)
│  ├─ SideNav (78×419 @ 1198,87)                          z=31
│  │  └─ NavTab ×3 (78×129, gap 16; 物品/炼丹/九州谱)
│  └─ DetailCard (290×440 @ 898,132, hidden by default)   z=40
├─ ReopenLayer (closed state, hidden)                     z=45
├─ Tooltip (292×82, follow cursor, pointer-events none)   z=60
├─ FxLayer (full, ignore pointer)                         z=65
├─ Toast (h 40, y 618, centered)                          z=70
├─ FilterPopup (128×180 @ 1054,418, hidden)               z=80
├─ PlaceholderOverlay (full dim + 640×380 card, hidden)   z=85
├─ ConfirmDialog (full dim + 440×236 card, hidden)        z=90
├─ DebugOverlay (F1, diagnostic, hidden)                  z=95
└─ FpsLabel (F3, hidden)                                  z=100
```

`ui_layout.json.nodes` 的每个条目都有 `parent`，可直接用「父先建、子后挂」的顺序实例化。

## 3. 最小导入步骤

### 3.1 Unity（UGUI）

1. **拷资产**：把 `assets/` 拷到 `Assets/InventoryUI/`。PNG：Texture Type = Sprite (2D and UI)、Filter = Bilinear、Compression = None/High Quality、sRGB = On、Alpha Is Transparency（panel/close/glow）；SVG 用 Vector Graphics 包或先栅格化（`docs/PORTABLE_ASSETS.md` §6.2）。
2. **画布**：新建 Canvas（Screen Space Overlay）；CanvasScaler = Scale With Screen Size，Reference Resolution = 1280×720；用 AspectRatioFitter（Fit In Parent）或固定 16:9 视口实现 letterbox；不要用 Match 造成的非等比拉伸。
3. **建树**：读 `ui_layout.json`。Unity y 轴向上，转换规则：
   - 父级局部坐标：`lx = rect.x - parent.x`，`lt = rect.y - parent.y`；
   - 左上锚定：`anchorMin = anchorMax = (0,1)`，`pivot = (0,1)`，`anchoredPosition = (lx, -lt)`，`sizeDelta = (w,h)`；
   - 中心锚定（标题/关闭）：`anchorMin = anchorMax = (0.5,0.5)`，`pivot = (0.5,0.5)`，`anchoredPosition = (lx + w/2 - parent.w/2, parent.h/2 - (lt + h/2))`；
   - 全屏：`anchorMin=(0,0)`、`anchorMax=(1,1)`、`offsets=0`；
   - 详情卡：`pivot=(0,0.5)`，按左中锚点换算。
4. **绘制**：Image 用 manifest 的贴图；渐变/圆角/描边写一个 UI shader（SDF）或用 9-slice（panel margin 120 源 px）；文字用 TextMeshPro，复制 CJK 字体并设置 Outline。
5. **逻辑**：C# 版 InventoryState；Newtonsoft 解析 `items.json`（`stats` 中文 key、`use` 联合类型）；动作返回 `{ok, message|reason, removed}`。
6. **交互/动效**：按 `docs/CROSS_ENGINE.md` §B/§C；DOTween 或 AnimationCurve，时长/缓动一致。
7. **验收**：`docs/CROSS_ENGINE.md` 的「移植验收清单」+ 1920×1080 截图。

### 3.2 Unreal（UMG / Slate）

1. **导入**：Content/UI；Texture Group = UI、Compression = UserInterface2D、sRGB = On、Filter = Bilinear、Mip = NoMipmaps。SVG 需插件或预栅格化（UE 原生对 SVG 支持有限）。
2. **根**：`UCanvasPanel` 1280×720 + `UScaleBox`（16:9、Fit）；UMG 的 Canvas Slot 使用左上基准、y 向下，与本规格一致。
3. **建树**：读 JSON；每个节点用 `CanvasPanelSlot`：
   - top-left：`SetAnchors(FAnchors(0,0))` + `SetAlignment(FVector2D(0,0))` + `SetPosition(FVector2D(lx, lt))` + `SetSize(FVector2D(w,h))`；
   - center：anchors/alignment (0.5,0.5)，位置按父级中心换算；
   - full：anchors (0,0)-(1,1)，offsets 全 0。
4. **绘制**：`UImage`（panel/close/icons/bg）；渐变/圆角用 Material 或 `UBorder`；9-slice 用 Draw As Box + `Brush.Margin`（按 Slate 纹理空间换算）。
5. **文本**：`UTextBlock` + 打包 CJK 字体 + Outline/Shadow；字号按 JSON；关闭 Auto Size。
6. **数据**：`FJsonSerializer` + `USTRUCT`；`stats` 用 `TMap<FString,int32>`；`use` 用可选字段。
7. **交互/动效**：`UButton`/`OnMouseButtonDown`；Esc 优先级按 §B.9；UMG Animation 或 Tick 插值。
8. **验收**：同 Unity；额外检查 DPI Scaling 下 1280×720 设计坐标不被二次缩放。

### 3.3 Three.js（CSS/DOM 或 Canvas 2D）

**CSS/DOM**：

```js
const [layout, manifest, data] = await Promise.all([
  fetch('export/ui_layout.json').then(r => r.json()),
  fetch('export/asset_manifest.json').then(r => r.json()),
  fetch('data/items.json').then(r => r.json()),
]);

const stage = document.getElementById('stage'); // 1280×720
function fit() {
  const s = Math.min(innerWidth / 1280, innerHeight / 720);
  stage.style.transform = `scale(${s})`;
  stage.style.transformOrigin = 'top left';
  stage.style.left = `${(innerWidth - 1280 * s) / 2}px`;
  stage.style.top = `${(innerHeight - 720 * s) / 2}px`;
}
addEventListener('resize', fit); fit();

for (const [id, node] of Object.entries(layout.nodes)) {
  const el = document.createElement('div');
  const [x, y, w, h] = node.rect_px;
  Object.assign(el.style, {
    position: 'absolute', left: `${x}px`, top: `${y}px`,
    width: `${w}px`, height: `${h}px`, zIndex: node.z ?? 0,
  });
  stage.appendChild(el);
}
```

- 贴图：`<img>` 或 `background-image`；光晕用 `ui_glow` + `opacity/filter`；文字用 CJK 字体 + `text-shadow`。
- 渐变/圆角/描边：`linear-gradient` + `border-radius` + `inset box-shadow`。
- 交互：DOM click/dblclick/pointerenter；tooltip `pointer-events:none`；网格 `wheel`。
- 动效：rAF 按 `docs/CROSS_ENGINE.md` §C.8 公式。

**Canvas 2D**：1280×720 canvas（按 DPR 放大）；`ctx.scale`；每节点按 rect 绘制圆角渐变/图标/文字；命中测试用同一 rect 表；粒子独立层。

### 3.4 Godot（参考实现，不需要导入）

当前工程本身就是参考：`godot --path .` 直接运行；`export/ui_layout.json` 的数值来自 `scripts/ui/*.gd` 常量。移植时如发现文档与实现不一致，以源码 + validator 的结果为准，并回报修正文档。

## 4. 数据/资产映射

- 图标：`manifest.assets[]` 中 `role=item_icon` 的条目，`icon_key` 对应 `items.json` 的 `icon`；建立 `key → texture` 字典。
- UI 纹理：`id` 如 `ui_panel` / `ui_close` / `ui_glow`；manifest 有 `source_size_px` / `display_size_px` / `nine_slice_note`。
- 背景/立绘：`bg_night_palace` / `char_cloud_fox`。
- 数据：`player` / `equipment_slots` / `items`；页/分类/品质/排序见 `docs/DEVELOPMENT.md` §5。
- 状态：没有状态切图；按 `ui_layout.json.interactions.states` 与 `docs/PORTABLE_ASSETS.md` §5 的配方实现。

## 5. 自检与验收

```bash
python3 export/validate_export.py
```

会检查：

- 所有 rect 在画布内（除声明的 title 3px 溢出）、`rect_norm` 与 `rect_px` 一致（误差 ≤1e-6）；
- `within` 包含关系（网格 25 格、页签 5、侧导航 3、8 装备槽、详情按钮等）；
- `self_check` 与真实节点计数/尺寸一致；
- manifest 每个路径存在、PNG/SVG 尺寸与文件一致、九宫格字段存在、许可字段存在；
- `items.json` 的计数与 manifest 一致；
- 本文与三份 docs 的相对链接有效。

目标引擎的验收按 `docs/CROSS_ENGINE.md` 的 23 项清单执行；关键几何 ≤3%、交互全过、动效时长一致、无参考素材、有 1920×1080 截图/录屏。

## 6. 不要做

- ❌ 不要用参考截图/图标/Logo/UI 切图当素材或底图；参考图只在 `/tmp` 用于测量，未入库。
- ❌ 不要把 `rect_norm` 当父级百分比重排；它是相对 1280×720 画布的。
- ❌ 不要把品质色画进图标；品质由边框/文字表达。
- ❌ 不要用引擎默认滚动条/按钮样式替换运行时配方，除非按 §5 完整复刻状态。
- ❌ 不要用「看起来差不多」验收；用 rect/色值/时长/截图证据。
- ❌ 不要在目标引擎里沿用 Godot 的 13–36 FPS 作为性能基线；在目标机重新 profile。

## 7. 相关文档

| 文档 | 内容 |
| --- | --- |
| [`../docs/DEVELOPMENT.md`](../docs/DEVELOPMENT.md) | 节点树/状态机/数据 schema/交互/动效/性能/维护 |
| [`../docs/CROSS_ENGINE.md`](../docs/CROSS_ENGINE.md) | A 数据 / B 算法 / C 渲染 / D 工具链 + 映射表 + 契约 + 验收清单 |
| [`../docs/PORTABLE_ASSETS.md`](../docs/PORTABLE_ASSETS.md) | 资产清单/九宫格/色板/命名/状态/许可/导出 |
| [`../docs/fidelity-1to1.md`](../docs/fidelity-1to1.md) | 参考测量表/误差/例外 |
| [`../CREDITS.md`](../CREDITS.md) | 原创声明/来源/许可 |
| `ui_layout.json` | 布局规格（机器可读） |
| `asset_manifest.json` | 资产清单（机器可读） |
