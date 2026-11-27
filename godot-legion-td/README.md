# Legionfall · 军团陨落

一个原创的「塔防 + RTS + 肉鸽」3D 俯视 vertical slice：三线裂隙不断涌出虚空蠕群，你一边框选军团、一边在固定建造点起塔，撑过 6 波，每波结束三选一。

- 引擎：Godot 4.6 stable（`4.6.stable.official.89cea1439`），GL Compatibility
- 设计分辨率：1280×720（`canvas_items` 拉伸）；截图/视频输出 1920×1080
- 主题：原创「余烬荒原 / 三线裂隙 / 灰烬军团」；不使用任何 Warcraft / 《军团塔防》素材、角色、UI、关卡或名称
- 目录：`godot-legion-td/`
- 工作名：Legionfall / 军团陨落（原创）

![总览](docs/shots/01_overview.png)

## 30 秒上手

```bash
# 直接游玩
godot --path godot-legion-td

# 无头逻辑自测（80 项；末行 LEGION_TD_SMOKE_OK）
godot --headless --path godot-legion-td \
  -s tools/smoke_legion_td.gd

# 真实 GPU 1920×1080 截图（9 张，输出 docs/shots/）
godot --path godot-legion-td -s tools/screenshot_legion_td.gd

# 真实 GPU 性能：720p 窗口 / 1080p SubViewport
godot --path godot-legion-td --resolution 1280x720 -s tools/perf_legion_td.gd
LEGION_PERF_1080=1 godot --path godot-legion-td -s tools/perf_legion_td.gd

# 10 秒 1920×1080 帧采集（15 fps，随后用 ffmpeg 编码）
godot --path godot-legion-td -s tools/video_legion_td.gd

# 六波全流程机器人（8 塔 Lv3 + 招募 + 自动三选一）
godot --headless --path godot-legion-td -s tools/probe_legion_run.gd
```

## 核心循环

1. **准备（首波 14s，之后 10s）**：招募军团（Z/X/C），在 8 个固定建造点建塔，设置兵营集结点。
2. **三线防守**：北门 / 西门 / 东门同时来敌；近战、远程、精英与终波熔核巨像走不同石道。
3. **RTS 指挥**：左键单选、拖拽框选、Shift 追加；右键移动或点杀敌人；A + 左键攻击移动；F 全选；S 停止。
4. **波中手忙脚乱**：WAVE 阶段仍可招募、建塔、升级、出售和指挥，不用等下一波。
5. **清波 → 三选一**：每波清空后从 10 个原创强化中随机抽 3 个（可重掷 1 次），只在本局生效。
6. **随机波次修饰**：同一 run seed 固定；精英潮 / 疾行虫群 / 虫群增殖 / 双线进攻 / 嗜血。
7. **胜负**：核心 100 HP 归零失败；守住第 6 波胜利。R 重开，重开换新 seed。

![战斗](docs/shots/02_battle.png)

## 内容

### 军团（3 兵种 + 1 英雄）

| 单位 | 定位 | 生命 / 伤害 | 射程 | 价格 | 人口 |
| --- | --- | --- | ---: | --- | ---: |
| 灰烬卫士 | 近战前排 | 170 / 15 | 1.9 | 55g | 1 |
| 余烬弩手 | 远程单体 | 105 / 13 | 8.2 | 75g | 1 |
| 熔火术士 | 远程溅射 2.6m | 120 / 27 | 7.0 | 110g + 5e | 2 |
| 焰语者 · 凯尔 | 英雄 / Q 范围技 | 540 / 32 | 2.5 | 初始 | 0 |

英雄 Q「熔火震击」：9m 内 72 伤害并减速 50% / 2.5s，20s 冷却；阵亡 24s 后在兵营复活。

### 塔与建造点（8 个固定点）

| 塔 | 定位 | 价格 | 伤害 | 射程 | 特殊 |
| --- | --- | --- | ---: | ---: | --- |
| 棱镜塔 | 单体高频 | 90g + 8e | 24 | 11.5 | 0.75s 间隔 |
| 熔渣炮台 | 范围慢速 | 120g + 14e | 38 | 13.0 | 3.4m 溅射 |
| 暮霜图腾 | 减速控场 | 85g + 18e | 7 | 9.5 | 50% 减速 / 2s |

- Lv1 → Lv3：每级 +50% 伤害、+8% 射程、-5% 间隔；升级花费见 `legion_data.gd`。
- 出售返还总投入 60%；固定点不可移动。
- 建造面板打开时按 1/2/3 可直接建对应塔；否则 1/2/3 呼叫编队。

### 敌人与波次

- 裂爪兽（近战）、酸刺虫（7.6m 远程）、熔核巨像（精英，950 HP）。
- 6 波：7 → 13 → 12 → 20 → 17 → 20 基础数量；终波双巨像 + 三线混编。
- 敌人生命/伤害随波次增长；波次修饰由 `seed + wave` 决定，同 seed 可复现。

### 肉鸽强化（10 选 3，局内等级）

