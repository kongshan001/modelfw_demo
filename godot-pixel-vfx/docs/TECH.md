# TECH · Pixel VFX Lab

任务：T-20261121-023。目标是把 PixelFX（MIT）的像素特效导出为引擎可用的 sprite sheet，在 Godot 4.6 中做成可交互、像素完美、可清理的 VFX playground。

## 1. 资产管线

- 来源：<https://github.com/patch-gg/pixelfx>
- Commit：`5294518ce7c72e48b6100a744596e0acf57f2826`（2026-11-12；“Link pixelfx's page on Patch (#13)”）
- 版本：`package.json` 0.3.1；渲染器 `tools/render.mjs`，Node 18+，本机 Node v22.19.0。
- 许可：MIT。`assets/pixelfx/LICENSE`、`assets/pixelfx/NOTICE.md` 原样保留。NOTICE 注明 `src/core/sim.js` 及部分效果改编自 Hugo Duprez / Sprite Fusion（MIT），`src/core/act.js` 改编自 Hollow Crown（MIT），以及 gallery 的 Patch Pixel 字体不在 MIT 范围内。**本项目不打包该字体，也不打包 PixelFX core 代码。**
- 导出：官方渲染器的 `--sheet` 模式，输出透明 PNG + Aseprite 风格 JSON（`frames[]` + `meta.pixelfx`：fps、loop、columns、pivot、frameSize）。

### 1.1 选用的效果

| 组 | PixelFX id | 帧 | fps | 时长 | JSON loop | 运行时 | 帧尺寸 | pivot | sheet |
|---|---|---|---|---|---|---|---|---|---|
| 挥剑 | `melee/double-slash` | 25 | 30 | 0.833 s | false | 单次 | 164×108 | 44,92 | 820×540 |
| 火球 | `fire/fireball` | 36 | 30 | 1.200 s | true | 循环（投射物） | 136×56 | 112,28 | 544×504 |
| 爆炸 | `explosions/small-explosion` | 163 | 30 | 5.433 s | false | 只播 2.2 s | 300×240 | 150,196 | 3600×3360 |
| 冰冻 | `ice/freeze` | 121 | 30 | 4.033 s | false | 单次 | 176×128 | 88,108 | 1760×1664 |
| 金币 | `pickups/coin-spin` | 48 | 30 | 1.600 s | true | 循环 | 56×56 | 28,48 | 392×392 |
| 拾取爆闪 | `pickups/collect-burst` | 42 | 30 | 1.400 s | false | 单次 | 112×108 | 56,94 | 784×648 |

`collect-burst` 使用金色 palette 重新导出，使其与金币一致：

```bash
node tools/render.mjs pickups/collect-burst --sheet \
  --opts '{"palette":["#1a1205","#3d2a08","#704a0c","#b07b12","#f5b92c","#ffde5e","#fff4bc","#ffffff"]}'
```

其余五组为默认 palette：

```bash
node tools/render.mjs melee/double-slash fire/fireball explosions/small-explosion \
  ice/freeze pickups/coin-spin --sheet
```

完整命令、SHA-256 见 `assets/pixelfx/MANIFEST.json`；复现脚本 `tools/export_pixelfx.sh`（要求 checkout 指向记录 commit；commit 不一致会警告，且不会自动改写 MANIFEST 哈希）。

### 1.2 为什么截断爆炸

`small-explosion` 的 JSON 时长为 5.433 s，后 3 s 主要是落地余烬/烟柱。运行时 `SpriteFX.max_time = 2.2`：只播放前 66 帧，既保留白闪、冲击环、火球和烟，又避免烟柱长时间遮住木桩。截断在运行时不修改 sheet，JSON 仍保持原始 163 帧信息，便于回溯。

## 2. 渲染与像素完美

