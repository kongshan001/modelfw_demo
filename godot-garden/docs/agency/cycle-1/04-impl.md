# Cycle 1 · 04 实现：提灯守夜人接入 KayKit Rogue

> 执行：游戏程序 | 日期：2026-10-31 | 范围：只换提灯守夜人外观，FSM/路线/速度/驻足/夜灯 API 不变
> 关联：`01-brief.md`、`02-art-review.md`、`03-qa-baseline.md`
> 时间盒说明：本轮在 5 分钟收敛窗口内按“灯可见 > 脸不过曝 > 比例/脚底 > 性能稳定 > 细节”取舍，未尽的微调列入 §7。

---

## 1. 改动文件

| 文件 | 改动 |
|---|---|
| `scripts/garden_patrol.gd` | `ROLE_LANTERN` 走 Rogue 外观分支；程序化 `_build()` 保留为回退（改名 `_build_procedural()`）；提灯装置/根灯/双层光晕/地面池；`Idle`/`Walking_A` 绑定；`set_night()` 对新灯分支；隐藏武器/披风；材质覆盖；`_add_shadow` 增加 alpha 参数（默认仍 0.5）。扫园人/小狐侍路径未改。 |
| `scripts/garden_scene.gd` | `PATROL_CAMERAS["lantern"]`：pitch **16→12**、distance **5.8→5.2**；`_update_camera` 近景目标高度按角色区分：lantern **1.0m**，其它保持 **0.85m**。默认 48°/27.5m 主镜头未改。 |
| `tools/screenshot_patrol.gd` | 仅验收截图工具：提灯近景前把 NPC 转向机位（`_face_patrol_to_camera`，yaw = 面向相机 -0.5rad），让左手灯入画。不改游戏逻辑/巡逻朝向。 |
| `assets/models/CREDITS.md` | 状态从“仅预演”改为“Rogue 已正式接入提灯守夜人；Mage 仍仅预演”；许可/源文件未动。 |

未改：`garden_world.gd`（路线/速度 0.72）、FSM、驻足时长、UI、音频、全局光照/雾/曝光、其他 NPC。

---

## 2. 关键参数

### 2.1 模型 / 动画

| 项 | 实现 |
|---|---|
| 根节点 | `GardenPatrol` 不缩放（FSM 米制不变） |
| `ModelRoot` | `rotation.y = PI`（模型正面 +Z → FSM forward −Z）、`scale = 0.74`、`position.y = 0` |
| 身高 | 0.74 × 2.187 = **1.618m**；脚底 y=0 |
| 隐藏网格 | `Knife_Offhand`、`1H_Crossbow`、`2H_Crossbow`、`Knife`、`Throwable`、`Rogue_Cape` |
| 材质 | 逐 surface 实例级覆盖：`TEXTURE_FILTER_NEAREST_WITH_MIPMAPS`、roughness **0.9**、metallic **0**、metallic_specular **0.15**、albedo × **(0.92,0.96,1.02)** |
| 阴影 | 身体/手臂/头/腿 `cast_shadow=ON`；灯体/光晕/地面池 OFF；接地软阴影 0.9m Quad、y=0.02、alpha **0.45** |
| 动画 | 只用 `Idle` / `Walking_A`（GLB 导入 loop=NONE，运行时置 `LOOP_LINEAR`）；Walk `play("Walking_A", 0.18, 1.29)`；Idle `play("Idle", 0.25)` + `seek(randf(), true)`；无 root motion |
| 旧程序化动画 | 提灯角色 `_idle()`/`_animate_walk()` 直接 return，不叠加四肢/呼吸，只保留根节点 yaw |

### 2.2 提灯（相对规格的实测偏差见 §6）

