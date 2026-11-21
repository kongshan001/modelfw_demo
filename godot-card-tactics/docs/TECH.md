# 技术说明 · 格间牌战 / Gridbound

本文记录规则模型、状态机、AI、图集切帧、UI 渲染与 CC0 资产管线。目标读者是后续维护者或想移植到其他引擎的人。

> **延伸文档（T-20261121-016）**：[DEVELOPMENT.md](DEVELOPMENT.md) 给出不读 GDScript 也能重写的完整规格与测试向量；[CROSS_ENGINE.md](CROSS_ENGINE.md) 给出 A 数据/B 算法/C 渲染/D 工具链四层拆分与四引擎映射；[PORTABLE_ASSETS.md](PORTABLE_ASSETS.md) 与 [`export/asset_manifest.json`](../export/asset_manifest.json) 给出逐资产清单、帧矩形与校验工具。

## 1. 总览

```
main.gd (Control)
 ├─ BoardView (Control)             9×5 棋盘、格子高亮、点击
 ├─ UnitLayer (Node2D)              UnitView × N（切帧精灵 + 攻血徽章）
 ├─ FxLayer (Node2D)                法术/攻击/召唤/死亡特效 + 飘字
 ├─ 手牌/侧栏/日志/结束回合 (Control)
 └─ Overlay (Control, z=1000)       胜负/重开

BattleCore (RefCounted, 纯规则, 无节点)
 ├─ units / hands / decks / mana / turn_owner / winner / log
 ├─ summon / move / attack / cast / replace / end_turn
 └─ fingerprint()

BattleAI (RefCounted)
 └─ next_action(core) 每次执行一个动作；take_turn(core) 同步跑完

CardDB (RefCounted) ← data/cards.json
AtlasAnim (Sprite2D) ← assets/duelyst_cc0/*/*.json + .png
AssetLoader (静态)  ← 原始 PNG 字节 → ImageTexture（免 .godot/imported）
```

设计原则：

- **规则与表现分离**：`BattleCore` 不依赖节点、纹理或 UI；headless 测试直接跑它。
- **UI 只消费动作返回值**：每个规则动作返回一个 Dictionary（类型、位置、伤害、死亡快照），UI 据此播放动画。
- **程序化回退**：单位纹理加载失败时 `UnitView` 画阵营色圆点；不阻塞规则与对局。
- **不复制原版代码**：仅参考公开玩法描述，GDScript 全部原创。

## 2. 坐标与数据模型

### 2.1 棋盘坐标

- `x ∈ [0, 8]`，`y ∈ [0, 4]`。
- 玩家将军初始 `(4,4)`，AI 将军初始 `(4,0)`。
- 上下左右邻接，无斜走。
- 距离使用曼哈顿距离。

### 2.2 单位 Dictionary

`BattleCore.units: Array[Dictionary]` 中每个元素：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `uid` | int | 全局唯一，递增；general 也占用 uid |
| `card_id` | String | 卡表 id；将军为 `general_f1` / `general_f2` |
| `name` | String | 中文显示名 |
| `owner` | int | 0=玩家，1=AI |
| `x`, `y` | int | 棋盘坐标 |
| `atk` | int | 当前攻击（可被 buff） |
| `hp`, `max_hp` | int | 当前/最大生命 |
| `ranged` | bool | 远程 |
| `provoke` | bool | 嘲讽 |
| `rush` | bool | 疾行 |
| `is_general` | bool | 将军 |
| `can_move` | bool | 本回合还能移动 |
| `can_attack` | bool | 本回合还能攻击 |
| `opening_heal` | int | 登场治疗量（普通单位） |
| `faction` | String | `f1` / `f2` / `neutral` |
| `sprite` | String | 图集 id，如 `f1_silverguardsquire` |

### 2.3 手牌/牌库

- `hands: Array[Array]`：`hands[0]` 玩家，`hands[1]` AI；元素是卡牌 id 字符串。
- `decks` 同理；`decks[owner].pop_front()` 抽牌，替换时 `append` 回牌库底。
- 卡牌静态数据来自 `data/cards.json`，`CardDB.cards[id]` 返回 Dictionary。

### 2.4 卡牌数据 schema

单位：

```json
{
  "id": "f1_backlinearcher",
  "name": "前阵弓手",
  "type": "unit",
  "faction": "f1",
  "cost": 2,
  "atk": 1,
  "hp": 3,
  "keywords": ["ranged"],
  "opening_heal": 0,
  "sprite": "f1_backlinearcher",
  "desc": "远程：同一行或列 2 格内攻击，视线不可被阻挡。"
}
```

