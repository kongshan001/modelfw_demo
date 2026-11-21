# 跨引擎移植 · CROSS_ENGINE

> **结论先行**：把项目拆成 **A 数据协议 / B 算法 / C 渲染表现 / D 工具链** 四层后，规则可以在任何引擎重写，美术可以按 manifest 直接切片，表现参数照本文映射。**权威数据源**是 [`export/cards.json`](../export/cards.json) 与 [`export/asset_manifest.json`](../export/asset_manifest.json)；**权威规则规格**是 [DEVELOPMENT.md](DEVELOPMENT.md)。Godot 只是参考实现，不是移植依赖：`export/slice_atlas.py` 已能在无 Godot 环境完成切片与校验。

**事实边界**：

- A/B 层：来自本项目源码与冒烟测试，属于**已验证行为**。
- C 层：Godot 实现的**实测参数**；其他引擎 API 是**工程映射建议**，未在本仓库逐引擎实跑。
- D 层：Python 工具已在本机跑通；Unity/Unreal/Three.js 的导入命令是通用做法，需按目标版本核对。

---

## 1. 四层拆分

| 层 | 内容 | 是否依赖引擎 | 交付物 | 复刻方式 |
| --- | --- | --- | --- | --- |
| **A 数据协议** | 棋盘规格、卡牌/将军/套牌、资产 manifest、图集帧 JSON、坐标/矩形/单位约定 | 否 | `export/cards.json`、`export/asset_manifest.json`、`assets/**/*.json` | 直接读 JSON；字段名/坐标约定见 §2 |
| **B 算法** | 回合状态机、规则校验、动作事件、AI 评分、胜负、确定性/指纹 | 否 | 本文 + [DEVELOPMENT.md](DEVELOPMENT.md) | 按规格重写纯逻辑；用 §5 验收 |
| **C 渲染表现** | 棋盘/单位/手牌/UI/FX、图集切帧、滤镜、深度、动画时序 | 是 | 本文 §3 映射表 + `docs/shots/` 参考图 | 按映射表实现；像素探针验收 |
| **D 工具链** | 资产切片/重打包、manifest 校验、冒烟/回归、截图/FPS | 部分 | `export/slice_atlas.py`、`export/build_exports.py`、`tools/*` | Python 工具跨引擎复用；引擎侧写等价校验 |

**移植顺序建议**：A → B（纯逻辑 + 测试）→ C（先静态棋盘/单位/手牌，再动画/FX）→ D（把冒烟与 manifest 校验接入 CI）。不要先做 UI 再补规则。

---

## 2. A 层：数据协议

### 2.1 坐标与单位（强制）

| 约定 | 值 | 说明 |
| --- | --- | --- |
| 逻辑分辨率 | `1280×720` | 所有布局常量以此为基准 |
| 原点 | 左上角 | `x` 向右，`y` 向下 |
| 棋盘 | `9×5` | 格坐标 `x∈[0,8]`、`y∈[0,4]` |
| 格尺寸 | `88×88` 逻辑 px | 不是世界单位；进引擎后统一缩放 |
| 棋盘原点 | `(236,104)` | 屏幕/画布坐标 |
| 格中心 | `(236+(x+0.5)*88, 104+(y+0.5)*88)` | 单位/FX 的落点 |
| 玩家将军 | `(4,4)` → 屏幕 `(632,500)` | 底线 |
| AI 将军 | `(4,0)` → 屏幕 `(632,148)` | 顶线 |
| 邻接 | 4 邻接，无斜线 | 曼哈顿距离 |
| 图集矩形 | `[x0,y0,width,height]` | `x1=x0+w`、`y1=y0+h` 是**排他边界**；无 trim/rotation |
| 图集原点 | 左上角 | PNG 像素坐标 |

### 2.2 卡牌协议

`export/cards.json` 是 `data/cards.json` 的规范化只读视图（原始文件不变）。关键结构：

