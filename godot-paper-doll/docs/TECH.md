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
- `DIRS`：8 个方向，包含 `yaw`（0 = 正面，1 = 正侧）、`back`（是否背向）、`flip`（是否水平镜像）。
- `ACTIONS`：`idle / walk / attack / hit`。
- 外观内存格式：`{slot_id: {variant: String, color: Color}}`；
  JSON 格式：`{slot_id: {variant: String, color: "#rrggbb"}}`。
- `normalize_outfit` 对缺失槽位、非法变体、非法颜色做兜底；`encode_outfit` 负责导出。
- 组合空间：所有槽位的 `变体数 × 8 色` 相乘，当前约 `9.0×10^26`。

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
- 八向通过 `yaw` 收窄肩宽/髋宽、头部前探、远侧肢体变暗、左右镜像实现。
- 动作曲线：
  - `idle`：呼吸 + 摆臂；
  - `walk`：0.82s 四拍步态，脚步下沉补偿避免“飘”；
  - `attack`：1.05s 蓄力 / 挥砍 / 收势，附 slash 特效；
  - `hit`：1.10s 指数衰减冲击 + 抖动 + 星星特效。
- 所有槽位仅读取同一份 pose 字典，因此换装、换向、换动作时部件天然对齐。

## 4. 绘制管线

`scripts/doll/part_painter.gd` → `PaintFigure / PaintCloth / PaintProps` → `DrawKit`

- `PartPainter.PAINTED` 是槽位→变体的完整覆盖表；`validate()` 在 smoke 中检查无遗漏。
- 画笔统一使用 DrawKit 的形状原语：圆、椭圆、圆角矩形、多边形、胶囊、折线、弧、星星。
- 每个槽位独立取色：`make_palette(primary)` 生成 primary/shade/deep/light/ink/paper/accent 等角色色。

### 三角形批处理（性能关键）

`DrawKit.begin_batch(canvas_item)` 在 `PaperDollRenderer._draw` 开始时启用，结束时 `end_batch()`：

- 所有填充 / 描边不再逐条 `draw_*`，而是写入 `PackedVector2Array` + `PackedColorArray` + 索引；
- 一次 `RenderingServer.canvas_item_add_triangle_array` 提交整只纸偶；
- 三角形按绘制顺序追加，层级与透明度顺序不变；
- 描边由“线段四边形 + 折点圆片”组成；圆形/椭圆/胶囊预先三角化；
- 阴影带坐标缩放，保留在批次外单独绘制。

在 Intel 集显 / macOS OpenGL 上，这套批处理把单偶重绘的提交开销从数百条指令降为一次提交，
是达到 30 FPS 的必要条件。

## 5. 渲染与 UI

- `PaperDollRenderer`：单个纸偶的 CanvasItem；`set_doll / set_direction / set_action / set_clock`；
  朝左时 `scale.x` 取负实现镜像；`show_shadow`、`mini`、`redraw_hz` 可调。
  - 试衣镜默认 `redraw_hz = 24`（定格木偶节奏），空闲时无重绘。
- `DollThumbnail`：把 `PaperDollRenderer` 放进 `SubViewport`，渲染两帧后把
  `render_target_update_mode` 设为 `UPDATE_DISABLED`，外层用 `TextureRect` 显示结果。
  - 用于 16 张阵容卡与 8 向 / 4 动作对照页，避免 24 个木偶每帧重画。
  - 外观签名不变时 `LineupCard.apply_entry` 跳过重烘焙。
- `main.gd`：用代码构建全部 UI（主题、三栏、页脚、对照弹层）；提供 smoke 所需的
  `set_slot_variant / set_slot_color / set_direction / set_action / save_current / load_saved /
  set_timeline_clock / set_ui_visible / get_*` 验收 API。
- `AtelierTheme`：奶油纸面、墨色描边、珊瑚/青绿/芥末三色；系统字体，无字体资源文件。
- `StageBackdrop`：试衣镜与对照页的暖色纸舞台（伪纸屑、软阴影、虚线缝边）。

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
| 最终 | 批次 + 24 Hz 试衣镜 + 签名缓存 | **35–55 FPS**（`PAPERDOLL_FPS_OK`） |

试衣镜与卡片在未变化时不重绘；阵容/对照页在数据变化时才重新烘焙。
`tools/perf_paperdoll.gd` 采样 5 秒并输出 `PAPERDOLL_FPS_OK` / `PAPERDOLL_FPS_LOW`。

## 8. 验收工具

| 工具 | 作用 | 成功标记 |
| --- | --- | --- |
| `tools/smoke_paperdoll.gd` | 17 槽 / 83 变体 / 8 向 / 4 动作 / 色板 / z 序 / 16 预设 / 随机 / JSON 往返 / 烘焙缓存 | `PAPERDOLL_SMOKE_OK` |
| `tools/screenshot_paperdoll.gd` | 真机 1280×720 的 6 张截图 | `PAPERDOLL_SHOTS_OK` |
| `tools/perf_paperdoll.gd` | Intel 帧率采样，要求最小值 ≥30 | `PAPERDOLL_FPS_OK` |
| `tools/demo_paperdoll.gd` | Movie Maker 宣传片段驱动 | `PAPERDOLL_RECORD_OK`（脚本） |
| `tools/record_paperdoll.sh` | 录制 AVI → MP4 / GIF | 输出 `docs/paperdoll.mp4`、`docs/paperdoll.gif` |
| `tools/verify.sh` | 串起以上检查（`SKIP_GPU=1` 可跳过真机部分） | `PAPERDOLL_VERIFY_OK` |

## 9. 原创性

- 不使用、不复制参考视频的素材、UI、名称或品牌。
- 全部 slot / variant / palette / 角色命名、界面布局与程序化绘制均为本项目原创。
- 外部依赖仅 Godot 引擎与系统字体；无二进制美术资产。
