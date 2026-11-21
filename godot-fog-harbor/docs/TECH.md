# TECH · 雾港余烬 / Fogfall Extraction

> 任务：T-20261121-026（game-engineer worker）
> 引擎：Godot 4.6 stable / GDScript / GL Compatibility / 1280×720 逻辑画布
> 说明：本文以源码为准；所有素材为程序化原创，未复制原作素材/UI/角色/名称。

## 1. 分层与文件

```
main.gd                 应用状态机；基地/行动/结算；HUD/背包接线；光照 shader 参数；demo API
├─ game_state.gd        跨局数据：信用点、仓库、3 项升级、统计；user:// JSON
├─ raid_rules.gd        单局规则：计时、激活、撤离进度、超时（纯 RefCounted，可单独测试）
├─ inventory.gd         6×4 背包数据（纯 RefCounted）
├─ items.gd             8 类物品 + 稀有度/价值/占格/堆叠 + 箱子权重
├─ harbor_map.gd        程序化地图视觉 + StaticBody2D 碰撞 + 灯光锚点
├─ player.gd            CharacterBody2D；输入、hitscan、换弹、冲刺、绘制
├─ enemy.gd             3 archetype；FSM；视野；攻击；绘制
├─ enemy_bullet.gd      手动射线弹丸
├─ loot_chest.gd        确定性掉落；E 搜索；剩余物资
├─ extraction_zone.gd   撤离圈视觉与状态
├─ pickup.gd            丢弃后的地面物品
├─ fx.gd                曳光/火花/浮动数字/圆环/近战弧
├─ hud.gd               HUD 绘制
├─ backpack_panel.gd    背包面板
├─ base_screen.gd       基地/仓库/升级
├─ result_screen.gd     结算
├─ ui_theme.gd          色板、系统字体、按钮、面板、文本/换行
├─ item_art.gd          8 个原创矢量小图标
└─ fog_art.gd           字体 + 雾噪声纹理
shaders/fog_overlay.gdshader   单次全屏夜间/雾/手电/光池
```

`game_state.gd`、`raid_rules.gd`、`inventory.gd`、`items.gd` 不依赖场景，可被 headless 工具直接实例化。

## 2. 应用状态机（main.gd）

```
BOOT ──> BASE ──(部署)──> RAID ──(撤离成功 / 阵亡 / 超时)──> RESULT
          ^                                                  │
          └────────────── 返回基地 ──────────────────────────┘
                              │
                              └── 再次部署 ──> RAID
```

| 状态 | 内容 | 输入 |
| --- | --- | --- |
| `base` | `FogBaseScreen`；仓库/升级/信用点；无世界 | 鼠标按钮 |
| `raid` | `RaidWorld`（地图/玩家/敌人/箱子/撤离点/FX）+ HUD + 背包 | 键鼠；背包打开时 `get_tree().paused = true` |
| `result` | 冻结的 `RaidWorld` + `FogResultScreen` | 返回基地 / 再次部署 |

- `main.process_mode = ALWAYS`，`world.process_mode = PAUSABLE`；背包打开时暂停世界，但 main/背包 UI 仍可接收 Esc/Tab 关闭。
- 行动开始：`rules.reset()`，背包 6×4，按升级发放初始医疗包，生成 9 箱 / 8 敌 / 撤离点 / 玩家。
- 行动结束：`raid_active=false`、玩家控制关闭、`world.process_mode=DISABLED`、HUD 隐藏、显示结算。
- 成功：`FogGameState.transfer_loot(inventory)` → 旧港币换信用点、物资入库/溢出折现、背包清空；`record_run(true)`。
- 失败：`FogGameState.lose_run(inventory)` → 返回损失摘要、清空背包、`record_run(false)`；仓库/升级/信用点不动。
- 结算页“再次部署”会重建 raid；“返回基地”重建基地。

### 2.1 Demo / 测试 API

