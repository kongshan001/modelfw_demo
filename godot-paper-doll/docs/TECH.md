# 技术说明 · 纸偶工坊

## 1. 目标与边界

- 引擎：Godot 4.6，2D，GL Compatibility，1280×720，`canvas_items` 拉伸。
- 17 槽位纸娃娃 + 8 方向 + 4 动作 + 独立 tint + z 序 + 16 预设 + 4×4 阵容 + JSON 存读。
- 所有美术在运行时由 GDScript 绘制，不加载外部贴图，不引入第三方运行时依赖。
- 不是完整游戏：没有战斗、关卡、数值；只做“可换装、可观察、可导出”的角色组合器。

## 2. 数据模型

`scripts/doll/doll_data.gd`

- `SLOTS`：17 个槽位，字段 `id / label / z / color_set / default / default_color / variants`。
  顺序即同 z 值时的稳定绘制顺序。
- `COLOR_SETS`：8 组色板（wood / hair / cloth / eye / leather / metal / aura / mask），每组 8 色。
- `DIRS`：8 个方向，包含 `yaw`（0 = 正面，0.55 = 斜向，1 = 正侧）、`back`（是否背向）、
  `flip`（是否水平镜像）。
- `ACTIONS`：`idle / walk / attack / hit`。
- 外观内存格式：`{slot_id: {variant: String, color: Color}}`；
  JSON 格式：`{slot_id: {variant: String, color: "#rrggbb"}}`。
- `normalize_outfit` 对缺失槽位、非法变体、非法颜色做兜底；`encode_outfit` 负责导出。
- 组合空间：所有槽位的 `变体数 × 8 色` 相乘，当前约 `9.0×10²⁶`。
- **色彩纪律（P1-4）**：`OUTFIT_SCHEMES` 提供 8 套 primary/secondary/accent；
  `random_outfit` 先选 scheme，再按“大件 primary 60% / 次件 secondary 30% / 小件 accent 10%”
  分配，帽子/披风/裤/鞋不再各自独立随机高饱和色。`_random_variant_id` 给帽子/武器更高的
  “非 none”概率，保证随机阵容也有破形件。
- **build**：`body` 槽的变体同时决定身体/衣物的横向 build（grain 0.90 / plain 1.0 /
  patch 1.08 / rivet 1.16），只作用于身体与衣物，不拉宽头/五官/武器；它跟着 outfit 存档，
  所以载入同一套外观会得到同一体型。

### z 序

- 基础 z：气场 0、披风 10、背饰 15、木偶身 20、下装 30、鞋 35、上衣 40、腰带 45、
  头 50、耳 52、面具 54、眼 55、发型 60、帽子 65、武器 71、手套 73、挂饰 80。
- `z_bonus` 根据方向与变体修正：
  - 披风背向 `+54`（盖住衣服），围巾 `+36`（压在衣领上）；
  - 背饰背向 `+47`（露出背包）；
  - 武器背向 `-60`（落到身体后方）。
- `draw_order` 按 `z` 升序、同 `z` 按槽位声明顺序稳定排序；smoke 校验 17 层唯一、升序、正反面翻转。

## 3. 骨骼与动作

`scripts/doll/doll_pose.gd`

- 原点 = 脚底中心，y 向上为负。
- 脊柱：hip → chest → neck → head；双臂双骨链；双腿双骨链；五官挂在 head 坐标上。
- 八向（P0-4）：`yaw 0 / 0.55 / 1.0`；`shoulder_narrow = 1−0.36·yaw`、
  `hip_narrow = 1−0.72·yaw`；头部前探 `5.2·yaw`；远侧肩再 −3.5·yaw、近侧肩 +3.8·yaw；
  远侧髋 −3·yaw；渲染层再对整体做 `1.0 / 0.835 / 0.64` 的 x 压缩。侧向时远侧手臂
  基本被躯干吃掉，近侧手臂在身体前；背向由披风槽补兜帽/肩披/双臂/刀鞘。
