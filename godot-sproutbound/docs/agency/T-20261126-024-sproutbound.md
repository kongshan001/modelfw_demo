# T-20261126-024 · Sproutbound 实现说明（Game Engineer）

## 任务与来源

- 任务：复刻 B 站《Claude + Codex + Godot，3小时25分钟做出一款3D游戏！》（BV1Z8yCz2Er7，UP AI前沿君）最终展示的高层 3D 游戏体验，做成 Godot 4.6 可玩 vertical slice；不复制视频作者流程/素材/角色/UI/品牌。
- 参考处理：`yt-dlp` 下载到 `/tmp/sprout_ref`，ffmpeg 抽帧 0/30/60/90/120/150/180/210/240/270/300/330/360/390/420s。参考帧仅为了解类型与迭代；交付目录无参考素材。
- 视频事实：最终游戏是**俯视/等轴 3D 幸存者**（绿色芽苗、紫色发光蘑菇群、道具栏/等级/计时/金币、三幕瘴潮；v0.2 修复可读性、v0.3 加跳跃、v1.0 三幕）。
- 规格事实：任务明确要求**第三人称动作**（相机轨道/缩放、近战连击、闪避、HP/受击/击退/死亡、≥2 种蘑菇 AI、目标/胜负/重开、中文 HUD、调试）。因此采用“同类型重释”：保留低模草地/芽苗主题/蘑菇/跳跃，改成第三人称动作，目标改为清空 10 敌 → 石拱门 → 走入光门。详见 `docs/TECH.md` §9。

## 实现文件

- `godot-sproutbound/project.godot`、`scenes/main.tscn`
- `scripts/`：main、world、player、enemy、spore_bolt、hud、style
- `shaders/`：grass_wind、portal_field
- `tools/`：smoke_sproutbound、perf_sproutbound、screenshot_sproutbound、capture_sproutbound_video
- 文档：README / docs/TECH.md / docs/迭代记录.md / CREDITS.md
- 证据：docs/shots/01..08（1920×1080）、docs/media/sproutbound_10s.mp4/.gif

## 关键参数

- 玩家：HP100；walk 4.35/sprint 6.5；jump 7.6；三段连斩 9/11/18（2.30/2.42/2.60m，80/86/96°）；RMB 闪避 0.4s、i-frames 0.28s；Space 跳跃；Shift 疾跑。
- 相机：yaw/pitch 轨道、dist 2.7–8.0、射线防穿墙、FOV 62。
- 菌仔 42HP/12 伤；孢囊菇 30HP/10 伤/9.6m·s⁻¹ 孢弹；菌卫 108HP/24 伤 AoE 2.95m；前摇 0.52/0.82/0.92s。
- 关卡：76×64m；10 敌；8 草籽 + 3 回春露；石拱门 (0,0,39.2)，触发 2.3m。
- 渲染：GL Compatibility；1280×720 逻辑；`canvas_items`；无实时阴影（本机 Intel/GL 无可见输出且多约 270 阴影 pass），程序化接触阴影 + 雾 + glow；全部低模程序化。

## 验证（真实执行）

- 导入：`godot --headless --path . --editor --quit`（首次生成 .godot / 全局类缓存）。
- 冒烟：`godot --headless --path . -s tools/smoke_sproutbound.gd`
  - 结果：`SPROUTBOUND_SMOKE checks=54 failures=0`，末行 `SPROUTBOUND_SMOKE_OK`。
  - 覆盖：启动/标题、开始、10 敌/11 拾取、落地、移动、跳跃、闪避 i-frames、攻击命中、连段、AI 巡逻/发现/追击/前摇→伤害、孢弹、玩家受伤/死亡/失败、重开、拾取草籽/回春露、击杀计数、全清开门、进入光门胜利、暂停、调试开关。
- 性能：`godot --path . --resolution 1280x720 -s tools/perf_sproutbound.gd`
  - 1280×720，VSync off，4s 预热 + 4s 采样：待机 **41.9 FPS**（23.9ms，draw 345，tris 205,654）；战斗 **44.1 FPS**（22.7ms，draw 196，tris 144,862）。
  - Intel HD Graphics 6000 / macOS / Godot 4.6 GL Compatibility；达到 30fps+。
  - 该机器同时跑多个 worker；后续复测 idle 34.5–37.8 / combat 29.3–33.7（load average 5–10）。日志：`docs/agency/perf_runs_final.log`、`docs/agency/perf_run_under_load.log`。低负载样本 41.9/44.1 是较早一次运行输出。
  - 另一次 1920 perf 与视频采集并发运行，读数 9.9/13.4 FPS，不作为有效结果；1920 详细说明见 TECH §7。
- 真实 GPU 截图/录屏：
  - `godot --path . --resolution 1920x1080 -s tools/screenshot_sproutbound.gd` → 8 张 1920×1080。
  - `godot --path . --resolution 1280x720 -s tools/capture_sproutbound_video.gd` → 200 帧 → ffmpeg MP4 10.000s + GIF。
  - 采集时 HUD FPS 冻结为 1280 正常游玩实测基准 42（见 TECH §7.1），避免读回/编码负载污染；正常游玩实时更新。
  - 运行过程中已修复 `spawn_dust` 拼写、全局类导入顺序、MultiMesh AABB、地面 trimesh 不碰撞等 SCRIPT/逻辑错误；最终 GPU 采集与控制台日志 `docs/agency/gpu_screenshot_run.log` 中 `SCRIPT ERROR` / `^ERROR` 均为 0。
  - 冒烟日志：`docs/agency/smoke_run.log`；性能日志：`docs/agency/perf_runs_final.log` 等。
- 已知风险：实时方向光阴影在本机无可见输出（已关闭并用接触阴影）；无音频；敌人命中为距离+扇区而非物理 Hitbox；1920 为输出/截图支持，游戏窗口 1280 逻辑上采样；截图/视频是脚本化摆位实机渲染，不是完整人工通关。

## 说明

本文件为 worker 实现说明，不替代 TECH / 迭代记录。所有数值以实际运行的代码与工具输出为准。
