# 回合制法术表现（VFX / 演出）性能审计协议

> 版本：v1.0 · 2026-11-21
> 适用：`godot-battle/`（Godot 4.6 · GL Compatibility · 1920×1080 基准 / 1280×720 档 · Intel HD 6000 级核显）
> 任务：T-20261121-010 · 类型：调研 / 审计协议 · 不修改游戏代码与资产
> 结论标记：**[公开]** 可核验的官方/厂商文档；**[案例]** 公开游戏案例（范围有限）；**[推断]** 由代码/文档推导但未实测；**[政策]** 本项目建议门槛，需首轮基线后校准；**[待测]** 下一轮必须采数。

---

## 00 · 结论先行（一页）

**业界一般不审“平均帧率”，而是审“最坏回合里的最坏一帧”，并用三套证据交叉验证：帧时间分布（用户是否卡）、引擎计数器（卡在哪个阶段）、GPU/资源证据（为什么卡）。** 回合制还有两个专属变量：**可预知的施法序列**（可以把首放成本前移）和 **倍速/跳过**（会把 VFX 生命周期与战斗时间轴解耦）。

| 问题 | 业界一般做法 | 本项目落地 |
|---|---|---|
| **审计单元** | 单次施法（cast）→ 回合窗口（turn window）→ 整场（battle）→ 长局热稳定（soak） | `action_start` 到该动作全部 Damage/Heal/Status/VFX 结束为 cast；一回合全部 cast 为 turn；3 场 × 10 回合为 soak |
| **核心指标** | p50/p95/p99 帧时间、worst frame、hitch 次数；draw call、overdraw、粒子量、显存；首放 hitch；倍速/跳过后的生命周期 | 同上 + `OBJECT_NODE_COUNT` 峰值 / 孤儿数 + F2 后处理开关差 + 2×/skip 峰值 VFX 并发数 |
| **工具** | 引擎 profiler + 引擎计数器 + GPU capture + 真机帧时间 + 热稳定测试 | Godot Profiler / Monitors / `--print-fps` + 自建逐帧 CSV；GPU capture 受 macOS + GL Compatibility 限制，需跨平台补测 |
| **流程** | 设备档位 → 帧预算 → 固定场景脚本 → 冷启动/热稳定/连续 N 回合采集 → 指标入库 → fail-closed 门禁 → 回归对比 → 报告签核 | 见 §04；缺失数据 = 不通过 |
| **“什么算过”** | 尾部分位 + 最坏帧 + hitch 数 + 峰值资源，全部在预算内；没有数据不签核 | 60fps：p95 ≤ 16.7ms、p99 ≤ 20ms、worst ≤ 33.3ms；30fps：p95 ≤ 33.3ms、p99 ≤ 40ms、worst ≤ 66.7ms；每 10 次施法 0 个 >2× 预算的 hitch |
| **报告** | 环境 + 场景脚本 + 原始逐帧数据 + 汇总 + 判定 + 证据附件 | Markdown 摘要 + JSON 汇总 + CSV 原始数据 + 截图/GIF；模板见 §4.6 |

**五条最值得记住的结论**

1. **审计对象是“最坏回合”，不是“平均战斗”。** 平均 FPS 会把 1 次 120ms 的卡顿稀释到看不见；门禁必须看 p99、worst frame 和 hitch 次数。**[公开]**（NVIDIA 百分位方法；Android Vitals 对慢帧/冻帧的定义）
2. **回合制最大的红利是“可预知”。** 指令阶段/回合开始前就知道下一批技能，可以把贴图、材质、粒子、shader 的首放成本前移到加载或指令阶段。**[推断]**（由回合制结构与 Godot/Unity/Unreal 的预热机制推导）
3. **倍速与跳过不是 UI 功能，是独立的 VFX 生命周期审计场景。** 战斗时间轴被压缩，但 tween/粒子寿命不会自动同比压缩；必须测 2× 下的并发峰值、skip 后的节点残留和孤儿数。**[推断]**（由本项目 `playback_speed` 与 tween 实现推导，需实测）
4. **引擎 profiler 回答“谁慢”，GPU capture 回答“为什么慢”，真机帧时间回答“用户是否感知到”。** 三者不能互相替代；只有计数器没有帧时间，会优化错对象。**[公开]**（工具能力边界见 §03）
5. **没有基线的阈值只是政策。** 下表所有数字是首轮政策值；第一轮采完基线后，按“设备档位 × 实测余量”校准，再写进 CI 门禁。**[政策]**

**最小可执行闭环（本轮之后下一轮就能跑）**

```text
固定 seed/阵容/指令脚本 → 冷启动 1 次 + 热稳定 3 次 × 10 次施法
→ 逐帧 CSV（frame_ms / draw_calls / nodes / vram）
→ p50/p95/p99 + worst + hitch + 峰值资源
→ fail-closed 门禁 → 与基线对比 → 报告签核
```

---

## 01 · 审计对象与四层拆分

### 1.1 审计单元（Audit Unit）

| 单元 | 定义 | 为什么需要 | 本项目对应 |
|---|---|---|---|
| **Cast（单次施法）** | 一次 `action_start` 到该动作的所有伤害/治疗/状态/VFX 结束 | 单法术预算卡的最小单位；可归因到具体技能 | `BattleDirector` 生成命令队列；`BattleSequencer` 逐条播放 |
| **Turn（回合窗口）** | 一个回合内所有单位的 cast 总和（含敌方） | 回合制 worst-case：AoE、连发、反击、状态跳伤叠加 | 3v4；敌方 `boss_brute` 有 `ground_split`，`boss_fox` 有 `charm_seal` |
| **Battle（整场）** | 从进场到结算面板 | 长局资源增长、日志/UI 累积、对象池是否泄漏 | 默认 `enc_bamboo_01`，seed `20261024` |
| **Soak（热稳定）** | 连续 20–30 分钟 / 10 回合 × 3 场 | 温控降频、显存/内存缓慢增长、shader 缓存逐步命中 | 移动档位必做；桌面档位做 10 分钟对照 |

**归因原则**：任何指标异常，先归到 cast，再归到 turn，最后才看整场；否则无法判断是“单法术太重”还是“连续叠加/泄漏”。

### 1.2 四层拆分

#### ① 内容 / 特效设计层——“这个法术本身有多重”

| 审计问题 | 指标 | 怎么量 | 常见缺陷 |
|---|---|---|---|
| 粒子数量是否超预算 | `GPUParticles2D.amount`、实际发射率 `amount × amount_ratio / lifetime`、峰值存活粒子 | 引擎计数器 / 代码审计 / 自建 sampler | 只改 `amount` 不改 `lifetime`，实际发射率仍然高；one_shot 重复触发 |
| 透明叠层与屏幕占比 | 平均 overdraw 层数、屏幕覆盖率、全屏闪白次数 | Overdraw 可视化 / GPU capture / 估算 | 全屏 `ColorRect` 闪白、多个 additive 光圈重叠、粒子贴图过大 |
| 材质 / 混合模式 | additive / alpha / opaque 的数量；材质切换次数 | Frame Debugger / RenderDoc / draw call 计数 | additive 打断 2D 批处理；每个特效一个独立材质 |
| Shader 复杂度 | 每像素采样数、分支、依赖纹理、全屏 pass 数 | 静态审计 + A/B 开关 + GPU capture | 全屏 9-tap Sobel 后处理、每帧 BackBufferCopy |
| 贴图 / 序列帧 | 单帧尺寸、序列帧数、压缩格式、VRAM | 资源清单 / `Performance.RENDER_TEXTURE_MEM_USED` | 4K 序列帧、未压缩 RGBA、未复用图集 |
| 演出时长与镜头 | 单 cast 时长、shake/punch zoom、闪白时长 | 命令时间轴 + 录屏 | 镜头抖动叠加、闪白与粒子同时峰值 |

**本项目代码事实（用于审计定位，不是整改）**

- `VFXFactory._burst()` 把传入粒子数翻倍：`particles.amount = maxi(2, amount * 2)`（`godot-battle/battle/vfx_factory.gd:360`）。例如火焰 32 + 14 会变成 64 + 28；雷击 24 → 48；AoE 22 → 44。
- `screen_flash()` 每次创建一个 `1920×1080` 的全屏 `ColorRect` 并淡出（`vfx_factory.gd:320-331`）；AoE 每个目标一次 `DamageCommand`，会叠加多个全屏透明层。
- 弹道拖尾 `GPUParticles2D.amount = 72`、`lifetime = 0.3`、`local_coords = false`（`vfx_factory.gd:260-280`）。
- 所有爆发使用共享的 additive `CanvasItemMaterial`（`vfx_factory.gd:397-401`），但每个爆发仍是独立节点/独立绘制项；是否打断批处理需用 draw call 实测确认。**[待测]**
- 画风后处理：`BackBufferCopy`（`COPY_MODE_VIEWPORT`）+ 全屏 `ColorRect` + `style_post.gdshader`（`godot-battle/battle/views/style_post_process.gd:30-37`）。Shader 的 Sobel 边缘检测对每像素做 8 次邻域采样 + 1 次原图采样（`godot-battle/shaders/style_post.gdshader:42-57,135`）。**[公开/代码事实]**

#### ② 运行时 / 渲染层——“这一帧的时间花在哪”