- 世界：640×360 `SubViewport`，`msaa_2d = DISABLED`，`snap_2d_transforms_to_pixel = true`，`snap_2d_vertices_to_pixel = true`。
- 显示：`TextureRect` 填满 1280×720（`stretch_mode = SCALE`, `expand_mode = IGNORE_SIZE`），`texture_filter = NEAREST`。项目设置 `textures/canvas_textures/default_texture_filter=0`。720p 为 2×，1080p 为 3×，均为整数。
- 角色/金币/特效位置取整；相机震动只使用整数偏移 `Vector2i(-2..2)`。
- Godot 舞台用整数像素 `draw_rect` / `draw_colored_polygon`（无 AA）绘制；像素字形由 5×7 位图逐像素绘制。
- HUD 在 1280×720 的 `CanvasLayer` 上绘制（非世界 SubViewport），中文字体由 `SystemFont` 运行时栅格化，不打包字体文件。
- macOS HiDPI：项目设置 `window/dpi/allow_hidpi=false`。原因：本机 Intel HD 6000 在 Retina backing（窗口物理 2560×1440）下实测会掉到 20–30 fps 且抖动；关闭后在同负载下 1280×720 窗口为 **66.4 fps 平均**。窗口逻辑分辨率仍是 1280×720，游戏内仍是整数 2×。代价是 OS 会把 1280 窗口放大到屏幕物理像素，边缘由系统合成器处理；项目内渲染仍是最近邻。需要 Retina 原生锐度可改回 `true`，并接受帧率下降。
- 1920×1080 验证：本机显示器 1440×900，截图/性能测试使用 1920×1080 离屏 `SubViewport`；世界按 3× 放大，HUD 通过 `set_hud_ui_scale(1.5)` 以 1280 布局生成后放大 1.5×。

## 3. JSON 驱动的播放器

`scripts/fx_library.gd`
- 启动时读取 6 组 JSON；校验 `frames` 与 `meta.pixelfx` 非空，取 `frameSize`、`columns`、`fps`、`loop`、`pivot`，缓存 `Texture2D`。任何缺失/解析失败都会 `push_error` 并列入 `errors`，冒烟测试会检查。

`scripts/sprite_fx.gd`
- 纯 `Node2D`，**不实现 `_process`**；由 `Main.tick(dt)` 手动驱动，便于 headless 冒烟与确定性截图/录屏。
- `time += dt * speed`；帧号 `floor(time * fps)`；帧矩形由 `columns` 与 `frameSize` 计算；`loop` 时取模，否则结束返回 false；`max_time` 用于爆炸截断。
- `_draw()` 用 `draw_texture_rect_region`，目标矩形为 `(-pivot, frameSize)`，即节点位置就是 JSON pivot 对应的地面/原点。所有实例 `texture_filter = NEAREST`。
- `step(dt)` 返回是否继续；`Main` 在返回 false 时 `queue_free()` 并从 active 列表移除。

## 4. 表演时序（Main）

- 全局 `speed_mult` ∈ {0.5, 1, 2}，`dt = remaining_delta * speed_mult`；影响特效、冷却、灼烧/冰冻计时、金币重生和投射物。
- **命中停顿**：命中时 `hitstop = 0.06–0.08 s`。`tick()` 只消耗 hitstop 拥有的那段 delta，剩余时间继续推进；命中发生的当前 tick 会跳过 `world.step()`，让白闪/伤害数字冻在接触帧。冒烟测试用 2× 下 `tick(0.05)` 验证 FX 时间前进 0.10 s、0.5× 下 `tick(0.2)` 前进 0.10 s。
- **震屏**：`shake(amp, seconds)`，相机 `offset` 为整数随机值，随时间线性衰减；挥剑 2 px/0.18 s，火球 3 px/0.26 s，冰冻 1 px/0.12 s。
- **挥剑**：在玩家脚底 `(180,300)` 生成 `melee/double-slash`，0.16 s 后命中：木桩白闪 `flash=1`、后仰 `recoil=3.4`、伤害 12–18、hitstop 0.08、震屏 2 px。特效 0.833 s 播完清理。
- **火球**：投射物从 `(196,260)` 以 120 px/s 飞向 `x=238`（约 0.35 s）。`fire/fireball` 循环，头在 pivot，尾焰向左拖。命中后在木桩脚底生成 `small-explosion`（2.2 s 截断），灼烧 3.0 s，伤害 24–32，hitstop 0.06、震屏 3 px。灼烧期间木桩向 `#ff7a33` 混色（0.20 + 0.07 sin 闪烁），肩部有火苗/火星；HUD 与头顶状态条同步倒计时。
- **冰冻**：在木桩脚底生成 `ice/freeze`（4.033 s），状态 2.9 s；木桩向 `#8fd8ff` 混色 0.42，脚边/肩部叠加小型原创冰晶和雪点；HUD chip 与头顶 34 px 计时条显示剩余时间。碎冰/融化片段保留完整 4.033 s，状态提前 1.1 s 结束，视觉上正好对应冰壳开裂。
- **金币**：4 枚位于 `x=352/404/462/524,y=300`，每枚 `coin-spin` 相位偏移 `i×0.37 s`，避免四枚同时变成侧面细条。拾取时 `coin.collect()` 置 `collected=true`，分数 +10，`collect-burst` 以 45 ms 间隔依次生成（视觉上的“多枚同时拾取”），2.6 s 后重生。`collect_all_coins()` 二次调用返回 0，防止重复计分。

