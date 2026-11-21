# 技术说明 — 灯下客 · 长安一夜

> Godot 4.6 stable / GL Compatibility / 1280×720（支持 1920×1080）。本文件记录可复现的实现参数与验收口径；“待实测”不写成已实测。

## 1. 总览

| 项 | 值 |
| --- | --- |
| 工程 | `godot-changan-action/` |
| 主场景 | `scenes/main.tscn` → `scripts/main.gd` |
| 渲染 | GL Compatibility；`scaling_3d/scale=0.65`；无实时阴影 / glow / SSAO / SSR |
| 窗口 | 1280×720 默认，`canvas_items` 拉伸；1080p 可用 |
| 角色 | KayKit Adventurers（CC0）4 个 GLB，每个 41 骨 / 76 clip；共享骨架 |
| 场景 | 程序化 90m 夜街 + 24m 鼓楼广场；54 盏 emissive 灯笼；3 盏可点亮街灯 |
| 实光 | 常态 ≤3（月光 + 玩家补光 + 最近街灯）；Boss 熄灯时广场灯串替换街灯；最多 4 |
| 物理 | CharacterBody3D + StaticBody 地面/墙/摊位/牌楼/鼓楼碰撞；命中用距离/扇区查询 |
| 第三方运行时依赖 | 无（glTF 直接 `load()`；字体用系统 CJK） |

## 2. 场景与关卡

### 2.1 布局

```text
Z=90  ┌──────── 鼓楼 / 结算 ────────┐
Z=82  │        广场大鼓（装饰）       │
Z=76  │        Boss 霍三更 (76.5)     │
Z=62  ├──────── 广场入口（24m 宽）───┤
Z=57  │  闻九（鼓）· 灯3 (3.4,52)     │
Z=49  │      [战斗2] 油贩+打手        │
Z=43  │  ── 战斗2触发线 ──            │
Z=42  │  灯2 (-3.4,42)                │
Z=30  │  灯1 (3.4,30)                 │
Z=18  │      [战斗1] 2 泼皮           │
Z=12.6│  阿禾面摊 (-4.75)             │
Z=8   │        牌楼                   │
Z=0   └──────── 出生 / 标题 ─────────┘
       X=-6          街宽 12m        X=+6
```

- 战斗 1 竞技场：X ∈ [-5.5, 5.5]、Z ∈ [11, 27]；战斗 2：Z ∈ [37.5, 54]；Boss：X ∈ [-10.8, 10.8]、Z ∈ [63.5, 87]。
- 无战斗时街道边界 X ∈ [-5.6, 5.6]，Z ∈ [0.2, 62.6]；广场 X ∈ [-11.8, 11.8]，Z ∈ [61, 89]。
- 地面/墙/摊位/牌楼/鼓楼均有 `StaticBody3D` 碰撞；`CharacterBody3D` 与地面碰撞层 1 交互。
- 触发：Z>17.5 兜底开战斗 1；Z>43 开战斗 2（需已清战斗 1）；Z>72 开 Boss（需已清战斗 2）。

### 2.2 程序化构件 / draw call 优化

- 石板路、街墙、檐口、窗、门、柱：**MultiMeshInstance3D** 合批。
- 6 个街边摊位、酒坛/竹筐、火盆、广场灯串、街灯杆件：合批为 MultiMesh（摊位约 7 draw call 替代 60+）。
- 远景屋顶/窗火、30 盏街面吊灯 + 6 盏广场吊灯：MultiMesh。
- 灯具：36 盏吊灯（含广场 6 盏）+ 广场灯串 6 + 牌楼 2 + 面摊 1 + 摊位 6 + 街灯 3 = **54 盏 emissive 灯笼**。
- 灯笼 halo 使用小尺寸（0.42m）soft billboard；关闭大尺寸 halo 可再提高约 15–20 fps，但会牺牲夜景氛围，故保留缩小版。
- 天空：`BG_COLOR` 平涂夜空 + 140 个星点 MultiMesh + 月亮盘；相较 ProceduralSky 约省 5–7 fps。
- 装饰摊位 `visibility_range_end=44m`，远处自然剔除。

### 2.3 光照预算

| 光源 | 常态 | Boss 熄灯 |
| --- | --- | --- |
| 月光 DirectionalLight | 1.55，无阴影 | 0.46–0.62（随灯数） |
| 玩家补光 Omni（y+3.0, z−1.3, range 11） | 2.2，无高光 | 同 |
| 最近一盏已点亮街灯 Omni（range 12） | 仅玩家 18m 内启用 | 关闭 |
| 广场灯串 Omni（range 20） | 0 | 0.9–1.4（随已点亮街灯数） |
| 环境色 ambient | 0.98 | 0.48–0.64 |