法术：

```json
{
  "id": "f1_truestrike",
  "name": "破魔箭",
  "type": "spell",
  "faction": "f1",
  "cost": 2,
  "effect": "damage",
  "amount": 3,
  "target": "enemy_minion",
  "icon": "icon_f1_truestrike",
  "desc": "对一个敌方随从造成 3 点伤害。"
}
```

`effect`：`heal` / `damage` / `buff_attack`。
`target`：`friendly_any` / `friendly_minion` / `enemy_minion` / `enemy_any`。
新增卡牌只需要改 JSON + 对应图集文件；卡面/规则文本会自动读取。

## 3. 回合状态机

```
GAME_START
  ├─ 洗牌（seed）
  ├─ 生成双方将军：玩家 (4,4)，AI (4,0)
  ├─ 双方各抽 3
  └─ start_turn(PLAYER)：抽 1 → 玩家手牌 4

PLAYER_TURN
  ├─ 玩家动作（任意顺序，受 can_move/can_attack/法力限制）
  ├─ 换牌（每回合最多 1 次）
  └─ end_turn()

AI_TURN
  ├─ start_turn(AI)：法力 +1（首次 1）、抽 1、重置己方单位 flags
  ├─ BattleAI phases:
  │    0 出牌（可多次）
  │    1 走位（每个单位最多 1 次）
  │    2 攻击（每个单位最多 1 次）
  │    3 结束回合
  └─ end_turn()

END_OVERLAY（winner >= 0）
  └─ 「再来一局」→ GAME_START（新 seed）
```

`start_turn(owner)` 的细节：

1. `turn_owner = owner`。
2. `replace_used[owner] = false`。
3. 如果该方已经启动过回合：`max_mana = min(9, max_mana + 1)`；否则保持 1。
4. `mana = max_mana`。
5. 该方所有单位 `can_move = true`、`can_attack = true`。
6. 抽 1 张（满手则弃置）。
7. 写战斗日志。

注意：召唤当回合的 `can_attack` 由 `rush` 决定；`can_move` 始终为 true，因此普通随从可以“落地走一步但不能攻击”。

## 4. 动作 API 与返回值

`BattleCore` 的公开动作：

| 方法 | 校验 | 返回 |
| --- | --- | --- |
| `play_unit(owner, hand_index, pos)` | 回合、卡类型、法力、`get_summon_tiles()` | `{type:"summon", uid, pos, deaths:[]}` |
| `move_unit(uid, pos)` | 回合、`can_move`、相邻空格 | `{type:"move", uid, from, to}` |
| `attack(attacker, target)` | 回合、`can_attack`、射程/视线/嘲讽 | `{type:"attack", attacker_uid, target_uid, damage, deaths}` |
| `cast_spell(owner, hand_index, target)` | 回合、法力、目标范围 | `{type:"spell", effect, amount, target_pos, deaths}` |
| `replace_card(owner, idx)` | 每回合 1 次、手牌非空 | bool |
| `end_turn()` | 未分胜负 | `{type:"end_turn", turn_owner, drawn}` |

`deaths` 是给 UI 的快照数组：`uid / name / owner / card_id / x / y / is_general / sprite`。核心会先移除死亡单位，UI 用快照生成死亡残影，不会丢失动画信息。

校验方法都是公开的，UI 与 AI 共用：

- `can_play_unit`
- `get_summon_tiles`
- `get_move_tiles`
- `get_attack_targets`
- `can_cast`

## 5. 攻击规则细节

### 5.1 近战

`manhattan(attacker, target) == 1`。

### 5.2 远程

```
要求: target 与 attacker 在同一行或同一列
距离: 1 或 2
距离 2 时: 中间格必须为空
```

没有斜线远程，也没有穿透；这是需求中“直线且不被阻挡（可简化）”的明确实现。

### 5.3 嘲讽

先计算普通合法目标，再检查攻击者上下左右是否存在敌方 `provoke`。若存在，目标列表过滤为这些嘲讽单位。远程攻击者在距离 2 时不会被嘲讽影响（因为不“相邻”）；一旦被贴脸，则同样被强制。

### 5.4 无反击

攻击只对目标造成 attacker.atk 伤害；目标不反伤。将军也一样。

## 6. AI

### 6.1 分阶段

`BattleAI` 是状态机：

