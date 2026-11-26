# 余烬堡 3D · 技术方案

> Godot 4.6 / GL Compatibility / 程序化低模 3D / 玩法与 AI 从 HTML 版 1:1 移植

## 1. 目标与边界

- 目标：把 `web-html-tower-defense/` 的完整塔防规则、数值、波次和 AI 行为移植到 3D；保留 HTML 版不修改。
- 平台：Godot 4.6，GL Compatibility；1280×720 逻辑，窗口 1920×1080 时 3D 战场自动 1.5× 超采样；Intel HD 6000 实测 ≥30 FPS。
- 资产：全部程序化生成（低模、顶点色、材质、UI 形状）；无第三方模型/贴图/音频/字体文件。
- 表现：3/4 正交相机、3D 塔/敌人/地形/道具/门/灯塔/投射物/VFX；**不用 2D billboard 代替 3D 模型**（血条等 UI 例外）。

## 2. 运行时结构

```
scenes/main.tscn
  Main (Node3D)                       scripts/main.gd
    FieldLayer (CanvasLayer 0)
      FieldBox (SubViewportContainer)  逻辑 928×672，scale 1..1/1.5
        FieldView (SubViewport, own_world_3d)
          Camera3D (orthographic 3/4)
          Sun / Fill (DirectionalLight3D)
          WorldEnvironment (color bg + ambient + depth fog)
          World
            MapRoot / Towers / Enemies / Projectiles / VFXRoot / Indicators
    UILayer (CanvasLayer 10)
      HUD (Control, custom _draw)     scripts/hud.gd, 1280×720 逻辑
    DitherLayer (CanvasLayer 5)
      Dither (TextureRect, field-sized) 地图过渡 snapshot + shader
```

- 根窗口 `stretch_mode=canvas_items`，1280×720 逻辑。`FieldBox.stretch=false`，main 根据实际 framebuffer 尺寸把 3D 子视口扩到 928×672 × s（s=window_width/1280，clamp 1..2），再用 `scale=1/s` 显示回 928×672 逻辑面积。这样 1280 原生、1920 不糊。
- HUD 是单个自定义绘制 `Control`（`_draw`），命中区数组在每次绘制时重建；鼠标事件在 `_gui_input` 中处理，字段点击转成 `field_pressed(local, button)` 信号给 main。
- 模拟固定 1/60s；渲染独立。main `_process` 用累加器 `accum += dt × speed`，每帧最多 40 步，暂停不推模拟，倍速 1/2/3。转场期间同样暂停模拟（与 HTML 一致）。

## 3. 模拟层：game_model.gd

`GameModel extends RefCounted`，无渲染/场景依赖，可在 headless 直接驱动。所有单位/塔/波次/金币/AI 都在这里。

- **坐标**：沿用 HTML 的 field px（x∈[0,464), y∈[0,336)），视觉层用 `0.125 world/px` 映射。射程/溅射/治疗半径/速度不需要换算即可保持原值。
- **地图准备**：`map_info.gd`（路径段、点、采样） + `map_data.gd`（waypoint、装饰、可建造格）。
  - 路径每 6px 采样；可建造格 = 中心到路径 ≥15px；装饰候选 27–92px，8 个，Chebyshev 相邻排除；
  - 复刻 HTML 的 `mulberry32` 与 `hash2` 32-bit 序列；道具顺序/类型/seed 与 HTML 完全一致（smoke 断言）。
- **战斗**：塔冷却 = 1/rate；目标按路径进度 `e.dist` 最靠前；伤害 `max(1, round(dmg-armor))`；霜减速 `amount × (1-slowResist)`；孢母每 1.35s 治疗 6（初始 0.7s）；Boss HP 随波次缩放 `round(1120 × hpScale(12)) = 3030`。
- **波次**：每波以 `{type, t=0.15+delay+i*gap}` 生成，按 t 稳定排序；清空队列且无存活敌人后结算；12 波清空即胜利。
- **AI**：`ai_think` 严格按 HTML 优先级：技能 → 起手攻击塔 → 必需霜/焰 → 圣坛 → 数量目标 → 升级 → 扩塔（≤12）；选点、升级评分、存钱日志（9s 去重）与 HTML 一致；每 0.55s 决策；所有动作走同一个 `try_build/try_upgrade/cast_skill`，共用金币/冷却，无作弊。
- **信号**：`enemy_spawned/killed/leaked/healed`、`tower_built/upgraded/sold/fired`、`impact`、`skill_cast`、`toast`、`game_over` 等，main 只负责把状态映射到 3D 表现；模拟不受视图影响。
- **autotest**：`run_autotest()` 复刻 HTML `?autotest=1`（首波 prep=2.5s），用于两图 AI 验收。

## 4. 3D 表现层

### MeshKit 与材质

