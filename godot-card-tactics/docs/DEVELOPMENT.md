# 开发文档 · 格间牌战 / Gridbound

> **结论先行**：这是一个规则与表现彻底分离的 9×5 卡牌战棋。规则核心 `scripts/battle_core.gd`（616 行）是无节点、无纹理的纯数据状态机；AI `scripts/battle_ai.gd` 只调用同一套公开规则 API；表现层 `scripts/main.gd` 消费每个动作返回的事件字典播放动画。本文给出**不读 GDScript 也能重写**的完整规格：坐标、数据结构、回合状态机、全部规则、AI 评分、确定性、性能基线与验收口径。资产与跨引擎映射分别见 [PORTABLE_ASSETS.md](PORTABLE_ASSETS.md) 与 [CROSS_ENGINE.md](CROSS_ENGINE.md)。

## 0. 事实边界与版本

| 项目 | 值 |
| --- | --- |
| 代码版本 | 仓库 commit `3f74a35`（T-20261121-013 交付） |
| 引擎 | Godot 4.6 stable（GL Compatibility） |
| 设计分辨率 | 1280×720，`canvas_items` 拉伸 + `keep` 宽高比 |
| 参考平台 | Intel HD Graphics 6000 / macOS / OpenGL 4.1 Compatibility |
| 卡池 | 16 张（12 随从 + 4 法术），双方各 20 张套牌 |
| 自动化 | headless 冒烟 65 checks，末行 `CARD_TACTICS_SMOKE_OK` |
| 资产 | CC0 1.0 子集，35 个 PNG + 24 个帧 JSON + LICENSE；来源 commit 见 [PORTABLE_ASSETS.md](PORTABLE_ASSETS.md) |

**事实分类**：

- **项目实测**：本文的规则、数值、坐标、性能、测试结果均来自本项目源码与本机运行；标注“实测”的 FPS 只代表当前机器。
- **公开资料**：Duelyst 原版玩法仅作为灵感背景，本文不声称逐条还原原版；原版完整规则请查公开 wiki/源码，未在本项目验证。
- **移植推断**：跨引擎建议属于工程判断，不是原项目实测，已在 [CROSS_ENGINE.md](CROSS_ENGINE.md) 标明。

---

## 1. 项目地图

```
godot-card-tactics/
├─ project.godot                  # 1280×720 / GL Compatibility / 主场景
├─ scenes/main.tscn               # 单场景入口（根节点 Control + main.gd）
├─ scripts/
│  ├─ battle_core.gd              # 规则核心：棋盘/回合/动作/胜负/fingerprint（无节点）
│  ├─ battle_ai.gd                # 确定性单层贪心 AI（出牌→走位→攻击→结束）
│  ├─ card_db.gd                  # data/cards.json 的读取与索引
│  ├─ main.gd                     # UI 搭建、输入、动画、AI 回合播放
│  ├─ board_view.gd               # 9×5 棋盘绘制、点击命中、高亮层
│  ├─ card_view.gd                # 手牌卡面（104×144）与悬停/选中
│  ├─ unit_view.gd                # 单位精灵、攻血徽章、移动/攻击/受击
│  ├─ atlas_anim.gd               # JSON 帧数据 → AtlasTexture 逐帧动画
│  ├─ asset_loader.gd             # 原始 PNG 字节 → ImageTexture（免导入缓存）
│  └─ mana_bar.gd                 # 9 颗法力水晶
├─ data/cards.json                # 原始卡牌/将军/套牌数据（唯一玩法数据源）
├─ assets/duelyst_cc0/            # CC0 资产子集 + LICENSE + SOURCE.md
├─ export/                        # 引擎无关 manifest / 卡牌导出 / 切片工具
├─ tools/                         # 冒烟、截图、录像、FPS 采样
└─ docs/                          # 本文 / TECH / 跨引擎 / 资产清单 / 迭代记录
```

设计原则：

1. **规则无引擎依赖**：`BattleCore` 不引用 `Node`、纹理或 UI；headless 测试直接跑它。
2. **动作即事件**：每个规则动作返回 `Dictionary`，包含 UI 需要的全部信息（含死亡快照）。
3. **校验与执行共用**：UI/AI 先调用公开校验（`get_summon_tiles` 等），动作内部再校验一次。
4. **表现可降级**：单位纹理缺失时画阵营色圆点，规则照常运行。
5. **数据唯一**：卡牌数值只在 `data/cards.json`；代码里没有第二份卡表。

---

## 2. 运行与验证

```bash
# 运行（从仓库根目录）
godot --path godot-card-tactics

# headless 启动：应无 ERROR / SCRIPT ERROR
godot --path godot-card-tactics --headless --quit-after 600

# 规则冒烟：65 checks，末行 CARD_TACTICS_SMOKE_OK
godot --path godot-card-tactics --headless -s tools/smoke_card_tactics.gd

# 真实 GPU 启动
godot --path godot-card-tactics --resolution 1280x720 --quit-after 600
```

干净 clone（无 `.godot/`）可直接运行：脚本用 `preload` 解析依赖，PNG 由 `AssetLoader` 按字节解码，不依赖编辑器生成的 `.godot/imported/*.ctex`。这是实测结论，不是推断。

**冒烟覆盖**（`tools/smoke_card_tactics.gd`）：

- 数据与资产完整性；法力 1→9 曲线；
- 召唤合法性（仅相邻空格、扣费、扣手牌、回合限制）；
- 移动、近战、远程射程/视线阻挡/斜线拒绝；
- 嘲讽过滤；疾行当回合攻击；登场治疗；
- 开局手牌数、抽牌、手牌上限弃牌、换牌次数；
- AI 完整回合、AI 能独立打完一局并获胜；
- 将军死亡判胜、胜负后动作拒绝；
- 同 seed + 同操作序列的 `fingerprint()` 完全一致。

---

## 3. 坐标、单位与屏幕映射

### 3.1 逻辑棋盘

