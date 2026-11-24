# 绯星弹幕 · 技术说明

> 工程：`godot-bullet-hell/` · Godot 4.6 stable · GL Compatibility · 1280×720 逻辑画布  
> 参考：B 站《Godot 弹幕怎么做？从一颗子弹到 10 种弹幕》（BV1B4yRzEE9x，UP：还没醒er）。仅研究弹幕算法与节奏语言；工程内不存在视频画面、教程代码、IP 角色/素材/UI/音乐。素材与代码为原创。

## 1. 目标与范围

- 俯视弹幕射击 vertical slice，1280×720 逻辑，可拉伸到 1920×1080。
- 玩家：移动/聚焦、自动射击、2.6px 小判定、擦弹、生命、被弹清弹、重开。
- 10 种数据驱动弹幕，参数集中在 `PatternRunner`，可单独观察。
- Boss 三阶段、120 BPM 时间轴、HP/阶段切换、自动演示。
- 容量 4096 的敌弹池；1200 弹压力下 Intel HD Graphics 6000 平均 ≥30 FPS。
- 固定 seed；headless smoke 复现核心逻辑。

不含音频、联网、存档、手柄；不引入第三方运行时库。

## 2. 场景与文件

```
main.tscn / Main (Node2D, main.gd)
├─ World (Node2D)                   # 屏震只移动 World，不移动 HUD
│  ├─ BulletBackground (z=-100)    # shader 渐变 + 星屑/绯瓣/节拍环/边框
│  ├─ BulletField (z=5)            # BulletPool + 单个 MultiMesh 绘制敌弹
│  ├─ HaloBoss (z=10)              # 原创发光机械光环 Boss
│  ├─ FireflyPlayer (z=20)         # 原创“萤舟”玩家机 + 判定环
│  ├─ ShotLayer (z=21)             # 玩家自动射击小弹池
│  └─ BulletFx (z=40)              # 火花/冲击环，additive
└─ BulletHud (Control, z=100)      # 中文 HUD/覆盖层，自绘
```

固定俯视舞台，无 Camera2D；受击/阶段时对 `World.position` 做衰减随机屏震。  
1920×1080 截图时用 1920×1080 `SubViewport`，逻辑舞台整体 ×1.5；HUD 与 World 同属缩放根节点，因此一起缩放。

核心脚本：

| 文件 | 职责 |
|---|---|
| `scripts/bullet_pool.gd` | 定长数组弹池、运动行为、圆碰撞、寿命/出屏/分裂 |
| `scripts/bullet_field.gd` | MultiMesh/Shader 渲染、容量、可见实例同步 |
| `scripts/pattern_runner.gd` | 10 pattern 的发射参数与节奏 |
| `scripts/boss_timeline.gd` | 120 BPM 三阶段事件表 |
| `scripts/main.gd` | 主循环、时间轴/观察/演示/暂停/重开、玩弹碰撞、HUD 接线 |
| `scripts/player.gd` | 移动、聚焦、自动演示避弹、判定/绘制 |
| `scripts/boss.gd` | Boss 运动、受击、绘制 |
| `scripts/shot_layer.gd` | 玩家子弹与 Boss 命中 |
| `scripts/fx.gd` | 火花/冲击环池 |
| `scripts/hud.gd` | 血条/阶段/弹幕卡/残机/擦弹/FPS/暂停/胜利 |
| `scripts/background.gd` | 程序化背景、星屑、节拍环、边框 |

## 3. 弹幕数据结构与池化

`BulletPool`（RefCounted）使用 **14 条平行定长数组 + count 写指针**：

```text
pos, vel, radius, age, life, behavior, kind,
p0, p1, p2, p3, color, flags, count
```

- `capacity = 4096`；`_init()` 一次 `resize`，运行期不再分配 per-bullet 对象。
- `spawn()` 写入 `count` 位置并递增；池满返回 `false`，不崩溃。
- 每帧 `step()` 顺序：age/运动 → 出屏/寿命 → 玩家碰撞/擦弹 → 分裂请求 → 写指针压实 → 生成子弹出射。
- 移除采用“写指针压实”（保序，便于确定性），不交换尾元素。
- 出界外扩 90px 回收；默认寿命 8–9s。
- `flags` 位：`GRAZED=1`、`CHILD=2`、`HIT=4`，保证同一发只擦/只被弹一次；子弹出射时带 `CHILD` 防止无限分裂。

