# 《苔关八波》技术说明

> 更新：2026-11-25 · Godot 4.6 stable / GL Compatibility · 1280×720 逻辑画布

## 1. 范围

- 单场地、8 波、5 种敌人（含 Boss）、2 种塔、3 次三选一、失败/重开/分数/本地最高分。
- 不做城建、抽卡、联盟、联网、付费；不做广告式大规模兵潮。
- 美术 100% 程序化（`_draw()`），无外部贴图/模型；字体走系统 CJK。

## 2. 架构

| 文件 | 职责 | 关键点 |
| --- | --- | --- |
| `scripts/main.gd` | 主控/接线/输入/经济/结算 | 固定步长手动 `_tick()`；所有测试钩子以 `demo_*` 暴露 |
| `scripts/game_data.gd` | 纯数据 + 路径查询 | 路径弧长预计算；8 波表；数值表 |
| `scripts/game_state.gd` | 单局状态、分数、存档 | `RefCounted`；JSON 只存最高分等元数据 |
| `scripts/wave_manager.gd` | 波次状态机 + 确定性出怪 | `idle/prep/combat/cleared/victory` |
| `scripts/enemy.gd` | 5 种敌人行为 + 程序化绘制 | 无物理引擎，按距离/模式确定性移动 |
| `scripts/player.gd` | 领主走位/自动索敌/技能/复活 | 死亡不结束本局 |
| `scripts/tower.gd` | 2 种塔、索敌、弹道、升级、出售 | 弩塔即时命中；炮塔延迟弹道 + 溅射 |
| `scripts/wall.gd` | 最后卡口可修墙 | 敌人优先拆墙，墙破后才打主城 |
| `scripts/arena_map.gd` | 静态苔关场景 | 只在悬停/主城受损时重绘 |
| `scripts/hud.gd` | 中文 HUD/面板/结算/命中区 | 15 Hz 重绘；所有点击命中区集中判定 |
| `scripts/art.gd` | 色板/字体/面板/血条/图标 | `SystemFont` 缓存；无外部资源 |
| `scripts/fx.gd` | 伤害数字/金币/箭线/炮击/爆炸 | 单 `CanvasItem` 批量绘制，上限 100 条 |

场景只有 `scenes/main.tscn`（一个挂 `main.gd` 的 `Node2D`）；`World`、`Units`、`UI` 均在 `_ready()` 运行时创建，便于 headless/截图工具复用。

## 3. 模拟模型

- 主循环 `_process(delta)` 只负责 UI 刷新；模拟由 `_tick(clamp(delta, 0.05))` 推进。
- `demo_set_manual_tick(true)` 后，外部可用 `demo_tick(dt)` 以固定步长确定性推进（smoke/截图/录像共用）。
- 暂停条件：结算、三选一面板、建造/塔面板、主菜单。暂停时 `_tick()` 直接返回。
- 坐标：1280×720 逻辑单位；玩家可行走范围 `x∈[48,1232], y∈[116,684]`。

### 3.1 路径

`PATH_POINTS` 16 个点，从右上入口到左下山口；`path_length()` 首次调用时计算累计弧长，`path_point_at(d)` / `path_tangent_at(d)` 做分段线性插值；`distance_to_path(p)` 用于场景装饰避让。

### 3.2 波次状态机

```
prep --(倒计时/按 N)--> combat --(计划出完 & 清场)--> cleared
cleared --(无升级节点)--> prep(下一波)
cleared --(有升级节点)--> 三选一 --(选择)--> prep(下一波)
cleared(第 8 波) --> victory
主城 HP=0 --> 失败结算（run_over）
```

- 波次奖励：`WAVES[i].reward`（20/25/30/35/40/45/50/100）。
- 每波守住后主城 +5 HP（上限 100），并检查 `UPGRADE_MILESTONES`。

## 4. 数据与数值（原创起点）

### 4.1 领主

| 属性 | 值 |
| --- | ---: |
| HP / 移速 | 100 / 178 px/s |
| 自动攻击 | 射程 182，12 伤害，1.2 次/s，精英/Boss 索敌权重 ×0.72 |
| 回旋斩 | 35 伤害，半径 118，冲刺 72，CD 8s（可被构筑缩短到 4s） |
| 死亡 | 4s 后主城前复活，扣 10 金（不足则扣到 0） |

### 4.2 敌人

| 类型 | HP | 速度 | 伤害 | 攻击间隔 | 金币 | 行为/特性 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 叛军民兵 | 30 | 66 | 5 | 1.0s | 2 | 沿路推进；近身仇恨玩家 |
| 疾行斥候 | 18 | 125 | 4 | 0.8s | 2 | 高速低血 |
| 铁盾卫 | 80 | 50 | 8 | 1.2s | 4 | 弩箭伤害 ×0.6；炮塔全额 |
| 破阵精英 | 280 | 56 | 18 | 1.35s | 15 | 优先拆 135 px 内最近的塔 |
| 裂关巨兽 | 1200 | 44 | 28 | 1.6s | 50 | 优先拆塔；HP≤50% 召唤 4 民兵（仅一次） |