```json
{
  "schema": "gridbound.cards/1",
  "board": { "cols": 9, "rows": 5, "cell_px": 88, "origin_px": [236,104] },
  "rules": { "mana_cap": 9, "hand_limit": 6, "...": "..." },
  "generals": [
    { "id": "general_f1", "faction": "f1", "stats": {"atk":2,"hp":20},
      "art": {"asset_id":"f1_general","static_frame":{"animation":"idle","index":0}} }
  ],
  "cards": [
    { "id": "f1_backlinearcher", "type": "unit", "faction": "f1", "cost": 2,
      "keywords": ["ranged"], "stats": {"atk":1,"hp":3},
      "art": {"asset_id":"f1_backlinearcher","static_frame":{"animation":"idle","index":0},
              "card_frame_asset_id":"f1_unit"} },
    { "id": "f1_truestrike", "type": "spell", "faction": "f1", "cost": 2,
      "spell": {"effect":"damage","amount":3,"target":"enemy_minion"},
      "art": {"asset_id":"icon_f1_truestrike","static_frame":{"animation":"truestrike","index":0},
              "card_frame_asset_id":"f1_spell"} }
  ],
  "decks": { "player": ["..."], "ai": ["..."] }
}
```

移植约定：

- `id` 是稳定主键；不要用显示名做键。
- `type` 只有 `unit` / `spell`；`faction` 只有 `f1` / `f2` / `neutral`。
- 单位：`stats.atk` / `stats.hp` / `opening_heal` / `keywords`。
- 法术：`spell.effect` / `spell.amount` / `spell.target`。
- `art.asset_id` 对应 manifest 中的资产 id；`card_frame_asset_id` 对应卡框资产 id。
- 套牌是两个 card id 数组；顺序是“洗牌前”的原始顺序。
- `rules` 是方便阅读的常量副本；**规则逻辑仍以实现为准**，不要只靠这些字段驱动。

### 2.3 资产 manifest 协议

`export/asset_manifest.json` 顶层：

| 字段 | 用途 |
| --- | --- |
| `schema` | `gridbound.asset-manifest/1`；不兼容变更需升版本 |
| `coordinate_system` | 坐标/矩形/棋盘索引约定 |
| `license` / `source` | CC0 1.0、来源 repo + commit + 上游路径 |
| `reference_runtime` | 参考实现的运行时参数（缩放、FPS、深度、滤镜、布局） |
| `counts` | 资产/图集/动画/帧总数，校验用 |
| `validation` | 校验命令与检查项说明 |
| `assets[]` | 每个 PNG 一条；字段见下 |

每个资产：

| 字段 | 说明 |
| --- | --- |
| `id` | 稳定 id（通常是文件名 stem） |
| `kind` | `unit_atlas` / `spell_icon_atlas` / `fx_atlas` / `tile_texture` / `card_frame` |
| `path` | 项目根相对 POSIX 路径，必须存在 |
| `upstream_path` | 上游仓库内路径 |
| `size_px` | PNG 宽高 |
| `sha256` | PNG 内容哈希 |
| `license` | `CC0-1.0`（逐资产冗余，便于单独抽取） |
| `source` | `{repo, commit, path}`，逐资产来源 |
| `frame_data` | 帧 JSON 相对路径（仅图集） |
| `frame_data_sha256` | 帧 JSON 内容哈希 |
| `animations` | `{动画名: {frames:[{name, rect:[x,y,w,h]}]}}`，顺序与源 JSON 一致 |
| `frame_count` | 总帧数 |
| `frame_size_px` / `frame_sizes_px` | 统一/非统一帧尺寸 |
| `reference_runtime` | 该资产的参考缩放、锚点、FPS、循环、默认动画、静态卡面帧 |
| `used_by` | `board_unit` / `general:f1` / `card_art:<id>` / `spell_art:<id>` / `vfx:<event>` / `tile:<state>` / `card:<id>` 等用途标签 |

**自校验**：`python3 export/slice_atlas.py verify --manifest export/asset_manifest.json` 会检查路径、PNG 尺寸、SHA-256、JSON 帧名/矩形/帧数、动画集合、静态帧索引、counts 一致性。