| 项 | 实现 |
|---|---|
| 挂点 | 每帧 `LanternRig.global_position = handslot_l.global_position + 角色 basis * (-0.20, -0.13, -0.12)`；`global_rotation = (0, root.yaw, 0)` 保持竖直 |
| 灯杆 | 0.7m × r0.018，深木色 (0.22,0.16,0.11)，杆底 = Rig 原点、杆顶 ≈ 手上 0.57m |
| 灯体 | 灯框 0.22×0.24×0.22（框色 0.11,0.09,0.07、roughness 0.65、metallic 0.35）；玻璃 0.15×0.19×0.15；灯心世界高 **≈0.871m**（Idle 手 0.471 −0.13 +0.53） |
| 光晕 | 核心 0.58m / 外圈 1.28m，Billboard、LINEAR；alpha 核心 `glow*0.40`、外圈 `glow*0.15` |
| 地面池 | 2.4m Quad、y=0.03、加色、alpha `glow*0.12`，`glow>0.02` 才显示 |
| 玻璃 | albedo (0.95,0.72,0.36)、emission (1.0,0.70,0.34)、`0.15 + glow*2.0` |
| 根灯 | 单个 OmniLight，local **(-1.30, 0.80, -0.90)**、色 (1.0,0.78,0.52)、range **4.0**、attenuation **1.8**、无阴影、**energy = 0.18 + glow*0.22** |
| glow | `glow = max(night, dusk*0.55)` 沿用；`set_night(night, dusk)` 对外行为不变（旧程序化分支仍是 `glow*1.35/0.85/2.6`） |

### 2.3 相机

- `PATROL_CAMERAS["lantern"]` 定为 **azimuth 140° / pitch 12° / distance 5.2m / anchor (-5,0,3)**，未采用 16°/5.8m（12° 能同时保住脸与地面灯池）。
- 近景 focus 高度：lantern **y=1.0**，其余 **0.85**；默认 48°/27.5m 未动。

---

## 3. 自测输出（逐字）

### 3.1 无头 600 帧（最终代码）

```text
$ godot --path godot-garden --headless --quit-after 600
headless_exit=0
grep -cE "SCRIPT ERROR|ERROR|WARNING" = 0
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org
```

### 3.2 标准巡逻探针（最终参数；窗口 `activate` 后前台）

```text
PATROL Patrol_lantern role=lantern travelled=7.9 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.90
PATROL Patrol_sweeper role=sweeper travelled=5.2 min_pond=13.35 min_circle=3.40 min_statue=10.55 min_pillar=11.56
PATROL Patrol_fox role=fox travelled=10.2 min_pond=12.98 min_circle=10.74 min_statue=9.41 min_pillar=1.72
PATROL_FPS avg=81.5 min=69.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=73.5 shown=66.8 cost=6.7
PROBE_PATROL_OK
```

参数收敛前另跑 3 次（窗口未 activate，被 macOS 限速，仅作样本；均 `PROBE_PATROL_OK`）：
`avg=45.2/min=34.0`（travelled 7.6）、`avg=55.3/min=44.0`（7.7）、`avg=59.4/min=55.0`（8.0）。
与 `03-qa-baseline` 一致：窗口前后台会显著改变 FPS；最终前台 81.5 高于门禁 58.2，但 A/B cost 6.7 是 legacy 单次顺序值（QA BUG-2 已判不可靠），交错探针未跑。

### 3.3 回退（`GARDEN_FORCE_PROCEDURAL=1`，模拟加载失败）

```text
$ GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --headless --quit-after 180
fallback_exit=0
warn_count=1
WARNING: GardenPatrol: Rogue unavailable (GARDEN_FORCE_PROCEDURAL), using procedural model

$ GARDEN_FORCE_PROCEDURAL=1 godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd
PATROL Patrol_lantern role=lantern travelled=7.4 min_pond=6.38 min_circle=6.43 min_statue=3.32 min_pillar=5.90
PATROL_FPS avg=61.0 min=59.0 samples=12
PATROL_TOGGLE hidden_ok=true shown_ok=true
PATROL_FPS_AB hidden=69.2 shown=62.2 cost=7.0
PROBE_PATROL_OK
```

### 3.4 截图

```text
$ godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd
SCREENSHOT: .../patrol_wide_dusk.png
SCREENSHOT: .../patrol_wide_dusk_off.png
SCREENSHOT: .../patrol_compare_on.png
SCREENSHOT: .../patrol_compare_off.png
SCREENSHOT: .../patrol_lantern_dusk.png
SCREENSHOT: .../patrol_lantern_night.png
SCREENSHOT: .../patrol_sweeper.png
SCREENSHOT: .../patrol_fox.png
exit=0
```

