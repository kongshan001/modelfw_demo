# Cycle 1 循环报告：提灯守夜人 → KayKit Rogue

> 日期：2026-10-31
> 范围：只替换提灯守夜人的“壳”（模型/动画/灯笼），保留巡逻 FSM、路线、速度、驻足时长与 `set_night` 行为。
> 结论先行：**条件通过（Conditional Pass）**。角色与动画 **4.5 → 6.6**，视觉统一性 **5.0 → 6.0**（同框 6.0，压线）；相关 5 维加权 **5.1 → 约 6.1**。性能门禁因本机噪声记 **INCONCLUSIVE**（无一致性回退证据）。

---

## 1. 协作链路

| 步骤 | 职能 | 产出 | 关键结论 |
|---|---|---|---|
| 1 | 策划 | `01-brief.md`（v2） | 3 个 P0；16°/5.8 为验收机位；同方法相对性能门槛；条件放行规则 |
| 2 | 美术 | `02-art-review.md` | Rogue 细节可到 7.0–7.5；A/B 的 0.58 太矮（1.27m），改 **0.74=1.618m**；建议隐藏披风/武器、Nearest+Mipmap、0.7m 提灯杆 |
| 3 | QA | `03-qa-baseline.md` | 基线：无头干净、probe 通过；legacy avg 中位 56.8，A/B cost 噪声不可用；建立交错稳态探针 |
| 4 | 程序 | `04-impl.md` | Rogue 接入完成；程序化回退可用（`GARDEN_FORCE_PROCEDURAL=1`）；首版脸过曝、相机 12° 越权 |
| 5 | QA / 美术 | `05-qa-verify.md`、`05-art-signoff.md` | **阻塞**：夜间脸 p95=255、相机 12°/5.2 未签字；证据缺失 |
| 6 | 程序/协调 | 参数与相机修正 | 回退 16°/5.8；灯笼外移/放低、光晕/玻璃减亮；补 640×360、正午、夜广角、混合阵营、90 帧 |
| 7 | QA / 美术（复审） | `06-qa-recheck.md`、`06-art-recheck.md` | QA：**条件放行**；美术：**条件通过**，C1–C4 关闭 |

## 2. 实现改动

- `scripts/garden_patrol.gd`
  - Rogue：`ModelRoot` scale 0.74、`rotation.y=PI`、脚底 y=0；隐藏 `Rogue_Cape` 与 5 件武器。
  - 材质：Nearest+Mipmap、roughness 0.9、metallic 0、specular 0.15、albedo 冷调 (0.92,0.96,1.02)。
  - 动画：`Idle` ↔ `Walking_A`（淡入 0.18/0.25s，`speed_scale=1.29`，Idle 随机相位，无 root motion）。
  - 灯笼：`handslot_l` 锚点 + 0.7m 杆、双层光晕（0.50/1.05）、2.4m 地面池、根节点无影 OmniLight（0.14+glow×0.18）、玻璃 emission 0.15+glow×1.0。
  - 回退：缺模型/缺动画/环境变量强制时走原程序化 `_build()`，只警告一次。
- `scripts/garden_scene.gd`：`PATROL_CAMERAS["lantern"]` 回到 **16°/5.8**，近景目标 y=1.0。
- `tools/screenshot_patrol.gd`：验收姿态朝机位、隐藏战斗飘字、640×360 / 正午 / 夜广角 / 混合阵营图。
- `tools/capture_patrol_sequence.gd`：提灯人 90 帧 WALK→PAUSE→WALK（隐藏主角/妖灵，短往返路线，仅工具）。

## 3. 验收证据

| 项 | 实测 | 门槛 | 判定 |
|---|---|---|---|
| 无头 600 帧 | 0 `SCRIPT ERROR/ERROR/WARNING`，exit 0 | 空 | PASS |
| legacy probe | `PROBE_PATROL_OK`；avg 47.5–69.7（随机负载） | 同方法中位 ≥54.8 | INCONCLUSIVE（负载噪声） |
| 回退 | 1 条 WARNING、程序化模型、`PROBE_PATROL_OK` | 可用、不刷屏 | PASS |
| 夜间脸部（16°） | p95 **185**、>240 **1.00%**、纯白 0 | p95<240、>240<5% | PASS（max=255 为鼻梁暖高光，美术签字接受） |
| 黄昏脸部（16°） | p95 **199**、>240 **0.76%** | p95<245 | PASS |
| 比例 / 脚底 | 1.618m，脚底 y=0 | 1.55–1.66m | PASS |
| 截图矩阵 | 近景/广角/640×360/正午/夜广角/混合/90 帧 | 齐全、无飘字 | PASS |
| 开关 / 回退 | `5` 键 + UI `QA_KEY_TOGGLE_OK` | 正常 | PASS |

> 性能说明：draw delta 优于基线（约 113.5 vs 144.5），但 legacy avg 随本机负载大幅波动（47.5–69.7），交错稳态探针同样噪声主导。**没有一致性回退证据**，但不能记为性能 PASS；Cycle 2 用固定场景状态、关 vsync、3 连跑中位数复测。

## 4. 评分变化

| 维度 | 基线 | Cycle 1 | 说明 |
|---|---:|---:|---|
| 角色与动画 | 4.5 | **6.6** | 细节/明暗/脸可读；PAUSE 无举灯、灯笼“脱手”感扣分 |
| 视觉统一性 | 5.0 | **6.0**（同框 6.0） | Q 版头身比 46.7% vs 程序化 23.9%，靠比例/机位/材质压线 |
| 光照与氛围 | 6.0 | 6.0（不回退） | 夜脸闭合；灯池/雾维持 |
| 构图与镜头 | 5.5 | 6.0 | 16° 近景完整；广角身份仍靠暖点 |
| 材质与细节密度 | 4.5 | 5.5 | 角色区提升；场景材质未动 |
| 性能 | — | INCONCLUSIVE | 噪声 |
| 稳定性 | — | 9 | 无头 + 回退 + 开关 |
| 相关 5 维加权 | **5.1** | **约 6.1** | +1.0 |

## 5. 未关闭 / 债务（进 Cycle 2）

1. **同框统一性**：Rogue 与程序化扫园人/小女孩仍是两套美术语言（头身比、材质）。计划：扫园人换同骨架 KayKit 角色 + 长袍/toon 调色；同框目标 ≥7.0。
2. **灯笼与 PAUSE**：灯笼外移 0.26m 后“脱手”感；PAUSE 仍是 Idle，没有“举灯/查看”意图。计划：灯回手（右手）+ `Spellcast_Raise` 1.6s。
3. **广角剪影与证据闭环**：默认 48°/27.5m 下灯杆/暖光区 <70px；脚滑探针、性能受控复测尚未完成。

## 6. 运行与复现

```bash
# 画面矩阵（1920×1080）
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd

# 90 帧动画序列
godot --path godot-garden --resolution 1280x720 -s tools/capture_patrol_sequence.gd

# 走位/间距/FPS/开关
godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd

# 回退验证
GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd
```

## 7. 结论

Cycle 1 把“角色细节”这一项从 4.5 拉到 6.6，并建立了一套可重复的职能协作与验收流程；但整体仍不是竞品 8 分——同框风格、PAUSE 意图、广角剪影和受控性能测试是下一循环的硬任务。**条件通过，按 Cycle 2 计划继续。**
