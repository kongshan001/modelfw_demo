# 可移植资产清单 · PORTABLE_ASSETS

> **结论先行**：本项目用到 **35 个 PNG**（14 单位/将军、4 法术图标、6 特效、5 地块高亮、6 卡框）和 **24 个帧 JSON**（单位 14 + 图标 4 + 特效 6），另有 CC0 1.0 许可全文。全部来自 `t73liu/open-duelyst-assets` commit `9fd0a16b611be8c9b991806ec5a6f602aa981823`，上游为 `open-duelyst/duelyst`（CC0-1.0）。**机器可读的权威清单是 [`export/asset_manifest.json`](../export/asset_manifest.json)**：它有每个文件的路径、尺寸、SHA-256、全部帧名/矩形、动画名、用途、锚点/缩放与来源；本文是可读说明与导出指南。

## 1. 许可、来源与品牌边界

| 项 | 值 |
| --- | --- |
| 许可 | **CC0 1.0 Universal**（公共领域贡献） |
| 许可全文 | [`assets/duelyst_cc0/LICENSE`](../assets/duelyst_cc0/LICENSE) |
| 资产仓库 | <https://github.com/t73liu/open-duelyst-assets> |
| commit | `9fd0a16b611be8c9b991806ec5a6f602aa981823`（2024-12-26） |
| 上游作品 | <https://github.com/open-duelyst/duelyst>（CC0-1.0） |
| 抽取记录 | [`assets/duelyst_cc0/SOURCE.md`](../assets/duelyst_cc0/SOURCE.md) |
| 品牌 | “Duelyst”名称/Logo 是 Counterplay Games 商标，**不在 CC0 内**；本项目使用原创名《格间牌战 / Gridbound》，不把 Duelyst 名称/Logo 当品牌 |

CC0 允许复制、修改、分发、商用且不要求署名；本项目仍主动保留 LICENSE、SOURCE、CREDITS 与上游 commit，便于追溯。

> 本项目的 GDScript、UI 布局、配色与规则代码为原创；没有复制 `open-duelyst/duelyst` 的 CoffeeScript/JS 代码，也没有使用 Duelyst II / Steam 版本素材。

## 2. 文件总览

### 2.1 目录结构

```
assets/duelyst_cc0/
├─ LICENSE                     CC0 1.0 全文
├─ SOURCE.md                   上游 repo/commit/文件清单/抽取方式
├─ units/                      14 个 PNG + 14 个 JSON（单位/将军图集）
├─ icons/                      4 个 PNG + 4 个 JSON（法术图标图集）
├─ fx/                         6 个 PNG + 6 个 JSON（特效图集）
├─ tiles/                      5 个 PNG（棋盘高亮，无帧 JSON）
├─ card_backgrounds/           6 个 PNG（手牌卡框，无帧 JSON）
└─ *.png.import                Godot 生成的导入元数据（不属于源资产；其他引擎可忽略）
```

上游路径 = `assets/<folder>/<file>`（与本地目录同名）。例如 `assets/units/f1_general.png`。manifest 的 `upstream_path` 字段逐文件记录。

### 2.2 单位/将军图集（14 个 PNG + 14 个 JSON）

