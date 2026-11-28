# Legionfall · 技术说明

- 任务：T-20261127-017（初版，连接中断失败）→ **T-20261127-018（本次续跑）**
- 完成日期：2026-11-28
- 引擎：Godot 4.6 stable `4.6.stable.official.89cea1439`
- 渲染：GL Compatibility / OpenGL 4.1（Intel HD Graphics 6000 实测）
- 设计分辨率：1280×720，`canvas_items` 拉伸；真实 GPU 截图 1920×1080
- 约束：无第三方运行时依赖；表内无外部美术/音频；CC0 规则仅约束外来资产，本作全部程序化原创

## 1. 启动路径与架构

```
scenes/main.tscn (Node3D + legion_game.gd)
  └─ LegionGame._ready()
       ├─ LegionWorld.build()          # 地形、石道、核心、传送门、建造点、相机
       ├─ CanvasLayer
       │    └─ LegionUI               # 1280×720 自绘 HUD
       └─ start_run(20261127)         # 初始资源、4 人小队、第 1 波准备
```

- `legion_game.gd`：唯一输入入口、经济、波次、强化、选择、调试 API。
- `legion_world.gd`：程序化场景与相机；`screen_to_ground` / `world_to_screen` / `lane_paths` 为 RTS 层提供坐标。
- `legion_actor.gd`：玩家/英雄/敌人共用 `Node3D`；不用 CharacterBody/物理引擎，移动与碰撞分离在游戏主循环里手算。
- `legion_tower.gd` / `legion_projectile.gd`：自动索敌与追踪弹。
- `legion_art.gd`：全部低模与材质/贴图/特效工厂；静态缓存 StandardMaterial 与运行时纹理。
- `legion_data.gd`：单位/塔/敌人/波次/修饰/强化/中文文案；纯数据引用，无场景依赖。
- `legion_ui.gd`：`Control._draw` 手绘 HUD；按钮热区在每次绘制时重建。

## 2. 相机 / 战场

| 参数 | 值 |
| --- | --- |
| 俯角 | 52°（固定，不旋转） |
| FOV | 42° |
| 初始目标 | `(0, 0, 23)` |
| 初始距离 | 56m |
| 缩放范围 | 34–96m |
| 平移范围 | x ∈ [-30, 30]，z ∈ [-33, 34] |

- 地图 120×120（`MAP_MIN=-60, MAP_MAX=60`），76×76 网格，SurfaceTool 生成三角面与顶点色。
- 岛体由 `ISLANDS` 椭圆 + 噪声遮罩；石道 `LANES` 每 1.4m 加密，宽度 5.2m；三座传送门对应北/西/东三线。
- 地形高度 `height_at()` 只用于贴地；单位/建筑/踏板位置都会采样。单位移动有 `island_mask` 边界保护，避免走进岩浆。
- 相机支持：WASD/方向键平移、滚轮缩放、中键拖拽、屏幕边缘滚动、小地图点击跳转。
- `debug_lock_camera` 只供截图/视频/perf 工具锁定机位，正常游戏默认关闭。

## 3. RTS 层

- 选择：屏幕坐标 → 世界；单位点击半径 1.35m；框选用 `world_to_screen` 投影判断；Shift 追加。
- 指令：`command_move` / `command_attack` / `command_attack_move` / `stop`；编队 1/2/3 由游戏层保存对象引用。
- 单位 FSM：`IDLE / MOVE / ATTACK / DEAD`。
  - 有显式 target：接近 → 攻击。
  - 攻击移动：每 0.25s 扫描 8.5m 内最近敌人，命中后切换攻击。
  - 待命自动索敌：每 0.3s 扫描，距锚点 15m 内有效；离锚点太远会自动拉回。
