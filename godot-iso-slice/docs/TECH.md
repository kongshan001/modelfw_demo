# 技术拆解：纯 2D 怎么做出伪 3D 地牢

> 对应视频 BV1kPxP6jEbr 的五个技术点。这里记录的是**本仓库实际踩过的坑**，
> 不是照抄结论：几个关键参数（texture_origin、y_sort_origin、map_to_local 偏移）
> 都是先用标记点验证过才写进代码的。

## 0. 一句话版本

等距不是 3D：它是一张 **2:1 菱形网格** + **每帧按 Y 排序** + **把碰撞/排序锚点放在脚底**。
光照是 2D 点光 + 遮挡多边形，跟 3D 无关。

| 技术点 | 核心开关 | 本仓库位置 |
| --- | --- | --- |
| 瓦片排列 | `tile_shape=Isometric` + `tile_layout=DiamondDown` | `tools/build_tileset.gd:33-34` |
| 遮挡 | Y-Sort + 正确的节点树 | `scenes/dungeon.tscn:24-28` |
| 移动 | 屏幕 Y 只走一半 | `src/core/portable_core.gd`（适配：`src/iso_math.gd`） |
| 朝向 | `(angle+22.5)/45` 切 8 扇区 | `src/core/portable_core.gd`（适配：`src/iso_math.gd`） |
| 锚点 | 精灵脚底 = 单元中心 = 节点原点 | `src/hero_frames.gd`、`scenes/player.tscn` |
| 光照 | PointLight2D + CanvasModulate + 瓦片遮挡层 | `src/dungeon.gd` `_spawn_candles()` |

---

## 1. 等距瓦片：两个设置，少一个就散架

```gdscript
ts.tile_size = Vector2i(128, 64)
ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC   # 形状
ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN  # 排列
```

- **只设 `tile_size` 不够**。默认 `tile_shape=Square`，`tile_layout=Stacked`，
  地砖会按 `(x*128, y*64)` 矩形堆叠，菱形之间留下三角形空洞——我们的第一版截图就是这样。
- 官方 demo 的 `tileset.tres` 里 `tile_shape=1, tile_layout=5`，这两个值缺一不可。

**图集单元格 ≠ 逻辑瓦片。** 逻辑 tile 是 128×64，但图集单元做成 **128×160**：
脚底菱形画在单元 `y=128`，比单元中心低 48px。墙的图形从脚底往上画 104px，正好落在单元内。

```gdscript
td.texture_origin = Vector2i(0, 48)   # 把图集内容整体上移 48px
```

- 这个值的方向**和直觉相反**：`+48` 让脚底对齐到逻辑 tile 中心，`-48` 会把整个图形再往下推 96px。
  我们的第一版墙比地砖低了一格，就是符号反了。
- 验证方法：在瓦片中心的 `map_to_local()` 打一个红点，看红点是否落在菱形中心/墙脚上。

**`map_to_local((0,0))` 不是 (0,0)**：当前配置下是 `(64, 32)`。所以相机边界、道具、
粒子位置全部用 `map_to_local()`，不要手写 `(x-y)*64` 公式——我们第一版相机边界就是这么算错的。

## 2. Y-Sort：节点树比属性更重要

```
Dungeon
├── Ground              y_sort_enabled = true
│   └── Floor           TileMapLayer, y_sort_enabled = true
├── World               y_sort_enabled = true, z_index = 1
│   ├── Walls           TileMapLayer, y_sort_enabled = true, y_sort_origin = 32
│   └── Player          CharacterBody2D
└── Lights              z_index = 2 (粒子)
```

- **玩家必须和墙层是兄弟节点**，且父节点 `World` 打开 Y-Sort；墙层自己也要打开，
  它内部的瓦片才会参与和兄弟节点的交错排序。
- `TileMapLayer.y_sort_origin = 32` = 半格高度，把瓦片的排序锚点从中心推到菱形**底边**。
  墙占据整个格子，前脸在底边，这样“站在墙前一格”和“墙”的排序值刚好接上。
- **z_index 会压制 Y-Sort**。我们最初给角色阴影设了 `z_index=-1`，结果阴影被画到地板下面
  （整张画布按 z 排序），完全看不见。修法是去掉 z_index，让阴影参与 Y-Sort，
  并保证同一 y 时阴影比道具先画（先 add_child）。
- 教学开关 `F1` 同时关掉 `World` 和 `Walls` 的 Y-Sort；关掉后子节点按树顺序画，
  玩家永远最后画，于是“穿到墙前”。

## 3. 等距移动：先除 2，再归一化

```gdscript
# 适配层 src/iso_math.gd：核心返回 [x, y*0.5]，这里转回 Vector2
var motion := IsoMath.screen_motion(input)
motion = motion.normalized() * SPEED
```

- 顺序不能反：先 `normalized()` 再 `y/=2` 会让斜向速度慢一截。
- 8 方向扇区：

```gdscript
var sector := int(floor((rad_to_deg(v.angle()) + 22.5) / 45.0))
return posmod(sector, 8)
```

`+22.5°` 把扇区边界推到对角线上，角色朝向不会在两条对角线之间抖动。
索引 0..7 对应：右、右下、下、左下、左、左上、上、右上。

