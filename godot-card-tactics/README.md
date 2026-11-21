# 格间牌战 · Gridbound

> 9×5 棋盘上的卡牌 + 战棋 vertical slice。玩家与 AI 各带一套 20 张牌，召唤随从、走位、卡射程、用法术拆掉对方将军。
>
> 玩法灵感来源 **Duelyst**（Counterplay Games）。本项目不是 Duelyst 的重制或官方产品，不使用其名称/Logo 作为品牌；所有 GDScript 代码与 UI 布局为原创，美术为 CC0 1.0 资产子集（来源与 commit 见 [CREDITS.md](CREDITS.md)）。

![棋盘](docs/shots/01_board.png)

## 快速开始

```bash
# 从仓库根目录运行
godot --path godot-card-tactics

# 或在 Godot 4.6 中打开 godot-card-tactics/project.godot
```

- 引擎：Godot 4.6（GL Compatibility）
- 逻辑分辨率：1280×720（拉伸模式 `canvas_items`，窗口/屏幕自适应）
- 目标设备：Intel HD Graphics 6000 级集显，实测 30 FPS 以上（见下方“验证”）
- 干净 clone 可直接运行：脚本用 `preload` 显式依赖，贴图由 `AssetLoader` 按 PNG 字节创建 `ImageTexture`，不依赖编辑器生成的 `.godot/imported` 缓存。

## 操作

| 操作 | 说明 |
| --- | --- |
| 点击手牌 | 选中卡牌；单位牌显示金色召唤格，法术牌显示蓝色目标圈 |
| 点击高亮格 | 召唤随从 / 把已选单位移动一格 |
| 点击红圈敌人 | 攻击 |
| 点击己方单位 | 选中该单位，查看移动/攻击范围 |
| 悬停手牌 | 卡面放大 |
| 「换一张手牌」 | 每回合 1 次，把选中的手牌洗回牌库底并抽 1 张 |
| 「结束回合」/ 空格 | 结束玩家回合，AI 开始行动 |
| Esc | 取消当前选择 |
| R | 立即重开（随机新 seed） |
| 覆盖层「再来一局」 | 胜负后重开 |

## 玩法规则（vertical slice）

- **棋盘**：9 列 × 5 行。玩家将军固定从 `(4,4)` 开始，AI 将军从 `(4,0)` 开始。
- **将军**：20 HP、2 攻击；可以像普通单位一样移动/攻击；HP 归零即败。
- **回合**：玩家先手。每方在自己回合开始时：
  - 法力上限 +1（首次为 1，上限 9），并回满；
  - 抽 1 张牌（牌库空则不抽；手牌上限 6，满手时抽到的牌被弃置）；
  - 己方所有单位恢复“可移动 1 次 + 可攻击 1 次”。
- **起手**：双方各 3 张；先手在自己第一个回合抽到第 4 张，后手在首个回合抽到第 4 张。
- **牌库**：每套 20 张。玩家套牌为晨光（f1）+ 中立；AI 套牌为风间（f2）+ 中立。
- **召唤**：只能召唤到己方将军或友方随从的上下左右相邻空格。
- **移动**：每个单位每回合可向上下左右移动 1 格（不能斜走、不能穿过/停在其他单位上）。
- **攻击**：每个单位每回合攻击 1 次，无反击。
  - 近战：攻击上下左右相邻的敌人。
  - **远程**：攻击同一行或同一列、距离 1–2 格的敌人；距离 2 时中间格必须为空（视线阻挡）。
- **召唤当回合**：普通随从可以移动，但不能攻击；**疾行**单位可以立即攻击。
- **嘲讽**：如果攻击者相邻存在敌方嘲讽单位，则本回合只能攻击这些嘲讽单位。
- **胜负**：任意一方将军 HP ≤ 0，对局结束；覆盖层显示胜利/败北与 seed，可重开。
- **换牌**：每方每回合 1 次（AI 当前不使用换牌）。

### 关键词

| 关键词 | 规则 |
| --- | --- |
| 远程 | 同行/列 2 格内攻击，中间格阻挡 |
| 嘲讽 | 相邻敌人必须优先攻击它 |
| 疾行 | 召唤当回合即可攻击 |
| 登场治疗 | 召唤时为己方将军恢复指定生命 |

### 卡池（16 张 = 12 随从 + 4 法术）