| PNG | 尺寸 | 帧数 | 动画（帧数） | 帧尺寸 |
| --- | --- | ---: | --- | --- |
| `units/f1_general.png` | 1024×1024 | 97 | attack:23, breathing:12, cast:12, castend:3, castloop:4, caststart:9, death:12, hit:3, idle:11, run:8 | 100×100 |
| `units/f2_general.png` | 1024×1024 | 109 | attack:18, breathing:14, cast:15, castend:5, castloop:8, caststart:9, death:14, hit:4, idle:14, run:8 | 80×80 |
| `units/f1_silverguardsquire.png` | 512×1024 | 59 | attack:13, breathing:14, death:11, hit:3, idle:10, run:8 | 80×80 |
| `units/f1_backlinearcher.png` | 2048×1024 | 79 | attack:24, breathing:14, death:15, hit:3, idle:12, projectile:3, run:8 | 120×120 |
| `units/f1_sunstonetemplar.png` | 512×1024 | 66 | attack:19, breathing:14, death:12, hit:3, idle:10, run:8 | 80×80 |
| `units/f1_windbladecommander.png` | 512×1024 | 55 | attack:11, breathing:14, death:9, **hurt:3**, idle:10, run:8 | 80×80 |
| `units/f1_ironcliffeguardian.png` | 512×1024 | 70 | attack:18, breathing:14, death:9, hit:3, idle:18, run:8 | 80×80 |
| `units/f2_onyxjaguar.png` | 1024×1024 | 91 | attack:29, breathing:14, death:26, hit:3, idle:13, run:6 | 100×100 |
| `units/f2_sparrowhawk.png` | 2048×1024 | 93 | attack:35, breathing:14, death:20, hit:3, idle:13, run:8 | 130×130 |
| `units/f2_lanternfox.png` | 512×1024 | 67 | attack:16, breathing:14, death:14, hit:3, idle:12, run:8 | 80×80 |
| `units/f2_mage4winds.png` | 512×1024 | 63 | attack:13, breathing:14, death:11, hit:3, idle:14, run:8 | 80×80 |
| `units/f2_heartofthesonghai.png` | 1024×1024 | 79 | attack:22, breathing:14, death:18, hit:3, idle:14, run:8 | 110×110 |
| `units/neutral_healingmystic.png` | 1024×1024 | 70 | attack:16, breathing:14, death:15, hit:3, idle:14, run:8 | 110×110 |
| `units/neutral_bonereaper.png` | 1024×1024 | 99 | attack:22, breathing:14, death:38, hit:3, idle:14, run:8 | 100×100 |

- 每个 PNG 的同名 `.json` 是帧数据（见 §3）。14 个 JSON 文件：
  `units/f1_general.json`、`units/f2_general.json`、`units/f1_silverguardsquire.json`、
  `units/f1_backlinearcher.json`、`units/f1_sunstonetemplar.json`、`units/f1_windbladecommander.json`、
  `units/f1_ironcliffeguardian.json`、`units/f2_onyxjaguar.json`、`units/f2_sparrowhawk.json`、
  `units/f2_lanternfox.json`、`units/f2_mage4winds.json`、`units/f2_heartofthesonghai.json`、
  `units/neutral_healingmystic.json`、`units/neutral_bonereaper.json`。
- **帧尺寸不统一**：80–130px；不要假设 100×100。
- 当前运行只用 `idle` / `run` / `attack` / `hit` / `death`；`breathing` 是 idle 的回退，`hurt` 是 hit 的回退；`cast*` / `projectile` 未使用但保留。
- `f1_windbladecommander` 没有 `hit`，只有 `hurt`；移植必须实现 `hit→hurt` 回退。
- 静态卡面 art 取 `idle[0]`（不是 attack）。

### 2.3 法术图标（4 个 PNG + 4 个 JSON）

| PNG | 尺寸 | 帧数 | 动画（帧数） | 帧尺寸 | 用途 |
| --- | --- | ---: | --- | --- | --- |
| `icons/icon_f1_sundropelixir.png` | 256×256 | 19 | sundropelixir:4, active:15 | 48×48 | 阳光药水 |
| `icons/icon_f1_truestrike.png` | 256×256 | 23 | truestrike:4, active:19 | 48×48 | 破魔箭 |
| `icons/icon_f2_phoenixfire.png` | 128×256 | 11 | phoenixfire:4, active:7 | 48×48 | 凤火 |
| `icons/icon_f2_cobrastrike.png` | 256×256 | 20 | cobrastrike:6, active:14 | 48×48 | 眼镜蛇击 |

- 运行中只取**静态首帧**：卡面 art 取“JSON 第一个动画的第 0 帧”（即 `sundropelixir` / `truestrike` / `phoenixfire` / `cobrastrike`），不是 `active`。
- `active` 动画未使用，可用于卡牌“可选/激活”态扩展。