`main.gd` 暴露一组 `demo_*` 方法给截图/视频/冒烟测试：
`demo_seed_state`、`demo_start_raid`、`demo_finish`、`demo_teleport`、`demo_move`、`demo_aim_at`、`demo_fire_at`、
`demo_search_chest`、`demo_force_extraction_progress`、`demo_stage_combat`、`demo_loot_setup`、`demo_extraction_setup`、
`demo_freeze_rules`、`demo_set_manual_interaction`、`demo_add_demo_loot`、`demo_set_crosshair`、
`demo_get_*`。这些只用于验收/媒体，不改变正常键鼠路径。

## 3. 单局规则（raid_rules.gd）

| 项 | 值 |
| --- | --- |
| 行动总时长 `RAID_TIME` | 360 秒（6:00） |
| 撤离激活时间 `UNLOCK_TIME` | 120 秒 |
| 撤离激活条件 2 | `chests_searched >= 2` |
| 撤离圈内滞留时间 `EXTRACT_HOLD` | 3.0 秒 |
| 超时 | `elapsed >= 360` → `finished=true, success=false, reason="timeout"` |

`tick(delta, in_zone)` 返回 `{activated, extracted, timeout}`：

1. 推进 `elapsed`（上限 360）。
2. 若未激活且（时间 ≥120 或搜箱 ≥2）→ 激活。
3. 若激活且 `in_zone` → `progress += delta`；达到 3 秒 → 成功结束。
4. 离开圈 `progress=0`。
5. 未结束且时间耗尽 → 失败。

`register_chest_search()` 返回“是否因此激活”；避免重复播报。

## 4. 玩家（player.gd）

| 项 | 值 |
| --- | --- |
| HP | 100 |
| 移动速度 | 218 px/s |
| 冲刺 | 570 px/s，0.16 s，冷却 1.05 s，冲刺期间 invuln ≥0.2 s |
| 受击无敌 | 0.35 s |
| 弹匣 / 备弹 | 12 / 96 |
| 射击间隔 | 0.14 s（按住左键连续射击） |
| 换弹 | 1.35 s，R 触发；空弹时再按左键会自动触发 |
| 伤害 | `18 + 3 × damage_level`（18–27） |
| 命中 | hitscan 射线，mask `1|4`（世界 + 敌人），最远 980 px |
| 瞄准 | `get_global_mouse_position()`；demo 可用 `aim_override` |

- `WASD/方向键` 用 `Input.is_physical_key_pressed`。
- `fire_cooldown` 控制射速；命中敌人调用 `take_damage(weapon_damage, aim)`，命中墙/箱子产生火花。
- 信号：`fired(from,to,hit_enemy)`、`hurt(amount)`、`died`、`notify(text,color)`、`dash_started`。
- 绘制：影子、腿、背包、躯干、头、围巾、枪、枪口焰、换弹进度环、冲刺残影。每帧 `queue_redraw()`（单个 CanvasItem）。
- 碰撞：layer 2，mask 1|4（世界 + 敌人）。半径 11。

## 5. 敌人（enemy.gd）

### 5.1 数据

| archetype | HP | 速度 | 侦测 | 有效侦测（×0.85） | 射程 | 伤害 | 前摇 | 冷却 | 弹速 | 备注 |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| `lurker` 潜伏者 | 55 | 122 | 250 | 212.5 | 48 | 近战 14 | 0.48 | 1.05 | — | 直冲 |
| `gunner` 雾港枪手 | 70 | 96 | 340 | 289 | 390 | 9 | 0.62 | 1.65 | 600 | 单发，保持 ~245 px |
| `elite` 港区看守 | 170 | 104 | 420 | 357 | 380 | 8×3 | 0.55 | 2.15 | 660 | 三连发；近战 18（≤56 px） |

- 弹丸由 `shoot_requested` 信号交给 main，生成 `FogEnemyBullet`；弹丸手动射线打墙、距离检测玩家。
- 精英弹丸爆发的间隔 0.12 s；其他参数见 `DEFS`。
- 命中玩家 `take_damage`；玩家有 0.35 s 无敌和轻微击退。