| 项 | 规格 |
| --- | --- |
| 尺寸 | 9 列 × 5 行 |
| `x` | `0..8`，从左到右 |
| `y` | `0..4`，**从上到下**；`y=0` 是 AI 底线，`y=4` 是玩家底线 |
| 邻接 | 上下左右 4 邻接，**无斜线** |
| 距离 | 曼哈顿距离 `abs(dx)+abs(dy)` |
| 玩家将军 | `(4,4)` |
| AI 将军 | `(4,0)` |

棋盘坐标不是屏幕坐标。逻辑层只存整数格坐标；表现层负责换算。

### 3.2 屏幕映射（1280×720 设计分辨率）

| 常量 | 值 | 出处 |
| --- | ---: | --- |
| 棋盘原点 | `(236,104)` | `main.gd:BOARD_POS` |
| 格子边长 | `88 px` | `board_view.gd:CELL` |
| 棋盘像素尺寸 | `792×440` | `9×88`, `5×88` |
| 单位层/FX 层原点 | 与棋盘原点相同 | `main.gd:_build_board` |
| 手牌基线 Y | `564` | `main.gd:HAND_BASE_Y` |
| 卡面尺寸 | `104×144` | `card_view.gd:CARD_SIZE` |

格中心公式（`board_view.gd:cell_center`）：

```
screen_x = 236 + (x + 0.5) * 88
screen_y = 104 + (y + 0.5) * 88
```

由此得到关键像素：

| 位置 | 格坐标 | 屏幕中心 |
| --- | --- | --- |
| 玩家将军 | `(4,4)` | `(632,500)` |
| AI 将军 | `(4,0)` | `(632,148)` |
| 棋盘左上格 | `(0,0)` | `(280,148)` |
| 棋盘右下格 | `(8,4)` | `(984,500)` |

窗口缩放：`project.godot` 使用 `canvas_items` + `keep`，因此逻辑坐标始终是 1280×720；窗口变大时由引擎整体缩放。截图工具用 1920×1080 的 SubViewport，`main.gd` 检测到 viewport 不是设计尺寸时把根节点 `scale` 设为 `viewport/1280`，所以截图是 1.5× 离屏渲染，不是运行时分辨率。

### 3.3 UI 布局（1:1 复刻时需要）

| 元素 | 位置/尺寸 |
| --- | --- |
| 左侧玩家面板 | `(14,104)`，`208×440` |
| 右侧 AI 面板 | `(1042,104)`，`224×440` |
| 左下法力/换牌面板 | `(14,560)`，`208×146` |
| 右下 seed/重开面板 | `(1042,560)`，`224×146` |
| 顶部标题/回合 | y=8..61 |
| 棋盘下方状态行 | `(236,545)`，`792×16` |
| 胜负覆盖层 | 全屏，`z_index=1000`，面板 `480×280` 居中 |

手牌扇形（`main.gd:_rebuild_hand`）：

- 卡面 `104×144`，间距 `118`，中心 x=`640`；
- 每张旋转 `center_offset × 2.2°`（`center_offset = i - (n-1)/2`）；
- 垂直偏移 `abs(center_offset) × 7 px`；选中的牌再上移 `26 px`；
- 悬停 `scale=1.34, z=60`；选中 `scale=1.1, z=40` 并加金色描边。

---

## 4. 数据模型

### 4.1 单位 `Unit`（`BattleCore.units: Array[Dictionary]`）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `uid` | int | 全局唯一、自增；将军也占 uid |
| `card_id` | string | 卡表 id；将军为 `general_f1` / `general_f2` |
| `name` | string | 中文显示名 |
| `owner` | int | `0=玩家`，`1=AI` |
| `x`, `y` | int | 棋盘格坐标 |
| `atk` | int | 当前攻击（可被永久 buff） |
| `hp`, `max_hp` | int | 当前/最大生命 |
| `ranged` | bool | 远程 |
| `provoke` | bool | 嘲讽 |
| `rush` | bool | 疾行 |
| `is_general` | bool | 是否将军 |
| `can_move` | bool | 本回合还能移动 |
| `can_attack` | bool | 本回合还能攻击 |
| `opening_heal` | int | 登场治疗量（普通单位） |
| `faction` | string | `f1` / `f2` / `neutral` |
| `sprite` | string | 图集 id，如 `f1_silverguardsquire` |

将军由 `_spawn_general` 创建：`atk=2`、`hp=max_hp=20`、`is_general=true`、`ranged/provoke/rush=false`、出生即可移动/攻击。

### 4.2 对局状态（`BattleCore` 字段）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `units` | `Array[Dictionary]` | 所有存活单位（含双方将军） |
| `hands` | `Array[Array[String]]` | `hands[0]` 玩家手牌，`hands[1]` AI；元素是 card_id |
| `decks` | `Array[Array[String]]` | 牌库；`pop_front()` 抽牌，`append()` 回牌库底 |
| `mana` / `max_mana` | `Array[int]` | 当前/上限法力，按 owner 索引 |
| `started_turns` | `Array[int]` | 每方已开始过的回合数 |
| `replace_used` | `Array[bool]` | 本回合是否已换牌 |
| `turn_owner` | int | 当前行动方 |
| `winner` | int | `-1=未分胜负`，`0=玩家胜`，`1=AI 胜` |
| `next_uid` | int | 下一个单位 uid |
| `turn_serial` | int | 内部分配序号；**不在 fingerprint 中**，不参与规则 |
| `general_uids` | `Array[int]` | 双方将军 uid |
| `log_lines` | `Array[String]` | 最近 80 条战斗日志 |
| `seed_value` / `rng` | int / RNG | 复现用 seed 与 RNG 实例 |

### 4.3 卡牌数据 `data/cards.json`

顶层：`generals`（按阵营）、`cards`（数组）、`decks`（`player` / `ai`）。

**随从卡 schema**：

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

**法术卡 schema**：

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

