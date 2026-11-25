# 关卡 JSON Schema（v1）

苔井工坊使用同一个核心格式保存与导出关卡：

- **编辑器 JSON**：`format = "mossgarden.level"`，包含图层 UI 元数据与 `next_entity_id`。
- **运行时 JSON**：`format = "mossgarden.level.runtime"`，去掉编辑器图层元数据与下一个实体 ID，其余字段一致。
- 文件扩展名统一为 `.json`；“运行预览”读取的是运行时 JSON（由当前关卡即时序列化）。

当前版本：`version = 1`。读取时格式不匹配、版本不符或任一字段非法都会拒绝载入并返回中文错误列表，不会留下半加载状态。

## 根对象

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `format` | string | 是 | `mossgarden.level` 或 `mossgarden.level.runtime` |
| `version` | int | 是 | 当前只能为 `1` |
| `name` | string | 否 | 关卡名，默认“苔庭试炼” |
| `width` | int | 是 | 地图宽（格），当前 schema 允许 1–256；编辑器 UI 默认 8–96 |
| `height` | int | 是 | 地图高（格），同上 |
| `cell_size` | int | 是 | 每格显示像素数，schema 允许 8–64；UI 提供 16/32/48 |
| `tiles` | array | 是 | 高度行 × 宽度列的二维数组；元素为 `null` 或 [Tile 对象](#tile-对象) |
| `collision` | array | 是 | 高度行 × 宽度列的二维数组；元素为 `0`（可通行）或 `1`（实心） |
| `entities` | array | 是 | [Entity 对象](#entity-对象) 列表 |
| `layers` | object | 仅编辑器 | 地形/碰撞/实体三层的可视与锁定状态；运行时 JSON 不包含 |
| `next_entity_id` | int | 仅编辑器 | 下一实体编号；运行时 JSON 不包含，重新载入时按已有 id 推导 |

## Tile 对象

```json
{ "type": "grass", "variant": -1, "mask": 6 }
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | `grass` 草地、`dirt` 泥土、`wall` 石墙、`water` 水面 |
| `variant` | int | `-1` = 自动边缘；`0` 素面；`1` 缀饰；`2` 裂纹（共 4 种）。手动变体优先于自动掩码 |
| `mask` | int | `0..15` 的四邻连接/外露掩码，位值见下 |

### 掩码位

| 位 | 值 | 方向 |
| --- | --- | --- |
| 0 | 1 | 北 |
| 1 | 2 | 东 |
| 2 | 4 | 南 |
| 3 | 8 | 西 |

掩码的含义随地形规则组不同：

- **草地 / 泥土**：同一“地面组”视为连续。位为 1 表示该方向是草/土；为 0 的一侧画压暗边缘与草叶。
- **石墙**：位为 1 表示该方向也是石墙；为 0 的一侧画外露描边，四邻组合自然产生端点、转角、丁字与十字。
- **水面**：位为 1 表示该方向还是水；为 0 的一侧生成泡沫岸线。

自动铺砖在落笔时按当前掩码实时重算；关闭“自动铺砖”时只更新当前格，周围保持旧掩码，点“重算铺砖”才统一刷新。手动变体格不会被“重算”修改，可用“清除覆盖”恢复全部自动格。

## Entity 对象

```json
{
  "id": "e2",
  "type": "enemy",
  "x": 14,
  "y": 11,
  "props": { "kind": "苔团", "hp": 30, "damage": 5, "facing": "left", "patrol": 3 }
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 实体唯一 id，形如 `e2`；缺失或重复时载入会重新生成 |
| `type` | string | `spawn` 出生点、`enemy` 敌人、`chest` 宝箱 |
| `x` / `y` | int | 格子坐标（0 起，左/上为 0），必须在地图内 |
| `props` | object | 类型相关属性；缺失字段用默认值补齐 |

### `spawn` props

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `facing` | string | `up` | `right` / `left` / `up` / `down`；预览初始朝向 |

### `enemy` props

| 字段 | 类型 | 默认 | 范围 / 说明 |
| --- | --- | --- | --- |
| `kind` | string | `苔团` | 自由字符串；UI 预设 `苔团` / `夜蛾` / `石卫` |
| `hp` | int | 30 | 1–999 |
| `damage` | int | 5 | 0–999 |
| `facing` | string | `left` | `right` / `left` / `up` / `down` |
| `patrol` | int | 3 | 0–32，仅存数据；预览不执行巡逻 AI |

### `chest` props

| 字段 | 类型 | 默认 | 范围 / 说明 |
| --- | --- | --- | --- |
| `loot` | string | `金币` | 自由字符串；UI 预设 `金币` / `药水` / `钥匙` |
| `amount` | int | 25 | 1–9999 |

预览中走到宝箱格附近会拾取并显示 `loot × amount`；实体属性会随保存/加载/导出保留。

## Layers（仅编辑器 JSON）

```json
"layers": {
  "terrain":   { "visible": true, "locked": false },
  "collision": { "visible": true, "locked": false },
  "entities":  { "visible": true, "locked": false }
}
```

- `visible`：画布是否绘制该层；隐藏时编辑会被阻止，并显示状态提示。
- `locked`：锁定后画布拒绝编辑该层。
- 这两个开关写入**编辑器 JSON**；运行时 JSON 不包含它们，载入时默认全部可见、未锁定。

## 完整示例（4×3）

```json
{
  "format": "mossgarden.level",
  "version": 1,
  "name": "苔庭角落",
  "width": 4,
  "height": 3,
  "cell_size": 16,
  "tiles": [
    [
      { "type": "grass", "variant": -1, "mask": 6 },
      { "type": "grass", "variant": -1, "mask": 14 },
      { "type": "grass", "variant": -1, "mask": 14 },
      { "type": "grass", "variant": -1, "mask": 12 }
    ],
    [
      { "type": "grass", "variant": -1, "mask": 7 },
      { "type": "grass", "variant": -1, "mask": 15 },
      { "type": "grass", "variant": -1, "mask": 15 },
      { "type": "grass", "variant": -1, "mask": 13 }
    ],
    [
      { "type": "grass", "variant": -1, "mask": 3 },
      { "type": "grass", "variant": -1, "mask": 11 },
      { "type": "grass", "variant": -1, "mask": 11 },
      { "type": "grass", "variant": -1, "mask": 9 }
    ]
  ],
  "collision": [
    [0, 0, 0, 0],
    [0, 0, 0, 0],
    [0, 0, 0, 0]
  ],
  "entities": [
    {
      "id": "e1",
      "type": "spawn",
      "x": 1,
      "y": 2,
      "props": { "facing": "up" }
    },
    {
      "id": "e2",
      "type": "chest",
      "x": 2,
      "y": 1,
      "props": { "loot": "药水", "amount": 2 }
    }
  ],
  "layers": {
    "terrain":   { "visible": true, "locked": false },
    "collision": { "visible": false, "locked": false },
    "entities":  { "visible": true, "locked": true }
  },
  "next_entity_id": 3
}
```

对应的运行时导出会去掉 `layers` 与 `next_entity_id`，并把 `format` 改成 `mossgarden.level.runtime`。

## 载入校验

`LevelData.from_dict()` / `from_json()` 会检查：

1. 根节点是对象，`format` 与 `version` 正确。
2. `width` / `height` / `cell_size` 在允许范围。
3. `tiles`、`collision` 行数与每行长度严格等于 `height × width`。
4. Tile 的 `type` 属于四种地形，`variant` 在 `-1..2`，`mask` 在 `0..15`。
5. 实体类型合法，坐标在地图内，`props` 为对象；数值属性按范围夹紧。
6. 实体 id 唯一；缺失/重复自动生成新的 `eN`。

校验失败会返回错误字符串数组，调用方保留原关卡不变。

## 运行时读取约定

- 格子坐标 → 地图像素：`pixel = cell * cell_size`。
- 地形渲染直接使用 `type/variant/mask`；`variant = -1` 时用 `mask` 选择四邻边缘图。
- 碰撞：`collision[y][x] == 1` 不可走；同时石墙和水面在预览中默认不可走。
- 实体坐标是格子左上角的索引；需要中心点时可加 `0.5` 格。
- `mask` 是编辑器计算并随文件保存的“烘焙结果”。若外部工具修改了地形类型，应同步重算掩码，或忽略掩码并按同一规则重建。