- 街灯 emissive 本体始终可见；实光只点亮最近一盏，保证任意时刻实光 ≤4。
- 熄灯黑暗时长：`20 − 5 × 已点亮街灯数`；3 灯 = 5s，0 灯 = 20s。画面上保留月光底 + 广场灯串，避免“全黑不可读”。
- 灯笼/命中/火油均为 emissive/additive，不新增实光。

## 3. 玩家状态机（`scripts/player.gd`）

### 3.1 状态

`idle / move / sprint / attack / roll / hit / knockdown / getup / victory / dead`。
另有 `frozen`（命中停顿）与 `controls_enabled`（对话/暂停/演出）两个正交开关。

| 状态 | 进入 | 退出 |
| --- | --- | --- |
| idle/move/sprint | 无输入 / WASD / Shift | 攻击/翻滚/受击 |
| attack | 左键/右键/Q | 收招、连段 queue、被击、翻滚取消收招 |
| roll | Space（或攻击判定后取消） | 0.45s 后 idle；冷却 0.20s |
| hit | 受击（非击倒） | 0.38s 后 idle |
| knockdown | 击倒 | 1.0s 倒地 + 0.18s Lie_Idle → getup |
| getup | 起身 | 0.8s 后 idle；前 0.5s 无敌 |
| victory | Boss 击败 | 保持到选择/结算 |
| dead | HP=0 | 失败面板 → 重试本场 |

### 3.2 动作参数（60fps 设计值）

| 动作 | 伤害 | 起手/判定/收招 | hitstop | 击退 | 气 | 备注 |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| 刺拳 A/B | 6 | 0.14s 判定 / 0.42–0.44s 总 | 2f | 0.15 | +6 | 可连；收招可被下一击取消 |
| 踢击 | 14 | 0.28s / 0.72s | 4f | 0.6 | +10 | 不可取消 |
| 3 连终结 | 20 | 0.32s / 0.80s | 6f | 1.0 | +14 | 击倒杂兵；对 Boss 造成 0.8s 破绽 |
| 灯破 | 30 | 0.40s / 0.78s | 8f | 0.9 | 清空 | 半径 3m、360°、击倒；无 i-frames |
| 翻滚 | — | 0.45s / 3.2m | — | — | — | i-frames 0.08–0.30s |
| 起身 | — | 0.8s | — | — | — | 前 0.5s 无敌 |

- 移动 4.2 m/s，冲刺 6.0 m/s；加速度 28 / 减速 26。
- 输入缓冲：攻击收招后 0.15s 内点击/翻滚可排队。
- 攻击自动朝向：锁定目标优先；否则 3m / 前方约 70° 内最近敌人。
- HP 100；气 0–100，命中回复，无自动回复；灯破是唯一消耗。

### 3.3 打击感分层

- **停顿**：`main.apply_hitstop()` 冻结玩家/敌人 `frozen=true`、`anim.speed_scale=0`；相机/UI/计时继续。轻 0.034s、踢 0.067s、终结 0.10s、灯破 0.134s。
- **震屏**：`trauma` 0–1，按 `trauma²` 叠加 sin 位移 + roll，1.5/s 衰减；命中 0.08/0.15/0.22/0.28。
- **命中闪**：敌人共享 `StandardMaterial3D` overlay，0.09s；起身/受击动画。
- **VFX**：共享 mesh/material，命中球/地面环用 `GeometryInstance3D.transparency` 淡出；火花 4 个对象池轮换；伤害数字 6 个 Label3D 对象池（不逐次创建字体/节点）。
- **数字**：白=普通、金=终结/灯破、朱砂=受伤；世界空间、billboard、上浮 0.72s。

## 4. 敌人 AI（`scripts/enemy.gd`）

### 4.1 数值

| 敌型 | HP | 伤害 | 速度 | poise | 攻击 |
| --- | ---: | ---: | ---: | ---: | --- |
| 泼皮 thug | 40 | 8×2 | 3.0 | 1 | 2 连挥（0.35s 起手） |
| 油贩 oil | 30 | 6 / 火 2×0.5s | 3.6 | 1 | 掷油瓶（0.55s 预警，0.8s 落地，2.5s 火区）；短刺 |
| 打手 brute | 90 | 15 砸地 / 12 冲撞 | 2.4 | 3 | 砸地（0.65s，1.95m，击倒）；冲撞（线形 4.2m） |
| 霍三更 boss | 180 | 10/10/14 / 12 / 8+火 / 18 | 3.4 | 5 | 铁尺三连、扫堂、撒油、二阶段火油冲锋 |