- `next_action(core)` 每次只执行一个动作，返回该动作的结果 Dictionary；UI 在两次调用之间 `await` 0.36–1.05s 播放动画（T-019 表现节奏，非 AI 决策）。
- `take_turn(core)` 循环调用直到 `end_turn` / 胜负；headless 测试用。
- 内部记录 `_move_skipped` / `_play_skipped`，避免在无法行动时死循环；`_action_count > 120` 强制结束。

### 6.2 出牌评分（摘要）

- 随从基础分：`20 + 3×cost`，嘲讽 +6、远程 +4、疾行 +5、登场治疗 +4；再加最佳召唤格分数的 40%。
- 召唤格分数：离玩家将军越近越高，避免落点被多个敌人夹击，偏好靠上（更接近敌方）。
- 法术评分：
  - 伤害：能击杀随从 +40；能击杀将军直接 1000；打将军但未击杀 90+。
  - 治疗：按缺失生命与将军加成评分；缺失 <2 不选。
  - 加攻：按目标攻击力评分。

### 6.3 走位评分

- 当前就能攻击的单位不移动，保留攻击。
- 候选位置 = 当前格 + 4 个相邻空格。
- 评分：到玩家将军的曼哈顿距离（越近越好）、新位置能否攻击目标、击杀加成、远程保持距离 2、避免被多个敌人贴身。
- 将军更保守：只有新位置能攻击时才移动。

### 6.4 攻击评分

- 击杀玩家将军：1000。
- 打将军：200 + 10×伤害。
- 击杀随从：180 + 8×目标攻击。
- 普通伤害：120 − 2×目标剩余 HP + 5×目标攻击。
- 每次选择全局最高分的一对 `(attacker, target)`。

### 6.5 可复现性

- 洗牌是自实现的 Fisher-Yates，使用 `RandomNumberGenerator.seed = seed`。
- AI 所有候选排序都有确定性的 tie-breaker（分数 → 费用 → id → uid/坐标）。
- 冒烟测试用同一 seed + 同一脚本动作跑两遍，比较 `fingerprint()`，完全一致。
- 玩家在 UI 里的实际点击顺序也会改变结果；复现实验使用固定动作序列。

## 7. 图集切帧与动画

### 7.1 数据格式

`open-duelyst-assets` 的 JSON：

```json
{
  "texture_filename": "f1_general.png",
  "width": 1024,
  "height": 1024,
  "frames": {
    "idle": [
      {"frame_name": "...", "x0": 404, "y0": 0, "x1": 504, "y1": 100, "width": 100, "height": 100}
    ],
    "run": [...],
    "attack": [...],
    "hit": [...],
    "death": [...]
  }
}
```

`AtlasAnim`：

- `Sprite2D` + `AtlasTexture.region`，每次换帧只换 texture，不重建节点。
- 纹理由 `AssetLoader` 读取原始 PNG 字节（`Image.load_png_from_buffer`）创建 `ImageTexture`，不调用 `load()` 的导入资源路径，因此干净 clone 首次运行也不需要先让编辑器导入。
- `texture_filter = NEAREST` 保持像素图清晰。
- 动画名回退：`hit → hurt`（部分单位用 `hurt`）、`idle → breathing`、`run → idle`、`attack → cast`。
- 循环：idle/run 循环；attack/hit/death 单次，结束 `finished` 信号。
- 单位 idle 起始相位按 uid 偏移，避免所有单位同步呼吸。
- 卡面 art：`AtlasAnim.static_frame()` 直接取 idle 第 0 帧或法术图标第 0 帧。

### 7.2 表现层动画（T-019 节奏版）

- **攻击**：攻方 `play_attack()` + 向目标方向 **20px** 冲刺 Tween（0.08s 出 / 0.12s 回）；受方 `play_hit()`：**0.03s 白闪 → 0.10s 红闪（#ff6b5e 系）→ 0.14s 恢复**；目标格生成 `fx_slashfrenzy`（远程弓手用 `fx_impact`），并叠加原创程序化命中闪光（白热多边形核心 + 暖色/蓝色外焰，0.10s 展开、0.06s 停留、0.16s 淡出）。
- **死亡**：核心移除单位后，UI 用死亡快照生成独立 `AtlasAnim` 残影，播放 `death` 单次后淡出。
- **移动**：`UnitView.move_to()` 播放 run + Tween 位置；刷新 UI 时对正在移动的 uid 跳过位置同步。
- **召唤**：`fx_summonlegendary`（0.70 缩放，26 帧裁到 **0.60s**）+ 新 UnitView 从 0.25 缩放弹出。
- **法术**：药水 → `fx_heal`，破魔箭 → `fx_impact`，凤火 → `fx_f2_phoenixfire`（0.85 缩放，38 帧裁到 **1.10s**），眼镜蛇击 → `fx_buff`。
- **飘字**：`Label` 0.8→1.15 弹出，上浮 34px / 0.80s；0.42s 停留后 0.38s 淡出；伤害红色、治疗绿色、加攻金色。
- **并发**：同屏 FX 超过 2 个时，最旧的一个立即 0.08s 淡出；所有 FX 默认 0.12s 淡出，不再 0.18s。
- **节奏**：AI 表现动作间隔 summon 0.66 / move 0.36 / attack 0.62 / spell 1.05（只影响 UI 播放，不改 AI 决策）。