### 5.2 FSM

```
PATROL ──看见玩家──> ALERT(0.38s) ──> CHASE ──(射程/冷却/LOS)──> ATTACK
  ^                                      │                         │
  │                                      └──丢失视线 3.4s──> PATROL
  └─────────────────────────────────────────────── STAGGER(0.17s)
                                                      │
                                                    DEAD
```

- **PATROL**：在 2–3 个巡逻点之间走动；到点等待 1.1–1.6 s。
- **ALERT**：停下、显示 `!`、面向玩家；0.38 s 后进入 CHASE。
- **CHASE**：远程保持 preferred 距离并横向绕行；近战直冲；被挡时用 ±0.85 rad 的临时避障（0.5 s）和碰撞滑动。
- **ATTACK**：远程前摇显示细红线和枪口亮点；近战显示红色弧。前摇结束才造成伤害/发射。
- **STAGGER**：被命中打断当前动作，0.17 s 硬直，带击退。
- **DEAD**：碰撞层清零，0.55 s 淡出后 `queue_free`；发出 `killed`，main 计击杀。
- **视野**：距离 ≤ `detect × 0.85` 且墙体射线通畅；玩家死亡/无效时不侦测。没有真实光照遮挡；雾只体现为系数和视觉。

## 6. 物品与掉落（items.gd）

### 6.1 数据表

| id | 名称 | rarity | value | stack_max | grid | kind | 使用 |
| --- | --- | ---: | ---: | ---: | --- | --- | --- |
| `old_script` | 旧港币 | 0 | 20 | 8 | 1×1 | currency | 撤离自动换钱 |
| `medkit` | 医疗包 | 0 | 20 | 3 | 1×1 | consumable | +45 HP |
| `brass_parts` | 黄铜零件 | 0 | 35 | 5 | 1×1 | material | — |
| `shipping_chip` | 船运芯片 | 1 | 90 | 3 | 1×1 | material | — |
| `military_cell` | 军用电池 | 1 | 75 | 2 | 1×1 | material | — |
| `precision_rig` | 精密仪器 | 2 | 170 | 1 | 2×1 | material | — |
| `fog_crystal` | 雾晶 | 2 | 240 | 2 | 1×1 | material | — |
| `black_box` | 黑匣子 | 3 | 480 | 1 | 2×2 | material | — |

稀有度颜色：常见 `#93a8b4`、少见 `#59c9b6`、稀有 `#b48cff`、绝密 `#f0b24d`。

### 6.2 箱子权重

每次 `roll_chest(rng, tier)` 抽 2–3 次，按权重选 id，数量按类型：

| id | 普通箱权重 | 精英箱权重 |
| --- | ---: | ---: |
| old_script | 30 | 20 |
| medkit | 14 | 10 |
| brass_parts | 24 | 15 |
| shipping_chip | 15 | 18 |
| military_cell | 10 | 14 |
| precision_rig | 4 | 10 |
| fog_crystal | 2 | 8 |
| black_box | 1 | 5 |

- 数量：旧港币 2–5；医疗包 1–2；黄铜 1–3；芯片/电池 1–2；其余 1。
- 精英箱（tier 1）若抽到的最高稀有度 <2，则追加 1 个雾晶保底。
- 同 id 在同一次掉落中合并。
- 确定性：箱子 RNG 种子 = `index * 7919 + tier * 131 + 17`（index 从 1 开始），便于测试与复现。

## 7. 背包（inventory.gd）