### 4.2 状态与令牌

`idle → alert(0.62s) → approach / circle → attack → recover → approach`；受击：flinch 0.2 / stagger 0.5 / knockdown 1.0 + getup 0.8 / dead。
- 攻击令牌：同屏最多 1 名杂兵处于攻击态；其余在 3.4–4.9m 环绕。Boss 单挑，不排队。
- 读法：地面圆/线预警（≥0.35s）；泼皮刺拳可打断；打手轻击不硬直、重击/终结可硬直；Boss 轻击不硬直，终结踢 0.8s 破绽，灯破每阶段 1 次击倒。
- 油贩/打手在远距会主动进入投掷/冲撞分支；贴脸则短刺/砸地。
- 火区：0.5s tick，站圈内 2 伤害/0.5s；Boss 冲锋沿途留下火痕。

### 4.3 Boss 两阶段

- HP ≤90（50%）→ phase 2：触发一次性 **熄灯**，黑暗时长 `20−5×灯数`；Boss 眼睛/铁尺/余烬粒子常亮，telegraph 仍可读。
- P2 三连加速（总时长 ×0.82），每第 4 次攻击使用火油冲锋（0.8s 线形预警，18 伤害，击倒）。
- 胜利：Boss 倒地 → 玩家 Victory → 选择面板（留手/了结）→ 结算。

## 5. 相机 / 锁定

- 第三人称 SpringArm3D：距离 4.2m（Boss 3.8m），目标高度 1.62m，FOV 60（Boss 55），碰撞 mask=1，弹簧球半径 0.24、margin 0.18。
- 鼠标灵敏度 0.0034 rad/px（水平）、0.0026（垂直）；俯仰 −0.82…0.16 rad。相机横向偏移 +0.34（过肩）。
- 锁定：Tab；8m、前方 120° 内最近敌人；目标死亡/超过 10m 自动解除；HUD 菱形 + 名字。
- 锁定但无移动输入时，相机 yaw 缓慢回正到“玩家-目标”后方。
- 震屏叠加在相机 rig 位移 + 局部 roll； cinematic 相机忽略震屏。

## 6. 剧情 / 任务 / HUD

- `story_stage`：`meet_ahe → fight1 → light_street → fight2 → find_wenjiu → boss_ready → boss → ending → results`。
- 3 个 beat：B1 阿禾对话+战斗 1；B2 Z>40 + 战斗 2；B3 广场 Boss。
- 目标条常驻；3D 任务环指向下一位 NPC / 下一盏未点亮街灯。
- 对话：2–4 句、底部面板、空格/E 继续、Esc 跳过、0.18s 输入保护；对话期间敌人 inactive。
- 选择：`1 留手 / 2 了结`；两条原创结尾文本；结算统计用时/最高连击/点灯/受击/选择；R 再走一遍。
- HUD 自绘，系统 CJK 字体（PingFang SC / Hiragino / Noto Sans CJK / 微软雅黑）；无外部 UI 素材。
- 失败：“灯灭了” → R 重试本场、Esc 回标题；重试满血，Boss 重试跳过入场演出。

## 7. 资产 / 角色

- **玩家沈灯 / 阿禾 / 闻九 / 霍三更** 与敌人泼皮、油贩、打手，网格来自 **KayKit Adventurers（CC0 1.0）**：
  - `Rogue.glb`（沈灯）
  - `Rogue_Hooded.glb`（泼皮 / 闻九）
  - `Mage.glb`（油贩 / 阿禾）
  - `Knight.glb`（打手 / 霍三更）
- 重着色：`shaders/character_tint.gdshader`（RGB→HSV→目标色相→HSV，保留贴图明暗与五官；Boss 用专门的暗色 StandardMaterial）。
- 原创程序化道具：沈灯腰灯/纸白围巾/披肩/腰带；泼皮红围巾；阿禾围裙/发髻/长筷；闻九披风/更锣/长须；霍三更半面具/双角/铁尺/披风/二阶段余烬。用于 4 人 4 色键/剪影。
- 未使用 Mixamo（`godot-mixamo-demo` 仅作重定向技术参考）；未使用 Tripo（本机无 `TRIPO_API_KEY`），角色为 CC0 + 程序化改造的 Fallback，待补管线见 `CREDITS.md`。
- 无音频；无外部纹理/UI/字体文件。

## 8. 验收 / 工具