| 字段 | 取值 |
| --- | --- |
| `type` | `unit` / `spell` |
| `faction` | `f1`（晨光）/ `f2`（风间）/ `neutral`（中立） |
| `keywords` | `ranged` / `provoke` / `rush`；空数组表示普通随从 |
| `opening_heal` | 整数；缺省 0；>0 时召唤后治疗己方将军 |
| `effect` | `heal` / `damage` / `buff_attack` |
| `target` | `friendly_any` / `friendly_minion` / `enemy_minion` / `enemy_any` |
| `sprite` | 单位图集 id（`assets/duelyst_cc0/units/<id>.png`） |
| `icon` | 法术图标图集 id（`assets/duelyst_cc0/icons/<id>.png`） |

引擎无关的规范化版本见 [`export/cards.json`](../export/cards.json)：保留原值，补充 `stats` / `spell` / `art.asset_id` / `rules`，原始 `data/cards.json` 不被修改。资产 id 与路径的权威清单见 [`export/asset_manifest.json`](../export/asset_manifest.json)。

### 4.4 卡池（16 张）

| id | 名称 | 阵营 | 类型 | 费用 | 攻/血 | 关键词/效果 |
| --- | --- | --- | --- | ---: | --- | --- |
| `f1_silverguardsquire` | 白银侍从 | 晨光 | 随从 | 2 | 2/2 | — |
| `f1_backlinearcher` | 前阵弓手 | 晨光 | 随从 | 2 | 1/3 | 远程 |
| `f1_sunstonetemplar` | 日石骑士 | 晨光 | 随从 | 3 | 3/3 | — |
| `f1_windbladecommander` | 风刃指挥官 | 晨光 | 随从 | 4 | 3/4 | 嘲讽 |
| `f1_ironcliffeguardian` | 铁崖守卫 | 晨光 | 随从 | 5 | 3/7 | 嘲讽 |
| `f2_onyxjaguar` | 猛虎刺客 | 风间 | 随从 | 3 | 3/3 | 疾行 |
| `f2_sparrowhawk` | 雀鹰 | 风间 | 随从 | 2 | 2/1 | 远程 |
| `f2_lanternfox` | 灯笼狐 | 风间 | 随从 | 3 | 2/3 | — |
| `f2_mage4winds` | 四方法师 | 风间 | 随从 | 4 | 2/4 | 远程 |
| `f2_heartofthesonghai` | 心之侍 | 风间 | 随从 | 5 | 4/5 | — |
| `neutral_healingmystic` | 疗愈秘术师 | 中立 | 随从 | 3 | 2/3 | 登场：己方将军 +2 HP |
| `neutral_bonereaper` | 骸骨收割者 | 中立 | 随从 | 4 | 3/4 | — |
| `f1_sundropelixir` | 阳光药水 | 晨光 | 法术 | 1 | — | 友方任意目标恢复 4 HP |
| `f1_truestrike` | 破魔箭 | 晨光 | 法术 | 2 | — | 敌方随从受到 3 伤害 |
| `f2_phoenixfire` | 凤火 | 风间 | 法术 | 3 | — | 敌方任意目标受到 3 伤害 |
| `f2_cobrastrike` | 眼镜蛇击 | 风间 | 法术 | 2 | — | 友方随从永久 +2 攻击 |

套牌（`data/cards.json:decks`）：

- 玩家（晨光 + 中立）：白银侍从 ×3、前阵弓手 ×2、日石骑士 ×3、风刃指挥官 ×2、铁崖守卫 ×2、疗愈秘术师 ×2、骸骨收割者 ×1、阳光药水 ×2、破魔箭 ×3 = 20。
- AI（风间 + 中立）：猛虎刺客 ×3、雀鹰 ×3、灯笼狐 ×3、四方法师 ×2、心之侍 ×2、疗愈秘术师 ×2、骸骨收割者 ×1、凤火 ×2、眼镜蛇击 ×2 = 20。

> 这些数值是 vertical slice 的可玩性调整，不代表 Duelyst 原版平衡。

---

## 5. 回合状态机

### 5.1 全局流程

```
setup(seed, player_deck, ai_deck)
  ├─ rng.seed = seed
  ├─ 复制双方套牌并各自 Fisher-Yates 洗牌
  ├─ 创建玩家将军 (4,4)、AI 将军 (4,0)
  ├─ 双方各抽 3 张
  └─ start_turn(PLAYER)  ← 玩家再抽 1，因此开局手牌 4；AI 仍 3

PLAYER_TURN
  ├─ 玩家可任意顺序：出牌 / 移动 / 攻击 / 法术 / 换牌（各受次数与法力约束）
  └─ end_turn()
       └─ start_turn(AI)

AI_TURN
  ├─ BattleAI.next_action() 每次一个动作：出牌→走位→攻击→结束
  └─ end_turn()
       └─ start_turn(PLAYER)

winner >= 0
  └─ 所有动作被拒绝；UI 显示胜负覆盖层；重开 → setup(新 seed)
```

### 5.2 `start_turn(owner)` 的精确顺序

1. `turn_owner = owner`；
2. `replace_used[owner] = false`；
3. **若该方此前已开始过回合**（`started_turns[owner] > 0`）：`max_mana = min(9, max_mana + 1)`；否则保持不变（首次为 1）；
4. `mana = max_mana`；
5. `started_turns[owner] += 1`；`turn_serial += 1`；
6. 该方所有存活单位 `can_move = true`、`can_attack = true`；
7. 抽 1 张（牌库空则不抽；满 6 张则弃置抽到的牌，但牌库仍 -1）；
8. 写日志。

因此：

- 双方第一次回合都是 **1 法力**（不是先手 1、后手 2）；
- 玩家第 N 个自己的回合上限 `min(9, N)`；
- 法力每回合回满，未用不保留；
- 将军也遵循同样的 `can_move/can_attack` 重置。

### 5.3 `end_turn()`

- 若 `winner >= 0` → 返回 `{type:"none"}`，不切换；
- 否则记录 `ending`，切换 `turn_owner`，调用新行动方的 `start_turn`，返回 `{type:"end_turn", ending, turn_owner, drawn}`。

### 5.4 动作次数与不变量