| 阵营 | 卡牌 | 类型 | 费用 | 攻/血 | 关键词 / 效果 |
| --- | --- | --- | ---: | --- | --- |
| 晨光 | 白银侍从 | 随从 | 2 | 2/2 | — |
| 晨光 | 前阵弓手 | 随从 | 2 | 1/3 | 远程 |
| 晨光 | 日石骑士 | 随从 | 3 | 3/3 | — |
| 晨光 | 风刃指挥官 | 随从 | 4 | 3/4 | 嘲讽 |
| 晨光 | 铁崖守卫 | 随从 | 5 | 3/7 | 嘲讽 |
| 风间 | 猛虎刺客 | 随从 | 3 | 3/3 | 疾行 |
| 风间 | 雀鹰 | 随从 | 2 | 2/1 | 远程 |
| 风间 | 灯笼狐 | 随从 | 3 | 2/3 | — |
| 风间 | 四方法师 | 随从 | 4 | 2/4 | 远程 |
| 风间 | 心之侍 | 随从 | 5 | 4/5 | — |
| 中立 | 疗愈秘术师 | 随从 | 3 | 2/3 | 登场：己方将军 +2 HP |
| 中立 | 骸骨收割者 | 随从 | 4 | 3/4 | — |
| 晨光 | 阳光药水 | 法术 | 1 | — | 友方任意目标恢复 4 HP |
| 晨光 | 破魔箭 | 法术 | 2 | — | 对敌方随从造成 3 伤害 |
| 风间 | 凤火 | 法术 | 3 | — | 对任意敌方目标造成 3 伤害 |
| 风间 | 眼镜蛇击 | 法术 | 2 | — | 友方随从永久 +2 攻击 |

> 数值为 vertical slice 平衡调整，不等同于原版 Duelyst 卡牌数值。

## AI 与复现

- AI 使用与玩家完全相同的 `BattleCore` 规则 API。
- 每个动作由 `BattleAI.next_action()` 推进一步，顺序为：**出牌 → 走位 → 攻击 → 结束回合**。
- 出牌、走位、攻击都使用确定性评分 + 明确的 tie-breaker；牌库洗牌用固定 seed 的 Fisher-Yates。
- 同 seed + 同玩家操作序列 ⇒ 完全相同的 `BattleCore.fingerprint()`（冒烟测试覆盖）。
- 当前 AI 为单层贪心，不会做多回合组合规划，也不会使用“换牌”。

## 项目结构

```
godot-card-tactics/
├─ project.godot
├─ scenes/main.tscn              # 单场景入口（Control 全 UI）
├─ scripts/
│  ├─ main.gd                    # UI、输入、动画、AI 回合播放
│  ├─ battle_core.gd             # 纯规则核心（无节点）
│  ├─ battle_ai.gd               # 确定性 AI
│  ├─ card_db.gd                 # data/cards.json 数据入口
│  ├─ asset_loader.gd            # 原始 PNG 字节 → ImageTexture（免导入缓存）
│  ├─ atlas_anim.gd              # JSON 帧数据 → AtlasTexture 动画
│  ├─ board_view.gd              # 9×5 棋盘绘制/点击/高亮
│  ├─ card_view.gd               # 手牌卡面与悬停放大
│  ├─ unit_view.gd               # 单位精灵/攻血徽章/攻击/移动
│  └─ mana_bar.gd                # 9 颗法力水晶
├─ data/cards.json               # 卡牌、将军、套牌
├─ assets/duelyst_cc0/          # CC0 资产子集 + LICENSE + SOURCE.md
├─ tools/
│  ├─ smoke_card_tactics.gd      # headless 冒烟测试（65 checks）
│  ├─ screenshot_card_tactics.gd # 1920×1080 真实 GPU 截图
│  ├─ demo_card_tactics.gd       # 10 秒演示录制脚本
│  ├─ record_card_tactics.sh     # AVI → MP4/GIF
│  └─ perf_card_tactics.gd       # 真实 GPU FPS 采样
├─ docs/
│  ├─ TECH.md                    # 规则模型/状态机/AI/图集/资产管线
│  ├─ 迭代记录.md
│  ├─ shots/                     # 5 张 1920×1080 截图
│  ├─ card_tactics.mp4           # 10.4s / 1280×720 / 30fps
│  └─ card_tactics.gif           # 10.4s / 800px 宽
├─ README.md
└─ CREDITS.md
```