目录：`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`
验收图：`patrol_lantern_dusk.png`（18:24，12°/5.2m）、`patrol_lantern_night.png`（00:00，同机位）、`patrol_wide_dusk.png`（默认 48°/27.5m，18:12）。截图 SubViewport 仍为 **1920×1080**（QA BUG-4，窗口 1440×810 不决定输出尺寸）。

目检结论：
- 黄昏/夜间近景：灯杆、灯框、玻璃、光晕均可见；灯挂在左手、随步伐位移；灯在脸侧但不遮脸；脚底贴地、无武器/披风。
- 夜间：脸部暖光照亮但仍能读出眼睛/鼻子/嘴，暗部靠月光/补光可读；地面可见淡暖光池；玻璃偏暖白但不糊成纯白面。
- 默认广角：提灯人仍是“人形 + 暖光点”，可辨。

---

## 4. 实现结构（便于回退/复查）

```text
GardenPatrol (scale 1)
├── ModelRoot (yaw=PI, scale=0.74, pos.y=0)
│   └── Rogue.glb (Rig → Skeleton3D → BoneAttachment3D handslot_l; AnimationPlayer)
├── LanternRig (每帧跟 handslot_l；scale 1)
│   ├── Pole 0.7m / Frame / Glass
│   └── HaloCore 0.58 / HaloOuter 1.28
├── LanternLight (根节点 OmniLight，无阴影)
├── LanternPool (2.4m Quad, y=0.03)
└── 接地软阴影 (0.9m Quad, alpha 0.45)
```

- 材质用 `set_surface_override_material()`，不修改源 GLB/共享网格。
- 提灯角色的 `_idle()`/`_animate_walk()` 不触碰 `_body/_leg/_arm`（这些节点为空）。
- `set_night()` 内按 `_uses_model` 分支；旧分支数值完全保留。

---

## 5. 回退验证方式

1. **推荐（无需改资产）**：`GARDEN_FORCE_PROCEDURAL=1 godot ...`。`_build_rogue()` 第一步检测环境变量，打印一次 `push_warning` 后返回 false，走原 `_build_procedural()`。
2. 也可临时把 `ROGUE_SCENE_PATH` 改成不存在路径、或重命名 `Rogue.glb`（重导入后）验证“模型不存在/加载失败”；`AnimationPlayer`/`handslot_l`/`Idle`/`Walking_A` 任一缺失同样回退。
3. 验证口径：场景不崩、只 1 条警告（`_fallback_warned` 去重）、`PROBE_PATROL_OK`、画面仍是原程序化提灯人。本次已用方式 1 实测（§3.3）。

已知限制：`ResourceLoader.exists()` 命中的是导入后的 remap，直接改名源 GLB 而保留 `.import` 时可能仍能加载缓存 `.scn`；要模拟“真缺失”需同时清理导入缓存或改路径（方式 1 已足够覆盖运行期回退）。

---

## 6. 与 02-art-review 规格的偏差（已实测，留痕）

| 项 | 规格 | 实现 | 原因 / 证据 |
|---|---|---|---|
| 提灯偏移 | `(-0.08,-0.12,-0.08)` | **`(-0.20,-0.13,-0.12)`** | Rogue 头宽 0.816m，规格偏移下灯框落在头部剪影内、灯心距脸颊约 0.3m；外移/放低后灯心 ≈0.871m（仍在 0.88±0.03），灯框离脸和草更远，近景不再“贴脸”。 |
| 根灯位置 | `(-0.38,1.02,-0.22)` | **`(-1.30,0.80,-0.90)`** | 实测规格位置落在脸颊/下巴极近处：关灯时脸部 p95=164，开灯后脸颊 90% 像素 max-channel >240；即使 energy 降到 0.05 仍饱和（近场衰减）。外移到该点后脸颊 >240 降到约 24%，左脸 p95≈229，五官可读。灯仍在根节点、单灯、无阴影。 |
| 根灯能量 | `0.20+glow*0.25` | **`0.18+glow*0.22`** | 与外移配合再降一档，夜间 0.374（原 0.421），避免脸/胸口继续裁切。 |
| 光晕核心 alpha | `glow*0.55` | **`glow*0.40`** | 降低近景光晕对脸颊的叠加，保留 0.58/1.28 尺寸与 billboard。 |
| 玻璃 emission | `0.15+glow*2.6` | **`0.15+glow*2.0`** | 降低灯芯 bloom 外溢；玻璃仍是最亮元素。 |
| 披风 | Brief 默认保留（可签字隐藏） | **隐藏** | 02-art-review §4.2 明确：未蒙皮、最低 y=-1.122，会钻地/穿石阶。 |
| 近景机位 | 16°/5.8m，允许 ≤4° 微调 | **12°/5.2m** | 按 02-art-review §4.8；保持与 QA 基线可对比的锚点机位。 |

