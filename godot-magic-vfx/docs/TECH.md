# TECH · Magic Projectile Lab

任务 T-20261121-037。目标：把 B 站中配《Godot Particles 魔法发射特效教程！》里的**魔法发射特效技法**复刻为一个可交互、可清理、能在 Godot 4.6 GL Compatibility 下真实运行的 3D demo。

---

## 1. 参考视频拆解（帧级）

参考：<https://www.bilibili.com/video/BV1v7sn6UEnu>（UP 双雷交火，21:21 中配）。
原教程：**Le Lu — “Godot 4 · Magic Projectile VFX (Fireball)”，VFX for Games 系列第 11 集**，YouTube `74XywaLGO5Q`；片中显示引擎为 **Godot 4.2.2**（右下角版本号），3D，非 2D。

用 `yt-dlp` 拉 480p 分段 + `ffmpeg` 抽帧（素材只在 `/tmp/magicref`，未入库）确认：

| 环节 | 教程做法 | 证据帧 |
| --- | --- | --- |
| 头部 Head | Blender 里用 UV 球切半、拉伸成“火焰勺/碗”网格，导出 `fireball_mesh.obj` 进 Godot；缩放 0.5、绕 Y 旋转 90°；自建 Shader 滚动纹理 | 0:00 预览 / 3:00 编辑器 / 3:30 导入 |
| 拖尾 Tail | Krita 画 348×512 火焰波纹贴图；在 Godot 用两块交叉平面（crossed quads）挂 `TrailShader`，UV 滚动、黄色→红→透明渐变；后续用 Trail3D 插件把拖尾挂到移动物体 | 10:00–15:00 |
| 火星 Sparks | 额外粒子系统，沿速度方向拉长的小火星 | 16:00 前后 |
| 光照 | 火球上挂 PointLight3D，地面/角色被橙光照亮 | 19:00 前后 |
| 形态 | 橙金火球 + 波浪拖尾；教程还展示了蓝/绿等变体（Patreon） | 0:00–1:00 |

本 demo 借的是**构成与技术意图**（3D 头 + 滚动火焰纹理拖尾 + 火星 + 动态光），不是素材或具体拓扑。

---

## 2. 与教程的差异（有意为之）

| 项 | 教程 | 本 demo | 原因 |
| --- | --- | --- | --- |
| 头部网格 | Blender 手工 UV 球切半 | `SurfaceTool` 程序化 16 环 × 20 段勺形网格；另做六棱双锥冰晶 | 无外部资产；可在代码里参数化 |
| 拖尾 | 交叉平面 + 贴图滚动 / Trail3D 插件 | **缓存的平面四边形 + 滚动火焰贴图**（贴近教程思路），由弹体驱动位置/朝向；另挂 GPU 火星/火团 | 兼容 GL Compatibility（无 built-in trail），且避免逐帧重建网格；平面拖尾是教程原始做法的等价实现 |
| 发光/Bloom | 教程中部分画面有较强泛光 | **假 Bloom**：多层 additive billboard（glow / flare）+ 饱和核心 | GL Compatibility 无 WorldEnvironment Glow 后处理 |
| 完整链路 | 重点讲火球本体 | 蓄力法阵 → 发射 → 拖尾 → 命中爆炸 → 余烬/光衰减，全链路可交互 | 任务要求 |
| 魔法种类 | 火球为主 + Patreon 变体 | 炎爆/奥术/霜晶三系，共享同一套管线，参数表驱动 | 任务要求 2–3 种 |
| 引擎版本 | 4.2.2 | 4.6 | 本机版本；4.6 的 Compatibility 粒子支持更完整 |

---

## 3. 节点与文件