- 动作曲线：
  - `idle`：呼吸 1.4 local + 摆臂 ±0.05 rad；披风/帽尖 `secondary` 滞后 0.3s；
  - `walk`（T-20261121-001 重做）：0.82s / 8 keys（contact/down/pass/up ×2），原地踏步 gait；
    双腿改为 2 骨 IK（THIGH 25 / SHIN 22），支撑相（p 0–0.58）脚目标 x 固定在 plant，
    摆动相（p 0.58–1.0）抬起 12 local（正/背面 5.5）+ 前探 7 local（正/背面 2）；
    hip bob 2.6±0.9 local、hip sway ±0.9 local、手臂 ±0.52 rad；
    脚掌 `_walk_foot_pitch`：−15° 脚跟 → 0° 全掌（p 0.10–0.36）→ +22° 脚尖（p 0.58），
    踝点按鞋底最低点补偿（`WALK_SOLE_DROP 5.4`、`WALK_FOOT_PIVOT 8.5`），不再叠加 shin 角度；
    披风/发 `secondary` 3.4 local、滞后 2 帧 @30fps（0.82s 内 0.51 rad，披风 sway ≈ ±4.8 local）。
  - `attack`：1.05s；0–0.28 蓄力（arm_r 0.14→−2.30）、0.28–0.40 蓄力停顿、
    0.40–0.52 挥砍（→1.55）、0.62–0.98 收势；`slash` 在 0.40–0.64 之间；
  - `hit`：1.10s 指数衰减；后脚退 6 local、头 −0.30 rad、披风滞后 −5.2。
- 所有槽位仅读取同一份 pose 字典，因此换装、换向、换动作时部件天然对齐。

### 3.1 walk 锁脚与脚掌滚动

旧版 walk 只在 hip/knee 上叠角度，支撑脚随步幅向后扫：QA 实测 dir6 45.26px、dir0 5.42px
（阈值 2px @2.1×）。T-20261121-001 按评审 R2-P0-2 的“原地踏步 gait”分支重写：

| 参数 | 值 | 作用 |
| --- | --- | --- |
| `WALK_PERIOD` | 0.82s | 保留原 8 keys 周期（每 key 0.1025s） |
| `WALK_STANCE` | 0.58 | 支撑相占比；脚目标 x 在支撑相严格固定 |
| `WALK_GROUND` | −3.0 local | 踝点基准；鞋底最低点与站立一致 |
| `WALK_HEEL` / `WALK_TOE` | −0.2618 / +0.384 rad | −15° 脚跟 / +22° 脚尖 |
| `WALK_FOOT_PIVOT` | 8.5 local | 鞋掌前后半径，用于踝点抬高的滚动补偿 |
| `WALK_SOLE_DROP` | 5.4 local | 靴中心偏移 0.5 + 半高 4.9，用来把鞋底最低点压回同一地面 |
| 支撑相摆动 | x 0.00 local | 锁脚目标；髋部只做 bob/sway，IK 反解膝/踝 |
| 摆动相 | 抬 12 / 前探 7 local（yaw=1） | 膝盖前弯、脚离地；正面/背面降为 5.5 / 2，避免侧向过夸张 |

- 正面/背面（yaw<0.20）：左右膝分别向外对称让位，读作原地踏步，避免同向侧踢；
  3/4 与侧面：两膝都朝美术朝向（+x）弯曲，避免反关节。
- 脚掌俯仰只做矢状面，不叠加 shin 角度，因此脚踝不会外翻/扭曲；支撑相中段全掌贴地。
- `tools/qa_motion_probe.gd` 0/6 向 = 0.00px；`tools/artist_walk_probe.gd` 8 向 = 0.00px，
  膝内角最大 151.3°（无过伸），脚掌区间 [−15.0°, +22.0°]，左右曲线误差 0.0000 local。

## 4. 绘制管线

`scripts/doll/part_painter.gd` → `PaintFigure / PaintCloth / PaintProps` → `DrawKit`

- `PartPainter.PAINTED` 是槽位→变体的完整覆盖表；`validate()` 在 smoke 中检查无遗漏。
- 画笔统一使用 DrawKit 的形状原语：圆、椭圆、圆角矩形、多边形、胶囊、折线、弧、星星。
- 每个槽位独立取色：`make_palette(primary)` 从 `RAMPS` 匹配最近的五档 ramp
  （deep / shade / base / light / hi），没有匹配则按 HSV 派生；木/布/皮/金/纸各有独立
  `material()` ramp。