### 2.4 图集帧 JSON 协议（原始 CC0 格式）

```json
{
  "texture_filename": "f1_general.png",
  "width": 1024,
  "height": 1024,
  "frames": {
    "idle": [
      {"frame_name": "f1_general_idle_000.png", "x0": 404, "y0": 0,
       "x1": 504, "y1": 100, "width": 100, "height": 100}
    ],
    "run": [], "attack": [], "hit": [], "death": []
  }
}
```

- `frames` 的键是动画名；常见：`idle` / `run` / `attack` / `hit` / `death`；部分单位有 `hurt`、`breathing`、`cast*`、`projectile`。
- 数组内顺序即播放顺序；`frame_name` 只作标识，不必是文件名。
- 帧矩形已烘焙，不需要再算网格；帧尺寸可以整张统一，也可以不一致（`fx_impact`）。
- `width`/`height` 必须等于 PNG 实际尺寸；已在本项目全部 24 个 JSON 上验证。

---

## 3. C 层：Godot / Unity / Unreal / Three.js 映射

> 下表是**工程映射建议**；Godot 列是实测实现，其他列未在本仓库逐项实跑。API 版本：Unity 6（2D/URP）、Unreal Engine 5（Paper2D/UMG）、Three.js r160+（2026 年写法可能更新）。