- GDScript 的 `%` 对负数不保证正数余数，所以用 `posmod()`。
- 这两段数学现在在仓库级 `portable-core/impl/gdscript/portable_core.gd`，
  本工程 `src/core/` 是同步副本；Python/JS 有等价实现和同一组 golden 向量（见第 8 节）。

## 4. 脚底锚点：一个决定，解决三个症状

美术图集里每个单元 112×160，**脚底画在单元正中心 (56,80)**。
于是 `AnimatedSprite2D` 放在 `(0,0)` 时，节点原点就是脚底。

- 碰撞胶囊 `position = (0,-11)`，从脚底往上只覆盖 22px；
- 阴影 Sprite 也在 `(0,0)`；
- Y-Sort 用的节点 y 就是脚底 y。

| 症状 | 通常查哪里 |
| --- | --- |
| 角色“飘”在地砖上 | 精灵偏移/单元脚底是否在中心；`texture_origin` 是否把地砖推走了 |
| 角色“穿墙” | 碰撞体是不是放在精灵中心而不是脚底；墙的碰撞多边形是否在墙脚 |
| 遮挡错乱 | Y-Sort 开关；玩家和瓦片层是否同一个 y-sorted 父节点；`y_sort_origin` 是否为半格 |

## 5. 2D 实时光照

- `CanvasModulate` 把全局压到深蓝 `(0.23, 0.25, 0.33)`；
- 6 盏 `PointLight2D`：暖色 `(1.0, 0.71, 0.44)`、`energy=1.5`、`texture_scale=2.5`、
  `shadow_enabled=true`、`shadow_filter=PCF5`、`shadow_filter_smooth=4`；
- 墙的 TileSet 加了 **occlusion layer**，每个墙瓦片的遮挡多边形是脚底菱形向内缩 5px；
  道具（桶/箱/罐）在代码里补 `LightOccluder2D`；
- 烛光用两条正弦叠加做呼吸闪烁（`_process`），火星用 `CPUParticles2D`；
- 官方 demo 是 23 盏点光；本切片房间更小，只放 6 盏，移动端更适合。

> GL Compatibility 下 2D 光照与实时阴影实测正常（Intel HD 6000 / macOS）。
> 这是 2D renderer 的能力，不需要 Forward+。

## 6. 排查手册（我们实际用过的）

1. **先打印坐标**：`player.global_position`、`map_to_local(cell)`、`y_sort_origin`、
   `get_screen_center_position()`。第一版相机被 limit 夹住、地砖散架，都是打印后定位的。
2. **打标记点**：在一个格子中心放一个高 z_index 的红点，直接看它跟美术是否重合。
3. **开关对比**：F1/F2 各拍一张，逐像素对比；比盯着单帧猜快得多。
4. **无头断言**：`tools/smoke_iso.gd` 把 TileSet 形状、排序开关、碰撞/遮挡多边形、
   动画帧数、8 方向索引、移动和穿墙都断言了。

## 7. 验证

```bash
godot --headless --path godot-iso-slice -s tools/smoke_iso.gd
godot --path godot-iso-slice --resolution 1280x720 -s tools/screenshot_iso.gd
godot --path godot-iso-slice --resolution 1280x720 -s tools/capture_iso_gif.gd
```

- `smoke_iso.gd` 通过输出 `ISO_SMOKE_OK`，失败退出码 1。
- 截图输出 `/tmp/iso_slice_shots/{01_start,02_behind_wall,03_ysort_off,04_lights_off,05_front_wall}.png`。
- GIF 帧输出 `/tmp/iso_slice_gif/`，编码命令见 README。

## 8. 跨引擎核心层（portable-core）

> 对应总览 `docs/技术方案总览.md` 9.7。目的：换引擎时算法不重写，只重写适配层。

```
portable-core/
├── spec/functions.md        # 语言无关契约
├── spec/golden.json         # 15 iso + 9 hash 向量（Python 生成）
├── impl/python|gdscript|js/ # 三份等价实现
├── tools/gen_golden.py
├── tests/                   # Python / JS 断言
├── sync.py                  # 同步到本工程（--check 检漂移）
└── verify.sh
```

- **本工程接入**：
  - `src/core/portable_core.gd`、`tools/core/portable_core.py` ← sync 副本，不手改；
  - `src/iso_math.gd`：只做 `Vector2 ↔ 标量` 适配；
  - `src/sigil_rules.gd` 的 `hash32` 委托核心层；`tools/bake_pipeline.py` 也 import
    同步的 Python core，两端不再各写一份。
- **精度边界**：核心返回 `Array`（float64）而不是 `Vector2`（float32），
  保证三语言 golden 逐值一致；适配层再转 Vector2。
- **验证**：

  ```bash
  bash portable-core/verify.sh
  bash tools/verify.sh   # 含 PORTABLE_SYNC_OK / PORTABLE_GD_OK
  ```

  输出 `PORTABLE_ALL_OK` 即三语言一致。
- **改核心的正确姿势**：改 `portable-core/impl/` → 跑 `gen_golden.py` → `sync.py` → `verify.sh`；
  直接改 `src/core/` 会被 `sync.py --check` 拦下。