### 行为公式

设 `v0` 为初速，`t` 为 age，`A,ω,φ` 为参数：

| behavior | 每帧速度/位置 | 参数 |
|---|---|---|
| 直线 0 | `pos += v0·dt` | — |
| 正弦 1 | `perp = normalize(-v0.y, v0.x)`；`v = v0 + perp·A·cos(ωt+φ)`；`pos += v·dt` | P07：A=36，ω=4.2，φ=k·0.41 |
| 追踪 2 | `angle = angle + clamp(wrap(targetAngle-angle), ±turn·dt)`，`v = from_angle(angle)·speed`，持续 `home_time` | P08：turn=1.9 rad/s，speed=200，时间 2.6s，初速 130 |
| 分裂 3 | `t ≥ split_time` 时标记父弹死亡，按固定 RNG 起始角生成 n 发环形子弹出射 | P09：1.05s，12 发，speed=225，r=5.5 |

## 4. 10 种弹幕参数

参数均在 `pattern_runner.gd`；时间单位秒，速度 px/s，角度 rad。

```
P01 单发·瞄准   0.72s  1发  300   aimed=player-boss
P02 三向扇      0.95s  3发  260   aim + (-13°,0,+13°)
P03 五向扇      1.25s  5发  240   aim + 11°·(k-2)
P04 环形        1.35s  24发 230   angle = wave·7° + 2πk/24
P05 双翼螺旋    0.055s 2发  210   angle += 10°/发；第二臂 +180°
P06 连射·加速层 2.3s   15发       3 脉冲 × (200+65j)，j=0..4；每层 ±2.2° 窄扇
P07 正弦花瓣    2.4s   48发       速度=170+160·|cos(3θ+phase)|；SINE 漂移
P08 追踪        1.35s  5发        初速 130；转向 1.9rad/s 持续 2.6s；之后 200
P09 定时分裂    2.0s   2大弹      速度 95，r=14；1.05s 后各 12 裂片，225
P10 旋转弹幕墙  2.5s   18/21列    158 向下；墙线 tilt=±5°；缺口 3 列随 wave 旋转
```

- 所有弹幕都从 Boss 当前位置发射，瞄准使用“发射瞬间玩家位置”，不做预判。
- P05 每发 `angle += 10°`，与教程的“0.05s 一次、每次转 10°”节奏同构；本项目取 0.055s 并以双臂提高可读性。
- P07 的速度调制来自教程花瓣公式的 `|cos(kθ)|` 思路（教程 k=3）；本项目额外给子弹叠加正弦横向速度，因此同时满足“正弦波”行为。
- P10 用 21 列、3 列缺口的墙，墙线整体 ±5° 缓慢旋转；缺口中心 `posmod(4 + wave*4, 21)`，形成可穿越的旋转缺口。

## 5. 时间轴与阶段

`boss_timeline.gd`：

```text
BPM=120, BEAT=0.5s
Phase 1 校准 20 beats / 10s HP 1200
  beat 0→P01, 5→P02, 10→P03, 15→P04
Phase 2 改速 24 beats / 12s HP 1450
  beat 0→P05, 6→P06, 12→P07, 18→P08
Phase 3 终曲 32 beats / 16s HP 1900
  beat 0→P09, 8→P10, 16→P07, 24→P05
```

- `update(dt)` 推进 elapsed，按 beat 找到当前事件；pattern 变化时重建 `PatternRunner`；phase 边界或 HP 归零时切换。
- 阶段切换：清空敌弹、Boss 1.5s 无敌、HUD 横幅、屏震、阶段大环；之后才恢复发射与伤害。
- 自动射击：0.10s 一发、10 伤害、900px/s、瞄准 Boss → 约 100 DPS。常规演示中阶段会按 HP 或时间轴结束（两者都允许）。
- 默认 `demo=true`：Boss 时间轴自动播放，玩家用 Lissajous 目标 + 附近弹斥力自动走位；按方向键/WASD 立即切手动。TAB 可随时切回。
- 1–0 进入 `inspect`：时间轴暂停、清弹、Boss 无敌、玩家不判定被弹（仍计擦弹）；Q 返回时间轴（0.8s 过渡）。
- 暂停：主循环跳过 `_simulate`；HUD 继续刷新覆盖层。R 调用 `reset_run()`，重建时间轴、清池、复位生命/阶段/seed。