```
MagicLab (Node3D, scripts/main.gd)
├─ Camera3D (当前相机, fov 41)
├─ WorldEnvironment (BG_COLOR + AMBIENT_SOURCE_COLOR + LINEAR tonemap)
├─ DirectionalLight3D KeyLight / OmniLight3D RimLight / Fill / MageFill
├─ Ground (PlaneMesh 120×120, shaders/ground.gdshader)
├─ Backdrop (48×22 QuadMesh, shaders/backdrop.gdshader)
├─ DecoRune (9.5 m 平放 quad, shaders/rune.gdshader)
├─ Lantern0..3 (小球 + additive halo)
├─ Caster (MagicCaster, scripts/caster.gd)
├─ Dummy0..2 (TrainingDummy, scripts/dummy.gd)
├─ AimMarker (ring + rune quad)
├─ VfxRoot
│  ├─ DustMotes (GPUParticles3D, 80)
│  └─ FxRoot (每次重置整体重建；所有瞬态 FX 都在此)
├─ ProjectileLight / ImpactLight (池化 OmniLight3D，能量 0 时仍存在)
├─ HudLayer → HUD (Control, 1280×720 逻辑)
└─ VignetteLayer → ColorRect (shaders/vignette.gdshader)
```

- `scripts/spell_data.gd`：三系参数表（颜色、头部 style、拖尾贴图/宽度/长度、速度/弧度、火星/火团/命中/光照/震屏等）。
- `scripts/main.gd`：输入、瞄准（地面射线 + 木桩屏幕距离锁定）、蓄力/发射状态机、弹体与命中调度、相机震动、光照池、自动演示、截图/录像时间线、统计与粒子计数。
- `scripts/projectile.gd`：程序化头部网格 + 假 Bloom billboard + 火星/火团 GPUParticles3D + 单张平面拖尾 + 曲线飞行 + 命中发射信号。
- `scripts/trail_quad.gd`：单张 1×1 四边形按投影拉长/拉高，`place(head, backward)` 用“后向 + 世界上”的相机朝向基构造；材质/网格由 main 缓存并复用（拖尾池），没有逐帧 `ImmediateMesh` 重建。
- `scripts/impact_fx.gd`：闪核、双层冲击环、Burst、FireCore、ImpactSparks、Embers、ScorchGlow、符文环/寒雾（烟已移除）；自身 TTL 3.6 s。
- `scripts/caster.gd`：原始几何体法师（袍/兜帽/手臂/法杖/晶体/环绕碎片）、蓄力法阵、聚能粒子、枪口爆发、施法后坐。
- `scripts/dummy.gd`：草靶木桩，弹簧摆动、材质 overlay 闪白、生命 3、击倒 0.5 s、3.4 s 重建。
- `scripts/hud.gd`：单次 draw transform 缩放的 HUD；1080p 自动 1.5×；截图显示 “STILL”，录像显示 “30 FPS · REC”，交互时显示真实 FPS。

---

## 4. 网格 / 材质 / 参数

### 4.1 火焰头（炎爆 & 奥术）

- `SurfaceTool` 环数 16、段数 20；沿 -Z 前进。
- 半径 profile（尾→头）：`0.27, 0.30, 0.315, 0.305, 0.28, 0.25, 0.215, 0.18, 0.135, 0.085`。
- 脊线 `yc = -0.26 + 0.52·t^1.75 + 0.03·sin(πt)`（上翘的钩/勺）；前端 Z=-0.36 收成尖点；尾端开口。
- UV：u = 沿长度 0→1，v = 环向；尾部开口 → 从侧面看是新月/勺形。
- 材质 `shaders/flame_head.gdshader`：`blend_add / unshaded / cull_disabled / depth_draw_never`；uniforms：hot/mid/deep、intensity 1.6–1.9、flow_speed 1.15–2.15、noise_scale 2.4、style。噪声采样原创 `noise.png`；白热前缘 `smoothstep(0.58,0.97,t)`。
- 头部缩放：`head_scale × (0.82 + 0.30 × power)`；另有两层 additive glow billboard（2.0 m / 0.7 m）充当 bloom。

### 4.2 冰晶（霜晶）

- 六棱双锥：尾部 tip (0,0,0.28)、环 z=0.10 / r=0.15、环 z=-0.24 / r=0.105、前尖 z=-0.52；
- 同一个头部 shader，`style=2`（更白、更锐、低湍流）；自旋 1.2 rad/s。

### 4.3 火焰拖尾（平面 scrolling sheet）