- **线宽层级（P0-1）**：
  - L0 外轮廓 `OUTER_STUDIO = 1.15 local`（试衣镜 2.1× ≈ 2.4px）；
  - L1 结构线 `0.55×ow ≈ 1.3px`；
  - L2 细节线 `0.40 local ≈ 0.8px`；
  - 内层部件 outline 传 `0` 或 `0.28–0.58×ow`；`mini` 只保留 L0，并把线加粗到
    `OUTER_MINI = 2.30 local`（0.56× 卡片 ≈ 1.29px），同时删除木纹/缝线/铆钉/睫毛等细节。
- **材质细节预算**（只在屏幕长度 ≥3px 时画）：
  - 木：2 条年轮弧（0.4px `#9a653f` 50%）；
  - 布：1–2 条折线（0.4px shade）+ 下摆 shade；
  - 皮：0.6px 针脚 + 铆钉；
  - 金属：2px `#fffaf0` 高光 + 金色只做扣/饰；
  - 纸：4% 纸纤维（0.32px 短线）+ 1.5px 层影 `(1.7,2.7)` + 切边色。
- **光照语言**：躯干/头/披风/帽/四肢右缘 0.9–1.1px `#ffe0a8` 暖轮廓，
  左缘 0.6–0.8px `#a8d4dd` 冷轮廓；受光面 `light` 40–60% 椭圆，背光面 `shade` 32–40%。
- **层视**：`explode` 按绘制层序号把整层沿 `(4.6, 5.2) local × (i−8)` 展开；
  `highlight_slot` 把其余层 alpha 降到 0.42。

### 三角形批处理（性能关键）

`DrawKit.begin_batch(canvas_item)` 在 `PaperDollRenderer._draw` 开始时启用，结束时 `end_batch()`：

- 所有填充 / 描边不再逐条 `draw_*`，而是写入 `PackedVector2Array` + `PackedColorArray` + 索引；
- 一次 `RenderingServer.canvas_item_add_triangle_array` 提交整只纸偶；
- 三角形按绘制顺序追加，层级与透明度顺序不变；
- 描边由“线段四边形 + 折点圆片”组成；圆形/椭圆/胶囊预先三角化；
- 阴影带坐标缩放，保留在批次外单独绘制。

在 Intel 集显 / macOS OpenGL 上，这套批处理把单偶重绘的提交开销从数百条指令降为一次提交，
是达到 30 FPS 的必要条件。

T-010 追加的绘制预算：

- `DrawKit.make_palette(primary)` 按 `#rrggbb` 缓存（色板只由 primary 决定），每只纸偶的
  17 次取色不再重复匹配 15 组 ramp；
- `mini` 批次（`DrawKit.set_mini(true)`）圆/圆环上限从 28/30 段降到 18/20 段，弧线最多 18 段，
  `_stroke` 省略折角圆头；缩略图在 2× 下采样后差异 <1px；
- `PaperDollRenderer` 记录 `last_draw_usec`，供 `tools/perf_paperdoll.gd`
  输出烘焙成本，不参与画面逻辑。

## 5. 渲染与 UI

- `PaperDollRenderer`：单个纸偶的 CanvasItem；`set_doll / set_direction / set_action / set_clock`；
  朝左时 `scale.x` 取负实现镜像；`show_shadow / show_effects / silhouette / mini / explode /
  highlight_slot / redraw_hz` 可调。
  - 试衣镜默认 `redraw_hz = 24`（定格木偶节奏），空闲时无重绘。
  - 渲染时按 `yaw` 设 `DrawKit.set_xscale`；`body` 变体再给身体/衣物乘 build。
  - 接触影：环境 223×34 + 接触 168×32（1280 口径），三层同心椭圆近似 blur 8，
    颜色 `#463426` α 0.030/0.105，整体下移 2px。
  - 斩击：三层弧 4.6px `#8f3030` + 2.6px `#b23c33` + 2.0px `#ffd27a`，半径 46–58 local。