### 2.4 特效（6 个 PNG + 6 个 JSON）

| PNG | 尺寸 | 帧数 | 动画（帧数） | 帧尺寸 | 事件 |
| --- | --- | ---: | --- | --- | --- |
| `fx/fx_slashfrenzy.png` | 512×1024 | 12 | default:12 | 128×128 | 近战命中 |
| `fx/fx_impact.png` | 256×256 | 18 | impactbluemedium:5, impactorangebig:7, impactorangemedium:6 | 32×34 / 42×34 / 72×56 | 前阵弓手远程、破魔箭 |
| `fx/fx_heal.png` | 512×256 | 15 | default:15 | 80×80 | 阳光药水 |
| `fx/fx_buff.png` | 256×256 | 12 | default:12 | 46×56 | 眼镜蛇击/未知法术 |
| `fx/fx_summonlegendary.png` | 2048×1024 | 26 | default:26 | 180×180 | 召唤 |
| `fx/fx_f2_phoenixfire.png` | 512×2048 | 38 | default:38 | 150×150 | 凤火 |

- 运行用 `play("", 24fps, loop=false)`：空动画名会回退到 **JSON 第一个动画**。因此 `fx_impact` 实际播放 `impactbluemedium`（5 帧），不是 `impactorangebig`。
- `fx_impact` 的帧尺寸不统一（见上）；切片/动画必须逐帧用矩形，不能按固定网格。
- FX 的视觉缩放（`reference_runtime.visual_scale`）：impact 2.3、slash 0.95、heal 1.15、buff 1.8、summon 0.82、phoenix 0.95。

### 2.5 棋盘高亮（5 个 PNG，无 JSON）

| PNG | 尺寸 | 运行时尺寸 | 用途 |
| --- | --- | --- | --- |
| `tiles/tile_hover.png` | 128×128 | 88×88 | 移动/悬停（青色叠加） |
| `tiles/tile_spawn.png` | 128×128 | 88×88 | 召唤（金色叠加） |
| `tiles/tile_attack.png` | 128×128 | 88×88 | 攻击目标（红色叠加） |
| `tiles/tile_spell.png` | 128×128 | 88×88 | 法术目标（蓝色叠加） |
| `tiles/tile_target.png` | 128×128 | 88×88 | 选中格（金色叠加） |

> **注意**：在当前 commit 中，`tile_spawn.png`、`tile_spell.png`、`tile_target.png` **字节完全相同**（manifest 的 SHA-256 相同）。视觉差异来自运行时 tint/圆弧，不是纹理内容。移植时可只保留一份纹理 + 不同 tint。

### 2.6 卡框（6 个 PNG，无 JSON）

| PNG | 尺寸 | 运行时尺寸 | 用途 |
| --- | --- | --- | --- |
| `card_backgrounds/f1_unit.png` | 224×294 | 104×144 | 晨光随从 |
| `card_backgrounds/f1_spell.png` | 224×294 | 104×144 | 晨光法术 |
| `card_backgrounds/f2_unit.png` | 224×294 | 104×144 | 风间随从 |
| `card_backgrounds/f2_spell.png` | 224×294 | 104×144 | 风间法术 |
| `card_backgrounds/neutral_unit.png` | 226×296 | 104×144 | 中立随从 |
| `card_backgrounds/neutral_spell.png` | 226×296 | 104×144 | 中立法术（当前卡池没有中立法术，**备用未使用**） |

卡框按 `faction + type` 选择；运行时为**非等比拉伸**到 104×144（原始宽高比约 0.762 vs 目标 0.722），线性过滤。若不想变形，可改为等比覆盖 + 裁剪，但会改变 1:1 视觉。

---

## 3. 图集 JSON schema

### 3.1 顶层