- 每条弹体一个 `TrailQuad`：1×1 四边形按 `(trail_len × (0.85+0.25·power), trail_width × (0.9+0.2·power))` 拉长；头部位于弹体，向后延伸；基向量 x=后向、y=世界上（投影），z=x×y，保证面向相机且随飞行方向自然摆动。
- shader `flame_trail_quad.gdshader`：`blend_add / unshaded / cull_disabled`；采样原创 `flame_strip.png` / `frost_strip.png`（512×128，程序化、可平铺）；u 方向 UV 滚动（1.25/1.6/0.8）+ 双正弦摆动；头部白热、尾部深红/深蓝，边缘回压 deep，alpha 由纹理/渐隐/中心权重相乘。
- 拖尾材质与网格按 spell 缓存，节点池化在 main（最多复用，不当场分配）；初始实现是 `ImmediateMesh` 历史点 ribbon，在 Intel GL 驱动上每帧重建会引发 0.5 s 级 stall，因此换成这条**贴教程原意**的平面方案（见迭代记录 R7）。
- 焰条贴图由 `tools/gen_assets.py` 生成：厚 0.30±0.055 的波带 + 多倍频湍流 + 洞 + 端部收缩；种子 20261121。

### 4.4 粒子参数（ParticleProcessMaterial）

| 系统 | texture | amount | lifetime | 关键参数 |
| --- | --- | ---: | ---: | --- |
| Projectile Sparks | `spark_streak.png` | 40 | 0.55 | 方向局部 +Z 后喷、spread 48°、速度 1.2–4.2、重力 -7、damping 0.8–2.2、Z-billboard + Y-to-velocity |
| Projectile FlamePuffs | `smoke.png` | 16 | 0.55 | 速度 0.3–1.1、scale 0.5–0.9 → ×2.1、颜色 → 透明 |
| ChargeMotes | `spark.png` | 48 | 0.7 | 球面半径 1.05、radial_accel -9…-14 汇聚、amount_ratio 随蓄力 0.12→1 |
| MuzzleBurst | `spark.png` | 18 | 0.35 | one-shot、explosiveness 1 |
| Impact Burst | `smoke.png` | 22 | 0.62 | 球面爆散 1.5–5.2×power、scale ×2.3、颜色 hot→mid→deep→透明 |
| Impact Sparks | `spark_streak.png` | 36 | 0.8 | 速度 2.5–6.5、重力 -8、Y-to-velocity |
| FireCore | `glow.png` | 26 | 0.55 | 速度 0.5–3.0、scale 0.7–1.5→×1.8、中心亮核 |
| Embers | `glow.png` | 14 | 1.7 | 速度 0.8–3.2、重力 -1.6、寿命长（仅炎爆） |
| FrostMist | `smoke.png` | 26 | 1.6 | 霜晶专用，蓝色 additive |
| IceShards | `shard.png` | 12 | 0.95 | 速度 3–7、重力 -7、Y-to-velocity |
| DustMotes | `dust.png` | 80 | 12 | 环境常驻，box 18×6×12，极慢 |

> 命中烟雾（Smoke）在最终版移除：其全屏覆盖与普通混合排序既遮挡主体，又在 Intel 上增加 overdraw；余烬/亮核/火星已足够表达温度。所有粒子材质/网格/梯度纹理经 `main.particle_mesh / ramp / curve` 缓存，避免每次命中重新上传纹理/资源。

粒子材质统一使用 `StandardMaterial3D`（unshaded、additive、`vertex_color_use_as_albedo`），寒雾用普通 MIX。粒子颜色由 `GradientTexture1D` ramp 提供；尺寸曲线由 `CurveTexture` 提供。

### 4.5 光照

- WorldEnvironment：背景 `#05070d`，ambient color `(0.25, 0.31, 0.50)` × 2.15。
- KeyLight 方向光 `(0.72,0.80,1.0)` × 3.0（前左上），RimLight 暖橙 omni × 2.6（后上），Fill 蓝 omni × 3.8，MageFill 冷 omni × 2.4。
- **池化动态光**：`ProjectileLight` 跟随最新弹体（能量随 spell + flicker），`ImpactLight` 在命中点脉冲（5.0×power，0.9 s 衰减 + 2.2 s 余辉）。全程 OmniLight3D 数量固定，避免增减光源触发前向渲染的状态/着色器变化。
- 地面是受光材质（`diffuse_lambert`），所以火球/命中光真的会在石板上形成光池；角色受同一组光。