## 5. 清理与状态机

- `Main.active_fx` 保存 `{node, kind}`；每 tick 逆序 `step`，结束即从数组移除并 `queue_free`。循环特效只有金币（由 `CoinPickup` 自己持有），不会被 `active_fx` 管理。
- 爆炸用 `max_time=2.2` 自动结束；冰冻自然结束；挥剑自然结束；收集爆闪自然结束。
- 伤害数字/`+10` 是 `PopupText` 节点，`world.popups` 管理，寿命 0.72–0.85 s，结束后移除。
- `reset_all()` 清理所有 active fx、投射物、popup、状态、冷却、震屏，并恢复四枚金币。
- 冒烟测试在 10 s 推进后断言 `active_fx=0`、`fx_layer` 无子节点、popup 为空、无投射物、无状态。

## 6. UI

- 标题「PIXEL VFX LAB」、分数、按键徽章使用原创 5×7 位图字体（`pixel_font.gd`），逐像素绘制，整数倍缩放。
- 中文说明/按钮/状态 chip 使用 `SystemFont`：PingFang SC → Hiragino Sans GB → Heiti SC → Microsoft YaHei → Noto Sans CJK SC → Arial Unicode MS → sans-serif；开启系统 fallback，无字体文件入库。AA 为 GRAY、hinting LIGHT，以保证 1280/1920 下中文可读。
- 面板/按钮为硬边矩形 + 2 px 描边 + 像素缺口；四个按钮的强调色分别是 slash `#ff6d9e`、fire `#ff8a3d`、ice `#7fd4ff`、coin `#f5c84b`。
- HUD 显示：标题、中文副标题、金币分数、FPS（交互时实时；录屏显示 DEMO；截图显示 1080p 实测代表值）、冰冻/灼烧倒计时、速度 0.5×/1×/2×、操作提示。
- 键盘 1–4/5–7/R 与鼠标按钮共用同一组 `Main` 方法；金币支持鼠标点选（屏幕坐标按 `WorldDisplay` 矩形反算到 640×360 世界坐标）。

## 7. 性能与验证

设备：Intel(R) HD Graphics 6000，OpenGL 4.1 Compatibility，macOS（Retina 面板，1440×900 逻辑）。

测量方式：`tools/probe_pixel_vfx.gd`，先预热四组特效（上传 3600×3360 爆炸图表并编译 canvas 管线），再连续 4 s 每 0.8 s 触发一次特效；采样 `Engine.get_frames_per_second()`。测量时机器上还有其他 worker（另一 Godot 截图/headless 进程），数字按“有竞争”记录。

| 场景 | 平均 | 最小 1 s 采样 | 备注 |
|---|---|---|---|
| 1280×720 真实窗口 | **66.4 fps** | 29 | `allow_hidpi=false`；同一轮测试 |
| 1920×1080 离屏 3× | **40.7 fps** | 2 | 首帧大图上传的 1 次卡顿；随后正常 |

