# 废墟花园 · 黄昏

参考 B 站视频 [BV1sEpE6pEWK](https://www.bilibili.com/video/BV1sEpE6pEWK)
做的 Godot 4.6 实时场景尝试：高清柔和渲染的风格化低模废墟花园，时间从黄昏
走向深夜再走向清晨，路灯与萤火逐渐亮起，水面、云影与光束随时间变化。

> 只分析参考视频的构图、光照和节奏；没有使用视频里的任何素材或代码。
> 这是一个风格化重做，不是逐帧 1:1 复刻。

## 运行

```bash
godot --path godot-garden
```

- Godot **4.6 stable**。
- 渲染器：**Mobile / Vulkan**（`project.godot` 已设置）。
  - 本机 Intel Iris 6000 + macOS 上，GL Compatibility 的 3D 直射光/点光不生效，
    所以改用 Mobile；实测 Vulkan 正常。
  - Forward+ 在本机 MoltenVK 上会有 fragment shader 编译错误，未采用。
- 窗口 1920×1080；场景内部 960×540 + 线性放大 + MSAA 2×，UI 保持全分辨率清晰。

## 操作

| 操作 | 说明 |
| --- | --- |
| 拖动「时间」滑杆 | 在 0–24 点之间跳转；拖动会自动暂停 |
| 「暂停 / 播放」 | 恢复 ×600 时间流速（一天 2.4 分钟） |
| 萤火 / 路灯 / 光束 / 云影 | 分别开关对应效果 |
| `空格` | 播放 / 暂停 |
| `R` | 回到 17:48 |
| `1`–`5` | 快速开关萤火 / 路灯 / 光束 / 云影 / 游人（巡逻 NPC） |
| 鼠标滚轮 | 镜头远近（0.82–1.25） |
| `F1` | 隐藏 / 显示 UI |
| `Esc` | 退出 |

## 实现要点

- **柔和渲染**：3D 世界渲染到 960×540 的 `SubViewport`，`LINEAR` 放大 + MSAA 2×；
  UI 在另一个全分辨率 `CanvasLayer`。
- **场景**：程序化地面、环形石径、水池、废墟拱门/石柱/断墙/石圈、树、
  MultiMesh 十字草叶、灌木、落叶、灯柱、主角 Knight、程序化章鱼、三名巡逻 NPC
  （提灯守夜人 / 扫园人 / 小狐侍）。
- **昼夜**：太阳/月亮/天空补光三盏 `DirectionalLight3D`；环境色、雾、
  曝光、色调随时刻变化；路灯 `OmniLight3D` 与灯罩自发光按黄昏曲线渐亮；
  萤火为 `GPUParticles3D` + 加法混合 billboard；水面、云影、雾、光束均为
  自定义 shader。
- **主角**：KayKit Knight（CC0）替换原程序化小女孩；`Idle` / `Running_A` /
  `1H_Melee_Attack_Chop`，0.74 缩放、yaw π、贴地软阴影；任务/战斗逻辑不变，
  程序化小女孩保留为回退（`GARDEN_FORCE_PROCEDURAL=1`）。
- **程序化章鱼**：水池石像旁，8 条 Verlet 触手（12 点/条），重力/阻尼/
  距离约束/目标弹簧；地面与石像圆柱碰撞；周期缠绕石像；夜间变色/收拢。
  触手用“静态管网格 + `arm_points[12]` uniform 顶点变形”渲染，8 draw call；
  近景工具见 `tools/screenshot_octopus.gd`。
- **巡园游人**：3 个 NPC（提灯人绕水池、扫园人绕石圈、小狐侍在拱门后），
  沿手工校验的 waypoint 闭环行走，到点驻足 1.6–3.4s 做各自的动作。
  提灯守夜人 = **KayKit Rogue**、扫园人 = **KayKit Rogue_Hooded**（均 CC0，76 条动画）、
  小狐侍 = **Khronos glTF Fox**（CC0 + CC-BY 动画）：0.74 / 0.011 缩放、线性贴图、
  Idle/Walking_A（Fox 用 Walk/Survey）、提灯挂右手 + 驻足 `Spellcast_Raise`、扫帚跟手。
  程序化模型保留为缺图/加载失败回退（`GARDEN_FORCE_PROCEDURAL=1` 可强制验证）。
  `5` 键或 UI「游人」开关整体显隐。
- **后处理**：CanvasItem shader 做轻量柔光、冷暖分级、暗角。P0-6 后采样锁定
  去掉像素对齐与抖动，保留柔光/冷暖分级/暗角。

## 技术拆解文档

- `docs/2026-10-29-废墟花园技术方案.md`：管线、渲染器踩坑、世界搭建、昼夜曲线、灯光/萤火/水面/光柱、后处理、性能、9 个坑、参数速查、术语表、自检清单。
- `docs/2026-10-29-废墟花园技术方案-交互版.html`：同一内容的交互式版本，含可拖动时间演示、曲线图、术语搜索和自检清单。
- `docs/2026-10-29-从原理到复刻-实时场景技术讲义.md`：12 模块技术讲义，按“原理 → Godot 实现 → Unity/Unreal/Three.js 等价 → 练习”组织，适合学习与迁移。
- `docs/2026-10-29-从原理到复刻-实时场景技术讲义-交互版.html`：讲义交互版，含引擎切换（所有代码示例联动）、像素化演示、时间演示、术语表与自检。
- `docs/2026-10-29-独立美术评审.md`：独立美术 agent 的只读评审（4.3/10 对标参考片），含十维评分、Top 5 差距、P0/P1/P2 路线与 Godot 落地建议。
- `docs/2026-10-29-独立美术评审-评分卡.html`：评审的交互式评分卡（雷达图 + 评分条 + 路线图）。
- `docs/2026-10-30-章鱼程序化动画-技术笔记.md`：Verlet 触手、碰撞/缠绕、GPU 管渲染、变色与跨引擎复刻。
- `docs/2026-10-30-免费3D角色模型调研.md`：可商用的免费角色模型来源、许可证、风格匹配与替换方案（KayKit / Quaternius / Kenney / glTF Fox）。
- `docs/agency/`：策划 / 美术 / QA / 程序四职能 agent 的协作协议、质量分卡与 Cycle 1（提灯人换 KayKit Rogue）全套评审/实现/验收记录。
- `docs/迭代记录.md`：每轮迭代的目标、改动、同机位前后对比、指标、结论与下一步；对比图在 `docs/media/`。

## P0 迭代（2026-10-29）

根据独立美术评审（`docs/2026-10-29-独立美术评审.md`）落地：

- **镜头**：hero 机位 `target (-1.5,0.8,4.5)`、27.5m、48°、45°、zoom 1.0；滚轮 0.65–1.7；视野约 15.7m。
- **光照**：暖直射 + 冷天光；太阳正午约 70°、黄昏侧光；月亮阴影关闭以保持 89–90 FPS。
- **后处理**：不再做像素对齐/dither；保留柔光/冷暖分级/暗角；降低 bloom 强度。
- **P0-4 材质**：`stone.gdshader`（噪声混色/苔藓/湿石/假 AO）与 `foliage.gdshader`（叶簇色变/透光/风摆）；石径改 6–8 边倒角石板，几乎全石覆盖；树冠每棵 +5 边簇。
- **P1-8 密度**：3 种草型（2800 中草 + 1600 短草 + 700 高草）、540 朵程序化小花（`flower.gdshader`）、140 片落叶、2 段新断墙 + 拱门垂藤；87 FPS @1280×720。
- **P1-9 程序化章鱼**：8 条 Verlet 触手、地面/石像碰撞、螺旋缠绕、夜间/睡眠变色；触手静态管 + 顶点变形，80–83 FPS @1280×720。
- **水面/岸线/路径/UI**：加深水面、噪声打断岸线、加睡莲/芦苇；路径收窄；副标题随时间变化、移除技术水印。
- 对比图：`docs/media/p0_before_after.jpg`、`docs/media/p0_4_before_after.jpg`、`docs/media/p1_density_before_after.jpg`、`docs/media/octopus_before_after.jpg`；新的黄昏→夜色/章鱼 GIF 已单独发送。

风格路线已定为 **非像素**：960×540 + 线性放大 + MSAA，后续继续补纹理/材质密度；仍待 P1-7 构图、P1-10 水体。

## 迭代记录

**每轮迭代的目标、改动、效果对比、指标与下一步统一写入 `docs/迭代记录.md`**，对比图放 `docs/media/`。当前记录：

- 轮次 0：初版基线。
- 轮次 1：P0-1 镜头 / P0-2 光照 / P0-6 后处理 + 部分 P0-3 → `media/p0_before_after.jpg`。
- 轮次 2：P0-4 材质语言（stone/foliage shader、倒角石板、树冠叶簇）→ `media/p0_4_before_after.jpg`。
- 轮次 3：P1-8 密度（3 草型、540 朵花、落叶、断墙/藤蔓）→ `media/p1_density_before_after.jpg`。
- 轮次 4：P1-9 程序化章鱼（Verlet 触手、缠绕、变色）→ `media/octopus_before_after.jpg`。
- 轮次 5：巡园游人（3 名程序化 NPC 的 waypoint 巡逻、驻足动作、夜间提灯）→ `media/patrol_before_after.jpg`。
- 轮次 6：Cycle 1 多职能协作——提灯守夜人换 KayKit Rogue（CC0）→ `media/cycle1_lantern_before_after.jpg`。
- 轮次 7：非像素风格切换（960×540 线性 + MSAA）+ Cycle 2（扫园人 Rogue_Hooded、小狐 glTF Fox、灯笼右手/驻足举灯）。

新增一轮时按 `docs/迭代记录.md` 末尾的模板追加，并同步更新本 README、技术方案 §13 和评审落地状态。

## 工具

```bash
# 1920×1080 四时截图
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_garden.gd

# 连续帧（合成 GIF 用）
godot --path godot-garden --resolution 1280x720 -s tools/capture_garden_sequence.gd

# 章鱼近景截图 / 序列
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_octopus.gd
godot --path godot-garden --resolution 1280x720 -s tools/capture_octopus_sequence.gd

# 巡逻 NPC 截图 / 序列 / 走位与帧率探针
godot --path godot-garden --resolution 1440x810 -s tools/screenshot_patrol.gd
godot --path godot-garden --resolution 1280x720 -s tools/capture_patrol_sequence.gd
godot --path godot-garden --resolution 1280x720 -s tools/probe_patrol.gd
```

截图与序列写入：
`~/Library/Application Support/Godot/app_userdata/废墟花园 · 黄昏/screenshots/`。

## 性能

- 测试机：Intel Iris 6000 / macOS，1280×720 输出，内部 960×540。
- P1-9 章鱼时（未含主角/妖灵/任务层、内部 640×360）**80–83 FPS**；当前完整场景
  （960×540 + MSAA 2×，含主角/妖灵/任务/巡园游人）实测约 **63 FPS avg / 52 min**
  （1280×720 窗口、关 vsync；本机负载波动大，按相对口径看）。
- 草叶约 5.1k MultiMesh（3 草型），花 540 朵，萤火 220 粒子，章鱼 8 条
  12 点 Verlet 触手，巡逻 3 人；11 盏动态灯（8 盏路灯 + 灯笼 + 太阳/月亮/
  补光），太阳 4 split 阴影。

## 已知限制

- 场景是低多边形 3D，走柔和风格化路线（非像素）；细节密度仍低于参考片。
- 主角已换 KayKit Knight；程序化小女孩仅作回退，灯柱/石柱仍是程序化几何，近看较简略。
- 水面是近似反射/波纹，没有真实折射和屏幕空间反射。
- 光束是半透明面片近似体积光；没有真正的 volumetrics。
- 已有主角自动战斗/任务链与巡逻 NPC，但没有音频和物理碰撞，交互仍以点击地面/怪物和 UI 开关为主。
- 主角色系已统一为 KayKit（Rogue / Rogue_Hooded / Knight + glTF Fox）；场景仍是程序化低模，材质密度与参考片有差距。
- 参考视频的相机路径和 UI 参数面板没有逐项复刻，只保留了时间/效果开关。