| 概念 | Godot 4.6（参考实现） | Unity 6（2D） | Unreal 5（Paper2D/UMG） | Three.js |
| --- | --- | --- | --- | --- |
| 坐标/原点 | Control/Node2D，左上原点，y 向下 | UI/Canvas 左上原点；世界空间 y 向上，需转换 | UMG 左上原点；Paper2D 世界 y 向上/前向；建议 UI 空间 | 画布左上原点；WebGL/Three 世界 y 向上，建议 UI 相机或 `screenY = 720 - y` |
| 棋盘绘制 | `BoardView._draw()` 画矩形 + tile PNG | `Graphic`/`Mesh`/`SpriteRenderer` + Tilemap 或 UI Image | UMG `Image`/`Border` 或 Paper2D TileMap | Canvas2D 叠加或 `PlaneGeometry` + `MeshBasicMaterial` |
| 格尺寸 | 88×88 逻辑 px | Canvas reference 1280×720，1 unit=1 px 或 PPU 100 | UMG 1280×720 设计尺寸；世界单位另定 | 正交相机 1280×720，1 unit=1 px |
| 棋盘原点 | `(236,104)` | 同逻辑值（Canvas 坐标） | 同逻辑值（UMG 坐标） | 同逻辑值（UI 坐标） |
| 图集/Atlas | `AtlasTexture(atlas, region)` | `Sprite.Create(texture, rect, pivot, PPU)`；或 Sprite Atlas + Sprite Editor | Paper2D `Sprite` 的 Source Region；或 UMG Image + 材质 UV | `Texture` + 自定义 UV / 每帧 `texture.clone()` 设 `offset/repeat`；或预切片 PNG |
| 图集原点 | 左上 | 左下（Sprite rect 以左下为原点；`Sprite.Create` 的 rect 用像素坐标） | 左上（Texture 坐标；UV 需按引擎约定） | 左下（UV v=0 在底部；PNG 顶行对应 v=1） |
| 动画帧 | 自写 `AtlasAnim`：换 `AtlasTexture`，`_process` 累加 `fps` | `AnimationClip` + Sprite 关键帧（按 fps 采样），或自写帧计时器 | Paper2D `Flipbook`（每帧 sprite + fps），或 UMG 材质/序列帧 | 自写帧计时器 + 每帧 UV；或 `THREE.AnimationMixer` + 精灵关键帧 |
| 帧率/循环 | idle 8 / run 13 / attack 17 / hit 15 / death 14；FX 24；idle/run 循环 | 同左；Clip 的 sample rate 设为对应 fps | Flipbook frames per second 同左 | 同左；用 `delta` 累加，不按屏幕刷新固定步进 |
| 单位锚点 | 帧中心（Sprite2D 默认），位置格中心 `(0,-2)` | Pivot `(0.5,0.5)`；`transform.position = cellCenter + (0,-2)` | Sprite pivot `(0.5,0.5)`；位置格中心 + `(0,-2)` | `SpriteMaterial` 的 `center=(0.5,0.5)`；位置格中心 + `(0,-2)` |
| 单位缩放 | 1.22；将军 ×1.1 | 同左（按帧像素尺寸，不做归一化） | 同左 | 同左 |
| 深度/排序 | `z_index = 10+y`；FX 60；死亡 55；覆盖层 1000 | `SpriteRenderer.sortingOrder` 或 Canvas `sortingOrder`；FX 60 等 | UMG `ZOrder`；Paper2D `TranslucencySortPriority` | `renderOrder` 或 `z`；`depthTest=false` 的 2D 场景注意顺序 |
| 像素过滤 | 图集/图标/单位 `NEAREST`；卡框/棋盘 tile `linear` | `FilterMode.Point` / `Bilinear` | Texture `Filter=Nearest`；Compression=UserInterface2D；NoMipmaps | `magFilter/minFilter = NearestFilter`；卡框用 LinearFilter |
| 相机 | 无 Camera2D；根 Control 按 viewport 缩放 | Canvas `ScreenSpaceOverlay` + CanvasScaler 1280×720；或正交相机 size=3.6（PPU 100） | UMG 1280×720；或正交相机 OrthoWidth=1280 | `OrthographicCamera(left=0,right=1280,top=720,bottom=0)`，或 UI 层 DOM |
| UI | Control/Theme/SystemFont | uGUI 或 UI Toolkit；TextMeshPro（CJK 需字体资产） | UMG；Font/TextBlock（CJK 需字体） | DOM/CSS overlay 或 Canvas 2D 文本；Web 字体 |
| 输入 | `_gui_input` / `_unhandled_input`；空格/R/Esc | Input System / EventSystem；UI Raycast | Enhanced Input / UMG OnClicked | Pointer Events / `Raycaster` |
| RNG | `RandomNumberGenerator`（PCG32），seed | `System.Random` / `Unity.Mathematics.Random` / 自实现 PCG32 | `FRandomStream` / 自实现 | 无内置 seed；自实现 PCG32 或 `seedrandom` |
| JSON | `JSON.parse_string`，Dictionary 保留插入顺序 | `JsonUtility`（不支持字典/多态）→ Newtonsoft/System.Text.Json | `FJsonObject` / `FJsonSerializer` | `JSON.parse` |
| 资源加载 | `FileAccess` 字节 + `Image.load_png_from_buffer` | `Resources.Load` / Addressables / `Texture2D.LoadImage` | Content Browser 导入 UTexture2D / Runtime Load | `TextureLoader` / `fetch` + `createImageBitmap` |
| 时间/动画驱动 | `_process(delta)`；Tween | Update + Animator/Tween 库 | Tick + Flipbook/Timeline | `requestAnimationFrame` + clock delta |
| 字体/CJK | 系统字体回退 | TMP 字体资产（需打包 Noto Sans SC 等） | UMG 字体资产 | CSS `font-family` 或打包 webfont |

**三个最容易踩的坑**：

1. **UV 翻转**：PNG 顶部对应 Three.js/OpenGL 纹理的 `v=1`（Three.js 默认 `flipY=true`；若关闭需翻转公式）；Unity Sprite rect 以左下为原点。用 `[x0,y0,w,h]`（左上）进引擎时必须转换，否则帧上下颠倒或错位。
2. **图集出血**：帧与帧之间可能相邻；`atlas.filter_clip = true`（Godot）/关闭 mipmap/加 padding（Unity/Unreal）避免采样到邻帧。
3. **非统一帧尺寸**：单位帧 80–130px 不等；不要假设所有单位 100×100。按 manifest 的 `frame_size_px` / `frame_sizes_px` 读取。