FX 的每帧尺寸不同（32×34 到 180×180），`FX_VISUAL_SCALE` 按动画 id 配缩放，保证在 88px 格子内构图合理。`FX_DURATION_LIMIT` 把斩击/召唤/凤火裁到与动作间隔匹配；`AtlasAnim.frame_count()` 用实际帧数反算播放 FPS，避免硬编码。

## 8. UI 与渲染

- 设计分辨率 1280×720；`project.godot` 使用 `canvas_items` + `keep` 拉伸。
- 根节点是 Control；`main.gd` 在 `_ready()` 里按 viewport/1280 设置根 `scale`。正常窗口拉伸时 viewport 逻辑尺寸仍是 1280×720，因此 scale=1；离屏截图用 1920×1080 SubViewport 时自动得到 1.5×。
- 棋盘：
  - 位置 `(236,104)`，格子 88px，总 792×440。
  - 底色由代码绘制；T-019：`#202b3d / #1e293a`（比 T-018 的 `#1b2636 / #192232` 约 +3.5 L*），网格线 α0.12；行 0/4 不再整行染色，改为上 3px 绯 `#d4657a` @0.42、下 3px 金 `#e8c56a` @0.46 的阵营边线。
  - 高亮改为“颜色 + 形状”双编码，绘制顺序固定 **移动 < 召唤 < 法术 < 选中 < 攻击**：
    - 移动：2px `#6ff2cf` 边框 + 四角 8×2 刻度 + 12% 填充 + 4px 中心点；
    - 召唤：金圈 2.5px r≈29 + “+” + 15% 填充 + 1px 暗外环；
    - 法术：8 段虚线环（4px 线宽）+ 6px 菱形符心 + 12% 填充；
    - 选中：近白 `#f7f2df` 双环（r=34/39）+ 四角括号；
    - 攻击：4px 红环 r≈29-30 + 4 个向内箭头 + 24% 填充 + 0.6s 呼吸（13 次/秒重绘，仅攻击态）。
- 单位层（`unit_view.gd`）：
  - 每个单位 = 主精灵 + 4 个队伍色实色剪影（偏移 ±2px，将军 ±3px，α0.65），共 44 个额外精灵；
  - 基座：26×12px 椭圆 3px 队伍色（玩家 `#e8c56a` / 敌方 `#d4657a`，α0.88）+ 1px 暗外环；将军 30×14 + 内环 + 6px 冠饰；
  - 接触影：30px、55% 黑、下移 3px；
  - 攻血徽章：22×22（将军 24×24），亮琥珀 `#e9b45b` / 亮绿 `#7fd39a`（残血 `#ef8b80`）+ 深色数字 + 2px 阴影；徽章与关键词 `z_index=+100`，永远在全部精灵之上；
  - 同行 z 序 `10 + y*10 + x`，消除树顺序造成的重叠抖动；
  - 三张整体过暗的 CC0 图（灯笼狐/猛虎刺客/四方法师）额外 ×1.55/1.38/1.45 提亮；雀鹰 ×1.12，其余 ×1.10。
- 手牌：
  - 卡面 104×144，6 张时中心 640、间距 118、扇形旋转 ±5.5°；基线 **546**（T-018 为 564），悬停 **1.24**（T-018 1.34），选中 1.1 + 上移 26px。
  - 名称带深色内衬（y=0–28，`#081018` α0.72）；规则区内衬（y=84–144，α0.82）。名称 12 / 类型 10 / 描述 10（最多 2 行）；描述为 `CardView.SHORT_DESC` 的 ≤16 字版本（加卡时需补一条，否则回退到原 desc 截 18 字）。
  - 选中改用近白 `#f7f2df` 2px 描边（glow 提到卡框之上），金色只保留给召唤；费用不足时费用徽章转红、卡面降至 72% 亮并保持可点（点击会提示法力不足）。
  - 悬停详情面板（评审可选）未实现。