```bash
godot --headless --path . --quit-after 600        # 无 SCRIPT ERROR
godot --headless --path . -s tools/smoke_changan_action.gd  # CHANGAN_ACTION_SMOKE_OK
godot --path . --resolution 1920x1080 -s tools/screenshot_changan.gd
godot --path . --resolution 1280x720 -s tools/probe_fps.gd
godot --path . --resolution 1280x720 -s tools/capture_gif.gd
bash tools/verify.sh
```

Smoke 覆盖 83 项：GLB/骨骼/76 clip、标题→开始、Move/Idle、jab 命中、3 连终结击倒、翻滚 i-frame 内/外伤害、油火持续伤害、受击/击倒/起身/胜利、敌人 AI 至少一次 telegraph 且同屏攻击 ≤1、Ahe 对话→战斗 1→灯→战斗 2→B2→闻九→B3→Boss 两阶段→熄灯→胜负→选择→重开→失败重试、0/3 与 3/3 灯黑暗时长（20s/5s）等。

### 8.1 证据

- `docs/shots/01…09`：9 张 1920×1080 实机截图（标题/夜街/对话/战斗/连击/翻滚/街灯/Boss P2/结算）。
- `docs/gameplay.gif`（960×540, 10s）/ `docs/gameplay.mp4`（1280×720, 10s）：真实运行、脚本化镜头。
- `docs/logs/`：boot / smoke / screenshots / fps 原始日志 + verify 摘要。
- `docs/迭代记录.md`：问题、修复、测量。

## 9. 性能（实测与限制）

### 9.1 设置

- GL Compatibility，`scaling_3d/scale=0.65`，MSAA 0，SSAA 0，无阴影/glow/SSAO/SSR。
- 暗部：月光 + 玩家补光 + 1 盏最近街灯；Boss 熄灯用广场灯串替换街灯。
- 所有重复构件 MultiMesh；摊位/酒坛/火盆/广场灯串/街灯杆件合批；灯笼 halo 缩小；VFX 共享资源 + 对象池；伤害数字池。
- 实测 draw calls 约 **146–198**，三角约 **50–57k**。

### 9.2 实测（同一台 Intel HD 6000，1280×720，无 VSync）

| 场景 | avg fps | min fps | 备注 |
| --- | ---: | ---: | --- |
| **最终 `verify.sh`**（代表战斗，1280×720） | **37.4** | **25.0** | draw calls 198 / tris 56,592 / 3 实光；`CHANGAN_FPS_OK` / `CHANGAN_VERIFY_OK` |
| 街道 idle + HUD（toggle 探针） | 30.1 | 22.0 | 负载 17.7，无战斗特效 |
| 代表性战斗（1.5s 终结踢 + 3s 火油） | 33.6 | 7.0 | 负载 20.7，宿主争抢 |
| 同上第二次 | 36.5 | 5.0 | 负载 12.5，宿主争抢 |
| 早期连续压力（1.5s 踢+火） | 20.8 | 1.0 | 负载 22.8，优化前 |

**结论**：最终一次干净回归 **avg 37.4 / min 25.0**，达到 Intel HD 6000 的 30/20 目标。但宿主（Lark/Blender/其他 agent）负载高时会测得 min 3–7 的抖动；逐帧诊断（`tools/probe_hitch.gd`）记录到 0.66–1.15s 的卡顿也发生在 `action=none`（无命中/火焰/特效）时。因此上表同时保留波动数据；发布前建议在空闲机器上再跑一次 `tools/probe_fps.gd`。

### 9.3 可继续降档

1. 关闭灯笼 halo（实测 +15–20 fps，但夜景氛围下降）。
2. `scaling_3d/scale=0.55`。
3. 将玩家补光改为环境光/自发光，不再使用实光。
4. 关闭雾。
5. 进一步合并鼓楼/面摊 geometry。

## 10. 已知技术债 / 风险

- 无音频；无手柄右摇杆视角、按键重映射、震屏开关。
- 角色为 CC0 Q 版共享骨架；Tripo→Blender→GLB 正式资产未做（无 key）。
- Boss 半面具/铁尺为静态挂点，不随头部骨骼旋转；动作中可能轻微穿模。
- 程序化场景偏简；阴影用 blob；夜景可读性依赖补光。
- 性能最终一次 `verify.sh` 全绿（avg 37.4 / min 25.0），但宿主负载高时最低帧会抖；发布前应在空闲机器复测。
- `ObjectDB instances leaked at exit` 警告在 headless smoke 退出时可能出现（挂起 tween/计时器），无 SCRIPT ERROR；不影响运行。