---

## 4. 移植契约（必须满足）

### C1 坐标与单位

- 逻辑画布固定 1280×720；窗口自适应时按 `min(w/1280, h/720)` 等比缩放并留黑边（Godot `keep` 的等价行为）。
- 棋盘格 88×88；原点 `(236,104)`；格中心公式固定。
- 内部规则只用整数格坐标；px 只在渲染/输入层出现。

### C2 锚点与偏移

| 元素 | 锚点 | 偏移/缩放 |
| --- | --- | --- |
| 单位精灵 | 帧中心 | 格中心 + `(0,-2)`；scale 1.22；将军 ×1.1 |
| 地面阴影 | 椭圆中心 | 单位 + `(0,31)`；半径 28；y 缩放 0.34 |
| 攻/血徽章 | 左上 | 攻击 `(-31,17)`、生命 `(11,17)`，21×21 |
| FX | 帧中心 | 格中心；scale 按 FX 表 |
| 死亡残影 | 帧中心 | 格中心；scale 同单位；z 55 |
| 手牌 | 卡面中心（pivot 0.5） | 中心 x=640；间距 118；y=564+附加偏移 |
| 棋盘 tile | 左上 | 88×88 非等比拉伸 |
| 卡框 | 左上 | 104×144 非等比拉伸 |

### C3 深度顺序

```
背景 → 棋盘底格/高亮 → 单位（10 + y）→ 死亡残影 55 → FX 60
     → UI 面板/手牌（手牌选中 40、悬停 60；与侧栏区域基本不重叠）
     → 胜负覆盖层 1000
```

单位 y 越大越靠前；同 y 时按 uid 稳定排序（参考实现依赖添加顺序，移植建议显式 uid）。

### C4 图集/UV

- 矩形以左上为原点，`[x0,y0,w,h]`，排他边界；不旋转、不 trim。
- 单位/图标/FX 用最近邻；卡框/tile 用线性。
- 不允许 mipmap 导致的帧间渗色；如使用 mipmap，给图集加 padding 或关闭。
- 保留原始 PNG 与 JSON；切片工具只生成派生文件，不修改源。

### C5 时间与动画

- 规则是**事件驱动**，没有固定逻辑 tick；不要用帧率驱动规则。
- 动画按 fps 独立计时：idle 8、run 13、attack 17、hit 15、death 14、FX 24。
- 循环：idle/run 循环；attack/hit/death/FX 单次。
- AI 播放节奏：召唤 0.48s、移动 0.34s、攻击 0.58s、法术 0.68s、其他 0.25s；回合开始 0.45s。只影响观感，不影响规则。
- 动画名回退：`hit→hurt`、`idle→breathing`、`run→idle`、`attack→cast`、`death→idle`；最后回退 JSON 第一个动画。

### C6 确定性