未偏差项：0.74 缩放、根节点不缩放、ModelRoot yaw=PI、脚底 y=0、武器隐藏、Nearest+Mipmap、roughness 0.9/metallic 0/specular 0.15/albedo 乘色、Walk 1.29、Idle 随机相位、无 root motion、灯保持竖直、光晕尺寸/地面池 2.4m/alpha 0.12、`glow=max(night,dusk*0.55)`、`set_night` 对外签名。

---

## 7. 已知风险与遗留

**风险**
1. **脸颊高光**：修正后在 3/4 持灯视角仍有暖色高光（cheek 区约 24% max-channel >240，左脸 p95≈229）；眼睛/鼻子/嘴可读，但严格按 02 §5 的“面部 p95<240”仍需美术用同一区域口径复测。不要让灯回到 (−0.38,1.02,−0.22) —— 实测任何能量都会打爆。
2. **灯被身体遮挡**：灯在左手，角色朝某些方向行走时正常游玩中会被身体挡住（物理正确）。验收近景用截图工具的姿态转向（只改工具）保证灯入画；默认广角仍靠光晕/地面池读“移动暖光”。
3. **双影**：身体实时阴影 + 0.45 alpha 接地贴片同时存在；近景未见明显双影，但未按 QA 口径逐帧检查。
4. **性能口径**：最终前台探针 avg 81.5，但只跑了 1 次；A/B cost 6.7 是 legacy 单次顺序值，按 QA BUG-2 不可作门禁；交错探针 `qa_probe_patrol_perf.gd` 未跑。
5. **Q 版头身比**（46.7%）与程序化 NPC 的统一性仍是 Cycle 2 议题；本轮未加长袍/toon。
6. **截图工具姿态**：`screenshot_patrol.gd` 在提灯近景前会转向 NPC，属验收工具行为，不代表玩家实际看到的固定朝向；QA 记录截图时需注明。
7. **640×360 源画面**未单独检查；截图仍为 1920×1080 SubViewport。
8. **材质共享**：逐 surface override 只影响当前实例；目前只有 1 个 Rogue 实例，Cycle 2 多角色时需复用材质实例。

**遗留（Cycle 2 / 05 复评）**
- 专用 PAUSE 举灯动作（本轮按任务范围只用 Idle/Walking_A，驻足播放 Idle 随机相位）。
- 面部 p95 的正式测量与灯光细调（备选：规格位置 + attenuation 0.5；实测左脸 p95≈186、脸颊约 65% >240，可作为美术对比方案）。
- 交错稳态性能探针 3 连跑、640×360 源画面、宽景夜间双方向截图。
- 长袍/toon 降饱和、同屏统一性（女孩/扫园人）。
- `patrol_fox.png` 树干遮挡（QA BUG-1，工具问题，未修）。

---

## 8. 一句话总结

提灯守夜人已换成 0.74 的 KayKit Rogue（Idle/Walking_A、无武器/披风、左手提灯、根灯+双层光晕+地面池），FSM/路线/速度/驻足/夜灯 API 与其他 NPC 全部保留；程序化回退单次警告且探针通过；为救脸部曝光把根灯外移/降一档并外移灯笼，偏差与证据见 §6。