军团训练（单位伤害）、坚韧战团（单位生命，含新兵）、疾行军令（移速）、高地射程（塔射程）、熔渣回收（塔伤害）、岛屿税收（波次金币）、精粹涌动（击杀精粹）、英雄共鸣（Q 冷却）、暮霜附魔（所有塔命中减速）、扩编令（人口 +4）。

![三选一](docs/shots/05_upgrade.png)

## 操作

| 输入 | 功能 |
| --- | --- |
| 鼠标左键 | 单选；拖拽框选；Shift 追加/取消 |
| 鼠标右键 | 选中单位移动；点敌人集火；选中兵营时设集结点 |
| A 然后左键 | 攻击移动：沿途自动索敌交战 |
| S / F | 停止警戒 / 全选存活单位 |
| Z / X / C | 招募卫士 / 弩手 / 术士 |
| Q | 英雄熔火震击 |
| 1/2/3 | 空建造点时建塔；否则呼叫编队 |
| Ctrl+1/2/3 | 记录编队 |
| B | 准备阶段立即开波 |
| Space / Tab | 暂停 / 1× ↔ 2× |
| H / Esc | 帮助 / 取消选择或攻击移动 |
| R | 结算画面重开（新 seed） |
| 滚轮 / 中键拖拽 / 方向键 / 屏幕边缘 | 缩放 / 平移 / 平移 / 边缘滚动 |

## 真实现场截图

| | |
| --- | --- |
| ![建造](docs/shots/04_build_panel.png) | ![技能](docs/shots/03_hero_skill.png) |
| ![帮助](docs/shots/06_help.png) | ![胜利](docs/shots/07_win.png) |
| ![传送门](docs/shots/09_portals.png) | ![失败](docs/shots/08_lose.png) |

## 10 秒演示

- MP4 1920×1080 / 15fps：`docs/legionfall_10s.mp4`
- GIF 960×540 / 12fps：`docs/legionfall_10s.gif`

## 性能（Intel HD Graphics 6000，真实 GPU，vsync off）

| 场景 | 平均 FPS | P95 帧时间 | 最差帧 | Draw calls |
| --- | ---: | ---: | ---: | ---: |
| 1280×720 窗口，8 塔 + 第 4 波 + 初始 4 人小队 | **38.2** | 35.38 ms | 98.09 ms | 714 |
| 1920×1080 SubViewport，同一场景 | **36.8** | 36.73 ms | 40.83 ms | 727 |

- 主机为 Intel HD 6000（OpenGL 4.1），不是高端 GPU；同场景两次测量约 **38–44fps @720p**、**35–37fps @1080p**。平均达到 30fps+，但 P95 约 28fps，存在偶发长帧。
- 截图/视频工具逐帧读回会拉低画面中的 FPS 读数；上表是独立 perf probe，不含截图读回。截图前会预热 1.2s，所以 HUD 显示约 30 FPS。
- 完整结果与复现命令见 `docs/TECH.md`。

## 项目结构

```
godot-legion-td/
  project.godot
  scenes/main.tscn
  scripts/
    legion_game.gd        # 主控：输入、经济、波次、胜负、调试 API
    legion_world.gd       # 程序化地形/石道/传送门/核心/建造点/相机
    legion_actor.gd       # RTS 单位、英雄、敌人共用 FSM
    legion_tower.gd       # 三种塔、索敌、升级、出售
    legion_projectile.gd  # 弩矢/火球/酸液/熔渣弹
    legion_art.gd         # 程序化低模、材质、贴图、特效
    legion_data.gd        # 数值、波次、修饰、强化、文案
    legion_ui.gd          # 1280×720 中文 HUD 自绘
  tools/
    smoke_legion_td.gd
    probe_legion_run.gd
    perf_legion_td.gd
    screenshot_legion_td.gd
    video_legion_td.gd
  docs/
    TECH.md
    迭代记录.md
    shots/*.png
    legionfall_10s.mp4 / .gif
```

## 原创与资产

全部 3D 模型、地形、材质、图标、UI、名称与文案均为本仓库程序化生成 / 新写代码；没有外部图片、GLB、音频或第三方运行时库。运行时只使用系统字体（PingFang SC / Noto Sans CJK 等）并通过 `SystemFont` 引用，不随仓库分发字体文件。参考视频只作为「塔防 + RTS + 每波三选一」抽象机制的研究对象。详见 `CREDITS.md` 与 `docs/TECH.md`。

## 已知限制（MVP）

- 美术是程序化低模 vertical slice，不是最终美术；单位只有程序化四肢摆动，没有骨骼动画。
- 平衡未细调：8 座 Lv3 塔 + 10 单位可 100 核心通关 6 波（见 `probe_legion_run.gd`）。
- 寻路是直线移动 + 圆形分离，没有导航网格/绕障；敌人只沿三条固定石道。
- 招募采用「购买小队」即时出兵；兵营用于设置新兵集结点，不包含训练队列。
- 无音频、无存档、无手柄；相机固定 52° 俯角，不能旋转。
- 所有内容未经独立 QA / 美术总监放行；截图与数值仅代表本次 worker 自测状态。