## 6. 玩家、碰撞与反馈

- 玩家真实判定 `HIT_RADIUS = 2.6`；视觉环直径 18px（半径 9）；擦弹半径 `GRAZE_RADIUS = 20`。
- 移动速度 300，聚焦 138；边界 `Rect2(28,88,1224,606)`。
- 碰撞条件：`distance² ≤ (bullet.radius + 2.6)²`；擦弹条件 `≤ (bullet.radius + 20)²` 且未擦过。
- 被弹：生命 -1，2.2s 无敌；释放半径 132px 清弹屏障；红色闪屏、屏震、爆炸火花+环。残机 0 → GAME OVER 覆盖层。
- 命中 Boss：玩家弹在半径 34 内消失，火花 + Boss 白闪 + HP 下降；阶段结束清弹。
- 擦弹：`graze` 计数 +1，每次擦弹限流触发青色火花与 10px 环。
- 分裂：`split_burst` 信号触发冲击环 + 火花。

HUD 显示：Boss 名/HP/阶段、当前弹幕卡、残机、擦弹、FPS/弹数/容量、seed/BPM、模式、按键提示、暂停/胜利/Game Over、阶段横幅。

## 7. 渲染与性能

### 敌弹：单 draw call

- `MultiMeshInstance2D` + `QuadMesh(1×1)` + 自定义 canvas_item shader（`blend_add`）。
- 实例容量 4096；每帧只同步 `visible_instance_count = pool.count` 的活动实例。
- 每实例写入 `Transform2D(angle, scale, 0, pos)` 和颜色；不同 `kind` 用缩放区分：
  - ORB：`r*4.0` 圆形；
  - SHARD：`(r*3.7, r*1.5)` 沿速度拉伸；
  - BLOOM：`r*4.5`；CORE：`r*3.3`。
- Shader：中心小白色核心 + 实例色光晕，additive 叠加；不在 CPU 端生成贴图。

### 程序化背景/UI

- 全屏背景渐变由 `background.gdshader` 一次 ColorRect 绘制；星屑 64、绯瓣 30、同心环/边框/节拍线由 `draw_*` 生成，无贴图。
- 背景以 **30Hz** 重录 `queue_redraw`；HUD 以 **20Hz** 重录（FPS/弹数/打击闪屏的 50ms 粒度足够）。跨脚本引用统一用 `preload` 常量并保留静态类型（同时解决 fresh clone 无 `.godot` 类缓存的问题）。两项优化后，1200 弹压力在 720p/1080p 的最终平均为 51.3/46.9 FPS（同机运行波动见日志）。
- FX：512 火花 + 32 环，定长数组 + 单 additive 材质；命中/擦弹/分裂/阶段共用。
- 字体：`SystemFont` 查找 `PingFang SC / Hiragino Sans GB / Microsoft YaHei / Noto Sans CJK SC ...`；不 bundle 字体文件。

### 截图/录像

- `tools/capture_bullet_hell.gd`：1920×1080 SubViewport，逻辑舞台 ×1.5；主进程关闭，按固定步长调用 `debug_step()`，逐张保存 PNG。最终截图 18 张全部原生 1920×1080。
- `tools/perf_bullet_hell.gd`：同一个 SubViewport 结构，`DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`，`Engine.max_fps=0`；预热 2.5s，测量 4s 的墙钟帧数；输出 average / worst-frame / min。
- 10s 视频由 Godot Movie Maker 以项目窗口 1280×720@60 录制 600 帧；ffmpeg lanczos 放大到 1920×1080，H.264 CRF 19；HUD 在 Movie Maker 中显示 `REC 60FPS`（成片节奏），避免把录制环境吞吐误当实时 FPS。

### 结果（原始日志 `docs/logs/`）

| 场景 | 分辨率 | 弹数 | 平均 FPS | 最坏帧 |
|---|---|---|---|---|
| 常规 | 1280×720 | 200 | 74.13 | 25.91 ms |
| 常规 | 1920×1080 | 200 | 67.98 | 20.92 ms |
| 压力 | 1280×720 | 1200 | 51.34 | 24.89 ms |
| 压力 | 1920×1080 | 1200 | 46.88 | 29.12 ms |