---

## 5. GL Compatibility 限制与回退

已验证引擎：Godot 4.6 stable，OpenGL 4.1 Compatibility（Intel HD Graphics 6000）。

| 限制 | 影响 | 本项目回退 |
| --- | --- | --- |
| 无 WorldEnvironment Glow / Bloom 后处理 | 加色特效没有自动泛光 | 多层 additive `glow.png`/`flare.png` billboard、饱和色核、HDR 式叠加 |
| GPUParticles3D 无内置 trail | 无法直接用粒子 trail 做拖尾 | 平面 scrolling sheet（缓存 quad + 滚动 Shader，贴近教程的交叉平面思路） |
| 无体积雾 / SSAO | 场景层次少 | 渐变背景屏、地面碎光、暗角、远处剪影、假接触阴影 |
| 无屏幕纹理/深度纹理通用访问 | 复杂屏幕特效不可用 | 不使用屏幕后处理；暗角独立 CanvasItem shader |
| 前向多光源开销 & 光源增减抖动 | 动态光易掉帧 | 固定光源数量 + 两盏池化动态光 |
| MSAA 3D 在 Intel HD 上代价高 | 边缘锯齿 | 项目 MSAA=OFF；依赖柔和 additive 与 1080p 截图；HUD 矢量文字 |
| 雾/Glow 需要 Forward+ | 不可用 | 不依赖；所有着色器只使用 Compatibility 支持的写法 |

未使用 2D 粒子回退：整个效果是 3D 形态，GPUParticles3D 在 4.6 Compatibility 正常工作；被替换的是“trail”和“glow”这类不支持的特性。

---

## 6. 清理与无泄漏

- 所有瞬态 FX（弹体、命中包、脱落的粒子系统）都挂在 `FxRoot` 下；`R` 重置时整体 `queue_free` 并重建 `FxRoot`。拖尾是 `VfxRoot` 下的复用池，重置时隐藏并释放占用。
- 弹体命中后：停止发射、把火花/火团 `reparent` 到 FxRoot、设置 `ephemeral_until`（墙上时间 + 1.2 s），挂到 `magic_ephemeral` 组；拖尾回到 main 的 `TrailQuad` 池（隐藏复用，不新建）；命中包 TTL 3.6 s。
- `main._prune_arrays()` 每 0.5 s 扫描 `magic_ephemeral`，对超过 `ephemeral_until` 的节点兜底 `queue_free`；即使计时器 Callable 失效也不会残留。
- `tools/smoke_magic_vfx.gd` 验证：发射、命中、切换、慢放、重置、木桩击倒/重建、以及 **FxRoot 清空**；末行 `MAGIC_VFX_SMOKE_OK`。
- 木桩重建定时 3.4 s；受击光已并入池化 ImpactLight，木桩自身不再创建光源。

---

## 7. 性能

### 7.1 预算

- 软预算：**2,400** 活跃粒子（HUD 实时显示）；典型战斗 ~300–800，最坏 ~1,400。
- 固定场景：~160–210 draw calls（含 HUD），3 个静态 omni/directional + 1 个法杖小光 + 2 个池化动态光。
- 无阴影、无 MSAA、无后处理；所有粒子单 Quad，单次绘制。

### 7.2 实测（真实 GPU，Intel HD Graphics 6000，macOS 12.7.6）

测量时间 2026-11-22 00:37–00:40；同机同时有其它进程，load average **8–22**。每个场景先预热全部材质/命中，再按墙钟时间统计；`NORMAL` = 2.2 s 一发，`STRESS` = 0.85 s 一发。基准是同一进程内的 1 Cube + 1 Plane + 1 Light。