- 洗牌：Fisher-Yates；若要与参考完全一致，移植 Godot 的 PCG32 + `randi_range`；否则**注入牌序**作为测试输入。
- 规则层不得使用时间、随机数、无序容器遍历、语言默认哈希。
- AI：固定遍历顺序与 tie-breaker（分数 → 费用 → id / uid / y,x）；浮点比较用容差或统一量化。
- 状态哈希：按 [DEVELOPMENT.md §9.2](DEVELOPMENT.md#92-fingerprint) 的字段与顺序；跨引擎用 canonical JSON（键排序、无空格）或逐字段比较。不要直接比对 Godot 的 SHA。
- 至少保留两组向量：seed 777 与 20260227（见 DEVELOPMENT §9.3）。

### C7 Manifest 与资产

- 所有资产 id/路径以 `export/asset_manifest.json` 为准；路径为项目根相对 POSIX 路径。
- 不要重命名/覆盖原始 PNG/JSON；派生资产放独立目录并在工具侧记录来源。
- 每个资产保留 `license` / `source` / `upstream_path`；游戏内保留 CC0 声明与商标边界。
- 新增资产：更新 manifest（`build_exports.py`）并跑 `slice_atlas.py verify`；不要把未登记文件塞进加载器。

### C8 数据与规则分离

- 卡牌数值、套牌、keywords 从 JSON 读取；不要在 UI/AI 里硬编码卡表。
- 规则动作返回事件字典（或等价结构），表现层不得直接读写规则状态。
- 死亡单位先从状态移除、再把快照交给表现层（或保留 tombstone），避免动画丢失位置。

### C9 品牌与许可

- 不使用 Duelyst 名称/Logo 作为游戏品牌；保留原创标题（《格间牌战 / Gridbound》或自有名称）。
- 不引入非 CC0 素材；CC0 不覆盖商标。
- 分发时保留 `assets/duelyst_cc0/LICENSE`、`SOURCE.md`、`CREDITS.md` 或等价声明。

---

## 5. 移植验收清单

### 5.1 数据/工具链

- [ ] `python3 export/slice_atlas.py verify --manifest export/asset_manifest.json` 输出 `MANIFEST_OK assets=35 atlas_assets=24 animations=109 frames=1291`。
- [ ] 读取 `export/cards.json`：16 张卡（12 随从 + 4 法术）、2 将军、双方套牌各 20 张。
- [ ] 读取 `export/asset_manifest.json`：35 个资产、24 个图集、109 个动画、1291 帧。
- [ ] 任一图集切片后的帧矩形与 manifest 一致；`f1_general` 的 `idle` 为 11 帧，首帧矩形 `[404,0,100,100]`。
- [ ] `f2_onyxjaguar` 的 `run` 为 6 帧；`fx_f2_phoenixfire` 的 `default` 为 38 帧；`icon_f1_truestrike` 有 `truestrike`(4) + `active`(19)。
- [ ] 图集加载无上下翻转、无邻帧渗色；透明边缘正确。

### 5.2 规则（逐项可自动断言）

- [ ] 初始：玩家手牌 4、AI 手牌 3；玩家将军 `(4,4)` 20/2；AI 将军 `(4,0)` 20/2。
- [ ] 双方首次回合法力都是 1；玩家其后每回合 +1，封顶 9，每回合回满。
- [ ] 玩家先手；`end_turn` 正确切换；结束后不能继续行动。
- [ ] 召唤格 = 己方将军/随从的 4 邻接空格；不能空降、不能占位、不能斜角。
- [ ] 召唤扣法力、扣手牌；普通随从当回合可移动不可攻击；疾行可攻击。
- [ ] 登场治疗：疗愈秘术师使己方将军 +2（不超过上限）。
- [ ] 移动只能 1 格、4 方向、不能穿/停在其他单位上；移动后仍可攻击。
- [ ] 近战只能打曼哈顿距离 1；远程只能同行/列、距离 1–2、距离 2 中间为空；斜线/距离 3 拒绝。
- [ ] 相邻敌方嘲讽强制目标；移除嘲讽后恢复正常；远程贴脸时同样被强制。
- [ ] 每次攻击后 `can_attack=false`；无反击；攻击后可移动（若未移动）。
- [ ] 单位 HP≤0 立即移除；死亡快照含 uid/name/owner/card_id/x/y/is_general/sprite。
- [ ] 法术目标：`friendly_any` 含将军；`friendly_minion` 不含将军；`enemy_minion` 不含将军；`enemy_any` 含将军。
- [ ] 治疗不超过 max_hp；伤害可击杀将军；加攻永久；法术不触发嘲讽。
- [ ] 将军死亡即结束；结束后所有动作拒绝；双方同时死亡的行为已显式定义（参考实现保持未分胜负，移植建议定义平局）。
- [ ] 手牌上限 6；满手抽牌仍消耗牌库并弃置；牌库空不抽、无疲劳。
- [ ] 换牌每回合 1 次：手牌回牌库底、再抽 1、手牌数不变。
- [ ] 牌库 20 张；抽牌顺序与 §5.4 向量一致（或显式注入）。

### 5.3 AI 与确定性

- [ ] AI 动作顺序：出牌（可多次）→ 走位 → 攻击 → 结束。
- [ ] AI 每回合能结束；不会死循环；`action_count>120` 有硬保护。
- [ ] AI 不使用换牌；不使用规则外状态。
- [ ] 同 seed + 同玩家操作序列产生相同状态哈希（逐字段比较）。
- [ ] 不同 seed 的初始牌序不同（至少 seed 777 vs 778）。
- [ ] 移植若保留自带 RNG：明确写出算法与 `randi_range` 映射；否则测试通过注入牌序完成。

**固定向量（seed 777 初始手牌）**：

```
Player: f1_silverguardsquire, f1_ironcliffeguardian, f1_truestrike, f1_sundropelixir
AI:     f2_sparrowhawk, f2_sparrowhawk, f2_cobrastrike
```

完整牌库顺序见 [DEVELOPMENT.md §9.3](DEVELOPMENT.md#93-参考测试向量实测)。

### 5.4 渲染/布局

- [ ] 1280×720 下棋盘矩形 `(236,104,792,440)`；玩家将军格中心 `(632,500)`，AI `(632,148)`。
- [ ] 单位精灵帧中心对齐格中心 + `(0,-2)`；缩放 1.22；将军 ×1.1；无意外归一化。
- [ ] 手牌 `104×144`，6 张时中心 x=640、间距 118、扇形 ±5.5°、选中上移 26px、悬停 1.34×。
- [ ] 深度：单位 `10+y`、死亡 55、FX 60、覆盖层 1000；重叠时顺序正确。
- [ ] 图集最近邻、卡框/tile 线性；无模糊/渗色。
- [ ] 动画帧率与循环符合 §C5；idle 相位错开（参考 `uid*3`）。
- [ ] FX 缩放：impact 2.3、slash 0.95、heal 1.15、buff 1.8、summon 0.82、phoenix 0.95。
- [ ] 中文 UI 在目标设备有可用字体；否则内置 CJK 字体。

### 5.5 性能与发布

- [ ] 目标设备 1280×720 下待机与 AI 动画 ≥30 FPS（参考机 Intel HD 6000：待机 avg 62.2/min 42；AI avg 55.7/min 40，实测）。
- [ ] 无每帧重建整手牌/重复解码 PNG 的热点（参考实现有缓存与签名判断）。
- [ ] 资产导出过滤包含原始 PNG（若沿用字节加载）；或改用引擎导入资源。
- [ ] 包体不含 `.godot/`、临时切片、测试截图之外的中间产物。
- [ ] LICENSE / SOURCE / CREDITS 随包分发；无 Duelyst 商标作为品牌。

---

## 6. 推荐实现路线（按引擎）

### Unity 6（2D/URP）

1. 建 2D URP 工程；Canvas 设计分辨率 1280×720，`ScreenMatchMode=MatchWidthOrHeight`，匹配宽高比。
2. 写 `CardDatabase`（Newtonsoft/System.Text.Json）读 `cards.json`；写 `AssetManifest` 读 manifest。
3. 图集：用 `Sprite.Create(texture, new Rect(x,y,w,h), new Vector2(0.5f,0.5f), 100f)`；注意 Unity Rect 以左下为原点，转换 `y_unity = textureHeight - (y0 + h)`。
4. 动画：优先自写帧计时器（简单、确定），或生成 AnimationClip（采样率 = fps，keyframe 切换 Sprite）。
5. 棋盘/单位：UI Canvas 或 SpriteRenderer；排序用 `sortingOrder`（单位 10+y 等）。
6. 规则：纯 C# 类库（无 UnityEngine 依赖），用 NUnit 跑 §5.2；AI 同 §8。
7. RNG：测试注入牌序；若需同 seed，移植 PCG32 或在文档声明 RNG 不同。
8. UI 文本：TMP + 打包 Noto Sans SC（OFL）或系统字体方案。

### Unreal 5（Paper2D + UMG）

1. 导入 PNG：Texture2D，`Compression Settings = UserInterface2D (RGBA)`、`Filter = Nearest`、`Mip Gen Settings = NoMipmaps`（卡框/tile 可用 Linear + Default）。
2. 图集：Paper2D `Sprite` 设 Source Region（像素坐标），pivot 0.5；或 UMG `Image` + 材质 UV。
3. 动画：Paper2D `Flipbook` 按 fps 配帧；FX 24fps；循环标记按 §C5。
4. UI/棋盘：UMG Canvas 1280×720；单位可用 UMG Image（纯 2D）或 Paper2D 正交场景。
5. 规则：纯 C++/Blueprint 不依赖 UI；JSON 用 `FJsonSerializer`；AI 用确定性排序。
6. RNG：`FRandomStream`；若需复现 Godot 牌序，注入牌序或实现 PCG32。
7. 字体：UMG Font 资产打包 CJK 字体。

### Three.js（Web）

1. 用 `OrthographicCamera` 建 1280×720 UI 空间；或 HTML/CSS 做 UI，canvas 只画棋盘/单位。
2. 资源：`TextureLoader.load(png)`；`texture.minFilter/magFilter = NearestFilter`；卡框/tile 用 LinearFilter。
3. 图集：解析 JSON；每帧计算 UV。注意 PNG 顶行 → `v=1 - y/H`；可用 `texture.clone()` 设置 `offset/repeat`（记得 `needsUpdate`），或预切片后 `slice_atlas.py frames`。
4. 动画：`requestAnimationFrame` + delta 累加；不要用固定 60fps 假设。
5. 规则：纯 TS/JS 模块，Vitest/Jest 跑 §5.2；AI 同 §8。
6. RNG：无内置 seed；测试注入牌序；如需同 seed 用 PCG32 实现或 `seedrandom`。
7. UI：DOM overlay（中文用 CSS 字体）；深度用 `renderOrder`/`z-index`；注意透明排序。

---

## 7. 已知移植风险

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| UV/原点差异 | 帧上下颠倒/错位 | 用 manifest 的左上矩形 + 引擎转换公式；像素探针验收 |
| Rect 排他边界 | 少 1px/多 1px | 统一 `x1=x0+w`，切片工具已按此校验 |
| 非统一帧尺寸 | 单位大小不一致 | 读 `frame_size_px`/`frame_sizes_px`；保留 1.22 缩放 |
| 图集渗色 | 帧边缘出现邻近像素 | 关闭 mipmap、加 padding、filter_clip |
| RNG 不同 | 牌序不同、复现失败 | 注入牌序；或移植 PCG32 并写清 |
| 浮点并列 | AI 决策不同 | 固定 tie-breaker/量化分数 |
| 容器遍历 | 同分决策不稳定 | 单位/目标按 uid、格子按 y/x |
| 中文缺字体 | 方框/豆腐块 | 打包 CJK 字体（注意 OFL） |
| 原始 PNG 未打包 | 运行时报缺图 | 导出过滤包含 PNG 或改用导入资源 |
| 商标误用 | 法律风险 | 原创品牌；保留 CC0 声明；不复制 Logo/名称 |

---

## 8. 相关文档与工具

- [DEVELOPMENT.md](DEVELOPMENT.md) —— 完整规则/AI/确定性/测试向量。
- [PORTABLE_ASSETS.md](PORTABLE_ASSETS.md) —— 35 个 PNG、24 个 JSON、图集 schema、锚点、许可。
- [export/README.md](../export/README.md) —— manifest/切片/校验命令与联系表。
- `python3 export/slice_atlas.py verify --manifest export/asset_manifest.json` —— 一条命令验资产。
- `python3 export/build_exports.py` —— 从源数据重建 `export/asset_manifest.json` 与 `export/cards.json`。
- Godot 参考验证：`godot --path godot-card-tactics --headless -s tools/smoke_card_tactics.gd` → `CARD_TACTICS_SMOKE_OK`。