```json
{
  "texture_filename": "f1_general.png",
  "width": 1024,
  "height": 1024,
  "frames": {
    "idle": [ ... ],
    "run": [ ... ],
    "attack": [ ... ],
    "hit": [ ... ],
    "death": [ ... ]
  }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `texture_filename` | string | 对应 PNG 文件名；仅信息，不保证路径 |
| `width`, `height` | int | 必须等于 PNG 实际像素尺寸（本项目 24 个 JSON 全部已校验） |
| `frames` | object | 动画名 → 帧数组；**数组顺序即播放顺序** |

### 3.2 帧对象

```json
{
  "frame_name": "f1_general_idle_000.png",
  "x0": 404,
  "y0": 0,
  "x1": 504,
  "y1": 100,
  "width": 100,
  "height": 100
}
```

| 字段 | 说明 |
| --- | --- |
| `frame_name` | 帧标识；本项目通常等于 `"<sheet>_<anim>_<index>.png"`，但**不要解析它**来定位/排序 |
| `x0`, `y0` | 帧左上角在 PNG 中的像素坐标（左上原点） |
| `x1`, `y1` | 右下边界；`x1 = x0 + width`，`y1 = y0 + height`（排他边界） |
| `width`, `height` | 帧像素尺寸；可整张统一，也可不统一 |

**没有锚点字段**：JSON 只描述矩形。锚点是运行时约定：本项目单位/FX 以帧中心为锚点；卡面 art 以目标区域居中；tile/卡框以左上为锚点。不要从 JSON 推断锚点。

### 3.3 帧名/矩形示例（每个图集的首帧）

完整 1291 帧的矩形见 [`export/asset_manifest.json`](../export/asset_manifest.json) 的 `assets[].animations`。

| 资产 id | 首动画 | 首帧名 | 首帧矩形 |
| --- | --- | --- | --- |
| `f1_general` | attack | `f1_general_attack_000.png` | `[404, 0, 100, 100]` |
| `f2_general` | attack | `f2_general_attack_000.png` | `[405, 162, 80, 80]` |
| `f1_silverguardsquire` | attack | `f1_silverguardsquire_attack_000.png` | `[81, 891, 80, 80]` |
| `f1_backlinearcher` | attack | `f1_backlinearcher_attack_000.png` | `[847, 242, 120, 120]` |
| `f1_sunstonetemplar` | attack | `f1_sunstonetemplar_attack_000.png` | `[162, 0, 80, 80]` |
| `f1_windbladecommander` | attack | `f1_windbladecommander_attack_000.png` | `[81, 810, 80, 80]` |
| `f1_ironcliffeguardian` | attack | `f1_ironcliffeguardian_attack_000.png` | `[162, 243, 80, 80]` |
| `f2_onyxjaguar` | attack | `f2_onyxjaguar_attack_000.png` | `[404, 505, 100, 100]` |
| `f2_sparrowhawk` | attack | `f2_sparrowhawk_attack_000.png` | `[786, 524, 130, 130]` |
| `f2_lanternfox` | attack | `f2_lanternfox_attack_000.png` | `[162, 567, 80, 80]` |
| `f2_mage4winds` | attack | `f2_mage4winds_attack_000.png` | `[162, 486, 80, 80]` |
| `f2_heartofthesonghai` | attack | `f2_heartofthesonghai_attack_000.png` | `[333, 888, 110, 110]` |
| `neutral_healingmystic` | attack | `neutral_healingmystic_attack_000.png` | `[333, 444, 110, 110]` |
| `neutral_bonereaper` | attack | `neutral_bonereaper_attack_000.png` | `[808, 606, 100, 100]` |
| `icon_f1_sundropelixir` | sundropelixir | `icon_f1_sundropelixir_000.png` | `[49, 49, 48, 48]` |
| `icon_f1_truestrike` | truestrike | `icon_f1_truestrike_000.png` | `[49, 196, 48, 48]` |
| `icon_f2_phoenixfire` | phoenixfire | `icon_f2_phoenixfire_000.png` | `[0, 196, 48, 48]` |
| `icon_f2_cobrastrike` | cobrastrike | `icon_f2_cobrastrike_000.png` | `[49, 196, 48, 48]` |
| `fx_slashfrenzy` | default | `fx_slashfrenzy_000.png` | `[0, 645, 128, 128]` |
| `fx_impact` | impactbluemedium | `fx_impactbluemedium_000.png` | `[159, 140, 32, 34]` |
| `fx_heal` | default | `fx_heal_000.png` | `[162, 81, 80, 80]` |
| `fx_buff` | default | `fx_buff_000.png` | `[47, 57, 46, 56]` |
| `fx_summonlegendary` | default | `fx_summonlegendary_000.png` | `[362, 362, 180, 180]` |
| `fx_f2_phoenixfire` | default | `fx_f2_phoenixfire_000.png` | `[151, 755, 150, 150]` |

### 3.4 动画名与回退

| 请求动画 | 本项目实际使用 | 回退链（找不到时） |
| --- | --- | --- |
| `idle` | 待机，8fps，循环 | → `breathing` → JSON 第一个动画 |
| `run` | 移动，13fps，循环 | → `idle` → JSON 第一个动画 |
| `attack` | 攻击，17fps，单次 | → `cast` → JSON 第一个动画 |
| `hit` | 受击，15fps，单次 | → `hurt` → JSON 第一个动画 |
| `death` | 死亡，14fps，单次 | → `idle` → JSON 第一个动画 |
| `""`（空） | FX 用，24fps，单次 | → JSON 第一个动画 |
| 图标静态 | 卡面 art | → JSON 第一个动画的第 0 帧 |

**注意**：`hit→hurt` 是必需的（`f1_windbladecommander`）；`idle→breathing` 是常见回退（多数单位有 `breathing`）；`run→idle` 是保底。

---

## 4. 锚点、缩放与运行时布局

### 4.1 单位/将军

| 项 | 值 |
| --- | --- |
| 锚点 | 帧中心 |
| 位置 | 格中心 + `(0,-2)` 逻辑 px |
| 缩放 | `1.22`；将军额外 `×1.1`（总 `1.342`） |
| 深度 | `10 + y` |
| 地面阴影 | 中心 `(0,31)`，半径 28，y 缩放 0.34，黑色 38% |
| 攻/血徽章 | 21×21；攻击 `(-31,17)`、生命 `(11,17)` |
| 受击闪红 | `(1.0,0.55,0.5)` 0.06s → 白 0.16s |

**重要**：不同图集的帧尺寸不同（80–130px），但运行统一乘 1.22，**没有按帧尺寸归一化**。因此 `f2_sparrowhawk`（130px）视觉上比 `f1_ironcliffeguardian`（80px）大。这是当前实现的真实行为；1:1 复刻应保留。若想视觉统一，应作为新的美术决策，而非“修 bug”。

### 4.2 卡面 art

| 项 | 值 |
| --- | --- |
| 区域 | 卡面内 `(10,25)`，`84×66` |
| 适配 | `keep-aspect-centered`（等比缩放居中，可能留边） |
| 过滤 | 最近邻 |
| 随从 | 对应单位图集 `idle[0]` |
| 法术 | 对应图标图集“第一个动画”的 `[0]` 帧 |

### 4.3 卡框 / tile

| 元素 | 锚点 | 运行时尺寸 | 适配 | 过滤 |
| --- | --- | --- | --- | --- |
| 卡框 | 左上 | 104×144 | 非等比拉伸 | 线性 |
| tile 高亮 | 左上 | 88×88 | 非等比拉伸 | 线性 |

### 4.4 FX

| 项 | 值 |
| --- | --- |
| 锚点 | 帧中心 |
| 位置 | 格中心 |
| 时长 | 帧数 / 24fps；单次；播完淡出 0.18s |
| 深度 | 60 |
| 缩放 | 见 §2.4 |
| 死亡残影 | 单位图集 `death`，深度 55，scale 同单位，播完淡出 |

---

## 5. 如何导出到其他引擎

### 5.1 通用：先校验，再切片

```bash
cd godot-card-tactics