硬件：Intel HD Graphics 6000，macOS，OpenGL 4.1 Compatibility。  
压力场景平均满足 ≥30 FPS，最终一轮四组采样中最坏帧 29.12ms（约 34 FPS 瞬时值），未出现持续掉帧。1200 弹场景只用于验收容量，常规玩法弹数远低于此。

截图 HUD 中的 FPS 是截图会话实际读数（最终一组：常规 90 / 1200 弹 49），不同次采集受温度、窗口前台状态和 PNG 读回影响会出现 9–90 的波动；因此性能结论以独立的 4s 采样为准。

## 8. 确定性与验收

- 全局 seed：`0xB17B17`；`BulletPool.rng` 负责分裂子弹出射角；弹幕发射不使用随机数。
- headless 测试用固定 `dt=1/60` 调用同一套 `BulletPool.step / PatternRunner.update / BossTimeline.update / Main._simulate`。
- `tools/smoke_bullet_hell.gd` 覆盖（69 checks）：
  - 10 pattern 数量与方向（P02 ±13°、P03 ±22°、P04 24 个不同方向、P05 角度推进、P06 5 层速度、P07 速度调制、P09 24 裂片、P10 18/21 列）；
  - 出屏/寿命回收、1000 发寿命清理、圆碰撞命中、单次擦弹、1200 发容量；
  - 追踪转向、定时分裂、固定 seed 的浮点签名一致；
  - 时间轴三段推进、全 10 pattern 覆盖、完成；
  - 主场景：暂停冻结、重开清池/复位、受击减命、残机 0 GAME OVER、Boss HP 0 胜利、1–0/Q/P/TAB/R 键位路由。
- 最终 smoke 输出 `BULLET_HELL_SMOKE_OK`（69/0）；`--headless --quit-after 600` 无 `ERROR`/`SCRIPT ERROR`。
- 在排除 `.godot/` 的 fresh copy 上重跑 headless boot 与 69 项 smoke 同样通过：跨脚本 `class_name` 引用已改为 `preload` 常量，不再依赖编辑器生成的全局类缓存。日志见 `docs/logs/fresh_clone_*.log`。

## 9. 已知问题与风险

1. **字体**：`SystemFont` 依赖系统 CJK 字体，不随仓库分发；缺少这些字体的机器会显示方框。完全可移植需引入 OFL 字体。
2. **性能波动**：Intel HD 6000 + macOS OpenGL 驱动在 1200 弹压力下会有运行间波动；最终一轮均值为 46.88–51.34 FPS、最坏帧 29.12ms，但历史采样中曾出现 73ms 单帧。均值稳定 ≥30，严格最小帧率仍受系统负载/温度影响。常规密度平均 68–74 FPS（vsync 关闭，4s 采样）。
3. **视频分辨率**：Movie Maker 只按项目窗口 1280×720 录制，最终 MP4 为 1080p 上采样；截图才是原生 1920×1080。
4. **录屏 HUD FPS**：显示 `REC 60FPS`（成片节奏）；截图显示实时读数。两者不是同一种测量，文档中已区分。
5. **玩法取舍**：无音频、手柄、键位重映射、难度选择、存档；自动演示避弹是启发式；观察模式为看弹幕而禁用被弹判定。
6. **容量满**：池满 4096 时静默丢弃新弹；不崩溃，但极端自定义模式下可能出现“弹幕变稀”。
7. 背景星屑已压低亮度，以避免与白色核心弹混淆；在极低弹数场景仍可能被误读。

## 10. 复现命令汇总

```bash
godot --headless --path godot-bullet-hell --quit-after 600
godot --headless --path godot-bullet-hell -s tools/smoke_bullet_hell.gd
godot --path godot-bullet-hell --resolution 1280x720 -s tools/capture_bullet_hell.gd
godot --path godot-bullet-hell --resolution 1280x720 -s tools/perf_bullet_hell.gd -- --vp=1280x720 --bullets=1200
godot --path godot-bullet-hell --resolution 1280x720 -s tools/perf_bullet_hell.gd -- --vp=1920x1080 --bullets=1200
godot --path godot-bullet-hell --resolution 1280x720 -s tools/perf_bullet_hell.gd -- --vp=1920x1080 --bullets=200
# 可选：重录 10s 展示（之后用 ffmpeg 转 MP4/GIF）
godot --path godot-bullet-hell --resolution 1280x720 --write-movie /tmp/scarlet.avi --fixed-fps 60 --quit-after 600 -- --showcase
```