- `DollThumbnail`：把 `PaperDollRenderer` 放进 `SubViewport`，渲染两帧后把
  `render_target_update_mode` 设为 `UPDATE_DISABLED`，外层用 `TextureRect` 显示结果。
  - 用于 16 张阵容卡与 8 向 / 4 动作对照页，避免 24 个木偶每帧重画。
  - **T-010 2× 超采样**：`viewport.size = 显示尺寸 × 2`，`doll.set_display_scale(display_scale × 2)`，
    外层 `TextureRect` 保持原尺寸并显式 `TEXTURE_FILTER_LINEAR`（无 mipmap）。
    GL Compatibility 不支持 2D MSAA，这是 AA 的兜底路径。
  - `mini` 纸偶只保留 1.3px 外轮廓；`PaintUtil.ol("struct") / detail_w` 在 mini 下返回 0，
    木纹/缝线/铆钉/睫毛/轮廓光整段跳过。`shadow_scale_y = 0.72`，避免接触影被 85px 卡片下缘裁平。
  - **缓存**：`DollThumbnail.set_doll` 按 outfit 签名 + 方向/动作/scale/offset/pad/shadow 去重，
    `set_clock` 按秒数去重；签名不变不重画。`LineupCard.apply_entry` 仍在外层做一次同样的签名检查。
  - 烘焙观测：`bake_count / last_bake_usec / last_draw_usec / bake_stats()`；
    smoke 校验 16/16 卡均为 2× 视口 + Linear + mini，并验证“同签名/同时钟不重烘焙”。
  - 卡片/罗盘/海报关闭 `show_effects`，避免斩击弧在纯黑剪影里变成噪点。
- `main.gd`：用代码构建全部 UI（主题、三栏、页脚、对照弹层、层视、F11 舞台模式）；提供 smoke 所需的
  `set_slot_variant / set_slot_color / set_direction / set_action / save_current / load_saved /
  set_timeline_clock / set_ui_visible / toggle_layer_view / get_*` 验收 API。
- `AtelierTheme`：奶油纸面、墨色描边、珊瑚/青绿/芥末三色；中文最小 11px；
  激活态 `#b23c33 / #2f7a6b / #6c5490`，白字 ≥4.5:1；`MUTED #5f5260`；
  所有控件 `FOCUS_ALL` + 2px 墨色焦点环（2px expand）。
- `StageBackdrop`（P0-5）：`#f4ddc0 → #e4c7a5` 渐变、左上 35% 暖光池 `#fff3d6`、
  太阳移到左上 15%、四周 10% 暗角、64 根纸纤维 + 96 个微点（α 4.5–5%）、
  纸胶带、14% 虚线缝边；不再画第二层地面阴影（由渲染器统一出接触影）。

## 6. 预设与存档

- `presets/lineup_16.json`：16 个原创角色，每个含名字、方向、动作、17 槽 outfit。
- 加载时 `normalize_outfit` 兜底；缺失文件时使用确定性随机 `fallback_lineup()`。
- 当前组合存储格式：

```json
{
  "format": "paperdoll.outfit/1",
  "name": "我的纸偶",
  "direction": "down_right",
  "action": "idle",
  "outfit": {
    "shirt": {"variant": "armor", "color": "#4fa58a"}
  }
}
```

- 默认路径 `user://paperdoll_outfit.json`；`save_current(path)` / `load_saved(path)` 可指定路径，
  smoke 使用 `user://paperdoll_smoke_save.json` 做往返校验。

## 7. 性能

测试环境：macOS，Intel HD Graphics 6000，1280×720，GL Compatibility。

接手时实测约 **1.8 FPS**（16 张阵容卡各挂一个实时纸偶，全部以 24 Hz 重绘，单偶数百条 draw 指令）。
优化后：

| 阶段 | 改动 | 实测 |
| --- | --- | --- |
| 原始 | 16 实时卡 + 逐条 draw | ~2 FPS |
| 卡片烘焙 | SubViewport 只渲染一次 | ~20–26 FPS |
| 三角形批处理 | 每只纸偶一次 `triangle_array` | 41–55 FPS @12 Hz |
| T-006 最终 | 批次 + 24 Hz 试衣镜 + 签名缓存 | 35–55 FPS |
| T-20261120-009 | 新增兜帽/肩披/气场/层视/侧身压缩 | **31–48 FPS，avg 39.0，min 31** |
| T-20261120-010 | 2× SubViewport 超采样 + Linear + mini 几何预算 + 色板缓存 | **30–45 FPS，avg 31.0–38.6，min 30**；verify 最终串联 min 30.0 / avg 31.0（低负载时 33.0/33.3） |