- 每个单位每回合：最多移动 1 次、攻击 1 次；二者独立，可先移动后攻击，也可先攻击后移动。
- 召唤当回合：`can_move=true`；`can_attack` 仅在 `rush` 时为 true。
- 法术不消耗单位行动次数，只消耗法力与手牌。
- 出牌/换牌次数只受法力、手牌与“每回合 1 次换牌”约束，没有“每回合最多出 N 张”的硬限制。
- 单位死亡立即从 `units` 移除；攻击/法术的结果字典携带死亡快照供 UI 播放。

---

## 6. 公开动作 API

所有动作先校验、后执行；失败返回空字典（或 `false`）。UI 与 AI 共用这些方法。

| 方法 | 前置校验 | 成功返回 |
| --- | --- | --- |
| `get_summon_tiles(owner)` | 无（只读） | `Array[Vector2i]`，排序：`y` 升序再 `x` 升序 |
| `can_play_unit(owner, hand_index, pos)` | 未分胜负、当前回合、卡是随从、法力够、`pos` 在召唤格 | `bool` |
| `play_unit(owner, hand_index, pos)` | 同上 | `{type:"summon", owner, uid, card_id, card_name, pos, deaths:[]}` |
| `get_move_tiles(uid)` | 未分胜负、己方回合、`can_move` | `Array[Vector2i]`，相邻空格，排序同上 |
| `move_unit(uid, pos)` | `pos` 在移动格 | `{type:"move", owner, uid, from, to}` |
| `get_attack_targets(uid)` | 自动使用单位当前位置 | `Array[int]`（目标 uid） |
| `get_attack_targets_at(uid, pos)` | 假设站在 `pos`，不修改棋盘 | `Array[int]`；AI 走位评估用 |
| `attack(attacker_uid, target_uid)` | 目标在 `get_attack_targets`、`can_attack` | `{type:"attack", owner, attacker_uid, target_uid, attacker_name, target_name, damage, target_pos, attacker_pos, deaths:[]}` |
| `can_cast(owner, hand_index, target_uid)` | 未分胜负、当前回合、卡是法术、法力够、目标符合 `target` | `bool` |
| `cast_spell(owner, hand_index, target_uid)` | 同上 | `{type:"spell", owner, card_id, card_name, target_uid, target_pos, effect, amount, deaths:[], healed? , damage? , attack_buff? }` |
| `replace_card(owner, hand_index)` | 当前回合、本回合未换、索引有效 | `bool` |
| `end_turn()` | 未分胜负 | `{type:"end_turn", ending, turn_owner, drawn}` |
| `damage_unit(uid, amount, reason)` | 测试/脚本用 | `{type:"damage", target_uid, damage, deaths:[], owner, target_name}` |

**死亡快照**（`deaths` 数组元素）：

```json
{
  "uid": 7, "name": "前阵弓手", "owner": 1, "card_id": "f1_backlinearcher",
  "x": 2, "y": 1, "is_general": false, "sprite": "f1_backlinearcher"
}
```

核心先移除死亡单位，再把快照交给 UI，因此表现层不会因为单位已删除而丢失位置/图集信息。

**只读/测试辅助**：

| 方法 | 用途 |
| --- | --- |
| `hand_card(owner, i)` | 返回手牌卡数据；越界返回空字典 |
| `playable_hand_indices(owner)` | 当前法力可支付的卡索引（只读；UI 也可自行判断） |
| `general_unit(owner)` / `general_hp(owner)` | 将军单位/生命；将军已死返回空/0 |
| `find_unit(uid)` / `unit_at(lpos)` / `units_of(owner)` | 查询；`units_of` 按 uid 升序 |
| `debug_spawn(card_id, owner, pos)` | **仅供截图/演示摆拍**：不扣手牌/法力，单位默认已行动；正常对局不要使用 |
| `damage_unit(uid, amount, reason)` | 测试/脚本直伤；正常对局由 attack/spell 结算 |

---

## 7. 规则细则

### 7.1 法力

- 双方独立；初始 `mana = max_mana = 1`；
- 每次自己的 `start_turn` 上限 +1，封顶 9，并回满；
- 召唤/法术立即扣费，不返还；
- 没有“过载/临时法力”。

### 7.2 抽牌、手牌上限、换牌

- 每回合开始抽 1；
- 手牌上限 6；**抽牌时若手牌已满，仍从牌库移除该牌并弃置**（不是不抽）；
- 牌库空时不抽，也不造成疲劳伤害；
- 换牌：每方每回合 1 次；把选中手牌移到牌库底，再抽 1；先移除再抽，所以手牌数不变；手牌为空不能换；
- 换牌不受“手牌上限”影响（移除后最多 5 再抽 1）。

### 7.3 召唤

- 合法格 = 己方将军或任意友方随从的上下左右相邻空格；多个来源取并集；不能落在已占用格或棋盘外；
- 只能召唤到上述格子，不能空降到远处；
- 召唤扣除卡牌费用并把手牌移出；
- 新单位 `can_move=true`；`can_attack=rush`；
- 若卡牌有 `opening_heal > 0`：立即治疗己方将军 `min(max_hp, hp + opening_heal)`；
- 召唤本身不触发胜负（治疗不会杀死将军）。

### 7.4 移动

- 每单位每回合 1 次；
- 只能移动到 4 邻接的**空格**；不能斜走、不能穿过/停留于其他单位；没有路径连续移动；
- 移动不消耗攻击次数；移动后仍可攻击；
- 远程单位没有“移动后不能攻击”的惩罚。

### 7.5 攻击与射程

**近战**（`ranged=false`）：

- 目标必须是曼哈顿距离 1 的敌方单位（含敌方将军）。

**远程**（`ranged=true`）：

- 目标必须在同一行或同一列；
- 距离 1 或 2；
- 距离 2 时，中间格必须为空（视线阻挡）；距离 1 无中间格；
- 没有斜线远程、没有穿透、没有 AOE。

**嘲讽**：

- 先算出普通合法目标；
- 若攻击者当前位置的 4 邻接内存在敌方 `provoke` 单位，则目标列表过滤为这些嘲讽单位；
- 该过滤对近战和远程都生效：远程贴脸时也不能越过相邻嘲讽去打远处目标；距离 2 的嘲讽不会被强制（不“相邻”）。