敌人 FSM：`path → wall → castle`（推进/拆墙/攻城），`chase → return`（仇恨玩家后回到路径），`tower`（精英/Boss 拆塔）。无物理碰撞；`lane_offset` 给同波敌人横向错位。

### 4.3 塔与墙

| 塔 | 造价 | 升级 | 射程 | 攻速 | 伤害 | 特性 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 弩塔 | 50 | 60 | 205 | 1.5/s | 10 | 单体即时命中；对铁盾卫 ×0.6 |
| 炮塔 | 70 | 80 | 190 | 0.6/s | 25 | 溅射半径 58；克制密集兵潮 |
| 升级 | — | — | +10% | +10% | +25% | 2 级；出售返还总投入 50% |

- 索敌：弩塔选路径进度最靠前（最接近主城）的目标；炮塔选“溅射范围内敌人最多”的簇中心。
- 塔 HP 180/200，精英/Boss 可拆塔；塔毁后基座空出，可在下一准备阶段重建。
- 墙：初始 80/120 HP（开局带旧损，提示玩家可修），修墙 25 金、重建 40 金；墙存在时敌人先拆墙。

### 4.4 构筑与结算

| 节点 | 触发 | 选项 |
| --- | --- | --- |
| 第一道战功 | 第 2 波后 | 塔射程 +20% / 领主攻速 +25% / 击杀金币 +1 |
| 工事抉择 | 第 4 波后 | 主城回复 20 / 炮塔伤害 +25% 且爆炸 +20% / 回旋斩 CD −2s |
| 终局构筑 | 第 6 波后 | 塔攻速 +20% / 领主伤害 +30% / 击杀金币 +1 |

- 分数：`wave_cleared×100 + kills×10 + castle_hp×50 + gold`。
- 评级：S ≥4200，A ≥3200，B ≥2200，C ≥1200，其余 D。
- 存档：`user://wave_defense_save.json`，只写 `best_score/best_grade/best_wave/best_kills/runs`；`demo_use_save_path()` 供测试隔离。

## 5. 确定性

- 出怪计划 `build_spawn_plan(wave, seed)` 用 `RandomNumberGenerator`，种子公式：
  `seed×7919 + wave×104729 + 17`。
- 每组敌人按 `start + interval×i` 生成，带 seed 决定的 `offset∈[-15,15]`；再按 `(time, 组内序)` 稳定排序。
- 模拟无物理/无 `Timer` 节点；帧步长由外部传入，headless smoke 固定 0.05s。
- 同一 seed 的 8 波计划可完全复现（smoke 中有 JSON 对比）。

## 6. 测试钩子（仅工具使用，不影响正常输入）

`main.gd` 末尾提供：
`demo_start_run / demo_set_manual_tick / demo_tick / demo_set_gold / demo_set_player_pos / demo_set_player_hp /
demo_spawn_enemy / demo_clear_enemies / demo_build_tower / demo_upgrade_tower / demo_sell_tower /
demo_damage_wall / demo_repair_wall / demo_damage_castle / demo_set_castle_hp / demo_set_wave /
demo_skip_prep / demo_open_build_menu / demo_open_upgrade / demo_choose_upgrade / demo_finish /
demo_restart / demo_click / demo_cast_skill`。

## 7. 渲染与性能

- 全部几何在 `_draw()` 中绘制；无贴图、无粒子节点。静态场景（`arena_map`）只在悬停/主城比例变化时 `queue_redraw()`。
- `fx.gd` 用单个 `CanvasItem` 批量绘制全部反馈，效果上限 100 条。
- HUD 重绘从 30 Hz 降到 **15 Hz**（`_hud_accum >= 0.066`），数字/倒计时仍可读。
- 敌人移动只改 `Node2D` 变换，**绘制指令按 10 Hz 重建**；受击白闪/前摇/击退期间 20 Hz，朝向翻转立即重建。移动本身仍按 60 Hz 变换，视觉上依旧平滑。
- 塔/领主每帧只重绘自身 CanvasItem；血条只在受伤后 2 秒显示（Boss 常显）。
- 弹道不建节点：弩塔为即时命中 + 0.16s 箭线；炮塔为字典记录延迟 + 命中时溅射。
- 1920×1080 截图：使用 `SubViewport(1920×1080)`，把 1280×720 场景与 CanvasLayer 各放大 1.5 倍渲染；不是先截 720p 再放大。
- 10s 实机片：同法 1280×720 `SubViewport`，30fps 手动 tick 300 帧，PNG 序列 → ffmpeg H.264 / GIF。

### 7.1 压力探针

`tools/probe_perf_wave_defense.gd`：真实窗口渲染，3 座 Lv.2 塔、主城/领主保活、持续补兵至指定数量（默认 70），输出每秒 FPS 与 `RENDER_TOTAL_DRAW_CALLS_IN_FRAME / RENDER_TOTAL_PRIMITIVES_IN_FRAME`。