- 敌人：沿 `lane_paths` 推进；射程内玩家优先，否则抵达核心 2.4m 内攻击核心；无导航网格，依靠路线与圆形分离。
- 分离：每帧 O(n²) 推挤所有存活单位（MVP 单位量 <50）；圆形半径由单位定义。
- 伤害：近战即时结算；弩手/术士/酸刺/熔渣走追踪弹；投射物命中时由 `LegionGame.on_projectile_hit` 统一结算 AoE/减速。
- 生存性：清理已释放 target 的引用（`is_instance_valid`），避免多个投射物同时击杀后出现 freed object 报错。

## 4. 塔防 / 经济 / 波次

- 8 个固定建造点；选中后显示建造/升级/出售面板；塔建成后仍可升级至 Lv3，出售返还总投入 60%。
- 三种塔均自动索敌；棱镜单体光束、熔渣抛射 AoE、暮霜全范围减速。
- 资源：金币 + 精粹；人口只计算非英雄；初始 300g / 36e / 12 人口。
- 招募冷却：卫士 4s、弩手 5s、术士 8s；英雄不可购买。
- 波次流程：
  - PREP 倒计时（首波 14s，后续 10s）→ WAVE 按 `spawn_queue` 生成 → 清空敌人与出生队列 → UPGRADE 三选一 → 下一波。
  - 终波清空进入 WIN；核心归零进入 LOSE。
- 波次修饰：`_roll_modifier(next_wave)` 用 `seed + wave*3571 + 19` 的独立 RNG；同一 seed 可复现。
- 强化：10 个池，等级上限不同；每波随机 3 选 1，可重掷 1 次；`_recompute_stats()` 派生出塔/单位/经济倍率。
- 关键数值表见 `scripts/legion_data.gd`，本说明不重复全部数值。

### 本次修复的强化生效链

- **坚韧战团**：已存在单位立即补足新增上限；本次额外修复“强化后新招募单位”也继承 `stats.unit_hp`。
- **暮霜附魔**：所有塔命中减速；本次补齐棱镜直伤和熔渣投射物的减速传递。
- **重开**：清空强化、塔、单位、选择、冷却、集结点和帮助面板；重开换 seed。

## 5. UI / 输入

- 设计坐标固定 1280×720；`canvas_items` 自动适应窗口。
- HUD：资源、人口、波次进度、核心 HP、seed、FPS、draw calls、选中单位、招募卡、建造面板、小地图、三选一、胜负、帮助、tooltip、横幅。
- 输入顺序：Upgrade/Win/Lose 模态优先 → 键盘快捷键 → UI 阻挡区 → 世界点击/框选。
- 建造面板 1/2/3 在“选中空建造点”时直接建塔；否则作为编队呼叫。`Ctrl+1/2/3` 记录编队。
- `ui.is_point_blocked` 拦截顶部栏、底栏、小地图、帮助和已打开的建造/选择面板。
- 截图工具使用 `game.set_process(false)` 冻结逻辑、保持 HUD 与 3D 场景渲染；正常游戏不受影响。

## 6. 验收工具

| 工具 | 作用 | 成功标志 |
| --- | --- | --- |
| `tools/smoke_legion_td.gd` | 80 项 headless 断言：启动、选择、框选、移动、攻击移动、造兵、塔建/升/卖、索敌、核心、波次、三选一、胜负、重开、强化、UI 点击、建造快捷键 | `LEGION_TD_SMOKE_OK` |
| `tools/probe_legion_run.gd` | 全流程机器人：8 塔 Lv3 + 招募 + 自动三选一，跑完 6 波 | `LEGION_TD_RUN_OK` |
| `tools/perf_legion_td.gd` | 720p 窗口 / 1080p SubViewport 实时性能；可选 `LEGION_3D_SCALE` | `LEGION_TD_PERF_OK` |
| `tools/screenshot_legion_td.gd` | 9 张真实 GPU 1920×1080 截图（SubViewport + UI 1.5×） | `LEGION_TD_SHOTS_OK` |
| `tools/video_legion_td.gd` | 10s / 15fps 帧序列，手动步进，镜头脚本 | `LEGION_TD_VIDEO_OK` |

复现：