`docs/perf.json` 为最近一次测量原始输出。平均值均 ≥30。首次使用大图表（爆炸 3600×3360）会有一次上传卡顿；`probe` 先预热以模拟游戏中第一次施法后的稳定状态。若把 HiDPI 打开，本机 1280×720 窗口会明显降到 20–30 fps，故默认关闭。

验证命令与结果：

```bash
# 干净检出先构建 .godot 缓存 / 全局 class_name 表，否则 -s 脚本无法解析类型
$ godot --headless --path godot-pixel-vfx --import

$ godot --headless --path godot-pixel-vfx -s tools/smoke_pixel_vfx.gd
...
PIXEL_VFX_SMOKE_OK checks=all

$ godot --path godot-pixel-vfx -s tools/probe_pixel_vfx.gd
PROBE 720p_window frames=266 sec=4.01 avg=66.4 min_sample=29.0
PROBE 1080p_offscreen frames=163 sec=4.00 avg=40.7 min_sample=2.0
PIXEL_VFX_FPS_OK 720p=66.4 1080p=40.7

$ godot --path godot-pixel-vfx -s tools/screenshot_pixel_vfx.gd
SHOT ... 1920x1080 (×8)
PIXEL_VFX_SHOTS_OK files=8 size=1920x1080
```

真实 GPU 启动（`godot --path . --quit-after 180`）和截图脚本均未输出 `ERROR`/`SCRIPT ERROR`。`docs/verification.log` 保存了 smoke、GPU 启动、截图与 perf 的原始输出。冒烟还覆盖 `1`/`5` 键与 4 个特效按钮 + 3 个速度按钮的命中矩形；`tools/verify.sh` 为干净检出的一键流程（import → smoke → FPS → 截图）。

## 8. 截图 / 视频管线

- 截图：`tools/screenshot_pixel_vfx.gd` 用 1920×1080 离屏 `SubViewport`，关闭 `Main._process`，按 1/60 s 手动推进到确定姿势，`RenderingServer.frame_post_draw` 后保存 PNG。为了显示 FPS 字段，HUD 使用 1080p 实测代表值 41（`FPS_OVERRIDE`）；这是截图专用固定字段，交互运行读取真实 `Engine.get_frames_per_second()`。
- 视频：`tools/capture_pixel_vfx.gd` 在 1280×720 离屏里按 1/30 s 推进 300 帧，输出到 `/tmp/pixel_vfx_frames/frame_%03d.png`；`tools/build_media.sh` 用 ffmpeg 生成 10 s MP4（30 fps、CRF 18）和 GIF（20 fps、960×540、192 色、nearest、无 dither）。GIF 2.1 MB，MP4 1.0 MB。
- 10 s 时间线：0–1 s idle；1.0 挥剑；2.0 火球；3.0 冰冻；4.0 四枚金币；5.0/5.4/5.8 连招（挥剑/火球/冰冻）；7.1 第二次金币；8.0 切 2× 并挥剑/火球；9.0 回到 1×。

## 9. 已知限制 / Handoff

- 无音频、手柄、存档；伤害值只驱动数字与反馈，没有敌人 HP/战斗结算。
- 冰冻壳是按 PixelFX 默认角色轮廓绘制的，本项目 44 px 草靶视觉上能套入；冰壳不是碰撞体。
- 金币“同时拾取”为了可读性将 collect burst 以 45 ms 错峰呈现；逻辑上四枚在同一按键帧内全部结算，分数一次性 +40。
- 1080p 的 FPS 是离屏渲染数据（显示器 1440×900）。真实 1080p 全屏窗口未在本机验证；如接入 QA 的 1080p 显示器，建议重跑 `probe_pixel_vfx.gd` 并观察首次大图上传卡顿。
- 非 macOS 若无 CJK 系统字体，HUD 中文可能 tofu；需要替换 `hud.gd` 的 `font_names` 或引入有许可字体（当前刻意不打包）。
- 如接入实际游戏：`SpriteFX` 可直接复用；把 `Main.tick` 的全局速度/冷却换成游戏时间，特效位置从角色骨骼点传入即可。玩法/数值/性能集成归 `game-engineer`；验收归 `game-qa-lead`；风格复评归 `game-art-director`。