实测 draw calls / primitives（1280×720，16 敌人 + 3 塔 + 满特效）：

| 指标 | 数值 |
| --- | ---: |
| Draw calls / frame | ~700 |
| Primitives / frame | ~26k |

> 首轮 FPS 测量时测试机同时运行了 2 个其他 Godot 任务 worker（`load average 24` / 4 核）；draw call / primitive 计数不受负载影响，最终 FPS 见 §8.1。层隔离工具：`tools/isolate_wave_defense_layers.gd`。

## 8. 验收记录（2026-11-25）

| 命令 | 结果 |
| --- | --- |
| `godot --headless --path . --quit-after 600` | 退出 0，输出仅有引擎 banner，0 ERROR |
| `godot --headless --path . --script tools/smoke_wave_defense.gd` | `SMOKE SUMMARY: 99 passed, 0 failed`；末行 `WAVE_DEFENSE_SMOKE_OK`；退出码 0 |
| `godot --path . --resolution 1920x1080 --script tools/screenshot_wave_defense.gd` | 7 张 1920×1080；0 报错 |
| `godot --path . --script tools/capture_wave_defense_reel.gd` | 300 帧；0 报错；ffprobe `duration=10.000000` |
| GPU 1200 帧（1280×720，V-Sync） | 准备段 59–60；W1 战斗段 27–54（同机负载）；平均≈52；0 错误 |
| 30s no-VSync（1280×720，单进程） | min 50 / avg 85.8 / max 123 FPS |
| 性能探针 16 敌人 | 见 §8.1（复测） |

### 8.1 性能复测（2026-11-25 12:18）

测试机：Intel HD Graphics 6000 / i7-5650U（4 逻辑核）。复测时同机还有 **2 个其他 Godot 任务 worker**，`load average 4.7–5.3`，wall-clock FPS 会偏低。

| 场景（1280×720，no-VSync） | 每秒 FPS 样本 | min | avg | max |
| --- | --- | ---: | ---: | ---: |
| 16 敌人 + 3×Lv.2 塔 + 满特效（持续补兵 12s） | 22/36/34/37/35/31/32/43/46/39/81 | 22 | **39.6** | 81 |
| 70 敌人合成压力（另一轮，load≈24） | 31/27/18/15/10/10/12/11/11/12/17 | 9 | 15.8 | 31 |

- 16 敌人档：`WAVE_DEFENSE_PERF_OK avg=39.6`，满足 brief 的“平均 ≥30fps”。实际 8 波峰值约 16–19 名敌人（第 8 波 Boss + 10 民兵 + 4 召唤）。
- 70 敌人档是**超出实际关卡内容**的合成压力：未崩溃、逻辑正常，但在被其他 worker 占满 CPU 时平均 15.8fps；不作为验收结论。

层隔离 A/B（同一进程、load≈4.2，16 敌人）：

| 隐藏层 | FPS | draw calls | primitives |
| --- | ---: | ---: | ---: |
| 基线 | 41.7 | 689 | 26.1k |
| 隐藏 HUD | 40.3 | 654 | 25.5k |
| 隐藏 FX | 43.6 | 704 | 26.6k |
| 隐藏静态场景 arena | 47.9 | 353 | 9.4k |
| 隐藏 HUD+FX | 45.6 | 618 | 24.3k |
| 隐藏 HUD+FX+敌人 | 110.4 | 409 | 18.8k |
| 全部隐藏 | 351.8 | 0 | 0 |

结论：**敌人每帧重建绘制命令**是主要 CPU 成本（隐藏后 45.6→110.4）；静态 arena 是 draw call 大头（689→353）。已做的低风险优化：敌人重绘 10Hz（紧急态 20Hz）、HUD 15Hz、FX 上限 100。进一步的优化方向（未做）：敌人 sprite 缓存 / 合并为单 CanvasItem、静态 arena 预烘焙为单贴图。

## 9. 已知限制与风险

1. **无音频**：brief 中音频为可选，本切片未做。
2. **墙初始 80/120**：有意留旧损以提示修墙；如果希望开局满墙，改 `wall.gd reset()` 即可。
3. **同屏 70 敌人的合成压力**超出实际关卡内容（8 波最多约 19 名敌人）；极端压力下 Intel HD 6000 可能低于 30fps，真实波次不受影响。
4. **系统字体**：依赖 macOS/Windows/Linux 的 CJK 字体；无中文字体的最小 Linux 环境会回退，可能缺字。未打包字体以保持仓库零资产依赖。
5. **存档路径**：`user://wave_defense_save.json`；截图/smoke 工具会切换到独立测试路径，不会污染真实最高分。
6. **1920×1080 为 1.5× 画布缩放**：逻辑布局仍以 1280×720 设计，不是重新排版；HUD 在 16:9 下无裁切。
7. **重开即时但无淡入**：按 R/按钮后立即重置，符合 brief 的 <2 秒目标。