- HUD：
  - 顶栏中心是唯一回合状态：`你的回合`（金）/`对手回合`（绯）/`对局结束`（灰）；状态提示行移到 y=62（12px，`#b8e6df`），不再被手牌遮挡；
  - 回合数只在标题下 12px 行；法力只在左下水晶 + `法力 N/N`；牌库/手牌只在双方将军面板；Seed 只在结束覆盖层；删除“演示局面/vertical slice/已换牌”等调试文案；
  - AI 回合：手牌整层 α0.60、`mouse_filter=IGNORE`，结束回合按钮禁用并改文案“对手行动中…”；胜负时隐藏顶栏状态，由 z=1000 覆盖层接管；
  - 战斗记录 12px / 行距 3 / 保留最近 10 行；右栏为 11px 操作图例（青框/红环/蓝虚/金圈/白环 + 上绯下金阵地）。
- 中文 UI 使用 `SystemFont`：PingFang SC → Hiragino Sans GB → Heiti SC → Noto Sans CJK SC → Microsoft YaHei → sans-serif；系统回退开启。字体不随项目分发；卡面/徽章另建 weight 650–700 的 SystemFont 以提高小字号字重。
- 目标平台 GL Compatibility；无 3D、无粒子系统。T-019 新增的是：
  - 单位轮廓的极简 2D canvas shader（`COLOR = vec4(outline_color.rgb, outline_color.a * texture(TEXTURE, UV).a)`，只做实色剪影）；
  - 命中闪光的 `Polygon2D` 星形（每帧最多 2 个）；
  - 其余特效仍是 2D 图集精灵。没有全屏 shader/后处理。

## 9. CC0 资产管线

### 9.1 来源

- 资产仓库：<https://github.com/t73liu/open-duelyst-assets>
- 许可：CC0 1.0（仓库根 `LICENSE`）
- 使用 commit：`9fd0a16b611be8c9b991806ec5a6f602aa981823`（2024-12-26）
- 原始游戏：OpenDuelyst / open-duelyst/duelyst（CC0-1.0），只参考玩法，不复制代码。

### 9.2 抽取方式

```bash
git clone --filter=blob:none --no-checkout https://github.com/t73liu/open-duelyst-assets /tmp/open-duelyst-assets
cd /tmp/open-duelyst-assets
git sparse-checkout init --no-cone
git show HEAD:assets/units/f1_general.png > .../assets/duelyst_cc0/units/f1_general.png
git show HEAD:assets/units/f1_general.json > .../assets/duelyst_cc0/units/f1_general.json
```

只复制用到的 60 个源文件（约 1.1MB；另有 Godot 生成的 `.import` 元数据），不搬运完整仓库。完整清单见 `assets/duelyst_cc0/SOURCE.md`。

### 9.3 导入设置

- 单位/图标图集、卡框、tile 高亮：统一通过 `AssetLoader.texture()` 读取 PNG 字节并创建 `ImageTexture`；不使用 SpriteFrames，也不依赖 `.godot/imported` ctex。
- 卡框：TextureRect 缩放到 104×144，默认线性过滤。
- 图集精灵：`AtlasAnim.texture_filter = NEAREST`，避免像素边缘糊掉。
- `docs/.gdignore`：防止 `docs/shots/*.png`、视频被 Godot 当作游戏资源导入。

### 9.4 许可与品牌边界

- CC0 允许复制/修改/商用/不署名；项目仍保留 LICENSE、SOURCE、CREDITS。
- “Duelyst”名称与 Logo 是 Counterplay Games 的商标，**不在 CC0 内**；游戏名使用原创《格间牌战 / Gridbound》，UI 布局与配色为本项目原创。
- 未使用 Duelyst II / Steam 素材。

## 10. 验证与性能

### 10.1 自动化