**结算**：

- 攻击者 `can_attack=false`；
- 目标 `hp -= attacker.atk`；
- **没有反击**，将军也不反伤；
- 目标 `hp <= 0` 立即死亡并从 `units` 移除；
- 每次攻击后检查胜负。

**目标顺序**：`get_attack_targets` 按 `units` 数组顺序（等价 uid 升序）返回；有嘲讽过滤时保持该顺序。移植时建议显式按 uid 升序，避免容器实现差异。

### 7.6 疾行与登场治疗

- `rush`：召唤当回合 `can_attack=true`，可以立即攻击；仍只有 1 次攻击。
- `opening_heal`：召唤后治疗己方将军；与 `rush` 可同时存在（当前卡池无此组合）。

### 7.7 法术

目标合法性（`_valid_spell_target`）：

| `target` | 合法目标 |
| --- | --- |
| `friendly_any` | 己方任意单位（含将军） |
| `friendly_minion` | 己方非将军单位 |
| `enemy_minion` | 敌方非将军单位 |
| `enemy_any` | 敌方任意单位（含将军） |

效果：

| `effect` | 结算 |
| --- | --- |
| `heal` | `hp = min(max_hp, hp + amount)`；结果带实际治疗量 `healed` |
| `damage` | `hp -= amount`；结果带 `damage`；可击杀，包括将军 |
| `buff_attack` | `atk += amount`，永久；结果带 `attack_buff` |

- 法术必须有单位目标，不能指向空格；
- 法术不触发 `opening_heal`、不受嘲讽影响；
- 施法后检查胜负；击杀将军立即结束。
- 当前卡池：阳光药水（friendly_any, heal 4）、破魔箭（enemy_minion, damage 3）、凤火（enemy_any, damage 3）、眼镜蛇击（friendly_minion, buff_attack 2）。

### 7.8 胜负

- 任意一方将军 `hp <= 0` → 该单位死亡并被移除；
- 玩家将军死亡 → `winner=1`（AI 胜）；AI 将军死亡 → `winner=0`（玩家胜）；
- `winner >= 0` 后：`play_unit` / `move_unit` / `attack` / `cast_spell` / `replace_card` / `end_turn` 全部拒绝；
- **边界**：代码对“双方将军同时消失”保持 `winner=-1`（没有平局状态）。当前一次只结算一个动作，不可能同时击杀双方；如果扩展 AOE/同时结算，需要新增平局或优先级规则。

---

## 8. AI 决策

AI 与玩家使用完全相同的规则 API；它只决定“下一个动作”，不直接改状态。

### 8.1 主循环

```
next_action(core):
  若未激活 / 已分胜负 / 不是 AI 回合 → none
  action_count += 1；>120 → 强制 end_turn
  phase 0: 尝试出牌；有合法牌 → 返回该动作
  phase 1: 尝试走位；有移动 → 返回该动作
  phase 2: 尝试攻击；有攻击 → 返回该动作
  phase 3: end_turn
```

- `begin_turn` 重置 phase、跳过集合与动作计数；
- `_move_skipped` / `_play_skipped` 防止同一单位/同一卡 id 反复失败导致死循环；
- UI 每两个动作之间等待：召唤 0.48s、移动 0.34s、攻击 0.58s、法术 0.68s、其他 0.25s；AI 回合开始时额外等 0.45s；
- headless 的 `take_turn()` 同步循环到 `end_turn` 或胜负，最多 120 步。

### 8.2 出牌评分

对每张可支付的手牌：

**随从**：

```
score = 20 + 3*cost
      + 6 (provoke) + 4 (ranged) + 5 (rush) + 4 (opening_heal>0)
      + 0.4 * tile_score(best_summon_tile)
```

`tile_score`：

```
score = -3 * manhattan(tile, player_general)
        -0.5 * tile.y
        -5 * (tile 的 4 邻接敌方单位数)
```

即：靠近玩家将军、靠上、避免落在多个敌人旁边。疾行单位若落点能攻击，额外 +35。

**法术**：枚举合法目标，按效果评分：

| 效果 | 评分 |
| --- | --- |
| `damage` 随从 | `50 + 5*target.atk`；能击杀 +40 |
| `damage` 将军 | `90 + 4*amount + (60 if kill)`；能击杀直接 `1000` |
| `heal` | 缺失 <2 不选；`30 + 3*min(missing, amount)`；将军额外 +20 |
| `buff_attack` | `35 + 3*target.atk` |

**排序**：分数降序 → 费用降序 → card id 升序。取第一个；执行失败则把该 card id 加入 `_play_skipped`。

### 8.3 走位评分

对每个己方单位（uid 升序）：

- 若当前就能攻击，跳过移动（保留攻击）；
- 候选 = 当前格 + 4 个相邻空格；
- 初始分：

```
score = -4 * manhattan(pos, player_general)
if 从 pos 能攻击: +60；对每个可攻击目标：将军 +14，能击杀 +10
```

- 将军：能攻击新位置 → `200`，否则 `score*0.1`；原地 +1（保守，不主动脱离）；
- 远程：最近敌人距离 2 → +12；≤1 → -8；
- 所有单位：每个相邻敌人 -6；原地 +2；
- 取严格更高分的位置（并列保留先遇到的，候选按 y 再 x 排序）；没有更高分则跳过。

### 8.4 攻击评分

枚举所有 `(attacker, target)`（attacker uid 升序，target uid 升序）：

| 情形 | 评分 |
| --- | --- |
| 击杀玩家将军 | `1000` |
| 打玩家将军未击杀 | `200 + 10*damage` |
| 击杀随从 | `180 + 8*target.atk` |
| 普通伤害 | `120 - 2*target.hp + 5*target.atk` |
| 所有情况 | 再加 `0.1*damage` |

取全局最高分；并列时保留先遇到的（严格 `>`）。执行后 `can_attack=false`，下一轮重新枚举。