| 指标 | 定义 | 工具 | 备注 |
|---|---|---|---|
| **Frame time** | 相邻两帧的真实时间差（ms） | 自建逐帧计时；`--print-fps` 只有 1Hz FPS | 用 `Time.get_ticks_usec()` 取原始值，不要用平滑后的 `delta` |
| **CPU main / process** | 主线程逻辑耗时 | Godot Profiler / Monitors `TIME_PROCESS` | Profiler 测脚本函数；Monitors 看整体 |
| **GPU time** | GPU 执行一帧的时间 | Unreal `stat GPU` / Unity GPU Profiler / Xcode / AGI；Godot GL Compatibility 无稳定 GPU timer | 没有 GPU timer 时，用“关闭 VFX/后处理后的帧时间差”近似 |
| **Draw calls** | 一帧提交的绘制调用数 | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`；Unity Frame Debugger；Unreal `stat RHI` / Insights；Three.js `renderer.info.render.calls` | 比较 **同场景的增量**，不要跨项目比绝对值 |
| **Batches** | 合批后的批次数 | 引擎 profiler / Frame Debugger | 2D 下材质/混合/纹理变化会打断批处理 |
| **Overdraw** | 平均每像素被着色的次数 | RenderDoc / AGI / Arm Streamline / 引擎 overdraw 视图 | 全屏闪白、additive 粒子、UI 透明层是主因 |
| **Shader 复杂度** | 每像素采样/指令数、分支、依赖纹理 | Mali Offline Compiler / RenderDoc shader debug / A/B | 静态复杂度 ≠ 实际耗时，需结合 overdraw |
| **带宽 / 显存** | 纹理/RT 读写带宽、VRAM 占用 | AGI / Streamline / Xcode counters；Godot `RENDER_VIDEO_MEM_USED` | 本项目目前贴图极小；未来 AI 立绘/序列帧时重点 |
| **RT / 后处理** | BackBufferCopy、全屏 pass、屏幕纹理采样 | 引擎渲染器 / GPU capture / A/B | 本项目 F2 三风格：原画 / 卡通 / 水墨 |

**关键区分**：`Performance.TIME_PROCESS` 是“完成一帧用了多久”，`TIME_FPS` 是“上一秒渲染了多少帧”，后者每秒才更新一次（Godot 文档明确说明）。用 FPS 做单法术审计会严重失真。**[公开]**

#### ③ 资源 / 加载层——“第一次为什么卡，之后为什么越来越好”

| 审计问题 | 指标 | 怎么量 | 备注 |
|---|---|---|---|
| 首放 hitch | 第 1 次 cast 的 worst frame vs 第 2–10 次的中位数 | 逐帧 CSV，按 cast 分组 | 首次绘制会触发 2D pipeline 编译；Godot Compatibility **没有** ubershader / 管线预编译 **[公开]** |
| Shader 编译 | 首次绘制 2D 节点、材质变体、后处理变体的耗时 | Godot 管线编译监视器（Canvas/Mesh/Surface/Draw/Specialization）；Unity ShaderVariantCollection；Unreal PSO 验证 | Compatibility 下的官方建议：在加载时把材质/shader/粒子放进视锥显示至少一帧 **[公开]** |
| 贴图/网格/音频加载 | 同步 `load()` 的耗时、峰值内存、线程加载是否完成 | `ResourceLoader.load_threaded_request/get_status/get`；加载日志 | 回合制可在指令阶段预加载下一批技能资源 **[推断]** |
| GC / 分配 | 每 cast 的节点创建/释放、对象孤儿、内存增长 | `OBJECT_NODE_COUNT`、`OBJECT_ORPHAN_NODE_COUNT`（debug-only）、`MEMORY_STATIC`（release 不可用） | 本项目 VFX 每次创建节点 + tween，无池化；需测峰值与残留 |
| 对象池 | 池命中率、峰值对象数、复用后的状态重置 | 自建计数器 / 引擎 profiler | 本项目当前无池；先测再决定是否池化 |
| 音频 voices | 同时在播的 SFX 数、被抢占次数 | `AudioDirector` 轮询池 + 听测 | 本项目 SFX 池固定 8 个（`audio_director.gd:8`），AoE 多段可能超过 8 而抢占 |

**本项目代码事实**

- 项目没有 VFX 对象池：每个法术创建 `Node2D` / `Line2D` / `Polygon2D` / `GPUParticles2D` / `Tween`，结束后 `queue_free()`（`vfx_factory.gd`）。
- 共享的 32×32 柔光贴图是静态缓存（`_soft_texture`），首次 `_burst` 时生成；additive 材质也是静态缓存。首次使用仍可能触发 2D pipeline 编译。**[推断]**
- 本轮未新增/修改 `godot-battle/` 任何代码或资产；上述为代码审阅事实与待测假设。

#### ④ 产品 / 回合制特性层——“玩家真正会遇到的组合”

| 场景 | 风险 | 指标 | 门槛（政策值） |
|---|---|---|---|
| 连续法术（同一回合多次出手） | VFX 未消散就叠加 | 峰值并发 VFX 数、峰值节点数、帧时间 | 2× 倍速下峰值 ≤ 1.5× 1×；无 frame > 2× 预算 |
| AoE 多目标 | 每个目标一套 VFX + 闪白 + 飘字 + 音效 | 峰值 draw calls / particles / overdraw / audio voices | 单 cast draw calls 增量 ≤ +40（D0）；无 >33ms 帧 |
| 2× / 4× 倍速 | 时间轴压缩，VFX 寿命不变 → 重叠 | 并发数、输入到下一指令延迟、帧时间 | 2× 下 p95 不劣化 >10%；输入延迟 ≤ 100ms |
| 自动战斗 | 长时间无人工节流，日志/节点累积 | 10 回合节点增长、日志行数、内存 | 10 回合节点增长 ≤ 10%；无孤儿增长 |
| 跳过演出 | 生成号切换、队列清空，但旧 tween/粒子可能残留 | skip 后 100ms / 1s 的节点数、孤儿数、闪白残留 | 1s 内回到基线 ±10 节点；孤儿 0 增长 |
| 镜头切换 / shake | 抖动叠加、与 UI 不同步 | 镜头位移峰值、UI 可读性、晕动 | 主观 + 录屏；不做性能门禁 |
| UI / 战斗日志 | 高速连发时 RichTextLabel 重排/滚动 | UI 帧耗时、日志行数、draw calls | 日志行数上限；UI p95 ≤ 2ms |
| 移动端热 / 电 | 20–30 分钟后降频、掉帧 | p95 退化、thermal status、耗电 | 30 分钟 p95 退化 ≤ 15%；不进入 SEVERE/CRITICAL |

**本项目代码事实**

- `BattleSequencer` 的倍速只缩放 `BattleContext.wait()`（`battle_context.gd:34-36`），而 VFX 的 Tween 走引擎时间，不会按 `playback_speed` 加速。**因此 2× 下命令间隔减半、VFX 时长不变，理论上会重叠。** **[推断，待测]**
- `skip_all()` 会把 `playback_speed` 设为 `1000.0`、`_generation += 1`、清空队列（`battle_sequencer.gd:56-69`）；已在播放的 tween/粒子不会自动 kill，需测残留。
- `DamageCommand` 的顿帧把 `Engine.time_scale` 设到 `0.05`，持续 0.12 秒真实时间（`damage_command.gd:4-5,59-65`）。这会让 VFX tween 也慢到 5%；AoE 多目标连续顿帧会显著拉长演出并改变 VFX 重叠形态。
- 暴击会额外触发全屏 flash（`damage_command.gd:51-52`）；固定 seed 下可复现。
- 技能数据：`thunder_storm` 是 `target_type=1, max_targets=99` 的敌方 AoE；`sweep` 最多 3 目标；`ground_split` 最多 2 目标；`fire_spell` 单体。3v4 战斗中 `thunder_storm` 最多同时命中 4 个敌人。

### 1.3 指标字典（统一口径，避免报告打架）

| 指标 | 单位 | 定义 | 采集方式 | 备注 |
|---|---|---|---|---|
| `frame_ms` | ms | 相邻帧真实时间差 | `Time.get_ticks_usec()` 差值 | 不做平滑；记录每帧 |
| `p50/p95/p99` | ms | 帧时间分位；p95 = 95% 的帧 ≤ 该值 | 对整段场景排序取分位 | 单 cast 窗口太短时 p99 无统计意义，见 §4.4 |
| `worst_ms` | ms | 场景内最大单帧 | `max(frame_ms)` | 必须单列，不能被 p99 掩盖 |
| `hitch_count` | 次 | `frame_ms > 2 × 帧预算` 的帧数 | 逐帧判定 | 另统计 `>4×` 的 severe hitch |
| `draw_calls_peak` | 次 | 场景内 `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` 最大值 | Godot 监视器 / 自建 sampler | 比较增量，不跨项目比 |
| `particles_peak` | 个 | 同时存活的粒子上限 | 引擎计数器 / 自建统计 | GPUParticles2D 的 `amount` 是上限，不等于存活数 |
| `overdraw_avg` | 层 | 着色片段数 / 屏幕像素数 | Overdraw 可视化 / GPU capture | 全屏闪白与 additive 层会推高 |
| `nodes_peak` | 个 | `OBJECT_NODE_COUNT` 峰值 | Godot 监视器 | 记录 cast 前后差值 |
| `orphans_after_skip` | 个 | `OBJECT_ORPHAN_NODE_COUNT` | 仅 debug build 有效 | 每次 skip 后 1s 采样 |
| `vram_delta` | MB | `RENDER_VIDEO_MEM_USED` 的 cast 前后差 | Godot 监视器 | 纹理会缓存，不代表泄漏 |
| `first_cast_ms` | ms | 第 1 次 cast 的 worst frame | 逐帧 CSV 分组 | 与第 2–10 次中位数比较 |
| `style_delta_ms` | ms | F2 原画 vs 卡通/水墨的 p95 差 | A/B 两次采集 | 归因后处理成本 |
| `speed_overlap_ratio` | 倍 | 2× 下峰值并发 VFX / 1× 下峰值 | 自建计数 | 目标 ≤ 1.5× |
| `input_latency_ms` | ms | 指令确认到下一指令阶段可交互 | 录屏/时间戳 | 产品体验指标 |
| `thermal_degradation` | % | 后 5 分钟 p95 相对前 5 分钟的退化 | 30 分钟 soak | 移动端必测 |

---

## 02 · 回合制专属方法

### 2.1 可预知序列 → 预热 / 预加载 / 预编译

回合制与动作游戏最大的区别：**下一批施法者在回合开始时就已知**。这允许把“首放成本”从玩家第一次看到特效时，前移到加载、指令阶段或回合横幅期间。

| 层级 | 做法 | Godot 实现 | Unity / Unreal 对应 | 证据 |
|---|---|---|---|---|
| 资源预加载 | 下一回合技能所需贴图/材质/场景异步加载 | `ResourceLoader.load_threaded_request()` + 轮询状态 | Addressables 预加载；Unreal Soft Reference + Async Load | **[公开]** Godot 后台加载文档 |
| Shader / pipeline 预热 | 让材质、shader、粒子在视锥内实际绘制至少一帧 | Compatibility 官方建议：预加载材质/shader/粒子并显示至少一帧 | Unity `ShaderVariantCollection.WarmUp`；Unreal PSO precaching | **[公开]** Godot 管线编译文档；Unity/Unreal 文档 |
| 粒子系统预热 | 先发射一次但不可见/在屏幕角落，或 `preprocess` 跑一段 | `GPUParticles2D.preprocess` 可在首帧前预模拟；one_shot 用 `restart()` 而不是反复 `emitting=true` | Unity VFX Graph PreWarm；Niagara Warmup Time | **[公开]** Godot `GPUParticles2D` 文档（`preprocess`、`restart`） |
| 对象池预热 | 预创建 N 个通用 VFX 节点，避免首放分配 | 自建 `VFXPool`（下一轮工程任务，不在本轮） | Unity ObjectPool；Unreal Niagara pooling | **[推断]** 由本项目“每 cast 创建/释放”推导 |
| 后处理预热 | 开局把 F2 三种风格各渲染一帧，编译 shader 变体 | `StylePostProcess.set_style()` 循环一次，放在加载画面内 | Unity Shader warmup；Unreal PSO cache | **[推断/待测]** 本项目后处理 shader 在 `_ready` 已使用，但风格分支可能首次切换才编译 |

**验收方式**：记录第 1 次 cast 与第 2–10 次 cast 的 worst frame。若首放明显高于热态，说明预热不足；若预热后仍高，说明是资源/带宽问题，不是编译问题。

### 2.2 单法术预算卡 + 回合 worst-case 预算

**预算卡按“峰值增量”计，不按“总耗时”计。** 一个 2 秒的法术如果每帧只多 1ms，它比一个 0.3 秒但峰值多 8ms 的法术更安全。**[政策/推断]**

单法术预算卡（D0：1080p / 60fps / VFX 占帧预算 30% = 5ms）：

| 字段 | 建议上限 | 说明 |
|---|---|---|
| `vfx_peak_ms` | ≤ 5.0ms | cast 期间相对基线中位帧时间的峰值增量（CPU+GPU 合计，无法分离时用总帧时间） |
| `draw_calls_delta` | ≤ +40 | 同一相机/分辨率下，cast 峰值相对空场基线 |
| `particles_peak` | ≤ +150 | 同时存活粒子；不是 `amount` 配置值 |
| `overdraw_delta` | ≤ +3 层 | 平均 overdraw 增量；全屏闪白单独计 1 层 |
| `nodes_delta` | ≤ +80 | cast 期间新增节点峰值 |
| `vram_delta` | ≤ +8MB | 一次性资源增量；缓存不算泄漏 |
| `first_cast_worst_ms` | ≤ 50ms | 首放最坏帧；>50ms 视为 P0 |
| `repeat_cast_worst_ms` | ≤ 16.7ms | 热态最坏帧；>16.7ms 视为 P1 |
| `audio_steals` | 0 | 同时请求 > 8 时的抢占/截断次数；池大小见 `audio_director.gd:8` |
| `duration_s` | 记录，不设硬上限 | 演出时长是产品选择，不是性能指标 |

回合 worst-case 预算（同一回合多个 cast 叠加/倍速）：

| 字段 | 建议上限（D0） | 说明 |
|---|---|---|
| `turn_vfx_peak_ms` | ≤ 7.5ms（1.5× 单法术） | 同一帧多个 VFX 叠加的峰值增量 |
| `turn_nodes_peak` | ≤ +120 | 连续 cast 未回收时的峰值 |
| `turn_draw_calls_peak` | ≤ +60 | AoE/连发叠加 |
| `2x_peak_ratio` | ≤ 1.5× 1× | 2× 倍速下并发 VFX 峰值 / 1× |
| `skip_restore_ms` | ≤ 100ms | 跳过到可交互的时间 |
| `orphans_after_skip` | 0 增长 | 10 次 skip 后仍为 0 |

> **为什么是 1.5× 而不是 2×？** 2× 倍速下命令间隔减半，理论上并发可以翻倍；但玩家可感知的“最坏帧”不应翻倍。1.5× 是政策缓冲，首轮基线后再校准。**[政策]**

### 2.3 倍速与跳过：审计的是“生命周期错配”

本项目的时间轴有两套时钟：

1. **战斗时钟**：`BattleContext.wait()` 用 `playback_speed` 缩放等待（`battle_context.gd:34-36`）。
2. **引擎时钟**：Tween、粒子、动画、`Engine.time_scale` 走引擎时间；`playback_speed` 不影响它们。

由此产生三个必测场景：

| 场景 | 机制 | 预期风险 | 必测指标 |
|---|---|---|---|
| **2× 连发** | 命令等待减半，VFX tween/粒子寿命不变 | 上一个法术未消散，下一个已开始 → 峰值叠加 | 并发 VFX 数、峰值节点、p95/worst、draw calls |
| **skip 中途** | `_generation += 1`、清队列、`playback_speed=1000`；旧 Tween 不会自动 kill | 闪白/粒子/Line2D 残留在屏幕上；节点孤儿 | skip 后 100ms/1s 节点数、孤儿数、屏幕截图 |
| **顿帧 + 倍速** | `Engine.time_scale=0.05` 持续 0.12s 真实时间；2× 下顿帧占比更大 | 演出被顿帧拉长、VFX 在 5% 时间下几乎冻结 | 输入延迟、cast 实际时长、VFX 峰值 |

**4× 的处理**：本项目当前只有 1×/2×（`battle_hud.gd:211-216`）；若未来上线 4×，按同一场景加跑 4×，重点看 `playback_speed` 与 tween/粒子的错配是否进一步放大。

**验收动作**：同一场景分别跑 1×、2×、2×+skip，各 10 次；比较峰值并发、节点峰值、skip 后残留。若 2× 峰值 >1.5× 1×，先修生命周期（kill/回收/池化），再谈美术削减。

### 2.4 可复现场景：固定 seed + 固定阵容 + 逐回合脚本

“同一场景”必须同时固定以下字段，缺一不可：

| 类别 | 字段 | 本项目默认/示例 |
|---|---|---|
| 构建 | 引擎版本、构建哈希、是否 debug | Godot `4.6.stable.official.89cea1439` |
| 渲染 | 渲染器、分辨率、vsync、窗口模式 | `gl_compatibility`、1920×1080、vsync 关/开各一次 |
| 设备 | 机型、OS、驱动、电源模式、热状态 | 本机 Intel HD 6000 / macOS 12；移动档位单独记录 |
| 战斗 | seed、遭遇、我方阵容、敌方阵容 | `20261024`、`enc_bamboo_01`、3 英雄 vs 4 妖 |
| 指令 | 逐回合的指令脚本（谁、对谁、用什么技能） | JSON：`[{turn:1, actor:"hero_mage", skill:"fire_spell", target:"boss_fox"}]` |
| 演出 | 倍速、skip 时机、画风、镜头 | 1× / 2× / skip@0.4s / 原画 / 卡通 / 水墨 |
| 采样 | 预热帧数、采样帧数、重复次数 | 弃前 2 次 cast；每场景 ≥2,000 帧；3 次重复 |

**场景脚本 JSON 建议**（下一轮可直接落盘为 `docs/perf/scenarios/*.json`，不修改游戏代码即可作为审计输入的“规格”）：

```json
{
  "id": "S2_aoe_thunder_storm",
  "seed": 20261024,
  "encounter": "enc_bamboo_01",
  "party": ["hero_swordsman", "hero_mage", "hero_healer"],
  "commands": [
    {"turn": 1, "actor": "hero_mage", "skill": "thunder_storm", "target": "all_enemies"},
    {"turn": 2, "actor": "hero_mage", "skill": "thunder_storm", "target": "all_enemies"},
    {"turn": 3, "actor": "hero_mage", "skill": "thunder_storm", "target": "all_enemies"}
  ],
  "speed": 1.0,
  "skip_at_s": null,
  "style": 0,
  "resolution": "1920x1080",
  "vsync": false,
  "warmup_casts": 2,
  "measured_casts": 10,
  "repeat_runs": 3
}
```

**可复现性校验**：同一脚本跑两次，p95 差异 ≤10%、节点峰值差异 ≤5%、cast 序列一致；否则本次数据作废，先查环境（后台进程、热降频、vsync、驱动缓存）。

### 2.5 审计场景矩阵

| 编号 | 场景 | 目的 | 关键变量 | 必测指标 |
|---|---|---|---|---|
| S0 | 空场 / 指令阶段 | 基线 | 5s 无 VFX | 基线 p50/p95、draw calls、节点数 |
| S1 | 单体大招 | 单法术预算卡 | `fire_spell` 单体 / 1× | 首放 vs 热态、峰值增量、闪白 |
| S2 | AoE 多段 | 最坏叠加 | `thunder_storm` 4 目标 / 1× | 峰值 draw calls/particles/overdraw、p95/worst |
| S3 | 倍速连发 | 生命周期错配 | `sweep` 3 目标 / 2× / skip | 并发峰值、skip 残留、输入延迟 |
| S4 | 后处理 A/B | 全屏 shader 成本 | F2 原画/卡通/水墨 | `style_delta_ms`、draw calls、VRAM |
| S5 | 10 回合 soak | 累积/泄漏/热稳定 | 自动战斗 / 30 分钟 | 节点增长、内存、p95 退化、thermal |
| S6 | 冷启动首放 | 首放 hitch | 重启应用 / 首次施法 | `first_cast_ms`、Canvas pipeline 计数 |

---

## 03 · 工具链：能回答什么、不能回答什么

### 3.1 总表

| 工具 | 能回答 | 不能回答 | 本项目可用性 |
|---|---|---|---|
| **Godot Profiler**（Debugger → Profiler） | 脚本函数/帧/物理的 CPU 时间；Inclusive/Self；哪段 GDScript 慢 | GPU 时间、draw call 原因、管线编译、热降频 | 可用；C# 不支持（本项目 GDScript） **[公开]** |
| **Godot Monitors** | FPS（1Hz）、`TIME_PROCESS`、draw calls、VRAM、节点/孤儿数 | 单帧分布、GPU pass、overdraw | 可用；部分 monitor release 下为 0；孤儿数 debug-only **[公开]** |
| **Godot Visual Profiler** | 渲染相关 CPU 耗时（按帧/按项；官方警告只测 CPU，不含非渲染逻辑） | GPU 微架构、overdraw、非渲染逻辑；macOS + Compatibility 下不可用 | **本项目 macOS + gl_compatibility：不可用** **[公开]** |
| **Godot `--print-fps`** | 每秒 FPS，stdout | 单帧、p95/p99、归因 | 可用；只适合冒烟/粗筛 **[公开]** |
| **Godot `--benchmark`** | 整次运行耗时，JSON 输出 | 帧分布、峰值 | 可用；不等同于性能审计 **[公开]** |
| **自建逐帧 sampler（建议）** | 每帧 `frame_ms`、draw calls、节点、VRAM、当前命令 | GPU pass、shader 指令、overdraw | 下一轮加 1 个 `tools/audit_spell_vfx.gd`（不改玩法） |
| **RenderDoc** | 逐 draw call 的管线状态、纹理/RT、shader 调试；帧捕获 | 持续热稳定、端到端 jank、引擎逻辑 | 支持 Vulkan/D3D11/D3D12/OpenGL/GLES；**不支持 macOS** **[公开]** |
| **Android GPU Inspector（AGI）** | Android 帧捕获、GPU 计数器、命令/帧缓冲/几何/内存/性能/管线/shader | iOS/桌面；引擎逻辑；热稳定（需另测） | 移动档位可用；Vulkan 或 GLES via ANGLE **[公开]** |
| **Xcode Metal Capture** | Metal 逐 draw call、shader 调试、资源绑定 | OpenGL/GLES；持续热稳定；非 Metal 渲染器 | 本项目 GL Compatibility 用不上；切 Metal 渲染器后可用 **[公开]** |
| **Arm Streamline / Frame Advisor** | Mali GPU 计数器、overdraw、带宽、调用栈 | 非 Arm 设备；引擎逻辑 | 移动档位（Mali）可用 **[公开]** |
| **NVIDIA FrameView / PresentMon** | Windows 逐帧呈现时间、P95/P99、1% low | 引擎归因、GPU pass、移动端 | 桌面 Windows 对照可用 **[公开]** |
| **Unity Profiler** | CPU/GPU/渲染/内存模块、逐帧耗时 | 跨引擎；持续热稳定（需真机） | Unity 项目对照 **[公开]** |
| **Unity Frame Debugger** | 逐 draw call、渲染顺序、批次、重复 pass | GPU 微架构计数器、热稳定 | Unity 项目对照 **[公开]** |
| **Unity Profile Analyzer** | 多帧聚合、Median/Quartile、直方图；CSV 导出 | 内置无 p99；需外部计算 | Unity 项目对照 **[公开]** |
| **Unity VFX Graph Debug Panel** | 每个 system/context 的 CPU/GPU 时间、粒子数、纹理内存 | 目标设备保证；Apple Silicon GPU 时间不可用；面板禁用 instancing | Unity VFX 对照 **[公开]** |
| **Unreal Insights / Timing Insights** | CPU/GPU 轨道、Frames 面板、逐帧 trace | 非 UE 项目；需要 trace 采集 | UE 项目对照 **[公开]** |
| **Unreal `stat unit` / `stat GPU` / ProfileGPU** | Frame/Game/Draw/GPU/RHIT；GPU pass 分解 | 逐 draw call 状态（需 RenderDoc/Insights） | UE 项目对照 **[公开]** |
| **Unreal Niagara Debugger / Scalability** | 粒子 system/emitter 成本、Effect Type 缩放、实例数 | 端到端帧时间（需 stat/Insights） | UE VFX 对照 **[公开]** |
| **Three.js `renderer.info`** | `render.calls`、`triangles`、`geometries`、`textures`、`frame` | GPU pass、shader 指令、热稳定 | Three.js 项目可用 **[公开]** |
| **Spector.js** | WebGL 帧捕获、逐 draw call、状态 | 浏览器外、持续性能 | Three.js 项目可用 **[公开]** |
| **Apple MetricKit / Android Vitals** | 线上 hitch time ratio / 慢帧/冻帧 | 本地逐帧归因、离线复现 | 上线后字段指标；不能替代本地审计 **[公开]** |
| **Android Thermal API / Apple thermalState** | 设备热状态等级 | 具体温度、GPU 频率 | soak 时记录环境 **[公开]** |

### 3.2 本项目的工具现实（重要）

`godot-battle/` 当前配置：

```ini
# godot-battle/project.godot:14-21
window/size/viewport_width=1920
window/size/viewport_height=1080
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

因此：

1. **Godot Visual Profiler 在 macOS + Compatibility 下不可用**（官方文档明确说明“not supported when using the Compatibility renderer on macOS, due to platform limitations”）。**[公开]**
2. **Godot Compatibility 没有 ubershader / 管线预编译**；官方建议的兼容做法是“在加载时把材质、shader、粒子放进视锥显示至少一帧”。**[公开]**
3. **RenderDoc 不支持 macOS**；Xcode GPU Capture 只抓 Metal，不抓 OpenGL。也就是说，本机 macOS + GL Compatibility 没有“逐 draw call 的 GPU 抓帧”标准路径。**[公开]**
4. **可行替代**：
   - 本机：Godot Profiler/Monitors + 逐帧 sampler + A/B 开关（F2/关特效）+ 录屏；对 2D 小项目足以定位“哪一帧、哪一类、哪次施法”。
   - 跨平台补测：同一构建在 Windows/Linux 上用 RenderDoc 抓 GL；或移动 Android 用 AGI/RenderDoc/Streamline。
   - 需要 Metal 级证据时：在实验分支切 Mobile/Forward+（Metal/Vulkan）+ Xcode/AGI，但这改变渲染器，结论不能直接外推到 Compatibility。**[推断]**
5. **GPU 时间缺失时**：用“关闭 VFX/后处理的帧时间差”近似归因，并明确标注是近似值，不是硬件 GPU timer。注意：F2 的“原画”仍会走 `BackBufferCopy` + 全屏 pass；F2 A/B 只测风格分支增量，不测后处理基础成本。要测基础成本，需临时隐藏 `StyleFX`（下一轮工具开关）。**[政策/推断]**

### 3.3 工具选择决策树

```text
先问：是单帧尖峰，还是持续低帧？
├─ 单帧尖峰（hitch）
│  ├─ 首次施法/首次切风格 → 管线编译/资源加载（Godot Compatibility 无预编译）
│  ├─ 每次施法都尖峰 → VFX 峰值（粒子/闪白/overdraw/draw call）
│  └─ skip/2× 后尖峰 → 生命周期错配/节点残留
├─ 持续低帧
│  ├─ CPU 高 → Godot Profiler（脚本）/ Profiler 帧时间
│  ├─ GPU 高（有 GPU timer 的平台）→ RenderDoc/AGI/Xcode/Insights
│  └─ 无法分离 → A/B 开关 + 分辨率降档 + 帧时间差
└─ 长时间越来越差 → soak + 节点/内存/热状态
```

---

## 04 · 审计流程与模板

### 4.1 七步流程

| 步骤 | 动作 | 产出 | 失败处理 |
|---|---|---|---|
| 1 | **定档位**：设备、分辨率、目标 FPS、渲染器 | 档位记录 | 档位不清 → 不测 |
| 2 | **算帧预算**：`1000/FPS`；分配 VFX/后处理/UI 份额 | 预算表 | 预算不成立 → 降档或降目标 |
| 3 | **冻结场景**：seed、阵容、逐回合指令、倍速/skip/画风 | 场景 JSON + 录屏 | 场景不可复现 → 作废 |
| 4 | **采集**：冷启动 1 次、热稳定 3 次、每次 ≥2,000 帧 | 逐帧 CSV | 采样不足 → 补采 |
| 5 | **入库**：按 cast/turn/battle 聚合 p50/p95/p99/worst/hitch/峰值 | 汇总 JSON | 缺指标 → 不通过 |
| 6 | **门禁**：fail-closed；任何 P0 失败或数据缺失 → FAIL | 判定 | 不允许“先过再补” |
| 7 | **回归 + 报告 + 签核**：与基线对比；QA/技术负责人签字 | 报告 + 证据 | 回归超阈值 → 打回 |

### 4.2 设备档位表

| 档位 | 典型设备 | 分辨率 | 目标 FPS | 帧预算 | VFX 份额 | 用途 |
|---|---|---|---|---|---|---|
| **D0** | 开发机 / Intel HD 6000 级核显 | 1920×1080 | 60 | 16.67ms | 30%（5.0ms） | 主基线；最严格 |
| **D1** | 低配桌面/笔记本 | 1280×720 | 60 | 16.67ms | 30%（5.0ms） | 分辨率降档对照 |
| **M1** | 移动中端 | 1280×720 | 30 | 33.33ms | 25%（8.3ms） | 移动主档 |
| **M2** | 移动低端 | 960×540 | 30 | 33.33ms | 20%（6.7ms） | 最低可玩档 |

> 档位不是按“品牌/型号”划分，而是按**实测能否稳定达到目标**划分；首轮基线后重新定档。**[政策]**

### 4.3 帧预算与门禁表

| 门禁 | 60fps（D0/D1） | 30fps（M1/M2） | 级别 | 判定 |
|---|---|---|---|---|
| p95 帧时间 | ≤ 16.7ms | ≤ 33.3ms | P1 | 超 → FAIL |
| p99 帧时间 | ≤ 20.0ms | ≤ 40.0ms | P0 | 超 → FAIL |
| worst frame（cast 内） | ≤ 33.3ms | ≤ 66.7ms | P0 | 超 → FAIL |
| hitch（>2× 预算） | 0 次 / 10 cast | 0 次 / 10 cast | P0 | 有 → FAIL |
| severe hitch（>4× 预算） | 0 次 / 场景 | 0 次 / 场景 | P0 | 有 → FAIL |
| 首放 worst | ≤ 50ms | ≤ 100ms | P1 | 超 → FAIL |
| 热态 worst | ≤ 16.7ms | ≤ 33.3ms | P1 | 超 → FAIL |
| draw calls 增量 | ≤ +40 | ≤ +24 | P1 | 超 → FAIL |
| particles 峰值增量 | ≤ +150 | ≤ +80 | P1 | 超 → FAIL |
| overdraw 增量 | ≤ +3 层 | ≤ +2 层 | P1 | 超 → FAIL |
| nodes 峰值增量 | ≤ +80 | ≤ +48 | P1 | 超 → FAIL |
| VRAM 增量 | ≤ +8MB | ≤ +4MB | P1 | 超 → FAIL |
| 2× 并发峰值比 | ≤ 1.5× 1× | ≤ 1.5× 1× | P0 | 超 → FAIL |
| skip 后 1s 节点 | 基线 ±10 | 基线 ±10 | P0 | 超 → FAIL |
| skip 后孤儿增长 | 0 | 0 | P0 | >0 → FAIL |
| 后处理 p95 增量 | ≤ 3ms | ≤ 5ms | P2 | 超 → 警告/需解释 |
| 30 分钟 p95 退化 | ≤ 10% | ≤ 15% | P1 | 超 → FAIL |
| 数据完整性 | 所有必填字段齐全 | 同左 | P0 | 缺 → FAIL |

**Fail-closed 规则**：没有测量数据 = P0 失败；工具不可用 ≠ 自动豁免；豁免必须写明替代证据、风险、批准人、有效期。**[政策]**

### 4.4 统计口径：p99 不能按“单次施法”算

- 60fps 下，1 秒的 cast 只有约 60 帧；p99 只对应不到 1 帧，等同于 worst frame，噪声极大。**[公开]**（NVIDIA 百分位方法：高百分位需要足够样本）
- **正确做法**：
  - 对 **整段场景**（≥2,000 帧，约 33 秒 @60fps）计算 p95/p99；
  - 对 **单次 cast** 报告 `worst_ms`、`frames_over_budget`、`median_ms`，不要报 p99；
  - 对 **回合窗口** 报告 `turn_worst_ms`、`hitch_count`；
  - 报告注明百分位定义（线性插值/最近秩）、采样时长、是否含加载/菜单。
- 3 次重复取中位数；若 p95 的 run-to-run 差异 >10%，本次数据作废。**[政策]**

### 4.5 单法术预算卡模板（可复制到技能数据旁边）

```yaml
skill: thunder_storm
visual_id: thunder
targets_max: 99
device_tier: D0            # 1920x1080 / 60fps
budget:
  vfx_peak_ms: 5.0
  draw_calls_delta: 40
  particles_peak: 150
  overdraw_delta: 3
  nodes_delta: 80
  vram_delta_mb: 8
  first_cast_worst_ms: 50
  repeat_cast_worst_ms: 16.7
  audio_steals: 0
measured:
  p50_ms: null
  p95_ms: null
  p99_ms: null
  worst_ms: null
  hitches: null
  draw_calls_peak: null
  particles_peak: null
  nodes_peak: null
  vram_delta_mb: null
  verdict: UNMEASURED
```

### 4.6 报告模板

```markdown
# VFX 性能审计报告 · <任务号/技能/场景>

## 1. 结论
- 判定：PASS / FAIL / PASS WITH WAIVERS
- 一句话：<最坏帧/瓶颈/是否放行>
- 失败项：<P0/P1 列表；无则写“无”>
- 豁免：<项/理由/替代证据/批准人/有效期>

## 2. 环境
- 构建：<git hash / Godot 版本 / debug or release>
- 设备：<机型 / CPU / GPU / 内存 / OS / 驱动>
- 渲染：<renderer / 分辨率 / vsync / 窗口模式>
- 电源/热：<插电 / 高性能 / 起始 thermal state>

## 3. 场景
- seed / 遭遇 / 阵容 / 指令脚本路径
- 倍速 / skip 时机 / 画风 / 采样帧数 / 重复次数

## 4. 数据
| 指标 | 基线 | 本次 | 差值 | 门槛 | 判定 |
|---|---|---|---|---|---|
| p95 | | | | | |
| p99 | | | | | |
| worst | | | | | |
| hitch | | | | | |
| draw calls | | | | | |
| particles | | | | | |
| nodes | | | | | |
| VRAM | | | | | |

## 5. 归因
- 主要瓶颈：<CPU/GPU/编译/带宽/生命周期>
- 证据：<CSV 行号 / 截图 / 抓帧 / A/B 对比>
- 未解释项：<必须写明>

## 6. 证据附件
- 原始 CSV：<路径>
- 汇总 JSON：<路径>
- 截图/GIF/视频：<路径>
- 复现命令：<完整命令>
```

**汇总 JSON 模板**

```json
{
  "schema": "vfx-audit/v1",
  "task": "T-20261121-010",
  "build": "godot 4.6.stable.official.89cea1439 / <git-hash>",
  "device": {"model": "dev-mac", "gpu": "Intel HD 6000", "os": "macOS 12", "driver": "system"},
  "render": {"renderer": "gl_compatibility", "resolution": "1920x1080", "vsync": false},
  "scenario": {"id": "S2_aoe_thunder_storm", "seed": 20261024, "speed": 1.0, "style": 0, "skip_at_s": null},
  "sample": {"frames": 2400, "warmup_casts": 2, "measured_casts": 10, "runs": 3},
  "metrics": {
    "frame_ms": {"p50": 0, "p95": 0, "p99": 0, "worst": 0, "hitches_over_2x": 0, "severe_over_4x": 0},
    "draw_calls_peak": 0,
    "particles_peak": 0,
    "nodes_peak": 0,
    "orphans_after_skip": 0,
    "vram_delta_mb": 0,
    "first_cast_worst_ms": 0,
    "style_delta_ms": 0,
    "speed_overlap_ratio": 0
  },
  "verdict": "UNMEASURED",
  "failures": [],
  "waivers": [],
  "evidence": []
}
```

### 4.7 回归对比

| 指标 | 允许回归 | 处理 |
|---|---|---|
| p95 | ≤ 10% | 超 → FAIL |
| p99 | ≤ 15% | 超 → FAIL |
| worst | ≤ 15% | 超 → FAIL |
| draw calls 峰值 | ≤ 10% | 超 → FAIL |
| particles 峰值 | ≤ 10% | 超 → FAIL |
| nodes 峰值 | ≤ 10% | 超 → FAIL |
| VRAM | ≤ 10% | 超 → FAIL |
| 首放 worst | ≤ 20% | 超 → P1 FAIL |
| 2× 并发比 | ≤ 10% | 超 → P0 FAIL |

> 回归必须同设备、同场景、同采样协议；跨设备/跨渲染器的对比只能作为参考，不能作为放行依据。**[政策]**

---

## 05 · 引擎映射与可移植契约

### 5.1 引擎能力映射

| 能力 | Godot 4.x | Unity | Unreal | Three.js |
|---|---|---|---|---|
| 帧时间 | 自建 `Time.get_ticks_usec()` / `--print-fps`（1Hz） | Profiler / Frame Timing Stats | `stat unit` / Insights | `requestAnimationFrame` 时间戳 / Performance API |
| CPU 脚本 profiler | Godot Profiler（Inclusive/Self） | Profiler CPU Usage | Insights CPU track | Chrome DevTools Performance |
| GPU 时间 | Visual Profiler（Forward+/Mobile；macOS Compatibility 不可用） | Profiler GPU module / Frame Debugger | `stat GPU` / ProfileGPU / Insights GPU track | 无内建；`EXT_disjoint_timer_query_webgl2`（可用性因浏览器/设备） |
| Draw calls | `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | Frame Debugger / Profiler Rendering | `stat RHI` / Insights | `renderer.info.render.calls` |
| Overdraw | 无专用内建视图；A/B + GPU capture | Scene View Overdraw / Frame Debugger | Shader Complexity / GPU Visualizer / RenderDoc | Spector.js / RenderDoc（WebGL 捕获有限） |
| 粒子计数 | `GPUParticles2D.amount` + 自建存活计数 | VFX Graph debug panel / ParticleSystem | Niagara Debugger / `stat Niagara` | 自建计数 |
| Shader 预热 | Compatibility 无预编译；视锥显示 1 帧 | ShaderVariantCollection / VFX Graph PreWarm | PSO precaching / bundled PSO cache | `renderer.compile()` / `compileAsync()` |
| 异步加载 | `ResourceLoader.load_threaded_*` | Addressables / AsyncOperation | Async Loading / Soft References | `fetch` + ArrayBuffer / GLTFLoader |
| 场景回放 | 确定性核心 + 录像/回放 | Playable / 录制工具 | Replay / Automation | 自建输入回放 |
| CI 门禁 | 自建 sampler + 阈值脚本 | Unity Test Framework + Profiler API | Automation + Insights | Playwright + Performance API |

### 5.2 引擎无关契约（必须跨引擎保持一致）

以下内容不应随引擎改变；换引擎时只换“实现”，不换“定义”：

1. **审计单元**：cast / turn / battle / soak。
2. **指标定义**：`frame_ms`、p50/p95/p99、worst、hitch、draw calls 增量、particles 峰值、overdraw 增量、nodes 峰值、VRAM 增量、首放/热态、2× 并发比、skip 残留。
3. **场景脚本 schema**：seed、阵容、逐回合指令、倍速、skip、画质、分辨率、采样次数。
4. **预算与门禁**：按档位的帧预算与 fail-closed 规则。
5. **统计口径**：整段算 p95/p99；单 cast 只报 worst/超预算帧数；3 次重复取中位数；差异 >10% 作废。
6. **报告 schema**：环境、场景、原始数据、汇总、判定、证据、豁免。

### 5.3 各引擎最小可行审计方案（MVP）

| 引擎 | MVP 方案 | 需要补的抓帧/计数器 | 备注 |
|---|---|---|---|
| **Godot 4.x** | 自建 sampler（frame_ms + 4 个 monitors）+ 固定场景 + 3 次重复 | Windows/Linux RenderDoc；Android AGI/RenderDoc；macOS GL 无标准抓帧 | 本项目路线；先做 sampler |
| **Unity** | Profiler（CPU/GPU/Rendering）+ Frame Debugger + Profile Analyzer CSV | RenderDoc/AGI（移动）；Xcode Metal（iOS） | Profile Analyzer 无 p99，需 CSV 外算 |
| **Unreal** | `stat unit` + `stat GPU` + Insights trace + Niagara Debugger | RenderDoc/AGI；PSO 验证日志 | Niagara 的 Effect Type 本身可用于档位缩放 |
| **Three.js** | `renderer.info` + Performance 面板 + 固定场景 | Spector.js；可选 timer query | 无内建 profiler；CI 用 Playwright 采帧 |

---

## 06 · 公开资料与回合制案例

### 6.1 回合制 / 重 VFX 手游：哪些有可核验公开资料

| 游戏 | 可核验公开资料 | 与审计的相关性 | 不能证明什么 |
|---|---|---|---|
| **梦幻西游手游** | 网易游戏学堂公开课《梦幻西游手游客户端优化经验》（2015，唐文良/余林路）：客户端架构、资源方案与资源优化、**分帧优化**（协议量大时曾造成卡顿，后续持续分帧优化） | 回合制 MMO 的**资源/加载层**与**分帧**实践；说明“协议/事件洪峰”会造成卡顿，需要用预算与分帧治理 | 不是 VFX 粒子/overdraw 专项；数据较旧（2015），不能代表现代移动 GPU |
| **Fate/Grand Order** | CEDEC 2017 开发团队 session 的公开报道：战斗角色攻击/宝具动作、2D 角色部件自上线以来大幅增加，part/纹理工作量翻倍以上 | 说明**内容量增长**会持续推高表现成本；审计必须可重复、可回归 | 该报道**不是**粒子优化技术分享；没有 VFX 预算数字 |
| **第七史诗（Epic Seven）** | Smilegate Newsroom 对 Super Creative 的官方访谈（2018）：自研 **YUNA** 移动端引擎；目标 15 秒进主界面、应用内“零加载”、4K 下加载 <1 秒；强调资源优化、低配适配、**抑制发热/降频** | 回合制 2D 手游把**加载/资源/热**作为一等公民；与“首放 hitch / soak / 热稳定”审计目标一致 | 没有公开 GPU 帧时间、粒子预算或审计流程；官方说法是产品目标，不是测量方法 |
| **崩坏：星穹铁道** | 截至 2026-11-21，未检索到可核验的官方 VFX 性能审计/技术分享；社区文章声称“魔改 Unity、DOTS 粒子、动态分辨率”等，但来源为评测/论坛，**不采信为事实** | 只能作为“重 VFX 手游需要类似协议”的动机，不能作为方法依据 | 没有官方数据；不引用社区数字 |
| **阴阳师** | 截至 2026-11-21，未检索到网易官方客户端性能优化技术分享；可见资料多为玩家画质设置/模拟器教程 | 玩家侧“战斗特效精简/仅己方/60fps 上限”说明回合制确实用**特效档位**做产品级降载 | 不是官方技术资料；不能证明其内部审计流程 |

**检索结论**：回合制游戏的公开资料以**产品目标/资源优化/分帧/热降频**为主，**很少公开 VFX 审计协议、预算数字或 GPU 抓帧方法**。因此本协议的指标与门槛主要来自**引擎/GPU 厂商文档 + 通用游戏性能工程方法 + 本项目代码推导**，而不是某家公司的内部流程。**[推断]**

### 6.2 通用来源（访问日期：2026-11-21）

| # | 来源 | URL | 支撑内容 | 类型 |
|---|---|---|---|---|
| 1 | Godot `Performance` 类文档 | https://docs.godotengine.org/en/stable/classes/class_performance.html | FPS 1Hz 更新；`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`；VRAM/纹理/缓冲；节点/孤儿数；release 下部分 monitor 为 0 | 官方 |
| 2 | Godot Debugger panel | https://docs.godotengine.org/en/stable/tutorials/debug/debugger_panel.html | Profiler / Monitors / Visual Profiler；**macOS + Compatibility 下 Visual Profiler 不支持** | 官方 |
| 3 | Godot The Profiler | https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html | 帧时间/物理时间/Idle；Inclusive vs Self；“粒子/视觉特效可能导致尖峰” | 官方 |
| 4 | Godot 管线编译 stutter | https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html | Compatibility 无 ubershader/预编译；Canvas 首次绘制；官方兼容做法：视锥内显示 ≥1 帧 | 官方 |
| 5 | Godot 命令行 | https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html | `--print-fps`、`--benchmark`、`--quit-after`、`--max-fps`、`--write-movie` | 官方 |
| 6 | Godot `GPUParticles2D` | https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html | `amount`/`amount_ratio`/`lifetime` 的发射率；`preprocess`；one_shot 用 `restart()`；`fixed_fps`；`local_coords` | 官方 |
| 7 | Godot 后台加载 | https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html | `load_threaded_request/get_status/get` | 官方 |
| 8 | Unity Profiler | https://docs.unity3d.com/Manual/Profiler.html | CPU/GPU/渲染/内存模块；设备 vs 编辑器 | 官方 |
| 9 | Unity Frame Debugger | https://docs.unity3d.com/Manual/FrameDebugger.html | 逐 draw call、渲染顺序、批次、重复 pass | 官方 |
| 10 | Unity Profile Analyzer | https://docs.unity3d.com/Packages/com.unity.performance.profile-analyzer@1.2/manual/profile-analyzer-window.html | 多帧聚合、Median/Quartile、直方图；**无内建 p99**；CSV 导出 | 官方 |
| 11 | Unity VFX Graph Performance | https://docs.unity3d.com/Packages/com.unity.visualeffectgraph@17.7/manual/performance-debug-panel.html | 每 system/context CPU/GPU 时间、粒子数、纹理内存；面板禁用 instancing；Apple Silicon GPU 时间不可用 | 官方 |
| 12 | Unity ShaderVariantCollection | https://docs.unity.com/en-us/engine/6000.6/script-reference/unityengine/shadervariantcollection | Shader warmup / WarmUp / WarmUpProgressively | 官方 |
| 13 | Unity Learn：移动粒子优化 | https://learn.unity.com/tutorial/optimizing-particle-effects-for-mobile-applications | `fillrate ≈ 屏幕像素 × shader 复杂度 × overdraw`；减少粒子数/大小/层数；避免大量 collider | 官方教程 |
| 14 | Unity + Arm 移动性能剖析 | https://unity.com/cn/blog/games/tackling-profiling-for-mobile-games-with-unity-and-arm | Profiler + Frame Debugger 定位移动端后处理/全分辨率成本 | 官方博客 |
| 15 | Unreal Timing Insights | https://dev.epicgames.com/documentation/en-us/unreal-engine/timing-insights-in-unreal-engine-5 | CPU/GPU 轨道、Frames 面板、GPU trace | 官方 |
| 16 | Unreal Stat Commands | https://dev.epicgames.com/documentation/en-us/unreal-engine/stat-commands-in-unreal-engine | `stat unit`（Frame/Game/Draw/GPU/RHIT）、`stat GPU` | 官方 |
| 17 | Unreal Optimizing Niagara | https://dev.epicgames.com/documentation/unreal-engine/optimizing-niagara?application_version=5.7 | Niagara 性能测量、Scalability、Systems as a Service | 官方 |
| 18 | Unreal Niagara Scalability | https://dev.epicgames.com/documentation/unreal-engine/scalability-and-best-practices-for-niagara | Effect Type 按平台/档位缩放；实例/emitter 开销；Lightweight Emitters | 官方 |
| 19 | Epic：Shader stuttering / PSO | https://dev.epicgames.com/community/learning/tutorials/xjzE/unreal-engine-epic-for-indies-game-engines-shader-stuttering-ue-s-solution | PSO 预缓存/precaching；运行时编译 hitch | 官方社区教程 |
| 20 | RenderDoc 文档 | https://renderdoc.org/docs/ | 逐 draw call 抓帧；支持 Vulkan/D3D11/D3D12/OpenGL/GLES；平台 Windows/Linux/Android/Switch | 官方 |
| 21 | Android GPU Inspector | https://developer.android.com/agi | Android GPU 系统/帧剖析；Vulkan；GLES via ANGLE | 官方 |
| 22 | AGI Frame Profiler | https://developer.android.com/agi/frame-trace/frame-profiler | Commands/Framebuffer/Geometry/Memory/Performance/Pipeline/Shader 面板 | 官方 |
| 23 | Xcode Metal Capture | https://developer.apple.com/documentation/Xcode/Capturing-a-Metal-workload-in-Xcode | Metal 逐 draw call、shader 调试、GPU trace；仅 Metal | 官方 |
| 24 | Arm GPU Best Practices | https://support.arm.com/documentation/101897/0304/Optimization-basics/Optimization-process | 预算（帧时间/三角形/带宽）、overdraw 2.5× 假设、Streamline/Frame Advisor | 厂商 |
| 25 | NVIDIA：百分位与 stutter | https://developer.nvidia.com/content/analysing-stutter-%e2%80%93-mining-more-percentiles-0 | P95/P99 定义；1% low 的多种算法；高百分位需要足够帧数 | 厂商 |
| 26 | NVIDIA FrameView 指南 | https://www.nvidia.com/content/dam/en-zz/Solutions/GeForce/technologies/frameview/FrameView_Beta_User_Guide.pdf | Present/Display 时间、Render99、排除加载/菜单 | 厂商 |
| 27 | Android Vitals：慢渲染 | https://developer.android.com/google/play/vitals/render | 慢帧 >16ms、冻帧 >700ms；不适用于 Unity/Unreal/Vulkan/GL 应用（其渲染统计不采集） | 官方 |
| 28 | Android 热状态 API | https://developer.android.com/reference/android/os/PowerManager#getCurrentThermalStatus() | THERMAL_STATUS_NONE/LIGHT/MODERATE/SEVERE/CRITICAL/EMERGENCY/SHUTDOWN | 官方 |
| 29 | Apple MetricKit hitch time | https://developer.apple.com/documentation/metrickit/mxanimationmetric/hitchtimeratio | 动效 hitch 时间占比；感知修正 | 官方 |
| 30 | Apple `thermalState` | https://developer.apple.com/documentation/foundation/processinfo/thermalstate | nominal/fair/serious/critical；建议降粒子/纹理/帧率 | 官方 |
| 31 | GDC 2020：移动 VFX | https://www.gamedeveloper.com/programming/video-achieving-high-quality-game-vfx-on-mobile-devices | 移动端高质量 VFX 的实践分享（Andy Saia / Level Ex） | 公开演讲 |
| 32 | GDC Vault：ARM 移动特效优化 | https://gdcvault.com/play/1018165/Optimized-Effects-for-Mobile-Devices | 移动端特效优化（ARM） | 公开演讲 |
| 33 | 网易游戏学堂：梦幻西游手游客户端优化经验 | https://game.academy.163.com/promotion/2015/12/14/17693_586343.html | 客户端架构、资源优化、分帧优化历程 | 公开课程（2015） |
| 34 | Smilegate Newsroom：YUNA 引擎 | https://newsroom.smilegate.com/eng/Epic_Seven_YUNA_Engine_EN | 移动端自研引擎；15 秒进主界面、零加载、热/降频目标 | 官方访谈（2018） |
| 35 | CEDEC 2017 FGO 报道 | https://www.inside-games.jp/article/2017/08/31/109451.html | 战斗动作/2D 部件增长；不是粒子优化分享 | 媒体报告（2017） |
| 36 | Three.js WebGLRenderer | https://threejs.org/docs/#api/en/renderers/WebGLRenderer | `renderer.info`（calls/triangles/geometries/textures/frame） | 官方 |
| 37 | Spector.js | https://spector.babylonjs.com/ | WebGL 帧捕获 | 开源工具 |

### 6.3 明确标注的推断清单

以下结论不是公开事实，落地时必须用本项目实测确认：

| 推断 | 依据 | 验证方式 |
|---|---|---|
| 2× 倍速下 VFX 会重叠 | `playback_speed` 只缩放 `wait()`；Tween/粒子走引擎时间 | S3 场景测并发峰值/节点峰值 |
| additive 材质会打断 Godot 2D 批处理 | Godot 2D 批处理在材质/混合变化时打断（社区资料；Compatibility 的 2D 批处理行为需实测） | S1/S2 测 draw calls 增量 |
| 全屏 Sobel 后处理在本机可能 >1ms | 9 次纹理采样/像素 + BackBufferCopy；Intel HD 6000 填充率有限 | S4 A/B 测 `style_delta_ms` |
| 首放会触发 2D pipeline 编译 | Godot 文档：Canvas 首次绘制编译；Compatibility 无预编译 | S6 首放 vs 热态 |
| 每 cast 创建/释放节点会造成峰值/碎片 | 代码无池化；Tween/粒子/Line2D 逐次创建 | S5 节点/孤儿/内存 |
| 1.5× 并发比是合理缓冲 | 政策推导，不是行业标准 | 首轮基线后校准 |
| 阈值表中的具体毫秒/数量 | 由帧预算、Arm overdraw 2.5× 参考、Unity fillrate 公式推导 | 首轮基线后校准 |

### 6.4 检索与引用限制

- GDC Vault 部分演讲需付费/登录，本文只引用公开页面/摘要，不复制幻灯片。
- 中文回合制游戏的官方技术分享稀缺；未找到可核验资料的项目（星穹铁道、阴阳师）明确标注“未检索到”，不拿社区文章冒充官方。
- 厂商文档会随版本变化；本文以 2026-11-21 访问时的 stable 文档为准，Godot 项目实际版本为 4.6。
- 本文没有复制任何游戏素材；所有代码/路径均为本项目自有内容。

---

## 07 · 落地 `godot-battle/`：下一轮可直接执行

### 7.1 当前事实（用于审计定位）

| 事实 | 位置 | 审计含义 |
|---|---|---|
| GL Compatibility、1920×1080 基准 | `project.godot:14-21` | 无 ubershader/管线预编译；macOS Visual Profiler 不可用 |
| 3v4、默认遭遇 `enc_bamboo_01` | `battle_session.gd`、`data/encounters/enc_bamboo_01.tres` | AoE 最坏 4 目标 |
| seed 默认 `20261024` | `battle_scene.gd:92` / `battle_session.gd:15` | 可复现的天然入口 |
| 1×/2× 倍速只缩放 `wait()` | `battle_context.gd:34-36` / `battle_hud.gd:211-216` | 2× 下 VFX 生命周期不缩放 |
| skip 设 `playback_speed=1000`、清队列、generation++ | `battle_sequencer.gd:56-69` | 旧 tween/粒子可能残留 |
| 顿帧 `Engine.time_scale=0.05` 持续 0.12s | `damage_command.gd:4-5,59-65` | 多目标 AoE 连续顿帧；VFX tween 也被放慢 |
| 粒子数在 `_burst` 内翻倍 | `vfx_factory.gd:360` | 配置值 ≠ 实际峰值 |
| 全屏闪白 1920×1080 ColorRect | `vfx_factory.gd:320-331` | 多目标叠加 overdraw |
| F2 后处理：BackBufferCopy + 全屏 9-tap Sobel | `style_post_process.gd:30-37` / `style_post.gdshader:42-57` | 后处理 A/B 必须单列 |
| SFX 池 8 个、轮询 | `audio_director.gd:8,52-59` | AoE 多段可能抢占 |
| 无 VFX 池、无性能采样工具 | 代码审阅 | 下一轮需加 1 个审计工具（不改玩法） |

### 7.2 下一轮审计工具（建议新增 1 个文件，本轮不建）

> 本轮遵守“只调研/文档，不改游戏代码”，因此不在 `godot-battle/` 新增文件。下一轮由 `game-engineer` 新增 `godot-battle/tools/audit_spell_vfx.gd`，只读运行，不改玩法逻辑。默认由操作者按场景脚本手动施法；加 `--auto` 可跑自动战斗基线。

**最小 sampler 骨架**（示意；实际实现需按 `BattleSession`/`BattleSequencer` API 调整）：

```gdscript
extends SceneTree
# 只读审计：加载战斗场景，逐帧记录时间/计数器/当前命令，输出 CSV。
# 运行（需要有窗口，不能 headless）：
# godot --path godot-battle --resolution 1920x1080 --print-fps \
#   -s tools/audit_spell_vfx.gd

class Sampler extends Node:
    var seq: BattleSequencer
    var out_path := "user://spell_vfx_audit.csv"
    var _last_usec := 0
    var _rows: Array[PackedStringArray] = []

    func _ready() -> void:
        _last_usec = Time.get_ticks_usec()
        set_process(true)

    func _process(_delta: float) -> void:
        var now := Time.get_ticks_usec()
        var frame_ms := float(now - _last_usec) / 1000.0
        _last_usec = now
        var cmd: BattleCommand = seq.current_command if seq != null else null
        var tag := ""
        if cmd != null and cmd.get_script() != null:
            tag = String(cmd.get_script().get_global_name())
        _rows.append(PackedStringArray([
            str(now / 1000), "%.3f" % frame_ms, tag,
            str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
            str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
            str(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
        ]))
        if _rows.size() % 600 == 0:
            _flush()   # 定期落盘，避免异常退出丢数据

    func _exit_tree() -> void:
        _flush()

    func _flush() -> void:
        if _rows.is_empty():
            return
        var f := FileAccess.open(out_path, FileAccess.WRITE)
        if f == null:
            push_error("AUDIT_CSV_OPEN_FAIL: " + out_path)
            return
        f.store_line("usec,frame_ms,command,draw_calls,nodes,vram_bytes")
        for row in _rows:
            f.store_csv_line(row)
        f.close()
        print("AUDIT_CSV=", ProjectSettings.globalize_path(out_path), " rows=", _rows.size())

func _initialize() -> void:
    var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
    scene.start_auto_mode = OS.get_cmdline_user_args().has("--auto")  # 默认手动/脚本化施法；加 --auto 跑自动战斗基线
    root.add_child(scene)
    await process_frame
    var sampler := Sampler.new()
    sampler.name = "SpellVfxSampler"
    sampler.seq = scene.get_node("BattleSequencer")
    var args := OS.get_cmdline_user_args()
    var out_idx := args.find("--out")
    if out_idx >= 0 and out_idx + 1 < args.size():
        sampler.out_path = String(args[out_idx + 1])
    root.add_child(sampler)
    var session: BattleSession = scene.get_node("BattleSession")
    session.battle_finished.connect(func(_outcome: int) -> void:
        sampler._flush()
        quit(0)
    )
```

**注意**：

- headless 下 `VFXFactory.visuals_enabled=false`，不会创建粒子；性能审计**必须**有窗口/真实渲染。**[代码事实]**
- `Performance.OBJECT_ORPHAN_NODE_COUNT` 仅 debug build 有效；`MEMORY_STATIC` 在 release 中不可用。**[公开]**
- 该 sampler 只是起点；要精确到“单次施法”，需在 `action_start`/`damage` 命令边界打 marker（下一轮工程改动，约 10 行，不改玩法）。**[推断]**

### 7.3 三个优先验证场景（按顺序做）

#### P1 · 单体大招：`fire_spell`（烈火咒）

- **目的**：建立单法术预算卡；首放 vs 热态；弹道 + 命中双重特效。
- **步骤**：
  1. 启动战斗，选青鸾（`mage_qingluan`），对 `boss_fox` 施放 `fire_spell`。
  2. 1× 速度，原画（F2 切换确认 `原画`）。
  3. 空场基线 5s → 施法 → 结束后 3s。
  4. 同一场战斗重复 10 次（MP 不足则重开，同 seed）；前 2 次作废。
  5. 重启应用，重复 1 次，记录首放。
- **采集**：`frame_ms`、draw calls、nodes、VRAM、当前命令；录屏 1 段。
- **通过**：首放 worst ≤50ms；热态 worst ≤16.7ms；峰值增量符合预算卡；无 >33.3ms 帧。
- **重点观察**：弹道拖尾 72 粒子 + 命中 64/28 粒子 + 屏幕是否暴击闪白；首放是否明显高于第 2 次。

#### P2 · AoE 多段：`thunder_storm`（雷霆万钧）

- **目的**：最坏叠加；4 目标同时雷击 + 全屏闪白；后处理 A/B。
- **步骤**：
  1. 青鸾对全体敌人施放 `thunder_storm`；1×；原画。
  2. 重复 10 次；记录每次 cast 的峰值。
  3. F2 切卡通渲染，重复 5 次；再切水墨，重复 5 次。
  4. 1280×720 重复 5 次（分辨率降档对照）。
- **采集**：峰值 draw calls/particles/nodes/overdraw 估算；`style_delta_ms`；每帧最坏。
- **通过**：单 cast draw calls 增量 ≤+40（D0）；无 >33.3ms 帧；后处理 p95 增量 ≤3ms；`style_delta_ms` 超阈值时需解释。
- **重点观察**：4 个 `screen_flash` 是否同帧叠加；4 个目标是否同帧触发 `DamageCommand`；音效请求是否超过 8 个（会出现抢占/截断）。

#### P3 · 倍速连发：`sweep`（横扫千军）+ 2× + skip

- **目的**：生命周期错配；并发峰值；skip 残留。
- **步骤**：
  1. 剑客（`hero_swordsman`）对 3 个敌人施放 `sweep`；2×。
  2. 连续 3 回合重复；第 2 回合在 cast 开始后 0.4s 触发 `skip`（HUD「跳过本回合」）。
  3. 重复 5 组；每组记录 1× 对照。
  4. skip 后 100ms、1s、3s 各采一次节点/孤儿数，并截图。
- **采集**：2× 并发峰值 / 1× 并发峰值；skip 后节点/孤儿；输入延迟；帧时间。
- **通过**：2× 并发比 ≤1.5×；skip 后 1s 节点回到基线 ±10；孤儿 0 增长；无 >33.3ms 帧；skip 到可交互 ≤100ms。
- **重点观察**：`playback_speed=1000` + `_generation` 切换后，旧的 Tween/粒子/Line2D 是否继续播放；闪白是否残留；顿帧是否把 2× 变成“更慢”。

### 7.4 采样协议（可直接执行）

| 项 | 规定 |
|---|---|
| 预热 | 2 次 cast 或 2 场战斗；不计入统计 |
| 单场景帧数 | ≥2,000 帧（60fps ≈ 33s；30fps ≈ 67s） |
| 重复 | 3 次，取中位数；报告 min/max |
| 有效性 | 两次运行 p95 差异 ≤10%；否则作废 |
| 冷/热 | 冷启动首放单独 1 次；热态在 3 次重复内 |
| 显示 | vsync 关（原始帧时间）+ vsync 开（节奏）各一次 |
| 电源 | 插电、高性能模式、关闭后台；移动端记录起始 thermal state |
| 采样工具 | 自建 sampler（逐帧 CSV）+ `--print-fps`（交叉校验） |
| 截图/录屏 | 每个场景至少 1 张关键帧截图或 5s 录屏 |
| 数据路径 | `docs/perf/<task>/<scenario>_runN.csv` + `summary.json` |

**命令示例（零改动粗筛）**：

```bash
# 粗筛：跑完整自动战斗，stdout 每秒 FPS
godot --path godot-battle --resolution 1920x1080 --print-fps \
  -s tools/smoke_presentation.gd

# 完整 HUD 输入战斗（真实鼠标路径；需要窗口）
godot --path godot-battle --resolution 1920x1080 --print-fps \
  -s tools/smoke_hud_input.gd

# 分辨率降档对照
godot --path godot-battle --resolution 1280x720 --print-fps \
  -s tools/smoke_hud_input.gd

# 正式采样（下一轮工具存在后）
# 不加 --auto：操作者按场景脚本手动施法；加 --auto：自动战斗基线。
godot --path godot-battle --resolution 1920x1080 --print-fps \
  -s tools/audit_spell_vfx.gd -- --scenario docs/perf/scenarios/S2_aoe_thunder_storm.json \
  --out user://S2_run1.csv
```

> `--print-fps` 只适合粗筛/冒烟，不能替代逐帧 CSV。**[公开]**

### 7.5 本项目建议阈值（首轮政策值）

| 档位 | 分辨率 / FPS | p95 (ms) | p99 (ms) | worst (ms) | hitch | 首放 worst (ms) | draw calls Δ | particles Δ | overdraw Δ | nodes Δ | VRAM Δ | style Δ (ms) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **D0** | 1920×1080 / 60 | 16.7 | 20.0 | 33.3 | 0/10 cast | 50 | +40 | +150 | +3 | +80 | 8MB | 3ms |
| **D1** | 1280×720 / 60 | 16.7 | 20.0 | 33.3 | 0/10 cast | 50 | +32 | +120 | +3 | +64 | 6MB | 3ms |
| **M1** | 1280×720 / 30 | 33.3 | 40.0 | 66.7 | 0/10 cast | 100 | +24 | +80 | +2 | +48 | 4MB | 5ms |
| **M2** | 960×540 / 30 | 33.3 | 40.0 | 66.7 | 0/10 cast | 100 | +16 | +48 | +2 | +36 | 3MB | 5ms |

> 所有数字均为 **[政策]**，不是行业标准；首轮基线后按实测余量校准。校准原则：新阈值 = 基线 p95 + 20% 余量，且不低于上表；不允许为了让当前实现通过而放宽 P0。

### 7.6 报告必填字段（下一轮验收用）

- [ ] 构建哈希 / Godot 版本 / debug or release
- [ ] 设备（CPU/GPU/内存/OS/驱动）/ 电源模式 / thermal state
- [ ] renderer / 分辨率 / vsync / 窗口模式
- [ ] seed / 遭遇 / 阵容 / 场景脚本路径
- [ ] 1×/2×/skip/画风/F2 状态
- [ ] 预热次数 / 采样帧数 / 重复次数
- [ ] frame_ms p50/p95/p99/worst/hitch/severe hitch
- [ ] 首放 vs 热态 worst
- [ ] draw calls / particles / overdraw / nodes / VRAM 峰值与增量
- [ ] 2× 并发比 / skip 残留 / 输入延迟
- [ ] 原始 CSV + 汇总 JSON + 截图/录屏
- [ ] 判定（PASS/FAIL/WAIVERS）+ 失败项 + 归因 + 未解释项

### 7.7 下一轮执行清单（勾选）

- [ ] **S0 基线**：空场/指令阶段 5s，D0 1080p，vsync 关，记录 p50/p95。
- [ ] **S1 单体**：`fire_spell` ×10，首放 + 热态，原画。
- [ ] **S2 AoE**：`thunder_storm` ×10，4 目标，记录峰值。
- [ ] **S2 后处理**：F2 卡通/水墨各 ×5，算 `style_delta_ms`。
- [ ] **S2 降档**：1280×720 ×5，比较分辨率收益。
- [ ] **S3 倍速**：`sweep` 2× ×3 回合，记录并发峰值。
- [ ] **S3 skip**：cast 后 0.4s skip ×5，记录 1s/3s 节点与孤儿。
- [ ] **S5 soak**：自动战斗 10 回合 ×3 场（或 30 分钟），记录 p95 退化。
- [ ] **S6 冷启动**：重启后首放 1 次，记录首放 hitch。
- [ ] **回归**：与基线对比 p95/p99/worst/draw calls/nodes/VRAM。
- [ ] **报告**：按 §4.6 输出 MD + JSON + CSV + 截图；QA/技术负责人签字。

### 7.8 不要做的事

- ❌ 用平均 FPS 或 `--print-fps` 的单秒值当性能结论。
- ❌ 在 headless 下测 VFX 性能（本项目 headless 不创建 VFX）。**[代码事实]**
- ❌ 用编辑器内的帧率代表发布构建/真机（编辑器有额外开销）。
- ❌ 跨设备/跨渲染器直接比较绝对值。
- ❌ 只测 1×，不测 2×/skip。
- ❌ 只测单法术，不测 AoE/连续回合。
- ❌ 只在冷机测，不做 20–30 分钟 soak（移动端）。
- ❌ 用一次运行下结论；至少 3 次，差异 >10% 作废。
- ❌ 为了让当前实现通过而放宽 P0 门槛；没有数据就写“未测”，不要编数。

---

## 08 · 局限

1. **本轮没有真机采样**：本文是协议与工具方法，所有阈值是政策值；`godot-battle/` 未新增/修改代码或资产，因此没有“本项目实测 p95/p99”。**[待测]**
2. **公开资料不对称**：引擎/GPU 厂商文档充足；回合制游戏的官方 VFX 审计流程极少公开。星穹铁道、阴阳师未检索到可核验官方技术分享，不引用社区数字。**[检索结论]**
3. **工具缺口**：macOS + GL Compatibility 下 Godot Visual Profiler 不可用、RenderDoc 不支持 macOS、Xcode 只抓 Metal；本机无法做逐 draw call 的 GPU 抓帧。跨平台补测或切渲染器都会改变结论的适用范围。**[公开/推断]**
4. **帧时间 ≠ 感知**：p99 低不代表没有可感知卡顿；需要结合 hitch 分布、镜头/闪白、输入延迟和录屏。Apple MetricKit 的 hitch time ratio、Android Vitals 的慢帧/冻帧是产品侧参考，但不能替代本地归因。**[公开]**
5. **阈值不是行业标准**：VFX 份额、overdraw +3、粒子 +150、draw calls +40 等均为本项目政策值；不同美术风格/设备差异很大，首轮基线后必须校准。**[政策]**
6. **硬件差异**：Intel HD 6000 是 2015 年级核显；移动 GPU 的 tiled 架构、带宽、热降频行为完全不同。桌面结论不能直接外推到移动。**[推断]**
7. **确定性边界**：战斗逻辑可 seed 复现，但渲染受驱动/GPU/OS/后台负载影响；同一场景仍需固定构建、驱动、电源和热状态，才能比较。**[推断]**
8. **统计边界**：单 cast 窗口的 p99 没有统计意义；必须按整段场景算 p99，单 cast 报 worst/超预算帧数。**[公开]**
9. **未覆盖**：网络/联机回合制、服务器权威回放、VR/AR、主机平台、内存泄漏的完整 heap 分析、音频 DSP 成本、UI 字体 atlas 成本；这些需要单独协议。**[推断]**

---

## 附录 A · 术语

| 术语 | 含义 |
|---|---|
| **Cast** | 一次施法从开始到该动作所有表现结束 |
| **Turn window** | 一个回合内所有 cast 的集合 |
| **Hitch** | 单帧超过 2× 帧预算；severe hitch 为超过 4× |
| **p95/p99** | 帧时间分布的上尾分位；p95=95% 的帧不超过该值 |
| **Overdraw** | 同一像素在一帧内被着色多次；平均层数 = 着色片段/屏幕像素 |
| **Draw call** | CPU 向 GPU 提交的一次绘制；2D 下受材质/纹理/混合影响 |
| **Peak increment** | cast 期间相对空场基线的峰值增量，不是总耗时 |
| **First cast / repeat cast** | 首次施放（含编译/加载）vs 热态重复施放 |
| **Soak** | 连续长时间运行，观察热降频/内存/节点累积 |
| **Fail-closed** | 缺数据或未验证即判失败，而不是默认通过 |

## 附录 B · 文档维护

- 新增技能/VFX 时：在技能数据旁补一张 §4.5 预算卡；在 §2.5 场景矩阵加一行；在 §7.3 决定是否加入优先场景。
- 更换渲染器/引擎版本时：重跑 S0/S1/S2/S6，更新 §3.2 工具可用性与 §7.5 阈值。
- 每次审计报告归档到 `docs/perf/<task>/`，原始 CSV 不删；报告只引用路径与哈希。
- 本协议是“怎么量、量什么、什么算过”；具体削减方案（粒子合并、图集、池化、分辨率降档）由美术/程序在审计结论之后执行。