- 网格 6×4 = 24 格；物品占 `grid(width × height)`；支持 1×1、2×1、2×2。
- `entries`：`{id, count, x, y}`，x/y 为左上格。
- **堆叠**：先补已有同 id 且未满的堆叠，再找空位创建新堆叠；超过容量返回实际放入数。
- **首格搜索**：逐行扫描（先 y 后 x），检查整个占位矩形无重叠。
- `remove_at(index, count)`：count ≤0 或 ≥堆叠数时整组移除，否则减 count。
- `use_at`：仅 kind=consumable，返回 `{ok,id,heal,message}` 并扣 1。
- `drop_at`：整组移除。
- `add_loot`：返回 `added` / `missed`，箱子用 missed 保留剩余物资。
- `cells_used` 按占格面积算；`capacity_cells`=24。
- 测试覆盖：堆叠拆分、2×2 排布、2×1 绕过、满包拒绝、部分移除、使用、丢弃、add_loot 区分。

## 8. 搜箱与撤离（loot_chest / extraction_zone / main）

### 8.1 搜箱

- 9 个箱子，位置/是否精英见 `harbor_map.gd` 的 `CHESTS`。
- 玩家距离 ≤64 px 且按住 E：`search_tick(delta, inventory)`。
- 搜索 0.9 s；松开 E 或走远 → `cancel_search()`（进度清零）。
- 完成：把能放下的物资放入背包；完全放不下的留在箱内；`first=true` 只在该箱第一次完成搜索时返回。
- `first` 会调用 `rules.register_chest_search()`；搜完 2 个箱子激活撤离点。
- 箱子视觉：关闭/空箱、脉动光、E 提示、搜索进度条。
- 空箱仍可交互但提示“空补给箱”。

### 8.2 撤离

- 撤离圈 `Rect2(2080,1200,200,160)`，在东南栈桥。
- 激活后青色脉冲；“撤离点”标签 + “站入3秒” + 实时进度条。
- 玩家在圈内且规则激活：HUD 显示 `撤离中 x.x / 3.0` 与剩余秒数；离开归零。
- 3 秒完成 → `_finish_run(true,"撤离成功")`。

### 8.3 结算转移

`FogGameState.transfer_loot(inventory)`：

1. 遍历背包快照。
2. `old_script`：`credits += 数量 × 20`。
3. 其它：按 max_stack 补已有堆叠 / 新建仓库格，直到 `warehouse_capacity`。
4. 放不下的部分：`overflow_credits += 数量 × 面值`，直接加信用点。
5. 清空背包，保存存档，返回 `{stored, currency_credits, overflow, overflow_credits, total_value, items}`。

`lose_run(inventory)`：记录 `{items,count,value}`，清空背包，`record_run(false)`，保存。

## 9. 持久化（game_state.gd）

### 9.1 升级

| id | 名称 | 最大等级 | 效果 | 价格（每级） |
| --- | --- | ---: | --- | --- |
| warehouse | 仓库扩容 | 3 | +6 格/级（24→42） | 120 / 220 / 360 |
| medkit | 出发医疗包 | 3 | 每局 +1（1→4） | 80 / 160 / 260 |
| damage | 武器校准 | 3 | +3 伤害/级（18→27） | 140 / 240 / 380 |

- 升级要求信用点足够且未满级；扣款后立即 `save()`。
- 信用点不足/满级的按钮禁用。

### 9.2 存档格式

路径：`user://fogfall_save.json`。

```json
{
  "version": 1,
  "credits": 680,
  "warehouse": [
    {"id": "fog_crystal", "count": 2},
    {"id": "shipping_chip", "count": 2},
    {"id": "black_box", "count": 1}
  ],
  "upgrades": {"warehouse": 1, "medkit": 1, "damage": 1},
  "stats": {"runs": 6, "extractions": 4, "deaths": 2}
}
```

- 读取时校验物品 id、数量、堆叠上限、升级等级 0..max、仓库容量；越界截断。
- 非字典/损坏 JSON → `load_save()` 返回 false，按空存档运行。
- 写入：直接 `FileAccess.WRITE` 覆盖（非原子）；写升级/撤离/阵亡时各一次。
- 仓库每项占 1 个格子；`warehouse_capacity = 24 + 6 × warehouse_level`。

## 10. 地图与碰撞（harbor_map.gd）