| 场景 | 分辨率 | 结果（avg / min / >100ms 帧） |
| --- | --- | --- |
| 最小基准 | 1280×720 | **58.2 / 25.0 / 0** |
| demo 空闲 | 1280×720 | **44.6 / 12.7 / 0** |
| demo NORMAL 连发 | 1280×720 | **10.4 / 0.32 / 6** |
| demo STRESS 连发 | 1280×720 | **20.3 / 1.63 / 7** |
| 最小基准 | 1920×1080 离屏 | **57.1 / 10.3 / 0** |
| demo 空闲 | 1920×1080 离屏 | **24.6 / 8.6 / 6** |
| demo NORMAL 连发 | 1920×1080 离屏 | **18.8 / 1.81 / 10** |
| demo STRESS 连发 | 1920×1080 离屏 | **15.8 / 2.28 / 14** |

**结论（必须如实记录）**：在 2026-11-21/22 这台 Intel HD 6000 + macOS 12.7.6 上，空闲稳定在 ~45–58 FPS，但**一旦发射/命中就出现 0.3–2 s 的同步停顿**，普通连发和压力连发都达不到 30 FPS 的验收线。停顿与预算内的粒子数（峰值 284 / 2400）不成比例，且同进程的最小基准稳定 57–58 FPS，说明瓶颈在 GL Compatibility 下**运行时创建/重启 GPUParticles3D 及其管线**，而不是场景/几何/粒子数量：
- 把每帧重建的 ImmediateMesh ribbon 换成缓存 quad 拖尾后，STRESS 从 ~4 FPS 提升到 ~20 FPS（仍不达标）。
- 缓存头部网格/材质、粒子 quad/材质/渐变/曲线后，停顿仍有 0.3–2 s，且相同状态下不同轮次差异极大（OS/驱动抖动）。
- 已尝试并记录：MSAA 关闭、无阴影、光源数量固定/池化、粒子数量下降 ~45%、去除命中烟雾、1080p 离屏。1080p 空闲 24.6 说明填充率也是限制之一。

**未完成项 / handoff**：要让 Intel HD 在战斗中稳定 ≥30：
1. 将命中 FX 改为**启动时预建一个 per-spell impact rig 池**（节点、粒子系统、材质都复用，仅 restart + 复位 tween），或把命中/弹体粒子切到 **CPUParticles3D**（本 demo 已验证 GL 下 GPUParticles 的创建/重启是停顿源；CPUParticles 是允许的回退）。
2. 1080p 下如需稳定 30，可把 3D 内部渲染降到 960×540 再放大，HUD 保持 1920×1080 布局。
3. 在干净机器（load < 3）上复测一次；本次 load 8–22，绝对数不能代表目标硬件。

命令：`godot --path . -s tools/perf_magic_vfx.gd`（720p）/ `... -- --1080`（1080p 离屏）。

---

## 8. 截图与录像

- 截图 `tools/screenshot_magic_vfx.gd`：创建 **1920×1080 离屏 SubViewport**（own_world_3d），真实 GPU 渲染；HUD 通过布局缩放 1.5×；10 个 pose 覆盖 overview / 蓄力 / 三种弹体飞行与命中 / 慢放 / 三系连发。
- 录像 `--write-movie`：Movie Maker 固定 30 fps、1280×720，`-- --capture` 启用 `main._enable_capture_timeline()`；时间线以**未缩放时间**推进，因此慢放段不会拉长成 4 倍片长；HUD 显示 `REC · CINEMATIC 30 FPS`，FPS 显示为录制帧率。
- `tools/build_media.sh` 生成 `docs/magic_vfx_demo.mp4` 与 GIF。

---

## 9. 原创资产管线

- `tools/gen_assets.py`（numpy + Pillow，seed `20261121`）生成 14 张 PNG：`flame_strip`、`frost_strip`、`glow`、`glow_wide`、`spark`、`spark_streak`、`smoke`、`ring`、`shard`、`flare`、`rune`、`contact_shadow`、`dust`、`noise`；`assets/textures/MANIFEST.json` 记录 sha256/bytes。
- 网格全部为程序化：头部/冰晶（SurfaceTool）、法师/木桩（Godot 基本体）、场景（Plane/Box/Sphere/Torus/Quad）。
- 字体使用运行时 `SystemFont`（PingFang SC / Menlo），不打包字体文件。
- 参考视频素材只在 `/tmp/magicref`，未复制到仓库；教程仅作为技术参考。