试衣镜与卡片在未变化时不重绘；阵容/对照页在数据变化时才重新烘焙。
`tools/perf_paperdoll.gd` 采样 7 秒（**丢弃首秒暖机样本**，避免窗口焦点/上一进程退出污染），
再逐只测烘焙成本，输出 `PAPERDOLL_FPS_OK/LOW` 与 `PAPERDOLL_BAKE_OK/SLOW`。
早期两次 verify 曾因首秒噪声/后台负载采到 min 29 与 23；改为稳态采样后固定输出
`steady_min / steady_avg`，原始 7 个样本照实打印。
T-010 起同一工具逐只重烘焙 16 张卡 + 6 个对照页缩略图，输出 `PAPERDOLL_BAKE_OK` /
`PAPERDOLL_BAKE_SLOW`：

```text
PAPERDOLL_FPS samples=[30,31,30,31,30,33,31] steady_min=30.0 steady_avg=31.0
PAPERDOLL_BAKE_OK card_median_ms=7.99 card_p90_ms=10.40 card_max_ms=12.04
                  overlay_median_ms=9.63 overlay_p90_ms=10.53 overlay_max_ms=12.41
                  wall_max_ms=80.8 budget_ms=16.0
```

- 判定用 p90（逐只测量，预算 16ms/次）；`card_max` 受飞书/WebKit 后台负载影响可到 17–27ms
  （个别 OS 调度尖峰，p90 仍 ≤16ms），照实输出。`wall_max` 是“请求→视口烘焙完成”的墙钟，
  含 2 帧异步等待与 30ms 轮询粒度，**不是**主线程阻塞时间。
- 超采样不增加 CPU 几何量（与 T-009 相同），只把每个缩略图的填充像素从 1× 提到 4×；
  一次性烘焙后 16 个 SubViewport 全部 `UPDATE_DISABLED`，稳态 FPS 与 T-009 同一量级。

## 8. 验收工具

| 工具 | 作用 | 成功标记 |
| --- | --- | --- |
| `tools/smoke_paperdoll.gd` | 17 槽 / 83 变体 / 8 向 / 4 动作 / 色板 / z 序 / 16 预设 / 随机 / JSON 往返 / 烘焙缓存 | `PAPERDOLL_SMOKE_OK` |
| `tools/qa_motion_probe.gd` | QA 口径 walk 支撑脚漂移（dir 0/6，≤2px @2.1×） | `QA_MOTION_OK` |
| `tools/artist_walk_probe.gd` | 美术自检：8 向漂移 / 膝过伸 / 脚掌区间 / 左右曲线一致 | `ARTIST_WALK_OK dirs=8` |
| `tools/walk_rig.gd` | 侧向/正面 walk 逐帧（640×360 @30fps）+ 1280×720 8 keys 接触帧 | `WALK_RIG_OK` |
| `tools/screenshot_paperdoll.gd` | 真机 1280×720 的 7 张截图（含层视） | `PAPERDOLL_SHOTS_OK` |
| `tools/showcase_paperdoll.gd` | hero / 8 向罗盘 / 16 人海报 / 6s 帧序列 | `PAPERDOLL_SHOWCASE_OK` |
| `tools/record_showcase.sh` | 180 帧 → 640×360 / 30fps / 6s GIF | `PAPERDOLL_SHOWCASE_GIF_OK` |
| `tools/metric_rig.gd` | 透明底角色 / 舞台 / 16+8 向剪影 / 斩击帧 | `PAPERDOLL_METRICS_OK` |
| `tools/measure_paperdoll.py` | 墨色族 / 色数 / L* / IoU / 对比度 / 随机色彩纪律 | `docs/metrics/summary.json` |
| `tools/perf_paperdoll.gd` | Intel 帧率采样（min ≥30）+ 逐只烘焙成本（p90 ≤16ms） | `PAPERDOLL_FPS_OK` / `PAPERDOLL_BAKE_OK` |
| `tools/demo_paperdoll.gd` | Movie Maker 宣传片段驱动 | `PAPERDOLL_RECORD_OK`（脚本） |
| `tools/record_paperdoll.sh` | 录制 AVI → MP4 / GIF | 输出 `docs/paperdoll.mp4`、`docs/paperdoll.gif` |
| `tools/verify.sh` | 串起以上检查（`SKIP_GPU=1` 可跳过真机部分；先测 FPS 再截图，避免截图进程退出污染采样） | `PAPERDOLL_VERIFY_OK` |