## 验证

### 1. Headless 启动无错误

```bash
godot --path godot-card-tactics --headless --quit-after 600
```

实测输出只有引擎版本行，无 `ERROR` / `SCRIPT ERROR`。

### 2. 冒烟测试

```bash
godot --path godot-card-tactics --headless -s tools/smoke_card_tactics.gd
```

覆盖：法力曲线、召唤合法性、移动/近战/远程/视线阻挡、嘲讽、疾行、登场治疗、回合交替、抽牌与手牌上限、换牌、AI 完整回合、AI 能完整打完一局、将军死亡判胜、同 seed 复现、数据与资产完整性。

最新结果：

```
checks=65
CARD_TACTICS_SMOKE_OK
```

### 3. 真实 GPU

```bash
# 运行 600 帧，检查 console
godot --path godot-card-tactics --resolution 1280x720 --quit-after 600

# FPS 采样（Intel HD Graphics 6000 / GL Compatibility / 关闭 vsync）
godot --path godot-card-tactics --resolution 1280x720 -s tools/perf_card_tactics.gd
```

本机实测（Intel HD Graphics 6000 / GL Compatibility / 1280×720 / 关闭 vsync）：

| 场景 | 平均 FPS | 最低 FPS | 最高 FPS |
| --- | ---: | ---: | ---: |
| 棋盘待机（11 个单位 + 6 张手牌） | 62.2 | 42 | 77 |
| AI 行动/动画期间 | 55.7 | 40 | 74 |

> 最新一轮采样时系统 load average 约 9–13（同时有其他 worker 在跑）。更早的空闲复测曾达到待机 avg 118 / AI 行动 avg 92；要求是 30 FPS 以上，当前有充足余量。FPS 会受窗口遮挡/系统负载影响。

### 4. 截图与视频

```bash
# 5 张 1920×1080（SubViewport 1.5× 离屏渲染）
godot --path godot-card-tactics -s tools/screenshot_card_tactics.gd

# 10.4 秒 1280×720 / 30fps 演示 → MP4 + GIF
cd godot-card-tactics
./tools/record_card_tactics.sh
```

- [棋盘](docs/shots/01_board.png)
- [手牌悬停 + 法术目标](docs/shots/02_hand.png)
- [近战攻击](docs/shots/03_attack.png)
- [凤火法术](docs/shots/04_spell.png)
- [胜利 / 重开](docs/shots/05_win.png)
- [演示 MP4](docs/card_tactics.mp4) / [演示 GIF](docs/card_tactics.gif)

> 截图使用 `demo_showcase()` 摆出的演示局面（双方各 5 个随从 + 6 张手牌）；手牌中特意放了一张风间法术以同时展示两阵营卡框，正常玩家套牌仍为晨光 + 中立。

## 资产与许可

- 美术：`assets/duelyst_cc0/`，来自 [t73liu/open-duelyst-assets](https://github.com/t73liu/open-duelyst-assets) 的 CC0 1.0 子集，commit `9fd0a16b611be8c9b991806ec5a6f602aa981823`。
- 许可全文：`assets/duelyst_cc0/LICENSE`；来源、文件清单与抽取方式：`assets/duelyst_cc0/SOURCE.md`。
- 原始游戏资产由 Counterplay Games 以 CC0 1.0 公开；**商标与品牌不在 CC0 范围内**，本项目不使用 Duelyst 名称/Logo。
- 代码与 UI：本项目原创 GDScript / 布局 / 配色，未复制 open-duelyst 的 CoffeeScript 代码。
- 中文显示依赖系统 CJK 字体（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC / Microsoft YaHei 等），不随项目分发。

## 已知限制

- 这是 vertical slice，不是完整 Duelyst：无神器、无将军技能、无飞行/位移等完整关键词体系，卡池仅 16 张。
- 远程按需求简化为“同行/列 2 格 + 中间格阻挡”，没有实现原版的全部视线/AOE 细节。
- AI 为确定性单层贪心，能完整打一局但不会做长线组合规划。
- 无音频；无卡组编辑器；无联网。
- 贴图为源码运行时按 PNG 字节加载；若要导出 PCK，需把原始 PNG 加入导出过滤，或改回 Godot 导入资源加载。
- 系统缺少 CJK 字体时，中文 UI 可能显示为方框。
- 玩法/数值为可玩性优先的调整，不代表原版平衡。