# 1) 校验 manifest（路径/尺寸/SHA/帧数/矩形）
python3 export/slice_atlas.py verify --manifest export/asset_manifest.json

# 2) 抽单帧（适合 Unity/Unreal 的逐帧导入；输出到临时目录，不要提交）
python3 export/slice_atlas.py frames \
  --png assets/duelyst_cc0/units/f1_general.png \
  --json assets/duelyst_cc0/units/f1_general.json \
  --animation idle --animation attack --out-dir /tmp/f1_general_frames

# 3) 重打包图集（适合 Three.js/自定义管线；生成 PNG + 同名 JSON）
python3 export/slice_atlas.py strip \
  --png assets/duelyst_cc0/units/f2_onyxjaguar.png \
  --json assets/duelyst_cc0/units/f2_onyxjaguar.json \
  --animation run --columns 6 --out /tmp/onyxjaguar_run_atlas.png

# 4) 联系表（预览/验收证据）
python3 export/slice_atlas.py contact --out /tmp/contact.png \
  --entry "f1_general / idle=assets/duelyst_cc0/units/f1_general.png:assets/duelyst_cc0/units/f1_general.json:idle:4" \
  --entry "fx_impact / impactorangebig=assets/duelyst_cc0/fx/fx_impact.png:assets/duelyst_cc0/fx/fx_impact.json:impactorangebig:4"