- `mesh_kit.gd`：程序化三角形构建器（box/cylinder/sphere/octa/disc/ring/chevron），把多种颜色合并进**一个 SurfaceTool → 一个顶点色网格**，减少 draw call。
- 颜色来源是 HTML 调色板；由于 PBR/顶点色管线会显著压暗，`MeshKit.lift()` 做 gamma 0.48 + 1.22 饱和度提升，再配合材质 albedo（地面/路径/角色分别 1.45–1.55）与场景灯光达到可读的低模色阶。
- 材质资源放在 `materials/*.tres`（stone/bone/gold/ember/frost/ground/path/water/char_vertex），供 T-030 直接替换。`char_vertex` 使用顶点色、关闭背面剔除（程序化薄面安全）。

### 场景/视图

| 场景 | 内容 |
| --- | --- |
| `map_view.tscn` | 68×52 单位地形网格（顶点色 + 高度噪声；路径 3 层 ribbon + 磨损石板 + 边石 + 3D chevron）、8 个阻挡道具（树/石/骨/冰晶 + 发光点 + 接触阴影）、出生门（双柱+横梁+发光帷幕+旋转环+粒子+OmniLight）、终点灯塔（锥塔+火核+光环+光束+OmniLight+粒子）、边界岩/枯树 MultiMesh、草丛/碎石 MultiMesh、环境余烬/霜点粒子 |
| `tower_view.tscn` | 燧石（基座+弩炮，可转向/开火）、焰炉（火盆+火焰）、霜环（冰晶+旋转核心）、圣坛（金坛+旋转金币）；3 级外观；幽灵模式（半透明绿/红） |
| `enemy_view.tscn` | 行者（斗篷+兜帽+双臂+发光眼）、幽火蛾（身体+拍翅双翼）、锈甲兽（四足+护甲+角）、孢母（浮空孢子+触须+紫色核）、Boss（巨型黑曜石躯干+角冠+熔火裂纹）；血条 Sprite3D（UI 例外）、受击白闪/减速青染、地面接触阴影、悬浮/拍翅/呼吸动画 |
| `projectile_view.tscn` | 箭矢（细长发光体）、炽炭（球体+抛弧）、霜晶（旋转八面体） |
| `vfx.tscn` | CPUParticles 爆发、地面 ring、Label3D 浮字、烬雨全场雨+环；全部一次性自动释放 |
| `main.tscn` / `main.gd` | 状态机、相机、输入、视图同步、HUD、转场、QA hooks |

- 相机：正交，yaw −11° / pitch −57°，target (0,0.7,0.5)，size 47；菜单缓慢左右 orbit；游戏内随鼠标轻微视差 + 屏幕震动（来自 model.shake）。
- 环境：`WorldEnvironment` 背景色、环境色、深度雾；两盏方向光（主光暖色，补光冷色）。实时阴影默认关闭（见性能），塔/敌人/道具使用程序化接触阴影。
- 投射物高度：箭矢/霜晶 1.25→0.62 线性，火球另加 sin(πt)×2.3 的抛物弧；命中判定仍由 2D 逻辑完成，视觉高度不影响平衡。

## 5. UI 与输入

- HUD 使用 `SystemFont`（PingFang SC 等）+ 自绘矩形/线条/图标；全部中文字符串。字体不打包。
- 显示区域：顶部资源/技能/倍速/AI/地图/FPS/DC；右侧商店 4 卡、选中/建造信息与升级/出售、AI 决策 3 条、敌情/波次/悬停敌人信息、暂停/倍速/重开/换图/菜单；底部战场波次条；Boss 血条；Toast。
- 菜单：3D 地图背景 + 双地图卡（2D 路径缩略图，程序化绘制）+ 手动/看 AI + 键位提示；选图也走抖动过渡。
- 暂停：战场变暗 + 面板（继续/重开/菜单），侧栏仍可建造升级（同 HTML）；结算：胜利/失败、6 项统计、重开/换图/菜单。
- HUD 每 10Hz 重绘以降低 CPU 文本整形/2D draw call 成本；点击、选塔、状态事件立即在下一帧重绘。3D 仍每帧 60Hz。实测这是 Intel HD 上从 ~30 提升到 ~47 FPS 的关键优化。
- 3D 拾取：`Camera3D.project_ray_origin/normal` 到 y=0 平面 → world → field px → 格；敌人悬停用 `unproject_position` 的屏幕距离阈值。HUD 命中区优先于战场点击。
- 键盘映射与 HTML 一致（1–4/U/E/S/X/Space/P/F/Tab/A/Q/M/R/Esc），菜单 Enter/W/方向键。

## 6. 地图过渡

- `_begin_transition(mid)`：
  1. 抓取 `FieldView` 当前帧（3D 战场，不含 HUD）为 `ImageTexture`；
  2. `Dither` TextureRect（覆盖 928×672 战场、位于 HUD 之下）显示快照，shader `progress=0`；
  3. 调用 mid（换图/开局/重开），新 3D 立即在下面渲染；
  4. 0.88s 内 shader 按 116×84 块（约 8px）的 8×8 抖动近似阈值逐块 discard，旧快照消失；HUD/顶部栏保持稳定。