```bash
# 启动 / 报错检查
godot --path godot-legion-td --headless --quit-after 600

# 逻辑自测
godot --headless --path godot-legion-td -s tools/smoke_legion_td.gd

# 全流程
godot --headless --path godot-legion-td -s tools/probe_legion_run.gd

# 真实 GPU
godot --path godot-legion-td -s tools/screenshot_legion_td.gd
godot --path godot-legion-td --resolution 1280x720 -s tools/perf_legion_td.gd
LEGION_PERF_1080=1 godot --path godot-legion-td -s tools/perf_legion_td.gd
rm -rf /tmp/legionfall_frames_1080
godot --path godot-legion-td -s tools/video_legion_td.gd
ffmpeg -y -framerate 15 -i /tmp/legionfall_frames_1080/frame_%04d.png \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart \
  godot-legion-td/docs/legionfall_10s.mp4
ffmpeg -y -i godot-legion-td/docs/legionfall_10s.mp4 \
  -vf "fps=12,scale=960:-1:flags=lanczos" -loop 0 \
  godot-legion-td/docs/legionfall_10s.gif
```

## 7. 本次实测

环境：macOS，Intel HD Graphics 6000，OpenGL 4.1，Godot 4.6 stable，vsync off，Engine.max_fps=0。

- `godot --headless --quit-after 600`：无 SCRIPT ERROR / parse error / warning。
- smoke：`SMOKE_CHECKS=80 FAILURES=0`，末行 `LEGION_TD_SMOKE_OK`。
- 全流程：8 塔 Lv3，6 波全清，核心 100/100，131 kills，模拟局内时间 129.8s，`LEGION_TD_RUN_OK`。
- 720p：最终 8.01s 采样 306 帧，平均 **38.2 FPS**，P95 35.38ms，最差 98.09ms，714 draw calls（同场景早前一次 43.5 FPS）。
- 1080p SubViewport：最终 8.02s 采样 295 帧，平均 **36.8 FPS**，P95 36.73ms，最差 40.83ms，727 draw calls（早前一次 35.1 FPS）。
- 截图：9 张 1920×1080；视频：10.000s、1920×1080、15fps、H.264；GIF 960×540 / 12fps。
- 截图/视频读回会占用 GPU/主线程，画面内 FPS 读数低于独立 perf probe；截图工具在每张前预热 1.2s，因此可能显示约 30 FPS。

## 8. 已知限制与风险

1. **美术为程序化 MVP**：塔、兵、核心都由 Box/Cylinder/Sphere/Torus 拼成，没有骨骼/外部动画；远景可读性有限。
2. **寻路**：直线移动 + 分离，无 NavMesh；单位可能被岩石几何边缘阻挡，敌人只沿三条石道。
3. **数值未平衡**：8 塔 Lv3 + 10 单位可以轻松通关；需要后续做难度曲线与塔位收益测试。
4. **性能尾部**：1080p 平均 35–37 FPS，但 P95 约 36.7–37.4ms，偶发掉到 30 以下；720p 也有单次 98ms 抖动。共享主机的单次测量不能代表所有 Intel 机器。
5. **无音频/存档/手柄**；相机固定俯角，不能旋转；没有多语言切换。
6. **兵营不产兵队列**：本作采用「购买小队」的即时招募；兵营提供集结点与英雄复活点，不包含训练队列。
7. **视觉校验范围**：截图与真实 GPU 启动已验证；没有独立美术总监/QA 的正式放行，平衡与可读性仍需外部评审。
8. **参考视频未做逐帧对照**：只复用塔防/RTS/三选一的抽象循环；没有 Warcraft / 《军团塔防》素材、UI、关卡或品牌。

## 9. 父任务残留与本次增量

T-20261127-017 在 00:04 因 `API Error: Connection closed mid-response` 中断，残留 9 个脚本 + 空 tools / docs。残留工程无法启动：多处 `:=` 对 Variant 推断失败、`LegionWorld.CORE_POS` 未注册、`MultiMesh.visible` 每帧报错、无任何验收工具。

本次 T-018 增量：