### 8.5 确定性与弱点

- 所有候选遍历顺序固定（手牌索引、单位 uid、格子 y/x、目标 uid）；浮点分数只在同一动作内比较，并用 `is_equal_approx` 判平；
- 同 seed + 同玩家操作序列 → 同结果（冒烟覆盖）；
- 弱点（已知）：单层贪心、无多回合规划、不使用换牌、不会为法术保留法力、不会预判 AOE/斩杀线；遇到嘲讽只会攻击嘲讽单位。它“能完整打完”，但不是强 AI。

---

## 9. 确定性、种子与复现

### 9.1 RNG 与洗牌

- `setup(seed, ...)` 设置 `RandomNumberGenerator.seed = seed`；
- 双方套牌各自洗牌，使用自实现的 Fisher-Yates：

```
for i from n-1 down to 1:
    j = rng.randi_range(0, i)
    swap(arr[i], arr[j])
```

- 规则层在 setup 之后不再使用 RNG；AI 没有随机数；
- 玩家 UI 的点击顺序是输入的一部分，因此“同 seed”只有在“同操作序列”下才完全可复现。

### 9.2 `fingerprint()`

返回一个 JSON 字符串，字段：

```
seed, turn_owner, mana, max_mana, started_turns, replace_used,
winner, next_uid, hands, decks, units
```

`units` 按 uid 升序，每行：

```
[uid, owner, card_id, x, y, atk, hp, can_move, can_attack]
```

**不包含**：`log_lines`、`general_uids`、`turn_serial`、RNG 内部状态、`spawn` 历史。当前规则在 setup 后不用 RNG，所以不影响对局；如果扩展随机效果，必须把 RNG 状态纳入状态哈希。

### 9.3 参考测试向量（实测）

以下由 Godot 4.6 + 本项目代码直接输出；用于移植时的数据级对照：

**seed = 777（初始状态，玩家刚抽完第 4 张）**

```
玩家手牌: f1_silverguardsquire, f1_ironcliffeguardian, f1_truestrike, f1_sundropelixir
AI 手牌:  f2_sparrowhawk, f2_sparrowhawk, f2_cobrastrike
玩家牌库(16): f1_sunstonetemplar, f1_ironcliffeguardian, f1_silverguardsquire,
  f1_truestrike, f1_truestrike, neutral_bonereaper, f1_silverguardsquire,
  f1_windbladecommander, neutral_healingmystic, f1_backlinearcher,
  f1_sunstonetemplar, neutral_healingmystic, f1_windbladecommander,
  f1_sundropelixir, f1_sunstonetemplar, f1_backlinearcher
AI 牌库(17): f2_phoenixfire, neutral_healingmystic, f2_mage4winds,
  f2_cobrastrike, neutral_healingmystic, f2_heartofthesonghai,
  f2_onyxjaguar, f2_phoenixfire, f2_lanternfox, f2_mage4winds,
  f2_lanternfox, f2_onyxjaguar, neutral_bonereaper, f2_sparrowhawk,
  f2_lanternfox, f2_onyxjaguar, f2_heartofthesonghai
fingerprint SHA-256: 6e681ae13468a62941c8a7f711b04a98333dfae234a8a48cee2143007c05b224
```

**seed = 20260227（`main.gd` 默认首局）**

```
玩家手牌: f1_sundropelixir, neutral_healingmystic, f1_silverguardsquire, f1_windbladecommander
AI 手牌:  f2_mage4winds, f2_sparrowhawk, f2_phoenixfire
fingerprint SHA-256: cecc57b82b86232b56adf5ddda4010d2017a6475f42ee9877105ff0356774ffc
```

> SHA 是 Godot `JSON.stringify(fingerprint())` 字符串的 SHA-256，依赖键插入顺序与 Godot 的序列化格式。**跨引擎不要直接比对 SHA**；请按 §9.2 字段逐项比较，或定义“键排序 + 无空格”的 canonical JSON 后再哈希。手牌/牌库序列是更稳的对照数据。

### 9.4 跨引擎确定性建议

1. 规则层显式接收“洗好的牌库顺序”，把 RNG 作为可选的上游；这样测试可以注入 §9.3 的牌序。
2. 若必须同 seed 同牌序：移植 Godot 的 PCG32 `RandomNumberGenerator` 及 `randi_range` 映射；不要用语言默认 RNG 冒充。
3. AI 浮点分数：保持同一运算顺序，或把分数四舍五入到 1e-6 后再比较；并列时使用文档给出的 tie-breaker。
4. 容器遍历：不要依赖哈希表迭代顺序；单位按 uid、目标按 uid、格子按 y/x 排序。

---

## 10. 表现层规格（复刻画面时需要）

规则不依赖画面；以下是当前实现的 1:1 表现参数。

### 10.1 单位

| 项 | 值 |
| --- | --- |
| 图集帧 | 每帧原始尺寸 80×80 ~ 130×130（见 manifest） |
| `Sprite2D` 缩放 | `1.22`；将军再 ×`1.1`（总 1.342） |
| 位置 | 格中心 + `(0,-2)` |
| 锚点 | 帧中心（Godot Sprite2D 默认 centered） |
| 朝向 | 攻击时 `flip_h = 目标在左侧` |
| 地面阴影 | 椭圆：中心 `(0,31)`，半径 28，y 缩放 0.34，黑色 38% |
| 攻/血徽章 | 21×21 圆角面板；攻击 `(-31,17)`、生命 `(11,17)` |
| 关键词标记 | `(15,-46)`，字号 9：嘲/远/疾；将军显示“将” |
| 深度 | `z_index = 10 + y`（y 越大越靠前） |

动画（`UnitView`）：

| 动画 | FPS | 循环 | 触发 |
| --- | ---: | --- | --- |
| idle | 8 | 是 | 待机；起始相位按 `uid*3` 偏移，避免同步呼吸 |
| run | 13 | 是 | 移动 Tween 期间 |
| attack | 17 | 否 | 攻击；结束后回 idle |
| hit | 15 | 否 | 受击；同时闪红 0.06s→0.16s |
| death | 14 | 否 | 死亡残影，播完淡出 0.18s |