- shader：`shaders/dither.gdshader`，Bayer 近似 + 少量 hash；`TEXTURE` 为快照，旧图压暗到 0.62。
- 与 HTML 的差异：HTML 盖住整个 640×360 画布；3D 版只盖战场，避免转场时旧/新 HUD 文本重叠。

## 7. 性能

测于 Intel HD Graphics 6000，macOS，共享机器（loadavg ≈ 3.0，GL Compatibility）：

| 场景 | FPS |
| --- | --- |
| 1280×720，全 HUD，AI 第 8 波（12 塔） | 39.9 / 47.6 / 47.4（三次） |
| 1920×1080，全 HUD，同场景 | 39.2 |
| 1280×720，隐藏 HUD | 51.0 |
| 1920×1080 菜单（console 检查） | 0 error / 0 script error |

关键取舍：

- **实时方向光阴影**在 GL Compatibility + Intel HD 上代价约 15–25ms/帧（PSSM/PCF），会把帧率压到 30 以下；默认关闭，保留方向光、环境光、雾和每个单位/塔/道具的程序化接触阴影。需要高画质时：`godot --path godot-emberhold-3d -- --shadows`（512 shadow map，正交 mode 0）。
- **HUD 10Hz**：CJK 系统字体的每帧整形/2D 绘制在 Intel 上很贵（约 20–50ms/次全量绘制）；限频 10Hz 后 3D 可保持流畅，交互时仍会在下一帧重绘。
- **高分辨率 3D**：FieldView 按窗口宽度 1.0–2.0× 扩，1920 窗口为 1392×1008；这样 1920 截图/窗口不糊，但比 928×672 多 2.25× 像素；1280 目标仍是 1.0×。
- Draw calls：正常战斗约 240–340（含 UI 文本）；地图主体 1 个地面 mesh、1 个路径 mesh、道具/门/灯塔若干、边界/草/碎石各 1 个 MultiMesh。单位/塔尽量合并为 1–4 个 MeshInstance（接触阴影/血条/发光另计）。
- 截图工具在 1920×1080 高分辨率离屏 + PNG 读回时 FPS 会显著低于真实游戏；性能以 `--bench` 与抓帧日志为准。

## 8. QA / 工具

| 脚本 | 用途 |
| --- | --- |
| `tools/smoke_emberhold3d.gd` | headless，72 项：地图/建造/升级/出售/金币/护甲/减速/治疗/漏怪/胜负/Boss HP/技能/波次/重开/AI 托管/双图 autotest；末行 `EMBERHOLD3D_SMOKE_OK` |
| `tools/probe_emberhold3d.gd` | 真实场景 29 项：HUD 按钮命中、暂停/继续、AI/倍速、商店→战场建塔→升级→出售、换图过渡、重开、结算按钮、菜单选图/看 AI、键盘 Space/F/A |
| `tools/screenshot_emberhold3d.gd` | 1920×1080 高分辨率截图 9 张（FieldView 1.5×），状态覆盖菜单/建造/战斗/过渡/Boss/暂停/胜利 |
| `tools/make_media.sh` | Godot MovieWriter 10s/30fps → ffmpeg MP4 + GIF |
| `main.gd --bench` | 真实 GPU FPS 压测（AI 到第 8 波、统计 7s） |
| `main.gd --autotest=ashen/frost` | 在真实主场景内跑模型 autotest（快速打印 JSON 后退出） |

QA hooks（仅调试/采集，不参与正常 AI）：`debug_start_game`、`debug_menu`、`debug_fast_forward`、`debug_advance_until_combat`、`debug_advance_until_boss`、`debug_advance_boss_visible`、`debug_freeze`、`debug_pause`、`debug_set_gold`、`debug_pick`、`debug_hover_cell`、`debug_select_tower`、`debug_show_transition`、`debug_hold_current_transition`、`debug_set_field_highres`、`debug_set_hud_rate`、`get_state`。

## 9. 已知限制 / 风险

- 实时阴影默认关闭（性能取舍）；接触阴影不是物理阴影。
- HUD 10Hz 更新，倒计时/FPS 数字有约 100ms 量化；交互不受影响。
- 3D 美术是程序化低模初版，剪影与细节仍留给 T-030 美术 pass；Boss 在远景中不够醒目（已在最近迭代放大 1.55×）。
- 1920×1080 使用 1.5× 3D 子视口，低端 GPU 可能低于 30；1280 是性能目标分辨率。
- 截图中的 FPS 数字受离屏/读回影响，不代表目标设备；以 bench 为准。
- 无音频；无手机专属触控布局；桌面鼠标优先。
- AI 整局（首波 prep 5.6s）与 autotest（prep 2.5s）时序不同，整局时间会不同于 autotest 的 559.67/444.75。
- 冻苔 autotest 时间与 HTML 差 −1.02s（浮点边界），其余数值/塔位一致。