## 9. 原创性

- 不使用、不复制参考视频的素材、UI、名称或品牌。
- 全部 slot / variant / palette / 角色命名、界面布局与程序化绘制均为本项目原创。
- 外部依赖仅 Godot 引擎与系统字体；无二进制美术资产。

## 10. 美术验收指标（T-20261120-009）

采集方式：`tools/metric_rig.gd` 用真实 GPU（Intel HD 6000 / GL Compatibility）渲染透明底角色、
舞台、16 预设剪影、8 向剪影与斩击帧；`tools/measure_paperdoll.py` 计算并写
`docs/metrics/summary.json`。剪影归一化采用“bbox 等比缩放到高 96px、保留宽高比、居中”。

| 指标 | 目标 | 实测 | 判定 |
| --- | ---: | ---: | --- |
| 墨色族（到 `#3a2f43` <40）/ 角色 bbox | ≤9% | **7.02%**（3518 / 142×353） | PASS |
| 量化色数（24 级分箱） | ≥80 | **85** | PASS |
| 角色 median L* / 舞台 median L* | ΔL* ≥25 | **62.0 / 94.0，Δ=32.0** | PASS |
| 斩击深边 `#8f3030` vs 舞台 | ≥3:1 | **6.85:1** | PASS |
| 斩击外圈 `#b23c33` vs 舞台 | ≥3:1 | **5.03:1** | PASS |
| UI 小字（白/深珊瑚、白/深青绿、白/深紫、MUTED/纸） | ≥4.5:1 | **5.76 / 5.01 / 6.24 / 6.01** | PASS |
| 8 向 正/背 IoU（未对齐） | ≤0.70 | **0.695**（归一化 0.568） | PASS |
| 8 向 相邻 IoU 均值 / 最大（未对齐） | ≤0.75 | **0.646 / 0.743** | PASS |
| 16 人剪影 IoU 均值（等比归一化） | ≤0.30 | **0.413**（p90 0.591，max 0.723） | **FAIL** |
| 随机 10 次色彩纪律（≤3 个色相簇） | 10/10 | **10/10** | PASS |
| Intel 帧率 min | ≥30 | **31**（avg 39.0；verify 串联 32.0/34.4） | PASS（贴近下限） |

**已知未达项 / 风险**：

1. **16 人剪影 IoU 0.41 > 0.30**：同一骨架 + 17 槽共用身体，靠帽子/武器/背饰/气场/体型
   build（0.90–1.16）已把均值从 T-006 的 0.52 降到 0.41，p90/最大值也低于原评审值；
   但要到 0.30 需要每角色独立骨架比例或更大的专属剪影资产。已交给 T-012 美术总监判断
   是否值得为 16 人做“专属破形件/体型”二次设计。
2. **正/背 IoU 0.687**：依赖披风槽的兜帽/肩披/加宽下摆/后发；没有披风的角色仍会更接近。
3. **缩略图 AA（T-010 已修）**：`DollThumbnail` 改为 2× SubViewport + Linear；16/16 卡
   由 smoke 校验。残留问题是 2× 采样带来的 1px 软边（设计预期），不是 1px 阶梯。
4. **斩击金色核心 1.22:1**：核心是 2px 高光，靠外两层深边/珊瑚圈提供 ≥3:1 的可读性；
   如果 QA 要求“每一层都 ≥3:1”，需把核心改为深金或加深边。
5. **FPS 稳态 min 30–33**：2× 超采样后与 T-009 同量级（稳态无每帧重绘），但 Intel HD 6000 余量仍小；
   后台负载高时首秒或个别 1 秒窗口会掉到 23–29。perf 已改为 7×1s 并丢弃首秒，
   原始样本照实输出。若后续还要加层，优先把试衣镜降到 20Hz 或预烘焙部件。
6. **随机阵容的烘焙尖峰**：16 张卡仍会在同一帧发起重烘焙（一次性），
   16 个 2× 视口同时填充会造成一次短暂尖峰；未做逐帧排队，避免改变“立即换装”的反馈。