动画名回退：`hit→hurt`、`idle→breathing`、`run→idle`、`attack→cast`、`death→idle`；最终回退到 JSON 的第一个动画。当前 `f1_windbladecommander` 用 `hurt` 而非 `hit`；两个将军有 `cast*` 但本作未使用。

移动/攻击 Tween：

- 移动：0.24s 到目标格；播放 run；结束回 idle；
- 攻击冲刺：向目标方向 13px / 0.09s，再回位 / 0.12s；
- 召唤：从 `scale=0.25` 弹到 1.0。

### 10.2 手牌与卡面

- 卡框：按 `faction + type` 选 `assets/duelyst_cc0/card_backgrounds/<faction>_<type>.png`，非等比拉伸到 104×144（原始 224×294 或 226×296）。
- 卡面 art 区域：`(10,25)`，`84×66`，`keep-aspect-centered`，最近邻过滤：
  - 随从：对应单位图集的 `idle[0]` 静态帧；
  - 法术：对应图标图集的**第一个动画**的 `[0]` 帧（图标 JSON 的第一个动画是该法术名，第二个是 `active`）。
- 费用：左上 27×27 圆形徽章；攻/血：随从 24×24 徽章；名称/关键词/描述为 8–11px 系统字体。
- 悬停/选中缩放与 z 见 §3.3。

### 10.3 棋盘与高亮

- 棋盘底色由代码绘制：深蓝灰格、AI 侧顶行偏紫、玩家侧底行偏黄、中线装饰点；格线 1px 半透明。
- 高亮纹理（128×128 PNG，缩放到 88×88，线性过滤）：
  - `tile_hover` 青色（移动/悬停）；
  - `tile_spawn` 金色（召唤）；
  - `tile_attack` 红色（攻击）；
  - `tile_spell` 蓝色（法术目标）；
  - `tile_target` 金色（选中格）。
- **注意**：`tile_spawn.png`、`tile_spell.png`、`tile_target.png` 在本资产版本中字节相同（SHA-256 相同），差异来自运行时 tint 与叠加圆弧。
- 高亮颜色（RGBA，实现在 `board_view.gd`）：移动 `(0.32,0.95,0.75,0.55)`、召唤 `(1.0,0.82,0.36,0.72)`、攻击 `(1.0,0.32,0.28,0.72)`、法术 `(0.55,0.72,1.0,0.65)`、选中 `(1.0,0.9,0.5,0.4)`。

### 10.4 特效

| 事件 | 图集 | 视觉缩放 | FPS / 循环 |
| --- | --- | ---: | --- |
| 近战命中 | `fx_slashfrenzy` | 0.95 | 24 / 否 |
| 前阵弓手远程攻击、破魔箭 | `fx_impact`（默认动画 `impactbluemedium`） | 2.3 | 24 / 否 |
| 阳光药水 | `fx_heal` | 1.15 | 24 / 否 |
| 眼镜蛇击/未知法术回退 | `fx_buff` | 1.8 | 24 / 否 |
| 召唤 | `fx_summonlegendary` | 0.82 | 24 / 否 |
| 凤火 | `fx_f2_phoenixfire` | 0.95 | 24 / 否 |

- FX 层的 `z_index=60`；死亡残影 `55`；单位 `10+y`；覆盖层 `1000`。
- 飘字：伤害红、治疗绿、加攻金；从格中心 `(-30,-62)` 上浮 30px / 0.72s 并淡出。
- 所有 FX 都是 2D 图集逐帧，无粒子/shader。

### 10.5 字体

- Godot `SystemFont`，优先 PingFang SC / Hiragino Sans GB / Heiti SC / Noto Sans CJK SC / Microsoft YaHei / sans-serif；
- **不随项目分发字体**。移植到无 CJK 字体的环境需内置字体（如 Noto Sans SC，注意其 OFL 许可）。

---

## 11. 性能（实测，不是推断）

测试设备：Intel HD Graphics 6000，OpenGL 4.1 Compatibility，1280×720，关闭 vsync。`tools/perf_card_tactics.gd`：预热 2.5s，每 0.5s 采样 `Engine.get_frames_per_second()`。

| 场景 | 平均 FPS | 最低 | 最高 |
| --- | ---: | ---: | ---: |
| 棋盘待机（11 单位 + 6 手牌） | 62.2 | 42 | 77 |
| AI 行动/动画期间 | 55.7 | 40 | 74 |

更早的空闲复测：待机 avg 118 / AI 行动 avg 92。多轮范围：待机 62–118、AI 行动 56–92，均高于 30 FPS 目标。最新一轮采样时系统 load average 约 9–13（有其他 worker 并发），FPS 受窗口遮挡、冷启动、系统负载影响明显；单次 20 FPS 的冷启动采样在预热后未复现。

性能相关的实现选择（可移植）：

- JSON 帧数据与静态 `AtlasTexture` 进程级缓存；手牌按内容签名判断是否重建；
- 棋盘仅在交互/高亮变化时重绘；
- 全部 2D 图集精灵，无 3D、无粒子、无 shader、无 MSAA；
- GL Compatibility 渲染路径，目标集显。

> 跨引擎的性能不能直接对比；上面的数值只作为“原实现足够轻量”的参考。移植验收应在目标引擎/设备上重新采样，目标仍是 1280×720 下 ≥30 FPS。

---

## 12. 已知限制与陷阱

**玩法/内容**

- 单层贪心 AI：能完整打完，无长线规划；不会换牌；不会为组合保留资源。
- 远程是简化直线规则（同行/列 2 格 + 中间格阻挡），不是原版完整视线/AOE。
- 无神器、将军技能、飞行/位移、完整关键词；卡池 16 张。
- 无音频、无卡组编辑、无联网、无存档/回放格式。

**实现**