```

仓库只提交工具、manifest 与一张小联系表（[`export/sample_contact_sheet.png`](../export/sample_contact_sheet.png)）；**不提交全部切片**。

### 5.2 Godot 4.6（参考实现）

- 直接用 `AtlasTexture` + `region`；`AssetLoader` 按 PNG 字节创建 `ImageTexture`。
- 图集精灵 `texture_filter = NEAREST`；卡框/tile 用默认线性。
- 动画用 `AtlasAnim`：每帧构造 `AtlasTexture` 并缓存；`_process` 累加 `delta*fps`。
- 若导出 PCK：把原始 PNG 加入导出过滤，或改回常规导入资源（见 README 已知限制）。

### 5.3 Unity 6（2D）

1. 把 PNG 作为 `Texture2D` 导入；单位/图标/FX 设 `Filter Mode = Point`、`Compression = None` 或高质量；卡框/tile 用 Bilinear。
2. 方案 A：`Sprite.Create(texture, rect, pivot, 100f)` 逐帧创建 Sprite；`rect` 用**左下原点**：`new Rect(x0, textureHeight - y0 - height, width, height)`。pivot `(0.5,0.5)`。
3. 方案 B：Sprite Editor 自定义切片（按 JSON 坐标批量生成）；注意 Unity 以左下为原点，需转换 Y。
4. 动画：生成 `AnimationClip`（Sprite 关键帧，sample rate = 对应 fps）或自写帧计时器（更简单、与参考一致）。
5. 卡框：`Image`/`SpriteRenderer` 拉伸到 104×144；如需 1:1 变形，保持非等比。
6. 排序：`sortingOrder` = 10+y（单位）、55（死亡残影）、60（FX）、1000（覆盖层）。
7. 中文：TextMeshPro 字体资产（打包 CJK 字体，注意 OFL）。

### 5.4 Unreal 5（Paper2D / UMG）

1. 导入 PNG：`Compression Settings = UserInterface2D (RGBA)`、`Filter = Nearest`、`Mip Gen Settings = NoMipmaps`（单位/图标/FX）；卡框/tile 可用 Linear/Default。
2. 方案 A：Paper2D `Sprite` 设置 Source Region（像素坐标，左上原点），pivot 0.5；用 `Flipbook` 按 fps 组织帧。
3. 方案 B：UMG `Image` + 材质 UV 区域；或把 JSON 转成 DataTable 驱动。
4. 排序：UMG `ZOrder`；Paper2D 用 `TranslucencySortPriority`。
5. 动画 fps：Flipbook 的 Frames Per Second 设为对应值；单次/循环按 §3.4。
6. 中文：UMG Font 资产打包 CJK 字体。

### 5.5 Three.js（Web）

1. `TextureLoader.load(png)`；单位/图标/FX `magFilter=minFilter=NearestFilter`、`generateMipmaps=false`；卡框/tile 用 Linear。
2. 图集 UV：PNG 顶行对应 `v=1`（Three.js 默认 `flipY=true`；若设为 false 需翻转公式）。帧矩形 `[x0,y0,w,h]` 的 UV：
   ```
   u0 = x0 / W;  u1 = (x0+w)/W
   v0 = 1 - (y0+h)/H;  v1 = 1 - y0/H
   ```
   可用 `texture.clone()` + `offset/repeat` 每帧设置，或预切片（`frames` 子命令）后逐张加载。
3. 动画：`requestAnimationFrame` + `delta` 累加；不要假设 60fps。
4. 相机：`OrthographicCamera(0, 1280, 720, 0, ...)`（y 向下）或普通 y 向上相机 + `screenY=720-y` 转换。
5. 中文：DOM overlay 用 CSS 字体（打包 webfont）。

### 5.6 从零导出到“自定义引擎”

最小步骤：

1. 读 manifest，按 `kind` 分类；
2. 对每个 `unit_atlas` / `spell_icon_atlas` / `fx_atlas`，用 JSON 的 `animations` 建帧表；
3. 上传 PNG 为纹理；按 `[x0,y0,w,h]` 生成 UV/子矩形；
4. 按 `reference_runtime` 设 pivot/scale/fps/loop/filter/depth；
5. 按 `used_by` 绑定到卡牌/事件；
6. 跑 §5.1 校验与 [CROSS_ENGINE.md](CROSS_ENGINE.md) 验收。

---

## 6. 自检与证据

| 检查 | 命令 | 期望 |
| --- | --- | --- |
| manifest 校验 | `python3 export/slice_atlas.py verify --manifest export/asset_manifest.json` | `MANIFEST_OK assets=35 atlas_assets=24 animations=109 frames=1291` |
| 单帧切片 | `frames ... --animation idle` | 输出帧数 = JSON 帧数 |
| 图集重打包 | `strip ... --animation run` | PNG + 同名 JSON，帧矩形正确 |
| 联系表 | `contact ...` | 生成预览图，帧内容与矩形一致 |
| Godot 冒烟 | `godot --path godot-card-tactics --headless -s tools/smoke_card_tactics.gd` | `checks=65` + `CARD_TACTICS_SMOKE_OK` |

**联系表示例**：[`export/sample_contact_sheet.png`](../export/sample_contact_sheet.png)（525×633，4 行；`f1_general` 的 idle/attack + `fx_impact` 的两个动画，共 16 个采样帧）。它证明矩形切图、透明通道、帧顺序与 JSON 一致。

---

## 7. 已知边界

- 资产原始尺寸/帧布局来自上游 commit；**不要重新打包后覆盖源 PNG/JSON**，否则许可追溯与 manifest 校验会失效。
- 图集没有锚点/trim 元数据；锚点是本项目运行时约定（§4）。
- `tile_spawn` / `tile_spell` / `tile_target` 当前字节相同；不要据此认为它们语义相同，运行差异在 tint。
- `f1_windbladecommander` 只有 `hurt`，没有 `hit`；必须实现回退。
- `fx_impact` 有三个动画，运行默认只播第一个（`impactbluemedium`）；要使用其它动画需显式指定。
- `neutral_spell.png` 当前未被卡池使用，保留作为扩展。
- 字体不在资产包内；中文显示依赖系统字体或自备 CJK 字体（注意许可）。
- 商标不在 CC0 内；不要用 Duelyst 名称/Logo 作为品牌。