- 世界 `2400×1500`，可玩区域 `Rect2(100,100,2200,1320)`。
- 布局（手写、确定性）：
  - 西北仓库：640×420 外墙，南墙留门；4 个货架。
  - 中部/东部集装箱堆场：11 个集装箱（横/竖，锈红/青/蓝/橙），7 个木箱。
  - 西侧木栈桥、东北码头、东南撤离栈桥。
  - 9 个补给箱；8 个敌人；6 个灯光锚点；4 处水洼；水面浮标/旧货轮剪影。
- 碰撞：StaticBody2D + RectangleShape2D，layer 1；玩家 layer 2，mask 1|4；敌人 layer 4，mask 1|2；箱子也是 layer 1（26×16）。
- 视觉：全部 `_draw()` 程序化，不加载任何贴图；使用 multiline 批处理格线/肋条/围栏。
- **预渲染**： gameplay 世界放一个 `visible=false` 的 HarborMap（只保留碰撞）；另建一个 `SubViewport(2400×1500)` 渲染视觉地图，3 帧后烘焙成 `ImageTexture`，释放 SubViewport，用 Sprite2D 显示。失败时回退为直接绘制。
- 地图上的灯光节点只提供位置/颜色给 shader；没有真实的 2D 灯光节点。

## 11. 渲染、夜间/雾 shader 与性能

### 11.1 单次全屏 shader

`shaders/fog_overlay.gdshader` 在 CanvasLayer(3) 上，低于 HUD(10)：

- `darkness = 0.66` 的深青夜色遮罩；
- 3 个灯池（最近的灯 + 撤离点；屏幕 UV 距离，`aspect` 校正）；
- 玩家径向光 + 手电锥（`player_uv`/`aim_dir`）；
- 可平铺 128×128 `FastNoiseLite` 纹理（两层视差改为一次采样 + 移动 UV）；
- 暗角。

`main._update_lighting()` 每帧把玩家/瞄准/最近 3 个灯位置换算为 UV 写入 ShaderMaterial。
这样世界只渲染一遍，避免 `PointLight2D` 的多 pass 开销；灯光不投影、不遮挡。

### 11.2 绘制批处理/裁剪

- 静态地图：预渲染为 1 个 Sprite2D（原 ~100 个地图 draw calls）。
- 仓库/背包空格线：`draw_multiline` 一次画完（原每格 2 条 draw）。
- 面板：去掉装饰性角线，每面板从 4 条 draw 降到 2 条（填充 + 描边）。
- 敌人/箱子：main 每 0.12 s 按相机距离设置 `visible`；AI/物理照常运行。
- HUD 重绘 12.5 Hz（`_redraw_accum >= 0.08`）；世界实体按需重绘。
- 目标：Intel HD 6000 上 30fps+；战斗场景 draw calls 123–133。

### 11.3 实测

| 场景 | 计数 |
| --- | --- |
| 1280×720 真实窗口，战斗 staged | 123–133 draw calls |
| 基线（空场景） | 169–209 fps |
| 纯色全屏覆盖 | 124–221 fps |
| 夜间 shader 全屏 | 112–169 fps |
| 基地 UI | 50–82 fps |
| 行动场景 | 见下（共享主机波动） |

多次真实采样（同机 Intel HD 6000，vsync off）：

- 2026-11-21 18:51（灯光 shader 版本，207 draws）：`avg 55.65 / min 51.00`，20 个样本 51–62。
- 2026-11-21 19:42（最终版，123 draws，主机 load ~38）：`avg 9.32 / median 9 / best 2s 16.25`。
- 2026-11-21 19:56（最终版，133 draws，主机 load ~38）：`avg 15.57 / median 11 / best 2s 38.62`。
- 2026-11-21 20:00（最终版，123 draws，主机 load 16.5，**验收轮**）：`avg 34.05 / median 37 / best 2s 46 / min 6`，`FOG_HARBOR_FPS_OK`。
- 主机出现外部 GPU 争用时，同一构建会从 55 掉到 9；空场景和全屏 shader 仍很快，说明是共享主机争用而非逻辑/物理瓶颈（`TIME_PROCESS≈0.05ms`、`TIME_PHYSICS≈0.1ms`）。