- 中文 UI 依赖系统 CJK 字体；无内置字体。
- PNG 在源码运行时按字节加载；导出 PCK 时需把原始 PNG 加入导出过滤，或改回常规导入资源。
- `BattleCore.fingerprint()` 不含 RNG 状态；扩展随机效果时需补。
- 双方将军同时死亡会保持 `winner=-1`；当前不可达，扩展同时结算时需定义规则。
- 手牌每次内容变化重建 Control；6 张时可忽略，20+ 张应改增量更新。
- 1920×1080 截图是离屏 1.5×，不是运行时窗口分辨率。
- GDScript `inference_on_variant` 在本机配置下当错误处理；新增代码需显式类型。

**资产/法律**

- “Duelyst”名称与 Logo 是 Counterplay Games 商标，不在 CC0 内；本项目使用原创名《格间牌战 / Gridbound》。
- 资产是 CC0 1.0 子集；保留 LICENSE、SOURCE、CREDITS。不要引入非 CC0 素材。
- 没有复制 `open-duelyst/duelyst` 的 CoffeeScript 代码；规则代码为原创实现。

---

## 13. 从零重写清单（不读 GDScript）

按顺序实现，每步都有可验证结果：

1. **数据层**：读取 `data/cards.json`（或 `export/cards.json`）与 `export/asset_manifest.json`；校验 16 卡、双方 20 张、资产路径存在。→ 与 manifest 的 counts 一致。
2. **棋盘状态**：9×5、4 邻接、曼哈顿距离；将军初始 `(4,4)`/`(4,0)`。→ 单元测试邻接/边界。
3. **单位结构**：实现 §4.1 字段；将军 20/2。→ 初始状态快照。
4. **洗牌与开局**：Fisher-Yates（或注入牌序）；双方抽 3；玩家 `start_turn` 再抽 1。→ seed 777 手牌/牌库匹配 §9.3。
5. **回合**：`start_turn` 七步顺序；`end_turn` 切换。→ 法力曲线 1→9；首次双方 1。
6. **校验器**：召唤格、移动格、攻击目标、法术目标。→ 用 §7 的边界用例。
7. **动作**：play/move/attack/cast/replace/end，返回事件字典与死亡快照。→ 事件字段与 §6 一致。
8. **胜负**：将军死亡即结束；结束后拒绝动作。→ 击杀将军测试。
9. **AI**：按 §8 的 phase 与评分；固定遍历顺序与 tie-breaker。→ 同输入同动作序列。
10. **表现**：按 §10 或 [CROSS_ENGINE.md](CROSS_ENGINE.md) 映射；先棋盘/单位/手牌，再 FX/动画。
11. **验收**：跑 [CROSS_ENGINE.md](CROSS_ENGINE.md) 的移植验收清单；至少覆盖 65 项冒烟中的规则部分。

**最小验收状态**（任何引擎都应能产出）：

- 初始：玩家手牌 4、AI 3；玩家将军 `(4,4)` 20/2；AI 将军 `(4,0)` 20/2；
- seed 777 的牌序与 §9.3 一致（或显式注入）；
- 召唤只落在将军/友军相邻空格；费用/手牌正确扣除；
- 近战只能打相邻；远程只能打同行/列 1–2 格且距离 2 中间为空；
- 相邻敌方嘲讽强制目标；疾行召唤当回合可攻击；登场治疗 +2；
- 攻击无反击；将军 0 HP 立即判负；
- 同 seed + 同操作序列状态哈希一致。

---

## 14. 与 Duelyst 原版的关系（公开资料，非本项目实测）

- **灵感来源**：Duelyst（Counterplay Games）的 9×5 棋盘、双将军、手牌/法力、随从走位与攻击的组合。
- **本项目不是重制**：没有使用原版代码、卡表、UI 布局或品牌；规则是面向 vertical slice 的原创简化实现（尤其是远程/嘲讽/无反击/无法术 AOE）。
- **公开资料**：原版完整规则、卡牌与平衡请参考 open-duelyst/duelyst 仓库及其社区 wiki；本文不保证与任何原版版本一致。
- **商标边界**：CC0 只覆盖资产版权，不覆盖商标；本项目不使用 Duelyst 名称/Logo 作为品牌。

---

## 附录 A：动作返回值示例

```json
// 召唤
{"type":"summon","owner":0,"uid":12,"card_id":"f1_silverguardsquire",
 "card_name":"白银侍从","pos":{"x":3,"y":4},"deaths":[]}

// 移动
{"type":"move","owner":1,"uid":7,"from":{"x":4,"y":1},"to":{"x":4,"y":2}}

// 攻击
{"type":"attack","owner":0,"attacker_uid":12,"target_uid":8,
 "attacker_name":"白银侍从","target_name":"雀鹰","damage":2,
 "target_pos":{"x":4,"y":2},"attacker_pos":{"x":4,"y":3},
 "deaths":[{"uid":8,"name":"雀鹰","owner":1,"card_id":"f2_sparrowhawk",
            "x":4,"y":2,"is_general":false,"sprite":"f2_sparrowhawk"}]}

// 法术（伤害）
{"type":"spell","owner":1,"card_id":"f2_phoenixfire","card_name":"凤火",
 "target_uid":12,"target_pos":{"x":3,"y":4},"effect":"damage","amount":3,
 "damage":3,"deaths":[]}
```

> Godot 内部用 `Vector2i` 表示坐标；JSON 化后是 `{"x":...,"y":...}`。其他引擎可直接用 `[x,y]` 或对象，但需在协议层固定一种。

## 附录 B：相关文档

- [技术说明](TECH.md) —— 原实现的结构、图集切帧、UI 渲染、资产管线。
- [跨引擎移植](CROSS_ENGINE.md) —— A 数据 / B 算法 / C 渲染 / D 工具链、四引擎映射、契约与验收。
- [可移植资产](PORTABLE_ASSETS.md) —— 每个 PNG/JSON、图集 schema、锚点/缩放、许可与导出。
- [导出工具](../export/README.md) —— manifest、`slice_atlas.py`、联系表、验收入口。
- [迭代记录](迭代记录.md)、[README](../README.md)、[CREDITS](../CREDITS.md)。