| 项目 | 命令 | 结果 |
| --- | --- | --- |
| Headless 启动 | `godot --path godot-card-tactics --headless --quit-after 600` | 无 ERROR / SCRIPT ERROR |
| 冒烟测试 | `godot --path godot-card-tactics --headless -s tools/smoke_card_tactics.gd` | 65 checks，末行 `CARD_TACTICS_SMOKE_OK` |
| 真实 GPU 启动 | `godot --path godot-card-tactics --resolution 1280x720 --quit-after 600` | exit 0，console 仅引擎/显卡信息 |
| 截图 | `godot --path ... -s tools/screenshot_card_tactics.gd` | 8 张 1920×1080 + 3 张 1280×720，`CARD_TACTICS_SHOTS_OK` |
| 录像 | `./tools/record_card_tactics.sh` | 10.43s / 1280×720 / 30fps，MP4 + GIF |

### 10.2 FPS

测试设备：Intel Inc. Intel(R) HD Graphics 6000，OpenGL 4.1 Compatibility。
测试方法：`tools/perf_card_tactics.gd`，关闭 vsync，启动后预热 2.5s，每 0.5s 采样一次 `Engine.get_frames_per_second()`。

T-018 基线（raw PNG loader 版本，系统 load average 约 9）：

| 场景 | 平均 | 最低 | 最高 |
| --- | ---: | ---: | ---: |
| 棋盘待机 | 62.2 | 42 | 77 |
| AI 行动/动画 | 55.7 | 40 | 74 |

T-019 最终（4 方向描边，44 个额外精灵，load average 10–24；并行 worker 环境）：

| 场景 | 平均 | 最低 | 最高 |
| --- | ---: | ---: | ---: |
| 棋盘待机 | 85.1 | 73 | 94 |
| AI 行动/动画 | 51.2 | 38 | 73 |

A/B：8 方向描边（88 个额外精灵）同等负载下单次最好 idle 77.8 / action 54.7，故最终取 4 方向。load 25–52 时采样会掉到 15–30 FPS，与 T-018 的窗口遮挡/负载结论一致；中等负载下满足 ≥30 FPS。完整数据见 `docs/shots/artfix/metrics.txt`。Movie Maker 在 30fps 录制时 CPU render time 约 13.75ms/帧，可作为渲染开销旁证。

性能相关的实现选择：

- 单位/图标帧数据与静态卡面 `AtlasTexture` 做进程级缓存，避免每次刷新手牌重复读 JSON / 新建纹理。
- 手牌用内容签名判断是否需要重建；AI 行动、走位、攻击等手牌未变化时只更新选中态。
- 特效为 2D 图集精灵 + 一个程序化 `Polygon2D` 命中闪光；单位轮廓用一个极简 2D canvas shader 做实色剪影；无 3D/粒子/全屏后处理。棋盘只在交互或攻击呼吸时 `queue_redraw()`。

FPS 受窗口遮挡、系统负载影响，报告时以同机采样为准。测试中曾在 load average 11+ 时出现单次 20 FPS 的冷启动采样；预热后复测（即使 load 13.4）待机最低 79、AI 行动最低 73。

## 11. 扩展点

- **加卡**：在 `data/cards.json` 增加条目；单位需要 `units/<sprite>.png/.json`，法术需要 `icons/<icon>.png/.json`，卡框按 faction/type 自动选择。
- **加关键词**：在 `BattleCore._spawn_unit` 解析 `keywords`，在 `get_attack_targets` / 伤害流程中加入规则，并在 `CardView._keyword_text` 与 `UnitView` 标记中显示。卡面描述优先取 `CardView.SHORT_DESC`（≤16 字），新卡需补一条，否则回退到原 desc 截 18 字。
- **加 AI**：`BattleAI` 的评分函数是纯函数；可替换为 MCTS/搜索，只需保持 `next_action` 返回同一动作 Dictionary。
- **换美术**：`AtlasAnim` 只依赖帧 JSON schema；其他图集可用适配器转换。
- **做完整版**：需要补将军技能、神器、完整关键词、卡组编辑、动画队列与音效。

## 12. 已知风险

- GDScript 的 `inference_on_variant` 警告在本机配置下会当错误处理；新增代码涉及 Variant 返回值时请显式标注类型（本项目的 `find()` 等已处理）。
- 系统 CJK 字体依赖运行环境；导出到无中文字体的设备需内置字体。
- 动态生成大量 Control（每次刷新重建手牌）在 6 张时开销可忽略；若扩展到手牌 20+，应改为增量更新。
- 1920×1080 截图通过 1.5× 根节点缩放 + SubViewport；这不是运行时窗口分辨率。
- 原始 PNG 在源码运行时加载；导出 PCK 时需要在导出过滤器中包含这些 PNG，或改回常规导入资源方案。
- 演示视频/截图使用摆拍局面，不代表正常牌库抽牌结果。