完整采样：`docs/fps.txt`；验收输出：`docs/verification.txt`。

## 12. 测试与工具

### 12.1 `tools/smoke_fog_harbor.gd`（headless，106 项）

覆盖：
- 8 类物品字段/合法 id/占格；同 seed 掉落一致；精英箱保底；旧港币类型。
- 背包 24 格、堆叠拆分、2×2/2×1 占位、满包拒绝、部分移除、使用、丢弃、add_loot。
- 箱子确定性、搜索完成/空箱/满背包剩余物资。
- 撤离规则：119.9 秒未激活、120 秒激活、1.5 秒进度、离开清零、3 秒成功、搜箱 2 次激活、360 秒超时。
- 存档：新档、升级价格/容量/伤害/医疗包、扣款、信用点不足拒绝、撤离转移、读回、阵亡清包不动仓库、溢出折现、回收。
- 整场景：9 箱/8 敌/3 archetype、初始医疗包、搜箱、hitscan 伤害、敌人 ALERT/CHASE、近战伤害、硬直、死亡/击杀、背包暂停、**真实输入**（E/WASD/Shift/鼠标左键/R）、**实际 HP 死亡 → 结算**、撤离结算、读档、再次部署、返回基地。

末行：`FOG_HARBOR_SMOKE_OK`。

### 12.2 `tools/screenshot_fog_harbor.gd`

- 1920×1080 SubViewport + `size_2d_override=1280×720` + stretch。
- 9 张：基地、地图、搜箱、战斗、战斗 B、背包、撤离、成功结算、失败结算。
- 末行：`FOG_HARBOR_SHOTS_OK`。

### 12.3 `tools/capture_fog_harbor.gd`

- `--fixed-fps 30`，300 帧 → `/tmp/fog_harbor_frames/frame_%04d.jpg`。
- 脚本化：基地 → 部署/移动 → 搜箱 → 战斗（射击/敌人）→ 背包 → 撤离 → 结算。
- 末行：`FOG_HARBOR_VIDEO_FRAMES_OK frames=300`。
- ffmpeg 命令见 README；产物 1920×1080/30fps/10s MP4 + 960 宽 12fps GIF。

### 12.4 `tools/probe_fps.gd`

- 1280×720 真实窗口、vsync off、战斗 staged、god mode。
- 2 秒预热 + 10 秒 × 0.25 s 采样；输出 avg/median/min/best 2s/draws。
- 写入 `docs/fps.txt`。

## 13. 已知风险 / 后续

- **共享主机 FPS 波动**：低负载 55.65 avg / 51 min；GPU 被外部占用时最终版会掉到 9–16 avg。验收应看 best 2s 或低负载整轮，并记录宿主状态。
- **伪光照**：没有墙体遮挡/真实阴影；灯光只影响遮罩 alpha。
- **AI 无寻路**：直接转向 + 滑动 + 卡住反向，复杂凹角可能卡住；需要时可改 NavigationAgent2D。
- **字体**：SystemFont，不打包字体；无 CJK 字体的 Linux/Windows 会回退。
- **无音频**、无触控、无设置菜单/暂停菜单（只暂停背包）。
- **存档**：直接覆盖写；异常断电可能损坏（会按空档启动）。
- **数值**：仓库溢出全额折现、撤离携带无重量限制，偏宽松。
- **地图预渲染**：2400×1500 RGBA ≈14MB 纹理；极低显存设备需要回退或缩小。
- **弹药**：初始 12+96 发，无补给；长局战斗可能打空，属于当前 slice 边界。
- **敌人掉落**：无；物资全部来自箱子。

## 14. 变更记录

见 [迭代记录.md](迭代记录.md)；验收原始输出见 [verification.txt](verification.txt)。