- 修复全部 parse/runtime 错误，工程可启动。
- 修复重开冷却未清、强化生命未继承新兵、暮霜附魔只影响冰塔、freed target 引用、banner 穿透模态层。
- 完成可玩闭环与 UI 交互（含 HUD 点击、建造快捷键 1/2/3）。
- 新增 smoke / full-run / perf / screenshot / video 五个工具与 9 张 1080p 截图、10s 视频。
- 调亮整体曝光、重做核心材质与光效、降低范围环过曝、初始机位改为能看到核心和初始军团。
- 补齐 README / TECH / 迭代记录 / CREDITS。


## 10. T-20261127-020 美术 pass（2026-11-28）

- 目标：按 T-019 brief 做第一遍生产级美术；不改玩法/数值/AI/波次/经济。
- 新增 `scripts/legion_mesh_kit.gd`：程序化低模的 **顶点色合并器**。每个 body / arms / 2 legs / glow / shadow 各 1 个 `ArrayMesh` + 1 材质，把一个单位从 20+ 个 MeshInstance 降到约 6 个 draw；静态遗迹/树/浮岩/远景合并成 1 个 mesh，雾改为 1 个 MultiMesh，车道床/余烬各 1 个 mesh。
- 美术重写：4 玩家角色（筝盾卫士 / 横向弩弩手 / 立杖术士 / 翼肩披风英雄）、3 敌人（骨甲裂爪/尾炮酸刺/熔炉巨像）、3 塔 × Lv1–3 + 等级旗标、3 种原创传送门、7m 核心 + 30/66% 血量态、建造幽灵预览、伤害数字、死亡余烬、Q 三环+余烬、每单位接触影。
- UI：`legion_ui.gd` 重绘为 1280×720 设计（1080 = 1.5×）；HUD 面积 **24.8%**；最小字 12（热键/装饰），关键 16–22；对比 ≥5.33:1；SEED/FPS/DC 移入 **F3** 调试层；新增实心两色图标、建造/升级/帮助/结算版式、720 真实 1280×720 截图。
- 计分/验收工具：`tools/art_check.py`（只读截图，输出 L*/ΔL*/过曝/Q 近白/剪影 IoU/WCAG/HUD 面积/25%+灰度）；`screenshot_legion_td.gd` 输出 `docs/shots/after/` 17 张；`video_legion_td.gd` 输出 10s/150 帧；`perf_legion_td.gd` 增加 peak 场景与 JSON。
- 实测（真实 GPU，Intel HD 6000，vsync off）：
  - 基线（8 塔 Lv3 + 第 4 波 + 小队 + Q）：1080p **41.1 FPS / P95 29.70ms / 292 dc**；720p **55.6 FPS / P95 22.05ms / 292 dc**。T-018 为 36.8 FPS / 36.73ms / 727 dc 与 38.2–41.2 FPS / 34.17–35.38ms / 727 dc。
  - 峰值（44 玩家 + 20 敌人 + 8 塔 Lv3 + Q）：1080p 25.2 FPS / 49.96ms / 639 dc；720p 32.0 FPS / 45.59ms / 639 dc。**峰值仍超过 550 dc 硬上限，交 game-engineer 做 MultiMesh/全局血条/阴影/UI 合批/LOD。**
- 视觉读数：地表 L*19.3、石道 37.1（Δ17.8）、敌人 vs 地表 Δ22.4、玩家 vs 地表 Δ46.0；玩家职业剪影最大 IoU 0.586、敌人 0.602；Q 近白 0.011%；全屏 >245 最高 0.69%。
- 文档：`docs/art-pass-T-20261127-020.md`、`docs/art_check_after.json`、`docs/perf_legion_td_after.json`、`docs/shots/after/README.md`；`docs/shots/before/` 保留 T-018 原图，`docs/shots/after/` 为本轮证据。
- 未做：第 4 敌型（需 designer 签字）、骨骼/mocap、LOD、原生 1920 UI 画布、音频、盲测；峰值性能尚未全绿。
